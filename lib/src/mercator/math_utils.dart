part of web_mercator;

const PI_2 = pi * .5;
const PI_4 = pi * .25;

num log2(num x) => log(x) / log(2);
num zoomToScale(double zoom) => pow(2, zoom);
num scaleToZoom(double scale) => log2(scale);

/// Generates a perspective projection matrix with the given bounds.
/// see: [gl-matrix/mat4.js](https://github.com/toji/gl-matrix/blob/master/src/mat4.js)
Matrix4 perspective(
    {required double fovy, required double aspect, double? near, double? far}) {
  final out = Matrix4.zero();
  final f = 1.0 / tan(fovy / 2);

  out[0] = f / aspect;
  out[5] = f;
  out[11] = -1;

  if (far != null && !far.isInfinite) {
    final nf = 1 / (near! - far);
    out[10] = (far + near) * nf;
    out[14] = (2 * far * near) * nf;
  } else {
    out[10] = -1;
    out[14] = -2 * near!;
  }

  return out;
}

/// Transforms a [vector] with a projection [matrix].
Vector4 transformVector(Vector4 vector, Matrix4 matrix) {
  final res = vector.clone();
  res.applyMatrix4(matrix);
  return res.scaled(1 / res[3]);
}

Matrix4 getViewMatrix({
  required num height,
  required double pitch,
  required double bearing,
  required double altitude,
  required double scale,
  Vector2? center,
}) {
  scale /= height;
  final vm = Matrix4.identity()
    ..translate(.0, .0, -altitude)
    ..rotateX(-pitch * degrees2Radians)
    ..rotateZ(bearing * degrees2Radians)
    ..scale(scale, scale, scale);

  if (center != null) {
    final centerClone = center.clone();
    centerClone.negate();
    vm.translate(centerClone[0], centerClone[1], .0);
  }

  return vm;
}

Matrix4 getProjMatrix({
  required num width,
  required num height,
  required double pitch,
  required double altitude,
  double? nearZMultiplier,
  required double farZMultiplier,
}) {
  final projParams = getProjParameters(
    width,
    height,
    altitude: altitude,
    pitch: pitch,
    nearZMultiplier: nearZMultiplier,
    farZMultiplier: farZMultiplier,
  );

  return perspective(
    fovy: projParams['fov'] as double,
    aspect: projParams['aspect'] as double,
    near: projParams['near'] as double?,
    far: projParams['far'] as double?,
  );
}

/// Project flat coordinates [xyz] to pixels on screen given the [pixelProjMatrix].
Vector4 worldToPixels(Vector3 xyz, Matrix4 pixelProjMatrix) {
  final x = xyz[0], y = xyz[1], z = xyz[2];
  assert(x.isFinite && y.isFinite && z.isFinite);

  return transformVector(Vector4(x, y, z, 1), pixelProjMatrix);
}

/// Unproject [xyz] pixels on screen to flat coordinates given the [pixelUnprojMatrix].
Vector pixelsToWorld(Vector3 xyz, Matrix4? pixelUnprojMatrix,
    {double? targetZ}) {
  final x = xyz[0], y = xyz[1], z = xyz[2];
  assert(x.isFinite && y.isFinite, 'invalid pixel coordinate');

  if (z.isFinite) {
    final coord = transformVector(Vector4(x, y, z, 1), pixelUnprojMatrix!);
    return coord;
  }

  /// unproject two points to get a line and then find the point on that line with z=0
  final coord0 = transformVector(Vector4(x, y, 0, 1), pixelUnprojMatrix!);
  final coord1 = transformVector(Vector4(x, y, 1, 1), pixelUnprojMatrix);

  final z0 = coord0[2], z1 = coord1[2];
  final t = z0 == z1 ? 0 : ((targetZ ?? 0) - z0) / (z1 - z0);

  /// lerp
  final ax = coord0[0], ay = coord0[1];
  return Vector2(ax + t * (coord1[0] - ax), ay + t * (coord1[1] - ay));
}
