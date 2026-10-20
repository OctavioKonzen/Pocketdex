// Os treinadores (assets/database/trainers.json): carregar, o seu e um para o
// computador. Os desenhos ficam em components/Trainer.jsx.

import { useEffect, useState } from 'react'
import { getTrainers } from './data'
import { useStore } from './store'

/** A lista dos treinadores (carrega uma vez). */
export function useTrainers() {
  const [list, setList] = useState(null)
  useEffect(() => {
    let alive = true
    getTrainers()
      .then((t) => alive && setList(t))
      .catch(() => alive && setList([]))
    return () => {
      alive = false
    }
  }, [])
  return list
}

/** O seu treinador (o escolhido ou o Red). */
export function useMyTrainer() {
  const list = useTrainers()
  const id = useStore((s) => s.trainer)
  return list?.find((t) => t.id === id) ?? list?.[0] ?? null
}

/** Um treinador para o computador (não repete o seu). */
export function randomTrainer(list, mine, random = Math.random) {
  const options = (list ?? []).filter((t) => !t.back && t.id !== mine)
  return options.length ? options[Math.floor(random() * options.length)] : null
}


/**
 * As classes de treinador comuns (Youngster, Hiker, Swimmer...): os treinadores
 * de rota usam só estas (nunca um líder de ginásio ou um personagem importante).
 * Igual ao app.
 */
const GENERIC_CLASSES = new Set([
  'acetrainer', 'acetrainercouple', 'acetrainerf', 'acetrainersnow', 'acetrainersnowf', 'aromalady', 'artist', 'backpacker', 'backpackerf', 'baker',
  'ballguy', 'battlegirl', 'beauty', 'bellhop', 'biker', 'birdkeeper', 'blackbelt', 'boarder', 'bugcatcher', 'burglar',
  'butler', 'cabbie', 'cafemaster', 'cameraman', 'camper', 'chef', 'clerk', 'clerkf', 'clown', 'collector',
  'cook', 'courier', 'cowgirl', 'cyclist', 'cyclistf', 'dancer', 'delinquent', 'depotagent', 'doctor', 'doubleteam',
  'dragontamer', 'fairytalegirl', 'firebreather', 'firefighter', 'fisherman', 'freediver', 'furisodegirl-black', 'furisodegirl-blue', 'furisodegirl-pink', 'furisodegirl-white',
  'gambler', 'garcon', 'gardener', 'gentleman', 'golfer', 'guitarist', 'harlequin', 'hiker', 'hooligans', 'hoopster',
  'idol', 'infielder', 'janitor', 'jogger', 'juggler', 'kimonogirl', 'lady', 'lass', 'linebacker', 'madame',
  'maid', 'medium', 'musician', 'ninjaboy', 'nurseryaide', 'officeworker', 'officeworkerf', 'owner', 'parasollady', 'picnicker',
  'pilot', 'pokefan', 'pokefanf', 'pokekid', 'pokemaniac', 'pokemonbreeder', 'pokemonbreederf', 'pokemonranger', 'pokemonrangerf', 'policeman',
  'postman', 'preschooler', 'preschoolerf', 'preschoolers', 'psychic', 'psychicf', 'punkgirl', 'punkguy', 'railstaff', 'rancher',
  'reporter', 'richboy', 'risingstar', 'risingstarf', 'rollerskater', 'rollerskaterf', 'roughneck', 'ruffian', 'ruinmaniac', 'sailor',
  'schoolboy', 'schoolgirl', 'schoolkid', 'schoolkidf', 'scientist', 'scientistf', 'scubadiver', 'sightseer', 'sightseerf', 'sisandbro',
  'skier', 'skierf', 'skytrainer', 'skytrainerf', 'smasher', 'streetthug', 'striker', 'supernerd', 'surfer', 'swimmer',
  'swimmerf', 'teacher', 'tourist', 'touristf', 'touristf2', 'tuber', 'tuberf', 'twins', 'veteran', 'veteranf',
  'waiter', 'waitress', 'worker', 'workerice', 'youngathlete', 'youngathletef', 'youngcouple', 'youngn', 'youngster',
])
const NAMED_TITLES = new Set(['Líder de Ginásio', 'Elite Four', 'Treinador', 'Treinadora', 'Rival', 'Cérebro da Frente', 'Campeão', 'Campeã', 'Equipe Rocket', 'Recruta', 'Equipe Plasma', 'Team Rocket', 'Chefe da Equipe Rocket', 'Chefe do Metrô', 'Professor'])
/** É um treinador comum (de classe), não um personagem com nome? */
export const isGenericTrainer = (t) =>
  !t.back && (t.title === 'Pokémon Showdown' ? t.id.startsWith('sd-') && GENERIC_CLASSES.has(t.id.slice(3).replace(/-(gen\d+\w*|\w*\d+)$/, '')) : !NAMED_TITLES.has(t.title))
/** Um treinador comum, sempre o mesmo para a mesma semente (o andar). */
export function genericTrainer(list, seed) {
  const options = (list ?? []).filter(isGenericTrainer)
  return options.length ? options[Math.abs(Math.floor(seed)) % options.length] : null
}
