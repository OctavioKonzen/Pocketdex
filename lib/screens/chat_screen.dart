// lib/screens/chat_screen.dart
//
// Chat com um amigo (o mesmo do site, web-site/src/pages/ChatPage.jsx): as
// últimas 100 mensagens em tempo real. Só existe enquanto os dois são amigos.

import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;

import '../i18n/text.dart';
import '../services/auth_service.dart';
import '../services/friends_service.dart';
import '../utils/site_ui.dart';
import '../widgets/account_avatar.dart';

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
                                    child: m.Text(msg.text, style: TextStyle(color: mine ? Colors.white : c.text, fontSize: 15)),
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
