// O plano das animações dos golpes para o app: o mesmo battleFx.js do site, rodando no QuickJS (lib/services/battle_fx.dart).
// setData uma vez (a boca e a frente de cada sprite e a receita de cada golpe); depois stage e plan devolvem JSON.
import { fxForMove, fxScene, fxStage } from '../../web-site/src/lib/battleFx.js'

let anchors = null
let recipes = null
globalThis.PocketDexFx = {
  setData(a, r) {
    anchors = a
    recipes = r
    return { ok: true }
  },
  stage(near, far) {
    return fxStage(anchors, String(near), String(far))
  },
  // As cenas: 'sendout' (a Poké Ball abre), 'recall' (o raio vermelho) e 'faint' (desmaio) do lado [o.side].
  scene(o) {
    const stage = fxStage(anchors, String(o.near), String(o.far))
    return fxScene({ kind: o.kind, side: o.side, stage, seed: o.seed ?? 1 })
  },
  plan(o) {
    const stage = fxStage(anchors, String(o.near), String(o.far))
    return fxForMove({ ...o, recipe: recipes?.[o.slug] ?? null, stage })
  },
}
