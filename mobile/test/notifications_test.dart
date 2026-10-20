import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wardrobelens/core/auth/session_manager.dart';
import 'package:wardrobelens/core/models/notification_model.dart';
import 'package:wardrobelens/features/home/screens/home_screen.dart';
import 'package:wardrobelens/features/notifications/screens/notifications_screen.dart';
import 'package:wardrobelens/state/analysis_provider.dart';
import 'package:wardrobelens/state/auth_provider.dart';
import 'package:wardrobelens/state/community_provider.dart';
import 'package:wardrobelens/state/notification_provider.dart';
import 'package:wardrobelens/state/outfits_provider.dart';
import 'package:wardrobelens/state/profile_provider.dart';
import 'package:wardrobelens/state/tryon_provider.dart';
import 'package:wardrobelens/state/wardrobe_provider.dart';

class MockAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  User? user = const User(
    id: 'user-notif-tester',
    appMetadata: {},
    userMetadata: {'full_name': 'Aarav Mehta'},
    aud: 'authenticated',
    createdAt: '2026-10-20T10:00:00Z',
    email: 'aarav@adaa.test',
  );

  @override
  bool isAuthenticated = true;

  @override
  String get displayName => 'Aarav Mehta';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('NotificationModel tests', () {
    test('NotificationModel fromJson and toJson preserves all fields', () {
      final json = {
        'id': 'notif-1',
        'user_id': 'user-123',
        'actor_id': 'user-456',
        'actor_name': 'Diya Sen',
        'event_type': 'borrow_request_created',
        'title': 'New borrow request',
        'message': 'Diya Sen requested to borrow "Silk Kurta".',
        'reference_id': 'req-999',
        'reference_type': 'borrow_request',
        'community_id': 'comm-777',
        'is_read': false,
        'created_at': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
      };

      final notif = NotificationModel.fromJson(json);
      expect(notif.id, 'notif-1');
      expect(notif.userId, 'user-123');
      expect(notif.actorName, 'Diya Sen');
      expect(notif.eventType, 'borrow_request_created');
      expect(notif.isRead, false);
      expect(notif.isBorrowRequest, true);
      expect(notif.isCommunity, false);
      expect(notif.iconData, Icons.handshake_outlined);
      expect(notif.formattedRelativeTime, contains('5m ago'));

      final outJson = notif.toJson();
      expect(outJson['id'], 'notif-1');
      expect(outJson['user_id'], 'user-123');
      expect(outJson['event_type'], 'borrow_request_created');
    });

    test('NotificationModel relative time formats properly', () {
      final now = DateTime.now();

      final justNow = NotificationModel(
        id: '1',
        userId: 'u',
        eventType: 'test',
        title: 'T',
        message: 'M',
        createdAt: now.subtract(const Duration(seconds: 20)),
      );
      expect(justNow.formattedRelativeTime, 'just now');

      final twoHours = NotificationModel(
        id: '2',
        userId: 'u',
        eventType: 'test',
        title: 'T',
        message: 'M',
        createdAt: now.subtract(const Duration(hours: 2)),
      );
      expect(twoHours.formattedRelativeTime, '2h ago');

      final yesterday = NotificationModel(
        id: '3',
        userId: 'u',
        eventType: 'test',
        title: 'T',
        message: 'M',
        createdAt: now.subtract(const Duration(days: 1)),
      );
      expect(yesterday.formattedRelativeTime, 'yesterday');
    });
  });

  group('NotificationProvider tests', () {
    test('NotificationProvider updates unread count and read state correctly', () {
      final prov = NotificationProvider();
      final n1 = NotificationModel(
        id: 'n1',
        userId: 'u',
        eventType: 'borrow_request_created',
        title: 'T1',
        message: 'M1',
        isRead: false,
        createdAt: DateTime.now(),
      );
      final n2 = NotificationModel(
        id: 'n2',
        userId: 'u',
        eventType: 'borrow_request_accepted',
        title: 'T2',
        message: 'M2',
        isRead: false,
        createdAt: DateTime.now(),
      );

      prov.notifications = [n1, n2];
      expect(prov.unreadCount, 2);
      expect(prov.unreadNotifications.length, 2);

      // Mark n1 as read
      prov.markAsRead('n1');
      expect(prov.unreadCount, 1);
      expect(prov.notifications.firstWhere((n) => n.id == 'n1').isRead, true);
      expect(prov.notifications.firstWhere((n) => n.id == 'n2').isRead, false);

      // Mark all as read
      prov.markAllAsRead();
      expect(prov.unreadCount, 0);
      expect(prov.notifications.every((n) => n.isRead), true);

      // Clear for session isolation
      prov.clear();
      expect(prov.notifications.isEmpty, true);
      expect(prov.unreadCount, 0);
      expect(prov.isLoading, false);
      expect(prov.error, null);
    });
  });

  group('NotificationsScreen Widget tests', () {
    testWidgets('renders empty state when no activity exists', (tester) async {
      final notifProv = NotificationProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<NotificationProvider>.value(value: notifProv),
            ChangeNotifierProvider<CommunityProvider>(create: (_) => CommunityProvider()),
          ],
          child: const MaterialApp(
            home: NotificationsScreen(autoLoad: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('activity'), findsOneWidget);
      expect(find.text('no activity yet'), findsOneWidget);
      expect(find.text('All (0)'), findsOneWidget);
      expect(find.text('Unread (0)'), findsOneWidget);
    });

    testWidgets('renders notifications and filters by unread', (tester) async {
      final notifProv = NotificationProvider();
      notifProv.notifications = [
        NotificationModel(
          id: 'n1',
          userId: 'u',
          eventType: 'borrow_request_created',
          title: 'New borrow request',
          message: 'Ananya requested your Linen Shirt.',
          isRead: false,
          referenceType: 'borrow_request',
          createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        ),
        NotificationModel(
          id: 'n2',
          userId: 'u',
          eventType: 'membership_approved',
          title: 'Membership approved',
          message: 'Your request to join Campus Closet was approved!',
          isRead: true,
          referenceType: 'community',
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
      ];

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<NotificationProvider>.value(value: notifProv),
            ChangeNotifierProvider<CommunityProvider>(create: (_) => CommunityProvider()),
          ],
          child: const MaterialApp(
            home: NotificationsScreen(autoLoad: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both notifications present in 'All' view
      expect(find.text('New borrow request'), findsOneWidget);
      expect(find.text('Membership approved'), findsOneWidget);
      expect(find.text('Mark all read'), findsOneWidget);

      // Tap on 'Unread (1)' chip
      await tester.tap(find.text('Unread (1)'));
      await tester.pumpAndSettle();

      // Only unread notification is shown
      expect(find.text('New borrow request'), findsOneWidget);
      expect(find.text('Membership approved'), findsNothing);
    });
  });

  group('HomeScreen & Session Isolation tests', () {
    testWidgets('HomeScreen shows notification bell icon with badge count', (tester) async {
      final notifProv = NotificationProvider();
      notifProv.unreadCount = 4;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => MockAuthProvider()),
            ChangeNotifierProvider<WardrobeProvider>(create: (_) => WardrobeProvider()),
            ChangeNotifierProvider<CommunityProvider>(create: (_) => CommunityProvider()),
            ChangeNotifierProvider<AnalysisProvider>(create: (_) => AnalysisProvider()),
            ChangeNotifierProvider<OutfitsProvider>(create: (_) => OutfitsProvider()),
            ChangeNotifierProvider<TryOnProvider>(create: (_) => TryOnProvider()),
            ChangeNotifierProvider<ProfileProvider>(create: (_) => ProfileProvider()),
            ChangeNotifierProvider<NotificationProvider>.value(value: notifProv),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );
      await tester.pump();

      // Notification icon and unread count badge
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('SessionManager.clearAllUserData wipes notifications and unread badge', (tester) async {
      final notifProv = NotificationProvider();
      notifProv.notifications = [
        NotificationModel(
          id: 'n1',
          userId: 'u',
          eventType: 'borrow_request_created',
          title: 'Title',
          message: 'Message',
          isRead: false,
          createdAt: DateTime.now(),
        ),
      ];
      expect(notifProv.notifications.length, 1);
      expect(notifProv.unreadCount, 1);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => MockAuthProvider()),
            ChangeNotifierProvider<WardrobeProvider>(create: (_) => WardrobeProvider()),
            ChangeNotifierProvider<CommunityProvider>(create: (_) => CommunityProvider()),
            ChangeNotifierProvider<AnalysisProvider>(create: (_) => AnalysisProvider()),
            ChangeNotifierProvider<OutfitsProvider>(create: (_) => OutfitsProvider()),
            ChangeNotifierProvider<TryOnProvider>(create: (_) => TryOnProvider()),
            ChangeNotifierProvider<ProfileProvider>(create: (_) => ProfileProvider()),
            ChangeNotifierProvider<NotificationProvider>.value(value: notifProv),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      SessionManager.clearAllUserData(context);
                    },
                    child: const Text('Clear Session'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Trigger session clear
      await tester.tap(find.text('Clear Session'));
      await tester.pump();

      // Notification state must be completely purged
      expect(notifProv.notifications.isEmpty, true);
      expect(notifProv.unreadCount, 0);
    });
  });
}
