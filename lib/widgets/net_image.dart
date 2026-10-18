import 'package:flutter/widgets.dart';

import 'net_image_io.dart' if (dart.library.js_interop) 'net_image_web.dart'
    as impl;

/// Renders a network image with a graceful [placeholder] (shown while loading
/// and on error).
///
/// On the web, Flutter's CanvasKit renderer loads network images with a CORS
/// `fetch()`, so a cross-origin image host that doesn't send
/// `Access-Control-Allow-Origin` fails to decode and only the placeholder is
/// seen. To avoid that we render a real HTML `<img>` element on the web (the
/// browser displays cross-origin images in `<img>` without CORS), and fall
/// back to [Image.network] on every other platform. Callers use this instead
/// of [Image.network] directly.
Widget netImage(
  String url, {
  double? width,
  double? height,
  double radius = 0,
  BoxFit fit = BoxFit.cover,
  required Widget placeholder,
}) =>
    impl.netImage(
      url,
      width: width,
      height: height,
      radius: radius,
      fit: fit,
      placeholder: placeholder,
    );
