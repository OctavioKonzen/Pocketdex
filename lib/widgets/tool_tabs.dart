// lib/widgets/tool_tabs.dart
//
// Duas ferramentas que se completam numa tela só, com abas (ex.: Calculadora
// de dano e Quem vence?; Breeding e Golpes de ovo). Cada ferramenta continua
// sendo a sua tela: dentro das abas, ela some com a própria barra de cima
// (ToolTabs.appBar) e fica só a barra com o título e as abas.

import 'package:flutter/material.dart' hide Text;
import '../i18n/i18n.dart';
import '../i18n/text.dart';

class ToolTabs extends StatelessWidget {
  const ToolTabs({super.key, required this.title, required this.tabs, this.initial = 0});

  final String title;

  /// (nome da aba, tela da ferramenta).
  final List<(String, Widget)> tabs;
  final int initial;

  /// A barra de cima da ferramenta, ou nada quando ela está dentro das abas.
  static PreferredSizeWidget? appBar(BuildContext context, PreferredSizeWidget bar) =>
      context.dependOnInheritedWidgetOfExactType<_InTabs>() != null ? null : bar;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      initialIndex: initial,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          bottom: TabBar(tabs: [for (final (label, _) in tabs) Tab(key: ValueKey('tool-tab-$label'), text: tr(label))]),
        ),
        body: TabBarView(children: [for (final (_, screen) in tabs) _InTabs(child: screen)]),
      ),
    );
  }
}

class _InTabs extends InheritedWidget {
  const _InTabs({required super.child});

  @override
  bool updateShouldNotify(_InTabs oldWidget) => false;
}
