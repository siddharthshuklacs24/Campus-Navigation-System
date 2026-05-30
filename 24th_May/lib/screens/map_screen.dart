import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:indoor_navigation/services/path_service.dart';

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

  // ✅ FIX: Controller to manage the initial zoom scale and position natively
  final TransformationController _transformationController = TransformationController();

  // ✅ MOBILE-NATIVE REDESIGN: Only the real PNG dimensions matter now.
  final Map<String, Size> pngDimensions = {
    "FG": const Size(1651.0, 1112.0),
    "F1": const Size(831.0, 211.0),
  };

  @override
  void initState() {
    super.initState();
    loadData();
    // ✅ Auto-fit the massive image to the screen on launch
    _fitMapToScreen("FG");
  }

  @override
  void dispose() {
    _transformationController.dispose();
    startSearchController.dispose();
    endSearchController.dispose();
    super.dispose();
  }

  // ✅ UPGRADED MATH: Calculates scale AND translation to dodge the search bar
  void _fitMapToScreen(String floor) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final imgSize = pngDimensions[floor] ?? const Size(1651, 1112);
      
      // 1. Get the real screen dimensions
      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height - kToolbarHeight;
      
      // 2. Reserve space at the top so the map doesn't hide behind the floating search bar
      const double searchBarClearance = 160.0; 
      final double availableHeight = screenHeight - searchBarClearance;
      
      // 3. Calculate how much we need to shrink width and height to fit the REMAINING safe area
      double scaleX = screenWidth / imgSize.width;
      double scaleY = availableHeight / imgSize.height;
      
      // 4. Pick the smaller scale to ensure the ENTIRE map fits perfectly
      double scale = scaleX < scaleY ? scaleX : scaleY;
      if (scale < 0.01) scale = 0.01;

      // 5. Calculate exact X and Y coordinates to center the map in the safe area
      double scaledWidth = imgSize.width * scale;
      double scaledHeight = imgSize.height * scale;
      
      double dx = (screenWidth - scaledWidth) / 2; // Center horizontally
      double dy = searchBarClearance + ((availableHeight - scaledHeight) / 2); // Push down & center vertically

      // 6. Apply both the shift (translate) and the shrink (scale) instantly
      _transformationController.value = Matrix4.identity()
        ..translate(dx, dy)
        ..scale(scale);
    });
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
    // ✅ Re-calculate and fit screen automatically when the floor changes
    _fitMapToScreen(newFloor);
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
    final filtered = ["FG", "F1"].where((f) => floorsInPath.contains(f)).toList();

    setState(() {
      path = newPath;
      availableFloors = filtered.isNotEmpty ? filtered : ["FG", "F1"];
      isPathActive = filtered.isNotEmpty;

      if (!availableFloors.contains(currentFloor) && availableFloors.isNotEmpty) {
        currentFloor = availableFloors.first;
        // ✅ Auto-fit if the floor jumps during path generation
        _fitMapToScreen(currentFloor);
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

  String getMapImage() {
    return currentFloor == "FG"
        ? 'assets/images/indoor/mess/ground_floorDigital.png'
        : 'assets/images/indoor/mess/FLOOR1Digital.png';
  }

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

    // Fetch the EXACT dimensions of the current PNG file
    final imgSize = pngDimensions[currentFloor] ?? const Size(1651, 1112);

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
                onSelected: (_) => setState(() => selectedMode = NavMode.indoor),
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
          // ✅ FIX: Attach the controller and set boundaries to prevent "Touch Snapping"
          InteractiveViewer(
            transformationController: _transformationController,
            constrained: false, 
            
            // ✅ FIX: Lowered to 0.01 to prevent scale-rounding snaps
            minScale: 0.01, 
            maxScale: 5.0,

            // ✅ FIX: Set to double.infinity. This explicitly tells Flutter's physics engine 
            // "Every coordinate is valid. Do NOT auto-correct or snap my map when the user touches it."
            boundaryMargin: const EdgeInsets.all(double.infinity), 
            
            child: GestureDetector(
              // 🔥 NEW TOOL: Tap anywhere on the map to get perfect Mobile JSON coordinates
              onTapUp: (details) {
                final x = details.localPosition.dx.round();
                final y = details.localPosition.dy.round();
                debugPrint('\n📍 NEW NODE COORD DETECTED 📍');
                debugPrint('{"id": "NEW_NODE", "x": $x, "y": $y, "floor": "$currentFloor"}');
              },
              child: SizedBox(
                width: imgSize.width,
                height: imgSize.height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Image.asset(
                      getMapImage(),
                      width: imgSize.width,
                      height: imgSize.height,
                      fit: BoxFit.none, // Do not stretch! Maintain 1:1 pixel mapping
                    ),

                    Positioned.fill(
                      child: CustomPaint(
                        painter: GraphPainter(nodes, currentFloor, connections, path),
                      ),
                    ),

                    ...currentFloorNodes.map((node) {
                      const double iconSize = 24.0;
                      return Positioned(
                        // Coordinates are now perfectly mapped 1:1 to the image
                        left: node.x - (iconSize / 2),
                        top: node.y - iconSize, 
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
                  mainAxisSize: MainAxisSize.min, // Stops the overlay from invisible gesture stealing
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

  GraphPainter(this.nodes, this.floor, this.connections, this.path);

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
        Offset(a.x, a.y),
        Offset(b.x, b.y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}