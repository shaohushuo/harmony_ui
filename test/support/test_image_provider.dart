import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 可控的假图源，专供 `OhosImage` 的用例。
///
/// **为什么不用 `MemoryImage` / `NetworkImage`**：那两者都没有「可观测的加载中
/// 状态」—— `MemoryImage` 解码完成前 `frameBuilder` 拿得到 `null`，但失败路径
/// 造不出来；`NetworkImage` 在测试里会真发请求。所以这里手写一个
/// `ImageProvider`：`completer` 不完成时就是「加载中」，完成失败就是「加载失败」。
class TestImageProvider extends ImageProvider<TestImageProvider> {
  TestImageProvider(this.image, {this.delay = true});

  /// `null` 表示这张图永远不加载完成（用来稳定停在「加载中」态）。
  final ui.Image? image;

  /// 是否异步交付。
  ///
  /// **必须默认异步**：用 `SynchronousFuture` 会让 `onComplete` 在
  /// `pumpWidget` 内部就触发，那时 `OhosImage` 还没布局、`findRenderObject()`
  /// 拿不到尺寸（实测 `componentWidth` 读到 0），用例断出来的偏移全是错的。
  /// 异步交付则落在下一次 `tester.pump()`，尺寸已经量过。
  final bool delay;

  @override
  Future<TestImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<TestImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    TestImageProvider key,
    ImageDecoderCallback decode,
  ) {
    if (image == null) {
      return OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
    }
    final Future<ImageInfo> info = delay
        ? Future<ImageInfo>.value(ImageInfo(image: image!))
        : SynchronousFuture<ImageInfo>(ImageInfo(image: image!));
    return OneFrameImageStreamCompleter(info);
  }

  @override
  bool operator ==(Object other) =>
      other is TestImageProvider && other.image == image;

  @override
  int get hashCode => image.hashCode;
}

/// 一定失败加载的图源。
class FailingImageProvider extends ImageProvider<FailingImageProvider> {
  const FailingImageProvider({this.message = 'boom'});

  final String message;

  @override
  Future<FailingImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<FailingImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    FailingImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      Future<ImageInfo>.error(StateError(message)),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FailingImageProvider && other.message == message;

  @override
  int get hashCode => message.hashCode;
}

/// 造一张纯色 `ui.Image`，用来给 `onComplete` 提供确定的原始尺寸。
Future<ui.Image> makeTestImage(int width, int height) {
  final Completer<ui.Image> completer = Completer<ui.Image>();
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF808080),
  );
  recorder.endRecording().toImage(width, height).then(completer.complete);
  return completer.future;
}
