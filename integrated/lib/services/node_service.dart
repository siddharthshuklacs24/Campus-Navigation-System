import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/node.dart';
import 'package:latlong2/latlong.dart';

class NodeService {
  static Future<List<Node>> loadNodes() async {
    try {
      // ✅ FIX: Added 'indoor/' to perfectly match your pubspec.yaml
      final String f1String = await rootBundle.loadString('assets/nodes/indoor/mess/floor1.json');
      final String fgString = await rootBundle.loadString('assets/nodes/indoor/mess/ground_floor.json');

      final List<dynamic> f1Json = json.decode(f1String);
      final List<dynamic> fgJson = json.decode(fgString);

      final combined = [...f1Json, ...fgJson];
      return combined.map((json) => Node.fromJson(json)).toList();
    } catch (e) {
      debugPrint("Error loading indoor nodes: $e");
      return [];
    }
  }

  static Future<Map<String, LatLng>> getNodeCoordinates() async {
    final nodes = await loadNodes();
    final Map<String, LatLng> nodeMap = {};
    for (var node in nodes) {
      nodeMap[node.id] = LatLng(node.x, node.y);
    }
    return nodeMap;
  }

  static Future<Map<String, LatLng>> getOutdoorNodeCoordinates() async {
    try {
      const String path = 'assets/nodes/outdoor/nodes.json';
      final String response = await rootBundle.loadString(path);
      final Map<String, dynamic> data = json.decode(response);
      
      return data.map((key, value) {
        return MapEntry(
          key, 
          LatLng(value[0] as double, value[1] as double)
        );
      });
    } catch (e) {
      debugPrint("Error loading outdoor nodes: $e");
      return {};
    }
  }

  static Future<Map<String, List<String>>> getOutdoorAdjacencyList() async {
    try {
      // MATCHES YAML EXACTLY
      const String path = 'assets/connections/outdoor/roads.json';
      
      final String response = await rootBundle.loadString(path);
      final Map<String, dynamic> data = json.decode(response);
      
      return data.map((key, value) {
        return MapEntry(
          key, 
          List<String>.from(value as List)
        );
      });
    } catch (e) {
      debugPrint("Error loading outdoor roads from connections folder: $e");
      return {};
    }
  }
}