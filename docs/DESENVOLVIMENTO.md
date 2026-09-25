# 🛠️ Desenvolvimento

Detalhes técnicos do PocketDex (app, site, conta e banco de dados). Para uma visão geral, veja o [README](../README.md).

---

## 🚀 Rodar o App

```bash
# Clone o repositório
git clone https://github.com/OctavioKonzen/Pocketdex.git

# Instale as dependências
flutter pub get

# Execute o app
flutter run

# Testes do app
flutter test
```

Sem o `google-services.json` o app abre normalmente, só que sem login. Para rodar o site, veja a seção **Site** abaixo.

---

## 🌐 Site (JavaScript + Python)

O site fica em `web-site/` e foi feito em **JavaScript** com **React**, usando as ferramentas:

* **Vite** (build e servidor de desenvolvimento), **Tailwind CSS** (estilo), **Framer Motion** (animações),
  **React Router** (páginas), **Zustand** (dados salvos no navegador), **Vitest** (testes) e **oxlint** (lint).
* **Python** (`tool/build_web_data.py`) gera os dados do site a partir do banco local: divide o banco em arquivos
  menores (um por Pokémon) e copia as imagens, para cada página baixar só o que precisa.

Tem todas as funcionalidades do app, com o mesmo visual adaptado para o PC: menu fixo no topo com a Pokédex como
página principal (6 cards por linha, detalhes abrindo na própria página com o Pokémon saindo da Pokébola),
Favoritos, Montador de Times com análise, Jogo com Ranked e ranking, Enciclopédia de golpes, habilidades e itens,
Natures, Breeding, Contador de EVs, Configurações (tema claro/escuro e conta) e o download do app para Android.
Funciona no PC e no celular.

```bash
cd web-site
npm install
npm run data     # gera os dados (Python)
npm run dev      # abre o site em modo desenvolvimento
npm test         # testes
npm run build    # gera o site final em web-site/dist
```

O deploy é automático: a cada push na `main`, o workflow `.github/workflows/deploy-web.yml` gera os dados, roda
lint e testes, faz o build e publica no **GitHub Pages**: **https://octaviokonzen.github.io/Pocketdex/**

---

## 🔐 Login e Conta (Firebase)

O app e o site usam o **mesmo projeto do Firebase** (`pocketdex-ffb4d`):

* **Authentication:** e-mail e senha ou Google. O "Manter conectado" guarda a sessão; desmarcado, ela termina ao
  fechar o app ou a aba.
* **Firestore:**
  * `users/{uid}` — nome, chave do nome, e-mail e os dados da conta (`data`: favoritos, times, treinos, tema,
    recordes, jogo salvo, foto de perfil e contadores das conquistas).
  * `usernames/{nome}` — reserva de nomes; o nome é comparado sem maiúsculas, acentos e espaços extras.
  * `ranking/{uid}` — recorde do Ranked de cada jogador (com a foto de perfil).
  * `weekly/{segunda}/scores/{uid}` — melhor Ranked da semana.
  * `daily/{dia}/scores/{uid}` — resultado do desafio do dia (uma tentativa por dia).
  * `publicTeams/{teamId}` — cópia pública de cada time (dono, nome, cor, Pokémon e a nota da comunidade:
    `ratingSum` / `ratingCount`); some quando o dono exclui o time. Os votos ficam em
    `publicTeams/{teamId}/ratings/{uid}` (1 a 5 estrelas) e só mudam junto com a nota do time.
* **Regras:** em `firestore.rules` — cada pessoa só lê e escreve os próprios dados; os rankings são visíveis para
  quem está logado; o nome usado nos rankings precisa ser um nome reservado para a própria pessoa; a lista de nomes
  não pode ser baixada inteira. Os testes das regras ficam em `firestore-tests/` (`npm ci && npm test`, usa o
  emulador do Firebase e precisa de Java).
* **Pix:** a chave, o nome e a cidade ficam em `lib/services/pix.dart` (app) e `web-site/src/lib/pix.js` (site);
  vazio, o cartão "Apoie o PocketDex" não aparece.
* **Desafio do dia:** os 10 Pokémon saem de um sorteio com semente = data (horário de Brasília), igual no app
  (`lib/services/league.dart`) e no site (`web-site/src/lib/league.js`).
* **Sincronização:** app (`lib/services/account_sync.dart`) e site (`web-site/src/lib/sync.js`) ouvem a conta em
  tempo real e gravam só os campos que mudaram, no mesmo formato, para um não sobrescrever o outro.

Enquanto o Firebase não estiver configurado, o app e o site funcionam sem login. Para configurar do zero:

1. Crie um projeto em https://console.firebase.google.com e adicione um **App da Web** e um **App Android**
   (`com.octaviokonzen.pocketdex`, com a impressão digital SHA-1 da chave de assinatura).
2. **Authentication → Método de login**: ative **E-mail/senha** e **Google**.
3. **Authentication → Configurações → Domínios autorizados**: adicione `octaviokonzen.github.io`.
4. **Firestore Database**: crie o banco e, em **Regras**, cole o conteúdo de `firestore.rules`.
5. Coloque a configuração do app da web em `web-site/src/lib/firebaseConfig.js` e o `google-services.json` do app
   Android nos secrets do GitHub (veja **Publicar uma versão nova do app**, abaixo).

---

## 🗄️ Banco de Dados

O app não consulta mais a PokeAPI nem baixa imagens da internet: tudo fica em `assets/database/`.

* **Dados (JSON, ~7 MB):** todos os Pokémon e formas (inclusive Mega, Gigantamax, regionais e formas cosméticas como Unown A–Z),
  espécies, cadeias de evolução, todos os golpes (com todas as formas de aprendizado), habilidades, itens, tipos, egg groups e gerações.
* **Imagens (~67 MB):** sprites normais e shiny, artes oficiais normais e shiny de todas as formas (em WebP, na resolução original)
  e os ícones dos itens.
* **Recorte dos sprites:** `sprite_boxes.json` diz onde cada Pokémon fica dentro do sprite, para todos aparecerem
  com o mesmo tamanho (gerado por `tool/build_sprite_boxes.py`).

Tudo é gerado pelo script `tool/build_database.py` a partir dos dumps estáticos da PokeAPI. Para atualizar (ex.: novos Pokémon):

```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/PokeAPI/api-data.git
cd api-data && git sparse-checkout set data/api/v2/pokemon data/api/v2/pokemon-species \
    data/api/v2/evolution-chain data/api/v2/move data/api/v2/type data/api/v2/ability \
    data/api/v2/item data/api/v2/egg-group data/api/v2/generation data/api/v2/pokemon-form && cd ..

git clone --depth 1 --filter=blob:none --sparse https://github.com/PokeAPI/sprites.git
cd sprites && git sparse-checkout set --no-cone '/sprites/pokemon/*.png' '/sprites/pokemon/shiny/*.png' \
    '/sprites/pokemon/other/official-artwork/*.png' '/sprites/pokemon/other/official-artwork/shiny/*.png' \
    '/sprites/items/*.png' && cd ..

pip install pillow
python3 tool/build_database.py api-data sprites
python3 tool/build_sprite_boxes.py
```

Outros scripts em `tool/`: `build_app_icon.py` gera o ícone do app a partir da logo e `shrink_app_images.py` reduz
as artes só para o APK.

---

## 📦 Publicar uma versão nova do app

Aumente a versão em `pubspec.yaml` (ex.: `1.1.0+2` → `1.2.0+3`) e mande para a `main`. O workflow
`.github/workflows/android-release.yml` gera o APK assinado e publica em Releases. Ele precisa destes secrets
(**Settings → Secrets and variables → Actions**):

| Secret | O que é |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | chave de assinatura (`.jks`) em base64 — sempre a mesma, senão o Android não instala a atualização |
| `ANDROID_KEYSTORE_PASSWORD` / `ANDROID_KEY_PASSWORD` | senhas da chave |
| `ANDROID_KEY_ALIAS` | apelido da chave |
| `GOOGLE_SERVICES_JSON` | conteúdo do `google-services.json` do app Android no Firebase (`com.octaviokonzen.pocketdex`) |

Sem os secrets o workflow gera o APK só como teste (confere que o app compila) e não publica. No APK as artes
oficiais são reduzidas para 320 px (`tool/shrink_app_images.py`) e só entram as bibliotecas ARM, para ele ficar menor.

Para compilar no PC com login, coloque o `google-services.json` em `android/app/` (e, para gerar a versão
assinada, um `android/key.properties` com `storeFile`, `storePassword`, `keyAlias` e `keyPassword`). Os dois ficam
fora do git.
