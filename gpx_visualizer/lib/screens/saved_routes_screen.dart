import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import '../services/gpx_service.dart';

class SavedRoutesScreen extends StatefulWidget {
  const SavedRoutesScreen({Key? key}) : super(key: key);

  @override
  State<SavedRoutesScreen> createState() => _SavedRoutesScreenState();
}

class _SavedRoutesScreenState extends State<SavedRoutesScreen> {
  final GpxService _gpxService = GpxService();
  List<File> _routes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    final routes = await _gpxService.getSavedRoutes();
    setState(() {
      _routes = routes;
      _isLoading = false;
    });
  }

  Future<void> _deleteRoute(File file) async {
    try {
      await file.delete();
      _loadRoutes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Route deleted')),
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error deleting file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Routes'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _routes.isEmpty
              ? const Center(child: Text('No saved routes found'))
              : ListView.builder(
                  itemCount: _routes.length,
                  itemBuilder: (context, index) {
                    final file = _routes[index];
                    final String fileName = path.basename(file.path);
                    return ListTile(
                      leading: const Icon(Icons.map),
                      title: Text(fileName),
                      subtitle: Text('Size: ${(file.lengthSync() / 1024).toStringAsFixed(1)} KB'),
                      onTap: () {
                        // Return the file back to the map screen
                        Navigator.pop(context, file);
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteRoute(file),
                      ),
                    );
                  },
                ),
    );
  }
}
