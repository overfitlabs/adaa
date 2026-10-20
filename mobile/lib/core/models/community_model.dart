import 'wardrobe_item.dart';
import 'user_profile_model.dart';

class CommunityMembershipSummary {
  final String id;
  final String role; // owner, admin, member
  final String status; // requested, approved, rejected, removed
  final DateTime requestedAt;
  final DateTime? decidedAt;

  CommunityMembershipSummary({
    required this.id,
    required this.role,
    required this.status,
    required this.requestedAt,
    this.decidedAt,
  });

  factory CommunityMembershipSummary.fromJson(Map<String, dynamic> json) {
    return CommunityMembershipSummary(
      id: json['id'] as String,
      role: json['role'] as String? ?? 'member',
      status: json['status'] as String? ?? 'requested',
      requestedAt: json['requested_at'] != null
          ? DateTime.parse(json['requested_at'] as String)
          : DateTime.now(),
      decidedAt: json['decided_at'] != null
          ? DateTime.parse(json['decided_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'status': status,
      'requested_at': requestedAt.toIso8601String(),
      'decided_at': decidedAt?.toIso8601String(),
    };
  }
}

class CommunityModel {
  final String id;
  final String name;
  final String? description;
  final String creatorId;
  final String status;
  final bool isPrivate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int membersCount;
  final int listingsCount;
  final CommunityMembershipSummary? myMembership;

  CommunityModel({
    required this.id,
    required this.name,
    this.description,
    required this.creatorId,
    required this.status,
    this.isPrivate = true,
    required this.createdAt,
    required this.updatedAt,
    this.membersCount = 0,
    this.listingsCount = 0,
    this.myMembership,
  });

  bool get isApprovedMember => myMembership?.status == 'approved';
  bool get isPendingRequest => myMembership?.status == 'requested';
  bool get isAdminOrOwner =>
      isApprovedMember && (myMembership?.role == 'owner' || myMembership?.role == 'admin');
  bool get isOwner => isApprovedMember && myMembership?.role == 'owner';

  factory CommunityModel.fromJson(Map<String, dynamic> json) {
    return CommunityModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      creatorId: json['creator_id'] as String,
      status: json['status'] as String? ?? 'active',
      isPrivate: json['is_private'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      membersCount: json['members_count'] as int? ?? 0,
      listingsCount: json['listings_count'] as int? ?? 0,
      myMembership: json['my_membership'] != null
          ? CommunityMembershipSummary.fromJson(json['my_membership'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'creator_id': creatorId,
      'status': status,
      'is_private': isPrivate,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'members_count': membersCount,
      'listings_count': listingsCount,
      'my_membership': myMembership?.toJson(),
    };
  }
}

class CommunityMemberModel {
  final String id;
  final String communityId;
  final String userId;
  final String role; // owner, admin, member
  final String status; // requested, approved, rejected, removed
  final DateTime requestedAt;
  final DateTime? decidedAt;
  final String? decidedById;
  final DateTime createdAt;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;

  CommunityMemberModel({
    required this.id,
    required this.communityId,
    required this.userId,
    required this.role,
    required this.status,
    required this.requestedAt,
    this.decidedAt,
    this.decidedById,
    required this.createdAt,
    this.displayName,
    this.avatarUrl,
    this.bio,
  });

  String get resolvedName {
    if (displayName != null && displayName!.trim().isNotEmpty) {
      return displayName!.trim();
    }
    return 'Member (${userId.length >= 6 ? userId.substring(0, 6) : userId})';
  }

  String get initials {
    final name = resolvedName;
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (name.isNotEmpty) {
      return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'M';
  }

  factory CommunityMemberModel.fromJson(Map<String, dynamic> json) {
    return CommunityMemberModel(
      id: json['id'] as String,
      communityId: json['community_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String? ?? 'member',
      status: json['status'] as String? ?? 'requested',
      requestedAt: json['requested_at'] != null
          ? DateTime.parse(json['requested_at'] as String)
          : DateTime.now(),
      decidedAt: json['decided_at'] != null
          ? DateTime.parse(json['decided_at'] as String)
          : null,
      decidedById: json['decided_by_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'community_id': communityId,
      'user_id': userId,
      'role': role,
      'status': status,
      'requested_at': requestedAt.toIso8601String(),
      'decided_at': decidedAt?.toIso8601String(),
      'decided_by_id': decidedById,
      'created_at': createdAt.toIso8601String(),
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'bio': bio,
    };
  }
}

class CommunityListingModel {
  final String id;
  final String communityId;
  final String? communityName;
  final String wardrobeItemId;
  final String ownerId;
  final String? ownerName;
  final String? ownerAvatarUrl;
  final String? ownerBio;
  final String status; // active, unlisted
  final String? notes;
  final DateTime createdAt;
  final WardrobeItem? item;

  CommunityListingModel({
    required this.id,
    required this.communityId,
    this.communityName,
    required this.wardrobeItemId,
    required this.ownerId,
    this.ownerName,
    this.ownerAvatarUrl,
    this.ownerBio,
    required this.status,
    this.notes,
    required this.createdAt,
    this.item,
  });

  String get resolvedOwnerName {
    if (ownerName != null && ownerName!.trim().isNotEmpty) {
      return ownerName!.trim();
    }
    return 'Member (${ownerId.length >= 6 ? ownerId.substring(0, 6) : ownerId})';
  }

  String get ownerInitials {
    final name = resolvedOwnerName;
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (name.isNotEmpty) {
      return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'M';
  }

  factory CommunityListingModel.fromJson(Map<String, dynamic> json) {
    return CommunityListingModel(
      id: json['id'] as String,
      communityId: json['community_id'] as String,
      communityName: json['community_name'] as String?,
      wardrobeItemId: json['wardrobe_item_id'] as String,
      ownerId: json['owner_id'] as String,
      ownerName: json['owner_name'] as String?,
      ownerAvatarUrl: json['owner_avatar_url'] as String?,
      ownerBio: json['owner_bio'] as String?,
      status: json['status'] as String? ?? 'active',
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      item: json['item'] != null
          ? WardrobeItem.fromJson(json['item'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'community_id': communityId,
      'community_name': communityName,
      'wardrobe_item_id': wardrobeItemId,
      'owner_id': ownerId,
      'owner_name': ownerName,
      'owner_avatar_url': ownerAvatarUrl,
      'owner_bio': ownerBio,
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'item': item?.toJson(),
    };
  }
}

class SharedClosetItemModel {
  final String listingId;
  final String communityId;
  final String communityName;
  final String ownerId;
  final String? ownerName;
  final String? ownerAvatarUrl;
  final String? ownerBio;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final WardrobeItem item;

  SharedClosetItemModel({
    required this.listingId,
    required this.communityId,
    required this.communityName,
    required this.ownerId,
    this.ownerName,
    this.ownerAvatarUrl,
    this.ownerBio,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.item,
  });

  String get resolvedOwnerName {
    if (ownerName != null && ownerName!.trim().isNotEmpty) {
      return ownerName!.trim();
    }
    return 'Member (${ownerId.length >= 6 ? ownerId.substring(0, 6) : ownerId})';
  }

  String get ownerInitials {
    final name = resolvedOwnerName;
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (name.isNotEmpty) {
      return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'M';
  }

  factory SharedClosetItemModel.fromJson(Map<String, dynamic> json) {
    return SharedClosetItemModel(
      listingId: json['listing_id'] as String,
      communityId: json['community_id'] as String,
      communityName: json['community_name'] as String? ?? 'Community',
      ownerId: json['owner_id'] as String,
      ownerName: json['owner_name'] as String?,
      ownerAvatarUrl: json['owner_avatar_url'] as String?,
      ownerBio: json['owner_bio'] as String?,
      status: json['status'] as String? ?? 'active',
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      item: WardrobeItem.fromJson(json['item'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'listing_id': listingId,
      'community_id': communityId,
      'community_name': communityName,
      'owner_id': ownerId,
      'owner_name': ownerName,
      'owner_avatar_url': ownerAvatarUrl,
      'owner_bio': ownerBio,
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'item': item.toJson(),
    };
  }
}

class ItemRequestModel {
  final String id;
  final String listingId;
  final String wardrobeItemId;
  final String communityId;
  final String? communityName;
  final String requesterId;
  final String? requesterName;
  final String? requesterAvatarUrl;
  final String ownerId;
  final String? ownerName;
  final String? ownerAvatarUrl;
  final String status; // pending, accepted, declined, cancelled, completed
  final String? message;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? respondedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final WardrobeItem? item;

  ItemRequestModel({
    required this.id,
    required this.listingId,
    required this.wardrobeItemId,
    required this.communityId,
    this.communityName,
    required this.requesterId,
    this.requesterName,
    this.requesterAvatarUrl,
    required this.ownerId,
    this.ownerName,
    this.ownerAvatarUrl,
    required this.status,
    this.message,
    this.startDate,
    this.endDate,
    this.respondedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    this.item,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';
  bool get isCancelled => status == 'cancelled';
  bool get isCompleted => status == 'completed';
  bool get isTerminal => isDeclined || isCancelled || isCompleted;

  String get resolvedRequesterName {
    if (requesterName != null && requesterName!.trim().isNotEmpty) {
      return requesterName!.trim();
    }
    return 'Member (${requesterId.length >= 6 ? requesterId.substring(0, 6) : requesterId})';
  }

  String get resolvedOwnerName {
    if (ownerName != null && ownerName!.trim().isNotEmpty) {
      return ownerName!.trim();
    }
    return 'Member (${ownerId.length >= 6 ? ownerId.substring(0, 6) : ownerId})';
  }

  String get dateRangeSummary {
    if (startDate == null && endDate == null) {
      return 'Flexible dates';
    }
    if (startDate != null && endDate != null) {
      return '${_formatMonthDay(startDate!)} - ${_formatMonthDay(endDate!)}';
    }
    if (startDate != null) {
      return 'From ${_formatMonthDay(startDate!)}';
    }
    return 'Until ${_formatMonthDay(endDate!)}';
  }

  static String _formatMonthDay(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  factory ItemRequestModel.fromJson(Map<String, dynamic> json) {
    return ItemRequestModel(
      id: json['id'] as String,
      listingId: json['listing_id'] as String,
      wardrobeItemId: json['wardrobe_item_id'] as String,
      communityId: json['community_id'] as String,
      communityName: json['community_name'] as String?,
      requesterId: json['requester_id'] as String,
      requesterName: json['requester_name'] as String?,
      requesterAvatarUrl: json['requester_avatar_url'] as String?,
      ownerId: json['owner_id'] as String,
      ownerName: json['owner_name'] as String?,
      ownerAvatarUrl: json['owner_avatar_url'] as String?,
      status: json['status'] as String? ?? 'pending',
      message: json['message'] as String?,
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date'] as String) : null,
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date'] as String) : null,
      respondedAt: json['responded_at'] != null ? DateTime.parse(json['responded_at'] as String) : null,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : DateTime.now(),
      item: json['item'] != null ? WardrobeItem.fromJson(json['item'] as Map<String, dynamic>) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'listing_id': listingId,
      'wardrobe_item_id': wardrobeItemId,
      'community_id': communityId,
      'community_name': communityName,
      'requester_id': requesterId,
      'requester_name': requesterName,
      'requester_avatar_url': requesterAvatarUrl,
      'owner_id': ownerId,
      'owner_name': ownerName,
      'owner_avatar_url': ownerAvatarUrl,
      'status': status,
      'message': message,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'responded_at': respondedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'item': item?.toJson(),
    };
  }
}

class PublicUserProfileModel {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final int? age;
  final String? phoneNumber;
  final String? email;
  final FitPreferencesModel? fitPreferences;
  final List<String>? preferredStyles;
  final int sharedCommunitiesCount;
  final int sharedItemsCount;

  PublicUserProfileModel({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    this.age,
    this.phoneNumber,
    this.email,
    this.fitPreferences,
    this.preferredStyles,
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
    return 'M';
  }

  factory PublicUserProfileModel.fromJson(Map<String, dynamic> json) {
    List<String>? styles;
    if (json['preferred_styles'] is List) {
      styles = (json['preferred_styles'] as List).map((e) => e.toString()).toList();
    }

    FitPreferencesModel? fit;
    if (json['fit_preferences'] is Map<String, dynamic>) {
      fit = FitPreferencesModel.fromJson(json['fit_preferences'] as Map<String, dynamic>);
    }

    return PublicUserProfileModel(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? 'Member',
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      age: json['age'] as int?,
      phoneNumber: json['phone_number'] as String?,
      email: json['email'] as String?,
      fitPreferences: fit,
      preferredStyles: styles,
      sharedCommunitiesCount: json['shared_communities_count'] as int? ?? 0,
      sharedItemsCount: json['shared_items_count'] as int? ?? 0,
    );
  }
}

