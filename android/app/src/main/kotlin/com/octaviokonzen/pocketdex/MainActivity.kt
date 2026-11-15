package com.octaviokonzen.pocketdex

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Links do site (time compartilhado, replay, desafio do quiz) abertos no app:
// o Flutter pede o link que abriu o app e recebe os que chegam com ele aberto
// (lib/services/deep_links.dart).
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var initialLink: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        initialLink = intent?.takeIf { it.action == Intent.ACTION_VIEW }?.dataString
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pocketdex/links").apply {
            setMethodCallHandler { call, result ->
                if (call.method == "initialLink") {
                    result.success(initialLink)
                    initialLink = null
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.action == Intent.ACTION_VIEW) intent.dataString?.let { channel?.invokeMethod("link", it) }
    }
}
