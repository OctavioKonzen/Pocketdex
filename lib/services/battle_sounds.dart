// lib/services/battle_sounds.dart
//
// Sons da batalha (assets/database/sounds, feitos por
// tool/build_battle_sounds.py: sintetizados, nada copiado de jogo). Igual ao
// site (web-site/src/lib/battleSound.js). Efeitos e música podem ser
// desligados nas Configurações.

import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

import 'app_settings.dart';
import 'turn_battle.dart';

class BattleSounds {
  BattleSounds._();

  // Nos testes não há áudio (o plugin não existe lá).
  static final bool _off = Platform.environment.containsKey('FLUTTER_TEST');
  static AudioPlayer? _music;

  // Até 3 tocadores fixos por efeito, usados em rodízio (dois golpes seguidos
  // tocam os dois). Antes cada som criava um tocador novo que nunca era
  // liberado: no Android o modo de baixa latência não avisa quando termina, e
  // cada um seguia consultando a posição do som a cada quadro da tela, então a
  // batalha ia travando.
  static final Map<String, List<AudioPlayer>> _fx = {};
  static final Map<String, int> _nextFx = {};
  static const _fxPlayers = 3;

  static Future<AudioPlayer> _fxPlayer(String name) async {
    final players = _fx.putIfAbsent(name, () => []);
    if (players.length < _fxPlayers) {
      final player = AudioPlayer()..positionUpdater = null;
      players.add(player);
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setSource(AssetSource('database/sounds/$name.mp3'));
      return player;
    }
    final i = (_nextFx[name] ?? 0) % _fxPlayers;
    _nextFx[name] = i + 1;
    return players[i];
  }

  /// Um efeito: hit, super, weak, faint, throw, open, recall, statup, statdown, heal, select, victory.
  static Future<void> play(String name, {double volume = 0.6}) async {
    // Minimizado ou em outra tela: sem efeitos (a batalha segue sem som).
    if (_off || !AppSettings.instance.battleSounds || _backgrounded || _covered) return;
    try {
      final player = await _fxPlayer(name);
      await player.stop();
      await player.setVolume(volume);
      await player.resume();
    } catch (_) {
      // Sem som: a batalha continua.
    }
  }

  /// A música da batalha deve estar tocando? (false ao sair da batalha, mesmo
  /// que o arquivo ainda esteja carregando: aí ela não começa depois.)
  static bool _wanted = false;
  // Quem pediu a música (a tela da batalha): só ela pode parar. A próxima
  // batalha começa antes da anterior fechar e não pode ficar sem música.
  static Object? _owner;
  // Pausada por outro motivo: app minimizado/trocado ou outra tela por cima da batalha.
  static bool _backgrounded = false, _covered = false;
  static _Lifecycle? _lifecycle;

  /// Avisa quando outra tela abre por cima da batalha (BattleViewState, RouteAware).
  static final RouteObserver<ModalRoute<void>> routes = RouteObserver<ModalRoute<void>>();

  /// A música em loop: battle_music, gym_<região> (líderes) ou champion_<nome>.
  static Future<void> startMusic([String track = 'battle_music', Object? owner]) async {
    if (_off || !AppSettings.instance.battleMusic) return;
    _wanted = true;
    _owner = owner;
    _covered = false;
    _lifecycle ??= _Lifecycle()..attach();
    try {
      // Sem acompanhar a posição (a música só toca em loop): nada de consulta a cada quadro.
      final player = _music ??= AudioPlayer()..positionUpdater = null;
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(0.3);
      await player.setSource(AssetSource('database/sounds/$track.mp3'));
      // Saiu da batalha (ou minimizou) enquanto carregava: não começa.
      if (_wanted && !_backgrounded && !_covered) await player.resume();
    } catch (_) {}
  }

  static Future<void> stopMusic([Object? owner]) async {
    if (owner != null && !identical(owner, _owner)) return;
    _wanted = false;
    if (_off) return;
    try {
      await _music?.stop();
    } catch (_) {}
  }

  /// Outra tela por cima da batalha (true) ou a batalha de volta (false).
  static Future<void> setCovered(bool covered, [Object? owner]) async {
    if (owner != null && !identical(owner, _owner)) return;
    _covered = covered;
    await _sync();
  }

  static Future<void> _sync() async {
    if (_off) return;
    final player = _music;
    if (player == null) return;
    if (_wanted && !_backgrounded && !_covered) {
      try {
        await player.resume();
      } catch (_) {}
      return;
    }
    // Os efeitos que ainda estão tocando também param.
    for (final fx in _fx.values.expand((p) => p)) {
      fx.stop().catchError((_) {});
    }
    try {
      await player.pause();
    } catch (_) {}
    // Se a pausa não pegou (o tocador ainda estava carregando, por exemplo),
    // para de vez: voltando para a batalha, a música recomeça do início.
    if (player.state == PlayerState.playing) {
      try {
        await player.stop();
      } catch (_) {}
    }
  }

  /// O som de cada evento ([lastEffect]: o último "É super eficaz"/"Não é muito eficaz").
  static String? of(BattleEvent e, String? lastEffect) {
    switch (e.t) {
      case 'hp':
        return lastEffect == 'super' ? 'super' : lastEffect == 'weak' ? 'weak' : 'hit';
      case 'faint':
        return 'faint';
      case 'heal':
        return 'heal';
      case 'text':
        if (e.key.startsWith('statUp')) return 'statup';
        if (e.key.startsWith('statDown')) return 'statdown';
    }
    return null;
  }
}

/// App minimizado ou trocado: a música pausa; voltando para a batalha, continua.
class _Lifecycle with WidgetsBindingObserver {
  void attach() {
    WidgetsBinding.instance.addObserver(this);
    final now = WidgetsBinding.instance.lifecycleState;
    BattleSounds._backgrounded = now != null && now != AppLifecycleState.resumed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final away = state != AppLifecycleState.resumed;
    if (away == BattleSounds._backgrounded) return;
    BattleSounds._backgrounded = away;
    BattleSounds._sync();
  }
}
