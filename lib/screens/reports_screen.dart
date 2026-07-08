import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _summary;
  String _currentFilter = 'thisMonth';
  DateTime? _selectedCustomMonth;

  @override
  void initState() {
    super.initState();
    _loadSummaryReport();
  }

  Map<String, String> _getDateRangeParams() {
    final now = DateTime.now();
    DateTime start;
    DateTime end;

    if (_currentFilter == 'customMonth' && _selectedCustomMonth != null) {
      start = DateTime(_selectedCustomMonth!.year, _selectedCustomMonth!.month, 1);
      end = DateTime(_selectedCustomMonth!.year, _selectedCustomMonth!.month + 1, 0, 23, 59, 59, 999);
    } else if (_currentFilter == 'thisYear') {
      start = DateTime(now.year, 1, 1);
      end = DateTime(now.year, 12, 31, 23, 59, 59, 999);
    } else if (_currentFilter == 'allTime') {
      start = DateTime(2020, 1, 1);
      end = DateTime(now.year + 1, 12, 31, 23, 59, 59, 999);
    } else {
      // Default: thisMonth
      start = DateTime(now.year, now.month, 1);
      end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
    }

    String formatDate(DateTime d) {
      return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    }

    return {
      'startDate': formatDate(start),
      'endDate': formatDate(end),
      'dateFrom': formatDate(start),
      'dateTo': formatDate(end),
    };
  }

  Future<void> _loadSummaryReport() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final params = _getDateRangeParams();
      final queryStr = Uri(queryParameters: params).query;
      final res = await apiService.getRequest('/reports/summary?$queryStr');
      if (res.statusCode == 200 && res.data != null && mounted) {
        setState(() {
          _summary = res.data['data'];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load summary reports: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    num totalPaid = 0;
    num regFees = 0;
    num instFees = 0;
    num refunds = 0;
    num totalPending = 0;
    num totalFeesExpected = 0;

    if (_summary != null) {
      final feesSummary = _summary!['fees']?['summary'] ?? {};
      totalPaid = feesSummary['totalPaid'] ?? feesSummary['totalRevenueCollected'] ?? 0;
      regFees = feesSummary['registrationPaid'] ?? 0;
      instFees = feesSummary['installmentPaid'] ?? 0;
      refunds = feesSummary['totalRefunds'] ?? 0;
      totalPending = feesSummary['totalPending'] ?? 0;
      totalFeesExpected = feesSummary['totalFeesExpected'] ?? 0;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Reports & Analytics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Tabs Bar
          Container(
            color: const Color(0xFF1E293B),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    selected: _currentFilter == 'thisMonth',
                    label: const Text('This Month'),
                    selectedColor: Colors.blueAccent,
                    labelStyle: TextStyle(color: _currentFilter == 'thisMonth' ? Colors.white : Colors.blueGrey, fontWeight: FontWeight.bold),
                    backgroundColor: const Color(0xFF0F172A),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _currentFilter = 'thisMonth';
                          _selectedCustomMonth = null;
                        });
                        _loadSummaryReport();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    selected: _currentFilter == 'thisYear',
                    label: const Text('This Year'),
                    selectedColor: Colors.blueAccent,
                    labelStyle: TextStyle(color: _currentFilter == 'thisYear' ? Colors.white : Colors.blueGrey, fontWeight: FontWeight.bold),
                    backgroundColor: const Color(0xFF0F172A),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _currentFilter = 'thisYear';
                          _selectedCustomMonth = null;
                        });
                        _loadSummaryReport();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    selected: _currentFilter == 'allTime',
                    label: const Text('All Time'),
                    selectedColor: Colors.blueAccent,
                    labelStyle: TextStyle(color: _currentFilter == 'allTime' ? Colors.white : Colors.blueGrey, fontWeight: FontWeight.bold),
                    backgroundColor: const Color(0xFF0F172A),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _currentFilter = 'allTime';
                          _selectedCustomMonth = null;
                        });
                        _loadSummaryReport();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    selected: _currentFilter == 'customMonth',
                    label: Text(_selectedCustomMonth == null
                        ? 'Select Month'
                        : '${_selectedCustomMonth!.year}-${_selectedCustomMonth!.month.toString().padLeft(2, '0')}'),
                    selectedColor: Colors.blueAccent,
                    labelStyle: TextStyle(color: _currentFilter == 'customMonth' ? Colors.white : Colors.blueGrey, fontWeight: FontWeight.bold),
                    backgroundColor: const Color(0xFF0F172A),
                    onSelected: (selected) async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedCustomMonth ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        helpText: 'Select Month Date',
                      );
                      if (picked != null) {
                        setState(() {
                          _currentFilter = 'customMonth';
                          _selectedCustomMonth = picked;
                        });
                        _loadSummaryReport();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _summary == null
                    ? const Center(child: Text('No reports data available.', style: TextStyle(color: Colors.blueGrey)))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildReportHeaderCard(totalPaid),
                            const SizedBox(height: 20),

                            // Dynamic Chart Visualizer
                            if (regFees > 0 || instFees > 0 || refunds > 0) ...[
                              _buildChartSection(regFees, instFees, refunds),
                              const SizedBox(height: 24),
                            ],

                            const Text(
                              'BUSINESS HIGHLIGHTS',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 12),
                            _buildReportRow('Total Revenue Collected', '₹$totalPaid'),
                            _buildReportRow('Total Baaki (Due)', '₹$totalPending'),
                            _buildReportRow('Total Fees (Expected)', '₹$totalFeesExpected'),
                            _buildReportRow('Gross Admissions', '${_summary!['admissions']?['summary']?['totalAdmissions'] ?? 0}'),
                            _buildReportRow('Total Leads Handled', '${_summary!['admissions']?['summary']?['totalEnquiries'] ?? 0}'),
                            _buildReportRow('Conversion Rate', '${_summary!['admissions']?['summary']?['conversionRate'] ?? 0}%'),
                            const SizedBox(height: 24),
                            const Text(
                              'FEE COLLECTION DETAILS',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 12),
                            _buildReportRow('Collected Registration Fees', '₹$regFees'),
                            _buildReportRow('Collected Installments', '₹$instFees'),
                            _buildReportRow('Refunded Fees', '₹$refunds'),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportHeaderCard(num totalPaid) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.blueAccent, Colors.indigoAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total Net Earnings', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            '₹$totalPaid',
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Gross collections across all admissions and packages minus refunded voids.',
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(num regFees, num instFees, num refunds) {
    final total = regFees + instFees + refunds;
    final regPct = total > 0 ? (regFees / total * 100).toStringAsFixed(1) : '0';
    final instPct = total > 0 ? (instFees / total * 100).toStringAsFixed(1) : '0';
    final refPct = total > 0 ? (refunds / total * 100).toStringAsFixed(1) : '0';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'COLLECTIONS DISTRIBUTION',
            style: TextStyle(color: Colors.blueGrey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 35,
                sections: [
                  if (regFees > 0)
                    PieChartSectionData(
                      color: Colors.blueAccent,
                      value: regFees.toDouble(),
                      title: '$regPct%',
                      radius: 40,
                      titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  if (instFees > 0)
                    PieChartSectionData(
                      color: Colors.teal,
                      value: instFees.toDouble(),
                      title: '$instPct%',
                      radius: 40,
                      titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  if (refunds > 0)
                    PieChartSectionData(
                      color: Colors.redAccent,
                      value: refunds.toDouble(),
                      title: '$refPct%',
                      radius: 40,
                      titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legend Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem('Reg.', Colors.blueAccent),
              _buildLegendItem('Installment', Colors.teal),
              if (refunds > 0) _buildLegendItem('Refund', Colors.redAccent),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLegendItem(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildReportRow(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.blueGrey, fontSize: 14, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
