import 'wardrobe_item.dart';

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
  });

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
    };
  }
}

class CommunityListingModel {
  final String id;
  final String communityId;
  final String? communityName;
  final String wardrobeItemId;
  final String ownerId;
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
    required this.status,
    this.notes,
    required this.createdAt,
    this.item,
  });

  factory CommunityListingModel.fromJson(Map<String, dynamic> json) {
    return CommunityListingModel(
      id: json['id'] as String,
      communityId: json['community_id'] as String,
      communityName: json['community_name'] as String?,
      wardrobeItemId: json['wardrobe_item_id'] as String,
      ownerId: json['owner_id'] as String,
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
  final String status;
  final String? notes;
  final DateTime createdAt;
  final WardrobeItem item;

  SharedClosetItemModel({
    required this.listingId,
    required this.communityId,
    required this.communityName,
    required this.ownerId,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.item,
  });

  factory SharedClosetItemModel.fromJson(Map<String, dynamic> json) {
    return SharedClosetItemModel(
      listingId: json['listing_id'] as String,
      communityId: json['community_id'] as String,
      communityName: json['community_name'] as String? ?? 'Community',
      ownerId: json['owner_id'] as String,
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
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'item': item.toJson(),
    };
  }
}
