// lib/screens/game_screen.dart
//
// Menu do "Quem é esse Pokémon?", igual ao do site adaptado ao celular:
// palco azul com raios, recordes (normal e Ranked), seletor de geração,
// botões de jogo normal e Ranked (5 s por Pokémon) e o ranking.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/generation.dart';
import '../services/account_sync.dart';
import '../services/auth_service.dart';
import '../services/user_data.dart';
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

  Future<void> _play({required bool ranked, bool resume = false}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(generation: ranked ? null : _generation, ranked: ranked, continueGame: resume),
      ),
    );
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
                label: '🏆 Jogar Ranked (${QuizScreen.rankedSeconds}s por Pokémon)',
                gradient: const LinearGradient(colors: [Color(0xFFF9A825), Color(0xFFE65100)]),
                onPressed: () => _play(ranked: true),
              ),
              const SizedBox(height: 20),
              const _Ranking(),
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
            TextSpan(children: [
              const TextSpan(text: '• '),
              const TextSpan(text: 'Ranked: ', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
              TextSpan(text: 'todas as gerações e só ${QuizScreen.rankedSeconds} segundos por Pokémon. É ele que conta para o ranking.'),
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
  final VoidCallback onPressed;
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
            child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}

/// Os 10 maiores recordes do Ranked (o mesmo ranking do site).
class _Ranking extends StatefulWidget {
  const _Ranking();
  @override
  State<_Ranking> createState() => _RankingState();
}

class _RankingState extends State<_Ranking> {
  final _sync = AccountSync.instance;
  List<Map<String, dynamic>>? _list;
  int? _position;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _sync.rankingVersion.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _sync.rankingVersion.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final record = UserData.instance.rankedRecord;
      final list = await _sync.topRanking();
      final position = record > 0 ? await _sync.rankingPosition(record) : null;
      if (mounted) {
        setState(() {
          _list = list;
          _position = position;
          _error = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _list = const [];
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = AuthService.instance.user;
    final inTop = _list?.any((r) => r['uid'] == me?.uid) ?? false;
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ranking', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  Text('Os maiores recordes no modo Ranked.', style: TextStyle(fontSize: 12, color: theme.hintColor)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_list == null)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (_error)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(child: Text('Não foi possível carregar o ranking agora.', style: TextStyle(color: theme.hintColor))),
            )
          else if (_list!.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(child: Text('Ninguém pontuou no Ranked ainda. Seja o primeiro!', style: TextStyle(color: theme.hintColor))),
            )
          else ...[
            for (final (i, r) in _list!.indexed)
              _RankingRow(position: i + 1, name: '${r['name']}', score: (r['score'] as num).toInt(), me: r['uid'] == me?.uid),
            if (!inTop && _position != null && me?.name != null) ...[
              Center(child: Text('⋯', style: TextStyle(color: theme.hintColor))),
              _RankingRow(position: _position!, name: me!.name!, score: UserData.instance.rankedRecord, me: true),
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
  final bool me;
  const _RankingRow({required this.position, required this.name, required this.score, required this.me});

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
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.bold)),
                if (me) const TextSpan(text: '  você', style: TextStyle(fontSize: 12, color: Colors.amber)),
              ]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text('$score', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.amber)),
        ],
      ),
    );
  }
}
