# Versões

**Nenhuma versão abaixo foi resolvida ou compilada** — o ambiente de desenvolvimento desta fase não alcançava
pub.dev nem o Maven do Google. São faixas escolhidas por conhecimento prévio; confirme na primeira execução.

| Item | Declarado | Onde |
|---|---|---|
| Dart SDK | `>=3.6.0 <4.0.0` | `pubspec.yaml` |
| flutter_riverpod | `^2.6.1` | `pubspec.yaml` |
| go_router | `^14.6.2` | `pubspec.yaml` |
| supabase_flutter | `^2.8.0` | `pubspec.yaml` |
| flutter_lints | `^5.0.0` | `pubspec.yaml` |
| Android Gradle Plugin | `8.7.3` | `android/settings.gradle.kts` |
| Kotlin | `2.1.0` | `android/settings.gradle.kts` |
| Gradle | `8.9` | `android/gradle/wrapper/gradle-wrapper.properties` |
| minSdk | 24 (Android 7.0) | `android/app/build.gradle.kts` |
| applicationId | `com.zapstation.app` (disponibilidade na Play Store **não verificada**) | `android/app/build.gradle.kts` |

## Procedimento
1. `flutter pub get`; se o resolvedor recusar uma faixa, ajuste e rode de novo.
2. `flutter build apk --debug`; se o Gradle recusar AGP/Kotlin/Gradle, alinhe com a tabela de compatibilidade do Flutter da sua versão.
3. Anote aqui as versões finais (`flutter pub deps --style=compact`, `flutter --version`) e faça commit do `pubspec.lock`.

Pacotes planejados (Fases 5–7, ainda **não** adicionados): `image_picker`, `file_picker`, `record`, `just_audio`, `permission_handler`,
`firebase_core`, `firebase_messaging`, `flutter_local_notifications`, `livekit_client`.
