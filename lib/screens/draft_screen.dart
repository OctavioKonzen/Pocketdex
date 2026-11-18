// lib/screens/draft_screen.dart
//
// Draft entre amigos (igual ao site, DraftPage.jsx): lista dos drafts, criar
// um novo com um amigo e a tela do draft (cada um escolhe um Pokémon na sua
// vez, sem repetir). No fim dá para batalhar e salvar o time.

import 'package:flutter/material.dart' hide Text;

import '../i18n/i18n.dart';
import '../i18n/text.dart';
import '../services/auth_service.dart';
import '../services/draft_service.dart';
import '../services/friends_service.dart';
import '../services/local_database.dart';
import '../services/team_service.dart';
import '../services/team_share.dart';
import '../utils/responsive.dart';
import '../utils/site_ui.dart';
import '../utils/string_extensions.dart';
import '../widgets/pokemon_sprite.dart';
import 'pokedex_screen.dart';
import 'turn_battle_screen.dart';

class DraftsScreen extends StatelessWidget {
  const DraftsScreen({super.key});

  Future<void> _new(BuildContext context) async {
    final friends = FriendsService.instance.friends;
    if (friends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Adicione amigos para fazer um draft.'))));
      return;
    }
    var size = 6;
    final chosen = await showModalBottomSheet<(String, String, int)>(
      context: context,
      builder: (sheet) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Novo draft', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(children: [
                const Text('Pokémon para cada um:'),
                const SizedBox(width: 8),
                for (final n in const [3, 6])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(label: Text('$n'), selected: size == n, onSelected: (_) => update(() => size = n)),
                  ),
              ]),
              const SizedBox(height: 8),
              for (final f in friends)
                ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(f.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(sheet, (f.uid, f.name, size)),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null || !context.mounted) return;
    final id = await DraftService.instance.create(chosen.$1, chosen.$2, size: chosen.$3);
    if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => DraftScreen(draftId: id)));
  }

  @override
  Widget build(BuildContext context) {
    final me = AuthService.instance.user?.uid;
    final c = SiteColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Draft')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-draft',
        onPressed: () => _new(context),
        icon: const Icon(Icons.add),
        label: const Text('Novo draft'),
      ),
      body: me == null
          ? const EmptyMessage('Entre na sua conta para fazer drafts com os amigos.')
          : StreamBuilder<List<Draft>>(
              stream: DraftService.instance.mine(),
              builder: (context, snap) {
                final list = snap.data;
                if (list == null) return const Center(child: CircularProgressIndicator());
                return ReadableWidth(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    children: [
                      Text('Você e um amigo escolhem Pokémon um de cada vez, sem repetir. Depois, batalhem com os times que saíram!',
                          style: TextStyle(color: c.muted, fontSize: 13)),
                      const SizedBox(height: 12),
                      if (list.isEmpty) const EmptyMessage('Nenhum draft ainda. Toque em "Novo draft".'),
                      for (final d in list)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DraftScreen(draftId: d.id))),
                            title: Text(tr('Com {0}').replaceAll('{0}', d.names[d.other(me)] ?? '?'),
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(d.done
                                ? tr('Acabou · pronto para batalhar')
                                : d.turn == me
                                    ? tr('Sua vez de escolher!')
                                    : tr('Vez do amigo')),
                            trailing: d.turn == me && !d.done
                                ? const Icon(Icons.circle, color: Colors.redAccent, size: 12)
                                : Row(mainAxisSize: MainAxisSize.min, children: [
                                    for (final id in d.of(me).take(6)) SizedBox.square(dimension: 26, child: PokemonSprite(id, fill: 0.95)),
                                  ]),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class DraftScreen extends StatefulWidget {
  final String draftId;
  const DraftScreen({super.key, required this.draftId});

  @override
  State<DraftScreen> createState() => _DraftScreenState();
}

class _DraftScreenState extends State<DraftScreen> {
  late final Stream<Draft?> _draft = DraftService.instance.watch(widget.draftId);
  bool _busy = false;
  Map<int, String> _names = {};

  @override
  void initState() {
    super.initState();
    LocalDatabase.instance.defaultPokemon().then((rows) {
      if (mounted) setState(() => _names = {for (final r in rows) r['id'] as int: r['name'] as String});
    });
  }

  String _name(int id) => I18n.pokemonName((_names[id] ?? '#$id').split('-').first.capitalise());

  Future<void> _pick(Draft d) async {
    final picked = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const PokedexScreen(isForTeamSelection: true)),
    );
    final id = int.tryParse('${picked?['id']}');
    if (id == null || !mounted) return;
    if (id > 1025) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('No draft vale só a forma normal de cada Pokémon.'))));
      return;
    }
    setState(() => _busy = true);
    final error = await DraftService.instance.pick(d.id, id).catchError((_) => tr('Não deu para escolher. Confira a internet.'));
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(error))));
  }

  /// Batalha por turnos com os times do draft (o computador joga pelo amigo).
  void _fight(Draft d, String me) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TurnBattleScreen(
            mine: [for (final id in d.of(me)) (id, null)],
            theirs: [for (final id in d.of(d.other(me))) (id, null)],
            foeName: d.names[d.other(me)] ?? '',
          ),
        ),
      );

  Future<void> _save(Draft d, String me) async {
    final ids = d.of(me);
    final name = tr('Draft com {0}').replaceAll('{0}', d.names[d.other(me)] ?? '');
    await TeamService().importTeam(SharedTeam(name, null, [for (var i = 0; i < 6; i++) i < ids.length ? ids[i] : null], List.filled(6, null)));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Time salvo nos seus times!'))));
  }

  Widget _side(String title, List<int> ids, int size, bool active) {
    final c = SiteColors.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: active ? Border.all(color: const Color(0xFF38BDF8), width: 2) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            for (var i = 0; i < size; i++)
              SizedBox(
                height: 44,
                child: i < ids.length
                    ? Row(children: [
                        SizedBox.square(dimension: 40, child: PokemonSprite(ids[i], fill: 0.95)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(_name(ids[i]), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                      ])
                    : Row(children: [
                        Icon(Icons.catching_pokemon, color: c.muted.withAlpha(90), size: 28),
                        const SizedBox(width: 6),
                        Text('—', style: TextStyle(color: c.muted)),
                      ]),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = AuthService.instance.user?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Draft')),
      body: StreamBuilder<Draft?>(
        stream: _draft,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final d = snap.data;
          if (d == null) return const EmptyMessage('Esse draft foi apagado.');
          final other = d.other(me);
          final myTurn = !d.done && d.turn == me;
          return ReadableWidth(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  d.done
                      ? tr('Draft completo! Hora de batalhar.')
                      : myTurn
                          ? tr('Sua vez de escolher!')
                          : tr('Vez de {0} escolher...').replaceAll('{0}', d.names[other] ?? ''),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _side(tr('Você'), d.of(me), d.size, myTurn),
                  const SizedBox(width: 10),
                  _side(d.names[other] ?? '?', d.of(other), d.size, !d.done && d.turn == other),
                ]),
                const SizedBox(height: 16),
                if (myTurn)
                  PillButton(
                    label: _busy ? '...' : tr('Escolher Pokémon'),
                    expand: true,
                    color: const Color(0xFF0284C7),
                    onPressed: _busy ? null : () => _pick(d),
                  ),
                if (d.done) ...[
                  PillButton(
                    label: '⚔️ ${tr('Batalhar!')}',
                    expand: true,
                    gradient: const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFF9333EA)]),
                    onPressed: () => _fight(d, me),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(onPressed: () => _save(d, me), icon: const Icon(Icons.save_alt), label: const Text('Salvar meu time')),
                ],
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () async {
                    await DraftService.instance.delete(d.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  label: const Text('Apagar draft', style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
