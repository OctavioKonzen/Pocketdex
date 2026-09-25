// lib/screens/settings_screen.dart
//
// Configurações no estilo do site: conta, tema, dados salvos, conquistas,
// versão do app (com "Procurar atualização"), excluir conta e sobre.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../services/account_sync.dart';
import '../services/achievements.dart';
import '../services/auth_service.dart';
import '../services/league.dart';
import '../services/update_service.dart';
import '../services/user_data.dart';
import '../utils/responsive.dart';
import '../utils/site_ui.dart';
import '../widgets/account_avatar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Limpar dados'),
        content: const Text('Isso apaga seus favoritos, times e treinos. Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Limpar', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    UserData.instance.update({'favorites': [], 'teams': [], 'training': []});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Favoritos, times e treinos apagados.')));
  }

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final dark = context.watch<ThemeProvider>().themeMode == ThemeMode.dark;
    final auth = context.watch<AuthService>();
    final user = auth.status == AuthStatus.signedIn ? auth.user : null;

    Widget row({required String title, required String subtitle, Widget? trailing, Widget? leading}) => SiteCard(
          child: Row(
            children: [
              if (leading != null) ...[leading, const SizedBox(width: 14)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: c.text, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: c.muted, fontSize: 13)),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing],
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            const PageHeader(title: 'Configurações'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  if (user != null) ...[
                    row(
                      leading: AccountAvatar(size: 48, onTap: () => ProfileSheet.show(context)),
                      title: user.name ?? 'Conta',
                      subtitle: user.email ?? '',
                      trailing: PillButton(label: 'Sair', color: const Color(0xFFE53935), onPressed: AccountSync.instance.logout),
                    ),
                    const SizedBox(height: 12),
                  ],
                  row(
                    title: 'Modo Escuro',
                    subtitle: 'Ative para uma experiência com cores escuras.',
                    trailing: Switch(
                      value: dark,
                      activeTrackColor: const Color(0xFF0EA5E9),
                      onChanged: (v) => context.read<ThemeProvider>().toggleTheme(v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  row(
                    title: 'Dados salvos',
                    subtitle: user != null
                        ? 'Favoritos, times e treinos ficam salvos na sua conta (app e site).'
                        : 'Favoritos, times e treinos ficam salvos neste aparelho.',
                    trailing: PillButton(label: 'Limpar', color: const Color(0xFFE53935), onPressed: () => _confirmClear(context)),
                  ),
                  const SizedBox(height: 12),
                  const _AchievementsCard(),
                  if (UpdateService.supported) ...[
                    const SizedBox(height: 12),
                    FutureBuilder<String>(
                      future: UpdateService.currentVersion(),
                      builder: (context, snapshot) => row(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: const Color(0xFF3DDC84), borderRadius: BorderRadius.circular(14)),
                          child: const Icon(Icons.android, color: Color(0xFF073042)),
                        ),
                        title: 'PocketDex ${snapshot.data ?? ''}',
                        subtitle: 'As versões novas são avisadas ao abrir o app.',
                        trailing: PillButton(
                          label: 'Procurar',
                          color: const Color(0xFF3DDC84),
                          foreground: const Color(0xFF073042),
                          onPressed: () => UpdateService.checkNow(context),
                        ),
                      ),
                    ),
                  ],
                  if (user != null) ...[
                    const SizedBox(height: 12),
                    row(
                      title: 'Excluir conta',
                      subtitle: 'Apaga para sempre sua conta, seus dados e suas posições nos rankings.',
                      trailing: PillButton(
                        label: 'Excluir',
                        color: const Color(0xFFB71C1C),
                        onPressed: () => showDialog(context: context, builder: (_) => const _DeleteAccountDialog()),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text('PocketDex · app em Flutter e site em React, com a mesma conta.\n'
                      'Pokémon e os nomes dos personagens são marcas da Nintendo.',
                      textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Medalhas conquistadas no jogo, na Pokédex e nos times (as mesmas do site).
class _AchievementsCard extends StatelessWidget {
  const _AchievementsCard();

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    return ListenableBuilder(
      listenable: UserData.instance,
      builder: (context, _) {
        final data = UserData.instance;
        final list = Achievements.of(
          stats: data.stats,
          rankedRecord: data.rankedRecord,
          favorites: data.favorites,
          teams: data.teams,
        );
        final unlocked = list.where((a) => a.unlocked).length;
        return SiteCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Conquistas', style: TextStyle(color: c.text, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text('Jogue, monte times e favorite Pokémon para liberar medalhas.',
                            style: TextStyle(color: c.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(20)),
                    child: Text('$unlocked/${list.length}',
                        style: const TextStyle(color: Color(0xFF3E2723), fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final a in list)
                Opacity(
                  opacity: a.unlocked ? 1 : 0.45,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: a.unlocked ? Colors.amber.withAlpha(35) : Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(14),
                      border: a.unlocked ? Border.all(color: Colors.amber.withAlpha(150)) : null,
                    ),
                    child: Row(
                      children: [
                        Text(a.icon, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.title, style: TextStyle(color: c.text, fontWeight: FontWeight.bold)),
                              Text(a.text, style: TextStyle(color: c.muted, fontSize: 12)),
                            ],
                          ),
                        ),
                        if (a.unlocked) const Icon(Icons.check_circle, color: Colors.amber, size: 20),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Confirma e apaga a conta e todos os dados dela (senha ou conta Google).
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();
  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final stats = UserData.instance.stats;
    final weeks = {...List<dynamic>.from(stats['weeks'] as List? ?? []).map((w) => '$w'), League.weekKey()}.toList();
    final days = {...List<dynamic>.from(stats['days'] as List? ?? []).map((d) => '$d'), League.dayKey()}.toList();
    final sync = AccountSync.instance;
    sync.pause(); // não recria os dados enquanto apaga
    try {
      await AuthService.instance.deleteAccount(password: _password.text, weeks: weeks, days: days);
      UserData.instance.clearAll();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).popUntil((route) => route.isFirst);
      messenger.showSnackBar(const SnackBar(content: Text('Sua conta foi excluída.')));
    } catch (e) {
      sync.resume();
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final google = AuthService.instance.usesGoogle;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Excluir conta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Isso apaga para sempre sua conta, favoritos, times, treinos, recordes, conquistas e suas linhas '
              'nos rankings. No app e no site. Não dá para desfazer.'),
          const SizedBox(height: 12),
          if (google)
            Text('Para confirmar, escolha a sua conta Google na janela que vai abrir.',
                style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13))
          else
            TextField(
              controller: _password,
              obscureText: true,
              enabled: !_busy,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Digite sua senha para confirmar'),
            ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(
          onPressed: _busy || (!google && _password.text.isEmpty) ? null : _run,
          child: Text(_busy ? 'Excluindo...' : 'Excluir para sempre',
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
