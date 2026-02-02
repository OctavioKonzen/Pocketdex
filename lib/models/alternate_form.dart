// lib/models/alternate_form.dart

class AlternateForm {
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
  final List<dynamic> rawMoves;

  AlternateForm({
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
    required this.rawMoves,
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
      rawMoves: json['moves'] as List,
    );
  }
}