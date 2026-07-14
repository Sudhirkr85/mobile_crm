import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String defaultBaseUrl = 'https://sssam-r3pz.onrender.com/api';
  
  final Dio _dio = Dio(BaseOptions(
    baseUrl: defaultBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  String? _token;
  String? _userName;
  String? _userEmail;
  String? _userRole;

  ApiService() {
    _initInterceptors();
  }

  String? get token => _token;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get userRole => _userRole;

  void _initInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          } else {
            // Load from shared preferences if not in memory
            final prefs = await SharedPreferences.getInstance();
            final savedToken = prefs.getString('token');
            if (savedToken != null) {
              _token = savedToken;
              _userName = prefs.getString('name');
              _userEmail = prefs.getString('email');
              _userRole = prefs.getString('role');
              options.headers['Authorization'] = 'Bearer $savedToken';
            }
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401) {
            await logout();
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('token');
    if (savedToken != null) {
      _token = savedToken;
      _userName = prefs.getString('name');
      _userEmail = prefs.getString('email');
      _userRole = prefs.getString('role');
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200 && response.data != null) {
        final responseData = response.data['data'];
        _token = responseData['token'];
        _userName = responseData['user']['name'];
        _userEmail = responseData['user']['email'];
        _userRole = responseData['user']['role'];

        // Persist session
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        await prefs.setString('name', _userName!);
        await prefs.setString('email', _userEmail!);
        await prefs.setString('role', _userRole!);

        return {'success': true, 'role': _userRole};
      }
      return {'success': false, 'message': 'Unknown error occurred'};
    } on DioException catch (e) {
      String msg = 'Login failed';
      if (e.response?.data != null && e.response?.data['message'] != null) {
        msg = e.response?.data['message'];
      } else if (e.message != null) {
        msg = e.message!;
      }
      return {'success': false, 'message': msg};
    }
  }

  Future<void> logout() async {
    _token = null;
    _userName = null;
    _userEmail = null;
    _userRole = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('name');
    await prefs.remove('email');
    await prefs.remove('role');
  }

  // Generic HTTP requests helper
  Future<Response> getRequest(String path, {Map<String, dynamic>? queryParameters}) async {
    return await _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> postRequest(String path, {dynamic data}) async {
    return await _dio.post(path, data: data);
  }

  Future<Response> putRequest(String path, {dynamic data}) async {
    return await _dio.put(path, data: data);
  }

  Future<Response> deleteRequest(String path, {dynamic data}) async {
    return await _dio.delete(path, data: data);
  }

  static String getReadableError(dynamic error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'Connection timeout. Please check your internet connection.';
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'Server connection error. Please check your internet or if the server is starting up.';
      }
      if (error.response != null) {
        final data = error.response!.data;
        if (data is Map && data['message'] != null) {
          return data['message'].toString();
        }
        return 'Server error (Status: ${error.response!.statusCode})';
      }
      if (error.message != null && error.message!.contains('SocketException')) {
        return 'No internet connection or server is offline.';
      }
    }
    final errStr = error.toString();
    if (errStr.contains('SocketException') || errStr.contains('Failed host lookup')) {
      return 'No internet connection or server is unreachable. Please try again.';
    }
    return errStr;
  }
}
