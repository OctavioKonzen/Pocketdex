// Tocando no aviso do celular: abre a tela dele (o chat do amigo, os amigos, a batalha online, o draft ou o seu
// perfil, onde ficam os duelos contra a sua defesa). Os dados vêm do servidor (tool/notify/notify.mjs).
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/screens/chat_screen.dart';
import 'package:pocket_dex/screens/draft_screen.dart';
import 'package:pocket_dex/screens/friends_screen.dart';
import 'package:pocket_dex/screens/online_battle_screen.dart';
import 'package:pocket_dex/screens/profile_screen.dart';
import 'package:pocket_dex/services/friends_service.dart';
import 'package:pocket_dex/services/push_service.dart';

void main() {
  const bia = Friend('bia', 'Bia', null, 'friends', null);
  Object? screen(Map<String, dynamic> data) => PushService.screenFor(data, friends: const [bia], me: 'ana');

  test('cada aviso abre a sua tela', () {
    expect(screen({'kind': 'message', 'screen': 'chat', 'uid': 'bia'}), isA<ChatScreen>().having((s) => s.friend.uid, 'amigo', 'bia'));
    // O amigo saiu da lista: abre os amigos.
    expect(screen({'kind': 'message', 'screen': 'chat', 'uid': 'outro'}), isA<FriendsScreen>());
    expect(screen({'kind': 'friend', 'screen': 'friends'}), isA<FriendsScreen>());
    expect(screen({'kind': 'battle', 'screen': 'online', 'battle': 'b1'}), isA<OnlineBattleScreen>());
    expect(screen({'kind': 'draft', 'screen': 'draft', 'draft': 'd1'}), isA<DraftScreen>().having((s) => s.draftId, 'draft', 'd1'));
    expect(screen({'kind': 'duelWon', 'screen': 'profile', 'uid': 'x'}), isA<ProfileScreen>().having((s) => s.uid, 'perfil', 'ana'));
    expect(screen({'kind': 'outro'}), isNull);
    expect(PushService.screenFor({'screen': 'profile'}), isNull);
  });
}
