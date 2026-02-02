// lib/screens/abilities_encyclopedia_screen.dart

import 'package:flutter/material.dart';
import '../models/ability.dart';
import '../services/pokemon_service.dart';
import '../utils/string_extensions.dart';
import 'ability_detail_screen.dart';

class AbilitiesEncyclopediaScreen extends StatefulWidget {
  const AbilitiesEncyclopediaScreen({super.key});

  @override
  State<AbilitiesEncyclopediaScreen> createState() => _AbilitiesEncyclopediaScreenState();
}

class _AbilitiesEncyclopediaScreenState extends State<AbilitiesEncyclopediaScreen> {
  final PokemonService _pokemonService = PokemonService();
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
    } catch (e) {
    }
  }

  void _filterAbilities(String query) {
    final filtered = _allAbilities.where((ability) {
      return ability['name']!.toLowerCase().replaceAll('-', ' ').contains(query.toLowerCase());
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: _filterAbilities,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Procurar Habilidade',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AbilityTile extends StatelessWidget {
  final String name;
  final String url;
  final PokemonService pokemonService;

  const _AbilityTile({required this.name, required this.url, required this.pokemonService});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardColor,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: FutureBuilder<Ability>(
        future: pokemonService.fetchResourceDetails(url, (json) => Ability.fromApiJson(json)),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return ListTile(
              title: Text(name.replaceAll('-', ' ').capitalise(), style: TextStyle(color: theme.colorScheme.onSurface)),
              subtitle: Text('Carregando...', style: TextStyle(color: theme.hintColor)),
            );
          }
          final ability = snapshot.data!;
          return ListTile(
            title: Text(ability.name, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
            subtitle: Text(ability.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.hintColor)),
            trailing: Icon(Icons.chevron_right, color: theme.hintColor),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AbilityDetailScreen(ability: ability)),
              );
            },
          );
        },
      ),
    );
  }
}