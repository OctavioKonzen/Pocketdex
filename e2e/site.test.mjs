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
  'treino/breeding',
  'treino/evs',
  'treino/comparar',
  'treino/dano',
  'configuracoes',
]
const user = { name: `Teste${Date.now() % 100000}`, email: `teste${Date.now()}@example.com`, password: 'senha123' }

const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined })
const context = await browser.newContext({ viewport: { width: 1280, height: 900 } })
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

// Liga o código por e-mail no emulador (como o servidor faz ao ser publicado).
async function setEmailCodes(on) {
  await fetch('http://127.0.0.1:8085/v1/projects/pocketdex-ffb4d/databases/(default)/documents/config/app', {
    method: 'PATCH',
    headers: { Authorization: 'Bearer owner', 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields: { emailCodes: { booleanValue: on } } }),
  })
}

// No emulador o servidor não manda e-mail: guarda o código em emulatorOutbox/{e-mail}.
async function codeFor(email, after = 0) {
  for (let i = 0; i < 40; i++) {
    const res = await fetch(`http://127.0.0.1:8085/v1/projects/pocketdex-ffb4d/databases/(default)/documents/emulatorOutbox/${email}`, {
      headers: { Authorization: 'Bearer owner' },
    })
    const body = await res.json()
    const at = Number(body.fields?.at?.integerValue ?? 0)
    if (body.fields && at > after) return { code: body.fields.code.stringValue, at }
    await new Promise((r) => setTimeout(r, 500))
  }
  throw new Error(`nenhum código chegou para ${email}`)
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
  const text = await page.locator('textarea').first().inputValue()
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

  step = 'excluir conta'
  await go('configuracoes')
  await page.getByRole('button', { name: 'Excluir', exact: true }).click()
  await page.getByPlaceholder('Digite sua senha para confirmar').fill(user.password)
  await page.getByRole('button', { name: 'Excluir para sempre' }).click()
  await page.getByRole('button', { name: 'Entrar' }).first().waitFor({ timeout: 30000 })
  await expectHealthy()

  step = 'banco vazio depois de excluir'
  for (const path of ['users', 'usernames', 'ranking', 'publicTeams']) {
    const docs = await emulatorDocs(path)
    assert.deepEqual(docs, [], `${step}: sobrou algo em ${path}`)
  }

  step = 'criar de novo com o mesmo e-mail e nome'
  await page.getByRole('button', { name: 'Criar conta' }).first().click()
  await page.locator('input[autocomplete=nickname]').fill(user.name)
  await page.locator('input[type=email]').fill(user.email)
  await page.locator('input[autocomplete=new-password]').nth(0).fill(user.password)
  await page.locator('input[autocomplete=new-password]').nth(1).fill(user.password)
  await page.locator('form button[type=submit]').click()
  await page.getByText(user.name).first().waitFor({ timeout: 20000 })
  await go('configuracoes')

  // ---------------------------------------------------------------- código por e-mail
  step = 'ligar código por e-mail'
  await setEmailCodes(true)
  await page.getByRole('button', { name: 'Sair' }).first().click()
  await page.getByRole('button', { name: 'Entrar' }).first().waitFor({ timeout: 15000 })
  await page.reload()
  const coded = { name: `Cod${Date.now() % 100000}`, email: `codigo${Date.now()}@example.com`, password: 'senha123' }

  step = 'criar conta com código'
  await page.getByRole('button', { name: 'Criar conta' }).first().click()
  await page.locator('input[autocomplete=nickname]').fill(coded.name)
  await page.locator('input[type=email]').fill(coded.email)
  await page.locator('input[autocomplete=new-password]').nth(0).fill(coded.password)
  await page.locator('input[autocomplete=new-password]').nth(1).fill(coded.password)
  await page.locator('form button[type=submit]').click() // Enviar código
  let mail = await codeFor(coded.email)
  await page.locator('input[autocomplete=one-time-code]').fill('000000' === mail.code ? '111111' : '000000')
  await page.locator('form button[type=submit]').click()
  await page.getByText('Código errado').waitFor({ timeout: 15000 })
  await page.locator('input[autocomplete=one-time-code]').fill(mail.code)
  await page.locator('form button[type=submit]').click()
  await page.getByText(coded.name).first().waitFor({ timeout: 30000 })
  await expectHealthy()

  step = 'trocar senha com código'
  await go('configuracoes')
  step = 'trocar senha com código'
  await page.getByRole('button', { name: 'Trocar', exact: true }).click()
  await page.getByRole('dialog').getByRole('button', { name: 'Enviar código' }).click()
  mail = await codeFor(coded.email, mail.at)
  await page.getByPlaceholder('Código de 6 números').fill(mail.code)
  await page.getByPlaceholder('Nova senha', { exact: true }).fill('senha456')
  await page.getByPlaceholder('Confirmar nova senha').fill('senha456')
  await page.getByRole('dialog').getByRole('button', { name: 'Trocar senha' }).click()
  await page.getByText('Senha trocada!').waitFor({ timeout: 20000 })
  await page.waitForTimeout(1500)
  await page.getByRole('button', { name: 'Sair' }).first().click()
  await page.getByRole('button', { name: 'Entrar' }).first().waitFor({ timeout: 15000 })

  step = 'entrar com a senha nova'
  await page.locator('input[type=email]').fill(coded.email)
  await page.locator('input[autocomplete=current-password]').fill('senha456')
  await page.locator('form button[type=submit]').click()
  await page.getByText(coded.name).first().waitFor({ timeout: 20000 })
  await go('configuracoes')
  await page.getByRole('button', { name: 'Sair' }).first().click()
  await page.getByRole('button', { name: 'Entrar' }).first().waitFor({ timeout: 15000 })

  await page.waitForTimeout(2500) // espera mínima entre códigos
  step = 'recuperar senha com código'
  await page.getByRole('button', { name: 'Esqueci minha senha' }).click()
  await page.locator('input[type=email]').fill(coded.email)
  await page.locator('form button[type=submit]').click() // Enviar código
  mail = await codeFor(coded.email, mail.at)
  await page.locator('input[autocomplete=one-time-code]').fill(mail.code)
  await page.locator('input[autocomplete=new-password]').nth(0).fill('senha789')
  await page.locator('input[autocomplete=new-password]').nth(1).fill('senha789')
  await page.locator('form button[type=submit]').click()
  await page.getByText('Senha trocada! Entre com a senha nova.').waitFor({ timeout: 20000 })
  await page.locator('input[type=email]').fill(coded.email)
  await page.locator('input[autocomplete=current-password]').fill('senha789')
  await page.locator('form button[type=submit]').click()
  await page.getByText(coded.name).first().waitFor({ timeout: 20000 })

  step = 'apagar conta com código'
  await go('configuracoes')
  step = 'apagar conta com código'
  await page.getByRole('button', { name: 'Excluir', exact: true }).click()
  await page.getByRole('dialog').getByRole('button', { name: 'Enviar código' }).click()
  mail = await codeFor(coded.email, mail.at)
  await page.getByPlaceholder('Código de 6 números').fill(mail.code)
  await page.getByRole('button', { name: 'Excluir para sempre' }).click()
  await page.getByRole('button', { name: 'Entrar' }).first().waitFor({ timeout: 60000 })
  await expectHealthy()
  const names = await emulatorDocs('usernames')
  assert.ok(!names.includes(coded.name.toLowerCase()), `${step}: o nome ficou reservado`)
  assert.equal((await emulatorDocs('users')).length, 1, `${step}: sobrou o perfil`)

  console.log(`TUDO CERTO: conta criada, ${ROUTES.length} páginas abertas, saiu, entrou, excluiu (banco limpo) e criou de novo; com código por e-mail: criou, trocou e recuperou a senha e apagou a conta.`)
} catch (error) {
  await page.screenshot({ path: 'falha.png', fullPage: true }).catch(() => {})
  console.error(`FALHOU em "${step}":`, error.message)
  process.exitCode = 1
} finally {
  await browser.close()
}
