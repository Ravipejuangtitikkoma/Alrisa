import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

enum UserRole {
  superadmin,
  user,
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final String password;
  final UserRole role;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    required this.createdAt,
  });

  bool get isSuperAdmin => role == UserRole.superadmin;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'password': password,
    'role': role.index,
    'createdAt': createdAt.toIso8601String(),
  };

  factory UserModel.fromJson(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      role: UserRole.values[map['role'] ?? 1],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}

/// Singleton Service Manajemen Akun & Autentikasi ALRISA (Dengan Persistensi Sesi)
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  AuthService._internal() {
    _initDefaultAccounts();
  }

  // Durasi inaktif sebelum sesi kedaluwarsa (Default: 30 hari inaktif bergulir / rolling)
  static const int sessionExpiryDays = 30;

  // Database Akun Lokal (Tersimpan in-memory dan persisten di users_db.json)
  final Map<String, UserModel> _usersDatabase = {};

  // Sesi Pengguna yang Sedang Login
  UserModel? _currentUser;
  DateTime? _lastActiveTime;

  // Stream perubahan sesi login
  final StreamController<UserModel?> _authController = StreamController<UserModel?>.broadcast();
  Stream<UserModel?> get authStream => _authController.stream;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isSuperAdmin => _currentUser?.isSuperAdmin ?? false;
  String get currentUserName => _currentUser?.name ?? 'Pengguna';
  DateTime? get lastActiveTime => _lastActiveTime;

  // Path helper untuk file penyimpanan
  Future<File> _getFile(String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$filename');
  }

  void _initDefaultAccounts() {
    // 👑 AKUN RESMI SUPER ADMIN RAVI ARMANZA
    final superAdmin = UserModel(
      id: 'usr_superadmin_01',
      name: 'Ravi Armanza',
      email: 'raviarmanza149@gmail.com',
      password: 'ravi18',
      role: UserRole.superadmin,
      createdAt: DateTime(2026, 1, 1),
    );
    _usersDatabase[superAdmin.email.toLowerCase()] = superAdmin;

    // Akun demo keluarga biasa
    final demoUser = UserModel(
      id: 'usr_family_02',
      name: 'Keluarga Nexora',
      email: 'user@nexora.id',
      password: 'user123',
      role: UserRole.user,
      createdAt: DateTime(2026, 1, 1),
    );
    _usersDatabase[demoUser.email.toLowerCase()] = demoUser;
  }

  /// Memulihkan database user tambahan dan sesi login dari penyimpanan lokal
  Future<bool> restoreSession() async {
    try {
      // 1. Muat akun-akun pendaftaran dari users_db.json
      final usersFile = await _getFile('alrisa_users_db.json');
      if (await usersFile.exists()) {
        final content = await usersFile.readAsString();
        final Map<String, dynamic> rawMap = json.decode(content);
        rawMap.forEach((email, userMap) {
          _usersDatabase[email.toLowerCase()] = UserModel.fromJson(Map<String, dynamic>.from(userMap));
        });
      }

      // 2. Muat sesi login aktif dari alrisa_session.json
      final sessionFile = await _getFile('alrisa_session.json');
      if (await sessionFile.exists()) {
        final sessionContent = await sessionFile.readAsString();
        final Map<String, dynamic> sessionData = json.decode(sessionContent);

        final userData = sessionData['user'];
        final lastActiveStr = sessionData['lastActive'];

        if (userData != null && lastActiveStr != null) {
          final lastActive = DateTime.tryParse(lastActiveStr) ?? DateTime.now();
          final difference = DateTime.now().difference(lastActive);

          // Cek apakah sesi sudah melewati batas kedaluwarsa inaktif
          if (difference.inDays >= sessionExpiryDays) {
            // Sesi kedaluwarsa karena tidak digunakan selama X hari
            await logout();
            return false;
          }

          // Sesi masih valid! Pulihkan user dan perbarui timestamp keaktifan
          _currentUser = UserModel.fromJson(Map<String, dynamic>.from(userData));
          _lastActiveTime = DateTime.now();
          _authController.add(_currentUser);

          // Simpan timestamp terbaru (Rolling Session)
          await _saveSessionToFile(_currentUser!, _lastActiveTime!);
          return true;
        }
      }
    } catch (e) {
      // Jika terjadi kesalahan baca, abaikan dan minta login normal
    }
    return false;
  }

  /// Simpan sesi aktif ke file lokal
  Future<void> _saveSessionToFile(UserModel user, DateTime activeTime) async {
    try {
      final sessionFile = await _getFile('alrisa_session.json');
      final sessionData = {
        'user': user.toJson(),
        'lastActive': activeTime.toIso8601String(),
        'expiryDays': sessionExpiryDays,
      };
      await sessionFile.writeAsString(json.encode(sessionData));
    } catch (_) {}
  }

  /// Simpan database user ke file lokal
  Future<void> _saveUsersDbToFile() async {
    try {
      final usersFile = await _getFile('alrisa_users_db.json');
      final Map<String, dynamic> data = {};
      _usersDatabase.forEach((key, val) {
        data[key] = val.toJson();
      });
      await usersFile.writeAsString(json.encode(data));
    } catch (_) {}
  }

  /// Proses Login
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600)); // Simulasi proses aman

    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    if (!_usersDatabase.containsKey(cleanEmail)) {
      return {
        'success': false,
        'message': 'Email belum terdaftar. Silakan registrasi terlebih dahulu.',
      };
    }

    final user = _usersDatabase[cleanEmail]!;
    if (user.password != cleanPassword) {
      return {
        'success': false,
        'message': 'Password yang Anda masukkan salah!',
      };
    }

    _currentUser = user;
    _lastActiveTime = DateTime.now();
    _authController.add(_currentUser);

    // Simpan sesi agar saat aplikasi ditutup tidak perlu login lagi
    await _saveSessionToFile(_currentUser!, _lastActiveTime!);

    return {
      'success': true,
      'message': user.isSuperAdmin
          ? 'Selamat datang kembali, Super Admin ${user.name}!'
          : 'Selamat datang, ${user.name}!',
      'user': user,
    };
  }

  /// Proses Registrasi Pengguna Baru
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));

    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim();
    final cleanPassword = password.trim();

    // 1. Validasi jika email sudah digunakan sebelumnya
    if (_usersDatabase.containsKey(cleanEmail)) {
      return {
        'success': false,
        'message': 'Email "$cleanEmail" sudah terdaftar! Gunakan email lain.',
      };
    }

    // 2. Buat akun baru sebagai role User biasa
    final newUser = UserModel(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      name: cleanName,
      email: cleanEmail,
      password: cleanPassword,
      role: UserRole.user,
      createdAt: DateTime.now(),
    );

    _usersDatabase[cleanEmail] = newUser;
    _currentUser = newUser;
    _lastActiveTime = DateTime.now();
    _authController.add(_currentUser);

    // Simpan akun ke database lokal & simpan sesi login otomatis
    await _saveUsersDbToFile();
    await _saveSessionToFile(_currentUser!, _lastActiveTime!);

    return {
      'success': true,
      'message': 'Pendaftaran berhasil! Selamat bergabung, $cleanName.',
      'user': newUser,
    };
  }

  /// Proses Logout
  Future<void> logout() async {
    _currentUser = null;
    _lastActiveTime = null;
    _authController.add(null);

    try {
      final sessionFile = await _getFile('alrisa_session.json');
      if (await sessionFile.exists()) {
        await sessionFile.delete();
      }
    } catch (_) {}
  }
}
