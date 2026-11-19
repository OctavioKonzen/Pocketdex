"""Hoenn: Ruby/Sapphire, Emerald e Omega Ruby/Alpha Sapphire (docs/historia/03-hoenn.md)."""
import copy

from .kanto import B, L

GYMS = {
    'Roxanne@Rustboro City': B([L('Roxanne', 'Eu estudei tudo na Trainer’s School. Pedras resistem a ataques normais. Agora, a prática!', 'I studied everything at the Trainer’s School. Rocks resist normal attacks. Now, the practice!')],
                               [L('Roxanne', 'Ainda tenho o que aprender. Leve a Stone Badge.', 'I still have things to learn. Take the Stone Badge.')]),
    'Brawly@Dewford Town': B([L('Brawly', 'Eu surfo na onda dos golpes de luta. Vem ver a minha onda!', 'I ride the wave of Fighting moves. Come see my wave!')],
                             [L('Brawly', 'Que onda! A Knuckle Badge é sua.', 'What a wave! The Knuckle Badge is yours.')]),
    'Wattson@Mauville City': B([L('Wattson', 'Wahahahah! Eu adoro inventar. E adoro lutar! Venha!', 'Wahahahah! I love inventing. And I love battling! Come on!')],
                               [L('Wattson', 'Wahahah! Que choque! Leve a Dynamo Badge.', 'Wahahah! What a shock! Take the Dynamo Badge.')]),
    'Flannery@Lavaridge Town': B([L('Flannery', 'Eu acabei de assumir o ginásio do meu avô! Eu... eu vou queimar tudo!', 'I just took over my grandpa’s Gym! I... I’m going to burn it all!')],
                                 [L('Flannery', 'Eu preciso me acalmar e ser eu mesma. Leve a Heat Badge.', 'I need to calm down and be myself. Take the Heat Badge.')]),
    'Norman@Petalburg City': B([L('Norman', 'Então é hora. Eu sou seu pai, mas aqui, eu sou o líder. Não vou pegar leve.', 'So it’s time. I’m your father, but here, I’m the Leader. I won’t go easy.')],
                               [L('Norman', 'Agora eu sei que você vai longe. Leve a Balance Badge.', 'Now I know you’ll go far. Take the Balance Badge.')]),
    'Winona@Fortree City': B([L('Winona', 'Eu sou a maior treinadora de pássaros de Hoenn. Altaria canta no céu!', 'I’m Hoenn’s greatest bird Trainer. Altaria sings in the sky!')],
                             [L('Winona', 'Você voa mais alto. A Feather Badge é sua.', 'You fly higher. The Feather Badge is yours.')]),
    'Tate & Liza@Mossdeep City': B([L('Tate', 'Você consegue derrotar nós dois ao mesmo tempo?', 'Can you beat both of us at once?'), L('Liza', 'Nós pensamos igual.', 'We think alike.')],
                                   [L('Tate', 'Perdemos...', 'We lost...'), L('Liza', '...juntos. Leve a Mind Badge.', '...together. Take the Mind Badge.')]),
    'Wallace@Sootopolis City': B([L('Wallace', 'Eu sou Wallace. Um treinador elegante e um Milotic belo. Mostre-me sua beleza de batalha.', 'I am Wallace. An elegant Trainer and a beautiful Milotic. Show me the beauty of your battle.')],
                                 [L('Wallace', 'Que elegância. A Rain Badge é sua.', 'Such elegance. The Rain Badge is yours.')]),
    'Sidney@Ever Grande City': B([L('Sidney', 'Ei, gosto da sua cara. Vamos ter uma luta que só pode acontecer aqui!', 'Hey, I like your look. Let’s have a battle that can only happen here!')],
                                 [L('Sidney', 'Foi uma luta e tanto! Siga em frente.', 'That was some battle! Go on ahead.')]),
    'Phoebe@Ever Grande City': B([L('Phoebe', 'Eu treinei no Mt. Pyre. Os espíritos são meus amigos.', 'I trained on Mt. Pyre. The spirits are my friends.')],
                                 [L('Phoebe', 'Os espíritos gostaram de você.', 'The spirits liked you.')]),
    'Glacia@Ever Grande City': B([L('Glacia', 'Vim de longe procurar um oponente digno. Até agora, nada.', 'I came from far away looking for a worthy opponent. So far, nothing.')],
                                 [L('Glacia', 'Finalmente, um oponente digno.', 'Finally, a worthy opponent.')]),
    'Drake@Ever Grande City': B([L('Drake', 'Para vencer, você precisa entender o coração dos Pokémon.', 'To win, you must understand the hearts of Pokémon.')],
                                [L('Drake', 'Você entende. Vá até o Campeão.', 'You understand. Go to the Champion.')]),
    'Steven@Ever Grande City': B([L('Steven', 'Eu sabia. Você tem o mesmo olhar das pedras que eu coleciono: algo raro. Vamos ver se você é o verdadeiro Campeão de Hoenn.', 'I knew it. You have the same look as the stones I collect: something rare. Let’s see if you’re Hoenn’s true Champion.')],
                                 [L('Steven', 'Você é o Campeão.', 'You are the Champion.')]),
}

RUBY_SAPPHIRE = {
    'intro': 'O caminhão de mudança para em Littleroot Town, em Hoenn. Seu pai, Norman, é o novo líder de Petalburg. Na Route 101, o Professor Birch grita por socorro, fugindo de um Zigzagoon: na bolsa dele estão Treecko, Torchic e Mudkip. Você escolhe um, e a jornada começa.',
    'end': 'Steven estendeu a mão: você é o Campeão de Hoenn. O céu está limpo de novo. Um barco leva você para outra região.',
    'cities': {
        'Rustboro City': [
            L('Norman', 'Você está aqui! Ainda não pode me desafiar. Quando tiver quatro insígnias, venha.', 'You’re here! You can’t challenge me yet. Come back when you have four badges.'),
            L('Wally', 'Eu... eu capturei um Ralts! Obrigado! Agora não vou ficar sozinho.', 'I... I caught a Ralts! Thank you! Now I won’t be alone.'),
        ],
        'Dewford Town': [
            L('', 'Um homem de azul, da Equipe Aqua, roubou uma encomenda da Devon. Você a recuperou no Rusturf Tunnel.', 'A man in blue, from Team Aqua, stole a Devon package. You got it back in Rusturf Tunnel.'),
            L('Mr. Stone', 'Entregue esta carta ao meu filho, Steven, em Dewford. E estas peças ao Capitão Stern, em Slateport.', 'Deliver this letter to my son, Steven, in Dewford. And these parts to Captain Stern, in Slateport.'),
        ],
        'Mauville City': [
            L('Steven', 'Uma carta do meu pai? Obrigado. Eu coleciono pedras raras. A gente se vê por aí.', 'A letter from my father? Thank you. I collect rare stones. See you around.'),
            L('', 'Em Slateport, a Equipe Aqua tentou tomar as peças da Devon. Na Route 112, homens de vermelho, a Equipe Magma, queriam explodir o Mt. Chimney.', 'In Slateport, Team Aqua tried to take the Devon parts. On Route 112, men in red, Team Magma, wanted to blow up Mt. Chimney.'),
        ],
        'Lavaridge Town': [
            L('', 'No alto do Mt. Chimney, a Equipe Magma pôs um meteorito numa máquina para fazer o vulcão entrar em erupção. Você venceu, e o meteorito ficou com você.', 'At the top of Mt. Chimney, Team Magma put a meteorite in a machine to make the volcano erupt. You won, and the meteorite stayed with you.'),
        ],
        'Fortree City': [
            L('', 'Na Route 119, a Equipe Aqua tomou o Weather Institute atrás de Kyogre. Você os expulsou e ganhou um Castform.', 'On Route 119, Team Aqua took the Weather Institute looking for Kyogre. You drove them out and got a Castform.'),
        ],
        'Mossdeep City': [
            L('', 'No Mt. Pyre, a equipe vilã roubou uma das orbes. "Com isso, o Pokémon antigo vai acordar." Agora eles atacam o Space Center de Mossdeep.', 'On Mt. Pyre, the villainous team stole one of the orbs. "With this, the ancient Pokémon will awaken." Now they’re attacking Mossdeep’s Space Center.'),
            L('Steven', 'A gente não pode deixar que eles levem o combustível dos foguetes. Vamos juntos!', 'We can’t let them take the rocket fuel. Let’s go together!'),
        ],
        'Sootopolis City': [
            L('', 'Na Seafloor Cavern, a orbe acordou Kyogre (ou Groudon). O céu enlouqueceu: em Hoenn inteira, chuva sem fim ou sol sem trégua.', 'In the Seafloor Cavern, the orb awoke Kyogre (or Groudon). The sky went mad: all over Hoenn, endless rain or merciless sun.'),
            L('Steven', 'A Cave of Origin, em Sootopolis. É lá que ele está. Wallace vai nos ajudar.', 'The Cave of Origin, in Sootopolis. That’s where it is. Wallace will help us.'),
        ],
        'Ever Grande City': [
            L('Wally', 'Eu fiquei forte por sua causa. Agora quero ver se posso te vencer!', 'I got strong because of you. Now I want to see if I can beat you!'),
        ],
    },
    'bosses': {
        **GYMS,
        'Archie@Mauville City': B([L('Archie', 'Kyahaha! Uma criança. A Equipe Aqua quer devolver o mundo ao mar. Os Pokémon do mar precisam de mais espaço.', 'Kyahaha! A child. Team Aqua wants to return the world to the sea. Sea Pokémon need more room.')],
                                  [L('Archie', 'Kyahaha! Você tem coragem. Mas o mar sempre vence.', 'Kyahaha! You’ve got guts. But the sea always wins.')]),
        'Maxie@Mauville City': B([L('Maxie', 'A Equipe Magma quer ampliar a terra, para as pessoas viverem melhor. O mar é demais.', 'Team Magma wants to expand the land so people can live better. There’s too much sea.')],
                                 [L('Maxie', 'Hm. Você ainda não entende o nosso ideal.', 'Hm. You don’t understand our ideal yet.')]),
        'Archie@Petalburg City': B([L('Archie', 'Você de novo! O Kyogre vai encher o mundo de mar. Saia do caminho!', 'You again! Kyogre will fill the world with sea. Out of the way!')],
                                   [L('Archie', 'Grr. O Weather Institute vai nos dizer onde ele está.', 'Grr. The Weather Institute will tell us where it is.')]),
        'Maxie@Petalburg City': B([L('Maxie', 'Mais terra para as pessoas. É tão difícil de entender?', 'More land for people. Is that so hard to understand?')],
                                  [L('Maxie', 'Você atrapalha um plano maior do que você imagina.', 'You’re getting in the way of a plan bigger than you imagine.')]),
        'Archie@Mossdeep City': B([L('Archie', 'O combustível dos foguetes vai ser nosso. O mar precisa crescer!', 'The rocket fuel will be ours. The sea must grow!')],
                                  [L('Archie', 'Isso... não era o que eu queria. Eu estava errado.', 'This... isn’t what I wanted. I was wrong.')]),
        'Maxie@Mossdeep City': B([L('Maxie', 'Na sala de controle, ninguém me impede. Nem você.', 'In the control room, no one stops me. Not even you.')],
                                 [L('Maxie', 'Eu só queria ampliar a terra para as pessoas... Eu estava errado.', 'I only wanted to expand the land for people... I was wrong.')]),
    },
}

EMERALD = copy.deepcopy(RUBY_SAPPHIRE)
EMERALD['intro'] = 'Littleroot Town, Hoenn. Seu pai é o líder de Petalburg, o Professor Birch te dá o parceiro, e May, a filha dele, vira sua rival. Em Emerald, Aqua e Magma agem as duas, inimigas de você e uma da outra.'
EMERALD['end'] = 'Rayquaza separou Groudon e Kyogre, e Wallace estendeu a mão: você é o Campeão de Hoenn. Steven espera no Meteor Falls, e a Battle Frontier abre ao sul. Um barco leva você para outra região.'
for k in ['Archie@Mauville City', 'Archie@Mossdeep City', 'Steven@Ever Grande City', 'Wallace@Sootopolis City']:
    EMERALD['bosses'].pop(k)
EMERALD['cities']['Sootopolis City'] = [
    L('Archie', 'Nós... nós não controlamos isso!', 'We... we can’t control this!'),
    L('Maxie', 'Nenhum de nós podia.', 'None of us could.'),
    L('', 'Groudon e Kyogre lutavam sobre Sootopolis. No topo do Sky Pillar, Rayquaza acordou, voou até a cidade e, com um rugido, separou os dois.', 'Groudon and Kyogre were fighting over Sootopolis. At the top of the Sky Pillar, Rayquaza awoke, flew to the city and, with a roar, drove them apart.'),
]
EMERALD['bosses'].update({
    'Wally@Rustboro City': B([L('Wally', 'Eu capturei um Ralts com a sua ajuda! Será que já consigo lutar?', 'I caught a Ralts with your help! Can I battle already?')],
                             [L('Wally', 'Eu vou ficar mais forte, prometo!', 'I’ll get stronger, I promise!')]),
    'May@Rustboro City': B([L('May', 'Então você é o novo vizinho! Meu pai pediu para eu te mostrar como pesquisar Pokémon. Vamos lutar!', 'So you’re the new neighbor! My dad asked me to show you how to research Pokémon. Let’s battle!')],
                           [L('May', 'Uau, você é bom! Vou registrar isso.', 'Wow, you’re good! I’ll write that down.')]),
    'May@Mauville City': B([L('May', 'Oi de novo! Já viu a Equipe Aqua e a Magma? Que confusão. Vamos lutar para relaxar!', 'Hi again! Have you seen Team Aqua and Magma? What a mess. Let’s battle to unwind!')],
                           [L('May', 'Você está ficando forte rápido!', 'You’re getting strong fast!')]),
    'May@Lavaridge Town': B([L('May', 'As fontes termais de Lavaridge são ótimas. Mas primeiro, uma batalha!', 'Lavaridge’s hot springs are great. But first, a battle!')],
                            [L('May', 'De novo! Tudo bem, vou treinar mais.', 'Again! All right, I’ll train more.')]),
    'Wally@Petalburg City': B([L('Wally', 'O ar de Verdanturf me fez bem! Agora eu quero lutar com você de verdade.', 'Verdanturf’s air did me good! Now I want to really battle you.')],
                              [L('Wally', 'Ainda não... Mas um dia eu te alcanço.', 'Not yet... But one day I’ll catch up.')]),
    'May@Fortree City': B([L('May', 'Peguei você na ponte! Toma o HM de Fly depois da batalha!', 'Caught you on the bridge! I’ll give you HM Fly after the battle!')],
                          [L('May', 'Aqui, o HM de Fly. Voe até onde quiser!', 'Here, HM Fly. Fly wherever you want!')]),
    'May@Mossdeep City': B([L('May', 'As duas equipes estão no Space Center! Antes de ir, vamos ver se você está pronto.', 'Both teams are at the Space Center! Before you go, let’s see if you’re ready.')],
                           [L('May', 'Você está pronto. Boa sorte!', 'You’re ready. Good luck!')]),
    'Juan@Sootopolis City': B([L('Juan', 'Eu ensinei Wallace. Venha, criança, e veja o que é elegância de verdade.', 'I taught Wallace. Come, child, and see what true elegance is.')],
                              [L('Juan', 'Bravo! A Rain Badge é sua.', 'Bravo! The Rain Badge is yours.')]),
    'Wallace@Ever Grande City': B([L('Wallace', 'Eu vi sua coragem em Sootopolis. Agora veja a minha.', 'I saw your courage in Sootopolis. Now see mine.')],
                                  [L('Wallace', 'Você é o Campeão de Hoenn. Steven espera você no Meteor Falls.', 'You are Hoenn’s Champion. Steven awaits you at Meteor Falls.')]),
})

ORAS = copy.deepcopy(RUBY_SAPPHIRE)
ORAS['intro'] = 'Hoenn de novo, com a Mega Evolução. Em Littleroot Town você escolhe Treecko, Torchic ou Mudkip, e Brendan ou May, o filho do Professor Birch, vira seu rival. A mesma pedra que muda os Pokémon também mexe com os antigos.'
ORAS['end'] = 'Steven estendeu a mão: você é o Campeão. Depois, um meteoro gigante ameaçou Hoenn; Rayquaza mega-evoluiu, e lá no espaço Deoxys esperava na rocha. Um barco leva você para outra região.'
for k in [k for k in ORAS['bosses'] if k.startswith(('Archie@', 'Maxie@'))]:
    del ORAS['bosses'][k]
ADMINS = {
    'Tabitha': ('Hehehe! A Equipe Magma vai mostrar a força da terra!', 'Hehehe! Team Magma will show you the power of the land!', 'Hehehe... Isso não estava nos planos.', 'Hehehe... That wasn’t part of the plan.'),
    'Courtney': ('Análise... Você... Diversão.', 'Analysis... You... Fun.', 'Análise... Inesperado.', 'Analysis... Unexpected.'),
    'Matt': ('Bwahaha! Muito forte! Isso é ótimo!', 'Bwahaha! So strong! This is great!', 'Bwahaha! Perdi! Mas foi ótimo!', 'Bwahaha! I lost! But it was great!'),
    'Shelly': ('Ahahaha! Uma criança no caminho da Equipe Aqua? Vou te ensinar uma lição.', 'Ahahaha! A child in Team Aqua’s way? I’ll teach you a lesson.', 'Tch. Você é mais forte do que parece.', 'Tch. You’re stronger than you look.'),
}
for city in ('Mauville City', 'Petalburg City', 'Mossdeep City'):
    for who, (a, b, c, d) in ADMINS.items():
        ORAS['bosses'][f'{who}@{city}'] = B([L(who, a, b)], [L(who, c, d)])
RIVAL = {
    'Rustboro City': ('Então você é o novo vizinho! Meu pai pediu para eu te mostrar como pesquisar Pokémon. Vamos lutar!', 'So you’re the new neighbor! My dad asked me to show you how to research Pokémon. Let’s battle!'),
    'Mauville City': ('Ouvi falar das equipes Aqua e Magma. Vamos ver se estamos prontos!', 'I’ve heard about Team Aqua and Magma. Let’s see if we’re ready!'),
    'Petalburg City': ('Seu pai é forte, sabia? Mas primeiro, eu!', 'Your dad is strong, you know? But first, me!'),
    'Mossdeep City': ('As duas equipes estão em Mossdeep. Vamos lutar antes que tudo dê errado!', 'Both teams are in Mossdeep. Let’s battle before everything goes wrong!'),
}
for city, (a, b) in RIVAL.items():
    ORAS['bosses'][f'Brendan/May@{city}'] = B([L('Brendan/May', a, b)], [L('Brendan/May', 'Você é forte demais! Vou treinar mais.', 'You’re too strong! I’ll train more.')])
ORAS['bosses'].update({
    'Wally@Rustboro City': B([L('Wally', 'Eu capturei um Ralts com a sua ajuda! Será que já consigo lutar?', 'I caught a Ralts with your help! Can I battle already?')],
                             [L('Wally', 'Eu vou ficar mais forte, prometo!', 'I’ll get stronger, I promise!')]),
    'Wally@Petalburg City': B([L('Wally', 'O meu Ralts evoluiu! Agora eu quero lutar com você de verdade.', 'My Ralts evolved! Now I want to really battle you.')],
                              [L('Wally', 'Um dia eu te alcanço, você vai ver.', 'One day I’ll catch up, you’ll see.')]),
    'Maxie@Lavaridge Town': B([L('Maxie', 'O Mt. Chimney vai entrar em erupção, e a terra vai crescer. Não se meta.', 'Mt. Chimney will erupt, and the land will grow. Stay out of it.')],
                              [L('Maxie', 'Hm. O meteorito fica com você... por enquanto.', 'Hm. The meteorite stays with you... for now.')]),
    'Archie@Lavaridge Town': B([L('Archie', 'Kyahaha! Se a Magma quer o vulcão, a Aqua vai impedir. E você também!', 'Kyahaha! If Magma wants the volcano, Aqua will stop them. And you too!')],
                               [L('Archie', 'Kyahaha! Você tem coragem.', 'Kyahaha! You’ve got guts.')]),
    'Maxie@Fortree City': B([L('Maxie', 'O Weather Institute sabe onde está Groudon. Saia do caminho.', 'The Weather Institute knows where Groudon is. Out of the way.')],
                            [L('Maxie', 'Isso só adia o inevitável.', 'This only delays the inevitable.')]),
    'Archie@Fortree City': B([L('Archie', 'Kyogre vai encher o mundo de mar. Nem você me para!', 'Kyogre will fill the world with sea. Not even you will stop me!')],
                             [L('Archie', 'Grr... A orbe vai resolver isso.', 'Grr... The orb will settle this.')]),
})

GAMES = {
    'Hoenn|Ruby/Sapphire': RUBY_SAPPHIRE,
    'Hoenn|Emerald': EMERALD,
    'Hoenn|Omega Ruby/Alpha Sapphire': ORAS,
}
