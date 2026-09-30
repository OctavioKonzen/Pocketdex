// lib/screens/friends_screen.dart
//
// Amigos (os mesmos do site): adicionar pelo nome, pedidos recebidos e
// enviados, desafios que os amigos deixaram e o ranking entre vocês pelo
// recorde do Ranked.

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;

import '../i18n/text.dart';
import '../services/auth_service.dart';
import '../services/challenge.dart';
import '../services/friends_service.dart';
import '../services/user_data.dart';
import '../utils/responsive.dart';
import '../utils/site_ui.dart';
import '../widgets/account_avatar.dart';
import 'chat_screen.dart';
import 'draft_screen.dart';
import 'quiz_screen.dart';
import 'team_battle_screen.dart';
import 'trades_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _service = FriendsService.instance;
  final _name = TextEditingController();
  bool _busy = false;
  (bool, String)? _message; // (ok, texto)
  Map<String, int> _records = {};
  String _recordsFor = '';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final typed = _name.text.trim();
    if (typed.isEmpty) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final other = await _service.findAccount(typed);
      final me = AuthService.instance.user!.uid;
      if (other == null) {
        _message = (false, 'Ninguém com esse nome. Confira como está escrito.');
      } else if (other.$1 == me) {
        _message = (false, 'Esse é você!');
      } else {
        final existing = _service.list.where((f) => f.uid == other.$1).firstOrNull;
        if (existing?.status == 'friends') {
          _message = (false, 'Vocês já são amigos.');
        } else if (existing?.status == 'sent') {
          _message = (false, 'Você já mandou um pedido para essa pessoa.');
        } else if (existing?.status == 'received') {
          await _service.accept(other.$1);
          _message = (true, 'Essa pessoa já tinha te chamado: agora vocês são amigos!');
        } else {
          await _service.sendRequest(other.$1, other.$2);
          _message = (true, 'Pedido enviado! Quando a pessoa aceitar, ela aparece na sua lista.');
        }
        _name.clear();
      }
    } catch (e) {
      _message = (false, 'Algo deu errado. Tente de novo.');
    }
    if (mounted) setState(() => _busy = false);
  }

  void _loadRecords(List<Friend> friends) {
    final key = friends.map((f) => f.uid).join(',');
    if (key == _recordsFor || key.isEmpty) return;
    _recordsFor = key;
    _service.records([for (final f in friends) f.uid]).then((r) {
      if (mounted) setState(() => _records = r);
    });
  }

  void _play(Friend f) {
    final c = Challenge.decode(f.challenge!['code'] as String);
    _service.clearChallenge(f.uid).catchError((_) {});
    if (c == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => QuizScreen(challenge: c)));
  }

  Widget _card(SiteColors c, String title, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: SiteCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Amigos')),
      body: ListenableBuilder(
        listenable: Listenable.merge([_service, UserData.instance]),
        builder: (context, _) {
          final user = AuthService.instance.user;
          if (user == null) return const EmptyMessage('Entre na sua conta para ter amigos.');
          final friends = _service.friends;
          _loadRecords(friends);
          final board = [
            for (final f in friends) (f.uid, f.name, f.avatar, _records[f.uid] ?? 0, f),
            (user.uid, user.name ?? '', UserData.instance.avatar, UserData.instance.rankedRecord, null),
          ]..sort((a, b) => b.$4.compareTo(a.$4));
          return ReadableWidth(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: PillButton(
                        label: '🔁 ${tr('Trocas')}',
                        expand: true,
                        gradient: const LinearGradient(colors: [Color(0xFF16A34A), Color(0xFF0F766E)]),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TradesScreen())),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PillButton(
                        label: '⚔️ ${tr('Batalha')}',
                        expand: true,
                        gradient: const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFF9333EA)]),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeamBattleScreen())),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                PillButton(
                  label: '🎯 ${tr('Draft')}',
                  expand: true,
                  gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEA580C)]),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DraftsScreen())),
                ),
                const SizedBox(height: 14),
                _card(c, tr('Adicionar amigo'), [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _name,
                          maxLength: 20,
                          decoration: InputDecoration(
                            hintText: tr('Nome da pessoa no PocketDex'),
                            counterText: '',
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _add(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(onPressed: _busy ? null : _add, child: Text(_busy ? 'Enviando...' : 'Enviar pedido')),
                    ],
                  ),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_message!.$2, style: TextStyle(color: _message!.$1 ? Colors.greenAccent : Colors.redAccent, fontSize: 13)),
                    ),
                ]),
                if (_service.incoming.isNotEmpty)
                  _card(c, tr('Pedidos recebidos ({0})').replaceAll('{0}', '${_service.incoming.length}'), [
                    for (final f in _service.incoming)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: PlayerAvatar(pokemonId: f.avatar, name: f.name, size: 40),
                        title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF43A047)),
                            onPressed: () => _service.accept(f.uid),
                            child: const Text('Aceitar'),
                          ),
                          IconButton(
                            tooltip: tr('Recusar'),
                            icon: Icon(Icons.close, color: c.muted),
                            onPressed: () => _service.remove(f.uid),
                          ),
                        ]),
                      ),
                  ]),
                if (_service.challenges.isNotEmpty)
                  _card(c, tr('Desafios dos amigos'), [
                    for (final f in _service.challenges)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: PlayerAvatar(pokemonId: f.avatar, name: f.name, size: 40),
                        title: Text(tr('🤝 {0} te desafiou!').replaceAll('{0}', f.name), style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(tr('Fez {0}/{1}').replaceAll('{0}', '${f.challenge?['score'] ?? 0}').replaceAll('{1}', '$challengeRounds')),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
                            onPressed: () => _play(f),
                            child: const Text('Jogar'),
                          ),
                          IconButton(
                            tooltip: tr('Dispensar'),
                            icon: Icon(Icons.close, color: c.muted),
                            onPressed: () => _service.clearChallenge(f.uid),
                          ),
                        ]),
                      ),
                  ]),
                _card(c, tr('Amigos ({0})').replaceAll('{0}', '${friends.length}'), [
                  Text(
                      'Ranking entre vocês pelo recorde do Ranked. Toque no balão para conversar; no fim de um desafio no Jogo, dá para mandar o desafio para um amigo.',
                      style: TextStyle(color: c.muted, fontSize: 12)),
                  const SizedBox(height: 8),
                  if (!_service.ready)
                    const Center(child: CircularProgressIndicator())
                  else if (friends.isEmpty)
                    Text('Você ainda não tem amigos aqui. Adicione alguém pelo nome.', style: TextStyle(color: c.muted))
                  else
                    for (final (i, (uid, name, avatar, score, friend)) in board.indexed)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: friend == null ? Colors.amber.withAlpha(35) : null,
                          borderRadius: BorderRadius.circular(12),
                          border: friend == null ? Border.all(color: Colors.amber) : null,
                        ),
                        child: Row(
                          children: [
                            SizedBox(width: 24, child: Text('${i + 1}', style: TextStyle(color: c.muted, fontWeight: FontWeight.w900))),
                            PlayerAvatar(pokemonId: avatar, name: name, size: 36),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(friend == null ? '$name · ${tr('você')}' : name,
                                      overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  if (friend?.lastText != null)
                                    // A mensagem vai como foi escrita (sem tradução).
                                    m.Text(friend!.lastText!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: friend.unread > 0 ? c.text : c.muted,
                                            fontWeight: friend.unread > 0 ? FontWeight.bold : null)),
                                ],
                              ),
                            ),
                            Text('🏆 $score', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900)),
                            if (friend != null)
                              IconButton(
                                tooltip: tr('Conversar'),
                                icon: Badge(
                                  isLabelVisible: friend.unread > 0,
                                  label: m.Text(friend.unread > 9 ? '9+' : '${friend.unread}'),
                                  child: const Icon(Icons.chat_bubble_outline, color: Color(0xFF38BDF8), size: 22),
                                ),
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(friend: friend))),
                              ),
                            if (friend != null)
                              IconButton(
                                tooltip: tr('Desfazer amizade'),
                                icon: Icon(Icons.person_remove_outlined, color: c.muted, size: 20),
                                onPressed: () => _service.remove(uid),
                              ),
                          ],
                        ),
                      ),
                ]),
                if (_service.outgoing.isNotEmpty)
                  _card(c, tr('Pedidos enviados ({0})').replaceAll('{0}', '${_service.outgoing.length}'), [
                    for (final f in _service.outgoing)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: PlayerAvatar(pokemonId: null, name: f.name, size: 36),
                        title: Text(f.name),
                        trailing: TextButton(onPressed: () => _service.remove(f.uid), child: const Text('Cancelar')),
                      ),
                  ]),
              ],
            ),
          );
        },
      ),
    );
  }
}
