import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:connectivity_plus/connectivity_plus.dart';

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
  String _errorMessage = '';
  final _client = http.Client(); // Create a persistent HTTP client

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getSunTimesToday();
    });
  }

  @override
  void dispose() {
    _client.close(); // Close the HTTP client when the widget is disposed
    super.dispose();
  }

  Future<bool> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> _fullRefresh() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final hasConnectivity = await _checkConnectivity();

      if (hasConnectivity) {
        try {
          final pos = await _getLocation(fresh: true);
          print("Location: ${pos.latitude}, ${pos.longitude}");
          final latitude = pos.latitude;
          final longitude = pos.longitude;
          final now = DateTime.now();
          final startOfMonth = DateTime(now.year, now.month, 1);
          final endOfMonth = DateTime(now.year, now.month + 1, 0);
          final dateStart =
              "${startOfMonth.year}-${startOfMonth.month.toString().padLeft(2, '0')}-${startOfMonth.day.toString().padLeft(2, '0')}";
          final dateEnd =
              "${endOfMonth.year}-${endOfMonth.month.toString().padLeft(2, '0')}-${endOfMonth.day.toString().padLeft(2, '0')}";

          final url =
              "https://api.sunrisesunset.io/json?lat=$latitude&lng=$longitude&date_start=$dateStart&date_end=$dateEnd&formatted=0";

          // Use the existing client with a shorter timeout
          final response = await _client
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 15));
          print("responce data is : ${response.body}");
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);

            // Save to cache
            final dir = await getApplicationDocumentsDirectory();
            final file = File(path.join(dir.path, 'SunriseTimes.json'));
            await file.writeAsString(jsonEncode(data));

            _setTodaySunTimes(data);
          } else {
            throw Exception('Failed to load sun times: ${response.statusCode}');
          }
        } catch (e) {
          debugPrint('Error fetching from API: $e');
          throw e; // Rethrow to be caught by the calling function
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You are offline. check your internet. and try again.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            backgroundColor: Theme.of(context).colorScheme.surface,
            duration: Duration(seconds: 8),
          ),
        );
        await _loadFromCache();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to get your location. Using default location.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          backgroundColor: Theme.of(context).colorScheme.surface,
          duration: Duration(seconds: 3),
        ),
      );
      await _loadFromCache();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getSunTimesToday() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final hasConnectivity = await _checkConnectivity();

      print("Connectivity status: $hasConnectivity");

      if (hasConnectivity) {
        await _fetchSunTimesFromApi();
      } else {
        await _loadFromCache();
      }
    } catch (e) {
      debugPrint('Error getting sun times: $e');
      await _loadFromCache();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchSunTimesFromApi() async {
    try {
      final pos = await _getLocation();
      print("Location: ${pos.latitude}, ${pos.longitude}");
      final latitude = pos.latitude;
      final longitude = pos.longitude;
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);
      final dateStart =
          "${startOfMonth.year}-${startOfMonth.month.toString().padLeft(2, '0')}-${startOfMonth.day.toString().padLeft(2, '0')}";
      final dateEnd =
          "${endOfMonth.year}-${endOfMonth.month.toString().padLeft(2, '0')}-${endOfMonth.day.toString().padLeft(2, '0')}";

      final url =
          "https://api.sunrisesunset.io/json?lat=$latitude&lng=$longitude&date_start=$dateStart&date_end=$dateEnd&formatted=0";

      // Use the existing client with a shorter timeout
      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      print("responce data is : ${response.body}");
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Save to cache
        final dir = await getDownloadsDirectory();
        if (dir == null) {
          throw Exception('Cannot access downloads directory');
        }
        print("dir path is : ${dir.path}");
        final file = File(path.join(dir.path, 'SunriseTimes.json'));
        await file.writeAsString(jsonEncode(data));

        _setTodaySunTimes(data);
      } else {
        throw Exception('Failed to load sun times: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching from API: $e');
      throw e; // Rethrow to be caught by the calling function
    }
  }

  void _setTodaySunTimes(Map<String, dynamic> data) {
    final today = DateTime.now();
    final todayStr =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    // Explicitly check that results is a List before using firstWhere
    if (data['results'] is! List) {
      setState(() {
        _errorMessage = 'Invalid data format from API';
      });
      return;
    }

    final todayEntry = (data['results'] as List).firstWhere(
      (entry) => entry['date'] == todayStr,
      orElse: () => null,
    );

    if (todayEntry != null) {
      setState(() {
        _sunrise = _parseTime(todayEntry['date'], todayEntry['sunrise']);
        _sunset = _parseTime(todayEntry['date'], todayEntry['sunset']);
        _solarNoon = _parseTime(todayEntry['date'], todayEntry['solar_noon']);
      });
    } else {
      setState(() {
        _errorMessage = 'No data available for today';
      });
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final dir = await getDownloadsDirectory();
      if (dir == null) {
        throw Exception('Cannot access downloads directory');
      }
      final file = File(path.join(dir.path, 'SunriseTimes.json'));
      if (await file.exists()) {
        final contents = await file.readAsString();
        final data = jsonDecode(contents);
        _setTodaySunTimes(data);
      } else {
        setState(() {
          _errorMessage = 'No cached data available';
        });
      }
    } catch (e) {
      debugPrint('Error loading from cache: $e');
      setState(() {
        _errorMessage = 'Error loading cached data';
      });
    }
  }

  Future<Position> _getLocation({bool fresh = false}) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Show dialog asking to enable location services
        bool userAccepted =
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text('Location Services Disabled'),
                  content: Text(
                    'Please enable location services to get accurate sun times for your location.',
                  ),
                  actions: <Widget>[
                    TextButton(
                      child: Text('Cancel'),
                      onPressed: () {
                        Navigator.of(context).pop(false);
                      },
                    ),
                    TextButton(
                      child: Text('Open Settings'),
                      onPressed: () {
                        Navigator.of(context).pop(true);
                      },
                    ),
                  ],
                );
              },
            ) ??
            false;

        if (userAccepted) {
          await Geolocator.openLocationSettings();
        }

        // Check again if enabled after settings
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          throw Exception('Location services are still disabled.');
        }
      }

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

      if (fresh) {
        // Get current position with timeout
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15),
        );
      } else {
        // Get last known position
        final lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null &&
            DateTime.now().difference(lastPosition.timestamp).inMinutes < 30) {
          return lastPosition;
        }

        // If we don't have a recent last position, get current position
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15),
        );
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to get your location. Using default location.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          backgroundColor: Theme.of(context).colorScheme.surface,
          duration: Duration(seconds: 3),
        ),
      );

      // Return default location
      return Position(
        latitude: 23.0225,
        longitude: 72.5714,
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
      if (timeStr.contains('T') && timeStr.contains('Z')) {
        return DateTime.parse(timeStr);
      }

      bool isPM = timeStr.toLowerCase().contains('pm');
      timeStr = timeStr
          .replaceAll(' AM', '')
          .replaceAll(' PM', '')
          .replaceAll(' am', '')
          .replaceAll(' pm', '');

      List<String> timeParts = timeStr.split(':');
      int hours = int.parse(timeParts[0]);

      if (isPM && hours != 12) {
        hours += 12;
      }
      if (!isPM && hours == 12) {
        hours = 0;
      }

      timeStr =
          '${hours.toString().padLeft(2, '0')}:${timeParts[1]}:${timeParts[2]}';
      String dateTimeStr = '${dateStr}T$timeStr';
      return DateTime.parse(dateTimeStr);
    } catch (e) {
      debugPrint('Error parsing time: $e');
      return DateTime.now();
    }
  }

  String _formatTime(DateTime time) {
    final hour =
        time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sun Times Today',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.titleLarge?.color,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.refresh,
                      size: 40,
                      color: theme.iconTheme.color,
                    ),
                    onPressed: _isLoading ? null : _getSunTimesToday,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_errorMessage.isNotEmpty && !_isLoading)
                Container(
                  padding: EdgeInsets.all(8),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange[700],
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: TextStyle(color: Colors.orange[800]),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_isLoading)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: theme.colorScheme.primary,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Loading sun times...',
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                ListTile(
                  leading: Icon(
                    Icons.wb_sunny,
                    color: Colors.orange[700],
                    size: 32,
                  ),
                  title: Text(
                    'Sunrise',
                    style: TextStyle(
                      color: theme.textTheme.titleMedium?.color,
                      fontSize: 20,
                    ),
                  ),
                  trailing: Text(
                    _sunrise != null ? _formatTime(_sunrise!) : 'Unavailable',
                    style: TextStyle(
                      color: theme.textTheme.titleMedium?.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                Divider(color: theme.dividerColor),
                ListTile(
                  leading: Icon(
                    Icons.wb_sunny_outlined,
                    color: Colors.orange[700],
                    size: 32,
                  ),
                  title: Text(
                    'Solar Noon',
                    style: TextStyle(
                      color: theme.textTheme.titleMedium?.color,
                      fontSize: 20,
                    ),
                  ),
                  trailing: Text(
                    _solarNoon != null
                        ? _formatTime(_solarNoon!)
                        : 'Unavailable',
                    style: TextStyle(
                      color: theme.textTheme.titleMedium?.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                Divider(color: theme.dividerColor),
                ListTile(
                  leading: Icon(
                    Icons.nightlight_round,
                    color: Colors.orange[700],
                    size: 32,
                  ),
                  title: Text(
                    'Sunset',
                    style: TextStyle(
                      color: theme.textTheme.titleMedium?.color,
                      fontSize: 20,
                    ),
                  ),
                  trailing: Text(
                    _sunset != null ? _formatTime(_sunset!) : 'Unavailable',
                    style: TextStyle(
                      color: theme.textTheme.titleMedium?.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                Spacer(),
                if (_sunrise != null)
                  Center(
                    child: ElevatedButton(
                      onPressed: _fullRefresh,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: Text('Full Refresh Data'),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
