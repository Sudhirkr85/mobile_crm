import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

class AddUserScreen extends StatefulWidget {
  const AddUserScreen({super.key});

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _selectedRole = 'counselor';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final res = await apiService.postRequest('/auth/register', data: {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'role': _selectedRole,
      });

      if (res.statusCode == 201 || res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User registered successfully!'), backgroundColor: Colors.green),
          );
        }
        _nameController.clear();
        _emailController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();
        setState(() {
          _selectedRole = 'counselor';
        });
      }
    } catch (e) {
      String errMsg = 'Failed to register user';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['message'] != null) {
          errMsg = data['message'];
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errMsg), backgroundColor: Colors.redAccent));
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
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Add User Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_add_alt_1, color: Colors.blueAccent, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Create Staff Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          SizedBox(height: 4),
                          Text(
                            'Assign roles with specific access levels for portal/app.',
                            style: TextStyle(color: Colors.blueGrey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Inputs Group
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: _buildInputDecoration(
                  label: 'Full Name *',
                  icon: Icons.person_outline,
                ),
                validator: (val) => val == null || val.isEmpty ? 'Please enter full name' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: _buildInputDecoration(
                  label: 'Email Address *',
                  icon: Icons.email_outlined,
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Please enter email';
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val)) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: _buildInputDecoration(
                  label: 'Password *',
                  icon: Icons.lock_outlined,
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Colors.blueGrey,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (val) => val == null || val.length < 6 ? 'Password must be at least 6 characters' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: _buildInputDecoration(
                  label: 'Confirm Password *',
                  icon: Icons.lock_reset_outlined,
                  suffix: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Colors.blueGrey,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Please confirm your password' : null,
              ),
              const SizedBox(height: 20),

              // Role Dropdown
              DropdownButtonFormField<String>(
                value: _selectedRole,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: _buildInputDecoration(
                  label: 'Account Role',
                  icon: Icons.shield_outlined,
                ),
                items: const [
                  DropdownMenuItem(value: 'counselor', child: Text('Counselor (Leads, Admissions)')),
                  DropdownMenuItem(value: 'employee', child: Text('Employee (Attendance only)')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin (Full access)')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedRole = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 32),

              // Register Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isLoading 
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline, color: Colors.white),
                  label: const Text(
                    'Create Account',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _handleRegister,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({required String label, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.blueGrey),
      prefixIcon: Icon(icon, color: Colors.blueAccent, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFF1E293B),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    );
  }
}
