import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'item.dart';
import 'splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  Hive.registerAdapter(ItemAdapter());

  await Hive.openBox<Item>('items');
  runApp(MaterialApp(
    home: SplashScreen(),
  ));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('My App'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Home'),
                Tab(text: 'Map'),
                Tab(text: 'Profile'),
                Tab(text: 'About'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              HomeTab(),
              MapTab(),
              ProfileTab(),
              AboutTab(),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  @override
  _HomeTabState createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController latitudeController = TextEditingController();
  final TextEditingController longitudeController = TextEditingController();
  List<String> categoryNames = ['Food', 'Clothing', 'Electronics', 'Books'];
  String selectedCategory = 'Food';

  void addItem() {
    try {
      final Box<Item> itemBox = Hive.box<Item>('items');
      Item newItem = Item(
        nameController.text,
        double.parse(latitudeController.text),
        double.parse(longitudeController.text),
        selectedCategory,
      );
      itemBox.add(newItem);
      nameController.clear();
      latitudeController.clear();
      longitudeController.clear();
      selectedCategory = categoryNames[0];

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Item saved successfully!'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving item: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: latitudeController,
                decoration: InputDecoration(labelText: 'Lat'),
              ),
              TextField(
                controller: longitudeController,
                decoration: InputDecoration(labelText: 'Lon'),
              ),
              DropdownButton<String>(
                value: selectedCategory,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      selectedCategory = newValue;
                    });
                  }
                },
                items: categoryNames
                    .map((String category) => DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        ))
                    .toList(),
              ),
              SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: addItem,
                child: Text('Add Item'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          FloatingActionButton(
            onPressed: () => _showBottomSheet(context),
            child: Icon(Icons.add),
          ),
          SizedBox(height: 20),
          _buildItemList(),
        ],
      ),
    );
  }

  Widget _buildItemList() {
    final Box<Item> itemBox = Hive.box<Item>('items');

    return Expanded(
      child: ListView.builder(
        itemCount: itemBox.length,
        itemBuilder: (BuildContext context, int index) {
          Item? item = itemBox.getAt(index);

          if (item != null) {
            return ListTile(
              title: Text(item.name),
              subtitle: Text(
                  'Location: ${item.latitude} ${item.longitude}, Category: ${item.category}'),
            );
          }

          return SizedBox.shrink();
        },
      ),
    );
  }
}

class ProfileTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Profile Tab Content'),
    );
  }
}

class AboutTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('App Version: 1.0.0'),
          SizedBox(height: 20),
          CircleAvatar(
            radius: 50,
            backgroundImage: AssetImage('assets/strider.jpeg'),
          ),
          SizedBox(height: 10),
          Text('Ana'),
          Text('Skills: Flutter'),
        ],
      ),
    );
  }
}

class MapTab extends StatelessWidget {
  final MapController mapController = MapController();
  final List<Item> items = [];

  Future<LatLng> _getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
    return LatLng(position.latitude, position.longitude);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LatLng>(
      future: _getCurrentLocation(),
      builder: (BuildContext context, AsyncSnapshot<LatLng> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          LatLng currentLocation = snapshot.data!;

          final Box<Item> itemBox = Hive.box<Item>('items');
          items.addAll(itemBox.values);

          items.add(Item('Current Location', currentLocation.latitude,
              currentLocation.longitude, 'Current Location'));

          return FlutterMap(
            options: MapOptions(
              initialCenter: currentLocation,
              initialZoom: 9.2,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              MarkerLayer(
                markers: items.map((item) {
                  return Marker(
                    width: 80.0,
                    height: 80.0,
                    point: LatLng(item.latitude, item.longitude),
                    child: FlutterLogo(),
                  );
                }).toList(),
              ),
            ],
          );
        }
      },
    );
  }
}



//class MapTab extends StatelessWidget {
//   final Geolocator geolocator = Geolocator();
//   final MapController mapController = MapController();
//   final List<Item> items = [];

//   Future<Position> _getCurrentLocation() async {
//     return await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high);
//   }

//   void _loadItemsFromLocalStorage() {
//     final Box<Item> itemBox = Hive.box<Item>('items');
//     items.addAll(itemBox.values);
//   }

//   @override
//   Widget build(BuildContext context) {
//     _loadItemsFromLocalStorage();

//     return FutureBuilder<Position>(
//       future: _getCurrentLocation(),
//       builder: (BuildContext context, AsyncSnapshot<Position> snapshot) {
//         if (snapshot.hasData) {
//           Position currentPosition = snapshot.data!;
//           return FlutterMap(
//             options: MapOptions(
//               center:
//                   LatLng(currentPosition.latitude, currentPosition.longitude),
//               zoom: 14.0,
//             ),
//             children: [
//               TileLayer(
//                 urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
//                 userAgentPackageName: 'com.example.app',
//               ),
//               MarkerLayer(
//                 markers: items.map((item) {
//                   return Marker(
//                     width: 80.0,
//                     height: 80.0,
//                     point: LatLng(item.latitude, item.longitude),
//                     child: FlutterLogo(),
//                   );
//                 }).toList(),
//               ),
//             ],
//           );
//         } else if (snapshot.hasError) {
//           return Center(
//             child: Text('Error: ${snapshot.error}'),
//           );
//         } else {
//           return Center(
//             child: CircularProgressIndicator(),
//           );
//         }
//       },
//     );
//   }
// }