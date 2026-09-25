// lib/screens/game_screen.dart
//
// Menu do "Quem é esse Pokémon?", igual ao do site adaptado ao celular:
// palco azul com raios, recordes (normal e Ranked), seletor de geração,
// botões de jogo normal, Ranked (5 s por Pokémon) e desafio do dia, e o
// ranking (geral, da semana e do desafio de hoje).

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/generation.dart';
import '../services/account_sync.dart';
import '../services/auth_service.dart';
import '../services/league.dart';
import '../services/user_data.dart';
import '../widgets/account_avatar.dart';
import '../widgets/pokemon_sprite.dart';
import '../utils/responsive.dart';
import '../widgets/game_stage.dart';
import '../widgets/generation_picker.dart';
import 'quiz_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  Generation? _generation;

  String _board = 'all';

  Future<void> _play({required bool ranked, bool daily = false, bool resume = false}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          generation: ranked || daily ? null : _generation,
          ranked: ranked,
          daily: daily,
          continueGame: resume,
        ),
      ),
    );
    if (mounted && (ranked || daily)) setState(() => _board = daily ? 'day' : 'week');
  }

  @override
  Widget build(BuildContext context) {
    // Recordes e jogo salvo podem mudar pela conta (site / outro aparelho).
    return ListenableBuilder(listenable: UserData.instance, builder: (context, _) => _build(context));
  }

  Widget _build(BuildContext context) {
    final data = UserData.instance;
    final signedIn = context.watch<AuthService>().status == AuthStatus.signedIn;
    final saved = data.quizGame;
    final playedToday = data.stats['lastDaily'] == League.dayKey();
    final starters = _generation?.starterIds ?? allGenerationsStarters;

    return Scaffold(
      appBar: AppBar(title: const Text('Jogo')),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            SizedBox(
              height: 230,
              child: GameStage(
                child: Stack(
                  children: [
                    const Positioned(
                      top: 14,
                      left: 0,
                      right: 0,
                      child: StageTitle('Quem é esse Pokémon?', size: 28),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final id in starters)
                            Expanded(
                              child: SizedBox(
                                height: 130,
                                child: PokemonSprite(id, alignBottom: true, silhouette: Colors.black),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _RecordCard(icon: '🎮', label: 'Recorde normal', value: data.quizRecord, color: Colors.lightBlue)),
                if (signedIn) ...[
                  const SizedBox(width: 10),
                  Expanded(child: _RecordCard(icon: '🏆', label: 'Recorde Ranked', value: data.rankedRecord, color: Colors.amber)),
                ],
              ],
            ),
            const SizedBox(height: 14),
            _Rules(signedIn: signedIn),
            const SizedBox(height: 14),
            const Text('Geração', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: GenerationPicker(value: _generation, onChanged: (g) => setState(() => _generation = g)),
            ),
            const SizedBox(height: 18),
            if (saved != null && (saved['lives'] as num? ?? 0) > 0) ...[
              _BigButton(
                label: '▶ Continuar jogo (${saved['score'] ?? 0} pontos)',
                color: const Color(0xFF43A047),
                onPressed: () => _play(ranked: false, resume: true),
              ),
              const SizedBox(height: 10),
            ],
            _BigButton(
              label: saved != null ? '▶ Novo jogo normal' : '▶ Jogo normal',
              color: const Color(0xFF2196F3),
              onPressed: () => _play(ranked: false),
            ),
            if (signedIn) ...[
              const SizedBox(height: 10),
              _BigButton(
                label: '🏆 Jogar Ranked (todas as gerações)',
                gradient: const LinearGradient(colors: [Color(0xFFF9A825), Color(0xFFE65100)]),
                onPressed: () => _play(ranked: true),
              ),
              const SizedBox(height: 10),
              Opacity(
                opacity: playedToday ? 0.6 : 1,
                child: _BigButton(
                  label: playedToday ? '📅 Desafio de hoje feito — volte amanhã!' : '📅 Desafio do dia',
                  gradient: const LinearGradient(colors: [Color(0xFF26A69A), Color(0xFF00695C)]),
                  onPressed: playedToday ? null : () => _play(ranked: false, daily: true),
                ),
              ),
              const SizedBox(height: 20),
              _Ranking(board: _board, onBoard: (b) => setState(() => _board = b)),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  final String icon;
  final String label;
  final int value;
  final Color color;
  const _RecordCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          CircleAvatar(radius: 22, backgroundColor: color, child: Text(icon, style: const TextStyle(fontSize: 20))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                Text('$value', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Rules extends StatelessWidget {
  final bool signedIn;
  const _Rules({required this.signedIn});
  @override
  Widget build(BuildContext context) {
    final style = TextStyle(color: Theme.of(context).hintColor, height: 1.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('• Adivinhe o Pokémon pela silhueta entre 4 opções.', style: style),
        Text('• Você tem 3 vidas; cada erro custa uma.', style: style),
        if (signedIn)
          Text.rich(
            const TextSpan(children: [
              TextSpan(text: '• '),
              TextSpan(text: 'Desafio do dia: ', style: TextStyle(color: Color(0xFF26A69A), fontWeight: FontWeight.bold)),
              TextSpan(
                  text: 'os mesmos ${League.dailyRounds} Pokémon para todo mundo, ${League.dailySeconds} segundos cada e '
                      'uma tentativa por dia. Quanto mais rápido acertar, mais pontos.'),
            ]),
            style: style,
          ),
        if (signedIn)
          Text.rich(
            const TextSpan(children: [
              TextSpan(text: '• '),
              TextSpan(text: 'Ranked: ', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
              TextSpan(text: 'todas as gerações e só ${QuizScreen.rankedSeconds} segundos por Pokémon, que caem para 4 s com 100 pontos, 3 s com 200 e 2 s com 400. É ele que conta para o ranking.'),
            ]),
            style: style,
          ),
      ],
    );
  }
}

class _BigButton extends StatelessWidget {
  final String label;
  final Color? color;
  final Gradient? gradient;
  final VoidCallback? onPressed;
  const _BigButton({required this.label, this.color, this.gradient, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 56,
        decoration: BoxDecoration(
          color: color,
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Center(
            child: Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}

/// Rankings (os mesmos do site): geral do Ranked, da semana e do desafio de hoje.
class _Ranking extends StatefulWidget {
  final String board;
  final ValueChanged<String> onBoard;
  const _Ranking({required this.board, required this.onBoard});
  @override
  State<_Ranking> createState() => _RankingState();
}

class _RankingState extends State<_Ranking> {
  static const _boards = [
    ('all', 'Geral', 'Os maiores recordes no modo Ranked.', 'Ninguém pontuou no Ranked ainda. Seja o primeiro!'),
    ('week', 'Semana', 'Os melhores Ranked desta semana (começa na segunda).', 'Ninguém jogou o Ranked esta semana ainda.'),
    ('day', 'Hoje', 'Desafio do dia: os mesmos 10 Pokémon para todos.', 'Ninguém fez o desafio de hoje ainda. Seja o primeiro!'),
  ];

  final _sync = AccountSync.instance;
  List<Map<String, dynamic>>? _list;
  Map<String, dynamic>? _mine;
  int? _position;
  bool _error = false;
  String? _errorText;
  String? _loadedBoard;

  StreamSubscription<List<Map<String, dynamic>>>? _live;

  @override
  void initState() {
    super.initState();
    _sync.rankingVersion.addListener(_load);
    _load();
  }

  @override
  void didUpdateWidget(covariant _Ranking old) {
    super.didUpdateWidget(old);
    if (old.board != widget.board) _load();
  }

  @override
  void dispose() {
    _live?.cancel();
    _sync.rankingVersion.removeListener(_load);
    super.dispose();
  }

  String get _key => switch (widget.board) {
        'week' => League.weekKey(),
        'day' => League.dayKey(),
        _ => '',
      };

  /// Ouve o ranking em tempo real: atualiza sozinho quando alguém faz pontos.
  void _load() {
    final board = widget.board;
    final key = _key;
    _live?.cancel();
    if (mounted && _loadedBoard != board) setState(() => _list = null);
    _live = _sync.watchRanking(10, board, key).listen(
      (list) => _show(board, key, list),
      onError: (Object e) {
        if (mounted && board == widget.board) {
          setState(() {
            _list = const [];
            _error = true;
            _errorText = e is FirebaseException ? e.code : '$e';
            _loadedBoard = board;
          });
        }
      },
    );
  }

  Future<void> _show(String board, String key, List<Map<String, dynamic>> list) async {
    // A posição é um extra: se falhar, a lista aparece do mesmo jeito.
    Map<String, dynamic>? mine;
    int? position;
    try {
      mine = await _sync.myScore(board, key);
      if (mine != null) position = await _sync.rankingPosition((mine['score'] as num).toInt(), board, key);
    } catch (_) {}
    if (mounted && board == widget.board) {
      setState(() {
        _list = list;
        _mine = mine;
        _position = position;
        _error = false;
        _errorText = null;
        _loadedBoard = board;
      });
    }
  }

  static String? _detail(Map<String, dynamic>? r) =>
      r?['correct'] == null ? null : '${r!['correct']}/${League.dailyRounds} acertos · ${r['seconds'] ?? 0}s';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = AuthService.instance.user;
    final info = _boards.firstWhere((b) => b.$1 == widget.board);
    final ready = _list != null && _loadedBoard == widget.board;
    final inTop = ready && _list!.any((r) => r['uid'] == me?.uid);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(radius: 22, backgroundColor: Colors.amber, child: Text('🏅', style: TextStyle(fontSize: 20))),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ranking', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    Text(info.$3, style: TextStyle(fontSize: 12, color: theme.hintColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: BorderRadius.circular(30)),
            child: Row(
              children: [
                for (final b in _boards)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => widget.onBoard(b.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: widget.board == b.$1 ? Colors.amber : Colors.transparent,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          b.$2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: widget.board == b.$1 ? const Color(0xFF3E2723) : theme.hintColor,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!ready)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (_error)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text('Não foi possível carregar o ranking agora${_errorText != null ? ' ($_errorText)' : ''}.',
                      textAlign: TextAlign.center, style: TextStyle(color: theme.hintColor)),
                  TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Tentar de novo')),
                ],
              ),
            )
          else if (_list!.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(child: Text(info.$4, textAlign: TextAlign.center, style: TextStyle(color: theme.hintColor))),
            )
          else ...[
            for (final (i, r) in _list!.indexed)
              _RankingRow(
                position: i + 1,
                name: '${r['name']}',
                score: (r['score'] as num).toInt(),
                avatar: (r['avatar'] as num?)?.toInt(),
                detail: _detail(r),
                me: r['uid'] == me?.uid,
              ),
            if (!inTop && _position != null && _mine != null && me?.name != null) ...[
              Center(child: Text('⋯', style: TextStyle(color: theme.hintColor))),
              _RankingRow(
                position: _position!,
                name: me!.name!,
                score: (_mine!['score'] as num).toInt(),
                avatar: UserData.instance.avatar,
                detail: _detail(_mine),
                me: true,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  final int position;
  final String name;
  final int score;
  final int? avatar;
  final String? detail;
  final bool me;
  const _RankingRow({
    required this.position,
    required this.name,
    required this.score,
    required this.avatar,
    required this.detail,
    required this.me,
  });

  static const _medals = [Color(0xFFFFD54F), Color(0xFFCFD8DC), Color(0xFFFFAB91)];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final medal = position <= 3 ? _medals[position - 1] : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: me ? Colors.amber.withAlpha(40) : theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: me ? Border.all(color: Colors.amber, width: 2) : null,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: medal ?? theme.cardColor,
            child: Text('$position',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: medal != null ? const Color(0xFF3E2723) : theme.hintColor)),
          ),
          const SizedBox(width: 8),
          PlayerAvatar(pokemonId: avatar, name: name),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (me) const TextSpan(text: '  você', style: TextStyle(fontSize: 12, color: Colors.amber)),
                  ]),
                  overflow: TextOverflow.ellipsis,
                ),
                if (detail != null) Text(detail!, style: TextStyle(fontSize: 11, color: theme.hintColor)),
              ],
            ),
          ),
          Text('$score', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.amber)),
        ],
      ),
    );
  }
}
