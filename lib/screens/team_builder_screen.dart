// lib/screens/team_builder_screen.dart

import 'package:flutter/material.dart';

import '../models/team.dart';
import '../services/account_format.dart';
import '../services/account_sync.dart';
import '../services/auth_service.dart';
import '../services/local_database.dart';
import '../services/team_service.dart';
import '../utils/profanity.dart';
import '../utils/team_analysis.dart';
import '../widgets/pikachu_loading_indicator.dart';
import '../widgets/team_analysis_view.dart';
import '../widgets/team_pokemon_card.dart';
import '../widgets/team_share_dialogs.dart';
import 'pokedex_screen.dart';
import '../utils/responsive.dart';
import '../utils/site_ui.dart';

class TeamBuilderScreen extends StatefulWidget {
  final Team team;

  const TeamBuilderScreen({super.key, required this.team});

  @override
  State<TeamBuilderScreen> createState() => _TeamBuilderScreenState();
}

class _TeamBuilderScreenState extends State<TeamBuilderScreen>
    with SingleTickerProviderStateMixin {
  final TeamService _teamService = TeamService();
  late TextEditingController _nameController;
  late Team _editableTeam;

  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 25),
  )..repeat();

  TeamAnalysis? _teamAnalysis;
  bool _isAnalysisLoading = false;
  Color? _selectedColor;
  (double?, int)? _communityRating; // nota da comunidade (se o time é público)


  @override
  void initState() {
    super.initState();
    _editableTeam = Team.fromMap(widget.team.toMap());
    _nameController = TextEditingController(text: _editableTeam.name);

    if (_editableTeam.color != null) {
      _selectedColor = Color(int.parse(_editableTeam.color!, radix: 16));
    }

    _updateTeamAnalysis();
    _loadRating();
  }

  Future<void> _loadRating() async {
    if (AuthService.instance.status != AuthStatus.signedIn) return;
    try {
      final ratings = await AccountSync.instance.myTeamRatings();
      if (mounted) setState(() => _communityRating = ratings[_editableTeam.id]);
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// Salva na hora (como no site): cada mudança já vai para a conta.
  Future<void> _persist() async {
    final name = _nameController.text.trim();
    _editableTeam.name = name.isEmpty ? _editableTeam.name : name;
    _editableTeam.color = _selectedColor?.toARGB32().toRadixString(16);
    await _teamService.updateTeam(_editableTeam);
  }

  Future<void> _saveTeam() async {
    await _persist();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _selectPokemon(int slotIndex) async {
    final navigator = Navigator.of(context);

    final result = await navigator.push<Map<String, String>?>(
      MaterialPageRoute(
        builder: (context) => const PokedexScreen(isForTeamSelection: true),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        while (_editableTeam.pokemons.length <= slotIndex) {
          _editableTeam.pokemons.add({});
        }
        _editableTeam.pokemons[slotIndex] = result;
      });
      await _updateTeamAnalysis();
      _persist();
    }
  }

  void _handleSlotTap(int slotIndex) {
    final existingPokemon = pokemonDataForSlot(slotIndex);
    if (existingPokemon != null) {
      _confirmRemovePokemon(slotIndex);
    } else {
      _selectPokemon(slotIndex);
    }
  }

  Map<String, String>? pokemonDataForSlot(int index) {
    if (_editableTeam.pokemons.length > index &&
        _editableTeam.pokemons[index].isNotEmpty) {
      return _editableTeam.pokemons[index];
    }
    return null;
  }

  void _confirmRemovePokemon(int slotIndex) {
    final theme = Theme.of(context);
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (dialogContext) => Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20.0),
                  topRight: Radius.circular(20.0),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Remover Pokémon?',
                      style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text('Deseja remover este Pokémon do time?',
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text('Cancelar',
                              style: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withAlpha(178),
                                  fontSize: 16))),
                      const SizedBox(width: 12),
                      ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))),
                          onPressed: () {
                            setState(() {
                              _editableTeam.pokemons[slotIndex] = {};
                            });
                            Navigator.pop(dialogContext);
                            _updateTeamAnalysis().then((_) => _persist());
                          },
                          child: const Text('Remover',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold))),
                    ],
                  )
                ],
              ),
            ));
  }

  /// Análise igual à do site: conta, para cada tipo, quem é fraco, resiste ou é imune.
  Future<void> _updateTeamAnalysis() async {
    if (!mounted) return;
    setState(() => _isAnalysisLoading = true);
    final db = LocalDatabase.instance;
    final membersTypes = <List<String>>[];
    for (final p in _editableTeam.pokemons.where((p) => p.isNotEmpty)) {
      final id = AccountFormat.pokemonIdFromImage(p['imageUrl']) ?? int.tryParse(p['id'] ?? '');
      if (id == null) continue;
      final row = await db.pokemonRow(id);
      if (row != null) membersTypes.add((row['types'] as List).cast<String>());
    }
    final chart = await db.typeChart();
    if (!mounted) return;
    setState(() {
      _teamAnalysis = TeamAnalysis.of(membersTypes, chart);
      _isAnalysisLoading = false;
    });
  }

  static const _teamColors = [
    Color(0xFFFF5252), Color(0xFFFFA726), Color(0xFFFFCA28), Color(0xFF66BB6A), Color(0xFF26A69A), Color(0xFF42A5F5),
    Color(0xFF5C6BC0), Color(0xFFAB47BC), Color(0xFFEC407A), Color(0xFF8D6E63), Color(0xFF78909C),
  ];

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final accent = _selectedColor ?? SectionColors.teams;
    final hasPokemon = _editableTeam.pokemons.any((p) => p.isNotEmpty);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _persist();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Editar time'),
          actions: [
            IconButton(
              tooltip: 'Compartilhar',
              icon: const Icon(Icons.share),
              onPressed: hasPokemon
                  ? () async {
                      await _persist();
                      if (context.mounted) await TeamShareDialogs.share(context, _editableTeam.id);
                    }
                  : null,
            ),
            TextButton.icon(
              onPressed: _saveTeam,
              icon: const Icon(Icons.check),
              label: const Text('Concluir'),
            ),
          ],
        ),
        body: ReadableWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              SiteCard(
                accentLeft: accent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nome do time', style: TextStyle(color: c.muted, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      onChanged: (_) {
                        setState(() {}); // atualiza o aviso de nome não permitido
                        _persist();
                      },
                      style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: c.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    if (AuthService.instance.status == AuthStatus.signedIn && isOffensive(_nameController.text))
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text('Esse nome não é permitido: o time não aparece na comunidade até você trocar.',
                            style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    const SizedBox(height: 14),
                    Text('Cor do time', style: TextStyle(color: c.muted, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final color in _teamColors)
                          GestureDetector(
                            onTap: () {
                              setState(() => _selectedColor = color);
                              _persist();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: color.toARGB32() == accent.toARGB32() ? c.text : Colors.transparent, width: 3),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text('Pokémon', style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.bold)),
              Text('Toque num espaço vazio para adicionar; num Pokémon para tirar.',
                  style: TextStyle(color: c.muted, fontSize: 13)),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.85,
                ),
                itemCount: 6,
                itemBuilder: (context, index) =>
                    TeamPokemonCard(pokemonData: pokemonDataForSlot(index), onTap: () => _handleSlotTap(index)),
              ),
              const SizedBox(height: 18),
              SiteCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('Análise do time',
                              style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        if (AuthService.instance.status == AuthStatus.signedIn)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Nota da comunidade', style: TextStyle(color: c.muted, fontSize: 12)),
                              RatingText(rating: _communityRating?.$1, count: _communityRating?.$2 ?? 0),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_isAnalysisLoading)
                      const Center(child: PikachuLoadingIndicator())
                    else
                      TeamAnalysisView(analysis: hasPokemon ? _teamAnalysis : null),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
