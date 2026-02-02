// lib/screens/breeding_help_screen.dart

import 'package:flutter/material.dart';
import '../models/pokemon_listing.dart';
import '../services/pokemon_service.dart';
import '../widgets/pikachu_loading_indicator.dart';
import '../widgets/pokemon_card.dart';
import 'breeding_partners_screen.dart';

class BreedingHelpScreen extends StatefulWidget {
  const BreedingHelpScreen({super.key});

  @override
  State<BreedingHelpScreen> createState() => _BreedingHelpScreenState();
}

class _BreedingHelpScreenState extends State<BreedingHelpScreen> {
  final PokemonService _pokemonService = PokemonService();
  Future<List<PokemonListing>>? _pokemonListFuture;
  List<PokemonListing> _allPokemon = [];
  List<PokemonListing> _filteredPokemon = [];

  @override
  void initState() {
    super.initState();
    _loadAllPokemon();
  }

  void _loadAllPokemon() {
    _pokemonListFuture = _pokemonService.fetchAllPokemonList();
    _pokemonListFuture?.then((list) {
      if (mounted) {
        setState(() {
          _allPokemon = list;
          _filteredPokemon = _allPokemon;
        });
      }
    });
  }

  void _filterPokemon(String query) {
    if (query.isEmpty) {
      setState(() => _filteredPokemon = _allPokemon);
      return;
    }
    final filtered = _allPokemon.where((pokemon) {
      final name = pokemon.name.toLowerCase();
      final id = pokemon.id;
      return name.contains(query.toLowerCase()) || id == query;
    }).toList();
    setState(() {
      _filteredPokemon = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajuda de Criação'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              onChanged: _filterPokemon,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Procurar Pokémon...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: theme.colorScheme.surface,
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<PokemonListing>>(
              future: _pokemonListFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && _allPokemon.isEmpty) {
                  return const PikachuLoadingIndicator();
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erro: ${snapshot.error}', style: TextStyle(color: theme.colorScheme.error)));
                }
                if (_filteredPokemon.isEmpty && snapshot.connectionState == ConnectionState.done) {
                   return Center(child: Text('Nenhum Pokémon encontrado.', style: TextStyle(color: theme.hintColor)));
                }
                
                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: _filteredPokemon.length,
                  itemBuilder: (context, index) {
                    final pokemon = _filteredPokemon[index];
                    return PokemonCard(
                      pokemonListing: pokemon,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => BreedingPartnersScreen(initialPokemon: pokemon)),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}