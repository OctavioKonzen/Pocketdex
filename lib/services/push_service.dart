// lib/services/push_service.dart
//
// Notificações no celular (push): pedido de amizade, mensagem no chat,
// desafio, convite para batalha online e draft. Quem manda é o servidor
// (tool/notify/notify.mjs, rodado pelo GitHub a cada 10 minutos); aqui o app
// guarda o endereço deste aparelho na conta (pushTokens/{uid}) e, com o app
// aberto, mostra o aviso (com o app fechado o próprio Android mostra).
// Liga e desliga nas Configurações (só neste aparelho).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/i18n.dart';
import 'auth_service.dart';

class PushService {
  PushService._();
  static final instance = PushService._();

  static const _prefKey = 'pushNotifications';
  static const _channel = AndroidNotificationChannel('pocketdex', 'Amigos e batalhas',
      description: 'Pedidos de amizade, mensagens, desafios e convites', importance: Importance.high);

  final _local = FlutterLocalNotificationsPlugin();
  String? _uid, _token;
  bool _started = false;

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> get enabled async => (await SharedPreferences.getInstance()).getBool(_prefKey) ?? true;

  /// Ao abrir o app: acompanha a conta (entrou → guarda o aparelho; saiu → tira).
  void start() {
    if (!supported || _started) return;
    _started = true;
    AuthService.instance.addListener(_onAuth);
    _onAuth();
  }

  Future<void> _onAuth() async {
    final uid = AuthService.instance.status == AuthStatus.signedIn ? AuthService.instance.user?.uid : null;
    if (uid == _uid) return;
    final old = _uid;
    _uid = uid;
    try {
      if (old != null && _token != null) await _remove(old, _token!);
      if (uid != null && await enabled) await _register(uid);
    } catch (_) {
      // Sem push (ex.: sem Google Play): o app continua.
    }
  }

  Future<void> _register(String uid) async {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;
    await _local.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(_channel);
    final token = await messaging.getToken();
    if (token == null) return;
    _token = token;
    await _save(uid, token);
    messaging.onTokenRefresh.listen((t) {
      _token = t;
      if (_uid != null) _save(_uid!, t);
    });
    // Com o app aberto o Android não mostra sozinho: mostra aqui.
    FirebaseMessaging.onMessage.listen((message) {
      final n = message.notification;
      if (n == null) return;
      _local.show(
        id: message.hashCode & 0x7fffffff,
        title: n.title,
        body: n.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(_channel.id, _channel.name, channelDescription: _channel.description, importance: Importance.high, priority: Priority.high),
        ),
      );
    });
  }

  Future<void> _save(String uid, String token) => FirebaseFirestore.instance.doc('pushTokens/$uid').set({
        'tokens': FieldValue.arrayUnion([token]),
        'lang': ['pt', 'en', 'fr', 'es'].contains(I18n.language) ? I18n.language : 'pt',
      }, SetOptions(merge: true));

  Future<void> _remove(String uid, String token) =>
      FirebaseFirestore.instance.doc('pushTokens/$uid').set({'tokens': FieldValue.arrayRemove([token])}, SetOptions(merge: true));

  /// Liga ou desliga (Configurações). Devolve false se a permissão for negada.
  Future<bool> setEnabled(bool on) async {
    await (await SharedPreferences.getInstance()).setBool(_prefKey, on);
    final uid = _uid;
    if (uid == null) return true;
    try {
      if (on) {
        await _register(uid);
        return _token != null;
      }
      if (_token != null) await _remove(uid, _token!);
      await FirebaseMessaging.instance.deleteToken();
      _token = null;
    } catch (_) {
      return false;
    }
    return true;
  }
}
