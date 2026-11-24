"""Orre, as regiões Ranger e os DLCs: Colosseum/XD, Ranger, Shadows of Almia, Guardian Signs, The Teal Mask, The Indigo Disk,
The Isle of Armor e The Crown Tundra (docs/historia/08-orre-rangers.md)."""
from .alola_galar_paldea import S
from .kanto import B, L

ORRE = {
    'intro': 'O barco atraca em Gateon Port. Orre é um deserto sem Pokémon selvagens no mato. "Ultimamente tem uns Pokémon estranhos por aí", diz um marinheiro. "Pokémon que não sentem nada." São os Pokémon Sombrios: a Cipher fecha o coração deles e os transforma em armas.',
    'end': 'Os Pokémon Sombrios abriram o coração de novo, um por um, em toda Orre. Wes, na moto: "Agora é com você. Orre está em boas mãos." Um barco leva você para outra região.',
    'cities': {
        'Pyrite Town': [L('', 'Pyrite Town é a cidade mais suja de Orre: bandidos nas esquinas, um xerife cansado e música alta saindo de uma caverna.', 'Pyrite Town is Orre’s dirtiest city: thugs on the corners, a tired sheriff and loud music coming out of a cave.')],
        'Agate Village': [L('', 'Agate Village é verde no meio do deserto. A Relic Stone purifica o coração dos Pokémon Sombrios.', 'Agate Village is green in the middle of the desert. The Relic Stone purifies the hearts of Shadow Pokémon.')],
        'Phenac City': [L('', 'Phenac City é a cidade mais bonita de Orre: fontes, mármore e um estádio no centro.', 'Phenac City is Orre’s most beautiful city: fountains, marble and a stadium in the center.')],
        'Cipher Lab': [L('', 'No meio do deserto, um prédio de vidro guarda a máquina que fecha o coração dos Pokémon.', 'In the middle of the desert, a glass building holds the machine that closes Pokémon’s hearts.')],
        'Realgam Tower': [L('', 'No topo da Realgam Tower, uma arena de luxo onde os ricos assistem batalhas, o verdadeiro líder da Cipher espera.', 'At the top of Realgam Tower, a luxury arena where the rich watch battles, Cipher’s true leader waits.')],
    },
    'bosses': {
        'Miror B.@Pyrite Town': S('Miror B.', 'Ooooh, yeah! Eu sou Miror B.! Meus Ludicolo dançam, e meus Pokémon Sombrios dançam também! Quer dançar comigo?', 'Ooooh, yeah! I’m Miror B.! My Ludicolo dance, and my Shadow Pokémon dance too! Wanna dance with me?', 'Nãããão! Minha dança! Isso não vai ficar assim, ouviu? Ooooh!', 'Noooo! My dance! This isn’t over, you hear? Ooooh!'),
        'Wes@Agate Village': S('Wes', 'Então você é quem está atrapalhando a Cipher agora. Eles voltaram, e piores. Quero ver se você aguenta.', 'So you’re the one getting in Cipher’s way now. They’re back, and worse. I want to see if you can handle it.', 'Nada mal. A Relic Stone pode curar os Pokémon Sombrios que você resgatar. Use.', 'Not bad. The Relic Stone can heal the Shadow Pokémon you rescue. Use it.'),
        'Dakim@Agate Village': S('Dakim', 'Dakim esmaga! Dakim não pensa! Dakim só esmaga!', 'Dakim smash! Dakim no think! Dakim only smash!', 'Dakim... perdeu?', 'Dakim... lost?'),
        'Venus@Phenac City': S('Venus', 'Oh, que gracinha, um desafiante. Eu sou a estrela de Orre. E os Sombrios... ah, eles são ainda mais obedientes.', 'Oh, how cute, a challenger. I’m Orre’s star. And the Shadow ones... oh, they’re even more obedient.', 'Que desagradável. Vou ter que me maquiar de novo.', 'How unpleasant. I’ll have to redo my makeup.'),
        'Ein@Cipher Lab': S('Ein', 'Eu criei a máquina. Eu tirei dos Pokémon o que os tornava fracos: os sentimentos. Você não entende a beleza disso.', 'I created the machine. I removed what made Pokémon weak: their feelings. You don’t understand the beauty of it.', 'Interessante... eles lutaram melhor com o coração aberto. Isso não está nos meus dados.', 'Interesting... they fought better with open hearts. That’s not in my data.'),
        'Wes@Desert Resort': S('Wes', 'A Cipher tem um chefe que ninguém conhece. Antes de você subir a torre, mais uma luta. Para ver se cresceu.', 'Cipher has a boss nobody knows. Before you climb the tower, one more battle. To see if you’ve grown.', 'Cresceu. Vá.', 'You’ve grown. Go.'),
        'Nascour@Desert Resort': S('Nascour', 'A Cipher não é uma gangue. É uma empresa. E, numa empresa, quem atrapalha é demitido.', 'Cipher isn’t a gang. It’s a company. And in a company, whoever gets in the way is fired.', 'Você vai subir até o fim, não é? Então vá. O chefe está esperando.', 'You’re going all the way up, aren’t you? Then go. The boss is waiting.'),
        'Evice@Realgam Tower': S('Evice', 'Você destruiu tudo. A máquina, os chefes, os Pokémon Sombrios. Mas eu ainda tenho os meus. Os mais fortes de Orre.', 'You destroyed everything. The machine, the bosses, the Shadow Pokémon. But I still have mine. The strongest in Orre.', 'Era para Orre ser minha. Só minha.', 'Orre was supposed to be mine. Only mine.'),
    },
}

FIORE = {
    'intro': 'Em Fiore não se prendem Pokémon em bolas: os Rangers ajudam a natureza com o Capture Styler. Em Ringtown, o chefe da base, Spenser, entrega o seu: "Aqui a gente não luta contra os Pokémon. A gente luta por eles."',
    'end': 'Os lendários foram embora em paz, e os Go-Rock Quads largaram a equipe para tocar música de verdade. Fiore está em paz. Um barco leva você para outra região.',
    'cities': {
        'Fall City': [L('', 'À noite, a Equipe Go-Rock tocava rock nos telhados e, com um Styler roubado, obrigava os Pokémon a obedecer.', 'At night, Team Go-Rock played rock on the rooftops and, with a stolen Styler, forced Pokémon to obey.')],
        'Summerland': [L('', 'Summerland é a terra do vulcão, onde o calor sobe do chão.', 'Summerland is the land of the volcano, where heat rises from the ground.')],
        'Sekra Range': [L('', 'O plano do pai dos Quads: soltar os lendários sobre Fiore para depois aparecer como herói e controlar tudo.', 'The Quads’ father’s plan: unleash the legendaries on Fiore, then show up as the hero and control everything.')],
        'Fiore Temple': [L('', 'O Fiore Temple é uma construção antiga no meio do mar.', 'The Fiore Temple is an ancient building in the middle of the sea.')],
    },
    'bosses': {
        'Solana@Fall City': S('Solana', 'Você é o novato de Ringtown? Antes de trabalharmos juntos, quero ver se você tem o que é preciso. Vamos treinar!', 'You’re the rookie from Ringtown? Before we work together, I want to see if you have what it takes. Let’s train!', 'Bom. Muito bom. Fica do meu lado e aprende.', 'Good. Very good. Stay by my side and learn.'),
        'Billy Jo@Fall City': S('Billy Jo', 'Somos os Go-Rock Quads! Fiore vai dançar no ritmo da gente, e os Pokémon também!', 'We’re the Go-Rock Quads! Fiore will dance to our beat, and so will the Pokémon!', 'Ei, isso não estava na música!', 'Hey, that wasn’t in the song!'),
        'Lavana@Summerland': S('Lavana', 'Quente, não é? Os Pokémon daqui são meus. Pode tentar levar, se não tiver medo de se queimar.', 'Hot, isn’t it? The Pokémon here are mine. Try to take them, if you’re not afraid of getting burned.', 'Hunf. O papai não vai gostar nada disso.', 'Hmph. Daddy won’t like this at all.'),
        'Solana@Wintown': S('Solana', 'Os Go-Rock estão roubando Pokémon pelas montanhas. Eu preciso saber se você aguenta o frio. Mais um treino!', 'Go-Rock is stealing Pokémon across the mountains. I need to know if you can handle the cold. One more training session!', 'Você aguenta. Vamos.', 'You can handle it. Let’s go.'),
        'Clyde@Wintown': S('Clyde', 'Você me atrapalha de novo, eu congelo esse seu Styler!', 'Get in my way again and I’ll freeze that Styler of yours!', 'Grr... Congelei eu.', 'Grr... I’m the one who froze.'),
        'Garret@Sekra Range': S('Garret', 'Ninguém passa daqui. O papai está quase terminando. Os lendários vão obedecer a gente!', 'No one gets past here. Dad’s almost done. The legendaries will obey us!', 'O papai... vai ficar sozinho lá em cima.', 'Dad... will be alone up there.'),
        'Gordor@Fiore Temple': S('Gordor', 'Hastings criou os Rangers, e eu fiquei esquecido. Agora até os lendários fazem o que eu quero. Raikou! Entei! Suicune!', 'Hastings created the Rangers, and I was forgotten. Now even the legendaries do as I say. Raikou! Entei! Suicune!', 'Eu só queria que o mundo me reconhecesse.', 'I only wanted the world to recognize me.'),
    },
}

ALMIA = {
    'intro': 'Em Almia, você entra na Escola de Rangers, perto de Vientown. No primeiro dia, Keith levanta o punho: "Eu vou ser o melhor Ranger de Almia! Você também? Então já somos rivais!"',
    'end': 'A máquina quebrou, os Pokémon foram libertados, e Keith deu um soco no ar: "Rangers de verdade!" Darkrai observa de longe. Um barco leva você para outra região.',
    'cities': {
        'Pueltown': [L('', 'Pueltown é a cidade do farol. A Equipe Dim Sun controla Pokémon com máquinas chamadas Gigaremo.', 'Pueltown is the lighthouse town. Team Dim Sun controls Pokémon with machines called Gigaremo.')],
        'Chicole Village': [L('', 'Em Chicole Village, uma fazenda tranquila, as Miltank estão furiosas.', 'In Chicole Village, a quiet farm, the Miltank are furious.')],
        'Boyleland': [L('', 'Boyleland é uma vila de fontes termais perto do vulcão.', 'Boyleland is a hot-spring village near the volcano.')],
        'Altru Building': [L('', 'Na Hippowdon Temple, a Dim Sun tinha acordado Regigigas, o colosso que puxou os continentes. Você e Keith o libertaram.', 'In the Hippowdon Temple, Dim Sun had awakened Regigigas, the colossus that towed the continents. You and Keith freed it.')],
        'Almia Castle': [L('', 'O Almia Castle é um castelo antigo guardado por cristais.', 'Almia Castle is an ancient castle guarded by crystals.')],
    },
    'bosses': {
        'Keith@Pueltown': S('Keith', 'Ha! Já faz tempo! Eu já resolvi três missões. E você? Vamos ver quem ficou mais forte!', 'Ha! Long time no see! I’ve already finished three missions. And you? Let’s see who got stronger!', 'Ouviu falar da Equipe Dim Sun? Estão controlando Pokémon com as Gigaremo. Cuidado.', 'Heard of Team Dim Sun? They’re controlling Pokémon with Gigaremo. Be careful.'),
        'Heath@Pueltown': S('Heath', 'Hehehe! Um Ranger! Nossos Pokémon são controlados pelas Gigaremo, garoto. Não adianta esse brinquedinho aí.', 'Heheheh! A Ranger! Our Pokémon are controlled by Gigaremo, kid. That little toy won’t help.', 'Hehe... Isso doeu.', 'Heh... That hurt.'),
        'Wendy@Chicole Village': S('Wendy', 'Achou mesmo que ia nos parar? Você é só um Ranger.', 'Did you really think you’d stop us? You’re just a Ranger.', 'Hmpf. Sorte.', 'Hmph. Luck.'),
        'Sven@Boyleland': S('Sven', 'Os Pokémon de Almia vão produzir energia sem fim para a Altru. Esse é o futuro. Você não pode parar o futuro.', 'Almia’s Pokémon will produce endless energy for Altru. That’s the future. You can’t stop the future.', 'O futuro... atrasou.', 'The future... got delayed.'),
        'Keith@Haruba Village': S('Keith', 'Eu descobri: a Dim Sun é a Altru Inc. Antes de a gente invadir, mais um treino. Eu não vou ser um peso morto pra você.', 'I found out: Dim Sun is Altru Inc. Before we storm in, one more training session. I won’t be dead weight for you.', 'Pronto. Vamos juntos!', 'Ready. Let’s go together!'),
        'Kincaid@Altru Building': S('Kincaid', 'Bem-vindos à Altru. Aqui nós transformamos Pokémon em energia. É progresso.', 'Welcome to Altru. Here we turn Pokémon into energy. It’s progress.', 'O presidente já foi para o castelo. Quando o Gigaremo final ligar, Almia inteira será dele.', 'The president has gone to the castle. When the final Gigaremo switches on, all of Almia will be his.'),
        'Blake Hall@Almia Castle': S('Blake Hall', 'Os Pokémon de Almia vão trabalhar para mim, para sempre. Uns mandam, outros obedecem.', 'Almia’s Pokémon will work for me, forever. Some command, others obey.', 'Impossível... A máquina...', 'Impossible... The machine...'),
    },
}

OBLIVIA = {
    'intro': 'Você chega a Oblivia caindo do céu: um Ranger atacado no ar pelos Pokémon Pinchers. Acorda na areia de Dolce Island, com um Pichu de ukulele cutucando seu rosto: "Pichu? Pi?" Ele vira seu parceiro.',
    'end': 'Os Pinchers foram presos. Summer sorriu: "Agora sim. Oblivia está em paz." Um barco leva você para outra região.',
    'cities': {
        'Renbow Island': [L('', 'Renbow Island é uma ilha cheia de cores. Os Pinchers caçam Pokémon com máquinas e naves.', 'Renbow Island is full of colors. The Pinchers hunt Pokémon with machines and ships.')],
        'Mitonga Island': [L('', 'Mitonga Island é uma ilha de selva.', 'Mitonga Island is a jungle island.')],
        'Oblivia Ruins': [L('', 'As Oblivia Ruins, um templo antigo, guardam o poder dos lendários.', 'The Oblivia Ruins, an ancient temple, hold the power of the legendaries.')],
    },
    'bosses': {
        'Summer@Renbow Island': S('Summer', 'Ei! Você é o novato que caiu do céu? Fica do meu lado. Mas antes, vamos ver se você está pronto!', 'Hey! You’re the rookie who fell from the sky? Stay by my side. But first, let’s see if you’re ready!', 'Bom. Os Pinchers estão em todo lugar. Vamos juntos.', 'Good. The Pinchers are everywhere. Let’s go together.'),
        'Purple Eyes@Renbow Island': S('Purple Eyes', 'Pokémon raros valem muito dinheiro. Você não vai estragar o nosso negócio, Ranger.', 'Rare Pokémon are worth a lot of money. You won’t ruin our business, Ranger.', 'O chefe não vai gostar disso.', 'The boss won’t like this.'),
        'Blue Eyes@Mitonga Island': S('Blue Eyes', 'Esses Pokémon vão para a coleção do chefe. Você? Você vai para o fundo do mar.', 'These Pokémon are going to the boss’s collection. You? You’re going to the bottom of the sea.', 'Afundei eu.', 'I’m the one who sank.'),
        'Summer@Layuda Island': S('Summer', 'O chefe dos Pinchers quer o poder das ruínas. Antes de irmos, mais um treino. Não vou deixar você entrar lá despreparado.', 'The Pinchers’ boss wants the ruins’ power. Before we go, one more training session. I won’t let you go in unprepared.', 'Agora sim. Vamos.', 'Now you’re ready. Let’s go.'),
        'Red Eyes@Faldera Island': S('Red Eyes', 'Você passou por dois de nós. Mas eu sou diferente. Ninguém entra nas ruínas sem passar por mim.', 'You got past two of us. But I’m different. No one enters the ruins without getting past me.', 'Passou. As ruínas são suas.', 'You got past. The ruins are yours.'),
        'Ice@Oblivia Ruins': S('Ice', 'Com o poder dos lendários, eu vou controlar todos os Pokémon de Oblivia. Você e esse Pichu ridículo não podem me parar.', 'With the legendaries’ power, I will control every Pokémon in Oblivia. You and that ridiculous Pichu can’t stop me.', 'Isso... não pode ser. Um Ranger...', 'This... can’t be. A Ranger...'),
    },
}

TEAL_MASK = {
    'intro': 'A Academia leva você numa viagem a Kitakami, terra de arrozais, macieiras e montanhas. Na estação de Mossui Town, dois irmãos da Blueberry Academy esperam: Carmine, mandona, e Kieran, tímido. No Kitakami Hall, uma placa conta a lenda do ogro e dos três Pokémon leais que o expulsaram.',
    'end': 'A lenda do ogro foi corrigida no Kitakami Hall, e Ogerpon finalmente anda pela vila sem medo. Kieran foi embora sem olhar para trás. Um barco leva você para outra região.',
    'cities': {
        'Apple Hills': [L('Kieran', 'Eu sempre quis ver o ogro. Dizem que ele é horrível. Eu não acredito.', 'I’ve always wanted to see the ogre. They say it’s horrible. I don’t believe it.')],
        'Oni Mountain': [L('', 'No meio da montanha, o ogro de verdade: Ogerpon, pequeno, de máscara, com medo de todo mundo.', 'Halfway up the mountain, the real ogre: Ogerpon, small and masked, afraid of everyone.'),
                         L('', 'Uma velha contou a verdade: o ogro nunca foi o vilão. Os três leais roubaram as máscaras dele, e o povo acreditou na mentira.', 'An old woman told the truth: the ogre was never the villain. The three loyal ones stole its masks, and the people believed the lie.')],
        'Crystal Pool': [L('Kieran', 'Você mentiu para mim! Você sabia que eu queria ver o ogro! Eu vou ficar mais forte que você. Prometo!', 'You lied to me! You knew I wanted to see the ogre! I’ll get stronger than you. I promise!')],
    },
    'bosses': {
        'Kieran@Apple Hills': S('Kieran', 'Eu... eu sou o Kieran. Prazer. Vamos lutar?', 'I... I’m Kieran. Nice to meet you. Want to battle?', 'Você é forte...', 'You’re strong...'),
        'Carmine@Apple Hills': S('Carmine', 'Vamos ver se você é forte o suficiente para andar com a gente!', 'Let’s see if you’re strong enough to hang out with us!', 'Hunf. Tá, você serve.', 'Hmph. Fine, you’ll do.'),
        'Munkidori@Apple Hills': S('', 'Munkidori, o macaco venenoso, ataca em Apple Hills!', 'Munkidori, the poisonous monkey, attacks in Apple Hills!', 'Munkidori fugiu.', 'Munkidori fled.'),
        'Okidogi@Oni Mountain': S('', 'Okidogi, o cão forte, bloqueia a Oni Mountain!', 'Okidogi, the strong dog, blocks Oni Mountain!', 'Okidogi recuou.', 'Okidogi backed down.'),
        'Fezandipiti@Kitakami Hall': S('', 'Fezandipiti, o faisão elegante, pousa no Kitakami Hall!', 'Fezandipiti, the elegant pheasant, lands at Kitakami Hall!', 'Fezandipiti voou embora.', 'Fezandipiti flew away.'),
        'Perrin@Timeless Woods': S('Perrin', 'Estou procurando o Ursaluna da lua de sangue. Primeiro, me mostre que você não vai assustar ele.', 'I’m looking for the Bloodmoon Ursaluna. First, show me you won’t scare it.', 'Você tem jeito. Vamos procurar juntos.', 'You have a way with them. Let’s look together.'),
        'Kieran@Crystal Pool': S('Kieran', 'Eu vou ficar mais forte que você. Agora!', 'I’ll get stronger than you. Right now!', '...', '...'),
    },
}

INDIGO_DISK = {
    'intro': 'A Blueberry Academy fica no mar, numa cúpula gigante com biomas: savana, costa, cânion e polo. Carmine te recebe: "Aqui as batalhas são em dupla. E o meu irmão... ele mudou. Você vai ver."',
    'end': 'Kieran pediu desculpas, e o clube começou a se encher de novo. No fundo de Area Zero, Terapagos dorme entre cristais. Um barco leva você para outra região.',
    'cities': {
        'Savanna Biome': [L('Carmine', 'Ele trocou todos os Pokémon. Só ficou com os mais fortes. Até o clube ele está destruindo. Por favor... para ele.', 'He swapped out all his Pokémon. He only kept the strongest. He’s even tearing the club apart. Please... stop him.')],
        'League Club Room': [L('', 'Kieran virou o Campeão da Liga Blueberry. Cortou o cabelo, fechou a jaqueta até o queixo e só fala de vitória.', 'Kieran has become the Blueberry League Champion. He cut his hair, zipped his jacket up to his chin, and only talks about winning.')],
    },
    'bosses': {
        'Carmine@Savanna Biome': S('Carmine', 'Bem-vindo à Blueberry. Quero ver se você ainda é forte.', 'Welcome to Blueberry. I want to see if you’re still strong.', 'Ainda é. Que bom.', 'You still are. Good.'),
        'Crispin@Savanna Biome': S('Crispin', 'Vamos ver se você arde! Fogo!', 'Let’s see if you burn! Fire!', 'Que chama! Siga.', 'What a flame! Go on.'),
        'Lacey@Coastal Biome': S('Lacey', 'Regras são regras! Mas uma batalha divertida também é regra!', 'Rules are rules! But a fun battle is a rule too!', 'Que divertido! Você passou.', 'That was fun! You passed.'),
        'Amarys@Canyon Biome': S('Amarys', 'Não espere conversa. Lute.', 'Don’t expect conversation. Fight.', '... Siga.', '... Go on.'),
        'Drayton@Polar Biome': S('Drayton', 'Eu podia estar dormindo. Mas tá bom, vamos.', 'I could be sleeping. But fine, let’s go.', 'Tá, você venceu. Vou cochilar.', 'Fine, you win. I’m taking a nap.'),
        'Kieran@League Club Room': B([L('Kieran', 'Eu treinei sem parar desde Kitakami. Eu peguei os mais fortes, eu venci todo mundo daqui. Eu não vou perder. Muito menos para você.', 'I’ve trained nonstop since Kitakami. I caught the strongest, I beat everyone here. I won’t lose. Least of all to you.')],
                                     [L('Kieran', 'Por que eu nunca consigo... Eu fiz tudo. Tudo!', 'Why can’t I ever... I did everything. Everything!'),
                                      L('Kieran', 'Eu fui horrível com todo mundo, não fui? Desculpa. Desculpa, mana.', 'I was horrible to everyone, wasn’t I? Sorry. I’m sorry, sis.')]),
    },
}

ISLE_OF_ARMOR = {
    'intro': 'Um trem leva você até a Isle of Armor. Na estação, o Mestre Mustard sorri tanto que os olhos somem: "Ohoho! Um novo aluno! Para virar aluno de verdade, você precisa passar por três testes." Honey, a esposa dele, empurra um prato de curry.',
    'end': 'Mustard riu de novo: "Você é um aluno de verdade agora! Ou melhor... um mestre!" Um barco leva você para outra região.',
    'cities': {
        'Tower of Two Fists': [L('Mustard', 'Este Kubfu é especial. Se ele confiar em você, é seu.', 'This Kubfu is special. If it trusts you, it’s yours.')],
        'Master Dojo': [L('', 'Na Tower of Two Fists, Kubfu escolheu o caminho e, no topo, evoluiu em Urshifu.', 'At the Tower of Two Fists, Kubfu chose its path and, at the top, evolved into Urshifu.')],
    },
    'bosses': {
        'Avery@Soothing Wetlands': S('Avery', 'Eu sou Avery, o aluno mais promissor do dojo! Um novato não vai me superar. Psíquico... é ciência!', 'I’m Avery, the dojo’s most promising student! A rookie won’t outdo me. Psychic... is science!', 'Inaceitável! Só pode ter sido sorte!', 'Unacceptable! It must have been luck!'),
        'Klara@Challenge Beach': S('Klara', 'Oi, oiii! Eu sou a Klara! Vou ser a melhor do dojo, tá? E quem atrapalha... leva um pouquinho de veneno.', 'Hiii! I’m Klara! I’m gonna be the best in the dojo, okay? And whoever gets in the way... gets a little poison.', 'Ai, que chato! Isso não vai pro meu vídeo!', 'Ugh, how annoying! This isn’t going in my video!'),
        'Kubfu@Tower of Two Fists': S('', 'Kubfu quer ver se pode confiar em você.', 'Kubfu wants to see if it can trust you.', 'Kubfu abanou o rabo. Ele confia em você.', 'Kubfu wagged its tail. It trusts you.'),
        'Mustard@Master Dojo': S('Mustard', 'Eu fui Campeão de Galar por muitos anos. Perdi porque fiquei com medo de perder. Agora quero ver quanto você aprendeu. Vamos com tudo!', 'I was Galar’s Champion for many years. I lost because I became afraid of losing. Now I want to see how much you’ve learned. Let’s go all out!', 'Ohoho! Você é um aluno de verdade agora! Ou melhor... um mestre!', 'Ohoho! You’re a true student now! Or rather... a master!'),
    },
}

CROWN_TUNDRA = {
    'intro': 'O trem para numa tundra branca. Um homem enorme de capacete de minerador grita de longe: "Hahaha! Você deve ser o meu novo parceiro de expedição! Eu sou Peony!" Em Freezington, o povo fala de um rei antigo, Calyrex.',
    'end': 'Peony tirou o capacete: "Obrigado, parceiro. Você me mostrou que eu não estava velho demais para aventuras." As lendas da tundra estão em paz. Um barco leva você para outra região.',
    'cities': {
        'Split-Decision Ruins': [L('Peony', 'Só pode escolher uma porta! Eu sempre fui ruim em escolher.', 'You can only pick one door! I’ve always been bad at choosing.')],
        'Crown Shrine': [L('Calyrex', 'Humano... Eu era o rei destas terras. Meu fiel corcel me abandonou. Ajude-me a chamá-lo de novo.', 'Human... I was the king of these lands. My loyal steed abandoned me. Help me call it back.')],
    },
    'bosses': {
        'Peony@Ballimere Lake': S('Peony', 'Antes da expedição, uma batalha! Pra ver se a gente é uma boa dupla! Hahaha!', 'Before the expedition, a battle! To see if we make a good team! Hahaha!', 'Excelente! Com você, a expedição vai ser um sucesso!', 'Excellent! With you, the expedition will be a success!'),
        'Regieleki@Split-Decision Ruins': S('', 'Do outro lado da porta, o antigo Regi acordou!', 'Beyond the door, the ancient Regi awoke!', 'O Regi se acalmou.', 'The Regi calmed down.'),
        'Calyrex@Crown Shrine': S('Calyrex', 'Meu corcel voltou. Agora quero provar que ainda sou rei.', 'My steed has returned. Now I wish to prove I am still king.', 'Você é digno, humano.', 'You are worthy, human.'),
        'Peony@Freezington': S('Peony', 'Hahaha! Parceiro! A expedição acabou, mas eu quero fechar com chave de ouro! Uma batalha de verdade!', 'Hahaha! Partner! The expedition is over, but I want to end it in style! A real battle!', 'Obrigado, parceiro. Eu achei que estava velho demais para aventuras.', 'Thanks, partner. I thought I was too old for adventures.'),
    },
}

GAMES = {
    'Orre|Colosseum/XD': ORRE,
    'Fiore|Ranger': FIORE,
    'Almia|Shadows of Almia': ALMIA,
    'Oblivia|Guardian Signs': OBLIVIA,
    'Kitakami|The Teal Mask': TEAL_MASK,
    'Blueberry|The Indigo Disk': INDIGO_DISK,
    'Armor|The Isle of Armor': ISLE_OF_ARMOR,
    'Crown|The Crown Tundra': CROWN_TUNDRA,
}
