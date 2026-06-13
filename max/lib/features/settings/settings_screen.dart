import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import 'settings_provider.dart';

// ─────────────────────────────────────────────────────────────────────
// Settings Screen
// ─────────────────────────────────────────────────────────────────────
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.spaceBlack,
      body: Stack(
        children: [
          // Background glow accents
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.neonPurple.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.electricCyan.withOpacity(0.05),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── App Bar ──────────────────────────────────────────
                _buildAppBar(context),

                // ── Content ───────────────────────────────────────────
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    children: [
                      // AI Model Section
                      _SectionHeader(title: 'AI ENGINE', icon: Icons.auto_awesome_rounded),
                      const SizedBox(height: 12),
                      _ModelSelector(settings: settings, ref: ref),
                      const SizedBox(height: 24),

                      // Voice Settings
                      _SectionHeader(title: 'VOICE', icon: Icons.mic_rounded),
                      const SizedBox(height: 12),
                      _SettingsTile(
                        icon: Icons.record_voice_over_rounded,
                        label: 'Voice Language',
                        value: settings.voiceLanguage,
                        onTap: () => _showLanguagePicker(context, ref),
                      ),
                      const SizedBox(height: 8),
                      _SettingsTile(
                        icon: Icons.face_rounded,
                        label: 'Voice Profile',
                        value: settings.voiceProfile.toUpperCase(),
                        onTap: () => _showVoiceProfilePicker(context, ref),
                      ),
                      const SizedBox(height: 8),
                      _SliderTile(
                        icon: Icons.speed_rounded,
                        label: 'Speech Rate',
                        value: settings.speechRate,
                        min: 0.25,
                        max: 1.0,
                        onChanged: (v) =>
                            ref.read(settingsProvider.notifier).setSpeechRate(v),
                      ),
                      const SizedBox(height: 8),
                      _SliderTile(
                        icon: Icons.tune_rounded,
                        label: 'Voice Pitch',
                        value: settings.voicePitch,
                        min: 0.5,
                        max: 2.0,
                        onChanged: (v) =>
                            ref.read(settingsProvider.notifier).setVoicePitch(v),
                      ),
                      const SizedBox(height: 24),

                      // Behavior
                      _SectionHeader(title: 'BEHAVIOR', icon: Icons.psychology_rounded),
                      const SizedBox(height: 12),
                      _ToggleTile(
                        icon: Icons.bluetooth_connected_rounded,
                        label: 'Auto-Start on Boot',
                        value: settings.autoStartOnBoot,
                        onChanged: (v) =>
                            ref.read(settingsProvider.notifier).setAutoStartOnBoot(v),
                      ),
                      const SizedBox(height: 8),
                      _ToggleTile(
                        icon: Icons.bubble_chart_rounded,
                        label: 'Floating Bubble',
                        value: settings.floatingBubbleEnabled,
                        onChanged: (v) =>
                            ref.read(settingsProvider.notifier).setFloatingBubble(v),
                      ),
                      const SizedBox(height: 8),
                      _ToggleTile(
                        icon: Icons.memory_rounded,
                        label: 'Persistent Memory (RAG)',
                        value: settings.persistentMemoryEnabled,
                        onChanged: (v) =>
                            ref.read(settingsProvider.notifier).setPersistentMemory(v),
                      ),
                      const SizedBox(height: 8),
                      _ToggleTile(
                        icon: Icons.wifi_off_rounded,
                        label: 'Offline Mode Fallback',
                        value: settings.offlineModeEnabled,
                        onChanged: (v) =>
                            ref.read(settingsProvider.notifier).setOfflineMode(v),
                      ),
                      const SizedBox(height: 24),

                      // Privacy & Security
                      _SectionHeader(title: 'PRIVACY & SECURITY', icon: Icons.security_rounded),
                      const SizedBox(height: 12),
                      _ToggleTile(
                        icon: Icons.fingerprint_rounded,
                        label: 'Biometric Lock',
                        value: settings.biometricLock,
                        onChanged: (v) =>
                            ref.read(settingsProvider.notifier).setBiometricLock(v),
                      ),
                      const SizedBox(height: 8),
                      _ToggleTile(
                        icon: Icons.analytics_outlined,
                        label: 'Send Analytics',
                        value: settings.sendAnalytics,
                        onChanged: (v) =>
                            ref.read(settingsProvider.notifier).setSendAnalytics(v),
                      ),
                      const SizedBox(height: 24),

                      // Backend config
                      _SectionHeader(title: 'BACKEND', icon: Icons.dns_rounded),
                      const SizedBox(height: 12),
                      _SettingsTile(
                        icon: Icons.link_rounded,
                        label: 'API Base URL',
                        value: settings.apiBaseUrl,
                        onTap: () => _showApiUrlDialog(context, ref, settings.apiBaseUrl),
                      ),
                      const SizedBox(height: 24),

                      // About / Dev
                      _SectionHeader(title: 'ABOUT', icon: Icons.info_outline_rounded),
                      const SizedBox(height: 12),
                      _InfoTile(label: 'Version', value: 'MAX v1.0.0 (build 1)'),
                      const SizedBox(height: 8),
                      _InfoTile(label: 'Architecture', value: 'Flutter + FastAPI + Groq'),
                      const SizedBox(height: 8),
                      _SettingsTile(
                        icon: Icons.bug_report_outlined,
                        label: 'Developer Console',
                        value: 'Logs & Traces',
                        onTap: () => context.push('/developer'),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: const Icon(Icons.arrow_back_ios_rounded,
                  color: Colors.white70, size: 18),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'SETTINGS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 3.0,
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, WidgetRef ref) {
    const langs = ['en-US', 'en-GB', 'es-ES', 'fr-FR', 'de-DE', 'hi-IN', 'ja-JP'];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1621),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Select Language',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
          ...langs.map((l) => ListTile(
                title: Text(l,
                    style: const TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  ref.read(settingsProvider.notifier).setVoiceLanguage(l);
                  Navigator.pop(context);
                },
              )),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showVoiceProfilePicker(BuildContext context, WidgetRef ref) {
    const profiles = ['boy', 'girl', 'jarvis'];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1621),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Select Voice Profile',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
          ...profiles.map((p) => ListTile(
                title: Text(p.toUpperCase(),
                    style: const TextStyle(color: AppColors.textPrimary)),
                subtitle: Text(p == 'jarvis' ? 'Calm, low-energy, robotic (Recommended)' : p == 'boy' ? 'Energetic male voice' : 'Sweet female voice',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                onTap: () {
                  ref.read(settingsProvider.notifier).setVoiceProfile(p);
                  Navigator.pop(context);
                },
              )),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showApiUrlDialog(BuildContext context, WidgetRef ref, String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F1621),
        title: const Text('API Base URL',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'http://192.168.x.x:8000',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.glassBorder)),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.electricCyan)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
              onPressed: () {
                ref
                    .read(settingsProvider.notifier)
                    .setApiBaseUrl(ctrl.text.trim());
                Navigator.pop(context);
              },
              child: const Text('Save',
                  style: TextStyle(color: AppColors.electricCyan))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Model Selector Widget
// ─────────────────────────────────────────────────────────────────────
class _ModelSelector extends StatelessWidget {
  final SettingsState settings;
  final WidgetRef ref;

  const _ModelSelector({required this.settings, required this.ref});

  static const List<_ModelInfo> _models = [
    _ModelInfo(
      id: 'llama-3.3-70b-versatile',
      label: 'Llama 3.3 70B',
      badge: 'FAST',
      badgeColor: AppColors.electricCyan,
      description: 'Best for general tasks',
    ),
    _ModelInfo(
      id: 'deepseek-r1-distill-llama-70b',
      label: 'DeepSeek R1',
      badge: 'REASONING',
      badgeColor: AppColors.neonPurple,
      description: 'Step-by-step reasoning (chain of thought)',
    ),
    _ModelInfo(
      id: 'qwen-qwq-32b',
      label: 'Qwen QwQ 32B',
      badge: 'BALANCED',
      badgeColor: AppColors.glowingGreen,
      description: 'Balanced performance & quality',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _models
          .map((m) => _buildModelCard(m))
          .toList(),
    );
  }

  Widget _buildModelCard(_ModelInfo model) {
    final bool selected = settings.selectedModel == model.id;
    return GestureDetector(
      onTap: () => ref.read(settingsProvider.notifier).setModel(model.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected
              ? model.badgeColor.withOpacity(0.08)
              : Colors.white.withOpacity(0.03),
          border: Border.all(
            color: selected ? model.badgeColor : AppColors.glassBorder,
            width: selected ? 1.5 : 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: model.badgeColor.withOpacity(0.12),
                    blurRadius: 16,
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            // Selection indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? model.badgeColor : AppColors.glassBorder,
                  width: 2,
                ),
                color: selected ? model.badgeColor : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check, size: 12, color: Colors.black)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        model.label,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: model.badgeColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: model.badgeColor.withOpacity(0.4)),
                        ),
                        child: Text(
                          model.badge,
                          style: TextStyle(
                            color: model.badgeColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    model.description,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelInfo {
  final String id;
  final String label;
  final String badge;
  final Color badgeColor;
  final String description;

  const _ModelInfo({
    required this.id,
    required this.label,
    required this.badge,
    required this.badgeColor,
    required this.description,
  });
}

// ─────────────────────────────────────────────────────────────────────
// Reusable tile components
// ─────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.electricCyan),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.electricCyan,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Divider(
                color: AppColors.glassBorder.withOpacity(0.5), height: 1)),
      ],
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withOpacity(0.03),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.electricCyan,
            inactiveTrackColor: Colors.white12,
          ),
        ],
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withOpacity(0.03),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 14),
                ),
              ),
              Text(
                value.toStringAsFixed(2),
                style: const TextStyle(
                    color: AppColors.electricCyan, fontSize: 12),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.electricCyan,
              inactiveTrackColor: Colors.white12,
              thumbColor: AppColors.electricCyan,
              overlayColor: AppColors.electricCyan.withOpacity(0.15),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              trackHeight: 2,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withOpacity(0.03),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 14),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withOpacity(0.02),
        border: Border.all(color: AppColors.glassBorder.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 13)),
        ],
      ),
    );
  }
}
