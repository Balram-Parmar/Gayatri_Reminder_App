import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:connectivity_plus/connectivity_plus.dart'; // Add this dependency to your pubspec.yaml
import 'package:provider/provider.dart';
import 'theme_provider.dart';

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
  int _retryCount = 0;
  final int _maxRetries = 3;
  final Duration _retryDelay = const Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getSunTimesToday();
    });
  }

Future<bool> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

Future<void> _getSunTimesToday() async {
    final theme = Theme.of(context);
    final isDarkMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Check for internet connectivity first
      final hasConnectivity = await _checkConnectivity();
      if (!hasConnectivity) {
        throw Exception('No internet connection available');
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File(path.join(dir.path, 'SunriseTimes.json'));
      final today = DateTime.now();
      final todayStr =
          "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

      Map<String, dynamic>? data;
      bool needsFreshData = true;
      bool loadedFromCache = false;

      // Try to load from cache
      if (await file.exists()) {
        try {
          final contents = await file.readAsString();
          data = jsonDecode(contents);

          final todayEntryIndex = data?['results']?.indexWhere(
            (entry) => entry['date'] == todayStr,
          );

          if (todayEntryIndex != null && todayEntryIndex != -1) {
            needsFreshData = false;
            loadedFromCache = true;
            final todayEntry = data!['results'][todayEntryIndex];

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
          // We'll try to get fresh data if we can't parse cached data
        }
      }

      if (needsFreshData) {
        var pos = await _getLocation();
        double latitude = pos.latitude;
        double longitude = pos.longitude;
        var date = DateTime.now();

        var dateStart =
            "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

        var endDate = date.add(const Duration(days: 30));
        var dateEnd =
            "${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";

        final url =
            "https://api.sunrisesunset.io/json?lat=$latitude&lng=$longitude&date_start=$dateStart&date_end=$dateEnd&formatted=0";

        // Try alternative APIs if the primary one fails
        final alternativeApis = [
          "https://api.sunrise-sunset.org/json?lat=$latitude&lng=$longitude&date=$dateStart&formatted=0",
        ];

        http.Response? response;
        String? errorDetails;

        // Try the primary API
        try {
          response = await http
              .get(Uri.parse(url))
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () => throw TimeoutException('Request timed out'),
              );
        } catch (e) {
          errorDetails = e.toString();
          debugPrint('Primary API error: $e');

          // Try alternative APIs
          for (var apiUrl in alternativeApis) {
            try {
              debugPrint('Trying alternative API: $apiUrl');
              response = await http
                  .get(Uri.parse(apiUrl))
                  .timeout(
                    const Duration(seconds: 10),
                    onTimeout:
                        () =>
                            throw TimeoutException(
                              'Alternative request timed out',
                            ),
                  );

              if (response.statusCode == 200) {
                debugPrint('Successfully connected to alternative API');
                break; // Break if successful
              }
            } catch (e) {
              debugPrint('Alternative API error: $e');
              // Continue to the next alternative
            }
          }
        }

        if (response == null || response.statusCode != 200) {
          throw Exception(
            'Failed to load sun times: ${response?.statusCode ?? "No response"}, Error: $errorDetails',
          );
        }

        data = jsonDecode(response.body);

        // Handle different API response formats
        if (data?['results'] != null) {
          // Primary API format
          final todayEntry = data!['results'].firstWhere(
            (entry) => entry['date'] == todayStr,
            orElse: () => data!['results'][0],
          );

          setState(() {
            _sunrise = _parseTime(todayEntry['date'], todayEntry['sunrise']);
            _sunset = _parseTime(todayEntry['date'], todayEntry['sunset']);
            _solarNoon = _parseTime(
              todayEntry['date'],
              todayEntry['solar_noon'],
            );
          });
        } else if (data?['results'] == null && data != null) {
          // Alternative API format (for api.sunrise-sunset.org)
          setState(() {
            _sunrise = DateTime.parse(data!['results']['sunrise']);
            _sunset = DateTime.parse(data['results']['sunset']);
            _solarNoon = DateTime.parse(data['results']['solar_noon']);
          });

          // Convert to our expected format for caching
          data = {
            'results': [
              {
                'date': todayStr,
                'sunrise': data['results']['sunrise'],
                'sunset': data['results']['sunset'],
                'solar_noon': data['results']['solar_noon'],
              },
            ],
          };
        }

        // Cache the data
        await file.writeAsString(jsonEncode(data));
      }

      // Reset retry count on success
      _retryCount = 0;
    } catch (e) {
      debugPrint('Error getting sun times: $e');

      setState(() {
        _errorMessage = 'Unable to fetch data: ${e.toString()}';
      });

      // Try to load from cache as fallback if we haven't already
      if (_retryCount < _maxRetries) {
        _retryCount++;
        debugPrint(
          'Retrying in $_retryDelay... (Attempt $_retryCount of $_maxRetries)',
        );

        // Show a retry message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Connection issue. Retrying in ${_retryDelay.inSeconds} seconds...',
            ),
            duration: _retryDelay,
          ),
        );

        // Retry after delay
        Timer(_retryDelay, _getSunTimesToday);
        return;
      } else {
        // Try to use cached data as last resort
        final dir = await getApplicationDocumentsDirectory();
        final file = File(path.join(dir.path, 'SunriseTimes.json'));

        if (await file.exists()) {
          try {
            final contents = await file.readAsString();
            final data = jsonDecode(contents);

            // Use the most recent entry in the cache
            if (data['results'] != null && data['results'].isNotEmpty) {
              final cachedEntry = data['results'][0];

              setState(() {
                _sunrise = _parseTime(
                  cachedEntry['date'],
                  cachedEntry['sunrise'],
                );
                _sunset = _parseTime(
                  cachedEntry['date'],
                  cachedEntry['sunset'],
                );
                _solarNoon = _parseTime(
                  cachedEntry['date'],
                  cachedEntry['solar_noon'],
                );
                _errorMessage = 'Using cached data from ${cachedEntry['date']}';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Network error. Using stored data from ${cachedEntry['date']}',
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                  backgroundColor:
                      isDarkMode ? Colors.orange[800] : Colors.orange[300],
                  duration: Duration(seconds: 5),
                ),
              );
              return;
            }
          } catch (e) {
            debugPrint('Error reading cache as fallback: $e');
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to load sun times: Network error',
              style: TextStyle(color: theme.colorScheme.onError),
            ),
            backgroundColor: theme.colorScheme.error,
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: theme.colorScheme.onError,
              onPressed: () {
                _retryCount = 0;
                _getSunTimesToday();
              },
            ),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

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

      final lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null &&
          DateTime.now().difference(lastPosition.timestamp).inMinutes < 30) {
        return lastPosition;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
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

      return Position(
        latitude: 40.7128,
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
      // Handle ISO format time strings (from alternative API)
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
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
                    color:
                        isDarkMode
                            ? Colors.orange[900]?.withOpacity(0.2)
                            : Colors.orange[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color:
                            isDarkMode
                                ? Colors.orange[300]
                                : Colors.orange[700],
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: TextStyle(
                            color:
                                isDarkMode
                                    ? Colors.orange[300]
                                    : Colors.orange[800],
                          ),
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
                      onPressed: _getSunTimesToday,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: Text('Refresh Data'),
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
