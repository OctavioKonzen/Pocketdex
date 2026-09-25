# 📱 Pocketdex

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter&style=for-the-badge" />
  <img src="https://img.shields.io/badge/React-19-61DAFB?logo=react&style=for-the-badge" />
  <img src="https://img.shields.io/badge/Firebase-FFCA28?logo=firebase&style=for-the-badge" />
  <img src="https://img.shields.io/badge/Android-1.1.4-green?logo=android&style=for-the-badge" />
</p>

<div align="center">
  <h3>Sua Enciclopédia Pokémon e Assistente Competitivo</h3>
  <p>App Android e site ligados pela mesma conta.</p>
  <p>🌐 <a href="https://octaviokonzen.github.io/Pocketdex/"><b>Abrir o site</b></a> · 📥 <a href="https://github.com/OctavioKonzen/Pocketdex/releases"><b>Baixar o APK</b></a></p>
</div>

---

## 📸 Screenshots

<p align="center">
  <img src="docs/screenshots/app_pokedex.jpg" width="200" title="Pokédex" />
  <img src="docs/screenshots/app_detalhes.jpg" width="200" title="Detalhes" />
  <img src="docs/screenshots/app_times.jpg" width="200" title="Montador de Times" />
  <img src="docs/screenshots/app_jogo.jpg" width="200" title="Jogo e Ranking" />
</p>
<p align="center">
  <img src="docs/screenshots/site_ranked.jpg" width="410" title="Site — Ranked" />
  <img src="docs/screenshots/site_times.jpg" width="410" title="Site — Times" />
</p>

---

## ✨ O que tem no projeto

* **Pokédex:** todos os Pokémon e formas (Mega, Alola, Galar...), com filtros por geração e tipo e detalhes completos: status, habilidades, evoluções e golpes.
* **Favoritos:** guarde os Pokémon que você mais usa.
* **Montador de Times:** monte times de até 6 Pokémon e veja fraquezas, resistências e a nota do time.
* **Jogo "Quem é esse Pokémon?":** modo normal e modo **Ranked** (5 segundos por Pokémon, caindo até 2 conforme os pontos), com ranking entre os jogadores.
* **Enciclopédia:** golpes, habilidades e itens.
* **Treino:** guia de Natures, ajuda de Breeding e contador de EVs.
* **Conta:** login com e-mail/senha ou Google; favoritos, times, treinos e recordes ficam salvos e sincronizados entre o app e o site.
* **Tema claro e escuro** e **atualização pelo próprio app**.

## 🛠️ Ferramentas usadas

| Parte | Ferramentas |
|---|---|
| **App (Android)** | Flutter / Dart, Provider |
| **Site** | React, Vite, Tailwind CSS, Framer Motion, React Router, Zustand |
| **Conta e dados online** | Firebase Authentication e Firestore |
| **Banco de dados local** | JSON e imagens em `assets/database/`, gerados com Python a partir da PokeAPI |
| **Publicação** | GitHub Actions (site no GitHub Pages e APK em Releases) |

## 📥 Como usar

* **Site:** https://octaviokonzen.github.io/Pocketdex/
* **App:** no site, clique em **Baixar app** (ou vá em [Releases](https://github.com/OctavioKonzen/Pocketdex/releases)), instale o `PocketDex.apk` e entre com a mesma conta do site.

## 🚀 Como rodar o código

```bash
git clone https://github.com/OctavioKonzen/Pocketdex.git
cd Pocketdex

# App
flutter pub get
flutter run

# Site
cd web-site
npm install
npm run data
npm run dev
```

Detalhes técnicos (Firebase, publicação de versões, banco de dados): [docs/DESENVOLVIMENTO.md](docs/DESENVOLVIMENTO.md).
