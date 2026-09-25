// lib/widgets/team_card.dart
//
// Card de time igual ao do site: borda colorida à esquerda (cor do time),
// nome, quantidade de Pokémon e nota, e os 6 espaços com os Pokémon.

import 'package:flutter/material.dart';

import '../models/team.dart';
import '../services/account_format.dart';
import '../utils/site_ui.dart';
import 'pokemon_sprite.dart';

class TeamCard extends StatelessWidget {
  final Team team;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const TeamCard({super.key, required this.team, required this.onTap, required this.onDelete});

  static Color colorOf(Team team) =>
      team.color != null ? Color(int.parse(team.color!, radix: 16)) : SectionColors.teams;

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final count = team.pokemons.where((p) => p.isNotEmpty).length;
    return SiteCard(
      onTap: onTap,
      accentLeft: colorOf(team),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(team.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.text)),
                    Text(
                      '$count/6 Pokémon${team.score != null ? ' · Nota ${team.score!.toStringAsFixed(1)}' : ''}',
                      style: TextStyle(fontSize: 13, color: c.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: c.muted),
                tooltip: 'Deletar time',
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                for (var i = 0; i < 6; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
                          child: _slot(i),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _slot(int i) {
    if (i >= team.pokemons.length || team.pokemons[i].isEmpty) return null;
    final p = team.pokemons[i];
    final id = AccountFormat.pokemonIdFromImage(p['imageUrl']) ?? int.tryParse(p['id'] ?? '');
    return id == null ? null : PokemonSprite(id, fill: 0.8);
  }
}
