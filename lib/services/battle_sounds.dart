// lib/services/battle_sounds.dart
//
// Sons da batalha (assets/database/sounds, feitos por
// tool/build_battle_sounds.py: sintetizados, nada copiado de jogo). Igual ao
// site (web-site/src/lib/battleSound.js). Efeitos e música podem ser
// desligados nas Configurações.

import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';

import 'app_settings.dart';
import 'turn_battle.dart';

class BattleSounds {
  BattleSounds._();

  // Nos testes não há áudio (o plugin não existe lá).
  static final bool _off = Platform.environment.containsKey('FLUTTER_TEST');
  static AudioPlayer? _music;

  /// Um efeito: hit, super, weak, faint, throw, open, recall, statup, statdown, heal, select, victory.
  static Future<void> play(String name, {double volume = 0.6}) async {
    if (_off || !AppSettings.instance.battleSounds) return;
    try {
      // Um tocador por efeito (dois golpes seguidos tocam os dois); some ao terminar.
      final player = AudioPlayer();
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setVolume(volume);
      player.onPlayerComplete.first.then((_) => player.dispose());
      await player.play(AssetSource('database/sounds/$name.mp3'));
    } catch (_) {
      // Sem som: a batalha continua.
    }
  }

  /// A música da batalha, em loop.
  /// A música em loop: battle_music, gym_music (líderes) ou champion_music.
  static Future<void> startMusic([String track = 'battle_music']) async {
    if (_off || !AppSettings.instance.battleMusic) return;
    try {
      final player = _music ??= AudioPlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(0.3);
      await player.play(AssetSource('database/sounds/$track.mp3'));
    } catch (_) {}
  }

  static Future<void> stopMusic() async {
    if (_off) return;
    try {
      await _music?.stop();
    } catch (_) {}
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
