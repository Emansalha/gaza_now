import 'package:flutter_test/flutter_test.dart';
import 'package:gaza_now/channel/channel_models.dart';

void main() {
  test('ChannelPost survives a JSON round trip', () {
    final p = ChannelPost(
      id: '1',
      authorName: 'مراسل',
      outlet: 'غزة الآن',
      text: 'خبر',
      region: 'رفح',
      urgent: true,
      createdAt: DateTime(2026, 1, 1, 9, 5),
    );
    final back = ChannelPost.fromJson(p.toJson());
    expect(back.text, 'خبر');
    expect(back.urgent, isTrue);
    expect(clockTime(back.createdAt), '09:05');
  });

  test('Journalist defaults to pending verification', () {
    const j = Journalist(name: 'أ', outlet: 'ب', phone: '1', pressId: '');
    expect(Journalist.fromJson(j.toJson()).status, JournalistStatus.pending);
  });
}
