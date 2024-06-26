import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Location location = Location();
  PermissionStatus permissionStatus = await location.hasPermission();
  if (permissionStatus == PermissionStatus.denied) {
    permissionStatus = await location.requestPermission();
    if (permissionStatus != PermissionStatus.granted) {
      // Handle the case if the user denies the permission
      print('Location permission denied');
      return;
    }
  }
  runApp(const MaterialApp(
    title: 'Code Green',
    home: MapScreen(),
  ));
}

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  late LatLng _currentLocation = const LatLng(0, 0); // Initialize with a default value
  LatLng? _destinationLocation;
  String _currentLocationString = '';
  String _destinationAddress = '';

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    Location location = Location();
    PermissionStatus permissionStatus = await location.hasPermission();
    if (permissionStatus == PermissionStatus.denied) {
      permissionStatus = await location.requestPermission();
      if (permissionStatus != PermissionStatus.granted) {
        // Handle the case if the user denies the permission
        print('Location permission denied');
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _currentLocationString = 'Lat: ${position.latitude}, Lng: ${position.longitude}';
    });

    _mapController.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: _currentLocation,
        zoom: 14.0,
      ),
    ));
  }

  Future<void> _calculateRoute() async {
    if (_destinationAddress.isEmpty) {
      print('Destination address is empty');
      return;
    }

    // Use Google Geocoding API to get the destination coordinates
    const String apiKey = 'AIzaSyBf1Kds5CKBNxLWG98qYJoaoGQe-2Gcyl0';
    final Uri url = Uri.parse('https://maps.googleapis.com/maps/api/geocode/json?address=$_destinationAddress&key=$apiKey');
    final response = await http.get(url);
    final jsonResponse = json.decode(response.body);

    if (jsonResponse['status'] == 'OK') {
      final lat = jsonResponse['results'][0]['geometry']['location']['lat'];
      final lng = jsonResponse['results'][0]['geometry']['location']['lng'];
      _destinationLocation = LatLng(lat, lng);

      PolylinePoints polylinePoints = PolylinePoints();
      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        apiKey,
        PointLatLng(_currentLocation.latitude, _currentLocation.longitude),
        PointLatLng(_destinationLocation!.latitude, _destinationLocation!.longitude),
      );

      if (result.points.isNotEmpty) {
        List<PointLatLng> points = result.points;
        List<LatLng> polylineCoordinates = points.map((point) => LatLng(point.latitude, point.longitude)).toList();
        setState(() {
          _polylines.clear();
          _polylines.add(Polyline(
            polylineId: const PolylineId('route'),
            points: polylineCoordinates,
            color: Colors.blue,
            width: 5,
          ));
          _markers.clear();
          _markers.add(Marker(
            markerId: const MarkerId('destination'),
            position: _destinationLocation!,
            infoWindow: InfoWindow(title: _destinationAddress),
          ));
        });
      } else {
        print('No route found');
        _showNoRouteDialog();
      }
    } else {
      print('Failed to get destination coordinates: ${jsonResponse['status']}');
      if (jsonResponse.containsKey('error_message')) {
        print('Error message: ${jsonResponse['error_message']}');
      }
      _showNoRouteDialog();
    }
  }

  void _showNoRouteDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('No Route Found'),
          content: const Text('There is no route to the specified destination.'),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
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
              initialCameraPosition: CameraPosition(
                target: _currentLocation,
                zoom: 14.0,
              ),
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
              markers: _markers,
              polylines: _polylines,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Text('Current Location: $_currentLocationString'),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Enter destination',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          _destinationAddress = value;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _calculateRoute,
                      child: const Text('Show Route'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
