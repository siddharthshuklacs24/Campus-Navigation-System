import 'dart:convert';
import 'package:flutter/services.dart';

class ConnectionService {
  static Future<Map<String, List<String>>> loadConnections() async {
    // ✅ FIX: Added 'indoor/'
    final data = await rootBundle.loadString(
      'assets/connections/indoor/mess/floor1.json',
    );

    final Map<String, dynamic> jsonResult = json.decode(data);

    return jsonResult.map((key, value) {
      return MapEntry(
        key,
        List<String>.from(value),
      );
    });
  }

  static Future<Map<String, List<String>>> loadGroundConnections() async {
    // ✅ FIX: Added 'indoor/'
    final data = await rootBundle.loadString(
      'assets/connections/indoor/mess/ground_floor.json',
    );

    final Map<String, dynamic> jsonResult = json.decode(data);

    return jsonResult.map((key, value) {
      return MapEntry(key, List<String>.from(value));
    });
  }

  static Future<Map<String, List<String>>> loadInterFloorConnections() async {
    // ✅ FIX: Added 'indoor/'
    final data = await rootBundle.loadString(
      'assets/connections/indoor/mess/inter_floor.json',
    );

    final Map<String, dynamic> jsonResult = json.decode(data);

    return jsonResult.map((key, value) {
      return MapEntry(key, List<String>.from(value));
    });
  }

  static Future<Map<String, List<String>>> loadOutdoorConnections() async {
    final data = await rootBundle.loadString(
      'assets/connections/outdoor/roads.json',
    );
    final Map<String, dynamic> jsonResult = json.decode(data);
    return jsonResult.map((key, value) => MapEntry(key, List<String>.from(value)));
  }

  static Future<Map<String, List<String>>> getConnections() async {
    final floor1 = await loadConnections();
    final ground = await loadGroundConnections();
    final inter = await loadInterFloorConnections();

    final combined = <String, List<String>>{};

    void merge(Map<String, List<String>> map) {
      for (var entry in map.entries) {
        combined.putIfAbsent(entry.key, () => []);
        combined[entry.key]!.addAll(entry.value);
      }
    }

    merge(floor1);
    merge(ground);
    merge(inter);

    return combined;
  }
}