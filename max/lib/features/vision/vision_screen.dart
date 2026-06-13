import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import 'vision_provider.dart';

class VisionScreen extends ConsumerStatefulWidget {
  const VisionScreen({super.key});

  @override
  ConsumerState<VisionScreen> createState() => _VisionScreenState();
}

class _VisionScreenState extends ConsumerState<VisionScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _queryController = TextEditingController();
  late AnimationController _scanAnimController;
  late Animation<double> _scanLineAnim;

  @override
  void initState() {
    super.initState();
    _scanAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _scanLineAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanAnimController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _scanAnimController.dispose();
    _queryController.dispose();
    super.dispose();
  }

  void _triggerAnalysis() {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a question about the screen first.')),
      );
      return;
    }
    ref.read(visionProvider.notifier).analyzeCurrentScreen(ref, query);
  }

  @override
  Widget build(BuildContext context) {
    final vision = ref.watch(visionProvider);

    return Scaffold(
      backgroundColor: AppColors.spaceBlack,
      body: Stack(
        children: [
          // === Background glow orbs ===
          Positioned(
            top: -80,
            left: -80,
            child: _glowOrb(AppColors.electricCyan.withOpacity(0.12), 250),
          ),
          Positioned(
            bottom: -60,
            right: -60,
            child: _glowOrb(AppColors.neonPurple.withOpacity(0.10), 200),
          ),

          // === Main Content ===
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Column(
                      children: [
                        // --- Screen Capture Preview / Idle HUD ---
                        _buildCapturePreview(vision),
                        const SizedBox(height: 24),

                        // --- Query Input ---
                        _buildQueryInput(vision),
                        const SizedBox(height: 16),

                        // --- Analyze Button ---
                        _buildAnalyzeButton(vision),
                        const SizedBox(height: 24),

                        // --- Analysis Result ---
                        if (vision.analysisResult.isNotEmpty)
                          _buildAnalysisResult(vision.analysisResult),

                        // --- Error ---
                        if (vision.error.isNotEmpty)
                          _buildErrorPanel(vision.error),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // App Bar
  // ─────────────────────────────────────────────
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          Column(
            children: [
              const Text(
                'VISION HUD',
                style: TextStyle(
                  color: AppColors.electricCyan,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3.0,
                ),
              ),
              Text(
                'Screen Projection Analysis',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            onPressed: () => ref.read(visionProvider.notifier).clearAnalysis(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Screen Capture Preview / Idle HUD
  // ─────────────────────────────────────────────
  Widget _buildCapturePreview(VisionState vision) {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: vision.isCapturing
              ? AppColors.electricCyan
              : AppColors.glassBorder,
          width: vision.isCapturing ? 1.5 : 1.0,
        ),
        color: Colors.black.withOpacity(0.4),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // Show screenshot preview if available
          if (vision.capturedImageBase64.isNotEmpty)
            _buildBase64Image(vision.capturedImageBase64)
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.screenshot_monitor_rounded,
                    size: 56,
                    color: AppColors.electricCyan.withOpacity(0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No Screen Captured Yet',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Type a query and press ANALYZE',
                    style: TextStyle(
                      color: AppColors.textSecondary.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

          // Scanning animation overlay during capture
          if (vision.isCapturing)
            AnimatedBuilder(
              animation: _scanLineAnim,
              builder: (context, _) {
                return Positioned(
                  top: _scanLineAnim.value * 220,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          AppColors.electricCyan.withOpacity(0.9),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

          // "CAPTURING" badge
          if (vision.isCapturing)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.electricCyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.electricCyan, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 8,
                      height: 8,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.electricCyan),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'CAPTURING',
                      style: TextStyle(
                        color: AppColors.electricCyan,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Corner grid-line HUD overlay
          _buildCornerHUD(),
        ],
      ),
    );
  }

  Widget _buildBase64Image(String base64String) {
    try {
      final Uint8List bytes = base64Decode(base64String);
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildCornerHUD() {
    const double size = 18.0;
    const double thick = 2.0;
    const color = AppColors.electricCyan;

    Widget corner({bool flipX = false, bool flipY = false}) {
      return Transform.scale(
        scaleX: flipX ? -1 : 1,
        scaleY: flipY ? -1 : 1,
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _CornerPainter(color: color, thickness: thick),
          ),
        ),
      );
    }

    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            Align(alignment: Alignment.topLeft, child: corner()),
            Align(alignment: Alignment.topRight, child: corner(flipX: true)),
            Align(alignment: Alignment.bottomLeft, child: corner(flipY: true)),
            Align(
                alignment: Alignment.bottomRight,
                child: corner(flipX: true, flipY: true)),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Query Input
  // ─────────────────────────────────────────────
  Widget _buildQueryInput(VisionState vision) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: TextField(
        controller: _queryController,
        enabled: !vision.isCapturing,
        maxLines: null,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'What do you want MAX to analyze? e.g. "Summarize what\'s on my screen"',
          hintStyle: TextStyle(
            color: AppColors.textSecondary.withOpacity(0.5),
            fontSize: 13,
          ),
          prefixIcon: const Icon(
            Icons.center_focus_strong_rounded,
            color: AppColors.electricCyan,
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Analyze Button
  // ─────────────────────────────────────────────
  Widget _buildAnalyzeButton(VisionState vision) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: EdgeInsets.zero,
        ),
        onPressed: vision.isCapturing ? null : _triggerAnalysis,
        child: Ink(
          decoration: BoxDecoration(
            gradient: vision.isCapturing
                ? LinearGradient(
                    colors: [Colors.grey.shade800, Colors.grey.shade700])
                : const LinearGradient(
                    colors: [AppColors.electricCyan, Color(0xFF006DCC)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: vision.isCapturing
                ? []
                : [
                    BoxShadow(
                      color: AppColors.electricCyan.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    )
                  ],
          ),
          child: Container(
            alignment: Alignment.center,
            child: vision.isCapturing
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Capturing & Analyzing...',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_enhance_rounded, color: Colors.black, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'CAPTURE & ANALYZE SCREEN',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Analysis Result Panel
  // ─────────────────────────────────────────────
  Widget _buildAnalysisResult(String result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(
          color: AppColors.glowingGreen.withOpacity(0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.glowingGreen.withOpacity(0.06),
            blurRadius: 20,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.glowingGreen,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'VISION ANALYSIS',
                style: TextStyle(
                  color: AppColors.glowingGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Divider(color: AppColors.glassBorder.withOpacity(0.5)),
          const SizedBox(height: 8),

          // Markdown body
          MarkdownBody(
            data: result,
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                height: 1.65,
              ),
              code: TextStyle(
                backgroundColor: Colors.black45,
                color: AppColors.electricCyan,
                fontSize: 13,
                fontFamily: 'monospace',
              ),
              codeblockDecoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(10),
              ),
              h1: const TextStyle(
                color: AppColors.electricCyan,
                fontWeight: FontWeight.bold,
              ),
              h2: const TextStyle(
                color: AppColors.electricCyan,
                fontWeight: FontWeight.bold,
              ),
              strong: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              blockquote: const TextStyle(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Action row: Copy + Send to Chat
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _actionChip(
                icon: Icons.copy_outlined,
                label: 'Copy',
                onTap: () {
                  // Clipboard copy handled in real device
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Analysis copied to clipboard')),
                  );
                },
              ),
              const SizedBox(width: 8),
              _actionChip(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Open in Chat',
                color: AppColors.electricCyan,
                onTap: () => context.push('/chat'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c = color ?? AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(0.4)),
          color: c.withOpacity(0.08),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: c),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: c, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Error Panel
  // ─────────────────────────────────────────────
  Widget _buildErrorPanel(String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.redAccent.withOpacity(0.08),
        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // Helpers
  Widget _glowOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Corner Painter for HUD overlay
// ─────────────────────────────────────────────
class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;

  _CornerPainter({required this.color, required this.thickness});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
    canvas.drawLine(Offset.zero, Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) =>
      old.color != color || old.thickness != thickness;
}
