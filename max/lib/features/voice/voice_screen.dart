import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../core/theme/app_theme.dart';
import '../chat/chat_provider.dart';
import '../settings/settings_provider.dart';

// ─────────────────────────────────────────────────────────────────────
// Voice state machine
// ─────────────────────────────────────────────────────────────────────
enum VoiceState { idle, listening, thinking, speaking }

// ─────────────────────────────────────────────────────────────────────
// VoiceScreen — Jarvis-style full-screen voice assistant UI
// ─────────────────────────────────────────────────────────────────────
class VoiceScreen extends ConsumerStatefulWidget {
  const VoiceScreen({super.key});

  @override
  ConsumerState<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends ConsumerState<VoiceScreen>
    with TickerProviderStateMixin {
  // ── Engine instances ──────────────────────────────────────
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  // ── State ─────────────────────────────────────────────────
  VoiceState _voiceState = VoiceState.idle;
  bool _sttAvailable = false;
  String _transcribedText = '';
  String _responseText = '';
  bool _isMuted = false;

  // ── Animation controllers ─────────────────────────────────
  late AnimationController _waveController;
  late AnimationController _glowController;
  late AnimationController _orbitController;

  // ── Amplitude for wave painter (0.0 → 1.0) ───────────────
  double _amplitude = 0.05;

  // ─────────────────────────────────────────────────────────
  // Init
  // ─────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _initSTT();
    _initTTS();
  }

  Future<void> _initSTT() async {
    final available = await _stt.initialize(
      onError: (error) {
        if (mounted) {
          setState(() {
            _voiceState = VoiceState.idle;
            _amplitude = 0.05;
          });
        }
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted && _voiceState == VoiceState.listening) {
            _onSTTDone();
          }
        }
      },
    );
    if (mounted) setState(() => _sttAvailable = available);
  }

  Future<void> _updateTtsSettings() async {
    final settings = ref.read(settingsProvider);
    await _tts.setLanguage(settings.voiceLanguage);
    await _tts.setSpeechRate(settings.speechRate);
    await _tts.setPitch(settings.voicePitch);

    try {
      final List<dynamic>? voices = await _tts.getVoices;
      if (voices != null) {
        final String lang = settings.voiceLanguage;
        final String profile = settings.voiceProfile;
        
        dynamic selectedVoice;
        for (var voice in voices) {
          if (voice is Map) {
            final String name = voice['name']?.toString().toLowerCase() ?? '';
            final String locale = voice['locale']?.toString() ?? '';
            
            if (locale.startsWith(lang)) {
              if (profile == 'girl' && (name.contains('female') || name.contains('girl') || name.contains('f-local') || name.contains('female-local'))) {
                selectedVoice = voice;
                break;
              } else if ((profile == 'boy' || profile == 'jarvis') && (name.contains('male') || name.contains('boy') || name.contains('m-local') || name.contains('male-local'))) {
                selectedVoice = voice;
                break;
              }
            }
          }
        }
        if (selectedVoice != null) {
          await _tts.setVoice(Map<String, String>.from(selectedVoice));
        }
      }
    } catch (_) {}
  }

  Future<void> _initTTS() async {
    await _updateTtsSettings();
    await _tts.setVolume(1.0);

    _tts.setStartHandler(() {
      if (mounted) setState(() => _voiceState = VoiceState.speaking);
    });
    _tts.setCompletionHandler(() {
      if (mounted) setState(() {
        _voiceState = VoiceState.idle;
        _amplitude = 0.05;
      });
    });
    _tts.setErrorHandler((msg) {
      if (mounted) setState(() => _voiceState = VoiceState.idle);
    });
  }

  // ─────────────────────────────────────────────────────────
  // STT control
  // ─────────────────────────────────────────────────────────
  Future<void> _startListening() async {
    if (!_sttAvailable || _voiceState != VoiceState.idle) return;
    await _tts.stop();

    setState(() {
      _voiceState = VoiceState.listening;
      _transcribedText = '';
      _responseText = '';
      _amplitude = 0.4;
    });

    await _stt.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      localeId: 'en_US',
    );
  }

  Future<void> _stopListening() async {
    await _stt.stop();
    _onSTTDone();
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() {
      _transcribedText = result.recognizedWords;
      // Amplitude driven by confidence
      _amplitude = 0.2 + (result.confidence * 0.7).clamp(0.0, 0.8);
    });
    if (result.finalResult) _onSTTDone();
  }

  void _onSTTDone() {
    if (_transcribedText.isEmpty) {
      setState(() {
        _voiceState = VoiceState.idle;
        _amplitude = 0.05;
      });
      return;
    }

    setState(() {
      _voiceState = VoiceState.thinking;
      _amplitude = 0.1;
    });

    _sendToAI(_transcribedText);
  }

  // ─────────────────────────────────────────────────────────
  // AI call via existing ChatNotifier
  // ─────────────────────────────────────────────────────────
  Future<void> _sendToAI(String userText) async {
    try {
      await ref.read(chatProvider.notifier).sendPrompt(userText);

      // Wait for the stream to complete (isStreaming goes false)
      await _waitForResponse();

      final messages = ref.read(chatProvider).messages;
      final lastResponse = messages.isNotEmpty
          ? messages.last.content
          : 'I could not process that request.';

      setState(() {
        _responseText = lastResponse;
        _voiceState = VoiceState.speaking;
        _amplitude = 0.5;
      });

      if (!_isMuted) {
        await _updateTtsSettings();
        await _tts.speak(lastResponse);
      } else {
        setState(() {
          _voiceState = VoiceState.idle;
          _amplitude = 0.05;
        });
      }
    } catch (e) {
      setState(() {
        _responseText = 'An error occurred processing your request.';
        _voiceState = VoiceState.idle;
      });
    }
  }

  Future<void> _waitForResponse() async {
    // Poll every 200ms waiting for streaming to finish (max 30s)
    int maxWait = 150; // 150 × 200ms = 30 seconds
    while (maxWait-- > 0) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!ref.read(chatProvider).isStreaming) break;
    }
  }

  // ─────────────────────────────────────────────────────────
  // Abort current action
  // ─────────────────────────────────────────────────────────
  Future<void> _abort() async {
    await _stt.stop();
    await _tts.stop();
    setState(() {
      _voiceState = VoiceState.idle;
      _transcribedText = '';
      _responseText = '';
      _amplitude = 0.05;
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    _glowController.dispose();
    _orbitController.dispose();
    _stt.cancel();
    _tts.stop();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Sync amplitude with speaking TTS if in speaking mode
    if (_voiceState == VoiceState.speaking) {
      _amplitude = 0.3 + math.sin(_waveController.value * 2 * math.pi) * 0.3;
    }

    return Scaffold(
      backgroundColor: AppColors.spaceBlack,
      body: Stack(
        children: [
          // ── Full-screen waveform / thinking rings canvas ──
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (_, __) => CustomPaint(
                painter: VoiceWavePainter(
                  phase: _waveController.value * 2 * math.pi,
                  amplitude: _amplitude,
                  state: _voiceState,
                  orbitPhase: _orbitController.value * 2 * math.pi,
                ),
              ),
            ),
          ),

          // ── Foreground HUD ────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                const Spacer(),
                _buildCenterOrb(),
                const SizedBox(height: 32),
                _buildStateLabel(),
                const SizedBox(height: 16),
                _buildTranscriptBubble(),
                const Spacer(),
                _buildControlRow(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Top Bar
  // ─────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _glassIconBtn(Icons.close_rounded, () => context.pop()),
          Column(
            children: [
              const Text(
                'MAX VOICE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 3.5,
                ),
              ),
              Text(
                'CORE v2.0',
                style: TextStyle(
                  color: AppColors.electricCyan.withOpacity(0.7),
                  fontSize: 9,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
          _glassIconBtn(
            Icons.settings_outlined,
            () => context.push('/settings'),
          ),
        ],
      ),
    );
  }

  Widget _glassIconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.06),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Center Glowing Orb
  // ─────────────────────────────────────────────
  Widget _buildCenterOrb() {
    return GestureDetector(
      onTap: () {
        if (_voiceState == VoiceState.idle) {
          _startListening();
        } else if (_voiceState == VoiceState.listening) {
          _stopListening();
        }
      },
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (_, __) {
          final double scale = 1.0 + (_glowController.value * 0.07);
          final double glowBlur = 40 + (_glowController.value * 30);
          final glowColor = _getGlowColor();

          return Center(
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      glowColor.withOpacity(0.8),
                      glowColor.withOpacity(0.1),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                    radius: 0.85,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withOpacity(0.4),
                      blurRadius: glowBlur,
                      spreadRadius: 4,
                    ),
                  ],
                  border: Border.all(
                    color: glowColor.withOpacity(0.6),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: Icon(
                      _getOrbIcon(),
                      key: ValueKey(_voiceState),
                      size: 56,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  // State Label + Hint
  // ─────────────────────────────────────────────
  Widget _buildStateLabel() {
    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _getStateLabel(),
            key: ValueKey(_voiceState),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: _getGlowColor(),
              letterSpacing: 4.0,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _getHintText(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // Transcript / Response bubble
  // ─────────────────────────────────────────────
  Widget _buildTranscriptBubble() {
    final String displayText =
        _responseText.isNotEmpty ? _responseText : _transcribedText;
    if (displayText.isEmpty) return const SizedBox(height: 60);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      constraints: const BoxConstraints(maxHeight: 130),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Text(
          displayText,
          style: TextStyle(
            color: _responseText.isNotEmpty
                ? AppColors.textPrimary
                : AppColors.electricCyan,
            fontSize: 14,
            height: 1.5,
            fontStyle: _responseText.isEmpty ? FontStyle.italic : FontStyle.normal,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Control Row (Mute | Abort | Keyboard)
  // ─────────────────────────────────────────────
  Widget _buildControlRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _controlButton(
          icon: _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          label: _isMuted ? 'Unmute' : 'Mute',
          color: _isMuted ? Colors.orangeAccent : Colors.white70,
          onTap: () => setState(() => _isMuted = !_isMuted),
        ),
        _controlButton(
          icon: Icons.stop_circle_outlined,
          label: 'Abort',
          color: Colors.redAccent,
          onTap: _abort,
        ),
        _controlButton(
          icon: Icons.keyboard_rounded,
          label: 'Type',
          color: Colors.white70,
          onTap: () => context.pop(),
        ),
      ],
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white70,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.06),
              border: Border.all(
                color: color.withOpacity(0.3),
              ),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────
  Color _getGlowColor() {
    switch (_voiceState) {
      case VoiceState.idle:
        return Colors.white54;
      case VoiceState.listening:
        return AppColors.electricCyan;
      case VoiceState.thinking:
        return AppColors.neonPurple;
      case VoiceState.speaking:
        return AppColors.glowingGreen;
    }
  }

  IconData _getOrbIcon() {
    switch (_voiceState) {
      case VoiceState.idle:
        return Icons.mic_none_rounded;
      case VoiceState.listening:
        return Icons.mic_rounded;
      case VoiceState.thinking:
        return Icons.psychology_outlined;
      case VoiceState.speaking:
        return Icons.surround_sound_outlined;
    }
  }

  String _getStateLabel() {
    switch (_voiceState) {
      case VoiceState.idle:
        return 'TAP TO SPEAK';
      case VoiceState.listening:
        return 'LISTENING';
      case VoiceState.thinking:
        return 'THINKING';
      case VoiceState.speaking:
        return 'SPEAKING';
    }
  }

  String _getHintText() {
    switch (_voiceState) {
      case VoiceState.idle:
        return '"Max, what\'s on my screen?" or "Turn on flashlight"';
      case VoiceState.listening:
        return 'Tap the orb to stop and process';
      case VoiceState.thinking:
        return 'MAX is processing your request...';
      case VoiceState.speaking:
        return 'Tap Abort to stop playback';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
// VoiceWavePainter — renders sine-wave bands + thinking orbits
// ─────────────────────────────────────────────────────────────────────
class VoiceWavePainter extends CustomPainter {
  final double phase;
  final double amplitude;
  final VoiceState state;
  final double orbitPhase;

  const VoiceWavePainter({
    required this.phase,
    required this.amplitude,
    required this.state,
    required this.orbitPhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (state == VoiceState.thinking) {
      _paintThinkingRings(canvas, size);
    } else {
      _paintSineWaves(canvas, size);
    }
  }

  void _paintSineWaves(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Color per state
    Color baseColor;
    switch (state) {
      case VoiceState.listening:
        baseColor = AppColors.electricCyan;
        break;
      case VoiceState.speaking:
        baseColor = AppColors.glowingGreen;
        break;
      default:
        baseColor = Colors.white;
    }

    final double centerY = size.height * 0.72;

    // 3 layered sine waves with Gaussian envelope
    final layers = [
      {'freq': 1.5, 'amp': 48.0, 'alpha': 0.45, 'width': 2.5, 'phaseShift': 0.0},
      {'freq': 2.8, 'amp': 28.0, 'alpha': 0.30, 'width': 1.5, 'phaseShift': math.pi * 0.6},
      {'freq': 0.9, 'amp': 65.0, 'alpha': 0.15, 'width': 4.5, 'phaseShift': math.pi * 1.3},
    ];

    for (final layer in layers) {
      paint.color = baseColor.withOpacity(layer['alpha']! * amplitude.clamp(0.1, 1.0));
      paint.strokeWidth = layer['width']!;

      final path = Path();
      final double maxAmp = layer['amp']! * amplitude;
      final double layerPhase = phase + layer['phaseShift']!;

      path.moveTo(0, centerY);

      for (double x = 0; x <= size.width; x += 2.5) {
        final double normalized = (x - size.width / 2) / (size.width / 2);
        final double envelope = math.exp(-2.2 * normalized * normalized);
        final double y = centerY +
            math.sin(x * 0.012 * layer['freq']! + layerPhase) * maxAmp * envelope;
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _paintThinkingRings(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.45);
    final paint = Paint()..style = PaintingStyle.stroke;

    // Static concentric rings
    for (int i = 1; i <= 3; i++) {
      paint
        ..color = AppColors.neonPurple.withOpacity(0.12 * (4 - i).toDouble())
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, 100.0 * i * 0.6, paint);
    }

    // Two orbiting arcs
    paint
      ..color = AppColors.electricCyan.withOpacity(0.6)
      ..strokeWidth = 2.5;

    final Rect arc1Rect = Rect.fromCircle(center: center, radius: 115);
    canvas.drawArc(arc1Rect, orbitPhase, 1.6, false, paint);
    canvas.drawArc(arc1Rect, orbitPhase + math.pi, 1.6, false, paint);

    paint
      ..color = AppColors.neonPurple.withOpacity(0.4)
      ..strokeWidth = 1.5;

    final Rect arc2Rect = Rect.fromCircle(center: center, radius: 142);
    canvas.drawArc(arc2Rect, -orbitPhase * 0.7, 2.0, false, paint);
    canvas.drawArc(arc2Rect, (-orbitPhase * 0.7) + math.pi, 2.0, false, paint);
  }

  @override
  bool shouldRepaint(covariant VoiceWavePainter old) =>
      old.phase != phase ||
      old.amplitude != amplitude ||
      old.state != state ||
      old.orbitPhase != orbitPhase;
}
