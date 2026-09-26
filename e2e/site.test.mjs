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

  console.log(`TUDO CERTO: conta criada, ${ROUTES.length} páginas abertas, saiu e entrou de novo.`)
} catch (error) {
  await page.screenshot({ path: 'falha.png', fullPage: true }).catch(() => {})
  console.error(`FALHOU em "${step}":`, error.message)
  process.exitCode = 1
} finally {
  await browser.close()
}
