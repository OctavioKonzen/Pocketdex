// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _recordKey = 'quiz_highscore';
  static const String _genKey = 'selected_generation_index';

  Future<void> _resetHighScore(BuildContext context) async {
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmar Ação'),
        content: const Text('Tem certeza que deseja zerar o seu recorde no quiz?'),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => navigator.pop(false),
          ),
          TextButton(
            child: const Text('Zerar', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onPressed: () => navigator.pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_recordKey, 0);
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Recorde do quiz zerado com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

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
      applicationLegalese: '© 2025 PocketDex\nPokémon and Pokémon character names are trademarks of Nintendo.',
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(8.0),
        children: [
          SwitchListTile(
            title: Text('Modo Escuro', style: theme.textTheme.titleMedium),
            subtitle: Text('Ative para uma experiência com cores escuras.', style: theme.textTheme.bodySmall),
            secondary: Icon(isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined, color: theme.colorScheme.secondary),
            activeTrackColor: theme.colorScheme.primary.withAlpha(150),
            activeThumbColor: theme.colorScheme.primary, 
            value: isDarkMode,
            onChanged: (value) {
              context.read<ThemeProvider>().toggleTheme(value);
            },
          ),
          const Divider(),
          _buildOptionTile(
            icon: Icons.leaderboard_outlined,
            color: Colors.amber,
            title: 'Zerar Recorde do Quiz',
            subtitle: 'Redefine sua pontuação máxima para zero.',
            onTap: () => _resetHighScore(context),
            theme: theme,
          ),
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
      ),
    );
  }
}