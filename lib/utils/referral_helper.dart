import 'dart:math';

/// Generates a unique-looking referral code (e.g. BKC865).
String generateReferralCode() {
  const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  const digits = '0123456789';
  final rnd = Random();
  final part1 = List.generate(3, (_) => letters[rnd.nextInt(letters.length)]).join();
  final part2 = List.generate(3, (_) => digits[rnd.nextInt(digits.length)]).join();
  return part1 + part2;
}
