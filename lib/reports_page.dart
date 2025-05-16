import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  Map<String, dynamic> defaultData = {};
  bool _isLoading = true;
  DateTime? _selectedDate;
  DateTime _focusedDay = DateTime.now();

  // Static constant for default day data
  static const Map<String, dynamic> _defaultDayData = {
    "morning": false,
    "afternoon": false,
    "night": false,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      defaultData = await _getData();
    } catch (e) {
      print('Error loading data: $e');
      // Initialize with empty data or handle error appropriately
      defaultData = {};
      // Optionally, create default data for the current year/month if needed
      // For now, sticking to the original logic of creating 2025 data if file is missing.
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _getData() async {
    final dir = await getDownloadsDirectory();
    if (dir == null) {
      throw Exception('Could not access downloads directory');
    }
    final fileName = 'sadhnaMantra.json';
    final filePath = path.join(dir.path, fileName);
    print('File path: $filePath');

    if (await File(filePath).exists()) {
      print('File exists. Reading...');
      final file = File(filePath);
      final contents = await file.readAsString();
      if (contents.isEmpty) {
        print('File is empty. Returning default structure.');
        return _createDefaultDataStructure();
      }
      try {
        final jsonData = jsonDecode(contents);
        return jsonData as Map<String, dynamic>;
      } catch (e) {
        print('Error decoding JSON: $e. Returning default structure.');
        return _createDefaultDataStructure();
      }
    } else {
      print('File does not exist. Creating with default data...');
      final Map<String, dynamic> newDefaultData = _createDefaultDataStructure();
      final file = File(filePath);
      await file.writeAsString(jsonEncode(newDefaultData));
      print('Default data file created at $filePath');
      return newDefaultData;
    }
  }

  Map<String, dynamic> _createDefaultDataStructure() {
    // Creates the default data for 2025, May as per original logic
    // You might want to make this more dynamic for current year/month if needed
    return {
      "2025": {
        "05": {
          "01": {"morning": true, "afternoon": false, "night": true},
          "02": _defaultDayData,
          "03": _defaultDayData,
          "04": _defaultDayData,
          "05": _defaultDayData,
          "06": _defaultDayData,
          "07": _defaultDayData,
          "08": _defaultDayData,
          "09": _defaultDayData,
          "10": _defaultDayData,
          "11": _defaultDayData,
          "12": _defaultDayData,
          "13": _defaultDayData,
          "14": _defaultDayData,
          "15": _defaultDayData,
          "16": _defaultDayData,
          "17": _defaultDayData,
          "18": _defaultDayData,
          "19": _defaultDayData,
          "20": _defaultDayData,
          "21": _defaultDayData,
          "22": _defaultDayData,
          "23": _defaultDayData,
          "24": _defaultDayData,
          "25": _defaultDayData,
          "26": _defaultDayData,
          "27": _defaultDayData,
          "28": _defaultDayData,
          "29": _defaultDayData,
          "30": _defaultDayData,
          "31": _defaultDayData,
        },
      },
    };
  }

  Future<void> _saveData(Map<String, dynamic> data) async {
    try {
      final dir = await getDownloadsDirectory();
      if (dir == null) {
        throw Exception('Could not access downloads directory');
      }
      final fileName = 'sadhnaMantra.json';
      final filePath = path.join(dir.path, fileName);
      final file = File(filePath);
      final jsonString = jsonEncode(data);
      await file.writeAsString(jsonString);
      print('Data saved successfully to $filePath');
    } catch (e) {
      print('Error saving data: $e');
    }
  }

  Map<String, dynamic>? _getSelectedDateData() {
    if (_selectedDate == null) return null;
    final year = _selectedDate!.year.toString();
    final month = _selectedDate!.month.toString().padLeft(2, '0');
    final day = _selectedDate!.day.toString().padLeft(2, '0');

    final yearData = defaultData[year] as Map<String, dynamic>?;
    if (yearData != null) {
      final monthData = yearData[month] as Map<String, dynamic>?;
      if (monthData != null) {
        final dayData = monthData[day] as Map<String, dynamic>?;
        if (dayData != null) {
          return dayData;
        }
      }
    }
    // Return a copy of default day data if no specific data found
    // This ensures that if a new date is selected, it has the default structure
    return Map<String, dynamic>.from(_defaultDayData);
  }

  void _updateReminderStatus(String timeSlot, bool value) {
    if (_selectedDate == null) return;
    final year = _selectedDate!.year.toString();
    final month = _selectedDate!.month.toString().padLeft(2, '0');
    final day = _selectedDate!.day.toString().padLeft(2, '0');

    // Ensure path exists in the map
    defaultData.putIfAbsent(year, () => <String, dynamic>{});
    (defaultData[year] as Map<String, dynamic>).putIfAbsent(
      month,
      () => <String, dynamic>{},
    );
    (defaultData[year][month] as Map<String, dynamic>).putIfAbsent(
      day,
      () => Map<String, dynamic>.from(_defaultDayData),
    );

    defaultData[year][month][day][timeSlot] = value;
    _saveData(defaultData);
    setState(() {}); // Rebuild to reflect changes
  }

  Widget _buildReminderItem({
    required String title,
    required bool isDone,
    required VoidCallback? onMarkAsDone,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).textTheme.titleMedium?.color,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child:
              isDone
                  ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    decoration: BoxDecoration(
                      color:
                          isDarkMode
                              ? Colors.grey[800]!.withOpacity(0.5)
                              : Colors.grey[200],
                      border: Border.all(
                        color:
                            isDarkMode ? Colors.grey[700]! : Colors.grey[400]!,
                        width: 1.0,
                      ),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color:
                              isDarkMode
                                  ? Colors.green[300]
                                  : Colors.green[600],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Completed',
                          style: TextStyle(
                            color:
                                isDarkMode
                                    ? Colors.green[300]
                                    : Colors.green[600],
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  )
                  : Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12.0),
                      boxShadow: [
                        if (!isDarkMode)
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                    child: OutlinedButton(
                      onPressed: onMarkAsDone,
                      style: OutlinedButton.styleFrom(
                        backgroundColor:
                            isDarkMode
                                ? Colors.grey[800]!.withOpacity(0.3)
                                : Colors.white,
                        side: BorderSide(
                          color:
                              isDarkMode
                                  ? Colors.blue.withOpacity(0.5)
                                  : Colors.blue.shade300,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                      ),
                      child: Text(
                        'Mark As Done',
                        style: TextStyle(
                          color:
                              isDarkMode
                                  ? Colors.blue[300]
                                  : Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final ThemeData theme = Theme.of(context);

    final selectedDateData = _getSelectedDateData();
    final bool morningDone = selectedDateData?["morning"] ?? false;
    final bool afternoonDone = selectedDateData?["afternoon"] ?? false;
    final bool nightDone = selectedDateData?["night"] ?? false;

    // Adjust firstDay to be more robust for general use
    final DateTime originalFirstDay = DateTime.utc(2025, 5, 1);
    DateTime calendarFirstDay = originalFirstDay;

    // Ensure _focusedDay is within the valid range of the calendar
    if (_focusedDay.isBefore(calendarFirstDay)) {
      _focusedDay = calendarFirstDay;
    }
    DateTime calendarLastDay = DateTime.now().add(
      const Duration(days: 365 * 5),
    ); // Allow viewing future for 5 years

    if (_focusedDay.isAfter(calendarLastDay)) {
      _focusedDay = calendarLastDay;
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Sadhana Reports',
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
        centerTitle: true,
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                ),
              )
              : SafeArea(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 12.0,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                isDarkMode
                                    ? theme.colorScheme.surface.withOpacity(0.8)
                                    : theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(16.0),
                            boxShadow: [
                              if (!isDarkMode)
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Calendar header with custom styling
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16.0,
                                  horizontal: 16.0,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isDarkMode
                                          ? theme.colorScheme.primary
                                              .withOpacity(0.2)
                                          : theme.colorScheme.primary
                                              .withOpacity(0.1),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16.0),
                                    topRight: Radius.circular(16.0),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.chevron_left_rounded,
                                        color: theme.colorScheme.primary,
                                        size: 28,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _focusedDay = DateTime(
                                            _focusedDay.year,
                                            _focusedDay.month - 1,
                                          );
                                        });
                                      },
                                      splashRadius: 20,
                                    ),
                                    Column(
                                      children: [
                                        Text(
                                          _getMonthYearText(_focusedDay),
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _selectedDate != null
                                              ? 'Selected: ${_formatDate(_selectedDate!)}'
                                              : 'Select a date',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color:
                                                isDarkMode
                                                    ? theme
                                                        .colorScheme
                                                        .onSurface
                                                        .withOpacity(0.7)
                                                    : theme
                                                        .colorScheme
                                                        .onSurface
                                                        .withOpacity(0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.chevron_right_rounded,
                                        color: theme.colorScheme.primary,
                                        size: 28,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _focusedDay = DateTime(
                                            _focusedDay.year,
                                            _focusedDay.month + 1,
                                          );
                                        });
                                      },
                                      splashRadius: 20,
                                    ),
                                  ],
                                ),
                              ),
                              // Days of week header with custom styling
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: _buildDaysOfWeekHeaders(
                                    isDarkMode,
                                    theme,
                                  ),
                                ),
                              ),
                              // Calendar
                              TableCalendar(
                                firstDay: calendarFirstDay,
                                lastDay: calendarLastDay,
                                focusedDay: _focusedDay,
                                selectedDayPredicate: (day) {
                                  return _selectedDate != null &&
                                      isSameDay(_selectedDate!, day);
                                },
                                onDaySelected: (selectedDay, focusedDay) {
                                  // Allow selection only up to today
                                  if (selectedDay.isAfter(
                                    DateTime.now()
                                        .add(const Duration(days: 1))
                                        .subtract(
                                          const Duration(microseconds: 1),
                                        ),
                                  )) {
                                    setState(() {
                                      // _selectedDate remains null or previous
                                      _focusedDay =
                                          focusedDay; // Allow focusing future days
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "Cannot select future dates for marking tasks.",
                                          style: TextStyle(
                                            color: theme.colorScheme.onError,
                                          ),
                                        ),
                                        backgroundColor:
                                            theme.colorScheme.error,
                                      ),
                                    );
                                    return;
                                  }
                                  setState(() {
                                    _selectedDate = selectedDay;
                                    _focusedDay = focusedDay;
                                  });
                                },
                                headerVisible:
                                    false, // Hide default header since we have custom one
                                daysOfWeekVisible:
                                    false, // Hide default days of week since we have custom ones
                                rowHeight: 48, // Slightly taller rows
                                calendarFormat: CalendarFormat.month,
                                calendarBuilders: CalendarBuilders(
                                  markerBuilder: (context, date, events) {
                                    final year = date.year.toString();
                                    final month = date.month.toString().padLeft(
                                      2,
                                      '0',
                                    );
                                    final day = date.day.toString().padLeft(
                                      2,
                                      '0',
                                    );

                                    // Check if date has any completion status
                                    bool hasSomeCompletion = false;
                                    bool hasFullCompletion = false;
                                    int completedTasks = 0;

                                    if (defaultData.containsKey(year) &&
                                        defaultData[year].containsKey(month) &&
                                        defaultData[year][month].containsKey(
                                          day,
                                        )) {
                                      final timeSlots =
                                          defaultData[year][month][day];
                                      if (timeSlots is Map) {
                                        if (timeSlots["morning"] == true)
                                          completedTasks++;
                                        if (timeSlots["afternoon"] == true)
                                          completedTasks++;
                                        if (timeSlots["night"] == true)
                                          completedTasks++;
                                      }

                                      hasSomeCompletion = completedTasks > 0;
                                      hasFullCompletion = completedTasks == 3;
                                    }

                                    bool isPastDay =
                                        date.isBefore(DateTime.now()) &&
                                        !isSameDay(date, DateTime.now());

                                    if (hasSomeCompletion || isPastDay) {
                                      return Positioned(
                                        bottom: 2,
                                        left: 0,
                                        right: 0,
                                        child: Center(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (hasFullCompletion)
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    color: Colors.green,
                                                    shape: BoxShape.circle,
                                                  ),
                                                )
                                              else if (hasSomeCompletion)
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    color: Colors.amber,
                                                    shape: BoxShape.circle,
                                                  ),
                                                )
                                              else if (isPastDay)
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    color: Colors.redAccent,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                    return null;
                                  },
                                  // Custom day cell styling
                                  defaultBuilder: (context, day, focusedDay) {
                                    return _buildCalendarDay(
                                      day,
                                      isDarkMode,
                                      theme,
                                      false,
                                      false,
                                    );
                                  },
                                  selectedBuilder: (context, day, focusedDay) {
                                    return _buildCalendarDay(
                                      day,
                                      isDarkMode,
                                      theme,
                                      true,
                                      false,
                                    );
                                  },
                                  todayBuilder: (context, day, focusedDay) {
                                    return _buildCalendarDay(
                                      day,
                                      isDarkMode,
                                      theme,
                                      false,
                                      true,
                                    );
                                  },
                                  outsideBuilder: (context, day, focusedDay) {
                                    return _buildCalendarDay(
                                      day,
                                      isDarkMode,
                                      theme,
                                      false,
                                      false,
                                      isOutsideDay: true,
                                    );
                                  },
                                ),
                                calendarStyle: CalendarStyle(
                                  // Most styling is handled by custom builders now
                                  cellMargin: const EdgeInsets.all(4),
                                  cellPadding: EdgeInsets.zero,
                                  // We hide these default decorations with Colors.transparent
                                  todayDecoration: const BoxDecoration(
                                    color: Colors.transparent,
                                  ),
                                  selectedDecoration: const BoxDecoration(
                                    color: Colors.transparent,
                                  ),
                                  defaultDecoration: const BoxDecoration(
                                    color: Colors.transparent,
                                  ),
                                  outsideDecoration: const BoxDecoration(
                                    color: Colors.transparent,
                                  ),
                                  weekendDecoration: const BoxDecoration(
                                    color: Colors.transparent,
                                  ),
                                  // Still need to hide the text since custom builder handles it
                                  todayTextStyle: const TextStyle(
                                    color: Colors.transparent,
                                  ),
                                  selectedTextStyle: const TextStyle(
                                    color: Colors.transparent,
                                  ),
                                  defaultTextStyle: const TextStyle(
                                    color: Colors.transparent,
                                  ),
                                  outsideTextStyle: const TextStyle(
                                    color: Colors.transparent,
                                  ),
                                  weekendTextStyle: const TextStyle(
                                    color: Colors.transparent,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Legend for the markers
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildLegendItem(
                                      'Completed',
                                      Colors.green,
                                      isDarkMode,
                                      theme,
                                    ),
                                    const SizedBox(width: 16),
                                    _buildLegendItem(
                                      'Partial',
                                      Colors.amber,
                                      isDarkMode,
                                      theme,
                                    ),
                                    const SizedBox(width: 16),
                                    _buildLegendItem(
                                      'Missed',
                                      Colors.redAccent,
                                      isDarkMode,
                                      theme,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_selectedDate != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 16.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isDarkMode
                                          ? theme.colorScheme.primary
                                              .withOpacity(0.15)
                                          : theme.colorScheme.primary
                                              .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.event_note,
                                      size: 20,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Status for: ${_formatDate(_selectedDate!)}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(20.0),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    if (!isDarkMode)
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildReminderItem(
                                      title: 'Morning Gayatri',
                                      isDone: morningDone,
                                      onMarkAsDone:
                                          () => _updateReminderStatus(
                                            'morning',
                                            true,
                                          ),
                                    ),
                                    _buildReminderItem(
                                      title: 'Afternoon Gayatri',
                                      isDone: afternoonDone,
                                      onMarkAsDone:
                                          () => _updateReminderStatus(
                                            'afternoon',
                                            true,
                                          ),
                                    ),
                                    _buildReminderItem(
                                      title: 'Night Gayatri',
                                      isDone: nightDone,
                                      onMarkAsDone:
                                          () => _updateReminderStatus(
                                            'night',
                                            true,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
    );
  }

  // Helper method to format a date as YYYY-MM-DD
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Helper method to get formatted month and year text
  String _getMonthYearText(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  // Helper method to build custom day cells
  Widget _buildCalendarDay(
    DateTime day,
    bool isDarkMode,
    ThemeData theme,
    bool isSelected,
    bool isToday, {
    bool isOutsideDay = false,
  }) {
    final textColor =
        isOutsideDay
            ? isDarkMode
                ? Colors.white30
                : Colors.black26
            : isSelected
            ? isDarkMode
                ? Colors.white
                : Colors.white
            : isToday
            ? theme.colorScheme.primary
            : isDarkMode
            ? Colors.white70
            : Colors.black87;

    final backgroundColor =
        isSelected
            ? theme.colorScheme.primary
            : isToday
            ? isDarkMode
                ? theme.colorScheme.primary.withOpacity(0.2)
                : theme.colorScheme.primary.withOpacity(0.1)
            : Colors.transparent;

    final borderColor =
        isToday && !isSelected ? theme.colorScheme.primary : Colors.transparent;

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Center(
        child: Text(
          day.day.toString(),
          style: TextStyle(
            color: textColor,
            fontWeight:
                isSelected || isToday ? FontWeight.bold : FontWeight.normal,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  // Helper method to build custom days of week headers
  List<Widget> _buildDaysOfWeekHeaders(bool isDarkMode, ThemeData theme) {
    final daysOfWeek = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return daysOfWeek.map((day) {
      final isWeekend = day == 'S';
      return Expanded(
        child: Center(
          child: Text(
            day,
            style: TextStyle(
              color:
                  isWeekend
                      ? isDarkMode
                          ? theme.colorScheme.primary.withOpacity(0.7)
                          : theme.colorScheme.primary
                      : isDarkMode
                      ? Colors.white60
                      : Colors.black54,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      );
    }).toList();
  }

  // Helper method to build legend items
  Widget _buildLegendItem(
    String label,
    Color color,
    bool isDarkMode,
    ThemeData theme,
  ) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
      ],
    );
  }
}
