import 'package:geolocator/geolocator.dart';

Future<Position> getCurrentLocation({bool fallbackToZero = true}) async {
  bool serviceEnabled;
  LocationPermission permission;

  // Verifica se o serviço de localização está ativo
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    if (fallbackToZero) {
      return Position(
        latitude: 0.0,
        longitude: 0.0,
        timestamp: DateTime.now(),
        accuracy: 0.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );
    }
    return Future.error('Serviço de localização desativado');
  }

  // Verifica permissão
  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      if (fallbackToZero) {
        return Position(
          latitude: 0.0,
          longitude: 0.0,
          timestamp: DateTime.now(),
          accuracy: 0.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        );
      }
      return Future.error('Permissão de localização negada');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    if (fallbackToZero) {
      return Position(
        latitude: 0.0,
        longitude: 0.0,
        timestamp: DateTime.now(),
        accuracy: 0.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );
    }
    return Future.error('Permissão permanentemente negada');
  }

  // Pega localização
  return await Geolocator.getCurrentPosition();
}

Stream<Position> getLocationStream({
  LocationAccuracy accuracy = LocationAccuracy.high,
  int distanceFilter = 5,
}) {
  return Geolocator.getPositionStream(
    locationSettings: LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
    ),
  );
}
