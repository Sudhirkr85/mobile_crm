import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  bool _isLoading = false;
  bool _isLoadMoreRunning = false;
  List<dynamic> _payments = [];
  
  // Pagination
  int _currentPage = 1;
  int _totalPages = 1;
  final ScrollController _scrollController = ScrollController();

  // Filters
  String _searchQuery = '';
  String _typeFilter = 'all'; // all, REGISTRATION, INSTALLMENT, refund
  String _statusFilter = 'all'; // all, ACTIVE, VOIDED
  DateTime? _dateFrom;
  DateTime? _dateTo;

  // Stats
  double _totalCollected = 0.0;
  double _totalRefunded = 0.0;
  int _totalTransactions = 0;

  @override
  void initState() {
    super.initState();
    _loadPayments(isFirstLoad: true);
    _scrollController.addListener(_loadMore);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_loadMore);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPayments({required bool isFirstLoad}) async {
    if (isFirstLoad) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _payments = [];
      });
    } else {
      setState(() {
        _isLoadMoreRunning = true;
      });
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final queryParams = <String, dynamic>{
        'page': _currentPage,
        'limit': 15,
      };

      if (_searchQuery.isNotEmpty) {
        queryParams['search'] = _searchQuery;
      }
      if (_typeFilter != 'all') {
        queryParams['type'] = _typeFilter;
      }
      if (_statusFilter != 'all') {
        queryParams['status'] = _statusFilter;
      }
      if (_dateFrom != null) {
        queryParams['dateFrom'] = DateFormat('yyyy-MM-dd').format(_dateFrom!);
      }
      if (_dateTo != null) {
        queryParams['dateTo'] = DateFormat('yyyy-MM-dd').format(_dateTo!);
      }

      final res = await apiService.getRequest('/payments', queryParameters: queryParams);
      if (res.statusCode == 200 && res.data != null) {
        final dataObj = res.data['data'] ?? {};
        final items = dataObj['payments'] ?? [];
        final pagObj = dataObj['pagination'] ?? {};

        setState(() {
          _payments.addAll(items);
          _totalPages = pagObj['totalPages'] ?? 1;
          
          if (!isFirstLoad) {
            _currentPage++;
          } else {
            _currentPage = 2;
          }
        });

        // Compute summary metrics from current loaded/filtered list or calculate active sums
        _calculateStats();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load payments: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadMoreRunning = false;
        });
      }
    }
  }

  void _loadMore() async {
    if (_isLoading || _isLoadMoreRunning) return;
    if (_currentPage > _totalPages) return;

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadPayments(isFirstLoad: false);
    }
  }

  void _calculateStats() {
    double collected = 0;
    double refunded = 0;
    int activeCount = 0;

    for (var p in _payments) {
      final status = p['status'] ?? 'ACTIVE';
      if (status == 'VOIDED') continue;

      final amt = double.tryParse(p['amount'].toString()) ?? 0.0;
      final isRefund = p['isRefund'] == true || p['type'] == 'refund';

      if (isRefund) {
        refunded += amt;
      } else {
        collected += amt;
      }
      activeCount++;
    }

    setState(() {
      _totalCollected = collected;
      _totalRefunded = refunded;
      _totalTransactions = activeCount;
    });
  }

  bool get _hasActiveFilters =>
      _typeFilter != 'all' ||
      _statusFilter != 'all' ||
      _dateFrom != null ||
      _dateTo != null;

  void _resetFilters() {
    setState(() {
      _typeFilter = 'all';
      _statusFilter = 'all';
      _dateFrom = null;
      _dateTo = null;
    });
    _loadPayments(isFirstLoad: true);
  }

  void _openFilterSheet() {
    String localType = _typeFilter;
    String localStatus = _statusFilter;
    DateTime? localDateFrom = _dateFrom;
    DateTime? localDateTo = _dateTo;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
                    ),
                  ),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Filter Payments', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          setLocal(() {
                            localType = 'all';
                            localStatus = 'all';
                            localDateFrom = null;
                            localDateTo = null;
                          });
                        },
                        child: const Text('Reset', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 20),

                  // Payment Type
                  const Text('Payment Type', style: TextStyle(color: Colors.blueGrey, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      {'label': 'All', 'value': 'all'},
                      {'label': 'Registration', 'value': 'REGISTRATION'},
                      {'label': 'Installment', 'value': 'INSTALLMENT'},
                      {'label': 'Refund', 'value': 'refund'},
                    ].map((t) {
                      final isSelected = localType == t['value'];
                      return ChoiceChip(
                        selected: isSelected,
                        label: Text(t['label'] as String, style: TextStyle(color: isSelected ? Colors.white : Colors.blueGrey, fontSize: 12)),
                        backgroundColor: const Color(0xFF0F172A),
                        selectedColor: Colors.blueAccent,
                        side: BorderSide(color: isSelected ? Colors.blueAccent : Colors.white12),
                        onSelected: (_) => setLocal(() => localType = t['value'] as String),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Status
                  const Text('Status', style: TextStyle(color: Colors.blueGrey, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      {'label': 'All', 'value': 'all'},
                      {'label': 'Active', 'value': 'ACTIVE'},
                      {'label': 'Voided', 'value': 'VOIDED'},
                    ].map((s) {
                      final isSelected = localStatus == s['value'];
                      return ChoiceChip(
                        selected: isSelected,
                        label: Text(s['label'] as String, style: TextStyle(color: isSelected ? Colors.white : Colors.blueGrey, fontSize: 12)),
                        backgroundColor: const Color(0xFF0F172A),
                        selectedColor: Colors.teal,
                        side: BorderSide(color: isSelected ? Colors.teal : Colors.white12),
                        onSelected: (_) => setLocal(() => localStatus = s['value'] as String),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Date range
                  const Text('Date Range', style: TextStyle(color: Colors.blueGrey, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: localDateFrom ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              builder: (ctx, child) => Theme(data: ThemeData.dark(), child: child!),
                            );
                            if (d != null) setLocal(() => localDateFrom = d);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: localDateFrom != null ? Colors.blueAccent : Colors.white12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, color: Colors.blueGrey, size: 14),
                                const SizedBox(width: 8),
                                Text(
                                  localDateFrom != null ? DateFormat('dd MMM yy').format(localDateFrom!) : 'From',
                                  style: TextStyle(color: localDateFrom != null ? Colors.white : Colors.blueGrey, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: localDateTo ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              builder: (ctx, child) => Theme(data: ThemeData.dark(), child: child!),
                            );
                            if (d != null) setLocal(() => localDateTo = d);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: localDateTo != null ? Colors.blueAccent : Colors.white12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, color: Colors.blueGrey, size: 14),
                                const SizedBox(width: 8),
                                Text(
                                  localDateTo != null ? DateFormat('dd MMM yy').format(localDateTo!) : 'To',
                                  style: TextStyle(color: localDateTo != null ? Colors.white : Colors.blueGrey, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Apply
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _typeFilter = localType;
                          _statusFilter = localStatus;
                          _dateFrom = localDateFrom;
                          _dateTo = localDateTo;
                        });
                        _loadPayments(isFirstLoad: true);
                      },
                      child: const Text('Apply Filters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final netCollection = _totalCollected - _totalRefunded;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Payments Ledger', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. Dashboard summary cards (horizontal scrollable)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                _buildSummaryCard('Total Collection', '₹${netCollection.toStringAsFixed(0)}', Colors.green, Icons.account_balance_wallet),
                const SizedBox(width: 12),
                _buildSummaryCard('Total Received', '₹${_totalCollected.toStringAsFixed(0)}', Colors.blueAccent, Icons.arrow_downward),
                const SizedBox(width: 12),
                _buildSummaryCard('Total Refunded', '₹${_totalRefunded.toStringAsFixed(0)}', Colors.redAccent, Icons.replay),
                const SizedBox(width: 12),
                _buildSummaryCard('Active Txns', '$_totalTransactions', Colors.purpleAccent, Icons.receipt_long),
              ],
            ),
          ),

          // 2. Search & Filter buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search by student name...',
                      hintStyle: const TextStyle(color: Colors.blueGrey),
                      prefixIcon: const Icon(Icons.search, color: Colors.blueGrey),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                      _loadPayments(isFirstLoad: true);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Stack(
                  children: [
                    GestureDetector(
                      onTap: _openFilterSheet,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: _hasActiveFilters ? Colors.blueAccent : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _hasActiveFilters ? Colors.blueAccent : Colors.white12),
                        ),
                        child: Icon(Icons.tune_rounded, color: _hasActiveFilters ? Colors.white : Colors.blueGrey, size: 22),
                      ),
                    ),
                    if (_hasActiveFilters)
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        ),
                      ),
                  ],
                ),
                if (_hasActiveFilters) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _resetFilters,
                    child: Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                      ),
                      child: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Active filter tags display
          if (_hasActiveFilters)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (_typeFilter != 'all')
                      _buildActiveFilterChip('Type: $_typeFilter', Colors.blueAccent),
                    if (_statusFilter != 'all')
                      _buildActiveFilterChip('Status: $_statusFilter', Colors.teal),
                    if (_dateFrom != null)
                      _buildActiveFilterChip('From: ${DateFormat('dd MMM').format(_dateFrom!)}', Colors.orange),
                    if (_dateTo != null)
                      _buildActiveFilterChip('To: ${DateFormat('dd MMM').format(_dateTo!)}', Colors.orange),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 8),

          // 3. Main Payments List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _payments.isEmpty
                    ? const Center(child: Text('No payments found.', style: TextStyle(color: Colors.blueGrey)))
                    : RefreshIndicator(
                        onRefresh: () => _loadPayments(isFirstLoad: true),
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: _payments.length + (_isLoadMoreRunning ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _payments.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              );
                            }

                            final payment = _payments[index];
                            final studentName = payment['studentName'] ?? 'General Payment';
                            final mobile = payment['studentMobile'] ?? '';
                            final course = payment['course'] ?? '';
                            final mode = payment['paymentMode'] ?? 'Cash';
                            final amount = payment['amount'] ?? 0;
                            final type = payment['type'] ?? 'INSTALLMENT';
                            final status = payment['status'] ?? 'ACTIVE';

                            final isRefund = payment['isRefund'] == true || type == 'refund';
                            final isVoided = status == 'VOIDED';

                            final dateStr = payment['paymentDate'] ?? '';
                            String formattedDate = '';
                            try {
                              if (dateStr.isNotEmpty) {
                                formattedDate = DateFormat('dd MMM yyyy').format(DateTime.parse(dateStr).toLocal());
                              }
                            } catch (_) {}

                            // Decorate icons and text based on type & status
                            IconData payIcon = Icons.payment;
                            Color iconColor = Colors.blueGrey;
                            String prefix = '₹';

                            if (isVoided) {
                              payIcon = Icons.cancel_outlined;
                              iconColor = Colors.redAccent;
                            } else if (isRefund) {
                              payIcon = Icons.replay_rounded;
                              iconColor = Colors.orangeAccent;
                              prefix = '-₹';
                            } else if (type == 'REGISTRATION') {
                              payIcon = Icons.app_registration;
                              iconColor = Colors.teal;
                              prefix = '+₹';
                            } else if (type == 'INSTALLMENT' || type == 'initial' || type == 'full') {
                              payIcon = Icons.monetization_on_outlined;
                              iconColor = Colors.green;
                              prefix = '+₹';
                            }

                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isVoided 
                                      ? Colors.redAccent.withValues(alpha: 0.1)
                                      : isRefund 
                                          ? Colors.orangeAccent.withValues(alpha: 0.1)
                                          : Colors.white.withValues(alpha: 0.05)
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: iconColor.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(payIcon, color: iconColor, size: 20),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        studentName,
                                        style: TextStyle(
                                          color: isVoided ? Colors.blueGrey : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          decoration: isVoided ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                    ),
                                    if (isVoided)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                                        child: const Text('VOIDED', style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      '$course • $mode • ${type.toUpperCase()}',
                                      style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 11),
                                    ),
                                    if (mobile.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Mobile: $mobile • $formattedDate',
                                        style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 11),
                                      ),
                                    ] else ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        formattedDate,
                                        style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 11),
                                      ),
                                    ]
                                  ],
                                ),
                                trailing: Text(
                                  '$prefix$amount',
                                  style: TextStyle(
                                    color: isVoided 
                                        ? Colors.blueGrey 
                                        : isRefund 
                                            ? Colors.orangeAccent 
                                            : Colors.greenAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    decoration: isVoided ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color, IconData icon) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              )
            ],
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.blueGrey, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildActiveFilterChip(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
