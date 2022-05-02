import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geoflutterfire/geoflutterfire.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:rxdart/rxdart.dart';

class Homepage extends StatelessWidget {
  const Homepage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.amberAccent,
      appBar: AppBar(
        title: const Text('location tracking'),
        backgroundColor: const Color(0xff1da1f2),
      ),
      body: FireMap(),
    );
  }
}

class FireMap extends StatefulWidget {
  const FireMap({Key? key}) : super(key: key);

  @override
  State createState() => FireMapState();
}

class FireMapState extends State<FireMap> {
  late GoogleMapController mapController;
  Location location = new Location();
  List<Marker> markers = [];

  final _firestore = FirebaseFirestore.instance;
  Geoflutterfire geo = Geoflutterfire();

  // Stateful Data
  var radius = BehaviorSubject.seeded(100.0);
  late Stream<dynamic> query;

  // Subscription
  late StreamSubscription subscription;

  Widget build(BuildContext context) {
    return Stack(children: [
      GoogleMap(
        initialCameraPosition:
            CameraPosition(target: LatLng(24.142, -110.321), zoom: 15),
        onMapCreated: _onMapCreated,
        myLocationEnabled: true,
        mapType: MapType.hybrid,
        compassEnabled: true,
        markers: markers.toSet(),
      ),
      Positioned(
          bottom: 120,
          right: 10,
          child: TextButton(
              child: Icon(Icons.drive_eta,
                  size: 50, color: Color.fromARGB(255, 15, 29, 108)),
              onPressed: _addGeoPoint)),
      Positioned(
          bottom: 50,
          left: 10,
          child: Slider(
            min: 100.0,
            max: 500.0,
            divisions: 4,
            value: radius.value,
            label: 'Radius ${radius.value}km',
            activeColor: Color.fromARGB(255, 34, 35, 34),
            inactiveColor: Color.fromARGB(255, 0, 0, 0).withOpacity(0.2),
            onChanged: _updateQuery,
          ))
    ]);
  }

  _onMapCreated(GoogleMapController controller) {
    _startQuery();
    setState(() {
      mapController = controller;
    });
  }

  _animateToUser(double lat, double lang) async {
    LocationData pos = await location.getLocation();

    mapController.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
      target: LatLng(pos.latitude!, pos.longitude!),
      zoom: 17.0,
    )));
  }

  Future<DocumentReference> _addGeoPoint() async {
    var pos = await location.getLocation();

    GeoFirePoint point =
        geo.point(latitude: pos.latitude!, longitude: pos.longitude!);
    return _firestore
        .collection('locations')
        .add({'position': point.data, 'name': 'aditya'});
  }

  void _updateMarkers(List<DocumentSnapshot> documentList) {
    documentList.forEach((DocumentSnapshot document) {
      GeoPoint point = document['position']['geopoint'];
      _addMarker(point.latitude, point.longitude);
    });
  }

  void _addMarker(double lat, double lng) {
    var _marker = Marker(
      markerId: MarkerId(UniqueKey().toString()),
      position: LatLng(lat, lng),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
    );
    setState(() {
      markers.add(_marker);
    });
  }

  @override
  void initState() {
    super.initState();
    geo = Geoflutterfire();
    _startQuery();
  }

  _startQuery() async {
    // Get users location
    LocationData pos = await location.getLocation();
    double lat = pos.latitude!;
    double lng = pos.longitude!;

    // Make a referece to firestore
    var collectionReference = _firestore.collection('locations');
    GeoFirePoint center = geo.point(latitude: lat, longitude: lng);

    // subscribe to query
    subscription = radius.switchMap((rad) {
      return geo.collection(collectionRef: collectionReference).within(
          center: center, radius: rad, field: 'position', strictMode: true);
    }).listen(_updateMarkers);
  }

  _updateQuery(value) {
    final zoomMap = {
      100.0: 12.0,
      200.0: 10.0,
      300.0: 7.0,
      400.0: 6.0,
      500.0: 5.0
    };
    final zoom = zoomMap[value];
    mapController.moveCamera(CameraUpdate.zoomTo(zoom!));

    setState(() {
      radius.add(value);
    });
  }

  @override
  dispose() {
    subscription.cancel();
    super.dispose();
  }
}
