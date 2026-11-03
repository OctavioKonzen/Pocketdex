// lib/screens/profile_screen.dart
//
// Perfil público (profiles/{uid}, services/public_profile.dart): a foto, o
// treinador, o tema (o desenho do Pokémon no cartão), os recordes, as medalhas
// e o Hall da Fama, com o link para compartilhar. Igual ao site
// (web-site/src/pages/ProfilePage.jsx).

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;
import 'package:share_plus/share_plus.dart';

import '../i18n/text.dart';
import '../services/account_sync.dart';
import '../services/app_settings.dart';
import '../services/friends_service.dart';
import '../services/medals.dart';
import '../services/public_profile.dart';
import '../services/trainers.dart';
import '../services/auth_service.dart';
import '../services/user_data.dart';
import '../utils/responsive.dart';
import '../utils/site_ui.dart';
import '../widgets/account_avatar.dart';
import '../widgets/medal_badge.dart';
import 'settings_screen.dart' show AchievementsScreen;
import '../widgets/pokemon_sprite.dart';
import '../widgets/pokemon_theme_art.dart';
import '../widgets/trainer_sprite.dart';
import 'turn_battle_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String uid;

  /// O seu perfil (com os botões de trocar a foto e o treinador). Sem dizer, compara com a conta conectada.
  final bool? mine;
  const ProfileScreen({super.key, required this.uid, this.mine});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final Future<Map<String, dynamic>?> _profile = AccountSync.instance.profile(widget.uid).catchError((_) => null);

  @override
  void initState() {
    super.initState();
    Trainers.load().then((_) => mounted ? setState(() {}) : null).catchError((_) {});
  }

  bool get _mine => widget.mine ?? AccountSync.instance.uid == widget.uid;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Perfil')),
        body: ReadableWidth(
          // O seu: na hora, com os dados do aparelho (e o que você trocar aparece já).
          child: _mine
              ? ListenableBuilder(
                  listenable: Listenable.merge([UserData.instance, AppSettings.instance, AuthService.instance]),
                  builder: (context, _) => _body(context, {...PublicProfile.of(UserData.instance), 'name': AuthService.instance.user?.name ?? ''}),
                )
              : FutureBuilder<Map<String, dynamic>?>(
            future: _profile,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              final p = snap.data;
              if (p == null) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Esse perfil não existe (ou a conta ainda não abriu o PocketDex depois da atualização).', textAlign: TextAlign.center),
                  ),
                );
              }
              return _body(context, p);
            },
          ),
        ),
      );

  // O time de defesa de outra pessoa (o seu vem do aparelho).
  late final Future<Map<String, dynamic>?> _defense = _mine ? Future.value(null) : AccountSync.instance.defense(widget.uid).catchError((_) => null);

  /// O treinador grande no cartão, da cintura para cima: o desenho de todos com
  /// a mesma altura (crianças e adultos), a cabeça perto do alto e à direita.
  Widget _bust(Trainer t) => Positioned(right: 0, top: 0, bottom: 0, width: 165, child: TrainerBust(t));

  /// O time de defesa (duelo assíncrono): só aqui no perfil. No seu, dá para
  /// escolher qual e ver os duelos; no de um amigo, o botão de atacar. Igual ao site.
  Widget _defenseCard(BuildContext context, Color color) {
    final c = SiteColors.of(context);
    final friend = FriendsService.instance.friends.any((f) => f.uid == widget.uid);
    Widget card(String? name, List<int?> pokemon) => SiteCard(
          key: const ValueKey('profile-defense'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('🛡️ ${tr('Time de defesa')}', style: TextStyle(color: c.text, fontWeight: FontWeight.bold, fontSize: 16))),
              if (_mine)
                TextButton(
                  key: const ValueKey('defense-change'),
                  onPressed: () => _pickDefense(context),
                  style: TextButton.styleFrom(backgroundColor: color.withAlpha(0x26), foregroundColor: color, shape: const StadiumBorder()),
                  child: Text(name == null ? 'Escolher' : 'Trocar', style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              if (!_mine && friend && name != null)
                TextButton(
                  key: const ValueKey('defense-attack'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TurnBattleScreen(duel: widget.uid))),
                  style: TextButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white, shape: const StadiumBorder()),
                  child: Text('⚔️ ${tr('Atacar')}', style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
            ]),
            const SizedBox(height: 4),
            if (name == null)
              Text(
                  _mine
                      ? 'Escolha um dos seus times: os amigos batalham contra ele quando quiserem, com o computador jogando por você.'
                      : 'Ainda sem time de defesa.',
                  style: TextStyle(color: c.muted, fontSize: 12))
            else ...[
              m.Text(name, style: TextStyle(color: c.muted, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(children: [
                for (var i = 0; i < 6; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
                          child: i < pokemon.length && pokemon[i] != null ? PokemonSprite(pokemon[i]!, fill: 0.85) : null,
                        ),
                      ),
                    ),
                  ),
              ]),
            ],
            if (_mine && AccountSync.instance.uid != null) _duels(c, AccountSync.instance.uid!),
          ]),
        );
    List<int?> ids(Object? list) => [for (final x in (list as List?) ?? const []) (x as num?)?.toInt()];
    if (_mine) {
      final team = UserData.instance.teams.where((t) => t['id'] == UserData.instance['defenseTeam']).firstOrNull;
      return card(team == null ? null : '${team['name'] ?? ''}', ids(team?['pokemon']));
    }
    return FutureBuilder<Map<String, dynamic>?>(
      future: _defense,
      builder: (context, snap) => card(snap.data == null ? null : '${snap.data!['teamName'] ?? ''}', ids(snap.data?['pokemon'])),
    );
  }

  /// Os últimos duelos dos amigos contra a sua defesa (o computador joga por você).
  Widget _duels(SiteColors c, String uid) => StreamBuilder<List<Map<String, dynamic>>>(
        key: const ValueKey('defense-duels'),
        stream: AccountSync.instance.watchDuels(uid),
        builder: (context, snap) {
          final duels = snap.data ?? const [];
          if (duels.isEmpty) return const SizedBox.shrink();
          final wins = duels.where((d) => d['won'] != true).length;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 10),
            Text(tr('Sua defesa venceu {0} de {1}.').replaceAll('{0}', '$wins').replaceAll('{1}', '${duels.length}'), style: TextStyle(color: c.muted, fontSize: 12)),
            for (final d in duels)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  PlayerAvatar(pokemonId: (d['avatar'] as num?)?.toInt(), name: '${d['name'] ?? ''}', size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: m.Text('${d['name'] ?? ''} ${tr(d['won'] == true ? 'venceu a sua defesa' : 'perdeu para a sua defesa')}',
                        overflow: TextOverflow.ellipsis, style: TextStyle(color: c.text, fontSize: 13)),
                  ),
                  m.Text(d['won'] == true ? '❌' : '✅'),
                  const SizedBox(width: 6),
                  m.Text(tr('{0} turnos').replaceAll('{0}', '${d['turns'] ?? ''}'), style: TextStyle(color: c.muted, fontSize: 11)),
                  // Revidar: ataca a defesa de quem te atacou (só amigos podem ser escolhidos na batalha).
                  if (d['from'] is String && FriendsService.instance.friends.any((f) => f.uid == d['from']))
                    IconButton(
                      key: ValueKey('duel-revenge-${d['id']}'),
                      tooltip: tr('Revidar'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TurnBattleScreen(duel: d['from'] as String))),
                      icon: const m.Text('⚔️', style: TextStyle(fontSize: 16)),
                    ),
                ]),
              ),
          ]);
        },
      );

  /// Escolhe o time de defesa entre os seus (ou nenhum).
  Future<void> _pickDefense(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (sheet) {
          final c = SiteColors.of(sheet);
          final teams = [for (final t in UserData.instance.teams) if (((t['pokemon'] as List?) ?? const []).any((x) => x != null)) t];
          final current = UserData.instance['defenseTeam'];
          void pick(Object? id) {
            UserData.instance.update({'defenseTeam': id});
            Navigator.pop(sheet);
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 14),
                Text('🛡️ ${tr('Time de defesa')}', textAlign: TextAlign.center, style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('Os amigos batalham contra ele quando quiserem, com o computador jogando por você.',
                    textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 13)),
                const SizedBox(height: 12),
                if (teams.isEmpty) Text('Monte um time em Times primeiro.', textAlign: TextAlign.center, style: TextStyle(color: c.muted)),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.5),
                  child: ListView(shrinkWrap: true, children: [
                    for (final t in teams)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: t['id'] == current ? const Color(0x2638BDF8) : c.surface,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: t['id'] == current ? const Color(0xFF38BDF8) : Colors.transparent, width: 2)),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            key: ValueKey('defense-team-${t['id']}'),
                            onTap: () => pick(t['id']),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Row(children: [
                                Expanded(
                                    child: m.Text('${t['name'] ?? ''}',
                                        overflow: TextOverflow.ellipsis, style: TextStyle(color: c.text, fontWeight: FontWeight.w800))),
                                for (final id in [for (final x in (t['pokemon'] as List?) ?? const []) if (x != null) (x as num).toInt()])
                                  SizedBox.square(dimension: 30, child: PokemonSprite(id, fill: 0.95)),
                              ]),
                            ),
                          ),
                        ),
                      ),
                  ]),
                ),
                if (current != null) TextButton(onPressed: () => pick(null), child: const Text('Sem time de defesa')),
              ]),
            ),
          );
        },
      );

  Future<void> _edit(BuildContext context) => editProfilePhoto(context);

  Future<void> _changePhoto(BuildContext context) => _edit(context);

  Widget _body(BuildContext context, Map<String, dynamic> p) {
    final c = SiteColors.of(context);
    int n(String k) => (p[k] as num?)?.toInt() ?? 0;
    final theme = n('theme');
    final shiny = p['shiny'] == true;
    final champion = p['champion'] == true;
    final color = theme == 0 ? const Color(0xFFEF3B36) : AppSettings.themeColorOf(theme, shiny: shiny) ?? const Color(0xFFEF3B36);
    final trainer = Trainers.byId(p['trainer'] as String?);
    final medals = ((p['medals'] as List?) ?? const []).map((e) => '$e').toSet();
    final records = [
      ('🏆', 'Ranked', n('ranked')),
      ('🎲', 'Pokelike: andar', n('factory')),
      ('🗼', 'Torre: vitórias seguidas', n('tower')),
      ('🏅', 'Insígnias', n('badges')),
      ('📘', 'Pokémon pegos', n('caught')),
    ];
    return ListView(
      key: const ValueKey('public-profile'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withAlpha(0x66)),
            gradient: LinearGradient(colors: [color.withAlpha(0x26), c.card], begin: Alignment.topLeft, end: const Alignment(0.3, 1)),
          ),
          child: Stack(children: [
            if (theme != 0)
              Positioned(
                right: -24,
                bottom: -24,
                width: 200,
                height: 200,
                child: Opacity(
                  opacity: 0.4,
                  child: PokemonThemeArt(theme,
                      fill: color, line: champion ? AppSettings.championGold : Color.lerp(color, Colors.black, 0.85)!, shiny: shiny),
                ),
              ),
            // O treinador grande, de pé no canto do cartão.
            // Só da cintura para cima: o resto fica para fora do cartão (cortado).
            if (trainer != null) _bust(trainer),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  _mine
                      ? GestureDetector(
                          key: const ValueKey('profile-photo'),
                          onTap: () => _changePhoto(context),
                          child: Stack(clipBehavior: Clip.none, children: [
                            PlayerAvatar(pokemonId: (p['avatar'] as num?)?.toInt(), name: '${p['name']}', size: 76),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: c.card, width: 2)),
                                child: const Icon(Icons.edit, size: 14, color: Colors.white),
                              ),
                            ),
                          ]),
                        )
                      : PlayerAvatar(pokemonId: (p['avatar'] as num?)?.toInt(), name: '${p['name']}', size: 76),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('TREINADOR', style: TextStyle(color: c.muted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
                      m.Text('${p['name']}', style: TextStyle(color: c.text, fontSize: 26, fontWeight: FontWeight.w900)),
                      if (champion) const Text('👑 Campeão', style: TextStyle(color: AppSettings.championGold, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                  // Espaço para o treinador grande, à direita do cartão.
                  if (trainer != null) const SizedBox(width: 120),
                ]),
                // Altura para o treinador caber de pé.
                SizedBox(height: trainer != null ? 40 : 12),
                PillButton(
                  key: const ValueKey('profile-share'),
                  label: '🔗 ${tr('Compartilhar perfil')}',
                  color: color,
                  onPressed: () => SharePlus.instance.share(ShareParams(uri: Uri.parse(PublicProfile.link(widget.uid)), subject: 'PocketDex · ${p['name']}')),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        _defenseCard(context, color),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, box) {
          final columns = box.maxWidth >= 520 ? 5 : 3;
          final width = (box.maxWidth - 10 * (columns - 1)) / columns;
          return Wrap(spacing: 10, runSpacing: 10, children: [
            for (final (icon, label, value) in records)
              Container(
                width: width,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.line)),
                child: Column(children: [
                  Text(icon, style: const TextStyle(fontSize: 20)),
                  Text('$value', style: TextStyle(color: c.text, fontSize: 22, fontWeight: FontWeight.w900)),
                  Text(label, textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 11)),
                ]),
              ),
          ]);
        }),
        const SizedBox(height: 14),
        SiteCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                  child: Text('${tr('Álbum de medalhas')} · ${medals.length}/${Medals.all.length}',
                      style: TextStyle(color: c.text, fontWeight: FontWeight.bold, fontSize: 16))),
              // As conquistas (saíram do menu da conta): daqui do seu perfil.
              if (_mine)
                TextButton(
                  key: const ValueKey('profile-achievements'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsScreen())),
                  child: Text('🏆 ${tr('Conquistas')}'),
                ),
            ]),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, box) {
              final columns = box.maxWidth >= 520 ? 6 : 3;
              final width = (box.maxWidth - 10 * (columns - 1)) / columns;
              return Wrap(spacing: 10, runSpacing: 14, children: [
                for (final m in Medals.all) SizedBox(width: width, child: MedalBadge(medal: m, unlocked: medals.contains(m.id))),
              ]);
            }),
          ]),
        ),
        if (((p['hall'] as List?) ?? const []).isNotEmpty) ...[
          const SizedBox(height: 14),
          SiteCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('🏆 ${tr('Hall da Fama')}', style: TextStyle(color: c.text, fontWeight: FontWeight.bold, fontSize: 16)),
              for (final h in p['hall'] as List)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    SizedBox(width: 80, child: m.Text('${(h as Map)['region']}', style: TextStyle(color: c.text, fontWeight: FontWeight.bold, fontSize: 13))),
                    Expanded(
                      child: Wrap(children: [
                        for (final id in (h['team'] as List? ?? const [])) SizedBox.square(dimension: 36, child: PokemonSprite((id as num).toInt(), fill: 0.95)),
                      ]),
                    ),
                  ]),
                ),
            ]),
          ),
        ],
      ],
    );
  }
}

/// Escolher de onde vem a foto de perfil: um Pokémon ou um treinador.
class _PhotoSheet extends StatelessWidget {
  final VoidCallback onPokemon, onTrainer, onBattleTrainer;
  const _PhotoSheet({required this.onPokemon, required this.onTrainer, required this.onBattleTrainer});

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final hasAvatar = UserData.instance.avatar != null;
    final sample = Trainers.byId(UserData.instance.trainer) ?? Trainers.list.firstOrNull;
    Widget option(Key key, String title, String text, Widget art, Color color, VoidCallback onTap) => Expanded(
          child: Material(
            color: color.withAlpha(0x1F),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: color.withAlpha(0x88), width: 1.5)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: key,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
                child: Column(children: [
                  SizedBox(height: 84, child: art),
                  const SizedBox(height: 8),
                  Text(title, style: TextStyle(color: c.text, fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(text, textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 12)),
                ]),
              ),
            ),
          ),
        );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 5, decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 16),
          Text('Editar perfil', style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          Align(alignment: Alignment.centerLeft, child: Text('Foto de perfil', style: TextStyle(color: c.text, fontSize: 15, fontWeight: FontWeight.w800))),
          Align(alignment: Alignment.centerLeft, child: Text('Aparece no ranking, no chat e no seu perfil.', style: TextStyle(color: c.muted, fontSize: 12))),
          const SizedBox(height: 16),
          Row(children: [
            option(const ValueKey('photo-pokemon'), 'Pokémon', 'Qualquer um da Pokédex, com formas e shiny',
                const AspectRatio(aspectRatio: 1, child: PokemonSprite(25, fill: 0.95)), const Color(0xFFF59E0B), onPokemon),
            const SizedBox(width: 12),
            option(const ValueKey('photo-trainer'), 'Treinador', 'Um dos treinadores dos jogos',
                sample == null ? const Icon(Icons.person, size: 60) : _face(sample, 84, c), const Color(0xFF38BDF8), onTrainer),
          ]),
          const SizedBox(height: 18),
          Align(alignment: Alignment.centerLeft, child: Text('Treinador', style: TextStyle(color: c.text, fontSize: 15, fontWeight: FontWeight.w800))),
          const SizedBox(height: 8),
          Material(
            color: c.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const ValueKey('edit-trainer'),
              onTap: onBattleTrainer,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(children: [
                  if (sample != null) _face(sample, 48, c),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      m.Text(sample?.name ?? '', style: TextStyle(color: c.text, fontWeight: FontWeight.w800, fontSize: 15)),
                      Text('Quem lança a Poké Ball na batalha', style: TextStyle(color: c.muted, fontSize: 12)),
                    ]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0x2638BDF8), borderRadius: BorderRadius.circular(99)),
                    child: const Text('Trocar', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                ]),
              ),
            ),
          ),
          if (hasAvatar) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () {
                UserData.instance.update({'avatar': null});
                Navigator.pop(context);
              },
              icon: const Icon(Icons.hide_image_outlined),
              label: const Text('Tirar a foto'),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Só o rosto do treinador, num círculo (como a foto de perfil).
Widget _face(Trainer trainer, double size, SiteColors c) => Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(shape: BoxShape.circle, color: c.surface, border: Border.all(color: c.line, width: 2)),
      child: TrainerFace(trainer, size: size),
    );

/// Editar o perfil (também pelo lápis do menu da conta): a foto (um Pokémon, com formas e shiny, ou um treinador) e o treinador da batalha.
Future<void> editProfilePhoto(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheet) => _PhotoSheet(onPokemon: () {
        Navigator.pop(sheet);
        ProfileSheet.changePhoto(context);
      }, onTrainer: () {
        Navigator.pop(sheet);
        TrainerPicker.show(context, photoOnly: true);
      }, onBattleTrainer: () {
        Navigator.pop(sheet);
        TrainerPicker.show(context);
      }),
    );
