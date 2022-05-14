part of amap_flutter_map;

class FlutterMarker {
  final LatLng latlng;
  final Widget child;
  Point? position;
  FlutterMarker({
    required this.latlng,
    required this.child,
  });
}

class MarkersStack extends StatefulWidget {
  final AmapMarkerController controller;
  const MarkersStack({required this.controller, Key? key}) : super(key: key);

  @override
  State<MarkersStack> createState() => _MarkersStackState();
}

class _MarkersStackState extends State<MarkersStack> {
  void rebuild() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    widget.controller.rebuildMarkersCallback = rebuild;
    return Stack(
      children: widget.controller.markers
          .map<Widget>(
            (e) => Positioned(
              left: (e.position?.x ?? 0.0) as double,
              top: (e.position?.y ?? 0.0) as double,
              child: Offstage(
                offstage: e.position == null,
                child: TransparentPointer(child: e.child),
              ),
            ),
          )
          .toList(),
    );
  }
}

class AmapMarkerController {

  ///地图控制器
  AMapController? controller;

  ///地图覆盖物
  List<FlutterMarker> _markers = [];

  ///marker刷新回调
  Function? rebuildMarkersCallback;

  List<FlutterMarker> get markers => _markers;

  void setMarkers(List<FlutterMarker> markers) {
    _markers = markers;
    updateMarkers();
  }

  ///更新覆盖物
  Future<void> updateMarkers() async {
    if (_markers.isEmpty) return;
    for (var marker in _markers) {
      marker.position = await map2screen(marker.latlng);
    }
    rebuildMarkersCallback?.call();
  }

  ///经纬度转屏幕坐标
  ///
  ///返回Point(x,y)（不在屏幕中为null）
  Future<Point<double>?> map2screen(LatLng? location) async {
    if (_markers.isEmpty || location == null || controller == null) {
      return Future.value(null);
    }
    final result = await controller!.screenLocation(location);
    final p = Platform.isAndroid ? window.devicePixelRatio : 1;
    return result == null
        ? null
        : Point<double>(result["x"] / p, result["y"] / p);
  }
}

///https://github.com/spkersten/flutter_transparent_pointer

/// This widget is invisible for its parent to hit testing, but still
/// allows its subtree to receive pointer events.
///
/// {@tool snippet}
///
/// In this example, a drag can be started anywhere in the widget, including on
/// top of the text button, even though the button is visually in front of the
/// background gesture detector. At the same time, the button is tappable.
///
/// ```dart
/// class MyWidget extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return Stack(
///       children: [
///         GestureDetector(
///           behavior: HitTestBehavior.opaque,
///           onVerticalDragStart: (_) => print("Background drag started"),
///         ),
///         Positioned(
///           top: 60,
///           left: 60,
///           height: 60,
///           width: 60,
///           child: TransparentPointer(
///             child: TextButton(
///               child: Text("Tap me"),
///               onPressed: () => print("You tapped me"),
///             ),
///           ),
///         ),
///       ],
///     );
///   }
/// }
/// ```
/// {@end-tool}
///
/// See also:
///
///  * [IgnorePointer], which is also invisible for its parent during hit testing, but
///    does not allow its subtree to receive pointer events.
///  * [AbsorbPointer], which is visible during hit testing, but prevents its subtree
///    from receiving pointer event. The opposite of this widget.
class TransparentPointer extends SingleChildRenderObjectWidget {
  /// Creates a widget that is invisible for its parent to hit testing, but still
  /// allows its subtree to receive pointer events.
  const TransparentPointer({
    Key? key,
    this.transparent = true,
    required Widget child,
  }) : super(key: key, child: child);

  /// Whether this widget is invisible to its parent during hit testing.
  final bool transparent;

  @override
  RenderTransparentPointer createRenderObject(BuildContext context) {
    return RenderTransparentPointer(
      transparent: transparent,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderTransparentPointer renderObject) {
    renderObject.transparent = transparent;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<bool>('transparent', transparent));
  }
}

class RenderTransparentPointer extends RenderProxyBox {
  RenderTransparentPointer({
    RenderBox? child,
    bool transparent = true,
  })  : _transparent = transparent,
        super(child);

  bool get transparent => _transparent;
  bool _transparent;

  set transparent(bool value) {
    if (value == _transparent) return;
    _transparent = value;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final hit = super.hitTest(result, position: position);
    return !transparent && hit;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<bool>('transparent', transparent));
  }
}

