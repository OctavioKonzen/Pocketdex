import React from 'react'
import {renderToStaticMarkup} from 'react-dom/server'
import {describe,it,expect,vi} from 'vitest'
import {MultiBattle} from './TurnBattlePage'
import {newPartyBattle} from '../lib/partyBattle'
import {simulatorDispose,simulatorTurn} from '../lib/battleSimulator'
vi.mock('../lib/pokemonIndex',()=>({usePokemonIndex:()=>new Map()}))
const mon=()=>({id:151,name:'Mew',types:['psychic'],level:50,maxHp:100,hp:100,spe:100,moves:[],simulation:{set:{species:'Mew',level:50,moves:['swift','recover','helpinghand','protect']}}})
describe('botões dos golpes em dupla e tripla',()=>{
  for(const count of [2,3]) it(`um Pokémon por vez, como no Showdown, com os quatro golpes, nas ${count} posições, antes e depois de atacar`,()=>{
    const b=newPartyBattle({me:Array.from({length:6},mon),npc3:Array.from({length:6},mon)},[...Array(count).fill('me'),...Array(count).fill('npc3')],count,()=>0.25)
    try {
      for(let turn=0;turn<3;turn++) {
        // Como na batalha normal: primeiro o menu (LUTAR / POKÉMON); LUTAR abre os golpes.
        const menu=renderToStaticMarkup(<MultiBattle battle={b} onExit={()=>{}} onAgain={()=>{}}/>)
        expect(menu).toContain('data-testid="multi-menu"');expect(menu).not.toContain('data-testid="multi-moves"')
        expect(menu).toMatch(new RegExp(`data-testid="battle-text"[^>]*>[^<]*Mew[^<]*\\(1/${count}\\)`))
        const html=renderToStaticMarkup(<MultiBattle battle={b} onExit={()=>{}} onAgain={()=>{}} startMenu="fight"/>)
        // Só o painel do primeiro Pokémon (1/count); os outros vêm depois.
        expect((html.match(/data-testid="multi-moves"/g)||[])).toHaveLength(1)
        expect((html.match(/data-testid="battle-move-0-/g)||[])).toHaveLength(4)
        expect(html).not.toContain('data-testid="battle-move-1-')
        expect(html).toContain(`(1/${count})`)
        expect(html).toContain('Swift');expect(html).toContain('Recover')
        const choices=Array.from({length:count},()=>({kind:'move',index:0,target:0}))
        simulatorTurn(b,[choices,Array.from({length:count},()=>({kind:'move',index:1}))])
      }
    } finally {simulatorDispose(b)}
  })
})
describe('cenário da batalha dupla',()=>{
  it('usa o lugar do mapa (a imagem BW, com plataforma), como a de um contra um',()=>{
    const b=newPartyBattle({me:Array.from({length:6},mon),npc3:Array.from({length:6},mon)},['me','me','npc3','npc3'],2,()=>0.25)
    try {
      b.scene='cave'
      const html=renderToStaticMarkup(<MultiBattle battle={b} onExit={()=>{}} onAgain={()=>{}}/>)
      expect(html).toContain('data-scene="cave"')
      expect(html).toContain('battle/cave.webp')
      expect(html).toContain('battle/cave-base-foe.webp')
      expect(html).toContain('battle/cave-base-mine.webp')
    } finally {simulatorDispose(b)}
  })
})
describe('dupla igual à batalha normal',()=>{
  // Com os golpes já lidos (para o dano estimado).
  const withMoves=()=>({...mon(),moves:['swift','recover','helpinghand','protect'].map(slug=>({...globalThis.PocketDexSim.move(slug),pp:10,maxPp:10}))})
  it('BOLSA e FUGIR funcionam; os golpes e os alvos mostram o dano estimado',()=>{
    const b=newPartyBattle({me:Array.from({length:6},withMoves),npc3:Array.from({length:6},withMoves)},['me','me','npc3','npc3'],2,()=>0.25)
    try {
      const menu=renderToStaticMarkup(<MultiBattle battle={b} onExit={()=>{}} onAgain={()=>{}}/>)
      expect(menu).toMatch(/<button[^>]*data-testid="battle-bag"/)
      expect(menu).not.toMatch(/<button[^>]*disabled=""[^>]*data-testid="battle-bag"/)
      expect(menu).not.toMatch(/<button[^>]*disabled=""[^>]*data-testid="battle-run"/)
      // O dano em cada adversário (Swift), com o "hit" da batalha.
      const hit=()=>({eff:1,rolls:[[10,12]]})
      const html=renderToStaticMarkup(<MultiBattle battle={b} hit={hit} onExit={()=>{}} onAgain={()=>{}} startMenu="fight"/>)
      expect(html).toContain('data-testid="damage-range-0-0-0"')
      expect(html).toMatch(/damage-range-0-0-0"><span[^>]*>\d+–\d+%/)
      // Online: a Bolsa fica apagada (como na batalha normal).
      const online=renderToStaticMarkup(<MultiBattle battle={b} online={{uid:'me',names:{},locked:false,onAction(){},onClose(){}}} onExit={()=>{}} onAgain={()=>{}}/>)
      expect(online).toMatch(/<button[^>]*disabled=""[^>]*data-testid="battle-bag"/)
    } finally {simulatorDispose(b)}
  })
  it('o motor aceita a Potion de um enquanto o outro ataca',()=>{
    const b=newPartyBattle({me:Array.from({length:6},mon),npc3:Array.from({length:6},mon)},['me','me','npc3','npc3'],2,()=>0.25)
    try {
      simulatorTurn(b,[[{kind:'move',index:0,target:0},{kind:'move',index:0,target:0}],[{kind:'move',index:0,target:0},{kind:'move',index:0,target:0}]])
      const hurt=b.sides[0].team.findIndex(m=>m.hp>0&&m.hp<m.maxHp)
      expect(hurt).toBeGreaterThanOrEqual(0)
      const potions=b.bags[0].potion
      simulatorTurn(b,[[{kind:'item',item:'potion',index:hurt},{kind:'move',index:3}],[{kind:'move',index:3},{kind:'move',index:3}]])
      expect(b.bags[0].potion).toBe(potions-1)
    } finally {simulatorDispose(b)}
  })
})
