// As animações dos golpes como no port de Black & White: o plano de cada golpe vem do mesmo battleFx.js do site
// (assets/database/battle_fx.js, rodando no QuickJS), e aqui ficam a câmera, o tremor, a HUD e os sprites em cada
// instante (iguais a fxCamera, fxShake, fxHud e fxSprite do site). Quem desenha é o battle_fx_painter.dart.

import 'dart:convert';
import 'dart:math' as math;

import 'package:quickjs_engine/quickjs_engine.dart';

import 'ota_update.dart';

/// O plano de um golpe (o JSON do battleFx.js).
class MoveFxPlan {
  MoveFxPlan(this.raw)
      : dur = (raw['dur'] as num).toDouble(),
        from = (raw['from'] as num?)?.toInt() ?? 0,
        world = [for (final v in (raw['world'] as List? ?? const [960, 540])) (v as num).toDouble()],
        cam = [for (final k in raw['cam'] as List) [for (final v in k as List) (v as num).toDouble()]],
        hud = raw['hud'] == null ? null : [for (final v in raw['hud'] as List) (v as num).toDouble()],
        shake = [for (final k in raw['shake'] as List) [for (final v in k as List) (v as num).toDouble()]],
        sprites = [for (final s in raw['sprites'] as List) Map<String, dynamic>.from(s as Map)],
        layers = [for (final l in raw['layers'] as List) Map<String, dynamic>.from(l as Map)];

  final Map<String, dynamic> raw;
  final double dur;
  final int from;
  final List<double> world;
  final List<List<double>> cam;
  final List<double>? hud;
  final List<List<double>> shake;
  final List<Map<String, dynamic>> sprites;
  final List<Map<String, dynamic>> layers;
}

/// Onde fica um lado no palco (mundo de 960 × 540): o pé, a altura, a caixa do sprite, a boca e a frente.
class FxSpot {
  FxSpot(Map raw)
      : x = (raw['x'] as num).toDouble(),
        y = (raw['y'] as num).toDouble(),
        h = (raw['h'] as num).toDouble(),
        left = ((raw['box'] as Map)['left'] as num).toDouble(),
        top = ((raw['box'] as Map)['top'] as num).toDouble(),
        w = ((raw['box'] as Map)['w'] as num).toDouble(),
        boxH = ((raw['box'] as Map)['h'] as num).toDouble();
  final double x, y, h, left, top, w, boxH;
}

/// O que acontece com um sprite num instante: deslocamento, escala, cor por cima, silhueta branca e se aparece.
class FxLook {
  double dx = 0, dy = 0, sx = 1, sy = 1, tintA = 0, alpha = 1;
  String? tint;
  bool white = false, hidden = false;
}

class BattleFx {
  BattleFx._();
  static JavascriptRuntime? _runtime;
  static Future<void>? _loading;
  static bool get ready => _runtime != null;

  /// Carrega o battle_fx.js, a boca/frente de cada sprite e a receita de cada golpe (uma vez).
  static Future<void> load() => _loading ??= _load();
  static Future<void> _load() async {
    try {
      final runtime = getJavascriptRuntime(xhr: false);
      final result = runtime.evaluate(await OtaUpdate.loadText('battle_fx.js'), sourceUrl: 'battle_fx.js');
      if (result.isError) {
        runtime.dispose();
        return;
      }
      final anchors = await OtaUpdate.loadText('fx_anchors.json');
      final recipes = await OtaUpdate.loadText('move_fx.json');
      final set = runtime.evaluate('JSON.stringify(PocketDexFx.setData($anchors, $recipes))');
      if (set.isError) {
        runtime.dispose();
        return;
      }
      _runtime = runtime;
    } catch (_) {
      // Sem o plano novo: a batalha usa as animações de antes.
    }
  }

  static Object? _call(String method, List<Object?> args) {
    final runtime = _runtime;
    if (runtime == null) return null;
    final result = runtime.evaluate('JSON.stringify(PocketDexFx.$method(...${jsonEncode(args)}))');
    if (result.isError) return null;
    return jsonDecode(result.stringResult);
  }

  /// Onde ficam o seu (near, de costas) e o outro (far, de frente) como no port; null sem os dados.
  static ({FxSpot near, FxSpot far})? stage(int near, int far) {
    final raw = _call('stage', [near, far]);
    if (raw is! Map || raw['near'] is! Map || raw['far'] is! Map) return null;
    if ((raw['near'] as Map)['box'] == null || (raw['far'] as Map)['box'] == null) return null;
    return (near: FxSpot(raw['near'] as Map), far: FxSpot(raw['far'] as Map));
  }

  /// A cena [kind] ('sendout', 'recall' ou 'faint') do lado [side] (0 você, 1 o outro), como no Black & White.
  static MoveFxPlan? scene({required String kind, required int side, required int near, required int far, int seed = 1}) {
    final raw = _call('scene', [
      {'kind': kind, 'side': side, 'near': near, 'far': far, 'seed': seed}
    ]);
    if (raw is! Map) return null;
    try {
      return MoveFxPlan(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  /// O plano do golpe [slug] usado por [from] (0 você, 1 o outro), com os sprites [near] e [far].
  static MoveFxPlan? plan({required String slug, required String type, required String category, required int from, required int near, required int far, bool self = false, List? entry, int seed = 1}) {
    final raw = _call('plan', [
      {'slug': slug, 'type': type, 'category': category, 'from': from, 'near': near, 'far': far, 'self': self, 'entry': entry, 'seed': seed}
    ]);
    if (raw is! Map) return null;
    try {
      return MoveFxPlan(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  // ---- Iguais ao battleFx.js ----

  static double rand(num i) {
    final x = math.sin(i * 127.1 + 311.7) * 43758.5453;
    return x - x.floorToDouble();
  }

  static double ease(double k) => k < 0.5 ? 2 * k * k : 1 - math.pow(-2 * k + 2, 2) / 2;

  /// A câmera no instante [ms]: [x, y, zoom, giro].
  static List<double> camera(MoveFxPlan p, double ms) {
    final k = p.cam;
    if (k.isEmpty) return [p.world[0] / 2, p.world[1] / 2, 1, 0];
    if (ms <= k.first[0]) return k.first.sublist(1);
    for (var i = 0; i < k.length - 1; i++) {
      final a = k[i], b = k[i + 1];
      if (ms <= b[0]) {
        final u = ease(((ms - a[0]) / math.max(1, b[0] - a[0])).clamp(0.0, 1.0));
        return [for (var j = 1; j < 5; j++) a[j] + (b[j] - a[j]) * u];
      }
    }
    return k.last.sublist(1);
  }

  /// A tela tremendo no instante [ms]: (dx, dy).
  static (double, double) shake(MoveFxPlan p, double ms) {
    var amp = 0.0;
    for (final s in p.shake) {
      if (ms >= s[0] && ms <= s[1]) amp = math.max(amp, s[2] * (1 - (ms - s[0]) / (s[1] - s[0])));
    }
    if (amp == 0) return (0, 0);
    final i = (ms / 33).floor();
    return ((rand(i) - 0.5) * 2 * amp, (rand(i + 99) - 0.5) * 2 * amp);
  }

  /// HP e caixas: 1 visível, 0 escondido.
  static double hud(MoveFxPlan p, double ms) {
    final h = p.hud;
    if (h == null) return 1;
    if (ms < h[0]) return 1;
    if (ms < h[0] + 150) return 1 - (ms - h[0]) / 150;
    if (ms < h[1]) return 0;
    return ((ms - h[1]) / 150).clamp(0.0, 1.0);
  }

  /// Como fica quem ataca ('A') ou o alvo ('T') no instante [ms].
  static FxLook sprite(MoveFxPlan p, String who, double ms) {
    final out = FxLook();
    for (final e in p.sprites) {
      if (e['who'] != who) continue;
      final t0 = (e['t0'] as num).toDouble();
      if (e['k'] == 'flash') {
        final k = ms - t0;
        final n = (e['n'] as num).toDouble();
        if (k >= 0 && k < n * 200) out.white = (k / 100).floor() % 2 == 0;
        continue;
      }
      final t1 = (e['t1'] as num).toDouble();
      if (ms < t0 || ms > t1) continue;
      final k = (ms - t0) / math.max(1, t1 - t0);
      switch (e['k']) {
        case 'tint':
          final fade = math.min(1.0, math.min(k * 6, (1 - k) * 4));
          final pulse = e['pulse'] != null ? 0.8 + 0.2 * math.sin(ms / 1000 * (e['pulse'] as num)) : 1.0;
          out.tint = e['color'] as String;
          out.tintA = math.max(out.tintA, (e['a'] as num) * fade * pulse);
        case 'move':
          final bounce = e['bounce'] as num?;
          final f = bounce != null
              ? (math.sin(k * math.pi * bounce)).abs() * (1 - k)
              : e['back'] == 0
                  ? ease(k)
                  : math.sin(k * math.pi);
          out.dx += (e['dx'] as num) * f;
          out.dy += (e['dy'] as num) * f;
        case 'hide':
          out.hidden = true;
        case 'grow':
          // Cresce (sai da Poké Ball) ou encolhe (volta para ela), a partir dos pés.
          final g = (e['s0'] as num) + ((e['s1'] as num) - (e['s0'] as num)) * ease(k);
          out.sx *= g;
          out.sy *= g;
        case 'fade':
          out.alpha *= (e['a0'] as num) + ((e['a1'] as num) - (e['a0'] as num)) * k;
        case 'silhouette':
          out.white = true;
        case 'squash':
          final f = math.sin(k * math.pi);
          out.sx *= 1 + ((e['sx'] as num) - 1) * f;
          out.sy *= 1 + ((e['sy'] as num) - 1) * f;
      }
    }
    return out;
  }
}
