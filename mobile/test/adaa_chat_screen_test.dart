import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wardrobelens/core/models/stylist_chat_model.dart';
import 'package:wardrobelens/core/models/wardrobe_item.dart';
import 'package:wardrobelens/core/utils/speech_cleaner.dart';
import 'package:wardrobelens/features/styling/screens/adaa_chat_screen.dart';
import 'package:wardrobelens/features/home/screens/home_screen.dart';
import 'package:wardrobelens/features/wardrobe/widgets/wardrobe_bottom_sheet.dart';
import 'package:wardrobelens/state/analysis_provider.dart';
import 'package:wardrobelens/state/auth_provider.dart';
import 'package:wardrobelens/state/chat_provider.dart';
import 'package:wardrobelens/state/community_provider.dart';
import 'package:wardrobelens/state/notification_provider.dart';
import 'package:wardrobelens/state/outfits_provider.dart';
import 'package:wardrobelens/state/profile_provider.dart';
import 'package:wardrobelens/state/stylist_provider.dart';
import 'package:wardrobelens/state/tryon_provider.dart';
import 'package:wardrobelens/state/wardrobe_provider.dart';

Widget createTestChatApp({
  required ChatProvider chatProvider,
  required WardrobeProvider wardrobeProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
      ChangeNotifierProvider<WardrobeProvider>.value(value: wardrobeProvider),
      ChangeNotifierProvider<AnalysisProvider>(
        create: (_) => AnalysisProvider(),
      ),
      ChangeNotifierProvider<TryOnProvider>(create: (_) => TryOnProvider()),
      ChangeNotifierProvider<CommunityProvider>(
        create: (_) => CommunityProvider(),
      ),
      ChangeNotifierProvider<ProfileProvider>(create: (_) => ProfileProvider()),
      ChangeNotifierProvider<NotificationProvider>(
        create: (_) => NotificationProvider(),
      ),
      ChangeNotifierProvider<OutfitsProvider>(create: (_) => OutfitsProvider()),
      ChangeNotifierProvider<StylistProvider>(create: (_) => StylistProvider()),
      ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
    ],
    child: const MaterialApp(home: AdaaChatScreen()),
  );
}

Widget createTestHomeApp({
  required WardrobeProvider wardrobeProvider,
  required OutfitsProvider outfitsProvider,
  required ChatProvider chatProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
      ChangeNotifierProvider<WardrobeProvider>.value(value: wardrobeProvider),
      ChangeNotifierProvider<AnalysisProvider>(
        create: (_) => AnalysisProvider(),
      ),
      ChangeNotifierProvider<TryOnProvider>(create: (_) => TryOnProvider()),
      ChangeNotifierProvider<CommunityProvider>(
        create: (_) => CommunityProvider(),
      ),
      ChangeNotifierProvider<ProfileProvider>(create: (_) => ProfileProvider()),
      ChangeNotifierProvider<NotificationProvider>(
        create: (_) => NotificationProvider(),
      ),
      ChangeNotifierProvider<OutfitsProvider>.value(value: outfitsProvider),
      ChangeNotifierProvider<StylistProvider>(create: (_) => StylistProvider()),
      ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
    ],
    child: const MaterialApp(home: HomeScreen()),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChatProvider chat;
  late WardrobeProvider wardrobe;
  late OutfitsProvider outfits;

  setUp(() {
    chat = ChatProvider();
    wardrobe = WardrobeProvider();
    outfits = OutfitsProvider();
  });

  group('SpeechCleaner Unit Tests', () {
    test('SpeechCleaner strips markdown, emojis, parenthesized UUIDs, and list markers', () {
      const rawText =
          '### Curated Look\n'
          '1. **Lime Green Top (401c6f94-e359-4b02-8b77-079c63fcf7ae):** Fitted jersey top with chic square neck! 💅\n'
          '* Pair with `denim jeans` for an effortless vibe ✨';

      final clean = SpeechCleaner.cleanForSpeech(rawText);

      // Should not contain markdown markers
      expect(clean.contains('###'), isFalse);
      expect(clean.contains('**'), isFalse);
      expect(clean.contains('`'), isFalse);

      // Should not contain UUID
      expect(clean.contains('401c6f94-e359-4b02-8b77-079c63fcf7ae'), isFalse);

      // Should not contain emojis
      expect(clean.contains('💅'), isFalse);
      expect(clean.contains('✨'), isFalse);

      // Should retain garment name and text
      expect(clean.contains('Lime Green Top'), isTrue);
      expect(clean.contains('Fitted jersey top with chic square neck!'), isTrue);
    });
  });

  testWidgets(
    'AdaaChatScreen renders empty state with luxury concierge and starter chips',
    (tester) async {
      await tester.pumpWidget(
        createTestChatApp(chatProvider: chat, wardrobeProvider: wardrobe),
      );
      await tester.pumpAndSettle();

      // Verify Title & Subtitle
      expect(find.text('STYLIST'), findsOneWidget);
      expect(find.text('Ask adaa'), findsOneWidget);
      expect(find.text('STARTER SUGGESTIONS'), findsOneWidget);
      expect(find.text('Style an outfit for dinner tonight'), findsOneWidget);

      // Verify Composer and Voice Mic
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      expect(find.byIcon(Icons.mic_none), findsOneWidget);

      // Verify View Wardrobe button in AppBar and Browse Closet button
      expect(find.byIcon(Icons.checkroom_outlined), findsOneWidget);
      expect(find.text('Browse Closet'), findsOneWidget);
      expect(find.text('Try Hands-free Mode'), findsOneWidget);
    },
  );

  testWidgets('HomeScreen renders persistent Ask adaa hero card entry point', (
    tester,
  ) async {
    await tester.pumpWidget(
      createTestHomeApp(
        wardrobeProvider: wardrobe,
        outfitsProvider: outfits,
        chatProvider: chat,
      ),
    );
    await tester.pumpAndSettle();

    // Verify Ask adaa hero card is rendered prominently
    expect(find.text('Ask adaa'), findsWidgets);
    expect(find.text('AI STYLIST'), findsWidgets);
    expect(
      find.text('What should I wear? Outfit pairings & styling'),
      findsOneWidget,
    );
  });

  testWidgets(
    'AdaaChatScreen displays assistant Markdown message, resolves UUIDs, and has speaker button',
    (tester) async {
      final testGarment = WardrobeItem(
        id: '11112222-3333-4444-5555-666677778888',
        name: 'Tailored Navy Blazer',
        category: 'outerwear',
        primaryColor: 'navy',
        imagePath: 'wardrobe/blazer.jpg',
        imageUrl: 'http://test.com/blazer.jpg',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      wardrobe.items.add(testGarment);

      // Seed mock message into ChatProvider with raw UUID and markdown list
      chat.addMessageForTesting(
        ChatMessageModel(role: 'user', content: 'How should I wear my blazer?'),
      );
      final asstMsg = ChatMessageModel(
        role: 'assistant',
        content: 'Here is your styling advice:\n* Pair 11112222-3333-4444-5555-666677778888 with **slim chinos**.\n* Finish with clean leather sneakers.',
        suggestedItems: [testGarment],
        suggestedAcquisitions: ['Crisp White T-Shirt'],
        actions: [
          StylistActionModel(
            actionType: 'start_tryon',
            title: 'Try On Blazer',
            payload: {'item_id': testGarment.id},
          ),
          StylistActionModel(
            actionType: 'open_wardrobe',
            title: 'Open Wardrobe',
          ),
        ],
      );
      chat.addMessageForTesting(asstMsg);

      await tester.pumpWidget(
        createTestChatApp(chatProvider: chat, wardrobeProvider: wardrobe),
      );
      await tester.pumpAndSettle();

      // Verify MarkdownBody is rendered
      expect(find.byType(MarkdownBody), findsOneWidget);

      // Verify raw UUID is resolved to human-readable garment name
      expect(find.textContaining('11112222-3333-4444-5555-666677778888'), findsNothing);

      // Verify speaker button on assistant message
      expect(find.byTooltip('Read response aloud'), findsOneWidget);

      // Verify action buttons
      expect(find.text('Try On Blazer'), findsOneWidget);
      expect(find.text('Open Wardrobe'), findsOneWidget);
    },
  );

  testWidgets('TTS playback: speaker button triggers speech and updates status bar', (
    tester,
  ) async {
    final asstMsg = ChatMessageModel(
      role: 'assistant',
      content: 'Your blazer looks iconic with dark slim chinos.',
    );
    chat.addMessageForTesting(asstMsg);

    await tester.pumpWidget(
      createTestChatApp(chatProvider: chat, wardrobeProvider: wardrobe),
    );
    await tester.pumpAndSettle();

    // Tap speaker icon on assistant message
    expect(find.byTooltip('Read response aloud'), findsOneWidget);

    // Simulate playback via test helper
    chat.simulateTtsPlayback(messageId: asstMsg.id);
    await tester.pump();

    // Verify speaking state is displayed in voice status bar
    expect(chat.isSpeaking, isTrue);
    expect(find.text('adaa is speaking...'), findsOneWidget);
    expect(find.byTooltip('Stop speaking'), findsWidgets);

    // Tap stop button
    await tester.tap(find.byTooltip('Stop speaking').first);
    await tester.pump();

    expect(chat.isSpeaking, isFalse);
    expect(chat.currentlySpeakingMessageId, isNull);
  });

  testWidgets('Voice interaction: persistent status bar, live transcript, and cancel', (
    tester,
  ) async {
    await tester.pumpWidget(
      createTestChatApp(chatProvider: chat, wardrobeProvider: wardrobe),
    );
    await tester.pumpAndSettle();

    // Initially no voice status bar
    expect(find.text('Listening...'), findsNothing);

    // Set listening state
    chat.setLiveTranscript('style my linen shirt');
    chat.setVoiceStatus('Listening...');
    await tester.pump();

    // Tap Cancel
    chat.cancelListening();
    await tester.pump();

    expect(chat.isListening, isFalse);
    expect(chat.liveTranscript, isEmpty);
  });

  testWidgets('Hands-free conversation mode toggle and exit', (
    tester,
  ) async {
    await tester.pumpWidget(
      createTestChatApp(chatProvider: chat, wardrobeProvider: wardrobe),
    );
    await tester.pumpAndSettle();

    // Toggle Hands-free Mode on via AppBar action
    final handsFreeButton = find.byTooltip('Start Hands-free Conversation');
    expect(handsFreeButton, findsOneWidget);

    await tester.tap(handsFreeButton);
    await tester.pump();

    expect(chat.isHandsFreeMode, isTrue);
    expect(find.text('HANDS-FREE'), findsOneWidget);

    // Exit hands-free mode via the voice status bar button
    expect(find.text('Exit Hands-free'), findsOneWidget);
    await tester.tap(find.text('Exit Hands-free'));
    await tester.pump();

    expect(chat.isHandsFreeMode, isFalse);
  });

  testWidgets('Auto voice replies toggle switches state', (
    tester,
  ) async {
    await tester.pumpWidget(
      createTestChatApp(chatProvider: chat, wardrobeProvider: wardrobe),
    );
    await tester.pumpAndSettle();

    // Initially auto voice replies is enabled
    expect(chat.autoVoiceRepliesEnabled, isTrue);
    expect(find.byTooltip('Spoken replies enabled (tap to mute)'), findsOneWidget);

    // Tap to mute
    await tester.tap(find.byTooltip('Spoken replies enabled (tap to mute)'));
    await tester.pump();

    expect(chat.autoVoiceRepliesEnabled, isFalse);
    expect(find.byTooltip('Spoken replies muted (tap to enable)'), findsOneWidget);
  });

  testWidgets('Voice interaction: graceful handling of permission denial or unsupported platform', (
    tester,
  ) async {
    await tester.pumpWidget(
      createTestChatApp(chatProvider: chat, wardrobeProvider: wardrobe),
    );
    await tester.pumpAndSettle();

    // Simulate permission denial / unsupported
    chat.simulateVoiceError(
      'Speech recognition is not available or permission was denied on this platform.',
    );
    await tester.pump();

    // Verify truthful error status is displayed
    expect(
      find.text('Speech recognition is not available or permission was denied on this platform.'),
      findsOneWidget,
    );

    // Verify dismiss button works
    expect(find.byTooltip('Dismiss status'), findsOneWidget);
    await tester.tap(find.byTooltip('Dismiss status'));
    await tester.pump();

    expect(find.text('Speech recognition is not available or permission was denied on this platform.'), findsNothing);
  });

  testWidgets('View Wardrobe opens WardrobeBottomSheet without replacing the chat screen', (
    tester,
  ) async {
    final item1 = WardrobeItem(
      id: 'item-1',
      name: 'White Oxford Shirt',
      category: 'tops',
      primaryColor: 'white',
      imagePath: 'wardrobe/oxford.jpg',
      imageUrl: 'http://test.com/oxford.jpg',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    wardrobe.items.add(item1);

    await tester.pumpWidget(
      createTestChatApp(chatProvider: chat, wardrobeProvider: wardrobe),
    );
    await tester.pumpAndSettle();

    // Tap the View Wardrobe icon in the AppBar
    await tester.tap(find.byTooltip('View Wardrobe'));
    await tester.pumpAndSettle();

    // Verify WardrobeBottomSheet is opened
    expect(find.byType(WardrobeBottomSheet), findsOneWidget);
    expect(find.text('Digital Wardrobe'), findsOneWidget);
    expect(find.text('White Oxford Shirt'), findsOneWidget);

    // Close sheet via Close button
    await tester.tap(find.byTooltip('Close Wardrobe'));
    await tester.pumpAndSettle();

    // Verify WardrobeBottomSheet is dismissed and chat screen is still intact
    expect(find.byType(WardrobeBottomSheet), findsNothing);
    expect(find.byType(AdaaChatScreen), findsOneWidget);
    expect(find.text('Ask adaa'), findsOneWidget);
  });

  testWidgets('In-app safe back navigation handles root route safely', (
    tester,
  ) async {
    await tester.pumpWidget(
      createTestChatApp(chatProvider: chat, wardrobeProvider: wardrobe),
    );
    await tester.pumpAndSettle();

    // Tap back button when canPop is false
    final backButton = find.byTooltip('Back');
    expect(backButton, findsOneWidget);

    await tester.tap(backButton);
    await tester.pumpAndSettle();

    // Should safely navigate to HomeScreen rather than black screen / crash
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  group('ChatProvider End-of-Speech & Voice Mode Lifecycle Tests', () {
    test('Empty transcript does not create user or assistant messages', () async {
      expect(chat.messages.isEmpty, isTrue);

      // Simulate empty voice input
      await chat.stopListening(submit: true);

      expect(chat.messages.isEmpty, isTrue);
      expect(chat.voiceStatus, contains("Couldn't hear that"));
    });

    test('Cancellation resets voice state and discards pending transcript', () async {
      chat.setLiveTranscript('unsubmitted thought...');
      expect(chat.liveTranscript, 'unsubmitted thought...');

      await chat.cancelListening();

      expect(chat.liveTranscript, isEmpty);
      expect(chat.voiceState, VoiceState.idle);
      expect(chat.messages.isEmpty, isTrue);
    });

    test('Hands-free mode toggle enables auto-replies and starts/exits cleanly', () {
      expect(chat.isHandsFreeMode, isFalse);

      chat.setHandsFreeMode(true);
      expect(chat.isHandsFreeMode, isTrue);
      expect(chat.autoVoiceRepliesEnabled, isTrue);

      chat.setHandsFreeMode(false);
      expect(chat.isHandsFreeMode, isFalse);
    });

    test('Microphone capture is stopped before speaking to prevent echo loops', () async {
      final msg = ChatMessageModel(role: 'assistant', content: 'Tailored trousers');
      chat.addMessageForTesting(msg);

      // Simulate speech playback
      chat.simulateTtsPlayback(messageId: msg.id);

      expect(chat.isSpeaking, isTrue);
      expect(chat.isListening, isFalse);

      await chat.stopSpeaking();
      expect(chat.isSpeaking, isFalse);
    });
  });
}
