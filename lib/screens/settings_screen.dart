// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../services/account_sync.dart';
import '../services/auth_service.dart';
import '../utils/responsive.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _genKey = 'selected_generation_index';

  Future<void> _clearCache(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_genKey);

    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Preferências de usuário limpas!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'PocketDex',
      applicationVersion: '1.0.0',
      applicationLegalese:
          '© 2025 PocketDex\nPokémon and Pokémon character names are trademarks of Nintendo.',
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Text('Desenvolvido com Flutter.'),
        )
      ],
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark;
    final theme = Theme.of(context);
    final auth = context.watch<AuthService>();
    final user = auth.status == AuthStatus.signedIn ? auth.user : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: ReadableWidth(
          child: ListView(
        padding: const EdgeInsets.all(8.0),
        children: [
          if (user != null) ...[
            ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                child: Text((user.name ?? '?').substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              title: Text(user.name ?? '', style: theme.textTheme.titleMedium),
              subtitle: Text('${user.email ?? ''}\nSeus dados ficam salvos na conta (app e site).',
                  style: theme.textTheme.bodySmall),
              isThreeLine: true,
              trailing: TextButton.icon(
                onPressed: () => AccountSync.instance.logout(),
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                label: const Text('Sair', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
            ),
            const Divider(),
          ],
          SwitchListTile(
            title: Text('Modo Escuro', style: theme.textTheme.titleMedium),
            subtitle: Text('Ative para uma experiência com cores escuras.',
                style: theme.textTheme.bodySmall),
            secondary: Icon(
                isDarkMode
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
                color: theme.colorScheme.secondary),
            activeTrackColor: theme.colorScheme.primary.withAlpha(150),
            activeThumbColor: theme.colorScheme.primary,
            value: isDarkMode,
            onChanged: (value) {
              context.read<ThemeProvider>().toggleTheme(value);
            },
          ),
          const Divider(),
          _buildOptionTile(
            icon: Icons.delete_sweep_outlined,
            color: Colors.lightBlueAccent,
            title: 'Limpar Preferências',
            subtitle: 'Remove dados salvos, como sua última geração vista.',
            onTap: () => _clearCache(context),
            theme: theme,
          ),
          const Divider(),
          _buildOptionTile(
            icon: Icons.info_outline,
            color: Colors.grey,
            title: 'Sobre o App',
            subtitle: 'Exibe informações sobre o PocketDex.',
            onTap: () => _showAboutDialog(context),
            theme: theme,
          ),
        ],
      )),
    );
  }
}
