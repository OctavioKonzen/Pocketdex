// lib/screens/training_screen.dart

import 'package:flutter/material.dart';
import 'package:pocket_dex/screens/nature_guide_screen.dart';
import 'package:pocket_dex/screens/breeding_help_screen.dart';
import 'package:pocket_dex/screens/ev_counter_screen.dart';

class TrainingScreen extends StatelessWidget {
  const TrainingScreen({super.key});

  Widget _buildOptionTile(BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget destination,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: iconColor.withAlpha(38),
        child: Icon(icon, color: iconColor, size: 28),
      ),
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      trailing: Icon(Icons.chevron_right, color: theme.hintColor),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destination),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Centro de Treinamento'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text(
              'Ferramentas para treinadores dedicados que buscam o Pokémon perfeito.',
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: 24),
            const Divider(),
            _buildOptionTile(
              context,
              icon: Icons.help_outline,
              iconColor: Colors.lightBlue.shade300,
              title: 'Guia de Natures',
              subtitle: 'Veja como cada Nature afeta os status',
              destination: const NatureGuideScreen(),
            ),
            _buildOptionTile(
              context,
              icon: Icons.egg_outlined,
              iconColor: Colors.pink.shade300,
              title: 'Ajuda de Criação (Breeding)',
              subtitle: 'Encontre parceiros compatíveis',
              destination: const BreedingHelpScreen(),
            ),
            _buildOptionTile(
              context,
              icon: Icons.calculate_outlined,
              iconColor: Colors.green.shade400,
              title: 'Contador de EVs',
              subtitle: 'Acompanhe o treino dos seus Pokémon',
              destination: const EvCounterScreen(),
            ),
          ],
        ),
      ),
    );
  }
}