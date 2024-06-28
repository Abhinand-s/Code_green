import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final List<LatLng> _polylineCoordinates = [];
  final DatabaseReference _databaseReference = FirebaseDatabase.instance.ref().child('locations');
  final String apiKey = 'YOUR_API_KEY_HERE'; // Replace with your OpenRouteService API key

  @override
  void initState() {
    super.initState();
    _fetchLocationsFromFirebase();
  }

  Future<void> _fetchLocationsFromFirebase() async {
    try {
      DataSnapshot snapshot = (await _databaseReference.once()).snapshot;
      if (snapshot.exists) {
        print('Data exists in Firebase.');
        List<dynamic>? locations = snapshot.value as List<dynamic>?;
        if (locations != null && locations.isNotEmpty) {
          print('Locations are not empty.');
          setState(() {
            _markers.clear();
            _polylines.clear();
          });
          for (var location in locations) {
            double? lat = location['latitude'];
            double? lng = location['longitude'];
            String? title = location['name'];
            
            // Check if any value is null
            if (lat == null || lng == null || title == null) {
              print('Invalid location data: $location');
              continue;
            }

            print('Adding marker: $title at ($lat, $lng)');

            setState(() {
              _markers.add(Marker(
                markerId: MarkerId(title),
                position: LatLng(lat, lng),
                infoWindow: InfoWindow(title: title),
              ));
            });
          }

          if (_markers.length > 1) {
            List<LatLng> markerPositions = _markers.map((marker) => marker.position).toList();
            _fitMarkersToBounds(markerPositions);
            await _fetchAllRoutes(markerPositions);
          }
        } else {
          print('Locations list is empty.');
        }
      } else {
        print('Snapshot does not exist.');
      }
    } catch (e) {
      print('Error fetching locations from Firebase: $e');
    }
  }

Future<void> _fetchAllRoutes(List<LatLng> markerPositions) async {
  try {
    // Ensure at least two markers are available
    if (markerPositions.length < 2) {
      print('Not enough markers to fetch routes.');
      return;
    }

    // Fetch route for the first pair of markers
    LatLng start = markerPositions[0];
    LatLng end = markerPositions[1];
    await _fetchRoute(start, end);
  } catch (e) {
    print('Error in fetching routes: $e');
  }
}

Future<void> _fetchRoute(LatLng start, LatLng end) async {
  try {
    Uri routeUrl = Uri.parse(
        'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$apiKey&start=${start.longitude},${start.latitude}&end=${end.longitude},${end.latitude}');

    final response = await http.get(routeUrl);
    print('Fetching polyline data from URL: $routeUrl');
    
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      List<dynamic> features = jsonResponse['features'];
      
      if (features.isNotEmpty) {
        List<dynamic> points = features[0]['geometry']['coordinates'];
        List<LatLng> polylinePoints = points.map((point) => LatLng(point[1], point[0])).toList();
        
        setState(() {
          _polylines.clear(); // Clear existing polylines
          _polylines.add(Polyline(
            polylineId: PolylineId('route'), // Use a fixed ID for the polyline
            points: polylinePoints,
            color: Colors.blue,
            width: 5,
          ));
        });
        
        print('Polyline added with ${polylinePoints.length} points.');
      } else {
        print('No route features found in response.');
      }
    } else {
      print('Failed to fetch route, status code: ${response.statusCode}');
      print('Response body: ${response.body}');
    }
  } catch (e) {
    print('Error in fetching route: $e');
  }
}




  void _fitMarkersToBounds(List<LatLng> markerPositions) {
    LatLngBounds bounds;
    if (markerPositions.length == 1) {
      bounds = LatLngBounds(
        southwest: markerPositions.first,
        northeast: markerPositions.first,
      );
    } else {
      bounds = LatLngBounds(
        southwest: LatLng(
          markerPositions.map((pos) => pos.latitude).reduce((a, b) => a < b ? a : b),
          markerPositions.map((pos) => pos.longitude).reduce((a, b) => a < b ? a : b),
        ),
        northeast: LatLng(
          markerPositions.map((pos) => pos.latitude).reduce((a, b) => a > b ? a : b),
          markerPositions.map((pos) => pos.longitude).reduce((a, b) => a > b ? a : b),
        ),
      );
    }
    _mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(0, 0), // Initial map center, can be any default location
                zoom: 10.0, // Initial zoom level
              ),
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
              markers: _markers,
              polylines: _polylines,
            ),
          ),
        ],
      ),
    );
  }
}
