# Verificação de golpes

O comando `bash tool/build_battle_engine.sh` compara os 919 registros de golpes dos jogos principais com uma batalha independente de referência do Pokémon Showdown (`@pkmn/sim@0.10.11`). Os 18 golpes exclusivos de Pokémon Shadow ficam excluídos.

Cada registro passa por cinco cenários: alvo que não ataca, alvo que ataca, alvo que troca, alvo Fantasma com Levitate e preparação de condições específicas. Essa preparação contempla cura após dano, sono, status, Stockpile, consumo de Berry, uso prévio dos outros golpes para Last Resort, neve, hazards, terreno, prioridade e um aliado desmaiado para Revival Blessing. A comparação acompanha até cinco etapas após a preparação, incluindo pedidos de troca, HP, status, atributos, tipos, habilidades, itens, terreno, clima, PP e os eventos completos. Golpes Z, Max e G-Max são acionados pela transformação e pelo golpe de origem correspondente.

O resultado detalhado por golpe é gerado em `docs/battle-move-verification.json` e publicado como artefato `battle-move-verification` na conferência do GitHub. A mesma sequência de referência de cada golpe também é reproduzida no pacote do site e no motor nativo do app.

Essa verificação confirma a integração nos cenários descritos. Ela não cobre todas as combinações possíveis, não substitui testes específicos de condições particulares e não demonstra, por si só, que o motor de referência reproduz todas as regras oficiais sem erros. Um golpe pode falhar corretamente quando suas condições não são satisfeitas.
