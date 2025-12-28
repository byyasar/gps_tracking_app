import 'dart:io';
import 'package:gpx/gpx.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class GpxService {
  /// GPX XML dizesini ayrıştırır ve iz için LatLng noktalarının bir listesini döndürür.
  List<LatLng> parseGpx(String gpxString) {
    try {
      final xmlGpx = GpxReader().fromString(gpxString);
      final List<LatLng> points = [];

      if (xmlGpx.trks.isNotEmpty) {
        for (var trk in xmlGpx.trks) {
          for (var seg in trk.trksegs) {
            for (var pt in seg.trkpts) {
              if (pt.lat != null && pt.lon != null) {
                points.add(LatLng(pt.lat!, pt.lon!));
              }
            }
          }
        }
      }
      return points;
    } catch (e) {
      // ignore: avoid_print
      print('GPX ayrıştırma hatası: $e');
      return [];
    }
  }

  /// Nokta listesini bir GPX dosyası olarak kaydeder.
  Future<String?> saveRoute(List<LatLng> points) async {
    if (points.isEmpty) return null;

    final gpx = Gpx();
    final trk = Trk();
    final seg = Trkseg();

    for (var point in points) {
      seg.trkpts.add(Wpt(lat: point.latitude, lon: point.longitude));
    }

    trk.trksegs.add(seg);
    gpx.trks.add(trk);
    gpx.creator = "Flutter GPX Visualizer";

    final gpxString = GpxWriter().asString(gpx, pretty: true);
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final String fileName = 'route_$timestamp.gpx';
      final File file = File('${directory.path}/$fileName');
      
      await file.writeAsString(gpxString);
      return file.path;
    } catch (e) {
      print('GPX kaydetme hatası: $e');
      return null;
    }
  }

  /// Kaydedilen GPX dosyalarının bir listesini döndürür.
  Future<List<File>> getSavedRoutes() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final List<FileSystemEntity> entities = directory.listSync();
      
      return entities
          .whereType<File>()
          .where((file) => file.path.endsWith('.gpx'))
          .toList()
          ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync())); // En yeni en üstte
    } catch (e) {
      print('Dosya listeleme hatası: $e');
      return [];
    }
  }

  /// Rotanın toplam mesafesini metre cinsinden hesaplar.
  // Mesafe hesaplama eklendi
  double calculateTotalDistance(List<LatLng> points) {
    if (points.length < 2) return 0.0;
    
    final Distance distance = Distance();
    double totalDistance = 0.0;

    for (int i = 0; i < points.length - 1; i++) {
      totalDistance += distance.as(LengthUnit.Meter, points[i], points[i + 1]);
    }

    return totalDistance;
  }
}
