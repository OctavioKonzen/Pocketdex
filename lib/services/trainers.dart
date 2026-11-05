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

  /// As treinadoras entre os que dá para escolher (o resto é menino). Igual ao site.
  static const girls = {'leaf', 'may', 'lyra', 'dawn', 'hilda', 'hilda-2', 'rosa', 'rosa-2', 'bianca', 'cheryl', 'marley', 'mira'};

  /// Dá para escolher para a batalha: tem as costas lançando a Poké Ball (os sem animação de frente respiram). Igual ao site.
  static bool playable(Trainer t) => t.back != null && t.back!.frames > 1;

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
  static const _namedTitles = {'Líder de Ginásio', 'Elite dos Quatro', 'Treinador', 'Treinadora', 'Rival', 'Cérebro da Frente', 'Campeão', 'Campeã', 'Equipe Rocket', 'Recruta', 'Equipe Plasma', 'Team Rocket', 'Chefe da Equipe Rocket', 'Chefe do Metrô', 'Professor'};

  /// É um treinador comum (de classe), não um personagem com nome?
  static bool isGeneric(Trainer t) =>
      t.back == null &&
      (t.title == 'Pokémon Showdown'
          ? t.id.startsWith('sd-') && _genericClasses.contains(t.id.substring(3).replaceFirst(RegExp(r'-(gen\d+\w*|\w*\d+)$'), ''))
          : !_namedTitles.contains(t.title));

  /// Os sprites com dois treinadores juntos (gêmeas, casal, irmãos, a dupla da Equipe Rocket...): só nas batalhas em
  /// dupla; na batalha de um contra um, só quem está sozinho. Não há sprite com três: a batalha tripla é como uma horda
  /// (sem treinador). Igual ao site.
  static const pairIds = {'cool-couple', 'crush-kin', 'sis-and-bro', 'twins', 'young-couple', 'tate-liza', 'sd-acetrainercouple', 'sd-backers',
    'sd-backersf', 'sd-doubleteam', 'sd-hooligans', 'sd-interviewers', 'sd-preschoolers', 'sd-sisandbro', 'sd-teammates', 'sd-teamrocket', 'sd-twins', 'sd-youngcouple'};
  static bool isPair(Trainer t) => pairIds.contains(t.id);

  /// Quem faz sentido em cada lugar (a classe do treinador, sem o "sd-", o número e os hífens): nadador e pescador na
  /// água, alpinista na montanha e na caverna, esquiador na neve, executivo e policial na cidade... Igual ao site.
  static const biomeTrainers = <String, List<String>>{
    'grass': ['youngster', 'lass', 'bugcatcher', 'camper', 'picnicker', 'schoolkid', 'schoolkidf', 'schoolboy', 'schoolgirl', 'pokefan', 'pokefanf', 'acetrainer', 'acetrainerf', 'acetrainerm', 'preschooler', 'preschoolerf', 'birdkeeper', 'cyclist', 'cyclistf', 'jogger', 'pokekid'],
    'forest': ['bugcatcher', 'camper', 'picnicker', 'pokemonranger', 'pokemonrangerf', 'rangerm', 'rangerf', 'aromalady', 'gardener', 'backpacker', 'backpackerf', 'ninjaboy', 'fairytalegirl'],
    'flowers': ['aromalady', 'lass', 'beauty', 'gardener', 'fairytalegirl', 'picnicker', 'parasollady', 'preschoolerf', 'pokefanf'],
    'bamboo': ['ninjaboy', 'blackbelt', 'battlegirl', 'kimonogirl', 'hiker', 'crushgirl'],
    'water': ['swimmer', 'swimmerf', 'swimmerm', 'fisherman', 'sailor', 'tuber', 'tuberf', 'tuberm', 'surfer', 'scubadiver', 'freediver'],
    'beach': ['swimmer', 'swimmerf', 'swimmerm', 'tuber', 'tuberf', 'tuberm', 'surfer', 'sailor', 'fisherman', 'parasollady', 'beauty', 'sightseer', 'sightseerf', 'tourist', 'touristf'],
    'underwater': ['scubadiver', 'freediver', 'swimmer', 'swimmerf', 'swimmerm', 'fisherman'],
    'seacave': ['scubadiver', 'freediver', 'swimmer', 'swimmerf', 'fisherman', 'sailor', 'hiker'],
    'swamp': ['fisherman', 'bugcatcher', 'pokemaniac', 'psychic', 'psychicf', 'medium', 'supernerd'],
    'poisoncave': ['pokemaniac', 'supernerd', 'scientist', 'scientistf', 'hiker', 'medium'],
    'sewer': ['supernerd', 'burglar', 'pokemaniac', 'worker', 'janitor', 'punkguy', 'punkgirl', 'delinquent'],
    'cave': ['hiker', 'ruinmaniac', 'pokemaniac', 'supernerd', 'blackbelt', 'backpacker', 'collector', 'worker'],
    'crystal': ['hiker', 'ruinmaniac', 'collector', 'supernerd', 'scientist', 'scientistf'],
    'icecave': ['skier', 'skierf', 'boarder', 'hiker', 'acetrainersnow', 'acetrainersnowf', 'workerice'],
    'snow': ['skier', 'skierf', 'boarder', 'acetrainersnow', 'acetrainersnowf', 'workerice', 'hiker'],
    'mountain': ['hiker', 'blackbelt', 'battlegirl', 'backpacker', 'backpackerf', 'pokemonranger', 'pokemonrangerf', 'birdkeeper', 'dragontamer', 'veteran', 'veteranf'],
    'desert': ['hiker', 'ruinmaniac', 'backpacker', 'backpackerf', 'firebreather', 'tourist', 'collector'],
    'dunes': ['hiker', 'ruinmaniac', 'backpacker', 'firebreather', 'collector', 'medium'],
    'volcano': ['firebreather', 'hiker', 'blackbelt', 'worker', 'supernerd'],
    'lavacave': ['firebreather', 'hiker', 'worker', 'supernerd'],
    'city': ['officeworker', 'officeworkerf', 'gentleman', 'lady', 'richboy', 'madame', 'clerk', 'clerkf', 'policeman', 'waiter', 'waitress', 'artist', 'musician', 'guitarist', 'idol', 'reporter', 'cameraman', 'punkguy', 'punkgirl', 'delinquent', 'roughneck', 'cyclist', 'cyclistf', 'rollerskater', 'rollerskaterf', 'beauty', 'juggler', 'clown'],
    'sky': ['birdkeeper', 'skytrainer', 'skytrainerf', 'pilot', 'dragontamer'],
    'tower': ['medium', 'psychic', 'psychicf', 'psychicm', 'channeler'],
    'ruins': ['ruinmaniac', 'psychic', 'psychicf', 'medium', 'collector'],
    'temple': ['psychic', 'psychicf', 'medium', 'blackbelt', 'battlegirl', 'kimonogirl'],
    'plant': ['scientist', 'scientistf', 'supernerd', 'worker', 'engineer'],
  };

  /// A classe de um treinador ("sd-swimmerf" → "swimmerf", "bug-catcher" → "bugcatcher").
  static String trainerClass(Trainer t) => t.id.replaceFirst(RegExp(r'^sd-'), '').replaceFirst(RegExp(r'-(gen\d+\w*|\w*\d+)$'), '').replaceAll('-', '');

  /// Um treinador comum, sempre o mesmo para a mesma semente (o andar); com [biome], um que faz sentido naquele lugar.
  static Trainer? generic(int seed, [String? biome]) {
    final options = list.where((t) => isGeneric(t) && !isPair(t)).toList();
    final want = biomeTrainers[biome];
    final fit = want == null ? <Trainer>[] : options.where((t) => want.contains(trainerClass(t))).toList();
    final pool = fit.isNotEmpty ? fit : options;
    return pool.isEmpty ? null : pool[seed.abs() % pool.length];
  }

  /// Os treinadores comuns ganham nome e fala (como nos jogos: "Youngster Joel"). Nomes nossos (sem os dos personagens
  /// dos jogos); a fala antes da luta (intro) e quando perde (beat) são textos traduzidos. Sempre os mesmos para a mesma
  /// semente. Igual ao site (trainerPersona).
  static const namesM = ['Joel', 'Ben', 'Tim', 'Eli', 'Theo', 'Lucas', 'Rafa', 'Davi', 'Leo', 'Noah', 'Hugo', 'Igor', 'Caio', 'Enzo', 'Gabe', 'Otto', 'Bruno', 'Dante', 'Felix', 'Ivo'];
  static const namesF = ['Lia', 'Mia', 'Ana', 'Bia', 'Luna', 'Nina', 'Sofia', 'Clara', 'Alice', 'Maya', 'Julia', 'Lara', 'Eva', 'Zoe', 'Helena', 'Olga', 'Vera', 'Tina', 'Paula', 'Duda'];
  static const intros = [
    'Ei, você! Nossos olhares se cruzaram, agora temos que batalhar!',
    'Treinei a manhã inteira aqui. Vamos ver se valeu a pena!',
    'Meu time está em ótima forma hoje!',
    'Não vou pegar leve só porque você chegou longe.',
    'Achei que ninguém passaria por aqui. Bora lutar!',
    'Esse lugar é meu ponto de treino favorito!',
    'Você parece forte… perfeito!',
    'Aposto que meu Pokémon é mais rápido que o seu!',
  ];
  static const beats = [
    'Ah, não! Você é bom mesmo.',
    'Preciso treinar mais um pouco…',
    'Que batalha! Valeu pela luta.',
    'Meus Pokémon deram tudo de si.',
    'Perdi, mas aprendi muita coisa.',
    'Da próxima vez vai ser diferente!',
  ];
  static final _femaleClass = RegExp(r'(f|girl|lass|lady|beauty|picnicker|madame|nurse|idol|maid|queen|woman|sis|socialite|aromalady|parasollady)$');

  static ({String name, String intro, String beat}) persona(Trainer t, int seed) {
    final cls = trainerClass(t);
    final s = seed.abs() & 0xFFFFFFFF;
    final names = _femaleClass.hasMatch(cls) ? namesF : namesM;
    // "Swimmerf" → "Swimmer" (a classe feminina no nome da imagem).
    final title = cls.endsWith('f') && t.name.endsWith('f') ? t.name.substring(0, t.name.length - 1) : t.name;
    return (name: '$title ${names[(s >> 3) % names.length]}', intro: intros[(s >> 7) % intros.length], beat: beats[(s >> 11) % beats.length]);
  }

  /// Dois treinadores comuns juntos (a batalha em dupla), sempre os mesmos para a mesma semente.
  static Trainer? pair(int seed) {
    final options = list.where((t) => isGeneric(t) && isPair(t)).toList();
    return options.isEmpty ? null : options[seed.abs() % options.length];
  }

  /// Um treinador para o computador (não repete o seu, não é um dos jogáveis e está sozinho: um contra um).
  static Trainer? random([Random? rng]) {
    final options = list.where((t) => t.back == null && t.id != UserData.instance.trainer && !isPair(t)).toList();
    if (options.isEmpty) return null;
    return options[(rng ?? Random()).nextInt(options.length)];
  }
}
