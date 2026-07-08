import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class AdminAttendanceScreen extends StatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late TabController _tabController;

  // Logs List state
  List<dynamic> _history = [];
  List<dynamic> _filteredHistory = [];
  String _searchQuery = '';
  String _selectedRole = 'ALL';

  // Calendar View state
  List<dynamic> _users = [];
  String? _selectedUserId;
  DateTime _selectedMonth = DateTime.now();
  List<dynamic> _userCalendarLogs = [];
  Map<String, dynamic> _selectedUserSummary = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAdminHistory();
    _loadUsersList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminHistory() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final res = await apiService.getRequest('/attendance/admin-history');
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data['data'];
        setState(() {
          _history = data['history'] ?? [];
          _applyFilters();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load attendance logs: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
        SnackBar(content: Text('Failed to load employee details: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredHistory = _history.where((log) {
        final name = (log['userName'] ?? '').toString().toLowerCase();
        final matchesSearch = name.contains(_searchQuery.toLowerCase());

        final role = (log['userRole'] ?? '').toString().toUpperCase();
        final matchesRole = _selectedRole == 'ALL' || role == _selectedRole;

        return matchesSearch && matchesRole;
      }).toList();
    });
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
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Staff Attendance Board', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.blueGrey,
          indicatorColor: Colors.blueAccent,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'Logs View'),
            Tab(icon: Icon(Icons.calendar_month), text: 'Calendar View'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLogsViewTab(),
          _buildCalendarViewTab(),
        ],
      ),
    );
  }

  Widget _buildLogsViewTab() {
    return Column(
      children: [
        // Filters Panel
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search by employee name...',
                  hintStyle: const TextStyle(color: Colors.blueGrey),
                  prefixIcon: const Icon(Icons.search, color: Colors.blueGrey),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) {
                  _searchQuery = val;
                  _applyFilters();
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Role Filter: ', style: TextStyle(color: Colors.blueGrey)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedRole,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Staff')),
                        DropdownMenuItem(value: 'ADMIN', child: Text('Admins')),
                        DropdownMenuItem(value: 'COUNSELOR', child: Text('Counselors')),
                        DropdownMenuItem(value: 'EMPLOYEE', child: Text('Employees')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          _selectedRole = val;
                          _applyFilters();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Logs list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredHistory.isEmpty
                  ? const Center(child: Text('No attendance records found.', style: TextStyle(color: Colors.blueGrey)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredHistory.length,
                      itemBuilder: (context, index) {
                        final log = _filteredHistory[index];
                        final name = log['userName'] ?? 'Unknown Staff';
                        final role = log['userRole'] ?? 'Employee';
                        final date = log['date'] ?? '';
                        final inTime = _formatTime(log['punchIn']);
                        final outTime = _formatTime(log['punchOut']);
                        final hours = log['totalHours'] ?? '--';
                        final specialStatus = log['specialStatus'];

                        return Card(
                          color: const Color(0xFF1E293B),
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    Chip(
                                      label: Text(
                                        role.toUpperCase(),
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                      backgroundColor: Colors.blueGrey,
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                                const Divider(color: Colors.white24, height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('DATE', style: TextStyle(color: Colors.blueGrey, fontSize: 10)),
                                        const SizedBox(height: 2),
                                        Text(date, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('PUNCH IN', style: TextStyle(color: Colors.blueGrey, fontSize: 10)),
                                        const SizedBox(height: 2),
                                        Text(inTime, style: TextStyle(color: inTime != '--:--' ? Colors.green : Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('PUNCH OUT', style: TextStyle(color: Colors.blueGrey, fontSize: 10)),
                                        const SizedBox(height: 2),
                                        Text(outTime, style: TextStyle(color: outTime != '--:--' ? Colors.redAccent : Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('HOURS', style: TextStyle(color: Colors.blueGrey, fontSize: 10)),
                                        const SizedBox(height: 2),
                                        Text(
                                          specialStatus != null ? specialStatus.toString() : hours,
                                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ],
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
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Select Employee',
                  labelStyle: TextStyle(color: Colors.blueGrey),
                  filled: true,
                  fillColor: Color(0xFF1E293B),
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
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('DAYS PRESENT', style: TextStyle(color: Colors.blueGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('${_selectedUserSummary['daysPresent'] ?? 0} Days', style: const TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('TOTAL HOURS', style: TextStyle(color: Colors.blueGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('${_selectedUserSummary['totalHours'] ?? 0} hrs', style: const TextStyle(color: Colors.teal, fontSize: 16, fontWeight: FontWeight.bold)),
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
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: totalDays + paddingOffset,
                  itemBuilder: (context, index) {
                    if (index < paddingOffset) {
                      return const SizedBox.shrink(); // blank offset cell
                    }

                    final day = index - paddingOffset + 1;
                    final dateStr = '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

                    // Find if there is an attendance record for this day
                    final record = _userCalendarLogs.firstWhere(
                      (log) => log['date'] == dateStr,
                      orElse: () => null,
                    );

                    Color cellColor = const Color(0xFF1E293B);
                    Color textColor = Colors.white70;

                    if (record != null) {
                      final specialStatus = record['specialStatus'];
                      if (specialStatus == 'LEAVE') {
                        cellColor = Colors.orange.withOpacity(0.2);
                        textColor = Colors.orange;
                      } else if (specialStatus == 'WEEKOFF') {
                        cellColor = Colors.purple.withOpacity(0.2);
                        textColor = Colors.purple;
                      } else {
                        // Present (IN / OUT punch logs)
                        cellColor = Colors.green.withOpacity(0.2);
                        textColor = Colors.green;
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
                          border: Border.all(color: cellColor.withOpacity(0.5)),
                        ),
                        child: Center(
                          child: Text(
                            '$day',
                            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
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
          backgroundColor: const Color(0xFF1E293B),
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
}
