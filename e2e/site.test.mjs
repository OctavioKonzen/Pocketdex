// Teste automático do site com login, usando os emuladores do Firebase
// (nada toca no projeto de verdade).
//
// Cria uma conta, abre todas as páginas, sai e entra de novo. Também imita o
// Opera GX, em que window.scrollTo devolve um valor (foi o que causou o erro
// "l is not a function"): qualquer tela de erro ou erro no console falha o
// teste.
//
// Precisa do site já gerado com VITE_EMULATORS=1 e servido em SITE_URL
// (padrão http://localhost:4175/Pocketdex/). Rode com: npm test

import assert from 'node:assert/strict'
import { chromium } from 'playwright'
import { initializeApp } from '../web-site/node_modules/firebase/app/dist/index.mjs'
import * as fbAuth from '../web-site/node_modules/firebase/auth/dist/index.mjs'

const SITE = process.env.SITE_URL ?? 'http://localhost:4175/Pocketdex/'
const ROUTES = [
  '',
  'favoritos',
  'times',
  'times/comunidade',
  'jogo',
  'enciclopedia',
  'enciclopedia/golpes',
  'enciclopedia/habilidades',
  'enciclopedia/itens',
  'treino',
  'treino/natures',
  'treino/ovos',
  'treino/breeding',
  'treino/evs',
  'treino/comparar',
  'treino/dano',
  'treino/ivs',
  'treino/tipos',
  'treino/shiny',
  'batalha',
  'batalha/quem-vence',
  'batalha/velocidade',
  'batalha/comparar',
  'batalha/tipos',
  'batalha/tera-raids',
  'treino/nuzlocke',
  'conquistas',
  'amigos',
  'amigos/draft',
  'configuracoes',
]
const user = { name: `Teste${Date.now() % 100000}`, email: `teste${Date.now()}@example.com`, password: 'senha123' }

const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined })
const context = await browser.newContext({ viewport: { width: 1280, height: 900 }, locale: 'pt-BR' })
// Opera GX: scrollTo devolve algo em vez de undefined.
await context.addInitScript(() => {
  const original = window.scrollTo
  window.scrollTo = function (...args) {
    original.apply(this, args)
    return 1
  }
})
const page = await context.newPage()
const errors = []
page.on('pageerror', (e) => errors.push(e.message))
page.on('console', (m) => {
  // Falha de rede de imagens externas não é erro do site.
  if (m.type() === 'error' && !/Failed to load resource/.test(m.text())) errors.push(m.text())
})

// Lê o banco do emulador como administrador (só existe no emulador).
async function emulatorDocs(path) {
  const res = await fetch(`http://127.0.0.1:8085/v1/projects/pocketdex-ffb4d/databases/(default)/documents/${path}`, {
    headers: { Authorization: 'Bearer owner' },
  })
  const body = await res.json()
  return (body.documents ?? []).map((d) => d.name.split('/').slice(-1)[0])
}

// Quantos documentos de amizade existem (friends/*/list/*), ou de outra coleção.
async function friendDocs(collectionId = 'list') {
  const res = await fetch('http://127.0.0.1:8085/v1/projects/pocketdex-ffb4d/databases/(default)/documents:runQuery', {
    method: 'POST',
    headers: { Authorization: 'Bearer owner', 'Content-Type': 'application/json' },
    body: JSON.stringify({ structuredQuery: { from: [{ collectionId, allDescendants: true }] } }),
  })
  return (await res.json()).filter((r) => r.document).length
}

// Conta Google de teste: o emulador aceita um "token do Google" falso.
const nodeApp = initializeApp({ apiKey: 'fake-api-key', projectId: 'pocketdex-ffb4d', authDomain: 'localhost' }, 'node')
const nodeAuth = fbAuth.getAuth(nodeApp)
fbAuth.connectAuthEmulator(nodeAuth, 'http://127.0.0.1:9099', { disableWarnings: true })

// Último link mandado para o e-mail (no emulador os e-mails ficam guardados).
async function lastLink(email, after = '') {
  for (let i = 0; i < 40; i++) {
    const res = await fetch('http://127.0.0.1:9099/emulator/v1/projects/pocketdex-ffb4d/oobCodes')
    const codes = (await res.json()).oobCodes.filter((c) => c.email === email && c.requestType === 'EMAIL_SIGNIN')
    const link = codes.at(-1)?.oobLink
    if (link && link !== after) return link
    await new Promise((r) => setTimeout(r, 500))
  }
  throw new Error(`nenhum link chegou para ${email}`)
}

let step = ''
async function expectHealthy() {
  const text = await page.evaluate(() => document.body.innerText)
  assert.ok(!text.includes('Algo deu errado'), `${step}: tela de erro\n${text.slice(0, 300)}`)
  assert.deepEqual(errors, [], `${step}: erros no console`)
}
const go = async (route) => {
  step = `página /${route}`
  await page.evaluate((r) => (location.hash = `#/${r}`), route)
  await page.waitForTimeout(1500)
  await expectHealthy()
}

try {
  step = 'abrir o site'
  await page.goto(SITE)
  await page.getByRole('button', { name: 'Criar conta' }).first().click()

  step = 'criar conta'
  await page.locator('input[autocomplete=nickname]').fill(user.name)
  await page.locator('input[type=email]').fill(user.email)
  await page.locator('input[autocomplete=new-password]').nth(0).fill(user.password)
  await page.locator('input[autocomplete=new-password]').nth(1).fill(user.password)
  await page.locator('form button[type=submit]').click()
  await page.getByText(user.name).first().waitFor({ timeout: 20000 })
  await expectHealthy()

  for (const route of ROUTES) await go(route)

  step = 'trocar o idioma para francês'
  await go('configuracoes')
  step = 'trocar o idioma para francês'
  await page.getByRole('button', { name: /Français/ }).click()
  await page.waitForLoadState('load')
  await page.getByText('Paramètres').first().waitFor({ timeout: 20000 })
  await page.evaluate(() => (location.hash = '#/'))
  await page.getByText('Bulbizarre').first().waitFor({ timeout: 20000 })
  await expectHealthy()
  await page.evaluate(() => (location.hash = '#/configuracoes'))
  await page.getByRole('button', { name: /Português/ }).click()
  await page.waitForLoadState('load')
  await page.getByText('Configurações').first().waitFor({ timeout: 20000 })

  await go('times')
  step = 'montar time com dados completos'
  await page.getByRole('button', { name: '+ Novo time' }).click()
  await page.getByPlaceholder('Nome do time').fill('Areia')
  await page.getByRole('button', { name: 'Criar', exact: true }).click()
  await page.getByRole('button', { name: 'Adicionar Pokémon' }).first().click()
  await page.getByPlaceholder('Procurar por nome ou número').fill('garchomp')
  await page.getByRole('dialog').getByRole('button', { name: /garchomp/i }).first().click()
  const editor = page.getByRole('dialog', { name: 'Garchomp' })
  await editor.waitFor({ timeout: 15000 })
  // Espera a lista de itens carregar antes de digitar o item.
  await editor.locator('datalist option[value="Choice Scarf"]').first().waitFor({ state: 'attached', timeout: 15000 })
  await editor.getByPlaceholder('Nenhum').fill('Choice Scarf')
  await editor.getByPlaceholder('Golpe 1').fill('Earthquake')
  await editor.locator('select').filter({ hasText: 'Jolly' }).selectOption('Jolly')
  await editor.locator('input[type=number]').first().fill('100')
  // Campos de número: nível, depois EVs e IVs de cada status (HP, Attack...).
  await editor.locator('input[type=number]').nth(3).fill('252') // EVs de Attack
  await editor.getByText('Shiny ✨').click()
  await page.keyboard.press('Escape')
  await page.getByText('Earthquake').first().waitFor({ timeout: 5000 })
  // Marcado como shiny: aparece shiny no time.
  await page.locator('img[src*="shiny/445."]').first().waitFor({ timeout: 10000 })
  await page.getByRole('button', { name: 'Compartilhar' }).click()
  // O texto do time é montado logo depois de abrir: espera ele aparecer.
  await page.waitForFunction(() => document.querySelector('textarea')?.value.includes('Garchomp @ Choice Scarf'), null, { timeout: 20000 })
  const text = await page.locator('textarea').first().inputValue()
  await page.getByRole('button', { name: '🖼️ Imagem do time' }).click()
  await page.getByRole('link', { name: 'Baixar imagem' }).waitFor({ timeout: 15000 })
  assert.match(text, /Garchomp @ Choice Scarf/, `${step}: texto sem o item`)
  assert.match(text, /EVs: 252 Atk/, `${step}: texto sem os EVs`)
  assert.match(text, /Jolly Nature/, `${step}: texto sem a Nature`)
  assert.match(text, /- Earthquake/, `${step}: texto sem o golpe`)
  await page.keyboard.press('Escape')
  await expectHealthy()

  step = 'sair'
  await go('configuracoes')
  await page.getByRole('button', { name: 'Sair' }).first().click()
  await page.getByRole('button', { name: 'Entrar' }).first().waitFor({ timeout: 15000 })
  await expectHealthy()

  step = 'entrar de novo'
  await page.locator('input[type=email]').fill(user.email)
  await page.locator('input[autocomplete=current-password]').fill(user.password)
  await page.locator('form button[type=submit]').click()
  await page.getByText(user.name).first().waitFor({ timeout: 20000 })
  await go('jogo')

  step = 'amigos: pedido e aceite'
  const friend = { name: `Amigo${Date.now() % 100000}`, email: `amigo${Date.now()}@example.com`, password: 'senha123' }
  const friendCtx = await browser.newContext({ viewport: { width: 1280, height: 900 }, locale: 'pt-BR' })
  const page2 = await friendCtx.newPage()
  await page2.goto(SITE)
  await page2.getByRole('button', { name: 'Criar conta' }).first().click()
  await page2.locator('input[autocomplete=nickname]').fill(friend.name)
  await page2.locator('input[type=email]').fill(friend.email)
  await page2.locator('input[autocomplete=new-password]').nth(0).fill(friend.password)
  await page2.locator('input[autocomplete=new-password]').nth(1).fill(friend.password)
  await page2.locator('form button[type=submit]').click()
  await page2.getByText(friend.name).first().waitFor({ timeout: 20000 })
  await go('amigos')
  await page.getByPlaceholder('Nome da pessoa no PocketDex').fill(friend.name.toLowerCase())
  await page.getByRole('button', { name: 'Enviar pedido' }).click()
  await page.getByText('Pedido enviado!').waitFor({ timeout: 15000 })
  await page2.evaluate(() => (location.hash = '#/amigos'))
  await page2.getByRole('button', { name: 'Aceitar' }).click()
  await page.getByText('🏆', { exact: false }).nth(1).waitFor({ timeout: 15000 })
  await page2.getByText(user.name).first().waitFor({ timeout: 15000 })
  assert.equal(await friendDocs(), 2, `${step}: devia ter os dois lados da amizade`)

  step = 'amigos: chat'
  // No PC a conversa abre na janelinha do canto (como no Facebook).
  const win = (p) => p.getByTestId('chat-window')
  await page.getByRole('link', { name: `Conversar: ${friend.name}` }).click()
  await win(page).getByText('Nenhuma mensagem ainda').waitFor({ timeout: 15000 })
  await win(page).getByPlaceholder('Mensagem').fill('Oi! Bora batalhar?')
  await page.keyboard.press('Enter')
  await win(page).getByText('Oi! Bora batalhar?').waitFor({ timeout: 15000 })
  // O amigo vê a última mensagem e o aviso de não lida na lista.
  await page2.getByText('Oi! Bora batalhar?').waitFor({ timeout: 15000 })
  await page2.getByRole('link', { name: `Conversar: ${user.name}` }).click()
  await win(page2).getByText('Oi! Bora batalhar?').waitFor({ timeout: 15000 })
  await win(page2).getByPlaceholder('Mensagem').fill('Bora!')
  await win(page2).getByRole('button', { name: 'Enviar' }).click()
  await win(page).getByText('Bora!', { exact: true }).waitFor({ timeout: 15000 })
  assert.equal(await friendDocs('messages'), 2, `${step}: devia ter 2 mensagens`)

  step = 'amigos: mandar time no chat'
  await win(page).getByRole('button', { name: 'Mandar Pokémon ou time' }).click()
  await win(page).getByRole('button', { name: /Areia/ }).click()
  await win(page2).getByRole('button', { name: 'Salvar nos meus times' }).click({ timeout: 15000 })
  await page2.waitForURL(/#\/times\//, { timeout: 15000 })
  // O time salvo pelo amigo vira público quando a conta dele sincroniza.
  for (let i = 0; i < 60 && (await emulatorDocs('publicTeams')).length < 2; i++) await page.waitForTimeout(1000)
  assert.equal((await emulatorDocs('publicTeams')).length, 2, `${step}: o time do amigo não ficou público`)

  step = 'amigos: janelinha e bolinha do chat'
  // A janelinha segue aberta em outras páginas; minimizar vira a bolinha,
  // clicar na bolinha abre de novo, dá para abrir em tela cheia e o X fecha.
  await go('amigos/batalha')
  await win(page).getByRole('button', { name: 'Minimizar' }).click()
  await page.getByTestId('chat-bubble').getByRole('button', { name: new RegExp(friend.name) }).click()
  await win(page).getByRole('link', { name: 'Abrir em tela cheia' }).click()
  await page.waitForURL(/#\/amigos\/chat\//, { timeout: 15000 })
  // Espera a página do chat (com o botão Voltar) terminar de abrir.
  await page.getByRole('link', { name: 'Voltar' }).waitFor({ timeout: 15000 })
  await page.getByText('Bora!', { exact: true }).waitFor({ timeout: 15000 })
  await go('amigos/batalha')
  await page.getByTestId('chat-bubble').getByRole('button', { name: 'Fechar' }).click()
  await page.getByTestId('chat-bubble').waitFor({ state: 'detached', timeout: 15000 })
  await win(page2).getByRole('button', { name: 'Fechar' }).click()
  await win(page2).waitFor({ state: 'detached', timeout: 15000 })


  step = 'amigos: batalha online entre dois jogadores'
  page2.on('pageerror', (e) => errors.push(e.message))
  await go('amigos/online')
  await page.getByLabel('Amigo', { exact: true }).selectOption({ label: friend.name })
  await page.getByLabel('Seu time', { exact: true }).selectOption({ label: 'Areia' })
  await page.getByRole('button', { name: 'Desafiar para batalha', exact: true }).click()
  await page.waitForURL(/#\/amigos\/online\//, { timeout: 20000 })
  const battleUrl = page.url()
  await page2.goto(battleUrl)
  await page2.getByLabel('Seu time', { exact: true }).selectOption({ label: 'Areia' })
  await page2.getByRole('button', { name: 'Aceitar e entrar', exact: true }).click()
  await page.getByTestId('online-hp-0').waitFor({ timeout: 30000 })
  await page2.getByTestId('online-hp-0').waitFor({ timeout: 30000 })
  assert.equal(await page.locator('.battle-field').getByText('Nv.50', { exact: true }).count(), 2, 'ambos os lados usam no máximo nível 50')
  const beforeOnline = await page.getByTestId('online-hp-0').innerText()
  await page.locator('.battle-field').waitFor({ timeout: 30000 })
  await page.getByRole('button', { name: '▸ LUTAR', exact: true }).click()
  await page.getByTestId('tera').click()
  assert.equal(await page.getByTestId('tera').getAttribute('aria-pressed'), 'true')
  await page.getByTestId('tera').click()
  assert.equal(await page.getByTestId('tera').getAttribute('aria-pressed'), 'false')
  await page.getByTestId('dmax').click()
  assert.equal(await page.getByTestId('dmax').getAttribute('aria-pressed'), 'true')
  await page.getByTestId('tera').click()
  assert.equal(await page.getByTestId('dmax').getAttribute('aria-pressed'), 'false')
  await page.getByTestId('moves').getByRole('button', { name: /^Earthquake/ }).click()
  await page.getByText('Você já enviou sua ação. Aguardando seu amigo…', { exact: true }).waitFor({ timeout: 15000 })
  assert.equal(await page2.getByTestId('online-hp-0').innerText(), beforeOnline, 'não deve resolver o turno sem a escolha do amigo')
  await page2.locator('.battle-field').waitFor({ timeout: 30000 })
  await page2.getByRole('button', { name: '▸ LUTAR', exact: true }).click()
  await page2.getByTestId('moves').getByRole('button', { name: /^Earthquake/ }).click()
  await page.waitForFunction((before) => document.querySelector('[data-testid="online-hp-0"]')?.innerText !== before, beforeOnline, { timeout: 30000 })
  await page2.waitForFunction((before) => document.querySelector('[data-testid="online-hp-0"]')?.innerText !== before, beforeOnline, { timeout: 30000 })
  await page.getByRole('button', { name: '▸ LUTAR', exact: true }).waitFor({ timeout: 60000 })
  await page2.getByRole('button', { name: '▸ LUTAR', exact: true }).waitFor({ timeout: 60000 })
  assert.equal(await page.getByTestId('tera-badge').count(), 1, 'Tera ativou após os dois enviarem')
  assert.equal(await page2.getByTestId('tera-badge').count(), 1, 'Tera sincronizada para o amigo')
  const onlineHp = await Promise.all([0, 1].map((i) => page.getByTestId('online-hp-' + i).innerText()))
  assert.deepEqual(await Promise.all([0, 1].map((i) => page2.getByTestId('online-hp-' + i).innerText())), onlineHp, 'ambos devem calcular o mesmo turno')
  await page.reload()
  await page.getByTestId('online-hp-0').waitFor({ timeout: 30000 })
  assert.deepEqual(await Promise.all([0, 1].map((i) => page.getByTestId('online-hp-' + i).innerText())), onlineHp, 'reabrir deve retomar a mesma partida')
  await page.getByRole('button', { name: 'Desistir / encerrar partida', exact: true }).click()
  await page2.getByText('Seu amigo encerrou a partida.', { exact: true }).waitFor({ timeout: 15000 })
  await expectHealthy()
  await go('amigos/batalha')

  step = 'amigos: desafio de quiz para o amigo escolhido'
  await go('amigos')
  await page.getByRole('link', { name: 'Quiz', exact: true }).click()
  await page.getByRole('button', { name: '🤝 Desafiar ' + friend.name + ' no quiz', exact: true }).click()
  for (let round = 0; round < 10; round++) {
    await page.waitForFunction(() => document.querySelector('[data-testid="quiz-option"]:not([disabled])'), null, { timeout: 15000 })
    await page.getByTestId('quiz-option').first().click()
    await page.waitForFunction(() => !document.querySelector('[data-testid="quiz-option"]:not([disabled])'), null, { timeout: 10000 })
  }
  await page.getByRole('dialog').getByText('Fim do desafio!', { exact: true }).waitFor({ timeout: 15000 })
  await page.getByRole('dialog').getByRole('button', { name: 'Enviar', exact: true }).click()
  await page.getByRole('dialog').getByRole('button', { name: 'Enviado ✓', exact: true }).waitFor({ timeout: 15000 })
  await page2.goto(SITE + '#/amigos')
  await page2.getByText('🤝 ' + user.name + ' te desafiou!', { exact: true }).waitFor({ timeout: 15000 })
  await page2.getByRole('button', { name: 'Jogar', exact: true }).click()
  await page2.waitForURL(/#\/jogo\?desafio=.+&amigo=/, { timeout: 15000 })
  await expectHealthy()
  await go('amigos/batalha')

  step = 'amigos: batalha de times'
  await page.locator('select').nth(0).selectOption({ label: 'Areia' })
  await page.locator('select').nth(1).selectOption({ label: friend.name })
  await page.locator('select').nth(2).selectOption({ label: 'Areia' })
  await page.getByRole('button', { name: '⚔️ Começar batalha' }).click()
  await page.getByText(`${friend.name} quer batalhar!`).waitFor({ timeout: 30000 })
  // Joga até o fim: LUTAR e o primeiro golpe; clicar no texto adianta as falas.
  let healed = false
  for (let i = 0; ; i++) {
    assert.ok(i < 150, `${step}: a batalha não terminou`)
    if (await page.getByRole('button', { name: 'Batalhar de novo' }).isVisible()) break
    if (await page.getByRole('button', { name: '▸ LUTAR' }).isVisible()) {
      // Uma vez, cura com uma Potion da Bolsa (quando já perdeu vida).
      if (!healed) {
        await page.getByRole('button', { name: '▸ BOLSA' }).click()
        const potion = page.getByTestId('bag').getByRole('button', { name: /^Potion/ })
        if (await potion.isEnabled()) {
          healed = true
          await potion.click()
          await page.getByTestId('party').locator('button:not([disabled])').first().click()
          await page.getByText(/recuperou \d+ de HP/).waitFor({ timeout: 15000 })
          continue
        }
        await page.getByTestId('bag').locator('..').getByRole('button', { name: 'Voltar' }).click()
      }
      await page.getByRole('button', { name: '▸ LUTAR' }).click()
      await page.getByTestId('moves').locator('button[data-no-translate]:not([disabled])').first().click()
    } else if (await page.getByTestId('party').isVisible()) {
      await page.getByTestId('party').locator('button:not([disabled])').first().click()
    } else await page.getByTestId('battle-text').click()
    await page.waitForTimeout(150)
  }
  const end = await page.getByTestId('battle-text').innerText()
  assert.ok(/venceu|perdeu/.test(end), `${step}: fim estranho: ${end}`)
  await expectHealthy()

  step = 'batalha: quem vence'
  await go('batalha/quem-vence')
  await page.getByRole('button', { name: 'Escolher Pokémon' }).click()
  await page.getByPlaceholder('Procurar por nome ou número').fill('charizard')
  await page.getByRole('dialog').getByRole('button', { name: /charizard/i }).first().click()
  await page.getByText(/Pokémon ganham do Charizard/).waitFor({ timeout: 60000 })
  await expectHealthy()

  step = 'amigos: draft'
  const pickIn = async (pg, name) => {
    await pg.getByRole('button', { name: 'Escolher Pokémon' }).click({ timeout: 15000 })
    await pg.getByPlaceholder('Procurar por nome ou número').fill(name)
    await pg.getByRole('dialog').getByRole('button', { name: new RegExp(name, 'i') }).first().click()
  }
  await go('amigos/draft')
  await page.getByRole('button', { name: '3', exact: true }).click()
  await page.getByRole('button', { name: friend.name }).click()
  await page.waitForURL(/#\/amigos\/draft\/.+/, { timeout: 15000 })
  const draftUrl = page.url()
  await page2.goto(draftUrl.replace(/^.*#/, `${SITE}#`))
  for (const [pg, name] of [[page, 'pikachu'], [page2, 'charmander'], [page, 'squirtle'], [page2, 'bulbasaur'], [page, 'eevee'], [page2, 'gengar']]) {
    await pg.getByText('Sua vez de escolher!').waitFor({ timeout: 15000 })
    await pickIn(pg, name)
  }
  await page.getByText('Draft completo! Hora de batalhar.').waitFor({ timeout: 15000 })
  await page.getByRole('button', { name: '⚔️ Batalhar!' }).click()
  // Vira uma batalha por turnos com os times do draft; fugir encerra.
  await page.getByRole('button', { name: '▸ LUTAR' }).waitFor({ timeout: 30000 })
  page.once('dialog', (d) => d.accept())
  await page.getByRole('button', { name: '▸ FUGIR' }).click()
  await page.getByText('Você fugiu da batalha!').waitFor({ timeout: 15000 })
  await expectHealthy()

  step = 'amigos: conversas'
  // As conversas ficam na própria tela de Amigos (como no WhatsApp).
  await go('amigos')
  await page.getByText(/^Você:/).waitFor({ timeout: 15000 })
  await page.getByRole('link', { name: `Conversar: ${friend.name}` }).click()
  await win(page).getByRole('button', { name: 'Fechar' }).click()
  // Link antigo das Trocas cai em Amigos.
  await go('amigos/trocas')
  await page.waitForURL(/#\/amigos$/, { timeout: 15000 })
  await expectHealthy()
  await friendCtx.close()

  step = 'excluir conta'
  await go('configuracoes')
  await page.getByRole('button', { name: 'Excluir', exact: true }).click()
  await page.getByPlaceholder('Digite sua senha para confirmar').fill(user.password)
  await page.getByRole('button', { name: 'Excluir para sempre' }).click()
  await page.getByRole('button', { name: 'Entrar' }).first().waitFor({ timeout: 30000 })
  await expectHealthy()

  step = 'banco vazio depois de excluir'
  for (const path of ['users', 'usernames', 'ranking']) {
    const docs = (await emulatorDocs(path)).filter((d) => path !== 'users' && path !== 'usernames' ? true : false)
    assert.deepEqual(docs, [], `${step}: sobrou algo em ${path}`)
  }
  assert.ok(!(await emulatorDocs('usernames')).includes(user.name.toLowerCase()), `${step}: sobrou o nome`)
  assert.equal(await friendDocs(), 0, `${step}: sobrou amizade`)
  assert.equal(await friendDocs('messages'), 0, `${step}: sobrou mensagem de chat`)
  // O amigo continua com a conta: sobra só o time dele.
  assert.equal((await emulatorDocs('publicTeams')).length, 1, `${step}: sobrou time público da conta excluída`)
  assert.equal((await emulatorDocs('drafts')).length, 0, `${step}: sobrou draft`)

  step = 'criar de novo com o mesmo e-mail e nome'
  await page.getByRole('button', { name: 'Criar conta' }).first().click()
  await page.locator('input[autocomplete=nickname]').fill(user.name)
  await page.locator('input[type=email]').fill(user.email)
  await page.locator('input[autocomplete=new-password]').nth(0).fill(user.password)
  await page.locator('input[autocomplete=new-password]').nth(1).fill(user.password)
  await page.locator('form button[type=submit]').click()
  await page.getByText(user.name).first().waitFor({ timeout: 20000 })
  await go('configuracoes')

  step = 'trocar senha com a senha atual'
  await go('configuracoes')
  step = 'trocar senha com a senha atual'
  await page.getByRole('button', { name: 'Trocar', exact: true }).click()
  await page.getByPlaceholder('Senha atual').fill(user.password)
  await page.getByPlaceholder('Nova senha', { exact: true }).fill('outra456')
  await page.getByPlaceholder('Confirmar nova senha').fill('outra456')
  await page.getByRole('dialog').getByRole('button', { name: 'Trocar senha' }).click()
  await page.getByText('Senha trocada!').waitFor({ timeout: 15000 })
  await page.waitForTimeout(1500)
  await page.getByRole('button', { name: 'Sair' }).first().click()
  await page.getByRole('button', { name: 'Entrar' }).first().waitFor({ timeout: 15000 })
  await page.locator('input[type=email]').fill(user.email)
  await page.locator('input[autocomplete=current-password]').fill('outra456')
  await page.locator('form button[type=submit]').click()
  await page.getByText(user.name).first().waitFor({ timeout: 20000 })
  await go('configuracoes')
  await page.getByRole('button', { name: 'Sair' }).first().click()
  await page.getByRole('button', { name: 'Entrar' }).first().waitFor({ timeout: 15000 })

  // ---------------------------------------------------------------- conta Google: link no e-mail
  step = 'conta Google: confirmar pelo link'
  const gmail = `g${Date.now()}@gmail.com`
  const gName = `Goo${Date.now() % 100000}`
  const gCred = await fbAuth.signInWithCredential(nodeAuth, fbAuth.GoogleAuthProvider.credential(JSON.stringify({ sub: `g${Date.now()}`, email: gmail, email_verified: true })))
  const gUid = gCred.user.uid
  await fbAuth.sendSignInLinkToEmail(nodeAuth, gmail, { url: `${SITE}?confirmar=signup`, handleCodeInApp: true })
  let link = await lastLink(gmail)
  await page.goto(link)
  await page.getByPlaceholder('E-mail').fill(gmail)
  await page.getByRole('button', { name: 'Confirmar' }).click()
  await page.getByText('E-mail confirmado!').waitFor({ timeout: 20000 })
  await page.getByRole('button', { name: 'Continuar' }).click()
  await page.locator('input[autocomplete=nickname]').fill(gName)
  await page.locator('form button[type=submit]').click()
  await page.getByText(gName).first().waitFor({ timeout: 20000 })
  await expectHealthy()

  step = 'conta Google: criar senha pelo link'
  await go('configuracoes')
  step = 'conta Google: criar senha pelo link'
  await page.getByRole('button', { name: 'Trocar', exact: true }).click()
  await page.getByRole('dialog').getByRole('button', { name: 'Enviar link' }).click()
  await page.getByText('Mandamos um link').waitFor({ timeout: 15000 })
  link = await lastLink(gmail, link)
  await page.goto(link)
  await page.getByPlaceholder('Nova senha', { exact: true }).fill('google123')
  await page.getByPlaceholder('Confirmar nova senha').fill('google123')
  await page.getByRole('button', { name: 'Salvar senha' }).click()
  await page.getByText('Senha salva!').waitFor({ timeout: 20000 })
  await page.getByRole('button', { name: 'Continuar' }).click()

  step = 'conta Google: excluir pelo link'
  await go('configuracoes')
  step = 'conta Google: excluir pelo link'
  // Outra aba com a conta aberta (como o app no celular): quando a conta some,
  // ela não pode gravar os dados de volta.
  const other = await context.newPage()
  await other.goto(SITE)
  await other.getByText(gName).first().waitFor({ timeout: 20000 })
  await page.getByRole('button', { name: 'Excluir', exact: true }).click()
  await page.getByRole('dialog').getByRole('button', { name: 'Enviar link de confirmação' }).click()
  await page.getByText('Mandamos um link').waitFor({ timeout: 15000 })
  link = await lastLink(gmail, link)
  await page.goto(link)
  await page.getByRole('button', { name: 'Excluir para sempre' }).click()
  await page.getByText('Sua conta foi excluída').waitFor({ timeout: 60000 })
  await page.getByRole('button', { name: 'Continuar' }).click()
  await page.getByRole('button', { name: 'Entrar' }).first().waitFor({ timeout: 15000 })
  await expectHealthy()
  assert.ok(!(await emulatorDocs('usernames')).includes(gName.toLowerCase()), `${step}: o nome ficou reservado`)
  assert.deepEqual(await emulatorDocs('confirmations'), [], `${step}: sobrou a confirmação`)
  await other.getByRole('button', { name: 'Entrar' }).first().waitFor({ timeout: 20000 })
  await page.waitForTimeout(3000)
  assert.ok(!(await emulatorDocs('users')).includes(gUid), `${step}: a outra aba gravou os dados de volta`)
  await other.close()

  console.log(`TUDO CERTO: conta criada, ${ROUTES.length} páginas abertas, saiu, entrou, excluiu (banco limpo), criou de novo e trocou a senha; conta Google confirmou, criou senha e excluiu pelo link do e-mail.`)
} catch (error) {
  await page.screenshot({ path: 'falha.png', fullPage: true }).catch(() => {})
  console.error(`FALHOU em "${step}":`, error.message)
  process.exitCode = 1
} finally {
  await browser.close()
}
