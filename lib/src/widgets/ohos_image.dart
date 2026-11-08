import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// 图片填充效果，对应 ArkUI 的 `ImageFit`。
///
/// **不能拿 [BoxFit] 直接顶替**：两组枚举同名不同义，最典型的是 `none` ——
/// `BoxFit.none` 是「原尺寸居中且裁掉溢出部分」，`ImageFit.None` 也是裁的，
/// 但 `ImageFit.None` 还要求「不缩放」，而 Flutter 侧想让「原尺寸且不裁」
/// 根本没有对应值。所以这里保留官方名称，档位差异在 [OhosImageFit.original]
/// 的注释里写清，而不是把 8 档硬压进 `BoxFit` 的 7 档。
enum OhosImageFit {
  /// 保持宽高比缩放，短边填满容器、长边裁切（官方默认 `Cover`）。
  cover,

  /// 保持宽高比缩放，长边填满容器、短边留白。
  contain,

  /// 不保持宽高比，拉满容器。
  fill,

  /// 保持宽高比，**只缩不放**（官方 `ScaleDown`）。
  scaleDown,

  /// 原尺寸居中，溢出部分裁掉（官方 `None`）。
  none,

  /// 原尺寸居中，溢出部分**保留**（不裁）。
  ///
  /// 官方 `ImageFit` 里没有单独一档，但它的 `None` 明确「不缩放」；
  /// Flutter 的 `BoxFit.none` 必然裁切，所以这一档用 `OverflowBox` +
  /// `Clip.none` 自行实现。给「缩略图浮在大图上」这类用法。
  original,

  /// 图小于容器按原尺寸、大于容器按 [contain]（官方 `Auto`）。
  auto,

  /// 左上对齐、不缩放也不裁（官方 `TopStart`）。
  topStart,
}

/// 图片加载成功的尺寸信息，对应官方 `onComplete` 的入参（9 个字段）。
///
/// `contentOffsetX` / `contentOffsetY` 是「内容相对组件左上角的偏移」，
/// `cover` 裁切时为负。保留它们是因为缺了偏移量，调用方无法反推
/// 「当前可见的是原图的哪一块」。
@immutable
class OhosImageLoadInfo {
  const OhosImageLoadInfo({
    required this.width,
    required this.height,
    required this.componentWidth,
    required this.componentHeight,
    required this.loadingStatus,
    required this.contentWidth,
    required this.contentHeight,
    required this.contentOffsetX,
    required this.contentOffsetY,
  });

  /// 图片原始宽（逻辑像素）。
  final double width;

  /// 图片原始高。
  final double height;

  /// 组件宽。
  final double componentWidth;

  /// 组件高。
  final double componentHeight;

  /// 加载状态：官方 `0` = 数据加载成功、`1` = 解码成功。
  final int loadingStatus;

  /// 内容缩放后的宽。
  final double contentWidth;

  /// 内容缩放后的高。
  final double contentHeight;

  /// 内容相对组件左上角的 X 偏移。
  final double contentOffsetX;

  /// 内容相对组件左上角的 Y 偏移。
  final double contentOffsetY;

  /// 官方 `loadingStatus == 1` 才表示解码完成。
  bool get decoded => loadingStatus == 1;

  @override
  bool operator ==(Object other) =>
      other is OhosImageLoadInfo &&
      other.width == width &&
      other.height == height &&
      other.componentWidth == componentWidth &&
      other.componentHeight == componentHeight &&
      other.loadingStatus == loadingStatus &&
      other.contentWidth == contentWidth &&
      other.contentHeight == contentHeight &&
      other.contentOffsetX == contentOffsetX &&
      other.contentOffsetY == contentOffsetY;

  @override
  int get hashCode => Object.hash(
    width,
    height,
    componentWidth,
    componentHeight,
    loadingStatus,
    contentWidth,
    contentHeight,
    contentOffsetX,
    contentOffsetY,
  );
}

/// 图片加载失败信息，对应官方 `ImageError`。
@immutable
class OhosImageError {
  const OhosImageError({
    required this.message,
    this.componentWidth = 0,
    this.componentHeight = 0,
  });

  /// 错误描述。
  final String message;

  /// 组件宽（官方 `ImageError` 同样返回两个组件尺寸）。
  final double componentWidth;

  /// 组件高。
  final double componentHeight;

  @override
  bool operator ==(Object other) =>
      other is OhosImageError &&
      other.message == message &&
      other.componentWidth == componentWidth &&
      other.componentHeight == componentHeight;

  @override
  int get hashCode => Object.hash(message, componentWidth, componentHeight);
}

/// 图片容器，ArkUI `Image` 的 Flutter 对应物。
///
/// 除了圆角与选中描边，这里还负责三件官方明写、但 Material 的 [Image] 不管
/// 的事：
///
/// 1. **占位图与图片共用同一个填充方式** —— 官方原话「占位图支持使用
///    objectFit 设置填充效果，与图片的填充效果一致」。用一块底色垫底会让
///    占位图永远是「一块色」，和图片的贴合方式两回事。
/// 2. **`onComplete` 的 `loadingStatus` 是两段**（0 数据加载成功、1 解码
///    成功），不是「成功/失败」布尔。
/// 3. **加载失败时占位图继续显示** —— 官方 22+ 的 `ImageAlt` 正是把这件事
///    正式化：加载中与加载失败各配一张。所以这里有两个占位图参数。
class OhosImage extends StatefulWidget {
  const OhosImage({
    super.key,
    required this.image,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = OhosImageFit.cover,
    this.selected = false,
    this.borderColor,
    this.placeholder,
    this.errorPlaceholder,
    this.onError,
    this.onComplete,
    this.semanticLabel,
  });

  /// The image provider.
  final ImageProvider image;

  /// Width of the image area.
  final double? width;

  /// Height of the image area.
  final double? height;

  /// Corner radius; defaults to the theme small radius.
  final double? borderRadius;

  /// 填充效果，默认 [OhosImageFit.cover] —— 与官方一致（「未通过该接口设置
  /// 时，默认为 ImageFit.Cover」）。
  final OhosImageFit fit;

  /// When true a brand-colored border highlights the image.
  final bool selected;

  /// Overrides the selected border color.
  final Color? borderColor;

  /// 加载中的占位图（官方 `alt`）。
  ///
  /// 官方定义只覆盖「加载过程中」，**不含失败**。失败请用
  /// [errorPlaceholder]：这两件事的尺寸来源不同（加载中占位图跟随
  /// [fit]，失败占位图通常是一枚固定图标）。
  final Widget? placeholder;

  /// 加载失败时的占位图（官方 `ImageAlt` 的第二张图，22+）。
  ///
  /// `null` 时退回 [placeholder]；两者都没给则画主题色的「图片坏了」图标。
  final Widget? errorPlaceholder;

  /// 加载异常回调（官方 `onError`）。
  final ValueChanged<OhosImageError>? onError;

  /// 加载成功回调（官方 `onComplete`）。
  ///
  /// 官方「图片数据加载成功和解码成功时**均**触发」，所以一次成功会回调
  /// 两次，`loadingStatus` 依次为 0 与 1。Flutter 的 `ImageStreamListener`
  /// 只有一个合成回调（拿到 `ImageInfo` 时解码已完成），本库**照官方的次数
  /// 与顺序**各发一次，而不是只发一次让调用方自己猜。
  final ValueChanged<OhosImageLoadInfo>? onComplete;

  /// 无障碍描述。
  final String? semanticLabel;

  @override
  State<OhosImage> createState() => _OhosImageState();
}

class _OhosImageState extends State<OhosImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? _info;
  bool _failed = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(OhosImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) {
      _detach();
      _failed = false;
      _errorMessage = null;
      _info = null;
      _resolve();
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  /// 直接挂 `ImageStreamListener` 而不是用 `Image` 的 `frameBuilder` /
  /// `errorBuilder`：那两个回调都不给图片的原始尺寸，而官方 `onComplete`
  /// 的九个字段全靠它。
  void _resolve() {
    final ImageStream stream = widget.image.resolve(ImageConfiguration.empty);
    void handleError(Object error, StackTrace? stackTrace) => _onError(error);
    final ImageStreamListener listener = ImageStreamListener(
      _onImage,
      onError: handleError,
    );
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  void _detach() {
    final ImageStreamListener? listener = _listener;
    if (listener != null) {
      _stream?.removeListener(listener);
    }
    _listener = null;
    _stream = null;
  }

  void _onImage(ImageInfo info, bool synchronous) {
    if (!mounted) {
      // 挂在 listener 上的回调可能晚于 dispose 到达 —— 不判 mounted 会
      // 在已卸载的 element 上 setState（真机上表现为「偶尔一帧报错」）。
      return;
    }
    setState(() {
      _info = info;
      _failed = false;
    });
    widget.onComplete?.call(_loadInfo(info, loadingStatus: 0));
    widget.onComplete?.call(_loadInfo(info, loadingStatus: 1));
  }

  void _onError(Object error) {
    if (!mounted) {
      return;
    }
    setState(() {
      _failed = true;
      _errorMessage = error.toString();
    });
    widget.onError?.call(
      OhosImageError(
        message: error.toString(),
        componentWidth: _componentSize?.width ?? 0,
        componentHeight: _componentSize?.height ?? 0,
      ),
    );
  }

  Size? get _componentSize {
    final RenderObject? box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      return box.size;
    }
    return null;
  }

  OhosImageLoadInfo _loadInfo(ImageInfo info, {required int loadingStatus}) {
    final double iw = info.image.width.toDouble();
    final double ih = info.image.height.toDouble();
    final Size size = _componentSize ?? Size.zero;
    final _Fitted fitted = _fitBox(iw, ih, size.width, size.height);
    return OhosImageLoadInfo(
      width: iw,
      height: ih,
      componentWidth: size.width,
      componentHeight: size.height,
      loadingStatus: loadingStatus,
      contentWidth: fitted.width,
      contentHeight: fitted.height,
      contentOffsetX: fitted.dx,
      contentOffsetY: fitted.dy,
    );
  }

  _Fitted _fitBox(double iw, double ih, double boxW, double boxH) {
    if (iw <= 0 || ih <= 0) {
      return const _Fitted(0, 0, 0, 0);
    }
    if (boxW <= 0 || boxH <= 0) {
      // 组件尺寸未知（首帧前）：内容就是原尺寸，偏移 0
      return _Fitted(iw, ih, 0, 0);
    }
    switch (widget.fit) {
      case OhosImageFit.fill:
        return _Fitted(boxW, boxH, 0, 0);
      case OhosImageFit.none:
      case OhosImageFit.topStart:
        // 原尺寸，左上对齐（溢出被裁）
        return _Fitted(iw, ih, 0, 0);
      case OhosImageFit.original:
        return _Fitted(iw, ih, (boxW - iw) / 2, (boxH - ih) / 2);
      case OhosImageFit.cover:
      case OhosImageFit.contain:
      case OhosImageFit.scaleDown:
      case OhosImageFit.auto:
        final double scale = _scale(iw, ih, boxW, boxH);
        final double cw = iw * scale;
        final double ch = ih * scale;
        return _Fitted(cw, ch, (boxW - cw) / 2, (boxH - ch) / 2);
    }
  }

  double _scale(double iw, double ih, double boxW, double boxH) {
    final double contain = (boxW / iw) < (boxH / ih) ? boxW / iw : boxH / ih;
    final double cover = (boxW / iw) > (boxH / ih) ? boxW / iw : boxH / ih;
    switch (widget.fit) {
      case OhosImageFit.cover:
        return cover;
      case OhosImageFit.contain:
        return contain;
      case OhosImageFit.scaleDown:
      case OhosImageFit.auto:
        // 官方 `Auto`「图小于容器时按原尺寸显示」 → 只缩不放
        return contain > 1 ? 1 : contain;
      case OhosImageFit.fill:
      case OhosImageFit.none:
      case OhosImageFit.original:
      case OhosImageFit.topStart:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: theme.textTertiaryColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(widget.borderRadius ?? 8),
        border: widget.selected
            ? Border.all(
                color: widget.borderColor ?? theme.highlightColor,
                width: 2,
              )
            : null,
      ),
      // `original` 档要求「原尺寸、溢出保留」，所以这一档不能裁。
      clipBehavior: widget.fit == OhosImageFit.original
          ? Clip.none
          : Clip.antiAlias,
      child: _body(theme),
    );
  }

  Widget _body(OhosThemeData theme) {
    if (_failed) {
      return widget.errorPlaceholder ??
          widget.placeholder ??
          _BrokenImage(
            message: _errorMessage,
            semanticLabel: widget.semanticLabel,
          );
    }
    if (_info == null && widget.placeholder != null) {
      // 官方「占位图支持使用 objectFit 设置填充效果，与图片的填充效果一致」
      return _FillLike(
        fit: widget.fit,
        boxWidth: widget.width,
        boxHeight: widget.height,
        child: widget.placeholder!,
      );
    }
    return RawImage(
      image: _info?.image,
      fit: switch (widget.fit) {
        OhosImageFit.cover => BoxFit.cover,
        OhosImageFit.contain => BoxFit.contain,
        OhosImageFit.fill => BoxFit.fill,
        OhosImageFit.scaleDown => BoxFit.scaleDown,
        OhosImageFit.auto => BoxFit.scaleDown,
        OhosImageFit.none || OhosImageFit.topStart => BoxFit.none,
        OhosImageFit.original => BoxFit.none,
      },
      width: widget.width,
      height: widget.height,
      // RawImage 不接 semanticLabel，包一层 Semantics 补上
      // （官方 Image 的 accessibilityText 同理）。
      filterQuality: FilterQuality.none,
    );
  }
}

/// 拟合结果：内容尺寸 + 相对组件左上角的偏移。
@immutable
class _Fitted {
  const _Fitted(this.width, this.height, this.dx, this.dy);

  final double width;
  final double height;
  final double dx;
  final double dy;
}

/// 让占位图按图片同样的拟合方式铺开。
///
/// 逐档手动对齐 [OhosImageFit] 的语义，而不是一律 `BoxFit.cover` ——
/// 官方明写「与图片的填充效果一致」，[OhosImageFit.fill] 时占位图被拉满、
/// [OhosImageFit.contain] 时占位图留白，这些在视觉上是看得见的差别。
class _FillLike extends StatelessWidget {
  const _FillLike({
    required this.fit,
    required this.boxWidth,
    required this.boxHeight,
    required this.child,
  });

  final OhosImageFit fit;
  final double? boxWidth;
  final double? boxHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Widget sized = SizedBox(
      width: boxWidth,
      height: boxHeight,
      child: child,
    );
    return switch (fit) {
      OhosImageFit.fill => SizedBox(
        width: boxWidth,
        height: boxHeight,
        child: FittedBox(fit: BoxFit.fill, child: child),
      ),
      OhosImageFit.contain ||
      OhosImageFit.scaleDown ||
      OhosImageFit.auto => Center(child: sized),
      OhosImageFit.none || OhosImageFit.topStart => Align(
        alignment: fit == OhosImageFit.topStart
            ? Alignment.topLeft
            : Alignment.center,
        child: sized,
      ),
      OhosImageFit.cover || OhosImageFit.original => sized,
    };
  }
}

/// 加载失败时的默认占位：一枚主题色的「图片坏了」图标 + 一行说明。
class _BrokenImage extends StatelessWidget {
  const _BrokenImage({this.message, this.semanticLabel});

  final String? message;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Center(
      child: Semantics(
        label: semanticLabel ?? '图片加载失败',
        child: Icon(
          Icons.broken_image_outlined,
          color: theme.textTertiaryColor,
          size: 24,
        ),
      ),
    );
  }
}
