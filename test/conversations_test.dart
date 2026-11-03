import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/widgets/conversation_list.dart';
import 'package:pocket_dex/services/friends_service.dart';

void main() {
  test('Conversas: mais recente primeiro; sem mensagem no fim, por nome', () {
    Friend f(String name, [int? at]) => Friend(name, name, null, 'friends', null, lastAt: at);
    final list = [f('bia'), f('Ana'), f('Caio', 10), f('Duda', 20)];
    expect(conversationOrder(list).map((f) => f.name), ['Duda', 'Caio', 'Ana', 'bia']);
  });

  test('Hora da última mensagem (igual ao site)', () {
    final now = DateTime(2026, 9, 30, 15);
    int ms(DateTime d) => d.millisecondsSinceEpoch;
    expect(chatTime(ms(now) - 20000, now), 'agora');
    expect(chatTime(ms(now) - 5 * 60000, now), '5 min');
    expect(chatTime(ms(DateTime(2026, 9, 30, 11, 30)), now), '3 h');
    expect(chatTime(ms(DateTime(2026, 9, 29, 23)), now), 'ontem');
    expect(chatTime(ms(DateTime(2026, 9, 3, 9)), now), '03/09');
  });
}
