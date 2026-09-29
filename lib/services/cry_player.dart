// lib/services/cry_player.dart
//
// Toca o grito de um Pokémon (arquivo do banco local, assets/database/cries).

import 'package:audioplayers/audioplayers.dart';

class CryPlayer {
  CryPlayer._();
  static final CryPlayer instance = CryPlayer._();

  AudioPlayer? _player;

  Future<void> play(int speciesId) async {
    try {
      final player = _player ??= AudioPlayer();
      await player.stop();
      await player.setVolume(0.7);
      await player.play(AssetSource('database/cries/$speciesId.mp3'));
    } catch (_) {
      // Sem som (ex.: aparelho sem saída de áudio): o app continua.
    }
  }

  Future<void> stop() async {
    try {
      await _player?.stop();
    } catch (_) {}
  }
}
