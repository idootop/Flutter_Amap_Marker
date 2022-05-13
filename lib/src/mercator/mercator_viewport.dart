part of web_mercator;

class MercatorViewport {
  final num width, height;
  final double? lat, lng, zoom, pitch, bearing, altitude, unitsPerMeter;
  final Vector2 center;

  Matrix4? viewMatrix, projMatrix;
  Matrix4? _viewProjMatrix, _pixelProjMatrix, _pixelUnprojMatrix;

  MercatorViewport({
    required num width,
    required num height,
    double this.lng = .0,
    double this.lat = .0,
    this.zoom = .0,
    this.pitch = .0,
    this.bearing = .0,
    double this.altitude = 1.5,
    double nearZMultiplier = .02,
    double farZMultiplier = 1.01,
  })  : assert(altitude >= .75, 'invalid altitude'),
        width = max(1, width),
        height = max(1, height),
        unitsPerMeter = getDistanceScales(lng, lat)['unitsPerMeter']![2],
        center = lngLatToWorld(lng, lat) {
    viewMatrix = getViewMatrix(
      height: this.height,
      pitch: pitch!,
      bearing: bearing!,
      altitude: max(.75, altitude!),
      scale: zoomToScale(zoom!) as double,
      center: center,
    );

    projMatrix = getProjMatrix(
      width: this.width,
      height: this.height,
      pitch: pitch!,
      altitude: altitude!,
      nearZMultiplier: nearZMultiplier,
      farZMultiplier: farZMultiplier,
    );

    _viewProjMatrix = Matrix4.identity()
      ..multiply(projMatrix!)
      ..multiply(viewMatrix!);

    _pixelProjMatrix = Matrix4.identity()
      ..scale(this.width * .5, -this.height * .5, 1)
      ..translate(1.0, -1.0, .0)
      ..multiply(_viewProjMatrix!);

    _pixelUnprojMatrix = Matrix4.inverted(_pixelProjMatrix!);
  }

  /// Returns a new viewport that fit around the given rectangle.
  factory MercatorViewport.fitBounds({
    required num width,
    required num height,
    required List<num> bounds,
    double minExtent = 0,
    double maxZoom = 24,
    dynamic padding = 0,
    List<num> offset = const [0, 0],
  }) {
    final lngLatZoom = fitBounds(
      width: width,
      height: height,
      bounds: bounds,
      minExtent: minExtent,
      maxZoom: maxZoom,
      padding: padding,
      offset: offset,
    );

    return MercatorViewport(
      width: width,
      height: height,
      lng: lngLatZoom['lng'] as double,
      lat: lngLatZoom['lat'] as double,
      zoom: lngLatZoom['zoom'] as double?,
    );
  }

  /// Convenient factory to clone a viewport with parameters typically reflecting user interactions.
  factory MercatorViewport.copyWith(
    MercatorViewport from, {
    double? pitch,
    double? bearing,
    double? zoom,
  }) =>
      MercatorViewport(
        width: from.width,
        height: from.height,
        lng: from.lng!,
        lat: from.lat!,
        pitch: pitch ?? from.pitch,
        bearing: bearing ?? from.bearing,
        zoom: zoom ?? from.zoom,
      );

  Point project2D(Point<double> p, {bool topLeft = true}) {
    final v = project(Vector2(p.x, p.y), topLeft: topLeft) as Vector2;
    return Point<double>(v.x, v.y);
  }

  /// Project [vector] to pixel coordinates.
  Vector project(Vector vector, {bool topLeft = true}) {
    assert(vector is Vector2 || vector is Vector3);

    final worldPosition = projectPosition(vector);
    final coord = worldToPixels(worldPosition, _pixelProjMatrix!);
    final num y = topLeft ? coord[1] : height - coord[1];

    return vector is Vector2
        ? Vector2(coord[0], y as double)
        : Vector3(coord[0], y as double, coord[2]);
  }

  /// Unproject [xyz] coordinates onto world coordinates.
  Vector unproject(Vector xyz, {bool topLeft = true, double? targetZ}) {
    assert(xyz is Vector2 || xyz is Vector3);

    dynamic vec, z;

    if (xyz is Vector2) {
      vec = xyz;
      z = double.nan;
    } else if (xyz is Vector3) {
      vec = xyz;
      z = vec[2];
    }

    final coord = pixelsToWorld(
      Vector3(vec[0], topLeft ? vec[1] : height - vec[1] as double, z),
      _pixelUnprojMatrix,
      targetZ: targetZ != null ? targetZ * unitsPerMeter! : null,
    );

    final unprojPosition = unprojectPosition(coord);
    if (vec is Vector3) {
      return unprojPosition;
    } else if (targetZ != null) {
      return Vector3(unprojPosition[0], unprojPosition[1], targetZ);
    } else {
      return Vector2(unprojPosition[0], unprojPosition[1]);
    }
  }

  Vector3 projectPosition(Vector vector) {
    assert(vector is Vector2 || vector is Vector3 || vector is Vector4);

    late dynamic vec;
    if (vector is Vector2) {
      vec = vector;
    } else if (vector is Vector3) {
      vec = vector;
    } else if (vector is Vector4) {
      vec = vector;
    }

    final flatProjection = projectFlat(vec[0], vec[1]);
    final num z = (vector is Vector3 ? vector[2] : 0) * unitsPerMeter!;

    return Vector3(flatProjection[0], flatProjection[1], z as double);
  }

  Vector3 unprojectPosition(Vector vector) {
    assert(vector is Vector2 || vector is Vector3 || vector is Vector4);

    late dynamic vec;
    if (vector is Vector2) {
      vec = vector;
    } else if (vector is Vector3) {
      vec = vector;
    } else if (vector is Vector4) {
      vec = vector;
    }

    final unprojection = unprojectFlat(vec[0], vec[1]);
    final dynamic z =
        (vec is Vector3 || vec is Vector4 ? vec[2] : 0) / unitsPerMeter;

    return Vector3(unprojection[0], unprojection[1], z);
  }

  Vector2 projectFlat(double x, double y) => lngLatToWorld(x, y);

  Vector2 unprojectFlat(double x, double y) => worldToLngLat(x, y);

  /// Get the map center that places a given [lngLat] coordinate at screen point [pos].
  Vector2 getLocationAtPoint({required Vector2 lngLat, required Vector2 pos}) {
    final fromLocation =
        pixelsToWorld(Vector3(pos[0], pos[1], double.nan), _pixelUnprojMatrix)
            as Vector2;
    final toLocation = lngLatToWorld(lngLat[0], lngLat[1]);

    final translate = toLocation.clone();
    fromLocation.negate();
    translate.add(fromLocation);

    final newCenter = center.clone();
    newCenter.add(translate);

    return worldToLngLat(newCenter[0], newCenter[1]);
  }

  @override
  int get hashCode => Object.hashAll([width, height, viewMatrix!, projMatrix!]);

  @override
  bool operator ==(Object other) =>
      other is MercatorViewport && other.hashCode == hashCode;

  @override
  String toString() => '''
    width: $width, height: $height, lng: $lng, lat: $lat,
    zoom: $zoom, pitch: $pitch, bearing: $bearing
    ''';
}
