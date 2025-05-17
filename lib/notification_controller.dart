import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class NotificationController {
  /// Use this method to detect when a new notification or a schedule is created

  // Key for storing the reschedule time in settings file
  static const String rescheduleTimeKey = 'notification_reschedule_minutes';
  // Default reschedule time in minutes (if not set in settings)
  static const int defaultRescheduleMinutes = 15;
  // File name for settings
  static const String settingsFileName = 'settings.json';

  /// Get the settings file path
  static Future<String> _getSettingsFilePath() async {
    final dir = await getDownloadsDirectory();
    if (dir == null) {
      // Fallback to application documents directory if downloads not available
      final docDir = await getApplicationDocumentsDirectory();
      return path.join(docDir.path, settingsFileName);
    }
    return path.join(dir.path, settingsFileName);
  }

  /// Load settings from file
  static Future<Map<String, dynamic>> _loadSettings() async {
    try {
      final filePath = await _getSettingsFilePath();
      final file = File(filePath);

      if (await file.exists()) {
        final contents = await file.readAsString();
        return jsonDecode(contents) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }

    // Return default settings if file doesn't exist or there's an error
    return {rescheduleTimeKey: defaultRescheduleMinutes};
  }

  /// Save settings to file
  static Future<void> _saveSettings(Map<String, dynamic> settings) async {
    try {
      final filePath = await _getSettingsFilePath();
      final file = File(filePath);

      // Convert settings to JSON string and write to file
      final jsonString = jsonEncode(settings);
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  /// Use this method to detect if the user dismissed a notification
  @pragma('vm:entry-point')
  static Future<void> onDismissActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    debugPrint('Notification dismissed: ${receivedAction.id}');

    int rescheduleMinutes;

    try {
      // Try to get the reschedule time from settings file
      final settings = await _loadSettings();
      rescheduleMinutes =
          settings[rescheduleTimeKey] ?? defaultRescheduleMinutes;
    } catch (e) {
      // If loading settings fails, use the default value
      debugPrint('Error accessing settings: $e');
      rescheduleMinutes = defaultRescheduleMinutes;
    }

    // Ensure we don't exceed the maximum of 60 minutes
    final adjustedRescheduleMinutes =
        rescheduleMinutes > 60 ? 60 : rescheduleMinutes;

    // Calculate the new time for the rescheduled notification
    final scheduleTime = DateTime.now().add(
      Duration(minutes: adjustedRescheduleMinutes),
    );

    debugPrint(
      'Rescheduling notification for $scheduleTime (in $adjustedRescheduleMinutes minutes)',
    );

    // Create a new notification that will show after the specified time
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: receivedAction.id ?? 0, // Use same ID to replace
        channelKey: 'basic_channel',
        title: receivedAction.title ?? 'Rescheduled Notification',
        body: receivedAction.body ?? 'This is a rescheduled notification',
      ),
      schedule: NotificationCalendar(
        year: scheduleTime.year,
        month: scheduleTime.month,
        day: scheduleTime.day,
        hour: scheduleTime.hour,
        minute: scheduleTime.minute,
        second: 0,
        preciseAlarm: true,
      ),
    );
  }

  /// Use this method to detect when the user taps on a notification or action button
  @pragma('vm:entry-point')
  static Future<void> onActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    debugPrint('Notification action received: ${receivedAction.id}');

    // Navigate according to notification action here
    // You could use Navigator.of(context).pushNamed() or similar as needed
  }

  /// Get the current reschedule time setting
  static Future<int> getRescheduleMinutes() async {
    final settings = await _loadSettings();
    return settings[rescheduleTimeKey] ?? defaultRescheduleMinutes;
  }

  /// Save a new reschedule time setting
  static Future<bool> setRescheduleMinutes(int minutes) async {
    // Enforce the maximum of 60 minutes
    final adjustedMinutes = minutes > 60 ? 60 : (minutes < 1 ? 1 : minutes);

    try {
      final settings = await _loadSettings();
      settings[rescheduleTimeKey] = adjustedMinutes;
      await _saveSettings(settings);
      return true;
    } catch (e) {
      debugPrint('Error saving reschedule minutes: $e');
      return false;
    }
  }
}
