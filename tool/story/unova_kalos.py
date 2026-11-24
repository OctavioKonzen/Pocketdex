"""Unova e Kalos: Black/White, Black 2/White 2 e X/Y (docs/historia/05-unova-kalos.md)."""
from .kanto import B, L


def rival(who, lines, after_pt, after_en):
    return {f'{who}@{c}': B([L(who, a, b)], [L(who, after_pt, after_en)]) for c, (a, b) in lines.items()}


ELITE_UNOVA = {
    'Shauntal@Pokémon League': B([L('Shauntal', 'Eu escrevo histórias sobre treinadores. Me dê um bom capítulo!', 'I write stories about Trainers. Give me a good chapter!')], [L('Shauntal', 'Que história! Vou escrever sobre você.', 'What a story! I’ll write about you.')]),
    'Marshal@Pokémon League': B([L('Marshal', 'Eu sou aluno do Alder. Minha força vem do treino!', 'I’m Alder’s student. My strength comes from training!')], [L('Marshal', 'Você é forte. Siga em frente.', 'You’re strong. Go on ahead.')]),
    'Grimsley@Pokémon League': B([L('Grimsley', 'Na vida e na batalha, tudo é uma aposta. Vamos jogar!', 'In life and in battle, everything is a gamble. Let’s play!')], [L('Grimsley', 'Perdi a aposta. Siga.', 'I lost the bet. Go on.')]),
    'Caitlin@Pokémon League': B([L('Caitlin', 'Eu estava dormindo... Você me acordou. Então vamos lutar.', 'I was sleeping... You woke me. So let’s battle.')], [L('Caitlin', 'Que batalha elegante. Pode passar.', 'Such an elegant battle. You may pass.')]),
}

BLACK_WHITE = {
    'intro': 'Em Nuvema Town, uma caixa de presente da Professora Juniper espera no seu quarto: Snivy, Tepig e Oshawott. Seus amigos de infância estão ali: Cheren, sério, quer ser Campeão; Bianca, doce, quer descobrir o que quer da vida. A primeira batalha destrói o quarto, e sua mãe só ri.',
    'end': 'Ghetsis foi preso, e N voou no dragão para procurar o próprio caminho. Unova está em paz. Um barco leva você para outra região.',
    'cities': {
        'Striaton City': [
            L('Ghetsis', 'Os Pokémon têm sentimentos! Nós os prendemos em bolas e mandamos lutar. Isso é justo? Libertem seus Pokémon!', 'Pokémon have feelings! We lock them in balls and make them fight. Is that fair? Liberate your Pokémon!'),
            L('N', 'Seus Pokémon... Esse Pokémon disse que gosta de você. Não entendo. Como pode?', 'Your Pokémon... This Pokémon said it likes you. I don’t understand. How can that be?'),
        ],
        'Nacrene City': [
            L('', 'No Dreamyard, a Equipe Plasma queria o gás de sonho dos Munna. Em Nacrene, o museu guarda uma Dragon Skull e uma pedra escura.', 'In the Dreamyard, Team Plasma wanted the Munna’s dream mist. In Nacrene, the museum holds a Dragon Skull and a dark stone.'),
        ],
        'Castelia City': [
            L('', 'A Plasma roubou o crânio do museu, e você o recuperou no Pinwheel Forest. Castelia, a cidade dos arranha-céus, tem ruas cheias de gente.', 'Plasma stole the museum’s skull, and you got it back in Pinwheel Forest. Castelia, the city of skyscrapers, has streets full of people.'),
        ],
        'Nimbasa City': [
            L('N', 'Lá em cima da roda-gigante eu te conto: eu sou o rei da Equipe Plasma. Quando eu tiver o Pokémon lendário, todos vão me ouvir.', 'Up here on the Ferris wheel I’ll tell you: I’m Team Plasma’s king. When I have the legendary Pokémon, everyone will listen to me.'),
        ],
        'Driftveil City': [
            L('', 'Em Driftveil, Ghetsis e os Sete Sábios prenderam treinadores para tirar os Pokémon deles.', 'In Driftveil, Ghetsis and the Seven Sages held Trainers to take their Pokémon.'),
        ],
        'Opelucid City': [
            L('N', 'Eu fui escolhido. Agora, vá encontrar o outro dragão. Só então a verdade vai aparecer.', 'I have been chosen. Now, go find the other dragon. Only then will the truth appear.'),
            L('', 'Na Dragonspiral Tower, N despertou Reshiram (ou Zekrom), e o dragão voou com ele.', 'At Dragonspiral Tower, N awoke Reshiram (or Zekrom), and the dragon flew off with him.'),
        ],
        'Pokémon League': [
            L('', 'A pedra antiga que você trazia começou a esquentar na mochila. Na Liga, a Elite dos Quatro espera.', 'The ancient stone you carried began to grow warm in your bag. At the League, the Elite Four awaits.'),
        ],
    },
    'bosses': {
        **rival('Bianca', {
            'Striaton City': ('A gente pode lutar aqui? Vamos ver quem treinou mais!', 'Can we battle here? Let’s see who trained more!'),
            'Castelia City': ('Castelia é enorme! Me perdi duas vezes. Vamos lutar para eu me achar!', 'Castelia is huge! I got lost twice. Let’s battle so I can find myself!'),
            'Nimbasa City': ('Meu pai quer que eu volte para casa... Mas eu quero continuar! Lute comigo!', 'My dad wants me to go home... But I want to keep going! Battle me!'),
            'Mistralton City': ('Eu acho que sei o que eu quero: ajudar a pesquisar Pokémon! Vamos!', 'I think I know what I want: to help research Pokémon! Let’s go!'),
            'Icirrus City': ('Que frio! Mas eu estou mais forte, você vai ver!', 'So cold! But I’m stronger now, you’ll see!'),
        }, 'Você é demais! Eu vou continuar descobrindo o meu caminho.', 'You’re amazing! I’ll keep finding my own way.'),
        **rival('Cheren', {
            'Striaton City': ('Uma batalha de verdade, longe do seu quarto. Vamos.', 'A real battle, away from your room. Let’s go.'),
            'Nacrene City': ('Eu quero ser Campeão. Para isso, preciso vencer você.', 'I want to be Champion. For that, I need to beat you.'),
            'Castelia City': ('O que é ser forte? Ainda estou procurando a resposta.', 'What does it mean to be strong? I’m still looking for the answer.'),
            'Nimbasa City': ('A Plasma diz que somos cruéis com os Pokémon. Eu quero provar que não.', 'Plasma says we’re cruel to Pokémon. I want to prove we’re not.'),
            'Mistralton City': ('Eu treinei todos os dias. Vamos ver se foi suficiente.', 'I trained every day. Let’s see if it was enough.'),
            'Icirrus City': ('Ser Campeão não é tudo. Mas ainda quero vencer você.', 'Being Champion isn’t everything. But I still want to beat you.'),
            'Opelucid City': ('N está com o dragão. A gente precisa estar pronto. Mostre o que você tem.', 'N has the dragon. We need to be ready. Show me what you’ve got.'),
        }, 'Você é forte. Eu ainda estou aprendendo o que isso significa.', 'You’re strong. I’m still learning what that means.'),
        'Cilan@Striaton City': B([L('Cilan', 'Bem-vindo ao restaurante! Hoje o cardápio é uma batalha!', 'Welcome to the restaurant! Today’s menu is a battle!')], [L('Cilan', 'Que sabor de vitória! A Trio Badge é sua.', 'What a taste of victory! The Trio Badge is yours.')]),
        'N@Nacrene City': B([L('N', 'Eu quero ouvir mais as vozes dos Pokémon. Mostre-me os seus de novo.', 'I want to hear more of the Pokémon’s voices. Show me yours again.')], [L('N', 'Eles continuam dizendo que gostam de você... Por quê?', 'They keep saying they like you... Why?')]),
        'Lenora@Nacrene City': B([L('Lenora', 'Vamos ver se sua estratégia é boa. Eu analiso tudo!', 'Let’s see if your strategy is good. I analyze everything!')], [L('Lenora', 'Ótima análise! A Basic Badge é sua.', 'Great analysis! The Basic Badge is yours.')]),
        'Burgh@Castelia City': B([L('Burgh', 'Meus insetos são obras de arte. Você vai ver o que é beleza!', 'My bugs are works of art. You’ll see what beauty is!')], [L('Burgh', 'Que inspiração! A Insect Badge é sua.', 'What inspiration! The Insect Badge is yours.')]),
        'N@Nimbasa City': B([L('N', 'Eu sou o rei da Equipe Plasma. Vou libertar todos os Pokémon.', 'I am Team Plasma’s king. I will liberate all Pokémon.')], [L('N', 'Eu vou buscar o Pokémon lendário. Então todos vão me ouvir.', 'I will find the legendary Pokémon. Then everyone will listen to me.')]),
        'Elesa@Nimbasa City': B([L('Elesa', 'Meus Pokémon elétricos são a minha passarela!', 'My Electric Pokémon are my runway!')], [L('Elesa', 'Que brilho! A Bolt Badge é sua.', 'What a shine! The Bolt Badge is yours.')]),
        'N@Driftveil City': B([L('N', 'Os Pokémon sofrem com os humanos. Eu vou separar os dois mundos.', 'Pokémon suffer because of humans. I will separate the two worlds.')], [L('N', 'Por que eles lutam por você com tanta vontade?', 'Why do they fight for you so willingly?')]),
        'Ghetsis@Driftveil City': B([L('Ghetsis', 'O povo de Unova vai libertar os Pokémon. É só uma questão de tempo.', 'The people of Unova will liberate their Pokémon. It’s only a matter of time.')], [L('Ghetsis', 'Hehehe. Isso não muda nada.', 'Heh heh. This changes nothing.')]),
        'Clay@Driftveil City': B([L('Clay', 'A Plasma está roubando os Pokémon da minha cidade. Aquilo não pode ficar assim!', 'Plasma is stealing my city’s Pokémon. That can’t stand!')], [L('Clay', 'Você é dos bons! Leve a Quake Badge.', 'You’re one of the good ones! Take the Quake Badge.')]),
        'N@Mistralton City': B([L('N', 'A Dragonspiral Tower me espera. O dragão das lendas vai me escolher.', 'Dragonspiral Tower awaits me. The dragon of legend will choose me.')], [L('N', 'Mesmo assim, eu vou até lá.', 'Even so, I will go there.')]),
        'Skyla@Mistralton City': B([L('Skyla', 'Vamos subir! O céu é o meu ginásio!', 'Let’s fly! The sky is my Gym!')], [L('Skyla', 'Que voo! A Jet Badge é sua.', 'What a flight! The Jet Badge is yours.')]),
        'Brycen@Icirrus City': B([L('Brycen', 'Eu deixei as câmeras para lutar de verdade. Vamos!', 'I left the cameras to battle for real. Let’s go!')], [L('Brycen', 'Corta! Que cena. A Freeze Badge é sua.', 'Cut! What a scene. The Freeze Badge is yours.')]),
        'N@Opelucid City': B([L('N', 'O dragão está comigo. Agora vá encontrar o outro. Só então a verdade vai aparecer.', 'The dragon is with me. Now go find the other one. Only then will the truth appear.')], [L('N', 'Te espero na Liga.', 'I’ll wait for you at the League.')]),
        'Drayden@Opelucid City': B([L('Drayden', 'Eu sou o prefeito. Para mim, Pokémon e pessoas devem ser iguais.', 'I am the mayor. To me, Pokémon and people should be equals.')], [L('Drayden', 'Você vive isso. A Legend Badge é sua.', 'You live it. The Legend Badge is yours.')]),
        **ELITE_UNOVA,
        'Alder@Pokémon League': B([L('Alder', 'Eu viajei pelo mundo para entender o que importa. N me venceu... e você? Vamos lutar!', 'I traveled the world to understand what matters. N beat me... and you? Let’s battle!')],
                                  [L('', 'Um castelo gigante saiu da terra. N esperava com o dragão, e a sua pedra brilhou: o outro dragão apareceu ao seu lado. N perdeu.', 'A giant castle rose from the earth. N waited with the dragon, and your stone glowed: the other dragon appeared at your side. N lost.'),
                                   L('Ghetsis', 'Inútil! N, você não é meu filho. É só uma ferramenta!', 'Useless! N, you are not my son. You are just a tool!'),
                                   L('N', 'Os Pokémon gostam de vocês. Eu estava errado. Vou procurar o meu caminho.', 'Pokémon like you all. I was wrong. I’ll find my own path.')]),
        'Cynthia@Pokémon League': B([L('Cynthia', 'Numa casa de verão em Undella, a Campeã de Sinnoh queria ver você lutar. Vamos?', 'At a summer house in Undella, Sinnoh’s Champion wanted to see you battle. Shall we?')], [L('Cynthia', 'Maravilhoso. Você é forte de verdade.', 'Wonderful. You’re truly strong.')]),
    },
}

BLACK2 = {
    'intro': 'Dois anos depois, em Aspertia City, Bianca, assistente da Professora Juniper, traz um Pokémon de presente. Seu vizinho Hugh procura o Purrloin que a Equipe Plasma roubou da irmã dele: "Nem que eu tenha que derrubar a Plasma inteira de novo."',
    'end': 'Ghetsis caiu, o Liepard da irmã de Hugh voltou para casa, e Iris reconheceu você como Campeão de Unova. Um barco leva você para outra região.',
    'cities': {
        'Virbank City': [L('', 'A Equipe Plasma se dividiu: uma parte segue N e cuida de Pokémon abandonados; a outra, de preto, ainda quer dominar Unova.', 'Team Plasma split: one side follows N and looks after abandoned Pokémon; the other, in black, still wants to rule Unova.')],
        'Opelucid City': [L('', 'O Plasma Frigate, o navio voador da Plasma, congelou Opelucid.', 'The Plasma Frigate, Plasma’s flying ship, froze Opelucid.')],
        'Pokémon League': [
            L('N', 'Ghetsis, pare! Os Pokémon não são ferramentas!', 'Ghetsis, stop! Pokémon are not tools!'),
            L('', 'No Giant Chasm, Ghetsis fundiu Kyurem com o dragão. Você venceu, e o Liepard da irmã de Hugh foi devolvido.', 'In the Giant Chasm, Ghetsis fused Kyurem with the dragon. You won, and Hugh’s sister’s Liepard was returned.'),
        ],
    },
    'bosses': {
        **rival('Hugh', {
            'Aspertia City': ('Eu vou achar aquele Pokémon. Mas primeiro, vamos ver quem é mais forte!', 'I’ll find that Pokémon. But first, let’s see who’s stronger!'),
            'Virbank City': ('Você viu alguém da Plasma por aqui? Depois da batalha a gente procura!', 'Have you seen anyone from Plasma around here? We’ll search after the battle!'),
            'Castelia City': ('A Plasma está em Castelia! Mostra que você está pronto!', 'Plasma is in Castelia! Show me you’re ready!'),
            'Nimbasa City': ('Cada vitória me deixa mais perto do Purrloin. Vamos!', 'Every win brings me closer to the Purrloin. Let’s go!'),
            'Driftveil City': ('Ghetsis voltou. Eu sinto isso. Lute comigo!', 'Ghetsis is back. I can feel it. Battle me!'),
            'Mistralton City': ('O navio da Plasma passou por aqui! Rápido, uma batalha!', 'The Plasma ship flew by here! Quick, a battle!'),
            'Opelucid City': ('Opelucid está congelada! A gente tem que ser mais forte que o frio!', 'Opelucid is frozen! We have to be stronger than the cold!'),
            'Humilau City': ('Falta pouco para a Liga. Uma última luta antes!', 'The League is almost here. One last battle before it!'),
        }, 'Você é forte demais! Vamos acabar com a Plasma juntos.', 'You’re way too strong! Let’s finish off Plasma together.'),
        'Cheren@Aspertia City': B([L('Cheren', 'Eu também comecei com o primeiro passo. Agora, você.', 'I also started with a first step. Now it’s your turn.')], [L('Cheren', 'Você vai longe. A Basic Badge é sua.', 'You’ll go far. The Basic Badge is yours.')]),
        'Roxie@Virbank City': B([L('Roxie', 'Vamos fazer barulho!', 'Let’s make some noise!')], [L('Roxie', 'Que show! A Toxic Badge é sua.', 'What a show! The Toxic Badge is yours.')]),
        'Burgh@Castelia City': B([L('Burgh', 'Meus insetos ficaram ainda mais bonitos. Vamos criar arte juntos!', 'My bugs got even more beautiful. Let’s make art together!')], [L('Burgh', 'Uma obra-prima! A Insect Badge é sua.', 'A masterpiece! The Insect Badge is yours.')]),
        'Elesa@Nimbasa City': B([L('Elesa', 'A passarela está pronta. Brilhe comigo!', 'The runway is ready. Shine with me!')], [L('Elesa', 'Você brilhou mais. A Bolt Badge é sua.', 'You shone brighter. The Bolt Badge is yours.')]),
        'Clay@Driftveil City': B([L('Clay', 'Driftveil tem um torneio novo, mas primeiro, eu!', 'Driftveil has a new tournament, but first, me!')], [L('Clay', 'Firme como a terra. A Quake Badge é sua.', 'Solid as the earth. The Quake Badge is yours.')]),
        'Skyla@Mistralton City': B([L('Skyla', 'Vamos subir! O céu é o meu ginásio!', 'Let’s fly! The sky is my Gym!')], [L('Skyla', 'A Jet Badge é sua!', 'The Jet Badge is yours!')]),
        'Drayden@Opelucid City': B([L('Drayden', 'Opelucid congelou, mas o fogo dos dragões continua aceso.', 'Opelucid froze, but the dragons’ fire still burns.')], [L('Drayden', 'A Legend Badge é sua.', 'The Legend Badge is yours.')]),
        'Marlon@Humilau City': B([L('Marlon', 'Eu sou forte como o mar.', 'I’m as strong as the sea.')], [L('Marlon', 'Que onda! A Wave Badge é sua.', 'What a wave! The Wave Badge is yours.')]),
        **{f'Zinzolin@{c}': B([L('Zinzolin', 'Ghetsis voltou. Com o frio do Kyurem, vamos congelar Unova inteira.', 'Ghetsis has returned. With Kyurem’s cold, we will freeze all of Unova.')], [L('Zinzolin', 'Brrr... Isso não acaba aqui.', 'Brrr... This isn’t over.')]) for c in ('Castelia City', 'Nimbasa City', 'Mistralton City', 'Opelucid City')},
        **{f'Colress@{c}': B([L('Colress', 'Minha pesquisa é sobre como tirar o máximo de um Pokémon. A Plasma me dá os meios. Só isso.', 'My research is about bringing out a Pokémon’s full potential. Plasma gives me the means. That’s all.')], [L('Colress', 'Fascinante! Seus Pokémon têm uma força que eu não medi.', 'Fascinating! Your Pokémon have a strength I didn’t measure.')]) for c in ('Nimbasa City', 'Mistralton City', 'Pokémon League')},
        'Ghetsis@Driftveil City': B([L('Ghetsis', 'Eu sou o único que pode governar Unova!', 'I am the only one who can rule Unova!')], [L('Ghetsis', 'Não... Eu sou...', 'No... I am...')]),
        **ELITE_UNOVA,
        'Iris@Pokémon League': B([L('Iris', 'Eu vou lutar com tudo, porque gosto muito de lutar com Pokémon fortes!', 'I’ll fight with everything, because I really love battling strong Pokémon!')], [L('Iris', 'Que batalha! Você é o Campeão de Unova!', 'What a battle! You are Unova’s Champion!')]),
        'N@Pokémon League': B([L('N', 'Os Pokémon e as pessoas... eu quero entender melhor. Lute comigo.', 'Pokémon and people... I want to understand them better. Battle me.')], [L('N', 'Obrigado. Agora eu entendo um pouco mais.', 'Thank you. Now I understand a little more.')]),
        'Benga@Pokémon League': B([L('Benga', 'Eu sou o neto do Alder! Vamos lutar, que eu gosto!', 'I’m Alder’s grandson! Let’s battle, I love it!')], [L('Benga', 'Hahaha! Que divertido!', 'Hahaha! That was fun!')]),
        'Alder@Pokémon League': B([L('Alder', 'No torneio mundial, todos lutam com o coração. Vamos!', 'At the world tournament, everyone fights with heart. Let’s go!')], [L('Alder', 'Esse é o espírito!', 'That’s the spirit!')]),
        'Cynthia@Pokémon League': B([L('Cynthia', 'O Pokémon World Tournament reúne os melhores. Mostre-me sua força.', 'The Pokémon World Tournament gathers the best. Show me your strength.')], [L('Cynthia', 'Maravilhoso.', 'Wonderful.')]),
    },
}

XY = {
    'intro': 'Você acabou de se mudar para Vaniville, em Kalos. Sua mãe é uma corredora famosa de Rhyhorn. Serena, a vizinha, chama você até Aquacorde Town, onde Shauna, Tierno e Trevor esperam com Chespin, Fennekin e Froakie.',
    'end': 'Lysandre caiu com a arma final, o Floette de AZ voltou para ele, e Diantha reconheceu você como Campeão de Kalos. Um barco leva você para outra região.',
    'cities': {
        'Cyllage City': [
            L('Lysandre', 'Eu sou Lysandre. Quero um mundo mais bonito. Não é estranho que haja tantas pessoas e tão pouco?', 'I am Lysandre. I want a more beautiful world. Isn’t it strange that there are so many people and so little?'),
        ],
        'Shalour City': [L('', 'Em Shalour, a Tower of Mastery guarda o segredo da Mega Evolução.', 'In Shalour, the Tower of Mastery holds the secret of Mega Evolution.')],
        'Coumarine City': [L('', 'Homens de terno vermelho com óculos escuros, a Equipe Flare, roubam energia e Pokémon por toda Kalos.', 'Men in red suits with dark glasses, Team Flare, are stealing energy and Pokémon all over Kalos.')],
        'Lumiose City': [L('', 'A Equipe Flare tomou a Power Plant de Lumiose, e Clemont ficou trancado no ginásio pelo próprio robô.', 'Team Flare took over Lumiose’s Power Plant, and Clemont got locked in his Gym by his own robot.')],
        'Anistar City': [
            L('Lysandre', 'Pessoas de Kalos. O mundo está ficando feio. Eu vou usar a arma final para limpar o mundo. Só os escolhidos vão sobreviver.', 'People of Kalos. The world is growing ugly. I will use the ultimate weapon to cleanse it. Only the chosen will survive.'),
        ],
        'Snowbelle City': [L('', 'Na base da Flare, embaixo de Geosenge, você acordou Xerneas (ou Yveltal) e venceu Lysandre. A arma final desmoronou.', 'In Flare’s base beneath Geosenge, you awoke Xerneas (or Yveltal) and beat Lysandre. The ultimate weapon collapsed.')],
    },
    'bosses': {
        **{f'{w}@Santalune City': B([L(w, a, b)], [L(w, c, d)]) for w, (a, b, c, d) in {
            'Shauna': ('Oi! Vamos ver de que jeito o nosso time combina!', 'Hi! Let’s see how our teams match up!', 'Que divertido! De novo depois!', 'That was fun! Again later!'),
            'Tierno': ('Os meus Pokémon dançam enquanto lutam. Olha só!', 'My Pokémon dance while they battle. Check it out!', 'Você dança bem também!', 'You dance well too!'),
            'Serena': ('Bem-vindo a Kalos! Vamos ver se você é bom de verdade.', 'Welcome to Kalos! Let’s see if you’re really good.', 'Você é bom mesmo!', 'You really are good!'),
            'Trevor': ('E-eu só quero completar a Pokédex... mas vamos lutar.', 'I-I just want to complete the Pokédex... but let’s battle.', 'Vou registrar essa batalha.', 'I’ll record this battle.'),
        }.items()},
        **rival('Serena', {
            'Shalour City': ('A Mega Evolução! Quero ver quem merece mais. Vamos!', 'Mega Evolution! I want to see who deserves it more. Let’s go!'),
            'Coumarine City': ('A Equipe Flare está por aí. Precisamos ficar fortes!', 'Team Flare is out there. We need to get strong!'),
            'Laverre City': ('Eu ainda não te alcancei. Vamos de novo!', 'I still haven’t caught up to you. Again!'),
            'Anistar City': ('Ouviu o Lysandre? A gente precisa impedir! Mas antes, mostre a sua força.', 'Did you hear Lysandre? We have to stop him! But first, show me your strength.'),
        }, 'Você continua na frente. Eu vou alcançar!', 'You’re still ahead. I’ll catch up!'),
        'Shauna@Lumiose City': B([L('Shauna', 'Lumiose é linda! Vamos comemorar com uma batalha!', 'Lumiose is beautiful! Let’s celebrate with a battle!')], [L('Shauna', 'Você é demais!', 'You’re amazing!')]),
        'Tierno@Lumiose City': B([L('Tierno', 'O meu time aprendeu passos novos!', 'My team learned new moves!')], [L('Tierno', 'Bela dança!', 'Nice dance!')]),
        'Viola@Santalune City': B([L('Viola', 'Vou capturar o momento da sua derrota em foto!', 'I’ll capture the moment of your defeat on camera!')], [L('Viola', 'Que foto! A Bug Badge é sua.', 'What a shot! The Bug Badge is yours.')]),
        'Grant@Cyllage City': B([L('Grant', 'As rochas são a minha muralha.', 'The rocks are my wall.')], [L('Grant', 'Você escalou a minha muralha. A Cliff Badge é sua.', 'You climbed my wall. The Cliff Badge is yours.')]),
        'Lysandre@Shalour City': B([L('Lysandre', 'Você tem potencial. Quero ver se ele serve para um mundo mais bonito.', 'You have potential. I want to see if it serves a more beautiful world.')], [L('Lysandre', 'Interessante. Nos veremos.', 'Interesting. We will meet again.')]),
        'Korrina@Shalour City': B([L('Korrina', 'Eu sou a herdeira da Mega Evolução. Vamos ver se você também é digno!', 'I am Mega Evolution’s heir. Let’s see if you’re worthy too!')], [L('Korrina', 'Você é digno! Leve a Rumble Badge e a Mega Ring.', 'You’re worthy! Take the Rumble Badge and the Mega Ring.')]),
        'Ramos@Coumarine City': B([L('Ramos', 'A gente cuida das plantas, e elas cuidam da gente.', 'We take care of the plants, and they take care of us.')], [L('Ramos', 'Você cresceu bem. A Plant Badge é sua.', 'You’ve grown well. The Plant Badge is yours.')]),
        'Clemont@Lumiose City': B([L('Clemont', 'Eu inventei um teste para os desafiantes! Mas... ele travou! Vamos lutar mesmo assim!', 'I invented a test for challengers! But... it jammed! Let’s battle anyway!')], [L('Clemont', 'O futuro é agora! A Voltage Badge é sua.', 'The future is now! The Voltage Badge is yours.')]),
        'Valerie@Laverre City': B([L('Valerie', 'As fadas dançam devagar... Venha ver.', 'Fairies dance slowly... Come and see.')], [L('Valerie', 'Que lindo. A Fairy Badge é sua.', 'How lovely. The Fairy Badge is yours.')]),
        'Olympia@Anistar City': B([L('Olympia', 'As estrelas me mostraram esta batalha.', 'The stars showed me this battle.')], [L('Olympia', 'O destino é seu. A Psychic Badge também.', 'Destiny is yours. The Psychic Badge too.')]),
        'Wulfric@Snowbelle City': B([L('Wulfric', 'Hahaha! Vamos esquentar esse gelo!', 'Hahaha! Let’s warm up this ice!')], [L('Wulfric', 'Que batalha quente! A Iceberg Badge é sua.', 'What a hot battle! The Iceberg Badge is yours.')]),
        **{f'{w}@{c}': B([L(w, a, b)], [L(w, 'A Equipe Flare não gosta de perder.', 'Team Flare doesn’t like to lose.')]) for (w, c), (a, b) in {
            ('Aliana', 'Coumarine City'): ('Energia para a Flare! Saia da frente.', 'Energy for Flare! Out of the way.'),
            ('Mable', 'Coumarine City'): ('A ciência da Flare é bonita. Você não entenderia.', 'Flare’s science is beautiful. You wouldn’t understand.'),
            ('Aliana', 'Laverre City'): ('De novo você? A Flare não esquece.', 'You again? Flare doesn’t forget.'),
            ('Mable', 'Laverre City'): ('Nós só queremos um mundo bonito.', 'We just want a beautiful world.'),
            ('Bryony', 'Lumiose City'): ('A Power Plant é nossa. Nossa energia, nosso mundo.', 'The Power Plant is ours. Our energy, our world.'),
            ('Celosia', 'Lumiose City'): ('Lindo, não? O vermelho da Flare.', 'Beautiful, isn’t it? Flare red.'),
            ('Xerosic', 'Lumiose City'): ('A ciência não tem lado. Mas eu tenho o meu.', 'Science takes no sides. But I have mine.'),
        }.items()},
        'Lysandre@Lumiose City': B([L('Lysandre', 'Kalos merece um futuro bonito. Por que você insiste em atrapalhar?', 'Kalos deserves a beautiful future. Why do you insist on interfering?')], [L('Lysandre', 'Você vai entender, um dia.', 'You will understand, one day.')]),
        'Lysandre@Anistar City': B([L('Lysandre', 'Por que você não entende? Eu só queria um mundo bonito!', 'Why don’t you understand? I only wanted a beautiful world!')], [L('Lysandre', 'O mundo... vai continuar feio...', 'The world... will remain ugly...')]),
        'Malva@Pokémon League': B([L('Malva', 'Repórter de dia, chama à noite. Vou queimar você ao vivo!', 'Reporter by day, flame by night. I’ll burn you live on air!')], [L('Malva', 'Você venceu. Que matéria.', 'You won. What a story.')]),
        'Wikstrom@Pokémon League': B([L('Wikstrom', 'Um cavaleiro de aço não recua. En garde!', 'A knight of steel never retreats. En garde!')], [L('Wikstrom', 'Honra a você. Siga.', 'Honor to you. Go on.')]),
        'Drasna@Pokémon League': B([L('Drasna', 'Ah, que gracinha. Meus dragões vão adorar brincar com você!', 'Oh, how cute. My dragons will love playing with you!')], [L('Drasna', 'Que delícia de batalha!', 'What a delightful battle!')]),
        'Siebold@Pokémon League': B([L('Siebold', 'Uma batalha é como um prato: precisa de equilíbrio.', 'A battle is like a dish: it needs balance.')], [L('Siebold', 'Um prato perfeito.', 'A perfect dish.')]),
        'Diantha@Pokémon League': B([L('Diantha', 'Eu sou atriz. Às vezes, eu não sei quem sou. Mas na batalha, sou eu de verdade.', 'I’m an actress. Sometimes I don’t know who I am. But in battle, I’m truly myself.')], [L('Diantha', 'Que performance! Você é o Campeão de Kalos.', 'What a performance! You are Kalos’s Champion.')]),
        'AZ@Pokémon League': B([L('AZ', 'Por 3.000 anos, eu procurei o meu Floette. Me mostre o que é a força de quem ama seus Pokémon.', 'For 3,000 years, I searched for my Floette. Show me the strength of one who loves their Pokémon.')],
                               [L('AZ', 'Você voltou... Floette...', 'You came back... Floette...')]),
    },
}

GAMES = {
    'Unova|Black/White': BLACK_WHITE,
    'Unova|Black 2/White 2': BLACK2,
    'Kalos|X/Y': XY,
}
