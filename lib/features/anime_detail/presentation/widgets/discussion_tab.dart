import 'package:flutter/material.dart';
import '../../../../core/i18n/l10n_extension.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/animation/animations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/haptic_helper.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../auth/presentation/app_auth_controller.dart';
import '../../data/discussion.dart';
import '../../data/discussion_repository.dart';
import '../../../../core/theme/app_radius.dart';

/// Tab Diskusi — list post + input field.
///
/// **Auth flow:** post butuh Supabase login. Read terbuka untuk semua.
class DiscussionTab extends ConsumerStatefulWidget {
  const DiscussionTab({required this.animeId, super.key});

  final int animeId;

  @override
  ConsumerState<DiscussionTab> createState() => _DiscussionTabState();
}

class _DiscussionTabState extends ConsumerState<DiscussionTab> {
  final _inputController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  /// Bottom sheet picker emoji "gift" — tap → langsung kirim sebagai message.
  /// Tidak persist sebagai attachment terpisah (untuk MVP cukup unicode).
  Future<void> _handleSendGift() async {
    final appUser = ref.read(appAuthControllerProvider).user;
    if (appUser == null) {
      AppSnackbar.info(context, 'Login dulu untuk kirim gift.');
      return;
    }
    Haptic.selection();
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceElevated(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _GiftPickerSheet(),
    );
    if (picked == null) return;
    _sendRaw(picked);
  }

  /// Send arbitrary content (used by gift + normal text send).
  Future<void> _sendRaw(String content) async {
    if (content.isEmpty || _isSending) return;
    final appUser = ref.read(appAuthControllerProvider).user;
    if (appUser == null) return;

    setState(() => _isSending = true);
    try {
      Haptic.light();
      await ref
          .read(discussionRepositoryProvider)
          .postDiscussion(
            animeId: widget.animeId,
            username: appUser.username,
            content: content,
          );
      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, 'Gagal kirim: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _handleSend() async {
    final content = _inputController.text.trim();
    if (content.isEmpty || _isSending) return;

    final appUser = ref.read(appAuthControllerProvider).user;
    if (appUser == null) {
      AppSnackbar.info(context, 'Login dulu untuk diskusi.');
      return;
    }

    setState(() => _isSending = true);
    try {
      Haptic.light();
      await ref
          .read(discussionRepositoryProvider)
          .postDiscussion(
            animeId: widget.animeId,
            username: appUser.username,
            content: content,
          );
      _inputController.clear();
      if (!mounted) return;
      AppSnackbar.success(context, context.l10n.discussionPosted);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, 'Gagal kirim: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _confirmDelete(Discussion d) async {
    Haptic.medium();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated(context),
        title: Text(
          'Hapus diskusi?',
          style: GoogleFonts.roboto(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
              style: GoogleFonts.roboto(color: AppColors.textMuted(context)),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(discussionRepositoryProvider).deleteDiscussion(d.id);
      // Safety net: invalidate stream provider supaya re-subscribe + fetch
      // ulang kalau Realtime DELETE event tidak propagate (REPLICA IDENTITY
      // belum FULL atau network glitch).
      ref.invalidate(discussionsStreamProvider(widget.animeId));
      if (!mounted) return;
      AppSnackbar.success(context, context.l10n.discussionDeleted);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, 'Gagal hapus: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncDiscussions = ref.watch(
      discussionsStreamProvider(widget.animeId),
    );
    final appUser = ref.watch(appAuthControllerProvider).user;
    final selfId = appUser?.id;
    final isAuthed = appUser != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Input field ────────────────────────────────────────────
          Row(
            children: [
              // Tombol Gift — picker emoji
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  onPressed: isAuthed && !_isSending ? _handleSendGift : null,
                  tooltip: 'Kirim gift',
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.card_giftcard_rounded, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceHigh(context),
                    foregroundColor: AppColors.warning,
                    shape: const CircleBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _inputController,
                  enabled: isAuthed && !_isSending,
                  maxLength: 1000,
                  maxLines: 3,
                  minLines: 1,
                  textInputAction: TextInputAction.newline,
                  style: GoogleFonts.roboto(
                    fontSize: 13,
                    color: AppColors.textPrimary(context),
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    counterText: '',
                    hintText: isAuthed
                        ? 'Bagaimana pendapatmu?'
                        : 'Login Supabase untuk diskusi',
                    hintStyle: GoogleFonts.roboto(
                      fontSize: 12,
                      color: AppColors.textMuted(context),
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceElevated(context),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(
                        color: AppColors.borderColor(context),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(
                        color: AppColors.borderColor(context),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                height: 44,
                child: FilledButton(
                  onPressed: (isAuthed && !_isSending) ? _handleSend : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onAccent,
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                  ),
                  child: _isSending
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onAccent,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Discussion list ────────────────────────────────────────
          asyncDiscussions.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Tidak bisa load diskusi: $e',
                style: GoogleFonts.roboto(fontSize: 12, color: AppColors.error),
              ),
            ),
            data: (list) {
              if (list.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          color: AppColors.textMuted(context),
                          size: 36,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Belum ada diskusi.\nJadi yang pertama!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.roboto(
                            fontSize: 12,
                            color: AppColors.textMuted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: list
                    .map(
                      (d) => _DiscussionCard(
                        discussion: d,
                        isOwn: d.userId == selfId,
                        onDelete: () => _confirmDelete(d),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DiscussionCard extends StatelessWidget {
  const _DiscussionCard({
    required this.discussion,
    required this.isOwn,
    required this.onDelete,
  });

  final Discussion discussion;
  final bool isOwn;
  final VoidCallback onDelete;

  String _relativeTime() {
    final diff = DateTime.now().difference(discussion.createdAt);
    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}j';
    if (diff.inDays < 7) return '${diff.inDays}h';
    return '${(diff.inDays / 7).floor()}m'; // minggu
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.primary.withValues(alpha: 0.18),
                child: Text(
                  discussion.username.isEmpty
                      ? '?'
                      : discussion.username.substring(0, 1).toUpperCase(),
                  style: GoogleFonts.roboto(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '@${discussion.username}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ),
              Text(
                _relativeTime(),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: AppColors.textMuted(context),
                ),
              ),
              if (isOwn)
                GestureDetector(
                  onTap: onDelete,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: AppColors.error,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isOnlyEmoji(discussion.content))
            _AnimatedGiftDisplay(emoji: discussion.content)
          else
            Text(
              discussion.content,
              style: GoogleFonts.roboto(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textPrimary(context),
              ),
            ),
        ],
      ),
    );
  }

  /// True kalau content cuma emoji (max 3 char, no alphanum). Untuk render
  /// gift emoji lebih besar + animated.
  bool _isOnlyEmoji(String s) {
    if (s.length > 8) return false;
    return !RegExp(r'[a-zA-Z0-9]').hasMatch(s);
  }
}

/// Gift emoji "sticker" dengan animasi pop-in + idle rotation pulse.
///
/// **Kenapa di-animate?** User minta "stiker bergerak" — biar feel-nya kayak
/// platform community (Discord, dll). Animasi pure Flutter (TweenAnimation +
/// AnimatedRotation) tanpa external dependency.
class _AnimatedGiftDisplay extends StatefulWidget {
  const _AnimatedGiftDisplay({required this.emoji});
  final String emoji;

  @override
  State<_AnimatedGiftDisplay> createState() => _AnimatedGiftDisplayState();
}

class _AnimatedGiftDisplayState extends State<_AnimatedGiftDisplay>
    with TickerProviderStateMixin {
  late final AnimationController _popCtrl;
  late final Animation<double> _scale;
  late final AnimationController _idleCtrl;

  @override
  void initState() {
    super.initState();
    // Pop-in animation: 0 → 1.3 → 1.0 (overshoot bounce)
    _popCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.3,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.3,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
    ]).animate(_popCtrl);
    _popCtrl.forward();

    // Idle pulse animation — repeat infinite (subtle wobble).
    // Skip loop kalau "Kurangi animasi" aktif (hemat CPU/baterai).
    _idleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (!AppAnimations.reduceAnimationsOverride) {
      _idleCtrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _popCtrl.dispose();
    _idleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedBuilder(
          animation: _idleCtrl,
          builder: (_, child) {
            // Wobble: -3deg .. +3deg
            final t = (_idleCtrl.value - 0.5) * 0.1;
            return Transform.rotate(angle: t, child: child);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.warning.withValues(alpha: 0.2),
                  AppColors.primary.withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.5),
              ),
            ),
            child: Text(widget.emoji, style: const TextStyle(fontSize: 36)),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _GiftPickerSheet — bottom sheet 6-kolom emoji grid
// ─────────────────────────────────────────────────────────────────────────

/// Bottom sheet picker dengan 3 kategori sticker/gift.
///
/// **Kategori:**
/// - **Reactions**: emoji ekspresi umum (love, fire, wow, etc.)
/// - **Anime**: emoji bertema anime/Jepang (sakura, onigiri, torii, etc.)
/// - **Special**: combo emoji "sticker" yang muncul dengan animasi pop+wobble
///
/// Tap emoji → close sheet → return value ke caller untuk dikirim sebagai
/// post diskusi.
class _GiftPickerSheet extends StatefulWidget {
  @override
  State<_GiftPickerSheet> createState() => _GiftPickerSheetState();
}

class _GiftPickerSheetState extends State<_GiftPickerSheet>
    with TickerProviderStateMixin {
  late final TabController _tabs;

  static const _reactions = [
    '❤️',
    '😍',
    '🔥',
    '✨',
    '⭐',
    '👏',
    '💯',
    '🎉',
    '😂',
    '😭',
    '😱',
    '🥳',
    '👍',
    '🙏',
    '😎',
    '🤩',
    '💖',
    '💎',
  ];
  static const _anime = [
    '🌸',
    '🍙',
    '🍡',
    '🎌',
    '⛩️',
    '🗡️',
    '🛡️',
    '👑',
    '🎀',
    '☕',
    '🌙',
    '⚡',
    '🍱',
    '🍵',
    '🎴',
    '🏯',
    '🌊',
    '🌟',
  ];
  // "Special" = combo sticker yang punya animasi pop + wobble di message
  static const _special = [
    '🎉🎊',
    '💖✨',
    '🔥🔥🔥',
    '👑✨',
    '⭐⭐⭐',
    '🌸🌸🌸',
    '🎀💖',
    '⚡🔥',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Widget _grid(List<String> items) {
    return GridView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final emoji = items[i];
        return InkWell(
          onTap: () => Navigator.pop(context, emoji),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.borderColor(context)),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderColor(context),
              borderRadius: BorderRadius.circular(AppRadius.tiny),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kirim Gift 🎁',
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      Text(
                        'Tap untuk kirim — sticker animated saat diterima',
                        style: GoogleFonts.roboto(
                          fontSize: 11,
                          color: AppColors.textMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabs,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 2,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted(context),
            labelStyle: GoogleFonts.roboto(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'Reactions'),
              Tab(text: 'Anime'),
              Tab(text: 'Special ✨'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [_grid(_reactions), _grid(_anime), _grid(_special)],
            ),
          ),
        ],
      ),
    );
  }
}
