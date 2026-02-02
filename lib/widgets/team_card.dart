// lib/widgets/team_card.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/team.dart';
import '../utils/pokemon_colors.dart';

class TeamCard extends StatelessWidget {
  final Team team;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const TeamCard({
    super.key,
    required this.team,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color cardColor = team.color != null
        ? Color(int.parse(team.color!, radix: 16))
        : theme.cardColor;

    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 10.0,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          team.name,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        if (team.score != null && team.score! > 0)
                          Chip(
                            label: Text('Nota: ${team.score!.toStringAsFixed(1)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 12)),
                            backgroundColor: Colors.black26,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white70),
                    tooltip: 'Deletar Time',
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    final bool hasPokemon = index < team.pokemons.length && team.pokemons[index].isNotEmpty;

                    if (hasPokemon) {
                      final pokemonData = team.pokemons[index];
                      return _PokemonIcon(
                        pokemonId: pokemonData['id']!,
                      );
                    } else {
                      return CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.black.withAlpha(51),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: theme.scaffoldBackgroundColor,
                        ),
                      );
                    }
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PokemonIcon extends StatefulWidget {
  final String pokemonId;

  const _PokemonIcon({required this.pokemonId});

  @override
  State<_PokemonIcon> createState() => _PokemonIconState();
}

class _PokemonIconState extends State<_PokemonIcon> {
  Future<Map<String, dynamic>>? _pokemonDataFuture;

  @override
  void initState() {
    super.initState();
    _pokemonDataFuture = _fetchPokemonData();
  }

  Future<Map<String, dynamic>> _fetchPokemonData() async {
    try {
      final response = await http.get(Uri.parse('https://pokeapi.co/api/v2/pokemon/${widget.pokemonId}'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final types = (data['types'] as List)
            .map((t) => t['type']['name'] as String)
            .toList();
        final imageUrl = data['sprites']['front_default'] ?? '';
        return {'types': types, 'imageUrl': imageUrl};
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<Map<String, dynamic>>(
      future: _pokemonDataFuture,
      builder: (context, snapshot) {
        Color typeColor = Colors.grey.shade700;
        String imageUrl = '';

        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data!.isNotEmpty) {
          final data = snapshot.data!;
          final types = data['types'] as List<String>;
          if (types.isNotEmpty) {
            typeColor = getColorForType(types.first);
          }
          imageUrl = data['imageUrl'] as String;
        }

        return CircleAvatar(
          radius: 25,
          backgroundColor: typeColor.withAlpha(204),
          child: CircleAvatar(
            radius: 22,
            backgroundColor: theme.cardColor,
            backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
            child: imageUrl.isNotEmpty
              ? Ink.image(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.contain,
                  width: 44,
                  height: 44,
                )
              : null,
          ),
        );
      },
    );
  }
}