"""Sevii Islands e Liga Laranja (docs/historia/07-sevii-orange.md)."""
from .alola_galar_paldea import S
from .kanto import B, L

SEVII = {
    'intro': 'Depois do Hall da Fama, Bill te encontra no porto de Vermilion: "Um amigo meu, o Celio, está montando uma máquina que liga o PC de Kanto ao mundo inteiro. Vem comigo?" O Seagallop Ferry leva vocês até One Island. Faltam duas pedras: a Ruby e a Sapphire.',
    'end': 'Com a Ruby e a Sapphire, a luz azul ligou Kanto às ilhas e a Hoenn. Blue riu de verdade: "Você ainda é mais forte. Mas eu gosto disso." Um barco leva você para outra região.',
    'cities': {
        'Three Island': [
            L('Celio', 'Bill! E você deve ser o Campeão. A máquina está quase pronta, mas faltam a Ruby e a Sapphire.', 'Bill! And you must be the Champion. The machine is almost ready, but it needs the Ruby and the Sapphire.'),
            L('', 'No Mt. Ember, dois Rockets cochichavam sobre uma pedra vermelha. Você os venceu e achou a Ruby. No pico, Moltres dormia.', 'On Mt. Ember, two Rockets whispered about a red stone. You beat them and found the Ruby. At the peak, Moltres was sleeping.'),
        ],
        'Four Island': [L('', 'Em Three Island, o povo saiu das casas aplaudindo. No Berry Forest, você achou o Pokémon perdido de uma menina, chorando entre as árvores.', 'On Three Island, the people came out of their houses cheering. In Berry Forest, you found a girl’s lost Pokémon, crying among the trees.')],
        'Five Island': [L('Lorelei', 'Obrigada. Sabe... eu também tenho um Lapras. Ele é daqui.', 'Thank you. You know... I have a Lapras too. It’s from here.'),
                        L('', 'Uma senha escondida no Memorial Pillar abriu a porta do Rocket Warehouse.', 'A password hidden at the Memorial Pillar opened the Rocket Warehouse door.')],
        'Six Island': [L('', 'No computador do armazém: "Sapphire. Dotted Hole. Six Island." Na Dotted Hole, quando você pegou a pedra, um cientista a arrancou da sua mão.', 'On the warehouse computer: "Sapphire. Dotted Hole. Six Island." In the Dotted Hole, as you took the stone, a scientist snatched it from your hand.')],
        'Seven Island': [L('Celio', 'Conseguimos! Graças a você, os Pokémon do mundo inteiro podem se encontrar.', 'We did it! Thanks to you, Pokémon from all over the world can meet.'),
                         L('', 'Em Seven Island, a Trainer Tower desafia treinadores a subir andares lutando. No topo, alguém espera de costas.', 'On Seven Island, the Trainer Tower challenges Trainers to battle up its floors. At the top, someone waits with their back turned.')],
    },
    'bosses': {
        'Paxton@Three Island': S('Paxton', 'Esta ilha agora é nossa! Os velhos daqui que se virem. Quer passar? Vai ter que me derrubar!', 'This island is ours now! The old folks can fend for themselves. Want to pass? You’ll have to knock me down!', 'Hunf. Vamos embora, pessoal.', 'Hmph. Let’s go, guys.'),
        'Lorelei@Four Island': B([L('Lorelei', 'Você? O novo Campeão? Rockets estão capturando Lapras no Icefall Cave. Antes, quero ver se você aguenta o frio.', 'You? The new Champion? Rockets are catching Lapras in Icefall Cave. First, I want to see if you can handle the cold.')],
                                 [L('Lorelei', 'Pegar Pokémon desta ilha para vender? Isso eu não perdoo. Venha comigo.', 'Taking this island’s Pokémon to sell? That I won’t forgive. Come with me.')]),
        'Executivo@Five Island': S('Executivo', 'Giovanni se foi, mas nós continuamos. Este armazém guarda tudo o que roubamos. E ninguém vai entrar.', 'Giovanni is gone, but we carry on. This warehouse holds everything we stole. And no one gets in.', 'O chefe... nunca vai voltar?', 'The boss... is never coming back?'),
        'Executiva@Five Island': S('Executiva', 'Uma criança, de novo? É sempre uma criança!', 'A child, again? It’s always a child!', 'Hmpf. Vão atrás da Sapphire, se quiserem.', 'Hmph. Go after the Sapphire, if you want.'),
        'Gideon@Six Island': S('Gideon', 'Ha! Sabe quanto a Equipe Rocket vai pagar por isso? Muito! Eu trabalho para quem paga mais!', 'Ha! Know how much Team Rocket will pay for this? A lot! I work for whoever pays most!', 'Hunf. Tá, tá. Mas eu já mandei os dados para eles. A pedra não importa mais!', 'Hmph. Fine, fine. But I already sent them the data. The stone doesn’t matter anymore!'),
        'Blue@Seven Island': S('Blue', 'Achei que você ia aparecer. Agora eu sou o líder de Viridian, sabia? Mas aqui não tem título. É só você e eu.', 'I figured you’d show up. I’m Viridian’s Gym Leader now, you know? But there’s no title here. It’s just you and me.', 'Você ainda é mais forte. Mas eu gosto disso. Me dá vontade de continuar.', 'You’re still stronger. But I like that. It makes me want to keep going.'),
    },
}

ORANGE = {
    'intro': 'Uma encomenda leva você até Valencia Island, no sul quente do mar de Kanto. A Professora Ivy conta: "Aqui não tem ginásio comum: tem a Liga Laranja. Quatro líderes, quatro provas, e um Supremo Líder na Pummelo Island."',
    'end': 'Você é o Campeão da Liga Laranja. Em Shamouti, a lenda diz que, quando o mar fica bravo, Lugia aparece para acalmar os senhores do fogo, do gelo e do raio. Um barco leva você para outra região.',
    'cities': {
        'Mikan Island': [L('Ivy', 'As Orange Islands são outro mundo. Aqui os Pokémon têm cores diferentes: Raticate de bigode amarelo, Butterfree rosa.', 'The Orange Islands are another world. Pokémon here have different colors: yellow-whiskered Raticate, pink Butterfree.')],
        'Navel Island': [L('', 'Navel Island é um monte coberto de neve no meio do mar tropical.', 'Navel Island is a snow-covered peak in the middle of the tropical sea.')],
        'Trovita Island': [L('', 'Em Trovita, o líder dança com a irmãzinha, Mahri.', 'In Trovita, the Leader dances with his little sister, Mahri.')],
        'Kumquat Island': [L('', 'Kumquat é um hotel de férias, e a líder cuida dele com o filho pequeno, Travis.', 'Kumquat is a vacation resort, and the Leader runs it with her little son, Travis.')],
        'Pummelo Island': [L('', 'No estádio de Pummelo, o Supremo Líder, que nunca perdeu, espera em pé na arena.', 'In Pummelo’s stadium, the Supreme Gym Leader, who has never lost, waits standing in the arena.')],
    },
    'bosses': {
        'Cissy@Mikan Island': S('Cissy', 'Bem-vindo à Liga Laranja! A primeira prova é de pontaria, depois uma corrida sobre Lapras. Pronto?', 'Welcome to the Orange League! The first test is accuracy, then a race on Lapras. Ready?', 'A Coral-Eye Badge. Você nada bem.', 'The Coral-Eye Badge. You swim well.'),
        'Danny@Navel Island': S('Danny', 'Minhas provas são três: subir o gêiser, fazer um trenó de gelo, descer a montanha! Depois a gente luta.', 'My tests are three: climb the geyser, build an ice sled, ride down the mountain! Then we battle.', 'Ha! Gostei de você! Leve a Sea Ruby Badge.', 'Ha! I like you! Take the Sea Ruby Badge.'),
        'Rudy@Trovita Island': S('Rudy', 'Bem-vindo, desafiante. Primeiro, acertar alvos no mar. Depois, uma batalha de verdade. E, se puder, um pouco de dança.', 'Welcome, challenger. First, hit targets at sea. Then, a real battle. And, if you can, a little dancing.', 'Você é forte. Mahri gosta de você. A Spike Shell Badge é sua.', 'You’re strong. Mahri likes you. The Spike Shell Badge is yours.'),
        'Luana@Kumquat Island': S('Luana', 'Minha prova é uma batalha dupla. O segredo é a confiança entre os Pokémon.', 'My test is a double battle. The secret is trust between the Pokémon.', 'Seus Pokémon confiam um no outro. A Jade Star Badge é sua.', 'Your Pokémon trust each other. The Jade Star Badge is yours.'),
        'Drake@Pummelo Island': S('Drake', 'Eu sou Drake. Ninguém tirou o Troféu Laranja de mim. Batalha completa: seis contra seis.', 'I am Drake. No one has taken the Orange Trophy from me. Full battle: six against six.', 'Hoje você é o Campeão da Liga Laranja.', 'Today you are the Orange League Champion.'),
    },
}

GAMES = {
    'Sevii|Sevii Islands': SEVII,
    'Orange|Liga Laranja': ORANGE,
}
