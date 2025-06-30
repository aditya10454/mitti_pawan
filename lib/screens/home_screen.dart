import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fl_chart/fl_chart.dart';
import '/core/services/aqi_service.dart';
import 'forecast_screen.dart';
import 'history_screen.dart';
import 'location_screen.dart';
import 'splash_screen.dart';

void main() {
  runApp(const MittiPawanApp());
}

class MittiPawanApp extends StatelessWidget {
  const MittiPawanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mitti Pawan',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const SplashScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double? pm25;
  String _aqiStatus = "Loading...";
  String _location = "Fetching location...";
  List<double> pm25Hourly = [];
  List<double> pm10Hourly = [];
  List<double> no2Hourly = [];
  List<double> o3Hourly = [];
  List<double> so2Hourly = [];
  List<double> coHourly = [];

  int _selectedIndex = 0;
  String _placeName = "Loading place...";


  final List<Widget> _screens = const [
    HomeContent(),
    SearchScreen(),
    HistoryScreen(),
    ForecastScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadLocationAndAQI();
  }

  Future<void> _loadLocationAndAQI() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    final position = await Geolocator.getCurrentPosition();

    String place = "Unknown location";
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final Placemark placeMark = placemarks.first;
        place = "${placeMark.locality ?? ''}, ${placeMark.administrativeArea ?? ''}";
      }
    } catch (e) {
      print("📍 Reverse geocoding failed: $e");
    }

    setState(() {
      _location = "Lat: ${position.latitude.toStringAsFixed(2)}, "
          "Lng: ${position.longitude.toStringAsFixed(2)}";
      _placeName = place;
    });

    final aqiData = await fetchSentinelAQI(position.latitude, position.longitude);
    if (aqiData != null && aqiData['hourly']['pm2_5'] != null) {
      setState(() {
        pm25Hourly = getHourlyValues(aqiData, 'pm2_5');
        pm10Hourly = getHourlyValues(aqiData, 'pm10');
        no2Hourly = getHourlyValues(aqiData, 'nitrogen_dioxide');
        o3Hourly = getHourlyValues(aqiData, 'ozone');
        so2Hourly = getHourlyValues(aqiData, 'sulphur_dioxide');
        coHourly = getHourlyValues(aqiData, 'carbon_monoxide');

        pm25 = pm25Hourly.isNotEmpty ? pm25Hourly[0] : null;
        _aqiStatus = pm25 != null ? classifyAQI(pm25!) : 'Data unavailable';
      });
    } else {
      setState(() {
        _aqiStatus = 'Data unavailable';
      });
    }
  }

  void _onNavTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey.shade100,
      body: _selectedIndex == 0 ? _buildHomeUI() : _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green[700],
        unselectedItemColor: Colors.grey[500],
        backgroundColor: Colors.black87,
        onTap: _onNavTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), label: 'Forecast'),
        ],
      ),
    );
  }

  Widget _buildHomeUI() {
    return Column(
      children: [
        const SizedBox(height: 60),
        Text(
          "Air Quality Index",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22),
        ),
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green],
                stops: [0.0, 0.33, 0.66, 1.0],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pm25?.toStringAsFixed(1) ?? '...',
                    style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _aqiStatus,
                    style: const TextStyle(fontSize: 20, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _location,
          style: const TextStyle(color: Colors.black, fontSize: 16),
        ),
        const SizedBox(height: 6),
        Text(
          _placeName,
          style: TextStyle(color: Colors.red[800], fontSize: 18),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            height: 280,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: pm25Hourly.isEmpty
                ? const Center(
              child: Text(
                "Loading graph...",
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            )
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 8.0, left: 12.0),
                  child: Text("Hourly Pollutant Levels (µg/m³)", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: LineChart(
                      LineChartData(
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                            axisNameWidget: const Text('µg/m³'),
                            axisNameSize: 20,
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                            axisNameWidget: const Text('Hours →'),
                            axisNameSize: 20,
                          ),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: true),
                        gridData: FlGridData(show: true),
                        lineBarsData: [
                          _line(pm25Hourly, Colors.green),
                          _line(pm10Hourly, Colors.teal),
                          _line(no2Hourly, Colors.orange),
                          _line(o3Hourly, Colors.blue),
                          _line(so2Hourly, Colors.purple),
                          _line(coHourly, Colors.brown),
                        ],
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 12.0, bottom: 8.0),
                  child: Wrap(
                    spacing: 12,
                    children: [
                      _Legend(color: Colors.green, label: "PM2.5"),
                      _Legend(color: Colors.teal, label: "PM10"),
                      _Legend(color: Colors.orange, label: "NO₂"),
                      _Legend(color: Colors.blue, label: "O₃"),
                      _Legend(color: Colors.purple, label: "SO₂"),
                      _Legend(color: Colors.brown, label: "CO"),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  LineChartBarData _line(List<double> values, Color color) {
    return LineChartBarData(
      isCurved: true,
      color: color,
      barWidth: 2,
      spots: values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
      dotData: FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("Home Screen Content Here"));
  }
}
