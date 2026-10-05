import {describe,it,expect} from 'vitest'
import {assembleParty,countOf,sideOf} from './partyBattle'
import {pairedActions,validateGroupChoices,validateParticipantTeam} from './onlineBattle'

describe('equipes cooperativas',()=>{
  const roster=uid=>Array.from({length:6},(_,i)=>({id:`${uid}${i}`}))
  it('distribui três participantes entre os ativos e a reserva compartilhada',()=>{
    const rosters={a:roster('a'),b:roster('b'),c:roster('c')}
    expect(assembleParty(['a','b','c'],rosters).map(p=>p.id)).toEqual(['a0','b0','c0','a1','b1','c1'])
    expect(rosters.a).toHaveLength(6)
  })
  it('um treinador pode controlar todas as posições',()=>{
    expect(assembleParty(['a','a','a'],{a:roster('a')}).map(p=>p.id)).toEqual(['a0','a1','a2','a3','a4','a5'])
  })
  it('identifica o lado pelo campo, mesmo com dois amigos contra NPCs',()=>{
    const room={mode:'doubles',players:['a','b'],seats:['a','b','npc2','npc3']}
    expect(countOf(room)).toBe(2);expect(sideOf(room,'b')).toBe(0)
  })
  it('aguarda os seis jogadores, sem pular rodadas incompletas',()=>{
    const players=['a','b','c','d','e','f']
    const actions=players.map(uid=>({uid,round:0,choices:[]}))
    expect(pairedActions(actions.slice(0,5),players)).toEqual([])
    expect(pairedActions([...actions,{uid:'a',round:1}],players)).toHaveLength(1)
  })
  it('NPCs não precisam enviar ações online',()=>{
    expect(pairedActions([{uid:'a',round:0},{uid:'b',round:0}],['a','b'])).toHaveLength(1)
  })
  it('evita duas trocas para a mesma reserva e duas ativações da mesma mecânica',()=>{
    expect(()=>validateGroupChoices([{kind:'switch',index:4},{kind:'switch',index:4}])).toThrow()
    expect(()=>validateGroupChoices([{kind:'move',gimmick:'tera'},{kind:'move',gimmick:'tera'}])).toThrow()
    expect(()=>validateGroupChoices([{kind:'move',gimmick:'mega'},{kind:'move',gimmick:'tera'}])).not.toThrow()
  })
  it('recusa um time pequeno para as posições controladas',()=>{
    expect(()=>validateParticipantTeam({pokemon:[6,null]},['a','a','b','b'],'a')).toThrow()
    expect(()=>validateParticipantTeam({pokemon:[6,25]},['a','a','b','b'],'a')).not.toThrow()
  })
})
