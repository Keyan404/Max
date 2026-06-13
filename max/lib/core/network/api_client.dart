import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../security/security_manager.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  // Production Live Render URL by default, fallback to local emulator URL if overridden.
  String _baseUrl = "https://max-av08.onrender.com/api";

  // ── Production SSL Certificate Fingerprints ──────────────────────────────
  // Set these to your backend server's SHA-256 TLS certificate fingerprints
  // before deploying to production.
  //
  // Obtain with:
  //   openssl s_client -connect your-backend.com:443 </dev/null 2>/dev/null \
  //     | openssl x509 -fingerprint -sha256 -noout
  //
  // Leave empty for local HTTP development (pinning disabled automatically).
  static const List<String> _pinnedFingerprints = [
    // Example: 'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:...'
    // Add your production server fingerprint here when deploying HTTPS.
  ];

  String get baseUrl => _baseUrl;
  set baseUrl(String url) {
    _baseUrl = url;
  }

  /// Helper to send generic REST POST requests
  Future<http.Response> post(String path, Map<String, dynamic> body) async {
    final url = Uri.parse("$_baseUrl$path");
    final headers = {"Content-Type": "application/json"};
    return await http.post(url, headers: headers, body: jsonEncode(body));
  }

  /// Helper to send generic REST GET requests
  Future<http.Response> get(String path) async {
    final url = Uri.parse("$_baseUrl$path");
    return await http.get(url);
  }

  /// Custom native SSE (Server-Sent Events) streaming parser for chatbot completions.
  /// Uses a SecurityManager-provided HttpClient with optional SSL certificate pinning.
  Stream<Map<String, dynamic>> streamChat({
    required String userId,
    required String prompt,
    required List<Map<String, String>> history,
    bool useRag = true,
    String? modelOverride,
  }) async* {
    // Create a pinned HttpClient — pinning is enforced when _pinnedFingerprints
    // is non-empty, otherwise skipped for local HTTP development.
    final client = SecurityManager().createPinnedHttpClient(
      pinnedSha256Fingerprints: _pinnedFingerprints,
      connectionTimeout: const Duration(seconds: 10),
    );

    try {
      final request = await client.postUrl(Uri.parse("$_baseUrl/chat/stream"));
      
      // Setup headers
      request.headers.set('content-type', 'application/json');
      request.headers.set('accept', 'text/event-stream');

      // Setup payload
      final payload = {
        "user_id": userId,
        "prompt": prompt,
        "history": history,
        "use_rag": useRag,
        "model_override": modelOverride,
      };
      
      request.add(utf8.encode(jsonEncode(payload)));
      final response = await request.close();

      if (response.statusCode != 200) {
        yield {"error": "Server error: ${response.statusCode}"};
        client.close();
        return;
      }

      // Parse stream lines
      await for (final line in response
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line.isEmpty) continue;
        
        if (line.startsWith("data: ")) {
          final dataStr = line.substring(6).trim();
          if (dataStr.isEmpty || dataStr == "[DONE]") continue;

          try {
            final Map<String, dynamic> parsedJson = jsonDecode(dataStr);
            yield parsedJson;
          } catch (e) {
            // Log parse errors silently or send raw
            yield {"raw": dataStr};
          }
        }
      }
    } catch (e) {
      yield {"error": "Network connection error: ${e.toString()}"};
    } finally {
      client.close();
    }
  }

  /// Uploads a file (PDF, DOCX, ZIP repo) to the knowledge base.
  Future<Map<String, dynamic>> uploadKnowledgeFile({
    required String userId,
    required String filePath,
    String projectId = "default",
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return {"status": "error", "message": "File not found locally."};
      }

      final url = Uri.parse("$_baseUrl/knowledge/upload");
      final request = http.MultipartRequest("POST", url);

      request.fields["user_id"] = userId;
      request.fields["project_id"] = projectId;
      request.files.add(await http.MultipartFile.fromPath("file", filePath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {"status": "error", "message": "Server error: ${response.statusCode}"};
      }
    } catch (e) {
      return {"status": "error", "message": e.toString()};
    }
  }
}
