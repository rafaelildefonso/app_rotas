import 'package:geolocator/geolocator.dart';

Future<Position> getCurrentLocation() async {
  bool serviceEnabled;
  LocationPermission permission;

  // Verifica se o serviço de localização está ativo
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return Future.error('Serviço de localização desativado');
  }

  // Verifica permissão
  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return Future.error('Permissão de localização negada');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    return Future.error('Permissão permanentemente negada');
  }

  // Pega localização
  return await Geolocator.getCurrentPosition();
}

Stream<Position> getLocationStream({LocationAccuracy accuracy = LocationAccuracy.high, int distanceFilter = 10}) {
  return Geolocator.getPositionStream(
    locationSettings: LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
    ),
  );
}
