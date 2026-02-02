// lib/screens/breeding_partners_screen.dart

import 'package:flutter/material.dart';
import '../models/pokemon_details.dart';
import '../models/pokemon_listing.dart';
import '../services/pokemon_service.dart';
import '../utils/pokemon_colors.dart';
import '../utils/string_extensions.dart';
import '../widgets/pikachu_loading_indicator.dart';
import '../widgets/pokemon_card.dart';

class BreedingPartnersScreen extends StatefulWidget {
  final PokemonListing initialPokemon;

  const BreedingPartnersScreen({super.key, required this.initialPokemon});

  @override
  State<BreedingPartnersScreen> createState() => _BreedingPartnersScreenState();
}

class _BreedingPartnersScreenState extends State<BreedingPartnersScreen> with SingleTickerProviderStateMixin {
  final PokemonService _pokemonService = PokemonService();
  Future<Map<String, dynamic>>? _dataFuture;

  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 25),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadBreedingData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadBreedingData() async {
    try {
      final details = await _pokemonService
          .fetchPokemonDetails(int.parse(widget.initialPokemon.id));
      final partners = await _pokemonService.fetchCompatiblePartners(details);
      return {'details': details, 'partners': partners};
    } catch (e) {
      throw Exception('Falha ao carregar parceiros de criação: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<Map<String, dynamic>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: PikachuLoadingIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
              appBar: AppBar(
                title: const Text('Parceiros de Criação'),
              ),
              body: Center(
                  child: Text('Erro ao carregar dados.',
                      style: TextStyle(color: theme.colorScheme.error))));
        }

        final PokemonDetails pokemonDetails = snapshot.data!['details'];
        final List<PokemonListing> partners = snapshot.data!['partners'];
        final Color backgroundColor =
            getColorForType(pokemonDetails.forms.first.types.first);
        final Size screenSize = MediaQuery.of(context).size;

        return Scaffold(
          backgroundColor: backgroundColor,
          body: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: screenSize.height * 0.45,
                child: ClipRect(
                  child: Container(
                    alignment: Alignment.center,
                    child: RotationTransition(
                      turns: _animationController,
                      child: Opacity(
                        opacity: 0.1,
                        child: Image.asset(
                          'assets/images/pokeball.png',
                          width: 350,
                          height: 350,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              Positioned(
                top: 40,
                left: 5,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Positioned(
                top: 100,
                left: 20,
                right: 20,
                child: Text(
                  pokemonDetails.name.capitalise(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2))
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Positioned(
                top: 150,
                left: 20,
                child: Row(
                  children: pokemonDetails.eggGroups
                      .map(
                        (group) => Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Chip(
                            label: Text(group.capitalise()),
                            backgroundColor: Colors.black26,
                            labelStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              Positioned(
                top: 105,
                right: 20,
                child: Text(
                  '#${pokemonDetails.id.toString().padLeft(3, '0')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Positioned(
                top: screenSize.height * 0.40,
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 90, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            'Parceiros Compatíveis',
                            style: theme.textTheme.titleLarge
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: partners.isEmpty
                              ? Center(
                                  child: Text(
                                    'Nenhum parceiro compatível encontrado.',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                )
                              : GridView.builder(
                                  padding:
                                      const EdgeInsets.only(top: 8, bottom: 16),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 0.8,
                                  ),
                                  itemCount: partners.length,
                                  itemBuilder: (context, index) {
                                    return PokemonCard(
                                        pokemonListing: partners[index]);
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: (screenSize.height * 0.40) - 150,
                left: 0,
                right: 0,
                child: Hero(
                  tag: '${pokemonDetails.id}-${widget.initialPokemon.name}',
                  child: Image.network(
                    pokemonDetails.forms.first.pixelImageUrl,
                    height: 200,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}