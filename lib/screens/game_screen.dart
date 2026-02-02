// lib/screens/game_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/generation.dart';
import '../widgets/generation_card.dart';
import 'quiz_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const String _recordKey = 'quiz_highscore';
  static const String _livesKey = 'quiz_lives';

  int _highScore = 0;
  bool _isGameInProgress = false;
  Generation? _selectedGeneration;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSavedGame());
  }

  Future<void> _checkSavedGame() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _highScore = prefs.getInt(_recordKey) ?? 0;
      _isGameInProgress = (prefs.getInt(_livesKey) ?? 0) > 0;
    });
  }

  Future<void> _clearSavedGame() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_livesKey);
    await prefs.remove('quiz_score');
    await prefs.remove('quiz_correct_pokemon_id');
    await prefs.remove('quiz_options');
    await prefs.remove('quiz_generation');
  }

  void _showGenerationSelector() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade700,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Generation', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 20),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: generations.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedGeneration = null;
                            });
                            Navigator.pop(context);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(
                                'Todas as Gerações',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      final generation = generations[index - 1];
                      return GenerationCard(
                        generation: generation,
                        onTap: () {
                          setState(() {
                            _selectedGeneration = generation;
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quem é esse Pokémon?'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Seu Recorde: $_highScore Pontos',
                style: TextStyle(
                  color: Colors.yellow[600],
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 60),
              Text(
                'Escolha a Geração:',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withAlpha(178),
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _showGenerationSelector,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedGeneration?.name ?? 'Todas as Gerações',
                        style: TextStyle(
                            color: theme.colorScheme.onSurface, fontSize: 16),
                      ),
                      Icon(Icons.arrow_drop_down,
                          color: theme.colorScheme.onSurface),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              if (_isGameInProgress)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (!mounted) return;
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => QuizScreen(
                            generation: _selectedGeneration,
                            continueGame: true,
                          ),
                        ),
                      );
                      if (!mounted) return;
                      _checkSavedGame();
                    },
                    icon: const Icon(Icons.play_circle_fill),
                    label: const Text('Continuar Jogo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle:
                          const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ElevatedButton.icon(
                onPressed: () async {
                  await _clearSavedGame();
                  if (!mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuizScreen(
                        generation: _selectedGeneration,
                        continueGame: false,
                      ),
                    ),
                  );
                  if (!mounted) return;
                  _checkSavedGame();
                },
                icon: const Icon(Icons.play_arrow),
                label:
                    Text(_isGameInProgress ? 'Iniciar Novo Jogo' : 'Iniciar Jogo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle:
                      const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}