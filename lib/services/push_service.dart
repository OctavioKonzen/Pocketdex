// lib/services/push_service.dart
//
// Notificações no celular (push): pedido de amizade, mensagem no chat,
// desafio, convite para batalha online e draft. Quem manda é o servidor
// (tool/notify/notify.mjs, rodado pelo GitHub a cada 10 minutos); aqui o app
// guarda o endereço deste aparelho na conta (pushTokens/{uid}) e, com o app
// aberto, mostra o aviso (com o app fechado o próprio Android mostra).
// Liga e desliga nas Configurações (só neste aparelho).

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/i18n.dart';
import '../screens/chat_screen.dart';
import '../screens/draft_screen.dart';
import '../screens/friends_screen.dart';
import '../screens/online_battle_screen.dart';
import '../screens/profile_screen.dart';
import '../widgets/chat_bubble.dart';
import 'auth_service.dart';
import 'friends_service.dart';

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
    // Tocando no aviso (com o app aberto): abre a tela dele.
    await _local.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (r) {
        if (r.payload != null) open(Map<String, dynamic>.from(json.decode(r.payload!) as Map));
      },
    );
    // Tocando no aviso com o app no fundo ou fechado.
    FirebaseMessaging.onMessageOpenedApp.listen((m) => open(m.data));
    final first = await messaging.getInitialMessage();
    if (first != null) open(first.data);
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
        payload: json.encode(message.data),
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

  /// A tela de cada aviso (data do servidor, tool/notify/notify.mjs): o chat do amigo, os amigos, a batalha online, o
  /// draft ou o seu perfil (os duelos contra a sua defesa). null: nenhuma.
  static Widget? screenFor(Map<String, dynamic> data, {List<Friend> friends = const [], String? me}) {
    switch (data['screen']) {
      case 'chat':
        final friend = friends.where((f) => f.uid == data['uid']).firstOrNull;
        return friend != null ? ChatScreen(friend: friend) : const FriendsScreen();
      case 'friends':
        return const FriendsScreen();
      case 'online':
        return const OnlineBattleScreen();
      case 'draft':
        final id = data['draft'];
        return id is String && id.isNotEmpty ? DraftScreen(draftId: id) : const OnlineBattleScreen();
      case 'profile':
        return me == null ? null : ProfileScreen(uid: me, mine: true);
    }
    return null;
  }

  /// Abre a tela do aviso (espera o app terminar de abrir).
  void open(Map<String, dynamic> data, [int tries = 0]) {
    final nav = ChatBubble.instance.navigatorKey.currentState;
    if (nav == null) {
      if (tries < 50) Future.delayed(const Duration(milliseconds: 200), () => open(data, tries + 1));
      return;
    }
    final screen = screenFor(data, friends: FriendsService.instance.friends, me: AuthService.instance.user?.uid);
    if (screen != null) nav.push(MaterialPageRoute(builder: (_) => screen));
  }

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
