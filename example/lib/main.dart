import 'package:amap_flutter_map_example/const_config.dart';
import 'package:flutter/material.dart';

import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';

class ViewPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.black45,
        body: Center(
          child: Hero(
            tag: 'marker',
            child: FlutterLogo(
              size: 256,
            ),
          ),
        ),
      ),
    );
  }
}

class MapPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    void jumpHero() {
      Navigator.of(context).push(
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (context, _, __) => ViewPage(),
        ),
      );
    }

    return Scaffold(
      body: AMapWidget(
        privacyStatement: ConstConfig.amapPrivacyStatement,
        apiKey: ConstConfig.amapApiKeys,
        flutterMarkers: [
          FlutterMarker(
            latlng: LatLng(39.909187, 116.397451),
            child: GestureDetector(
              onTap: jumpHero,
              child: Hero(
                tag: 'marker',
                child: FlutterLogo(
                  size: 64,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(home: MapPage()));
}
