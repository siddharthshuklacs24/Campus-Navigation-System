import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

import '../models/node.dart';
import '../services/node_service.dart';
import '../services/graph_service.dart';
import '../services/navigation_controller.dart';
import 'outdoor_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<Node> nodes = [];
  Map<String, List<String>> connections = {};

  NavMode selectedMode = NavMode.indoor;

  String currentFloor = "FG";
  String? startNodeId;
  String? endNodeId;

  List<String> path = [];
  List<String> recentSearches = [];

  List<String> availableFloors = ["FG", "F1"];
  bool isPathActive = false;

  final SearchController startSearchController = SearchController();
  final SearchController endSearchController = SearchController();

  // ── Coordinate space in which node x/y values are defined ──────────────
  // These must match the aspect ratio of your PNG files.
  // If nodes still look off after reverting, print your actual image sizes
  // (see _debugImageDimensions below) and update these values to match.
  final Map<String, Size> plotDimensions = {
    "FG": const Size(760.0, 480.0),
    "F1": const Size(760.0, 180.0),
  };

  static const Map<String, String> _floorImagePaths = {
    "FG": 'assets/images/indoor/mess/ground_floorDigital.png',
    "F1": 'assets/images/indoor/mess/FLOOR1Digital.png',
  };

  @override
  void initState() {
    super.initState();
    loadData();
    _debugImageDimensions(); // ← remove once you've verified dimensions
  }

  /// Prints the actual pixel size of each floor image to the debug console.
  /// Compare these against plotDimensions — the ASPECT RATIOS must match
  /// (e.g. if the PNG is 1520×960, plotDimensions should be 760×480 ✓).
  /// If they don't match, update plotDimensions to mirror the real ratio.
  void _debugImageDimensions() {
    for (final entry in _floorImagePaths.entries) {
      final stream =
          AssetImage(entry.value).resolve(ImageConfiguration.empty);
      stream.addListener(ImageStreamListener((info, _) {
        debugPrint(
          '[MapScreen] Floor ${entry.key} → '
          'image: ${info.image.width}×${info.image.height}  |  '
          'plotDimensions: ${plotDimensions[entry.key]}',
        );
      }));
    }
  }

  void loadData() async {
    final loadedNodes = await NodeService.loadNodes();
    final graph = await GraphService.buildGraph();
    if (!mounted) return;
    setState(() {
      nodes = loadedNodes;
      connections = graph;
    });
  }

  Future<void> switchFloorAnimated(String newFloor) async {
    if (newFloor == currentFloor) return;
    setState(() => currentFloor = newFloor);
  }

  void saveRecent(String id) {
    setState(() {
      recentSearches.remove(id);
      recentSearches.insert(0, id);
      if (recentSearches.length > 5) recentSearches.removeLast();
    });
  }

  void calculatePathIfReady() async {
    if (startNodeId == null || endNodeId == null) return;

    final result = await getPath(
      mode: NavMode.indoor,
      source: startNodeId!,
      destination: endNodeId!,
    );

    final newPath = result.map((p) {
      final node = nodes.firstWhere(
        (n) => (n.x - p.latitude).abs() < 1 && (n.y - p.longitude).abs() < 1,
      );
      return node.id;
    }).toList();

    final Set<String> floorsInPath = {};
    for (final nodeId in newPath) {
      final node = nodes.firstWhereOrNull((n) => n.id == nodeId);
      if (node != null) floorsInPath.add(node.floor.trim().toUpperCase());
    }
    final filtered =
        ["FG", "F1"].where((f) => floorsInPath.contains(f)).toList();

    setState(() {
      path = newPath;
      availableFloors = filtered.isNotEmpty ? filtered : ["FG", "F1"];
      isPathActive = filtered.isNotEmpty;
      if (!availableFloors.contains(currentFloor) &&
          availableFloors.isNotEmpty) {
        currentFloor = availableFloors.first;
      }
    });
  }

  void resetNavigation() {
    setState(() {
      startNodeId = null;
      endNodeId = null;
      path = [];
      availableFloors = ["FG", "F1"];
      isPathActive = false;
      startSearchController.clear();
      endSearchController.clear();
    });
  }

  String getMapImage() => _floorImagePaths[currentFloor]!;

  String formatNodeName(String rawId) {
    if (rawId.contains('_')) {
      final parts = rawId.split('_');
      final floorPrefix = parts[0];
      parts.removeAt(0);
      final name =
          parts.map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
      return "$name ($floorPrefix)";
    }
    return rawId;
  }

  @override
  Widget build(BuildContext context) {
    final currentFloorNodes = nodes
        .where((n) =>
            n.floor.trim().toUpperCase() == currentFloor.trim().toUpperCase())
        .toList();

    final screenWidth = MediaQuery.of(context).size.width;

    final plotSize =
        plotDimensions[currentFloor] ?? const Size(760.0, 480.0);

    // Uniform scale: fit plot width → screen width; height follows same ratio.
    // Both axes use the SAME scale so nodes never drift vertically.
    final double scale = screenWidth / plotSize.width;
    final double renderHeight = plotSize.height * scale;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text("Campus Navigator"),
        actions: [
          Row(
            children: [
              ChoiceChip(
                label: const Text("Indoor"),
                selected: selectedMode == NavMode.indoor,
                onSelected: (_) =>
                    setState(() => selectedMode = NavMode.indoor),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text("Outdoor"),
                selected: selectedMode == NavMode.outdoor,
                onSelected: (_) {
                  setState(() => selectedMode = NavMode.outdoor);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const OutdoorScreen()),
                  );
                },
              ),
            ],
          ),
          DropdownButton<String>(
            value: availableFloors.contains(currentFloor)
                ? currentFloor
                : availableFloors.first,
            underline: const SizedBox(),
            items: availableFloors.map((f) {
              return DropdownMenuItem(
                value: f,
                child: Text(f == "FG" ? "Ground Floor" : "Floor $f"),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) switchFloorAnimated(val);
            },
          ),
          if (isPathActive)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: "Clear route & show all floors",
              onPressed: resetNavigation,
            ),
        ],
      ),
      body: Stack(
        children: [
          InteractiveViewer(
            minScale: 1.0,
            maxScale: 5.0,
            boundaryMargin: const EdgeInsets.all(20),
            child: Center(
              child: SizedBox(
                width: screenWidth,
                height: renderHeight,
                child: Stack(
                  alignment: Alignment.topLeft,
                  clipBehavior: Clip.none,
                  children: [
                    Image.asset(
                      getMapImage(),
                      width: screenWidth,
                      height: renderHeight,
                      fit: BoxFit.fill,
                      alignment: Alignment.topLeft,
                    ),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: GraphPainter(
                          nodes,
                          currentFloor,
                          connections,
                          path,
                          scale,
                          scale,
                        ),
                      ),
                    ),
                    ...currentFloorNodes.map((node) {
                      const double iconSize = 24.0;
                      return Positioned(
                        left: (node.x * scale) - (iconSize / 2),
                        top: (node.y * scale) - iconSize,
                        child: Icon(
                          Icons.location_on,
                          size: iconSize,
                          color: node.id == startNodeId
                              ? Colors.green
                              : node.id == endNodeId
                                  ? Colors.orange
                                  : Colors.blue,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
          // Search overlay
          Positioned(
            top: 20,
            left: 16,
            right: 16,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                constraints: const BoxConstraints(maxWidth: 520),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 25,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    buildModernSearchField(
                      "From",
                      Icons.my_location,
                      Colors.green,
                      startSearchController,
                      (id) {
                        startNodeId = id;
                        saveRecent(id);
                        calculatePathIfReady();
                      },
                    ),
                    const SizedBox(height: 10),
                    buildModernSearchField(
                      "To",
                      Icons.location_on,
                      Colors.orange,
                      endSearchController,
                      (id) {
                        endNodeId = id;
                        saveRecent(id);
                        calculatePathIfReady();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildModernSearchField(
    String label,
    IconData icon,
    Color color,
    SearchController controller,
    Function(String) onSelected,
  ) {
    return SearchAnchor(
      searchController: controller,
      builder: (context, controller) {
        return GestureDetector(
          onTap: () => controller.openView(),
          child: AbsorbPointer(
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: label,
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      suggestionsBuilder: (context, controller) {
        final keyword = controller.text.toLowerCase();
        final filtered = keyword.isEmpty
            ? nodes
            : nodes.where(
                (n) => formatNodeName(n.id).toLowerCase().contains(keyword));

        final recentWidgets = recentSearches.map((id) {
          return ListTile(
            leading: const Icon(Icons.history, color: Colors.grey),
            title: Text(formatNodeName(id),
                style: const TextStyle(color: Colors.black)),
            onTap: () {
              controller.closeView(formatNodeName(id));
              onSelected(id);
            },
          );
        }).toList();

        final searchWidgets = filtered.map((n) {
          return ListTile(
            leading: const Icon(Icons.place, color: Colors.blue),
            title: Text(formatNodeName(n.id),
                style: const TextStyle(color: Colors.black)),
            onTap: () {
              controller.closeView(formatNodeName(n.id));
              onSelected(n.id);
            },
          );
        }).toList();

        return [
          if (recentSearches.isNotEmpty && keyword.isEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text("Recent Searches",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.black87)),
            ),
            ...recentWidgets,
            const Divider(),
          ],
          ...searchWidgets,
        ];
      },
    );
  }
}

class GraphPainter extends CustomPainter {
  final List<Node> nodes;
  final String floor;
  final Map<String, List<String>> connections;
  final List<String> path;
  final double scaleX;
  final double scaleY;

  GraphPainter(this.nodes, this.floor, this.connections, this.path,
      this.scaleX, this.scaleY);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 4
      ..color = Colors.blueAccent
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < path.length - 1; i++) {
      final a = nodes.firstWhereOrNull((n) => n.id == path[i]);
      final b = nodes.firstWhereOrNull((n) => n.id == path[i + 1]);

      if (a == null || b == null) continue;
      if (a.floor.trim().toUpperCase() != floor.trim().toUpperCase()) continue;
      if (b.floor.trim().toUpperCase() != floor.trim().toUpperCase()) continue;

      canvas.drawLine(
        Offset(a.x * scaleX, a.y * scaleY),
        Offset(b.x * scaleX, b.y * scaleY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}