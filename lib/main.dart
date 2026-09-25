// lib/main.dart
import 'package:flutter/material.dart';
import 'package:pocket_dex/providers/favorites_provider.dart';
import 'package:pocket_dex/providers/theme_provider.dart';
import 'package:pocket_dex/screens/home_screen.dart';
import 'package:pocket_dex/screens/web_shell.dart';
import 'package:pocket_dex/utils/site_ui.dart';
import 'package:provider/provider.dart';
import 'package:pocket_dex/utils/responsive.dart';
import 'package:pocket_dex/screens/login_screen.dart';
import 'package:pocket_dex/services/account_format.dart';
import 'package:pocket_dex/services/account_sync.dart';
import 'package:pocket_dex/services/auth_service.dart';
import 'package:pocket_dex/services/firebase_setup.dart';
import 'package:pocket_dex/services/user_data.dart';
import 'package:pocket_dex/widgets/pokemon_sprite.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Dados salvos no aparelho (favoritos, times, treinos, tema e recordes).
  await Future.wait([UserData.instance.load(), SpriteBoxes.load()]);
  // Tabela Pokémon → espécie (para converter times/treinos da conta) em
  // segundo plano, sem atrasar a abertura do app.
  AccountFormat.init();
  // Login e sincronização com a conta (a mesma do site).
  if (await initFirebase()) {
    AccountSync.instance.start();
    AuthService.instance.start();
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: AuthService.instance),
        ChangeNotifierProvider(create: (context) => FavoritesProvider()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

ThemeData _siteTheme(SiteColors c, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF2196F3), brightness: brightness).copyWith(
    primary: const Color(0xFF2196F3),
    onPrimary: Colors.white,
    secondary: const Color(0xFF26A69A),
    surface: c.surface,
    onSurface: c.text,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    cardColor: c.card,
    canvasColor: c.bg,
    hintColor: c.muted,
    dividerColor: c.line,
    appBarTheme: AppBarTheme(
      backgroundColor: c.surface,
      foregroundColor: c.text,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      scrolledUnderElevation: 4,
      shadowColor: Colors.black54,
      titleTextStyle: TextStyle(color: c.text, fontSize: 20, fontWeight: FontWeight.bold),
      iconTheme: IconThemeData(color: c.text),
    ),
    cardTheme: CardThemeData(
      color: c.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: c.card, surfaceTintColor: Colors.transparent),
    dialogTheme: DialogThemeData(backgroundColor: c.card, surfaceTintColor: Colors.transparent),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    textTheme: ThemeData(brightness: brightness).textTheme.apply(bodyColor: c.text, displayColor: c.text),
  );
}

/// Sem login aparece a tela de entrar; logado, vai direto para o app.
class AuthGate extends StatelessWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthService>().status;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: switch (status) {
        AuthStatus.disabled || AuthStatus.signedIn => KeyedSubtree(key: const ValueKey('app'), child: child),
        AuthStatus.loading => const _Splash(),
        _ => const LoginScreen(key: ValueKey('login')),
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(child: Image.asset('assets/images/poke_logo.png', height: 96)),
      );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'PocketDex',
      // Mesmas cores do site (claro e escuro).
      theme: _siteTheme(SiteColors.light, Brightness.light),
      darkTheme: _siteTheme(SiteColors.dark, Brightness.dark),
      themeMode: themeProvider.themeMode,
      scrollBehavior: const AppScrollBehavior(),
      builder: (context, child) => WebFrame(child: child!),
      // No PC o site abre direto na Pokédex, com navegação no topo.
      home: AuthGate(
        child: Builder(
          builder: (context) =>
              Responsive.isWide(context) ? const WebShell() : const HomeScreen(),
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
