import 'package:flutter/widgets.dart';

/// Native (mobile/desktop) implementation: plain [Image.network]. No CORS on
/// these platforms, so any image host works.
Widget netImage(
  String url, {
  double? width,
  double? height,
  double radius = 0,
  BoxFit fit = BoxFit.cover,
  required Widget placeholder,
}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: SizedBox(
      width: width,
      height: height,
      child: Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSync) =>
            (wasSync || frame != null) ? child : placeholder,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : placeholder,
        errorBuilder: (_, _, _) => placeholder,
      ),
    ),
  );
}
