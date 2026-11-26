"""Sinnoh e Hisui: Diamond/Pearl, Platinum, Brilliant Diamond/Shining Pearl e Legends: Arceus (docs/historia/04-sinnoh-hisui.md)."""
import copy

from .kanto import B, L

GYMS = {
    'Roark@Oreburgh City': B([L('Roark', 'Eu sou o líder de Oreburgh e trabalho na mina. Nossas pedras são duras!', 'I’m Oreburgh’s Leader and I work in the mine. Our rocks are tough!')],
                             [L('Roark', 'Você cavou mais fundo. A Coal Badge é sua.', 'You dug deeper. The Coal Badge is yours.')]),
    'Gardenia@Eterna City': B([L('Gardenia', 'Eu amo plantas! E a sua equipe? Também é fofa? Vamos ver!', 'I love plants! And your team? Is it cute too? Let’s see!')],
                              [L('Gardenia', 'Que equipe linda e forte! Leve a Forest Badge.', 'What a lovely, strong team! Take the Forest Badge.')]),
    'Fantina@Hearthome City': B([L('Fantina', 'Ah, você veio! Meus Pokémon fantasmas dançam no escuro. Vamos ver!', 'Ah, you came! My Ghost Pokémon dance in the dark. Let’s see!')],
                                [L('Fantina', 'Magnifique! A Relic Badge é sua.', 'Magnifique! The Relic Badge is yours.')]),
    'Maylene@Veilstone City': B([L('Maylene', 'Eu não sei se sou boa o bastante. Mas eu vou lutar com tudo.', 'I don’t know if I’m good enough. But I’ll fight with everything I have.')],
                                [L('Maylene', 'Obrigada. Agora sei o que preciso treinar. Leve a Cobble Badge.', 'Thank you. Now I know what to train. Take the Cobble Badge.')]),
    'Wake@Pastoria City': B([L('Wake', 'Eu sou o Crasher Wake! A onda é minha!', 'I’m Crasher Wake! The wave is mine!')],
                            [L('Wake', 'Que onda! A Fen Badge é sua!', 'What a wave! The Fen Badge is yours!')]),
    'Byron@Canalave City': B([L('Byron', 'Ha! Meu filho perdeu? Então eu vou mostrar como se faz!', 'Ha! My son lost? Then I’ll show you how it’s done!')],
                             [L('Byron', 'Hahaha! Que força! Leve a Mine Badge.', 'Hahaha! What strength! Take the Mine Badge.')]),
    'Candice@Snowpoint City': B([L('Candice', 'Foco total! Meus Pokémon de gelo vão te congelar!', 'Total focus! My Ice Pokémon will freeze you!')],
                                [L('Candice', 'Que foco! A Icicle Badge é sua.', 'What focus! The Icicle Badge is yours.')]),
    'Volkner@Sunyshore City': B([L('Volkner', 'Eu cansei. Ninguém me desafia. Por favor, me mostre algo diferente.', 'I’m bored. No one challenges me. Please, show me something different.')],
                                [L('Volkner', 'Isso! Era disso que eu precisava. Leve a Beacon Badge.', 'Yes! That’s what I needed. Take the Beacon Badge.')]),
    'Aaron@Pokémon League': B([L('Aaron', 'Insetos são bonitos e fortes. Vou provar!', 'Bugs are beautiful and strong. I’ll prove it!')], [L('Aaron', 'Você é forte. Siga em frente.', 'You’re strong. Go on ahead.')]),
    'Bertha@Pokémon League': B([L('Bertha', 'Ah, que jovem. Eu sou só uma avó, mas não sou fraca!', 'Oh, how young. I’m just a grandma, but I’m not weak!')], [L('Bertha', 'Muito bem, querido. Continue.', 'Very good, dear. Keep going.')]),
    'Flint@Pokémon League': B([L('Flint', 'Meu fogo vai acender sua alma!', 'My fire will light up your soul!')], [L('Flint', 'Sua alma queima mais forte. Vá!', 'Your soul burns brighter. Go!')]),
    'Lucian@Pokémon League': B([L('Lucian', 'Eu estava lendo. Vamos ver o que o próximo capítulo me traz.', 'I was reading. Let’s see what the next chapter brings me.')], [L('Lucian', 'Um ótimo capítulo. A Campeã espera.', 'A great chapter. The Champion awaits.')]),
    'Cynthia@Pokémon League': B([L('Cynthia', 'Eu esperei por você. Pokémon... Você entende o que eles são? Me mostre na batalha.', 'I’ve been waiting for you. Pokémon... Do you understand what they are? Show me in battle.')],
                                [L('Cynthia', 'Você me fez lembrar por que eu amo Pokémon. Você é o Campeão de Sinnoh.', 'You reminded me why I love Pokémon. You are Sinnoh’s Champion.')]),
}

BARRY = {
    'Oreburgh City': ('Eu já ganhei! Mentira. Vamos lutar! Se perder, te multo em um milhão!', 'I already won! Just kidding. Let’s battle! If you lose, I’ll fine you a million!'),
    'Eterna City': ('Ei! Você viu aqueles caras de cabelo turquesa? Esquece. Batalha!', 'Hey! Did you see those turquoise-haired guys? Forget it. Battle!'),
    'Hearthome City': ('Hearthome é a cidade das amizades. E amigos lutam, né? Vamos!', 'Hearthome is the city of friendship. And friends battle, right? Let’s go!'),
    'Veilstone City': ('A Galactic tem um prédio enorme aqui! Mas antes, você e eu!', 'Galactic has a huge building here! But first, you and me!'),
    'Canalave City': ('A biblioteca de Canalave tem as lendas dos lagos. Depois da batalha eu leio!', 'Canalave’s library has the lake legends. I’ll read them after the battle!'),
    'Snowpoint City': ('Que frio! Uma batalha esquenta. Vamos!', 'So cold! A battle will warm us up. Let’s go!'),
    'Sunyshore City': ('Eu vou ser forte como meu pai! Ele é o Tower Tycoon, sabia?', 'I’m going to be strong like my dad! He’s the Tower Tycoon, you know?'),
}

DIAMOND_PEARL = {
    'intro': 'Em Twinleaf Town, a TV mostra um Gyarados vermelho num lago. Barry, seu melhor amigo, bate na porta: "Rápido, eu te multo em um milhão se você se atrasar!" No Lake Verity, uma maleta esquecida do Professor Rowan: Turtwig, Chimchar e Piplup. Um bando de Starly ataca, e cada um pega um.',
    'end': 'Garchomp caiu por último, e Cynthia sorriu: você é o Campeão de Sinnoh. Um barco leva você para outra região.',
    'cities': {
        'Oreburgh City': [
            L('Rowan', 'Vocês usaram meus Pokémon sem permissão. Pois vão cuidar deles direito. E vão me ajudar a pesquisar.', 'You used my Pokémon without permission. Then you’ll take good care of them. And you’ll help my research.'),
        ],
        'Eterna City': [
            L('', 'Na Valley Windworks, homens de roupa espacial e cabelo turquesa, a Equipe Galactic, prenderam um homem para roubar energia.', 'At Valley Windworks, men in space suits with turquoise hair, Team Galactic, held a man to steal energy.'),
            L('Cynthia', 'Dialga, senhor do tempo. Palkia, senhora do espaço. E um terceiro, esquecido. As histórias de Sinnoh são todas sobre eles.', 'Dialga, lord of time. Palkia, lady of space. And a third, forgotten one. All of Sinnoh’s stories are about them.'),
        ],
        'Veilstone City': [
            L('', 'Em Veilstone fica a sede da Equipe Galactic, um prédio enorme no meio da pedra.', 'Veilstone is home to Team Galactic’s headquarters, a huge building carved into the rock.'),
        ],
        'Pastoria City': [
            L('', 'No Great Marsh, a Galactic ameaçou explodir o Lake Valor com uma bomba.', 'In the Great Marsh, Galactic threatened to blow up Lake Valor with a bomb.'),
        ],
        'Canalave City': [
            L('Rowan', 'Uxie, Mesprit e Azelf: os três espíritos dos lagos. Saber, emoção e vontade. Se alguém os prender...', 'Uxie, Mesprit and Azelf: the three lake spirits. Knowledge, emotion and willpower. If someone captures them...'),
        ],
        'Snowpoint City': [
            L('', 'Explosões sacudiram o Lake Valor e o Lake Verity. Os três espíritos foram presos em tubos na base da Galactic.', 'Explosions shook Lake Valor and Lake Verity. The three spirits were locked in tubes at the Galactic base.'),
        ],
        'Sunyshore City': [
            L('', 'No topo do Mt. Coronet, em Spear Pillar, Cyrus usou a Red Chain. Uxie, Mesprit e Azelf voltaram e quebraram a corrente, e o lendário ficou livre.', 'At the top of Mt. Coronet, at Spear Pillar, Cyrus used the Red Chain. Uxie, Mesprit and Azelf returned and broke the chain, and the legendary was freed.'),
            L('Cyrus', 'Por quê...? Eu fiz tudo certo. Não importa. Eu vou descobrir o segredo de novo.', 'Why...? I did everything right. It doesn’t matter. I’ll discover the secret again.'),
        ],
    },
    'bosses': {
        **GYMS,
        **{f'Barry@{c}': B([L('Barry', a, b)], [L('Barry', 'Aaah! Perdi! Vou treinar e te multar depois!', 'Aaah! I lost! I’ll train and fine you later!')]) for c, (a, b) in BARRY.items()},
        'Mars@Eterna City': B([L('Mars', 'Ai, que chato. A gente só quer a energia. Para o universo novo do nosso chefe.', 'Ugh, how boring. We just want the energy. For our boss’s new universe.')],
                              [L('Mars', 'Que irritante. O prédio de Eterna é nosso, não esqueça.', 'How annoying. The Eterna building is ours, don’t forget.')]),
        'Jupiter@Hearthome City': B([L('Jupiter', 'Hm. Uma criança que atrapalha a Galactic. Logo vamos dar um jeito em você.', 'Hm. A child who meddles with Galactic. We’ll deal with you soon.')],
                                    [L('Jupiter', 'Interessante. O chefe vai querer saber de você.', 'Interesting. The boss will want to hear about you.')]),
        'Saturn@Canalave City': B([L('Saturn', 'A Equipe Galactic vai capturar os três espíritos dos lagos. Com eles, nosso chefe vai fazer a Red Chain.', 'Team Galactic will capture the three lake spirits. With them, our boss will make the Red Chain.')],
                                  [L('Saturn', 'Tarde demais. Ouça: a explosão no Lake Valor já começou.', 'Too late. Listen: the explosion at Lake Valor has already begun.')]),
        'Mars@Snowpoint City': B([L('Mars', 'Você de novo? Os espíritos ficam com a gente!', 'You again? The spirits stay with us!')], [L('Mars', 'Ai! Saturn, é com você.', 'Ugh! Saturn, it’s up to you.')]),
        'Saturn@Snowpoint City': B([L('Saturn', 'Ninguém passa daqui. Os tubos dos espíritos estão logo atrás de mim.', 'No one gets past here. The spirits’ tubes are right behind me.')], [L('Saturn', 'O chefe espera você.', 'The boss is waiting for you.')]),
        'Cyrus@Snowpoint City': B([L('Cyrus', 'As emoções são inúteis. O mundo é imperfeito. Eu vou criar um novo, sem espírito, sem dor. Para isso, preciso de Dialga e Palkia.', 'Emotions are useless. The world is imperfect. I will create a new one, without spirit, without pain. For that, I need Dialga and Palkia.')],
                                  [L('Cyrus', 'Agora vou criar o mundo que eu quero. Só para mim. Spear Pillar me espera.', 'Now I will create the world I want. Just for me. Spear Pillar awaits.')]),
    },
}

PLATINUM = copy.deepcopy(DIAMOND_PEARL)
PLATINUM['intro'] = 'Sinnoh de novo, mais sombria. Em Twinleaf Town, Barry te arrasta até o Lake Verity, onde vocês pegam os Pokémon do Professor Rowan. Uma sombra antiga espera do outro lado do mundo: Giratina, banido por Arceus.'
PLATINUM['end'] = 'Cyrus ficou no Distortion World, e Giratina voltou para a sombra. Cynthia sorriu: você é o Campeão de Sinnoh. Um barco leva você para outra região.'
for k in ['Mars@Eterna City', 'Jupiter@Hearthome City', 'Saturn@Canalave City', 'Saturn@Snowpoint City']:
    PLATINUM['bosses'].pop(k)
PLATINUM['cities']['Sunyshore City'] = [
    L('', 'Em Spear Pillar, Cyrus chamou Dialga e Palkia ao mesmo tempo. Uma sombra saiu de um buraco no céu e o arrastou: Giratina.', 'At Spear Pillar, Cyrus summoned Dialga and Palkia at the same time. A shadow came out of a hole in the sky and dragged him away: Giratina.'),
    L('Cyrus', 'Um mundo sem espírito... Eu achei que fosse perfeito. Eu ainda vou encontrar o caminho.', 'A world without spirit... I thought it would be perfect. I will still find the way.'),
]
PLATINUM['bosses'].update({
    'Mars@Hearthome City': B([L('Mars', 'Ai, que chato. A gente só quer a energia. Para o universo novo do nosso chefe.', 'Ugh, how boring. We just want the energy. For our boss’s new universe.')], [L('Mars', 'Que irritante!', 'How annoying!')]),
    'Cyrus@Hearthome City': B([L('Cyrus', 'As pessoas vivem presas às emoções. Eu vou libertar o mundo delas.', 'People live trapped by their emotions. I will free the world from them.')], [L('Cyrus', 'Interessante. Nos veremos.', 'Interesting. We will meet again.')]),
    'Jupiter@Veilstone City': B([L('Jupiter', 'Hm. Uma criança que atrapalha a Galactic. Logo vamos dar um jeito em você.', 'Hm. A child who meddles with Galactic. We’ll deal with you soon.')], [L('Jupiter', 'O chefe vai saber disso.', 'The boss will hear about this.')]),
    'Saturn@Veilstone City': B([L('Saturn', 'A sede da Galactic não é lugar para crianças.', 'Galactic’s headquarters is no place for children.')], [L('Saturn', 'Hm. Você é persistente.', 'Hm. You’re persistent.')]),
    'Mars@Pastoria City': B([L('Mars', 'O Great Marsh é só o começo. Some daqui!', 'The Great Marsh is just the beginning. Get lost!')], [L('Mars', 'Ai! De novo!', 'Ugh! Again!')]),
    'Cyrus@Pastoria City': B([L('Cyrus', 'Os três espíritos dos lagos serão meus. Você não entende o que está em jogo.', 'The three lake spirits will be mine. You don’t understand what’s at stake.')], [L('Cyrus', 'Isso não muda nada.', 'This changes nothing.')]),
    'Jupiter@Canalave City': B([L('Jupiter', 'O Lake Valor vai explodir. Você não chega a tempo.', 'Lake Valor is going to explode. You won’t make it in time.')], [L('Jupiter', 'Tarde demais.', 'Too late.')]),
    'Saturn@Canalave City': B([L('Saturn', 'A Red Chain está quase pronta.', 'The Red Chain is almost ready.')], [L('Saturn', 'O chefe vai conseguir.', 'The boss will succeed.')]),
    'Barry@Pokémon League': B([L('Barry', 'Você venceu a Cynthia?! Eu também quero! Mas primeiro, você!', 'You beat Cynthia?! I want to too! But first, you!')], [L('Barry', 'Um dia eu te alcanço. Promessa!', 'One day I’ll catch up. Promise!')]),
    'Jupiter@Pokémon League': B([L('Jupiter', 'A Galactic ainda não acabou. Charon assumiu.', 'Galactic isn’t finished yet. Charon took over.')], [L('Jupiter', 'Talvez seja hora de parar.', 'Maybe it’s time to stop.')]),
    'Mars@Pokémon League': B([L('Mars', 'O Cyrus foi embora sem a gente... Uma última luta!', 'Cyrus left without us... One last battle!')], [L('Mars', 'Acho que eu vou procurar um novo caminho.', 'I think I’ll look for a new path.')]),
})

BDSP = copy.deepcopy(DIAMOND_PEARL)
BDSP['intro'] = 'A história de Diamond/Pearl de novo, com Twinleaf Town, Barry e a maleta do Professor Rowan no Lake Verity. O Grand Underground esconde cavernas e Pokémon raros.'
BDSP['end'] = 'Cynthia sorriu: você é o Campeão de Sinnoh. O Ramanas Park abre, com lendários de outras regiões. Um barco leva você para outra região.'
for k in [k for k in BDSP['bosses'] if k.split('@')[0] in ('Mars', 'Jupiter', 'Saturn', 'Cyrus') or k in ('Barry@Eterna City', 'Barry@Sunyshore City')]:
    del BDSP['bosses'][k]
BDSP['bosses'].update({
    'Cyrus@Veilstone City': B([L('Cyrus', 'As emoções são inúteis. Eu vou criar um mundo novo, sem espírito, sem dor.', 'Emotions are useless. I will create a new world, without spirit, without pain.')], [L('Cyrus', 'Interessante. Nos veremos.', 'Interesting. We will meet again.')]),
    'Cyrus@Canalave City': B([L('Cyrus', 'Os três espíritos dos lagos serão meus. Com eles, a Red Chain.', 'The three lake spirits will be mine. With them, the Red Chain.')], [L('Cyrus', 'Spear Pillar me espera.', 'Spear Pillar awaits.')]),
    'Barry@Pokémon League': B([L('Barry', 'Você é o Campeão agora? Então eu tenho que te vencer!', 'You’re the Champion now? Then I have to beat you!')], [L('Barry', 'De novo... Mas eu não desisto!', 'Again... But I won’t give up!')]),
})

LEGENDS_ARCEUS = {
    'intro': 'Uma voz fala dentro da sua cabeça: "Encontre todos os Pokémon desta região." Você cai do céu numa praia de Hisui, a antiga Sinnoh, muito antes das cidades. O Professor Laventon te mostra Rowlet, Cyndaquil e Oshawott, e leva você para Jubilife Village, sede da Galaxy Expedition Team.',
    'end': 'Volo perdeu, Giratina voltou para a sombra, e Arceus chamou você no topo do Mt. Coronet. Hisui está em paz. Uma fenda no céu leva você para outra região.',
    'cities': {
        'Obsidian Fieldlands': [
            L('Kamado', 'Alguém que cai do céu... Isso não é normal. Mas se você é útil, fique.', 'Someone who falls from the sky... That isn’t normal. But if you’re useful, stay.'),
            L('', 'Os Nobles, Pokémon enormes protegidos pelos clãs, estão furiosos por causa da fenda no céu.', 'The Nobles, huge Pokémon protected by the clans, are furious because of the rift in the sky.'),
        ],
        'Crimson Mirelands': [
            L('', 'Os dois clãs de Hisui não se entendem: o Diamond Clan venera o tempo (Dialga), e o Pearl Clan, o espaço (Palkia).', 'Hisui’s two clans don’t get along: the Diamond Clan worships time (Dialga), and the Pearl Clan, space (Palkia).'),
        ],
        'Coronet Highlands': [
            L('Kamado', 'Desde que você chegou, o céu piora. Você trouxe o desastre. Está banido de Jubilife.', 'Since you arrived, the sky has gotten worse. You brought disaster. You’re banished from Jubilife.'),
            L('', 'Adaman e Irida acolheram você e, pela primeira vez, falaram juntos.', 'Adaman and Irida took you in and, for the first time, spoke together.'),
        ],
        'Temple of Sinnoh': [
            L('', 'Com as Red Chain, vocês subiram ao Temple of Sinnoh. Dialga e Palkia apareceram na Forma Origem, enlouquecidos. Você venceu, e o céu se fechou.', 'With the Red Chains, you climbed to the Temple of Sinnoh. Dialga and Palkia appeared in their Origin Forms, enraged. You won, and the sky closed.'),
        ],
    },
    'bosses': {
        'Akari@Obsidian Fieldlands': B([L('Akari', 'Vamos trabalhar juntos! A gente precisa completar a Pokédex.', 'Let’s work together! We need to complete the Pokédex.')], [L('Akari', 'Você leva jeito! Vamos acalmar os Nobles.', 'You’ve got a knack for this! Let’s calm the Nobles.')]),
        'Lian@Obsidian Fieldlands': B([L('Lian', 'Eu sou o guardião de Kleavor. Ele está furioso. Mostre que pode ajudar!', 'I’m Kleavor’s warden. It’s furious. Show me you can help!')], [L('Lian', 'Kleavor se acalmou. Obrigado!', 'Kleavor has calmed down. Thank you!')]),
        'Adaman@Crimson Mirelands': B([L('Adaman', 'Então você é o tal que caiu do céu. Lute comigo. Se for forte, eu confio.', 'So you’re the one who fell from the sky. Fight me. If you’re strong, I’ll trust you.')], [L('Adaman', 'Você é forte. O Diamond Clan confia em você.', 'You’re strong. The Diamond Clan trusts you.')]),
        'Arezu@Crimson Mirelands': B([L('Arezu', 'Lady Lilligant dança em fúria no meio da névoa. Me ajude a acalmá-la!', 'Lady Lilligant is dancing in a rage in the mist. Help me calm her!')], [L('Arezu', 'Ela parou de dançar... Obrigada!', 'She stopped dancing... Thank you!')]),
        'Akari@Cobalt Coastlands': B([L('Akari', 'A Pokédex está crescendo! Vamos ver como está o seu time.', 'The Pokédex is growing! Let’s see how your team is doing.')], [L('Akari', 'Incrível! Continue assim.', 'Amazing! Keep it up.')]),
        'Irida@Cobalt Coastlands': B([L('Irida', 'Eu sou Irida, do Pearl Clan. Quero ver com meus próprios olhos o que você faz.', 'I’m Irida, of the Pearl Clan. I want to see with my own eyes what you can do.')], [L('Irida', 'Vi. O Pearl Clan confia em você.', 'I’ve seen it. The Pearl Clan trusts you.')]),
        'Melli@Cobalt Coastlands': B([L('Melli', 'Um forasteiro tomando conta dos nossos Nobles? Prove que merece, se puder!', 'An outsider looking after our Nobles? Prove you deserve it, if you can!')], [L('Melli', 'Hmpf. Tá, você merece. Lady Arcanine está nas pedras da costa.', 'Hmph. Fine, you deserve it. Lady Arcanine is on the coastal rocks.')]),
        'Kamado@Coronet Highlands': B([L('Kamado', 'Eu protejo esta vila. Se for preciso lutar contra o céu inteiro, eu luto.', 'I protect this village. If I must fight the whole sky, I will.')], [L('Kamado', 'Talvez eu estivesse errado sobre você.', 'Perhaps I was wrong about you.')]),
        'Ingo@Coronet Highlands': B([L('Ingo', 'Eu não sei de onde vim. Mas sei lutar! Partida! Todos a bordo!', 'I don’t know where I came from. But I know how to battle! Departure! All aboard!')], [L('Ingo', 'Fim da linha! Lord Electrode está nas encostas.', 'End of the line! Lord Electrode is on the slopes.')]),
        'Akari@Alabaster Icelands': B([L('Akari', 'Falta só um Noble! Vamos juntos até o fim.', 'Just one Noble left! Let’s go to the end together.')], [L('Akari', 'Estou orgulhosa de você.', 'I’m proud of you.')]),
        'Gaeric@Alabaster Icelands': B([L('Gaeric', 'Brrr! Eu não suporto o frio, mas vivo nele. Lord Avalugg espera. Primeiro, eu!', 'Brrr! I can’t stand the cold, but I live in it. Lord Avalugg awaits. First, me!')], [L('Gaeric', 'Você aquece até o gelo. Vá!', 'You warm even the ice. Go!')]),
        'Volo@Temple of Sinnoh': B([L('Volo', 'Eu queria o poder de Arceus. Para isso, precisava que alguém juntasse as placas. Obrigado, você fez tudo por mim.', 'I wanted Arceus’s power. For that, I needed someone to gather the plates. Thank you, you did it all for me.')],
                                   [L('Volo', 'Ah, você é forte mesmo. Eu só queria criar um mundo novo, perfeito, sem as dores deste.', 'Ah, you really are strong. I only wanted to create a new, perfect world, without this one’s pain.')]),
    },
}

GAMES = {
    'Sinnoh|Diamond/Pearl': DIAMOND_PEARL,
    'Sinnoh|Platinum': PLATINUM,
    'Sinnoh|Brilliant Diamond/Shining Pearl': BDSP,
    'Hisui|Legends: Arceus': LEGENDS_ARCEUS,
}
