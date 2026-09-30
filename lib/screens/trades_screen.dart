// lib/screens/trades_screen.dart
//
// Trocas entre amigos (igual ao site, TradesPage.jsx): a pessoa marca os
// Pokémon que tem repetidos e vê, para cada amigo, o que pode dar (repetidos
// meus que ele não pegou) e o que pode receber (repetidos dele que me faltam).
// "Pegos" vem da Coleção de cada um.

import 'package:flutter/material.dart' hide Text;

import '../i18n/text.dart';
import '../services/friends_service.dart';
import '../services/trades_service.dart';
import '../services/user_data.dart';
import '../utils/responsive.dart';
import '../utils/site_ui.dart';
import '../widgets/account_avatar.dart';
import '../widgets/pokemon_sprite.dart';
import 'pokedex_screen.dart';
import 'pokemon_detail_screen.dart';

class TradesScreen extends StatefulWidget {
  const TradesScreen({super.key});

  @override
  State<TradesScreen> createState() => _TradesScreenState();
}

class _TradesScreenState extends State<TradesScreen> {
  final _service = TradesService.instance;
  late final Stream<TradeList> _mine = _service.mine();
  Map<String, TradeList>? _friends;

  @override
  void initState() {
    super.initState();
    _service.syncCaught().catchError((_) {});
    _load();
  }

  Future<void> _load() async {
    final uids = [for (final f in FriendsService.instance.friends) f.uid];
    final lists = await _service.ofFriends(uids);
    if (mounted) setState(() => _friends = lists);
  }

  Future<void> _add(List<int> dupes) async {
    final picked = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const PokedexScreen(isForTeamSelection: true)),
    );
    final id = int.tryParse('${picked?['id']}');
    if (id == null || dupes.contains(id)) return;
    await _service.setDupes([...dupes, id]..sort());
  }

  void _open(int id) => Navigator.push(context, MaterialPageRoute(builder: (_) => PokemonDetailScreen(initialPokemonId: id)));

  Widget _sprites(List<int> ids, {void Function(int)? onRemove}) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final id in ids)
            Stack(
              clipBehavior: Clip.none,
              children: [
                InkWell(
                  onTap: () => _open(id),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: Colors.white.withAlpha(18), borderRadius: BorderRadius.circular(12)),
                    child: PokemonSprite(id, fill: 0.9),
                  ),
                ),
                if (onRemove != null)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: GestureDetector(
                      onTap: () => onRemove(id),
                      child:
                          const CircleAvatar(radius: 10, backgroundColor: Colors.redAccent, child: Icon(Icons.close, size: 12, color: Colors.white)),
                    ),
                  ),
              ],
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final muted = TextStyle(color: c.muted, fontSize: 13);
    return Scaffold(
      appBar: AppBar(title: const Text('Trocas')),
      body: StreamBuilder<TradeList>(
        stream: _mine,
        builder: (context, snap) {
          final mine = snap.data ?? const TradeList([], {});
          final caught = UserData.instance.allCaught;
          return ReadableWidth(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SiteCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('Meus repetidos ({0})').replaceAll('{0}', '${mine.dupes.length}'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('Marque os Pokémon que você tem sobrando para trocar. O que você já pegou vem da sua Coleção.', style: muted),
                        const SizedBox(height: 12),
                        _sprites(mine.dupes, onRemove: (id) => _service.setDupes([...mine.dupes]..remove(id))),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => _add(mine.dupes),
                          icon: const Icon(Icons.add),
                          label: const Text('Adicionar repetido'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_friends == null)
                    const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                  else if (FriendsService.instance.friends.isEmpty)
                    const EmptyMessage('Adicione amigos para ver as trocas possíveis.')
                  else
                    for (final f in FriendsService.instance.friends) ...[
                      SiteCard(
                        child: Builder(builder: (context) {
                          final theirs = _friends![f.uid];
                          final give = [
                            for (final id in mine.dupes)
                              if (theirs != null && !theirs.caught.contains(id)) id
                          ];
                          final get = [
                            for (final id in theirs?.dupes ?? const <int>[])
                              if (!caught.contains(id)) id
                          ];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                PlayerAvatar(pokemonId: f.avatar, name: f.name, size: 36),
                                const SizedBox(width: 10),
                                Expanded(child: Text(f.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                              ]),
                              const SizedBox(height: 10),
                              if (theirs == null)
                                Text(tr('{0} ainda não abriu as Trocas.').replaceAll('{0}', f.name), style: muted)
                              else ...[
                                Text(tr('Você pode dar ({0})').replaceAll('{0}', '${give.length}'),
                                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4ADE80))),
                                const SizedBox(height: 6),
                                give.isEmpty ? Text('Nenhum dos seus repetidos falta para essa pessoa.', style: muted) : _sprites(give),
                                const SizedBox(height: 12),
                                Text(tr('Pode te dar ({0})').replaceAll('{0}', '${get.length}'),
                                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF38BDF8))),
                                const SizedBox(height: 6),
                                get.isEmpty ? Text('Nenhum repetido dessa pessoa falta para você.', style: muted) : _sprites(get),
                              ],
                            ],
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
