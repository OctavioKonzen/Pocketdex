// lib/services/battle_speed.dart
//
// A velocidade da batalha (⏩ na faixa do campo): 1×, 2× ou 4×. Mais rápido,
// as esperas entre os textos e as animações (timeDilation) andam junto. Fica guardada
// neste aparelho. Igual ao site (lib/battleSpeed.js).

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BattleSpeed {
  BattleSpeed._();

  static const _key = 'battleSpeed';
  static final speed = ValueNotifier<int>(1);
  static bool _loaded = false;
  static int _open = 0;

  /// A espera de [ms] na velocidade de agora.
  static int ms(int ms) => (ms / speed.value).round();

  static Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final saved = (await SharedPreferences.getInstance()).getInt(_key) ?? 1;
      speed.value = steps.contains(saved) ? saved : 1;
    } catch (_) {}
    _apply();
  }

  /// Uma batalha abriu (as animações andam na velocidade dela) ou fechou (voltam ao normal).
  static void enter() {
    _open++;
    _load();
    _apply();
  }

  static void leave() {
    _open = _open > 0 ? _open - 1 : 0;
    _apply();
  }

  /// As velocidades do botão, nesta ordem (depois da última, volta para a primeira).
  static const steps = [1, 2, 4];

  static void toggle() {
    speed.value = steps[(steps.indexOf(speed.value) + 1) % steps.length];
    _apply();
    SharedPreferences.getInstance().then((p) => p.setInt(_key, speed.value)).catchError((_) => true);
  }

  static void _apply() => timeDilation = _open > 0 ? 1 / speed.value : 1.0;
}
