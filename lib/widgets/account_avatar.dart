// lib/widgets/account_avatar.dart
//
// Foto de perfil da conta: o Pokémon escolhido pela pessoa (o mesmo no app e
// no site), ou a foto do Google, ou a inicial do nome. Tocar abre o perfil,
// onde dá para trocar a foto e sair da conta.

import 'package:flutter/material.dart' hide Text;

import '../screens/pokedex_screen.dart';
import '../screens/friends_screen.dart';
import '../screens/settings_screen.dart';
import '../services/friends_service.dart';
import '../services/local_database.dart';
import '../services/account_format.dart';
import '../services/account_sync.dart';
import '../services/auth_service.dart';
import '../services/user_data.dart';
import '../utils/site_ui.dart';
import 'pokemon_sprite.dart';
import 'trainer_sprite.dart';
import '../services/trainers.dart';
import 'package:pocket_dex/i18n/text.dart';

class AccountAvatar extends StatelessWidget {
  final double size;
  final VoidCallback? onTap;
  const AccountAvatar({super.key, this.size = 44, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([UserData.instance, AuthService.instance, FriendsService.instance]),
      builder: (context, _) {
        final user = AuthService.instance.user;
        final avatar = UserData.instance.avatar;
        final Widget content;
        final trainer = Trainers.ofAvatar(avatar);
        if (trainer != null) {
          content = TrainerFace(trainer, size: size);
        } else if (avatar != null) {
          content = Padding(
              padding: EdgeInsets.all(size * 0.08), child: PokemonSprite(UserData.avatarId(avatar), shiny: UserData.avatarShiny(avatar), fill: 0.95));
        } else if (user?.photo != null) {
          content = Image.network(user!.photo!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _initial(user));
        } else {
          content = _initial(user);
        }
        final circle = Container(
          width: size,
          height: size,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFB71C1C)]),
            border: Border.all(color: Colors.white, width: size * 0.05),
            boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: content,
        );
        if (onTap == null) return circle;
        // Pedidos de amizade ou desafios esperando: bolinha vermelha.
        final pending = FriendsService.instance.pending > 0;
        return GestureDetector(
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              circle,
              if (pending)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: size * 0.3,
                    height: size * 0.3,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _initial(AccountUser? user) => Center(
        child: Text(
          (user?.name ?? '?').substring(0, 1).toUpperCase(),
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: size * 0.42),
        ),
      );
}

/// Foto de qualquer jogador (ex.: nas linhas do ranking): o Pokémon escolhido
/// ou a inicial do nome.
class PlayerAvatar extends StatelessWidget {
  final int? pokemonId;
  final String name;
  final double size;
  const PlayerAvatar({super.key, required this.pokemonId, required this.name, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFB71C1C)]),
        border: Border.all(color: Colors.white, width: size * 0.05),
      ),
      child: Trainers.ofAvatar(pokemonId) != null
          ? TrainerFace(Trainers.ofAvatar(pokemonId)!, size: size)
          : pokemonId != null
          ? Padding(
              padding: EdgeInsets.all(size * 0.08),
              child: PokemonSprite(UserData.avatarId(pokemonId!), shiny: UserData.avatarShiny(pokemonId!), fill: 0.95))
          : Center(
              child: Text(
                name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: size * 0.42),
              ),
            ),
    );
  }
}

/// Painel do perfil: foto, nome, e-mail, trocar foto, configurações e sair.
class ProfileSheet {
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheet) => const _ProfileContent(),
    );
  }

  /// Escolhe um Pokémon da Pokédex para ser a foto de perfil.
  static Future<void> changePhoto(BuildContext context) async {
    final picked = await Navigator.push<Map<String, String>?>(
      context,
      MaterialPageRoute(builder: (_) => const PokedexScreen(isForTeamSelection: true)),
    );
    if (picked == null) return;
    final id = AccountFormat.pokemonIdFromImage(picked['imageUrl']) ?? int.tryParse(picked['id'] ?? '');
    if (id == null || !context.mounted) return;
    // Forma (Mega, regional...) e shiny.
    final chosen = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _AvatarOptions(id),
    );
    if (chosen != null) UserData.instance.update({'avatar': chosen});
  }
}

/// Escolhe a forma (as da mesma espécie) e se é shiny, vendo como fica.
class _AvatarOptions extends StatefulWidget {
  final int id;
  const _AvatarOptions(this.id);

  @override
  State<_AvatarOptions> createState() => _AvatarOptionsState();
}

class _AvatarOptionsState extends State<_AvatarOptions> {
  late int _id = widget.id;
  bool _shiny = false;
  List<int> _forms = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = LocalDatabase.instance;
    final species = (await db.pokemonRow(widget.id))?['species'];
    final rows = await db.allPokemonRows();
    final forms = [
      for (final r in rows)
        if (r['species'] == species) (r['id'] as num).toInt(),
    ]..sort();
    if (mounted) setState(() => _forms = forms);
  }

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Escolha sua foto de perfil', style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            SizedBox.square(dimension: 120, child: PokemonSprite(_id, shiny: _shiny, fill: 0.95)),
            SwitchListTile(
              value: _shiny,
              onChanged: (v) => setState(() => _shiny = v),
              title: Text('✨ Shiny', style: TextStyle(color: c.text, fontWeight: FontWeight.w700)),
            ),
            if (_forms.length > 1) ...[
              Align(
                  alignment: Alignment.centerLeft, child: Text('Formas alternativas', style: TextStyle(color: c.muted, fontWeight: FontWeight.w700))),
              const SizedBox(height: 8),
              SizedBox(
                height: 76,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final f in _forms)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          key: ValueKey('form-$f'),
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => setState(() => _id = f),
                          child: Container(
                            width: 72,
                            decoration: BoxDecoration(
                              color: c.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: f == _id ? const Color(0xFFFBBF24) : Colors.transparent, width: 3),
                            ),
                            child: PokemonSprite(f, shiny: _shiny, fill: 0.85),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _shiny ? _id + UserData.shinyAvatar : _id),
                child: const Text('Salvar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent();

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([UserData.instance, AuthService.instance, FriendsService.instance]),
      builder: (context, _) {
        final user = AuthService.instance.user;
        final hasAvatar = UserData.instance.avatar != null;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 5, decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 20),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const AccountAvatar(size: 110),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Material(
                        color: const Color(0xFF2196F3),
                        shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 3)),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => ProfileSheet.changePhoto(context),
                          child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.edit, color: Colors.white, size: 20)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(user?.name ?? 'Sem conta', style: TextStyle(color: c.text, fontSize: 22, fontWeight: FontWeight.w900)),
                if (user?.email != null) Text(user!.email!, style: TextStyle(color: c.muted)),
                const SizedBox(height: 16),
                _MenuItem(icon: Icons.catching_pokemon, label: 'Trocar foto de perfil', onTap: () => ProfileSheet.changePhoto(context)),
                _MenuItem(icon: Icons.person_pin, label: 'Meu treinador', onTap: () => TrainerPicker.show(context)),
                if (hasAvatar)
                  _MenuItem(icon: Icons.hide_image_outlined, label: 'Tirar a foto', onTap: () => UserData.instance.update({'avatar': null})),
                _MenuItem(
                  icon: Icons.group,
                  label: 'Amigos',
                  badge: FriendsService.instance.pending,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendsScreen()));
                  },
                ),
                _MenuItem(
                  icon: Icons.emoji_events,
                  label: 'Conquistas',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsScreen()));
                  },
                ),
                _MenuItem(
                  icon: Icons.settings,
                  label: 'Configurações',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                  },
                ),
                Divider(color: c.line, height: 16),
                _MenuItem(
                  icon: Icons.logout,
                  label: 'Sair da conta',
                  danger: true,
                  onTap: () {
                    Navigator.pop(context);
                    AccountSync.instance.logout();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Uma linha do menu do avatar.
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  final int badge; // avisos (pedidos de amizade, desafios)
  const _MenuItem({required this.icon, required this.label, required this.onTap, this.danger = false, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final color = danger ? const Color(0xFFE53935) : c.text;
    return ListTile(
      leading: Icon(icon, color: danger ? color : c.muted),
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      trailing: badge > 0
          ? CircleAvatar(
              radius: 11,
              backgroundColor: Colors.redAccent,
              child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            )
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      onTap: onTap,
    );
  }
}
