import 'dart:async';

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

/// Singleton Service Manajemen Akun & Autentikasi Nexora
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  AuthService._internal() {
    _initDefaultAccounts();
  }

  // Database Akun Lokal (Tersimpan in-memory dan persisten)
  final Map<String, UserModel> _usersDatabase = {};

  // Sesi Pengguna yang Sedang Login
  UserModel? _currentUser;

  // Stream perubahan sesi login
  final StreamController<UserModel?> _authController = StreamController<UserModel?>.broadcast();
  Stream<UserModel?> get authStream => _authController.stream;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isSuperAdmin => _currentUser?.isSuperAdmin ?? false;
  String get currentUserName => _currentUser?.name ?? 'Pengguna';

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
    _authController.add(_currentUser);

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
    _authController.add(_currentUser);

    return {
      'success': true,
      'message': 'Pendaftaran berhasil! Selamat bergabung, $cleanName.',
      'user': newUser,
    };
  }

  /// Proses Logout
  void logout() {
    _currentUser = null;
    _authController.add(null);
  }
}
