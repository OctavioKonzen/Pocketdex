// lib/screens/abilities_encyclopedia_screen.dart

import 'package:flutter/material.dart';
import '../widgets/expandable_entry.dart';
import '../models/ability.dart';
import '../services/pokemon_service.dart';
import '../utils/string_extensions.dart';
import 'ability_detail_screen.dart';
import '../utils/responsive.dart';

class AbilitiesEncyclopediaScreen extends StatefulWidget {
  const AbilitiesEncyclopediaScreen({super.key});

  @override
  State<AbilitiesEncyclopediaScreen> createState() =>
      _AbilitiesEncyclopediaScreenState();
}

class _AbilitiesEncyclopediaScreenState
    extends State<AbilitiesEncyclopediaScreen> {
  final PokemonService _pokemonService = PokemonService();
  // Item aberto na lista (abre embaixo, empurrando os outros).
  final ValueNotifier<String?> _openId = ValueNotifier(null);

  @override
  void dispose() {
    _openId.dispose();
    super.dispose();
  }

  List<Map<String, String>> _allAbilities = [];
  List<Map<String, String>> _filteredAbilities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAbilities();
  }

  Future<void> _loadAbilities() async {
    try {
      final abilitiesList = await _pokemonService.fetchAllAbilitiesList();
      if (mounted) {
        setState(() {
          _allAbilities = abilitiesList;
          _filteredAbilities = _allAbilities;
          _isLoading = false;
        });
      }
    } catch (e) {}
  }

  void _filterAbilities(String query) {
    final filtered = _allAbilities.where((ability) {
      return ability['name']!
          .toLowerCase()
          .replaceAll('-', ' ')
          .contains(query.toLowerCase());
    }).toList();
    setState(() {
      _filteredAbilities = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enciclopédia de Habilidades'),
      ),
      body: ReadableWidth(
          child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: _filterAbilities,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Procurar Habilidade',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: theme.colorScheme.surface,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _filteredAbilities.length,
                    itemBuilder: (context, index) {
                      final abilityData = _filteredAbilities[index];
                      return _AbilityTile(
                        name: abilityData['name']!,
                        url: abilityData['url']!,
                        pokemonService: _pokemonService,
                        openId: _openId,
                      );
                    },
                  ),
          ),
        ],
      )),
    );
  }
}

class _AbilityTile extends StatelessWidget {
  final String name;
  final String url;
  final PokemonService pokemonService;
  final ValueNotifier<String?> openId;

  const _AbilityTile({required this.name, required this.url, required this.pokemonService, required this.openId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpandableEntry<Ability>(
      id: url,
      openId: openId,
      accent: const Color(0xFF42A5F5),
      load: () => pokemonService.fetchResourceDetails(url, (json) => Ability.fromApiJson(json)),
      header: (context, ability, open) => ListTile(
        title: Text(ability?.name ?? name.replaceAll('-', ' ').capitalise(),
            style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
        subtitle: Text(ability == null ? 'Carregando...' : ability.description,
            maxLines: open ? null : 1,
            overflow: open ? null : TextOverflow.ellipsis,
            style: TextStyle(color: theme.hintColor)),
      ),
      details: (context, ability) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pokémon com esta Habilidade:', style: theme.textTheme.titleMedium),
          PokemonPreviewGrid(
            load: () => pokemonService.fetchPokemonWithAbility(ability.name),
            onSeeAll: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => AbilityDetailScreen(ability: ability))),
          ),
        ],
      ),
    );
  }
}
