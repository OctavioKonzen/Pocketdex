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

  const Trainer({required this.id, required this.name, required this.title, required this.size, required this.frames, this.scale = 1, this.back});

  String get front => 'assets/database/sprites/trainers/$id.png';
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

  /// Um treinador para o computador (não repete o seu, e não é um dos jogáveis).
  static Trainer? random([Random? rng]) {
    final options = list.where((t) => t.back == null && t.id != UserData.instance.trainer).toList();
    if (options.isEmpty) return null;
    return options[(rng ?? Random()).nextInt(options.length)];
  }
}
