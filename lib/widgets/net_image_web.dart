import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Web implementation: render a real HTML `<img>` element via a platform view.
/// The browser displays cross-origin images in `<img>` without a CORS check,
/// which Flutter's CanvasKit `Image.network` path does not. The Flutter-drawn
/// [placeholder] sits behind it and shows while the image loads or if it fails
/// (the `<img>` hides itself on error).
final Set<String> _registered = <String>{};

Widget netImage(
  String url, {
  double? width,
  double? height,
  double radius = 0,
  BoxFit fit = BoxFit.cover,
  required Widget placeholder,
}) {
  final viewType = 'netimg:${url.hashCode}:${radius.toInt()}';
  if (_registered.add(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final img = web.HTMLImageElement();
      img.src = url;
      img.style
        ..width = '100%'
        ..height = '100%'
        ..border = 'none'
        ..borderRadius = '${radius}px'
        ..objectFit = fit == BoxFit.contain ? 'contain' : 'cover';
      // On a failed load, hide the <img> so the placeholder behind shows.
      img.onerror = (web.Event _) {
        img.style.display = 'none';
      }.toJS;
      return img;
    });
  }
  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          placeholder,
          HtmlElementView(viewType: viewType),
        ],
      ),
    ),
  );
}
