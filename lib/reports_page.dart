import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      defaultData = await _getData();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      defaultData = {};
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _getData() async {
    final dir = await getDownloadsDirectory();
    print("Path: ${dir?.path}");
    if (dir == null) {
      throw Exception('Could not access downloads directory');
    }
    final fileName = 'sadhnaMantra.json';
    final filePath = path.join(dir.path, fileName);
    print('full path: $filePath');

    if (await File(filePath).exists()) {
      print('File exists');
      final file = File(filePath);
      final contents = await file.readAsString();
      final jsonData = jsonDecode(contents);
      return jsonData;
    } else {
      print('File does not exist');
      final Map<String, dynamic> defaultData = {
        "2025": {
          "05": {
            "01": {"morning": true, "afternoon": false, "night": true},
            "02": {"morning": false, "afternoon": false, "night": false},
            "03": {"morning": false, "afternoon": false, "night": false},
            "04": {"morning": false, "afternoon": false, "night": false},
            "05": {"morning": false, "afternoon": false, "night": false},
            "06": {"morning": false, "afternoon": false, "night": false},
            "07": {"morning": false, "afternoon": false, "night": false},
            "08": {"morning": false, "afternoon": false, "night": false},
            "09": {"morning": false, "afternoon": false, "night": false},
            "10": {"morning": false, "afternoon": false, "night": false},
            "11": {"morning": false, "afternoon": false, "night": false},
            "12": {"morning": false, "afternoon": false, "night": false},
            "13": {"morning": false, "afternoon": false, "night": false},
            "14": {"morning": false, "afternoon": false, "night": false},
            "15": {"morning": false, "afternoon": false, "night": false},
            "16": {"morning": false, "afternoon": false, "night": false},
            "17": {"morning": false, "afternoon": false, "night": false},
            "18": {"morning": false, "afternoon": false, "night": false},
            "19": {"morning": false, "afternoon": false, "night": false},
            "20": {"morning": false, "afternoon": false, "night": false},
            "21": {"morning": false, "afternoon": false, "night": false},
            "22": {"morning": false, "afternoon": false, "night": false},
            "23": {"morning": false, "afternoon": false, "night": false},
            "24": {"morning": false, "afternoon": false, "night": false},
            "25": {"morning": false, "afternoon": false, "night": false},
            "26": {"morning": false, "afternoon": false, "night": false},
            "27": {"morning": false, "afternoon": false, "night": false},
            "28": {"morning": false, "afternoon": false, "night": false},
            "29": {"morning": false, "afternoon": false, "night": false},
            "30": {"morning": false, "afternoon": false, "night": false},
            "31": {"morning": false, "afternoon": false, "night": false},
          },
        },
      };
      final file = File(filePath);
      await file.writeAsString(jsonEncode(defaultData));
      return defaultData;
    }
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
    if (defaultData.containsKey(year) &&
        defaultData[year].containsKey(month) &&
        defaultData[year][month].containsKey(day)) {
      return defaultData[year][month][day];
    }
    return {"morning": false, "afternoon": false, "night": false};
  }

  void _updateReminderStatus(String timeSlot, bool value) {
    if (_selectedDate == null) return;
    final year = _selectedDate!.year.toString();
    final month = _selectedDate!.month.toString().padLeft(2, '0');
    final day = _selectedDate!.day.toString().padLeft(2, '0');
    if (!defaultData.containsKey(year)) {
      defaultData[year] = {};
    }
    if (!defaultData[year].containsKey(month)) {
      defaultData[year][month] = {};
    }
    if (!defaultData[year][month].containsKey(day)) {
      defaultData[year][month][day] = {
        "morning": false,
        "afternoon": false,
        "night": false,
      };
    }
    defaultData[year][month][day][timeSlot] = value;
    _saveData(defaultData);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final selectedDateData = _getSelectedDateData();
    final bool morningDone = selectedDateData?["morning"] ?? false;
    final bool afternoonDone = selectedDateData?["afternoon"] ?? false;
    final bool nightDone = selectedDateData?["night"] ?? false;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      appBar: AppBar(
        title: const Text('Reports Calendar'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(12),
                          child: TableCalendar(
                            firstDay: DateTime.utc(2025, 5, 1),
                            lastDay: DateTime.now(),
                            headerStyle: const HeaderStyle(
                              formatButtonVisible: false,
                              titleCentered: true,
                              titleTextStyle: TextStyle(
                                fontSize: 20,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              leftChevronIcon: Icon(
                                Icons.chevron_left,
                                color: Colors.white,
                              ),
                              rightChevronIcon: Icon(
                                Icons.chevron_right,
                                color: Colors.white,
                              ),
                            ),
                            rowHeight: 48,
                            focusedDay: _focusedDay,
                            selectedDayPredicate: (day) {
                              return _selectedDate != null &&
                                  isSameDay(_selectedDate!, day);
                            },
                            onDaySelected: (selectedDay, focusedDay) {
                              setState(() {
                                _selectedDate = selectedDay;
                                _focusedDay = focusedDay;
                              });
                            },
                            calendarBuilders: CalendarBuilders(
                              markerBuilder: (context, date, events) {
                                final year = date.year.toString();
                                final month = date.month.toString().padLeft(
                                  2,
                                  '0',
                                );
                                final day = date.day.toString().padLeft(2, '0');
                                bool isRed = false;
                                if (defaultData.containsKey(year) &&
                                    defaultData[year].containsKey(month) &&
                                    defaultData[year][month].containsKey(day)) {
                                  final timeSlots =
                                      defaultData[year][month][day];
                                  if (timeSlots["morning"] == false ||
                                      timeSlots["afternoon"] == false ||
                                      timeSlots["night"] == false) {
                                    isRed = true;
                                  }
                                } else {
                                  isRed = true;
                                }
                                if (isRed) {
                                  return Positioned(
                                    bottom: 1,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  );
                                }
                                return null;
                              },
                            ),
                            calendarStyle: CalendarStyle(
                              isTodayHighlighted: true,
                              tableBorder: TableBorder(
                                bottom: BorderSide(
                                  color: Colors.grey[800]!,
                                  width: 0.5,
                                ),
                              ),
                              defaultDecoration: BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                              ),
                              weekendDecoration: BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                              ),
                              outsideDecoration: BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                              ),
                              selectedDecoration: BoxDecoration(
                                color: Colors.blueGrey[700],
                                shape: BoxShape.circle,
                              ),
                              todayDecoration: BoxDecoration(
                                border: Border.all(color: Colors.blue[300]!),
                                shape: BoxShape.circle,
                              ),
                              defaultTextStyle: TextStyle(color: Colors.white),
                              weekendTextStyle: TextStyle(
                                color: Colors.white70,
                              ),
                              outsideTextStyle: TextStyle(
                                color: Colors.grey[600],
                              ),
                              selectedTextStyle: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              todayTextStyle: TextStyle(
                                color: Colors.blue[300],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_selectedDate != null) ...[
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Selected Date: ${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Morning Gayatri Reminder',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed:
                                        morningDone
                                            ? null
                                            : () {
                                              _updateReminderStatus(
                                                'morning',
                                                true,
                                              );
                                            },
                                    style: ElevatedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      backgroundColor:
                                          morningDone
                                              ? Colors.grey[800]
                                              : Colors.blue[700],
                                      disabledBackgroundColor: Colors.green
                                          .withOpacity(0.6),
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      elevation: morningDone ? 0 : 2,
                                    ),
                                    child: Text(
                                      'Mark As Done',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'Afternoon Gayatri Reminder',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed:
                                        afternoonDone
                                            ? null
                                            : () {
                                              _updateReminderStatus(
                                                'afternoon',
                                                true,
                                              );
                                            },
                                    style: ElevatedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      backgroundColor:
                                          afternoonDone
                                              ? Colors.grey[800]
                                              : Colors.amber[700],
                                      disabledBackgroundColor: Colors.green
                                          .withOpacity(0.6),
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      elevation: afternoonDone ? 0 : 2,
                                    ),
                                    child: Text(
                                      'Mark As Done',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'Night Gayatri Reminder',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed:
                                        nightDone
                                            ? null
                                            : () {
                                              _updateReminderStatus(
                                                'night',
                                                true,
                                              );
                                            },
                                    style: ElevatedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      backgroundColor:
                                          nightDone
                                              ? Colors.grey[800]
                                              : Colors.indigo[700],
                                      disabledBackgroundColor: Colors.green
                                          .withOpacity(0.6),
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      elevation: nightDone ? 0 : 2,
                                    ),
                                    child: Text(
                                      'Mark As Done',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
    );
  }
}
