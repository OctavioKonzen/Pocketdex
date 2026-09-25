// lib/services/auth_service.dart
//
// Login com Firebase — a MESMA conta do site: e-mail e senha ou Google, com
// "Manter conectado". Regras iguais às do site (web-site/src/lib/auth.js):
//   users/{uid}          → { name, email, createdAt, data }
//   usernames/{nomeNorm} → { uid, name }   (2 pessoas não têm o mesmo nome)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AuthStatus { disabled, loading, signedOut, needsName, signedIn }

class AccountUser {
  final String uid;
  final String? email;
  final String? photo;
  final String? name;
  const AccountUser({required this.uid, this.email, this.photo, this.name});
  AccountUser withName(String name) => AccountUser(uid: uid, email: email, photo: photo, name: name);
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const nameMin = 3;
  static const nameMax = 20;
  static const _keepKey = 'auth_keep_signed_in';

  AuthStatus status = AuthStatus.disabled;
  AccountUser? user;
  bool _signingUp = false;
  bool _googleReady = false;

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  void _set(AuthStatus s, [AccountUser? u]) {
    status = s;
    user = u;
    notifyListeners();
  }

  /// Começa a ouvir o login. Chamado ao abrir o app, se o Firebase subiu.
  Future<void> start() async {
    _set(AuthStatus.loading);
    // "Manter conectado" desmarcado: a sessão termina quando o app fecha.
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keepKey) == false && _auth.currentUser != null) {
      await _auth.signOut();
    }
    _auth.authStateChanges().listen((u) async {
      if (_signingUp) return;
      if (u == null) return _set(AuthStatus.signedOut);
      final base = AccountUser(uid: u.uid, email: u.email, photo: u.photoURL);
      try {
        final profile = await _db.collection('users').doc(u.uid).get();
        final name = profile.data()?['name'] as String?;
        _set(name == null ? AuthStatus.needsName : AuthStatus.signedIn, name == null ? base : base.withName(name));
      } catch (_) {
        // Sem internet: entra com o nome salvo no aparelho, se houver.
        final cached = prefs.getString('auth_name_${u.uid}');
        _set(cached == null ? AuthStatus.needsName : AuthStatus.signedIn, cached == null ? base : base.withName(cached));
      }
      if (user?.name != null) prefs.setString('auth_name_${u.uid}', user!.name!);
    });
  }

  Future<void> _setKeep(bool keep) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keepKey, keep);
  }

  // ---------------------------------------------------------------- nomes

  /// "Ash  Ketchum", "ash ketchum" e "Ásh Ketchum" são o mesmo nome.
  static String nameKey(String name) {
    const accents = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
    const plain = 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN';
    final buffer = StringBuffer();
    for (final ch in name.trim().split('')) {
      final i = accents.indexOf(ch);
      buffer.write(i >= 0 ? plain[i] : ch);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  static String cleanName(String name) => name.trim().replaceAll(RegExp(r'\s+'), ' ');

  static String? validateName(String name) {
    final clean = cleanName(name);
    if (clean.length < nameMin) return 'O nome precisa ter pelo menos $nameMin letras.';
    if (clean.length > nameMax) return 'O nome pode ter no máximo $nameMax letras.';
    if (!RegExp(r'^[\p{L}\p{N} _.-]+$', unicode: true).hasMatch(clean)) {
      return 'Use só letras, números, espaço, ponto, - ou _.';
    }
    return null;
  }

  Future<bool> isNameAvailable(String name) async {
    final snap = await _db.collection('usernames').doc(nameKey(name)).get();
    return !snap.exists || snap.data()?['uid'] == _auth.currentUser?.uid;
  }

  Future<String> _claimName(User u, String name) async {
    final clean = cleanName(name);
    final nameRef = _db.collection('usernames').doc(nameKey(clean));
    final userRef = _db.collection('users').doc(u.uid);
    await _db.runTransaction((tx) async {
      final taken = await tx.get(nameRef);
      if (taken.exists && taken.data()?['uid'] != u.uid) throw AuthException(_messages['name-taken']!);
      tx.set(nameRef, {'uid': u.uid, 'name': clean});
      tx.set(userRef, {'name': clean, 'email': u.email ?? '', 'createdAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
    });
    return clean;
  }

  // ---------------------------------------------------------------- ações

  Future<void> signUp({required String name, required String email, required String password, required bool keep}) =>
      _guard(() async {
        final error = validateName(name);
        if (error != null) throw AuthException(error);
        if (!await isNameAvailable(name)) throw AuthException(_messages['name-taken']!);
        await _setKeep(keep);
        _signingUp = true;
        User? u;
        try {
          u = (await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password)).user!;
          final clean = await _claimName(u, name);
          await u.updateDisplayName(clean);
          _set(AuthStatus.signedIn, AccountUser(uid: u.uid, email: u.email, name: clean));
        } catch (e) {
          // Alguém pegou o nome no mesmo instante: desfaz a conta criada.
          await u?.delete().catchError((_) {});
          _set(AuthStatus.signedOut);
          rethrow;
        } finally {
          _signingUp = false;
        }
      });

  Future<void> signIn({required String email, required String password, required bool keep}) => _guard(() async {
        await _setKeep(keep);
        await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      });

  Future<void> signInWithGoogle({required bool keep}) => _guard(() async {
        await _setKeep(keep);
        final provider = GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});
        if (kIsWeb) {
          await _auth.signInWithPopup(provider);
          return;
        }
        // No celular: janela nativa do Google para escolher a conta (sem abrir
        // o navegador, que em muitos Android não volta direito para o app).
        final google = GoogleSignIn.instance;
        try {
          if (!_googleReady) {
            await google.initialize(); // usa o ID do google-services.json
            _googleReady = true;
          }
          final account = await google.authenticate();
          final idToken = account.authentication.idToken;
          if (idToken == null) throw AuthException('O Google não devolveu a conta. Tente de novo.');
          await _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
        } on GoogleSignInException catch (e) {
          if (e.code == GoogleSignInExceptionCode.canceled) {
            throw AuthException('O login com Google foi cancelado.');
          }
          if (e.code == GoogleSignInExceptionCode.clientConfigurationError ||
              e.code == GoogleSignInExceptionCode.providerConfigurationError) {
            // Sem a configuração do login nativo: usa o login pelo navegador.
            await _auth.signInWithProvider(provider);
            return;
          }
          throw AuthException('Não foi possível entrar com Google (${e.code.name}). Tente de novo.');
        }
      });

  /// Primeiro login com Google: a pessoa escolhe o nome dela.
  Future<void> chooseName(String name) => _guard(() async {
        final error = validateName(name);
        if (error != null) throw AuthException(error);
        final u = _auth.currentUser!;
        final clean = await _claimName(u, name);
        await u.updateDisplayName(clean).catchError((_) {});
        _set(AuthStatus.signedIn, (user ?? AccountUser(uid: u.uid, email: u.email)).withName(clean));
      });

  Future<void> resetPassword(String email) => _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  Future<void> signOut() async {
    // Também sai da conta Google, para poder escolher outra na próxima vez.
    if (!kIsWeb && _googleReady) await GoogleSignIn.instance.signOut().catchError((_) {});
    await _auth.signOut();
  }

  // ---------------------------------------------------------------- erros

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messages['auth/${e.code}'] ?? 'Algo deu errado (${e.code}). Tente de novo.');
    } on FirebaseException catch (e) {
      throw AuthException(_messages[e.code] ?? 'Algo deu errado. Tente de novo.');
    }
  }

  static const _messages = {
    'name-taken': 'Esse nome já está sendo usado. Escolha outro.',
    'auth/invalid-email': 'E-mail inválido.',
    'auth/missing-email': 'Digite o seu e-mail.',
    'auth/missing-password': 'Digite a sua senha.',
    'auth/email-already-in-use': 'Já existe uma conta com esse e-mail.',
    'auth/weak-password': 'A senha precisa ter pelo menos 6 caracteres.',
    'auth/invalid-credential': 'E-mail ou senha incorretos.',
    'auth/wrong-password': 'E-mail ou senha incorretos.',
    'auth/user-not-found': 'E-mail ou senha incorretos.',
    'auth/user-disabled': 'Essa conta foi desativada.',
    'auth/too-many-requests': 'Muitas tentativas. Espere um pouco e tente de novo.',
    'auth/network-request-failed': 'Sem conexão com a internet.',
    'auth/web-context-canceled': 'O login com Google foi cancelado.',
    'auth/popup-closed-by-user': 'A janela do Google foi fechada antes de terminar.',
    'auth/operation-not-allowed': 'Esse tipo de login não está ativado no Firebase.',
    'permission-denied': 'Sem permissão no banco de dados. Confira as regras do Firestore.',
    'unavailable': 'Sem conexão com a internet.',
  };
}
