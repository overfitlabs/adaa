import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';

import '../../../core/models/wardrobe_item.dart';
import '../../../core/models/stylist_chat_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/private_image_view.dart';
import '../../../core/widgets/adaa_wordmark.dart';
import '../../../state/chat_provider.dart';
import '../../../state/wardrobe_provider.dart';
import '../../home/screens/home_screen.dart';
import '../../tryon/screens/tryon_screen.dart';
import '../../wardrobe/screens/wardrobe_detail_screen.dart';
import '../../wardrobe/screens/add_wardrobe_item_screen.dart';
import '../../wardrobe/widgets/wardrobe_bottom_sheet.dart';

class AdaaChatScreen extends StatefulWidget {
  final String? initialPrompt;

  const AdaaChatScreen({super.key, this.initialPrompt});

  @override
  State<AdaaChatScreen> createState() => _AdaaChatScreenState();
}

class _AdaaChatScreenState extends State<AdaaChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    if (widget.initialPrompt != null &&
        widget.initialPrompt!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ChatProvider>().sendMessage(widget.initialPrompt!);
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _syncPulseAnimation(bool shouldAnimate) {
    if (shouldAnimate) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.value = 0.0;
      }
    }
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      return;
    }

    _textController.clear();
    context.read<ChatProvider>().sendMessage(text);
    _scrollToBottom();
  }

  void _handleVoiceToggle(ChatProvider chatProv) {
    if (chatProv.isSpeaking) {
      chatProv.stopSpeaking();
    } else if (chatProv.isListening) {
      chatProv.stopListening(submit: true);
    } else {
      chatProv.startListening(onTranscriptUpdate: (_) => _scrollToBottom());
    }
  }

  void _handleAction(StylistActionModel action) {
    switch (action.actionType) {
      case 'start_tryon':
        final itemId = action.payload['item_id'] as String?;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TryOnScreen(prefilledWardrobeItemId: itemId),
          ),
        );
        break;

      case 'view_garment':
        final itemId = action.payload['item_id'] as String?;
        if (itemId != null) {
          final wardrobe = context.read<WardrobeProvider>();
          final item = wardrobe.items.firstWhere(
            (i) => i.id == itemId,
            orElse: () => WardrobeItem(
              id: itemId,
              name: action.title.replaceFirst('View ', ''),
              category: 'garment',
              primaryColor: 'neutral',
              imagePath: '',
              imageUrl: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => WardrobeDetailScreen(item: item)),
          );
        }
        break;

      case 'open_scanner':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddWardrobeItemScreen()),
        );
        break;

      case 'open_wardrobe':
        WardrobeBottomSheet.show(
          context,
          onItemSelected: (item) {
            _textController.text = 'Style an outfit featuring my ${item.name}';
          },
        );
        break;

      default:
        break;
    }
  }

  void _openWardrobeBottomSheet() {
    WardrobeBottomSheet.show(
      context,
      onItemSelected: (item) {
        _textController.text = 'Style an outfit featuring my ${item.name}';
      },
    );
  }

  void _handleSafeBack() {
    final chatProv = context.read<ChatProvider>();
    chatProv.stopAllVoice();

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  String _formatAssistantContent(
    String rawContent,
    List<WardrobeItem> userItems,
  ) {
    var formatted = rawContent;

    // 1. Strip parenthesized or bracketed UUIDs like '(401c6f94-e359-4b02-8b77-079c63fcf7ae)' or '[...]'
    final parenUuidRegex = RegExp(
      r'\s*[\(\[]\s*[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\s*[\)\]]',
    );
    formatted = formatted.replaceAll(parenUuidRegex, '');

    // 2. Resolve known user wardrobe items into bold names
    for (final item in userItems) {
      if (formatted.contains(item.id)) {
        formatted = formatted.replaceAll(item.id, '**${item.name}**');
      }
    }

    // 3. Sanitize any remaining raw UUID patterns so internal database hashes never leak
    final uuidRegex = RegExp(
      r'\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b',
    );

    formatted = formatted.replaceAllMapped(uuidRegex, (match) {
      final matchedId = match.group(0)!;
      final matchedItem = userItems.where((i) => i.id == matchedId).firstOrNull;
      if (matchedItem != null) {
        return '**${matchedItem.name}**';
      }
      return 'garment';
    });

    formatted = formatted.replaceAll(
      RegExp(r'\bgarment\s*\(\s*garment\s*\)', caseSensitive: false),
      'garment',
    );

    return formatted;
  }

  @override
  Widget build(BuildContext context) {
    final chatProv = context.watch<ChatProvider>();
    _syncPulseAnimation(chatProv.isListening || chatProv.isSpeaking);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleSafeBack();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: 68,
          automaticallyImplyLeading: false,
          leadingWidth: 56,
          leading: Padding(
            padding: const EdgeInsets.all(10),
            child: IconButton(
              tooltip: 'Back',
              icon: const Icon(
                Icons.arrow_back_ios_new,
                size: 20,
                color: AppColors.forest,
              ),
              onPressed: _handleSafeBack,
            ),
          ),
          title: const AdaaWordmark(
            size: AdaaWordmarkSize.medium,
            color: AppColors.espresso,
            withDotAccent: true,
            showSubtitle: true,
            subtitle: 'style intelligence & closet',
          ),
          centerTitle: true,
          titleSpacing: 0,
          actions: [
            IconButton(
              icon: const Icon(
                Icons.checkroom_outlined,
                color: AppColors.forest,
                size: 20,
              ),
              tooltip: 'View Wardrobe',
              onPressed: _openWardrobeBottomSheet,
            ),
            IconButton(
              icon: Icon(
                chatProv.isHandsFreeMode
                    ? Icons.headset_mic
                    : Icons.headset_mic_outlined,
                color: chatProv.isHandsFreeMode
                    ? AppColors.gold
                    : AppColors.forest,
                size: 20,
              ),
              tooltip: chatProv.isHandsFreeMode
                  ? 'Exit Hands-free Mode'
                  : 'Start Hands-free Conversation',
              onPressed: () {
                chatProv.setHandsFreeMode(!chatProv.isHandsFreeMode);
              },
            ),

            // Auto-Spoken Responses Toggle
            IconButton(
              icon: Icon(
                chatProv.autoVoiceRepliesEnabled
                    ? Icons.volume_up
                    : Icons.volume_off,
                color: chatProv.autoVoiceRepliesEnabled
                    ? AppColors.forest
                    : AppColors.textMuted,
                size: 20,
              ),
              tooltip: chatProv.autoVoiceRepliesEnabled
                  ? 'Spoken replies enabled (tap to mute)'
                  : 'Spoken replies muted (tap to enable)',
              onPressed: () {
                chatProv.setAutoVoiceReplies(!chatProv.autoVoiceRepliesEnabled);
              },
            ),

            // New Session Action
            if (chatProv.messages.isNotEmpty)
              IconButton(
                icon: const Icon(
                  Icons.refresh,
                  color: AppColors.forest,
                  size: 20,
                ),
                tooltip: 'New Styling Session',
                onPressed: () {
                  chatProv.clearChat();
                },
              ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: chatProv.messages.isEmpty
                  ? _buildEmptyState(chatProv)
                  : _buildMessageList(chatProv),
            ),
            if (chatProv.error != null) _buildErrorBanner(chatProv),
            _buildVoiceStatusBar(chatProv),
            _buildComposer(chatProv),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ChatProvider chatProv) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            child: Image.asset('assets/branding/app_icon_no_bg.png'),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Ask adaa',
            style: AppTypography.displaySmall.copyWith(
              color: AppColors.forest,
              fontWeight: FontWeight.w700,
              fontSize: 22,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Your personal wardrobe concierge. Grounded in your real pieces to curate outfits, suggest pairings, advise garment care, and simulate virtual try-ons.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Quick Mode Badges
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ActionChip(
              avatar: const Icon(
                Icons.headset_mic_outlined,
                size: 16,
                color: AppColors.forest,
              ),
              label: const Text(
                'Try Hands-free Mode',
                style: TextStyle(fontSize: 12, color: AppColors.forest),
              ),
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.border),
              onPressed: () => chatProv.setHandsFreeMode(true),
            ),
            const SizedBox(width: 8),
            ActionChip(
              avatar: const Icon(
                Icons.checkroom,
                size: 16,
                color: AppColors.forest,
              ),
              label: const Text(
                'Browse Closet',
                style: TextStyle(fontSize: 12, color: AppColors.forest),
              ),
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.border),
              onPressed: () {
                WardrobeBottomSheet.show(
                  context,
                  onItemSelected: (item) {
                    _textController.text =
                        'Style an outfit with my ${item.name}';
                  },
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 24),
        Text(
          'STARTER SUGGESTIONS',
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ...ChatProvider.starterPrompts.map(
          (prompt) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () {
                _textController.text = prompt;
                _handleSend();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: AppColors.gold,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        prompt,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.forest,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageList(ChatProvider chatProv) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: chatProv.messages.length + (chatProv.isThinking ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == chatProv.messages.length) {
          return _buildThinkingBubble();
        }
        final message = chatProv.messages[index];
        return _buildMessageItem(message);
      },
    );
  }

  Widget _buildMessageItem(ChatMessageModel message) {
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.forest,
            borderRadius: BorderRadius.circular(16)
                .copyWith(bottomRight: const Radius.circular(4)),
          ),
          child: Text(
            message.content,
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.white,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ),
      );
    }

    // Assistant adaa Message
    final wardrobe = context.read<WardrobeProvider>();
    final formattedContent = _formatAssistantContent(
      message.content,
      wardrobe.items,
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18, right: 28),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16)
              .copyWith(topLeft: const Radius.circular(4)),
          border: Border.all(color: AppColors.border),
          boxShadow: [AppColors.subtleShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: AppColors.sageContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 12,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'adaa',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                    letterSpacing: 0.8,
                  ),
                ),
                if (message.domainStatus == 'redirected') ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE8E8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Fashion Scope',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF9B1C1C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const Spacer(),

                // Dedicated Speaker Control for Reading Response Aloud
                Consumer<ChatProvider>(
                  builder: (context, chatProv, _) {
                    final isThisSpeaking =
                        chatProv.isSpeaking &&
                        chatProv.currentlySpeakingMessageId == message.id;
                    return IconButton(
                      icon: Icon(
                        isThisSpeaking
                            ? Icons.stop_circle_outlined
                            : Icons.volume_up_outlined,
                        size: 18,
                        color: isThisSpeaking
                            ? const Color(0xFFE02424)
                            : AppColors.forest,
                      ),
                      tooltip: isThisSpeaking
                          ? 'Stop reading aloud'
                          : 'Read response aloud',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        if (isThisSpeaking) {
                          chatProv.stopSpeaking();
                        } else {
                          chatProv.speakMessage(message);
                        }
                      },
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Formatted Markdown Message Body
            MarkdownBody(
              data: formattedContent,
              selectable: false,
              shrinkWrap: true,
              styleSheet: MarkdownStyleSheet(
                p: AppTypography.bodyMedium.copyWith(
                  color: AppColors.forest,
                  fontSize: 14,
                  height: 1.5,
                ),
                strong: AppTypography.bodyMedium.copyWith(
                  color: AppColors.forest,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  height: 1.5,
                ),
                em: AppTypography.bodyMedium.copyWith(
                  color: AppColors.forest,
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                  height: 1.5,
                ),
                listBullet: AppTypography.bodyMedium.copyWith(
                  color: AppColors.forest,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                pPadding: const EdgeInsets.only(bottom: 8),
                listIndent: 16,
                code: const TextStyle(
                  backgroundColor: AppColors.surface,
                  color: AppColors.forest,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),

            // Inline Suggested User Wardrobe Items
            if (message.suggestedItems.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'FROM YOUR WARDROBE',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: message.suggestedItems.length,
                  itemBuilder: (ctx, idx) {
                    final item = message.suggestedItems[idx];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WardrobeDetailScreen(item: item),
                          ),
                        );
                      },
                      child: Container(
                        width: 104,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AspectRatio(
                              aspectRatio: 1.0,
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(10),
                                ),
                                child: Container(
                                  color: AppColors.surfaceContainerLow,
                                  child: PrivateImageView(
                                    imageUrl: item.imageUrl,
                                    fit: BoxFit.contain,
                                    backgroundColor:
                                        AppColors.surfaceContainerLow,
                                    errorWidget: Container(
                                      color: AppColors.accentSoft,
                                      child: const Icon(
                                        Icons.checkroom,
                                        color: AppColors.textMuted,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                child: Text(
                                  item.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.forest,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            // Suggested Acquisitions
            if (message.suggestedAcquisitions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'RECOMMENDED STAPLE ADDITIONS',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: message.suggestedAcquisitions.map((acq) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      acq,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            // Action Buttons
            if (message.actions.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: message.actions.map((act) {
                  IconData icon = Icons.touch_app;
                  if (act.actionType == 'start_tryon') {
                    icon = Icons.view_in_ar;
                  } else if (act.actionType == 'view_garment') {
                    icon = Icons.checkroom;
                  } else if (act.actionType == 'open_scanner') {
                    icon = Icons.camera_alt_outlined;
                  } else if (act.actionType == 'open_wardrobe') {
                    icon = Icons.grid_view;
                  }

                  return OutlinedButton.icon(
                    onPressed: () => _handleAction(act),
                    icon: Icon(icon, size: 14, color: AppColors.forest),
                    label: Text(
                      act.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.forest,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      side: const BorderSide(color: AppColors.forest),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildThinkingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.forest,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'adaa is curating your wardrobe...',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(ChatProvider chatProv) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFFDE8E8),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: Color(0xFF9B1C1C)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              chatProv.error!,
              style: const TextStyle(fontSize: 12, color: Color(0xFF9B1C1C)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () => chatProv.retryLastMessage(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
            ),
            child: const Text(
              'Retry',
              style: TextStyle(fontSize: 12, color: Color(0xFF9B1C1C)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceStatusBar(ChatProvider chatProv) {
    if (chatProv.voiceState == VoiceState.idle &&
        chatProv.voiceStatus.isEmpty &&
        !chatProv.isHandsFreeMode) {
      return const SizedBox.shrink();
    }

    final isListening = chatProv.isListening;
    final isSpeaking = chatProv.isSpeaking;
    final isHandsFree = chatProv.isHandsFreeMode;
    final isError =
        chatProv.voiceState == VoiceState.error ||
        chatProv.voiceStatus.toLowerCase().contains('denied') ||
        chatProv.voiceStatus.toLowerCase().contains('unavailable') ||
        chatProv.voiceStatus.toLowerCase().contains('not available');

    final bgColor = isSpeaking
        ? const Color(0xFFF4F8F5)
        : (isListening
              ? AppColors.sageContainer.withValues(alpha: 0.8)
              : (isError ? const Color(0xFFFDE8E8) : AppColors.surface));

    final textColor = isError
        ? const Color(0xFF9B1C1C)
        : (isSpeaking || isListening
              ? AppColors.forest
              : AppColors.textPrimary);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(
            color: isError ? const Color(0xFFF8B4B4) : AppColors.border,
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          if (isListening)
            ScaleTransition(
              scale: Tween<double>(begin: 0.85, end: 1.15).animate(
                CurvedAnimation(
                  parent: _pulseController,
                  curve: Curves.easeInOut,
                ),
              ),
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFFE02424),
                  shape: BoxShape.circle,
                ),
              ),
            )
          else if (isSpeaking)
            const Icon(Icons.volume_up, size: 16, color: AppColors.forest)
          else
            Icon(
              isError ? Icons.mic_off_outlined : Icons.info_outline,
              size: 16,
              color: textColor,
            ),
          const SizedBox(width: 10),

          // Main Voice Status & Live Transcription Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (isHandsFree) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: AppColors.forest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'HANDS-FREE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        chatProv.voiceStatus.isNotEmpty
                            ? chatProv.voiceStatus
                            : (isListening
                                  ? 'Listening to your request...'
                                  : 'adaa Voice Mode'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (isListening && chatProv.liveTranscript.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '"${chatProv.liveTranscript}"',
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: AppColors.forest,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),

          // Contextual Voice Controls
          if (isHandsFree) ...[
            OutlinedButton(
              onPressed: () => chatProv.setHandsFreeMode(false),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Exit Hands-free',
                style: TextStyle(fontSize: 11, color: AppColors.forest),
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (isListening) ...[
            TextButton(
              onPressed: () => chatProv.cancelListening(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 4),
            ElevatedButton(
              onPressed: () => chatProv.stopListening(submit: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forest,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Send',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ] else if (isSpeaking) ...[
            IconButton(
              icon: Icon(
                chatProv.isTtsPaused ? Icons.play_arrow : Icons.pause,
                size: 18,
              ),
              color: AppColors.forest,
              tooltip: chatProv.isTtsPaused
                  ? 'Resume speaking'
                  : 'Pause speaking',
              onPressed: () {
                if (chatProv.isTtsPaused) {
                  chatProv.resumeSpeaking();
                } else {
                  chatProv.pauseSpeaking();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.stop, size: 18),
              color: const Color(0xFFE02424),
              tooltip: 'Stop speaking',
              onPressed: () => chatProv.stopSpeaking(),
            ),
          ] else if (!isHandsFree) ...[
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              color: textColor,
              onPressed: () => chatProv.resetVoiceStatus(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Dismiss status',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComposer(ChatProvider chatProv) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final isListening = chatProv.isListening;
              final isSpeaking = chatProv.isSpeaking;

              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isListening || isSpeaking
                      ? const Color(0xFFFDE8E8)
                      : Colors.transparent,
                  boxShadow: (isListening || isSpeaking)
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFFE02424,
                            ).withValues(alpha: 0.3 * _pulseController.value),
                            blurRadius: 8 * _pulseController.value,
                            spreadRadius: 2 * _pulseController.value,
                          ),
                        ]
                      : null,
                ),
                child: child,
              );
            },
            child: IconButton(
              icon: Icon(
                chatProv.isSpeaking
                    ? Icons.stop_circle_outlined
                    : (chatProv.isListening ? Icons.mic : Icons.mic_none),
                color: (chatProv.isListening || chatProv.isSpeaking)
                    ? const Color(0xFFE02424)
                    : AppColors.forest,
              ),
              tooltip: chatProv.isSpeaking
                  ? 'Stop speaking'
                  : (chatProv.isListening ? 'Stop listening' : 'Voice input'),
              onPressed: () => _handleVoiceToggle(chatProv),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _handleSend(),
              decoration: InputDecoration(
                hintText: chatProv.isHandsFreeMode
                    ? 'Hands-free active (or type anytime)...'
                    : 'Ask adaa about outfits, styling, care...',
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.forest),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.forest,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.arrow_upward,
                color: Colors.white,
                size: 20,
              ),
              onPressed: chatProv.isThinking ? null : _handleSend,
            ),
          ),
        ],
      ),
    );
  }
}
