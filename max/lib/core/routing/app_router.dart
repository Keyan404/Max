import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/chat_screen.dart';
import '../../features/developer/developer_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/permissions/permissions_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/vision/vision_screen.dart';
import '../../features/voice/voice_screen.dart';

// ─────────────────────────────────────────────────────────────────────
// Route constants — single source of truth for all navigation paths
// ─────────────────────────────────────────────────────────────────────
class AppRoutes {
  static const String splash = '/';
  static const String permissions = '/permissions';
  static const String home = '/home';
  static const String chat = '/chat';
  static const String voice = '/voice';
  static const String vision = '/vision';
  static const String settings = '/settings';
  static const String developer = '/developer';
}

// ─────────────────────────────────────────────────────────────────────
// GoRouter — full navigation graph for MAX AI
// ─────────────────────────────────────────────────────────────────────
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.permissions,
  debugLogDiagnostics: false,
  routes: [
    // ── Permissions Gate (first-run onboarding) ──────────────
    GoRoute(
      path: AppRoutes.permissions,
      pageBuilder: (context, state) => _slide(const PermissionsScreen()),
    ),

    // ── Home Cockpit ─────────────────────────────────────────
    GoRoute(
      path: AppRoutes.home,
      pageBuilder: (context, state) => _slide(const HomeScreen()),
    ),

    // ── Chat (text mode) ─────────────────────────────────────
    GoRoute(
      path: AppRoutes.chat,
      pageBuilder: (context, state) => _slide(const ChatScreen()),
    ),

    // ── Voice Mode (full-screen Jarvis UI) ───────────────────
    GoRoute(
      path: AppRoutes.voice,
      pageBuilder: (context, state) => CustomTransitionPage(
        child: const VoiceScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    ),

    // ── Vision HUD ───────────────────────────────────────────
    GoRoute(
      path: AppRoutes.vision,
      pageBuilder: (context, state) => _slide(const VisionScreen()),
    ),

    // ── Settings ─────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.settings,
      pageBuilder: (context, state) => _slide(const SettingsScreen()),
    ),

    // ── Developer Console ────────────────────────────────────
    GoRoute(
      path: AppRoutes.developer,
      pageBuilder: (context, state) => _slide(const DeveloperScreen()),
    ),
  ],
);

// Helper: slide-up transition
CustomTransitionPage<void> _slide(Widget child) {
  return CustomTransitionPage(
    child: child,
    transitionsBuilder: (_, animation, __, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
    transitionDuration: const Duration(milliseconds: 280),
  );
}
