import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // O plugin do Flutter deve vir depois dos plugins Android e Kotlin.
    id("dev.flutter.flutter-gradle-plugin")
}

// Assinatura de release: android/key.properties (NUNCA versionado; veja docs/SIGNING.md).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.zapstation.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.zapstation.app"
        // Android 7.0+. WebRTC/LiveKit e FCM funcionam a partir daqui.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // Permite testar o APK de release localmente. NÃO distribua este APK:
                // ele é assinado com a chave de depuração.
                logger.warn("AVISO: android/key.properties ausente; release assinado com a chave de DEBUG.")
                signingConfig = signingConfigs.getByName("debug")
            }
            // Minificação/ofuscação ficam para a Fase 8 (exigem regras do WebRTC/LiveKit/Firebase).
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
