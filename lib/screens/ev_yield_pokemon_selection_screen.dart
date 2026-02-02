// lib/screens/ev_yield_pokemon_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:pocket_dex/models/pokemon_listing.dart';
import 'package:pocket_dex/services/pokemon_service.dart';
import 'package:pocket_dex/widgets/pikachu_loading_indicator.dart';
import 'package:pocket_dex/widgets/pokemon_card.dart';

class EvYieldPokemonSelectionScreen extends StatefulWidget {
  const EvYieldPokemonSelectionScreen({super.key});

  @override
  State<EvYieldPokemonSelectionScreen> createState() =>
      _EvYieldPokemonSelectionScreenState();
}

class _EvYieldPokemonSelectionScreenState
    extends State<EvYieldPokemonSelectionScreen> {
  final PokemonService _pokemonService = PokemonService();
  List<PokemonListing> _allPokemon = [];
  List<PokemonListing> _filteredPokemon = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllPokemon();
    _searchController.addListener(_filterPokemon);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterPokemon);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllPokemon() async {
    final list = await _pokemonService.fetchAllPokemonList();
    if (mounted) {
      setState(() {
        _allPokemon = list;
        _filteredPokemon = list;
        _isLoading = false;
      });
    }
  }

  void _filterPokemon() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredPokemon = _allPokemon.where((pokemon) {
        return pokemon.name.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(54, 54, 54, 1),
      appBar: AppBar(
        title: const Text('Selecione o Pokémon Derrotado'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Buscar Pokémon...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[850],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const PikachuLoadingIndicator()
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                          Navigator.of(context).pop(pokemon);
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