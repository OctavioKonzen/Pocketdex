// lib/screens/conversations_screen.dart
//
// Conversas (igual ao site, ConversationsPage.jsx): todos os chats com os
// amigos, do mais recente para o mais antigo, com a última mensagem e as
// não lidas. Tocar abre o chat.

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;

import '../i18n/text.dart';
import '../services/auth_service.dart';
import '../services/friends_service.dart';
import '../utils/responsive.dart';
import '../utils/site_ui.dart';
import '../widgets/account_avatar.dart';
import 'chat_screen.dart';

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

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FriendsService.instance;
    final c = SiteColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Conversas')),
      body: ListenableBuilder(
        listenable: service,
        builder: (context, _) {
          final me = AuthService.instance.user?.uid;
          if (me == null) return const EmptyMessage('Entre na sua conta para conversar com os amigos.');
          if (!service.ready) return const Center(child: CircularProgressIndicator());
          final friends = conversationOrder(service.friends);
          if (friends.isEmpty) return const EmptyMessage('Você ainda não tem amigos aqui. Adicione alguém pelo nome.');
          final now = DateTime.now();
          return ReadableWidth(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: friends.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final f = friends[i];
                final unread = f.unread > 0;
                final preview = f.lastText == null ? null : (f.lastFrom == me ? '${tr('Você')}: ${f.lastText}' : f.lastText!);
                return SiteCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: PlayerAvatar(pokemonId: f.avatar, name: f.name, size: 44),
                    // O nome e a mensagem vão como foram escritos (sem tradução).
                    title: m.Text(f.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: preview == null
                        ? Text('Nenhuma mensagem ainda. Diga oi!', style: TextStyle(color: c.muted, fontSize: 12))
                        : m.Text(preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: unread ? c.text : c.muted, fontWeight: unread ? FontWeight.bold : null)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (f.lastAt != null) m.Text(chatTime(f.lastAt!, now), style: TextStyle(color: c.muted, fontSize: 11)),
                        if (unread)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Badge(label: m.Text(f.unread > 9 ? '9+' : '${f.unread}')),
                          ),
                      ],
                    ),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(friend: f))),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
