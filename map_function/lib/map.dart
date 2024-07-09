import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';

class ParkBlueprintScreen extends StatefulWidget {
  @override
  _ParkBlueprintScreenState createState() => _ParkBlueprintScreenState();
}

class _ParkBlueprintScreenState extends State<ParkBlueprintScreen> {
  List<Offset> dustbinLocations = [];
  double imageWidth = 1000.0;  // Blueprint image width in pixels
  double imageHeight = 500.0;  // Blueprint image height in pixels
  double realWorldLength = 200.0;  // Real-world length in meterszy
  double realWorldBreadth = 100.0;  // Real-world breadth in meters
  double scaleFactor = 1.0;  // Scale factor of the blueprint image

  @override
  void initState() {
    super.initState();
    _loadCoordinates();
  }

  void _addDustbinLocation(TapDownDetails details) {
    setState(() {
      dustbinLocations.add(details.localPosition);
    });
    _saveCoordinates();
  }

  void _removeDustbinLocation(Offset position) {
    setState(() {
      dustbinLocations.remove(position);
    });
    _saveCoordinates();
  }

  void _saveCoordinates() async {
    final file = File('dustbin_locations.json');
    final jsonString = jsonEncode(dustbinLocations.map((e) => {'x': e.dx, 'y': e.dy}).toList());
    await file.writeAsString(jsonString);
  }

  void _loadCoordinates() async {
    final file = File('dustbin_locations.json');
    if (!file.existsSync()) return;
    final jsonString = await file.readAsString();
    final List<dynamic> jsonList = jsonDecode(jsonString);
    setState(() {
      dustbinLocations = jsonList.map((e) => Offset(e['x'], e['y'])).toList();
    });
  }

  Offset convertToRealWorldCoordinates(Offset offset) {
    double scaleX = realWorldLength / (imageWidth * scaleFactor);
    double scaleY = realWorldBreadth / (imageHeight * scaleFactor);
    return Offset(offset.dx * scaleX, offset.dy * scaleY);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Park Blueprint'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              _showSettingsDialog();
            },
          ),
        ],
      ),
      body: Center(
        child: GestureDetector(
          onTapDown: _addDustbinLocation,
          child: InteractiveViewer(
            child: Stack(
              children: [
                Image.asset('assets/images/image.jpg', width: imageWidth, height: imageHeight),
                ...dustbinLocations.map((location) {
                  Offset realWorldLocation = convertToRealWorldCoordinates(location);
                  return Positioned(
                    left: location.dx,
                    top: location.dy,
                    child: GestureDetector(
                      onDoubleTap: () {
                        _removeDustbinLocation(location);
                      },
                      child: Icon(
                        Icons.delete,
                        color: Colors.red,
                        size: 30.0,
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    TextEditingController lengthController = TextEditingController(text: realWorldLength.toString());
    TextEditingController breadthController = TextEditingController(text: realWorldBreadth.toString());
    TextEditingController scaleController = TextEditingController(text: scaleFactor.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: lengthController,
                decoration: InputDecoration(labelText: 'Real-world Length (meters)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: breadthController,
                decoration: InputDecoration(labelText: 'Real-world Breadth (meters)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: scaleController,
                decoration: InputDecoration(labelText: 'Scale Factor'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  realWorldLength = double.parse(lengthController.text);
                  realWorldBreadth = double.parse(breadthController.text);
                  scaleFactor = double.parse(scaleController.text);
                });
                Navigator.of(context).pop();
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: ParkBlueprintScreen(),
  ));
}
