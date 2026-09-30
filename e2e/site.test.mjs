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
  await editor.getByPlaceholder('Nenhum').fill('Choice Scarf')
  await editor.getByPlaceholder('Golpe 1').fill('Earthquake')
  await editor.locator('select').filter({ hasText: 'Jolly' }).selectOption('Jolly')
  // Campos de número: nível, depois EVs e IVs de cada status (HP, Attack...).
  await editor.locator('input[type=number]').nth(3).fill('252') // EVs de Attack
  await page.keyboard.press('Escape')
  await page.getByText('Earthquake').first().waitFor({ timeout: 5000 })
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
  await page.getByRole('link', { name: 'Conversar' }).click()
  await page.getByText('Nenhuma mensagem ainda').waitFor({ timeout: 15000 })
  await page.getByPlaceholder('Mensagem').fill('Oi! Bora batalhar?')
  await page.keyboard.press('Enter')
  await page.getByText('Oi! Bora batalhar?').waitFor({ timeout: 15000 })
  // O amigo vê a última mensagem e o aviso de não lida na lista.
  await page2.getByText('Oi! Bora batalhar?').waitFor({ timeout: 15000 })
  await page2.getByRole('link', { name: 'Conversar' }).click()
  await page2.getByText('Oi! Bora batalhar?').waitFor({ timeout: 15000 })
  await page2.getByPlaceholder('Mensagem').fill('Bora!')
  await page2.getByRole('button', { name: 'Enviar' }).click()
  await page.getByText('Bora!', { exact: true }).waitFor({ timeout: 15000 })
  assert.equal(await friendDocs('messages'), 2, `${step}: devia ter 2 mensagens`)

  step = 'amigos: mandar time no chat'
  await page.getByRole('button', { name: 'Mandar Pokémon ou time' }).click()
  await page.getByRole('button', { name: /Areia/ }).click()
  await page2.getByRole('button', { name: 'Salvar nos meus times' }).click({ timeout: 15000 })
  await page2.waitForURL(/#\/times\//, { timeout: 15000 })
  // O time salvo pelo amigo vira público quando a conta dele sincroniza.
  for (let i = 0; i < 60 && (await emulatorDocs('publicTeams')).length < 2; i++) await page.waitForTimeout(1000)
  assert.equal((await emulatorDocs('publicTeams')).length, 2, `${step}: o time do amigo não ficou público`)

  step = 'amigos: batalha de times'
  await go('amigos/batalha')
  await page.locator('select').nth(0).selectOption({ label: 'Areia' })
  await page.locator('select').nth(1).selectOption({ label: friend.name })
  await page.locator('select').nth(2).selectOption({ label: 'Areia' })
  await page.getByRole('button', { name: '⚔️ Batalhar!' }).click()
  await page.getByText(/de 1 confrontos/).waitFor({ timeout: 30000 })
  await expectHealthy()

  step = 'batalha: quem vence'
  await go('batalha/quem-vence')
  await page.getByRole('button', { name: 'Escolher Pokémon' }).click()
  await page.getByPlaceholder('Procurar por nome ou número').fill('charizard')
  await page.getByRole('dialog').getByRole('button', { name: /charizard/i }).first().click()
  await page.getByText(/Pokémon ganham do Charizard/).waitFor({ timeout: 60000 })
  await expectHealthy()

  step = 'amigos: trocas'
  await go('amigos/trocas')
  await page.getByRole('button', { name: '+ Adicionar repetido' }).click()
  await page.getByPlaceholder('Procurar por nome ou número').fill('pikachu')
  await page.getByRole('dialog').getByRole('button', { name: /pikachu/i }).first().click()
  await page.getByText('Meus repetidos (1)').waitFor({ timeout: 15000 })
  await page2.evaluate(() => (location.hash = '#/amigos/trocas'))
  await page2.getByText('Pode te dar (1)').waitFor({ timeout: 15000 })
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
  // O amigo continua com a conta: sobra só o time dele (ele não marcou repetidos).
  assert.equal((await emulatorDocs('publicTeams')).length, 1, `${step}: sobrou time público da conta excluída`)
  assert.equal((await emulatorDocs("trades")).length, 0, `${step}: sobrou a lista de trocas (${(await emulatorDocs("trades")).length})`)

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
