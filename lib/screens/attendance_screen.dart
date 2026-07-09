import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'login_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _isLoading = false;
  bool _isPunching = false;
  Map<String, dynamic>? _officeSettings;
  List<dynamic> _history = [];
  String _distanceMessage = 'Fetching location...';
  double? _currentDistance;
  Position? _currentPosition;
  String _punchStatus = 'IN';
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      
      // Get office settings
      final settingsRes = await apiService.getRequest('/attendance/office-settings');
      if (settingsRes.statusCode == 200) {
        _officeSettings = settingsRes.data['data'];
      }

      // Get history
      await _fetchHistory();
      await _checkCurrentLocation();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data: ${ApiService.getReadableError(e)}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchHistory() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final String monthStr = DateFormat('yyyy-MM').format(_selectedMonth);
    final historyRes = await apiService.getRequest('/attendance/personal-history?range=custom_$monthStr');
    if (historyRes.statusCode == 200) {
      setState(() {
        _history = historyRes.data['data'] ?? [];
        _deducePunchStatus();
      });
    }
  }

  void _deducePunchStatus() {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayLog = _history.firstWhere(
      (log) => log['date'] == todayStr,
      orElse: () => null,
    );

    if (todayLog != null) {
      if (todayLog['punchIn'] != null && todayLog['punchOut'] == null) {
        _punchStatus = 'OUT';
      } else {
        _punchStatus = 'IN';
      }
    } else {
      _punchStatus = 'IN';
    }
  }

  Future<void> _checkCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _distanceMessage = 'Location permissions denied.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _distanceMessage = 'Location permissions permanently denied.';
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
      });

      if (_officeSettings != null) {
        final officeLat = _officeSettings!['latitude'];
        final officeLng = _officeSettings!['longitude'];
        final radius = _officeSettings!['radiusMeters'];

        double distanceInMeters = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          officeLat,
          officeLng,
        );

        setState(() {
          _currentDistance = distanceInMeters;
          if (distanceInMeters <= radius) {
            _distanceMessage = 'You are within the office range (${distanceInMeters.toStringAsFixed(1)}m away).';
          } else {
            _distanceMessage = 'You are too far (${distanceInMeters.toStringAsFixed(1)}m away). Office radius: ${radius}m.';
          }
        });
      }
    } catch (e) {
      setState(() {
        _distanceMessage = 'Failed to get location: $e';
      });
    }
  }

  Future<void> _handlePunch() async {
    setState(() {
      _isPunching = true;
    });

    try {
      await _checkCurrentLocation();

      if (_currentPosition == null) {
        throw Exception(_distanceMessage);
      }

      final apiService = Provider.of<ApiService>(context, listen: false);
      final res = await apiService.postRequest('/attendance/punch', data: {
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
      });

      if (res.statusCode == 200) {
        _showSuccessDialogWithMessage('Punch ${_punchStatus} recorded successfully!');
        _selectedMonth = DateTime.now();
        await _fetchHistory();
      }
    } catch (e) {
      String errMsg = e.toString();
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['message'] != null) {
          errMsg = data['message'];
        }
      }
      _showErrorDialog(errMsg);
    } finally {
      setState(() {
        _isPunching = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    await NotificationService().removeFCMTokenOnLogout(apiService);
    await apiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Attendance Console', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blueAccent),
            onPressed: _fetchData,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Profile Header Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.blueAccent,
                            child: Icon(Icons.person, color: Colors.white, size: 30),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  apiService.userName ?? 'Employee',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  apiService.userEmail ?? '',
                                  style: TextStyle(
                                    color: Colors.blueGrey.shade400,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              apiService.userRole?.toUpperCase() ?? '',
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Punch Card
                    Card(
                      color: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Text(
                              'PUNCH CONSOLE',
                              style: TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              DateFormat('EEEE, d MMM yyyy').format(DateTime.now()),
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 24),
                            
                            // Punch Button
                            GestureDetector(
                              onTap: _isPunching ? null : _handlePunch,
                              child: Container(
                                height: 160,
                                width: 160,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _punchStatus == 'IN'
                                      ? Colors.green.withOpacity(0.15)
                                      : Colors.amber.withOpacity(0.15),
                                  border: Border.all(
                                    color: _punchStatus == 'IN' ? Colors.green : Colors.amber,
                                    width: 4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_punchStatus == 'IN' ? Colors.green : Colors.amber).withOpacity(0.3),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    )
                                  ]
                                ),
                                child: Center(
                                  child: _isPunching
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.touch_app_rounded,
                                              size: 48,
                                              color: _punchStatus == 'IN' ? Colors.green : Colors.amber,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'PUNCH $_punchStatus',
                                              style: TextStyle(
                                                color: _punchStatus == 'IN' ? Colors.green : Colors.amber,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Location/Range display
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: _currentDistance != null &&
                                          _officeSettings != null &&
                                          _currentDistance! <= _officeSettings!['radiusMeters']
                                      ? Colors.green
                                      : Colors.redAccent,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _distanceMessage,
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const SizedBox(height: 24),

                    // Month Selector Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: Colors.blueAccent),
                          onPressed: () {
                            setState(() {
                              _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                            });
                            _fetchData();
                          },
                        ),
                        Text(
                          DateFormat('MMMM yyyy').format(_selectedMonth),
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, color: Colors.blueAccent),
                          onPressed: () {
                            setState(() {
                              _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                            });
                            _fetchData();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Calculate month statistics
                    () {
                      int daysPresent = 0;
                      int leavesTaken = 0;
                      int weekoffs = 0;
                      int absents = 0;
                      int missedLogouts = 0;
                      double totalHoursSum = 0;

                      for (final log in _history) {
                        final specialStatus = log['specialStatus'];
                        if (specialStatus == 'LEAVE') {
                          leavesTaken++;
                        } else if (specialStatus == 'WEEKOFF') {
                          weekoffs++;
                        } else if (log['punchIn'] != null) {
                          daysPresent++;
                          if (log['punchOut'] == null) {
                            final dateStr = log['date'];
                            final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
                            if (dateStr != todayStr) {
                              missedLogouts++;
                            }
                          }
                          totalHoursSum += (log['hoursValue'] ?? 0.0).toDouble();
                        }
                      }

                      final today = DateTime.now();
                      final lastDayDateTime = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
                      final totalDays = lastDayDateTime.day;

                      for (int day = 1; day <= totalDays; day++) {
                        final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
                        final dateStr = DateFormat('yyyy-MM-dd').format(date);
                        final matchingLog = _history.firstWhere(
                          (log) => log['date'] == dateStr,
                          orElse: () => null,
                        );
                        if (matchingLog == null) {
                          if (date.isBefore(DateTime(today.year, today.month, today.day))) {
                            absents++;
                          }
                        }
                      }

                      Widget buildStatCard(String label, String value, Color color) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: color.withOpacity(0.15), width: 1),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                label,
                                style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 9, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                value,
                                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GridView.count(
                            crossAxisCount: 3,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 2.1,
                            children: [
                              buildStatCard('PRESENT', '$daysPresent Days', Colors.green),
                              buildStatCard('LEAVES', '$leavesTaken Days', Colors.orange),
                              buildStatCard('WEEKOFFS', '$weekoffs Days', Colors.indigoAccent),
                              buildStatCard('ABSENTS', '$absents Days', Colors.blueGrey),
                              buildStatCard('MISSED OUT', '$missedLogouts Days', Colors.redAccent),
                              buildStatCard('TOTAL HOURS', '${totalHoursSum.toStringAsFixed(1)} hrs', Colors.teal),
                            ],
                          ),
                          const SizedBox(height: 20),
                          
                          // Weekdays Header Grid
                          GridView.count(
                            crossAxisCount: 7,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: const [
                              Center(child: Text('M', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 12))),
                              Center(child: Text('T', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 12))),
                              Center(child: Text('W', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 12))),
                              Center(child: Text('T', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 12))),
                              Center(child: Text('F', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 12))),
                              Center(child: Text('S', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 12))),
                              Center(child: Text('S', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 12))),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Calendar Days Grid
                          () {
                            final firstDayWeekday = DateTime(_selectedMonth.year, _selectedMonth.month, 1).weekday; // Mon=1, Sun=7
                            final paddingOffset = firstDayWeekday - 1; // Mon=0, Tue=1, ..., Sun=6

                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7,
                                crossAxisSpacing: 6,
                                mainAxisSpacing: 6,
                                childAspectRatio: 1.05,
                              ),
                              itemCount: totalDays + paddingOffset,
                              itemBuilder: (context, index) {
                                if (index < paddingOffset) {
                                  return const SizedBox.shrink();
                                }

                                final day = index - paddingOffset + 1;
                                final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
                                final dateStr = DateFormat('yyyy-MM-dd').format(date);

                                final record = _history.firstWhere(
                                  (log) => log['date'] == dateStr,
                                  orElse: () => null,
                                );

                                Color cellColor = const Color(0xFF1E293B);
                                Color textColor = Colors.white;
                                String statusLabel = '';
                                String subLabel = '';
                                bool isMissedLogout = false;

                                final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
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
                                    cellColor = const Color(0xFF1E293B);
                                    textColor = Colors.white30;
                                  }
                                }

                                return InkWell(
                                  onTap: () {
                                    if (record != null || isPast) {
                                      _showDayDetailsBottomSheet(date, record);
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
                            );
                          }(),
                        ],
                      );
                    }(),
                  ],
                ),
              ),
            ),
    );
  }

  void _showDayDetailsBottomSheet(DateTime date, Map<String, dynamic>? record) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        String punchInText = 'N/A';
        String punchOutText = 'N/A';
        String totalHoursText = 'N/A';
        String statusText = 'Absent';
        Color statusColor = Colors.blueGrey;

        if (record != null) {
          final specialStatus = record['specialStatus'];
          if (specialStatus == 'LEAVE') {
            statusText = 'On Leave';
            statusColor = Colors.orange;
          } else if (specialStatus == 'WEEKOFF') {
            statusText = 'Weekoff';
            statusColor = Colors.purple;
          } else {
            statusText = 'Present';
            statusColor = Colors.green;
            if (record['punchIn'] != null) {
              punchInText = DateFormat('hh:mm a').format(DateTime.parse(record['punchIn']).toLocal());
            }
            if (record['punchOut'] != null) {
              punchOutText = DateFormat('hh:mm a').format(DateTime.parse(record['punchOut']).toLocal());
            } else {
              final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
              final logStr = record['date'];
              if (logStr == todayStr) {
                statusText = 'Punched In (Active)';
                punchOutText = 'Active Now';
              } else {
                statusText = 'Missing Logout';
                statusColor = Colors.redAccent;
                punchOutText = 'Missing';
              }
            }
            totalHoursText = record['totalHours'] ?? 'N/A';
          }
        }

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('EEEE, dd MMMM yyyy').format(date),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Chip(
                    label: Text(statusText, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    backgroundColor: statusColor,
                  ),
                ],
              ),
              const Divider(color: Colors.white10, height: 32),
              _buildDetailRow('Punch In Time', punchInText, Icons.login, Colors.green),
              const SizedBox(height: 16),
              _buildDetailRow(
                'Punch Out Time', 
                punchOutText, 
                Icons.logout, 
                punchOutText == 'Missing' ? Colors.redAccent : Colors.orange
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Total Hours Worked', totalHoursText, Icons.timer, Colors.teal),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, Color iconColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 16),
        Text(label, style: const TextStyle(color: Colors.blueGrey, fontSize: 14)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: value == 'Missing' ? Colors.redAccent : Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _showSuccessDialogWithMessage(String message) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Success',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Success!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.blueGrey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Error',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Punch Failed',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: SingleChildScrollView(
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Colors.blueGrey, width: 1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}
