import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class PickedPlace extends StatelessWidget {
  final LatLng localizacao;

  const PickedPlace({super.key, required this.localizacao});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Localização picked")),
      body: Column(
        children: [
          Text('Lat: ${localizacao.latitude}', style: TextStyle(fontSize: 25)),
          Text('Lng: ${localizacao.longitude}', style: TextStyle(fontSize: 25)),
        ],
      ),
    );
  }
}
