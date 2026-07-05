import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/i18n/l10n_extension.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../core/utils/nav_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../data/friends_repository.dart';
import '../data/friendship.dart';
import 'friends_providers.dart';

/// 3 tab: Friends · Pending (incoming) · Sent (outgoing)
class FriendsListScreen extends ConsumerStatefulWidget {
  const FriendsListScreen({super.key});

  @override
  ConsumerState<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends ConsumerState<FriendsListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(acceptedFriendsProvider);
    final pending = ref.watch(incomingPendingProvider);
    final sent = ref.watch(outgoingPendingProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.friendsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => NavHelper.safePop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: context.l10n.friendsSearch,
            onPressed: () => context.push(AppRoutes.userSearch),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: [
            Tab(text: '${context.l10n.friendsList} (${friends.length})'),
            Tab(text: '${context.l10n.friendsIncoming} (${pending.length})'),
            Tab(text: '${context.l10n.friendsOutgoing} (${sent.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _FriendsTab(items: friends),
          _IncomingTab(items: pending),
          _OutgoingTab(items: sent),
        ],
      ),
    );
  }
}

class _FriendsTab extends StatelessWidget {
  const _FriendsTab({required this.items});
  final List<Friendship> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Belum ada teman — tap ikon + atas untuk cari.',
          style: GoogleFonts.roboto(color: AppColors.textMuted(context)),
        ),
      );
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (ctx, i) => _FriendRow(friendship: items[i]),
    );
  }
}

class _IncomingTab extends ConsumerWidget {
  const _IncomingTab({required this.items});
  final List<Friendship> items;

  Future<void> _accept(BuildContext context, WidgetRef ref, String fid) async {
    Haptic.medium();
    try {
      await ref.read(friendsRepositoryProvider).acceptRequest(fid);
      if (context.mounted) AppSnackbar.success(context, 'Diterima');
    } catch (e) {
      if (context.mounted) AppSnackbar.error(context, 'Gagal: $e');
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref, String fid) async {
    Haptic.heavy();
    try {
      await ref.read(friendsRepositoryProvider).rejectRequest(fid);
      if (context.mounted) AppSnackbar.success(context, 'Ditolak');
    } catch (e) {
      if (context.mounted) AppSnackbar.error(context, 'Gagal: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Belum ada permintaan teman masuk.',
          style: GoogleFonts.roboto(color: AppColors.textMuted(context)),
        ),
      );
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final f = items[i];
        final me = ref.watch(myFriendshipsProvider);
        // Resolve profile partner
        return _UserAsyncRow(
          userId: f.requesterId,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => _accept(context, ref, f.id),
                child: Text(context.l10n.friendsAccept),
              ),
              TextButton(
                onPressed: () => _reject(context, ref, f.id),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: Text(context.l10n.friendsReject),
              ),
            ],
          ),
          // ignore: avoid_redundant_argument_values
          subtitle: me.isLoading ? 'Loading...' : null,
        );
      },
    );
  }
}

class _OutgoingTab extends ConsumerWidget {
  const _OutgoingTab({required this.items});
  final List<Friendship> items;

  Future<void> _cancel(BuildContext context, WidgetRef ref, String fid) async {
    Haptic.medium();
    await ref.read(friendsRepositoryProvider).cancelRequest(fid);
    if (context.mounted) AppSnackbar.success(context, 'Dibatalkan');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Tidak ada request terkirim.',
          style: GoogleFonts.roboto(color: AppColors.textMuted(context)),
        ),
      );
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final f = items[i];
        return _UserAsyncRow(
          userId: f.recipientId,
          trailing: TextButton(
            onPressed: () => _cancel(context, ref, f.id),
            child: const Text('Batal'),
          ),
        );
      },
    );
  }
}

class _FriendRow extends ConsumerWidget {
  const _FriendRow({required this.friendship});
  final Friendship friendship;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final otherId = friendship.otherUserId(myId);
    return _UserAsyncRow(
      userId: otherId,
      onTap: () => context.push(AppRoutes.friendProfilePath(otherId)),
    );
  }
}

/// Generic row yang resolve user profile async.
class _UserAsyncRow extends ConsumerWidget {
  const _UserAsyncRow({
    required this.userId,
    this.trailing,
    this.onTap,
    this.subtitle,
  });

  final String userId;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfile = ref.watch(userProfileProvider(userId));
    return asyncProfile.when(
      loading: () =>
          const ListTile(leading: CircleAvatar(), title: Text('Loading...')),
      error: (e, _) => ListTile(
        leading: const CircleAvatar(child: Icon(Icons.error_outline_rounded)),
        title: Text(context.l10n.errorGeneric),
      ),
      data: (profile) {
        if (profile == null) {
          return const ListTile(title: Text('User not found'));
        }
        return ListTile(
          onTap:
              onTap ??
              () => context.push(AppRoutes.friendProfilePath(profile.id)),
          leading: CircleAvatar(
            backgroundColor: AppColors.surfaceElevated(context),
            backgroundImage: (profile.avatarUrl?.isNotEmpty ?? false)
                ? CachedNetworkImageProvider(profile.avatarUrl!)
                : null,
            child: (profile.avatarUrl?.isEmpty ?? true)
                ? const Icon(Icons.person_outline_rounded)
                : null,
          ),
          title: Text('@${profile.username}'),
          subtitle: subtitle != null
              ? Text(subtitle!)
              : (profile.bio == null || profile.bio!.isEmpty)
              ? null
              : Text(
                  profile.bio!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          trailing: trailing,
        );
      },
    );
  }
}
