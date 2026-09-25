// lib/screens/settings_screen.dart
//
// Configurações no estilo do site: conta, tema, dados salvos, versão do app
// (com "Procurar atualização") e sobre.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../services/account_sync.dart';
import '../services/auth_service.dart';
import '../services/update_service.dart';
import '../services/user_data.dart';
import '../utils/responsive.dart';
import '../utils/site_ui.dart';

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
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFFE53935),
                        child: Text((user.name ?? '?').substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                      ),
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
