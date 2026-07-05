import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/i18n/l10n_extension.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../core/utils/nav_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../friends/presentation/friends_providers.dart';
import '../data/direct_message.dart';
import '../data/dm_repository.dart';
import '../../../core/theme/app_radius.dart';

/// 1-on-1 chat screen dengan partner. Realtime via Supabase channel.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.partnerId});

  final String partnerId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isSending = false;

  String get _myId => Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    // Auto-mark conversation as read saat user buka chat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dmRepositoryProvider).markConversationRead(widget.partnerId);
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final content = _inputCtrl.text.trim();
    if (content.isEmpty) return;
    Haptic.medium();
    setState(() => _isSending = true);
    try {
      await ref
          .read(dmRepositoryProvider)
          .sendMessage(recipientId: widget.partnerId, content: content);
      if (!mounted) return;
      _inputCtrl.clear();
      // Scroll to bottom (reverse list: index 0 is newest)
      _scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'Gagal kirim: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncMessages = ref.watch(conversationProvider(widget.partnerId));
    final asyncProfile = ref.watch(userProfileProvider(widget.partnerId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => NavHelper.safePop(context),
        ),
        title: asyncProfile.when(
          loading: () => const Text('Loading...'),
          error: (_, _) => const Text('User'),
          data: (p) => Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.surfaceElevated(context),
                backgroundImage: (p?.avatarUrl?.isNotEmpty ?? false)
                    ? CachedNetworkImageProvider(p!.avatarUrl!)
                    : null,
                child: (p?.avatarUrl?.isEmpty ?? true)
                    ? const Icon(Icons.person_outline_rounded, size: 16)
                    : null,
              ),
              const SizedBox(width: 10),
              Text(
                p == null ? 'User' : '@${p.username}',
                style: GoogleFonts.roboto(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: asyncMessages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: ErrorRetry(
                  message: e.toString(),
                  onRetry: () =>
                      ref.invalidate(conversationProvider(widget.partnerId)),
                ),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Mulai chat — kirim pesan pertama!',
                      style: GoogleFonts.roboto(
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  );
                }
                // Reverse list — newest at top (index 0). UI ListView reverse=true.
                final reversed = messages.reversed.toList();
                return ListView.builder(
                  controller: _scrollCtrl,
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: reversed.length,
                  itemBuilder: (_, i) => _Bubble(
                    msg: reversed[i],
                    isFromMe: reversed[i].isFromMe(_myId),
                  ),
                );
              },
            ),
          ),
          _InputBar(
            controller: _inputCtrl,
            onSend: _send,
            isSending: _isSending,
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg, required this.isFromMe});
  final DirectMessage msg;
  final bool isFromMe;

  String _time(DateTime t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = isFromMe
        ? AppColors.primary
        : AppColors.surfaceElevated(context);
    final textColor = isFromMe ? Colors.black : AppColors.textPrimary(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: isFromMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.75,
              ),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadius.lg),
                  topRight: const Radius.circular(AppRadius.lg),
                  bottomLeft: Radius.circular(isFromMe ? 16 : 4),
                  bottomRight: Radius.circular(isFromMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    msg.content,
                    style: GoogleFonts.roboto(fontSize: 14, color: textColor),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _time(msg.createdAt),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          color: textColor.withValues(alpha: 0.6),
                        ),
                      ),
                      if (isFromMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          msg.isRead
                              ? Icons.done_all_rounded
                              : Icons.done_rounded,
                          size: 12,
                          color: msg.isRead
                              ? Colors.blueAccent
                              : textColor.withValues(alpha: 0.6),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.isSending,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isSending;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        12 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        border: Border(top: BorderSide(color: AppColors.borderColor(context))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLength: 2000,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: context.l10n.messagesType,
                counterText: '',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: isSending ? null : onSend,
            icon: isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.send_rounded,
                    color: AppColors.primaryAdaptive(context),
                  ),
          ),
        ],
      ),
    );
  }
}
