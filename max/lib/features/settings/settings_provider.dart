import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ─────────────────────────────────────────────────────────────────────
// Settings State
// ─────────────────────────────────────────────────────────────────────
class SettingsState {
  final String selectedModel;
  final String voiceLanguage;
  final String voiceProfile;
  final double speechRate;
  final double voicePitch;
  final bool autoStartOnBoot;
  final bool floatingBubbleEnabled;
  final bool persistentMemoryEnabled;
  final bool offlineModeEnabled;
  final bool biometricLock;
  final bool sendAnalytics;
  final String apiBaseUrl;

  const SettingsState({
    this.selectedModel = 'llama-3.3-70b-versatile',
    this.voiceLanguage = 'en-US',
    this.voiceProfile = 'jarvis',
    this.speechRate = 0.48,
    this.voicePitch = 1.05,
    this.autoStartOnBoot = true,
    this.floatingBubbleEnabled = true,
    this.persistentMemoryEnabled = true,
    this.offlineModeEnabled = true,
    this.biometricLock = false,
    this.sendAnalytics = false,
    this.apiBaseUrl = 'https://max-av08.onrender.com',
  });

  SettingsState copyWith({
    String? selectedModel,
    String? voiceLanguage,
    String? voiceProfile,
    double? speechRate,
    double? voicePitch,
    bool? autoStartOnBoot,
    bool? floatingBubbleEnabled,
    bool? persistentMemoryEnabled,
    bool? offlineModeEnabled,
    bool? biometricLock,
    bool? sendAnalytics,
    String? apiBaseUrl,
  }) {
    return SettingsState(
      selectedModel: selectedModel ?? this.selectedModel,
      voiceLanguage: voiceLanguage ?? this.voiceLanguage,
      voiceProfile: voiceProfile ?? this.voiceProfile,
      speechRate: speechRate ?? this.speechRate,
      voicePitch: voicePitch ?? this.voicePitch,
      autoStartOnBoot: autoStartOnBoot ?? this.autoStartOnBoot,
      floatingBubbleEnabled: floatingBubbleEnabled ?? this.floatingBubbleEnabled,
      persistentMemoryEnabled:
          persistentMemoryEnabled ?? this.persistentMemoryEnabled,
      offlineModeEnabled: offlineModeEnabled ?? this.offlineModeEnabled,
      biometricLock: biometricLock ?? this.biometricLock,
      sendAnalytics: sendAnalytics ?? this.sendAnalytics,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Settings Notifier — reads/writes to secure storage for persistence
// ─────────────────────────────────────────────────────────────────────
class SettingsNotifier extends StateNotifier<SettingsState> {
  static const _storage = FlutterSecureStorage();

  // Storage keys
  static const _kModel = 'settings_model';
  static const _kVoiceLang = 'settings_voice_lang';
  static const _kVoiceProfile = 'settings_voice_profile';
  static const _kSpeechRate = 'settings_speech_rate';
  static const _kPitch = 'settings_voice_pitch';
  static const _kAutoStart = 'settings_auto_start';
  static const _kBubble = 'settings_bubble';
  static const _kMemory = 'settings_memory';
  static const _kOffline = 'settings_offline';
  static const _kBiometric = 'settings_biometric';
  static const _kAnalytics = 'settings_analytics';
  static const _kApiUrl = 'settings_api_url';

  SettingsNotifier() : super(const SettingsState()) {
    _load();
  }

  // ─── Load all settings from secure storage ───────────────
  Future<void> _load() async {
    final model = await _storage.read(key: _kModel) ?? 'llama-3.3-70b-versatile';
    final voiceLang = await _storage.read(key: _kVoiceLang) ?? 'en-US';
    final voiceProfile = await _storage.read(key: _kVoiceProfile) ?? 'jarvis';
    final speechRate = double.tryParse(await _storage.read(key: _kSpeechRate) ?? '') ?? 0.48;
    final pitch = double.tryParse(await _storage.read(key: _kPitch) ?? '') ?? 1.05;
    final autoStart = (await _storage.read(key: _kAutoStart)) != 'false';
    final bubble = (await _storage.read(key: _kBubble)) != 'false';
    final memory = (await _storage.read(key: _kMemory)) != 'false';
    final offline = (await _storage.read(key: _kOffline)) != 'false';
    final biometric = (await _storage.read(key: _kBiometric)) == 'true';
    final analytics = (await _storage.read(key: _kAnalytics)) == 'true';
    final apiUrl = await _storage.read(key: _kApiUrl) ?? 'https://max-av08.onrender.com';

    state = SettingsState(
      selectedModel: model,
      voiceLanguage: voiceLang,
      voiceProfile: voiceProfile,
      speechRate: speechRate,
      voicePitch: pitch,
      autoStartOnBoot: autoStart,
      floatingBubbleEnabled: bubble,
      persistentMemoryEnabled: memory,
      offlineModeEnabled: offline,
      biometricLock: biometric,
      sendAnalytics: analytics,
      apiBaseUrl: apiUrl,
    );
  }

  // ─── Setters ──────────────────────────────────────────────

  Future<void> setModel(String model) async {
    state = state.copyWith(selectedModel: model);
    await _storage.write(key: _kModel, value: model);
  }

  Future<void> setVoiceLanguage(String lang) async {
    state = state.copyWith(voiceLanguage: lang);
    await _storage.write(key: _kVoiceLang, value: lang);
  }

  Future<void> setVoiceProfile(String profile) async {
    double targetPitch = state.voicePitch;
    double targetRate = state.speechRate;
    if (profile == 'boy') {
      targetPitch = 0.90;
      targetRate = 0.48;
    } else if (profile == 'girl') {
      targetPitch = 1.25;
      targetRate = 0.50;
    } else if (profile == 'jarvis') {
      targetPitch = 0.82;
      targetRate = 0.45;
    }
    
    state = state.copyWith(
      voiceProfile: profile,
      voicePitch: targetPitch,
      speechRate: targetRate,
    );
    await _storage.write(key: _kVoiceProfile, value: profile);
    await _storage.write(key: _kPitch, value: targetPitch.toString());
    await _storage.write(key: _kSpeechRate, value: targetRate.toString());
  }

  Future<void> setSpeechRate(double rate) async {
    state = state.copyWith(speechRate: rate);
    await _storage.write(key: _kSpeechRate, value: rate.toString());
  }

  Future<void> setVoicePitch(double pitch) async {
    state = state.copyWith(voicePitch: pitch);
    await _storage.write(key: _kPitch, value: pitch.toString());
  }

  Future<void> setAutoStartOnBoot(bool v) async {
    state = state.copyWith(autoStartOnBoot: v);
    await _storage.write(key: _kAutoStart, value: v.toString());
  }

  Future<void> setFloatingBubble(bool v) async {
    state = state.copyWith(floatingBubbleEnabled: v);
    await _storage.write(key: _kBubble, value: v.toString());
  }

  Future<void> setPersistentMemory(bool v) async {
    state = state.copyWith(persistentMemoryEnabled: v);
    await _storage.write(key: _kMemory, value: v.toString());
  }

  Future<void> setOfflineMode(bool v) async {
    state = state.copyWith(offlineModeEnabled: v);
    await _storage.write(key: _kOffline, value: v.toString());
  }

  Future<void> setBiometricLock(bool v) async {
    state = state.copyWith(biometricLock: v);
    await _storage.write(key: _kBiometric, value: v.toString());
  }

  Future<void> setSendAnalytics(bool v) async {
    state = state.copyWith(sendAnalytics: v);
    await _storage.write(key: _kAnalytics, value: v.toString());
  }

  Future<void> setApiBaseUrl(String url) async {
    state = state.copyWith(apiBaseUrl: url);
    await _storage.write(key: _kApiUrl, value: url);
  }
}

// Provider
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
