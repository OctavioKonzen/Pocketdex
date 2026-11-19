"""A história do Pokelike por jogo (docs/historia): as cenas de cada jogo ("Região|Jogo").

Cada jogo tem:
  intro: o começo da história (português), no primeiro andar.
  end: o fim (português), ao sair da região.
  cities: ao chegar na cidade, antes do chefe: [(quem fala, português, inglês)] (quem fala vazio: o narrador).
  bosses: "Nome@Cidade" (a ordem dos chefes no Pokelike): before (antes da luta), after (depois), last (o último Pokémon).
Sem francês e espanhol, as falas aparecem em inglês nessas línguas. Usado por tool/build_factory_data.py.
"""
from .alola_galar_paldea import GAMES as _alola_galar_paldea
from .extras import GAMES as _extras
from .hoenn import GAMES as _hoenn
from .johto import GAMES as _johto
from .kanto import GAMES as _kanto
from .sevii_orange import GAMES as _sevii_orange
from .sinnoh import GAMES as _sinnoh
from .unova_kalos import GAMES as _unova_kalos

GAMES = {}
for part in (_kanto, _johto, _hoenn, _sinnoh, _unova_kalos, _alola_galar_paldea, _sevii_orange, _extras):
    GAMES.update(part)
