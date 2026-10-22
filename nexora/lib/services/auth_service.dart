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
  final String? photoPath;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    required this.createdAt,
    this.photoPath,
  });

  bool get isSuperAdmin => role == UserRole.superadmin;

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? password,
    UserRole? role,
    DateTime? createdAt,
    String? photoPath,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      photoPath: photoPath ?? this.photoPath,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'password': password,
    'role': role.index,
    'createdAt': createdAt.toIso8601String(),
    'photoPath': photoPath,
  };

  factory UserModel.fromJson(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      role: UserRole.values[map['role'] ?? 1],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      photoPath: map['photoPath'],
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

  /// Konfigurasi URL API Kantor Resmi (dapat diisi jika API kantor sudah aktif)
  String officeApiBaseUrl = ''; // Contoh: 'https://api.kantor.com/v1'

  /// Cek apakah suatu email sudah terdaftar di sistem kantor
  bool checkEmailExists(String email) {
    final cleanEmail = email.trim().toLowerCase();
    return _usersDatabase.containsKey(cleanEmail);
  }

  /// Proses Login Menggunakan Akun Kantor
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
        'message': 'Email belum terdaftar di sistem kantor Alrisa. Silakan hubungi administrator kantor Anda.',
      };
    }

    final user = _usersDatabase[cleanEmail]!;
    if (user.password != cleanPassword) {
      return {
        'success': false,
        'message': 'Kata sandi yang Anda masukkan salah!',
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

  /// Masuk Cepat Menggunakan Akun Google (Single Sign-On Kantor)
  Future<Map<String, dynamic>> loginWithGoogle(String googleEmail) async {
    await Future.delayed(const Duration(milliseconds: 700));

    final cleanEmail = googleEmail.trim().toLowerCase();

    // Verifikasi apakah akun Google ini sudah didaftarkan oleh kantor
    if (!_usersDatabase.containsKey(cleanEmail)) {
      return {
        'success': false,
        'message': 'Akun Google ($cleanEmail) belum terdaftar di sistem kantor Alrisa. Silakan hubungi admin kantor untuk mendaftarkan email ini.',
      };
    }

    final user = _usersDatabase[cleanEmail]!;
    _currentUser = user;
    _lastActiveTime = DateTime.now();
    _authController.add(_currentUser);

    await _saveSessionToFile(_currentUser!, _lastActiveTime!);

    return {
      'success': true,
      'message': 'Berhasil masuk dengan Google sebagai ${user.name}!',
      'user': user,
    };
  }

  /// Proses Permintaan Reset Kata Sandi via Email
  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final cleanEmail = email.trim().toLowerCase();

    // 1. Cek apakah akun terdaftar di sistem kantor
    if (!_usersDatabase.containsKey(cleanEmail)) {
      return {
        'success': false,
        'message': 'Email tidak terdaftar di dalam sistem Alrisa! Pastikan Anda memasukkan email resmi yang diberikan oleh kantor.',
      };
    }

    // 2. Email ditemukan! Kirim instruksi pemulihan
    // (Jika API kantor sudah siap, di sini kita tinggal mengirim request POST ke server kantor)
    return {
      'success': true,
      'message': 'Instruksi pemulihan kata sandi telah dikirimkan ke $cleanEmail. Silakan periksa kotak masuk atau spam email Anda.',
    };
  }

  /// Pendaftaran / Pembuatan Akun Baru oleh Administrator Kantor
  Future<Map<String, dynamic>> addOfficeAccount({
    required String name,
    required String email,
    required String password,
    UserRole role = UserRole.user,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim();
    final cleanPassword = password.trim();

    if (_usersDatabase.containsKey(cleanEmail)) {
      return {
        'success': false,
        'message': 'Email "$cleanEmail" sudah terdaftar di sistem!',
      };
    }

    final newUser = UserModel(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      name: cleanName,
      email: cleanEmail,
      password: cleanPassword,
      role: role,
      createdAt: DateTime.now(),
    );

    _usersDatabase[cleanEmail] = newUser;
    await _saveUsersDbToFile();

    return {
      'success': true,
      'message': 'Akun resmi kantor untuk $cleanName berhasil dibuat.',
      'user': newUser,
    };
  }

  /// Proses Registrasi (Deprecated: Dipertahankan untuk kompatibilitas data lama)
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    return addOfficeAccount(name: name, email: email, password: password);
  }

  /// Update nama atau foto profil akun pengguna
  Future<void> updateProfile({required String newName, String? newPhotoPath}) async {
    if (_currentUser == null) return;
    final updated = _currentUser!.copyWith(
      name: newName.trim().isNotEmpty ? newName.trim() : _currentUser!.name,
      photoPath: newPhotoPath ?? _currentUser!.photoPath,
    );
    _currentUser = updated;
    _usersDatabase[updated.email.toLowerCase()] = updated;
    _authController.add(_currentUser);

    await _saveSessionToFile(_currentUser!, _lastActiveTime ?? DateTime.now());
    await _saveUsersDbToFile();
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
