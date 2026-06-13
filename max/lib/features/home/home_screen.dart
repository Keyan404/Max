import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routing/app_router.dart';
import '../../core/security/security_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const platform = MethodChannel('com.example.max/control');

  String _rootStatus = "Checking...";
  String _emulatorStatus = "Checking...";
  String _selectedModel = "llama-3.3-70b-versatile";
  bool _bubbleActive = false;

  @override
  void initState() {
    super.initState();
    _performSecurityCheck();
  }

  Future<void> _performSecurityCheck() async {
    final status = await SecurityManager().performSecurityScan();
    if (mounted) {
      setState(() {
        _rootStatus = status.rootStatusLabel;
        _emulatorStatus = status.emulatorStatusLabel;
      });
    }
  }

  Future<void> _toggleFloatingBubble(bool enable) async {
    try {
      await platform.invokeMethod('toggleBubble', {'state': enable});
      setState(() {
        _bubbleActive = enable;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Matrix look
          Positioned.fill(
            child: Container(
              color: AppColors.spaceBlack,
            ),
          ),
          Positioned(
            top: -150,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.electricCyan.withValues(alpha: 0.06),
                    blurRadius: 120,
                    spreadRadius: 60,
                  ),
                ],
              ),
            ),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  
                  // Top Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "SYSTEM CORE",
                            style: TextStyle(
                              color: AppColors.electricCyan,
                              fontSize: 11,
                              letterSpacing: 2.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "MAX OS",
                            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      // Glowing Active Indicator
                      Container(
                        width: 48,
                        height: 48,
                        decoration: AppTheme.glassBox(borderRadius: 24),
                        child: const Icon(Icons.blur_on, color: AppColors.electricCyan, size: 24),
                      )
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Core Actions Grid
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        // Glassmorphic Quick Launcher Rows
                        Row(
                          children: [
                            Expanded(
                              child: _buildLauncherCard(
                                icon: Icons.chat_bubble_outline_rounded,
                                title: "Chat Console",
                                desc: "Fast text & code reasoning",
                                color: AppColors.electricCyan,
                                onTap: () => context.push(AppRoutes.chat),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildLauncherCard(
                                icon: Icons.mic_none_rounded,
                                title: "Voice HUD",
                                desc: "Hands-free continuous talk",
                                color: AppColors.neonPurple,
                                onTap: () => context.push(AppRoutes.voice),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Vision + Settings row
                        Row(
                          children: [
                            Expanded(
                              child: _buildLauncherCard(
                                icon: Icons.screenshot_monitor_rounded,
                                title: "Vision HUD",
                                desc: "Screen capture & analysis",
                                color: AppColors.glowingGreen,
                                onTap: () => context.push(AppRoutes.vision),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildLauncherCard(
                                icon: Icons.settings_outlined,
                                title: "Settings",
                                desc: "Models, voice & security",
                                color: Colors.orangeAccent,
                                onTap: () => context.push(AppRoutes.settings),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Floating Assistant Controller Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: AppTheme.glassBox(),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Floating Assistant Bubble",
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "Draw Chat Head overlay on screen",
                                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                              Switch(
                                value: _bubbleActive,
                                activeColor: AppColors.electricCyan,
                                inactiveTrackColor: Colors.black45,
                                onChanged: (val) => _toggleFloatingBubble(val),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Model Selector HUD
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: AppTheme.glassBox(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Orchestration AI Models",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 12),
                              _buildModelSelectorTile("llama-3.3-70b-versatile", "Llama 3.3 70B (Primary Chat)"),
                              _buildModelSelectorTile("deepseek-r1-distill-llama-70b", "DeepSeek R1 (Advanced Reasoning)"),
                              _buildModelSelectorTile("qwen-2.5-coder-32b", "Qwen Coder (IDE & Repository)"),
                              _buildModelSelectorTile("llama-3.2-11b-vision-preview", "Llama 11B Vision (Screen Capture)"),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Security Center Status
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: AppTheme.glassBox(
                            borderCol: _rootStatus.contains("WARNING") ? Colors.redAccent.withOpacity(0.3) : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.shield_outlined, color: AppColors.electricCyan, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    "Hardware Security Verification",
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildSecurityIndicator("Root Status:", _rootStatus),
                              const SizedBox(height: 8),
                              _buildSecurityIndicator("Device Integrity:", _emulatorStatus),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLauncherCard({
    required IconData icon,
    required String title,
    required String desc,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.glassBox(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildModelSelectorTile(String modelId, String title) {
    bool isSelected = _selectedModel == modelId;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedModel = modelId;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.electricCyan.withOpacity(0.08) : Colors.black26,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.electricCyan : Colors.white10,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.electricCyan : AppColors.textPrimary,
              ),
            ),
            if (isSelected)
              const Icon(Icons.radio_button_checked_rounded, color: AppColors.electricCyan, size: 16)
            else
              const Icon(Icons.radio_button_off_rounded, color: AppColors.textSecondary, size: 16)
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityIndicator(String label, String value) {
    bool isAlert = value.contains("WARNING");
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13, 
            fontWeight: FontWeight.bold, 
            color: isAlert ? Colors.redAccent : AppColors.glowingGreen
          )
        ),
      ],
    );
  }
}
