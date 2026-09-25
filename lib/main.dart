// lib/main.dart
import 'package:flutter/material.dart';
import 'package:pocket_dex/providers/favorites_provider.dart';
import 'package:pocket_dex/providers/theme_provider.dart';
import 'package:pocket_dex/screens/home_screen.dart';
import 'package:pocket_dex/screens/web_shell.dart';
import 'package:pocket_dex/utils/app_colors.dart';
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
      theme: ThemeData(
          brightness: Brightness.light,
          primarySwatch: Colors.red,
          fontFamily: 'Poppins',
          scaffoldBackgroundColor: const Color(0xFFF5F5F5),
          cardColor: Colors.white,
          hintColor: Colors.grey.shade600,
          appBarTheme: const AppBarTheme(
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.black,
            titleTextStyle: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins'),
            iconTheme: IconThemeData(color: Colors.black),
          ),
          colorScheme: ColorScheme.fromSwatch(
            primarySwatch: Colors.red,
            brightness: Brightness.light,
          ).copyWith(
            surface: Colors.white,
            onSurface: Colors.black,
          ),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Colors.black),
            bodyMedium: TextStyle(color: Colors.black87),
          )),
      darkTheme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.blue,
          fontFamily: 'Poppins',
          scaffoldBackgroundColor: AppColors.primaryBackground,
          cardColor: const Color.fromRGBO(70, 70, 70, 1),
          hintColor: Colors.grey.shade400,
          appBarTheme: const AppBarTheme(
            elevation: 0,
            backgroundColor: Colors.transparent,
            titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins'),
            iconTheme: IconThemeData(color: Colors.white),
          ),
          colorScheme: ColorScheme.fromSwatch(
            primarySwatch: Colors.blue,
            brightness: Brightness.dark,
          ).copyWith(
            surface: Colors.grey[850],
            onSurface: Colors.white,
          ),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Colors.white),
            bodyMedium: TextStyle(color: Colors.white70),
          )),
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
