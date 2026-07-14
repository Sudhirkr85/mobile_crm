import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'admission_screens.dart';

class EnquiryListScreen extends StatefulWidget {
  const EnquiryListScreen({super.key});

  @override
  State<EnquiryListScreen> createState() => _EnquiryListScreenState();
}

class _EnquiryListScreenState extends State<EnquiryListScreen> {
  bool _isLoading = false;
  bool _isLoadMoreRunning = false;
  List<dynamic> _enquiries = [];
  String _searchQuery = '';
  String _statusFilter = 'all';

  // Advanced filters
  String _filterType = 'all';
  bool _followUpToday = false;
  bool _followUpOverdue = false;
  String? _assignedTo; // null, 'me', 'any'
  DateTime? _dateFrom;
  DateTime? _dateTo;

  int _currentPage = 1;
  int _totalPages = 1;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadEnquiries(isFirstLoad: true);
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

  Future<void> _sendWhatsApp(String mobile, String name, String course) async {
    final cleanMobile = mobile.replaceAll(RegExp(r'\D'), '');
    final formattedMobile = cleanMobile.length == 10 ? '91$cleanMobile' : cleanMobile;
    final apiService = Provider.of<ApiService>(context, listen: false);
    final counselorName = apiService.userName ?? 'representative';

    final message = "Hi $name,\n\n"
        "This is $counselorName from SSSAM Academy, Gurgaon.\n\n"
        "Regarding your $course enquiry, please let me know a convenient time to connect.";

    final encodedMessage = Uri.encodeComponent(message);
    final Uri uri = Uri.parse("https://wa.me/$formattedMobile?text=$encodedMessage");
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
        _loadEnquiries(isFirstLoad: false);
      }
    }
  }

  Future<void> _loadEnquiries({required bool isFirstLoad}) async {
    if (isFirstLoad) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _enquiries = [];
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
      if (_statusFilter != 'all') {
        queryParams['status'] = _statusFilter;
      }
      if (_filterType != 'all') {
        queryParams['filterType'] = _filterType;
      }
      if (_followUpToday) {
        queryParams['followUpToday'] = true;
      }
      if (_followUpOverdue) {
        queryParams['followUpOverdue'] = true;
      }
      if (_assignedTo != null) {
        queryParams['assignedTo'] = _assignedTo;
      }
      if (_dateFrom != null) {
        queryParams['dateFrom'] = DateFormat('yyyy-MM-dd').format(_dateFrom!);
      }
      if (_dateTo != null) {
        queryParams['dateTo'] = DateFormat('yyyy-MM-dd').format(_dateTo!);
      }
      if (_searchQuery.isNotEmpty) {
        queryParams['search'] = _searchQuery;
      }

      final res = await apiService.getRequest('/enquiries', queryParameters: queryParams);
      if (res.statusCode == 200 && res.data != null) {
        final items = res.data['data'] ?? [];
        final pagObj = res.data['pagination'] ?? {};

        setState(() {
          _enquiries.addAll(items);
          _totalPages = pagObj['totalPages'] ?? 1;
          if (!isFirstLoad) {
            _currentPage++;
          } else {
            _currentPage = 2; // Setup for next page load
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load enquiries: ${ApiService.getReadableError(e)}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadMoreRunning = false;
      });
    }
  }

  bool get _hasActiveFilters =>
      _filterType != 'all' ||
      _statusFilter != 'all' ||
      _followUpToday ||
      _followUpOverdue ||
      _assignedTo != null ||
      _dateFrom != null ||
      _dateTo != null;

  void _resetFilters() {
    setState(() {
      _statusFilter = 'all';
      _filterType = 'all';
      _followUpToday = false;
      _followUpOverdue = false;
      _assignedTo = null;
      _dateFrom = null;
      _dateTo = null;
    });
    _loadEnquiries(isFirstLoad: true);
  }

  void _openFilterSheet() {
    // Local mutable copies
    String localStatus = _statusFilter;
    String localFilterType = _filterType;
    bool localFollowUpToday = _followUpToday;
    bool localFollowUpOverdue = _followUpOverdue;
    String? localAssignedTo = _assignedTo;
    DateTime? localDateFrom = _dateFrom;
    DateTime? localDateTo = _dateTo;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocal) {
          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            maxChildSize: 0.92,
            minChildSize: 0.5,
            expand: false,
            builder: (_, scrollCtrl) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.all(20),
                child: ListView(
                  controller: scrollCtrl,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Filter Leads', style: TextStyle(color: Color(0xFF1E293B), fontSize: 18, fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () {
                            setLocal(() {
                              localStatus = 'all';
                              localFilterType = 'all';
                              localFollowUpToday = false;
                              localFollowUpOverdue = false;
                              localAssignedTo = null;
                              localDateFrom = null;
                              localDateTo = null;
                            });
                          },
                          child: const Text('Reset', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.black12),
                    const SizedBox(height: 12),

                    // Assigned To
                    const Text('Assigned To', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        {'label': 'Any', 'value': null},
                        {'label': 'Me', 'value': 'me'},
                        {'label': 'Unassigned', 'value': 'null'},
                      ].map((a) {
                        final isSelected = localAssignedTo == a['value'];
                        return ChoiceChip(
                          selected: isSelected,
                          label: Text(
                            a['label'] as String,
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF64748B),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          backgroundColor: const Color(0xFFF8FAFC),
                          selectedColor: Colors.purple,
                          side: BorderSide(color: isSelected ? Colors.purple : Colors.black12),
                          onSelected: (_) => setLocal(() => localAssignedTo = a['value'] as String?),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Date Range
                    const Text('Date Range (Enquiry Created)', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)),
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
                                builder: (ctx, child) => Theme(
                                  data: ThemeData.light(),
                                  child: child!,
                                ),
                              );
                              if (d != null) setLocal(() => localDateFrom = d);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: localDateFrom != null ? Colors.blueAccent : Colors.black12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, color: Colors.blueGrey, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    localDateFrom != null ? DateFormat('dd MMM yy').format(localDateFrom!) : 'From',
                                    style: TextStyle(
                                      color: localDateFrom != null ? const Color(0xFF1E293B) : Colors.blueGrey,
                                      fontSize: 12,
                                      fontWeight: localDateFrom != null ? FontWeight.bold : FontWeight.normal,
                                    ),
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
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                                builder: (ctx, child) => Theme(
                                  data: ThemeData.light(),
                                  child: child!,
                                ),
                              );
                              if (d != null) setLocal(() => localDateTo = d);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: localDateTo != null ? Colors.blueAccent : Colors.black12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, color: Colors.blueGrey, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    localDateTo != null ? DateFormat('dd MMM yy').format(localDateTo!) : 'To',
                                    style: TextStyle(
                                      color: localDateTo != null ? const Color(0xFF1E293B) : Colors.blueGrey,
                                      fontSize: 12,
                                      fontWeight: localDateTo != null ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Apply Button
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
                            _statusFilter = localStatus;
                            _filterType = localFilterType;
                            _followUpToday = localFollowUpToday;
                            _followUpOverdue = localFollowUpOverdue;
                            _assignedTo = localAssignedTo;
                            _dateFrom = localDateFrom;
                            _dateTo = localDateTo;
                          });
                          _loadEnquiries(isFirstLoad: true);
                        },
                        child: const Text('Apply Filters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        });
      },
    );
  }

  void _openAddEnquiryDialog() {
    final nameController = TextEditingController();
    final mobileController = TextEditingController();
    final emailController = TextEditingController();
    final customCourseController = TextEditingController();
    final referenceNameController = TextEditingController();
    final referenceContactController = TextEditingController();
    final walkInBroughtByController = TextEditingController();

    final addFormKey = GlobalKey<FormState>();

    String? selectedCourse;
    String? selectedSource;
    bool showCustomCourse = false;
    bool showReferralFields = false;
    bool showWalkInField = false;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Theme(
          data: ThemeData(
            brightness: Brightness.dark,
            primaryColor: Colors.blueAccent,
            inputDecorationTheme: const InputDecorationTheme(
              filled: true,
              fillColor: Color(0xFF374151),
            ),
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                backgroundColor: const Color(0xFF1F2937),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.person_add_alt_1, color: Colors.blueAccent),
                  SizedBox(width: 10),
                  Text('Add New Lead', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Form(
                    key: addFormKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Name *',
                            labelStyle: TextStyle(color: Colors.blueGrey),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueGrey)),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Name is required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: mobileController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            MobileNumberFormatter(),
                          ],
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Mobile *',
                            hintText: 'XXXXX XXXXX',
                            hintStyle: TextStyle(color: Colors.white24),
                            labelStyle: TextStyle(color: Colors.blueGrey),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueGrey)),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Mobile is required';
                            final clean = val.replaceAll(' ', '');
                            if (clean.length != 10) return 'Enter exactly 10 digits';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Email (Optional)',
                            labelStyle: TextStyle(color: Colors.blueGrey),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueGrey)),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedCourse,
                          dropdownColor: const Color(0xFF1F2937),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Course Interested *',
                            labelStyle: TextStyle(color: Colors.blueGrey),
                            filled: true,
                            fillColor: Color(0xFF374151),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueGrey)),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Data Analytics', child: Text('Data Analytics', style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'Data Science', child: Text('Data Science', style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'Basic Computer', child: Text('Basic Computer', style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'Python Full Stack', child: Text('Python Full Stack', style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'Java Full Stack', child: Text('Java Full Stack', style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'MERN Stack', child: Text('MERN Stack', style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'Ethical Hacking', child: Text('Ethical Hacking', style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'Web Development', child: Text('Web Development', style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'Digital Marketing', child: Text('Digital Marketing', style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'Other', child: Text('Other', style: TextStyle(color: Colors.white))),
                          ],
                          onChanged: (val) {
                            setState(() {
                              selectedCourse = val;
                              showCustomCourse = val == 'Other';
                            });
                          },
                          validator: (val) => val == null || val.isEmpty ? 'Course is required' : null,
                        ),
                        if (showCustomCourse) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: customCourseController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Custom Course Name *',
                              labelStyle: TextStyle(color: Colors.blueGrey),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueGrey)),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                            ),
                            validator: (val) => showCustomCourse && (val == null || val.trim().isEmpty) ? 'Custom Course name is required' : null,
                          ),
                        ],
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedSource,
                          dropdownColor: const Color(0xFF1F2937),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Source *',
                            labelStyle: TextStyle(color: Colors.blueGrey),
                            filled: true,
                            fillColor: Color(0xFF374151),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueGrey)),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'walk_in', child: Text('Walk In', style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'phone_call', child: Text('Phone Call', style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'website', child: Text('Website', style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'referral', child: Text('Referral', style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'social_media', child: Text('Social Media', style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'advertisement', child: Text('Advertisement', style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'other', child: Text('Other', style: TextStyle(color: Colors.white))),
                          ],
                          onChanged: (val) {
                            setState(() {
                              selectedSource = val;
                              showReferralFields = val == 'referral';
                              showWalkInField = val == 'walk_in';
                            });
                          },
                          validator: (val) => val == null || val.isEmpty ? 'Source is required' : null,
                        ),
                        if (showReferralFields) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: referenceNameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Reference Name *',
                              labelStyle: TextStyle(color: Colors.blueGrey),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueGrey)),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                            ),
                            validator: (val) => showReferralFields && (val == null || val.trim().isEmpty) ? 'Reference Name is required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: referenceContactController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Reference Contact *',
                              labelStyle: TextStyle(color: Colors.blueGrey),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueGrey)),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                            ),
                            validator: (val) => showReferralFields && (val == null || val.trim().isEmpty) ? 'Reference Contact is required' : null,
                          ),
                        ],
                        if (showWalkInField) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: walkInBroughtByController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Brought By * (Who brought this student)',
                              labelStyle: TextStyle(color: Colors.blueGrey),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueGrey)),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                            ),
                            validator: (val) => showWalkInField && (val == null || val.trim().isEmpty) ? 'Brought By is required' : null,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!addFormKey.currentState!.validate()) {
                            return;
                          }

                          setState(() {
                            isSubmitting = true;
                          });

                          final finalCourse = selectedCourse == 'Other' ? customCourseController.text.trim() : selectedCourse;
                          final cleanMobile = mobileController.text.replaceAll(' ', '');

                          final dataPayload = <String, dynamic>{
                            'name': nameController.text.trim(),
                            'mobile': cleanMobile,
                            'email': emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                            'course': finalCourse,
                            'source': selectedSource,
                            'notes': '',
                          };

                          if (selectedSource == 'referral') {
                            dataPayload['referenceName'] = referenceNameController.text.trim();
                            dataPayload['referenceContact'] = referenceContactController.text.trim();
                          } else if (selectedSource == 'walk_in') {
                            dataPayload['walkInBroughtBy'] = walkInBroughtByController.text.trim();
                          }

                          try {
                            final apiService = Provider.of<ApiService>(context, listen: false);
                            final res = await apiService.postRequest('/enquiries', data: dataPayload);
                            if (res.statusCode == 201 || res.statusCode == 200) {
                              Navigator.pop(context);
                              _loadEnquiries(isFirstLoad: true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Lead added successfully'), backgroundColor: Colors.green),
                              );
                            }
                          } catch (e) {
                            setState(() {
                              isSubmitting = false;
                            });
                            if (e is DioException && e.response?.statusCode == 409) {
                              final errorData = e.response?.data;
                              final existing = errorData?['errors']?['existingEnquiry'];
                              Navigator.pop(context);
                              if (existing != null) {
                                _showDuplicateDialog(existing, nameController.text.trim(), cleanMobile);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(errorData?['message'] ?? 'Student already registered with this mobile number.'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            } else {
                              final errMsg = e is DioException
                                  ? (e.response?.data?['message'] as String? ?? e.message ?? 'Unknown error')
                                  : e.toString();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to add lead: $errMsg'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              ],
            );
          },
        ),
      );
    },
  );
}

  void _showDuplicateDialog(Map<String, dynamic> existing, String newName, String newMobile) {
    final status = existing['status']?.toString();
    Color statusColor = Colors.blueGrey;
    String statusLabel = status ?? 'Unknown';
    if (status == 'CONTACTED') { statusColor = Colors.blue; statusLabel = 'Contacted'; }
    else if (status == 'INTERESTED') { statusColor = Colors.green; statusLabel = 'Interested'; }
    else if (status == 'NOT_INTERESTED') { statusColor = Colors.red; statusLabel = 'Not Interested'; }
    else if (status == 'ADMITTED') { statusColor = Colors.teal; statusLabel = 'Admitted'; }
    else if (status == null) { statusLabel = 'New Lead'; }

    String? followUpText;
    if (existing['followUpDate'] != null) {
      try {
        final d = DateTime.parse(existing['followUpDate'].toString());
        followUpText = DateFormat('dd MMM yyyy').format(d);
      } catch (_) {
        followUpText = existing['followUpDate'].toString();
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.withOpacity(0.4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(bottom: BorderSide(color: Colors.orange.withOpacity(0.2))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_search, color: Colors.orange, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Student Already Registered', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('This mobile number already exists', style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),

              // Existing student details
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('EXISTING RECORD', style: TextStyle(color: Colors.blueGrey, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        children: [
                          _dupRow(Icons.person, 'Name', existing['name'] ?? 'N/A'),
                          _dupRow(Icons.phone, 'Mobile', existing['mobile'] ?? 'N/A'),
                          _dupRow(Icons.book, 'Course', existing['course'] ?? 'Not set'),
                          _dupRow(Icons.person_outline, 'Assigned To', existing['assignedTo']?['name'] ?? 'Unassigned'),
                          if (followUpText != null)
                            _dupRow(Icons.calendar_today, 'Follow-up', followUpText),
                          // Status chip
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.circle, color: Colors.blueGrey, size: 14),
                                const SizedBox(width: 8),
                                const Text('Status', style: TextStyle(color: Colors.blueGrey, fontSize: 13)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: statusColor.withOpacity(0.4)),
                                  ),
                                  child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Action buttons
                    const Text('WHAT WOULD YOU LIKE TO DO?', style: TextStyle(color: Colors.blueGrey, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                    const SizedBox(height: 10),

                    // Update Existing
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.edit, color: Colors.white, size: 16),
                        label: const Text('View / Update Existing Lead', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          final existingId = existing['_id']?.toString();
                          if (existingId != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => EnquiryDetailScreen(enquiryId: existingId)),
                            ).then((_) => _loadEnquiries(isFirstLoad: true));
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 8),

                    // New Course Enquiry
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 16),
                        label: const Text('Add Enquiry for New Course', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          // Reopen add dialog pre-filled with same name/mobile but different course
                          _openAddEnquiryDialogPrefilled(
                            name: existing['name'] ?? newName,
                            mobile: existing['mobile'] ?? newMobile,
                            email: existing['email'] ?? '',
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Cancel
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel', style: TextStyle(color: Colors.blueGrey)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dupRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueGrey, size: 14),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.blueGrey, fontSize: 13)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Color(0xFF1E293B), fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _openAddEnquiryDialogPrefilled({String name = '', String mobile = '', String email = ''}) {
    final nameController = TextEditingController(text: name);
    final mobileController = TextEditingController(text: mobile);
    final emailController = TextEditingController(text: email);
    final customCourseController = TextEditingController();
    final referenceNameController = TextEditingController();
    final referenceContactController = TextEditingController();
    final walkInBroughtByController = TextEditingController();
    final notesController = TextEditingController();

    String? selectedCourse;
    String? selectedSource;
    bool showCustomCourse = false;
    bool showReferralFields = false;
    bool showWalkInField = false;

    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Theme(
          data: ThemeData(
            brightness: Brightness.dark,
            primaryColor: Colors.teal,
            inputDecorationTheme: const InputDecorationTheme(
              filled: true,
              fillColor: Color(0xFF374151),
            ),
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                backgroundColor: const Color(0xFF1F2937),
              title: Row(
                children: [
                  const Icon(Icons.add_circle, color: Colors.teal, size: 20),
                  const SizedBox(width: 8),
                  Text('New Course Enquiry', style: const TextStyle(color: Colors.white)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.teal.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.teal, size: 14),
                          SizedBox(width: 6),
                          Expanded(child: Text('Name & mobile pre-filled. Select a different course.', style: TextStyle(color: Colors.teal, fontSize: 12))),
                        ],
                      ),
                    ),
                    TextField(controller: nameController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Name *', labelStyle: TextStyle(color: Colors.blueGrey))),
                    TextField(controller: mobileController, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Mobile *', labelStyle: TextStyle(color: Colors.blueGrey))),
                    TextField(controller: emailController, keyboardType: TextInputType.emailAddress, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Email', labelStyle: TextStyle(color: Colors.blueGrey))),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedCourse,
                      dropdownColor: const Color(0xFF1F2937),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Course *', labelStyle: TextStyle(color: Colors.blueGrey), filled: true, fillColor: Color(0xFF374151)),
                      items: const [
                        DropdownMenuItem(value: 'Data Analytics', child: Text('Data Analytics', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 'Data Science', child: Text('Data Science', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 'Basic Computer', child: Text('Basic Computer', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 'Python Full Stack', child: Text('Python Full Stack', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 'Java Full Stack', child: Text('Java Full Stack', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 'MERN Stack', child: Text('MERN Stack', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 'Ethical Hacking', child: Text('Ethical Hacking', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 'Web Development', child: Text('Web Development', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 'Digital Marketing', child: Text('Digital Marketing', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 'Other', child: Text('Other', style: TextStyle(color: Colors.white))),
                      ],
                      onChanged: (val) => setState(() { selectedCourse = val; showCustomCourse = val == 'Other'; }),
                    ),
                    if (showCustomCourse)
                      TextField(controller: customCourseController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Specify Course *', labelStyle: TextStyle(color: Colors.blueGrey))),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final finalCourse = selectedCourse == 'Other' ? customCourseController.text.trim() : selectedCourse;
                          if (nameController.text.trim().isEmpty || mobileController.text.trim().isEmpty || (finalCourse ?? '').isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name, mobile and course are required'), backgroundColor: Colors.orange));
                            return;
                          }
                          setState(() {
                            isSubmitting = true;
                          });
                          try {
                            final apiService = Provider.of<ApiService>(context, listen: false);
                            final emailVal = emailController.text.trim();
                            final res = await apiService.postRequest('/enquiries', data: {
                              'name': nameController.text.trim(),
                              'mobile': mobileController.text.trim(),
                              if (emailVal.isNotEmpty) 'email': emailVal,
                              'course': finalCourse,
                              'source': selectedSource,
                            });
                            if (res.statusCode == 201 || res.statusCode == 200) {
                              Navigator.pop(context);
                              _loadEnquiries(isFirstLoad: true);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ New course enquiry added'), backgroundColor: Colors.green));
                            }
                          } catch (e) {
                            setState(() {
                              isSubmitting = false;
                            });
                            final errMsg = ApiService.getReadableError(e);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $errMsg'), backgroundColor: Colors.redAccent));
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Enquiries & Leads', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1F2937),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddEnquiryDialog,
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Search & Filter header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search by name or mobile...',
                      hintStyle: const TextStyle(color: Colors.blueGrey),
                      prefixIcon: const Icon(Icons.search, color: Colors.blueGrey),
                      filled: true,
                      fillColor: const Color(0xFFFFFFFF),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                      _loadEnquiries(isFirstLoad: true);
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
                          color: _hasActiveFilters ? Colors.blueAccent : const Color(0xFFFFFFFF),
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
                        color: Colors.redAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                      ),
                      child: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Horizontal Quick Filters directly at the top
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  {'label': 'All', 'value': 'all', 'icon': Icons.list},
                  {'label': 'New', 'value': 'new', 'icon': Icons.fiber_new},
                  {'label': "Today's", 'value': 'today_followups', 'icon': Icons.today},
                  {'label': 'Pending', 'value': 'pending_followups', 'icon': Icons.pending_actions},
                  {'label': 'Upcoming', 'value': 'upcoming_followups', 'icon': Icons.upcoming},
                  {'label': 'Contacted', 'value': 'contacted', 'icon': Icons.phone_in_talk},
                  {'label': 'Not Interested', 'value': 'not_interested', 'icon': Icons.thumb_down_outlined},
                ].map((f) {
                  final isSelected = _filterType == f['value'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      selected: isSelected,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            f['icon'] as IconData,
                            size: 14,
                            color: isSelected ? Colors.white : Colors.blueGrey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            f['label'] as String,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.blueGrey,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: const Color(0xFF1F2937),
                      selectedColor: Colors.blueAccent,
                      side: BorderSide(
                        color: isSelected ? Colors.blueAccent : Colors.white12,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _filterType = f['value'] as String;
                          });
                          _loadEnquiries(isFirstLoad: true);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Active filter chips display
          if (_hasActiveFilters)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (_filterType != 'all')
                      _buildActiveFilterChip(_filterType.replaceAll('_', ' ').toUpperCase(), Colors.blueAccent),
                    if (_statusFilter != 'all')
                      _buildActiveFilterChip(_statusFilter, Colors.teal),
                    if (_followUpToday)
                      _buildActiveFilterChip("Today's Follow-ups", Colors.blue),
                    if (_followUpOverdue)
                      _buildActiveFilterChip('Overdue', Colors.redAccent),
                    if (_assignedTo != null)
                      _buildActiveFilterChip('Assigned: ${_assignedTo == 'me' ? 'Me' : 'Unassigned'}', Colors.purple),
                    if (_dateFrom != null)
                      _buildActiveFilterChip('From: ${DateFormat('dd MMM').format(_dateFrom!)}', Colors.orange),
                    if (_dateTo != null)
                      _buildActiveFilterChip('To: ${DateFormat('dd MMM').format(_dateTo!)}', Colors.orange),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 8),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _enquiries.isEmpty
                    ? const Center(child: Text('No leads found.', style: TextStyle(color: Colors.blueGrey)))
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _enquiries.length + (_isLoadMoreRunning ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _enquiries.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          }
                          final lead = _enquiries[index];
                          final status = lead['status'] ?? 'NEW';
                          Color statusColor = Colors.grey;
                          if (status == 'CONTACTED') statusColor = Colors.blue;
                          if (status == 'INTERESTED') statusColor = Colors.orange;
                          if (status == 'ADMITTED') statusColor = Colors.teal;
                          if (status == 'NOT_INTERESTED') statusColor = Colors.redAccent;

                           final mobile = lead['mobile'] ?? '';
                           final course = lead['course'] ?? 'General Enquiry';
                           final source = lead['source'] ?? lead['leadSource'] ?? 'Unknown';

                           return Card(
                             color: const Color(0xFFFFFFFF),
                             margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                             child: InkWell(
                               onTap: () => Navigator.push(
                                 context,
                                 MaterialPageRoute(builder: (_) => EnquiryDetailScreen(enquiryId: lead['_id'])),
                               ).then((_) => _loadEnquiries(isFirstLoad: true)),
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
                                             lead['name'] ?? 'No Name',
                                             style: const TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.bold),
                                           ),
                                         ),
                                         Container(
                                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                           decoration: BoxDecoration(
                                             color: statusColor.withOpacity(0.15),
                                             borderRadius: BorderRadius.circular(8),
                                             border: Border.all(color: statusColor.withOpacity(0.5)),
                                           ),
                                           child: Text(
                                             status,
                                             style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
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
                                       'Source: $source',
                                       style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
                                     ),
                                     const Divider(color: Colors.black12, height: 20),
                                     Row(
                                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                       children: [
                                         Text(
                                           mobile,
                                           style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
                                         ),
                                         if (mobile.isNotEmpty)
                                           Row(
                                             children: [
                                               IconButton(
                                                 icon: const Icon(Icons.phone, color: Colors.green, size: 18),
                                                 padding: EdgeInsets.zero,
                                                 constraints: const BoxConstraints(),
                                                 onPressed: () => _makeCall(mobile),
                                               ),
                                               const SizedBox(width: 16),
                                               IconButton(
                                                 icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF25D366), size: 18),
                                                 padding: EdgeInsets.zero,
                                                 constraints: const BoxConstraints(),
                                                 onPressed: () => _sendWhatsApp(mobile, lead['name'] ?? 'Student', course),
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

  Widget _buildActiveFilterChip(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class EnquiryDetailScreen extends StatefulWidget {
  final String enquiryId;
  const EnquiryDetailScreen({super.key, required this.enquiryId});

  @override
  State<EnquiryDetailScreen> createState() => _EnquiryDetailScreenState();
}

class _EnquiryDetailScreenState extends State<EnquiryDetailScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _detail;

  String _formatTimelineDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    final parsed = DateTime.tryParse(dateStr);
    if (parsed == null) return dateStr;
    // Format as e.g. "14 Jul, 10:09 AM"
    return DateFormat('d MMM, hh:mm a').format(parsed.toLocal());
  }

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
      final res = await apiService.getRequest('/enquiries/${widget.enquiryId}');
      if (res.statusCode == 200 && res.data != null) {
        setState(() {
          _detail = res.data['data']['enquiry'] ?? res.data['data'];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load lead details: ${ApiService.getReadableError(e)}')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
    final apiService = Provider.of<ApiService>(context, listen: false);
    final counselorName = apiService.userName ?? 'representative';

    final name = _detail?['name'] ?? 'Student';
    final course = _detail?['course'] ?? 'course';

    final message = "Hi $name,\n\n"
        "This is $counselorName from SSSAM Academy, Gurgaon.\n\n"
        "Regarding your $course enquiry, please let me know a convenient time to connect.";

    final encodedMessage = Uri.encodeComponent(message);
    final Uri uri = Uri.parse("https://wa.me/$formattedMobile?text=$encodedMessage");
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not launch WhatsApp: $e')));
      }
    }
  }



  void _openFollowUpSheet() {
    String currentStatus = _detail!['status'] ?? 'NEW';
    final noteController = TextEditingController();
    DateTime? selectedDate = _detail!['followUpDate'] != null
        ? DateTime.tryParse(_detail!['followUpDate'].toString())
        : null;
    bool isSaving = false;

    final statuses = [
      {'value': 'CONTACTED', 'label': 'Contacted', 'color': Colors.blue},
      {'value': 'INTERESTED', 'label': 'Interested', 'color': Colors.green},
      {'value': 'NOT_INTERESTED', 'label': 'Not Interested', 'color': Colors.red},
    ];

    // Quick date shortcuts
    final now = DateTime.now();
    final quickDates = [
      {'label': 'Today', 'date': now},
      {'label': 'Tomorrow', 'date': now.add(const Duration(days: 1))},
      {'label': 'In 3 Days', 'date': now.add(const Duration(days: 3))},
      {'label': 'Next Week', 'date': now.add(const Duration(days: 7))},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            expand: false,
            builder: (_, scrollCtrl) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: ListView(
                  controller: scrollCtrl,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4)),
                      ),
                    ),

                    // Header
                    Row(
                      children: [
                        const Icon(Icons.phone_callback, color: Colors.blueAccent, size: 20),
                        const SizedBox(width: 8),
                        const Text('Update Status & Follow-up', style: TextStyle(color: Color(0xFF1E293B), fontSize: 17, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _detail!['name'] ?? '',
                      style: const TextStyle(color: Colors.blueGrey, fontSize: 13),
                    ),
                    const Divider(color: Colors.black12, height: 24),

                    // Status Selection
                    const Text('Lead Status', style: TextStyle(color: Colors.blueGrey, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: statuses.map((s) {
                        final isSelected = currentStatus == s['value'];
                        final color = s['color'] as Color;
                        return GestureDetector(
                          onTap: () => setSheet(() => currentStatus = s['value'] as String),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? color.withOpacity(0.2) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isSelected ? color : Colors.black12, width: isSelected ? 1.5 : 1),
                            ),
                            child: Text(
                              s['label'] as String,
                              style: TextStyle(
                                color: isSelected ? color : Colors.blueGrey,
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Follow-up Date
                    const Text('Follow-up Date', style: TextStyle(color: Colors.blueGrey, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),

                    // Quick date shortcuts
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: quickDates.map((q) {
                          final qDate = q['date'] as DateTime;
                          final isSelected = selectedDate != null &&
                              selectedDate!.year == qDate.year &&
                              selectedDate!.month == qDate.month &&
                              selectedDate!.day == qDate.day;
                          return GestureDetector(
                            onTap: () => setSheet(() => selectedDate = qDate),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blueAccent.withOpacity(0.2) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isSelected ? Colors.blueAccent : Colors.black12),
                              ),
                              child: Text(
                                q['label'] as String,
                                style: TextStyle(
                                  color: isSelected ? Colors.blueAccent : Colors.blueGrey,
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Custom date picker
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 7)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          builder: (ctx, child) => Theme(data: ThemeData.light(), child: child!),
                        );
                        if (picked != null) setSheet(() => selectedDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: selectedDate != null ? Colors.blueAccent.withOpacity(0.5) : Colors.black12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Colors.blueGrey, size: 18),
                            const SizedBox(width: 12),
                            Text(
                              selectedDate != null
                                  ? DateFormat('EEEE, dd MMM yyyy').format(selectedDate!)
                                  : 'Choose a custom date...',
                              style: TextStyle(
                                color: selectedDate != null ? const Color(0xFF1E293B) : Colors.blueGrey,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            if (selectedDate != null)
                              GestureDetector(
                                onTap: () => setSheet(() => selectedDate = null),
                                child: const Icon(Icons.close, color: Colors.redAccent, size: 16),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Notes / Call Summary
                    const Text('Call Summary / Note', style: TextStyle(color: Colors.blueGrey, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: noteController,
                      maxLines: 3,
                      style: const TextStyle(color: Color(0xFF1E293B), fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'e.g. Interested in Python batch, will call back tomorrow...',
                        hintStyle: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.black12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.black12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.blueAccent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: isSaving
                            ? const SizedBox.shrink()
                            : const Icon(Icons.check_circle_outline, color: Colors.white),
                        label: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Save Follow-up', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                setSheet(() {
                                  isSaving = true;
                                });
                                try {
                                  final apiService = Provider.of<ApiService>(context, listen: false);
                                  final payload = <String, dynamic>{
                                    'status': currentStatus,
                                  };
                                  if (noteController.text.trim().isNotEmpty) {
                                    payload['note'] = noteController.text.trim();
                                  }
                                  if (selectedDate != null) {
                                    payload['followUpDate'] = DateFormat('yyyy-MM-dd').format(selectedDate!);
                                  } else if (currentStatus == 'NOT_INTERESTED') {
                                    payload['followUpDate'] = null;
                                  }

                                  final res = await apiService.putRequest(
                                    '/enquiries/${widget.enquiryId}',
                                    data: payload,
                                  );
                                  if (res.statusCode == 200) {
                                    if (mounted) Navigator.pop(ctx);
                                    _loadDetails();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('✅ Follow-up updated successfully'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  setSheet(() {
                                    isSaving = false;
                                  });
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to update: $e')),
                                    );
                                  }
                                }
                              },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        });
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_detail == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: Text('Lead detail not found.', style: TextStyle(color: Colors.blueGrey))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_detail!['name'] ?? 'Lead Details', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1F2937),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Basic Info Card (Animated Fade-in & Slide)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 500),
              builder: (context, val, child) {
                return Opacity(
                  opacity: val,
                  child: Transform.translate(
                    offset: Offset(0, 30 * (1 - val)),
                    child: child,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.15)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.badge, color: Colors.blueAccent, size: 18),
                        SizedBox(width: 8),
                        Text('LEAD INFORMATION', style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRowWithIcon(Icons.person, 'Name', _detail!['name']),
                    _buildInfoRowWithIcon(Icons.phone, 'Phone', _detail!['mobile']),
                    _buildInfoRowWithIcon(Icons.email, 'Email', _detail!['email']),
                    _buildInfoRowWithIcon(Icons.book, 'Course Interested', _detail!['course'] ?? _detail!['courseInterested']),
                    _buildInfoRowWithIcon(Icons.share, 'Source', _detail!['source'] ?? _detail!['leadSource']),
                    _buildStatusRow('Current Status', _detail!['status']),
                    if (_detail!['followUpDate'] != null) ...[  
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month, color: Colors.blueAccent, size: 16),
                            const SizedBox(width: 8),
                            const Text('Follow-up:', style: TextStyle(color: Colors.blueGrey, fontSize: 13)),
                            const Spacer(),
                            Text(
                              () {
                                try {
                                  final d = DateTime.parse(_detail!['followUpDate'].toString());
                                  final now = DateTime.now();
                                  final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
                                  final isOverdue = d.isBefore(DateTime(now.year, now.month, now.day));
                                  final formatted = DateFormat('dd MMM yyyy').format(d);
                                  if (isToday) return '📅 Today ($formatted)';
                                  if (isOverdue) return '⚠️ Overdue ($formatted)';
                                  return '🗓 $formatted';
                                } catch (_) {
                                  return _detail!['followUpDate'].toString();
                                }
                              }(),
                              style: TextStyle(
                                color: () {
                                  try {
                                    final d = DateTime.parse(_detail!['followUpDate'].toString());
                                    final now = DateTime.now();
                                    if (d.isBefore(DateTime(now.year, now.month, now.day))) return Colors.redAccent;
                                    return Colors.blueAccent;
                                  } catch (_) {
                                    return Colors.blueAccent;
                                  }
                                }(),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Actions box
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.teal.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.flash_on, color: Colors.amber, size: 18),
                      SizedBox(width: 8),
                      Text('QUICK ACTIONS', style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _openFollowUpSheet,
                    icon: const Icon(Icons.phone_callback, color: Colors.white, size: 20),
                    label: const Text('Update Status & Follow-up', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  if (_detail!['status'] != 'ADMITTED' && _detail!['status'] != 'CONVERTED') ...[
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ConvertAdmissionScreen(
                              enquiryId: widget.enquiryId,
                              studentName: _detail!['name'] ?? '',
                              studentMobile: _detail!['mobile'] ?? '',
                              studentEmail: _detail!['email'] ?? '',
                              course: (_detail!['course'] ?? _detail!['courseInterested']) ?? '',
                            ),
                          ),
                        ).then((_) => _loadDetails());
                      },
                      icon: const Icon(Icons.school, color: Colors.white, size: 20),
                      label: const Text('Convert to Admission', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Timeline notes
            const Row(
              children: [
                Icon(Icons.history, color: Colors.blueGrey, size: 18),
                SizedBox(width: 8),
                Text('TIMELINE & NOTES', style: TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            (() {
              final List<Map<String, dynamic>> items = [];
              if (_detail!['createdAt'] != null) {
                items.add({
                  'status': 'CREATED',
                  'note': 'Enquiry created',
                  'changedAt': _detail!['createdAt'],
                  'changedBy': _detail!['createdBy'],
                });
              }
              final history = _detail!['statusHistory'] as List<dynamic>? ?? [];
              for (var h in history) {
                if (h is Map<String, dynamic>) {
                  items.add(h);
                } else if (h is Map) {
                  items.add(Map<String, dynamic>.from(h));
                }
              }

              // Sort latest first
              items.sort((a, b) {
                final dateA = DateTime.tryParse(a['changedAt']?.toString() ?? '') ?? DateTime(2000);
                final dateB = DateTime.tryParse(b['changedAt']?.toString() ?? '') ?? DateTime(2000);
                return dateB.compareTo(dateA);
              });

              if (items.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: const Color(0xFFFFFFFF), borderRadius: BorderRadius.circular(12)),
                  child: const Center(
                    child: Text(
                      'No activity notes recorded yet.',
                      style: TextStyle(color: Colors.blueGrey, fontSize: 13),
                    ),
                  ),
                );
              }

              return Column(
                children: items.map((historyItem) {
                  final status = historyItem['status'] ?? 'UPDATE';
                  final note = historyItem['note'] ?? '';
                  final changedAt = _formatTimelineDate(historyItem['changedAt']?.toString());

                  Color statusColor;
                  Color statusBg;
                  switch (status.toString().toUpperCase()) {
                    case 'NEW':
                      statusColor = const Color(0xFF3B82F6);
                      statusBg = const Color(0xFF3B82F6).withOpacity(0.15);
                      break;
                    case 'CONTACTED':
                      statusColor = const Color(0xFFF59E0B);
                      statusBg = const Color(0xFFF59E0B).withOpacity(0.15);
                      break;
                    case 'INTERESTED':
                      statusColor = const Color(0xFF10B981);
                      statusBg = const Color(0xFF10B981).withOpacity(0.15);
                      break;
                    case 'NOT_INTERESTED':
                      statusColor = const Color(0xFFEF4444);
                      statusBg = const Color(0xFFEF4444).withOpacity(0.15);
                      break;
                    case 'ADMITTED':
                    case 'CONVERTED':
                      statusColor = const Color(0xFF8B5CF6);
                      statusBg = const Color(0xFF8B5CF6).withOpacity(0.15);
                      break;
                    case 'CREATED':
                      statusColor = Colors.indigoAccent;
                      statusBg = Colors.indigoAccent.withOpacity(0.15);
                      break;
                    default:
                      statusColor = Colors.blueGrey;
                      statusBg = Colors.blueGrey.withOpacity(0.15);
                  }

                  final changedByObj = historyItem['changedBy'];
                  String updaterName = 'System';
                  if (changedByObj is Map) {
                    updaterName = changedByObj['name'] ?? 'Unknown User';
                  } else if (changedByObj is String) {
                    if (changedByObj == _detail!['createdBy']?['_id']) {
                      updaterName = _detail!['createdBy']?['name'] ?? 'Creator';
                    } else if (changedByObj == _detail!['assignedTo']?['_id']) {
                      updaterName = _detail!['assignedTo']?['name'] ?? 'Assignee';
                    } else {
                      updaterName = 'Staff';
                    }
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Text(
                              changedAt,
                              style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          note,
                          style: const TextStyle(color: Color(0xFF1E293B), fontSize: 14),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 14, color: Colors.blueGrey),
                            const SizedBox(width: 4),
                            Text(
                              'Updated by: $updaterName',
                              style: const TextStyle(color: Colors.blueGrey, fontSize: 11, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            })(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRowWithIcon(IconData icon, String label, dynamic value) {
    final valStr = value?.toString() ?? 'N/A';
    final isPhone = label.toLowerCase() == 'phone' && valStr != 'N/A';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueGrey, size: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.blueGrey, fontSize: 14)),
          const Spacer(),
          Text(
            valStr,
            style: const TextStyle(color: Color(0xFF1E293B), fontSize: 14, fontWeight: FontWeight.bold),
          ),
          if (isPhone) ...[
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

  Widget _buildStatusRow(String label, dynamic value) {
    final status = value?.toString() ?? 'NEW';
    Color statusColor = Colors.grey;
    if (status == 'CONTACTED') statusColor = Colors.blue;
    if (status == 'INTERESTED') statusColor = Colors.orange;
    if (status == 'ADMITTED' || status == 'CONVERTED') statusColor = Colors.teal;
    if (status == 'NOT_INTERESTED' || status == 'LOST') statusColor = Colors.redAccent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.blueGrey, size: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.blueGrey, fontSize: 14)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withOpacity(0.5)),
            ),
            child: Text(
              status,
              style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class MobileNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(RegExp(r'\D'), '');
    final cleanText = text.substring(0, text.length > 10 ? 10 : text.length);
    String formatted = '';
    if (cleanText.length > 5) {
      formatted = cleanText.substring(0, 5) + ' ' + cleanText.substring(5);
    } else {
      formatted = cleanText;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
