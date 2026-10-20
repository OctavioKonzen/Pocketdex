// lib/models/type_relations.dart

class TypeRelations {
  final Map<String, double> weaknesses;
  final Map<String, double> resistances;
  final List<String> immunities;
  final Map<String, int> advantages;

  TypeRelations({
    required this.weaknesses,
    required this.resistances,
    required this.immunities,
    required this.advantages,
  });
}