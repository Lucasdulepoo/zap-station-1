# Assinatura do APK de release

Sem `android/key.properties`, o build de release é assinado com a chave de **debug** (o Gradle emite um aviso).
Esse APK serve para testar no seu aparelho — **não distribua**.

## Criar a chave (uma vez)
```bash
keytool -genkey -v -keystore ~/zap-station-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias zapstation
```
Guarde o arquivo `.jks` e as senhas em um cofre. **Perder a chave = não conseguir atualizar o app.**

## Configurar
Crie `android/key.properties` (ignorado pelo Git):
```properties
storeFile=/caminho/absoluto/zap-station-release.jks
storePassword=...
keyAlias=zapstation
keyPassword=...
```
Depois: `flutter build apk --release --dart-define=...`.
Para a Play Store use `flutter build appbundle` e ative o Play App Signing.
