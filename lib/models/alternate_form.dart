// lib/models/alternate_form.dart

class AlternateForm {
  /// Id do Pokémon (ou da forma) no banco.
  final int id;
  final String formName;
  final String apiName;
  final String imageUrl;
  final String shinyImageUrl;
  final String pixelImageUrl;
  final String shinyPixelImageUrl;
  final List<String> types;
  final int height;
  final int weight;
  final Map<String, int> stats;
  /// EVs que ele dá ao ser derrotado (mesma ordem de [stats]).
  final Map<String, int> efforts;
  final List<dynamic> rawMoves;
  /// Jogos em que a forma aparece (chaves de lib/models/game.dart).
  final List<String> games;

  AlternateForm({
    this.id = 0,
    required this.formName,
    required this.apiName,
    required this.imageUrl,
    required this.shinyImageUrl,
    required this.pixelImageUrl,
    required this.shinyPixelImageUrl,
    required this.types,
    required this.height,
    required this.weight,
    required this.stats,
    this.efforts = const {},
    required this.rawMoves,
    this.games = const [],
  });

  factory AlternateForm.fromJson(Map<String, dynamic> json, String baseName) {
    String formatFormName() {
      final name = json['name'] as String;
      if (name == baseName) return "Default";
      return name
          .replaceAll(baseName, '')
          .replaceAll('-', ' ')
          .trim()
          .split(' ')
          .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
          .join(' ');
    }

    return AlternateForm(
      id: (json['id'] as num?)?.toInt() ?? 0,
      formName: formatFormName(),
      apiName: json['name'],
      imageUrl: json['sprites']['other']['official-artwork']['front_default'] ?? '',
      shinyImageUrl: json['sprites']['other']['official-artwork']['front_shiny'] ?? '',
      pixelImageUrl: json['sprites']['front_default'] ?? '',
      shinyPixelImageUrl: json['sprites']['front_shiny'] ?? '',
      types: (json['types'] as List).map((t) => t['type']['name'] as String).toList(),
      height: json['height'],
      weight: json['weight'],
      stats: { for (var stat in (json['stats'] as List)) stat['stat']['name'] : stat['base_stat'] as int },
      efforts: { for (var stat in (json['stats'] as List)) stat['stat']['name'] : (stat['effort'] as num?)?.toInt() ?? 0 },
      rawMoves: json['moves'] as List,
      games: ((json['games'] as List?) ?? const []).cast<String>(),
    );
  }
}