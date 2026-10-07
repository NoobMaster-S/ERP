import 'package:equatable/equatable.dart';

class BusinessSummary extends Equatable {
  final String id;
  final String name;
  final String slug;
  final String businessType;
  final String roleName;
  final List<String> permissions;

  const BusinessSummary({
    required this.id,
    required this.name,
    required this.slug,
    required this.businessType,
    required this.roleName,
    required this.permissions,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'businessType': businessType,
        'roleName': roleName,
        'permissions': permissions,
      };

  factory BusinessSummary.fromJson(Map<String, dynamic> json) =>
      BusinessSummary(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
        businessType: json['businessType'] as String,
        roleName: json['roleName'] as String,
        permissions: (json['permissions'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );

  @override
  List<Object?> get props =>
      [id, name, slug, businessType, roleName, permissions];
}

class UserProfile extends Equatable {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final bool isPlatformAdmin;

  const UserProfile({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.isPlatformAdmin,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'isPlatformAdmin': isPlatformAdmin,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        email: json['email'] as String,
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        isPlatformAdmin: json['isPlatformAdmin'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [id, email, firstName, lastName, isPlatformAdmin];
}

class AuthSession extends Equatable {
  final String accessToken;
  final String refreshToken;
  final UserProfile user;
  final BusinessSummary? activeBusiness;
  final List<BusinessSummary> availableBusinesses;

  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    this.activeBusiness,
    required this.availableBusinesses,
  });

  AuthSession copyWith({
    String? accessToken,
    String? refreshToken,
    UserProfile? user,
    BusinessSummary? activeBusiness,
    List<BusinessSummary>? availableBusinesses,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      user: user ?? this.user,
      activeBusiness: activeBusiness ?? this.activeBusiness,
      availableBusinesses: availableBusinesses ?? this.availableBusinesses,
    );
  }

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'user': user.toJson(),
        'activeBusiness': activeBusiness?.toJson(),
        'availableBusinesses':
            availableBusinesses.map((b) => b.toJson()).toList(),
      };

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        user: UserProfile.fromJson(json['user'] as Map<String, dynamic>),
        activeBusiness: json['activeBusiness'] != null
            ? BusinessSummary.fromJson(
                json['activeBusiness'] as Map<String, dynamic>)
            : null,
        availableBusinesses: (json['availableBusinesses'] as List<dynamic>?)
                ?.map((b) => BusinessSummary.fromJson(b as Map<String, dynamic>))
                .toList() ??
            [],
      );

  @override
  List<Object?> get props =>
      [accessToken, refreshToken, user, activeBusiness, availableBusinesses];
}
