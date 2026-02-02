// lib/widgets/evolution_pokemon_card.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/string_extensions.dart';

class EvolutionPokemonCard extends StatefulWidget {
  final String pokemonName;
  final String pokemonId;
  final String currentFormName;
  final Function(int) onPokemonSelected;
  final double size;

  const EvolutionPokemonCard({
    super.key,
    required this.pokemonName,
    required this.pokemonId,
    required this.currentFormName,
    required this.onPokemonSelected,
    this.size = 70.0,
  });

  @override
  State<EvolutionPokemonCard> createState() => _EvolutionPokemonCardState();
}

class _EvolutionPokemonCardState extends State<EvolutionPokemonCard> {
  Future<Map<String, String>>? _evolutionCardDataFuture;

  @override
  void initState() {
    super.initState();
    _evolutionCardDataFuture = _fetchEvolutionCardData();
  }

  @override
  void didUpdateWidget(EvolutionPokemonCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentFormName != widget.currentFormName || oldWidget.pokemonId != widget.pokemonId) {
      setState(() {
        _evolutionCardDataFuture = _fetchEvolutionCardData();
      });
    }
  }

  String _extractFormHint(String formName) {
    String lowerCaseForm = formName.toLowerCase();
    if (lowerCaseForm.contains('alola')) return 'alola';
    if (lowerCaseForm.contains('galar')) return 'galar';
    if (lowerCaseForm.contains('hisui')) return 'hisui';
    if (lowerCaseForm.contains('paldea')) return 'paldea';
    if (lowerCaseForm.contains('mega')) return 'mega';
    return '';
  }

  Future<Map<String, String>> _fetchEvolutionCardData() async {
    final formHint = _extractFormHint(widget.currentFormName);
    String potentialApiName = widget.pokemonName.toLowerCase();
    
    if (formHint.isNotEmpty && widget.pokemonName != 'perrserker') {
        potentialApiName = '${widget.pokemonName.toLowerCase()}-$formHint';
    }

    try {
      final response = await http.get(Uri.parse('https://pokeapi.co/api/v2/pokemon/$potentialApiName'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final imageUrl = data['sprites']['front_default'] ?? data['sprites']['other']['official-artwork']['front_default'] ?? '';
        if (imageUrl.isNotEmpty) {
          return {
            'id': (data['id'] as int).toString(),
            'name': (data['name'] as String).replaceAll('-', ' ').capitalise(),
            'imageUrl': imageUrl,
          };
        }
      }
      throw Exception('Fallback to base form');
    } catch (e) {
      final response = await http.get(Uri.parse('https://pokeapi.co/api/v2/pokemon/${widget.pokemonId}'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final imageUrl = data['sprites']['front_default'] ?? data['sprites']['other']['official-artwork']['front_default'] ?? '';
         if (imageUrl.isEmpty) throw Exception("No image found for base form");
        return {
          'id': (data['id'] as int).toString(),
          'name': (data['name'] as String).replaceAll('-', ' ').capitalise(),
          'imageUrl': imageUrl,
        };
      } else {
        throw Exception('Failed to load evolution data for ${widget.pokemonName}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _evolutionCardDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: const Center(child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2)),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: Icon(Icons.error_outline, color: Colors.white, size: widget.size * 0.5),
          );
        }

        final data = snapshot.data!;
        final id = data['id']!;
        final name = data['name']!;
        final imageUrl = data['imageUrl']!;

        return GestureDetector(
          onTap: () => widget.onPokemonSelected(int.parse(id)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Hero(
                tag: 'evolution-$id-$name', 
                child: Image.network(
                  imageUrl,
                  height: widget.size,
                  width: widget.size,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                  errorBuilder: (c, e, s) => Icon(Icons.error, size: widget.size * 0.8),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}