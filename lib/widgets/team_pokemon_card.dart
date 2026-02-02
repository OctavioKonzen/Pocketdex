// lib/widgets/team_pokemon_card.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/pokemon_colors.dart';
import 'pikachu_loading_indicator.dart';

class TeamPokemonCard extends StatefulWidget {
  final Map<String, String>? pokemonData;
  final VoidCallback onTap;

  const TeamPokemonCard({
    super.key,
    required this.pokemonData,
    required this.onTap,
  });

  @override
  State<TeamPokemonCard> createState() => _TeamPokemonCardState();
}

class _TeamPokemonCardState extends State<TeamPokemonCard> with SingleTickerProviderStateMixin {
  Future<Map<String, dynamic>?>? _cardDetailsFuture;

  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 15),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _fetchDetailsIfNeeded();
  }

  @override
  void dispose() {
    _animationController.dispose(); 
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TeamPokemonCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pokemonData?['id'] != oldWidget.pokemonData?['id']) {
      _fetchDetailsIfNeeded();
    }
  }

  void _fetchDetailsIfNeeded() {
    if (widget.pokemonData != null && widget.pokemonData!['id'] != null) {
      setState(() {
        _cardDetailsFuture = _fetchCardDetails(widget.pokemonData!['id']!);
      });
    } else {
      setState(() {
        _cardDetailsFuture = null;
      });
    }
  }

  Future<Map<String, dynamic>?> _fetchCardDetails(String id) async {
    try {
      final response = await http.get(Uri.parse('https://pokeapi.co/api/v2/pokemon/$id'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (widget.pokemonData == null) {
      return InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor, width: 2),
          ),
          child: Icon(Icons.add, color: theme.colorScheme.onSurface.withOpacity(0.7), size: 40),
        ),
      );
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _cardDetailsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(16)),
            child: const PikachuLoadingIndicator(size: 40.0),
          );
        }

        final imageUrl = snapshot.hasData && snapshot.data != null
            ? snapshot.data!['sprites']['front_default'] ?? widget.pokemonData!['imageUrl']!
            : widget.pokemonData!['imageUrl']!;
            
        final pokemonId = widget.pokemonData!['id']!;
        
        final types = snapshot.hasData && snapshot.data != null
            ? (snapshot.data!['types'] as List).map((t) => t['type']['name'] as String).toList()
            : <String>[];
            
        final displayName = snapshot.hasData && snapshot.data != null
            ? (snapshot.data!['name'] as String).split('-').first
            : 'Pokémon';

        final backgroundColor = types.isNotEmpty ? getColorForType(types.first) : Colors.grey[800]!;

        return InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: backgroundColor.withAlpha(102), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  RotationTransition(
                    turns: _animationController,
                    child: Opacity(
                      opacity: 0.1,
                      child: Image.asset(
                        'assets/images/pokeball.png',
                        width: 120,
                        height: 120,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 5,
                    left: 0,
                    right: 0,
                    child: Image.network(
                      imageUrl,
                      height: 80,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.error_outline, color: Colors.white, size: 40),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Column(
                      children: [
                        Text(
                          '${displayName[0].toUpperCase()}${displayName.substring(1)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, shadows: [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))]),
                        ),
                        Text(
                          '#${pokemonId.padLeft(3, '0')}',
                          style: TextStyle(color: Colors.white.withAlpha(204), fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}