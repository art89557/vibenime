import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/i18n/l10n_extension.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/haptic_helper.dart';
import '../../../../shared/models/character.dart';
import '../../../../core/theme/app_radius.dart';

/// Grid 2-kolom karakter anime + voice actor (Japanese seiyuu).
/// Tap karakter → buka bottom sheet detail (deskripsi + bio).
class CharactersTab extends StatelessWidget {
  const CharactersTab({required this.characters, super.key});

  final List<Character> characters;

  @override
  Widget build(BuildContext context) {
    if (characters.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 48,
                color: AppColors.textMuted(context),
              ),
              const SizedBox(height: 12),
              Text(
                'Daftar karakter belum tersedia.',
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                  fontSize: 13,
                  color: AppColors.textMuted(context),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.4,
      ),
      itemCount: characters.length,
      itemBuilder: (_, i) => _CharacterTile(
        character: characters[i],
        onTap: () => _showCharacterDetail(context, characters[i]),
      ),
    );
  }

  void _showCharacterDetail(BuildContext context, Character c) {
    Haptic.light();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _CharacterDetailSheet(character: c),
    );
  }
}

/// Tile horizontal: 2 portrait kotak (character + voice actor) + names.
/// Tap → buka detail sheet.
class _CharacterTile extends StatelessWidget {
  const _CharacterTile({required this.character, required this.onTap});
  final Character character;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceElevated(context),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderColor(context)),
          ),
          child: Row(
            children: [
              // Character portrait (left)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.md),
                  bottomLeft: Radius.circular(AppRadius.md),
                ),
                child: AspectRatio(
                  aspectRatio: 2 / 3,
                  child: _Portrait(
                    imageUrl: character.imageUrl,
                    isCharacter: true,
                  ),
                ),
              ),
              // Names (center)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            character.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.roboto(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context),
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            character.roleLabel,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9,
                              letterSpacing: 1,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      if (character.voiceActor != null)
                        Text(
                          'CV: ${character.voiceActor}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.roboto(
                            fontSize: 10,
                            color: AppColors.textMuted(context),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Voice actor portrait (right, kalau ada)
              if (character.voiceActorImageUrl != null) ...[
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(AppRadius.md),
                    bottomRight: Radius.circular(AppRadius.md),
                  ),
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: _Portrait(
                      imageUrl: character.voiceActorImageUrl,
                      isCharacter: false,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _CharacterDetailSheet — bottom sheet showing full character info
// ─────────────────────────────────────────────────────────────────────────

class _CharacterDetailSheet extends StatelessWidget {
  const _CharacterDetailSheet({required this.character});
  final Character character;

  /// Strip HTML tags + spoiler markers ~!...!~ dari description AniList.
  static String _cleanDescription(String? raw) {
    if (raw == null) return '';
    return raw
        .replaceAll(RegExp(r'<[^>]*>'), '') // HTML tags
        .replaceAll(RegExp(r'~!|!~'), '') // AniList spoiler markers
        .replaceAll('__', '') // bold markers
        .replaceAll('**', '')
        .trim();
  }

  Widget _bioRow(BuildContext context, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: AppColors.textMuted(context),
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.roboto(
                fontSize: 13,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final desc = _cleanDescription(character.description);
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: portrait + name + role
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: SizedBox(
                          width: 90,
                          height: 130,
                          child: _Portrait(
                            imageUrl: character.imageUrl,
                            isCharacter: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              character.name,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 22,
                                fontStyle: FontStyle.italic,
                                color: AppColors.textPrimary(context),
                                height: 1.1,
                              ),
                            ),
                            if (character.nativeName != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                character.nativeName!,
                                style: GoogleFonts.roboto(
                                  fontSize: 13,
                                  color: AppColors.textMuted(context),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.18,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                              ),
                              child: Text(
                                character.roleLabel,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  letterSpacing: 1,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Bio rows
                  _bioRow(context, 'Gender', character.gender),
                  _bioRow(context, 'Umur', character.age),
                  _bioRow(context, 'Lahir', character.birthMonthDay),
                  _bioRow(context, 'Gol. Darah', character.bloodType),
                  if (character.voiceActor != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (character.voiceActorImageUrl != null) ...[
                          ClipOval(
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: _Portrait(
                                imageUrl: character.voiceActorImageUrl,
                                isCharacter: false,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Voice Actor (Japanese)',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9,
                                  color: AppColors.textMuted(context),
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Text(
                                character.voiceActor!,
                                style: GoogleFonts.roboto(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (desc.isNotEmpty) ...[
                    Divider(color: AppColors.borderColor(context), height: 24),
                    Text(
                      context.l10n.commonAbout,
                      style: GoogleFonts.roboto(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      desc,
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        height: 1.5,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Portrait extends StatelessWidget {
  const _Portrait({required this.imageUrl, required this.isCharacter});
  final String? imageUrl;
  final bool isCharacter;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        color: AppColors.surfaceHigh(context),
        child: Icon(
          isCharacter ? Icons.person_rounded : Icons.mic_rounded,
          color: AppColors.textMuted(context),
          size: 24,
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(color: AppColors.surfaceHigh(context)),
      errorWidget: (_, _, _) => Container(
        color: AppColors.surfaceHigh(context),
        child: Icon(
          Icons.broken_image_outlined,
          color: AppColors.textMuted(context),
          size: 18,
        ),
      ),
    );
  }
}
