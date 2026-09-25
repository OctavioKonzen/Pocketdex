// lib/screens/encyclopedia_screen.dart
//
// Enciclopédia no estilo do site: golpes, habilidades e itens, cada um com a
// sua cor (as mesmas das abas do site).

import 'package:flutter/material.dart';

import '../utils/responsive.dart';
import '../utils/site_ui.dart';
import 'abilities_encyclopedia_screen.dart';
import 'items_encyclopedia_screen.dart';
import 'moves_encyclopedia_screen.dart';

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
            const PageHeader(title: 'Enciclopédia', subtitle: 'Todos os golpes, habilidades e itens do banco de dados.'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  ToolCard(
                    icon: Icons.flash_on,
                    title: 'Golpes',
                    subtitle: 'Tipo, categoria, poder, precisão e quem aprende',
                    color: const Color(0xFFFFA726),
                    onTap: () => _open(context, const MovesEncyclopediaScreen()),
                  ),
                  const SizedBox(height: 14),
                  ToolCard(
                    icon: Icons.shield,
                    title: 'Habilidades',
                    subtitle: 'O que cada habilidade faz e quem tem',
                    color: const Color(0xFF42A5F5),
                    onTap: () => _open(context, const AbilitiesEncyclopediaScreen()),
                  ),
                  const SizedBox(height: 14),
                  ToolCard(
                    icon: Icons.shopping_bag,
                    title: 'Itens',
                    subtitle: 'Efeito e categoria de cada item',
                    color: const Color(0xFF8D6E63),
                    onTap: () => _open(context, const ItemsEncyclopediaScreen()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
