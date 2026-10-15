import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Global navigator key so shared content can open a screen regardless of
/// which tab is currently active.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Receives plain text / links shared from other apps (e.g. a caption or reel
/// link shared from Instagram) via the Android/iOS share sheet.
class ShareService {
  ShareService._();
  static final ShareService instance = ShareService._();

  StreamSubscription<List<SharedMediaFile>>? _sub;
  bool _started = false;

  /// Invoked with the combined shared text whenever content arrives.
  void Function(String text)? onText;

  void start() {
    if (kIsWeb || _started) return;
    _started = true;
    // While the app is running.
    _sub = ReceiveSharingIntent.instance.getMediaStream().listen(
      _handle,
      onError: (_) {},
    );
    // Content that launched the app from a cold start.
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      _handle(files);
      ReceiveSharingIntent.instance.reset();
    });
  }

  void _handle(List<SharedMediaFile> files) {
    if (files.isEmpty) return;
    final parts = <String>[];
    for (final f in files) {
      if (f.type == SharedMediaType.text || f.type == SharedMediaType.url) {
        if (f.path.trim().isNotEmpty) parts.add(f.path.trim());
      }
      final msg = f.message;
      if (msg != null && msg.trim().isNotEmpty && msg.trim() != f.path.trim()) {
        parts.add(msg.trim());
      }
    }
    final text = parts.join('\n').trim();
    if (text.isNotEmpty) onText?.call(text);
  }

  void dispose() {
    _sub?.cancel();
    _started = false;
  }
}
