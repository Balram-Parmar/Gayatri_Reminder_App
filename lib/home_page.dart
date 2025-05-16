import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime? _sunrise;
  DateTime? _sunset;
  DateTime? _solarNoon;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Load sun times after the first frame is rendered to avoid UI jank
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getSunTimesToday();
    });
  }

Future<void> _getSunTimesToday() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(path.join(dir.path, 'SunriseTimes.json'));
      final today = DateTime.now();
      final todayStr =
          "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

      Map<String, dynamic> data;
      bool needsFreshData = true;

      if (await file.exists()) {
        try {
          // Read from the local file
          final contents = await file.readAsString();
          data = jsonDecode(contents);

          // Check if we have today's data
          final todayEntryIndex = data['results'].indexWhere(
            (entry) => entry['date'] == todayStr,
          );

          if (todayEntryIndex != -1) {
            needsFreshData = false;
            // Find today's entry
            final todayEntry = data['results'][todayEntryIndex];

            setState(() {
              _sunrise = _parseTime(todayEntry['date'], todayEntry['sunrise']);
              _sunset = _parseTime(todayEntry['date'], todayEntry['sunset']);
              _solarNoon = _parseTime(
                todayEntry['date'],
                todayEntry['solar_noon'],
              );
            });
          }
        } catch (e) {
          debugPrint('Error parsing local data: $e');
          // Continue to fetch fresh data
        }
      }

      if (needsFreshData) {
        var pos = await _getLocation();
        double latitude = pos.latitude;
        double longitude = pos.longitude;
        var date = DateTime.now();

        // Format date in YYYY-MM-DD format
        var dateStart =
            "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

        // Create date 30 days from today
        var endDate = date.add(const Duration(days: 30));
        var dateEnd =
            "${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";

        final url =
            "https://api.sunrisesunset.io/json?lat=$latitude&lng=$longitude&date_start=$dateStart&date_end=$dateEnd&formatted=0";

        final response = await http.get(Uri.parse(url));

        if (response.statusCode != 200) {
          throw Exception('Failed to load sun times');
        }

        // Parse the response body as JSON
        data = jsonDecode(response.body);

        // Find today's entry
        final todayEntry = data['results'].firstWhere(
          (entry) => entry['date'] == todayStr,
          orElse:
              () => data['results'][0], // Use first entry if today not found
        );

        setState(() {
          _sunrise = _parseTime(todayEntry['date'], todayEntry['sunrise']);
          _sunset = _parseTime(todayEntry['date'], todayEntry['sunset']);
          _solarNoon = _parseTime(todayEntry['date'], todayEntry['solar_noon']);
        });

        // Save to local file for future use
        await file.writeAsString(jsonEncode(data));
      }
    } catch (e) {
      debugPrint('Error getting sun times: $e');
      // Show error to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to retrieve sun times. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Fallback method to calculate approximate sun times when API is unavailable

  // Helper to convert decimal hour to DateTime
  Future<Position> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      // Try to get last known position first as it's much faster
      final lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null &&
          DateTime.now().difference(lastPosition.timestamp).inMinutes < 30) {
        return lastPosition;
      }

      // Otherwise get current position with a timeout and medium accuracy for better balance
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      // Show error to user and provide default location
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to get your location. Using default location.'),
          duration: Duration(seconds: 3),
        ),
      );

      // Default to a generic location if we can't get the user's location
      return Position(
        latitude: 40.7128, // Default to New York City
        longitude: -74.0060,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
    }
  }

  DateTime _parseTime(String dateStr, String timeStr) {
    try {
      // Convert 12-hour format to 24-hour format
      bool isPM = timeStr.toLowerCase().contains('pm');
      timeStr = timeStr
          .replaceAll(' AM', '')
          .replaceAll(' PM', '')
          .replaceAll(' am', '')
          .replaceAll(' pm', '');

      List<String> timeParts = timeStr.split(':');
      int hours = int.parse(timeParts[0]);

      // Adjust hours for PM
      if (isPM && hours != 12) {
        hours += 12;
      }
      // Adjust for 12 AM
      if (!isPM && hours == 12) {
        hours = 0;
      }

      timeStr =
          '${hours.toString().padLeft(2, '0')}:${timeParts[1]}:${timeParts[2]}';

      // Combine date and time
      String dateTimeStr = '${dateStr}T$timeStr';
      return DateTime.parse(dateTimeStr);
    } catch (e) {
      debugPrint('Error parsing time: $e');
      // Return current time as fallback
      return DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.black,
        title: const Text('Sun Times Today'),
        centerTitle: true,
        elevation: 4,
        shadowColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getSunTimesToday,
            tooltip: 'Refresh sun times',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Sunrise Card
                      _buildTimeCard(
                        title: 'Sunrise',
                        time: _sunrise,
                        icon: Icons.wb_sunny,
                        color: const Color.fromARGB(255, 0, 0, 0),
                      ),
                      const SizedBox(height: 16),

                      // Sunset Card
                      _buildTimeCard(
                        title: 'Sunset',
                        time: _sunset,
                        icon: Icons.nightlight_round,
                        color: const Color.fromARGB(255, 0, 0, 0),
                      ),
                      const SizedBox(height: 16),

                      // Solar Noon Card
                      _buildTimeCard(
                        title: 'Solar Noon',
                        time: _solarNoon,
                        icon: Icons.wb_sunny_outlined,
                        color: const Color.fromARGB(255, 0, 0, 0),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  // Helper widget to create a time card
  Widget _buildTimeCard({
    required String title,
    required DateTime? time,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
        child: Row(
          children: [
            Icon(icon, size: 32, color: Colors.white),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time != null ? _formatTime(time) : 'Loading...',
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to format time nicely
  String _formatTime(DateTime time) {
    // Format time as HH:MM AM/PM
    final hour =
        time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
