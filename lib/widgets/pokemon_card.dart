// lib/widgets/pokemon_card.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:pocket_dex/providers/favorites_provider.dart';
import 'package:pocket_dex/models/pokemon_listing.dart';
import 'package:pocket_dex/screens/pokemon_detail_screen.dart';
import 'package:pocket_dex/utils/pokemon_colors.dart';
import 'package:pocket_dex/widgets/pikachu_loading_indicator.dart';

class PokemonCard extends StatefulWidget {
  final PokemonListing pokemonListing;
  final bool isForTeamSelection;
  final VoidCallback? onTap;

  const PokemonCard({
    super.key,
    required this.pokemonListing,
    this.isForTeamSelection = false,
    this.onTap,
  });

  @override
  State<PokemonCard> createState() => _PokemonCardState();
}

class _PokemonCardState extends State<PokemonCard> with SingleTickerProviderStateMixin {
  String? _imageUrl;
  String? _id;
  String? _displayName;

  List<String> _types = [];
  bool _isLoading = true;
  bool _hasError = false;

  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 15),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _fetchCardData();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PokemonCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pokemonListing.url != widget.pokemonListing.url) {
      _fetchCardData();
    }
  }

  Future<void> _fetchCardData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      http.Response response;
      try {
        response = await http.get(Uri.parse(widget.pokemonListing.url));
        if (response.statusCode != 200) throw Exception('Form-specific URL failed');
      } catch (e) {
        final baseName = widget.pokemonListing.name.split('-').first;
        final fallbackUrl = 'https://pokeapi.co/api/v2/pokemon/$baseName/';
        response = await http.get(Uri.parse(fallbackUrl));
      }

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        _id = (data['id'] as int).toString();
        
        _imageUrl = data['sprites']['front_default'] ?? data['sprites']['other']['official-artwork']['front_default'];

        _displayName = widget.pokemonListing.name.split('-').first;
        _types = (data['types'] as List).map((t) => t['type']['name'] as String).toList();

      } else {
        throw Exception('Failed to load card data');
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  void _toggleFavorite() {
    if (_isLoading || _hasError || _id == null) return;
    context.read<FavoritesProvider>().toggleFavorite(_id!);
  }

  void _handleTap() {
    if (_hasError) {
      _fetchCardData();
      return;
    }
    if (_isLoading || _id == null) return;

    if (widget.onTap != null) {
      widget.onTap!();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PokemonDetailScreen(
            initialPokemonId: int.parse(_id!),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const PikachuLoadingIndicator(size: 40.0),
      );
    }

    if (_hasError || _imageUrl == null || _id == null) {
      return GestureDetector(
        onTap: _fetchCardData,
        child: Container(
          decoration: BoxDecoration(color: Colors.red[900], borderRadius: BorderRadius.circular(16)),
          child: const Center(child: Icon(Icons.refresh, color: Colors.white, size: 32)),
        ),
      );
    }

    final favoritesProvider = context.watch<FavoritesProvider>();
    final isFavorited = favoritesProvider.isFavorite(_id!);

    final Color backgroundColor = _types.isNotEmpty ? getColorForType(_types.first) : Colors.grey[850]!;

    return GestureDetector(
      onTap: _handleTap,
      onDoubleTap: _toggleFavorite,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withAlpha(102),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
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
              Hero(
                tag: '${_id!}-${widget.pokemonListing.name}',
                child: Image.network(
                  _imageUrl!,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.none,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.error_outline, color: Colors.white, size: 40),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black.withAlpha(204)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Column(
                  children: [
                    Text(
                      '${_displayName![0].toUpperCase()}${_displayName!.substring(1)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14,
                          shadows: [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1))]),
                    ),
                    Text(
                      '#${_id!.padLeft(3, '0')}',
                      style: TextStyle(color: Colors.white.withAlpha(204), fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (isFavorited)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(Icons.star, color: Colors.yellow[600], size: 20,
                      shadows: const [Shadow(color: Colors.black38, blurRadius: 4)]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}