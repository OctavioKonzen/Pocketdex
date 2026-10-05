import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:quickjs_engine/quickjs_engine.dart';

/// One offline JavaScript runtime, using the exact bundle shipped on the site.
/// Battles are isolated handles; disposing one never resets another battle.
class BattleSimulator {
  static JavascriptRuntime? _runtime;
  static Future<void>? _loading;
  static bool get ready => _runtime != null;

  static Future<void> load() => _loading ??= _load();
  static Future<void> _load() async {
    final source = await rootBundle.loadString('assets/database/battle_engine.js');
    final runtime = getJavascriptRuntime(xhr: false, extraArgs: {'stackSize': 4 * 1024 * 1024});
    final result = runtime.evaluate(source, sourceUrl: 'battle_engine.js');
    if (result.isError) {
      runtime.dispose();
      throw StateError('Não foi possível carregar as regras da batalha: ${result.stringResult}');
    }
    _runtime = runtime;
  }

  static Map<String, dynamic> call(String method, List<Object?> args) {
    final runtime = _runtime;
    if (runtime == null) throw StateError('As regras da batalha ainda não foram carregadas');
    final result = runtime.evaluate('JSON.stringify(PocketDexSim.$method(...${jsonEncode(args)}))');
    if (result.isError) throw StateError(result.stringResult);
    return Map<String, dynamic>.from(jsonDecode(result.stringResult) as Map);
  }

  static void release(int handle) {
    _runtime?.evaluate('PocketDexSim.dispose($handle)');
  }
}
