// lib/services/medals.dart
//
// Álbum de medalhas. Igual ao site (web-site/src/lib/medals.js): marcos
// grandes, cada um com o desenho de um Pokémon (o mesmo dos temas,
// widgets/pokemon_theme_art.dart), pintado na cor dele quando liberado.

class Medal {
  const Medal(this.id, this.pokemon, this.title, this.text, this.done);
  final String id;
  final int pokemon;
  final String title;
  final String text;
  final bool Function(Map league, Map collection) done;
}

int _len(Object? x) => x is List ? x.length : 0;
int _n(Object? x) => (x as num?)?.toInt() ?? 0;
Map _factory(Map league) => (league['factory'] as Map?) ?? const {};
int _caught(Map collection) => {
      for (final g in collection.values)
        if (g is Map) ...[...(g['c'] as List? ?? const []), ...(g['s'] as List? ?? const [])],
    }.length;

class Medals {
  static final all = [
    Medal('shiny1', 130, 'Primeiro shiny', 'Capture um shiny no Pokelike.', (l, _) => _len(_factory(l)['shinies']) >= 1),
    Medal('shiny10', 384, 'Caçador de shiny', 'Capture 10 shiny no Pokelike.', (l, _) => _len(_factory(l)['shinies']) >= 10),
    Medal('shiny100', 493, 'Lenda brilhante', 'Capture 100 shiny no Pokelike.', (l, _) => _len(_factory(l)['shinies']) >= 100),
    Medal('floor25', 133, 'Explorador', 'Chegue ao andar 25 do Pokelike.', (l, _) => _n(_factory(l)['best']) >= 25),
    Medal('floor100', 149, 'Desbravador', 'Chegue ao andar 100 do Pokelike.', (l, _) => _n(_factory(l)['best']) >= 100),
    Medal('missions30', 25, 'Missão cumprida', 'Cumpra 30 missões diárias do Pokelike.', (l, _) => _n(_factory(l)['missionsDone']) >= 30),
    Medal('badges8', 95, 'Oito insígnias', 'Junte 8 insígnias numa região.', (l, _) => ((l['badges'] as Map?) ?? const {}).values.any((b) => _len(b) >= 8)),
    Medal('champion', 6, 'Campeão', 'Entre no Hall da Fama.', (l, _) => _len(l['hall']) >= 1),
    Medal('champions', 150, 'Lenda das regiões', 'Entre no Hall da Fama de 5 regiões.',
        (l, _) => {for (final h in (l['hall'] as List? ?? const [])) (h as Map)['region']}.length >= 5),
    Medal('tower10', 376, 'Torre de aço', 'Vença 10 seguidas na Torre de Batalha.', (l, _) => _n((l['tower'] as Map?)?['best']) >= 10),
    Medal('weekly', 445, 'Desafiante da semana', 'Vença um desafio semanal.', (l, _) => (l['weeklyBattle'] as Map?)?['best'] != null),
    Medal('kanto', 151, 'Pokédex de Kanto', 'Marque 151 Pokémon como pegos na coleção.', (_, c) => _caught(c) >= 151),
  ];

  /// As medalhas e se cada uma está liberada.
  static List<(Medal, bool)> of(Map league, Map collection) => [for (final m in all) (m, m.done(league, collection))];
}
