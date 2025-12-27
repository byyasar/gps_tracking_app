import 'dart:io';
import 'package:gpx/gpx.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class GpxService {
  /// Parses GPX XML string and returns a list of LatLng points for the track.
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
      print('Error parsing GPX: $e');
      return [];
    }
  }

  /// Saves a list of points as a GPX file
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
      print('Error saving GPX: $e');
      return null;
    }
  }

  /// Returns a list of saved GPX files
  Future<List<File>> getSavedRoutes() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final List<FileSystemEntity> entities = directory.listSync();
      
      return entities
          .whereType<File>()
          .where((file) => file.path.endsWith('.gpx'))
          .toList()
          ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync())); // Newest first
    } catch (e) {
      print('Error listing files: $e');
      return [];
    }
  }
}
