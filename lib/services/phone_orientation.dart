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

  /// Só em pé (o normal do app no celular).
  static Future<void> portrait() async {
    if (isPhone) await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  /// Em pé ou deitado (na batalha).
  static Future<void> any() async {
    if (isPhone) await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }
}
