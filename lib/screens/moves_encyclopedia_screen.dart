// lib/screens/moves_encyclopedia_screen.dart

import 'package:flutter/material.dart';
import '../models/move.dart';
import '../services/pokemon_service.dart';
import '../utils/pokemon_colors.dart';
import '../utils/string_extensions.dart';
import 'move_detail_screen.dart';

class MovesEncyclopediaScreen extends StatefulWidget {
  const MovesEncyclopediaScreen({super.key});

  @override
  State<MovesEncyclopediaScreen> createState() => _MovesEncyclopediaScreenState();
}

class _MovesEncyclopediaScreenState extends State<MovesEncyclopediaScreen> {
  final PokemonService _pokemonService = PokemonService();
  List<Map<String, String>> _allMoves = [];
  List<Map<String, String>> _filteredMoves = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMoves();
  }

  Future<void> _loadMoves() async {
    try {
      final movesList = await _pokemonService.fetchAllMovesList();
      if (mounted) {
        setState(() {
          _allMoves = movesList;
          _filteredMoves = _allMoves;
          _isLoading = false;
        });
      }
    } catch (e) {
    }
  }

  void _filterMoves(String query) {
    final filtered = _allMoves.where((move) {
      return move['name']!.toLowerCase().replaceAll('-', ' ').contains(query.toLowerCase());
    }).toList();
    setState(() {
      _filteredMoves = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enciclopédia de Golpes'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: _filterMoves,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Procurar Golpe',
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
                    itemCount: _filteredMoves.length,
                    itemBuilder: (context, index) {
                      final moveData = _filteredMoves[index];
                      return _MoveTile(
                        name: moveData['name']!,
                        url: moveData['url']!,
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

class _MoveTile extends StatelessWidget {
  final String name;
  final String url;
  final PokemonService pokemonService;

  const _MoveTile({required this.name, required this.url, required this.pokemonService});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardColor,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: FutureBuilder<Move>(
        future: pokemonService.fetchResourceDetails(url, (json) => Move.fromApiJson(json)),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return ListTile(
              title: Text(name.replaceAll('-', ' ').capitalise(), style: TextStyle(color: theme.colorScheme.onSurface)),
              subtitle: Text('Carregando...', style: TextStyle(color: theme.hintColor)),
            );
          }
          final move = snapshot.data!;
          return ListTile(
            title: Text(move.name, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
            subtitle: Row(
              children: [
                Chip(
                  label: Text(move.type.capitalise(), style: const TextStyle(color: Colors.white)),
                  backgroundColor: getColorForType(move.type),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Icon(
                  move.category == 'physical' ? Icons.sports_mma : move.category == 'special' ? Icons.star : Icons.adjust,
                  color: theme.hintColor, size: 20,
                ),
              ],
            ),
            trailing: Icon(Icons.chevron_right, color: theme.hintColor),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MoveDetailScreen(move: move)),
              );
            },
          );
        },
      ),
    );
  }
}