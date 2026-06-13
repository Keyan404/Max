import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../chat/chat_provider.dart';

class VisionState {
  final bool isCapturing;
  final String analysisResult;
  final String capturedImageBase64;
  final String error;

  const VisionState({
    this.isCapturing = false,
    this.analysisResult = '',
    this.capturedImageBase64 = '',
    this.error = '',
  });

  VisionState copyWith({
    bool? isCapturing,
    String? analysisResult,
    String? capturedImageBase64,
    String? error,
  }) {
    return VisionState(
      isCapturing: isCapturing ?? this.isCapturing,
      analysisResult: analysisResult ?? this.analysisResult,
      capturedImageBase64: capturedImageBase64 ?? this.capturedImageBase64,
      error: error ?? this.error,
    );
  }
}

class VisionNotifier extends StateNotifier<VisionState> {
  final ApiClient _apiClient = ApiClient();
  static const _screenPlatform = MethodChannel('com.example.max/screen');

  VisionNotifier() : super(const VisionState());

  /// Triggers Android MediaProjection screen capture and sends to vision backend
  Future<void> analyzeCurrentScreen(WidgetRef ref, String queryPrompt) async {
    state = state.copyWith(isCapturing: true, error: '', analysisResult: '');

    try {
      // 1. Request MediaProjection permission
      final bool hasPermission =
          await _screenPlatform.invokeMethod('requestScreenCapturePermission') ?? false;
      if (!hasPermission) {
        state = state.copyWith(
          isCapturing: false,
          error: 'Screen capture permission denied.',
        );
        return;
      }

      // 2. Capture screen as base64-encoded JPEG
      final String? base64Image = await _screenPlatform.invokeMethod('captureScreen');
      if (base64Image == null || base64Image.isEmpty) {
        state = state.copyWith(
          isCapturing: false,
          error: 'Screen capture returned empty data.',
        );
        return;
      }

      // 3. Send to vision endpoint on backend
      final response = await _apiClient.post('/chat/vision', {
        'image_base64': base64Image,
        'prompt': queryPrompt,
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body) as Map<String, dynamic>;
        final String analysis = (data['analysis'] as String?) ?? 'No analysis returned.';

        state = state.copyWith(
          isCapturing: false,
          analysisResult: analysis,
          capturedImageBase64: base64Image,
        );

        // Mirror result to chat history so user can reference it later
        ref.read(chatProvider.notifier).appendSystemLog(
          '**[VISION HUD — SCREEN ANALYSIS]**\n\nQuery: _"$queryPrompt"_\n\n$analysis',
        );
      } else {
        state = state.copyWith(
          isCapturing: false,
          error: 'Vision server error: HTTP ${response.statusCode}',
        );
      }
    } on PlatformException catch (pe) {
      state = state.copyWith(
        isCapturing: false,
        error: 'Native error: ${pe.message}',
      );
    } catch (e) {
      state = state.copyWith(
        isCapturing: false,
        error: 'Exception: $e',
      );
    }
  }

  void clearAnalysis() {
    state = const VisionState();
  }
}

final visionProvider = StateNotifierProvider<VisionNotifier, VisionState>((ref) {
  return VisionNotifier();
});
