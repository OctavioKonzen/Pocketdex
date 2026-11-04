"""Sons da batalha, sintetizados aqui (nada copiado de jogo): efeitos no
estilo 8-bit, uma música de batalha chiptune original em loop e um tema
original para cada região (líderes, Elite Four e kahunas) e cada campeão.

Saída: assets/database/sounds/<nome>.mp3 (o site copia com o resto do banco).

Uso: pip install lameenc numpy && python3 tool/build_battle_sounds.py [nomes]
"""

import os
import sys

import subprocess

import lameenc
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'database', 'sounds')
RATE = 22050


def freq(note):
    """Nota MIDI → Hz."""
    return 440.0 * 2 ** ((note - 69) / 12)


def t(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def pulse(f, seconds, duty=0.5, phase0=0.0):
    """Onda quadrada (com f podendo variar no tempo)."""
    f = np.broadcast_to(np.asarray(f, dtype=float), (int(RATE * seconds),))
    phase = (phase0 + np.cumsum(f) / RATE) % 1.0
    return np.where(phase < duty, 1.0, -1.0)


def triangle(f, seconds):
    f = np.broadcast_to(np.asarray(f, dtype=float), (int(RATE * seconds),))
    phase = np.cumsum(f) / RATE % 1.0
    return 4 * np.abs(phase - 0.5) - 1


def noise(seconds, seed=1, step=1):
    """Ruído como o do NES: um valor novo a cada `step` amostras (mais grave com step maior)."""
    rng = np.random.default_rng(seed)
    n = int(RATE * seconds)
    values = rng.uniform(-1, 1, n // step + 1)
    return np.repeat(values, step)[:n]


def env(n, attack=0.005, release=0.05, total=None):
    """Envelope simples: sobe rápido, segura e cai no fim."""
    total = total or n / RATE
    e = np.ones(n)
    a = max(1, int(RATE * attack))
    r = max(1, int(RATE * release))
    e[:a] = np.linspace(0, 1, a)
    e[-r:] *= np.linspace(1, 0, r)
    return e


def decay(n, k):
    return np.exp(-np.arange(n) / RATE * k)


def seq(parts):
    return np.concatenate(parts)


def save_loop(name, signal, bitrate=64):
    """Uma música em loop: OGG Vorbis (sem o silêncio que o MP3 põe no começo e no fim, que vira um
    buraco a cada volta), com ANDROID_LOOP (o Android emenda o loop sem nenhum corte). E uma reserva em
    MP3 em sounds/web/, só para o site, nos navegadores sem OGG (o app não leva subpastas)."""
    signal = np.clip(signal, -1, 1)
    pcm = (signal * 32767 * 0.9).astype(np.int16)
    path = os.path.join(OUT, f'{name}.ogg')
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 's16le', '-ar', str(RATE), '-ac', '1', '-i', '-',
                    '-c:a', 'libvorbis', '-q:a', '3', '-fflags', '+bitexact', '-map_metadata', '-1',
                    '-metadata', 'ANDROID_LOOP=true', path], input=pcm.tobytes(), check=True)
    os.makedirs(os.path.join(OUT, 'web'), exist_ok=True)
    old = os.path.join(OUT, f'{name}.mp3')
    if os.path.exists(old):
        os.remove(old)  # a versão antiga em MP3 (agora a reserva fica em web/)
    save(os.path.join('web', name), signal, bitrate)
    return os.path.getsize(path)


def save(name, signal, bitrate=64):
    signal = np.clip(signal, -1, 1)
    pcm = (signal * 32767 * 0.9).astype(np.int16)
    enc = lameenc.Encoder()
    enc.set_bit_rate(bitrate)
    enc.set_in_sample_rate(RATE)
    enc.set_channels(1)
    enc.set_quality(2)
    data = enc.encode(pcm.tobytes()) + enc.flush()
    with open(os.path.join(OUT, f'{name}.mp3'), 'wb') as f:
        f.write(data)
    return len(data)


# ------------------------------------------------------------------ efeitos

def sfx_hit():
    n = int(RATE * 0.18)
    body = pulse(np.linspace(180, 60, n), 0.18, 0.5) * decay(n, 22) * 0.6
    crack = noise(0.18, 3, 2) * decay(n, 35) * 0.8
    return body + crack


def sfx_super():
    a = sfx_hit()
    n = int(RATE * 0.22)
    zap = pulse(np.linspace(900, 200, n), 0.22, 0.25) * decay(n, 14) * 0.5 + noise(0.22, 5, 1) * decay(n, 18) * 0.6
    return seq([a * 1.1, zap])


def sfx_weak():
    n = int(RATE * 0.14)
    return triangle(np.linspace(150, 70, n), 0.14) * decay(n, 25) * 0.7 + noise(0.14, 7, 6) * decay(n, 40) * 0.3


def sfx_faint():
    n = int(RATE * 0.8)
    f = np.geomspace(700, 90, n)
    return pulse(f, 0.8, 0.5) * env(n, 0.005, 0.15) * 0.45


def sfx_throw():
    n = int(RATE * 0.38)
    whoosh = noise(0.38, 9, 1)
    # Filtro passa-baixa que vai abrindo: o vento da Poké Ball.
    k = np.linspace(0.02, 0.5, n)
    out = np.zeros(n)
    y = 0.0
    for i in range(n):
        y += k[i] * (whoosh[i] - y)
        out[i] = y
    return out * np.sin(np.linspace(0, np.pi, n)) * 1.6


def sfx_open():
    notes = [72, 79, 84, 91]
    parts = [pulse(freq(m), 0.045, 0.25) * 0.4 for m in notes]
    pop = noise(0.12, 11, 1) * decay(int(RATE * 0.12), 30) * 0.5
    return seq(parts + [pop])


def sfx_recall():
    n = int(RATE * 0.35)
    return pulse(np.geomspace(1200, 200, n), 0.35, 0.125) * decay(n, 6) * 0.4


def arpeggio(notes, step=0.06, duty=0.25, vol=0.4):
    return seq([pulse(freq(m), step, duty) * env(int(RATE * step), 0.002, 0.01) * vol for m in notes])


def sfx_statup():
    return arpeggio([60, 64, 67, 72, 76, 79, 84])


def sfx_statdown():
    return arpeggio([84, 79, 76, 72, 67, 64, 60])


def sfx_heal():
    parts = []
    for m in [76, 81, 88, 81, 88, 93]:
        s = triangle(freq(m), 0.08) * env(int(RATE * 0.08), 0.002, 0.03) * 0.6
        parts.append(s)
    return seq(parts)


def sfx_shiny():
    """Brilho do shiny (original): estrelinhas descendo rápidas e um cintilar no fim."""
    stars = []
    for i, m in enumerate([96, 100, 103, 108, 103, 108, 112]):
        n = int(RATE * 0.045)
        stars.append(triangle(freq(m), 0.045) * decay(n, 6) * (0.55 - i * 0.03))
    shimmer = (pulse(freq(108), 0.25, 0.125) + 0.5 * noise(0.25, seed=7, step=2)) * decay(int(RATE * 0.25), 4) * 0.18
    return seq(stars + [shimmer])


def sfx_select():
    return pulse(freq(84), 0.05, 0.25) * env(int(RATE * 0.05), 0.001, 0.02) * 0.35


def sfx_victory():
    """Fanfarra curta (original): sobe em Dó maior e termina num acorde."""
    beat = 0.14
    melody = [(72, 1), (72, 1), (72, 1), (72, 3), (68, 3), (70, 3), (72, 2), (70, 1), (72, 6)]
    lead = seq([pulse(freq(m), beat * d, 0.25) * env(int(RATE * beat * d), 0.003, 0.03) * 0.35 for m, d in melody])
    bass_notes = [(48, 6), (44, 3), (46, 3), (48, 9)]
    bass = seq([triangle(freq(m), beat * d) * env(int(RATE * beat * d), 0.003, 0.03) * 0.5 for m, d in bass_notes])
    n = max(len(lead), len(bass))
    out = np.zeros(n)
    out[: len(lead)] += lead
    out[: len(bass)] += bass
    return out


# ------------------------------------------------------------------ música

BPM = 152
STEP = 60 / BPM / 2  # colcheia

# Melodia original (colcheias; 0 = pausa): Mi menor, i–VI–VII–V.
LEAD = [
    64, 67, 71, 72, 71, 67, 64, 0, 76, 0, 74, 72, 71, 0, 67, 69,
    72, 0, 71, 69, 67, 0, 64, 67, 72, 74, 76, 0, 74, 72, 71, 0,
    74, 0, 72, 71, 69, 0, 66, 69, 74, 76, 78, 0, 76, 74, 72, 0,
    71, 0, 75, 78, 75, 0, 71, 0, 78, 76, 75, 73, 71, 0, 0, 0,
    76, 79, 83, 0, 81, 79, 76, 0, 79, 0, 78, 76, 74, 0, 71, 74,
    76, 0, 74, 72, 71, 0, 67, 72, 76, 0, 79, 0, 76, 74, 72, 0,
    74, 78, 81, 0, 78, 74, 69, 0, 78, 0, 76, 74, 72, 0, 69, 72,
    75, 0, 78, 0, 83, 0, 78, 75, 71, 0, 75, 0, 78, 0, 0, 0,
]
# Um acorde a cada 2 compassos (16 colcheias).
CHORDS = [(40, [64, 67, 71]), (36, [60, 64, 67]), (38, [62, 66, 69]), (35, [59, 63, 66])] * 2


def piano(f, seconds):
    """Timbre de piano simples: seno com harmônicos, ataque rápido e queda longa."""
    x = t(seconds)
    wave = np.sin(2 * np.pi * f * x) + 0.4 * np.sin(4 * np.pi * f * x) + 0.15 * np.sin(6 * np.pi * f * x)
    return wave / 1.55 * decay(len(x), 3.5)


def grand(f, seconds, vel=1.0):
    """Piano de cauda sintetizado: harmônicos levemente desafinados (cordas reais), duas cordas
    por nota (o batimento), queda em duas fases (os agudos somem antes) e a batida do martelo."""
    x = t(seconds)
    n = len(x)
    out = np.zeros(n)
    inharm = 0.0004
    for k in range(1, 11):
        fk = f * k * np.sqrt(1 + inharm * k * k)
        if fk > RATE / 2.2:
            break
        amp = k ** -1.15 * vel ** (0.4 + 0.12 * k)  # mais forte = mais brilhante
        fast, slow = 0.18 / (1 + 0.35 * k), (1.6 + 120 / f) / (1 + 0.25 * k)
        shape = 0.55 * np.exp(-x / fast) + 0.45 * np.exp(-x / slow)
        for cents in (-0.9, 0.9):
            out += 0.5 * amp * shape * np.sin(2 * np.pi * fk * 2 ** (cents / 1200) * x + k * 0.7)
    m = min(n, int(RATE * 0.015))
    hammer = np.random.default_rng(int(f * 10)).standard_normal(m) * np.exp(-np.linspace(0, 7, m))
    out[:m] += np.convolve(hammer, np.ones(6) / 6, 'same') * 0.06 * vel
    return out * env(n, 0.002, 0.04) / 2.0


def flute(f, seconds):
    """Flauta: quase seno (um pouco do 2º harmônico), sopro suave no começo e vibrato depois."""
    x = t(seconds)
    n = len(x)
    wobble = 1 + 0.004 * np.sin(2 * np.pi * 5 * x) * np.clip((x - 0.15) / 0.15, 0, 1)
    phase = 2 * np.pi * np.cumsum(f * wobble) / RATE
    tone = np.sin(phase) + 0.12 * np.sin(2 * phase) + 0.04 * np.sin(3 * phase)
    breath = np.convolve(np.random.default_rng(int(f)).standard_normal(n), np.ones(12) / 12, 'same')
    return (tone + breath * 0.25 * np.exp(-x * 8)) * env(n, 0.04, 0.08) / 1.2


def pluck(f, seconds, bright=0.5):
    """Corda dedilhada (Karplus-Strong): violão ou koto."""
    n = int(RATE * seconds)
    period = max(2, int(RATE / f))
    buf = np.random.default_rng(int(f * 7)).uniform(-1, 1, period)
    out = np.zeros(n)
    keep = 0.996 - (1 - bright) * 0.006
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = keep * 0.5 * (buf[i % period] + buf[(i + 1) % period])
    return out * env(n, 0.001, 0.05)


def saw(f, seconds, detune=0.0):
    """Onda dente de serra (com f podendo variar), com uma segunda levemente desafinada (coro)."""
    n = int(RATE * seconds)
    f = np.broadcast_to(np.asarray(f, dtype=float), (n,))
    out = 2 * (np.cumsum(f) / RATE % 1.0) - 1
    if detune:
        out = 0.5 * out + 0.5 * (2 * (np.cumsum(f * 2 ** (detune / 1200)) / RATE % 1.0) - 1)
    return out


def smooth(sig, width):
    """Filtro passa-baixa simples (média móvel): mais largo, mais escuro."""
    return np.convolve(sig, np.ones(width) / width, 'same') if width > 1 else sig


def brass(f, seconds):
    """Metais (trompa/trombone): dente de serra com coro, abrindo o brilho na entrada da nota."""
    n = int(RATE * seconds)
    x = t(seconds)
    raw = saw(f, seconds, 9)
    dark, bright = smooth(raw, 14), smooth(raw, 4)
    opening = np.clip(x / 0.12, 0, 1)
    return (dark * (1 - opening * 0.6) + bright * opening * 0.6) * env(n, 0.05, 0.08)


def drum(seconds, hi=90, lo=38, seed=5, body=0.9):
    """Tímpano/taiko: seno grave que cai de altura, com o ruído da pele."""
    n = int(RATE * seconds)
    x = t(seconds)
    f = lo + (hi - lo) * np.exp(-x * 18)
    skin = smooth(np.random.default_rng(seed).standard_normal(n), 10) * np.exp(-x * 40) * 0.5
    return (np.sin(2 * np.pi * np.cumsum(f) / RATE) * body + skin) * np.exp(-x * 5)


def reed(f, seconds):
    """Acordeão/palheta: duas ondas de pulso levemente desafinadas, filtradas, com tremolo."""
    n = int(RATE * seconds)
    x = t(seconds)
    raw = 0.55 * pulse(f, seconds, 0.3) + 0.45 * pulse(f * 2 ** (6 / 1200), seconds, 0.45)
    return smooth(raw, 5) * (1 + 0.18 * np.sin(2 * np.pi * 6 * x)) * env(n, 0.02, 0.05) / 1.2


def snare(seconds, seed=11):
    """Caixa: ruído com o corpo de um tom curto."""
    n = int(RATE * seconds)
    x = t(seconds)
    rattle = np.random.default_rng(seed).standard_normal(n)
    return ((rattle - smooth(rattle, 4)) * 0.8 + np.sin(2 * np.pi * 190 * x) * 0.5) * np.exp(-x * 22)


def wobble_bass(f0, f1, seconds, rate_hz):
    """Baixo ondulado: dente de serra que escorrega de f0 para f1, com o filtro abrindo e fechando (wob)."""
    n = int(RATE * seconds)
    x = t(seconds)
    f = f1 + (f0 - f1) * np.exp(-x * 25)
    raw = saw(f, seconds, 12)
    lfo = 0.5 - 0.5 * np.cos(2 * np.pi * rate_hz * x)
    dark, bright = smooth(raw, 40), smooth(raw, 6)
    return (dark * (1 - lfo) + bright * lfo) * env(n, 0.004, 0.03)


def synth_lead(f, seconds):
    """Sintetizador brilhante da melodia (duas serras e um pulso), com vibrato leve."""
    n = int(RATE * seconds)
    x = t(seconds)
    wob = 1 + 0.004 * np.sin(2 * np.pi * 6 * x) * np.clip((x - 0.1) / 0.1, 0, 1)
    raw = saw(f * wob, seconds, 14) * 0.7 + pulse(f * wob * 2, seconds, 0.25) * 0.15
    return smooth(raw, 3) * env(n, 0.006, 0.05)


def violin(f, seconds):
    """Violino: dente de serra filtrado, entrando devagar (arco) e com vibrato."""
    n = int(RATE * seconds)
    x = t(seconds)
    wob = 1 + 0.005 * np.sin(2 * np.pi * 5.5 * x) * np.clip((x - 0.12) / 0.15, 0, 1)
    return smooth(saw(f * wob, seconds, 8), 7) * env(n, 0.08, 0.1)


def steel(f_from, f, seconds):
    """Guitarra havaiana (lap steel): desliza da nota anterior até a nota, com vibrato largo e corpo redondo."""
    n = int(RATE * seconds)
    x = t(seconds)
    glide = f + (f_from - f) * np.exp(-x * 22)
    wob = 1 + 0.007 * np.sin(2 * np.pi * 5 * x) * np.clip((x - 0.15) / 0.2, 0, 1)
    phase = 2 * np.pi * np.cumsum(glide * wob) / RATE
    tone = np.sin(phase) + 0.45 * np.sin(2 * phase) + 0.2 * np.sin(3 * phase) + 0.08 * np.sin(4 * phase)
    return tone * (0.35 + 0.65 * np.exp(-x * 1.8)) * env(n, 0.01, 0.08) / 1.7


def power_chord(root_f, seconds, muted=False):
    """Guitarra distorcida: raiz, quinta e oitava (power chord); abafada fica curta e mais escura."""
    n = int(RATE * seconds)
    x = t(seconds)
    raw = saw(root_f, seconds, 10) + saw(root_f * 1.5, seconds, -8) * 0.8 + saw(root_f * 2, seconds, 6) * 0.5
    dist = np.tanh(smooth(raw, 5 if muted else 3) * 4)
    tail = np.exp(-x * (18 if muted else 1.5))
    return smooth(dist, 4 if muted else 2) * tail * env(n, 0.002, 0.03) * 0.5


def bell(f, seconds, bright=1.0):
    """Sino/glockenspiel: parciais de sino (inarmônicos) que somem rápido, os agudos antes."""
    n = int(RATE * seconds)
    x = t(seconds)
    out = np.zeros(n)
    for ratio, amp, k in ((1, 1, 1.2), (2.76, 0.45 * bright, 3), (5.4, 0.25 * bright, 6), (8.93, 0.12 * bright, 10)):
        if f * ratio < RATE / 2.2:
            out += amp * np.sin(2 * np.pi * f * ratio * x) * np.exp(-x * k)
    return out * env(n, 0.001, 0.05) / 1.8


def choir(f, seconds):
    """Coro ("aah"): várias vozes levemente desafinadas, bem filtradas, entrando devagar."""
    n = int(RATE * seconds)
    x = t(seconds)
    out = np.zeros(n)
    for j, cents in enumerate((-12, -5, 0, 6, 13)):
        wob = 1 + 0.003 * np.sin(2 * np.pi * (4.5 + j * 0.3) * x + j)
        out += saw(f * 2 ** (cents / 1200) * wob, seconds)
    # Formantes de "a": realça a região de 700 Hz e 1200 Hz (média de dois filtros) e corta o resto.
    voiced = smooth(out, int(RATE / 1400)) - smooth(out, int(RATE / 500))
    return (voiced * 0.8 + smooth(out, 20) * 0.4) * env(n, 0.35, 0.4) / 5


def gong(seconds, seed=500):
    """Gongo: parciais graves inarmônicos que tremem e somem devagar, com o estrondo do começo."""
    n = int(RATE * seconds)
    x = t(seconds)
    out = np.zeros(n)
    for ratio, amp in ((1, 1), (1.47, 0.7), (2.09, 0.5), (2.56, 0.4), (3.39, 0.3), (4.17, 0.2)):
        f = 70 * ratio * (1 + 0.01 * np.exp(-x * 2))
        out += amp * np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-x * (0.6 + ratio * 0.3))
    crash = np.random.default_rng(seed).standard_normal(n)
    return (out / 3 + (crash - smooth(crash, 4)) * np.exp(-x * 3) * 0.3) * env(n, 0.003, 0.3)


def room(sig, step_s):
    """Eco de sala (com o pedal), dando a volta no fim para o loop continuar sem emenda."""
    out = sig.copy()
    for delay, gain in ((0.031, 0.32), (0.067, 0.24), (0.113, 0.18), (0.171, 0.12), (0.241, 0.08)):
        out += np.roll(sig, int(RATE * delay)) * gain
    return out


def music(lead=None, chords=None, bpm=BPM, duty=0.25, voice='pulse', drive=False, soft=False, swing=0.0, solo=False, fine=False, nostalgia=False, humble=False, epic=False, weather=True, giant=False, harbor=False, club=False, french=False, island=False, anime=False, school=False):
    """Uma música em loop. voice: 'pulse' (chiptune, com `duty`) ou 'piano'; drive: bumbo em todo tempo;
    soft: bateria leve (bumbo só no 1º tempo, sem caixa), para andar no mapa;
    swing: balanço (shuffle), a 2ª colcheia de cada tempo atrasa essa fração de uma colcheia;
    solo: só piano de cauda (grand), em clima de suspense, sem bateria e com eco de sala;
    fine: a melodia de piano no piano de cauda (as músicas do mapa);
    nostalgia: Game Boy de lembrança (vibrato e eco na melodia, acordes macios de piano por baixo,
    som mais quente e eco de sala);
    humble: personagem secundário (flauta na melodia, cordas dedilhadas, baixo dedilhado, só um chocalho);
    epic: batalha lendária (metais, cordas em ostinato, tambores de guerra, chuva, trovão e terra roncando;
    weather False: sem a chuva, o trovão e a terra; giant: orquestra gigante, com a melodia em três
    oitavas, coro, cordas em trêmulo e gongo);
    harbor: banda de cidade portuária com balanço (acordeão, baixo saltitante, metais nos contratempos, bateria);
    club: porto à noite, clima de boate (baixo ondulado, bumbo em todo tempo, melodia em espiral);
    french: café francês que evolui (o dobro do tamanho, em 4 partes: acordeão e violão; + contrabaixo e
    vassourinha; + violino e cordas; + harpa e um tom acima);
    island: praia havaiana (guitarra havaiana deslizando, ukulele, baixo macio, chocalho e ipu, ondas do mar);
    anime: abertura de anime de futebol (guitarra distorcida, bateria de rock, apito, torcida e palmas);
    school: escola de anime (sinal da escola, flauta doce e glockenspiel, piano, pizzicato, bateria leve)."""
    lead = lead or LEAD
    chords = chords or CHORDS
    if french:  # o dobro do tamanho, para evoluir em 4 partes; a última um tom acima
        lead, chords = lead * 2, chords * 2
        quarter = len(chords) * 3 // 4
        lead = [m + 2 if m and i >= len(lead) * 3 // 4 else m for i, m in enumerate(lead)]
        chords = [(r + 2, [m + 2 for m in tones]) if c >= quarter else (r, tones) for c, (r, tones) in enumerate(chords)]
    step = 60 / bpm / 2
    bars = len(lead) // 8
    total = bars * 8 * step
    n = int(RATE * total)
    out = np.zeros(n)
    step_n = int(RATE * step)

    def put(start_step, signal, offset=0):
        if swing and float(start_step).is_integer() and int(start_step) % 2:
            start_step += swing
        i = int(start_step * RATE * step) + offset
        end = min(n, i + len(signal))
        out[i:end] += signal[: end - i]
        if (solo or fine or nostalgia or humble or epic or harbor or club or french or island or anime or school) and i + len(signal) > n:  # o resto da nota soa no começo (loop sem corte)
            rest = signal[end - i:][:n]
            out[: len(rest)] += rest

    # Melodia (pulso 25%), nota a nota, ligando as repetidas.
    i = 0
    last_note = 0
    while i < len(lead):
        note = lead[i]
        length = 1
        while i + length < len(lead) and lead[i + length] == 0 and length < 2:
            length += 1
        if note:
            d = step * length * 0.95
            if solo:  # suspense: só as notas dos tempos, soando longas, uma oitava acima
                sig = grand(freq(note + 12), step * 6, 0.8) * 0.5 if i % 2 == 0 else np.zeros(1)
            elif voice == 'piano' and fine:
                sig = grand(freq(note), d * 2.5, 0.8) * 0.55
            elif voice == 'piano':
                sig = piano(freq(note), d) * env(int(RATE * d), 0.002, 0.03) * 0.42
            elif school:  # flauta doce com o glockenspiel dobrando uma oitava acima
                sig = flute(freq(note), d * 1.1) * 0.27
                sig = sig + np.pad(bell(freq(note + 12), d * 0.9, 0.6), (0, len(sig)))[: len(sig)] * 0.1
            elif anime:  # sintetizador brilhante com metais dobrando
                sig = synth_lead(freq(note), d * 1.02) * 0.17 + brass(freq(note), d * 1.02) * 0.1
            elif island:  # guitarra havaiana deslizando da nota anterior
                sig = steel(freq(last_note or note), freq(note), d * 1.3) * 0.3
                last_note = note
            elif french:  # acordeão; da 3ª parte em diante, o violino dobrando uma oitava acima
                part = i * 4 // len(lead)
                sig = reed(freq(note), d * 1.05) * 0.26
                if part >= 2:
                    sig = sig + violin(freq(note + 12), d * 1.05) * 0.09
            elif club:  # sintetizador brilhante na melodia
                sig = synth_lead(freq(note), d * 1.05) * 0.2
            elif harbor:  # acordeão na melodia e metais dobrando uma oitava abaixo
                sig = reed(freq(note), d * 1.05) * 0.26 + brass(freq(note - 12), d * 1.05) * 0.1
            elif epic and giant:  # orquestra gigante: a melodia nos metais em três oitavas
                sig = brass(freq(note - 24), d * 1.1) * 0.22 + brass(freq(note - 12), d * 1.1) * 0.26 + brass(freq(note), d * 1.1) * 0.12
            elif epic:  # metais na melodia, uma oitava abaixo (mais pesado), dobrados na oitava de cima
                sig = brass(freq(note - 12), d * 1.1) * 0.3 + brass(freq(note), d * 1.1) * 0.12
            elif humble:  # flauta, soando um pouco além da nota
                sig = flute(freq(note), d * 1.3) * 0.32
            elif nostalgia:  # vibrato depois do começo da nota, como nas rotas do Game Boy
                x = t(d)
                wobble = 1 + 0.006 * np.sin(2 * np.pi * 5.5 * x) * np.clip((x - 0.12) / 0.1, 0, 1)
                sig = pulse(freq(note) * wobble, d, duty) * env(int(RATE * d), 0.004, 0.06) * 0.2
                put(i, sig * 0.35, int(RATE * step * 0.75))  # o eco: a mesma nota, mais baixa e atrasada
            else:
                sig = pulse(freq(note), d, duty) * env(int(RATE * d), 0.004, 0.04) * 0.22
            put(i, sig)
        i += length

    for c, (root, tones) in enumerate(chords):
        base = c * 16
        # Baixo (triângulo): raiz em oitavas, colcheias (no humble, o baixo é dedilhado, mais abaixo).
        for k in range(0 if humble or epic or harbor or club or french or island or anime or school else 16):
            m = root + (12 if k % 2 else 0)
            d = step * 0.9
            if solo:  # suspense: a nota grave no pedal e, por cima, duas notas a meio tom se repetindo baixinho
                low = root - 12 if root >= 40 else root
                if k == 0:
                    put(base, grand(freq(low), step * 16, 0.9) * 0.55)
                put(base + k, grand(freq(low + 12 + (1 if k % 2 else 0)), step * 1.5, 0.35) * 0.3 * (0.7 + 0.4 * k / 15))
                continue
            put(base + k, triangle(freq(m), d) * env(int(RATE * d), 0.002, 0.02) * 0.35)
        if school:  # piano saltitante, pizzicato e contrabaixo
            low = root if root < 46 else root - 12
            for bar in range(2):
                b0 = base + bar * 8
                for k, gain in ((0, 0.13), (3, 0.09), (4, 0.11), (6, 0.09)):
                    for m in tones:
                        put(b0 + k, grand(freq(m), step * 1.5, 0.55) * gain)
                for k in range(0, 8, 2):
                    m = [tones[0], tones[2], tones[1], tones[2]][k // 2] + 12
                    put(b0 + k + 1, pluck(freq(m), step * 0.5, 0.9) * env(int(RATE * step * 0.5), 0.001, 0.05) * 0.1)
                for k, m in ((0, low), (4, low + 7)):
                    put(b0 + k, smooth(pluck(freq(m), step * 2, 0.2), 4) * 0.38)
            continue
        if anime:  # guitarra (aberta na entrada do acorde, abafada em colcheias) e baixo em colcheias
            low = root if root < 46 else root - 12
            put(base, power_chord(freq(low + 12), step * 3) * 0.3)
            for k in range(3, 16):
                put(base + k, power_chord(freq(low + 12), step * 0.9, True) * (0.22 if k % 2 == 0 else 0.16))
            for k in range(16):
                put(base + k, smooth(saw(freq(low), step * 0.9, 5), 10) * env(int(RATE * step * 0.9), 0.003, 0.03) * 0.3)
            continue
        if island:  # ukulele (batidas para baixo e para cima) e baixo macio
            uke = [tones[0] + 12, tones[1] + 12, tones[2] + 12, tones[0] + 24]
            for bar in range(2):
                b0 = base + bar * 8
                for k, down, gain in ((0, True, 0.11), (2, True, 0.09), (3, False, 0.06), (5, False, 0.06), (6, True, 0.09), (7, False, 0.06)):
                    for j, m in enumerate(uke if down else uke[::-1]):  # as cordas uma depois da outra (o rasgueado)
                        put(b0 + k, pluck(freq(m), step * 1.4, 0.8) * gain, int(RATE * 0.012 * j))
                low = root if root < 46 else root - 12
                for k, m in ((0, low), (3, low + 7), (4, low + 12)):
                    put(b0 + k, smooth(triangle(freq(m), step * 1.8), 8) * env(int(RATE * step * 1.8), 0.01, 0.1) * 0.32)
            continue
        if french:  # la pompe do violão; e, conforme a parte, contrabaixo, cordas e harpa
            part = c * 4 // len(chords)
            low = root if root < 46 else root - 12
            for bar in range(2):
                b0 = base + bar * 8
                for k in (0, 4):  # violão: o baixo nos tempos 1 e 3...
                    put(b0 + k, pluck(freq(low + 12 + (7 if k else 0)), step * 1.5, 0.5) * 0.22)
                for k in (2, 6):  # ...e o acorde curto (abafado) no 2 e no 4
                    for m in tones:
                        put(b0 + k, pluck(freq(m), step * 0.6, 0.7) * env(int(RATE * step * 0.6), 0.001, 0.08) * 0.1)
                if part >= 1:  # contrabaixo andando: raiz, terça, quinta e a nota de passagem
                    nxt = chords[(c + 1) % len(chords)][0]
                    nxt = nxt if nxt < 46 else nxt - 12
                    third = tones[1] - 12 if tones[1] - 12 > low else tones[1]
                    third = third - 12 if third - low > 12 else third
                    walk = [low, third, low + 7, (nxt - 1) if bar else low + 9]
                    for j, m in enumerate(walk):
                        put(b0 + j * 2, smooth(pluck(freq(m), step * 2, 0.2), 4) * 0.4)
            if part >= 2:  # cordas segurando o acorde
                for m in tones:
                    put(base, violin(freq(m), step * 16) * 0.035)
            if part >= 3:  # harpa em arpejo, subindo
                for k in range(16):
                    m = [tones[0], tones[1], tones[2], tones[0] + 12][k % 4] + 12
                    put(base + k, pluck(freq(m), step * 2, 0.8) * 0.07)
            continue
        if club:  # baixo ondulado (escorregando da nota anterior) e a linha em espiral por cima
            low = root if root < 46 else root - 12
            pattern = [(0, low, 3), (3, low + 12, 1), (4, low, 2), (6, low + 10, 1), (7, low + 12, 1)]
            prev = low
            for bar in range(2):
                for k, m, length in pattern:
                    put(base + bar * 8 + k, wobble_bass(freq(prev), freq(m), step * length * 0.95, 60 / bpm * 2) * 0.42)
                    prev = m
            spiral = [tones[0], tones[1], tones[2], tones[0] + 12, tones[1] + 12, tones[2], tones[1], tones[0] + 12]
            for k in range(32):
                m = spiral[k % 8] + (12 if (k // 8) % 2 else 0)
                put(base + k / 2, smooth(saw(freq(m), step * 0.4, 8), 3) * env(int(RATE * step * 0.4), 0.002, 0.03) * 0.05)
            # Pad macio segurando o acorde.
            for m in tones:
                put(base, smooth(saw(freq(m - 12), step * 16, 18), 30) * env(int(RATE * step * 16), 0.4, 0.6) * 0.05)
            continue
        if harbor:  # baixo saltitante pelo acorde (com nota de passagem) e metais curtos nos contratempos
            low = root if root < 46 else root - 12
            fifth = low + 7
            nxt = chords[(c + 1) % len(chords)][0]
            nxt = nxt if nxt < 46 else nxt - 12
            for bar in range(2):
                walk = [(0, low), (2, fifth), (4, low + 12), (6, fifth), (7, nxt - 1 if bar else fifth + 2)]
                for k, m in walk:
                    put(base + bar * 8 + k, smooth(pluck(freq(m), step * 1.6, 0.25), 3) * 0.55)
                for k in (1, 3, 5):
                    for m in tones:
                        put(base + bar * 8 + k, brass(freq(m), step * 0.45) * 0.07)
            continue
        if epic:  # baixo grave em colcheias (metal escuro) e cordas em ostinato de semicolcheias
            for k in range(16):
                low = root if root < 45 else root - 12
                put(base + k, smooth(saw(freq(low + (12 if k % 4 == 3 else 0)), step * 0.85, 6), 18) * env(int(RATE * step * 0.85), 0.005, 0.03) * 0.3)
            for k in range(32):
                m = [tones[0], tones[1], tones[0], tones[2]][k % 4] - 12
                put(base + k / 2, smooth(saw(freq(m), step * 0.48, 12), 6) * env(int(RATE * step * 0.48), 0.004, 0.02) * (0.11 if k % 4 else 0.15))
            if giant:  # coro segurando o acorde, cordas em trêmulo no agudo e o gongo na entrada
                for m in tones:
                    put(base, choir(freq(m), step * 16) * 0.5)
                for k in range(64):
                    m = tones[(k // 16) % 3] + 12
                    put(base + k / 4, smooth(saw(freq(m), step * 0.24, 9), 5) * env(int(RATE * step * 0.24), 0.002, 0.01) * 0.03)
                put(base, gong(3.5, 500 + c) * 0.35)
            continue
        if humble:  # baixo dedilhado nos tempos 1 e 3; acorde dedilhado em colcheias, subindo
            for k in range(0, 16, 4):
                put(base + k, pluck(freq(root + 12), step * 4, 0.3) * 0.35)
            for k in range(16):
                m = [tones[0], tones[1], tones[2], tones[1]][k % 4]
                put(base + k, pluck(freq(m), step * 3, 0.6) * (0.16 if k % 2 == 0 else 0.11))
            continue
        if nostalgia:  # acordes macios de piano por baixo, no começo e no meio do acorde
            for k in (0, 8):
                for m in tones:
                    put(base + k, grand(freq(m), step * 9, 0.35) * 0.1)
        # Arpejo (pulso 12,5%) em semicolcheias, bem baixinho.
        for k in range(32):
            m = tones[k % 3] - 12
            d = step / 2 * 0.9
            if solo:  # suspense: o acorde quebrado devagar (a cada 4 semicolcheias); no fim da frase, o trítono
                if k % 4:
                    continue
                m = [tones[0], tones[2], tones[1] + 12, tones[0] + 6 + 12 if k >= 24 else tones[2] + 12][(k // 4) % 4]
                sig = grand(freq(m), step * 4, 0.5) * 0.28
            else:
                sig = pulse(freq(m), d, 0.125) * env(int(RATE * d), 0.001, 0.01) * 0.07
            put(base + k / 2, sig)

    # Bateria (ruído): bumbo nos tempos 1 e 3, caixa no 2 e 4, chimbal nos contratempos.
    if school:  # bateria leve (bumbo, caixa macia com palmas, chocalho) e o sinal da escola no começo
        for b in range(bars):
            for k in (0, 4):
                put(b * 8 + k, drum(0.22, 120, 50, 300 + k, 0.8) * 0.3)
            for k in (2, 6):
                put(b * 8 + k, snare(0.14, 310 + b) * 0.12)
                for j in range(3):
                    put(b * 8 + k, snare(0.07, 320 + j) * 0.05, int(RATE * 0.007 * j))
            for k in range(8):
                sh = int(RATE * 0.04)
                put(b * 8 + k, noise(0.04, 330 + k, 1) * decay(sh, 80) * (0.03 if k % 2 else 0.02))
        tonic = chords[0][1][0]
        while tonic < 60:
            tonic += 12
        # Carrilhão de Westminster (domínio público, 1793): o "kin-kon-kan-kon" das escolas japonesas.
        chime = [4, 0, 2, -5, -5, 2, 4, 0]
        for j, deg in enumerate(chime):
            put(j * 4, bell(freq(tonic + deg), step * 8, 0.8) * 0.16)
    if anime:  # bateria de rock, prato no acorde, virada no fim; apito, torcida e as três palmas
        for b in range(bars):
            for k in (0, 4, 5):
                put(b * 8 + k, drum(0.25, 140, 50, 200 + k, 1.0) * 0.45)
            for k in (2, 6):
                put(b * 8 + k, snare(0.2, 210 + b) * 0.3)
            for k in range(8):
                hh = int(RATE * 0.05)
                put(b * 8 + k, noise(0.05, 220 + k, 1) * decay(hh, 70) * 0.05)
            if b % 2 == 0:  # prato de ataque na entrada de cada acorde
                cr = int(RATE * 1.2)
                crash = np.random.default_rng(230 + b).standard_normal(cr)
                put(b * 8, (crash - smooth(crash, 3)) * np.exp(-np.linspace(0, 5, cr)) * 0.12)
            else:  # virada no último tempo
                for r in range(4):
                    put(b * 8 + 6 + r / 2, snare(0.1, 240 + r) * (0.16 + 0.04 * r))
            if b % 4 == 3:  # clap-clap-clap da torcida
                for k in (5, 6, 7):
                    for j in range(5):
                        put(b * 8 + k, snare(0.08, 250 + j * 3 + k) * 0.07, int(RATE * 0.006 * j))
        crowd = np.random.default_rng(260).standard_normal(n)
        crowd = smooth(crowd, 12) - smooth(crowd, 60)
        out += crowd * (0.75 + 0.25 * np.sin(2 * np.pi * 3 * np.arange(n) / n)) * 0.06
        wl = int(RATE * 0.5)  # o apito do juiz, logo no começo
        wx = np.arange(wl) / RATE
        trill = 1 + 0.03 * np.sign(np.sin(2 * np.pi * 28 * wx))
        out[:wl] += np.sin(2 * np.pi * np.cumsum(2900 * trill) / RATE) * env(wl, 0.01, 0.05) * 0.12
    if island:  # chocalho em semicolcheias, ipu (cabaça) e as ondas do mar indo e voltando
        for b in range(bars):
            for k in range(16):
                sh = int(RATE * 0.04)
                put(b * 8 + k / 2, noise(0.04, 160 + k, 1) * decay(sh, 80) * (0.035 if k % 2 else 0.02))
            for k, hi in ((0, 220), (3, 260), (4, 200)):
                put(b * 8 + k, drum(0.2, hi, 110, 170 + k, 0.7) * 0.18)
        sea = smooth(np.random.default_rng(190).standard_normal(n), 30)
        waves = 4  # ondas por volta (o loop fecha certinho)
        swell = (0.5 - 0.5 * np.cos(2 * np.pi * waves * np.arange(n) / n)) ** 2
        out += sea * swell * 0.09
    for b in range(bars if french else 0):  # vassourinha da 2ª parte em diante; caixa leve no 2 e 4 na última
        part = b * 4 // bars
        if part >= 1:
            for beat in range(4):
                sw = int(RATE * 0.16)
                swish = np.random.default_rng(140 + beat).standard_normal(sw)
                put(b * 8 + beat * 2, (swish - smooth(swish, 3)) * np.sin(np.linspace(0, np.pi, sw)) * 0.035)
        if part >= 3:
            for k in (2, 6):
                put(b * 8 + k, snare(0.12, 150 + b) * 0.1)
    for b in range(bars if club else 0):  # batida de boate: bumbo em todo tempo, palma no 2 e 4, chimbal aberto
        for beat in range(4):
            put(b * 8 + beat * 2, drum(0.3, 150, 45, 90 + beat, 1.0) * 0.5)
            if beat % 2:
                put(b * 8 + beat * 2, snare(0.16, 120 + b) * 0.2)
            oh = int(RATE * 0.12)
            put(b * 8 + beat * 2 + 1, noise(0.12, 130 + beat, 1) * decay(oh, 30) * 0.05)
    for b in range(bars if harbor else 0):  # bateria com balanço: bumbo, caixa, chimbal e palmas
        for k in (0, 3, 4):
            put(b * 8 + k, drum(0.25, 130, 50, 60 + k, 0.8) * (0.45 if k != 3 else 0.25))
        for k in (2, 6):
            put(b * 8 + k, snare(0.18, 70 + b) * 0.22)
        for k in range(8):
            hh = int(RATE * 0.04)
            put(b * 8 + k, noise(0.04, 80 + k, 1) * decay(hh, 90) * (0.06 if k % 2 else 0.035))
        if b % 4 == 3:
            put(b * 8 + 7, snare(0.12, 99) * 0.16)  # palma no fim da frase
    for b in range(bars if epic else 0):  # tambores de guerra: 1, o "e" do 2 e o 3; rufada no fim da frase
        for s_, gain, hi in ((0, 0.6, 95), (3, 0.4, 80), (4, 0.55, 90)):
            put(b * 8 + s_, drum(0.6, hi, 36, 5 + s_) * gain)
        if b % 2 == 1:
            for r in range(6):
                put(b * 8 + 5 + r / 2, drum(0.2, 160, 90, 40 + r, 0.4) * (0.15 + 0.05 * r))
    if epic and weather:  # chuva fina o tempo todo, um trovão (Kyogre) e a terra roncando (Groudon)
        rain = np.random.default_rng(77).standard_normal(n)
        out += (rain - smooth(rain, 6)) * 0.02
        for bar, seed in ((2, 3), (10, 4)):
            m = int(RATE * 2.5)
            thunder = smooth(np.random.default_rng(seed).standard_normal(m), 60) * np.exp(-np.linspace(0, 4, m)) * 1.6
            put(bar * 8, thunder)
        for bar, seed in ((6, 8), (14, 9)):
            m = int(RATE * 3.0)
            rumble = smooth(np.random.default_rng(seed).standard_normal(m), 200) * np.sin(np.linspace(0, np.pi, m)) * 5.0
            put(bar * 8, rumble)
    for b in range(bars if humble else 0):  # só um chocalho leve nos contratempos
        for beat in range(4):
            sh = int(RATE * 0.05)
            put(b * 8 + beat * 2 + 1, noise(0.05, 23 + beat, 1) * decay(sh, 60) * 0.045)
    for b in range(0 if solo or humble or epic or harbor or club or french or island or anime or school else bars):
        for beat in range(4):
            s = b * 8 + beat * 2
            if (beat == 0 if soft else beat in (0, 2) or drive):
                kick_n = int(RATE * 0.12)
                put(s, pulse(np.linspace(140, 45, kick_n), 0.12, 0.5) * decay(kick_n, 30) * 0.3)
            if beat in (1, 3) and not soft:
                sn = int(RATE * 0.12)
                put(s, noise(0.12, 13 + b, 1) * decay(sn, 28) * 0.18)
            hh = int(RATE * 0.04)
            put(s + 1, noise(0.04, 17 + beat, 1) * decay(hh, 90) * 0.08)
    # Só piano: sem bateria e chiptune fica mais baixo; sobe para o volume das outras.
    if nostalgia or humble or epic or harbor or club or french or island or anime or school:  # mais quente (agudos suavizados) e um eco de sala leve
        out = np.convolve(out, np.ones(3) / 3, 'same')
        out = out * 0.8 + (room(out, step) - out) * 0.35
        out = out / max(1e-9, np.abs(out).max())
        # Os acústicos (flauta e cordas) variam mais de volume: compressão leve, como nas outras.
        return np.tanh(out * 2.2) / np.tanh(2.2) * 0.85 if humble or epic or harbor or club or french or island or anime or school else out * 0.85
    if solo:
        out = room(out, step)
        out = out / max(1e-9, np.abs(out).max())
        # Compressão leve: o piano tem muita diferença entre forte e fraco; fica no volume das outras.
        return np.tanh(out * 3.0) / np.tanh(3.0) * 0.9
    return out


# ------------------------------------------------------------------ temas

# Escalas (semitons a partir da tônica).
MODES = {
    'minor': [0, 2, 3, 5, 7, 8, 10], 'harmonic': [0, 2, 3, 5, 7, 8, 11], 'dorian': [0, 2, 3, 5, 7, 9, 10],
    'major': [0, 2, 4, 5, 7, 9, 11], 'mixolydian': [0, 2, 4, 5, 7, 9, 10], 'phrygian': [0, 1, 3, 5, 7, 8, 10],
}
# Ritmos de 2 compassos (colcheias): 1 = nota nova, 0 = segura/pausa.
RHYTHMS = [
    [1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 1, 1, 0, 0, 0],
    [1, 1, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 0, 0],
    [1, 0, 0, 1, 1, 0, 1, 0, 1, 1, 1, 1, 1, 0, 0, 0],
    [1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 0, 1, 1, 0, 1, 0],
    [1, 1, 0, 1, 1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 1, 0],
    [1, 0, 1, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1, 0, 0],
]
CADENCE = [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0]

# Cada região (líderes, Elite Four e kahunas) e cada campeão com o seu tema
# original: tônica, escala, progressão (graus), andamento, timbre e semente.
REGION_THEMES = {
    'kanto': (69, 'dorian', [0, 6, 5, 6], 160, 0.25),
    'johto': (62, 'dorian', [0, 3, 6, 4], 156, 0.5),
    'hoenn': (67, 'minor', [0, 5, 2, 6], 164, 0.25),
    'sinnoh': (64, 'harmonic', [0, 5, 3, 4], 158, 0.125),
    'unova': (65, 'minor', [0, 5, 6, 4], 170, 0.25),
    'kalos': (66, 'phrygian', [0, 1, 0, 6], 162, 0.5),
    'alola': (67, 'mixolydian', [0, 3, 6, 4], 150, 0.5),
    'galar': (62, 'minor', [0, 5, 6, 0], 168, 0.25),
    'paldea': (69, 'dorian', [0, 3, 0, 6], 166, 0.125),
}
CHAMPION_THEMES = {
    'blue': (64, 'harmonic', [0, 5, 3, 4], 176, 0.25, 'pulse'),
    'lance': (62, 'harmonic', [0, 3, 5, 4], 172, 0.5, 'pulse'),
    'steven': (65, 'minor', [0, 5, 6, 4], 174, 0.25, 'pulse'),
    'cynthia': (64, 'harmonic', [0, 5, 3, 4], 168, 0.25, 'piano'),
    'alder': (67, 'dorian', [0, 6, 3, 4], 168, 0.5, 'pulse'),
    'iris': (69, 'harmonic', [0, 5, 1, 4], 178, 0.125, 'pulse'),
    'diantha': (66, 'minor', [0, 2, 5, 4], 170, 0.5, 'piano'),
    'kukui': (67, 'mixolydian', [0, 6, 3, 4], 160, 0.25, 'pulse'),
    'leon': (62, 'minor', [0, 5, 6, 4], 180, 0.25, 'pulse'),
    'geeta': (63, 'harmonic', [0, 3, 5, 4], 172, 0.125, 'pulse'),
}

# Os lugares da Battle Factory, cada grupo com o seu tema original (selvagens e treinadores da rota).
PLACE_THEMES = {
    'field': (67, 'major', [0, 3, 4, 0], 150, 0.5),
    'forest': (62, 'dorian', [0, 3, 0, 4], 140, 0.25),
    'sea': (65, 'mixolydian', [0, 4, 3, 0], 146, 0.5),
    'cave': (60, 'phrygian', [0, 1, 0, 6], 136, 0.125),
    'mountain': (64, 'dorian', [0, 6, 3, 4], 154, 0.25),
    'desert': (62, 'harmonic', [0, 1, 0, 6], 148, 0.25),
    'city': (67, 'minor', [0, 5, 6, 4], 160, 0.25),
    'spooky': (63, 'harmonic', [0, 1, 5, 4], 132, 0.125),
}


# O mapa de cada região no Pokelike: temas originais mais calmos (andamento lento, bateria leve;
# o 7º item, quando há, muda a bateria e o balanço: soft False é a bateria completa).
# As músicas do mapa saem com mais qualidade (64 kbps): a 40, os agudos do piano ficam metálicos.
MAP_THEMES = {
    # Kanto: nostalgia do Game Boy (I–vi–IV–V em tom maior, vibrato, eco e acordes macios), melodia original.
    'kanto': (67, 'major', [0, 5, 3, 4], 112, 0.25, 'pulse', {'nostalgia': True}),
    # Johto: a sensação de personagem secundário (humilde, simpático, agridoce): flauta e cordas
    # dedilhadas, I–iii–IV–V, melodia original.
    'johto': (62, 'major', [0, 2, 3, 4], 100, 0.25, 'piano', {'humble': True}),
    # Hoenn: uma batalha lendária entre o mar e a terra (metais, cordas em ostinato, tambores de guerra,
    # chuva, trovão e terra roncando), i–VI–ii°–V na menor harmônica, melodia original.
    'hoenn': (62, 'harmonic', [0, 5, 1, 4], 152, 0.5, 'pulse', {'epic': True}),
    # Sinnoh: suspense no estilo de um tema de campeã dramático, só piano (menor harmônica, grave no
    # pedal, duas notas a meio tom se repetindo, trítono no fim da frase), com melodia original.
    'sinnoh': (64, 'harmonic', [0, 5, 3, 4], 96, 0.25, 'piano', {'solo': True}),
    # Unova: porto à noite com clima de boate (baixo ondulado, bumbo em todo tempo, melodia em espiral),
    # na dórica, com melodia original.
    'unova': (64, 'dorian', [0, 6, 3, 4], 130, 0.5, 'pulse', {'club': True}),
    # Kalos: café francês que evolui (acordeão e violão cigano; entram contrabaixo, vassourinha, violino,
    # cordas e harpa; no fim sobe um tom), na menor harmônica, com melodia original.
    'kalos': (62, 'harmonic', [0, 3, 4, 0], 126, 0.5, 'pulse', {'french': True, 'swing': 0.2}),
    # Alola: praia havaiana, o espírito do Aloha (guitarra havaiana, ukulele, ipu e ondas do mar), com melodia original.
    'alola': (67, 'major', [0, 3, 4, 0], 96, 0.5, 'pulse', {'island': True, 'swing': 0.15}),
    # Galar: abertura de anime de futebol (guitarra distorcida, bateria de rock, apito, torcida e palmas),
    # IV–V–iii–vi (o "caminho real" do J-pop), com melodia original.
    'galar': (64, 'major', [3, 4, 2, 5], 172, 0.125, 'pulse', {'anime': True}),
    # Paldea: escola de anime (o sinal da escola, flauta doce e glockenspiel, piano, pizzicato e bateria leve),
    # I–V–vi–IV, com melodia original.
    'paldea': (65, 'major', [0, 4, 5, 3], 128, 0.25, 'pulse', {'school': True}),
}


def compose(name, tonic, mode, progression, climax=False):
    """Melodia e acordes originais (128 colcheias) a partir de motivos gerados:
    A no 1º acorde, A em sequência no 2º, B no 3º e uma cadência no 4º; depois
    tudo de novo com variação (mais alto no tema de campeão)."""
    scale = MODES[mode]
    rng = np.random.default_rng(sum(ord(c) * (i + 1) for i, c in enumerate(name)))

    def midi(degree):
        return tonic + 12 * (degree // 7) + scale[degree % 7]

    def motif(rhythm):
        out, d = [], int(rng.choice([0, 2, 4]))
        for pos, on in enumerate(rhythm):
            if not on:
                out.append(None)
                continue
            if out:
                d += int(rng.choice([-2, -1, -1, 1, 1, 2, 3, -3]))
            if pos % 4 == 0:  # tempo forte: nota do acorde
                d = min((c for c in range(-7, 12) if c % 7 in (0, 2, 4)), key=lambda c: (abs(c - d), c))
            d = max(-2, min(7, d))
            out.append(d)
        return out

    a = motif(RHYTHMS[int(rng.integers(len(RHYTHMS)))])
    b = motif(RHYTHMS[int(rng.integers(len(RHYTHMS)))])
    cadence = [4, None, None, None, 2, None, None, None, 1, None, 0, None, 2, None, None, None]
    lead, chords = [], []
    for half in range(2):
        lift = (5 if climax else 2) if half else 0
        for k, root in enumerate(progression):
            part = [a, a, b, cadence][k]
            if half and k == 2:
                part = [None if x is None else 4 - x for x in b]  # B espelhado
            # A raiz do acorde fica perto da tônica, para a melodia não pular.
            r = root if root <= 3 else root - 7
            for x in part:
                m = 0 if x is None else midi(r + x + lift)
                while m and m < 62:  # registro confortável: dobra a oitava nos extremos
                    m += 12
                while m > 88:
                    m -= 12
                lead.append(m)
            tones = [midi(root + i) for i in (0, 2, 4)]
            bass = tones[0] - 24
            while bass > 47:
                bass -= 12
            chords.append((bass, [m - 12 if m >= 72 else m for m in tones]))
    return lead, chords


def theme_tracks():
    """{nome do arquivo: música} dos temas de região e de campeão."""
    out = {}
    for region, (tonic, mode, prog, bpm, duty) in REGION_THEMES.items():
        lead, chords = compose(region, tonic, mode, prog)
        out[f'gym_{region}'] = music(lead, chords, bpm, duty=duty)
    for champion, (tonic, mode, prog, bpm, duty, voice) in CHAMPION_THEMES.items():
        lead, chords = compose(champion, tonic, mode, prog, climax=True)
        out[f'champion_{champion}'] = music(lead, chords, bpm, duty=duty, voice=voice, drive=voice == 'pulse')
    for place, (tonic, mode, prog, bpm, duty) in PLACE_THEMES.items():
        lead, chords = compose(f'place-{place}', tonic, mode, prog)
        out[f'place_{place}'] = music(lead, chords, bpm, duty=duty)
    out.update(map_tracks())
    out['mega_theme'] = mega_theme()
    out['dmax_theme'] = dmax_theme()
    return out


def map_tracks():
    """{nome do arquivo: música} do mapa de cada região (map_<região>)."""
    return {
        f'map_{region}': music(*compose(f'map-{region}', tonic, mode, prog), bpm, duty=duty, voice=voice, **{'soft': True, 'fine': True, **(extra[0] if extra else {})})
        for region, (tonic, mode, prog, bpm, duty, voice, *extra) in MAP_THEMES.items()
    }


# O clarão da Mega/Dynamax na animação (turn_battle_screen.dart e TurnBattlePage.jsx: espera de 700 ms).
HIT_AT = 0.7


def sfx_mega():
    """Fanfarra da Mega Evolução: coro e cordas subindo com o rufar dos tímpanos crescendo e, na
    transformação, um acorde gigante de metais com prato e o brilho de sinos. O estouro cai em HIT_AT,
    o clarão da animação (app e site tocam adiantado em 2x e 4x para continuar junto)."""
    total = 4.2
    n = int(RATE * total)
    out = np.zeros(n)

    def put(at, sig):
        i = int(RATE * at)
        end = min(n, i + len(sig))
        out[i:end] += sig[: end - i]

    rise = HIT_AT
    x = t(rise)
    for base in (52, 59, 64):  # cordas e coro subindo uma oitava
        f = freq(base) * 2 ** (x / rise)
        put(0, smooth(saw(f, rise, 10), 8) * np.linspace(0.1, 1, len(x)) * 0.12)
    for r in range(14):  # rufar dos tímpanos, cada vez mais forte
        put(r * rise / 14, drum(0.25, 110, 55, 400 + r, 0.8) * (0.1 + 0.03 * r))
    hit = rise
    for m in (40, 52, 59, 64, 68, 71, 76):  # o acorde dos metais (Mi maior aberto)
        put(hit, brass(freq(m), 2.6) * (0.16 if m < 60 else 0.1))
    put(hit, drum(1.2, 90, 36, 420, 1.0) * 0.7)
    cr = int(RATE * 2.5)
    crash = np.random.default_rng(430).standard_normal(cr)
    put(hit, (crash - smooth(crash, 3)) * np.exp(-np.linspace(0, 4, cr)) * 0.25)
    for j, m in enumerate((76, 80, 83, 88, 92)):  # o brilho de sinos descendo do céu
        put(hit + 0.15 + j * 0.09, bell(freq(m), 1.6) * 0.12)
    out = room(out, 0.1)
    return np.tanh(out / max(1e-9, np.abs(out).max()) * 2.2) / np.tanh(2.2) * 0.9


def sfx_dmax():
    """Fanfarra do Dynamax/Gigantamax: a orquestra gigante. O coro e os metais graves crescem junto com
    o Pokémon, o rufar dos tímpanos sobe e, na transformação (HIT_AT), o gongo e o acorde em três oitavas."""
    total = 5.5
    n = int(RATE * total)
    out = np.zeros(n)

    def put(at, sig):
        i = int(RATE * at)
        end = min(n, i + len(sig))
        out[i:end] += sig[: end - i]

    rise = HIT_AT
    x = t(rise)
    for m in (33, 40, 45, 52):  # metais graves e coro crescendo (subindo uma quinta)
        f = freq(m) * 2 ** (7 / 12 * x / rise)
        put(0, smooth(saw(f, rise, 12), 10) * np.linspace(0.05, 1, len(x)) ** 2 * 0.14)
    for r in range(18):
        put(r * rise / 18, drum(0.3, 90, 40, 600 + r, 0.9) * (0.08 + 0.03 * r))
    hit = rise
    put(hit, gong(4.5, 610) * 0.8)
    put(hit, drum(1.5, 70, 30, 620, 1.0) * 0.8)
    for m in (28, 40, 52, 59, 64, 67, 71, 76):  # o acorde em três oitavas (Mi menor aberto)
        put(hit, brass(freq(m), 3.4) * (0.2 if m < 45 else 0.11))
    for m in (52, 59, 64, 67):
        put(hit, choir(freq(m), 4.0) * 0.6)
    out = room(out, 0.1)
    return np.tanh(out / max(1e-9, np.abs(out).max()) * 2.2) / np.tanh(2.2) * 0.9


def dmax_theme():
    """O tema da orquestra gigante depois do Dynamax/Gigantamax: lento e pesado, i–VI–iv–V na menor
    harmônica, com melodia original."""
    lead, chords = compose('dynamax-giant', 64, 'harmonic', [0, 5, 3, 4], climax=True)
    return music(lead, chords, 120, epic=True, weather=False, giant=True)


def mega_theme():
    """O tema épico depois da Mega Evolução: orquestra heroica (metais, cordas em ostinato, tambores
    de guerra), i–VI–III–VII na menor, com melodia original."""
    lead, chords = compose('mega-evolution', 64, 'minor', [0, 5, 2, 6], climax=True)
    return music(lead, chords, 160, epic=True, weather=False)


def main():
    os.makedirs(OUT, exist_ok=True)
    sounds = {
        'hit': sfx_hit(),
        'super': sfx_super(),
        'weak': sfx_weak(),
        'faint': sfx_faint(),
        'throw': sfx_throw(),
        'open': sfx_open(),
        'recall': sfx_recall(),
        'statup': sfx_statup(),
        'statdown': sfx_statdown(),
        'heal': sfx_heal(),
        'select': sfx_select(),
        'shiny': sfx_shiny(),
        'victory': sfx_victory(),
        'mega': sfx_mega(),
        'dmax': sfx_dmax(),
    }
    # Só alguns (ex.: python3 tool/build_battle_sounds.py shiny): sem gerar as músicas de novo.
    only = sys.argv[1:]
    if only == ['mega']:  # python3 tool/build_battle_sounds.py mega: as fanfarras e os temas da Mega e do Dynamax
        save('mega', sfx_mega())
        save_loop('mega_theme', mega_theme())
        save('dmax', sfx_dmax())
        save_loop('dmax_theme', dmax_theme())
        return
    if only == ['maps']:  # python3 tool/build_battle_sounds.py maps: só as músicas do mapa
        for name, sig in map_tracks().items():
            save_loop(name, sig, bitrate=64)
        return
    if only:
        for name in only:
            save(name, sounds[name])
        return
    total = 0
    for name, sig in sounds.items():
        total += save(name, sig)
    total += save_loop('battle_music', music(), bitrate=64)
    themes = theme_tracks()
    for name, sig in themes.items():
        total += save_loop(name, sig, bitrate=64 if name.startswith('map_') or name in ('mega_theme', 'dmax_theme') else 40)
    print(f'{len(sounds) + 1 + len(themes)} sons, {total // 1024} KB')


if __name__ == '__main__':
    main()
