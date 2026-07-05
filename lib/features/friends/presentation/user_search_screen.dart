import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/i18n/l10n_extension.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../core/utils/nav_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../data/friends_repository.dart';
import '../data/friendship.dart';
import 'friends_providers.dart';

/// Search user untuk add friend. Query by username (via RPC).
class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen> {
  final _queryCtrl = TextEditingController();
  List<FriendUserProfile> _results = const [];
  bool _isSearching = false;

  Future<void> _doSearch() async {
    final q = _queryCtrl.text.trim();
    if (q.length < 2) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _isSearching = true);
    final results = await ref.read(friendsRepositoryProvider).searchUsers(q);
    if (!mounted) return;
    setState(() {
      _results = results;
      _isSearching = false;
    });
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.friendsSearch),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => NavHelper.safePop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _queryCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Username atau email...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _isSearching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              onChanged: (_) => _doSearch(),
              onSubmitted: (_) => _doSearch(),
            ),
          ),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      _queryCtrl.text.length < 2
                          ? 'Ketik minimal 2 karakter'
                          : context.l10n.searchNoResults,
                      style: GoogleFonts.roboto(
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (_, i) => _UserResultRow(profile: _results[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _UserResultRow extends ConsumerWidget {
  const _UserResultRow({required this.profile});
  final FriendUserProfile profile;

  Future<void> _addFriend(BuildContext context, WidgetRef ref) async {
    Haptic.medium();
    try {
      await ref.read(friendsRepositoryProvider).sendRequest(profile.id);
      if (!context.mounted) return;
      AppSnackbar.success(context, 'Request terkirim ke @${profile.username}');
    } catch (e) {
      if (context.mounted) AppSnackbar.error(context, 'Gagal: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(friendshipStateProvider(profile.id));
    final btnLabel = switch (state) {
      FriendshipState.none => 'Add Friend',
      FriendshipState.pendingOutgoing => 'Pending',
      FriendshipState.pendingIncoming => 'Terima',
      FriendshipState.accepted => 'Teman',
      FriendshipState.blocked => 'Blocked',
    };
    final btnEnabled =
        state == FriendshipState.none ||
        state == FriendshipState.pendingIncoming;

    return ListTile(
      onTap: () => context.push(AppRoutes.friendProfilePath(profile.id)),
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
      subtitle: profile.bio == null || profile.bio!.isEmpty
          ? null
          : Text(profile.bio!, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: TextButton(
        onPressed: btnEnabled ? () => _addFriend(context, ref) : null,
        child: Text(btnLabel),
      ),
    );
  }
}
