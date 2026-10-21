class FitPreferencesModel {
  final String? topsSize;
  final String? bottomsSize;
  final String? shoeSize;
  final String? preferredFit; // slim, regular, relaxed, oversized

  const FitPreferencesModel({
    this.topsSize,
    this.bottomsSize,
    this.shoeSize,
    this.preferredFit,
  });

  bool get hasAnyPreferences =>
      (topsSize != null && topsSize!.isNotEmpty) ||
      (bottomsSize != null && bottomsSize!.isNotEmpty) ||
      (shoeSize != null && shoeSize!.isNotEmpty) ||
      (preferredFit != null && preferredFit!.isNotEmpty);

  factory FitPreferencesModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const FitPreferencesModel();
    return FitPreferencesModel(
      topsSize: json['tops_size'] as String?,
      bottomsSize: json['bottoms_size'] as String?,
      shoeSize: json['shoe_size'] as String?,
      preferredFit: json['preferred_fit'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (topsSize != null) 'tops_size': topsSize,
      if (bottomsSize != null) 'bottoms_size': bottomsSize,
      if (shoeSize != null) 'shoe_size': shoeSize,
      if (preferredFit != null) 'preferred_fit': preferredFit,
    };
  }

  FitPreferencesModel copyWith({
    String? topsSize,
    String? bottomsSize,
    String? shoeSize,
    String? preferredFit,
  }) {
    return FitPreferencesModel(
      topsSize: topsSize ?? this.topsSize,
      bottomsSize: bottomsSize ?? this.bottomsSize,
      shoeSize: shoeSize ?? this.shoeSize,
      preferredFit: preferredFit ?? this.preferredFit,
    );
  }
}

class ProfilePrivacySettingsModel {
  final bool showProfilePhoto;
  final bool showBio;
  final bool showAge;
  final bool showPhone;
  final bool showEmail;
  final bool showFitPreferences;
  final bool showPreferredStyles;

  const ProfilePrivacySettingsModel({
    this.showProfilePhoto = true,
    this.showBio = true,
    this.showAge = false,
    this.showPhone = false,
    this.showEmail = false,
    this.showFitPreferences = false,
    this.showPreferredStyles = true,
  });

  factory ProfilePrivacySettingsModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ProfilePrivacySettingsModel();
    return ProfilePrivacySettingsModel(
      showProfilePhoto: json['show_profile_photo'] as bool? ?? true,
      showBio: json['show_bio'] as bool? ?? true,
      showAge: json['show_age'] as bool? ?? false,
      showPhone: json['show_phone'] as bool? ?? false,
      showEmail: json['show_email'] as bool? ?? false,
      showFitPreferences: json['show_fit_preferences'] as bool? ?? false,
      showPreferredStyles: json['show_preferred_styles'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'show_profile_photo': showProfilePhoto,
      'show_bio': showBio,
      'show_age': showAge,
      'show_phone': showPhone,
      'show_email': showEmail,
      'show_fit_preferences': showFitPreferences,
      'show_preferred_styles': showPreferredStyles,
    };
  }

  ProfilePrivacySettingsModel copyWith({
    bool? showProfilePhoto,
    bool? showBio,
    bool? showAge,
    bool? showPhone,
    bool? showEmail,
    bool? showFitPreferences,
    bool? showPreferredStyles,
  }) {
    return ProfilePrivacySettingsModel(
      showProfilePhoto: showProfilePhoto ?? this.showProfilePhoto,
      showBio: showBio ?? this.showBio,
      showAge: showAge ?? this.showAge,
      showPhone: showPhone ?? this.showPhone,
      showEmail: showEmail ?? this.showEmail,
      showFitPreferences: showFitPreferences ?? this.showFitPreferences,
      showPreferredStyles: showPreferredStyles ?? this.showPreferredStyles,
    );
  }

  bool get isPhotoVisible => showProfilePhoto;
  bool get isBioVisible => showBio;
  bool get isAgeVisible => showAge;
  bool get isPhoneVisible => showPhone;
  bool get isEmailVisible => showEmail;
  bool get isSizesVisible => showFitPreferences;
  bool get isFitPreferencesVisible => showFitPreferences;
  bool get isStylesVisible => showPreferredStyles;
  bool get isGenderVisible => false;
}

class UserProfileModel {
  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final int? age;
  final String? phoneNumber;
  final FitPreferencesModel fitPreferences;
  final List<String> preferredStyles;
  final ProfilePrivacySettingsModel privacySettings;
  final int sharedCommunitiesCount;
  final int sharedItemsCount;

  UserProfileModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    this.age,
    this.phoneNumber,
    this.fitPreferences = const FitPreferencesModel(),
    this.preferredStyles = const [],
    this.privacySettings = const ProfilePrivacySettingsModel(),
    this.sharedCommunitiesCount = 0,
    this.sharedItemsCount = 0,
  });

  String get initials {
    final parts = displayName.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (displayName.isNotEmpty) {
      return displayName.substring(0, displayName.length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'U';
  }

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    List<String> styles = [];
    if (json['preferred_styles'] is List) {
      styles = (json['preferred_styles'] as List).map((e) => e.toString()).toList();
    }

    return UserProfileModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['display_name'] as String? ?? 'Member',
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      age: json['age'] as int?,
      phoneNumber: json['phone_number'] as String?,
      fitPreferences: FitPreferencesModel.fromJson(json['fit_preferences'] as Map<String, dynamic>?),
      preferredStyles: styles,
      privacySettings: ProfilePrivacySettingsModel.fromJson(json['privacy_settings'] as Map<String, dynamic>?),
      sharedCommunitiesCount: json['shared_communities_count'] as int? ?? 0,
      sharedItemsCount: json['shared_items_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'bio': bio,
      'age': age,
      'phone_number': phoneNumber,
      'fit_preferences': fitPreferences.toJson(),
      'preferred_styles': preferredStyles,
      'privacy_settings': privacySettings.toJson(),
      'shared_communities_count': sharedCommunitiesCount,
      'shared_items_count': sharedItemsCount,
    };
  }
}
