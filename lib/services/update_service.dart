// lib/services/update_service.dart
//
// Atualização do app pelo próprio app (Android, APK fora da Play Store).
// Ao abrir, confere a última versão publicada em GitHub Releases
// (github.com/OctavioKonzen/Pocketdex/releases). Se for mais nova que a
// instalada, baixa o APK sozinho em segundo plano e, quando termina, abre o
// instalador do Android (a confirmação final é sempre do Android).
//
// As versões são publicadas pelo workflow .github/workflows/android-release.yml
// sempre que a versão do pubspec.yaml muda.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppRelease {
  final String version; // "1.2.0"
  final String apkUrl;
  final String notes;
  const AppRelease(this.version, this.apkUrl, this.notes);
}

class UpdateService {
  UpdateService._();

  static const _latest = 'https://api.github.com/repos/OctavioKonzen/Pocketdex/releases/latest';
  static bool _checked = false;

  /// "1.10.0" > "1.9.2"
  static bool isNewer(String candidate, String current) {
    List<int> parts(String v) =>
        v.replaceFirst(RegExp('^v'), '').split('+').first.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final a = parts(candidate), b = parts(current);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  static Future<AppRelease?> latestRelease() async {
    final response = await http
        .get(Uri.parse(_latest), headers: {'Accept': 'application/vnd.github+json'})
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final apk = (json['assets'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .where((a) => (a['name'] as String).endsWith('.apk'))
        .firstOrNull;
    if (apk == null) return null;
    return AppRelease(
      (json['tag_name'] as String).replaceFirst(RegExp('^v'), ''),
      apk['browser_download_url'] as String,
      (json['body'] as String? ?? '').trim(),
    );
  }

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Confere uma vez por abertura do app; se houver versão nova, baixa sozinho.
  static Future<void> checkOnStart(BuildContext context) async {
    if (_checked || !supported) return;
    _checked = true;
    try {
      final info = await PackageInfo.fromPlatform();
      final release = await latestRelease();
      if (release == null || !isNewer(release.version, info.version)) return;
      if (!context.mounted) return;
      _downloadInBackground(context, release, info.version);
    } catch (_) {
      // Sem internet ou GitHub fora do ar: tenta na próxima abertura.
    }
  }

  /// Baixa sem janela; no fim o Android abre a tela de instalar a atualização.
  /// Se faltar a permissão de instalar apps, mostra o aviso com o botão.
  static void _downloadInBackground(BuildContext context, AppRelease release, String current) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    messenger?.showSnackBar(SnackBar(content: Text('Baixando a versão ${release.version} em segundo plano...')));
    OtaUpdate().execute(release.apkUrl, destinationFilename: 'pocketdex-${release.version}.apk').listen(
      (event) {
        if (event.status != OtaStatus.PERMISSION_NOT_GRANTED_ERROR) return;
        if (!navigator.mounted) return;
        showDialog(
          context: navigator.context,
          builder: (_) => _UpdateDialog(release: release, current: current),
        );
      },
      onError: (_) {
        // Falhou (internet caiu, etc.): tenta de novo na próxima abertura.
      },
    );
  }

  /// Botão "Procurar atualização" das Configurações.
  static Future<void> checkNow(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _check(context, quiet: false);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Não foi possível procurar agora. Confira a internet.')));
    }
  }

  static Future<void> _check(BuildContext context, {required bool quiet}) async {
    final info = await PackageInfo.fromPlatform();
    final release = await latestRelease();
    if (!context.mounted) return;
    if (release == null || !isNewer(release.version, info.version)) {
      if (!quiet) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Você já tem a versão mais recente (${info.version}).')),
        );
      }
      return;
    }
    await showDialog(context: context, builder: (_) => _UpdateDialog(release: release, current: info.version));
  }

  static Future<String> currentVersion() async => (await PackageInfo.fromPlatform()).version;
}

class _UpdateDialog extends StatefulWidget {
  final AppRelease release;
  final String current;
  const _UpdateDialog({required this.release, required this.current});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double? _progress;
  String? _error;

  void _update() {
    setState(() {
      _progress = 0;
      _error = null;
    });
    OtaUpdate()
        .execute(widget.release.apkUrl, destinationFilename: 'pocketdex-${widget.release.version}.apk')
        .listen(
      (event) {
        if (!mounted) return;
        switch (event.status) {
          case OtaStatus.DOWNLOADING:
            setState(() => _progress = (double.tryParse(event.value ?? '') ?? 0) / 100);
          case OtaStatus.INSTALLING:
          case OtaStatus.INSTALLATION_DONE:
            setState(() => _progress = 1);
          case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
            setState(() {
              _progress = null;
              _error = 'Permita que o PocketDex instale apps (o Android vai pedir) e tente de novo.';
            });
          default:
            setState(() {
              _progress = null;
              _error = 'Não foi possível baixar a atualização. Tente de novo.';
            });
        }
      },
      onError: (_) {
        if (mounted) {
          setState(() {
            _progress = null;
            _error = 'Não foi possível baixar a atualização. Tente de novo.';
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final downloading = _progress != null;
    return AlertDialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.system_update, color: Color(0xFFE53935)),
          SizedBox(width: 10),
          Expanded(child: Text('Nova versão disponível!')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Versão ${widget.release.version} (você tem a ${widget.current}).'),
          if (widget.release.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: Text(widget.release.notes, style: TextStyle(color: theme.hintColor)),
              ),
            ),
          ],
          if (downloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress == 0 ? null : _progress, color: const Color(0xFFE53935)),
            const SizedBox(height: 6),
            Text(_progress! >= 1 ? 'Abrindo o instalador...' : 'Baixando... ${(_progress! * 100).round()}%',
                style: TextStyle(fontSize: 12, color: theme.hintColor)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(downloading ? 'Fechar' : 'Depois'),
        ),
        ElevatedButton(
          onPressed: downloading ? null : _update,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white),
          child: const Text('Atualizar agora'),
        ),
      ],
    );
  }
}
