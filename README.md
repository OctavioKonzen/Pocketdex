# 📱 Pocketdex

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter&style=for-the-badge" />
  <img src="https://img.shields.io/badge/React-19-61DAFB?logo=react&style=for-the-badge" />
  <img src="https://img.shields.io/badge/Firebase-FFCA28?logo=firebase&style=for-the-badge" />
  <img src="https://img.shields.io/badge/Android-0.7.1-green?logo=android&style=for-the-badge" />
</p>

<div align="center">
  <h3>Sua Enciclopédia Pokémon, Assistente Competitivo e Jogo de Batalha</h3>
  <p>App Android e site com a mesma conta: o que você faz em um aparece no outro.</p>
  <p>🌐 <a href="https://octaviokonzen.github.io/Pocketdex/"><b>Abrir o site</b></a> · 📥 <a href="https://github.com/OctavioKonzen/Pocketdex/releases/latest"><b>Baixar o APK</b></a></p>
</div>

---

## 📑 Sumário

- [Telas principais](#-telas-principais)
  - [Início e Pokédex](#início-e-pokédex) · [Pokémon](#pokémon) · [Times](#times) · [Jogo](#jogo-quem-é-esse-pokémon) · [Centro de Batalha](#centro-de-batalha) · [Treino](#treino) · [Enciclopédia](#enciclopédia) · [Amigos](#amigos) · [Conquistas e Configurações](#conquistas-e-configurações)
- [Modos de batalha](#-modos-de-batalha)
  - [Como a batalha funciona](#como-a-batalha-funciona) · [Individual](#individual-1-contra-1) · [Dupla e tripla](#dupla-e-tripla) · [Contra o computador](#contra-o-computador) · [Online com amigos](#online-com-amigos) · [Draft](#draft) · [Jornada, Torre e Battle Factory](#jornada-torre-de-batalha-e-battle-factory-pokelike)
- [Apoie o projeto](#-apoie-o-projeto) · [Ferramentas](#️-ferramentas-usadas) · [Como usar](#-como-usar) · [Como rodar o código](#-como-rodar-o-código) · [Créditos](#-créditos)

> As imagens do app são do celular (Android) e as do site são do computador. As telas são as mesmas nos dois: mesmo visual, mesmas regras e mesma conta.

---

## 🧭 Telas principais

### Início e Pokédex

O **Início** do app tem a busca, o **Pokémon do dia** (com o grito) e os atalhos para todas as áreas. A **Pokédex** lista os 1025 Pokémon com Megas, formas regionais e outras formas, sprites animados no estilo Black & White (normais e shiny) e filtros por geração, jogo, tipo, status e mais. No site, a Pokédex é a página inicial e os atalhos ficam na barra de cima.

<table>
  <tr><th>📱 App</th><th>💻 Site</th></tr>
  <tr>
    <td align="center"><img src="docs/screenshots/app-inicio.jpg" width="200" alt="App: app-inicio" /> <img src="docs/screenshots/app-pokedex.jpg" width="200" alt="App: app-pokedex" /></td>
    <td align="center"><img src="docs/screenshots/site-inicio.jpg" width="520" alt="Site: site-inicio" /></td>
  </tr>
</table>

### Pokémon

A ficha de cada Pokémon: tipos, grito, forma shiny, descrição, altura, peso, gênero e grupos de ovo, **status base**, **evolução**, **golpes** (por nível, TM, tutor e ovo), **habilidades** (inclusive a oculta) e a aba **Jogos**, que mostra em quais jogos ele aparece e onde encontrar.

<table>
  <tr><th>📱 App</th><th>💻 Site</th></tr>
  <tr>
    <td align="center"><img src="docs/screenshots/app-pokemon.jpg" width="200" alt="App: app-pokemon" /></td>
    <td align="center"><img src="docs/screenshots/site-pokemon.jpg" width="520" alt="Site: site-pokemon" /></td>
  </tr>
</table>

### Times

Monte times de até 6 Pokémon com golpes, item, habilidade, Nature, EVs, IVs, Tera Type e a mecânica de cada um (Mega, Z-Move, Dynamax/Gigantamax ou Tera). O montador mostra fraquezas, cobertura de tipos e uma nota do time, e sugere quem completa a equipe. Dá para compartilhar por link, código ou texto do Pokémon Showdown, publicar na **Comunidade** e ver os **Times dos personagens** (líderes, Elite Four, campeões, rivais e vilões de cada jogo, da 1ª à 9ª geração).

<table>
  <tr><th>📱 App</th><th>💻 Site</th></tr>
  <tr>
    <td align="center"><img src="docs/screenshots/app-times.jpg" width="200" alt="App: app-times" /> <img src="docs/screenshots/app-montador.jpg" width="200" alt="App: app-montador" /></td>
    <td align="center"><img src="docs/screenshots/site-times.jpg" width="520" alt="Site: site-times" /></td>
  </tr>
</table>

### Jogo (Quem é esse Pokémon?)

Adivinhe o Pokémon entre 4 opções, pela **silhueta**, pelo **grito**, pela **descrição** ou pelos **tipos**. Tem o modo normal (3 vidas), o **Ranked** (5 segundos por Pokémon, vale ranking), o **Desafio do dia** (os mesmos 10 Pokémon para todo mundo) e desafios entre amigos, com rankings geral, da semana e do dia.

<table>
  <tr><th>📱 App</th><th>💻 Site</th></tr>
  <tr>
    <td align="center"><img src="docs/screenshots/app-jogo.jpg" width="200" alt="App: app-jogo" /></td>
    <td align="center"><img src="docs/screenshots/site-jogo.jpg" width="520" alt="Site: site-jogo" /></td>
  </tr>
</table>

### Centro de Batalha

O ponto de partida das batalhas (veja os [modos de batalha](#-modos-de-batalha)) e as ferramentas para preparar o time: **Calculadora de dano**, **Quem vence?** (quem ganha um contra um), **Faixas de velocidade**, **Comparar Pokémon**, **Tabela de tipos** e **Tera Raids**.

<table>
  <tr><th>📱 App</th><th>💻 Site</th></tr>
  <tr>
    <td align="center"><img src="docs/screenshots/app-centro.jpg" width="200" alt="App: app-centro" /> <img src="docs/screenshots/app-dano.jpg" width="200" alt="App: app-dano" /></td>
    <td align="center"><img src="docs/screenshots/site-centro.jpg" width="520" alt="Site: site-centro" /></td>
  </tr>
</table>

### Treino

Ferramentas de criação: **Guia de Natures**, **Breeding** (parceiros compatíveis), **Golpes de ovo** (quem passa o golpe), **Contador de EVs**, **Calculadora de IVs**, **Contador de shiny** e o acompanhamento de **Nuzlocke**.

<table>
  <tr><th>📱 App</th><th>💻 Site</th></tr>
  <tr>
    <td align="center"><img src="docs/screenshots/app-treino.jpg" width="200" alt="App: app-treino" /></td>
    <td align="center"><img src="docs/screenshots/site-treino.jpg" width="520" alt="Site: site-treino" /></td>
  </tr>
</table>

### Enciclopédia

Todos os **golpes** (tipo, categoria, poder, precisão e quem aprende), **habilidades** (o que fazem e quem tem) e **itens** (efeito e categoria), com busca e filtros.

<table>
  <tr><th>📱 App</th><th>💻 Site</th></tr>
  <tr>
    <td align="center"><img src="docs/screenshots/app-enciclopedia.jpg" width="200" alt="App: app-enciclopedia" /></td>
    <td align="center"><img src="docs/screenshots/site-enciclopedia.jpg" width="520" alt="Site: site-enciclopedia" /></td>
  </tr>
</table>

### Amigos

Adicione amigos pelo nome, converse no chat (as mensagens somem em 7 dias), mande cartões de time e de Pokémon, desafie para o quiz ou para uma batalha online e compare os recordes do Ranked.

<table>
  <tr><th>📱 App</th><th>💻 Site</th></tr>
  <tr>
    <td align="center"></td>
    <td align="center"><img src="docs/screenshots/site-amigos.jpg" width="520" alt="Site: site-amigos" /></td>
  </tr>
</table>

### Conquistas e Configurações

As **Conquistas** dão medalhas por jogar, montar times, favoritar Pokémon e avançar nas batalhas (inclusive as da Battle Factory). Nas **Configurações** ficam a conta (Google ou e-mail), o tema claro/escuro, o idioma (português, inglês, francês e espanhol), o tamanho do texto, os sprites (animados, BW ou 3D) e o Pix para apoiar o projeto.

<table>
  <tr><th>📱 App</th><th>💻 Site</th></tr>
  <tr>
    <td align="center"><img src="docs/screenshots/app-conquistas.jpg" width="200" alt="App: app-conquistas" /> <img src="docs/screenshots/app-configuracoes.jpg" width="200" alt="App: app-configuracoes" /></td>
    <td align="center"><img src="docs/screenshots/site-conquistas.jpg" width="520" alt="Site: site-conquistas" /><br/><img src="docs/screenshots/site-configuracoes.jpg" width="520" alt="Site: site-configuracoes" /></td>
  </tr>
</table>

---

## ⚔️ Modos de batalha

### Como a batalha funciona

As batalhas são por turnos, no estilo **Black & White**, com o **mesmo motor** no app e no site (as regras do Pokémon Showdown): dano, precisão, prioridade, crítico, status, clima, terrenos, habilidades, itens equipados e os golpes de 2 turnos ou de recarga.

- **A tela é fixa, como num jogo oficial:** o campo tem sempre o mesmo tamanho, a fala aparece sempre na mesma caixa (o que não cabe vem em partes, com ▼) e os botões ficam sempre no mesmo lugar.
- **Menu:** **LUTAR** (os 4 golpes), **BOLSA** (Poções, Revive e, contra Pokémon selvagem, Poké Balls), **POKÉMON** (a tela do time com os 6, com TROCAR e DADOS) e **FUGIR** (conta como derrota).
- **Golpes:** cada botão mostra o PP, a chance de crítico, a **efetividade** e o **dano estimado** em % da vida do adversário.
- **Mecânicas:** Mega, Z-Move, Dynamax/Gigantamax e Tera, uma vez por batalha, pelo botão redondo no meio dos golpes.
- **Abertura:** a tela **VS** (contra treinador, chefe e online; contra Pokémon selvagem ele aparece direto), os treinadores lançando a Poké Ball e a música de cada lugar ou personagem.
- **Tudo com o mesmo tamanho:** Pokémon e treinadores na mesma escala, pela altura de cada um.

### Individual (1 contra 1)

Um Pokémon de cada lado. Antes de começar, a **prévia dos times** mostra o time do adversário e você escolhe quem entra primeiro.

<table>
  <tr><th>📱 App</th><th>💻 Site</th></tr>
  <tr>
    <td align="center"><img src="docs/screenshots/app-batalha.jpg" width="200" alt="App: app-batalha" /> <img src="docs/screenshots/app-batalha-golpes.jpg" width="200" alt="App: app-batalha-golpes" /></td>
    <td align="center"><img src="docs/screenshots/site-batalha.jpg" width="520" alt="Site: site-batalha" /><br/><img src="docs/screenshots/site-batalha-golpes.jpg" width="520" alt="Site: site-batalha-golpes" /></td>
  </tr>
</table>

### Dupla e tripla

Dois (ou três) Pokémon de cada lado, **com a mesma tela e os mesmos botões da individual**. Você escolhe o golpe de cada um e em quem usar (adversário ou aliado). Depois o turno acontece na ordem da velocidade e da prioridade, como nos jogos, com a ordem do turno na caixa de texto. A BOLSA também funciona: quem usa o item gasta o turno dele. Os golpes mostram o dano estimado em cada adversário.

<table>
  <tr><th>📱 App</th><th>💻 Site</th></tr>
  <tr>
    <td align="center"><img src="docs/screenshots/app-dupla.jpg" width="200" alt="App: app-dupla" /> <img src="docs/screenshots/app-dupla-golpes.jpg" width="200" alt="App: app-dupla-golpes" /></td>
    <td align="center"><img src="docs/screenshots/site-dupla.jpg" width="520" alt="Site: site-dupla" /><br/><img src="docs/screenshots/site-dupla-golpes.jpg" width="520" alt="Site: site-dupla-golpes" /></td>
  </tr>
</table>

### Contra o computador

Escolha o **formato** (individual, dupla ou tripla), o seu time (um dos seus ou aleatório), o adversário (time aleatório, o de um amigo, um líder de ginásio, a Torre de Batalha ou a Battle Factory) e a **dificuldade**:

- **Fácil:** o computador ataca ao acaso, sem trocar nem usar itens.
- **Normal:** IVs e EVs aleatórios.
- **Difícil:** sets competitivos.

<table>
  <tr><th>📱 App</th><th>💻 Site</th></tr>
  <tr>
    <td align="center"><img src="docs/screenshots/app-batalha-config.jpg" width="200" alt="App: app-batalha-config" /></td>
    <td align="center"><img src="docs/screenshots/site-batalha-config.jpg" width="520" alt="Site: site-batalha-config" /></td>
  </tr>
</table>

### Online com amigos

Batalha ao vivo, cada um controlando o próprio time, com nível máximo 50 e tempo por turno. Dá para jogar individual, dupla ou tripla, inclusive amigos juntos contra a máquina: até 4 jogadores na dupla e 6 na tripla, cada equipe com 6 Pokémon e reserva compartilhada. Também tem adversário aleatório (fila), emotes, regras opcionais (como a Sleep Clause), **histórico** e **replays** com link para compartilhar.

### Draft

Você e um amigo escolhem Pokémon um de cada vez para montar os times e depois batalham com eles.

### Jornada, Torre de Batalha e Battle Factory (Pokelike)

- **Jornada (Desafio dos Líderes):** enfrente os líderes de ginásio de cada região com os times originais, ganhe as insígnias, desafie a Liga (Elite Four e Campeão) e entre no Hall da Fama.
- **Torre de Batalha:** batalhas seguidas para aumentar a sua sequência de vitórias.
- **Battle Factory (Pokelike):** um roguelike pela história de cada região. Você começa com um inicial grátis e segue pelo **mapa** de rotas e cidades, escolhendo o caminho em cada bifurcação: treinadores, Pokémon selvagens para **capturar**, eventos, vendedor ambulante, cura no caminho, cavernas e outros lugares até o **chefe** de cada cidade (líderes, rival, vilões, Elite Four e Campeão). A partir do andar 15 aparecem **duplas de treinadores** em batalha dupla. Nas cidades ficam o **Poké Mart**, o **Centro Pokémon** e a **Creche**. O XP vai para quem lutou (ou para todos com o Exp. Share) e os Pokémon evoluem. As moedas de cada corrida compram melhorias na **árvore de habilidades** e novos iniciais.

<table>
  <tr><th>📱 App</th><th>💻 Site</th></tr>
  <tr>
    <td align="center"><img src="docs/screenshots/app-factory-mapa.jpg" width="200" alt="App: mapa" /> <img src="docs/screenshots/app-factory-cidade.jpg" width="200" alt="App: cidade" /><br/><img src="docs/screenshots/app-factory-loja.jpg" width="200" alt="App: Poké Mart" /> <img src="docs/screenshots/app-factory-cura.jpg" width="200" alt="App: cura na rota" /><br/><img src="docs/screenshots/app-factory-captura.jpg" width="200" alt="App: captura" /> <img src="docs/screenshots/app-factory-resultado.jpg" width="200" alt="App: resultado" /><br/><img src="docs/screenshots/app-factory-arvore.jpg" width="200" alt="App: árvore de melhorias" /></td>
    <td align="center"><img src="docs/screenshots/site-factory-hub.jpg" width="420" alt="Site: começo da corrida" /><br/><img src="docs/screenshots/site-factory-mapa.jpg" width="420" alt="Site: mapa" /><br/><img src="docs/screenshots/site-factory-batalha.jpg" width="420" alt="Site: batalha" /></td>
  </tr>
</table>

---

## 💚 Apoie o projeto

O PocketDex é gratuito e sem anúncios. Se ele te ajuda, qualquer valor por **Pix** ajuda a manter o projeto:

**Chave Pix (aleatória):** `b2f17626-44c0-421d-9a60-71a33b272741`

No app e no site, em **Configurações**, tem o QR Code e o "Pix copia e cola".

## 🛠️ Ferramentas usadas

| Parte | Ferramentas |
|---|---|
| **App (Android)** | Flutter / Dart, Provider |
| **Site** | React, Vite, Tailwind CSS, Framer Motion, React Router, Zustand |
| **Batalha** | Motor próprio sobre o simulador do Pokémon Showdown (`@pkmn/sim`), o mesmo no app (QuickJS) e no site |
| **Conta e dados online** | Firebase Authentication e Firestore |
| **Banco de dados local** | JSON e imagens em `assets/database/`, gerados com Python a partir da PokeAPI |
| **Publicação** | GitHub Actions (conferência automática, site no GitHub Pages e APK em Releases) |

## 📥 Como usar

* **Site:** https://octaviokonzen.github.io/Pocketdex/
* **App:** no site, clique em **Baixar app** (ou vá em [Releases](https://github.com/OctavioKonzen/Pocketdex/releases/latest)), instale o `PocketDex.apk` e entre com a mesma conta do site. O próprio app avisa quando sai uma versão nova.

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

## 🙏 Créditos

* Dados e sprites: [PokeAPI](https://pokeapi.co/) (repositório [PokeAPI/sprites](https://github.com/PokeAPI/sprites)). Pokémon e os nomes, imagens e sons são da Nintendo, Game Freak e The Pokémon Company.
* Sprites animados, no banco do site (o app puxa da nuvem): no estilo Black & White, os oficiais do Black & White (até o #649) e, do #650 em diante, os animados no estilo BW da pasta `gen5ani` do Pokémon Showdown; sem animação BW, a arte BW parada do [Smogon Sprite Project](https://www.smogon.com/forums/forums/smeargles-studio.258/) ([smogon/sprites](https://github.com/smogon/sprites)), também nas costas (`tool/bw_style_sprites.py`). Animações BW feitas por fãs para quem não tem a do Showdown: [Animated sprites by Ghasty001](https://github.com/Ghasty001/Animated_sprites_by_Ghasty001) e os artistas das bases (hexagonereal, Kyledove, Bloxable, KingOfThe-X-Roads, G.E.Z, Katten, aXl, Antiant e os outros listados lá) (`tool/fan_sprites.py`). A maior parte das animações (todos os Pokémon, Megas, formas regionais e formas só de aparência, como Vivillon, Unown e Alcremie) vem do [Animated Pokemon System](https://eeveeexpo.com/resources/1544/) (plugin do Pokémon Essentials por Lucidious89, baseado no Generation 8 Pack de Golisopod User e no EBDX de Luka S.J.): as animações do plugin espanhol "Sprites Animados" (Tenshi of War, DPertierra, Skyflyer, Hellfire_raptor, Antiant, Diegotoon20, KingOfThe-X-Roads e os outros listados lá) sobre os sprites dos projetos X/Y, Sun/Moon, Sword/Shield e Scarlet/Violet da Smogon (`tool/aps_sprites.py`). Mega Zygarde: animação de [RetroNC](https://www.youtube.com/@RetroNC) ([DeviantArt](https://www.deviantart.com/retronc/art/Mega-Zygarde-Gen-5-Pokemon-Sprite-1260116710)). Charizard Gigantamax: animação de [noirium](https://www.deviantart.com/noirium) ([DeviantArt](https://www.deviantart.com/noirium/art/Gigantamax-Charizard-Animated-Sprite-934376791)), usada sem fins lucrativos, com crédito ao artista. Gigantamax (frente e costas, inclusive o Charizard de costas e shiny), Eternamax e Zarude Dada: animações de [mangalos810](https://www.deviantart.com/mangalos810) (DeviantArt), usadas sem fins lucrativos, com crédito ao artista. Desenhados em escala inteira (cada pixel do mesmo tamanho, sem borrar).
* Treinadores da batalha e da foto de perfil (`tool/build_trainers.py`): os sprites animados no estilo Black & White do [Elite Battle System / EBDX](https://luka-sj.com/res/ebs4) para Pokémon Essentials (Luka S.J. e os spriters da comunidade listados lá), base © Nintendo/Game Freak; usados sem fins lucrativos, com crédito aos autores.
* Líderes, Elite Four, campeões, vilões e protagonistas animados (`tool/build_leader_trainers.py`): pacote [Animated Trainer Intros](https://eeveeexpo.com/resources/1667/) (add-on do Deluxe Battle Kit, Lucidious89, sobre o Animated Pokémon System e o EBDX de Luka S.J.), sprites das gerações 4 e 5 © Nintendo/Game Freak; usados sem fins lucrativos, com crédito aos autores.
* Desafio dos Líderes (`tool/build_gym_leaders.py`): os times originais de cada líder de ginásio, Elite Four e campeão, já evoluídos e no nível 50.
* Treinadores do [Pokémon Showdown](https://play.pokemonshowdown.com/sprites/trainers/) (`tool/build_showdown_trainers.py`): sprites 80 × 80 © Nintendo/Game Freak e dos artistas creditados em [play.pokemonshowdown.com/credits](https://pokemonshowdown.com/credits); usados sem fins lucrativos, com crédito aos autores.
* Times oficiais dos personagens (`tool/build_official_teams.py`): tirados do código dos jogos pelos projetos de desmontagem do [pret](https://github.com/pret) (pokered, pokeyellow, pokegold, pokecrystal, pokeruby, pokeemerald, pokefirered e pokeplatinum); nature, habilidade e IVs calculados como o próprio jogo faz. Black 2/White 2: a desmontagem [pokebw2](https://github.com/fuddlesworth/pokebw2), com a nature e a habilidade calculadas como o jogo (`tr_tool.c`). Scarlet/Violet (versão 1.0, sem as DLCs): a tabela de treinadores do jogo (`trdata_array`) como está no [SV-Randomizer](https://github.com/XLuma/SV-Randomizer), com a conversão das espécies do [PKHeX](https://github.com/kwsch/PKHeX). Diamond/Pearl, HeartGold/SoulSilver, Black/White, X/Y, Omega Ruby/Alpha Sapphire, Sun/Moon, Ultra Sun/Ultra Moon, Sword/Shield e Brilliant Diamond/Shining Pearl (marcados como dados da comunidade): os dados de treinadores do [Trevenant](https://github.com/zacharybussey/Trevenant) (MIT), vindos do VanillaNuzlockeCalc (Honko e colaboradores). Só os dados (níveis, golpes, itens), nenhum código dos jogos.
* Calculadora de dano ([@smogon/calc](https://github.com/smogon/damage-calc)), sets prontos e regras dos golpes do [Pokémon Showdown](https://github.com/smogon/pokemon-showdown) (licença MIT).
