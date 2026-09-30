// lib/screens/quiz_screen.dart
//
// Partida do "Quem é esse Pokémon?" — mesmas regras do site: 4 opções,
// 3 vidas. O jogo normal fica salvo na conta para continuar depois (até em
// outro aparelho). No Ranked (precisa de login) são todas as gerações e só
// 5 segundos por Pokémon (4 s com 100 pontos, 3 s com 200 e 2 s com 400);
// o recorde dele vai para o ranking geral e o da semana.
//
// Desafio do dia (precisa de login): os mesmos 10 Pokémon para todo mundo no
// dia (os mesmos do site), 10 segundos cada e uma tentativa só. Quanto mais
// rápido acertar, mais pontos.
//
// Modos de pista (jogo normal e desafio entre amigos): silhueta, grito,
// descrição da Pokédex ou tipos. O desafio entre amigos são 10 Pokémon
// sorteados por uma semente (os mesmos do site) e um link para comparar.

import 'dart:math';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../i18n/i18n.dart';
import '../services/auth_service.dart';
import '../services/challenge.dart';
import '../services/cry_player.dart';
import '../services/friends_service.dart';
import '../widgets/account_avatar.dart';
import '../services/local_database.dart';

import '../models/generation.dart';
import '../models/pokemon_listing.dart';
import '../services/account_sync.dart';
import '../services/daily_reminder.dart';
import '../services/league.dart';
import '../services/pokemon_service.dart';
import '../services/user_data.dart';
import '../widgets/pokemon_sprite.dart';
import '../utils/pokemon_colors.dart';
import '../utils/responsive.dart';
import '../utils/string_extensions.dart';
import '../widgets/game_stage.dart';
import '../widgets/pikachu_loading_indicator.dart';
import 'package:pocket_dex/i18n/text.dart';

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
  final bool daily;
  final bool continueGame;

  /// Pista: 'silhouette' | 'cry' | 'description' | 'types'.
  final String hint;

  /// Desafio entre amigos (o de outra pessoa, ou um novo com semente própria).
  final Challenge? challenge;

  const QuizScreen({
    super.key,
    this.generation,
    this.ranked = false,
    this.daily = false,
    this.continueGame = false,
    this.hint = 'silhouette',
    this.challenge,
  });

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
  List<int> _recent = []; // respostas recentes, que ainda não podem voltar

  int? _chosen;
  bool _over = false;

  // Desafio do dia
  late final bool _daily = widget.daily;
  final String _day = League.dayKey();
  List<int> _answers = [];
  int _correct = 0;
  double _seconds = 0;
  DateTime _roundStart = DateTime.now();

  // Pista e desafio entre amigos
  late String _hint = widget.ranked || widget.daily ? 'silhouette' : widget.hint;
  late Challenge? _challenge = widget.challenge;
  List<(int, List<int>)> _rounds = [];

  bool get _timed => _ranked || _daily;

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
        data.countRanked(League.weekKey());
        AccountSync.instance.saveWeekly(League.weekKey(), score);
      });
    }
    if (_daily && !_over) _finishDaily();
    _timer.dispose();
    _shake.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_daily) {
      _answers = League.dailyAnswers(_day);
      _data.countDaily(_day); // conta já ao começar: uma tentativa por dia
      DailyReminder.instance.reschedule(); // hoje já jogou: sem lembrete hoje
    }
    final saved = widget.continueGame && !_daily ? _data.quizGame : null;
    _generationId = saved != null
        ? (saved['generation'] as num? ?? 0).toInt()
        : _challenge != null
            ? _challenge!.gen
            : (widget.generation?.id ?? 0);
    if (saved?['hint'] is String) _hint = saved!['hint'] as String;
    if (_challenge != null) _hint = _challenge!.hint;
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
    if (_challenge != null) {
      _rounds = challengeRoundsFor(_byId.keys.toList(), _challenge!.seed);
      _next(first: true);
      return;
    }
    if (saved != null && _byId.containsKey(saved['answerId'])) {
      setState(() {
        _ranked = false;
        _score = (saved['score'] as num? ?? 0).toInt();
        _lives = (saved['lives'] as num? ?? QuizScreen.lives).toInt();
        _streak = (saved['streak'] as num? ?? 0).toInt();
        _round = (saved['round'] as num? ?? 0).toInt();
        _answerId = (saved['answerId'] as num).toInt();
        _recent = [for (final r in saved['recent'] as List? ?? []) (r as num).toInt()];
        _options = [for (final o in saved['options'] as List) (o as num).toInt()];
      });
    } else {
      _next(first: true);
    }
  }

  /// Quantos Pokémon recentes não podem voltar (80% da lista, no máximo 400; igual ao site).
  int get _recentLimit => min(400, (_pool!.length * 0.8).floor());

  void _next({bool first = false}) {
    final pool = _pool!;
    final round = first ? 0 : _round + 1;
    if (!_daily && !first && _answerId != null) {
      _recent = [..._recent, _answerId!];
      if (_recent.length > _recentLimit) _recent = _recent.sublist(_recent.length - _recentLimit);
    }
    // Sorteia entre os que não saíram há pouco, para não repetir cedo.
    final seen = _recent.toSet();
    final fresh = seen.isEmpty ? pool : pool.where((p) => !seen.contains(int.parse(p.id))).toList();
    final from = fresh.isEmpty ? pool : fresh;
    final answerId = _challenge != null
        ? _rounds[round].$1
        : _daily
            ? _answers[round]
            : int.parse(from[_random.nextInt(from.length)].id);
    final options = <int>{answerId};
    while (_challenge == null && options.length < min(4, pool.length)) {
      options.add(int.parse(pool[_random.nextInt(pool.length)].id));
    }
    setState(() {
      _chosen = null;
      if (!first) _round++;
      _answerId = answerId;
      _options = _challenge != null ? [..._rounds[round].$2] : (options.toList()..shuffle(_random));
    });
    _save();
    _roundStart = DateTime.now();
    if (_timed) {
      _timer.duration = Duration(seconds: _daily ? League.dailySeconds : QuizScreen.rankedSecondsFor(_score));
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
        'recent': _recent,
        'hint': _hint,
      };

  /// O Ranked não fica salvo para continuar depois (senão daria para ganhar tempo).
  void _save() {
    if (!_ranked && !_daily && _challenge == null) _data.update({'quizGame': _game});
  }

  void _answer(int id) {
    if (_chosen != null || _answerId == null || _over) return;
    _timer.stop();
    final correct = id == _answerId;
    final spent = DateTime.now().difference(_roundStart).inMilliseconds.clamp(0, League.dailySeconds * 1000);
    setState(() {
      _chosen = id;
      if (_daily) {
        _seconds += spent / 1000;
        if (correct) {
          _score += League.dailyPoints(League.dailySeconds * 1000 - spent);
          _correct++;
          _streak++;
        } else {
          _streak = 0;
        }
      } else if (correct) {
        _score++;
        _streak++;
      } else {
        if (_challenge == null) _lives--;
        _streak = 0;
      }
    });
    _data.countAnswer(correct, _streak);
    if (!correct) _shake.forward(from: 0);
    Future.delayed(Duration(milliseconds: correct ? 1100 : 2000), () {
      if (!mounted) return;
      if (_challenge != null
          ? _round + 1 >= _rounds.length
          : _daily
              ? _round + 1 >= League.dailyRounds
              : _lives <= 0) {
        _end();
      } else {
        _next();
      }
    });
  }

  void _finishRanked() {
    if (_score > _data.rankedRecord) _data.update({'rankedRecord': _score});
    final week = League.weekKey();
    _data.countRanked(week);
    AccountSync.instance.saveWeekly(week, _score);
  }

  void _finishDaily() {
    if (_correct == League.dailyRounds) _data.countDailyPerfect();
    AccountSync.instance.saveDaily(_day, score: _score, correct: _correct, seconds: _seconds.round());
  }

  void _end() {
    _over = true;
    _timer.stop();
    if (_challenge != null) return _endChallenge();
    final previous = _ranked ? _data.rankedRecord : _data.quizRecord;
    if (_daily) {
      _finishDaily();
    } else if (_ranked) {
      _finishRanked();
    } else {
      _data.update({'quizGame': null, if (_score > _data.quizRecord) 'quizRecord': _score});
    }
    final newRecord = !_daily && _score > previous;
    final theme = Theme.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Center(
            child: Text(_daily
                ? 'Fim do desafio do dia!'
                : _ranked
                    ? 'Fim do Ranked!'
                    : 'Fim de Jogo!')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Sua pontuação foi:'),
            Text('$_score', style: const TextStyle(color: Colors.amber, fontSize: 56, fontWeight: FontWeight.w900)),
            if (_daily)
              Text(
                '$_correct de ${League.dailyRounds} acertos. Veja sua posição na aba Hoje do ranking e volte amanhã para um desafio novo!',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.hintColor),
              ),
            if (_daily && DailyReminder.supported) const _ReminderOffer(),
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
          if (!_daily)
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

  /// Fim do desafio entre amigos: resultado, comparação e link para mandar.
  void _endChallenge() {
    final theme = Theme.of(context);
    final from = _challenge!.name.isEmpty ? null : _challenge!;
    final mine = Challenge(
      seed: _challenge!.seed,
      gen: _generationId,
      hint: _hint,
      name: AuthService.instance.user?.name ?? '',
      score: _score,
    );
    final verdict = from == null
        ? null
        : _score > from.score
            ? tr('Você venceu! 🎉')
            : _score < from.score
                ? tr('{0} venceu dessa vez.').replaceAll('{0}', from.name)
                : tr('Empate!');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Center(child: Text('Fim do desafio!')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$_score/${_rounds.length}',
                style: const TextStyle(color: Color(0xFFA78BFA), fontSize: 52, fontWeight: FontWeight.w900)),
            if (from != null)
              Text(tr('{0} fez {1}/{2}.').replaceAll('{0}', from.name).replaceAll('{1}', '${from.score}').replaceAll('{2}', '${_rounds.length}'),
                  style: TextStyle(color: theme.hintColor)),
            if (verdict != null) Text(verdict, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            Text('Mande este link para um amigo jogar os mesmos Pokémon e tentar te passar:',
                textAlign: TextAlign.center, style: TextStyle(color: theme.hintColor, fontSize: 13)),
            const SizedBox(height: 6),
            SelectableText(mine.link, style: const TextStyle(fontSize: 11)),
            _SendToFriends(code: mine.code, score: _score),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceAround,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialog);
              Navigator.pop(context);
            },
            child: const Text('Sair'),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: mine.link));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copiado!')));
            },
            child: const Text('Copiar link'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialog);
              setState(() {
                _challenge = Challenge(seed: Random().nextInt(1 << 31), gen: _generationId, hint: _hint);
                _rounds = challengeRoundsFor(_byId.keys.toList(), _challenge!.seed);
                _over = false;
                _score = 0;
                _streak = 0;
                _round = 0;
              });
              _next(first: true);
            },
            child: const Text('Novo desafio'),
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
        title: Text(_challenge != null
            ? '🤝 Desafio'
            : _daily
                ? '📅 Desafio do dia'
                : _ranked
                    ? '🏆 Ranked'
                    : 'Quem é esse Pokémon?'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                if (_challenge != null)
                  Text('${_round + 1}/${_rounds.length}',
                      style: const TextStyle(color: Color(0xFFA78BFA), fontWeight: FontWeight.w900, fontSize: 18))
                else if (_daily)
                  Text('${_round + 1}/${League.dailyRounds}',
                      style: const TextStyle(color: Color(0xFF26A69A), fontWeight: FontWeight.w900, fontSize: 18)),
                if (!_daily && _challenge == null)
                  for (var i = 0; i < QuizScreen.lives; i++)
                    AnimatedScale(
                      scale: i < _lives ? 1 : 0.7,
                      duration: const Duration(milliseconds: 250),
                      child:
                          Icon(i < _lives ? Icons.favorite : Icons.favorite_border, color: Colors.redAccent, size: 26),
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
                  _challenge != null
                      ? (_challenge!.name.isNotEmpty
                          ? _Stat(tr('{0} fez').replaceAll('{0}', _challenge!.name), '${_challenge!.score}', color: Colors.amber)
                          : _Stat('Rodada', '${_round + 1}', color: Colors.amber))
                      : _daily
                          ? _Stat('Acertos', '$_correct', color: Colors.amber)
                          : _Stat('Recorde', '${max(record, _score)}', color: Colors.amber),
                ],
              ),
              if (_timed) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(_daily ? '📅 Desafio do dia · Todas as gerações' : '🏆 Ranked · Todas as gerações',
                          style: TextStyle(
                              color: _daily ? const Color(0xFF26A69A) : Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                    Text('${_daily ? League.dailySeconds : QuizScreen.rankedSecondsFor(_score)}s por Pokémon',
                        style:
                            TextStyle(color: Theme.of(context).hintColor, fontWeight: FontWeight.bold, fontSize: 13)),
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
                              child: _hint != 'silhouette' && !revealed
                                  ? _Clue(pokemonId: answer, hint: _hint)
                                  : PokemonSprite(answer, fill: 0.95, silhouette: revealed ? null : Colors.black),
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
                        _daily
                            ? (hit
                                ? 'Acertou!'
                                : _chosen == _timeout
                                    ? 'Tempo esgotado!'
                                    : 'Errou!')
                            : hit
                                ? 'Acertou! +1 ponto'
                                : _challenge != null
                                    ? 'Errou!'
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

/// No fim do desafio do dia: oferece o lembrete diário (se ainda não estiver ligado).
class _ReminderOffer extends StatefulWidget {
  const _ReminderOffer();

  @override
  State<_ReminderOffer> createState() => _ReminderOfferState();
}

class _ReminderOfferState extends State<_ReminderOffer> {
  bool? _on;

  @override
  void initState() {
    super.initState();
    DailyReminder.instance.enabled.then((on) {
      if (mounted) setState(() => _on = on);
    });
  }

  Future<void> _enable() async {
    final ok = await DailyReminder.instance.setEnabled(true);
    if (mounted) setState(() => _on = ok);
  }

  @override
  Widget build(BuildContext context) {
    if (_on == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: _on!
          ? const Text('🔔 Lembrete diário ligado', style: TextStyle(color: Colors.greenAccent))
          : TextButton.icon(
              onPressed: _enable,
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Me lembrar todo dia às 9h'),
            ),
    );
  }
}

/// Pista nos modos Grito, Descrição e Tipos (a mesma do site).
class _Clue extends StatefulWidget {
  final int pokemonId;
  final String hint;
  const _Clue({required this.pokemonId, required this.hint});

  @override
  State<_Clue> createState() => _ClueState();
}

class _ClueState extends State<_Clue> {
  Map<String, dynamic>? _row;
  Map<String, dynamic>? _species;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = LocalDatabase.instance;
    final row = await db.pokemonRow(widget.pokemonId);
    final species = row == null ? null : (await db.speciesById())[row['species']];
    if (!mounted) return;
    setState(() {
      _row = row;
      _species = species;
    });
    if (widget.hint == 'cry') CryPlayer.instance.play((row?['species'] as int?) ?? widget.pokemonId);
  }

  @override
  void dispose() {
    if (widget.hint == 'cry') CryPlayer.instance.stop();
    super.dispose();
  }

  /// Tira o nome do Pokémon da descrição (para não entregar a resposta).
  String _hideName(String text) {
    final species = _species;
    if (species == null) return text;
    final names = <String>{
      species['name'] as String,
      (species['name'] as String).replaceAll('-', ' '),
      ...((species['names'] as Map?) ?? const {}).values.whereType<String>(),
    }.where((n) => n.length > 1);
    var out = text;
    for (final n in names) {
      out = out.replaceAll(RegExp(RegExp.escape(n), caseSensitive: false), '???');
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hint == 'cry') {
      return Center(
        child: Material(
          color: Colors.white.withAlpha(230),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => CryPlayer.instance.play((_row?['species'] as int?) ?? widget.pokemonId),
            child: const Padding(padding: EdgeInsets.all(36), child: Text('🔊', style: TextStyle(fontSize: 64))),
          ),
        ),
      );
    }
    final species = _species;
    final row = _row;
    if (species == null || row == null) return const Center(child: CircularProgressIndicator(color: Colors.white));
    final box = BoxDecoration(color: Colors.black.withAlpha(90), borderRadius: BorderRadius.circular(24));
    if (widget.hint == 'types') {
      final genus = (I18n.pick(species['genus'] as String?, species['genera']) ?? '')
          .replaceAll(' Pokémon', '')
          .replaceFirst(RegExp(r'^Pokémon '), '');
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: box,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(spacing: 8, children: [
                for (final t in (row['types'] as List).cast<String>())
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(color: getColorForType(t), borderRadius: BorderRadius.circular(20)),
                    child: Text(t.capitalise(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
              ]),
              const SizedBox(height: 12),
              Text('Pokémon $genus', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }
    final flavor = I18n.pick(species['flavor'] as String?, species['flavors']) ?? '';
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: box,
        child: SingleChildScrollView(
          // Já está no idioma escolhido: não passa pelo tradutor (m.Text).
          child: _plainText(_hideName(flavor)),
        ),
      ),
    );
  }

  Widget _plainText(String text) => RichText(
        textAlign: TextAlign.center,
        text: TextSpan(text: text, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, height: 1.4)),
      );
}

/// No fim do desafio: manda direto para amigos (aparece na tela Amigos deles).
class _SendToFriends extends StatefulWidget {
  final String code;
  final int score;
  const _SendToFriends({required this.code, required this.score});

  @override
  State<_SendToFriends> createState() => _SendToFriendsState();
}

class _SendToFriendsState extends State<_SendToFriends> {
  final _sent = <String, bool>{}; // true = enviado; false = enviando

  @override
  Widget build(BuildContext context) {
    final friends = FriendsService.instance.friends;
    if (friends.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        const SizedBox(height: 10),
        Text('Ou mande para um amigo:', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 180),
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final f in friends)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: PlayerAvatar(pokemonId: f.avatar, name: f.name, size: 30),
                    title: Text(f.name, overflow: TextOverflow.ellipsis),
                    trailing: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), visualDensity: VisualDensity.compact),
                      onPressed: _sent.containsKey(f.uid)
                          ? null
                          : () {
                              setState(() => _sent[f.uid] = false);
                              FriendsService.instance
                                  .sendChallenge(f.uid, widget.code, widget.score)
                                  .then((_) => mounted ? setState(() => _sent[f.uid] = true) : null)
                                  .catchError((_) => mounted ? setState(() => _sent.remove(f.uid)) : null);
                            },
                      child: Text(_sent[f.uid] == true ? 'Enviado ✓' : _sent.containsKey(f.uid) ? '...' : 'Enviar'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
