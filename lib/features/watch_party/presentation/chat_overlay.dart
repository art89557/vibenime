import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/i18n/l10n_extension.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../auth/presentation/app_auth_controller.dart';
import '../data/chat_message.dart';
import '../data/watch_party_repository.dart';
import 'watch_party_providers.dart';
import 'widgets/chat_message_bubble.dart';
import '../../../core/theme/app_radius.dart';

/// Overlay chat real-time untuk watch party.
///
/// **Layout**: Column dengan ScrollView di atas (auto-scroll ke bottom saat
/// ada message baru) + TextField input di bawah.
///
/// **Realtime**: subscribe ke [chatStreamProvider] yang wrap Supabase
/// `stream(primaryKey)` di tabel `chat_messages` filter by `party_id`.
///
/// **Send**: panggil [WatchPartyRepository.sendMessage] yang INSERT ke
/// Supabase, lalu Realtime auto-broadcast balik ke semua subscriber.
///
/// **Auth**: kalau user belum login Supabase, input field di-disable +
/// show hint "Login dulu untuk chat".
class ChatOverlay extends ConsumerStatefulWidget {
  const ChatOverlay({required this.partyId, super.key});

  final String partyId;

  @override
  ConsumerState<ChatOverlay> createState() => _ChatOverlayState();
}

class _ChatOverlayState extends ConsumerState<ChatOverlay> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _isSending = false;
  DateTime _lastSendAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Scroll ke bottom — dipanggil tiap kali message list update.
  /// `addPostFrameCallback` supaya layout sudah selesai dulu.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  /// Handler tombol send / submit Enter:
  /// 1. Validate text non-empty + auth
  /// 2. Rate-limit: minimum 1 detik antar message (anti-spam)
  /// 3. Call repo.sendMessage → Realtime broadcast otomatis
  Future<void> _handleSend() async {
    final raw = _inputController.text.trim();
    if (raw.isEmpty || _isSending) return;

    final appUser = ref.read(appAuthControllerProvider).user;
    if (appUser == null) {
      AppSnackbar.info(context, context.l10n.wpChatLoginRequired);
      return;
    }

    // Anti-spam: throttle 1 message per 1 detik
    final now = DateTime.now();
    if (now.difference(_lastSendAt).inMilliseconds < 1000) {
      AppSnackbar.info(context, 'Pelan-pelan, jangan spam.');
      return;
    }

    setState(() => _isSending = true);
    try {
      Haptic.light();
      await ref
          .read(watchPartyRepositoryProvider)
          .sendMessage(
            partyId: widget.partyId,
            username: appUser.username,
            message: raw,
          );
      _inputController.clear();
      _lastSendAt = now;
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, '${context.l10n.wpChatSendFailed}: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncMessages = ref.watch(chatStreamProvider(widget.partyId));
    final appUser = ref.watch(appAuthControllerProvider).user;
    final selfId = appUser?.id ?? '__anon__';
    final isAuthed = appUser != null;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.85),
          ],
        ),
      ),
      child: Column(
        children: [
          // ── Messages list (expand) ─────────────────────────────────
          Expanded(
            child: asyncMessages.when(
              loading: () => const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
              error: (e, _) => Center(
                child: Text(
                  '${context.l10n.errorGeneric}: $e',
                  style: GoogleFonts.roboto(
                    fontSize: 11,
                    color: AppColors.error,
                  ),
                ),
              ),
              data: (messages) {
                // Setelah data muncul, scroll ke bawah (post-frame).
                _scrollToBottom();
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      context.l10n.wpChatEmpty,
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    return _AnimatedChatItem(
                      key: ValueKey(msg.id),
                      message: msg,
                      isSelf: msg.userId == selfId,
                    );
                  },
                );
              },
            ),
          ),

          // ── Input field ────────────────────────────────────────────
          _ChatInput(
            controller: _inputController,
            focusNode: _focusNode,
            isSending: _isSending,
            isAuthed: isAuthed,
            onSend: _handleSend,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _AnimatedChatItem — fade+slide-in animasi untuk message baru
// ─────────────────────────────────────────────────────────────────────────

class _AnimatedChatItem extends StatefulWidget {
  const _AnimatedChatItem({
    required this.message,
    required this.isSelf,
    super.key,
  });

  final ChatMessage message;
  final bool isSelf;

  @override
  State<_AnimatedChatItem> createState() => _AnimatedChatItemState();
}

class _AnimatedChatItemState extends State<_AnimatedChatItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: ChatMessageBubble(
          message: widget.message,
          isSelf: widget.isSelf,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _ChatInput — TextField + send button
// ─────────────────────────────────────────────────────────────────────────

class _ChatInput extends StatelessWidget {
  const _ChatInput({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.isAuthed,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final bool isAuthed;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: isAuthed && !isSending,
              maxLength: 200,
              onSubmitted: (_) => onSend(),
              textInputAction: TextInputAction.send,
              style: GoogleFonts.roboto(
                fontSize: 13,
                color: AppColors.textPrimary(context),
              ),
              decoration: InputDecoration(
                isDense: true,
                counterText: '',
                hintText: isAuthed
                    ? context.l10n.messagesType
                    : context.l10n.wpChatLoginRequired,
                hintStyle: GoogleFonts.roboto(
                  fontSize: 12,
                  color: AppColors.textMuted(context),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: (isAuthed && !isSending) ? onSend : null,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (isAuthed && !isSending)
                    ? AppColors.primary
                    : AppColors.surfaceHigh(context),
                shape: BoxShape.circle,
              ),
              child: isSending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onAccent,
                      ),
                    )
                  : Icon(
                      Icons.send_rounded,
                      size: 18,
                      color: isAuthed
                          ? AppColors.surface(context)
                          : AppColors.textMuted(context),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
