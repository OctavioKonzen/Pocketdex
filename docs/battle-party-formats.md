# Batalhas com parceiros

O app e o site reutilizam a tela de combate para individual, dupla e tripla.
Cada lado tem até seis Pokémon, com dois ou três ativos nos formatos maiores.
Um treinador pode controlar todas as posições ou atribuí-las a amigos e NPCs.
Assim, dois amigos podem enfrentar NPCs, e equipes online podem misturar amigos
e NPCs. Duplas comportam até quatro humanos e triplas até seis.

Cada participante envia um time. As vagas da equipe são divididas entre os
treinadores: três por treinador na dupla com dois participantes, duas na tripla
com três. Um Pokémon ocupa cada posição e os restantes formam a reserva
compartilhada. Cada jogador escolhe somente as ações de suas posições.
As trocas usam a reserva da equipe; duas posições não podem escolher a mesma
reserva ou a mesma transformação no mesmo turno.

Os turnos aguardam todos os humanos. NPCs escolhem suas ações no motor local,
com a mesma semente e os mesmos times salvos na sala em ambos os dispositivos.
Precisão, aliados, golpes em área, habilidades e a distância entre posições na
tripla seguem o motor de combate. A tripla permite mudar para a posição central.
Itens equipados mantêm seus efeitos; a bolsa de itens continua no combate
individual contra a máquina.

As salas usam o protocolo 5. As regras mantêm salas individuais de protocolo 4
para instalações anteriores, mas os novos clientes exigem criar uma sala atual.
Salas e histórico são privados; times, posições e NPCs ficam fixos após o convite.
As ações são imutáveis, identificadas pelo jogador e rodada, e limitadas às
posições que ele controla. O Firestore exige todas as ações humanas da rodada
anterior antes de permitir avançar.

Os testes abrangem golpes em área, Helping Hand, distância e mudança de posição,
escolhas da IA, distribuição da reserva, espera por seis humanos e permissões
de salas com quatro/seis humanos e com amigos contra NPCs. A conferência de
golpes individuais permanece separada em `battle-move-verification.md`.
