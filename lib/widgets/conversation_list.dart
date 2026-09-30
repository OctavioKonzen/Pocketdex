// lib/widgets/conversation_list.dart
//
// Conversas na tela de Amigos (como no WhatsApp, igual ao site,
// FriendsPage.jsx): cada amigo com a última mensagem, a hora e as não
// lidas, do mais recente para o mais antigo. Tocar abre o chat.

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;

import '../i18n/text.dart';
import '../screens/chat_screen.dart';
import '../services/friends_service.dart';
import '../utils/site_ui.dart';
import 'account_avatar.dart';

/// Amigos em ordem de conversa: quem mandou por último primeiro; quem ainda
/// não conversou vai para o fim, em ordem alfabética.
List<Friend> conversationOrder(List<Friend> friends) => [...friends]..sort((a, b) {
    final byTime = (b.lastAt ?? 0).compareTo(a.lastAt ?? 0);
    return byTime != 0 ? byTime : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

/// "agora", "5 min", "3 h", "ontem" ou a data (dd/mm).
String chatTime(int at, DateTime now) {
  final when = DateTime.fromMillisecondsSinceEpoch(at);
  final diff = now.difference(when);
  if (diff.inMinutes < 1) return tr('agora');
  if (diff.inMinutes < 60) return '${diff.inMinutes} min';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(when.year, when.month, when.day);
  if (day == today) return '${diff.inHours} h';
  if (today.difference(day).inDays == 1) return tr('ontem');
  return '${when.day.toString().padLeft(2, '0')}/${when.month.toString().padLeft(2, '0')}';
}

class ConversationList extends StatelessWidget {
  final List<Friend> friends;
  final String me;
  const ConversationList({super.key, required this.friends, required this.me});

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final now = DateTime.now();
    const green = Color(0xFF22C55E);
    return Column(
      children: [
        for (final f in conversationOrder(friends))
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(friend: f))),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  PlayerAvatar(pokemonId: f.avatar, name: f.name, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // O nome e a mensagem vão como foram escritos (sem tradução).
                            Expanded(
                              child: m.Text(f.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ),
                            if (f.lastAt != null)
                              m.Text(chatTime(f.lastAt!, now),
                                  style: TextStyle(fontSize: 11, color: f.unread > 0 ? green : c.muted, fontWeight: f.unread > 0 ? FontWeight.bold : null)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: f.lastText == null
                                  ? Text('Nenhuma mensagem ainda. Diga oi!', style: TextStyle(color: c.muted, fontSize: 13))
                                  : m.Text(f.lastFrom == me ? '${tr('Você')}: ${f.lastText}' : f.lastText!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: f.unread > 0 ? c.text : c.muted,
                                          fontWeight: f.unread > 0 ? FontWeight.w600 : null)),
                            ),
                            if (f.unread > 0)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                constraints: const BoxConstraints(minWidth: 20),
                                decoration: BoxDecoration(color: green, borderRadius: BorderRadius.circular(10)),
                                child: m.Text(f.unread > 99 ? '99+' : '${f.unread}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
