# Gerar o APK de teste (sem instalar nada no computador)

O APK é compilado no GitHub Actions. Você só precisa de uma conta no GitHub.

1. Crie um repositório **privado** vazio no GitHub (ex.: `zap-station`).
2. Envie este projeto:
   ```bash
   git remote add origin https://github.com/SEU-USUARIO/zap-station.git
   git push -u origin main
   ```
3. No GitHub: aba **Actions** → **Build APK de teste** → **Run workflow** (também roda sozinho a cada push).
4. Quando terminar, abra a execução e baixe **zap-station-debug-apk** em *Artifacts* (vem em .zip; dentro está `app-debug.apk`).
5. Passe o `app-debug.apk` para o celular e instale (o Android pedirá para permitir "instalar apps desconhecidos" para o app que você usou para abrir o arquivo).

## Conectar ao servidor (opcional, necessário para o login funcionar)
Em *Settings → Secrets and variables → Actions* crie `SUPABASE_URL` e `SUPABASE_ANON_KEY` (somente a chave **anon**) e rode o workflow de novo.
Sem eles o APK abre normalmente, mostra "servidor não configurado" e não envia SMS.

## O que esperar do APK
Splash, tela de telefone (seleção de país e validação), tela de OTP, perfil, navegação inferior e as abas
"em breve". Mensagens, grupos, chamadas e mídia ainda não existem (Fases 3–7).

## Se a compilação falhar
É provável na primeira vez: o código Dart e as versões do Gradle/Kotlin nunca foram compilados. Abra o log do passo que
falhou e me envie o trecho do erro — corrijo e você roda de novo. O APK é gerado antes de `analyze` e `test`, então uma falha
em teste não impede o download.
