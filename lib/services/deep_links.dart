// lib/services/deep_links.dart
//
// Links do site abertos no app: um time compartilhado
// (#/times/importar/<código>), um replay (#/batalha/replay?d=<código>) e um
// desafio do quiz (#/jogo?desafio=<código>). Chegam pelo Android
// (MainActivity.kt) como o próprio link do site ou como
// pocketdex://open?u=<rota>, que o site usa no botão "Abrir no app".

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/battle_history_screen.dart';
import '../screens/quiz_screen.dart';
import '../screens/team_builder_screen.dart';
import '../widgets/chat_bubble.dart';
import 'challenge.dart';
import 'replay_link.dart';
import 'team_service.dart';
import 'team_share.dart';

class DeepLinks {
  DeepLinks._();

  static const _channel = MethodChannel('pocketdex/links');

  /// Escuta os links (o que abriu o app e os que chegam depois).
  static Future<void> start() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'link') open('${call.arguments}');
    });
    try {
      final first = await _channel.invokeMethod<String>('initialLink');
      if (first != null) open(first);
    } on MissingPluginException {
      // Fora do Android (testes, web): sem links.
    }
  }

  /// A rota do site dentro do link ("/times/importar/PDX1...").
  static String route(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null) return '';
    if (uri.scheme == 'pocketdex') return uri.queryParameters['u'] ?? '';
    return uri.fragment;
  }

  /// Abre a tela do link (espera o app terminar de abrir).
  static void open(String link) {
    final path = route(link);
    if (path.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _go(path, 0));
  }

  static Future<void> _go(String path, int tries) async {
    final nav = ChatBubble.instance.navigatorKey.currentState;
    if (nav == null) {
      if (tries < 50) Future.delayed(const Duration(milliseconds: 200), () => _go(path, tries + 1));
      return;
    }
    final context = nav.context;
    final team = RegExp(r'^/times/importar/(PDX1[\w-]+)').firstMatch(path);
    if (team != null) return _importTeam(context, nav, team.group(1)!);
    final replay = RegExp(r'^/batalha/replay\?(?:.*&)?d=([\w-]+)').firstMatch(path);
    if (replay != null) {
      final record = ReplayLink.decode(replay.group(1)!);
      if (record == null) return _error(context, 'Link de replay inválido.');
      nav.push(MaterialPageRoute(builder: (_) => ReplayScreen(record)));
      return;
    }
    if (RegExp(r'^/jogo\?(?:.*&)?desafio=').hasMatch(path)) {
      final challenge = Challenge.decode(path);
      if (challenge == null) return _error(context, 'Código de desafio inválido.');
      nav.push(MaterialPageRoute(builder: (_) => QuizScreen(challenge: challenge)));
    }
  }

  static Future<void> _importTeam(BuildContext context, NavigatorState nav, String code) async {
    final shared = TeamShare.decode(code);
    if (shared == null) return _error(context, 'Não encontrei um time nesse texto.');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Importar time'),
        content: Text('Importar o time "${shared.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Importar')),
        ],
      ),
    );
    if (ok != true) return;
    final team = await TeamService().importTeam(shared);
    nav.push(MaterialPageRoute(builder: (_) => TeamBuilderScreen(team: team)));
  }

  static void _error(BuildContext context, String text) =>
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));
}
