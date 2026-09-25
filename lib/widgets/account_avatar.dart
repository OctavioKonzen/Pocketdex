// lib/widgets/account_avatar.dart
//
// Foto de perfil da conta: o Pokémon escolhido pela pessoa (o mesmo no app e
// no site), ou a foto do Google, ou a inicial do nome. Tocar abre o perfil,
// onde dá para trocar a foto e sair da conta.

import 'package:flutter/material.dart';

import '../screens/pokedex_screen.dart';
import '../screens/settings_screen.dart';
import '../services/account_format.dart';
import '../services/account_sync.dart';
import '../services/auth_service.dart';
import '../services/user_data.dart';
import '../utils/site_ui.dart';
import 'pokemon_sprite.dart';

class AccountAvatar extends StatelessWidget {
  final double size;
  final VoidCallback? onTap;
  const AccountAvatar({super.key, this.size = 44, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([UserData.instance, AuthService.instance]),
      builder: (context, _) {
        final user = AuthService.instance.user;
        final avatar = UserData.instance.avatar;
        final Widget content;
        if (avatar != null) {
          content = Padding(padding: EdgeInsets.all(size * 0.08), child: PokemonSprite(avatar, fill: 0.95));
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
        return onTap == null ? circle : GestureDetector(onTap: onTap, child: circle);
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
    if (id != null) UserData.instance.update({'avatar': id});
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent();

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([UserData.instance, AuthService.instance]),
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
                const SizedBox(height: 20),
                PillButton(
                  label: 'Trocar foto de perfil',
                  icon: Icons.catching_pokemon,
                  expand: true,
                  onPressed: () => ProfileSheet.changePhoto(context),
                ),
                if (hasAvatar) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => UserData.instance.update({'avatar': null}),
                    child: Text('Tirar a foto', style: TextStyle(color: c.muted)),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: PillButton(
                        label: 'Configurações',
                        icon: Icons.settings,
                        color: c.card,
                        foreground: c.text,
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PillButton(
                        label: 'Sair',
                        icon: Icons.logout,
                        color: const Color(0xFFE53935),
                        onPressed: () {
                          Navigator.pop(context);
                          AccountSync.instance.logout();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
