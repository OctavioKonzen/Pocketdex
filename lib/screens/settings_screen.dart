// lib/screens/settings_screen.dart
//
// Configurações em seções, como no site: conta, aparência (tema, idioma e
// tamanho do texto), Pokédex, notificações, dados, sobre e zona de perigo.

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/theme_provider.dart';
import '../services/account_sync.dart';
import '../services/achievements.dart';
import '../services/app_settings.dart';
import '../services/auth_service.dart';
import '../services/daily_pokemon.dart';
import '../services/daily_reminder.dart';
import '../services/league.dart';
import '../services/pix.dart';
import '../services/update_service.dart';
import '../services/user_data.dart';
import '../utils/responsive.dart';
import '../utils/site_ui.dart';
import '../widgets/account_avatar.dart';
import 'package:pocket_dex/i18n/text.dart';
import 'package:pocket_dex/widgets/language_picker.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Limpar dados'),
        content: const Text('Isso apaga seus favoritos, times e treinos. Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Limpar', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    UserData.instance.update({'favorites': [], 'teams': [], 'training': []});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Favoritos, times e treinos apagados.')));
  }

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final settings = context.watch<AppSettings>();
    final auth = context.watch<AuthService>();
    final user = auth.status == AuthStatus.signedIn ? auth.user : null;

    Widget row({required String title, required String subtitle, Widget? trailing, Widget? leading, Widget? below}) => SiteCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (leading != null) ...[leading, const SizedBox(width: 14)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: TextStyle(color: c.text, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(subtitle, style: TextStyle(color: c.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[const SizedBox(width: 12), trailing],
                ],
              ),
              if (below != null) ...[const SizedBox(height: 12), below],
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            const PageHeader(title: 'Configurações'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (user != null)
                    _Section('Conta', [
                      row(
                        leading: AccountAvatar(size: 48, onTap: () => ProfileSheet.show(context)),
                        title: user.name ?? 'Conta',
                        subtitle: user.email ?? '',
                        trailing: PillButton(label: 'Sair', color: const Color(0xFFE53935), onPressed: AccountSync.instance.logout),
                      ),
                      row(
                        title: 'Conquistas',
                        subtitle: 'Medalhas do jogo, da Pokédex e dos times.',
                        trailing: PillButton(
                          label: 'Ver',
                          color: const Color(0xFFF59E0B),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsScreen())),
                        ),
                      ),
                      row(
                        title: 'Trocar senha',
                        subtitle: 'Com a senha atual, ou por um link no e-mail se você entra com Google.',
                        trailing: PillButton(
                          label: 'Trocar',
                          color: const Color(0xFF546E7A),
                          onPressed: () => showDialog(context: context, builder: (_) => const _ChangePasswordDialog()),
                        ),
                      ),
                    ]),
                  _Section('Aparência', [
                    row(
                      title: 'Tema',
                      subtitle: 'Automático segue o tema do celular.',
                      below: _Choice(
                        value: themeProvider.theme,
                        onChanged: themeProvider.setTheme,
                        options: const [('light', 'Claro'), ('dark', 'Escuro'), ('system', 'Automático')],
                      ),
                    ),
                    row(
                      title: 'Idioma',
                      subtitle: 'Nomes dos Pokémon e descrições também mudam.',
                      below: const Align(alignment: Alignment.centerLeft, child: LanguagePicker()),
                    ),
                    row(
                      title: 'Tamanho do texto',
                      subtitle: 'Aumenta as letras em todo o app.',
                      below: _Choice(
                        value: settings.textSize,
                        onChanged: settings.setTextSize,
                        options: [for (final t in AppSettings.textSizes) (t.$1, t.$2)],
                      ),
                    ),
                  ]),
                  _Section('Animações', [
                    row(
                      title: 'Animação da Pokébola',
                      subtitle: 'O Pokémon sai da Pokébola ao abrir os detalhes.',
                      trailing: Switch(
                        value: settings.pokeballAnimation,
                        activeTrackColor: const Color(0xFF0EA5E9),
                        onChanged: settings.setPokeballAnimation,
                      ),
                    ),
                    row(
                      title: 'Pokébola girando no fundo',
                      subtitle: 'Uma Pokébola clarinha gira devagar atrás das telas.',
                      trailing: Switch(
                        value: settings.backgroundAnimation,
                        activeTrackColor: const Color(0xFF0EA5E9),
                        onChanged: settings.setBackgroundAnimation,
                      ),
                    ),
                    row(
                      title: 'Sprites animados',
                      subtitle: 'Os Pokémon se mexem (estilo Black & White). Cada um é baixado da primeira vez que aparece e fica salvo no celular.',
                      trailing: Switch(
                        value: settings.animatedSprites,
                        activeTrackColor: const Color(0xFF0EA5E9),
                        onChanged: settings.setAnimatedSprites,
                      ),
                    ),
                  ]),
                  if (DailyReminder.supported) _Section('Notificações', [_ReminderSwitch(row: row), _DailyPokemonSwitch(row: row)]),
                  _Section('Dados', [
                    row(
                      title: 'Dados salvos',
                      subtitle: user != null
                          ? 'Favoritos, times e treinos ficam salvos na sua conta (app e site).'
                          : 'Favoritos, times e treinos ficam salvos neste aparelho.',
                      trailing: PillButton(label: 'Limpar', color: const Color(0xFFE53935), onPressed: () => _confirmClear(context)),
                    ),
                  ]),
                  _Section('Sobre', [
                    if (UpdateService.supported)
                      FutureBuilder<String>(
                        future: UpdateService.currentVersion(),
                        builder: (context, snapshot) => row(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(color: const Color(0xFF3DDC84), borderRadius: BorderRadius.circular(14)),
                            child: const Icon(Icons.android, color: Color(0xFF073042)),
                          ),
                          title: 'PocketDex ${snapshot.data ?? ''}',
                          subtitle: 'As versões novas são avisadas ao abrir o app.',
                          trailing: PillButton(
                            label: 'Procurar',
                            color: const Color(0xFF3DDC84),
                            foreground: const Color(0xFF073042),
                            onPressed: () => UpdateService.checkNow(context),
                          ),
                        ),
                      ),
                    if (Pix.enabled) const _SupportCard(),
                  ]),
                  if (user != null)
                    _Section('Zona de perigo', [
                      row(
                        title: 'Excluir conta',
                        subtitle: 'Apaga para sempre sua conta, seus dados e suas posições nos rankings.',
                        trailing: PillButton(
                          label: 'Excluir',
                          color: const Color(0xFFB71C1C),
                          onPressed: () => showDialog(context: context, builder: (_) => const _DeleteAccountDialog()),
                        ),
                      ),
                    ]),
                  const SizedBox(height: 8),
                  Text('PocketDex · app em Flutter e site em React, com a mesma conta.\n'
                      'Pokémon e os nomes dos personagens são marcas da Nintendo.',
                      textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grupo de configurações com título.
class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section(this.title, this.children);

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(tr(title).toUpperCase(),
                style: TextStyle(color: c.muted, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Botões lado a lado para escolher uma opção.
class _Choice extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final List<(String, String)> options;
  const _Choice({required this.value, required this.onChanged, required this.options});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: [for (final o in options) ButtonSegment(value: o.$1, label: Text(o.$2))],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(s.first),
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: const Color(0xFF0EA5E9),
        selectedForegroundColor: Colors.white,
      ),
    );
  }
}

/// Página das conquistas (aberta pelo menu do avatar).
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Conquistas')),
        body: ReadableWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: const [_AchievementsCard()],
          ),
        ),
      );
}

/// Medalhas conquistadas no jogo, na Pokédex e nos times (as mesmas do site).
class _AchievementsCard extends StatelessWidget {
  const _AchievementsCard();

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    return ListenableBuilder(
      listenable: UserData.instance,
      builder: (context, _) {
        final data = UserData.instance;
        final list = Achievements.of(
          stats: data.stats,
          rankedRecord: data.rankedRecord,
          favorites: data.favorites,
          teams: data.teams,
        );
        final unlocked = list.where((a) => a.unlocked).length;
        return SiteCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Conquistas', style: TextStyle(color: c.text, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text('Jogue, monte times e favorite Pokémon para liberar medalhas.',
                            style: TextStyle(color: c.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(20)),
                    child: Text('$unlocked/${list.length}',
                        style: const TextStyle(color: Color(0xFF3E2723), fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final a in list)
                Opacity(
                  opacity: a.unlocked ? 1 : 0.45,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: a.unlocked ? Colors.amber.withAlpha(35) : SiteColors.of(context).bg,
                      borderRadius: BorderRadius.circular(14),
                      border: a.unlocked ? Border.all(color: Colors.amber.withAlpha(150)) : null,
                    ),
                    child: Row(
                      children: [
                        Text(a.icon, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.title, style: TextStyle(color: c.text, fontWeight: FontWeight.bold)),
                              Text(a.text, style: TextStyle(color: c.muted, fontSize: 12)),
                            ],
                          ),
                        ),
                        if (a.unlocked) const Icon(Icons.check_circle, color: Colors.amber, size: 20),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Confirma e apaga a conta e todos os dados dela (senha ou conta Google).
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();
  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  String? _info;
  bool _linkSent = false;

  /// Conta Google: manda o link; a exclusão é confirmada no site (abrindo o link).
  Future<void> _sendLink() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.instance.sendConfirmationLink('delete');
      _linkSent = true;
      _info = 'Mandamos um link para o e-mail da conta. Abra o link (confira também o spam), confirme a exclusão '
          'e depois toque em "Já excluí".';
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _busy = false);
  }

  /// Depois de excluir pelo link: confere e sai da conta aqui também.
  Future<void> _checkDeleted() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final exists = await AuthService.instance.accountStillExists();
    if (!mounted) return;
    if (exists) {
      setState(() {
        _busy = false;
        _error = 'A conta ainda existe. Abra o link do e-mail e toque em "Excluir para sempre".';
      });
      return;
    }
    UserData.instance.clearAll();
    if (DailyReminder.supported) await DailyReminder.instance.setEnabled(false).catchError((_) => false);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).popUntil((route) => route.isFirst);
    messenger.showSnackBar(const SnackBar(content: Text('Sua conta foi excluída.')));
  }

  Future<void> _run() async {
    if (AuthService.instance.usesGoogle) return _linkSent ? _checkDeleted() : _sendLink();
    setState(() {
      _busy = true;
      _error = null;
    });
    final stats = UserData.instance.stats;
    final weeks = {...List<dynamic>.from(stats['weeks'] as List? ?? []).map((w) => '$w'), League.weekKey()}.toList();
    final days = {...List<dynamic>.from(stats['days'] as List? ?? []).map((d) => '$d'), League.dayKey()}.toList();
    final sync = AccountSync.instance;
    sync.pause(); // não recria os dados enquanto apaga
    try {
      await AuthService.instance.deleteAccount(password: _password.text, weeks: weeks, days: days);
      UserData.instance.clearAll();
      // Nada da conta fica no aparelho: nem o lembrete do desafio.
      if (DailyReminder.supported) await DailyReminder.instance.setEnabled(false).catchError((_) => false);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).popUntil((route) => route.isFirst);
      messenger.showSnackBar(const SnackBar(content: Text('Sua conta foi excluída.')));
    } catch (e) {
      sync.resume();
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final google = AuthService.instance.usesGoogle;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Excluir conta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Isso apaga para sempre sua conta, favoritos, times, treinos, recordes, conquistas e suas linhas '
              'nos rankings. No app e no site. Não dá para desfazer.'),
          const SizedBox(height: 12),
          if (google)
            Text('Para confirmar, vamos mandar um link para o e-mail da sua conta Google.',
                style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13))
          else
            TextField(
              controller: _password,
              obscureText: true,
              enabled: !_busy,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: tr('Digite sua senha para confirmar')),
            ),
          if (_info != null && _error == null) ...[
            const SizedBox(height: 10),
            Text(_info!, style: const TextStyle(color: Colors.green, fontSize: 13)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        if (google && _linkSent) TextButton(onPressed: _busy ? null : _sendLink, child: const Text('Reenviar')),
        TextButton(
          onPressed: _busy || (!google && _password.text.isEmpty) ? null : _run,
          child: Text(
              _busy
                  ? 'Aguarde...'
                  : google
                      ? (_linkSent ? 'Já excluí' : 'Enviar link')
                      : 'Excluir para sempre',
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

/// Trocar senha: senha atual (conta com e-mail) ou link no e-mail (conta Google).
class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();
  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    for (final c in [_current, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run() async {
    final google = AuthService.instance.usesGoogle;
    if (!google) {
      if (_password.text.length < 6) return setState(() => _error = 'A senha precisa ter pelo menos 6 caracteres.');
      if (_password.text != _confirm.text) return setState(() => _error = 'As senhas não são iguais.');
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (google) {
        await AuthService.instance.sendConfirmationLink('password');
        _info = 'Mandamos um link para o e-mail da conta. Abra o link (confira também o spam) para escolher a senha.';
      } else {
        await AuthService.instance.changePassword(current: _current.text, password: _password.text);
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(const SnackBar(content: Text('Senha trocada!')));
        return;
      }
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final google = AuthService.instance.usesGoogle;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Trocar senha'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (google)
              Text('Você entra com Google. Vamos mandar um link para o seu e-mail; abrindo, você cria ou troca a senha.',
                  style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13))
            else ...[
              TextField(
                controller: _current,
                obscureText: true,
                enabled: !_busy,
                autofillHints: const [AutofillHints.password],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: tr('Senha atual')),
              ),
              TextField(
                controller: _password,
                obscureText: true,
                enabled: !_busy,
                autofillHints: const [AutofillHints.newPassword],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: tr('Nova senha')),
              ),
              TextField(
                controller: _confirm,
                obscureText: true,
                enabled: !_busy,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(labelText: tr('Confirmar nova senha')),
              ),
            ],
            if (_info != null && _error == null) ...[
              const SizedBox(height: 10),
              Text(_info!, style: const TextStyle(color: Colors.green, fontSize: 13)),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context), child: Text(_info != null ? 'Fechar' : 'Cancelar')),
        TextButton(
          onPressed: _busy || (!google && (_current.text.isEmpty || _password.text.isEmpty)) ? null : _run,
          child: Text(_busy ? 'Aguarde...' : (google ? (_info != null ? 'Reenviar link' : 'Enviar link') : 'Trocar senha'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

/// Pix para apoiar o projeto (QR Code e "copia e cola").
class _SupportCard extends StatelessWidget {
  const _SupportCard();

  void _copy(BuildContext context, String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$what copiado!')));
  }

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final code = Pix.code();
    return SiteCard(
      accentLeft: const Color(0xFF32BCAD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('💚 Apoie o PocketDex', style: TextStyle(color: c.text, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text('O PocketDex é gratuito e sem anúncios. Se ele te ajuda, uma contribuição por Pix '
              '(de qualquer valor) ajuda a manter o projeto.',
              style: TextStyle(color: c.muted, fontSize: 13)),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: QrImageView(data: code, size: 170, padding: EdgeInsets.zero),
            ),
          ),
          const SizedBox(height: 10),
          SelectableText('Chave: ${Pix.key}', style: TextStyle(color: c.text, fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: PillButton(
                  label: 'Pix copia e cola',
                  color: const Color(0xFF32BCAD),
                  expand: true,
                  onPressed: () => _copy(context, code, 'Pix copia e cola'),
                ),
              ),
              const SizedBox(width: 8),
              PillButton(label: 'Chave', color: const Color(0xFF546E7A), onPressed: () => _copy(context, Pix.key, 'Chave')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Liga/desliga o aviso do Pokémon do dia (fica só neste aparelho).
class _DailyPokemonSwitch extends StatefulWidget {
  const _DailyPokemonSwitch({required this.row});

  final Widget Function({Widget? leading, required String title, required String subtitle, Widget? trailing, Widget? below}) row;

  @override
  State<_DailyPokemonSwitch> createState() => _DailyPokemonSwitchState();
}

class _DailyPokemonSwitchState extends State<_DailyPokemonSwitch> {
  bool _on = false;

  @override
  void initState() {
    super.initState();
    DailyPokemon.instance.enabled.then((on) {
      if (mounted) setState(() => _on = on);
    });
  }

  Future<void> _toggle(bool on) async {
    setState(() => _on = on);
    final ok = await DailyPokemon.instance.setEnabled(on);
    if (!mounted) return;
    if (on && !ok) {
      setState(() => _on = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permita as notificações do PocketDex nas configurações do celular.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.row(
        title: 'Pokémon do dia',
        subtitle: 'Uma notificação às 10h com o Pokémon de hoje.',
        trailing: Switch(value: _on, activeTrackColor: const Color(0xFF0EA5E9), onChanged: _toggle),
      );
}

/// Liga/desliga o lembrete diário do desafio (fica só neste aparelho).
class _ReminderSwitch extends StatefulWidget {
  const _ReminderSwitch({required this.row});

  final Widget Function({Widget? leading, required String title, required String subtitle, Widget? trailing, Widget? below}) row;

  @override
  State<_ReminderSwitch> createState() => _ReminderSwitchState();
}

class _ReminderSwitchState extends State<_ReminderSwitch> {
  bool _on = false;

  @override
  void initState() {
    super.initState();
    DailyReminder.instance.enabled.then((on) {
      if (mounted) setState(() => _on = on);
    });
  }

  Future<void> _toggle(bool on) async {
    setState(() => _on = on);
    final ok = await DailyReminder.instance.setEnabled(on);
    if (!mounted) return;
    if (on && !ok) {
      setState(() => _on = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permita as notificações do PocketDex nas configurações do celular.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.row(
        title: 'Lembrete do desafio do dia',
        subtitle: 'Uma notificação às 9h nos dias em que você ainda não jogou.',
        trailing: Switch(value: _on, activeTrackColor: const Color(0xFF0EA5E9), onChanged: _toggle),
      );
}
