import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routing/app_router.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> with WidgetsBindingObserver {
  static const platform = MethodChannel('com.example.max/control');

  // Local statuses
  bool _micGranted = false;
  bool _smsGranted = false;
  bool _contactsGranted = false;
  bool _overlayGranted = false;
  bool _accessibilityGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final mic = await Permission.microphone.isGranted;
    final sms = await Permission.sms.isGranted;
    final contacts = await Permission.contacts.isGranted;
    final phone = await Permission.phone.isGranted;
    
    // Check overlay status using native plugin
    bool overlay = false;
    try {
      overlay = await Permission.systemAlertWindow.isGranted;
    } catch (_) {}

    // Check accessibility status using our native plugin
    bool accessibility = false;
    try {
      accessibility = await platform.invokeMethod('isAccessibilityEnabled') as bool? ?? false;
    } catch (_) {}

    if (mounted) {
      setState(() {
        _micGranted = mic;
        _smsGranted = sms;
        _contactsGranted = contacts && phone;
        _overlayGranted = overlay;
        _accessibilityGranted = accessibility;
      });
    }
  }

  Future<void> _requestStandard(Permission permission, Function(bool) update) async {
    final status = await permission.request();
    update(status.isGranted);
    _checkPermissions();
  }

  Future<void> _requestContactsAndPhone() async {
    await Permission.contacts.request();
    await Permission.phone.request();
    _checkPermissions();
  }

  Future<void> _requestOverlay() async {
    // Open system overlay settings
    await Permission.systemAlertWindow.request();
    _checkPermissions();
  }

  Future<void> _requestAccessibility() async {
    // Open accessibility settings directly
    try {
      await platform.invokeMethod('openAccessibilitySettings');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable "MAX Operating System Assistant" in Accessibility Services.'),
            duration: Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      // fallback
      try {
        await platform.invokeMethod('launchApp', {'packageName': 'com.android.settings'});
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.spaceBlack, Color(0xFF0F172E)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
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
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: AppColors.electricCyan,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.electricCyan,
                              blurRadius: 8,
                            )
                          ]
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "MAX OS ASSISTANT",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.electricCyan,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "System Permissions",
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "MAX requires the following system access to function as your local companion operating system.",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  
                  // Scrollable Permission list
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildPermissionCard(
                          title: "Continuous Microphone Access",
                          whyNeeded: "To monitor wake words ('Hey Max') in the background.",
                          benefit: "Allows natural, hands-free voice-activation commands.",
                          privacy: "Audio calculations are computed on-device. No background voice leaks online.",
                          isGranted: _micGranted,
                          onPressed: () => _requestStandard(Permission.microphone, (val) => _micGranted = val),
                        ),
                        _buildPermissionCard(
                          title: "Accessibility Service (Automation)",
                          whyNeeded: "Required to parse messaging screens and simulate touch keyboard events.",
                          benefit: "Enables voice messaging automation (WhatsApp, Telegram, SMS).",
                          privacy: "Only intercepts target communication layouts. Keystroke scrapers are blocked.",
                          isGranted: _accessibilityGranted,
                          onPressed: _requestAccessibility,
                        ),
                        _buildPermissionCard(
                          title: "Draw Over Other Apps (Overlay)",
                          whyNeeded: "Needed to present the floating assistant bubble HUD.",
                          benefit: "Instant chat access from any application or home screen.",
                          privacy: "The bubble remains inactive unless touched, preserving memory.",
                          isGranted: _overlayGranted,
                          onPressed: _requestOverlay,
                        ),
                        _buildPermissionCard(
                          title: "SMS Management",
                          whyNeeded: "Used to read text notifications and automate response drafts.",
                          benefit: "Dictate messages: 'Send SMS to John stating I will be 10 min late'.",
                          privacy: "SMS logs are never uploaded. Access is strictly sandboxed.",
                          isGranted: _smsGranted,
                          onPressed: () => _requestStandard(Permission.sms, (val) => _smsGranted = val),
                        ),
                        _buildPermissionCard(
                          title: "Contacts & Dialer",
                          whyNeeded: "To query names, retrieve phone numbers, and execute phone calls.",
                          benefit: "Supports vocal dialing: 'Hey Max, call Mom on speaker'.",
                          privacy: "Contacts list cached locally in native SQL memory.",
                          isGranted: _contactsGranted,
                          onPressed: _requestContactsAndPhone,
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Action Button pinned at bottom
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [AppColors.electricCyan, AppColors.neonPurple],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.electricCyan.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ]
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  // Direct to main workspace Home
                  context.go(AppRoutes.home);
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Launch MAX OS Dashboard",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, color: Colors.white),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPermissionCard({
    required String title,
    required String whyNeeded,
    required String benefit,
    required String privacy,
    required bool isGranted,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isGranted 
                    ? AppColors.glowingGreen.withOpacity(0.1) 
                    : Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isGranted ? AppColors.glowingGreen : Colors.redAccent,
                    width: 1,
                  ),
                ),
                child: Text(
                  isGranted ? "ACTIVE" : "DISABLED",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isGranted ? AppColors.glowingGreen : Colors.redAccent,
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Why Needed: $whyNeeded",
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            "Benefit: $benefit",
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined, size: 14, color: AppColors.electricCyan),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  "Privacy: $privacy",
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!isGranted)
            SizedBox(
              width: double.infinity,
              height: 38,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.electricCyan, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: onPressed,
                child: const Text(
                  "Grant Access",
                  style: TextStyle(
                    color: AppColors.electricCyan,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
