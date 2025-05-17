import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'notification_controller.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';

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
  String? _lastLoadedSadhnaFile;

  @override
  void initState() {
    super.initState();
    _initializeSettings();
  }

  /// Fetches sun times data for the next 30 days and saves it to a file.
  Future<Map<String, dynamic>> saveNewSunTimes() async {
    var date = DateTime.now();
    var dateStart =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    var endDate = date.add(const Duration(days: 30));
    var dateEnd =
        "${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";
    final url =
        "https://api.sunrisesunset.io/json?lat=$_latitude&lng=$_longitude&date_start=$dateStart&date_end=$dateEnd&formatted=0";
    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('Failed to load sun times');
    }

    final dir = await getDownloadsDirectory();
    final file = File(path.join(dir!.path, 'SunriseTimes.json'));
    await file.writeAsString(response.body);

    return jsonDecode(response.body);
  }

  /// Initializes app settings: permissions, reschedule time, and location.
  Future<void> _initializeSettings() async {
    setState(() => _isLoading = true);
    try {
      await _requestNotificationPermission();
      await _loadRescheduleTime();
      try {
        final location = await _getLocation();
        setState(() {
          _latitude = location.latitude;
          _longitude = location.longitude;
        });
      } catch (e) {
        // Continue even if location fails
      }
    } catch (e) {
      _showErrorSnackBar('Failed to initialize settings: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRescheduleTime() async {
    final minutes = await NotificationController.getRescheduleMinutes();
    setState(() => _rescheduleMinutes = minutes);
  }

  Future<void> _saveRescheduleTime(int minutes) async {
    await NotificationController.setRescheduleMinutes(minutes);
    setState(() => _rescheduleMinutes = minutes);
    _showSuccessSnackBar(
      'Notification reschedule time set to $minutes minutes',
    );
  }

  Future<void> _requestNotificationPermission() async {
    final isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  void _listNotifications() {
    AwesomeNotifications().listScheduledNotifications().then((notifications) {
      _showSuccessSnackBar(
        '${notifications.length} notifications listed in console',
      );
    });
  }

  void _cancelAllNotifications() {
    AwesomeNotifications().cancelAllSchedules();
  }

  Future<Position> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        bool enableService = await _showEnableLocationDialog();
        if (enableService) {
          await Geolocator.openLocationSettings();
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

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      return position;
    } catch (e) {
      final lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null) {
        setState(() {
          _latitude = lastPosition.latitude;
          _longitude = lastPosition.longitude;
        });
        return lastPosition;
      }
      rethrow;
    }
  }

  Future<bool> _showEnableLocationDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => AlertDialog(
                title: const Text(
                  'Location Services Disabled',
                  style: TextStyle(color: Colors.black),
                ),
                content: const Text(
                  'Location services are disabled. The app needs your location to '
                  'calculate sunrise and sunset times. Please enable location services.',
                  style: TextStyle(color: Colors.black),
                ),
                actions: [
                  TextButton(
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(color: Colors.black),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('ENABLE LOCATION'),
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
        ) ??
        false;
  }

  DateTime _parseDateTime(String dateStr, String timeStr) {
    bool isPM = timeStr.contains('PM');
    timeStr = timeStr.replaceAll(' AM', '').replaceAll(' PM', '');
    List<String> timeParts = timeStr.split(':');
    int hours = int.parse(timeParts[0]);

    if (isPM && hours != 12) hours += 12;
    if (!isPM && hours == 12) hours = 0;

    timeStr =
        '${hours.toString().padLeft(2, '0')}:${timeParts[1]}:${timeParts[2]}';
    return DateTime.parse('${dateStr}T$timeStr');
  }

  Future<void> _refreshNotifications() async {
    setState(() => _isLoading = true);
    try {
      if (_latitude == null || _longitude == null) {
        throw Exception('Location not available. Please try again.');
      }

      _cancelAllNotifications();
      var data = await saveNewSunTimes();
      List<dynamic> results = data['results'];
      if (results.isEmpty) {
        throw Exception('No sun times data available');
      }

      _showSuccessSnackBar("Setting Notifications For Next 30 Days...");
      for (var dayData in results) {
        final dateStr = dayData['date'];
        final sunriseStr = dayData['sunrise'];
        final sunsetStr = dayData['sunset'];
        final solarNoonStr = dayData['solar_noon'];

        DateTime sunriseTime = _parseDateTime(dateStr, sunriseStr);
        DateTime sunsetTime = _parseDateTime(dateStr, sunsetStr);
        DateTime solarNoonTime = _parseDateTime(dateStr, solarNoonStr);
        print(
          'Scheduled notification at sunriseTime: $sunriseTime and dateStr: $dateStr',
        );
        _scheduleNotification(
          sunriseTime,
          "Sunrise Time:$sunriseTime",
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
      }
      _showSuccessSnackBar('All notifications cancelled and rescheduled');
    } catch (e) {
      _showErrorSnackBar('Failed to refresh notifications: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _sendTestNotification() {
    final scheduledTime = DateTime.now().add(const Duration(minutes: 1));
    final utcScheduledTime = scheduledTime.toUtc();

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
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: theme.colorScheme.surface,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: theme.colorScheme.onError),
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        backgroundColor: theme.colorScheme.error,
      ),
    );
  }

  void _scheduleNotification(DateTime sTime, String title, String body) {
    final notificationId = _id!;
    _id = notificationId + 1;
    final utcTime = sTime.toUtc();

    AwesomeNotifications().createNotification(
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
    );
  }

  void _showRescheduleDialog() {
    int tempMinutes = _rescheduleMinutes;
    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text(
                    'Set Reschedule Time',
                    style: TextStyle(color: Colors.black),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'When notifications are dismissed, they will reappear after:',
                        style: TextStyle(color: Colors.black),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          '$tempMinutes minutes',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      Slider(
                        value: tempMinutes.toDouble(),
                        min: 1,
                        max: 60,
                        divisions: 59,
                        label: '$tempMinutes minutes',
                        onChanged:
                            (value) => setDialogState(
                              () => tempMinutes = value.round(),
                            ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                    FilledButton(
                      onPressed: () {
                        _saveRescheduleTime(tempMinutes);
                        Navigator.pop(context);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
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
            title: const Text(
              'Cancel All Notifications',
              style: TextStyle(color: Colors.black),
            ),
            content: const Text(
              'Are you sure you want to cancel all scheduled notifications?',
              style: TextStyle(color: Colors.black),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('NO', style: TextStyle(color: Colors.black)),
              ),
              FilledButton(
                onPressed: () {
                  _cancelAllNotifications();
                  Navigator.pop(context);
                  _showSuccessSnackBar('All notifications cancelled');
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                child: const Text('YES'),
              ),
            ],
          ),
    );
  }

  /// Loads a Sadhna file from device storage and replaces sadhnaMantra.json
  Future<void> _loadSadhnaFile() async {
    try {
      setState(() => _isLoading = true);

      // Open file picker to select JSON file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) {
        _showErrorSnackBar('No file selected');
        return;
      }

      // Get the selected file path
      final filePath = result.files.single.path;
      if (filePath == null) {
        _showErrorSnackBar('Unable to access selected file');
        return;
      }

      // Read the selected JSON file
      final selectedFile = File(filePath);
      final String jsonContent = await selectedFile.readAsString();

      // Verify it's valid JSON with the correct structure
      try {
        final dynamic jsonData = jsonDecode(jsonContent);
        if (jsonData == null) {
          _showErrorSnackBar('Selected file does not contain valid JSON data');
          return;
        }

        // Verify JSON structure has years as keys
        if (jsonData is! Map<String, dynamic>) {
          _showErrorSnackBar(
            'Invalid sadhnaMantra file format: must contain year entries',
          );
          return;
        }

        // Create backup of existing file before replacement
        final dir = await getDownloadsDirectory();
        if (dir == null) {
          _showErrorSnackBar('Could not access downloads directory');
          return;
        }

        final destFilePath = path.join(dir.path, 'sadhnaMantra.json');
        final destFile = File(destFilePath);

        // Create backup if the original file exists
        if (await destFile.exists()) {
          final backupPath = path.join(
            dir.path,
            'sadhnaMantra_backup_${DateTime.now().millisecondsSinceEpoch}.json',
          );
          await destFile.copy(backupPath);
          print('Created backup at: $backupPath');
        }

        // Copy content to destination file
        await destFile.writeAsString(jsonContent);

        setState(() {
          _lastLoadedSadhnaFile = path.basename(filePath);
        });

        // Force reports page to reload data on next visit
        await _refreshDataInReportsPage();

        _showSuccessSnackBar(
          'Sadhna file loaded successfully: ${path.basename(filePath)}',
        );
      } catch (e) {
        _showErrorSnackBar(
          'Invalid JSON format in selected file: ${e.toString()}',
        );
        return;
      }
    } catch (e) {
      _showErrorSnackBar('Error loading Sadhna file: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Forces reports page to reload data on next visit
  Future<void> _refreshDataInReportsPage() async {
    // This method doesn't need to do anything as the Reports page reads
    // the file every time it's loaded, but we could add additional logic here
    // if needed in the future
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(color: theme.appBarTheme.foregroundColor),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                ),
              )
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
                            color: Colors.white,
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        color: Colors.black,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Location Status',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (_latitude != null && _longitude != null)
                                    RichText(
                                      text: TextSpan(
                                        style: const TextStyle(
                                          color: Colors.black,
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
                                    const Text(
                                      'Location not available',
                                      style: TextStyle(color: Colors.black),
                                    ),
                                  const SizedBox(height: 8),
                                  FilledButton.icon(
                                    onPressed: _refreshNotifications,
                                    icon: const Icon(
                                      Icons.refresh,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      'Re-Schedule Notifications For 30 Days',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.black,
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

                          // Sadhna File Card
                          Card(
                            color: Colors.white,
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.file_present,
                                        color: Colors.black,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Sadhna File',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (_lastLoadedSadhnaFile != null)
                                    Text(
                                      'Last loaded: $_lastLoadedSadhnaFile',
                                      style: const TextStyle(
                                        color: Colors.black,
                                      ),
                                    )
                                  else
                                    const Text(
                                      'No Sadhna file loaded',
                                      style: TextStyle(color: Colors.black),
                                    ),
                                  const SizedBox(height: 16),
                                  FilledButton.icon(
                                    onPressed: _loadSadhnaFile,
                                    icon: const Icon(
                                      Icons.file_upload,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      'Load Sadhna File',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.black,
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
                            color: Colors.white,
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.notifications_active,
                                        color: Colors.black,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Notification Settings',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1, color: Colors.black),
                                ListTile(
                                  leading: const Icon(
                                    Icons.timer,
                                    color: Colors.black,
                                  ),
                                  title: const Text(
                                    'Remind Me After',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  subtitle: Text(
                                    '$_rescheduleMinutes minutes',
                                    style: const TextStyle(color: Colors.black),
                                  ),
                                  onTap: _showRescheduleDialog,
                                ),
                                const Divider(height: 1, color: Colors.black),
                                ListTile(
                                  leading: const Icon(
                                    Icons.send,
                                    color: Colors.black,
                                  ),
                                  title: const Text(
                                    'Test Notification (Developer Only)',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  subtitle: const Text(
                                    'Send a notification to test which will trigger after 1m',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  onTap: _sendTestNotification,
                                ),
                              ],
                            ),
                          ),
                          // Notification Management Card
                          Card(
                            color: Colors.white,
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.settings,
                                        color: Colors.black,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Notification Management',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1, color: Colors.black),
                                ListTile(
                                  leading: const Icon(
                                    Icons.list,
                                    color: Colors.black,
                                  ),
                                  title: const Text(
                                    'List Notifications',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  subtitle: const Text(
                                    'View all scheduled notifications in console',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  onTap: _listNotifications,
                                ),
                                const Divider(height: 1, color: Colors.black),
                                ListTile(
                                  leading: const Icon(
                                    Icons.cancel_outlined,
                                    color: Colors.black,
                                  ),
                                  title: const Text(
                                    'Cancel All Notifications',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  subtitle: const Text(
                                    'Remove all scheduled notifications',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  onTap: _showCancelConfirmationDialog,
                                ), // No dark mode toggle - removed
                              ],
                            ),
                          ),

                          // About Section
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
