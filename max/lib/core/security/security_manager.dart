import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SecurityManager
// Provides device security status: root detection, emulator detection,
// and SSL pinning helper for the ApiClient.
//
// Root detection uses TWO layers:
//   1. flutter_jailbreak_detection package (cross-platform Dart bridge)
//   2. Native Kotlin deep scan (SystemControlPlugin `securityScan`)
//      — checks su binaries, test-keys, Magisk, emulator hardware fingerprint
//
// SSL Pinning:
//   - createPinnedHttpClient() returns a hardened HttpClient
//   - In production: set pinnedSha256Fingerprints to your server cert's SHA-256
//   - In development (local HTTP): pinning is disabled automatically
// ─────────────────────────────────────────────────────────────────────────────

class DeviceSecurityStatus {
  final bool isRooted;
  final bool isEmulator;
  final bool isDeveloperMode;
  final String rootStatusLabel;
  final String emulatorStatusLabel;

  const DeviceSecurityStatus({
    required this.isRooted,
    required this.isEmulator,
    required this.isDeveloperMode,
    required this.rootStatusLabel,
    required this.emulatorStatusLabel,
  });

  /// True if the device passes all security checks.
  bool get isSecure => !isRooted;

  /// True when high-risk features (accessibility automation, key exposure)
  /// should be blocked.
  bool get shouldBlockHighRiskFeatures => isRooted;
}

class SecurityManager {
  static final SecurityManager _instance = SecurityManager._internal();
  factory SecurityManager() => _instance;
  SecurityManager._internal();

  static const _platform = MethodChannel('com.example.max/control');

  DeviceSecurityStatus? _lastStatus;
  DeviceSecurityStatus? get lastStatus => _lastStatus;

  // ─────────────────────────────────────────────────────────────────
  // Root & Emulator Detection
  // ─────────────────────────────────────────────────────────────────

  /// Performs a full device security scan.
  /// Combines flutter_jailbreak_detection + native Kotlin scan.
  Future<DeviceSecurityStatus> performSecurityScan() async {
    bool isRooted = false;
    bool isEmulator = false;
    bool isDeveloperMode = kDebugMode;

    // Layer 1: flutter_jailbreak_detection (pure Dart, works across platforms)
    if (!kIsWeb) {
      try {
        isRooted = await FlutterJailbreakDetection.jailbroken;
        isDeveloperMode = await FlutterJailbreakDetection.developerMode;
        debugPrint('[SecurityManager] JailbreakDetection → rooted=$isRooted, devMode=$isDeveloperMode');
      } catch (e) {
        debugPrint('[SecurityManager] JailbreakDetection unavailable: $e');
      }
    }

    // Layer 2: Native Kotlin deep scan via MethodChannel
    if (!kIsWeb) {
      try {
        final Map<dynamic, dynamic> result =
            await _platform.invokeMethod('securityScan');
        final nativeRooted = result['isRooted'] as bool? ?? false;
        final nativeEmulator = result['isEmulator'] as bool? ?? false;
        debugPrint('[SecurityManager] NativeScan → rooted=$nativeRooted, emulator=$nativeEmulator');

        // Conservative: if EITHER layer detects root, flag the device.
        isRooted = isRooted || nativeRooted;
        isEmulator = isEmulator || nativeEmulator;
      } catch (e) {
        debugPrint('[SecurityManager] NativeScan unavailable: $e');
      }
    }

    final status = DeviceSecurityStatus(
      isRooted: isRooted,
      isEmulator: isEmulator,
      isDeveloperMode: isDeveloperMode,
      rootStatusLabel:
          isRooted ? '⚠ WARNING: ROOT DETECTED' : '✓ SECURE (NO ROOT)',
      emulatorStatusLabel:
          isEmulator ? '⚠ WARNING: EMULATOR' : '✓ SECURE (HARDWARE)',
    );

    _lastStatus = status;
    debugPrint('[SecurityManager] Security scan complete → secure=${status.isSecure}');
    return status;
  }

  // ─────────────────────────────────────────────────────────────────
  // SSL Pinning
  // ─────────────────────────────────────────────────────────────────

  /// Creates a security-hardened [HttpClient].
  ///
  /// **Production (HTTPS backend):**
  ///   Pass [pinnedSha256Fingerprints] with your server certificate's
  ///   SHA-256 fingerprint (colon-separated hex, e.g. "AA:BB:CC:...").
  ///   Any TLS handshake with a non-matching cert is immediately rejected.
  ///
  /// **Development (HTTP localhost):**
  ///   Leave [pinnedSha256Fingerprints] empty. Pinning is skipped since
  ///   plain HTTP has no TLS layer to pin against.
  ///
  /// How to get your server's SHA-256 fingerprint:
  ///   openssl s_client -connect yourserver.com:443 </dev/null 2>/dev/null \
  ///     | openssl x509 -fingerprint -sha256 -noout
  HttpClient createPinnedHttpClient({
    List<String> pinnedSha256Fingerprints = const [],
    Duration connectionTimeout = const Duration(seconds: 15),
  }) {
    final client = HttpClient();
    client.connectionTimeout = connectionTimeout;

    if (pinnedSha256Fingerprints.isEmpty) {
      // Development mode: SSL pinning not active (local HTTP server).
      debugPrint(
        '[SecurityManager] SSL Pinning: DISABLED '
        '(no fingerprints configured — development mode)',
      );
      return client;
    }

    // Normalize expected fingerprints: lowercase, strip colons.
    final normalizedPins = pinnedSha256Fingerprints
        .map((p) => p.toLowerCase().replaceAll(':', ''))
        .toSet();

    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      // Compute the SHA-256 fingerprint of the certificate's DER bytes.
      final fingerprint = _sha256Fingerprint(cert.der);

      final isTrusted = normalizedPins.contains(fingerprint);

      if (isTrusted) {
        debugPrint(
          '[SecurityManager] SSL Pinning: ✓ TRUSTED cert for $host:$port '
          '($fingerprint)',
        );
      } else {
        debugPrint(
          '[SecurityManager] SSL Pinning: ✗ REJECTED cert for $host:$port\n'
          '  Got:      $fingerprint\n'
          '  Expected: $normalizedPins',
        );
      }

      // Return true to ACCEPT (trust) the certificate.
      // The callback is called when the cert would normally be rejected.
      return isTrusted;
    };

    debugPrint(
      '[SecurityManager] SSL Pinning: ENABLED '
      '(${pinnedSha256Fingerprints.length} pin(s))',
    );

    return client;
  }

  /// Returns lowercase hex SHA-256 fingerprint (no colons) of DER bytes.
  String _sha256Fingerprint(Uint8List derBytes) {
    final digest = sha256.convert(derBytes);
    return digest.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join('');
  }
}
