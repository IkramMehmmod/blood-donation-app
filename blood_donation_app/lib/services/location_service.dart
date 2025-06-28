import 'package:location/location.dart';

abstract class LocationService {
  Future<bool> serviceEnabled();
  Future<bool> requestService();
  Future<PermissionStatus> hasPermission();
  Future<PermissionStatus> requestPermission();
  Future<LocationData> getLocation();
  Stream<LocationData> get onLocationChanged;
  Future<bool> changeSettings({
    LocationAccuracy? accuracy,
    int? interval,
    double? distanceFilter,
  });
}

class RealLocationService implements LocationService {
  final Location _location = Location();

  @override
  Future<bool> serviceEnabled() => _location.serviceEnabled();
  @override
  Future<bool> requestService() => _location.requestService();
  @override
  Future<PermissionStatus> hasPermission() => _location.hasPermission();
  @override
  Future<PermissionStatus> requestPermission() => _location.requestPermission();
  @override
  Future<LocationData> getLocation() => _location.getLocation();
  @override
  Stream<LocationData> get onLocationChanged => _location.onLocationChanged;
  @override
  Future<bool> changeSettings({
    LocationAccuracy? accuracy,
    int? interval,
    double? distanceFilter,
  }) =>
      _location.changeSettings(
        accuracy: accuracy,
        interval: interval,
        distanceFilter: distanceFilter,
      );
}
