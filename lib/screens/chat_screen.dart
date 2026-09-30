// lib/screens/chat_screen.dart
//
// Chat com um amigo (o mesmo do site, web-site/src/pages/ChatPage.jsx): as
// últimas 100 mensagens em tempo real. Só existe enquanto os dois são amigos.

import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;

import '../i18n/i18n.dart';
import '../i18n/text.dart';
import '../services/auth_service.dart';
import '../services/friends_service.dart';
import '../services/local_database.dart';
import '../services/team_service.dart';
import '../services/team_share.dart';
import '../services/user_data.dart';
import '../utils/site_ui.dart';
import '../utils/string_extensions.dart';
import '../widgets/account_avatar.dart';
import '../widgets/pokemon_sprite.dart';
import 'pokedex_screen.dart';
import 'pokemon_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  final Friend friend;
  const ChatScreen({super.key, required this.friend});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _service = FriendsService.instance;
  final _text = TextEditingController();
  final _scroll = ScrollController();
  late final Stream<List<ChatMessage>> _messages = _service.watchChat(widget.friend.uid);
  String? _error;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _service.addListener(_markRead);
    _markRead();
  }

  @override
  void dispose() {
    _service.removeListener(_markRead);
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Com o chat aberto, o que chega já conta como lido.
  void _markRead() {
    final f = _service.friends.where((f) => f.uid == widget.friend.uid).firstOrNull;
    if (f != null && f.unread > 0) unawaited(_service.markRead(f.uid).catchError((_) {}));
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty) return;
    _text.clear();
    setState(() => _error = null);
    try {
      await _service.sendMessage(widget.friend.uid, body);
    } catch (e) {
      _text.text = body;
      setState(() => _error = tr('Não deu para mandar. Confira a internet.'));
    }
  }

  Future<void> _sendCard(String text, Map<String, dynamic> card) async {
    setState(() => _error = null);
    try {
      await _service.sendMessage(widget.friend.uid, text, card: card);
    } catch (_) {
      setState(() => _error = tr('Não deu para mandar. Confira a internet.'));
    }
  }

  /// Anexar: um Pokémon (da Pokédex) ou um dos meus times.
  Future<void> _attach() async {
    final teams = UserData.instance.teams.where((t) => ((t['pokemon'] as List?) ?? const []).any((p) => p != null)).toList();
    final choice = await showModalBottomSheet<Object>(
      context: context,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            ListTile(
              leading: const Icon(Icons.catching_pokemon),
              title: const Text('Mandar um Pokémon'),
              onTap: () => Navigator.pop(sheet, 'pokemon'),
            ),
            if (teams.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text('Mandar um time', style: TextStyle(color: Theme.of(sheet).hintColor, fontWeight: FontWeight.bold)),
              ),
            for (final t in teams)
              ListTile(
                leading: const Icon(Icons.groups),
                title: m.Text('${t['name'] ?? 'Time'}', overflow: TextOverflow.ellipsis),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (final p in (t['pokemon'] as List).whereType<num>())
                    SizedBox.square(dimension: 26, child: PokemonSprite(p.toInt(), fill: 0.95)),
                ]),
                onTap: () => Navigator.pop(sheet, t),
              ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'pokemon') {
      final picked = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(builder: (_) => const PokedexScreen(isForTeamSelection: true)),
      );
      final id = int.tryParse('${picked?['id']}');
      if (id == null) return;
      final row = await LocalDatabase.instance.pokemonRow(id);
      final name = I18n.pokemonName(((row?['name'] as String?) ?? '#$id').replaceAll('-', ' ').capitalise());
      await _sendCard('📎 $name', {'kind': 'pokemon', 'id': id, 'name': name.length > 60 ? name.substring(0, 60) : name});
    } else if (choice is Map<String, dynamic>) {
      final name = '${choice['name'] ?? 'Time'}';
      final slots = [for (final p in (choice['pokemon'] as List? ?? const [])) (p as num?)?.toInt()];
      final sets = [for (final x in (choice['sets'] as List? ?? const [])) x is Map ? Map<String, dynamic>.from(x) : null];
      await _sendCard('📎 ${tr('Time')}: $name', {
        'kind': 'team',
        'name': name.length > 60 ? name.substring(0, 60) : name,
        'ids': slots.whereType<int>().toList(),
        'code': TeamShare.encode(name: name, color: choice['color'] as String?, pokemon: slots, sets: sets),
      });
    }
  }

  static String _time(DateTime t) {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final hour = '${two(t.hour)}:${two(t.minute)}';
    return now.year == t.year && now.month == t.month && now.day == t.day ? hour : '${two(t.day)}/${two(t.month)} $hour';
  }

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final me = AuthService.instance.user?.uid;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            PlayerAvatar(pokemonId: widget.friend.avatar, name: widget.friend.name, size: 36),
            const SizedBox(width: 10),
            Expanded(child: m.Text(widget.friend.name, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListenableBuilder(
                listenable: _service,
                builder: (context, _) {
                  final stillFriends = _service.friends.any((f) => f.uid == widget.friend.uid);
                  if (_service.ready && !stillFriends) {
                    return const EmptyMessage('Vocês não são amigos (ou a amizade foi desfeita).');
                  }
                  return StreamBuilder<List<ChatMessage>>(
                    stream: _messages,
                    builder: (context, snap) {
                      if (snap.hasError) return const EmptyMessage('Não deu para abrir o chat.');
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                      final list = snap.data!;
                      if (list.isEmpty) return const EmptyMessage('Nenhuma mensagem ainda. Diga oi! 👋');
                      // Nova mensagem: desce até o fim.
                      if (list.length != _count) {
                        _count = list.length;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_scroll.hasClients) _scroll.jumpTo(0);
                        });
                      }
                      return ListView.builder(
                        controller: _scroll,
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final msg = list[list.length - 1 - i];
                          final mine = msg.from == me;
                          return Align(
                            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                              decoration: BoxDecoration(
                                color: mine ? const Color(0xFF0284C7) : c.card,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(18),
                                  topRight: const Radius.circular(18),
                                  bottomLeft: Radius.circular(mine ? 18 : 6),
                                  bottomRight: Radius.circular(mine ? 6 : 18),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // A mensagem vai como foi escrita (sem tradução).
                                  SizedBox(
                                    width: double.infinity,
                                    child: msg.card != null
                                        ? _CardView(card: msg.card!, light: mine)
                                        : m.Text(msg.text, style: TextStyle(color: mine ? Colors.white : c.text, fontSize: 15)),
                                  ),
                                  const SizedBox(height: 2),
                                  m.Text(_time(msg.at), style: TextStyle(fontSize: 10, color: mine ? Colors.white70 : c.muted)),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: tr('Mandar Pokémon ou time'),
                    onPressed: _attach,
                    icon: Icon(Icons.add_circle_outline, color: c.muted),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: FriendsService.chatMax,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: tr('Mensagem'),
                        counterText: '',
                        isDense: true,
                        filled: true,
                        fillColor: c.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder(
                    valueListenable: _text,
                    builder: (context, value, _) => IconButton.filled(
                      tooltip: tr('Enviar'),
                      style: IconButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
                      onPressed: value.text.trim().isEmpty ? null : _send,
                      icon: const Icon(Icons.send),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cartão de Pokémon (abre a página dele) ou de time (dá para salvar).
class _CardView extends StatelessWidget {
  final Map<String, dynamic> card;
  final bool light;
  const _CardView({required this.card, required this.light});

  Future<void> _saveTeam(BuildContext context) async {
    final shared = TeamShare.decode('${card['code'] ?? ''}');
    if (shared == null) return;
    await TeamService().importTeam(shared);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Time salvo nos seus times!'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = light ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final name = '${card['name'] ?? ''}';
    if (card['kind'] == 'pokemon' && card['id'] is num) {
      final id = (card['id'] as num).toInt();
      return InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PokemonDetailScreen(initialPokemonId: id))),
        child: Row(
          children: [
            SizedBox.square(dimension: 56, child: PokemonSprite(id, fill: 0.95)),
            const SizedBox(width: 8),
            Expanded(child: m.Text(name, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16))),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      );
    }
    final ids = [for (final x in (card['ids'] as List?) ?? const []) if (x is num) x.toInt()];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.groups, color: color, size: 18),
          const SizedBox(width: 6),
          Expanded(child: m.Text(name, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 4),
        Wrap(children: [for (final id in ids) SizedBox.square(dimension: 40, child: PokemonSprite(id, fill: 0.95))]),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: color, padding: EdgeInsets.zero),
          onPressed: () => _saveTeam(context),
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Salvar nos meus times'),
        ),
      ],
    );
  }
}
