// lib/services/run_guard.dart
//
// A corrida do Pokelike aberta em dois aparelhos: quando a conta traz uma
// corrida diferente da daqui (continuada no site ou em outro celular), a
// batalha velha deste aparelho fecha e avisa — senão o fim dela gravaria por
// cima do que foi jogado lá. Igual ao site (web-site/src/lib/runGuard.js).

import 'dart:convert';
import 'package:flutter/foundation.dart';

class RunGuard {
  RunGuard._();

  /// Sobe a cada corrida continuada em outro aparelho.
  static final takeovers = ValueNotifier<int>(0);

  /// [before] e [after]: a "league" da conta antes e depois do que veio de fora.
  static bool changed(Object? before, Object? after) {
    final old = _runOf(before);
    // Sem corrida aqui (ou já acabada) não tem o que perder.
    return old != null && canonical(old) != canonical(_runOf(after));
  }

  /// O JSON com as chaves em ordem: a conta devolve os campos em outra ordem e não é mudança. Igual ao site.
  static String canonical(Object? v) => jsonEncode(_sorted(v));
  static Object? _sorted(Object? v) => switch (v) {
        final Map m => {for (final k in (m.keys.map((k) => '$k').toList()..sort())) k: _sorted(m[k])},
        final List l => [for (final x in l) _sorted(x)],
        _ => v,
      };

  static Object? _runOf(Object? league) {
    final factory = league is Map ? league['factory'] : null;
    return factory is Map ? factory['run'] : null;
  }
}
