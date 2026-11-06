// lib/services/battle_sounds.dart
//
// Sons da batalha (assets/database/sounds, feitos por
// tool/build_battle_sounds.py: sintetizados, nada copiado de jogo). Igual ao
// site (web-site/src/lib/battleSound.js). Efeitos e música podem ser
// desligados nas Configurações.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:flutter/widgets.dart';

import 'app_settings.dart';
import 'music_cache.dart';
import 'turn_battle.dart';

class BattleSounds {
  BattleSounds._();

  // Nos testes não há áudio (o plugin não existe lá).
  static final bool _off = Platform.environment.containsKey('FLUTTER_TEST');
  // A música toca pelo just_audio (no Android, o ExoPlayer): ele repete a faixa emendando sem buraco. O audioplayers
  // voltava para o começo com um "seek" quando ela acabava, e a música dava uma travadinha a cada volta.
  static ja.AudioPlayer? _music;

  /// A troca de uma música para outra: a de antes vai abaixando enquanto a nova sobe. Igual ao site (FADE).
  static const fade = Duration(milliseconds: 800);

  /// Sobe ou desce o volume de um tocador aos poucos (em 16 passos) até [to]; no fim, [then].
  static void _ramp(ja.AudioPlayer player, double from, double to, [void Function()? then]) {
    const steps = 16;
    var k = 0;
    Timer.periodic(fade ~/ steps, (timer) {
      k++;
      player.setVolume(from + (to - from) * k / steps).catchError((_) {});
      if (k >= steps) {
        timer.cancel();
        then?.call();
      }
    });
  }

  /// A música de antes vai abaixando e, no fim, o tocador dela é liberado.
  static void _fadeOut(ja.AudioPlayer? player) {
    if (player == null) return;
    if (!player.playing) {
      player.dispose().catchError((_) {});
      return;
    }
    _ramp(player, player.volume, 0, () => player.dispose().catchError((_) {}));
  }

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
      await player.setAudioContext(mixed);
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

  /// Um efeito: hit, super, weak, faint, throw, open, recall, statup, statdown, heal, select, victory, mega, dmax.
  /// [from]: começa desse ponto do som (a fanfarra da Mega em 2x e 4x, ver [syncedStart]).
  static Future<void> play(String name, {double volume = 0.6, Duration from = Duration.zero}) async {
    // Minimizado ou em outra tela: sem efeitos (a batalha segue sem som).
    if (_off || !AppSettings.instance.battleSounds || _backgrounded || _covered) return;
    try {
      final player = await _fxPlayer(name);
      await player.stop();
      if (from > Duration.zero) await player.seek(from);
      await player.setVolume(volume * sfxLevel);
      await player.resume();
    } catch (_) {
      // Sem som: a batalha continua.
    }
  }

  /// A música da batalha deve estar tocando? (false ao sair da batalha, mesmo
  /// que o arquivo ainda esteja carregando: aí ela não começa depois.)
  static bool _wanted = false;
  static String? _track; // a música carregada no tocador
  // Quem pediu a música (a tela da batalha): só ela pode parar. A próxima
  // batalha começa antes da anterior fechar e não pode ficar sem música.
  static Object? _owner;
  // Pausada por outro motivo: app minimizado/trocado ou outra tela por cima da batalha.
  static bool _backgrounded = false, _covered = false;
  static _Lifecycle? _lifecycle;

  /// Avisa quando outra tela abre por cima da batalha (BattleViewState, RouteAware).
  /// Só telas inteiras (PageRoute): o registro, uma janela de confirmação ou um menu por cima não pausam a música.
  static final RouteObserver<PageRoute<dynamic>> routes = RouteObserver<PageRoute<dynamic>>();

  /// Os efeitos e os gritos tocam junto com a música, sem pedir o foco do áudio (no Android, pedir o foco pausa a música).
  static final mixed = AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build();

  /// A música em loop: map_<região> (o tema da região: no mapa do Pokelike, nos ginásios, campeões e batalhas
  /// comuns), mega_theme (depois da Mega Evolução) ou dmax_theme (depois do Dynamax).
  static Future<void> startMusic(String track, [Object? owner]) async {
    if (_off || !AppSettings.instance.battleMusic) return;
    // A mesma música já tocando (o tema do mapa entrando na batalha da região): continua de onde estava.
    final same = _track == track && _wanted && (_music?.playing ?? false);
    _wanted = true;
    _owner = owner;
    _covered = false;
    if (same) return;
    _track = track;
    _lifecycle ??= _Lifecycle()..attach();
    try {
      // A de antes vai abaixando num tocador à parte; a nova entra num tocador novo, subindo (a troca suave).
      _fadeOut(_music);
      // Sem pedir o foco do áudio (os efeitos tocam junto, como antes).
      final player = _music = ja.AudioPlayer(handleInterruptions: false, handleAudioSessionActivation: false);
      await player.setLoopMode(ja.LoopMode.one);
      await player.setVolume(0);
      // OGG (emenda o loop sem o buraco do MP3), baixado do site e guardado no celular (music_cache.dart):
      // mudar uma música não precisa de app novo. Sem internet e sem cópia guardada, fica sem música.
      final path = await MusicCache.pathFor(track);
      if (!_wanted || !identical(owner, _owner) || !identical(player, _music)) return;
      if (path == null) return; // a de antes já está saindo (não fica tocando na batalha)
      await player.setFilePath(path);
      // Saiu da batalha (ou minimizou) enquanto carregava: não começa. (O play só termina quando a música para: sem esperar.)
      if (_wanted && !_backgrounded && !_covered && identical(player, _music)) {
        player.play().catchError((_) {});
        _ramp(player, 0, musicLevel);
      }
    } catch (_) {}
  }

  /// O estouro da fanfarra da Mega e do Dynamax cai em 0,7 s, o clarão da animação em 1x. Mais rápido
  /// (2x, 4x), o clarão vem antes: o som começa adiantado para o estouro continuar junto. Igual ao site.
  static const hitAt = Duration(milliseconds: 700);
  static Duration syncedStart(int speed) => speed <= 1 ? Duration.zero : hitAt - hitAt ~/ speed;

  /// O volume da música no tocador, pelo das Configurações.
  /// A música e os efeitos no mesmo nível: os efeitos (golpes, Poké Ball...) são curtos e fortes, e tocavam uns 8 dB
  /// acima da música. A música sobe (0,9 × o das Configurações: 0,5 dá 0,45) e os efeitos descem (×0,6). Igual ao site.
  static double get musicLevel => 0.9 * AppSettings.instance.musicVolume;
  static const sfxLevel = 0.6;

  /// Mudou o volume nas Configurações: a música que está tocando acompanha.
  static Future<void> applyVolume() async {
    if (_off) return;
    try {
      await _music?.setVolume(musicLevel);
    } catch (_) {}
  }

  static Future<void> stopMusic([Object? owner]) async {
    if (owner != null && !identical(owner, _owner)) return;
    _wanted = false;
    if (_off) return;
    // Saindo: a música vai abaixando até parar (a próxima entra num tocador novo).
    final player = _music;
    _music = null;
    _track = null;
    _fadeOut(player);
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
      if (!player.playing) player.play().catchError((_) {});
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
    if (player.playing) {
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
        if (e.key.startsWith('statUp') || e.key == 'levelUp') return 'statup';
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
