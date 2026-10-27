// lib/services/offline_notice.dart
//
// Sem internet o app funciona (os dados estão no aparelho), mas os sprites
// animados, a conta e as batalhas online não: ao abrir, avisa uma vez.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../widgets/chat_bubble.dart';

class OfflineNotice {
  OfflineNotice._();

  /// Confere a conexão ao abrir o app e avisa se não tiver.
  static Future<void> check() async {
    if (kIsWeb || await online()) return;
    _show(0);
  }

  static Future<bool> online() async {
    try {
      final found = await InternetAddress.lookup('octaviokonzen.github.io').timeout(const Duration(seconds: 5));
      return found.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static void _show(int tries) {
    final context = ChatBubble.instance.navigatorKey.currentContext;
    final messenger = context == null ? null : ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      if (tries < 50) Timer(const Duration(milliseconds: 200), () => _show(tries + 1));
      return;
    }
    messenger.showSnackBar(const SnackBar(
      duration: Duration(seconds: 6),
      content: Text('Sem internet: a Pokédex e as ferramentas funcionam, mas os sprites animados, a conta e as batalhas online voltam quando a conexão voltar.'),
    ));
  }
}
