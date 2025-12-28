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

  /// Kaynakları serbest bırakır.
  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  /// Canlı konum takibini açar veya kapatır.
  void _toggleLiveLocation(bool value) {
    setState(() {
      _isLiveLocationEnabled = value;
    });

    if (value) {
      _determinePosition(); // İlk güncelleme
      _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _determinePosition();
      });
    } else {
      _locationTimer?.cancel();
      _locationTimer = null;
    }
  }

  /// Mevcut konumu belirler ve izinleri kontrol eder.
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Konum servisleri kapalı.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Konum izni reddedildi');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('Konum izni kalıcı olarak reddedildi.');
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
    });
    
    // Canlı konum açıksa (ve zamanlayıcı çalışıyorsa), harita merkezini güncelle ama yakınlaştırmayı koru
    // İlk yükleme ise (örn. GPX yoksa), varsayılan bir yere gitmek isteyebiliriz,
    // ancak kullanıcı isteği "gps konumu değiştiğinde zoom değişmesin".
    // Bu yüzden mevcut yakınlaştırmayı kullanıyoruz.
    
    if (_isRecording && _currentLocation != null) {
      _recordedPath.add(_currentLocation!);
      // Rotayı haritada gerçek zamanlı güncelle?
      // Şimdilik _routePoints'i sadece "yüklenen/görüntülenen" rota için tutalım
      // ve belki "kaydedilen" yol için ikincil bir çoklu çizgi kullanalım?
      // Veya sadece _routePoints'e ekleyelim?
      // _routePoints'e eklemek anında geri bildirim verir.
       if (!_routePoints.contains(_currentLocation!)) {
          setState(() {
            _routePoints.add(_currentLocation!);
            // Mesafeyi gerçek zamanlı güncelle
            if (_routePoints.length > 1) {
              _totalDistance += const Distance().as(LengthUnit.Meter, _routePoints[_routePoints.length - 2], _currentLocation!);
            }
          });
       }
    }

    if (_routePoints.isEmpty || _isLiveLocationEnabled) {
       // Manuel merkezleme düğmesine basıldıysa veya canlı geçiş açıksa, kullanıcıyı takip et.
       // Ancak, _determinePosition her ikisi tarafından da çağrılır.
       
       // DİKKAT: Kullanıcı sadece "gps değiştiğinde zoom değişmesin" dedi.
       // Haritanın onları takip etmesini (merkezi değiştirmesini) ama yakınlaştırmayı korumasını ima ediyorlar.
       // Bu yüzden _mapController.camera.zoom kullanıyoruz.
       
       // Sadece "takip etme" modundaysak taşı (canlı konum etkin veya ilk yükleme ile ima edilir)
        _mapController.move(_currentLocation!, _mapController.camera.zoom);
    }
  }

  /// GPX dosyasını seçer ve yükler.
  Future<void> _pickAndLoadGpx() async {
    setState(() {
      _isLoading = true;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any, // Daha geniş uyumluluk için 'any' kullanılıyor, ideal olarak uzantılarla 'custom'
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
          _showSnackBar('GPX dosyasında geçerli iz noktası bulunamadı.');
        }
      }
    } catch (e) {
      _showSnackBar('GPX dosyası yüklenirken hata: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Rota kaydını başlatır veya durdurur.
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // Kaydı durdur
      setState(() {
        _isRecording = false;
        _isLoading = true;
      });

      final path = await _gpxService.saveRoute(_recordedPath);
      
      setState(() {
        _isLoading = false;
        _recordedPath.clear(); // Kaydedildikten sonra kaydedilen yolu temizle (ya da göster?)
        // Şimdilik kaydedilen yolu temizleyelim, çünkü kaydedildi.
        // Veya _routePoints'i bununla dolu tutabiliriz?
        // Kullanıcı akışı: Kaydet -> Durdur -> Kaydedildi.
        // Belki az önce ne kaydettiğimizi görmek isteriz.
        // Şimdilik sadece bildirelim.
      });

      if (path != null) {
        _showSnackBar('Rota kaydedildi: $path');
      } else {
        _showSnackBar('Rota kaydedilemedi (nokta kaydedilmedi mi?)');
      }
    } else {
      // Kaydı başlat
      setState(() {
        _isRecording = true;
        _recordedPath = [];
        // İsteğe bağlı: yeni kayıt başlarken haritadaki mevcut rotayı temizle?
        // _routePoints = []; 
        _totalDistance = 0.0;
      });
      _showSnackBar('Kayıt başladı...');
    }
  }

  /// Kayıtlı rotalar ekranını açar.
  Future<void> _openSavedRoutes() async {
    final File? selectedFile = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SavedRoutesScreen()),
    );

    if (selectedFile != null) {
      // Seçilen dosyayı yükle
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
        _showSnackBar('Rota yüklenirken hata: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Haritayı rota üzerine odaklar.
  void _centerMapOnRoute(List<LatLng> points) {
    if (points.isEmpty) return;
    
    // Basit sınır kutusu hesaplaması
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
    
    // Kullanıcı GPX yüklerken yakınlaştırma seviyesini korumayı istedi.
    // Bu yüzden merkezi taşıyoruz ama mevcut yakınlaştırmayı koruyoruz.
    _mapController.move(center, _mapController.camera.zoom);
  }

  /// Kullanıcıya bildirim mesajı gösterir.
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Ekranı oluşturur.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPX Görselleştirici'),
        actions: [
          Row(
            children: [
              const Text("Canlı GPS", style: TextStyle(fontSize: 12)),
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
              initialCenter: LatLng(41.0082, 28.9784), // İstanbul varsayılan
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
            tooltip: 'Yakınlaş',
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: "zoom_out",
            onPressed: () {
              final camera = _mapController.camera;
              _mapController.move(camera.center, camera.zoom - 1);
            },
            tooltip: 'Uzaklaş',
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
            tooltip: 'Konuma Odaklan',
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "open_file",
            onPressed: () {
              // Gösterilecek alt sayfa veya dosya seçici ile kaydedilmiş rotalar arasında seçim yapma penceresi
              showModalBottomSheet(
                context: context,
                builder: (context) {
                  return Wrap(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.folder_open),
                        title: const Text('GPX Dosyası Aç'),
                        onTap: () {
                          Navigator.pop(context);
                          _pickAndLoadGpx();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.list),
                        title: const Text('Kayıtlı Rotalar'),
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
            tooltip: 'Aç',
            child: const Icon(Icons.folder),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "record_route",
            onPressed: _toggleRecording,
            backgroundColor: _isRecording ? Colors.red : null,
            tooltip: _isRecording ? 'Kaydı Durdur' : 'Kaydı Başlat',
            child: Icon(_isRecording ? Icons.stop : Icons.fiber_manual_record),
          ),
        ],
      ),
    );
  }
}
