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
        const html=renderToStaticMarkup(<MultiBattle battle={b} onExit={()=>{}} onAgain={()=>{}}/>)
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
