"""Johto: Gold/Silver, Crystal e HeartGold/SoulSilver (docs/historia/02-johto.md)."""
import copy

from .kanto import B, L

KANTO_BACK = {
    'Brock@Pewter City': B([L('Brock', 'Três anos se passaram, e minhas rochas ficaram ainda mais duras. Vamos ver o campeão de Johto!', 'Three years have passed, and my rocks got even harder. Let’s see Johto’s champion!')],
                           [L('Brock', 'Você é forte de verdade. Leve a Boulder Badge.', 'You’re truly strong. Take the Boulder Badge.')]),
    'Misty@Cerulean City': B([L('Misty', 'Você atrapalhou o meu encontro na Route 25! Vai pagar com uma batalha!', 'You interrupted my date on Route 25! You’ll pay with a battle!')],
                             [L('Misty', 'Tá bom, você venceu. A Cascade Badge é sua.', 'Okay, you win. The Cascade Badge is yours.')]),
    'Lt. Surge@Vermilion City': B([L('Lt. Surge', 'Ei, você de Johto! Meus elétricos ainda paralisam qualquer um!', 'Hey, you from Johto! My Electric types still paralyze anyone!')],
                                  [L('Lt. Surge', 'Eletrizante como sempre. Leve a Thunder Badge!', 'Electrifying as ever. Take the Thunder Badge!')]),
    'Erika@Celadon City': B([L('Erika', 'O perfume das flores me deixa com sono... Ah, um desafiante. Vamos lá.', 'The scent of the flowers makes me sleepy... Oh, a challenger. Let’s begin.')],
                            [L('Erika', 'Você cuida bem dos seus Pokémon. A Rainbow Badge é sua.', 'You care well for your Pokémon. The Rainbow Badge is yours.')]),
    'Janine@Fuchsia City': B([L('Janine', 'Eu sou Janine, filha do Koga. O meu pai me deixou o ginásio, e eu não vou decepcioná-lo!', 'I’m Janine, Koga’s daughter. My father left me this Gym, and I won’t let him down!')],
                             [L('Janine', 'Ainda tenho muito a aprender. Leve a Soul Badge.', 'I still have a lot to learn. Take the Soul Badge.')]),
    'Sabrina@Saffron City': B([L('Sabrina', 'Eu previ a sua vinda, e também a sua vitória. Mas vou lutar mesmo assim.', 'I foresaw your coming, and your victory too. But I’ll fight anyway.')],
                              [L('Sabrina', 'Meus poderes não mentem. Leve a Marsh Badge.', 'My powers don’t lie. Take the Marsh Badge.')]),
    'Blaine@Seafoam Islands': B([L('Blaine', 'O vulcão de Cinnabar entrou em erupção e destruiu tudo. Mas o meu fogo continua aceso, aqui nas Seafoam Islands!', 'Cinnabar’s volcano erupted and destroyed everything. But my fire still burns, here on the Seafoam Islands!')],
                                [L('Blaine', 'Queimei de novo! Leve a Volcano Badge.', 'I got burned again! Take the Volcano Badge.')]),
    'Blue@Viridian City': B([L('Blue', 'Você é aquele de Johto? Eu já fui Campeão, sabia? Por dois minutos.', 'You’re the one from Johto? I was Champion once, you know. For two minutes.')],
                            [L('Blue', 'Tá bom. Tem alguém no Mt. Silver que você precisa ver.', 'All right. There’s someone on Mt. Silver you need to see.')]),
}

GOLD_SILVER = {
    'intro': 'Três anos depois da queda da Equipe Rocket, o Professor Elm, de New Bark Town, pede que você busque algo com o Mr. Pokémon. Você escolhe Chikorita, Cyndaquil ou Totodile. Na volta, um garoto de cabelo vermelho sai das sombras: ele roubou um inicial do laboratório. O nome dele é Silver.',
    'end': 'No topo do Mt. Silver, Red desapareceu na neve depois da batalha. Johto e Kanto são seus. Um barco leva você para outra região.',
    'cities': {
        'Violet City': [
            L('', 'Em Violet City, a Sprout Tower balança como um Bellsprout. Lá dentro, monges treinam em silêncio.', 'In Violet City, Sprout Tower sways like a Bellsprout. Inside, monks train in silence.'),
        ],
        'Azalea Town': [
            L('Kurt', 'A Equipe Rocket voltou! Eles estão cortando a cauda dos Slowpoke no poço para vender!', 'Team Rocket is back! They’re cutting off the Slowpoke tails in the well to sell them!'),
            L('', 'No Slowpoke Well, os capangas e um executivo de cabelo verde fugiram quando você venceu.', 'In Slowpoke Well, the grunts and a green-haired Executive fled when you won.'),
        ],
        'Goldenrod City': [
            L('', 'No Ilex Forest, um Farfetch’d fujão levou você até o santuário de Celebi. Depois, Goldenrod: a maior cidade de Johto, com loja, rádio, Game Corner e trem magnético.',
              'In Ilex Forest, a runaway Farfetch’d led you to Celebi’s shrine. Then Goldenrod: Johto’s biggest city, with a store, a radio station, a Game Corner and a magnet train.'),
        ],
        'Ecruteak City': [
            L('', 'Ecruteak tem duas torres. A Burned Tower pegou fogo há 150 anos; três Pokémon morreram, e Ho-Oh os trouxe de volta como Raikou, Entei e Suicune.',
              'Ecruteak has two towers. The Burned Tower caught fire 150 years ago; three Pokémon died, and Ho-Oh brought them back as Raikou, Entei and Suicune.'),
        ],
        'Cianwood City': [
            L('Jasmine', 'Por favor, existe um remédio em Cianwood. Eu não posso deixar o Amphy sozinho no farol.', 'Please, there’s medicine in Cianwood. I can’t leave Amphy alone in the lighthouse.'),
        ],
        'Olivine City': [
            L('', 'Com a SecretPotion de Cianwood, você voltou ao farol de Olivine, onde o Ampharos que ilumina os navios estava doente.', 'With the SecretPotion from Cianwood, you returned to Olivine’s lighthouse, where the Ampharos that lights the ships was sick.'),
        ],
        'Mahogany Town': [
            L('Lance', 'Esses Gyarados do Lake of Rage foram forçados a evoluir por ondas de rádio. A Equipe Rocket está por trás disso, em Mahogany. Me ajude.',
              'These Lake of Rage Gyarados were forced to evolve by radio waves. Team Rocket is behind it, in Mahogany. Help me.'),
        ],
        'Blackthorn City': [
            L('', 'A Equipe Rocket tomou a Radio Tower de Goldenrod. No último andar, o executivo que comandava tudo entregou os pontos: "Giovanni não ouviu nosso chamado. A Equipe Rocket está dissolvida."',
              'Team Rocket took over Goldenrod’s Radio Tower. On the top floor, the Executive in charge gave up: "Giovanni didn’t hear our call. Team Rocket is disbanded."'),
        ],
        'Indigo Plateau': [
            L('', 'No Indigo Plateau, a nova Elite dos Quatro espera.', 'At Indigo Plateau, the new Elite Four awaits.'),
        ],
        'Pewter City': [
            L('', 'Com o S.S. Aqua, você atravessou o mar para Kanto. Três anos mudaram muita coisa por aqui.', 'On the S.S. Aqua, you crossed the sea to Kanto. Three years changed a lot here.'),
        ],
        'Seafoam Islands': [
            L('', 'Cinnabar foi destruída por uma erupção, e Blaine mudou o ginásio para as Seafoam Islands.', 'Cinnabar was destroyed by an eruption, and Blaine moved his Gym to the Seafoam Islands.'),
        ],
    },
    'bosses': {
        'Silver@Violet City': B(
            [L('Silver', 'Pokémon fracos são inúteis. Eu só quero os fortes. Saia da frente!', 'Weak Pokémon are useless. I only want the strong ones. Out of my way!')],
            [L('Silver', 'Hm. Eu não vou perder de novo. Nunca.', 'Hm. I won’t lose again. Ever.')]),
        'Falkner@Violet City': B(
            [L('Falkner', 'Dizem que Pokémon voadores são fracos contra elétricos. Eu vou provar o contrário, pela honra do meu pai!', 'People say Flying types are weak to Electric. I’ll prove them wrong, for my father’s honor!')],
            [L('Falkner', 'Pela honra do meu pai... Você venceu. Leve a Zephyr Badge.', 'For my father’s honor... You win. Take the Zephyr Badge.')]),
        'Bugsy@Azalea Town': B(
            [L('Bugsy', 'Eu sei tudo sobre insetos. Scyther é a obra-prima da natureza!', 'I know everything about bugs. Scyther is nature’s masterpiece!')],
            [L('Bugsy', 'Ainda tenho muito a estudar. A Hive Badge é sua.', 'I still have a lot to study. The Hive Badge is yours.')]),
        'Silver@Goldenrod City': B(
            [L('Silver', 'Ainda está nessa? Que patético.', 'Still at it? How pathetic.')],
            [L('Silver', 'Tch. Eu vou atrás de Pokémon mais fortes.', 'Tch. I’m going after stronger Pokémon.')]),
        'Executivo@Goldenrod City': B(
            [L('Executivo', 'Você de novo, do Slowpoke Well? A Equipe Rocket tem planos para Goldenrod. Some daqui!', 'You again, from Slowpoke Well? Team Rocket has plans for Goldenrod. Get lost!')],
            [L('Executivo', 'Isso não acaba aqui. A Rocket vai voltar com tudo!', 'This isn’t over. Rocket will be back in full force!')]),
        'Whitney@Goldenrod City': B(
            [L('Whitney', 'Oi! Eu sou a Whitney! Todo mundo gosta de Pokémon fofos, né? O meu Miltank é fofo E forte!', 'Hi! I’m Whitney! Everyone loves cute Pokémon, right? My Miltank is cute AND strong!')],
            [L('Whitney', 'Buá! Você é maldoso! Não é justo! ... Tá, tá. Leve a Plain Badge.', 'Waaah! You’re mean! It’s not fair! ... Fine, fine. Take the Plain Badge.')]),
        'Executiva@Ecruteak City': B(
            [L('Executiva', 'Uma criança xeretando as torres de Ecruteak? A Equipe Rocket não gosta de testemunhas.', 'A child snooping around Ecruteak’s towers? Team Rocket doesn’t like witnesses.')],
            [L('Executiva', 'Hmpf. Os capangas vão ouvir por terem deixado você passar.', 'Hmph. The grunts will hear about letting you through.')]),
        'Silver@Ecruteak City': B(
            [L('Silver', 'Eu ouvi dizer que aqui tem um Pokémon lendário. Eu vou pegar e ficar mais forte do que todos.', 'I heard there’s a legendary Pokémon here. I’ll catch it and become stronger than anyone.')],
            [L('', 'O chão cedeu, e você caiu no porão. Raikou, Entei e Suicune olharam para você e fugiram, cada um para um lado de Johto.', 'The floor gave way, and you fell into the basement. Raikou, Entei and Suicune looked at you and fled, each to a different part of Johto.')]),
        'Executivo@Ecruteak City': B(
            [L('Executivo', 'As lendas de Ecruteak valem uma fortuna. Saia do caminho da Rocket!', 'Ecruteak’s legends are worth a fortune. Get out of Rocket’s way!')],
            [L('Executivo', 'Recuar! Recuar!', 'Retreat! Retreat!')]),
        'Morty@Ecruteak City': B(
            [L('Morty', 'Dizem que Ho-Oh vai aparecer diante de um treinador de verdade. Eu treinei a vida toda para ser essa pessoa. Talvez seja você.', 'They say Ho-Oh will appear before a true Trainer. I’ve trained all my life to be that person. Maybe it’s you.')],
            [L('Morty', 'Talvez seja mesmo você. Leve a Fog Badge.', 'Maybe it really is you. Take the Fog Badge.')]),
        'Chuck@Cianwood City': B(
            [L('Chuck', 'WAHAHAH! Treino é tudo! Debaixo da cachoeira, todo dia!', 'WAHAHAH! Training is everything! Under the waterfall, every day!')],
            [L('Chuck', 'Que força! Leve a Storm Badge. E a farmácia da cidade tem o remédio que você procura.', 'What strength! Take the Storm Badge. And the town pharmacy has the medicine you’re looking for.')]),
        'Silver@Olivine City': B(
            [L('Silver', 'Uma líder que não sai do lado de um Pokémon doente? Isso é fraqueza.', 'A Leader who won’t leave a sick Pokémon’s side? That’s weakness.')],
            [L('Silver', 'Hunf. Faça o que quiser.', 'Hmph. Do what you want.')]),
        'Executivo@Olivine City': B(
            [L('Executivo', 'O porto de Olivine vai ser nosso. Os navios trazem tudo o que a Rocket precisa.', 'Olivine’s port will be ours. The ships bring everything Rocket needs.')],
            [L('Executivo', 'Tch. Eu aviso o chefe.', 'Tch. I’ll warn the boss.')]),
        'Executiva@Olivine City': B(
            [L('Executiva', 'Você atrapalhou demais. Agora é comigo.', 'You’ve meddled too much. Now you deal with me.')],
            [L('Executiva', 'Isso não vai ficar assim.', 'This won’t stand.')]),
        'Jasmine@Olivine City': B(
            [L('Jasmine', 'Obrigada pelo remédio. O Amphy está melhor. Agora sim, meu Steelix está pronto.', 'Thank you for the medicine. Amphy is better. Now my Steelix is ready.')],
            [L('Jasmine', 'Você é forte e gentil. Leve a Mineral Badge.', 'You’re strong and kind. Take the Mineral Badge.')]),
        'Silver@Mahogany Town': B(
            [L('Silver', 'Eu vi o Gyarados vermelho. Os mais fortes ficam comigo. Lute!', 'I saw the red Gyarados. The strongest ones stay with me. Fight!')],
            [L('Silver', 'Por que eu perco para você?', 'Why do I keep losing to you?')]),
        'Executivo@Mahogany Town': B(
            [L('Executivo', 'As nossas ondas de rádio forçam os Gyarados a evoluir. Ninguém desliga esta máquina!', 'Our radio waves force the Gyarados to evolve. No one shuts this machine down!')],
            [L('', 'Você venceu, e Lance derrubou o Electrode que alimentava o gerador. As ondas pararam.', 'You won, and Lance knocked out the Electrode powering the generator. The waves stopped.')]),
        'Pryce@Mahogany Town': B(
            [L('Pryce', 'Eu vivi muitas nevascas. A experiência é o meu gelo. Vamos ver se você derrete.', 'I’ve lived through many blizzards. Experience is my ice. Let’s see if you melt.')],
            [L('Pryce', 'Você tem a força da juventude. Leve a Glacier Badge.', 'You have the strength of youth. Take the Glacier Badge.')]),
        'Clair@Blackthorn City': B(
            [L('Clair', 'Eu sou a melhor treinadora de dragões do mundo! Prima do Lance!', 'I’m the best Dragon Trainer in the world! Lance’s cousin!')],
            [L('Clair', 'Não aceito essa derrota! ... Tá. Vá ao Dragon’s Den e responda ao Mestre do Clã. Só então a Rising Badge é sua.', 'I don’t accept this defeat! ... Fine. Go to the Dragon’s Den and answer the Clan Master. Only then is the Rising Badge yours.')]),
        'Will@Indigo Plateau': B(
            [L('Will', 'Eu treinei em todo o mundo. Meus Pokémon psíquicos não têm medo.', 'I’ve trained all over the world. My Psychic Pokémon know no fear.')],
            [L('Will', 'Eu não vou desistir. Siga em frente.', 'I won’t give up. Go on ahead.')]),
        'Koga@Indigo Plateau': B(
            [L('Koga', 'Fufufu. Eu deixei o ginásio para a minha filha. Agora, a escuridão é minha arma.', 'Fufufu. I left my Gym to my daughter. Now, darkness is my weapon.')],
            [L('Koga', 'Uma derrota digna de um ninja. Continue.', 'A defeat worthy of a ninja. Continue.')]),
        'Bruno@Indigo Plateau': B(
            [L('Bruno', 'Nossa força é imbatível!', 'Our strength is unbeatable!')],
            [L('Bruno', 'Você é mais forte. Vá!', 'You’re stronger. Go!')]),
        'Karen@Indigo Plateau': B(
            [L('Karen', 'Pokémon fortes, Pokémon fracos... isso é egoísmo dos humanos. Treinadores de verdade usam os que amam.', 'Strong Pokémon, weak Pokémon... that’s just human selfishness. True Trainers use the ones they love.')],
            [L('Karen', 'Você usa os que ama. Siga para o Campeão.', 'You use the ones you love. Go on to the Champion.')]),
        'Lance@Indigo Plateau': B(
            [L('Lance', 'Eu estava esperando por você. Você nos ajudou no Lake of Rage. Agora, como Campeão, vou mostrar o poder dos dragões.', 'I’ve been waiting for you. You helped us at the Lake of Rage. Now, as Champion, I’ll show you the power of dragons.')],
            [L('Lance', 'Você é o novo Campeão. Johto é seu. Mas Kanto, do outro lado do mar, também tem ginásios esperando.', 'You’re the new Champion. Johto is yours. But Kanto, across the sea, has Gyms waiting too.')]),
        **KANTO_BACK,
        'Silver@Indigo Plateau': B(
            [L('Silver', 'Eu perdi para você de novo. O Lance me disse que eu não confiava nos meus Pokémon. Vamos lutar mais uma vez.', 'I lost to you again. Lance told me I didn’t trust my Pokémon. Let’s battle one more time.')],
            [L('Silver', 'Eu vou começar de novo, com eles.', 'I’ll start over, with them.'),
             L('', 'O Pokémon que ele roubou do laboratório, agora evoluído, olhou para ele de outro jeito.', 'The Pokémon he stole from the lab, now evolved, looked at him differently.')]),
        'Red@Indigo Plateau': B(
            [L('', 'No topo do Mt. Silver, no frio e no silêncio, um treinador estava de costas. Era Red, o campeão de Kanto de três anos atrás.', 'At the top of Mt. Silver, in the cold and silence, a Trainer stood with his back to you. It was Red, Kanto’s champion from three years ago.'),
             L('Red', '...', '...')],
            [L('Red', '...', '...'), L('', 'Quando a batalha terminou, ele simplesmente desapareceu na neve.', 'When the battle ended, he simply vanished into the snow.')]),
    },
}

CRYSTAL = copy.deepcopy(GOLD_SILVER)
CRYSTAL['intro'] = 'A mesma jornada de Johto, com outra estrela: Suicune, a encarnação do vento do norte. Desde a Burned Tower, ela aparece e some diante de você. O Professor Elm te dá o primeiro parceiro, e Silver, o ladrão do laboratório, cruza o seu caminho.'
CRYSTAL['cities']['Cianwood City'] = CRYSTAL['cities']['Cianwood City'] + [
    L('Eusine', 'Suicune. A encarnação do vento do norte. Eu a sigo desde menino. Não vou deixar você pegá-la primeiro!', 'Suicune. The embodiment of the north wind. I’ve followed her since I was a boy. I won’t let you catch her first!'),
    L('Eusine', 'Talvez Suicune tenha escolhido você.', 'Maybe Suicune has chosen you.'),
]
CRYSTAL['cities']['Blackthorn City'] = CRYSTAL['cities']['Blackthorn City'] + [
    L('', 'O diretor da rádio deu a você o Clear Bell. Na Tin Tower, depois do teste dos três monges, Suicune finalmente esperou parada pela batalha.', 'The radio director gave you the Clear Bell. In Tin Tower, after the three monks’ test, Suicune finally stood still for battle.'),
]

HGSS = copy.deepcopy(GOLD_SILVER)
HGSS['intro'] = 'Johto de novo, e agora o primeiro Pokémon do time sai da bola e anda atrás de você, falando pelo jeito que olha. O Professor Elm te dá o parceiro, sua amiga de infância acompanha os primeiros passos, e Silver rouba um inicial do laboratório.'
HGSS['end'] = 'Na Ruins of Alph, Celebi mostrou o passado: o dia em que Giovanni desistiu, e o pequeno Silver gritando "Você é fraco!". Foi ali que a raiva dele nasceu. Um barco leva você para outra região.'
for k in [k for k in HGSS['bosses'] if k.startswith('Executiv')]:
    del HGSS['bosses'][k]
HGSS['bosses'].update({
    'Proton@Ecruteak City': B([L('Proton', 'Eu sou chamado de o mais cruel e assustador da Equipe Rocket. Saia daqui!', 'They call me the cruelest and scariest in Team Rocket. Get out of here!')],
                              [L('Proton', 'Você vai se arrepender disso.', 'You’ll regret this.')]),
    'Petrel@Ecruteak City': B([L('Petrel', 'Hehe, mestre dos disfarces, ao seu dispor. Hoje eu sou só um turista de Ecruteak.', 'Heh, master of disguise, at your service. Today I’m just a tourist in Ecruteak.')],
                              [L('Petrel', 'Disfarce descoberto. Fuga!', 'Disguise blown. Run!')]),
    'Ariana@Ecruteak City': B([L('Ariana', 'Os capangas que deixaram você passar vão ser punidos. E você também.', 'The grunts who let you through will be punished. And so will you.')],
                              [L('Ariana', 'Hmpf. Archer vai saber disso.', 'Hmph. Archer will hear about this.')]),
    'Eusine@Cianwood City': B([L('Eusine', 'Eu persigo Suicune há mais de dez anos. Mostre-me se você é digno.', 'I’ve chased Suicune for over ten years. Show me if you’re worthy.')],
                              [L('Eusine', 'Talvez Suicune tenha escolhido você.', 'Maybe Suicune has chosen you.')]),
    'Archer@Cianwood City': B([L('Archer', 'Nós vamos trazer Giovanni de volta. Nem que tenhamos de gritar no mundo inteiro.', 'We will bring Giovanni back. Even if we have to shout it to the whole world.')],
                              [L('Archer', 'Ainda não acabou. A Radio Tower vai transmitir o nosso chamado.', 'It’s not over. The Radio Tower will broadcast our call.')]),
    'Proton@Olivine City': B([L('Proton', 'De novo você? Eu não tenho pena de ninguém.', 'You again? I have no mercy for anyone.')], [L('Proton', 'Grr...', 'Grr...')]),
    'Petrel@Olivine City': B([L('Petrel', 'Adivinha quem eu sou hoje? Um marinheiro inocente!', 'Guess who I am today? An innocent sailor!')], [L('Petrel', 'Descoberto de novo!', 'Found out again!')]),
    'Ariana@Olivine City': B([L('Ariana', 'Chega. Eu mesma cuido de você.', 'Enough. I’ll handle you myself.')], [L('Ariana', 'Isso não vai ficar assim.', 'This won’t stand.')]),
})
HGSS['cities']['Ecruteak City'] = HGSS['cities']['Ecruteak City'] + [
    L('', 'No teatro, as cinco Kimono Girls dançam e protegem a lenda. Elas guardam o caminho até Ho-Oh e Lugia.', 'In the theater, the five Kimono Girls dance and guard the legend. They protect the way to Ho-Oh and Lugia.'),
]
HGSS['bosses']['Silver@Indigo Plateau'] = B(
    [L('Silver', 'Eu não sou mais o garoto que roubou um Pokémon. Hoje eu luto junto com eles. Vamos!', 'I’m not the kid who stole a Pokémon anymore. Today I fight alongside them. Let’s go!')],
    [L('Silver', 'Obrigado. Por tudo.', 'Thanks. For everything.')])

GAMES = {
    'Johto|Gold/Silver': GOLD_SILVER,
    'Johto|Crystal': CRYSTAL,
    'Johto|HeartGold/SoulSilver': HGSS,
}
