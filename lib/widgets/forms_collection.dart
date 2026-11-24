// lib/widgets/forms_collection.dart
//
// Living Dex das formas (igual ao site, FormsCollection.jsx): todas as formas
// alternativas separadas por tipo (regionais, Megas, Gigantamax e outras),
// para marcar as que você já tem (normal e shiny). Fica na Coleção da conta
// como o "jogo" especial 'forms'.

import 'package:flutter/material.dart' hide Text;

import '../i18n/i18n.dart';
import '../i18n/text.dart';
import '../services/local_database.dart';
import '../services/user_data.dart';
import '../utils/string_extensions.dart';
import 'pokemon_sprite.dart';

/// Chave da Coleção para as formas.
const formsKey = 'forms';

/// Categoria de uma forma pelo nome ("vulpix-alola" → Regionais).
String formCategory(String name) {
  if (RegExp(r'-(alola|galar|hisui|paldea)').hasMatch(name)) return 'Regionais';
  if (name.contains('-mega') || name.contains('-primal')) return 'Mega e Primal';
  if (name.endsWith('-gmax')) return 'Gigantamax';
  return 'Outras formas';
}

const formCategories = ['Regionais', 'Mega e Primal', 'Gigantamax', 'Outras formas'];

/// Nome da forma para mostrar: "vulpix-alola" → "Vulpix Alola".
String formLabel(String name) => name.split('-').map((w) => w.capitalise()).join(' ');

class FormsCollection extends StatefulWidget {
  final Widget header;
  const FormsCollection({super.key, required this.header});

  @override
  State<FormsCollection> createState() => _FormsCollectionState();
}

class _FormsCollectionState extends State<FormsCollection> {
  List<Map<String, dynamic>>? _forms;
  String _category = formCategories.first;
  bool _shinyMode = false;

  @override
  void initState() {
    super.initState();
    LocalDatabase.instance.allPokemonRows().then((rows) {
      // Formas que só mudam a cor/estado de batalha sem sprite próprio ficam de fora.
      final forms = [
        for (final r in rows)
          if ((r['id'] as int) >= 10000 && !(r['name'] as String).contains('-totem') && !(r['name'] as String).endsWith('-cap')) r,
      ];
      if (mounted) setState(() => _forms = forms);
    });
  }

  @override
  Widget build(BuildContext context) {
    final forms = _forms;
    if (forms == null) return const Center(child: CircularProgressIndicator());
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: UserData.instance,
      builder: (context, _) {
        final caught = UserData.instance.caught(formsKey);
        final shiny = UserData.instance.caught(formsKey, shiny: true);
        final shown = [
          for (final f in forms)
            if (formCategory(f['name'] as String) == _category) f
        ];
        final done = shown.where((f) => caught.contains(f['id'])).length;
        final all = forms.where((f) => caught.contains(f['id'])).length;
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              sliver: SliverList.list(children: [
                widget.header,
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final cat in formCategories)
                    ChoiceChip(
                      label: Text(cat),
                      selected: _category == cat,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _category = cat),
                    ),
                  FilterChip(
                    label: const Text('✨ Shiny'),
                    selected: _shinyMode,
                    selectedColor: Colors.amber,
                    onSelected: (v) => setState(() => _shinyMode = v),
                  ),
                ]),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFDB2777)]),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(_category, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))),
                      Text('$done/${shown.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: shown.isEmpty ? 0 : done / shown.length,
                        minHeight: 10,
                        color: Colors.white,
                        backgroundColor: Colors.black26,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(tr('{0} de {1} formas no total').replaceAll('{0}', '$all').replaceAll('{1}', '${forms.length}'),
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                ),
              ]),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 104,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.78,
                ),
                itemCount: shown.length,
                itemBuilder: (context, i) {
                  final f = shown[i];
                  final id = f['id'] as int;
                  final isCaught = caught.contains(id), isShiny = shiny.contains(id);
                  final on = _shinyMode ? isShiny : isCaught;
                  final name = f['name'] as String;
                  final base = I18n.pokemonName(name.split('-').first.capitalise());
                  final rest = formLabel(name.substring(name.indexOf('-') + 1));
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => UserData.instance.toggleCaught(formsKey, id, shiny: _shinyMode),
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: on ? Border.all(color: const Color(0xFF38BDF8), width: 2) : null,
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Stack(children: [
                        if (isShiny) const Align(alignment: Alignment.topRight, child: Text('✨', style: TextStyle(fontSize: 12))),
                        Column(children: [
                          Expanded(
                            child: Opacity(opacity: isCaught || isShiny ? 1 : 0.35, child: PokemonSprite(id, shiny: isShiny && _shinyMode)),
                          ),
                          Text(base, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          Text(rest, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, color: theme.hintColor)),
                        ]),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
