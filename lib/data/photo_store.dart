import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// On-device cache of recipe photo bytes.
///
/// An imported recipe's AI photo is fetched from the network only once; the
/// bytes are then stored locally and loaded from storage (offline, instant) on
/// every later view — so the app never re-fetches a photo it already has.
/// Seed recipes use bundled assets and don't need this.
///
/// Native only: skipped on web, where large base64 blobs would quickly exhaust
/// localStorage (the web preview just loads the cached network image instead).
class PhotoStore {
  PhotoStore._();

  static const _prefix = 'photo:';
  static final Map<String, Uint8List> _mem = {};
  static final Set<String> _inFlight = {};
  static SharedPreferences? _prefs;

  /// Loads any previously cached photos into memory. Call once at startup.
  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      final p = await SharedPreferences.getInstance();
      _prefs = p;
      for (final k in p.getKeys()) {
        if (!k.startsWith(_prefix)) continue;
        final b64 = p.getString(k);
        if (b64 == null) continue;
        try {
          _mem[k.substring(_prefix.length)] = base64Decode(b64);
        } catch (_) {
          // Corrupt entry — ignore.
        }
      }
    } catch (_) {
      // No storage available — fall back to network images.
    }
  }

  /// Cached bytes for [recipeId], or null if not stored yet.
  static Uint8List? bytes(String recipeId) => _mem[recipeId];

  /// Fetches [url] once and stores the bytes for [recipeId] (fire-and-forget).
  /// No-ops if already cached or in flight, or on web.
  static void cacheFromUrl(String recipeId, String url) {
    if (kIsWeb || _mem.containsKey(recipeId) || _inFlight.contains(recipeId)) {
      return;
    }
    _inFlight.add(recipeId);
    () async {
      try {
        final res = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 60));
        if (res.statusCode == 200 && res.bodyBytes.length > 5000) {
          _mem[recipeId] = res.bodyBytes;
          await _prefs?.setString(
              '$_prefix$recipeId', base64Encode(res.bodyBytes));
        }
      } catch (_) {
        // Leave it; the network image still shows, we retry next session.
      } finally {
        _inFlight.remove(recipeId);
      }
    }();
  }
}
