import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:blood_donation_app/services/location_service.dart';
import 'dart:async';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MapScreen extends StatefulWidget {
  final LocationService? locationService;
  const MapScreen({super.key, this.locationService});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _bloodCenters = [];
  String _selectedFilter = 'All';
  final List<String> _filters = [
    'All',
    'Hospitals',
    'Blood Banks',
    'Donation Centers'
  ];

  // Map controller - initialized later
  MapController? _mapController;
  bool _mapReady = false;

  // Default location (will be updated with user's location)
  LatLng _initialPosition = const LatLng(37.7749, -122.4194); // San Francisco
  double _initialZoom = 12.0;

  // User location
  LocationData? _currentLocation;
  late final LocationService _locationService;

  // Markers
  List<Marker> _markers = [];

  // Search radius in meters (increased from 5000 to 8000)
  final int _searchRadius = 8000;

  @override
  void initState() {
    super.initState();
    // Initialize map controller
    _mapController = MapController();
    _locationService = widget.locationService ?? RealLocationService();
    // Start location request in background
    _initializeLocationAndData();
  }

  Future<void> _initializeLocationAndData() async {
    // First check location permissions without showing loading indicator
    await _checkLocationPermissions();

    // Then get user location
    await _getUserLocation(showLoading: false);
  }

  Future<bool> _checkLocationPermissions() async {
    try {
      bool serviceEnabled = await _locationService.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _locationService.requestService();
        if (!serviceEnabled) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location services are disabled')),
            );
          }
          return false;
        }
      }

      PermissionStatus permissionStatus =
          await _locationService.hasPermission();
      if (permissionStatus == PermissionStatus.denied) {
        permissionStatus = await _locationService.requestPermission();
        if (permissionStatus != PermissionStatus.granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error checking location permissions: $e');
      return false;
    }
  }

  Future<void> _getUserLocation({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Get current location
      _currentLocation = await _locationService.getLocation();

      if (_currentLocation != null && mounted) {
        setState(() {
          _initialPosition =
              LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!);
          _initialZoom = 14.0;
        });

        // Only move map if it's ready
        if (_mapReady && _mapController != null) {
          _mapController!.move(_initialPosition, _initialZoom);
        }

        // Fetch nearby blood centers
        await _fetchNearbyBloodCenters();
      }
    } catch (e) {
      debugPrint('Error getting user location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    } finally {
      if (showLoading && mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchNearbyBloodCenters() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Use the Overpass API to fetch real POIs
      await _fetchRealNearbyBloodCenters();
    } catch (e) {
      debugPrint('Error fetching blood centers: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching nearby centers: $e')),
        );
      }
      // Fall back to sample data if API fails
      _generateSampleBloodCenters();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchRealNearbyBloodCenters() async {
    try {
      final lat = _currentLocation?.latitude ?? _initialPosition.latitude;
      final lon = _currentLocation?.longitude ?? _initialPosition.longitude;

      // Overpass API query to find hospitals, clinics, and blood banks
      // Increased search radius from 5000 to 8000 meters
      final query = """
        [out:json];
        (
          node["amenity"="hospital"](around:$_searchRadius,$lat,$lon);
          node["amenity"="clinic"](around:$_searchRadius,$lat,$lon);
          node["healthcare"="blood_donation"](around:$_searchRadius,$lat,$lon);
          node["amenity"="doctors"](around:$_searchRadius,$lat,$lon);
          node["amenity"="bloodbank"](around:$_searchRadius,$lat,$lon);
        );
        out body;
      """;

      final response = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        body: query,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final elements = data['elements'] as List;

        if (elements.isEmpty) {
          // If no results from API, fall back to sample data
          _generateSampleBloodCenters();
          return;
        }

        final centers = elements.map((element) {
          final tags = element['tags'] as Map<String, dynamic>;
          String type = 'Hospital';

          if (tags['amenity'] == 'clinic' || tags['amenity'] == 'doctors') {
            type = 'Donation Center';
          } else if (tags['healthcare'] == 'blood_donation' ||
              tags['amenity'] == 'bloodbank') {
            type = 'Blood Bank';
          }

          return {
            'id': element['id'].toString(),
            'name': tags['name'] ?? 'Medical Facility',
            'type': type,
            'address': tags['addr:full'] ??
                '${tags['addr:street'] ?? ''} ${tags['addr:housenumber'] ?? ''}',
            'phone': tags['phone'] ?? 'N/A',
            'latitude': element['lat'],
            'longitude': element['lon'],
            'bloodTypes': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
            'operatingHours': tags['opening_hours'] ?? '8:00 AM - 8:00 PM',
            'distance': _calculateDistance(
              lat,
              lon,
              element['lat'],
              element['lon'],
            ),
          };
        }).toList();

        // Sort by distance
        centers.sort((a, b) =>
            (a['distance'] as double).compareTo(b['distance'] as double));

        if (mounted) {
          setState(() {
            _bloodCenters = centers;
            _updateMarkers();
          });
        }
      } else {
        // If API request fails, fall back to sample data
        _generateSampleBloodCenters();
      }
    } catch (e) {
      debugPrint('Error fetching real blood centers: $e');
      // Fall back to sample data
      _generateSampleBloodCenters();
    }
  }

  void _generateSampleBloodCenters() {
    // Generate sample blood centers around the user's location
    final random = Random();
    final List<Map<String, dynamic>> centers = [];

    // Use current location instead of default
    final double baseLat =
        _currentLocation?.latitude ?? _initialPosition.latitude;
    final double baseLng =
        _currentLocation?.longitude ?? _initialPosition.longitude;

    final List<String> hospitalNames = [
      'City General Hospital',
      'Memorial Medical Center',
      'University Hospital',
      'St. Mary\'s Hospital',
      'Community Health Center',
    ];

    final List<String> bloodBankNames = [
      'Red Cross Blood Bank',
      'LifeStream Blood Center',
      'Community Blood Services',
      'BloodSource',
      'United Blood Services',
    ];

    final List<String> donationCenterNames = [
      'Downtown Donation Center',
      'Westside Blood Donation',
      'Eastside Donor Center',
      'Northgate Donation Facility',
      'Southside Blood Collection',
    ];

    // Generate more spread out sample data (increased from 0.05 to 0.08)
    final double spreadFactor = 0.08;

    // Add hospitals
    for (int i = 0; i < hospitalNames.length; i++) {
      final latitude = baseLat + (random.nextDouble() - 0.5) * spreadFactor;
      final longitude = baseLng + (random.nextDouble() - 0.5) * spreadFactor;

      centers.add({
        'id': 'hospital_$i',
        'name': hospitalNames[i],
        'type': 'Hospital',
        'address': '${100 + i} Main Street, City',
        'phone': '(555) ${100 + i}-${1000 + i}',
        'latitude': latitude,
        'longitude': longitude,
        'bloodTypes': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
        'operatingHours': '8:00 AM - 8:00 PM',
        'distance': _calculateDistance(
          baseLat,
          baseLng,
          latitude,
          longitude,
        ),
      });
    }

    // Add blood banks
    for (int i = 0; i < bloodBankNames.length; i++) {
      final latitude = baseLat + (random.nextDouble() - 0.5) * spreadFactor;
      final longitude = baseLng + (random.nextDouble() - 0.5) * spreadFactor;

      centers.add({
        'id': 'blood_bank_$i',
        'name': bloodBankNames[i],
        'type': 'Blood Bank',
        'address': '${200 + i} Oak Avenue, City',
        'phone': '(555) ${200 + i}-${2000 + i}',
        'latitude': latitude,
        'longitude': longitude,
        'bloodTypes': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
        'operatingHours': '9:00 AM - 5:00 PM',
        'distance': _calculateDistance(
          baseLat,
          baseLng,
          latitude,
          longitude,
        ),
      });
    }

    // Add donation centers
    for (int i = 0; i < donationCenterNames.length; i++) {
      final latitude = baseLat + (random.nextDouble() - 0.5) * spreadFactor;
      final longitude = baseLng + (random.nextDouble() - 0.5) * spreadFactor;

      centers.add({
        'id': 'donation_center_$i',
        'name': donationCenterNames[i],
        'type': 'Donation Center',
        'address': '${300 + i} Pine Street, City',
        'phone': '(555) ${300 + i}-${3000 + i}',
        'latitude': latitude,
        'longitude': longitude,
        'bloodTypes': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
        'operatingHours': '10:00 AM - 6:00 PM',
        'distance': _calculateDistance(
          baseLat,
          baseLng,
          latitude,
          longitude,
        ),
      });
    }

    // Sort by distance
    centers.sort(
        (a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

    if (mounted) {
      setState(() {
        _bloodCenters = centers;
        _updateMarkers();
      });
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    // Haversine formula for more accurate distance calculation
    const double earthRadius = 6371.0; // in kilometers

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final distance = earthRadius * c;

    return double.parse(distance.toStringAsFixed(2));
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  List<Map<String, dynamic>> _getFilteredCenters() {
    if (_selectedFilter == 'All') {
      return _bloodCenters;
    } else {
      // Fix the filtering to correctly match the type
      String filterType = _selectedFilter;
      if (filterType == 'Hospitals') filterType = 'Hospital';
      if (filterType == 'Blood Banks') filterType = 'Blood Bank';
      if (filterType == 'Donation Centers') filterType = 'Donation Center';

      return _bloodCenters
          .where((center) => center['type'] == filterType)
          .toList();
    }
  }

  void _updateMarkers() {
    final filteredCenters = _getFilteredCenters();
    final List<Marker> markers = [];

    // Add user location marker if available
    if (_currentLocation != null) {
      markers.add(
        Marker(
          point:
              LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha((255 * 0.7).round()),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(
              Icons.person_pin_circle,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      );
    }

    // Add blood center markers
    for (final center in filteredCenters) {
      final point = LatLng(center['latitude'], center['longitude']);

      // Choose marker color based on center type
      Color markerColor;
      IconData markerIcon;

      switch (center['type']) {
        case 'Hospital':
          markerColor = Colors.red.withAlpha((255 * 0.7).round());
          markerIcon = Icons.local_hospital;
          break;
        case 'Blood Bank':
          markerColor = Colors.blue.withAlpha((255 * 0.7).round());
          markerIcon = Icons.bloodtype;
          break;
        case 'Donation Center':
          markerColor = Colors.green.withAlpha((255 * 0.7).round());
          markerIcon = Icons.volunteer_activism;
          break;
        default:
          markerColor = Colors.purple.withAlpha((255 * 0.7).round());
          markerIcon = Icons.location_on;
      }

      markers.add(
        Marker(
          point: point,
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () {
              _showCenterDetails(context, center);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: markerColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((255 * 0.2).round()),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                markerIcon,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _markers = markers;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredCenters = _getFilteredCenters();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blood Centers Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _getUserLocation();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading && _bloodCenters.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Map view
                Expanded(
                  flex: 1,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _initialPosition,
                          initialZoom: _initialZoom,
                          onMapReady: () {
                            // Set map as ready and move to user location if available
                            setState(() {
                              _mapReady = true;
                            });

                            if (_currentLocation != null &&
                                _mapController != null) {
                              _mapController!.move(
                                  LatLng(_currentLocation!.latitude!,
                                      _currentLocation!.longitude!),
                                  _initialZoom);
                            }
                          },
                          onTap: (_, __) {
                            // Close any open info windows
                          },
                        ),
                        children: [
                          // Fixed OSM tile layer to avoid subdomain warning
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            // Removed subdomains parameter
                            userAgentPackageName:
                                'com.example.blood_donation_app',
                          ),
                          MarkerLayer(markers: _markers),
                          // Current location indicator with increased radius
                          if (_currentLocation != null)
                            CircleLayer(
                              circles: [
                                CircleMarker(
                                  point: LatLng(_currentLocation!.latitude!,
                                      _currentLocation!.longitude!),
                                  radius: 200, // Increased from 100 to 200
                                  color: Colors.blue
                                      .withAlpha((255 * 0.2).round()),
                                  borderColor: Colors.blue
                                      .withAlpha((255 * 0.7).round()),
                                  borderStrokeWidth: 2,
                                ),
                              ],
                            ),
                        ],
                      ),
                      // Map controls
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FloatingActionButton(
                              heroTag: 'zoomIn',
                              mini: true,
                              onPressed: () {
                                if (_mapController != null && _mapReady) {
                                  final currentZoom =
                                      _mapController!.camera.zoom;
                                  _mapController!.move(
                                      _mapController!.camera.center,
                                      currentZoom + 1);
                                }
                              },
                              child: const Icon(Icons.add),
                            ),
                            const SizedBox(height: 8),
                            FloatingActionButton(
                              heroTag: 'zoomOut',
                              mini: true,
                              onPressed: () {
                                if (_mapController != null && _mapReady) {
                                  final currentZoom =
                                      _mapController!.camera.zoom;
                                  _mapController!.move(
                                      _mapController!.camera.center,
                                      currentZoom - 1);
                                }
                              },
                              child: const Icon(Icons.remove),
                            ),
                            const SizedBox(height: 8),
                            FloatingActionButton(
                              heroTag: 'myLocation',
                              mini: true,
                              onPressed: () {
                                if (_currentLocation != null &&
                                    _mapController != null &&
                                    _mapReady) {
                                  _mapController!.move(
                                    LatLng(_currentLocation!.latitude!,
                                        _currentLocation!.longitude!),
                                    15,
                                  );
                                } else {
                                  _getUserLocation();
                                }
                              },
                              child: const Icon(Icons.my_location),
                            ),
                          ],
                        ),
                      ),
                      // Find nearby button
                      Positioned(
                        left: 16,
                        top: 16,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _getUserLocation();
                          },
                          icon: const Icon(Icons.near_me),
                          label: const Text('Find Nearby'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      // Loading indicator overlay
                      if (_isLoading && _bloodCenters.isNotEmpty)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withAlpha((255 * 0.3).round()),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Filter chips
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: Theme.of(context).colorScheme.surface,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: _filters.map((filter) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(filter),
                            selected: _selectedFilter == filter,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedFilter = filter;
                                  _updateMarkers();
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // List of blood centers
                Expanded(
                  flex: 1,
                  child: filteredCenters.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.location_off,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No centers found',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () {
                                  _getUserLocation();
                                },
                                child: const Text('Refresh'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredCenters.length,
                          itemBuilder: (context, index) {
                            final center = filteredCenters[index];
                            return _buildBloodCenterCard(context, center);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildBloodCenterCard(
      BuildContext context, Map<String, dynamic> center) {
    Color typeColor;
    IconData typeIcon;

    switch (center['type']) {
      case 'Hospital':
        typeColor = Colors.red.withAlpha((255 * 0.7).round());
        typeIcon = Icons.local_hospital;
        break;
      case 'Blood Bank':
        typeColor = Colors.blue.withAlpha((255 * 0.7).round());
        typeIcon = Icons.bloodtype;
        break;
      case 'Donation Center':
        typeColor = Colors.green.withAlpha((255 * 0.7).round());
        typeIcon = Icons.volunteer_activism;
        break;
      default:
        typeColor = Colors.grey.withAlpha((255 * 0.7).round());
        typeIcon = Icons.location_on;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // Center map on this location
          if (_mapController != null && _mapReady) {
            _mapController!.move(
              LatLng(center['latitude'], center['longitude']),
              16.0,
            );
          }

          // Show details
          _showCenterDetails(context, center);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: typeColor.withAlpha((255 * 0.1).round()),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      typeIcon,
                      color: typeColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          center['name'],
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        Text(
                          center['type'],
                          style: TextStyle(
                            color: typeColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withAlpha((255 * 0.1).round()),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${center['distance']} km',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      center['address'],
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    center['operatingHours'],
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Open in maps with directions
                        _openMapsWithLocation(center['latitude'],
                            center['longitude'], center['name']);
                      },
                      icon: const Icon(Icons.directions),
                      label: const Text('Directions'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: typeColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Call the center
                        _callPhoneNumber(center['phone']);
                      },
                      icon: const Icon(Icons.phone),
                      label: const Text('Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: typeColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCenterDetails(BuildContext context, Map<String, dynamic> center) {
    Color typeColor;
    IconData typeIcon;

    switch (center['type']) {
      case 'Hospital':
        typeColor = Colors.red.withAlpha((255 * 0.7).round());
        typeIcon = Icons.local_hospital;
        break;
      case 'Blood Bank':
        typeColor = Colors.blue.withAlpha((255 * 0.7).round());
        typeIcon = Icons.bloodtype;
        break;
      case 'Donation Center':
        typeColor = Colors.green.withAlpha((255 * 0.7).round());
        typeIcon = Icons.volunteer_activism;
        break;
      default:
        typeColor = Colors.grey.withAlpha((255 * 0.7).round());
        typeIcon = Icons.location_on;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 60,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300
                              .withAlpha((255 * 0.3).round()),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: typeColor.withAlpha((255 * 0.1).round()),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            typeIcon,
                            color: typeColor,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                center['name'],
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              Text(
                                center['type'],
                                style: TextStyle(
                                  color: typeColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    _buildDetailItem(
                      context,
                      icon: Icons.location_on,
                      title: 'Address',
                      value: center['address'],
                    ),
                    const SizedBox(height: 16),
                    _buildDetailItem(
                      context,
                      icon: Icons.phone,
                      title: 'Phone',
                      value: center['phone'],
                    ),
                    const SizedBox(height: 16),
                    _buildDetailItem(
                      context,
                      icon: Icons.access_time,
                      title: 'Operating Hours',
                      value: center['operatingHours'],
                    ),
                    const SizedBox(height: 16),
                    _buildDetailItem(
                      context,
                      icon: Icons.bloodtype,
                      title: 'Blood Types',
                      value: (center['bloodTypes'] as List<dynamic>).join(', '),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailItem(
                      context,
                      icon: Icons.location_searching,
                      title: 'Distance',
                      value: '${center['distance']} km from your location',
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      'Actions',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              // Open in maps
                              Navigator.pop(context);
                              _openMapsWithLocation(center['latitude'],
                                  center['longitude'], center['name']);
                            },
                            icon: const Icon(Icons.directions),
                            label: const Text('Get Directions'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: typeColor,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Call the center
                              Navigator.pop(context);
                              _callPhoneNumber(center['phone']);
                            },
                            icon: const Icon(Icons.phone),
                            label: const Text('Call Now'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: typeColor,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Navigate to blood request screen instead of donation
                        Navigator.pop(context);
                        Navigator.of(context).pushNamed('/requests');
                      },
                      icon: const Icon(Icons.bloodtype),
                      label: const Text('Make Blood Request'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .primary
                .withAlpha((255 * 0.1).round()),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openMapsWithLocation(
      double latitude, double longitude, String label) async {
    try {
      // Use Google Maps for directions
      final url =
          'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&destination_place_id=$label';

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Fallback for web or if no map app is available
        final fallbackUrl =
            'https://www.openstreetmap.org/directions?from=${_currentLocation?.latitude},${_currentLocation?.longitude}&to=$latitude,$longitude';
        await launchUrl(Uri.parse(fallbackUrl));
      }
    } catch (e) {
      debugPrint('Error opening maps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps application')),
        );
      }
    }
  }

  Future<void> _callPhoneNumber(String phoneNumber) async {
    try {
      final url = 'tel:$phoneNumber';
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch phone dialer')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error making phone call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not make phone call')),
        );
      }
    }
  }
}
