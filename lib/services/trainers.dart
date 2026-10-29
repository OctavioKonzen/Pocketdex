// lib/services/trainers.dart
//
// Os treinadores no estilo BW (assets/database/trainers.json, feito por
// tool/build_trainers.py): a frente animada em tira de quadros e, nos
// jogáveis, as costas lançando a Poké Ball. Igual ao site (web-site/src/lib/trainers.js).

import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

import 'user_data.dart';

class Trainer {
  final String id, name, title;

  /// Lado de cada quadro da frente (px) e quantos quadros.
  final int size, frames;

  /// Os jogáveis vêm desenhados maiores: na tela, do tamanho dos outros.
  final double scale;

  /// Costas lançando a Poké Ball: largura e altura de cada quadro e quantos (null: não tem).
  final ({int width, int height, int frames})? back;

  /// Onde ficam os pés no quadro (px de cima; tool/trainer_figures.py). Sem: o fim do quadro.
  final int? feet;

  /// Onde começa o desenho (o alto da cabeça, px de cima). Sem: o começo do quadro.
  final int? head;

  /// O centro do tronco na horizontal (px no quadro; tool/trainer_figures.py): para mostrar da cintura para cima.
  final double? bustX;

  const Trainer(
      {required this.id, required this.name, required this.title, required this.size, required this.frames, this.scale = 1, this.back, this.feet, this.head, this.bustX});

  String get front => 'assets/database/sprites/trainers/$id.png';
  /// Com as animações completas: parado (animado) e de costas lançando a Poké Ball. Só esses dá para escolher. Igual ao site.
  bool get fullyAnimated => back != null && back!.frames > 1 && frames > 1;

  String get backPath => 'assets/database/sprites/trainers/${id}_back.png';

  factory Trainer.fromJson(Map<String, dynamic> j) {
    final b = j['back'] as Map<String, dynamic>?;
    return Trainer(
      id: j['id'] as String,
      name: j['name'] as String,
      title: j['title'] as String,
      size: (j['size'] as num).toInt(),
      frames: (j['frames'] as num).toInt(),
      scale: (j['scale'] as num?)?.toDouble() ?? 1,
      back: b == null ? null : (width: (b['width'] as num).toInt(), height: (b['height'] as num).toInt(), frames: (b['frames'] as num).toInt()),
      feet: ((j['fig'] as List?)?.last as num?)?.toInt(),
      head: ((j['fig'] as List?)?.first as num?)?.toInt(),
      bustX: ((j['bust'] as List?)?.first as num?)?.toDouble(),
    );
  }
}

class Trainers {
  Trainers._();

  /// Foto de perfil de treinador: [avatarBase] + a posição dele na lista (igual ao site, TRAINER_AVATAR).
  static const avatarBase = 1000000;

  static List<Trainer>? _list;
  static Future<List<Trainer>>? _loading;

  /// A lista (já carregada) ou vazia.
  static List<Trainer> get list => _list ?? const [];

  static Future<List<Trainer>> load() => _loading ??= rootBundle.loadString('assets/database/trainers.json').then((text) {
        final list = [for (final j in jsonDecode(text) as List) Trainer.fromJson(j as Map<String, dynamic>)];
        _list = list;
        return list;
      });

  static Trainer? byId(String? id) => list.where((t) => t.id == id).firstOrNull;

  /// O seu treinador (o escolhido ou o Red).
  static Trainer? get mine => byId(UserData.instance.trainer) ?? list.firstOrNull;

  /// O treinador de uma foto de perfil (null se a foto é de Pokémon).
  static Trainer? ofAvatar(int? avatar) {
    if (avatar == null || avatar < avatarBase) return null;
    final i = avatar - avatarBase;
    return i < list.length ? list[i] : null;
  }

  /// As classes de treinador comuns (Youngster, Hiker, Swimmer...): os treinadores de rota usam só estas (nunca um
  /// líder de ginásio ou um personagem importante). Igual ao site.
  static const _genericClasses = {
    'acetrainer', 'acetrainercouple', 'acetrainerf', 'acetrainersnow', 'acetrainersnowf', 'aromalady', 'artist', 'backpacker', 'backpackerf', 'baker',
    'ballguy', 'battlegirl', 'beauty', 'bellhop', 'biker', 'birdkeeper', 'blackbelt', 'boarder', 'bugcatcher', 'burglar',
    'butler', 'cabbie', 'cafemaster', 'cameraman', 'camper', 'chef', 'clerk', 'clerkf', 'clown', 'collector',
    'cook', 'courier', 'cowgirl', 'cyclist', 'cyclistf', 'dancer', 'delinquent', 'depotagent', 'doctor', 'doubleteam',
    'dragontamer', 'fairytalegirl', 'firebreather', 'firefighter', 'fisherman', 'freediver', 'furisodegirl-black', 'furisodegirl-blue', 'furisodegirl-pink', 'furisodegirl-white',
    'gambler', 'garcon', 'gardener', 'gentleman', 'golfer', 'guitarist', 'harlequin', 'hiker', 'hooligans', 'hoopster',
    'idol', 'infielder', 'janitor', 'jogger', 'juggler', 'kimonogirl', 'lady', 'lass', 'linebacker', 'madame',
    'maid', 'medium', 'musician', 'ninjaboy', 'nurseryaide', 'officeworker', 'officeworkerf', 'owner', 'parasollady', 'picnicker',
    'pilot', 'pokefan', 'pokefanf', 'pokekid', 'pokemaniac', 'pokemonbreeder', 'pokemonbreederf', 'pokemonranger', 'pokemonrangerf', 'policeman',
    'postman', 'preschooler', 'preschoolerf', 'preschoolers', 'psychic', 'psychicf', 'punkgirl', 'punkguy', 'railstaff', 'rancher',
    'reporter', 'richboy', 'risingstar', 'risingstarf', 'rollerskater', 'rollerskaterf', 'roughneck', 'ruffian', 'ruinmaniac', 'sailor',
    'schoolboy', 'schoolgirl', 'schoolkid', 'schoolkidf', 'scientist', 'scientistf', 'scubadiver', 'sightseer', 'sightseerf', 'sisandbro',
    'skier', 'skierf', 'skytrainer', 'skytrainerf', 'smasher', 'streetthug', 'striker', 'supernerd', 'surfer', 'swimmer',
    'swimmerf', 'teacher', 'tourist', 'touristf', 'touristf2', 'tuber', 'tuberf', 'twins', 'veteran', 'veteranf',
    'waiter', 'waitress', 'worker', 'workerice', 'youngathlete', 'youngathletef', 'youngcouple', 'youngn', 'youngster',
  };
  static const _namedTitles = {'Líder de Ginásio', 'Elite Four', 'Treinador', 'Treinadora', 'Rival', 'Cérebro da Frente', 'Campeão', 'Campeã', 'Equipe Rocket', 'Recruta', 'Equipe Plasma', 'Team Rocket', 'Chefe da Equipe Rocket', 'Chefe do Metrô', 'Professor'};

  /// É um treinador comum (de classe), não um personagem com nome?
  static bool isGeneric(Trainer t) =>
      t.back == null &&
      (t.title == 'Pokémon Showdown'
          ? t.id.startsWith('sd-') && _genericClasses.contains(t.id.substring(3).replaceFirst(RegExp(r'-(gen\d+\w*|\w*\d+)$'), ''))
          : !_namedTitles.contains(t.title));

  /// Um treinador comum, sempre o mesmo para a mesma semente (o andar).
  static Trainer? generic(int seed) {
    final options = list.where(isGeneric).toList();
    return options.isEmpty ? null : options[seed.abs() % options.length];
  }

  /// Um treinador para o computador (não repete o seu, e não é um dos jogáveis).
  static Trainer? random([Random? rng]) {
    final options = list.where((t) => t.back == null && t.id != UserData.instance.trainer).toList();
    if (options.isEmpty) return null;
    return options[(rng ?? Random()).nextInt(options.length)];
  }
}
