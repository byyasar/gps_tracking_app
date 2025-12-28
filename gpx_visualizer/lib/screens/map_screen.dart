import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gpx_visualizer/services/gpx_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gpx_visualizer/screens/saved_routes_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  List<LatLng> _routePoints = [];
  final GpxService _gpxService = GpxService();
  // Distance calculation added
  double _totalDistance = 0.0;

  bool _isLoading = false;
  LatLng? _currentLocation;
  Timer? _locationTimer;
  bool _isLiveLocationEnabled = false;
  
  bool _isRecording = false;
  List<LatLng> _recordedPath = [];

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  void _toggleLiveLocation(bool value) {
    setState(() {
      _isLiveLocationEnabled = value;
    });

    if (value) {
      _determinePosition(); // Initial update
      _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _determinePosition();
      });
    } else {
      _locationTimer?.cancel();
      _locationTimer = null;
    }
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Location services are disabled.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Location permissions are denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('Location permissions are permanently denied.');
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
    });
    
    // If live location is enabled (and timer is running), update map center but keep zoom
    // If it's the first load (e.g. no GPX), we might want to default to something, 
    // but the user specific request is "gps konumu değiştiğinde zoom değişmesin".
    // So we use current zoom.
    
    if (_isRecording && _currentLocation != null) {
      _recordedPath.add(_currentLocation!);
      // Update the visual route on map in real-time?
      // For now, let's keep _routePoints strictly for "loaded/viewed" route
      // and maybe use a secondary polyline for "recording" path?
      // Or just append to _routePoints?
      // Appending to _routePoints gives immediate feedback.
       if (!_routePoints.contains(_currentLocation!)) {
          setState(() {
            _routePoints.add(_currentLocation!);
            // Update distance in real-time
            if (_routePoints.length > 1) {
              _totalDistance += const Distance().as(LengthUnit.Meter, _routePoints[_routePoints.length - 2], _currentLocation!);
            }
          });
       }
    }

    if (_routePoints.isEmpty || _isLiveLocationEnabled) {
       // If manual center button was pressed, or live toggle is on, follow user.
       // However, _determinePosition is called by both.
       
       // CAUTION: The user only said "when gps changes, zoom shouldn't change".
       // They imply they want the map to follow them (change center) but keep zoom.
       // So we use _mapController.camera.zoom.
       
       // Only move if we are in "following" mode (implied by live location enabled or initial load)
        _mapController.move(_currentLocation!, _mapController.camera.zoom);
    }
  }

  Future<void> _pickAndLoadGpx() async {
    setState(() {
      _isLoading = true;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any, // Using any for broader compatibility, ideally 'custom' with extensions
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        String gpxString = await file.readAsString();
        List<LatLng> points = _gpxService.parseGpx(gpxString);

          if (points.isNotEmpty) {
            setState(() {
              _routePoints = points;
              _totalDistance = _gpxService.calculateTotalDistance(points);
            });
            _centerMapOnRoute(points);
          } else {
          _showSnackBar('No valid track points found in GPX file.');
        }
      }
    } catch (e) {
      _showSnackBar('Error loading GPX file: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // Stop recording
      setState(() {
        _isRecording = false;
        _isLoading = true;
      });

      final path = await _gpxService.saveRoute(_recordedPath);
      
      setState(() {
        _isLoading = false;
        _recordedPath.clear(); // Clear recorded path after saving (or keep it displayed?)
        // Let's clear the recorded path for now, as it's saved.
        // Or we could keep _routePoints populated with it?
        // User flow: Record -> Stop -> Saved.
        // Maybe we want to see what we just recorded.
        // For now, let's just notify.
      });

      if (path != null) {
        _showSnackBar('Route saved to $path');
      } else {
        _showSnackBar('Failed to save route (no points recorded?)');
      }
    } else {
      // Start recording
      setState(() {
        _isRecording = true;
        _recordedPath = [];
        // Optional: clear existing route on map when starting new recording?
        // _routePoints = []; 
        _totalDistance = 0.0;
      });
      _showSnackBar('Recording started...');
    }
  }

  Future<void> _openSavedRoutes() async {
    final File? selectedFile = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SavedRoutesScreen()),
    );

    if (selectedFile != null) {
      // Load the selected file
      setState(() {
        _isLoading = true;
      });
      try {
        String gpxString = await selectedFile.readAsString();
        List<LatLng> points = _gpxService.parseGpx(gpxString);
        if (points.isNotEmpty) {
           setState(() {
             _routePoints = points;
             _totalDistance = _gpxService.calculateTotalDistance(points);
           });
           _centerMapOnRoute(points);
        }
      } catch (e) {
        _showSnackBar('Error loading route: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _centerMapOnRoute(List<LatLng> points) {
    if (points.isEmpty) return;
    
    // Simple bounding box calculation
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLon = points.first.longitude;
    double maxLon = points.first.longitude;

    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }

    LatLng center = LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2);
    
    // User requested to preserve zoom level when loading GPX.
    // So we move the center but keep the current zoom.
    _mapController.move(center, _mapController.camera.zoom);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPX Visualizer'),
        actions: [
          Row(
            children: [
              const Text("Live GPS", style: TextStyle(fontSize: 12)),
              Switch(
                value: _isLiveLocationEnabled,
                onChanged: _toggleLiveLocation,
                activeColor: Colors.blue,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(41.0082, 28.9784), // Istanbul default
              initialZoom: 10.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.gpx_visualizer',
              ),
              PolylineLayer(
                polylines: [
                  if (_routePoints.isNotEmpty)
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 4.0,
                      color: Colors.red,
                    ),
                ],
              ),
              if (_currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.person_pin_circle,
                        color: Colors.blue,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            left: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Text(
                _totalDistance >= 1000
                    ? '${(_totalDistance / 1000).toStringAsFixed(2)} km'
                    : '${_totalDistance.toStringAsFixed(0)} m',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: "zoom_in",
            onPressed: () {
              final camera = _mapController.camera;
              _mapController.move(camera.center, camera.zoom + 1);
            },
            tooltip: 'Zoom In',
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: "zoom_out",
            onPressed: () {
              final camera = _mapController.camera;
              _mapController.move(camera.center, camera.zoom - 1);
            },
            tooltip: 'Zoom Out',
            child: const Icon(Icons.remove),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: "center_location",
            onPressed: () {
              if (_currentLocation != null) {
                _mapController.move(_currentLocation!, _mapController.camera.zoom);
              } else {
                _determinePosition();
              }
            },
            tooltip: 'Center on Location',
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "open_file",
            onPressed: () {
              // Show modal bottom sheet or simple dialog to choose between File Picker and Saved Routes
              showModalBottomSheet(
                context: context,
                builder: (context) {
                  return Wrap(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.folder_open),
                        title: const Text('Open GPX File'),
                        onTap: () {
                          Navigator.pop(context);
                          _pickAndLoadGpx();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.list),
                        title: const Text('Saved Routes'),
                        onTap: () {
                          Navigator.pop(context);
                          _openSavedRoutes();
                        },
                      ),
                    ],
                  );
                },
              );
            },
            tooltip: 'Open',
            child: const Icon(Icons.folder),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "record_route",
            onPressed: _toggleRecording,
            backgroundColor: _isRecording ? Colors.red : null,
            tooltip: _isRecording ? 'Stop Recording' : 'Start Recording',
            child: Icon(_isRecording ? Icons.stop : Icons.fiber_manual_record),
          ),
        ],
      ),
    );
  }
}
