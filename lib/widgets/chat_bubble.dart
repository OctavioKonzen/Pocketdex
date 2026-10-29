// lib/widgets/chat_bubble.dart
//
// Bolinha do chat (igual ao site, ChatBubble.jsx): depois de abrir uma
// conversa, o amigo fica numa bolinha por cima de todas as telas, com as
// mensagens não lidas. Tocar volta para o chat, arrastar muda de lugar e o
// X tira a bolinha.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/i18n.dart';
import '../screens/chat_screen.dart';
import '../services/friends_service.dart';
import 'account_avatar.dart';

class ChatBubble extends ChangeNotifier {
  ChatBubble._();
  static final ChatBubble instance = ChatBubble._();
  static const _key = 'chat_bubble';

  /// Navegador do app (a bolinha fica fora dele, por cima de tudo).
  final navigatorKey = GlobalKey<NavigatorState>();

  /// Amigo da bolinha e o chat que está aberto agora (esconde a bolinha dele).
  String? uid;
  final Set<String> _open = {};

  Future<void> load() async {
    try {
      uid = (await SharedPreferences.getInstance()).getString(_key);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> show(String friendUid) async {
    uid = friendUid;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setString(_key, friendUid);
    } catch (_) {}
  }

  Future<void> close() async {
    uid = null;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).remove(_key);
    } catch (_) {}
  }

  void opened(String friendUid) {
    _open.add(friendUid);
    notifyListeners();
  }

  void closed(String friendUid) {
    _open.remove(friendUid);
    notifyListeners();
  }

  bool isOpen(String friendUid) => _open.contains(friendUid);
}

/// Põe a bolinha por cima do app (usado no builder do MaterialApp).
class ChatBubbleLayer extends StatefulWidget {
  final Widget child;
  const ChatBubbleLayer({super.key, required this.child});

  @override
  State<ChatBubbleLayer> createState() => _ChatBubbleLayerState();
}

class _ChatBubbleLayerState extends State<ChatBubbleLayer> {
  static const _size = 56.0;

  /// Distância da borda direita e de baixo (arrastável).
  Offset _pos = const Offset(16, 104);

  @override
  Widget build(BuildContext context) {
    final bubble = ChatBubble.instance;
    final friends = FriendsService.instance;
    return Stack(
      children: [
        widget.child,
        ListenableBuilder(
          listenable: Listenable.merge([bubble, friends]),
          builder: (context, _) {
            final uid = bubble.uid;
            final friend = uid == null ? null : friends.friends.where((f) => f.uid == uid).firstOrNull;
            if (friend == null || bubble.isOpen(friend.uid)) return const SizedBox.shrink();
            final media = MediaQuery.of(context);
            final maxX = media.size.width - _size - 8;
            final maxY = media.size.height - _size - media.padding.top - 8;
            final right = _pos.dx.clamp(8.0, maxX < 8 ? 8.0 : maxX);
            final bottom = _pos.dy.clamp(8.0 + media.padding.bottom, maxY < 8 ? 8.0 : maxY);
            return Positioned(
              right: right,
              bottom: bottom,
              child: GestureDetector(
                onPanUpdate: (d) => setState(() => _pos = Offset(right - d.delta.dx, bottom - d.delta.dy)),
                // Solta perto de um lado: gruda na borda.
                onPanEnd: (_) => setState(() => _pos = Offset(right > media.size.width / 2 - _size / 2 ? maxX : 16, bottom)),
                onTap: () => bubble.navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => ChatScreen(friend: friend))),
                child: Semantics(
                  button: true,
                  label: '${tr('Conversar')}: ${friend.name}',
                  child: SizedBox(
                    width: _size + 8,
                    height: _size + 8,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 0,
                          bottom: 0,
                          child: Material(
                            shape: const CircleBorder(side: BorderSide(color: Color(0xFF0EA5E9), width: 2)),
                            elevation: 6,
                            color: Theme.of(context).cardColor,
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: PlayerAvatar(pokemonId: friend.avatar, name: friend.name, size: _size - 6),
                            ),
                          ),
                        ),
                        if (friend.unread > 0)
                          Positioned(
                            left: -2,
                            top: 4,
                            child: Badge(label: Text(friend.unread > 9 ? '9+' : '${friend.unread}')),
                          ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: bubble.close,
                            child: Semantics(
                              button: true,
                              label: tr('Fechar'),
                              child: Material(
                                shape: const CircleBorder(),
                                elevation: 3,
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: const Padding(padding: EdgeInsets.all(3), child: Icon(Icons.close, size: 14)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
