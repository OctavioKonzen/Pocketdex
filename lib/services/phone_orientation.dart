// lib/services/phone_orientation.dart
//
// No celular o app fica em pé (main.dart); só a batalha pode deitar, com o
// registro dela ao lado (BattleView). No tablet gira sempre.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;

class PhoneOrientation {
  static bool get isPhone {
    if (kIsWeb) return false;
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    return view.physicalSize.shortestSide / view.devicePixelRatio < 600;
  }

  /// Quantas telas abertas deixam deitar (a tela da Batalha e a batalha dentro dela): só volta a ficar em pé quando todas fecham.
  static int _open = 0;

  /// Quantas telas abertas querem só deitado (o Pokelike, como o port do Black & White): enquanto houver uma, fica deitado.
  static int _land = 0;

  static Future<void> _apply() async {
    if (!isPhone) return;
    await SystemChrome.setPreferredOrientations(_land > 0
        ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : _open > 0
            ? DeviceOrientation.values
            : [DeviceOrientation.portraitUp]);
  }

  /// Só em pé (o normal do app no celular): quem tinha chamado [any] e saiu.
  static Future<void> portrait() async {
    if (_open > 0) _open--;
    await _apply();
  }

  /// Em pé ou deitado (na batalha e na Battle Factory). Cada [any] tem o seu [portrait] ao sair.
  static Future<void> any() async {
    _open++;
    await _apply();
  }

  /// Só deitado (o Pokelike). Cada [landscape] tem o seu [leaveLandscape] ao sair.
  static Future<void> landscape() async {
    _land++;
    await _apply();
  }

  static Future<void> leaveLandscape() async {
    if (_land > 0) _land--;
    await _apply();
  }
}
