// lib/utils/type_relations_builder.dart

import '../models/alternate_form.dart';
import '../models/pokemon_details.dart';
import '../models/type_relations.dart';

/// Fraquezas, resistências, imunidades e vantagens de uma forma, a partir dos
/// dados de tipo carregados em [PokemonDetails].
TypeRelations buildTypeRelations(
    PokemonDetails pokeDetails, AlternateForm form) {
  final Map<String, double> weaknesses = {};
  final Map<String, double> resistances = {};
  final List<String> immunities = [];
  final Map<String, int> advantages = {};
  final Map<String, double> damageTaken = {};

  for (String typeName in form.types) {
    final typeJson = pokeDetails.allTypeDetails[typeName];
    if (typeJson != null) {
      final relations = typeJson['damage_relations'] as Map<String, dynamic>;
      for (var relation in relations.entries) {
        double multiplier = 1.0;
        if (relation.key == 'double_damage_from') {
          multiplier = 2.0;
        } else if (relation.key == 'half_damage_from') {
          multiplier = 0.5;
        } else if (relation.key == 'no_damage_from') {
          multiplier = 0.0;
        } else {
          continue;
        }
        for (var typeData in (relation.value as List)) {
          String attackingTypeName = typeData['name'];
          damageTaken.update(attackingTypeName, (value) => value * multiplier,
              ifAbsent: () => multiplier);
        }
      }
      final doubleDamageTo = relations['double_damage_to'] as List;
      for (var typeData in doubleDamageTo) {
        advantages[typeData['name']] = 1;
      }
    }
  }

  damageTaken.forEach((type, multiplier) {
    if (multiplier >= 2.0) {
      weaknesses[type] = multiplier;
    } else if (multiplier > 0 && multiplier < 1) {
      resistances[type] = multiplier;
    } else if (multiplier == 0) {
      immunities.add(type);
    }
  });

  return TypeRelations(
      weaknesses: weaknesses,
      resistances: resistances,
      immunities: immunities,
      advantages: advantages);
}
