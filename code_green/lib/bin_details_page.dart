import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class BinDetailsPage extends StatelessWidget {
  final String placeId;

  BinDetailsPage({required this.placeId});

  // Method to calculate Euclidean distance between two points
  double calculateDistance(List<double> point1, List<double> point2) {
    double x1 = point1[0];
    double y1 = point1[1];
    double x2 = point2[0];
    double y2 = point2[1];

    double distance = sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));
    return distance;
  }

  // Method to parse a string to a list of doubles
  List<double> parseLocation(String location) {
    try {
      List<String> parts = location.replaceAll('(', '').replaceAll(')', '').split(',');
      double x = double.parse(parts[0].trim());
      double y = double.parse(parts[1].trim());
      return [x, y];
    } catch (e) {
      print("Error parsing location: $e");
      return [0.0, 0.0]; // Return a default value in case of parsing error
    }
  }

  // Method to find the shortest path using the nearest neighbor algorithm
  List<DocumentSnapshot> findShortestPath(List<DocumentSnapshot> bins) {
    List<DocumentSnapshot> path = [];
    List<bool> visited = List<bool>.filled(bins.length, false);
    int currentIndex = 0;

    path.add(bins[currentIndex]);
    visited[currentIndex] = true;

    while (path.length < bins.length) {
      double minDistance = double.infinity;
      int nearestIndex = -1;

      for (int i = 0; i < bins.length; i++) {
        if (!visited[i]) {
          List<double> currentLocation = parseLocation((bins[currentIndex].data() as Map<String, dynamic>)['location']);
          List<double> candidateLocation = parseLocation((bins[i].data() as Map<String, dynamic>)['location']);
          double distance = calculateDistance(currentLocation, candidateLocation);

          if (distance < minDistance) {
            minDistance = distance;
            nearestIndex = i;
          }
        }
      }

      currentIndex = nearestIndex;
      path.add(bins[currentIndex]);
      visited[currentIndex] = true;
    }

    return path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$placeId Bins Details'),
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('places')
            .doc(placeId)
            .collection('bins')
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No bins found for $placeId.'));
          }

          // Extracting and filtering filled bins
          List<DocumentSnapshot> filledBins = snapshot.data!.docs.where((doc) {
            Map<String, dynamic> binData = doc.data() as Map<String, dynamic>;
            return binData['fillStatus'] == '1';
          }).toList();

          // If no filled bins are found
          if (filledBins.isEmpty) {
            return Center(child: Text('No filled bins found for $placeId.'));
          }

          // Finding the shortest path using the nearest neighbor algorithm
          List<DocumentSnapshot> sortedBins = findShortestPath(filledBins);

          return ListView.builder(
            itemCount: sortedBins.length,
            itemBuilder: (context, index) {
              var binData = sortedBins[index].data() as Map<String, dynamic>;
              var binId = sortedBins[index].id;
              return ListTile(
                title: Text('Step ${index + 1}: Go to Bin $binId near ${binData['nearbyPoint']}'),
              );
            },
          );
        },
      ),
    );
  }
}
