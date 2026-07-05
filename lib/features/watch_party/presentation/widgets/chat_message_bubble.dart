import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/chat_message.dart';
import '../../../../core/theme/app_radius.dart';

/// Bubble single chat message di overlay.
///
/// **Variants berdasarkan [ChatMessage.type]:**
/// - `text`: bubble normal — left untuk other, right untuk self
/// - `gift`: gold border + emoji big di tengah
/// - `system`: italic centered text tanpa bubble (mis. "@user joined")
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    required this.message,
    required this.isSelf,
    super.key,
  });

  final ChatMessage message;

  /// True kalau pengirim message adalah current user (Supabase auth.uid()).
  /// Bubble di-render align kanan dengan warna primary kalau true.
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) return _SystemRow(message: message);
    if (message.isGift) return _GiftBubble(message: message);
    return _TextBubble(message: message, isSelf: isSelf);
  }
}

class _SystemRow extends StatelessWidget {
  const _SystemRow({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Text(
          message.message ?? '',
          style: GoogleFonts.roboto(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: AppColors.textMuted(context),
          ),
        ),
      ),
    );
  }
}

class _GiftBubble extends StatelessWidget {
  const _GiftBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.card_giftcard_rounded,
              size: 18,
              color: AppColors.warning,
            ),
            const SizedBox(width: 8),
            Text(
              '@${message.username} ',
              style: GoogleFonts.roboto(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.warning,
              ),
            ),
            Text(
              message.message ?? 'mengirim hadiah',
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextBubble extends StatelessWidget {
  const _TextBubble({required this.message, required this.isSelf});
  final ChatMessage message;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final align = isSelf ? Alignment.centerRight : Alignment.centerLeft;
    final bgColor = isSelf
        ? AppColors.primary.withValues(alpha: 0.85)
        : AppColors.surfaceHigh(context).withValues(alpha: 0.85);
    final textColor = isSelf
        ? AppColors.surface(context)
        : AppColors.textPrimary(context);

    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppRadius.md),
              topRight: const Radius.circular(AppRadius.md),
              bottomLeft: Radius.circular(isSelf ? 12 : 2),
              bottomRight: Radius.circular(isSelf ? 2 : 12),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isSelf)
                Text(
                  '@${message.username}',
                  style: GoogleFonts.roboto(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              if (!isSelf) const SizedBox(height: 2),
              Text(
                message.message ?? '',
                style: GoogleFonts.roboto(
                  fontSize: 12.5,
                  height: 1.35,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
