// lib/screens/main_shell.dart
//
// Celular: as telas principais ficam numa barra embaixo (Início, Pokédex,
// Times, Jogo e Amigos). Cada aba guarda onde a pessoa parou; o voltar do
// Android volta para o Início antes de sair do app.

import 'package:flutter/material.dart' hide Text;

import '../i18n/text.dart';
import '../services/friends_service.dart';
import 'friends_screen.dart';
import 'game_screen.dart';
import 'home_screen.dart';
import 'pokedex_screen.dart';
import 'teams_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  /// Troca de aba a partir de qualquer tela dentro da barra (ex.: o Início).
  static void go(BuildContext context, int tab) => context.findAncestorStateOfType<_MainShellState>()?._select(tab);

  static const home = 0, pokedex = 1, teams = 2, game = 3, friends = 4;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  // As abas só são criadas na primeira vez que a pessoa abre.
  final _opened = <int>{0};

  void _select(int i) => setState(() {
        _index = i;
        _opened.add(i);
      });

  Widget _page(int i) => switch (i) {
        0 => const HomeScreen(),
        1 => const PokedexScreen(),
        2 => const TeamsScreen(),
        3 => const GameScreen(),
        _ => const FriendsScreen(),
      };

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF0284C7);
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [for (var i = 0; i < 5; i++) _opened.contains(i) ? _page(i) : const SizedBox.shrink()],
        ),
        bottomNavigationBar: ListenableBuilder(
          listenable: FriendsService.instance,
          builder: (context, _) {
            final pending = FriendsService.instance.pending;
            return NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _select,
              height: 66,
              indicatorColor: color.withAlpha(60),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: tr('Início')),
                NavigationDestination(
                    icon: const Icon(Icons.catching_pokemon_outlined), selectedIcon: const Icon(Icons.catching_pokemon), label: tr('Pokédex')),
                NavigationDestination(icon: const Icon(Icons.groups_outlined), selectedIcon: const Icon(Icons.groups), label: tr('Times')),
                NavigationDestination(
                    icon: const Icon(Icons.videogame_asset_outlined), selectedIcon: const Icon(Icons.videogame_asset), label: tr('Jogo')),
                NavigationDestination(
                  icon: Badge(isLabelVisible: pending > 0, label: Text('$pending'), child: const Icon(Icons.people_outline)),
                  selectedIcon: Badge(isLabelVisible: pending > 0, label: Text('$pending'), child: const Icon(Icons.people)),
                  label: tr('Amigos'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
