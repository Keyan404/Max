import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';

class ChatMessage {
  final String id;
  final String sender; // "user" | "assistant"
  final String content;
  final String reasoning; // Thoughts/Thinking process (DeepSeek R1)
  final DateTime timestamp;
  final bool isPinned;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.content,
    this.reasoning = '',
    required this.timestamp,
    this.isPinned = false,
  });

  ChatMessage copyWith({
    String? content,
    String? reasoning,
    bool? isPinned,
  }) {
    return ChatMessage(
      id: id,
      sender: sender,
      content: content ?? this.content,
      reasoning: reasoning ?? this.reasoning,
      timestamp: timestamp,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}

class ChatState {
  final List<ChatMessage> messages;
  final bool isStreaming;
  final String activeModel;
  final String error;

  ChatState({
    this.messages = const [],
    this.isStreaming = false,
    this.activeModel = 'llama-3.3-70b-versatile',
    this.error = '',
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isStreaming,
    String? activeModel,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      activeModel: activeModel ?? this.activeModel,
      error: error ?? this.error,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final ApiClient _apiClient = ApiClient();

  ChatNotifier() : super(ChatState());

  /// Appends a manual local message (useful for offline command logs)
  void appendSystemLog(String text) {
    final msg = ChatMessage(
      id: DateTime.now().toIso8601String(),
      sender: 'assistant',
      content: text,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(messages: [...state.messages, msg]);
  }

  /// Pins/Unpins a message
  void togglePin(String messageId) {
    state = state.copyWith(
      messages: state.messages.map((m) {
        if (m.id == messageId) {
          return m.copyWith(isPinned: !m.isPinned);
        }
        return m;
      }).toList(),
    );
  }

  /// Sends a prompt to the backend and streams the result in real-time
  Future<void> sendPrompt(String prompt, {bool useRag = true, String? modelOverride}) async {
    if (prompt.trim().isEmpty) return;

    final userMsgId = DateTime.now().toIso8601String();
    final userMsg = ChatMessage(
      id: userMsgId,
      sender: 'user',
      content: prompt,
      timestamp: DateTime.now(),
    );

    final assistantMsgId = '${userMsgId}_response';
    final assistantMsg = ChatMessage(
      id: assistantMsgId,
      sender: 'assistant',
      content: '',
      reasoning: '',
      timestamp: DateTime.now(),
    );

    // 1. Update UI with user message and streaming indicator
    state = state.copyWith(
      messages: [...state.messages, userMsg, assistantMsg],
      isStreaming: true,
      error: '',
    );

    final history = state.messages
        .take(state.messages.length - 2) // exclude current turn
        .map((m) => {"role": m.sender, "content": m.content})
        .toList();

    // 2. Open Stream Connection
    String accumulatedContent = '';
    String accumulatedReasoning = '';
    String modelUsed = state.activeModel;

    await for (final chunk in _apiClient.streamChat(
      userId: 'default_user',
      prompt: prompt,
      history: history,
      useRag: useRag,
      modelOverride: modelOverride,
    )) {
      if (chunk.containsKey('error')) {
        state = state.copyWith(
          error: chunk['error'],
          isStreaming: false,
        );
        return;
      }

      final String contentDelta = chunk['content'] ?? '';
      final String reasoningDelta = chunk['reasoning'] ?? '';
      final String? model = chunk['model'];
      
      if (model != null) {
        modelUsed = model;
      }

      accumulatedContent += contentDelta;
      accumulatedReasoning += reasoningDelta;

      // 3. Update the last message text chunk-by-chunk
      state = state.copyWith(
        activeModel: modelUsed,
        messages: state.messages.map((m) {
          if (m.id == assistantMsgId) {
            return m.copyWith(
              content: accumulatedContent,
              reasoning: accumulatedReasoning,
            );
          }
          return m;
        }).toList(),
      );
    }

    // 4. Conclude streaming state
    state = state.copyWith(isStreaming: false);

    // Parse and execute system actions
    final regExp = RegExp(r'ACTION:(\w+)\(([^)]*)\)');
    final matches = regExp.allMatches(accumulatedContent);
    for (final match in matches) {
      final action = match.group(1);
      final param = match.group(2)?.trim();
      
      try {
        const platform = MethodChannel('com.example.max/control');
        if (action == 'launchApp') {
          await platform.invokeMethod('launchApp', {'packageName': param});
        } else if (action == 'toggleFlashlight') {
          await platform.invokeMethod('toggleFlashlight', {'state': param == 'true'});
        } else if (action == 'controlVolume') {
          await platform.invokeMethod('controlVolume', {'direction': param});
        } else if (action == 'openAccessibilitySettings') {
          await platform.invokeMethod('openAccessibilitySettings');
        } else if (action == 'scheduleAutomation') {
          await platform.invokeMethod('scheduleAutomation', {'text': param});
        } else if (action == 'callPhone') {
          await platform.invokeMethod('callPhone', {'phoneNumber': param});
        } else if (action == 'lockPhone') {
          await platform.invokeMethod('lockPhone');
        }
      } catch (e) {
        // Handled silently
      }
    }
  }

  /// Clears the current chat history
  void clearChat() {
    state = ChatState();
  }
}

// Global Riverpod Provider binding
final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});
