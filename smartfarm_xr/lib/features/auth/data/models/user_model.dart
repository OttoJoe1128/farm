/// Kullanici modeli - Backend'den gelen kullanici verisi
class UserModel {
  final String id;
  final String username;
  final String email;
  final String? fullName;
  final String? phone;
  final String? avatarUrl;
  final String role;
  final bool isActive;
  final DateTime? lastLoginAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.id,
    required this.username,
    required this.email,
    this.fullName,
    this.phone,
    this.avatarUrl,
    required this.role,
    required this.isActive,
    this.lastLoginAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] as String,
      isActive: json['is_active'] as bool? ?? true,
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.tryParse(json['last_login_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'avatar_url': avatarUrl,
      'role': role,
      'is_active': isActive,
      'last_login_at': lastLoginAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? username,
    String? email,
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? role,
    bool? isActive,
    DateTime? lastLoginAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Rol goruntuleme adi (Turkce)
  String get roleDisplayName {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'yonetici':
        return 'Yonetici';
      case 'calisan':
        return 'Calisan';
      case 'tarimci':
        return 'Tarimci';
      case 'izleyici':
        return 'Izleyici';
      default:
        return role;
    }
  }

  /// Admin rolune sahip mi
  bool get isAdmin => role == 'admin';

  /// Yonetici veya admin rolune sahip mi
  bool get isManagerOrAdmin => role == 'admin' || role == 'yonetici';
}

/// Token yaniti modeli
class TokenResponse {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final UserBrief user;

  const TokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
      expiresIn: json['expires_in'] as int,
      user: UserBrief.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

/// Kisa kullanici bilgisi
class UserBrief {
  final String id;
  final String username;
  final String email;
  final String? fullName;
  final String role;
  final String? avatarUrl;

  const UserBrief({
    required this.id,
    required this.username,
    required this.email,
    this.fullName,
    required this.role,
    this.avatarUrl,
  });

  factory UserBrief.fromJson(Map<String, dynamic> json) {
    return UserBrief(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      role: json['role'] as String,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}
