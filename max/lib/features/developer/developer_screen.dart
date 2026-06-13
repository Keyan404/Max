import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../chat/chat_provider.dart';

// ─────────────────────────────────────────────────────────────────────
// Developer Console Screen
// Provides: chat history dump, AI traces, error log, vector DB status
// ─────────────────────────────────────────────────────────────────────

enum DevTab { logs, chatTrace, systemInfo }

class DeveloperScreen extends ConsumerStatefulWidget {
  const DeveloperScreen({super.key});

  @override
  ConsumerState<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends ConsumerState<DeveloperScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Simulated in-memory log buffer (production: wire to a real log sink)
  final List<_LogEntry> _logs = [
    _LogEntry(level: 'INFO', message: 'MAX AI boot sequence complete'),
    _LogEntry(level: 'INFO', message: 'FastAPI backend connected'),
    _LogEntry(level: 'INFO', message: 'Qdrant vector store ready (768-dim)'),
    _LogEntry(level: 'INFO', message: 'Firebase Admin SDK initialized'),
    _LogEntry(level: 'DEBUG', message: 'Groq SSE stream handler registered'),
    _LogEntry(level: 'INFO', message: 'AccessibilityService: active'),
    _LogEntry(level: 'INFO', message: 'FloatingBubbleService: OVERLAY_GRANTED'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: DevTab.values.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF080C12),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLogsTab(),
                  _buildChatTraceTab(chat),
                  _buildSystemInfoTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: AppColors.glassBorder.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: const Icon(Icons.arrow_back_ios_rounded,
                  color: Colors.white60, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          const Icon(Icons.terminal_rounded,
              color: AppColors.electricCyan, size: 18),
          const SizedBox(width: 8),
          const Text(
            'DEVELOPER CONSOLE',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 2.5,
            ),
          ),
          const Spacer(),
          // Clear logs
          GestureDetector(
            onTap: () => setState(() => _logs.clear()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                color: Colors.redAccent.withOpacity(0.06),
              ),
              child: const Text(
                'CLEAR',
                style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Tab Bar
  // ─────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: AppColors.electricCyan.withOpacity(0.15),
          border: Border.all(color: AppColors.electricCyan.withOpacity(0.5)),
        ),
        labelColor: AppColors.electricCyan,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
        tabs: const [
          Tab(text: 'LOGS'),
          Tab(text: 'CHAT TRACE'),
          Tab(text: 'SYSTEM'),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Logs Tab
  // ─────────────────────────────────────────────
  Widget _buildLogsTab() {
    if (_logs.isEmpty) {
      return const Center(
        child: Text('No logs yet.', style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _logs.length,
      itemBuilder: (_, i) {
        final log = _logs[_logs.length - 1 - i];
        return _buildLogRow(log);
      },
    );
  }

  Widget _buildLogRow(_LogEntry log) {
    Color levelColor;
    switch (log.level) {
      case 'ERROR':
        levelColor = Colors.redAccent;
        break;
      case 'WARN':
        levelColor = Colors.orangeAccent;
        break;
      case 'DEBUG':
        levelColor = AppColors.neonPurple;
        break;
      default:
        levelColor = AppColors.glowingGreen;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: levelColor.withOpacity(0.04),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '[${log.timestamp}]',
            style: TextStyle(
                color: Colors.white30,
                fontSize: 10,
                fontFamily: 'monospace'),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: levelColor.withOpacity(0.15),
            ),
            child: Text(
              log.level,
              style: TextStyle(
                  color: levelColor,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              log.message,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11,
                  fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Chat Trace Tab
  // ─────────────────────────────────────────────
  Widget _buildChatTraceTab(ChatState chat) {
    if (chat.messages.isEmpty) {
      return const Center(
        child: Text('No messages in session.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: chat.messages.length,
      itemBuilder: (_, i) {
        final msg = chat.messages[i];
        final bool isUser = msg.sender == 'user';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.white.withOpacity(0.03),
            border: Border.all(
              color: isUser
                  ? AppColors.electricCyan.withOpacity(0.2)
                  : AppColors.glassBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    isUser ? '► USER' : '◄ MAX',
                    style: TextStyle(
                      color: isUser
                          ? AppColors.electricCyan
                          : AppColors.glowingGreen,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}:${msg.timestamp.second.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        color: Colors.white30,
                        fontSize: 9,
                        fontFamily: 'monospace'),
                  ),
                  if (msg.isPinned) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.push_pin,
                        size: 10, color: AppColors.electricCyan),
                  ],
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: msg.content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
                    child: const Icon(Icons.copy_outlined,
                        size: 12, color: Colors.white30),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (msg.reasoning.isNotEmpty) ...[
                Text(
                  'REASONING: ${msg.reasoning.substring(0, msg.reasoning.length.clamp(0, 120))}...',
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontFamily: 'monospace',
                      fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                msg.content,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontFamily: 'monospace'),
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // System Info Tab
  // ─────────────────────────────────────────────
  Widget _buildSystemInfoTab() {
    final entries = [
      ['Platform', 'Android (Flutter 3.x)'],
      ['Backend', 'FastAPI + Uvicorn'],
      ['AI Engine', 'Groq (Llama / DeepSeek / Qwen)'],
      ['Vector DB', 'Qdrant (768-dim nomic-embed)'],
      ['Auth', 'Firebase Admin SDK'],
      ['State Mgmt', 'Riverpod 2.x'],
      ['Routing', 'GoRouter 14.x'],
      ['Audio', 'speech_to_text + flutter_tts'],
      ['Security', 'AES Keystore + Biometric'],
      ['Services', 'ForegroundService, AccessibilityService, FloatingBubble, MediaProjection'],
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      children: [
        // Architecture badge
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [
                AppColors.electricCyan.withOpacity(0.08),
                AppColors.neonPurple.withOpacity(0.08),
              ],
            ),
            border: Border.all(
                color: AppColors.electricCyan.withOpacity(0.25)),
          ),
          child: Column(
            children: [
              const Text(
                'MAX AI ARCHITECTURE',
                style: TextStyle(
                  color: AppColors.electricCyan,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'v1.0.0 · Production Ready',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        ...entries.map(
          (e) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.white.withOpacity(0.025),
              border: Border.all(
                  color: AppColors.glassBorder.withOpacity(0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 95,
                  child: Text(
                    e[0],
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const Text(
                  ':  ',
                  style: TextStyle(
                      color: AppColors.electricCyan, fontFamily: 'monospace'),
                ),
                Expanded(
                  child: Text(
                    e[1],
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Log entry model
// ─────────────────────────────────────────────────────────────────────
class _LogEntry {
  final String level;
  final String message;
  final String timestamp;

  _LogEntry({required this.level, required this.message})
      : timestamp = _ts();

  static String _ts() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }
}
