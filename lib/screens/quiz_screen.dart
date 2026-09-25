// lib/screens/quiz_screen.dart
//
// Partida do "Quem é esse Pokémon?" — mesmas regras do site: 4 opções,
// 3 vidas. O jogo normal fica salvo na conta para continuar depois (até em
// outro aparelho). No Ranked (precisa de login) são todas as gerações e só
// 5 segundos por Pokémon (4 s com 100 pontos, 3 s com 200 e 2 s com 400);
// o recorde dele vai para o ranking.

import 'dart:math';
import 'package:flutter/material.dart';

import '../models/generation.dart';
import '../models/pokemon_listing.dart';
import '../services/pokemon_service.dart';
import '../services/user_data.dart';
import '../widgets/pokemon_sprite.dart';
import '../utils/responsive.dart';
import '../utils/string_extensions.dart';
import '../widgets/game_stage.dart';
import '../widgets/pikachu_loading_indicator.dart';

class QuizScreen extends StatefulWidget {
  static const lives = 3;
  static const rankedSeconds = 5;

  /// Ranked fica mais difícil com os pontos: 100 → 4 s, 200 → 3 s, 400 → 2 s.
  static int rankedSecondsFor(int score) {
    if (score >= 400) return 2;
    if (score >= 200) return 3;
    if (score >= 100) return 4;
    return rankedSeconds;
  }

  final Generation? generation;
  final bool ranked;
  final bool continueGame;

  const QuizScreen({super.key, this.generation, this.ranked = false, this.continueGame = false});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

const _timeout = -1; // "resposta" quando o tempo acaba

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
  final _data = UserData.instance;
  final _random = Random();

  List<PokemonListing>? _pool;
  Map<int, PokemonListing> _byId = {};

  // Estado no mesmo formato do site (quizGame).
  int _generationId = 0;
  late bool _ranked = widget.ranked;
  int _score = 0;
  int _lives = QuizScreen.lives;
  int _streak = 0;
  int _round = 0;
  int? _answerId;
  List<int> _options = [];

  int? _chosen;
  bool _over = false;

  late final AnimationController _timer = AnimationController(
    vsync: this,
    duration: const Duration(seconds: QuizScreen.rankedSeconds),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) _answer(_timeout);
    });

  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    // Sair no meio de um Ranked encerra o jogo com os pontos feitos
    // (depois do quadro atual, para não mexer em outras telas no meio dele).
    if (_ranked && !_over) {
      final score = _score;
      final data = _data;
      Future.microtask(() {
        if (score > data.rankedRecord) data.update({'rankedRecord': score});
      });
    }
    _timer.dispose();
    _shake.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final saved = widget.continueGame ? _data.quizGame : null;
    _generationId = saved != null ? (saved['generation'] as num? ?? 0).toInt() : (widget.generation?.id ?? 0);
    final gen = generations.where((g) => g.id == _generationId).firstOrNull;
    final service = PokemonService();
    try {
      _pool = gen == null ? await service.fetchAllPokemonList() : await service.fetchPokedex(gen);
    } catch (_) {
      if (mounted) Navigator.pop(context);
      return;
    }
    _byId = {for (final p in _pool!) int.parse(p.id): p};
    if (!mounted) return;
    if (saved != null && _byId.containsKey(saved['answerId'])) {
      setState(() {
        _ranked = false;
        _score = (saved['score'] as num? ?? 0).toInt();
        _lives = (saved['lives'] as num? ?? QuizScreen.lives).toInt();
        _streak = (saved['streak'] as num? ?? 0).toInt();
        _round = (saved['round'] as num? ?? 0).toInt();
        _answerId = (saved['answerId'] as num).toInt();
        _options = [for (final o in saved['options'] as List) (o as num).toInt()];
      });
    } else {
      _next(first: true);
    }
  }

  void _next({bool first = false}) {
    final pool = _pool!;
    final answer = pool[_random.nextInt(pool.length)];
    final options = <int>{int.parse(answer.id)};
    while (options.length < min(4, pool.length)) {
      options.add(int.parse(pool[_random.nextInt(pool.length)].id));
    }
    setState(() {
      _chosen = null;
      if (!first) _round++;
      _answerId = int.parse(answer.id);
      _options = options.toList()..shuffle(_random);
    });
    _save();
    if (_ranked) {
      _timer.duration = Duration(seconds: QuizScreen.rankedSecondsFor(_score));
      _timer.forward(from: 0);
    }
  }

  Map<String, dynamic> get _game => {
        'generation': _generationId,
        'ranked': _ranked,
        'round': _round,
        'score': _score,
        'lives': _lives,
        'streak': _streak,
        'answerId': _answerId,
        'options': _options,
      };

  /// O Ranked não fica salvo para continuar depois (senão daria para ganhar tempo).
  void _save() {
    if (!_ranked) _data.update({'quizGame': _game});
  }

  void _answer(int id) {
    if (_chosen != null || _answerId == null || _over) return;
    _timer.stop();
    final correct = id == _answerId;
    setState(() {
      _chosen = id;
      if (correct) {
        _score++;
        _streak++;
      } else {
        _lives--;
        _streak = 0;
      }
    });
    if (!correct) _shake.forward(from: 0);
    Future.delayed(Duration(milliseconds: correct ? 1100 : 2000), () {
      if (!mounted) return;
      if (_lives <= 0) {
        _end();
      } else {
        _next();
      }
    });
  }

  void _finishRanked() {
    if (_score > _data.rankedRecord) _data.update({'rankedRecord': _score});
  }

  void _end() {
    _over = true;
    _timer.stop();
    final previous = _ranked ? _data.rankedRecord : _data.quizRecord;
    if (_ranked) {
      _finishRanked();
    } else {
      _data.update({'quizGame': null, if (_score > _data.quizRecord) 'quizRecord': _score});
    }
    final newRecord = _score > previous;
    final theme = Theme.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Center(child: Text(_ranked ? 'Fim do Ranked!' : 'Fim de Jogo!')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Sua pontuação foi:'),
            Text('$_score', style: const TextStyle(color: Colors.amber, fontSize: 56, fontWeight: FontWeight.w900)),
            if (newRecord)
              Text(_ranked ? 'Novo recorde no Ranked! Confira sua posição no ranking! 🎉' : 'Novo recorde! 🎉',
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.greenAccent)),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceAround,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialog);
              Navigator.pop(context);
            },
            child: const Text('Sair', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialog);
              setState(() {
                _over = false;
                _score = 0;
                _lives = QuizScreen.lives;
                _streak = 0;
                _round = 0;
              });
              _next(first: true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white),
            child: const Text('Jogar novamente', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  String _name(int id) {
    final name = _byId[id]?.name ?? '?';
    return name.replaceAll('-', ' ').capitalise();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final answer = _answerId;
    if (_pool == null || answer == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: PikachuLoadingIndicator()));
    }
    final revealed = _chosen != null;
    final hit = revealed && _chosen == answer;
    final record = _ranked ? _data.rankedRecord : _data.quizRecord;

    return Scaffold(
      appBar: AppBar(
        title: Text(_ranked ? '🏆 Ranked' : 'Quem é esse Pokémon?'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                for (var i = 0; i < QuizScreen.lives; i++)
                  AnimatedScale(
                    scale: i < _lives ? 1 : 0.7,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(i < _lives ? Icons.favorite : Icons.favorite_border, color: Colors.redAccent, size: 26),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: ReadableWidth(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              Row(
                children: [
                  _Stat('Pontos', '$_score'),
                  const SizedBox(width: 8),
                  _Stat('Sequência', '$_streak🔥', color: Colors.orange),
                  const SizedBox(width: 8),
                  _Stat('Recorde', '${max(record, _score)}', color: Colors.amber),
                ],
              ),
              if (_ranked) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(
                      child: Text('🏆 Ranked · Todas as gerações',
                          style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    Text('${QuizScreen.rankedSecondsFor(_score)}s por Pokémon',
                        style: TextStyle(color: Theme.of(context).hintColor, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                _TimerBar(timer: _timer),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: GameStage(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 56),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                            child: SizedBox.expand(
                              key: ValueKey('$answer-$revealed'),
                              // Mesmo tamanho visual para todos (como no site).
                              child: PokemonSprite(answer, fill: 0.95, silhouette: revealed ? null : Colors.black),
                            ),
                          ),
                        ),
                      ),
                      if (revealed)
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 12,
                          child: StageTitle('É o ${_name(answer)}!', size: 24),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AnimatedBuilder(
                animation: _shake,
                builder: (context, child) => Transform.translate(
                  offset: Offset(sin(_shake.value * pi * 6) * 8 * (1 - _shake.value), 0),
                  child: child,
                ),
                child: Column(
                  children: [
                    for (final (i, id) in _options.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _OptionButton(
                          index: i + 1,
                          label: _name(id),
                          color: !revealed
                              ? const Color(0xFF42A5F5)
                              : id == answer
                                  ? const Color(0xFF43A047)
                                  : id == _chosen
                                      ? const Color(0xFFE53935)
                                      : const Color(0xFF616161),
                          mark: revealed && id == answer
                              ? '✓'
                              : revealed && id == _chosen
                                  ? '✗'
                                  : null,
                          onTap: revealed ? null : () => _answer(id),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 24,
                child: revealed
                    ? Text(
                        hit
                            ? 'Acertou! +1 ponto'
                            : _chosen == _timeout
                                ? 'Tempo esgotado! -1 vida'
                                : 'Errou! -1 vida',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: hit ? Colors.greenAccent : Colors.redAccent),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Stat(this.label, this.value, {this.color});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
        ),
      );
}

/// Barra de tempo do Ranked: verde → amarelo → vermelho em 5 s.
class _TimerBar extends StatelessWidget {
  final AnimationController timer;
  const _TimerBar({required this.timer});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 12,
        child: AnimatedBuilder(
          animation: timer,
          builder: (context, _) {
            final t = timer.value;
            final color = t < .5
                ? Color.lerp(const Color(0xFF43A047), const Color(0xFFFDD835), t * 2)!
                : Color.lerp(const Color(0xFFFDD835), const Color(0xFFE53935), (t - .5) * 2)!;
            return LinearProgressIndicator(
              value: 1 - t,
              backgroundColor: Theme.of(context).cardColor,
              valueColor: AlwaysStoppedAnimation(color),
            );
          },
        ),
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final int index;
  final String label;
  final Color color;
  final String? mark;
  final VoidCallback? onTap;
  const _OptionButton({required this.index, required this.label, required this.color, this.mark, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.white24,
                  child: Text('$index',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                if (mark != null) Text(mark!, style: const TextStyle(color: Colors.white, fontSize: 20)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
