"""Kanto: Red/Blue, Yellow e FireRed/LeafGreen (docs/historia/01-kanto.md)."""


def L(who, pt, en):
    return (who, pt, en)


def B(before=None, after=None, last=None):
    out = {}
    if before:
        out['before'] = before
    if after:
        out['after'] = after
    if last:
        out['last'] = last
    return out


RED_BLUE = {
    'intro': 'Em Pallet Town, sua mãe avisa: o Professor Oak está te procurando. No laboratório, você escolhe seu primeiro parceiro, e Blue, o neto dele, pega o que tem vantagem sobre o seu. "Vamos ver quem escolheu melhor!" A jornada começa na Route 1.',
    'end': 'Seu nome está no Hall da Fama de Kanto. Do lado de Cerulean, uma caverna trancada se abriu, e um barco no porto leva você para outra região.',
    'cities': {
        'Pewter City': [
            L('', 'Depois da Viridian Forest e dos seus Caterpie, as casas de pedra de Pewter City. O museu exibe um fóssil de Kabutops.',
              'Past Viridian Forest and its Caterpie lie the stone houses of Pewter City. The museum shows a Kabutops fossil.'),
            L('Oak', 'Esta é a Pokédex, uma enciclopédia que se completa sozinha. Meu sonho de registrar todos os Pokémon agora é de vocês.',
              'This is the Pokédex, an encyclopedia that fills itself in. My dream of recording every Pokémon is yours now.'),
        ],
        'Cerulean City': [
            L('', 'No Mt. Moon, homens de preto com um R vermelho no peito cavavam atrás de fósseis. Você venceu os capangas e levou um fóssil, o Dome ou o Helix.',
              'In Mt. Moon, men in black with a red R on their chests were digging for fossils. You beat the grunts and took a fossil, the Dome or the Helix.'),
            L('', 'Em Cerulean, uma casa foi assaltada: um Rocket levou um TM de Dig e fugiu pela parede quebrada.',
              'In Cerulean, a house was robbed: a Rocket took a Dig TM and fled through the broken wall.'),
        ],
        'Vermilion City': [
            L('Bill', 'Obrigado por me desmisturar daquele Clefairy! Leve este ingresso para o S.S. Anne, o navio atracado em Vermilion.',
              'Thanks for unmixing me from that Clefairy! Take this ticket for the S.S. Anne, the ship docked in Vermilion.'),
            L('', 'No S.S. Anne, o capitão estava enjoado. Você esfregou as costas dele até passar, e ele deu o HM de Cut.',
              'On the S.S. Anne, the captain was seasick. You rubbed his back until it passed, and he gave you HM Cut.'),
        ],
        'Celadon City': [
            L('', 'Em Lavender Town, uma névoa fantasma impede a subida da Pokémon Tower. Em Celadon, a cidade mais colorida de Kanto, um Rocket vigia um pôster no Game Corner.',
              'In Lavender Town, a ghostly mist blocks the way up Pokémon Tower. In Celadon, Kanto’s most colorful city, a Rocket guards a poster in the Game Corner.'),
        ],
        'Fuchsia City': [
            L('', 'Atrás do pôster, o Rocket Hideout. Giovanni largou o Silph Scope, e a névoa da torre virou forma: o fantasma de uma Marowak, morta pela Rocket defendendo o filho.',
              'Behind the poster lay the Rocket Hideout. Giovanni dropped the Silph Scope, and the tower’s mist took shape: the ghost of a Marowak, killed by Rocket defending her child.'),
            L('Mr. Fuji', 'Obrigado por me salvar. O espírito dela descansa agora. Com esta Poké Flute, até o Snorlax mais pesado acorda.',
              'Thank you for saving me. Her spirit rests now. With this Poké Flute, even the heaviest Snorlax wakes up.'),
        ],
        'Saffron City': [
            L('', 'Saffron City está cercada: a Equipe Rocket ocupou a Silph Co., a maior fábrica de Poké Balls do mundo. Um copo de chá amoleceu o guarda do portão.',
              'Saffron City is under siege: Team Rocket has taken Silph Co., the world’s biggest Poké Ball maker. A cup of tea softened the gate guard.'),
        ],
        'Cinnabar Island': [
            L('', 'Com Surf, você chegou a Cinnabar. No diário da mansão queimada: cientistas clonaram o mítico Mew, e o clone, Mewtwo, forte demais e cheio de raiva, fugiu.',
              'With Surf, you reached Cinnabar. In the burned mansion’s journal: scientists cloned the mythical Mew, and the clone, Mewtwo, too strong and full of rage, escaped.'),
        ],
        'Indigo Plateau': [
            L('', 'O ginásio de Viridian, sempre fechado, abriu. Depois dele, a Victory Road e o Indigo Plateau, onde a Elite dos Quatro espera.',
              'Viridian’s ever-closed Gym opened. After it come Victory Road and Indigo Plateau, where the Elite Four waits.'),
        ],
    },
    'bosses': {
        'Blue@Pewter City': B(
            [L('Blue', 'Demorou, hein? Já vi o Brock lutar, ele é duro feito pedra. Mas antes, vamos ver se você melhorou!',
               'Took you long enough! I’ve seen Brock fight, he’s hard as a rock. But first, let’s see if you got any better!')],
            [L('Blue', 'Hunf. Eu vou ficar mais forte. Diga tchau, perdedor!', 'Hmph. I’ll get stronger. Smell ya later!')]),
        'Brock@Pewter City': B(
            [L('Brock', 'Eu sou Brock, o líder de Pewter. Acredito em defesa sólida e determinação. Minhas rochas não racham fácil.',
               'I’m Brock, Pewter’s Gym Leader. I believe in rock-hard defense and determination. My rocks don’t crack easily.')],
            [L('Brock', 'Você é o tipo de treinador que ainda vai longe. Leve a Boulder Badge e siga para Cerulean.',
               'You’re the kind of Trainer who’ll go far. Take the Boulder Badge and head for Cerulean.')]),
        'Blue@Cerulean City': B(
            [L('Blue', 'Ei! Ainda está nessa? Pegou quantos Pokémon? Eu já tenho uma porção! Vamos!',
               'Hey! Still at it? How many Pokémon have you caught? I’ve got a bunch! Let’s go!')],
            [L('Blue', 'Tá, tá. Vou visitar o Bill, um Pokémaníaco que mora no fim da Route 25. Até mais!',
               'Yeah, yeah. I’m off to see Bill, a Poké Maniac at the end of Route 25. Later!')]),
        'Misty@Cerulean City': B(
            [L('Misty', 'Minha política é ataque total com Pokémon de água! Se quiser a Cascade Badge, vai ter que se molhar.',
               'My policy is an all-out attack with Water Pokémon! If you want the Cascade Badge, you’ll have to get wet.')],
            [L('Misty', 'Tá bom, tá bom. Você é bom mesmo. Leve a insígnia.', 'Okay, okay. You really are good. Take the badge.')]),
        'Blue@Vermilion City': B(
            [L('Blue', 'E aí? Também veio no navio? Você nem sabe por que está aqui. Vamos ver se você aguenta!',
               'Well? You came on the ship too? You don’t even know why you’re here. Let’s see if you can keep up!')],
            [L('Blue', 'Ouvi dizer que tem um Pokémon que corta árvores. Vou atrás dele antes de você!', 'I heard there’s a Pokémon move that cuts trees. I’ll get it before you!')]),
        'Lt. Surge@Vermilion City': B(
            [L('Lt. Surge', 'Ei, garoto! Sabe por que os Pokémon elétricos me salvaram na guerra? Eles paralisavam o inimigo! E vão fazer o mesmo com você!',
               'Hey, kid! Know why Electric Pokémon saved me in the war? They paralyzed the enemy! And they’ll do the same to you!')],
            [L('Lt. Surge', 'Uau, você é eletrizante! Leve a Thunder Badge!', 'Whoa, you’re electrifying! Take the Thunder Badge!')]),
        'Blue@Celadon City': B(
            [L('Blue', 'Ei, você! Eu já vi o fantasma da torre. Não tenho medo de nada! Vamos lutar!',
               'Hey, you! I’ve seen the tower’s ghost. I’m not scared of anything! Let’s battle!')],
            [L('Blue', 'Hunf. O fantasma era mais assustador que você.', 'Hmph. That ghost was scarier than you.')]),
        'Erika@Celadon City': B(
            [L('Erika', 'Ah... desculpe, eu adormeci. Sou Erika. Amo plantas, flores e chá. Não perco para quem não respeita a natureza.',
               'Oh... I’m sorry, I dozed off. I’m Erika. I love plants, flowers and tea. I won’t lose to someone who doesn’t respect nature.')],
            [L('Erika', 'Você respeita a natureza, eu vejo. Leve a Rainbow Badge.', 'You do respect nature, I see. Take the Rainbow Badge.')]),
        'Giovanni@Fuchsia City': B(
            [L('Giovanni', 'Você de novo. A Silph Co. é minha agora. Não vou deixar uma criança estragar isso.',
               'You again. Silph Co. is mine now. I won’t let a child ruin it.')],
            [L('Giovanni', 'Hm. Você entende a força que tem? Nos veremos de novo.', 'Hm. Do you understand the strength you have? We’ll meet again.')]),
        'Blue@Fuchsia City': B(
            [L('Blue', 'Ei! Vi o chefão da Rocket indo embora. Foi você? Que nada... Vamos lutar!',
               'Hey! I saw the Rocket boss leaving. Was that you? No way... Let’s battle!')],
            [L('Blue', 'Tá, foi sorte. Vou para Saffron.', 'Fine, that was luck. I’m heading to Saffron.')]),
        'Koga@Fuchsia City': B(
            [L('Koga', 'Fwahahaha! Um ninja sabe que a vitória vem da paciência. Venenos e ilusões, criança!',
               'Fwahahaha! A ninja knows victory comes from patience. Poison and illusion, child!')],
            [L('Koga', 'Hmm! Você tem a paciência de um ninja. A Soul Badge é sua.', 'Hmm! You have a ninja’s patience. The Soul Badge is yours.')]),
        'Giovanni@Saffron City': B(
            [L('Giovanni', 'O protótipo da Master Ball será nosso. Você de novo... Não há outro jeito. Vou acabar com isso aqui.',
               'The Master Ball prototype will be ours. You again... There’s no other way. I’ll end this here.')],
            [L('Giovanni', 'Por agora, a Rocket vai embora de Saffron. Mas o meu ginásio ainda espera.', 'For now, Rocket leaves Saffron. But my Gym still awaits.'),
             L('', 'O presidente da Silph, grato, deu a você a Master Ball: a única no mundo.', 'The grateful Silph president gave you the Master Ball: the only one in the world.')]),
        'Blue@Saffron City': B(
            [L('Blue', 'O quê? Você também veio salvar a Silph? Eu cheguei primeiro! Me mostra que está pronto!',
               'What? You came to save Silph too? I got here first! Show me you’re ready!')],
            [L('Blue', 'Tá bom, tá bom. Vai lá falar com a Sabrina.', 'Fine, fine. Go deal with Sabrina.')]),
        'Sabrina@Saffron City': B(
            [L('Sabrina', 'Eu tive uma visão de você chegando. Eu não gosto de lutar, mas sei que vou vencer. Meu Alakazam lê seus pensamentos.',
               'I had a vision of you coming. I don’t like fighting, but I know I’ll win. My Alakazam reads your thoughts.')],
            [L('Sabrina', 'Essa eu não previ. Leve a Marsh Badge.', 'I didn’t foresee that. Take the Marsh Badge.')]),
        'Blue@Cinnabar Island': B(
            [L('Blue', 'Ei! Eu ouvi falar daquele Mewtwo. Coisa de louco. Mas eu sou mais louco ainda. Vamos!',
               'Hey! I heard about that Mewtwo. Crazy stuff. But I’m even crazier. Let’s go!')],
            [L('Blue', 'Hunf. Te vejo na Liga.', 'Hmph. See you at the League.')]),
        'Blaine@Cinnabar Island': B(
            [L('Blaine', 'Ha! Fogo destrói tudo! Que queimem suas esperanças!', 'Hah! Fire burns everything! Let your hopes burn!')],
            [L('Blaine', 'Eu me queimei! Você merece a Volcano Badge.', 'I got burned! You’ve earned the Volcano Badge.')]),
        'Giovanni@Indigo Plateau': B(
            [L('Giovanni', 'Aqui é o meu verdadeiro lar. Eu sou o líder de ginásio de Viridian. A Equipe Rocket começou aqui. Agora você vai ver o que é força.',
               'This is my true home. I am Viridian’s Gym Leader. Team Rocket began here. Now you’ll see what strength is.')],
            [L('Giovanni', 'Hoje, eu desisto. A Equipe Rocket acabou. Vou desaparecer, para treinar de novo. Um dia, talvez...',
               'Today, I give up. Team Rocket is finished. I’ll disappear and train again. Someday, perhaps...')]),
        'Lorelei@Indigo Plateau': B(
            [L('Lorelei', 'Ninguém resiste aos meus Pokémon de gelo. Você vai virar escultura.', 'No one withstands my Ice Pokémon. You’ll turn into a sculpture.')],
            [L('Lorelei', 'Você derreteu o meu gelo. Siga em frente.', 'You melted my ice. Go on ahead.')]),
        'Bruno@Indigo Plateau': B(
            [L('Bruno', 'Nós treinamos até o limite. Nossos músculos estão prontos!', 'We train to our limits. Our muscles are ready!')],
            [L('Bruno', 'Hm! Perdi. Continue, você tem força de verdade.', 'Hm! I lost. Keep going, your strength is real.')]),
        'Agatha@Indigo Plateau': B(
            [L('Agatha', 'Hehehe. O Oak ainda está vivo? Aquele velho já foi forte, mas virou um bobão. Pokémon são para lutar!',
               'Hehehe. Is Oak still alive? That old man was strong once, but he’s gone soft. Pokémon are for battling!')],
            [L('Agatha', 'Agora entendo por que o Oak gosta de você.', 'Now I see why Oak likes you.')]),
        'Lance@Indigo Plateau': B(
            [L('Lance', 'Dragões são lendários. São criaturas místicas. Ninguém derrotou meus Dragonite. Até hoje.',
               'Dragons are legendary. They are mystical creatures. No one has beaten my Dragonite. Until today.')],
            [L('Lance', 'Você venceu a Elite dos Quatro. Mas há alguém que chegou antes de você...', 'You beat the Elite Four. But someone got here before you...')]),
        'Blue@Indigo Plateau': B(
            [L('Blue', 'Eu estava te esperando! Venci a Elite dos Quatro primeiro. Agora eu sou o Campeão! Eu sou o treinador mais poderoso do mundo!',
               'I was waiting for you! I beat the Elite Four first. I’m the Champion now! I’m the most powerful Trainer in the world!')],
            [L('Blue', 'Não... Não pode ser... Eu fiz tudo certo... Por quê?', 'No... It can’t be... I did everything right... Why?'),
             L('Oak', 'Blue, você esqueceu de tratar seus Pokémon com confiança e amor. Por isso perdeu. E você: parabéns, é o novo Campeão de Kanto!',
               'Blue, you forgot to treat your Pokémon with trust and love. That’s why you lost. And you: congratulations, you’re Kanto’s new Champion!')],
            [L('Blue', 'Ainda não acabou! Vai lá, meu último!', 'It’s not over yet! Go, my last one!')]),
    },
}

YELLOW = {
    'intro': 'Na Route 1, um Pikachu selvagem pula do mato, e o Professor Oak o prende às pressas. No laboratório, Blue agarra o Eevee: "Pode ficar com o rato, vovô!" O Pikachu não gosta de Poké Balls e anda do seu lado. A jornada começa.',
    'end': 'Blue perdeu, e o seu Pikachu pulou no seu colo com um "Pika!" que se ouviu no prédio inteiro. Um barco no porto leva você para outra região.',
    'cities': {
        'Cerulean City': [
            L('', 'No Mt. Moon, uma dupla com um discurso ensaiado queria o seu Pikachu.', 'In Mt. Moon, a duo with a rehearsed speech wanted your Pikachu.'),
            L('Jessie', 'Preparem-se para encrenca!', 'Prepare for trouble!'),
            L('James', 'E encrenca em dobro! Equipe Rocket, decolando na velocidade da luz!', 'And make it double! Team Rocket, blasting off at the speed of light!'),
            L('Meowth', 'Miau, é isso aí!', 'Meowth, that’s right!'),
            L('', 'Em Cerulean, uma moça que cuida de Pokémon abandonados viu o carinho do seu Pikachu e te deu um Bulbasaur.',
              'In Cerulean, a girl who looks after abandoned Pokémon saw how much your Pikachu loves you and gave you a Bulbasaur.'),
        ],
        'Vermilion City': [
            L('', 'Na Route 24, um treinador deixou um Charmander abandonado com você. Em Vermilion, o policial entregou um Squirtle.',
              'On Route 24, a Trainer left an abandoned Charmander with you. In Vermilion, the police officer handed you a Squirtle.'),
        ],
        'Celadon City': [
            L('', 'Jessie e James voltaram a aparecer no Rocket Hideout e na Pokémon Tower, sempre com Ekans, Koffing e Meowth, e sempre saindo em disparada.',
              'Jessie and James showed up again in the Rocket Hideout and Pokémon Tower, always with Ekans, Koffing and Meowth, and always blasting off.'),
        ],
    },
    'bosses': {
        'Blue@Pewter City': B(
            [L('Blue', 'Esse rato ainda não entrou na bola? O meu Eevee é muito melhor. Vamos ver!', 'That mouse still won’t go in its ball? My Eevee is way better. Let’s see!')],
            [L('Blue', 'Hunf. Sorte do rato.', 'Hmph. Lucky mouse.')]),
        'Blue@Saffron City': B(
            [L('Blue', 'O meu Eevee evoluiu, viu? Agora sim você vai perder!', 'My Eevee evolved, see? Now you’re really going to lose!')],
            [L('Blue', 'Esse Pikachu de novo...', 'That Pikachu again...')]),
        'Blue@Indigo Plateau': B(
            [L('Blue', 'Eu sou o Campeão! O meu Eevee cresceu comigo. Vamos ver quem tem o melhor parceiro!',
               'I’m the Champion! My Eevee grew up with me. Let’s see who has the best partner!')],
            [L('Blue', 'Esse Pikachu de novo! Eu deveria ter ficado com ele...', 'That Pikachu again! I should have taken it...'),
             L('', 'O Professor Oak entrou, e o seu Pikachu pulou no seu colo com um "Pika!" que se ouviu no prédio inteiro.',
               'Professor Oak came in, and your Pikachu jumped into your arms with a "Pika!" heard all over the building.')]),
    },
}

FIRERED = {
    'intro': 'A mesma Kanto, com cores novas. Em Pallet Town você escolhe o seu parceiro e Blue, o que vence o seu. O Professor Oak dá conselhos pelo caminho, e em Viridian um velho mostra como se lança uma Poké Ball: "Você joga assim, ó!"',
    'end': 'Blue perdeu e ficou um bom tempo olhando para o chão. Depois do Hall da Fama, Bill chama você para conhecer as Sevii Islands, ao sul de Kanto.',
    'cities': {
        'Cinnabar Island': [
            L('', 'Em Cinnabar, a Equipe Rocket estudava a mansão abandonada, onde o diário conta a história de Mewtwo.',
              'On Cinnabar, Team Rocket was studying the abandoned mansion, whose journal tells the story of Mewtwo.'),
        ],
        'Viridian City': [
            L('', 'O ginásio de Viridian, sempre fechado, finalmente abriu. O líder espera lá dentro.', 'Viridian’s ever-closed Gym has finally opened. The Leader waits inside.'),
        ],
    },
    'bosses': {
        'Giovanni@Fuchsia City': B(
            [L('Giovanni', 'Você está no meu caminho de novo. Eu sou paciente, criança. Mas paciência tem limite.',
               'You’re in my way again. I am patient, child. But patience has limits.')],
            [L('Giovanni', 'Hm. Isso não vai se repetir.', 'Hm. This won’t happen again.')]),
        'Giovanni@Cinnabar Island': B(
            [L('Giovanni', 'Esta mansão guarda segredos que valem uma fortuna. Saia do meu caminho.', 'This mansion holds secrets worth a fortune. Get out of my way.')],
            [L('Giovanni', 'Eu sou paciente. Nos veremos em Viridian.', 'I am patient. We’ll meet in Viridian.')]),
        'Blue@Viridian City': B(
            [L('Blue', 'Viridian também? Eu vou pegar a última insígnia antes de você!', 'Viridian too? I’ll get the last badge before you!')],
            [L('Blue', 'Hunf. Te espero na Liga.', 'Hmph. I’ll be waiting at the League.')]),
        'Giovanni@Viridian City': B(
            [L('Giovanni', 'Como líder deste ginásio, eu reconheço sua força. Mas como chefe da Equipe Rocket, eu não perdoo. Venha.',
               'As this Gym’s Leader, I acknowledge your strength. But as Team Rocket’s boss, I do not forgive. Come.')],
            [L('Giovanni', 'A Equipe Rocket acabou. Leve a Earth Badge. Eu vou sair de Kanto.', 'Team Rocket is finished. Take the Earth Badge. I am leaving Kanto.')]),
        'Blue@Indigo Plateau': B(
            [L('Blue', 'Eu escolhi o Pokémon que vencia o seu e treinei todos os dias. Por que você está sempre logo atrás de mim?',
               'I picked the Pokémon that beat yours and trained every day. Why are you always right behind me?')],
            [L('Blue', 'Você é forte. É. Você é forte de verdade.', 'You’re strong. Yeah. You’re really strong.'),
             L('Oak', 'Você esqueceu de tratar seus Pokémon com amor, Blue. Eles sentem isso.', 'You forgot to treat your Pokémon with love, Blue. They can feel that.')]),
    },
}

# Yellow e FireRed/LeafGreen: as falas de Red/Blue, com as próprias por cima (só dos chefes e cidades de cada um).
YELLOW['cities'] = {**RED_BLUE['cities'], **YELLOW['cities']}
YELLOW['bosses'] = {**{k: v for k, v in RED_BLUE['bosses'].items() if k != 'Blue@Celadon City'}, **YELLOW['bosses']}
FIRERED['cities'] = {**{k: v for k, v in RED_BLUE['cities'].items() if k != 'Indigo Plateau'}, **FIRERED['cities']}
FIRERED['bosses'] = {**{k: v for k, v in RED_BLUE['bosses'].items() if k not in ('Blue@Fuchsia City', 'Giovanni@Saffron City', 'Giovanni@Indigo Plateau')}, **FIRERED['bosses']}

GAMES = {
    'Kanto|Red/Blue': RED_BLUE,
    'Kanto|Yellow': YELLOW,
    'Kanto|FireRed/LeafGreen': FIRERED,
}
