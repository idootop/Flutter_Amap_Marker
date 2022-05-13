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
              bottom: (e.position?.y ?? 0.0) as double,
              child: Offstage(
                offstage: e.position == null,
                child: e.child,
              ),
            ),
          )
          .toList(),
    );
  }
}

class AmapMarkerController {
  ///左边界
  double? x1;

  ///右边界
  double? x2;

  ///上边界
  double? y1;

  ///下边界
  double? y2;

  ///地图宽度
  double? mapWidth;

  ///地图高度
  double? mapHeight;

  ///墨卡托投影视野
  MercatorViewport? viewport;

  ///地图摄像机位置
  CameraPosition? cameraPosition;

  ///地图控制器
  AMapController? controller;

  ///地图覆盖物
  List<FlutterMarker> _markers = [];

  ///marker刷新回调
  Function? rebuildMarkersCallback;

  ///更新地图视图
  Future<void> updateViewport(CameraPosition? camera) async {
    if (camera == null) return;
    //更新视野
    if (camera.target != cameraPosition?.target ||
        camera.zoom != cameraPosition?.zoom) {
      cameraPosition = camera;
      //获取屏幕可视区域内地图经纬度范围
      final region =
          // ignore: argument_type_not_assignable_to_error_handler
          await controller?.getVisibleRegion().catchError((_) {
        return null;
      });
      if (region is Map) {
        final centerX = camera.target.longitude;
        x1 = region['southwest'][1];
        x2 = region['northeast'][1];
        y1 = region['southwest'][0];
        y2 = region['northeast'][0];

        var halfWidth = centerX - x1!;
        if (halfWidth > 180) {
          halfWidth = 360 - halfWidth;
        } else if (halfWidth < 0) {
          halfWidth = -halfWidth;
        }
        //修正经度边界
        x1 = centerX - halfWidth;
        x2 = centerX + halfWidth;
        //更新视图
        viewport = MercatorViewport.fitBounds(
          width: mapWidth!,
          height: mapHeight!,
          bounds: [x1!, y1!, x2!, y2!],
        );
      }
    }
  }

  void setMarkers(List<FlutterMarker> markers) {
    _markers = markers;
    updateMarkers();
  }

  List<FlutterMarker> get markers => _markers;

  ///更新覆盖物
  void updateMarkers() {
    if (_markers.isEmpty) return;
    for (var marker in _markers) {
      marker.position = map2screen(marker.latlng);
    }
    rebuildMarkersCallback?.call();
  }

  ///经纬度转屏幕坐标
  ///
  ///返回Point(x,y)（不在屏幕中为null）
  Point<double>? map2screen(LatLng? location) {
    if (_markers.isEmpty || location == null || viewport == null) {
      return null;
    }

    //修正跨东西半球处经度
    var x0 = cameraPosition!.target.longitude > 90 && location.longitude < 0
        ? 360 + location.longitude
        : location.longitude;

    if (x1! < -180 && x0 > 0 && x0 < 180) {
      x0 = x0 - 360;
    }

    final y0 = location.latitude;

    final flagX = x1! < x0 && x0 < x2!;
    final flagY = y1! < y0 && y0 < y2!;

    final width = x2! - x1!;
    final mapX = (x0 - x1!);

    final x = (mapX /width) * mapWidth!;

    //不在屏幕范围内
    if (!(flagX && flagY)) {
      return null;
    }

    //投影
    final v = viewport!.project2D(
      Point(location.longitude, location.latitude),
      topLeft: false,
    );

    return Point<double>(x, v.y as double);
  }
}
