"""Alola, Galar e Paldea: Sun/Moon, Ultra Sun/Ultra Moon, Sword/Shield e Scarlet/Violet (docs/historia/06-alola-galar-paldea.md)."""
from .kanto import B, L


def S(who, before_pt, before_en, after_pt, after_en):
    """Um chefe: a fala antes e depois da luta."""
    return B([L(who, before_pt, before_en)], [L(who, after_pt, after_en)])


def at(who, cities, before_pt, before_en, after_pt, after_en):
    """A mesma pessoa em várias cidades, com as mesmas falas."""
    return {f'{who}@{c}': S(who, before_pt, before_en, after_pt, after_en) for c in cities}


ALOLA_COMMON = {
    'Ilima@Verdant Cavern': S('Ilima', 'Bem-vindo. Seu trial é achar o Pokémon Totem desta caverna.', 'Welcome. Your trial is to find this cave’s Totem Pokémon.', 'Trial completo! Siga para o Grand Trial.', 'Trial complete! On to the Grand Trial.'),
    'Hala@Iki Town': S('Hala', 'Eu vou mostrar o que é um Kahuna de verdade!', 'I’ll show you what a true Kahuna is!', 'Hohoho! Você passou no Grand Trial de Melemele.', 'Hohoho! You passed Melemele’s Grand Trial.'),
    'Lana@Brooklet Hill': S('Lana', 'Vamos pescar! Seu trial é encontrar o peixe totem!', 'Let’s go fishing! Your trial is to find the totem fish!', 'Você pescou bem. Trial completo!', 'You fished well. Trial complete!'),
    'Kiawe@Wela Volcano Park': S('Kiawe', 'Minha dança é feita de fogo. Siga o ritmo das chamas!', 'My dance is made of fire. Follow the rhythm of the flames!', 'Você dançou com o fogo. Trial completo!', 'You danced with the fire. Trial complete!'),
    'Mallow@Lush Jungle': S('Mallow', 'Seu trial é encontrar os ingredientes para meu prato!', 'Your trial is to find the ingredients for my dish!', 'Que delícia! Trial completo!', 'Delicious! Trial complete!'),
    'Olivia@Ruins of Life': S('Olivia', 'Eu sou a Kahuna! Vamos de uma vez!', 'I’m the Kahuna! Let’s get it over with!', 'Você é duro como diamante. Grand Trial de Akala completo.', 'You’re as hard as diamond. Akala’s Grand Trial complete.'),
    'Nanu@Malie City': S('Nanu', 'Eu sou o Kahuna? É, sou. Que trabalheira.', 'I’m the Kahuna? Yeah, I am. What a chore.', 'Hm. Você passou. Agora me deixa em paz.', 'Hm. You passed. Now leave me alone.'),
    'Hapu@Vast Poni Canyon': S('Hapu', 'Eu sou a nova Kahuna de Poni. Mostre que merece ir até o altar!', 'I’m Poni’s new Kahuna. Show me you deserve to reach the altar!', 'Você merece. Siga até o altar.', 'You deserve it. Go on to the altar.'),
    'Acerola@Mount Lanakila': S('Acerola', 'Meus fantasmas querem brincar com você!', 'My ghosts want to play with you!', 'Que divertido! Siga.', 'That was fun! Go on.'),
    'Kahili@Mount Lanakila': S('Kahili', 'Um bom golfe e uma boa batalha pedem a mesma calma.', 'Good golf and a good battle need the same calm.', 'Que tacada. Siga em frente.', 'What a shot. Go on ahead.'),
    'Olivia@Mount Lanakila': S('Olivia', 'Na Elite, minhas pedras estão ainda mais duras!', 'In the Elite Four, my rocks are even harder!', 'Você brilha. Siga.', 'You shine. Go on.'),
    'Gladion@Verdant Cavern': S('Gladion', 'Eu não tenho tempo para amizade. Só para ficar forte.', 'I have no time for friendship. Only for getting stronger.', 'Tch. Você é forte. Isso não muda nada.', 'Tch. You’re strong. That changes nothing.'),
    'Guzma@Brooklet Hill': S('Guzma', 'Guzma! Guzma é o que destrói tudo! E o que a gente faz com destruição? A gente faz de novo!', 'Guzma! Guzma is what destroys everything! And what do we do with destruction? We do it again!', 'Grr! Você não sabe com quem está mexendo!', 'Grr! You don’t know who you’re messing with!'),
    'Plumeria@Wela Volcano Park': S('Plumeria', 'Eu sou a irmã mais velha da Skull. Ninguém mexe com os meus.', 'I’m Skull’s big sister. No one messes with my crew.', 'Hmpf. Você é durona.', 'Hmph. You’re tough.'),
    'Lusamine@Wela Volcano Park': S('Lusamine', 'A Fundação Aether cuida dos Pokémon que sofrem. Todos os Pokémon merecem amor. Eu amo todos eles.', 'The Aether Foundation cares for suffering Pokémon. All Pokémon deserve love. I love them all.', 'Que lindos os seus Pokémon. Quase tanto quanto os meus.', 'Your Pokémon are lovely. Almost as lovely as mine.'),
    'Faba@Ruins of Life': S('Faba', 'Eu sou o chefe de pesquisas da Aether. Os Ultra Beasts são a ciência do futuro!', 'I’m Aether’s head of research. Ultra Beasts are the science of the future!', 'Inaceitável!', 'Unacceptable!'),
    'Guzma@Ruins of Life': S('Guzma', 'De novo você? O grande Guzma não perde duas vezes!', 'You again? The great Guzma doesn’t lose twice!', 'Grr... Isso é destruição de verdade.', 'Grr... That’s real destruction.'),
    'Sina@Ruins of Life': S('Sina', 'Viemos de Kalos para estudar Alola. Mostre como lutam aqui!', 'We came from Kalos to study Alola. Show us how they battle here!', 'Que força! Vou anotar.', 'What strength! I’ll write it down.'),
    'Ryuki@Ruins of Life': S('Ryuki', 'Eu sou o rei do rock de Alola! Vamos tocar alto!', 'I’m Alola’s king of rock! Let’s play it loud!', 'Que solo! Você arrasou.', 'What a solo! You rocked it.'),
    'Gladion@Hokulani Observatory': S('Gladion', 'A minha mãe... Não importa. Lute.', 'My mother... Never mind. Fight.', 'Você é forte. Talvez possa ajudar a Lillie.', 'You’re strong. Maybe you can help Lillie.'),
    'Plumeria@Hokulani Observatory': S('Plumeria', 'O Guzma quer a menina e o Pokémon dela. E vai ter.', 'Guzma wants the girl and her Pokémon. And he’ll get them.', 'Você vai atrás deles? Boa sorte.', 'Going after them? Good luck.'),
    'Lusamine@Hokulani Observatory': S('Lusamine', 'Lillie é minha filha. O Nebby é meu. Saia do caminho.', 'Lillie is my daughter. Nebby is mine. Get out of the way.', 'Eu vou viver com meus queridos Ultra Beasts, longe de tudo que é imperfeito.', 'I’ll live with my dear Ultra Beasts, far from everything imperfect.'),
    'Guzma@Malie City': S('Guzma', 'Bem-vindo a Po Town, a casa da Skull! Aqui quem manda sou eu!', 'Welcome to Po Town, Skull’s home! I’m the boss here!', 'Eu peguei a menina. Ela está na Aether. Vai lá, se tiver coragem.', 'I took the girl. She’s at Aether. Go, if you dare.'),
}
for city in ('Brooklet Hill', 'Wela Volcano Park', 'Ruins of Life', 'Hokulani Observatory', 'Vast Poni Canyon', 'Lush Jungle', 'Seafolk Village'):
    ALOLA_COMMON[f'Hau@{city}'] = S('Hau', 'Vamos lutar! Lutar é divertido! Depois a gente come malasadas.', 'Let’s battle! Battling is fun! Then we’ll get malasadas.', 'Que batalha! Eu vou ficar mais forte, igual ao meu avô.', 'What a battle! I’ll get stronger, just like my grandpa.')

SUN_MOON = {
    'intro': 'Você chega em Alola com sua mãe e um Meowth. O Professor Kukui abre a porta: "Alola!" Na estrada para Iki Town, você salva o Cosmog que Lillie carrega na bolsa, e Tapu Koko te salva quando a ponte quebra. O Kahuna Hala te dá Rowlet, Litten ou Popplio, e Hau, o neto dele, escolhe o que vence o seu.',
    'end': 'Você é o primeiro Campeão de Alola. Lillie levou a mãe para Kanto: "Eu vou ficar forte. Como você." Um barco leva você para outra região.',
    'cities': {
        'Verdant Cavern': [L('', 'Em vez de ginásios, Alola tem o Desafio da Ilha: os Trials dos Capitães e, no fim de cada ilha, o Grand Trial contra o Kahuna.', 'Instead of Gyms, Alola has the Island Challenge: the Captains’ Trials and, at the end of each island, the Grand Trial against the Kahuna.')],
        'Brooklet Hill': [L('', 'Homens de máscara de caveira, a Equipe Skull, roubam Pokémon por toda Alola, falando gírias e cuspindo rimas.', 'Men in skull masks, Team Skull, are stealing Pokémon all over Alola, talking slang and spitting rhymes.')],
        'Wela Volcano Park': [L('', 'Na ilha artificial da Fundação Aether, Faba estuda os Ultra Beasts, criaturas que vêm por buracos no céu.', 'On the Aether Foundation’s artificial island, Faba studies Ultra Beasts, creatures that come through holes in the sky.')],
        'Ruins of Life': [L('Lillie', 'Lusamine... é a minha mãe. Eu fugi com o Nebby porque ela queria usar ele para abrir os buracos no céu. Ela só ama o que pode prender.', 'Lusamine... is my mother. I ran away with Nebby because she wanted to use it to open the holes in the sky. She only loves what she can lock away.')],
        'Malie City': [L('', 'Em Po Town, uma cidade cercada e cheia de chuva, a Equipe Skull mora numa mansão. Guzma pegou Lillie e o Nebby.', 'In Po Town, a walled, rainy town, Team Skull lives in a mansion. Guzma took Lillie and Nebby.')],
        'Vast Poni Canyon': [
            L('Lusamine', 'Eu vou viver com meus queridos Ultra Beasts. Lillie, você não é mais minha filha.', 'I’ll live with my dear Ultra Beasts. Lillie, you are no longer my daughter.'),
            L('', 'Lusamine abriu o Ultra Wormhole com o Nebby e foi para o Ultra Space, levando Guzma. O Nebby desmaiou e virou Cosmoem.', 'Lusamine opened the Ultra Wormhole with Nebby and went to Ultra Space, taking Guzma. Nebby fainted and became Cosmoem.'),
        ],
        'Mount Lanakila': [L('', 'No altar, o Cosmoem virou Solgaleo (ou Lunala). No Ultra Space, você venceu Lusamine fundida a Nihilego. Kukui construiu a primeira Liga de Alola no Mount Lanakila.', 'At the altar, Cosmoem became Solgaleo (or Lunala). In Ultra Space, you beat Lusamine fused with Nihilego. Kukui built Alola’s first League on Mount Lanakila.')],
    },
    'bosses': {
        **ALOLA_COMMON,
        'Hau@Verdant Cavern': S('Hau', 'Vamos lutar! Lutar é divertido!', 'Let’s battle! Battling is fun!', 'Que batalha! Vamos de novo depois!', 'What a battle! Let’s go again later!'),
        'Gladion@Wela Volcano Park': S('Gladion', 'O Type: Null foi feito em laboratório. Como eu, ele luta para não ser descartado.', 'Type: Null was made in a lab. Like me, it fights so it won’t be thrown away.', 'Hm. Você é estranho. É forte.', 'Hm. You’re strange. You’re strong.'),
        'Dexio@Ruins of Life': S('Dexio', 'Eu sou da equipe do Professor Sycamore. Quero ver os Pokémon de Alola em ação.', 'I’m on Professor Sycamore’s team. I want to see Alola’s Pokémon in action.', 'Excelente. Vou registrar.', 'Excellent. I’ll record this.'),
        'Molayne@Hokulani Observatory': S('Molayne', 'O céu daqui é o mais limpo de Alola. Meu trial é de aço!', 'The sky here is Alola’s clearest. My trial is made of steel!', 'Trial completo!', 'Trial complete!'),
        'Hala@Mount Lanakila': S('Hala', 'Na Elite, o Kahuna luta com todo o coração!', 'In the Elite Four, the Kahuna fights with his whole heart!', 'Hohoho! Siga para o topo.', 'Hohoho! On to the top.'),
        'Kukui@Mount Lanakila': S('Kukui', 'Eu sempre quis fazer uma Liga em Alola. E eu sou o desafiante!', 'I always wanted to build a League in Alola. And I’m the challenger!', 'Woo! Você é o primeiro Campeão de Alola!', 'Woo! You’re Alola’s first Champion!'),
        'Dexio@Mount Lanakila': S('Dexio', 'Agora contra o Campeão de Alola. Que honra.', 'Now against Alola’s Champion. What an honor.', 'Impressionante.', 'Impressive.'),
        'Guzma@Mount Lanakila': S('Guzma', 'Eu voltei do Ultra Space. E o grande Guzma quer revanche!', 'I came back from Ultra Space. And the great Guzma wants a rematch!', 'Tá... Eu vou começar de novo. Do jeito certo.', 'Yeah... I’ll start over. The right way.'),
        'Faba@Mount Lanakila': S('Faba', 'Eu exijo uma revanche!', 'I demand a rematch!', 'Inaceitável... de novo.', 'Unacceptable... again.'),
        'Anabel@Mount Lanakila': S('Anabel', 'Sou da polícia internacional. Caço Ultra Beasts. Vamos ver sua força.', 'I’m with the International Police. I hunt Ultra Beasts. Let’s see your strength.', 'Você seria um ótimo agente.', 'You’d make a great agent.'),
        'Blue@Mount Lanakila': S('Blue', 'Na Battle Tree? Eu já fui Campeão de Kanto, sabia? Vamos!', 'At the Battle Tree? I was Kanto’s Champion, you know? Let’s go!', 'Hunf. Você é bom mesmo.', 'Hmph. You really are good.'),
        'Red@Mount Lanakila': S('Red', '...', '...', '...', '...'),
    },
}

ULTRA = {
    'intro': 'Alola de novo. O Professor Kukui te recebe, Lillie carrega o Cosmog na bolsa, e o Kahuna Hala te dá o primeiro parceiro. Desta vez, estranhos de armadura branca, vindos de uma cidade sem luz, aparecem desde o começo.',
    'end': 'A luz voltou a Ultra Megalopolis, e Hau desafiou você pelo título: você é o Campeão de Alola. Lillie voltou de Kanto. Um barco leva você para outra região.',
    'cities': {
        'Brooklet Hill': [L('Soliera', 'Nós viemos de um mundo onde a luz foi devorada. Precisamos de Necrozma, o Pokémon que roubou a nossa luz.', 'We come from a world where the light was devoured. We need Necrozma, the Pokémon that stole our light.')],
        'Seafolk Village': [L('', 'Necrozma se fundiu a Solgaleo (ou Lunala). No topo da Megalo Tower, ele virou Ultra Necrozma e queimou o céu. Você venceu, e a luz voltou.', 'Necrozma fused with Solgaleo (or Lunala). At the top of Megalo Tower, it became Ultra Necrozma and set the sky ablaze. You won, and the light returned.')],
        'Mount Lanakila': [L('', 'Giovanni voltou com a Equipe Rainbow Rocket, uma aliança de chefes vilões de outros mundos. Eles tomaram a Fundação Aether.', 'Giovanni returned with Team Rainbow Rocket, an alliance of villain bosses from other worlds. They took over the Aether Foundation.')],
    },
    'bosses': {
        **ALOLA_COMMON,
        'Hau@Verdant Cavern': S('Hau', 'Vamos lutar! Lutar é divertido!', 'Let’s battle! Battling is fun!', 'Que batalha! Vamos de novo depois!', 'What a battle! Let’s go again later!'),
        **at('Soliera', ('Brooklet Hill', 'Lush Jungle', 'Hokulani Observatory', 'Seafolk Village'), 'Precisamos ver se você é forte o bastante para enfrentar Necrozma.', 'We must see if you are strong enough to face Necrozma.', 'Você tem uma luz forte.', 'You have a strong light.'),
        **at('Dulse', ('Brooklet Hill', 'Lush Jungle', 'Hokulani Observatory', 'Seafolk Village'), 'A Ultra Recon Squad precisa da luz de Alola. Mostre a sua.', 'The Ultra Recon Squad needs Alola’s light. Show us yours.', 'Talvez você possa nos ajudar.', 'Perhaps you can help us.'),
        'Guzma@Wela Volcano Park': ALOLA_COMMON['Guzma@Brooklet Hill'],
        'Gladion@Wela Volcano Park': SUN_MOON['bosses']['Gladion@Wela Volcano Park'],
        **at('Dexio', ('Wela Volcano Park', 'Malie City'), 'Eu sou da equipe do Professor Sycamore. Quero ver os Pokémon de Alola em ação.', 'I’m on Professor Sycamore’s team. I want to see Alola’s Pokémon in action.', 'Excelente. Vou registrar.', 'Excellent. I’ll record this.'),
        'Gladion@Malie City': ALOLA_COMMON['Gladion@Hokulani Observatory'],
        'Plumeria@Malie City': ALOLA_COMMON['Plumeria@Hokulani Observatory'],
        'Lusamine@Malie City': ALOLA_COMMON['Lusamine@Hokulani Observatory'],
        'Guzma@Seafolk Village': ALOLA_COMMON['Guzma@Malie City'],
        'Sophocles@Hokulani Observatory': S('Sophocles', 'Minhas máquinas elétricas estão prontas. Seu trial começa agora!', 'My electric machines are ready. Your trial starts now!', 'Trial completo!', 'Trial complete!'),
        'Mina@Seafolk Village': S('Mina', 'Eu pinto o mundo com as cores das fadas. Vamos lá.', 'I paint the world with fairy colors. Let’s go.', 'Que obra! Trial completo.', 'What a work of art! Trial complete.'),
        'Molayne@Mount Lanakila': S('Molayne', 'Na Elite, o aço é ainda mais firme.', 'In the Elite Four, steel is even firmer.', 'Você é sólido. Siga.', 'You’re solid. Go on.'),
        'Hau@Mount Lanakila': S('Hau', 'Eu treinei tanto. Agora eu quero mostrar ao meu avô, e a você, quem eu sou!', 'I trained so hard. Now I want to show my grandpa, and you, who I am!', 'Você é o Campeão de Alola! Eu vou continuar treinando!', 'You’re Alola’s Champion! I’ll keep training!'),
        'Cyrus@Mount Lanakila': S('Cyrus', 'Neste mundo, eu também vou criar o meu universo sem espírito.', 'In this world, too, I will create my universe without spirit.', 'Este mundo também me rejeita.', 'This world rejects me too.'),
        'Ghetsis@Mount Lanakila': S('Ghetsis', 'Eu governo qualquer mundo! Ajoelhe-se!', 'I rule any world! Kneel!', 'Impossível!', 'Impossible!'),
        'Lysandre@Mount Lanakila': S('Lysandre', 'Em qualquer mundo, eu busco a beleza. E você atrapalha.', 'In any world, I seek beauty. And you interfere.', 'Até aqui...', 'Even here...'),
        'Maxie@Mount Lanakila': S('Maxie', 'Mais terra para as pessoas. Em qualquer mundo.', 'More land for people. In any world.', 'De novo, eu estava errado.', 'Once again, I was wrong.'),
        'Blue@Mount Lanakila': SUN_MOON['bosses']['Blue@Mount Lanakila'],
        'Lillie@Mount Lanakila': S('Lillie', 'Eu voltei de Kanto! E o meu Clefairy quer lutar com você!', 'I’m back from Kanto! And my Clefairy wants to battle you!', 'Você continua forte. Eu também fiquei.', 'You’re still strong. I got stronger too.'),
        'Red@Mount Lanakila': SUN_MOON['bosses']['Red@Mount Lanakila'],
    },
}

SWORD_SHIELD = {
    'intro': 'Em Postwick, Hop, seu vizinho, conta os dias: o irmão dele, Leon, o Campeão invicto de Galar, chega de trem trazendo Grookey, Scorbunny e Sobble. Na mesma noite, no Slumbering Weald, uma sombra de lobo enorme aparece na névoa.',
    'end': 'Leon caiu, e Hop decidiu virar professor. Você é o Campeão de Galar. Um barco leva você para outra região.',
    'cities': {
        'Turffield': [L('', 'Em Galar, a Gym Challenge é um espetáculo: estádios lotados e transmissões ao vivo. Os Pokémon crescem em gigantes com a energia Dynamax.', 'In Galar, the Gym Challenge is a spectacle: packed stadiums and live broadcasts. Pokémon grow into giants with Dynamax energy.')],
        'Motostoke': [L('Marnie', 'Desculpa por eles. Eles torcem muito por mim. Mesmo atrapalhando.', 'Sorry about them. They cheer really hard for me. Even when they get in the way.')],
        'Wyndon': [
            L('Rose', 'Galar vai ficar sem energia em mil anos. Eu vou resolver agora, acordando Eternatus. Desculpe, Leon. O jogo vai ter que esperar.', 'Galar will run out of energy in a thousand years. I’ll solve it now, by awakening Eternatus. Sorry, Leon. The match will have to wait.'),
        ],
    },
    'bosses': {
        **at('Hop', ('Turffield', 'Hulbury', 'Motostoke', 'Stow-on-Side', 'Ballonlea', 'Circhester', 'Spikemuth', 'Hammerlocke'),
             'Meu irmão é o Campeão! E um dia eu vou vencer ele. Começando por você!', 'My brother is the Champion! And one day I’ll beat him. Starting with you!',
             'Você é forte demais! Vou treinar mais.', 'You’re too strong! I’ll train more.'),
        **at('Bede', ('Turffield', 'Stow-on-Side', 'Circhester'), 'Eu fui escolhido pelo Rose. Você não passa de um mero desafiante.', 'I was chosen by Rose. You’re nothing but a mere challenger.', 'Isso... não conta.', 'That... doesn’t count.'),
        **at('Marnie', ('Turffield', 'Stow-on-Side', 'Circhester'), 'Vamos ver quem chega mais longe. Sem torcida dessa vez.', 'Let’s see who gets further. No cheering squad this time.', 'Você é bom. Vou lembrar.', 'You’re good. I’ll remember that.'),
        **at('Equipe Yell', ('Motostoke', 'Stow-on-Side', 'Spikemuth'), 'A Marnie vai ser a Campeã! Você não passa!', 'Marnie is going to be Champion! You’re not getting through!', 'Ai, ai! A Marnie vai ficar brava...', 'Oh no! Marnie’s going to be mad...'),
        'Milo@Turffield': S('Milo', 'Ah, você veio! Vamos ver se cresce algo bom aqui.', 'Oh, you came! Let’s see if something good grows here.', 'Que colheita! A Grass Badge é sua.', 'What a harvest! The Grass Badge is yours.'),
        'Nessa@Hulbury': S('Nessa', 'Minha onda vai te afogar!', 'My wave will drown you!', 'Você surfou bem. A Water Badge é sua.', 'You rode it well. The Water Badge is yours.'),
        'Kabu@Motostoke': S('Kabu', 'Fogo é ardor. Dynamax é força.', 'Fire is passion. Dynamax is strength.', 'Seu ardor é maior. A Fire Badge é sua.', 'Your passion burns brighter. The Fire Badge is yours.'),
        'Bea@Stow-on-Side': S('Bea', 'Eu treinei todos os dias. Venha!', 'I trained every single day. Come on!', 'Você mereceu. A Fighting Badge é sua.', 'You earned it. The Fighting Badge is yours.'),
        'Opal@Ballonlea': S('Opal', 'Você é rosa? Não? Então vamos ver se você é forte.', 'Are you pink? No? Then let’s see if you’re strong.', 'Hm. Forte, mas não rosa. A Fairy Badge é sua.', 'Hm. Strong, but not pink. The Fairy Badge is yours.'),
        'Gordie@Circhester': S('Gordie', 'Minhas pedras não rolam para trás.', 'My rocks don’t roll backward.', 'Você é sólido. A Rock Badge é sua.', 'You’re solid. The Rock Badge is yours.'),
        'Piers@Spikemuth': S('Piers', 'Meu ginásio não tem Dynamax. É só a gente aqui.', 'My Gym has no Dynamax. It’s just us here.', 'Belo show. A Dark Badge é sua.', 'Nice show. The Dark Badge is yours.'),
        'Raihan@Hammerlocke': S('Raihan', 'Eu sou o rival do Leon. Se não passar por mim, não chega a ele.', 'I’m Leon’s rival. If you can’t get past me, you won’t reach him.', 'Você vai enfrentar o Leon. Boa sorte.', 'You’ll face Leon. Good luck.'),
        'Oleana@Wyndon': S('Oleana', 'A Rose Tower é do senhor Rose. Ninguém atrapalha os planos dele.', 'Rose Tower belongs to Mr. Rose. No one interferes with his plans.', 'Hmpf. O senhor Rose vai resolver isso.', 'Hmph. Mr. Rose will handle this.'),
        'Rose@Wyndon': B([L('Rose', 'Eu vou acordar Eternatus e salvar o futuro de Galar. Não me atrapalhe.', 'I will awaken Eternatus and save Galar’s future. Don’t get in my way.')],
                         [L('', 'O Darkest Day começou. No Slumbering Weald, a espada e o escudo enferrujados chamaram Zacian e Zamazenta, que lutaram ao seu lado contra Eternatus.', 'The Darkest Day began. In the Slumbering Weald, the rusted sword and shield called Zacian and Zamazenta, who fought beside you against Eternatus.')]),
        'Leon@Wyndon': S('Leon', 'Vamos ter um tempo campeão! Eu nunca perdi. Até hoje!', 'Let’s have a champion time! I’ve never lost. Until today!', 'Você é o novo Campeão de Galar!', 'You’re Galar’s new Champion!'),
        'Hop@Wyndon': S('Hop', 'Você venceu meu irmão... Eu quero lutar com você mais uma vez!', 'You beat my brother... I want to battle you one more time!', 'Eu vou virar professor. E ainda vamos lutar muito!', 'I’m going to become a professor. And we’ll still battle a lot!'),
        'Sordward e Shielbert@Wyndon': S('Sordward e Shielbert', 'Somos descendentes dos heróis! Zacian e Zamazenta são nossos!', 'We are descendants of the heroes! Zacian and Zamazenta are ours!', 'Impossível! Os lobos escolheram você?', 'Impossible! The wolves chose you?'),
    },
}

PALDEA_RIVAL = ('Vamos ser rivais! Rivais de verdade! Vamos lutar todo dia!', 'Let’s be rivals! Real rivals! Let’s battle every day!', 'Isso! Você está ficando forte! De novo!', 'Yes! You’re getting strong! Again!')
SCARLET_VIOLET = {
    'intro': 'Você entra na Academia, em Mesagoza. Nemona, a garota mais forte da escola e já Campeã, mora do lado e traz Sprigatito, Fuecoco e Quaxly. Na praia, um Pokémon lendário ferido, Koraidon (ou Miraidon), vira seu parceiro de passeio. A Treasure Hunt começa.',
    'end': 'Em Area Zero, a IA do professor atravessou a máquina do tempo: "Arven... cuide-se. Eu tenho orgulho de você." Geeta reconheceu você como Campeão de Paldea. Um barco leva você para outra região.',
    'cities': {
        'Cortondo': [L('', 'A Treasure Hunt tem três caminhos: vencer os oito ginásios com Nemona, caçar os Titãs com Arven e enfrentar a Equipe Star em Starfall Street.', 'The Treasure Hunt has three paths: beat the eight Gyms with Nemona, hunt the Titans with Arven, and take on Team Star on Starfall Street.')],
        'Levincia': [L('Arven', 'O Mabosstiff... meu primeiro Pokémon. Ele se machucou protegendo a gente. As Herba Mystica são a única coisa que pode curar ele.', 'Mabosstiff... my first Pokémon. It got hurt protecting us. Herba Mystica are the only thing that can heal it.')],
        'Glaseado': [L('', 'No último Titã, Mabosstiff levantou e abanou o rabo. Arven chorou de costas para todo mundo.', 'At the last Titan, Mabosstiff got up and wagged its tail. Arven cried with his back to everyone.')],
        'Pokémon League': [L('', 'Em Area Zero, a IA com a cara do professor lutou com os Pokémon paradoxo. Koraidon recuperou a força, e juntos vocês venceram.', 'In Area Zero, the AI with the professor’s face battled with paradox Pokémon. Koraidon regained its strength, and together you won.')],
    },
    'bosses': {
        **at('Nemona', ('Cortondo', 'Artazon', 'Cascarrafa', 'Medali', 'Montenevera', 'Glaseado'), *PALDEA_RIVAL),
        'Katy@Cortondo': S('Katy', 'Meus insetos são doces como os meus pães!', 'My bugs are as sweet as my bread!', 'Que delícia de batalha! A insígnia é sua.', 'What a delicious battle! The badge is yours.'),
        'Brassius@Artazon': S('Brassius', 'A grama é arte! Minha obra vai florescer!', 'Grass is art! My work will bloom!', 'Uma obra-prima! A insígnia é sua.', 'A masterpiece! The badge is yours.'),
        'Iono@Levincia': S('Iono', 'Oi, gente! Ao vivo com a Iono! Vamos eletrizar esse desafiante!', 'Hey, everyone! Live with Iono! Let’s electrify this challenger!', 'Que live! A insígnia é sua!', 'What a stream! The badge is yours!'),
        'Kofu@Cascarrafa': S('Kofu', 'Peixe fresquinho e batalha quente!', 'Fresh fish and a hot battle!', 'Que sabor! A insígnia é sua.', 'What flavor! The badge is yours.'),
        'Larry@Medali': S('Larry', 'Eu sou só um assalariado. Vamos acabar logo com isso.', 'I’m just a salaryman. Let’s get this over with.', 'Bom trabalho. A insígnia é sua.', 'Good work. The badge is yours.'),
        'Ryme@Montenevera': S('Ryme', 'No palco dos fantasmas, eu solto o meu rap!', 'On the ghosts’ stage, I drop my rap!', 'Que rima! A insígnia é sua.', 'What a rhyme! The badge is yours.'),
        'Tulip@Alfornada': S('Tulip', 'Vou maquiar a sua derrota com cores psíquicas.', 'I’ll make up your defeat in psychic colors.', 'Que beleza. A insígnia é sua.', 'How beautiful. The badge is yours.'),
        'Grusha@Glaseado': S('Grusha', 'Na neve, só o frio fala.', 'In the snow, only the cold speaks.', 'Você esquentou até o gelo. A insígnia é sua.', 'You warmed even the ice. The badge is yours.'),
        **{f'{w}@{c}': S(w, a, b, 'A Equipe Star não é o que parece...', 'Team Star isn’t what it seems...') for (w, c), (a, b) in {
            ('Giacomo', 'Levincia'): ('Bem-vindo à base sombria da Equipe Star! O Starmobile está pronto!', 'Welcome to Team Star’s dark base! The Starmobile is ready!'),
            ('Mela', 'Cascarrafa'): ('Fogo na base! A Equipe Star não recua!', 'Fire at the base! Team Star doesn’t back down!'),
            ('Atticus', 'Medali'): ('Ó, visitante! O veneno é poesia nesta base.', 'Oh, visitor! Poison is poetry at this base.'),
            ('Ortega', 'Montenevera'): ('Hmpf! A base das fadas não é para qualquer um!', 'Hmph! The fairy base isn’t for just anyone!'),
            ('Eri', 'Alfornada'): ('A base lutadora é o meu escudo. Venha!', 'The fighting base is my shield. Come on!'),
        }.items()},
        'Penny@Glaseado': B([L('Penny', 'Eu... eu sou a chefe. Cassiopeia. A gente nunca quis machucar ninguém. A gente só quis ficar junto.', 'I... I’m the boss. Cassiopeia. We never wanted to hurt anyone. We just wanted to stay together.')],
                            [L('Penny', 'Obrigada por entender a Equipe Star.', 'Thank you for understanding Team Star.')]),
        'Hassel@Pokémon League': S('Hassel', 'Meus dragões são arte que me faz chorar.', 'My dragons are art that moves me to tears.', 'Que batalha linda... (snif)', 'What a beautiful battle... (sniff)'),
        'Poppy@Pokémon League': S('Poppy', 'Eu sou pequena, mas o meu aço é grande!', 'I’m little, but my steel is big!', 'Você é forte! Pode passar.', 'You’re strong! You can go.'),
        'Larry@Pokémon League': S('Larry', 'Hora extra na Elite. Os voadores, desta vez.', 'Overtime at the Elite Four. Flying types, this time.', 'Expediente encerrado. Siga.', 'Shift over. Go on.'),
        'Rika@Pokémon League': S('Rika', 'Hora da entrevista: mostre o que tem!', 'Interview time: show me what you’ve got!', 'Ótima entrevista. Siga.', 'Great interview. Go on.'),
        'Geeta@Pokémon League': S('Geeta', 'Você chegou até aqui. Agora mostre o que é ser campeão.', 'You’ve made it this far. Now show me what it means to be a champion.', 'Você é o Campeão de Paldea.', 'You are Paldea’s Champion.'),
        'Arven@Pokémon League': S('Arven', 'O Mabosstiff está de pé! E eu quero revanche, com a cozinha cheia de sanduíches.', 'Mabosstiff is back on its feet! And I want a rematch, with a kitchen full of sandwiches.', 'Valeu. Por tudo.', 'Thanks. For everything.'),
        'Nemona@Pokémon League': S('Nemona', 'Agora você é Campeão também! A gente pode lutar sério. De verdade. Sempre!', 'Now you’re a Champion too! We can battle for real. Seriously. Always!', 'Isso! A melhor batalha da minha vida! De novo amanhã!', 'Yes! The best battle of my life! Again tomorrow!'),
    },
}


# Só os chefes de cada jogo (as falas comuns de Alola valem para os dois, mas nem todos estão nos dois).
SUN_MOON_KEYS = ['Acerola@Mount Lanakila', 'Anabel@Mount Lanakila', 'Blue@Mount Lanakila', 'Dexio@Mount Lanakila', 'Dexio@Ruins of Life', 'Faba@Mount Lanakila', 'Faba@Ruins of Life', 'Gladion@Hokulani Observatory', 'Gladion@Verdant Cavern', 'Gladion@Wela Volcano Park', 'Guzma@Brooklet Hill', 'Guzma@Malie City', 'Guzma@Mount Lanakila', 'Guzma@Ruins of Life', 'Hala@Iki Town', 'Hala@Mount Lanakila', 'Hapu@Vast Poni Canyon', 'Hau@Brooklet Hill', 'Hau@Hokulani Observatory', 'Hau@Ruins of Life', 'Hau@Vast Poni Canyon', 'Hau@Verdant Cavern', 'Hau@Wela Volcano Park', 'Ilima@Verdant Cavern', 'Kahili@Mount Lanakila', 'Kiawe@Wela Volcano Park', 'Kukui@Mount Lanakila', 'Lana@Brooklet Hill', 'Lusamine@Hokulani Observatory', 'Lusamine@Wela Volcano Park', 'Mallow@Lush Jungle', 'Molayne@Hokulani Observatory', 'Nanu@Malie City', 'Olivia@Mount Lanakila', 'Olivia@Ruins of Life', 'Plumeria@Hokulani Observatory', 'Plumeria@Wela Volcano Park', 'Red@Mount Lanakila', 'Ryuki@Ruins of Life', 'Sina@Ruins of Life']
ULTRA_KEYS = ['Acerola@Mount Lanakila', 'Blue@Mount Lanakila', 'Cyrus@Mount Lanakila', 'Dexio@Malie City', 'Dexio@Wela Volcano Park', 'Dulse@Brooklet Hill', 'Dulse@Hokulani Observatory', 'Dulse@Lush Jungle', 'Dulse@Seafolk Village', 'Faba@Ruins of Life', 'Ghetsis@Mount Lanakila', 'Gladion@Malie City', 'Gladion@Verdant Cavern', 'Gladion@Wela Volcano Park', 'Guzma@Ruins of Life', 'Guzma@Seafolk Village', 'Guzma@Wela Volcano Park', 'Hala@Iki Town', 'Hapu@Vast Poni Canyon', 'Hau@Brooklet Hill', 'Hau@Hokulani Observatory', 'Hau@Lush Jungle', 'Hau@Mount Lanakila', 'Hau@Seafolk Village', 'Hau@Verdant Cavern', 'Ilima@Verdant Cavern', 'Kahili@Mount Lanakila', 'Kiawe@Wela Volcano Park', 'Lana@Brooklet Hill', 'Lillie@Mount Lanakila', 'Lusamine@Malie City', 'Lusamine@Wela Volcano Park', 'Lysandre@Mount Lanakila', 'Mallow@Lush Jungle', 'Maxie@Mount Lanakila', 'Mina@Seafolk Village', 'Molayne@Mount Lanakila', 'Nanu@Malie City', 'Olivia@Mount Lanakila', 'Olivia@Ruins of Life', 'Plumeria@Malie City', 'Plumeria@Wela Volcano Park', 'Red@Mount Lanakila', 'Ryuki@Ruins of Life', 'Sina@Ruins of Life', 'Soliera@Brooklet Hill', 'Soliera@Hokulani Observatory', 'Soliera@Lush Jungle', 'Soliera@Seafolk Village', 'Sophocles@Hokulani Observatory']
SUN_MOON['bosses'] = {k: v for k, v in SUN_MOON['bosses'].items() if k in SUN_MOON_KEYS}
ULTRA['bosses'] = {k: v for k, v in ULTRA['bosses'].items() if k in ULTRA_KEYS}

GAMES = {
    'Alola|Sun/Moon': SUN_MOON,
    'Alola|Ultra Sun/Ultra Moon': ULTRA,
    'Galar|Sword/Shield': SWORD_SHIELD,
    'Paldea|Scarlet/Violet': SCARLET_VIOLET,
}
