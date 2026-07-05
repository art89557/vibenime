import 'package:flutter_test/flutter_test.dart';
import 'package:vibenime/features/gamification/data/xp_repository.dart';

void main() {
  group('UserXp', () {
    test('fromRow parse xp + level dengan default aman', () {
      final xp = UserXp.fromRow({'xp': 250, 'level': 2});
      expect(xp.xp, 250);
      expect(xp.level, 2);

      final empty = UserXp.fromRow({});
      expect(empty.xp, 0);
      expect(empty.level, 1);
    });

    test('xpToNextLevel = (level^2 * 100) - xp', () {
      const xp = UserXp(xp: 150, level: 2);
      // next threshold = 2*2*100 = 400 → butuh 250 lagi
      expect(xp.xpToNextLevel, 250);
    });

    test('levelProgress fraction 0..1', () {
      // level 2: range 100..400 (300). xp 250 → (250-100)/300 = 0.5
      const xp = UserXp(xp: 250, level: 2);
      expect(xp.levelProgress, closeTo(0.5, 0.0001));
    });

    test('levelProgress clamp ke 0..1', () {
      const over = UserXp(xp: 99999, level: 2);
      expect(over.levelProgress, 1.0);
    });

    test('empty constant', () {
      expect(UserXp.empty.xp, 0);
      expect(UserXp.empty.level, 1);
    });
  });
}
