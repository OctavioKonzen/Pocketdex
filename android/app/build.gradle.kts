import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.octaviokonzen.pocketdex"
    compileSdk = flutter.compileSdkVersion

    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.octaviokonzen.pocketdex"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Assinatura fixa das versões publicadas: o Android só instala uma
    // atualização por cima se ela vier assinada com a MESMA chave. A chave
    // vem de android/key.properties (no PC) ou das variáveis ANDROID_* (no
    // GitHub Actions). Sem ela, usa a chave de debug.
    val keyProps = Properties().apply {
        val file = rootProject.file("key.properties")
        if (file.exists()) file.inputStream().use { load(it) }
    }
    fun key(name: String, env: String): String? = keyProps.getProperty(name) ?: System.getenv(env)
    val storeFilePath = key("storeFile", "ANDROID_KEYSTORE_PATH")

    signingConfigs {
        if (storeFilePath != null) {
            create("release") {
                storeFile = file(storeFilePath)
                storePassword = key("storePassword", "ANDROID_KEYSTORE_PASSWORD")
                keyAlias = key("keyAlias", "ANDROID_KEY_ALIAS")
                keyPassword = key("keyPassword", "ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// Firebase (login e dados da conta): o arquivo google-services.json vem do
// Console do Firebase (app Android com.octaviokonzen.pocketdex). Sem ele o
// app compila e funciona sem login.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}