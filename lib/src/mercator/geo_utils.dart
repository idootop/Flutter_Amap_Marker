part of web_mercator;

/// Average circumference (40075 km equatorial, 40007 km meridional)
const EARTH_CIRCUMFERENCE = 40.03e6;

/// Mapbox default altitude
const DEFAULT_ALTITUDE = 1.5;

/// Default size of a map tile
const TILE_SIZE = 512;

/// Convert a distance measurement (assuming a spherical Earth) from a real-world unit into radians.
/// see: [https://github.com/Turfjs/turf/blob/master/packages/turf-helpers/index.ts](turf/helpers)
num lengthToRadians(num distance) {
  const earthRadius = 6371008.8;
  final factor = earthRadius / 1000;
  return distance / factor;
}

/// Takes a [lng, lat] location and calculates the location of a destination point given a [distance] in kilometers; and [bearing] in degrees.
/// see: [https://github.com/Turfjs/turf/blob/master/packages/turf-destination/index.ts](turf/destination)
Vector2 destination(double lng, double lat,
    {required num distance, num bearing = 0}) {
  assert(distance.isFinite && distance > 0, 'distance is invalid');

  final lng1 = lng * degrees2Radians;
  final lat1 = lat * degrees2Radians;
  final num bearingRad = bearing * degrees2Radians;
  final radians = lengthToRadians(distance);

  final lat2 = asin(
      sin(lat1) * cos(radians) + cos(lat1) * sin(radians) * cos(bearingRad));
  final lng2 = lng1 +
      atan2(sin(bearingRad) * sin(radians) * cos(lat1),
          cos(radians) - sin(lat1) * sin(lat2));

  return Vector2(lng2 * radians2Degrees, lat2 * radians2Degrees);
}

/// Takes a list of [coordinates] and returns a bounding box enclosing them (in [minX, minY, maxX, maxY] order).
/// see: [https://github.com/Turfjs/turf/blob/master/packages/turf-bbox/index.ts](turf/bbox)
List<double> bbox(List<List<double>> coordinates) {
  var result = <double>[
    double.infinity,
    double.infinity,
    double.negativeInfinity,
    double.negativeInfinity
  ];

  for (final coord in coordinates) {
    if (result[0] > coord[0]) {
      result[0] = coord[0];
    }
    if (result[1] > coord[1]) {
      result[1] = coord[1];
    }
    if (result[2] < coord[0]) {
      result[2] = coord[0];
    }
    if (result[3] < coord[1]) {
      result[3] = coord[1];
    }
  }

  return result;
}

/// Project [lng, lat] on sphere on 512*512 Mercator Zoom 0 tile.
Vector2 lngLatToWorld(double lng, double lat) {
  assert(lng.isFinite);
  assert(lat.isFinite && lat >= -90 && lat <= 90, 'invalid latitude');

  final lambda2 = lng * degrees2Radians;
  final phi2 = lat * degrees2Radians;
  final x = (TILE_SIZE * (lambda2 + pi)) / (2 * pi);
  final y = (TILE_SIZE * (pi + log(tan(PI_4 + phi2 * .5)))) / (2 * pi);

  return Vector2(x, y);
}

/// Unproject world point [x, y] on map onto [lng, lat] on sphere.
Vector2 worldToLngLat(double x, double y) {
  final lambda2 = (x / TILE_SIZE) * (2 * pi) - pi;
  final phi2 = 2 * (atan(exp((y / TILE_SIZE) * (2 * pi) - pi)) - PI_4);

  return Vector2(lambda2 * radians2Degrees, phi2 * radians2Degrees);
}

/// Return the zoom level that gives a 1 meter pixel at a certain [lat].
double getMeterZoom(double lat) {
  assert(lat.isFinite);

  final latCosine = cos(lat * degrees2Radians);

  return scaleToZoom(EARTH_CIRCUMFERENCE * latCosine) - 9;
}

/// Calculate distance scales in meters around current [lat, lng], for both degrees and pixels.
Map<String, List> getDistanceScales(double lng, double lat,
    {bool highPrecision = false}) {
  assert(lng.isFinite && lat.isFinite);

  final latCosine = cos(lat * degrees2Radians);

  /// Number of pixels occupied by one degree lng around current lat/lon:
  const unitsPerDegreeX = TILE_SIZE / 360;
  final unitsPerDegreeY = unitsPerDegreeX / latCosine;

  /// Number of pixels occupied by one meter around current lat/lon:
  final altUnitsPerMeter = TILE_SIZE / EARTH_CIRCUMFERENCE / latCosine;

  final result = <String, List>{};
  result['unitsPerMeter'] = <double>[
    altUnitsPerMeter,
    altUnitsPerMeter,
    altUnitsPerMeter
  ];
  result['metersPerUnit'] = <double>[
    1 / altUnitsPerMeter,
    1 / altUnitsPerMeter,
    1 / altUnitsPerMeter
  ];
  result['unitsPerDegree'] = <double>[
    unitsPerDegreeX,
    unitsPerDegreeY,
    altUnitsPerMeter
  ];
  result['degreesPerUnit'] = <double>[
    1 / unitsPerDegreeX,
    1 / unitsPerDegreeY,
    1 / altUnitsPerMeter
  ];

  if (highPrecision) {
    final latCosine2 =
        (degrees2Radians * tan(lat * degrees2Radians)) / latCosine;
    final unitsPerDegreeY2 = (unitsPerDegreeX * latCosine2) * .5;
    final altUnitsPerDegree2 = (TILE_SIZE / EARTH_CIRCUMFERENCE) * latCosine2;
    final altUnitsPerMeter2 =
        (altUnitsPerDegree2 / unitsPerDegreeY) * altUnitsPerMeter;

    result['unitsPerDegree2'] = <double>[
      .0,
      unitsPerDegreeY2,
      altUnitsPerDegree2
    ];
    result['unitsPerMeter2'] = <double>[
      altUnitsPerMeter2,
      .0,
      altUnitsPerMeter2
    ];
  }

  return result;
}

/// Calculates camera projection for
Map<String, num?> getProjParameters(
  num width,
  num height, {
  double altitude = DEFAULT_ALTITUDE,
  double pitch = 0,
  double? nearZMultiplier = 1,
  double farZMultiplier = 1,
}) {
  /// Find the distance from the center point to the center top in altitude units using law of sines.
  final pitchRadians = pitch * degrees2Radians;
  final halfFov = atan(.5 / altitude);
  final topHalfSurfaceDistance =
      (sin(halfFov) * altitude) / sin(PI_2 - pitchRadians - halfFov);

  /// Calculate z value of the farthest fragment that should be rendered.
  final farZ = cos(PI_2 - pitchRadians) * topHalfSurfaceDistance + altitude;

  return {
    'fov': 2 * halfFov,
    'aspect': width / height,
    'focalDistance': altitude,
    'near': nearZMultiplier,
    'far': farZ * farZMultiplier,
  };
}

/// Returns map settings {lng, lat, zoom} containing the provided [bounds] within the provided [width] & [height].
/// Only supports non-perspective mode.
Map<String, num> fitBounds({
  required num width,
  required num height,
  required List<num> bounds,
  double minExtent = 0,
  double maxZoom = 24,
  dynamic padding = 0,
  List<num> offset = const [0, 0],
}) {
  assert(bounds.length == 4);
  assert(offset.length == 2);

  final west = bounds[0],
      south = bounds[1],
      east = bounds[2],
      north = bounds[3];

  if (padding is int) {
    final num p = padding;
    padding = {'top': p, 'right': p, 'bottom': p, 'left': p};
  } else {
    assert(padding is Map<String, num>);
    assert(padding['top'] is num &&
        padding['right'] is num &&
        padding['bottom'] is num &&
        padding['left'] is num);
  }

  final viewport = MercatorViewport(width: width, height: height);

  final nw =
      viewport.project(Vector2(west as double, north as double)) as Vector2;
  final se =
      viewport.project(Vector2(east as double, south as double)) as Vector2;

  /// width/height on the Web Mercator plane
  final size = <num>[
    max((se[0] - nw[0]).abs(), minExtent),
    max((se[1] - nw[1]).abs(), minExtent),
  ];

  final targetSize = <num>[
    width - padding['left'] - padding['right'] - offset[0].abs() * 2,
    height - padding['top'] - padding['bottom'] - offset[1].abs() * 2,
  ];

  assert(targetSize[0] > 0 && targetSize[1] > 0);

  /// scale = screen pixels per unit on the Web Mercator plane
  final scaleX = targetSize[0] / size[0];
  final scaleY = targetSize[1] / size[1];

  /// Find how much we need to shift the center
  final double offsetX = (padding['right'] - padding['left']) * .5 / scaleX;
  final double offsetY = (padding['bottom'] - padding['top']) * .5 / scaleY;

  final center = Vector3((se[0] + nw[0]) * .5 + offsetX,
      (se[1] + nw[1]) * .5 + offsetY, double.nan);
  final centerLngLat = viewport.unproject(center) as Vector3;
  final zoom = min(maxZoom, viewport.zoom! + log2(min(scaleX, scaleY)).abs());

  assert(zoom.isFinite);
  return {'lng': centerLngLat[0], 'lat': centerLngLat[1], 'zoom': zoom};
}

/// Offset a [lngLatZ] position by meterOffset (northing, easting) [xyz].
Vector3 addMetersToLngLat(Vector3 lngLatZ, Vector3 xyz) {
  final lng = lngLatZ[0], lat = lngLatZ[1], z0 = lngLatZ[2];
  final x = xyz[0], y = xyz[1], z = xyz[2];

  final distanceScales = getDistanceScales(lng, lat, highPrecision: true);
  final unitsPerMeter = distanceScales['unitsPerMeter']!;
  final unitsPerMeter2 = distanceScales['unitsPerMeter2']!;

  final worldspace = lngLatToWorld(lng, lat);
  worldspace[0] += x * (unitsPerMeter[0] + unitsPerMeter2[0] * y);
  worldspace[1] += y * (unitsPerMeter[1] + unitsPerMeter2[1] * y);

  final newLngLat = worldToLngLat(worldspace[0], worldspace[1]);
  final newZ = z0 + z;

  return Vector3(newLngLat[0], newLngLat[1], newZ);
}
