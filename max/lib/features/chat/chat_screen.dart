import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routing/app_router.dart';
import 'chat_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  
  bool _searchMode = false;
  String _searchQuery = "";

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    _messageController.clear();
    ref.read(chatProvider.notifier).sendPrompt(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    
    // Auto-scroll on new chunks
    if (chatState.isStreaming) {
      _scrollToBottom();
    }

    // Filter messages for search
    final displayedMessages = _searchMode && _searchQuery.isNotEmpty
        ? chatState.messages.where((m) => m.content.toLowerCase().contains(_searchQuery.toLowerCase())).toList()
        : chatState.messages;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: _searchMode
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: "Search chat...",
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                style: const TextStyle(color: AppColors.textPrimary),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              )
            : Row(
                children: [
                  Text(
                    "MAX AI",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.electricCyan,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.neonPurple.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.neonPurple, width: 0.8),
                    ),
                    child: Text(
                      chatState.activeModel.split('-').first.toUpperCase(),
                      style: const TextStyle(fontSize: 10, color: AppColors.textPrimary),
                    ),
                  )
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_searchMode ? Icons.close : Icons.search, color: AppColors.textPrimary),
            onPressed: () {
              setState(() {
                _searchMode = !_searchMode;
                if (!_searchMode) {
                  _searchQuery = "";
                  _searchController.clear();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
            onPressed: () {
              ref.read(chatProvider.notifier).clearChat();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background Glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neonPurple.withValues(alpha: 0.08),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.electricCyan.withValues(alpha: 0.05),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          
          Column(
            children: [
              // Chat logs
              Expanded(
                child: displayedMessages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.chat_bubble_outline_rounded, size: 64, color: AppColors.textSecondary),
                            const SizedBox(height: 16),
                            Text(
                              "Start your conversation with MAX",
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: displayedMessages.length,
                        itemBuilder: (context, index) {
                          final msg = displayedMessages[index];
                          final isUser = msg.sender == 'user';
                          
                          return _buildMessageTile(msg, isUser);
                        },
                      ),
              ),

              if (chatState.isStreaming)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.electricCyan),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "MAX is thinking...",
                        style: TextStyle(fontSize: 12, color: AppColors.glassBorder.withOpacity(0.6)),
                      ),
                    ],
                  ),
                ),

              if (chatState.error.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: Text(
                    chatState.error,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ),

              // Chat Input HUD
              _buildInputHUD(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageTile(ChatMessage msg, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        padding: const EdgeInsets.all(16),
        decoration: isUser
            ? BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.electricCyan, Color(0xFF00B0FF)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.electricCyan.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ],
              )
            : AppTheme.glassBox(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header for assistant containing reasoning steps
            if (!isUser && msg.reasoning.isNotEmpty) ...[
              _buildReasoningBlock(msg.reasoning),
              const SizedBox(height: 12),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 12),
            ],
            
            // Text Message Content (Markdown renderer)
            MarkdownBody(
              data: msg.content.isEmpty && !isUser ? "Thinking..." : msg.content,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(color: isUser ? Colors.white : AppColors.textPrimary, fontSize: 15),
                code: TextStyle(
                  backgroundColor: isUser ? Colors.black26 : Colors.black45,
                  color: AppColors.electricCyan,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
                codeblockPadding: const EdgeInsets.all(12),
                codeblockDecoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // Timestamp and Pin button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}",
                  style: TextStyle(
                    fontSize: 10,
                    color: isUser ? Colors.white70 : AppColors.textSecondary,
                  ),
                ),
                if (!isUser)
                  GestureDetector(
                    onTap: () => ref.read(chatProvider.notifier).togglePin(msg.id),
                    child: Icon(
                      msg.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      size: 14,
                      color: msg.isPinned ? AppColors.electricCyan : AppColors.textSecondary,
                    ),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildReasoningBlock(String reasoning) {
    return ExpansionTile(
      title: Row(
        children: [
          const Icon(Icons.psychology_outlined, size: 18, color: AppColors.electricCyan),
          const SizedBox(width: 8),
          Text(
            "Thinking Process",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.electricCyan.withOpacity(0.8),
            ),
          ),
        ],
      ),
      iconColor: AppColors.electricCyan,
      collapsedIconColor: AppColors.textSecondary,
      childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      tilePadding: EdgeInsets.zero,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            reasoning,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
              fontFamily: 'monospace',
            ),
          ),
        )
      ],
    );
  }

  Widget _buildInputHUD() {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24, top: 8),
      decoration: BoxDecoration(
        color: AppColors.spaceBlack,
        border: Border(top: BorderSide(color: AppColors.glassBorder)),
      ),
      child: Row(
        children: [
          // Voice Assistant Page Trigger
          IconButton(
            icon: const Icon(Icons.mic_none_outlined, color: AppColors.electricCyan),
            onPressed: () {
              context.push(AppRoutes.voice);
            },
          ),
          
          // Chat input field
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: "Ask MAX anything...",
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              maxLines: null,
              style: const TextStyle(color: AppColors.textPrimary),
              onSubmitted: (_) => _handleSendMessage(),
            ),
          ),
          const SizedBox(width: 12),
          
          // Send Button
          Container(
            decoration: const BoxDecoration(
              color: AppColors.electricCyan,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.black),
              onPressed: _handleSendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
