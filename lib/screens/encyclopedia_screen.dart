// lib/screens/encyclopedia_screen.dart

import 'package:flutter/material.dart';
import 'abilities_encyclopedia_screen.dart';
import 'items_encyclopedia_screen.dart';
import 'moves_encyclopedia_screen.dart';

class EncyclopediaScreen extends StatelessWidget {
  const EncyclopediaScreen({super.key});

  Widget _buildListTile(BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget destination,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: theme.textTheme.titleMedium),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enciclopédia'),
      ),
      body: ListView(
        children: [
          _buildListTile(
            context,
            icon: Icons.flash_on,
            iconColor: Colors.yellow.shade700,
            title: 'Enciclopédia de Golpes',
            destination: const MovesEncyclopediaScreen(),
          ),
          _buildListTile(
            context,
            icon: Icons.shield,
            iconColor: Colors.blue.shade400,
            title: 'Enciclopédia de Habilidades',
            destination: const AbilitiesEncyclopediaScreen(),
          ),
          _buildListTile(
            context,
            icon: Icons.shopping_bag,
            iconColor: Colors.brown.shade400,
            title: 'Enciclopédia de Itens',
            destination: const ItemsEncyclopediaScreen(),
          ),
        ],
      ),
    );
  }
}