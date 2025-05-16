import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'notification_controller.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  double? _latitude;
  double? _longitude;
  int _rescheduleMinutes = 15;
  bool _isLoading = false;
  int? _id = 0;

  @override
  void initState() {
    super.initState();
    _initializeSettings();
  }

  Future<Map<String, dynamic>> saveNewSunTimes() async {
    var date = DateTime.now();

    // Format date in YYYY-MM-DD format
    var dateStart =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    // Create date 30 days from today
    var endDate = date.add(const Duration(days: 30));
    var dateEnd =
        "${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";
    final url =
        "https://api.sunrisesunset.io/json?lat=$_latitude&lng=$_longitude&date_start=$dateStart&date_end=$dateEnd&formatted=0";
    final response = await http.get(Uri.parse(url));

    print("Response for month: ${response.body}");

    if (response.statusCode != 200) {
      throw Exception('Failed to load sun times');
    }

    final dir = await getDownloadsDirectory();
    final file = File(path.join(dir!.path, 'SunriseTimes.json'));
    file.writeAsString(response.body);

    // Parse the response body as JSON

    return jsonDecode(response.body);
  }

  Future<void> _initializeSettings() async {
    setState(() => _isLoading = true);

    try {
      // Request notification permissions first
      await _requestNotificationPermission();

      // Load reschedule time from settings file
      await _loadRescheduleTime();

      // Try to get location last (since it might fail or take time)
      try {
        final location = await _getLocation();
        setState(() {
          _latitude = location.latitude;
          _longitude = location.longitude;
        });
      } catch (e) {
        debugPrint('Location error: ${e.toString()}');
        // Don't rethrow - continue even if location fails
      }
    } catch (e) {
      _showErrorSnackBar('Failed to initialize settings: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Load the notification reschedule time
  Future<void> _loadRescheduleTime() async {
    final minutes = await NotificationController.getRescheduleMinutes();
    setState(() {
      _rescheduleMinutes = minutes;
    });
  }

  // Save the notification reschedule time
  Future<void> _saveRescheduleTime(int minutes) async {
    await NotificationController.setRescheduleMinutes(minutes);
    setState(() {
      _rescheduleMinutes = minutes;
    });
    _showSuccessSnackBar(
      'Notification reschedule time set to $minutes minutes',
    );
  }

  // Request notification permission
  Future<void> _requestNotificationPermission() async {
    final isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      // Request permission
      await AwesomeNotifications().requestPermissionToSendNotifications();
      debugPrint('Notification permission requested');
    } else {
      debugPrint('Notification permission already granted');
    }
  }

  void _listNotifications() {
    AwesomeNotifications().listScheduledNotifications().then((notifications) {
      for (var notification in notifications) {
        print('Notification ID: ${notification.schedule}');
      }
      _showSuccessSnackBar(
        '${notifications.length} notifications listed in console',
      );
    });
  }

  void _cancelAllNotifications() {
    AwesomeNotifications().cancelAllSchedules();
    print("all notifications cancelled");
  }

  Future<Position> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Show dialog asking user to enable location services
        bool enableService = await _showEnableLocationDialog();
        if (enableService) {
          // Open location settings
          await Geolocator.openLocationSettings();
          // Check again if location is enabled after returning from settings
          serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (!serviceEnabled) {
            throw Exception('Location services are still disabled.');
          }
        } else {
          throw Exception('Location services are required for this app.');
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

      // Always get current position with high accuracy
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5), // Reduced timeout
      );

      // Store the precise coordinates in state
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      return position;
    } catch (e) {
      // Try with last known position if getting current position fails
      try {
        final lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          // Store the last known coordinates in state
          setState(() {
            _latitude = lastPosition.latitude;
            _longitude = lastPosition.longitude;
          });
          return lastPosition;
        }
      } catch (_) {
        // If even that fails, rethrow the original exception
      }
      rethrow;
    }
  }

  // Show a dialog asking the user to enable location services
  Future<bool> _showEnableLocationDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Location Services Disabled'),
              content: const Text(
                'Location services are disabled. The app needs your location to '
                'calculate sunrise and sunset times. Please enable location services.',
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('CANCEL'),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
                FilledButton(
                  child: const Text('ENABLE LOCATION'),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                ),
              ],
            );
          },
        ) ??
        false;
  }

  DateTime _parseDateTime(String dateStr, String timeStr) {
    // Convert 12-hour format to 24-hour format
    bool isPM = timeStr.contains('PM');
    timeStr = timeStr.replaceAll(' AM', '').replaceAll(' PM', '');

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
  }

  Future<void> _refreshNotifications() async {
    setState(() => _isLoading = true);

    try {
      if (_latitude == null || _longitude == null) {
        throw Exception('Location not available. Please try again.');
      }

      _cancelAllNotifications();
      var data = await saveNewSunTimes();
      // Process the API response data
      List<dynamic> results = data['results'];
      print("result type : ${results.runtimeType}");
      if (results.isEmpty) {
        throw Exception('No sun times data available');
      }

      _showSuccessSnackBar(
        "Setting Notifications For Next 30 Days, Please Wait...",
      );

      for (int i = 0; i < results.length; i++) {
        var dayData = results[i];

        // Create DateTime objects for the key times
        final dateStr = dayData['date'];
        final sunriseStr = dayData['sunrise'];
        final sunsetStr = dayData['sunset'];
        final solarNoonStr = dayData['solar_noon'];

        // Parse the date and times
        DateTime sunriseTime = _parseDateTime(dateStr, sunriseStr);
        DateTime sunsetTime = _parseDateTime(dateStr, sunsetStr);
        DateTime solarNoonTime = _parseDateTime(dateStr, solarNoonStr);

        _scheduleNotification(
          sunriseTime,
          "Sunrise Time:$sunsetTime",
          "Please Chant The Following Mantra For Morning",
        );

        _scheduleNotification(
          solarNoonTime,
          "Solar Noon Time:$solarNoonTime",
          "Please Chant The Following Mantra For Afternoon",
        );

        _scheduleNotification(
          sunsetTime,
          "Sunset Time:$sunsetTime",
          "Please Chant The Following Mantra For Evening",
        );

        print('Sunrise: $sunriseTime');
        print('Sunset: $sunsetTime');
        print('Solar Noon: $solarNoonTime');
      } // Schedule notification for 2 minutes in the future

      // Just show a success message instead of trying to fetch sun times
      _showSuccessSnackBar('All notifications cancelled and rescheduled');
    } catch (e) {
      _showErrorSnackBar('Failed to refresh notifications: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _sendTestNotification() {
    // Schedule time for 1 minute from now
    final scheduledTime = DateTime.now().add(const Duration(minutes: 1));
    final utcScheduledTime = scheduledTime.toUtc();

    print(
      'Scheduling test notification in UTC: ${utcScheduledTime.toString()}',
    );

    // Create a test notification that will show after 1 minute
    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 999,
        channelKey: 'basic_channel',
        title: 'Test Notification',
        body:
            'Dismiss this notification to see it reschedule in $_rescheduleMinutes minutes',
      ),
      schedule: NotificationCalendar.fromDate(
        date: utcScheduledTime,
        preciseAlarm: true,
      ),
    );

    _showSuccessSnackBar('Test notification scheduled for 1 minute from now');
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  void _scheduleNotification(DateTime sTime, String title, String body) {
    try {
      final notificationId = _id!;
      _id = notificationId + 1;

      // Convert to UTC to avoid timezone issues
      final utcTime = sTime.toUtc();
      print('Scheduling notification in UTC: ${utcTime.toString()}');

      AwesomeNotifications()
          .createNotification(
            content: NotificationContent(
              id: notificationId,
              channelKey: 'basic_channel',
              title: title,
              body: body,
            ),
            schedule: NotificationCalendar.fromDate(
              date: utcTime,
              preciseAlarm: true,
            ),
          )
          .then((_) {
            print(
              'Notification scheduled successfully for $sTime with id $notificationId',
            );
          })
          .catchError((error) {
            print('Error scheduling notification: $error');
          });
    } catch (e) {
      print('Exception when scheduling notification: $e');
    }
  }

  void _showRescheduleDialog() {
    int tempMinutes = _rescheduleMinutes;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Set Reschedule Time'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'When notifications are dismissed, they will reappear after:',
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$tempMinutes minutes',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: tempMinutes.toDouble(),
                        min: 1,
                        max: 60,
                        divisions: 59,
                        label: '$tempMinutes minutes',
                        onChanged: (value) {
                          setDialogState(() {
                            tempMinutes = value.round();
                          });
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CANCEL'),
                    ),
                    FilledButton(
                      onPressed: () {
                        _saveRescheduleTime(tempMinutes);
                        Navigator.pop(context);
                      },
                      child: const Text('SAVE'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showCancelConfirmationDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Cancel All Notifications'),
            content: const Text(
              'Are you sure you want to cancel all scheduled notifications?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('NO'),
              ),
              FilledButton(
                onPressed: () {
                  _cancelAllNotifications();
                  Navigator.pop(context);
                  _showSuccessSnackBar('All notifications cancelled');
                },
                child: const Text('YES'),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _initializeSettings,
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(16.0),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // Location Status Card
                          Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        color: colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Location Status',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (_latitude != null && _longitude != null)
                                    RichText(
                                      text: TextSpan(
                                        style: TextStyle(
                                          color: colorScheme.onSurface,
                                        ),
                                        children: [
                                          const TextSpan(
                                            text: 'Current location: ',
                                          ),
                                          TextSpan(
                                            text:
                                                '${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    Text(
                                      'Location not available',
                                      style: TextStyle(
                                        color: colorScheme.error,
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  FilledButton.icon(
                                    onPressed: _refreshNotifications,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text(
                                      'Schedule Sun Notifications',
                                    ),
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(
                                        double.infinity,
                                        44,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Notification Settings Card
                          Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.notifications_active,
                                        color: colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Notification Settings',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.timer),
                                  title: const Text('Reschedule Time'),
                                  subtitle: Text('$_rescheduleMinutes minutes'),
                                  onTap: _showRescheduleDialog,
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.send),
                                  title: const Text('Test Notification'),
                                  subtitle: const Text(
                                    'Send a notification to test which will trigger after 1m',
                                  ),
                                  onTap: _sendTestNotification,
                                ),
                              ],
                            ),
                          ),

                          // Notification Management Card
                          Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.settings,
                                        color: colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Notification Management',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.list),
                                  title: const Text('List Notifications'),
                                  subtitle: const Text(
                                    'View all scheduled notifications in console',
                                  ),
                                  onTap: _listNotifications,
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: Icon(
                                    Icons.cancel_outlined,
                                    color: colorScheme.error,
                                  ),
                                  title: const Text('Cancel All Notifications'),
                                  subtitle: const Text(
                                    'Remove all scheduled notifications',
                                  ),
                                  onTap: _showCancelConfirmationDialog,
                                ),
                              ],
                            ),
                          ),

                          // About Section
                          Card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'About',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  title: const Text('Version'),
                                  subtitle: const Text('1.0.0'),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  title: const Text('Developer'),
                                  subtitle: const Text('Sun Notification App'),
                                ),
                              ],
                            ),
                          ),

                          // Space at the bottom for better scrolling
                          const SizedBox(height: 16),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
