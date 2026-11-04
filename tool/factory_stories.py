"""A história da corrida em cada região (texto original, só para dar contexto).
A Battle Factory (os andares) não existe na história: é só o contador de até
onde você avançou; na história, você viaja pela região, de cidade em cidade.
{0} é o nome do chefe. Usado por tool/build_factory_data.py.

intro: quando a região começa; gym/rival/villain/elite/champion: antes do
chefe desse tipo; end: depois do Campeão (a corrida segue para outra região).
"""

STORIES = {
    'Kanto': {
        'intro': 'Em Pallet Town, você recebe seu primeiro parceiro e uma mochila quase vazia. Os Pokémon de Kanto andam inquietos e ninguém sabe por quê. A jornada começa na Route 1.',
        'gym': '{0} já ouviu falar de você. Uma insígnia de Kanto é a prova de que você pode seguir viagem.',
        'rival': '{0} saiu de Pallet Town no mesmo dia que você e chegou antes, como sempre. "Achou que ia ser o primeiro? Vamos ver quem treinou mais!"',
        'villain': 'Homens de preto com um R no peito estão roubando Pokémon pela região. {0} comanda a Equipe Rocket.',
        'elite': 'A Elite Four de Kanto espera no Indigo Plateau. {0} bloqueia a passagem.',
        'champion': 'No fim de Kanto, {0} espera como Campeão. É a última batalha da região.',
        'end': 'Kanto voltou a ficar em paz. Um barco no porto leva você para outra região.',
    },
    'Johto': {
        'intro': 'Os sinos de Johto tocaram sozinhos. Você parte de New Bark Town; os anciãos dizem que os lendários estão observando quem viaja pela região.',
        'gym': '{0}, líder de Johto, guarda o ginásio com o orgulho da tradição. Mostre respeito e força.',
        'rival': '{0} roubou um Pokémon de um laboratório e jura que só os fortes merecem vencer. Ele quer provar isso em você.',
        'villain': 'A Equipe Rocket voltou e está transmitindo sinais estranhos pela região. {0} comanda o ataque.',
        'elite': 'A Elite Four de Johto treina no frio do Indigo. {0} quer ver se você aguenta.',
        'champion': '{0}, o Campeão, chega com seus dragões. Os sinos tocam mais forte.',
        'end': 'Os sinos silenciaram. Ho-Oh passou voando e um trem leva você para uma nova região.',
    },
    'Hoenn': {
        'intro': 'Chuva sem fim de um lado, seca do outro: o clima de Hoenn enlouqueceu. Sua viagem começa em Littleroot Town.',
        'gym': '{0} quer ver do que você é capaz. Uma insígnia acalma um pouco o clima.',
        'rival': '{0} também quer completar a Pokédex e não vai deixar você passar na frente.',
        'villain': 'As Equipes Magma e Aqua brigam pela região: uma quer mais terra, a outra mais mar. {0} está no caminho.',
        'elite': 'A Elite Four de Hoenn espera em Ever Grande. {0} não pega leve.',
        'champion': '{0} coleciona pedras raras e diz que você é a mais rara que já viu. Só um dos dois sai vencedor.',
        'end': 'O sol e a chuva voltaram ao normal. Rayquaza cruzou o céu e um barco já espera você no porto.',
    },
    'Sinnoh': {
        'intro': 'Em Sinnoh, o tempo e o espaço tremeram perto do Monte Coronet. Você sai de Twinleaf Town para descobrir o que está acontecendo.',
        'gym': '{0}, líder de Sinnoh, quer saber se você está pronto para o que vem pela frente.',
        'rival': '{0} está sempre com pressa e já foi multado por isso. "Vou chegar antes de você!"',
        'villain': 'A Equipe Galáctica quer criar um mundo novo. {0} está pronto para isso.',
        'elite': 'A Elite Four de Sinnoh vigia a Liga. {0} sente a distorção chegando.',
        'champion': '{0}, a Campeã, estuda as lendas de Sinnoh e quer saber se você merece a verdade.',
        'end': 'Dialga e Palkia se acalmaram. Você pega o barco para uma nova região.',
    },
    'Unova': {
        'intro': 'Em Unova, todos discutem: os Pokémon devem ficar com os humanos ou ser libertados? Sua jornada começa em Nuvema Town, no meio dessa briga.',
        'gym': '{0} defende o ginásio e quer ver a ligação entre você e seus Pokémon.',
        'rival': '{0} cresceu com você e quer ficar mais forte para proteger quem ama.',
        'villain': 'A Equipe Plasma diz querer libertar os Pokémon, mas esconde outro plano. {0} está a serviço dela.',
        'elite': 'A Elite Four de Unova guarda a Liga. {0} quer ver sua verdade e seus ideais.',
        'champion': '{0} espera no fim de Unova. Verdade ou ideais: o que move você?',
        'end': 'Os dragões de Unova se acalmaram. Um avião leva você para outra região.',
    },
    'Kalos': {
        'intro': 'Kalos é linda, mas uma arma antiga voltou a brilhar debaixo da região. Você sai de Vaniville Town; alguém quer usá-la para deixar o mundo "bonito".',
        'gym': '{0}, com todo o estilo de Kalos, quer uma batalha à altura da região.',
        'rival': '{0} e os amigos também estão viajando e querem ver o quanto você evoluiu.',
        'villain': 'A Equipe Flare só aceita quem tem dinheiro e estilo. {0} quer você longe da arma.',
        'elite': 'A Elite Four de Kalos ocupa o castelo da Liga. {0} luta com elegância.',
        'champion': '{0} é campeã e estrela de cinema. A última cena de Kalos é sua.',
        'end': 'A arma voltou a dormir. Xerneas e Yveltal assistiram tudo de longe, e o trem para outra região já vai partir.',
    },
    'Alola': {
        'intro': 'Em Alola, buracos estranhos no céu trazem criaturas de outro mundo. Você chega a Hau\'oli City para o desafio das ilhas.',
        'gym': '{0} preparou a prova da ilha para testar você. Cada ilha tem seu desafio.',
        'rival': '{0} adora batalhas e quer ser seu maior rival de Alola.',
        'villain': 'A Equipe Skull e a Fundação Aether escondem segredos sobre os buracos no céu. {0} está envolvido.',
        'elite': 'A primeira Elite Four de Alola mal começou e já quer derrotar você. {0} está pronto.',
        'champion': '{0} defende o título de Alola no topo da montanha. É o último desafio das ilhas.',
        'end': 'Os buracos no céu se fecharam e as ilhas fizeram uma festa. Um barco leva você para a próxima região.',
    },
    'Galar': {
        'intro': 'Em Galar, batalhas lotam estádios e o céu escureceu: a energia Dynamax está vazando. Você sai de Postwick rumo ao Desafio dos Ginásios.',
        'gym': '{0} faz da batalha um show. A torcida está toda lá para ver você.',
        'rival': '{0} sonha em vencer o Campeão desde criança e quer começar vencendo você.',
        'villain': 'Os torcedores da Equipe Yell e os planos da Macro Cosmos complicam a viagem. {0} está no meio disso.',
        'elite': 'O Campeonato de Galar chegou às finais. {0} quer a vaga contra o Campeão.',
        'champion': '{0}, o Campeão invicto, ergue o braço e o estádio explode. Hora da final.',
        'end': 'A energia Dynamax se estabilizou e o céu de Galar clareou. O trem para a próxima região já está na plataforma.',
    },
    'Paldea': {
        'intro': 'Em Paldea, a escola deu como tarefa uma busca pelo tesouro. Você sai de Cabo Poco, e o maior mistério está na Grande Cratera.',
        'gym': '{0} aplica o teste do ginásio antes da batalha. Paldea gosta de surpresas.',
        'rival': '{0} quer ser campeã e decidiu que você é o rival perfeito.',
        'villain': 'A Equipe Star não é bem o que parece. {0} vai ter que ser enfrentado para você entender.',
        'elite': 'A Elite Four de Paldea entrevista e depois batalha. {0} faz a última pergunta.',
        'champion': '{0}, a presidente da Liga, quer ver de perto quem chegou tão longe.',
        'end': 'A Grande Cratera ficou em silêncio. A viagem continua para outra região.',
    },
}

# As cidades do mapa da corrida: o líder (o nome do treinador, sem o "sd-" e o
# "-genN" do sprite) -> a cidade do ginásio (ou da prova, em Alola). Os
# chefes que não são de ginásio (rival, vilões) aparecem na cidade do próximo
# líder; a Elite Four e o Campeão, na Liga (league). Nomes próprios: não traduzir.
CITIES = {
    'Kanto': {
        'league': 'Indigo Plateau',
        'brock': 'Pewter City', 'misty': 'Cerulean City', 'lt-surge': 'Vermilion City', 'erika': 'Celadon City',
        'koga': 'Fuchsia City', 'janine': 'Fuchsia City', 'sabrina': 'Saffron City', 'blaine': 'Cinnabar Island',
        'giovanni': 'Viridian City', 'champion-blue': 'Viridian City', 'blue': 'Viridian City',
    },
    'Johto': {
        'league': 'Indigo Plateau',
        'falkner': 'Violet City', 'bugsy': 'Azalea Town', 'whitney': 'Goldenrod City', 'morty': 'Ecruteak City',
        'chuck': 'Cianwood City', 'jasmine': 'Olivine City', 'pryce': 'Mahogany Town', 'clair': 'Blackthorn City',
        'brock': 'Pewter City', 'misty': 'Cerulean City', 'lt-surge': 'Vermilion City', 'erika': 'Celadon City',
        'janine': 'Fuchsia City', 'sabrina': 'Saffron City', 'blaine': 'Seafoam Islands', 'champion-blue': 'Viridian City',
        'blue': 'Viridian City',
    },
    'Hoenn': {
        'league': 'Ever Grande City',
        'roxanne': 'Rustboro City', 'brawly': 'Dewford Town', 'wattson': 'Mauville City', 'flannery': 'Lavaridge Town',
        'norman': 'Petalburg City', 'winona': 'Fortree City', 'tate-liza': 'Mossdeep City', 'wallace': 'Sootopolis City',
        'juan': 'Sootopolis City',
    },
    'Sinnoh': {
        'league': 'Pokémon League',
        'roark': 'Oreburgh City', 'gardenia': 'Eterna City', 'fantina': 'Hearthome City', 'maylene': 'Veilstone City',
        'wake': 'Pastoria City', 'byron': 'Canalave City', 'candice': 'Snowpoint City', 'volkner': 'Sunyshore City',
    },
    'Unova': {
        'league': 'Pokémon League',
        'chili': 'Striaton City', 'cilan': 'Striaton City', 'cress': 'Striaton City', 'lenora': 'Nacrene City',
        'burgh': 'Castelia City', 'elesa': 'Nimbasa City', 'clay': 'Driftveil City', 'skyla': 'Mistralton City',
        'brycen': 'Icirrus City', 'drayden': 'Opelucid City', 'iris': 'Opelucid City', 'cheren': 'Aspertia City',
        'roxie': 'Virbank City', 'marlon': 'Humilau City',
    },
    'Kalos': {
        'league': 'Pokémon League',
        'viola': 'Santalune City', 'grant': 'Cyllage City', 'korrina': 'Shalour City', 'ramos': 'Coumarine City',
        'clemont': 'Lumiose City', 'valerie': 'Laverre City', 'olympia': 'Anistar City', 'wulfric': 'Snowbelle City',
    },
    'Alola': {
        'league': 'Mount Lanakila',
        'ilima': 'Verdant Cavern', 'hala': 'Iki Town', 'lana': 'Brooklet Hill', 'kiawe': 'Wela Volcano Park',
        'mallow': 'Lush Jungle', 'olivia': 'Ruins of Life', 'sophocles': 'Hokulani Observatory', 'acerola': 'Thrifty Megamart',
        'molayne': 'Hokulani Observatory', 'nanu': 'Malie City', 'mina': 'Seafolk Village', 'hapu': 'Vast Poni Canyon',
        'kahili': 'Mount Lanakila',
    },
    'Galar': {
        'league': 'Wyndon',
        'milo': 'Turffield', 'nessa': 'Hulbury', 'kabu': 'Motostoke', 'bea': 'Stow-on-Side', 'allister': 'Stow-on-Side',
        'opal': 'Ballonlea', 'bede': 'Ballonlea', 'gordie': 'Circhester', 'melony': 'Circhester', 'piers': 'Spikemuth',
        'marnie': 'Spikemuth', 'raihan': 'Hammerlocke',
    },
    'Paldea': {
        'league': 'Pokémon League',
        'katy': 'Cortondo', 'brassius': 'Artazon', 'iono': 'Levincia', 'kofu': 'Cascarrafa', 'larry': 'Medali',
        'ryme': 'Montenevera', 'tulip': 'Alfornada', 'grusha': 'Glaseado',
    },
}
