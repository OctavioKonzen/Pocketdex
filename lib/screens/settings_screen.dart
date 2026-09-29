// lib/screens/settings_screen.dart
//
// Configurações no estilo do site: conta, tema, dados salvos, conquistas,
// versão do app (com "Procurar atualização"), excluir conta e sobre.

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/theme_provider.dart';
import '../services/account_sync.dart';
import '../services/achievements.dart';
import '../services/auth_service.dart';
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
    final dark = context.watch<ThemeProvider>().themeMode == ThemeMode.dark;
    final auth = context.watch<AuthService>();
    final user = auth.status == AuthStatus.signedIn ? auth.user : null;

    Widget row({required String title, required String subtitle, Widget? trailing, Widget? leading}) => SiteCard(
          child: Row(
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
                children: [
                  if (user != null) ...[
                    row(
                      leading: AccountAvatar(size: 48, onTap: () => ProfileSheet.show(context)),
                      title: user.name ?? 'Conta',
                      subtitle: user.email ?? '',
                      trailing: PillButton(label: 'Sair', color: const Color(0xFFE53935), onPressed: AccountSync.instance.logout),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SiteCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Idioma', style: TextStyle(color: c.text, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 10),
                        const Align(alignment: Alignment.centerLeft, child: LanguagePicker()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  row(
                    title: 'Modo Escuro',
                    subtitle: 'Ative para uma experiência com cores escuras.',
                    trailing: Switch(
                      value: dark,
                      activeTrackColor: const Color(0xFF0EA5E9),
                      onChanged: (v) => context.read<ThemeProvider>().toggleTheme(v),
                    ),
                  ),
                  if (DailyReminder.supported) ...[
                    const SizedBox(height: 12),
                    _ReminderSwitch(row: row),
                  ],
                  const SizedBox(height: 12),
                  row(
                    title: 'Dados salvos',
                    subtitle: user != null
                        ? 'Favoritos, times e treinos ficam salvos na sua conta (app e site).'
                        : 'Favoritos, times e treinos ficam salvos neste aparelho.',
                    trailing: PillButton(label: 'Limpar', color: const Color(0xFFE53935), onPressed: () => _confirmClear(context)),
                  ),
                  if (Pix.enabled) ...[
                    const SizedBox(height: 12),
                    const _SupportCard(),
                  ],
                  const SizedBox(height: 12),
                  const _AchievementsCard(),
                  if (UpdateService.supported) ...[
                    const SizedBox(height: 12),
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
                  ],
                  if (user != null) ...[
                    const SizedBox(height: 12),
                    row(
                      title: 'Trocar senha',
                      subtitle: 'Com a senha atual, ou por um link no e-mail se você entra com Google.',
                      trailing: PillButton(
                        label: 'Trocar',
                        color: const Color(0xFF546E7A),
                        onPressed: () => showDialog(context: context, builder: (_) => const _ChangePasswordDialog()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    row(
                      title: 'Excluir conta',
                      subtitle: 'Apaga para sempre sua conta, seus dados e suas posições nos rankings.',
                      trailing: PillButton(
                        label: 'Excluir',
                        color: const Color(0xFFB71C1C),
                        onPressed: () => showDialog(context: context, builder: (_) => const _DeleteAccountDialog()),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
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
                      color: a.unlocked ? Colors.amber.withAlpha(35) : Theme.of(context).scaffoldBackgroundColor,
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

/// Liga/desliga o lembrete diário do desafio (fica só neste aparelho).
class _ReminderSwitch extends StatefulWidget {
  const _ReminderSwitch({required this.row});

  final Widget Function({Widget? leading, required String title, required String subtitle, Widget? trailing}) row;

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
