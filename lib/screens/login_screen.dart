// lib/screens/login_screen.dart
//
// Tela de login do app — a mesma conta do site. Aparece antes do app para
// quem não entrou. E-mail e senha ou Google, "Manter conectado", recuperar
// senha e, no cadastro, o nome (único) da pessoa.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/update_service.dart';
import '../utils/app_images.dart';

const _red = Color(0xFFE53935);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  void initState() {
    super.initState();
    // Versão nova do app? Avisa já aqui, sem precisar entrar na conta.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) UpdateService.checkOnStart(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final needsName = AuthService.instance.status == AuthStatus.needsName;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: _Hero()),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: needsName ? const _ChooseNameForm() : const _AuthForm(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Topo vermelho com a logo, a Pokébola girando e Pokémon flutuando.
class _Hero extends StatefulWidget {
  const _Hero();
  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _float(int id, double size, double phase) => AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = (_controller.value + phase) % 1.0;
          return Transform.translate(offset: Offset(0, -10 * (t < .5 ? t * 2 : (1 - t) * 2)), child: child);
        },
        child: Image.asset(AppImages.pokemonArtwork(id), width: size, height: size, cacheWidth: (size * 2).round()),
      );

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      height: 250 + top,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE53935), Color(0xFFB71C1C), Color(0xFF4A0D0D)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -90,
            bottom: -90,
            child: RotationTransition(
              turns: _controller.drive(Tween(begin: 0.0, end: 0.1)),
              child: Opacity(
                opacity: 0.12,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  child: Image.asset('assets/images/pokeball.png', width: 300, height: 300),
                ),
              ),
            ),
          ),
          Positioned(top: top + 70, left: 16, child: _float(6, 120, 0)),
          Positioned(top: top + 40, right: 20, child: _float(9, 110, .33)),
          Positioned(bottom: 16, right: 110, child: _float(25, 90, .66)),
          Positioned(
            top: top + 16,
            left: 0,
            right: 0,
            child: Center(child: Image.asset('assets/images/poke_logo.png', height: 72)),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final bool password;
  final TextInputType? keyboard;
  final String? hint;
  final List<String>? autofill;
  final int? maxLength;
  const _Field(this.label, this.controller, {this.password = false, this.keyboard, this.hint, this.autofill, this.maxLength});
  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  bool _show = false;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: TextStyle(fontWeight: FontWeight.w600, color: theme.hintColor)),
          const SizedBox(height: 6),
          TextField(
            controller: widget.controller,
            obscureText: widget.password && !_show,
            keyboardType: widget.keyboard,
            autofillHints: widget.autofill,
            maxLength: widget.maxLength,
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: theme.cardColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _red, width: 2),
              ),
              suffixIcon: widget.password
                  ? IconButton(
                      icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _show = !_show),
                    )
                  : null,
            ),
          ),
          if (widget.hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(widget.hint!, style: TextStyle(fontSize: 12, color: theme.hintColor)),
            ),
        ],
      ),
    );
  }
}

/// Campo do código de 6 números, com "reenviar".
class _CodeField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onResend;
  const _CodeField(this.controller, {required this.onResend});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Código do e-mail', style: TextStyle(fontWeight: FontWeight.w600, color: theme.hintColor)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            maxLength: 6,
            style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: theme.cardColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          TextButton(
            onPressed: onResend,
            child: const Text('Reenviar código', style: TextStyle(color: _red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String? error;
  final String? info;
  const _Message({this.error, this.info});
  @override
  Widget build(BuildContext context) {
    final text = error ?? info;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: text == null
          ? const SizedBox.shrink()
          : Container(
              key: ValueKey(text),
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: (error != null ? Colors.red : Colors.green).withAlpha(38),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                text,
                style: TextStyle(fontWeight: FontWeight.w600, color: error != null ? Colors.red.shade300 : Colors.green.shade400),
              ),
            ),
    );
  }
}

class _MainButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback onPressed;
  const _MainButton(this.label, {required this.busy, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _red,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _red.withAlpha(150),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        child: busy
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
            : Text(label),
      ),
    );
  }
}

enum _Mode { login, signup, forgot }

class _AuthForm extends StatefulWidget {
  const _AuthForm();
  @override
  State<_AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<_AuthForm> {
  final _auth = AuthService.instance;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _code = TextEditingController();
  _Mode _mode = _Mode.login;
  bool _keep = true;
  bool _busy = false;
  String? _error;
  String? _info;
  // Código por e-mail (quando ligado): depois de mandar, aparece o campo do código.
  bool _codes = false;
  bool _codeSent = false;

  @override
  void initState() {
    super.initState();
    _auth.emailCodesEnabled().then((on) => mounted ? setState(() => _codes = on) : null);
    _email.addListener(() {
      if (_codeSent) setState(() => _codeSent = false);
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  void _switch(_Mode mode) => setState(() {
        _mode = mode;
        _error = null;
        _info = null;
        _codeSent = false;
        _code.clear();
      });

  void _sendCode(String purpose) => _run(() async {
        await _auth.sendEmailCode(purpose, _email.text);
        if (mounted) {
          setState(() {
            _codeSent = true;
            _info = 'Mandamos um código de 6 números para ${_email.text.trim()}. Confira também o spam.';
          });
        }
      });

  Future<void> _run(Future<void> Function() action) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = e is AuthException ? e.message : 'Algo deu errado. Tente de novo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submit() {
    switch (_mode) {
      case _Mode.forgot:
        if (_codes) {
          if (!_codeSent) return _sendCode('reset');
          if (_password.text.length < 6) return setState(() => _error = 'A senha precisa ter pelo menos 6 caracteres.');
          if (_password.text != _confirm.text) return setState(() => _error = 'As senhas não são iguais.');
          _run(() async {
            await _auth.resetPasswordWithCode(email: _email.text, code: _code.text, password: _password.text);
            if (!mounted) return;
            _switch(_Mode.login);
            setState(() => _info = 'Senha trocada! Entre com a senha nova.');
          });
          return;
        }
        _run(() async {
          await _auth.resetPassword(_email.text);
          if (mounted) setState(() => _info = 'Enviamos um e-mail com o link para criar uma nova senha.');
        });
      case _Mode.signup:
        final nameError = AuthService.validateName(_name.text);
        if (nameError != null) return setState(() => _error = nameError);
        if (_password.text.length < 6) return setState(() => _error = 'A senha precisa ter pelo menos 6 caracteres.');
        if (_password.text != _confirm.text) return setState(() => _error = 'As senhas não são iguais.');
        if (_codes) {
          if (!_codeSent) {
            _run(() async {
              if (!await _auth.isNameAvailable(_name.text)) {
                throw AuthException('Esse nome já está sendo usado. Escolha outro.');
              }
              await _auth.sendEmailCode('signup', _email.text);
              if (mounted) {
                setState(() {
                  _codeSent = true;
                  _info = 'Mandamos um código de 6 números para ${_email.text.trim()}. Confira também o spam.';
                });
              }
            });
            return;
          }
          _run(() => _auth.signUpWithCode(
              name: _name.text, email: _email.text, password: _password.text, code: _code.text, keep: _keep));
          return;
        }
        _run(() => _auth.signUp(name: _name.text, email: _email.text, password: _password.text, keep: _keep));
      case _Mode.login:
        _run(() => _auth.signIn(email: _email.text, password: _password.text, keep: _keep));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final signup = _mode == _Mode.signup;
    final forgot = _mode == _Mode.forgot;
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            forgot ? 'Recuperar senha' : signup ? 'Crie sua conta' : 'Bem-vindo de volta!',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            forgot
                ? (_codes ? 'Digite o e-mail da sua conta para receber um código.' : 'Digite o e-mail da sua conta para receber o link.')
                : signup
                    ? 'A mesma conta vale no app e no site.'
                    : 'Entre para continuar na sua Pokédex.',
            style: TextStyle(color: theme.hintColor),
          ),
          const SizedBox(height: 20),
          if (!forgot) ...[
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  for (final (mode, label) in [(_Mode.login, 'Entrar'), (_Mode.signup, 'Criar conta')])
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _switch(mode),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _mode == mode ? _red : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            label,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _mode == mode ? Colors.white : theme.hintColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: Column(
              children: [
                if (signup)
                  _Field('Seu nome', _name,
                      autofill: const [AutofillHints.nickname],
                      maxLength: AuthService.nameMax,
                      hint: 'É assim que os outros vão te ver. Cada nome só pode ser usado por uma pessoa.'),
                _Field('E-mail', _email, keyboard: TextInputType.emailAddress, autofill: const [AutofillHints.email]),
                if (!forgot)
                  _Field('Senha', _password,
                      password: true,
                      autofill: [signup ? AutofillHints.newPassword : AutofillHints.password],
                      hint: signup ? 'Pelo menos 6 caracteres.' : null),
                if (signup) _Field('Confirmar senha', _confirm, password: true, autofill: const [AutofillHints.newPassword]),
                if (_codes && _codeSent && (signup || forgot))
                  _CodeField(_code, onResend: _busy ? null : () => _sendCode(forgot ? 'reset' : 'signup')),
                if (forgot && _codes && _codeSent) ...[
                  _Field('Nova senha', _password,
                      password: true, autofill: const [AutofillHints.newPassword], hint: 'Pelo menos 6 caracteres.'),
                  _Field('Confirmar nova senha', _confirm, password: true, autofill: const [AutofillHints.newPassword]),
                ],
              ],
            ),
          ),
          if (!forgot)
            Row(
              children: [
                Checkbox(value: _keep, activeColor: _red, onChanged: (v) => setState(() => _keep = v ?? true)),
                GestureDetector(onTap: () => setState(() => _keep = !_keep), child: const Text('Manter conectado')),
                const Spacer(),
                if (!signup)
                  TextButton(
                    onPressed: () => _switch(_Mode.forgot),
                    child: const Text('Esqueci a senha', style: TextStyle(color: _red, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          _Message(error: _error, info: _info),
          _MainButton(
              forgot
                  ? (_codes ? (_codeSent ? 'Trocar senha' : 'Enviar código') : 'Enviar link')
                  : signup
                      ? (_codes && !_codeSent ? 'Enviar código' : 'Criar conta')
                      : 'Entrar',
              busy: _busy,
              onPressed: _submit),
          if (forgot)
            Center(
              child: TextButton(onPressed: () => _switch(_Mode.login), child: const Text('← Voltar para o login')),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(children: [
                Expanded(child: Divider(color: theme.dividerColor)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('ou', style: TextStyle(color: theme.hintColor))),
                Expanded(child: Divider(color: theme.dividerColor)),
              ]),
            ),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : () => _run(() => _auth.signInWithGoogle(keep: _keep)),
                icon: const Text('G', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF4285F4))),
                label: const Text('Entrar com Google'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Primeiro login com Google: falta escolher o nome.
class _ChooseNameForm extends StatefulWidget {
  const _ChooseNameForm();
  @override
  State<_ChooseNameForm> createState() => _ChooseNameFormState();
}

class _ChooseNameFormState extends State<_ChooseNameForm> {
  final _auth = AuthService.instance;
  final _name = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _info;
  bool _codes = false;
  bool _codeSent = false;

  @override
  void initState() {
    super.initState();
    _auth.emailCodesEnabled().then((on) => mounted ? setState(() => _codes = on) : null);
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.sendEmailCode('signup');
      if (mounted) {
        setState(() {
          _codeSent = true;
          _info = 'Mandamos um código de 6 números para ${_auth.user?.email ?? ''}. Confira também o spam.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e is AuthException ? e.message : 'Algo deu errado. Tente de novo.');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _submit() async {
    final nameError = AuthService.validateName(_name.text);
    if (nameError != null) return setState(() => _error = nameError);
    // Conta Google nova com código ligado: primeiro confirma o e-mail.
    if (_codes && !_codeSent) {
      if (!await _auth.isNameAvailable(_name.text)) {
        return setState(() => _error = 'Esse nome já está sendo usado. Escolha outro.');
      }
      return _sendCode();
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_codes) await _auth.confirmSignupCode(_code.text);
      await _auth.chooseName(_name.text);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is AuthException ? e.message : 'Algo deu errado. Tente de novo.';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Como quer ser chamado?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('Entrou como ${_auth.user?.email ?? ''}. Escolha o seu nome no PocketDex.',
            style: TextStyle(color: theme.hintColor)),
        const SizedBox(height: 20),
        _Field('Seu nome', _name, maxLength: AuthService.nameMax, hint: 'Cada nome só pode ser usado por uma pessoa.'),
        if (_codes && _codeSent) _CodeField(_code, onResend: _busy ? null : _sendCode),
        _Message(error: _error, info: _info),
        _MainButton(_codes && !_codeSent ? 'Enviar código' : 'Continuar', busy: _busy, onPressed: _submit),
        Center(child: TextButton(onPressed: _auth.signOut, child: const Text('Usar outra conta'))),
      ],
    );
  }
}
