// lib/screens/encyclopedia_screen.dart
//
// Enciclopédia no estilo do site: golpes, habilidades e itens, cada um num card
// com a sua cor (as mesmas das abas do site) e um Pokémon animado, como no Treino.

import 'package:flutter/material.dart' hide Text;

import '../utils/responsive.dart';
import '../utils/site_ui.dart';
import 'abilities_encyclopedia_screen.dart';
import 'items_encyclopedia_screen.dart';
import 'moves_encyclopedia_screen.dart';
import 'package:pocket_dex/i18n/text.dart';

class EncyclopediaScreen extends StatelessWidget {
  const EncyclopediaScreen({super.key});

  void _open(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enciclopédia')),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const PageHeader(eyebrow: 'Referência', title: 'Enciclopédia', subtitle: 'Todos os golpes, habilidades e itens do banco de dados.'),
            // O mesmo card do Treino e do Centro de Batalha: o ícone na cor da área e o Pokémon animado.
            for (final (icon, title, color, pokemon, screen) in [
              (Icons.flash_on, 'Golpes', const Color(0xFFFFA726), 68, const MovesEncyclopediaScreen()),
              (Icons.shield, 'Habilidades', const Color(0xFF42A5F5), 65, const AbilitiesEncyclopediaScreen()),
              (Icons.shopping_bag, 'Itens', const Color(0xFF8D6E63), 52, const ItemsEncyclopediaScreen()),
            ])
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: ModeCard(icon: icon, title: title, color: color, pokemon: pokemon, onTap: () => _open(context, screen)),
              ),
          ],
        ),
      ),
    );
  }
}
