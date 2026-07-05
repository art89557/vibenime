import 'package:flutter/material.dart';

/// Badge yang bisa di-unlock user — match dengan badge_code di Supabase.
///
/// Server (sql/gamification.sql) yang evaluate criteria + insert row ke
/// user_badges. Client cuma render display.
enum Badge {
  firstEpisode(
    code: 'first_episode',
    name: 'First Episode',
    description: 'Tonton episode pertama',
    icon: Icons.play_circle_filled_rounded,
    color: Color(0xFF5DD3F0),
  ),
  bingeWatcher(
    code: 'binge_watcher',
    name: 'Binge Watcher',
    description: 'Tonton 100 episode',
    icon: Icons.tv_rounded,
    color: Color(0xFFFFD700),
  ),
  completionist(
    code: 'completionist',
    name: 'Completionist',
    description: 'Selesaikan 10 anime',
    icon: Icons.emoji_events_rounded,
    color: Color(0xFFFFA500),
  ),
  socialButterfly(
    code: 'social_butterfly',
    name: 'Social Butterfly',
    description: '10 teman terhubung',
    icon: Icons.people_alt_rounded,
    color: Color(0xFFFF8FA3),
  ),
  listBuilder(
    code: 'list_builder',
    name: 'List Builder',
    description: 'Tambahkan 25 anime ke list',
    icon: Icons.bookmark_rounded,
    color: Color(0xFFA78BFA),
  );

  const Badge({
    required this.code,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String code;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  static Badge? fromCode(String code) {
    for (final b in Badge.values) {
      if (b.code == code) return b;
    }
    return null;
  }
}
