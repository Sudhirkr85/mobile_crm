import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class AdmissionListScreen extends StatefulWidget {
  const AdmissionListScreen({super.key});

  @override
  State<AdmissionListScreen> createState() => _AdmissionListScreenState();
}

class _AdmissionListScreenState extends State<AdmissionListScreen> {
  bool _isLoading = false;
  bool _isLoadMoreRunning = false;
  List<dynamic> _admissions = [];
  String _searchQuery = '';
  String _statusFilter = 'ALL';
  bool _hasDuesFilter = false;
  String _dateRangeFilter = 'thisMonth'; // 'thisMonth', 'thisYear', 'allTime'

  int _currentPage = 1;
  int _totalPages = 1;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadAdmissions(isFirstLoad: true);
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _makeCall(String mobile) async {
    final Uri uri = Uri(scheme: 'tel', path: mobile);
    try {
      await launchUrl(uri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not launch call: $e')));
      }
    }
  }

  Future<void> _sendWhatsApp(String mobile) async {
    final cleanMobile = mobile.replaceAll(RegExp(r'\D'), '');
    final formattedMobile = cleanMobile.length == 10 ? '91$cleanMobile' : cleanMobile;
    final Uri uri = Uri.parse("https://wa.me/$formattedMobile");
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not launch WhatsApp: $e')));
      }
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      if (_currentPage < _totalPages && !_isLoadMoreRunning) {
        _loadAdmissions(isFirstLoad: false);
      }
    }
  }

  Future<void> _loadAdmissions({required bool isFirstLoad}) async {
    if (isFirstLoad) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _admissions = [];
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
        'limit': 10,
      };
      if (_searchQuery.isNotEmpty) {
        queryParams['search'] = _searchQuery;
      }
      if (_statusFilter != 'ALL') {
        queryParams['status'] = _statusFilter;
      }
      if (_hasDuesFilter) {
        queryParams['hasDues'] = 'true';
        queryParams['sortBy'] = 'nextDue';
        queryParams['sortOrder'] = 'asc';
      }

      // Add createdDate range filters
      final dateRange = _getDateRangeParams();
      queryParams['dateFrom'] = dateRange['dateFrom'];
      queryParams['dateTo'] = dateRange['dateTo'];

      final res = await apiService.getRequest('/admissions', queryParameters: queryParams);
      if (res.statusCode == 200 && res.data != null) {
        final items = res.data['data'] ?? [];
        final pagObj = res.data['pagination'] ?? {};

        setState(() {
          _admissions.addAll(items);
          _totalPages = pagObj['totalPages'] ?? 1;
          if (!isFirstLoad) {
            _currentPage++;
          } else {
            _currentPage = 2; // Setup for next page load
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load admissions: ${ApiService.getReadableError(e)}')));
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadMoreRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Admissions & Students', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Date Range Filter Tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                const Text(
                  'Date Range: ',
                  style: TextStyle(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildDateTabButton('This Month', 'thisMonth'),
                      const SizedBox(width: 6),
                      _buildDateTabButton('This Year', 'thisYear'),
                      const SizedBox(width: 6),
                      _buildDateTabButton('All Time', 'allTime'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search by Name, Mobile & Course...',
                      hintStyle: const TextStyle(color: Colors.blueGrey, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: Colors.blueGrey),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                      _loadAdmissions(isFirstLoad: true);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButton<String>(
                    value: _statusFilter,
                    dropdownColor: const Color(0xFF1E293B),
                    underline: const SizedBox(),
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All')),
                      DropdownMenuItem(value: 'Active', child: Text('Active')),
                      DropdownMenuItem(value: 'Dropped', child: Text('Dropped')),
                      DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _statusFilter = val;
                        });
                        _loadAdmissions(isFirstLoad: true);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: Text(
                    _hasDuesFilter ? 'Pending Dues & Upcoming Sort: ON' : 'Filter: Pending Dues & Upcoming Sort',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  selected: _hasDuesFilter,
                  selectedColor: Colors.amber.shade700,
                  backgroundColor: const Color(0xFF1E293B),
                  checkmarkColor: Colors.white,
                  onSelected: (bool selected) {
                    setState(() {
                      _hasDuesFilter = selected;
                    });
                    _loadAdmissions(isFirstLoad: true);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _admissions.isEmpty
                    ? const Center(child: Text('No admissions found.', style: TextStyle(color: Colors.blueGrey)))
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _admissions.length + (_isLoadMoreRunning ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _admissions.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          }
                          final student = _admissions[index];
                          final status = (student['status'] ?? 'active').toString().toLowerCase();
                          final course = student['course'] ?? 'N/A';
                          final pending = student['remainingAmount'] ?? student['pendingAmount'] ?? 0;

                           final mobile = student['mobile'] ?? '';

                           return Card(
                             color: const Color(0xFF1E293B),
                             margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                             child: InkWell(
                               onTap: () => Navigator.push(
                                 context,
                                 MaterialPageRoute(builder: (_) => AdmissionDetailScreen(admissionId: student['_id'])),
                               ).then((_) => _loadAdmissions(isFirstLoad: true)),
                               borderRadius: BorderRadius.circular(12),
                               child: Padding(
                                 padding: const EdgeInsets.all(16.0),
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     Row(
                                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                       children: [
                                         Expanded(
                                           child: Text(
                                             student['name'] ?? 'No Name',
                                             style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                           ),
                                         ),
                                         Container(
                                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                           decoration: BoxDecoration(
                                             color: status == 'active' ? Colors.teal.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                                             borderRadius: BorderRadius.circular(8),
                                             border: Border.all(color: status == 'active' ? Colors.teal.withOpacity(0.5) : Colors.red.withOpacity(0.5)),
                                           ),
                                           child: Text(
                                             status[0].toUpperCase() + status.substring(1),
                                             style: TextStyle(color: status == 'active' ? Colors.teal : Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                                           ),
                                         ),
                                       ],
                                     ),
                                     const SizedBox(height: 8),
                                     Text(
                                       course,
                                       style: const TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.w500),
                                     ),
                                     const SizedBox(height: 4),
                                     Text(
                                       'Pending Fees: ₹$pending',
                                       style: TextStyle(color: pending > 0 ? Colors.redAccent : Colors.blueGrey, fontSize: 12, fontWeight: pending > 0 ? FontWeight.bold : FontWeight.normal),
                                     ),
                                     const Divider(color: Colors.white10, height: 20),
                                     Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            mobile,
                                            style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 12, fontWeight: FontWeight.w500),
                                          ),
                                          Row(
                                            children: [
                                              if (mobile.isNotEmpty) ...[
                                                IconButton(
                                                  icon: const Icon(Icons.phone, color: Colors.green, size: 16),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                  onPressed: () => _makeCall(mobile),
                                                ),
                                                const SizedBox(width: 12),
                                                IconButton(
                                                  icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF25D366), size: 16),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                  onPressed: () => _sendWhatsApp(mobile),
                                                ),
                                                const SizedBox(width: 12),
                                              ],
                                              IconButton(
                                                icon: const Icon(Icons.visibility, color: Colors.blueAccent, size: 16),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(builder: (_) => AdmissionDetailScreen(admissionId: student['_id'])),
                                                ).then((_) => _loadAdmissions(isFirstLoad: true)),
                                              ),
                                              const SizedBox(width: 12),
                                              IconButton(
                                                icon: const Icon(Icons.add_circle_outline, color: Colors.green, size: 16),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: () => _showAddPaymentFromList(student),
                                              ),
                                              const SizedBox(width: 12),
                                              IconButton(
                                                icon: const Icon(Icons.receipt_long, color: Colors.blue, size: 16),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: () => _showPaymentHistoryFromList(student),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                   ],
                                 ),
                               ),
                             ),
                           );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Map<String, String> _getDateRangeParams() {
    final today = DateTime.now();
    DateTime startDate;
    DateTime endDate = DateTime(today.year, today.month, today.day, 23, 59, 59, 999);

    if (_dateRangeFilter == 'thisMonth') {
      startDate = DateTime(today.year, today.month, 1);
    } else if (_dateRangeFilter == 'thisYear') {
      startDate = DateTime(today.year, 1, 1);
    } else {
      // allTime: since 2020
      startDate = DateTime(2020, 1, 1);
    }

    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    return {
      'dateFrom': formatter.format(startDate),
      'dateTo': formatter.format(endDate),
    };
  }

  Widget _buildDateTabButton(String label, String value) {
    final isSelected = _dateRangeFilter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _dateRangeFilter = value;
          });
          _loadAdmissions(isFirstLoad: true);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade700 : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? Colors.blueAccent : Colors.white.withOpacity(0.05),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.blueGrey,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddPaymentFromList(dynamic student) async {
    final remainingAmount = ((student['remainingAmount'] ?? student['pendingAmount'] ?? 0) as num).toDouble();
    if (remainingAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This student has no pending dues.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.amber),
      );
      return;
    }

    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String paymentType = 'installment';
    String paymentMode = 'CASH';
    DateTime paymentDate = DateTime.now();
    final List<String> modes = ['CASH', 'UPI', 'CARD', 'ONLINE', 'CHEQUE', 'BANK_TRANSFER'];

    final installments = student['installments'] as List<dynamic>? ?? [];
    final pendingInstallments = installments.where((inst) => inst['status'] == 'PENDING').toList();

    String getModeLabel(String mode) {
      switch (mode) {
        case 'CASH': return '💵 Cash';
        case 'UPI': return '📱 UPI';
        case 'CARD': return '💳 Card';
        case 'ONLINE': return '🏦 Online Transfer';
        case 'CHEQUE': return '📋 Cheque';
        case 'BANK_TRANSFER': return '🏛️ Bank Transfer';
        default: return mode;
      }
    }

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Record Payment',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                      child: const Icon(Icons.add_card, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Add Payment', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(student['name'] ?? 'Record new fee payment', style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Balances box
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                children: [
                                  const Text('TOTAL', style: TextStyle(color: Colors.blueGrey, fontSize: 10)),
                                  const SizedBox(height: 2),
                                  Text('₹${student['totalFees'] ?? 0}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Column(
                                children: [
                                  const Text('PAID', style: TextStyle(color: Colors.blueGrey, fontSize: 10)),
                                  const SizedBox(height: 2),
                                  Text('₹${student['totalPaid'] ?? 0}', style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Column(
                                children: [
                                  const Text('BALANCE', style: TextStyle(color: Colors.blueGrey, fontSize: 10)),
                                  const SizedBox(height: 2),
                                  Text('₹${remainingAmount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Installment schedule
                        if (pendingInstallments.isNotEmpty) ...[
                          const Text('INSTALLMENT SCHEDULE', style: TextStyle(color: Colors.blueGrey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          const SizedBox(height: 8),
                          ...pendingInstallments.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final inst = entry.value;
                            final amt = inst['amount'] ?? 0;
                            final dueDateStr = inst['dueDate'] != null 
                                ? DateFormat('dd/MM/yyyy').format(DateTime.parse(inst['dueDate'].toString()))
                                : '--/--/----';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white.withOpacity(0.05)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Installment ${idx + 1}: ₹$amt (Due: $dueDateStr)',
                                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade700,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () {
                                      setDialogState(() {
                                        amountController.text = amt.toString();
                                      });
                                    },
                                    child: const Text('Pay This', style: TextStyle(color: Colors.white, fontSize: 10)),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          const SizedBox(height: 16),
                        ],

                        // Amount input
                        TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Amount (₹) *',
                            labelStyle: TextStyle(color: Colors.blueGrey),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueGrey)),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Payment Type dropdown
                        DropdownButtonFormField<String>(
                          value: paymentType,
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Payment Type *',
                            labelStyle: TextStyle(color: Colors.blueGrey),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueGrey)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'installment', child: Text('Installment Payment')),
                            DropdownMenuItem(value: 'full', child: Text('Full Payment')),
                            DropdownMenuItem(value: 'admission', child: Text('Admission/Registration Fee')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                paymentType = val;
                                if (paymentType == 'full') {
                                  amountController.text = remainingAmount.toStringAsFixed(0);
                                }
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Payment Mode dropdown
                        DropdownButtonFormField<String>(
                          value: paymentMode,
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Payment Mode *',
                            labelStyle: TextStyle(color: Colors.blueGrey),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueGrey)),
                          ),
                          items: modes.map((m) {
                            return DropdownMenuItem(value: m, child: Text(getModeLabel(m)));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                paymentMode = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Date picker
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: paymentDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                paymentDate = picked;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Payment Date *',
                              labelStyle: TextStyle(color: Colors.blueGrey),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueGrey)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormat('dd MMM yyyy').format(paymentDate),
                                  style: const TextStyle(color: Colors.white),
                                ),
                                const Icon(Icons.calendar_today, color: Colors.blueGrey, size: 16),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Note input
                        TextField(
                          controller: noteController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Note',
                            labelStyle: TextStyle(color: Colors.blueGrey),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueGrey)),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.blueGrey)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () async {
                      final amountText = amountController.text.trim();
                      if (amountText.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter amount')));
                        return;
                      }
                      final amount = double.tryParse(amountText) ?? 0.0;
                      if (amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Amount must be greater than zero')));
                        return;
                      }

                      if (paymentType == 'full' && (amount - remainingAmount).abs() > 0.01) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('For Full Payment type, amount must equal remaining balance exactly')));
                        return;
                      }

                      final apiService = Provider.of<ApiService>(context, listen: false);
                      final df = DateFormat('yyyy-MM-dd');
                      final data = {
                        'amount': amount,
                        'paymentType': paymentType.toUpperCase(),
                        'paymentMode': paymentMode,
                        'paymentDate': df.format(paymentDate),
                        'note': noteController.text.trim(),
                      };

                      try {
                        final res = await apiService.postRequest('/admissions/${student['_id']}/payments', data: data);
                        if (res.statusCode == 200 || res.statusCode == 210) {
                          if (context.mounted) Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Payment recorded successfully!'), backgroundColor: Colors.green),
                          );
                          _loadAdmissions(isFirstLoad: true);
                        } else {
                          String msg = res.data?['message'] ?? 'Failed to record payment';
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to record payment: ${ApiService.getReadableError(e)}')));
                      }
                    },
                    child: const Text('Save Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showPaymentHistoryFromList(dynamic student) async {
    setState(() {
      _isLoading = true;
    });

    List<dynamic> payments = [];
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final res = await apiService.getRequest('/admissions/${student['_id']}/payments');
      if (res.statusCode == 200 && res.data != null) {
        final rawData = res.data['data'];
        if (rawData is Map && rawData['payments'] != null) {
          payments = rawData['payments'] as List<dynamic>? ?? [];
        } else if (rawData is List) {
          payments = rawData;
        } else {
          payments = res.data['data'] as List<dynamic>? ?? [];
        }
      }
    } catch (e) {
      debugPrint('Failed to load payment history: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }

    final totalPaid = ((student['totalPaid'] ?? 0) as num).toDouble();
    final remainingAmount = ((student['remainingAmount'] ?? student['pendingAmount'] ?? 0) as num).toDouble();

    if (!mounted) return;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Payment History',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                  child: const Icon(Icons.history, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Payment History', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(student['name'] ?? '', style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Balances box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            children: [
                              const Text('TOTAL', style: TextStyle(color: Colors.blueGrey, fontSize: 10)),
                              const SizedBox(height: 2),
                              Text('₹${student['totalFees'] ?? 0}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Column(
                            children: [
                              const Text('PAID', style: TextStyle(color: Colors.blueGrey, fontSize: 10)),
                              const SizedBox(height: 2),
                              Text('₹${totalPaid.toStringAsFixed(0)}', style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Column(
                            children: [
                              const Text('REMAINING', style: TextStyle(color: Colors.blueGrey, fontSize: 10)),
                              const SizedBox(height: 2),
                              Text('₹${remainingAmount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (payments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('No payments recorded yet.', style: TextStyle(color: Colors.blueGrey)),
                      )
                    else
                      ...payments.map((pay) {
                        final amt = pay['amount'] ?? 0;
                        final mode = pay['paymentMode'] ?? 'N/A';
                        final type = pay['paymentType'] ?? 'INSTALLMENT';
                        final rawDate = pay['paymentDate'] ?? pay['createdAt'] ?? '';
                        final formattedDate = rawDate.isNotEmpty
                            ? DateFormat('dd MMM yyyy').format(DateTime.parse(rawDate.toString()))
                            : 'N/A';
                        final note = pay['note'] ?? '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '₹$amt',
                                    style: const TextStyle(color: Colors.green, fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      type.toString().toUpperCase(),
                                      style: const TextStyle(color: Colors.blueAccent, fontSize: 8, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$formattedDate • $mode',
                                    style: const TextStyle(color: Colors.blueGrey, fontSize: 11),
                                  ),
                                ],
                              ),
                              if (note.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  note,
                                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(color: Colors.blueAccent)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AdmissionDetailScreen extends StatefulWidget {
  final String admissionId;
  const AdmissionDetailScreen({super.key, required this.admissionId});

  @override
  State<AdmissionDetailScreen> createState() => _AdmissionDetailScreenState();
}

class _AdmissionDetailScreenState extends State<AdmissionDetailScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _detail;

  List<dynamic> _payments = [];

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final res = await apiService.getRequest('/admissions/${widget.admissionId}');
      if (res.statusCode == 200 && res.data != null) {
        final rawDetail = res.data['data'];
        if (rawDetail is Map) {
          _detail = rawDetail['admission'] ?? rawDetail;
        } else {
          _detail = rawDetail;
        }
      }

      // Fetch payment transactions
      final payRes = await apiService.getRequest('/admissions/${widget.admissionId}/payments');
      if (payRes.statusCode == 200 && payRes.data != null) {
        setState(() {
          final rawData = payRes.data['data'];
          if (rawData is Map) {
            _payments = rawData['payments'] as List<dynamic>? ?? [];
          } else if (rawData is List) {
            _payments = rawData;
          } else {
            _payments = [];
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load admission detail: ${ApiService.getReadableError(e)}')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
                    Navigator.pop(context); // Close dialog
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
                  'Record Failed',
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
                    Navigator.pop(context); // Close dialog
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

  Future<void> _recordPayment(double remainingAmount) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String paymentType = 'installment';
    String paymentMode = 'CASH';
    DateTime paymentDate = DateTime.now();
    final List<String> modes = ['CASH', 'UPI', 'CARD', 'ONLINE', 'CHEQUE', 'BANK_TRANSFER'];

    String getModeLabel(String mode) {
      switch (mode) {
        case 'CASH':
          return '💵 Cash';
        case 'UPI':
          return '📱 UPI';
        case 'CARD':
          return '💳 Card';
        case 'ONLINE':
          return '🏦 Online Transfer';
        case 'CHEQUE':
          return '📋 Cheque';
        case 'BANK_TRANSFER':
          return '🏛️ Bank Transfer';
        default:
          return mode;
      }
    }

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Record Payment',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_card, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Add Payment', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Record new fee payment', style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                content: Container(
                  width: double.maxFinite,
                  constraints: const BoxConstraints(maxHeight: 450),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Remaining Balance:', style: TextStyle(color: Colors.tealAccent, fontSize: 13)),
                              Text('₹${remainingAmount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Amount (₹) *',
                            labelStyle: TextStyle(color: Colors.blueGrey),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: paymentType,
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Payment Type *',
                            labelStyle: TextStyle(color: Colors.blueGrey),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'installment', child: Text('Installment')),
                            DropdownMenuItem(value: 'full', child: Text('Full Payment')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                paymentType = val;
                                if (paymentType == 'full') {
                                  amountController.text = remainingAmount.toStringAsFixed(0);
                                }
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: paymentMode,
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Payment Mode *',
                            labelStyle: TextStyle(color: Colors.blueGrey),
                          ),
                          items: modes.map((m) {
                            return DropdownMenuItem(
                              value: m,
                              child: Text(getModeLabel(m)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                paymentMode = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: paymentDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.dark(
                                      primary: Colors.teal,
                                      onPrimary: Colors.white,
                                      surface: Color(0xFF1E293B),
                                      onSurface: Colors.white,
                                    ),
                                    dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF0F172A)),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setDialogState(() {
                                paymentDate = picked;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Payment Date *',
                              labelStyle: TextStyle(color: Colors.blueGrey),
                            ),
                            child: Text(
                              DateFormat('dd MMM yyyy').format(paymentDate),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: noteController,
                          maxLines: 2,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Note (Optional)',
                            labelStyle: TextStyle(color: Colors.blueGrey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountController.text) ?? 0.0;
                      if (amount <= 0) {
                        _showErrorDialog('Please enter a valid amount');
                        return;
                      }
                      if (amount > remainingAmount) {
                        _showErrorDialog('Amount cannot exceed remaining balance (₹${remainingAmount.toStringAsFixed(0)})');
                        return;
                      }
                      if (paymentType == 'full' && (amount - remainingAmount).abs() > 0.01) {
                        _showErrorDialog('For "Full Payment" type, amount must equal remaining balance exactly');
                        return;
                      }

                      Navigator.pop(context);

                      setState(() {
                        _isLoading = true;
                      });

                      try {
                        final apiService = Provider.of<ApiService>(context, listen: false);
                        final DateFormat df = DateFormat('yyyy-MM-dd');
                        final Map<String, dynamic> data = {
                          'amount': amount,
                          'paymentMode': paymentMode,
                          'paymentDate': df.format(paymentDate),
                        };
                        if (noteController.text.trim().isNotEmpty) {
                          data['note'] = noteController.text.trim();
                        }

                        final res = await apiService.postRequest('/admissions/${widget.admissionId}/payments', data: data);
                        if (res.statusCode == 201 || res.statusCode == 200) {
                          _showSuccessDialogWithMessage('Payment recorded successfully!');
                          _loadDetails();
                        } else {
                          String msg = res.data?['message'] ?? 'Failed to record payment';
                          _showErrorDialog(msg);
                        }
                      } catch (e) {
                        _showErrorDialog(e.toString());
                      } finally {
                        setState(() {
                          _isLoading = false;
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Save Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _makeCall(String mobile) async {
    final Uri uri = Uri(scheme: 'tel', path: mobile);
    try {
      await launchUrl(uri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not launch call: $e')));
      }
    }
  }

  Future<void> _sendWhatsApp(String mobile) async {
    final cleanMobile = mobile.replaceAll(RegExp(r'\D'), '');
    final formattedMobile = cleanMobile.length == 10 ? '91$cleanMobile' : cleanMobile;
    final Uri uri = Uri.parse("https://wa.me/$formattedMobile");
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not launch WhatsApp: $e')));
      }
    }
  }

  Future<void> _handleVoidPayment(String paymentId) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final res = await apiService.postRequest('/payments/$paymentId/void');
      if (res.statusCode == 200) {
        _loadDetails();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment voided successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Void failed: ${ApiService.getReadableError(e)}')));
    }
  }

  Future<void> _handleRefundPayment(String paymentId) async {
    final amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Refund Payment', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Refund Amount (₹)', labelStyle: TextStyle(color: Colors.blueGrey)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final apiService = Provider.of<ApiService>(context, listen: false);
                  final amount = double.parse(amountController.text);
                  final res = await apiService.postRequest('/payments/$paymentId/refund', data: {
                    'amount': amount,
                  });
                  if (res.statusCode == 200) {
                    Navigator.pop(context);
                    _loadDetails();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment refunded successfully!'), backgroundColor: Colors.green));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Refund failed: ${ApiService.getReadableError(e)}')));
                }
              },
              child: const Text('Refund'),
            )
          ],
        );
      },
    );
  }

  Future<void> _setInstallmentPlan(double remainingInstallmentBalance) async {
    final List<dynamic> existingInstallments = _detail!['installments'] as List<dynamic>? ?? [];
    final List<InstallmentRowData> dialogRows = [];

    if (existingInstallments.isNotEmpty) {
      for (var inst in existingInstallments) {
        final amount = (inst['amount'] as num?)?.toDouble() ?? 0.0;
        final dueDateStr = inst['dueDate'] as String?;
        final dueDate = dueDateStr != null ? DateTime.parse(dueDateStr) : null;
        dialogRows.add(InstallmentRowData(amount: amount, dueDate: dueDate));
      }
    } else {
      dialogRows.add(InstallmentRowData(amount: remainingInstallmentBalance, dueDate: null));
    }

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Set Installments',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              double currentSum = 0.0;
              for (var row in dialogRows) {
                currentSum += double.tryParse(row.amountController.text) ?? 0.0;
              }
              final diff = remainingInstallmentBalance - currentSum;
              final isMatching = diff.abs() < 0.01;

              return AlertDialog(
                backgroundColor: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.calendar_month, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Set Installments', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Configure installment schedule', style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                content: Container(
                  width: double.maxFinite,
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Remaining Dues to Plan:', style: TextStyle(color: Colors.amberAccent, fontSize: 13)),
                              Text('₹${remainingInstallmentBalance.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: dialogRows.length,
                          itemBuilder: (context, index) {
                            final row = dialogRows[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: row.amountController,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(color: Colors.white),
                                      decoration: InputDecoration(
                                        labelText: 'Amount (₹) *',
                                        labelStyle: const TextStyle(color: Colors.blueGrey),
                                        hintText: 'Inst. ${index + 1}',
                                      ),
                                      onChanged: (_) {
                                        setDialogState(() {});
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () async {
                                        final DateTime? picked = await showDatePicker(
                                          context: context,
                                          initialDate: row.dueDate ?? DateTime.now().add(Duration(days: 30 * (index + 1))),
                                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                          lastDate: DateTime(2100),
                                          builder: (context, child) {
                                            return Theme(
                                              data: Theme.of(context).copyWith(
                                                colorScheme: const ColorScheme.dark(
                                                  primary: Colors.teal,
                                                  onPrimary: Colors.white,
                                                  surface: Color(0xFF1E293B),
                                                  onSurface: Colors.white,
                                                ),
                                                dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF0F172A)),
                                              ),
                                              child: child!,
                                            );
                                          },
                                        );
                                        if (picked != null) {
                                          setDialogState(() {
                                            row.dueDate = picked;
                                          });
                                        }
                                      },
                                      child: InputDecorator(
                                        decoration: const InputDecoration(
                                          labelText: 'Due Date *',
                                          labelStyle: TextStyle(color: Colors.blueGrey),
                                        ),
                                        child: Text(
                                          row.dueDate != null
                                              ? DateFormat('dd MMM yyyy').format(row.dueDate!)
                                              : 'Select Date',
                                          style: TextStyle(
                                            color: row.dueDate != null ? Colors.white : Colors.tealAccent,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                    onPressed: () {
                                      if (dialogRows.length > 1) {
                                        setDialogState(() {
                                          row.dispose();
                                          dialogRows.removeAt(index);
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              final row = InstallmentRowData(amount: null, dueDate: null);
                              row.amountController.addListener(() {
                                setDialogState(() {});
                              });
                              dialogRows.add(row);
                            });
                          },
                          icon: const Icon(Icons.add, color: Colors.teal),
                          label: const Text('Add Installment Row', style: TextStyle(color: Colors.teal)),
                        ),
                        const SizedBox(height: 12),
                        if (!isMatching)
                          Text(
                            diff > 0
                                ? 'Total is ₹${diff.toStringAsFixed(0)} LESS than remaining balance.'
                                : 'Total EXCEEDS remaining balance by ₹${diff.abs().toStringAsFixed(0)}.',
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                          )
                        else
                          Row(
                            children: const [
                              Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                              SizedBox(width: 6),
                              Text('Total matches remaining balance exactly!', style: TextStyle(color: Colors.green, fontSize: 12)),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      for (var r in dialogRows) {
                        r.dispose();
                      }
                      Navigator.pop(context);
                    },
                    child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
                  ),
                  ElevatedButton(
                    onPressed: isMatching
                        ? () async {
                            final List<Map<String, dynamic>> instData = [];
                            for (var r in dialogRows) {
                              final amt = double.tryParse(r.amountController.text) ?? 0.0;
                              if (amt <= 0 || r.dueDate == null) {
                                _showErrorDialog('All rows must have positive amounts and valid due dates.');
                                return;
                              }
                              instData.add({
                                'amount': amt,
                                'dueDate': DateFormat('yyyy-MM-dd').format(r.dueDate!),
                                'note': 'Installment plan updated by admin',
                              });
                            }

                            Navigator.pop(context);
                            setState(() {
                              _isLoading = true;
                            });

                            try {
                              final apiService = Provider.of<ApiService>(context, listen: false);
                              final res = await apiService.putRequest(
                                '/admissions/${widget.admissionId}',
                                data: {
                                  'paymentType': 'INSTALLMENT',
                                  'installments': instData,
                                },
                              );
                              if (res.statusCode == 200) {
                                _showSuccessDialogWithMessage('Installment plan saved successfully!');
                                _loadDetails();
                              } else {
                                String msg = res.data?['message'] ?? 'Failed to save installments';
                                _showErrorDialog(msg);
                              }
                            } catch (e) {
                              _showErrorDialog(e.toString());
                            } finally {
                              setState(() {
                                _isLoading = false;
                              });
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      disabledBackgroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Save Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _refundAdmission(double maxRefundable) async {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    final noteController = TextEditingController();
    String refundMode = 'CASH';
    final List<String> modes = ['CASH', 'UPI', 'CARD', 'ONLINE', 'CHEQUE', 'BANK_TRANSFER'];

    String getModeLabel(String mode) {
      switch (mode) {
        case 'CASH':
          return '💵 Cash';
        case 'UPI':
          return '📱 UPI';
        case 'CARD':
          return '💳 Card';
        case 'ONLINE':
          return '🏦 Online Transfer';
        case 'CHEQUE':
          return '📋 Cheque';
        case 'BANK_TRANSFER':
          return '🏛️ Bank Transfer';
        default:
          return mode;
      }
    }

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Refund Admission',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.undo, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Refund Admission', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Process global refund', style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                content: Container(
                  width: double.maxFinite,
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Max Refundable:', style: TextStyle(color: Colors.orangeAccent, fontSize: 13)),
                              Text('₹${maxRefundable.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Refund Amount (₹) *',
                            labelStyle: TextStyle(color: Colors.blueGrey),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: refundMode,
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Refund Mode *',
                            labelStyle: TextStyle(color: Colors.blueGrey),
                          ),
                          items: modes.map((m) {
                            return DropdownMenuItem(
                              value: m,
                              child: Text(getModeLabel(m)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                refundMode = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: reasonController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Reason for Refund *',
                            labelStyle: TextStyle(color: Colors.blueGrey),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: noteController,
                          maxLines: 2,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Note (Optional)',
                            labelStyle: TextStyle(color: Colors.blueGrey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountController.text) ?? 0.0;
                      final reason = reasonController.text.trim();
                      if (amount <= 0 || amount > maxRefundable) {
                        _showErrorDialog('Please enter a valid refund amount (Max: ₹${maxRefundable.toStringAsFixed(0)})');
                        return;
                      }
                      if (reason.isEmpty) {
                        _showErrorDialog('Please enter a reason for the refund.');
                        return;
                      }

                      final successfulPayments = _payments.where((p) {
                        if (p['type'] == 'refund') return false;
                        final status = (p['status'] ?? '').toString().toLowerCase();
                        return status != 'voided';
                      }).toList();

                      if (successfulPayments.isEmpty) {
                        _showErrorDialog('No successful payments found to refund.');
                        return;
                      }

                      successfulPayments.sort((a, b) {
                        final dateA = DateTime.parse(a['createdAt'] ?? a['paymentDate'] ?? DateTime.now().toString());
                        final dateB = DateTime.parse(b['createdAt'] ?? b['paymentDate'] ?? DateTime.now().toString());
                        return dateB.compareTo(dateA);
                      });

                      final originalPaymentId = successfulPayments.first['_id'] ?? successfulPayments.first['id'];

                      Navigator.pop(context);
                      setState(() {
                        _isLoading = true;
                      });

                      try {
                        final apiService = Provider.of<ApiService>(context, listen: false);
                        final res = await apiService.postRequest(
                          '/payments/$originalPaymentId/refund',
                          data: {
                            'amount': amount,
                            'reason': reason,
                            'refundMode': refundMode,
                            'note': noteController.text.trim().isNotEmpty ? noteController.text.trim() : 'Refund processed',
                          },
                        );

                        if (res.statusCode == 200 || res.statusCode == 201) {
                          _showSuccessDialogWithMessage('Refund processed successfully!');
                          _loadDetails();
                        } else {
                          String msg = res.data?['message'] ?? 'Failed to process refund';
                          _showErrorDialog(msg);
                        }
                      } catch (e) {
                        _showErrorDialog(e.toString());
                      } finally {
                        setState(() {
                          _isLoading = false;
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Process Refund', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _handleDropStudent() async {
    final reasonController = TextEditingController();
    bool clearDues = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: const Text('Drop Student', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: reasonController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Reason for dropping', labelStyle: TextStyle(color: Colors.blueGrey)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: clearDues,
                        activeColor: Colors.teal,
                        checkColor: Colors.white,
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              clearDues = val;
                            });
                          }
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'Clear remaining dues (write-off)',
                          style: TextStyle(color: Colors.blueGrey, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    setState(() {
                      _isLoading = true;
                    });
                    try {
                      final apiService = Provider.of<ApiService>(context, listen: false);
                      final res = await apiService.postRequest('/admissions/${widget.admissionId}/drop', data: {
                        'reason': reasonController.text.trim(),
                        'clearDues': clearDues,
                      });
                      if (res.statusCode == 200) {
                        _loadDetails();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student dropped successfully!'), backgroundColor: Colors.redAccent));
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to drop student: ${ApiService.getReadableError(e)}')));
                    } finally {
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  },
                  child: const Text('Drop'),
                )
              ],
            );
          }
        );
      },
    );
  }

  String _formatDateString(dynamic dateObj) {
    if (dateObj == null) return '';
    try {
      final date = DateTime.parse(dateObj.toString());
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateObj.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context);
    final isAdmin = apiService.userRole == 'admin';

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_detail == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: Text('Admission details not found.', style: TextStyle(color: Colors.blueGrey))),
      );
    }

    final totalFees = _detail!['totalFees'] ?? 0;
    final totalPaid = _detail!['totalPaid'] ?? 0;
    final pendingAmount = _detail!['remainingAmount'] ?? _detail!['pendingAmount'] ?? 0;
    final status = (_detail!['status'] ?? 'active').toString().toLowerCase();
    final installments = _detail!['installments'] as List<dynamic>? ?? [];

    final refunded = _payments
        .where((p) => p['type'] == 'refund' && p['status'] != 'VOIDED')
        .fold(0.0, (sum, p) => sum + (p['amount'] ?? 0));

    final upcoming = _detail!['upcomingInstallment'];
    final nextDueAmt = upcoming != null ? (upcoming['amount'] ?? 0) : 0;
    final nextDueDateRaw = upcoming != null ? upcoming['dueDate'] : null;
    final nextDueDateFormatted = nextDueDateRaw != null ? _formatDateString(nextDueDateRaw) : 'N/A';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(_detail!['name'] ?? 'Student Profile', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (status == 'active' && pendingAmount > 0)
                          ? () => _recordPayment(pendingAmount.toDouble())
                          : null,
                      icon: const Icon(Icons.payment, color: Colors.white, size: 16),
                      label: const Text('Record Fee Payment', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  if (status == 'active' && isAdmin) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _handleDropStudent,
                      icon: const Icon(Icons.person_off, color: Colors.white, size: 16),
                      label: const Text('Drop', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ]
                ],
              ),
              if (isAdmin) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (status == 'active') ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _setInstallmentPlan(totalFees - (_detail!['registrationAmount'] ?? 0)),
                          icon: const Icon(Icons.calendar_month, color: Colors.white, size: 16),
                          label: const Text('Set Installments', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                    Builder(
                      builder: (context) {
                        final paid = _payments.where((p) => p['type'] != 'refund' && p['status'] != 'VOIDED').fold(0.0, (sum, p) => sum + (p['amount'] ?? 0));
                        final refunded = _payments.where((p) => p['type'] == 'refund' && p['status'] != 'VOIDED').fold(0.0, (sum, p) => sum + (p['amount'] ?? 0));
                        final maxRefund = paid - refunded;
                        if (maxRefund > 0) {
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(left: (status == 'active') ? 8.0 : 0.0),
                              child: ElevatedButton.icon(
                                onPressed: () => _refundAdmission(maxRefund),
                                icon: const Icon(Icons.undo, color: Colors.white, size: 16),
                                label: const Text('Refund Admission', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade800,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      }
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Student summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('STUDENT & COURSE INFO', style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildInfoRow('Name', _detail!['name']),
                  _buildInfoRow('Course', _detail!['course']),
                  _buildInfoRow('Email', _detail!['email']),
                  _buildInfoRow('Mobile', _detail!['mobile']),
                  _buildInfoRow('Joining Date', _formatDateString(_detail!['admissionDate'] ?? _detail!['createdAt'])),
                  _buildInfoRow('Status', status[0].toUpperCase() + status.substring(1)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Financial Summary
            const Text(
              'FINANCIAL SUMMARY',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.1,
              children: [
                _buildSummaryCard('Total Fees', '₹$totalFees', Icons.receipt, const Color(0xFF818CF8)),
                _buildSummaryCard('Total Paid', '₹$totalPaid', Icons.check_circle_outline, const Color(0xFF34D399)),
                _buildSummaryCard('Refunded', '₹${refunded.toStringAsFixed(0)}', Icons.keyboard_return, const Color(0xFFF87171)),
                _buildSummaryCard('Remaining', '₹$pendingAmount', Icons.hourglass_empty, const Color(0xFFFBBF24)),
                _buildSummaryCard('Next Due', nextDueAmt > 0 ? '₹$nextDueAmt' : 'Paid', Icons.wallet, const Color(0xFF60A5FA)),
                _buildSummaryCard('Due Date', nextDueDateFormatted, Icons.calendar_month, const Color(0xFFC084FC)),
              ],
            ),
            const SizedBox(height: 20),

            // Installment Plan list
            if (installments.isNotEmpty) ...[
              const Text('INSTALLMENT SCHEDULES', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...installments.map((inst) {
                final status = inst['status'] ?? 'PENDING';
                Color instColor = Colors.orange;
                if (status == 'PAID') instColor = Colors.teal;
                if (status == 'OVERDUE') instColor = Colors.redAccent;

                return Card(
                  color: const Color(0xFF1E293B),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text('Amount: ₹${inst['amount']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text('Due Date: ${_formatDateString(inst['dueDate'])}', style: TextStyle(color: Colors.blueGrey.shade400)),
                    trailing: Chip(
                      label: Text(status, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      backgroundColor: instColor,
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],

            // Payments Ledger History
            if (_payments.isNotEmpty) ...[
              const Text('PAYMENTS LEDGER', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ..._payments.map((pay) {
                final id = pay['_id'];
                final payStatus = pay['status'] ?? 'ACTIVE';
                final payType = pay['type'] ?? 'REGISTRATION';
                final isVoided = payStatus == 'VOIDED';

                return Card(
                  color: const Color(0xFF1E293B),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Amount: ₹${pay['amount']} ($payType)', style: TextStyle(color: Colors.white, decoration: isVoided ? TextDecoration.lineThrough : null)),
                          subtitle: Text('Mode: ${pay['paymentMode']} | Date: ${_formatDateString(pay['paymentDate'] ?? pay['createdAt'])}', style: TextStyle(color: Colors.blueGrey.shade400)),
                          trailing: Chip(
                            label: Text(payStatus, style: const TextStyle(color: Colors.white, fontSize: 10)),
                            backgroundColor: payStatus == 'ACTIVE' || payStatus == 'success' ? Colors.green : Colors.grey,
                          ),
                        ),
                        if (isAdmin && !isVoided && payType != 'refund') ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () => _handleVoidPayment(id),
                                icon: const Icon(Icons.block, size: 14, color: Colors.redAccent),
                                label: const Text('Void', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () => _handleRefundPayment(id),
                                icon: const Icon(Icons.replay_circle_filled, size: 14, color: Colors.orangeAccent),
                                label: const Text('Refund', style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                              ),
                            ],
                          ),
                        ]
                      ],
                    ),
                  ),
                );
              }),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    final valStr = value?.toString() ?? 'N/A';
    final isMobile = label.toLowerCase() == 'mobile' && valStr != 'N/A';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.blueGrey, fontSize: 14)),
          const Spacer(),
          Text(valStr, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          if (isMobile) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _makeCall(valStr),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                child: const Icon(Icons.phone, color: Colors.white, size: 14),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _sendWhatsApp(valStr),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Color(0xFF25D366), shape: BoxShape.circle),
                child: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.blueGrey, fontSize: 8, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class InstallmentRowData {
  final TextEditingController amountController;
  DateTime? dueDate;

  InstallmentRowData({required double? amount, required this.dueDate})
      : amountController = TextEditingController(text: amount != null ? amount.toStringAsFixed(0) : '');

  void dispose() {
    amountController.dispose();
  }
}

class ConvertAdmissionScreen extends StatefulWidget {
  final String enquiryId;
  final String studentName;
  final String studentMobile;
  final String studentEmail;
  final String course;

  const ConvertAdmissionScreen({
    super.key,
    required this.enquiryId,
    required this.studentName,
    required this.studentMobile,
    required this.studentEmail,
    required this.course,
  });

  @override
  State<ConvertAdmissionScreen> createState() => _ConvertAdmissionScreenState();
}

class _ConvertAdmissionScreenState extends State<ConvertAdmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _totalFeesController = TextEditingController();
  final _regAmountController = TextEditingController();

  bool _isLoading = false;

  String _paymentType = 'ONE_TIME';
  String _paymentMode = 'CASH';
  DateTime _initialPaymentDate = DateTime.now();
  DateTime? _pendingDueDate;
  final List<InstallmentRowData> _installmentRows = [];
  final List<String> _paymentModes = ['CASH', 'UPI', 'CARD', 'BANK_TRANSFER'];

  @override
  void initState() {
    super.initState();
    _totalFeesController.addListener(_onAmountChanged);
    _regAmountController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _totalFeesController.removeListener(_onAmountChanged);
    _regAmountController.removeListener(_onAmountChanged);
    _totalFeesController.dispose();
    _regAmountController.dispose();

    for (var row in _installmentRows) {
      row.dispose();
    }
    super.dispose();
  }

  void _onAmountChanged() {
    setState(() {});
  }

  double get _totalFees {
    return double.tryParse(_totalFeesController.text) ?? 0.0;
  }

  double get _initialPayment {
    return double.tryParse(_regAmountController.text) ?? 0.0;
  }

  double get _remainingAmount {
    double total = _totalFees;
    double initial = _initialPayment;
    return (total - initial).clamp(0.0, double.infinity);
  }

  double get _installmentsSum {
    double sum = 0.0;
    for (var row in _installmentRows) {
      sum += double.tryParse(row.amountController.text) ?? 0.0;
    }
    return sum;
  }

  void _addInstallmentRow() {
    final row = InstallmentRowData(amount: null, dueDate: null);
    row.amountController.addListener(_onAmountChanged);
    setState(() {
      _installmentRows.add(row);
    });
  }

  void _removeInstallmentRow(int index) {
    setState(() {
      _installmentRows[index].amountController.removeListener(_onAmountChanged);
      _installmentRows[index].dispose();
      _installmentRows.removeAt(index);
    });
  }

  String _getPaymentModeLabel(String mode) {
    switch (mode) {
      case 'CASH':
        return '💵 Cash';
      case 'UPI':
        return '📱 UPI';
      case 'CARD':
        return '💳 Card';
      case 'BANK_TRANSFER':
        return '🏦 Bank Transfer';
      default:
        return mode;
    }
  }

  Future<void> _selectDate(BuildContext context, DateTime initialDate, DateTime? firstDate, DateTime? lastDate, Function(DateTime) onPicked) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.teal,
              onPrimary: Colors.white,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onPicked(picked);
    }
  }

  void _showSuccessDialog() {
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
                  'Admission Created!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'The lead "${widget.studentName}" has been successfully converted and registered.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.blueGrey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Close screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: const Text(
                    'Done',
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
                  'Setup Failed',
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
                    Navigator.pop(context); // Close dialog
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

  Future<void> _handleConvert() async {
    if (!_formKey.currentState!.validate()) return;

    final total = _totalFees;
    final initial = _initialPayment;
    final remaining = _remainingAmount;

    if (total <= 0) {
      _showErrorDialog('Total fees must be greater than 0');
      return;
    }

    if (initial < 0) {
      _showErrorDialog('Registration amount cannot be negative');
      return;
    }

    if (initial > total) {
      _showErrorDialog('Registration amount cannot exceed total fees');
      return;
    }

    if (_paymentType == 'ONE_TIME') {
      if (remaining > 0 && _pendingDueDate == null) {
        _showErrorDialog('Please select a due date for the pending balance');
        return;
      }
    } else {
      if (_installmentRows.isEmpty) {
        _showErrorDialog('Please add at least one installment row');
        return;
      }

      double instSum = 0.0;
      for (var row in _installmentRows) {
        final amt = double.tryParse(row.amountController.text) ?? 0.0;
        if (amt <= 0) {
          _showErrorDialog('Installment amount must be greater than 0');
          return;
        }
        if (row.dueDate == null) {
          _showErrorDialog('Please set a due date for all installments');
          return;
        }
        instSum += amt;
      }

      if ((instSum - remaining).abs() > 0.01) {
        _showErrorDialog(
          'Total of installments (₹${instSum.toStringAsFixed(0)}) '
          'must match the remaining amount (₹${remaining.toStringAsFixed(0)}) exactly.'
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final DateFormat df = DateFormat('yyyy-MM-dd');

      final Map<String, dynamic> data = {
        'enquiryId': widget.enquiryId,
        'name': widget.studentName,
        'mobile': widget.studentMobile,
        'email': widget.studentEmail,
        'studentName': widget.studentName,
        'studentMobile': widget.studentMobile,
        'studentEmail': widget.studentEmail,
        'course': widget.course,
        'totalFees': total,
        'registrationAmount': initial,
        'paymentType': _paymentType,
      };



      if (_paymentType == 'ONE_TIME') {
        data['paymentMethod'] = _paymentMode;
        data['paymentDate'] = df.format(_initialPaymentDate);
        if (_pendingDueDate != null) {
          data['fullPaymentDueDate'] = df.format(_pendingDueDate!);
        }
      } else {
        data['installments'] = _installmentRows.map((row) {
          return {
            'amount': double.parse(row.amountController.text),
            'dueDate': df.format(row.dueDate!),
            'note': 'Installment payment',
          };
        }).toList();

        if (initial > 0) {
          data['initialPayment'] = initial;
          data['initialPaymentMode'] = _paymentMode;
          data['paymentDate'] = df.format(_initialPaymentDate);
        }
      }

      final res = await apiService.postRequest('/admissions', data: data);

      if (res.statusCode == 201 || res.statusCode == 200) {
        _showSuccessDialog();
      } else {
        String msg = res.data?['message'] ?? 'An unknown error occurred';
        _showErrorDialog(msg);
      }
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Convert to Admission', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Convert lead "${widget.studentName}" into a registered admission.', style: const TextStyle(color: Colors.blueGrey)),
              const SizedBox(height: 24),

              DropdownButtonFormField<String>(
                value: _paymentType,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Payment Type',
                  labelStyle: TextStyle(color: Colors.blueGrey),
                ),
                items: const [
                  DropdownMenuItem(value: 'ONE_TIME', child: Text('Full Payment')),
                  DropdownMenuItem(value: 'INSTALLMENT', child: Text('Installment Payment')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _paymentType = val;
                      if (_paymentType == 'INSTALLMENT' && _installmentRows.isEmpty) {
                        _addInstallmentRow();
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _totalFeesController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Total Fees (₹) *',
                  labelStyle: TextStyle(color: Colors.blueGrey),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Please enter total fees';
                  final amt = double.tryParse(val);
                  if (amt == null || amt <= 0) return 'Total fees must be greater than 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _regAmountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Initial Payment / Registration Paid (₹) *',
                  labelStyle: TextStyle(color: Colors.blueGrey),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Please enter initial payment';
                  final amt = double.tryParse(val);
                  if (amt == null || amt < 0) return 'Initial payment cannot be negative';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(
                        context,
                        _initialPaymentDate,
                        DateTime(2000),
                        DateTime(2100),
                        (date) {
                          setState(() {
                            _initialPaymentDate = date;
                          });
                        },
                      ),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Payment Date',
                          labelStyle: TextStyle(color: Colors.blueGrey),
                        ),
                        child: Text(
                          DateFormat('dd MMM yyyy').format(_initialPaymentDate),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _paymentMode,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Payment Mode',
                        labelStyle: TextStyle(color: Colors.blueGrey),
                      ),
                      items: _paymentModes.map((mode) {
                        return DropdownMenuItem(
                          value: mode,
                          child: Text(_getPaymentModeLabel(mode)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _paymentMode = val;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  border: Border.all(color: Colors.teal.withOpacity(0.3), width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Remaining Balance:',
                      style: TextStyle(color: Colors.tealAccent, fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '₹${_remainingAmount.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              if (_paymentType == 'ONE_TIME' && _remainingAmount > 0) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.05),
                    border: Border.all(color: Colors.amber.withOpacity(0.2), width: 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Pending Balance Details',
                        style: TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Pending Amount (₹)',
                                labelStyle: TextStyle(color: Colors.blueGrey),
                              ),
                              child: Text(
                                '₹${_remainingAmount.toStringAsFixed(0)}',
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(
                                context,
                                _pendingDueDate ?? DateTime.now().add(const Duration(days: 30)),
                                DateTime.now(),
                                DateTime(2100),
                                (date) {
                                  setState(() {
                                    _pendingDueDate = date;
                                  });
                                },
                              ),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Due Date *',
                                  labelStyle: TextStyle(color: Colors.blueGrey),
                                ),
                                child: Text(
                                  _pendingDueDate != null
                                      ? DateFormat('dd MMM yyyy').format(_pendingDueDate!)
                                      : 'Select Date',
                                  style: TextStyle(
                                    color: _pendingDueDate != null ? Colors.white : Colors.amber,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              if (_paymentType == 'INSTALLMENT') ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Future Installments',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      onPressed: _addInstallmentRow,
                      icon: const Icon(Icons.add, color: Colors.teal),
                      label: const Text('Add Row', style: TextStyle(color: Colors.teal)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _installmentRows.length,
                  itemBuilder: (context, index) {
                    final row = _installmentRows[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: row.amountController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Amount (₹) *',
                                labelStyle: const TextStyle(color: Colors.blueGrey),
                                hintText: 'Inst. ${index + 1}',
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) return 'Required';
                                final amt = double.tryParse(val);
                                if (amt == null || amt <= 0) return 'Invalid';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(
                                context,
                                row.dueDate ?? DateTime.now().add(Duration(days: 30 * (index + 1))),
                                _initialPaymentDate,
                                DateTime(2100),
                                (date) {
                                  setState(() {
                                    row.dueDate = date;
                                  });
                                },
                              ),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Due Date *',
                                  labelStyle: TextStyle(color: Colors.blueGrey),
                                ),
                                child: Text(
                                  row.dueDate != null
                                      ? DateFormat('dd MMM yyyy').format(row.dueDate!)
                                      : 'Select Date',
                                  style: TextStyle(
                                    color: row.dueDate != null ? Colors.white : Colors.tealAccent,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                            onPressed: () => _removeInstallmentRow(index),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                if (_installmentRows.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final sum = _installmentsSum;
                      final remaining = _remainingAmount;
                      final difference = remaining - sum;
                      if (difference.abs() > 0.01) {
                        return Text(
                          difference > 0
                              ? 'Installments total (₹${sum.toStringAsFixed(0)}) is ₹${difference.toStringAsFixed(0)} LESS than remaining balance.'
                              : 'Installments total (₹${sum.toStringAsFixed(0)}) EXCEEDS remaining balance by ₹${difference.abs().toStringAsFixed(0)}.',
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
                        );
                      } else {
                        return Row(
                          children: const [
                            Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Installments sum matches remaining balance exactly!',
                              style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ],
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleConvert,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Submit Admission', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
