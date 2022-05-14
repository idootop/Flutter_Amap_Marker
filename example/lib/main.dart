import 'dart:math';

import 'package:amap_flutter_map_example/const_config.dart';
import 'package:flutter/material.dart';

import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';

class MapPage extends StatefulWidget {
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  List<FlutterMarker> _markers = [];

  @override
  void initState() {
    super.initState();
    final rnd = Random();
    _markers = List.generate(
      10,
      (_) => marker(LatLng(
        39.909187 + rnd.nextDouble() * 0.5 * (rnd.nextBool() ? 1 : -1),
        116.397451 + rnd.nextDouble() * 0.5 * (rnd.nextBool() ? 1 : -1),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AMapWidget(
        flutterMarkers: _markers,
        apiKey: ConstConfig.amapApiKeys,
        privacyStatement: ConstConfig.amapPrivacyStatement,
      ),
    );
  }

  FlutterMarker marker(LatLng latlng) => FlutterMarker(
        latlng: latlng,
        child: GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              PageRouteBuilder(
                opaque: false,
                pageBuilder: (context, _, __) => ViewPage(latlng),
              ),
            );
          },
          child: Hero(
            tag: 'marker$latlng',
            child: FlutterLogo(
              size: 64,
            ),
          ),
        ),
      );
}

class ViewPage extends StatelessWidget {
  final LatLng latlng;
  ViewPage(this.latlng);
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.black45,
        body: Center(
          child: Hero(
            tag: 'marker$latlng',
            child: FlutterLogo(
              size: 256,
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(home: MapPage()));
}
