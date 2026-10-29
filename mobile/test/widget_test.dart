import 'package:flutter_test/flutter_test.dart';
import 'package:pomp/screens/matches_screen.dart';

void main() {
  test('saat biçimi: bugünkü mesajlar SS:DD olarak gösterilir', () {
    final now = DateTime.now();
    final t = DateTime(now.year, now.month, now.day, 9, 5);
    expect(formatTime(t), '09:05');
  });
}
