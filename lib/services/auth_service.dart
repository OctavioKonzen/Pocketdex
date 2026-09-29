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

import '../utils/profanity.dart';

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
      // Conta que já existe entra direto: se a leitura do perfil falhar (rede
      // instável), tenta de novo em vez de achar que é uma conta nova.
      for (var attempt = 0; _auth.currentUser?.uid == u.uid; attempt++) {
        try {
          final profile = await _db.collection('users').doc(u.uid).get();
          final name = profile.data()?['name'] as String?;
          _set(name == null ? AuthStatus.needsName : AuthStatus.signedIn, name == null ? base : base.withName(name));
          break;
        } catch (_) {
          // Sem internet: entra com o nome salvo no aparelho (ou no login).
          final display = u.displayName;
          final known = prefs.getString('auth_name_${u.uid}') ??
              (display != null && validateName(display) == null ? display : null);
          if (known != null) {
            _set(AuthStatus.signedIn, base.withName(known));
            break;
          }
          await Future<void>.delayed(Duration(seconds: attempt < 4 ? attempt + 1 : 5));
        }
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
    if (isOffensive(clean)) return 'Esse nome não é permitido. Escolha outro.';
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
      // Nome de outra pessoa: as regras só deixam pegar se a conta dela foi
      // excluída (senão a gravação é recusada e o nome continua dela).
      await tx.get(nameRef);
      tx.set(nameRef, {'uid': u.uid, 'name': clean});
      tx.set(userRef, {'name': clean, 'nameKey': nameKey(clean), 'email': u.email ?? '', 'createdAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
    }).catchError((Object e) {
      if (e is FirebaseException && e.code == 'permission-denied') throw AuthException(_messages['name-taken']!);
      throw e;
    });
    return clean;
  }

  // ---------------------------------------------------------------- ações

  Future<void> signUp({required String name, required String email, required String password, required bool keep}) =>
      _guard(() async {
        final error = validateName(name);
        if (error != null) throw AuthException(error);
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

  // ---------------------------------------------------------------- confirmações
  //   Conta com e-mail e senha: trocar a senha e excluir pedem a senha atual.
  //   Conta Google: entra direto (o Google já confirmou o e-mail); criar/trocar
  //   a senha e excluir pedem que a
  //   pessoa abra um link mandado para o e-mail. O link abre o site, que
  //   confirma e grava em confirmations/{uid} (igual ao site).

  static const _siteUrl = 'https://octaviokonzen.github.io/Pocketdex/';

  /// Troca a senha de uma conta com e-mail e senha (confirma a senha atual).
  Future<void> changePassword({required String current, required String password}) => _guard(() async {
        if (password.length < 6) throw AuthException('A senha precisa ter pelo menos 6 caracteres.');
        final u = _auth.currentUser!;
        await u.reauthenticateWithCredential(EmailAuthProvider.credential(email: u.email ?? '', password: current));
        await u.updatePassword(password);
      });

  /// Manda o link de confirmação: purpose 'signup' | 'password' | 'delete'.
  Future<void> sendConfirmationLink(String purpose) => _guard(() async {
        final email = _auth.currentUser?.email;
        if (email == null) throw AuthException('Essa conta não tem e-mail.');
        await _auth.sendSignInLinkToEmail(
          email: email,
          actionCodeSettings: ActionCodeSettings(url: '$_siteUrl?confirmar=$purpose', handleCodeInApp: true),
        );
      });

  /// A pessoa já abriu o link de confirmação?
  Future<bool> hasConfirmation(String purpose) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    try {
      final snap = await _db.collection('confirmations').doc(uid).get(const GetOptions(source: Source.server));
      return snap.data()?[purpose] != null;
    } catch (_) {
      return false;
    }
  }

  /// Depois de confirmar a exclusão no site: a conta ainda existe? Se não,
  /// sai dela aqui também.
  Future<bool> accountStillExists() async {
    final u = _auth.currentUser;
    if (u == null) return false;
    try {
      await u.reload();
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'user-disabled' || e.code == 'user-token-expired') {
        await forgetAccount();
        return false;
      }
      return true;
    }
  }

  /// A conta foi excluída em outro lugar: sai dela sem deixar nada no aparelho.
  Future<void> forgetAccount() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((k) => k.startsWith('auth_') && k != _keepKey)) {
      await prefs.remove(key);
    }
    await signOut().catchError((_) {});
  }

  // ---------------------------------------------------------------- excluir conta

  /// A conta entrou com Google (e não com e-mail e senha)?
  bool get usesGoogle => _auth.currentUser?.providerData.any((p) => p.providerId == 'google.com') ?? false;

  /// Apaga a conta e tudo dela: dados, nome reservado, rankings e o login.
  /// Por segurança o Firebase pede para confirmar a senha (ou a conta Google).
  Future<void> deleteAccount({String? password, List<String> weeks = const [], List<String> days = const []}) =>
      _guard(() async {
        final u = _auth.currentUser;
        if (u == null) return;
        if (usesGoogle) {
          if (kIsWeb) {
            await u.reauthenticateWithPopup(GoogleAuthProvider());
          } else {
            final google = GoogleSignIn.instance;
            if (!_googleReady) {
              await google.initialize();
              _googleReady = true;
            }
            try {
              final account = await google.authenticate();
              final idToken = account.authentication.idToken;
              if (idToken == null) throw AuthException('O Google não devolveu a conta. Tente de novo.');
              await u.reauthenticateWithCredential(GoogleAuthProvider.credential(idToken: idToken));
            } on GoogleSignInException catch (e) {
              if (e.code == GoogleSignInExceptionCode.canceled) throw AuthException('A confirmação com Google foi cancelada.');
              rethrow;
            }
          }
        } else {
          await u.reauthenticateWithCredential(EmailAuthProvider.credential(email: u.email ?? '', password: password ?? ''));
        }
        final uid = u.uid;
        final profile = await _db.collection('users').doc(uid).get();
        final name = profile.data()?['name'] as String?;
        final keys = {
          if (profile.data()?['nameKey'] is String) profile.data()!['nameKey'] as String,
          if (name != null) nameKey(name),
        };
        Future<void> quiet(Future<void> f) => f.catchError((_) {});

        // Times públicos: os da pessoa somem inteiros (com votos e denúncias);
        // nos dos outros, o voto e a denúncia dela saem (a nota e a contagem voltam).
        QuerySnapshot<Map<String, dynamic>>? teams;
        try {
          teams = await _db.collection('publicTeams').get();
        } catch (_) {}
        for (final team in teams?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
          if (team.data()['ownerUid'] == uid) {
            for (final sub in const ['ratings', 'reports']) {
              try {
                final docs = await team.reference.collection(sub).get();
                await Future.wait(docs.docs.map((d) => quiet(d.reference.delete())));
              } catch (_) {}
            }
            await quiet(team.reference.delete());
          } else {
            try {
              final vote = await team.reference.collection('ratings').doc(uid).get();
              final stars = (vote.data()?['stars'] as num?)?.toInt();
              if (vote.exists && stars != null) {
                final batch = _db.batch()
                  ..update(team.reference, {'ratingSum': FieldValue.increment(-stars), 'ratingCount': FieldValue.increment(-1)})
                  ..delete(vote.reference);
                await quiet(batch.commit());
              }
            } catch (_) {}
            try {
              final report = await team.reference.collection('reports').doc(uid).get();
              if (report.exists) {
                final batch = _db.batch()
                  ..update(team.reference, {'reportCount': FieldValue.increment(-1)})
                  ..delete(report.reference);
                await quiet(batch.commit());
              }
            } catch (_) {}
          }
        }

        // Nome reservado e rankings: o geral e todas as semanas e dias desde
        // que os rankings existem.
        await Future.wait(keys.map((k) => quiet(_db.collection('usernames').doc(k).delete())));
        final refs = <DocumentReference>[_db.collection('ranking').doc(uid)];
        for (final key in {..._boardKeys(), ...weeks, ...days}) {
          refs
            ..add(_db.collection('weekly').doc(key).collection('scores').doc(uid))
            ..add(_db.collection('daily').doc(key).collection('scores').doc(uid));
        }
        for (var i = 0; i < refs.length; i += 400) {
          final part = refs.sublist(i, i + 400 > refs.length ? refs.length : i + 400);
          final batch = _db.batch();
          for (final ref in part) {
            batch.delete(ref);
          }
          try {
            await batch.commit();
          } catch (_) {
            await Future.wait(part.map((ref) => quiet(ref.delete())));
          }
        }

        await quiet(_db.collection('confirmations').doc(uid).delete());
        await _db.collection('users').doc(uid).delete();
        await u.delete();
        final prefs = await SharedPreferences.getInstance();
        for (final key in prefs.getKeys().where((k) => k.startsWith('auth_'))) {
          await prefs.remove(key);
        }
        if (!kIsWeb && _googleReady) await GoogleSignIn.instance.signOut().catchError((_) {});
      });

  /// Todos os dias desde o começo dos rankings (semana e dia usam "AAAA-MM-DD").
  static List<String> _boardKeys() {
    final end = DateTime.now().toUtc().add(const Duration(days: 2));
    return [
      for (var d = DateTime.utc(2026, 9, 20); !d.isAfter(end); d = d.add(const Duration(days: 1)))
        d.toIso8601String().substring(0, 10),
    ];
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
    'auth/requires-recent-login': 'Por segurança, saia e entre de novo na conta e tente outra vez.',
    'auth/user-mismatch': 'Escolha a mesma conta Google que está conectada.',
    'permission-denied': 'Sem permissão no banco de dados. Confira as regras do Firestore.',
    'unavailable': 'Sem conexão com a internet.',
  };
}
