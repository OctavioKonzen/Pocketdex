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
import '../services/medals.dart';
import '../services/public_profile.dart';
import '../services/trainers.dart';
import '../utils/responsive.dart';
import '../utils/site_ui.dart';
import '../widgets/account_avatar.dart';
import '../widgets/medal_badge.dart';
import '../widgets/pokemon_sprite.dart';
import '../widgets/pokemon_theme_art.dart';
import '../widgets/trainer_sprite.dart';

class ProfileScreen extends StatefulWidget {
  final String uid;
  const ProfileScreen({super.key, required this.uid});

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

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Perfil')),
        body: ReadableWidth(
          child: FutureBuilder<Map<String, dynamic>?>(
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
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  PlayerAvatar(pokemonId: (p['avatar'] as num?)?.toInt(), name: '${p['name']}', size: 76),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('TREINADOR', style: TextStyle(color: c.muted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
                      m.Text('${p['name']}', style: TextStyle(color: c.text, fontSize: 26, fontWeight: FontWeight.w900)),
                      if (champion) const Text('👑 Campeão', style: TextStyle(color: AppSettings.championGold, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                  if (trainer != null) TrainerSprite(trainer, box: 90),
                ]),
                const SizedBox(height: 12),
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
            Text('${tr('Álbum de medalhas')} · ${medals.length}/${Medals.all.length}', style: TextStyle(color: c.text, fontWeight: FontWeight.bold, fontSize: 16)),
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
