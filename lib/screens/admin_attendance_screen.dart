import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class AdminAttendanceScreen extends StatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  bool _isLoading = false;

  // Calendar View state
  List<dynamic> _users = [];
  String? _selectedUserId;
  DateTime _selectedMonth = DateTime.now();
  List<dynamic> _userCalendarLogs = [];
  Map<String, dynamic> _selectedUserSummary = {};

  @override
  void initState() {
    super.initState();
    _loadUsersList();
  }


  Future<void> _loadUsersList() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final res = await apiService.getRequest('/users');
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data['data'];
        setState(() {
          _users = data['users'] ?? [];
          if (_users.isNotEmpty) {
            _selectedUserId = _users.first['_id'];
            _loadUserCalendarData();
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to load user list: $e');
    }
  }

  Future<void> _loadUserCalendarData() async {
    if (_selectedUserId == null) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final formattedMonth = DateFormat('yyyy-MM').format(_selectedMonth);
      final params = {'range': 'custom_$formattedMonth'};

      final res = await apiService.getRequest('/attendance/admin-history', queryParameters: params);
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data['data'];
        final rawHistory = data['history'] as List<dynamic>? ?? [];
        final rawSummary = data['summary'] as List<dynamic>? ?? [];

        // Find summary stats for selected employee
        final selectedUser = _users.firstWhere((u) => u['_id'] == _selectedUserId);
        final userSum = rawSummary.firstWhere(
          (s) => s['name'] == selectedUser['name'],
          orElse: () => {
            'name': selectedUser['name'],
            'role': selectedUser['role'],
            'daysPresent': 0,
            'totalHours': 0,
          },
        );

        setState(() {
          // Filter logs to match this user only
          _userCalendarLogs = rawHistory.where((log) => log['userId'] == _selectedUserId).toList();
          _selectedUserSummary = userSum;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load employee details: ${ApiService.getReadableError(e)}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '--:--';
    try {
      final date = DateTime.parse(timestamp.toString()).toLocal();
      return DateFormat('hh:mm a').format(date);
    } catch (e) {
      return '--:--';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Staff Attendance Board', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1F2937),
        elevation: 0,
      ),
      body: _buildCalendarViewTab(),
    );
  }

  Widget _buildCalendarViewTab() {
    if (_users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Days in current selected month
    final lastDayDateTime = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final totalDays = lastDayDateTime.day;
    final firstDayWeekday = DateTime(_selectedMonth.year, _selectedMonth.month, 1).weekday; // Mon=1, Sun=7
    final paddingOffset = firstDayWeekday - 1; // Mon=0, Tue=1, ..., Sun=6

    return Column(
      children: [
        // Employee Selector & Month Pickers
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedUserId,
                dropdownColor: const Color(0xFFFFFFFF),
                style: const TextStyle(color: Color(0xFF1E293B)),
                decoration: const InputDecoration(
                  labelText: 'Select Employee',
                  labelStyle: TextStyle(color: Colors.blueGrey),
                  filled: true,
                  fillColor: Color(0xFFFFFFFF),
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                ),
                items: _users.map((u) {
                  return DropdownMenuItem(
                    value: u['_id'].toString(),
                    child: Text('${u['name']} (${u['role'].toString().toUpperCase()})'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedUserId = val;
                    });
                    _loadUserCalendarData();
                  }
                },
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.blueAccent),
                    onPressed: () {
                      setState(() {
                        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                      });
                      _loadUserCalendarData();
                    },
                  ),
                  Text(
                    DateFormat('MMMM yyyy').format(_selectedMonth),
                    style: const TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: Colors.blueAccent),
                    onPressed: () {
                      setState(() {
                        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                      });
                      _loadUserCalendarData();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        // Summary Statistics Card
        if (_selectedUserSummary.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryStatItem('PRESENT', '$_countPresent', Colors.green),
                      _buildSummaryStatItem('LEAVE', '$_countLeave', Colors.orange),
                      _buildSummaryStatItem('ABSENT', '$_countAbsent', Colors.redAccent),
                    ],
                  ),
                  const Divider(color: Colors.black12, height: 16, thickness: 1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryStatItem('WEEKOFF', '$_countWeekoff', Colors.indigoAccent),
                      _buildSummaryStatItem('TOTAL HOURS', '${_selectedUserSummary['totalHours'] ?? 0} hrs', Colors.teal),
                    ],
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 16),

        // Weekdays Header (M, T, W, T, F, S, S)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              Center(child: Text('M', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold))),
              Center(child: Text('T', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold))),
              Center(child: Text('W', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold))),
              Center(child: Text('T', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold))),
              Center(child: Text('F', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold))),
              Center(child: Text('S', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold))),
              Center(child: Text('S', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold))),
            ],
          ),
        ),

        // Grid Calendar View
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : GridView.builder(
                  padding: const EdgeInsets.all(16.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                    childAspectRatio: 1.05,
                  ),
                  itemCount: totalDays + paddingOffset,
                  itemBuilder: (context, index) {
                    if (index < paddingOffset) {
                      return const SizedBox.shrink(); // blank offset cell
                    }

                    final day = index - paddingOffset + 1;
                    final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
                    final dateStr = '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

                    // Find if there is an attendance record for this day
                    final record = _userCalendarLogs.firstWhere(
                      (log) => log['date'] == dateStr,
                      orElse: () => null,
                    );

                    Color cellColor = const Color(0xFFFFFFFF);
                    Color textColor = Colors.white;
                    String statusLabel = '';
                    String subLabel = '';
                    bool isMissedLogout = false;

                    final today = DateTime.now();
                    final todayStr = DateFormat('yyyy-MM-dd').format(today);
                    final isToday = dateStr == todayStr;
                    final isPast = date.isBefore(DateTime(today.year, today.month, today.day));

                    if (record != null) {
                      final specialStatus = record['specialStatus'];
                      if (specialStatus == 'LEAVE') {
                        cellColor = const Color(0xFFD97706);
                        statusLabel = 'LEAVE';
                      } else if (specialStatus == 'WEEKOFF') {
                        cellColor = const Color(0xFF6366F1);
                        statusLabel = 'WEEKOFF';
                      } else if (record['punchIn'] != null) {
                        final inTime = DateTime.parse(record['punchIn']).toLocal();

                        if (record['punchOut'] != null) {
                          final outTime = DateTime.parse(record['punchOut']).toLocal();
                          cellColor = const Color(0xFF10B981);
                          statusLabel = 'In: ${DateFormat('hh:mm').format(inTime)}';
                          subLabel = 'Out: ${DateFormat('hh:mm').format(outTime)}';
                        } else {
                          if (isToday) {
                            cellColor = const Color(0xFF10B981);
                            statusLabel = 'In: ${DateFormat('hh:mm').format(inTime)}';
                            subLabel = 'ACTIVE';
                          } else {
                            cellColor = const Color(0xFFEF4444);
                            statusLabel = 'In: ${DateFormat('hh:mm').format(inTime)}';
                            subLabel = 'MISS';
                            isMissedLogout = true;
                          }
                        }
                      }
                    } else {
                      if (isPast) {
                        cellColor = const Color(0xFF334155).withOpacity(0.3);
                        statusLabel = 'ABSENT';
                        textColor = Colors.blueGrey.shade400;
                      } else {
                        cellColor = const Color(0xFFFFFFFF);
                        textColor = Colors.white30;
                      }
                    }

                    return InkWell(
                      onTap: () {
                        if (record != null) {
                          _showDayDetailsPopup(day, record);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('No attendance details recorded for $dateStr.')),
                          );
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: cellColor,
                          borderRadius: BorderRadius.circular(8),
                          border: isToday
                              ? Border.all(color: Colors.blueAccent, width: 1.5)
                              : Border.all(color: Colors.white.withOpacity(0.05), width: 1),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  day.toString(),
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  DateFormat('E').format(date).substring(0, 1),
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.5),
                                    fontSize: 7,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            if (statusLabel.isNotEmpty)
                              Text(
                                statusLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 7,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (subLabel.isNotEmpty)
                              Text(
                                subLabel,
                                style: TextStyle(
                                  color: isMissedLogout
                                      ? Colors.yellowAccent
                                      : Colors.white.withOpacity(0.9),
                                  fontSize: 7,
                                  fontWeight: isMissedLogout
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showDayDetailsPopup(int day, Map<String, dynamic> record) {
    final specialStatus = record['specialStatus'];
    final inTime = _formatTime(record['punchIn']);
    final outTime = _formatTime(record['punchOut']);
    final totalHours = record['totalHours'] ?? '--';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1F2937),
          title: Text('Day $day Attendance Details', style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (specialStatus != null) ...[
                Text('Status: $specialStatus', style: const TextStyle(color: Colors.white70, fontSize: 15)),
              ] else ...[
                Text('Punch IN: $inTime', style: const TextStyle(color: Colors.white70, fontSize: 15)),
                const SizedBox(height: 8),
                Text('Punch OUT: $outTime', style: const TextStyle(color: Colors.white70, fontSize: 15)),
                const SizedBox(height: 8),
                Text('Worked Hours: $totalHours', style: const TextStyle(color: Colors.white70, fontSize: 15)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            )
          ],
        );
      },
    );
  }

  int get _countPresent {
    return _userCalendarLogs.where((log) =>
      log['specialStatus'] == null &&
      (log['punchIn'] != null || log['punchOut'] != null)
    ).length;
  }

  int get _countLeave {
    return _userCalendarLogs.where((log) => log['specialStatus'] == 'LEAVE').length;
  }

  int get _countWeekoff {
    return _userCalendarLogs.where((log) => log['specialStatus'] == 'WEEKOFF').length;
  }

  int get _countAbsent {
    final today = DateTime.now();
    final lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final totalDays = lastDayOfMonth.day;

    int absentCount = 0;
    for (int day = 1; day <= totalDays; day++) {
      final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
      final isPast = date.isBefore(DateTime(today.year, today.month, today.day));
      if (!isPast) continue;

      final dateStr = '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      final hasRecord = _userCalendarLogs.any((log) => log['date'] == dateStr);
      if (!hasRecord) {
        absentCount++;
      }
    }
    return absentCount;
  }

  Widget _buildSummaryStatItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.blueGrey, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)
        ),
      ],
    );
  }
}
