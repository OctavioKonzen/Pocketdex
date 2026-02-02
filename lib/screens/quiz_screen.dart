// lib/screens/quiz_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/generation.dart';
import '../models/pokemon_listing.dart';
import '../services/pokemon_service.dart';
import '../utils/string_extensions.dart';
import '../widgets/pikachu_loading_indicator.dart';

class QuizScreen extends StatefulWidget {
  final Generation? generation;
  final bool continueGame;

  const QuizScreen({super.key, this.generation, this.continueGame = false});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  static const String _recordKey = 'quiz_highscore';
  static const String _scoreKey = 'quiz_score';
  static const String _livesKey = 'quiz_lives';
  static const String _pokemonIdKey = 'quiz_correct_pokemon_id';
  static const String _optionsKey = 'quiz_options';
  static const String _generationKey = 'quiz_generation';
  
  final PokemonService _pokemonService = PokemonService();
  
  List<PokemonListing>? _pokemonList;
  PokemonListing? _correctPokemon;
  List<String> _options = [];
  
  int _score = 0;
  int _lives = 3;
  bool _isLoading = true;
  bool _showCorrectAnswer = false;

  @override
  void initState() {
    super.initState();
    if (widget.continueGame) {
      _loadSavedGameAndStart();
    } else {
      _startGame();
    }
  }

  @override
  void dispose() {
    if (_lives > 0) {
      _saveGameState();
    }
    super.dispose();
  }

  Future<void> _saveGameState() async {
    if (_correctPokemon == null || _options.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_scoreKey, _score);
    await prefs.setInt(_livesKey, _lives);
    await prefs.setString(_pokemonIdKey, _correctPokemon!.id);
    await prefs.setStringList(_optionsKey, _options);
    await prefs.setString(_generationKey, widget.generation?.pokedexName ?? 'all');
  }

  Future<void> _clearGameState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scoreKey);
    await prefs.remove(_livesKey);
    await prefs.remove(_pokemonIdKey);
    await prefs.remove(_optionsKey);
    await prefs.remove(_generationKey);
  }

  Future<void> _loadSavedGameAndStart() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();

    _score = prefs.getInt(_scoreKey) ?? 0;
    _lives = prefs.getInt(_livesKey) ?? 3;
    final pokemonId = prefs.getString(_pokemonIdKey);
    _options = prefs.getStringList(_optionsKey) ?? [];
    final generationName = prefs.getString(_generationKey);

    if (pokemonId == null || _options.isEmpty || _lives == 0) {
      _startGame();
      return;
    }

    try {
      if (generationName != null && generationName != 'all') {
        final savedGeneration = generations.firstWhere((g) => g.pokedexName == generationName);
        _pokemonList = await _pokemonService.fetchPokedex(savedGeneration);
      } else {
        _pokemonList = await _pokemonService.fetchAllPokemonList();
      }

      _correctPokemon = _pokemonList!.firstWhere((p) => p.id == pokemonId);

      setState(() => _isLoading = false);
    } catch(e) {
      _startGame();
    }
  }

  Future<void> _startGame() async {
    setState(() { _isLoading = true; });
    
    try {
      if (widget.generation != null) {
        _pokemonList = await _pokemonService.fetchPokedex(widget.generation!);
      } else {
        _pokemonList = await _pokemonService.fetchAllPokemonList();
      }
      _loadNextQuestion();
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao carregar Pokémon para o jogo.'))
        );
      }
    }
  }

  void _loadNextQuestion() {
    if (_pokemonList == null || _pokemonList!.isEmpty) return;

    setState(() {
      _isLoading = true;
      _showCorrectAnswer = false;
      _options = [];
      _correctPokemon = null;
    });

    final random = Random();
    
    _correctPokemon = _pokemonList![random.nextInt(_pokemonList!.length)];
    final correctName = _correctPokemon!.name.capitalise();
    _options.add(correctName);

    while (_options.length < 4) {
      final randomPokemon = _pokemonList![random.nextInt(_pokemonList!.length)];
      final randomName = randomPokemon.name.capitalise();
      if (!_options.contains(randomName)) {
        _options.add(randomName);
      }
    }

    _options.shuffle();
    setState(() => _isLoading = false);
  }

  void _handleAnswer(String selectedName) {
    if (_showCorrectAnswer) return;

    setState(() => _showCorrectAnswer = true);

    if (selectedName == _correctPokemon!.name.capitalise()) {
      setState(() => _score++);
      Future.delayed(const Duration(seconds: 1), _loadNextQuestion);
    } else {
      setState(() => _lives--);
      Future.delayed(const Duration(seconds: 2), () {
        if (_lives == 0) {
          _endGame();
        } else {
          _loadNextQuestion();
        }
      });
    }
  }

  Future<void> _endGame() async {
    final prefs = await SharedPreferences.getInstance();
    final highScore = prefs.getInt(_recordKey) ?? 0;
    if (_score > highScore) {
      await prefs.setInt(_recordKey, _score);
    }
    await _clearGameState();
    
    if(mounted) {
      final theme = Theme.of(context);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          title: Center(child: Text('Fim de Jogo!', style: theme.textTheme.headlineMedium)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Sua pontuação foi:', textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('$_score', style: TextStyle(color: Colors.yellow.shade600, fontSize: 36, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(foregroundColor: theme.colorScheme.onSurface.withAlpha(178), textStyle: const TextStyle(fontSize: 18)),
                    child: const Text('Sair'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      setState(() {
                        _score = 0;
                        _lives = 3;
                      });
                      _startGame();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    child: const Text('Jogar Novamente'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Pontos: $_score'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: List.generate(3, (index) {
                return Icon(
                  index < _lives ? Icons.favorite : Icons.favorite_border,
                  color: Colors.redAccent,
                );
              }),
            ),
          ),
        ],
      ),
      body: _isLoading || _correctPokemon == null
          ? const Center(child: PikachuLoadingIndicator())
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  flex: 4,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: _showCorrectAnswer
                          ? Image.network(
                              _correctPokemon!.pixelImageUrl,
                              key: ValueKey(_correctPokemon!.id),
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.none,
                            )
                          : ColorFiltered(
                              colorFilter: const ColorFilter.mode(
                                Colors.black,
                                BlendMode.srcIn,
                              ),
                              child: Image.network(
                                _correctPokemon!.pixelImageUrl,
                                key: ValueKey('silhouette_${_correctPokemon!.id}'),
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.none,
                              ),
                            ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 2.5,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    padding: const EdgeInsets.all(24.0),
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _options.length,
                    itemBuilder: (context, index) {
                      final option = _options[index];
                      Color buttonColor = theme.colorScheme.surface;
                      if (_showCorrectAnswer) {
                        if (option == _correctPokemon!.name.capitalise()) {
                          buttonColor = Colors.green.shade700;
                        } else {
                          buttonColor = Colors.red.shade800;
                        }
                      }
                      return ElevatedButton(
                        onPressed: () => _handleAnswer(option),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonColor,
                          foregroundColor: theme.colorScheme.onSurface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          option,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}