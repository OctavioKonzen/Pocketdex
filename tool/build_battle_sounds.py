"""Sons da batalha, sintetizados aqui (nada copiado de jogo): efeitos no
estilo 8-bit, uma música de batalha chiptune original em loop e um tema
original para cada região (líderes, Elite dos Quatro e kahunas) e cada campeão.

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


def singer(f, seconds):
    """Voz feminina sem letra ("aah", estilo mezzo-soprano): serra com vibrato de cantora, nas formantes
    do "a" (realça ~800 Hz e ~1200 Hz), entrando devagar."""
    n = int(RATE * seconds)
    x = t(seconds)
    vib = 1 + 0.009 * np.sin(2 * np.pi * 5.6 * x) * np.clip((x - 0.2) / 0.3, 0, 1)
    raw = saw(f * vib, seconds, 4)
    a = smooth(raw, int(RATE / 1600)) - smooth(raw, int(RATE / 650))
    return (a * 1.6 + smooth(raw, 14) * 0.25) * env(n, 0.12, 0.15)


def room(sig, step_s):
    """Eco de sala (com o pedal), dando a volta no fim para o loop continuar sem emenda."""
    out = sig.copy()
    for delay, gain in ((0.031, 0.32), (0.067, 0.24), (0.113, 0.18), (0.171, 0.12), (0.241, 0.08)):
        out += np.roll(sig, int(RATE * delay)) * gain
    return out


def music(lead=None, chords=None, bpm=BPM, duty=0.25, voice='pulse', drive=False, soft=False, swing=0.0, solo=False, fine=False, nostalgia=False, humble=False, epic=False, weather=True, giant=False, harbor=False, club=False, french=False, island=False, anime=False, school=False, belle=False):
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
    school: escola de anime (sinal da escola, flauta doce e glockenspiel, piano, pizzicato, bateria leve);
    belle: francês melancólico e operístico, que evolui em 4 partes (piano solo; + violoncelo e harpa;
    + acordeão e cordas; + voz sem letra, orquestra e um tom acima)."""
    lead = lead or LEAD
    chords = chords or CHORDS
    if french or belle:  # o dobro do tamanho, para evoluir em 4 partes; a última um tom acima
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
        if (solo or fine or nostalgia or humble or epic or harbor or club or french or island or anime or school or belle) and i + len(signal) > n:  # o resto da nota soa no começo (loop sem corte)
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
            elif belle:  # piano solo; acordeão suave na 3ª parte; a voz sem letra na última
                part = i * 4 // len(lead)
                sig = grand(freq(note), d * 2.2, 0.75) * 0.42
                if part >= 2:
                    sig = sig + np.pad(reed(freq(note), d * 1.05), (0, len(sig)))[: len(sig)] * 0.08
                if part >= 3:
                    sig = sig + np.pad(singer(freq(note), d * 1.15), (0, len(sig)))[: len(sig)] * 0.2
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
        for k in range(0 if humble or epic or harbor or club or french or island or anime or school or belle else 16):
            m = root + (12 if k % 2 else 0)
            d = step * 0.9
            if solo:  # suspense: a nota grave no pedal e, por cima, duas notas a meio tom se repetindo baixinho
                low = root - 12 if root >= 40 else root
                if k == 0:
                    put(base, grand(freq(low), step * 16, 0.9) * 0.55)
                put(base + k, grand(freq(low + 12 + (1 if k % 2 else 0)), step * 1.5, 0.35) * 0.3 * (0.7 + 0.4 * k / 15))
                continue
            put(base + k, triangle(freq(m), d) * env(int(RATE * d), 0.002, 0.02) * 0.35)
        if belle:  # acordes quebrados no piano; e, conforme a parte, violoncelo, harpa, cordas e tímpano
            part = c * 4 // len(chords)
            low = root if root < 46 else root - 12
            put(base, grand(freq(low), step * 16, 0.6) * 0.3)
            for k in range(2, 16, 2):  # a mão esquerda quebrando o acorde, devagar
                m = [tones[0], tones[1], tones[2], tones[1]][(k // 2) % 4] - 12
                put(base + k, grand(freq(m), step * 3, 0.45) * 0.12)
            if part >= 1:  # violoncelo em contracanto (a terça e a quinta, em notas longas) e harpa
                for k, m in ((0, tones[1] - 12), (8, tones[2] - 12)):
                    put(base + k, violin(freq(m - 12), step * 8) * 0.16)
                for k in range(16):
                    m = [tones[0], tones[1], tones[2], tones[0] + 12][k % 4] + 12
                    put(base + k, pluck(freq(m), step * 2, 0.8) * 0.05)
            if part >= 2:  # cordas segurando o acorde
                for m in tones:
                    put(base, violin(freq(m), step * 16) * 0.04)
            if part >= 3:  # tímpano leve no começo do acorde
                for r in range(6):
                    put(base + r / 3, drum(0.3, 80, 45, 700 + r + c, 0.8) * (0.05 + 0.02 * r))
            continue
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
    if nostalgia or humble or epic or harbor or club or french or island or anime or school or belle:  # mais quente (agudos suavizados) e um eco de sala leve
        out = np.convolve(out, np.ones(3) / 3, 'same')
        out = out * 0.8 + (room(out, step) - out) * 0.35
        out = out / max(1e-9, np.abs(out).max())
        # Os acústicos (flauta e cordas) variam mais de volume: compressão leve, como nas outras.
        return np.tanh(out * 2.2) / np.tanh(2.2) * 0.85 if humble or epic or harbor or club or french or island or anime or school or belle else out * 0.85
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

# Cada região (líderes, Elite dos Quatro e kahunas) e cada campeão com o seu tema
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
    'wallace': (62, 'dorian', [0, 3, 6, 4], 166, 0.25, 'pulse'),
    'cynthia': (64, 'harmonic', [0, 5, 3, 4], 168, 0.25, 'piano'),
    'alder': (67, 'dorian', [0, 6, 3, 4], 168, 0.5, 'pulse'),
    'iris': (69, 'harmonic', [0, 5, 1, 4], 178, 0.125, 'pulse'),
    'diantha': (66, 'minor', [0, 2, 5, 4], 170, 0.5, 'piano'),
    'kukui': (67, 'mixolydian', [0, 6, 3, 4], 160, 0.25, 'pulse'),
    'leon': (62, 'minor', [0, 5, 6, 4], 180, 0.25, 'pulse'),
    'geeta': (63, 'harmonic', [0, 3, 5, 4], 172, 0.125, 'pulse'),
    'volo': (62, 'harmonic', [0, 1, 5, 4], 170, 0.25, 'pulse'),
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
    # Kalos: francês melancólico e operístico, que evolui (piano solo; entram violoncelo, harpa, acordeão,
    # cordas e, no fim, uma voz sem letra e um tom acima), i–iv–VII–III na menor, com melodia original.
    'kalos': (62, 'minor', [0, 3, 6, 2], 84, 0.5, 'pulse', {'belle': True}),
    # Alola: praia havaiana, o espírito do Aloha (guitarra havaiana, ukulele, ipu e ondas do mar), com melodia original.
    'alola': (67, 'major', [0, 3, 4, 0], 96, 0.5, 'pulse', {'island': True, 'swing': 0.15}),
    # Galar: abertura de anime de futebol (guitarra distorcida, bateria de rock, apito, torcida e palmas),
    # IV–V–iii–vi (o "caminho real" do J-pop), com melodia original.
    'galar': (64, 'major', [3, 4, 2, 5], 172, 0.125, 'pulse', {'anime': True}),
    # Paldea: escola de anime (o sinal da escola, flauta doce e glockenspiel, piano, pizzicato e bateria leve),
    # I–V–vi–IV, com melodia original.
    'paldea': (65, 'major', [0, 4, 5, 3], 128, 0.25, 'pulse', {'school': True}),
    # Hisui: o Japão antigo da era Meiji (shakuhachi, koto, shamisen e taikô ao longe), na frígia, com melodia original.
    'hisui': (62, 'phrygian', [0, 5, 6, 0], 88, 0.25, 'pulse', {}),
    # Orre: faroeste no deserto (violão, gaita, assobio e o baixo andando), na dórica.
    'orre': (64, 'dorian', [0, 6, 3, 4], 104, 0.5, 'pulse', {}),
    # Fiore: aventura ao ar livre de Ranger (flauta, violão e cordas leves), I–IV–V–IV.
    'fiore': (67, 'major', [0, 3, 4, 3], 120, 0.25, 'pulse', {}),
    # Almia: a escola de Rangers no litoral (piano, clarinete e pizzicato), I–vi–ii–V.
    'almia': (65, 'major', [0, 5, 1, 4], 112, 0.25, 'pulse', {}),
    # Oblivia: ilhas tropicais e ruínas antigas (marimba, flauta de pã e tambores de mão), na mixolídia.
    'oblivia': (62, 'mixolydian', [0, 6, 3, 0], 108, 0.5, 'pulse', {}),
    # Kitakami: o festival do interior (koto, flauta japonesa, taikô e sininhos), na menor.
    'kitakami': (64, 'minor', [0, 5, 3, 6], 96, 0.25, 'pulse', {}),
    # Blueberry Academy: escola no mar, moderna (sintetizador, piano elétrico, baixo e bateria eletrônica leve).
    'blueberry': (66, 'major', [0, 4, 5, 3], 124, 0.25, 'pulse', {}),
    # Ilhas Sevii: viagem de barco entre ilhas (marimba, flauta e violão, ondas calmas), I–IV–ii–V.
    'sevii': (67, 'major', [0, 3, 1, 4], 110, 0.25, 'pulse', {}),
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


# ------------------------------------------------------------------ com instrumentos gravados

# Banco de instrumentos gravados (FluidR3 GM, licença MIT; no Ubuntu: apt install fluidsynth fluid-soundfont-gm).
SOUNDFONT = os.environ.get('SOUNDFONT', '/usr/share/sounds/sf2/FluidR3_GM.sf2')
HI_RATE = 44100


# Banco de instrumentos melhor (MuseScore General, licença MIT; no Ubuntu: apt install musescore-general-soundfont),
# usado nas trilhas novas (rivais): guitarras, bateria e metais mais realistas.
MUSESCORE = os.environ.get('MUSESCORE_SF', '/usr/share/sounds/sf3/MuseScore_General_Full.sf3')


def _midi_render(parts, bpm, soundfont):
    """As notas → áudio estéreo [n, 2] (FluidSynth), sem cortar nem normalizar."""
    import tempfile

    import mido

    tpb = 480
    per_step = tpb // 2
    mid = mido.MidiFile(ticks_per_beat=tpb)
    meta = mido.MidiTrack()
    meta.append(mido.MetaMessage('set_tempo', tempo=mido.bpm2tempo(bpm), time=0))
    mid.tracks.append(meta)
    melodic = 0
    for part in parts:
        program, notes = part[0], part[1]
        opts = part[2] if len(part) > 2 else {}
        if program == 'drums':
            ch = 9
        else:
            ch = melodic if melodic < 9 else melodic + 1  # o canal 10 é da bateria
            melodic += 1
        events = []  # (tick, ordem, mensagem)
        if program != 'drums':
            events.append((0, 0, mido.Message('program_change', channel=ch, program=program)))
        for ctl, val in opts.get('cc', {}).items():
            events.append((0, 1, mido.Message('control_change', channel=ch, control=ctl, value=val)))
        if opts.get('glide'):  # pitch bend de 12 semitons (RPN 0)
            for ctl, val in ((101, 0), (100, 0), (6, 12), (38, 0)):
                events.append((0, 1, mido.Message('control_change', channel=ch, control=ctl, value=val)))
        bend_at = {round(x, 3) for x in opts.get('bend', ())}
        prev = None
        for start, length, note, vel in sorted(notes):
            at = int(round(start * per_step))
            end = at + max(1, int(round(length * per_step))) - 1
            if round(start, 3) in bend_at:  # o bend de verdade: começa 1 tom abaixo e sobe até a nota
                ticks = int(per_step * 0.6)
                for j in range(7):
                    events.append((at + ticks * j // 6, 2, mido.Message('pitchwheel', channel=ch, pitch=int(-8191 * (1 - j / 6)))))
                events.append((end, 2, mido.Message('pitchwheel', channel=ch, pitch=0)))
            if opts.get('glide') and prev is not None and prev != note:
                ticks = int(per_step * 0.45)
                for j in range(6):  # desliza da nota anterior até a nota
                    bend = int((prev - note) / 12 * 8191 * (1 - j / 5))
                    events.append((at + ticks * j // 5, 2, mido.Message('pitchwheel', channel=ch, pitch=max(-8192, min(8191, bend)))))
            events.append((at, 3, mido.Message('note_on', channel=ch, note=int(note), velocity=int(max(1, min(127, vel))))))
            events.append((end, 1, mido.Message('note_off', channel=ch, note=int(note), velocity=0)))
            prev = note
        events.sort(key=lambda e: (e[0], e[1]))
        track = mido.MidiTrack()
        now = 0
        for at, _, msg in events:
            track.append(msg.copy(time=at - now))
            now = at
        mid.tracks.append(track)
    with tempfile.TemporaryDirectory() as tmp:
        mpath, wpath = os.path.join(tmp, 'm.mid'), os.path.join(tmp, 'm.wav')
        mid.save(mpath)
        subprocess.run(['fluidsynth', '-ni', '-q', '-g', '0.5', '-r', str(HI_RATE), '-F', wpath, soundfont, mpath], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', wpath, '-f', 's16le', '-ac', '2', '-ar', str(HI_RATE), '-'],
                             capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.int16).astype(float).reshape(-1, 2) / 32768


def amp(audio, drive=30.0):
    """Amplificador de guitarra: a guitarra limpa (DI) → pré (corta o grave embolado, realça o médio) →
    saturação em dois estágios (assimétrica, como válvula) → caixa 4×12 (corta o agudo áspero, ressalta
    ~2 kHz). É o que faz a guitarra soar pesada e real, em vez do "patch" distorcido pronto do banco."""
    from scipy.signal import butter, sosfilt

    def f(kind, freq, x, order=2):
        return sosfilt(butter(order, freq, kind, fs=HI_RATE, output='sos'), x, axis=0)

    x = f('highpass', 110, audio)
    x = x + 0.8 * f('bandpass', [600, 1800], x)
    x = np.tanh(drive * x + 0.15) - np.tanh(0.15)
    x = f('highpass', 80, x)
    x = np.tanh(2.2 * x)
    x = f('lowpass', 5200, x, 4)
    x = x + 0.5 * f('bandpass', [1600, 2600], x)
    return x / max(1e-9, np.abs(x).max())


def render(parts, bpm, steps, tail=4.0, loop=True, overlay=None, squash=2.6, soundfont=None):
    """Toca as notas com instrumentos gravados (FluidSynth). parts = [(programa GM ou 'drums', notas[, opções])],
    notas = [(colcheia, duração em colcheias, nota MIDI, força)]. Opções: glide (desliza da nota anterior,
    com pitch bend), cc ({controle: valor}, ex.: 1 vibrato, 7 volume, 10 pan, 91 reverb), amp (a guitarra
    limpa passa pelo amplificador: {'drive': .., 'gain': .., 'pan': -1..1, 'double': gravar duas vezes, uma
    de cada lado}). loop: o som que passa do fim (o reverb, as notas soando) volta para o começo, para
    emendar; sem loop (as fanfarras), termina depois de [tail] s. overlay: um som sintetizado (RATE, mono)
    somado por cima. Devolve o áudio estéreo [n, 2] em HI_RATE."""
    sf = soundfont or SOUNDFONT
    plain = [p for p in parts if not (len(p) > 2 and 'amp' in p[2])]
    amped = [p for p in parts if len(p) > 2 and 'amp' in p[2]]
    n = int(round(steps * 60 / bpm / 2 * HI_RATE)) + (0 if loop else int(tail * HI_RATE))
    def fit(audio):
        audio = np.vstack([audio, np.zeros((max(0, n + int(tail * HI_RATE) - len(audio)), 2))])
        out = audio[:n].copy()
        if loop:
            rest = audio[n:]
            out[: min(n, len(rest))] += rest[: min(n, len(rest))]
        return out
    out = fit(_midi_render(plain, bpm, sf)) if plain else np.zeros((n, 2))
    level = np.abs(out).max() or 1
    for program, notes, opts in amped:
        cfg = opts['amp']
        takes = []
        for take in range(2 if cfg.get('double') else 1):
            jitter = [(max(0.0, st + (0.012 * ((i * 7 + take * 3) % 5 - 2) if take else 0)), ln, m, max(1, v - (4 if take else 0))) for i, (st, ln, m, v) in enumerate(notes)]
            dry = fit(_midi_render([(program, jitter, {k: v for k, v in opts.items() if k != 'amp'})], bpm, sf)).mean(axis=1)
            takes.append(amp(np.stack([dry, dry], axis=1), cfg.get('drive', 30.0))[:, 0])
        gain = cfg.get('gain', 0.5) * level
        if len(takes) == 2:
            out[:, 0] += takes[0] * gain * 0.9
            out[:, 1] += takes[1] * gain * 0.9
        else:
            pan = cfg.get('pan', 0.0)
            out[:, 0] += takes[0] * gain * (1 - max(0, pan))
            out[:, 1] += takes[0] * gain * (1 + min(0, pan))
    if overlay is not None:
        up = np.interp(np.arange(n) * RATE / HI_RATE, np.arange(len(overlay)), overlay)
        out += up[:, None] * (np.abs(out).max() or 1)
    out = out / max(1e-9, np.abs(out).max())
    return np.tanh(out * squash) / np.tanh(squash) * 0.9


MUSIC = os.path.join(OUT, 'music')


# O volume de todas as músicas em loop (LUFS integrado, EBU R128): o da mais baixa (o tema de Kalos), para nenhuma
# precisar subir muito. Medido pelo ffmpeg (ebur128).
MUSIC_LUFS = -12.0


def loudness(pcm):
    """O volume que o ouvido sente (LUFS integrado) de um áudio estéreo em int16, pelo ffmpeg; None se não deu."""
    import re
    r = subprocess.run(['ffmpeg', '-hide_banner', '-nostats', '-f', 's16le', '-ar', str(HI_RATE), '-ac', '2', '-i', '-',
                        '-af', 'ebur128=framelog=quiet', '-f', 'null', '-'], input=pcm.tobytes(), capture_output=True)
    m = re.findall(r'I:\s+(-?[\d.]+) LUFS', r.stderr.decode(errors='ignore'))
    return float(m[-1]) if m else None


def save_hifi_loop(name, audio):
    """Uma música em loop (estéreo, instrumentos gravados): OGG Vorbis (sem o silêncio que o MP3 põe no
    começo e no fim, que vira um buraco a cada volta), com ANDROID_LOOP, e uma reserva em MP3 (web/) para os
    navegadores sem OGG. Ficam em sounds/music/, que NÃO vai dentro do app: o app baixa do site e guarda no
    celular (lib/services/music_cache.dart), então mudar uma música não precisa de app novo, só do site."""
    pcm = (np.clip(audio, -1, 1) * 32767 * 0.9).astype(np.int16)
    # Todas no mesmo volume (o que o ouvido sente, em LUFS): a troca de uma música para outra não pula de volume.
    loud = loudness(pcm)
    if loud is not None:
        gain = 10 ** ((MUSIC_LUFS - loud) / 20)
        peak = np.abs(pcm).max() / 32767
        gain = min(gain, 0.98 / peak) if peak else gain  # subir sem estourar
        pcm = np.clip(pcm.astype(np.float64) * gain, -32767, 32767).astype(np.int16)
    os.makedirs(os.path.join(MUSIC, 'web'), exist_ok=True)
    path = os.path.join(MUSIC, f'{name}.ogg')
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 's16le', '-ar', str(HI_RATE), '-ac', '2', '-i', '-',
                    '-c:a', 'libvorbis', '-q:a', '1', '-fflags', '+bitexact', '-map_metadata', '-1',
                    '-metadata', 'ANDROID_LOOP=true', path], input=pcm.tobytes(), check=True)
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 's16le', '-ar', str(HI_RATE), '-ac', '2', '-i', '-',
                    '-c:a', 'libmp3lame', '-b:a', '96k', os.path.join(MUSIC, 'web', f'{name}.mp3')], input=pcm.tobytes(), check=True)
    for old in (os.path.join(OUT, f'{name}.ogg'), os.path.join(OUT, f'{name}.mp3'), os.path.join(OUT, 'web', f'{name}.mp3')):
        if os.path.exists(old):
            os.remove(old)  # onde ficava antes (dentro do app)
    write_manifest()
    return os.path.getsize(path)


def write_manifest():
    """sounds/music/music.json: {música: hash do arquivo}. O app compara com o que guardou e baixa de novo
    só o que mudou."""
    import hashlib
    import json

    out = {}
    for f in sorted(os.listdir(MUSIC)):
        if f.endswith('.ogg'):
            with open(os.path.join(MUSIC, f), 'rb') as fh:
                out[f[:-4]] = hashlib.sha1(fh.read()).hexdigest()[:12]
    with open(os.path.join(MUSIC, 'music.json'), 'w') as fh:
        json.dump(out, fh, indent=0, sort_keys=True)
        fh.write('\n')


def _sw(step, swing):
    """O balanço: a 2ª colcheia de cada tempo atrasa [swing] de colcheia."""
    return step + swing if swing and float(step).is_integer() and int(step) % 2 else step


def lead_notes(lead, vel=90, shift=0, maxlen=2, extra=0.0, swing=0.0, keep=None):
    """A melodia (colcheias; 0 segura a anterior) em notas: (colcheia, duração, nota, força)."""
    out, i = [], 0
    while i < len(lead):
        length = 1
        while i + length < len(lead) and not lead[i + length] and length < maxlen:
            length += 1
        if lead[i] and (keep is None or keep(i)):
            out.append((_sw(i, swing), length + extra, lead[i] + shift, vel))
        i += length
    return out


def low_of(root):
    return root if root < 46 else root - 12


def each_chord(chords, fn):
    """fn(base, raiz grave, notas do acorde, índice) → notas; para todos os acordes (16 colcheias cada)."""
    out = []
    for c, (root, tones) in enumerate(chords):
        out += fn(c * 16, low_of(root), tones, c)
    return out


def hits(chords, pattern, swing=0.0):
    """Bateria: pattern(base, compasso) → [(colcheia, nota GM, força)], em cada compasso (8 colcheias)."""
    out = []
    for bar in range(len(chords) * 2):
        for step, note, vel in pattern(bar * 8, bar):
            out.append((_sw(step, swing), 0.5, note, vel))
    return out


# Bateria GM (canal 10): bumbo 36, caixa 38, palma 39, chimbal fechado 42 / aberto 46, prato 49,
# ride 51, pandeiro 54, bongô 60/61, conga 62/63, apito 72, maraca 70, shaker 82, triângulo 81.
def rock_kit(base, bar, kick=(0, 4, 5), fill=True):
    out = [(base + k, 36, 100) for k in kick] + [(base + k, 38, 95) for k in (2, 6)]
    out += [(base + k, 42, 60 if k % 2 else 75) for k in range(8)]
    if bar % 2 == 0:
        out.append((base, 49, 90))
    elif fill:
        out += [(base + 6 + r / 2, 38, 70 + 8 * r) for r in range(4)]
    return out


def battle_parts(lead, chords, lead_prog=61, double=48, bass=33, ostinato=48, kit=rock_kit, extra=()):
    """Orquestra de batalha: a melodia (metais), cordas dobrando, cordas em ostinato, baixo em colcheias,
    tímpano na entrada do acorde e bateria."""
    parts = [
        (lead_prog, lead_notes(lead, 100, extra=0.1)),
        (double, lead_notes(lead, 55, 12, extra=0.1)),
        (ostinato, each_chord(chords, lambda b, r, t, c: [(b + k / 2, 0.45, [t[0], t[1], t[0], t[2]][k % 4] - 12, 50 if k % 4 else 62) for k in range(32)])),
        (bass, each_chord(chords, lambda b, r, t, c: [(b + k, 0.9, r + (12 if k % 4 == 3 else 0), 88) for k in range(16)])),
        (47, each_chord(chords, lambda b, r, t, c: [(b, 2, r, 85), (b + 8, 2, r, 70)])),
        ('drums', hits(chords, kit)),
    ]
    return parts + list(extra)


def kalos_orchestra():
    """Kalos com instrumentos gravados: francês melancólico e operístico, que evolui em 4 partes (piano
    solo; + violoncelo e harpa; + acordeão e cordas; + voz, tímpano e um tom acima). No fim, a última frase
    resolve na tônica: a voz segura a nota, as cordas crescem, glissando de harpa, rufar do tímpano e o
    piano sozinho, suave, levando de volta ao começo. Melodia original."""
    tonic, mode, prog, bpm = 62, 'minor', [0, 3, 6, 2], 84
    lead, chords = compose('map-kalos', tonic, mode, prog)
    lead, chords = lead * 2, chords * 2
    lead = [m + 2 if m and i >= len(lead) * 3 // 4 else m for i, m in enumerate(lead)]
    quarter = len(chords) * 3 // 4
    chords = [(r + 2, [m + 2 for m in tones]) if c >= quarter else (r, tones) for c, (r, tones) in enumerate(chords)]
    steps = len(lead)
    end = steps - 16  # a última frase: o final
    home_root, home = chords[0][0] + 2, [m + 2 for m in chords[0][1]]  # a tônica, um tom acima
    chords[-1] = (home_root, home)
    part_of = lambda step: step * 4 // steps
    piano, cello, harp, accordion, strings, voice_, timpani = [], [], [], [], [], [], []
    for i, length, note, vel in lead_notes(lead, 78, maxlen=4, keep=lambda i: i < end):
        part = part_of(i)
        piano.append((i, length + 0.5, note, vel))
        if part >= 2:
            accordion.append((i, length, note, 42))
        if part >= 3:
            voice_.append((i, length + 0.3, note, 92))
    for c, (root, tones) in enumerate(chords):
        base = c * 16
        part = part_of(base)
        low = low_of(root)
        last = base >= end
        piano.append((base, 16, low, 58))
        if not last:
            for k in range(2, 16, 2):
                m = [tones[0], tones[1], tones[2], tones[1]][(k // 2) % 4] - 12
                piano.append((base + k, 3, m, 46))
        if part >= 1 and not last:
            cello.append((base, 8, tones[1] - 24, 70))
            cello.append((base + 8, 8, tones[2] - 24, 70))
            for k in range(16):
                harp.append((base + k, 2, [tones[0], tones[1], tones[2], tones[0] + 12][k % 4] + 12, 42))
        if part >= 2 and not last:
            for m in tones:
                strings.append((base, 16, m, 48))
        if part >= 3 and not last:
            for r in range(6):
                timpani.append((base + r / 3, 0.3, low, 40 + 8 * r))
    # O final: rufar crescendo até a tônica, a voz segurando a nota de cima, cordas crescendo, glissando de
    # harpa e, nos últimos tempos, o piano sozinho e suave (de volta ao começo, que é piano solo).
    top = home[0] + 12
    for r in range(12):
        timpani.append((end - 4 + r / 3, 0.3, low_of(home_root), 35 + 6 * r))
    timpani.append((end, 4, low_of(home_root), 110))
    voice_.append((end, 11, top, 100))
    piano += [(end, 10, m, 80) for m in (low_of(home_root), *home, top)]
    for v, m in ((60, home[0]), (70, home[1]), (80, home[2]), (85, top)):
        strings.append((end, 11, m, v))
    cello.append((end, 11, home[0] - 24, 85))
    gliss = sorted({m + 12 * o for o in (0, 1, 2) for m in home})
    for j, m in enumerate(gliss):
        harp.append((end + 1 + j * 0.25, 4, m, 55 + 3 * j))
    for j, m in enumerate((home[2], home[1], home[0], home[2] - 12)):  # o piano suave, descendo
        piano.append((end + 12 + j, 2.5, m, 38))
    # GM: 0 piano de cauda, 42 violoncelo, 46 harpa, 21 acordeão, 48 cordas, 53 voz ("oohs"), 47 tímpano.
    parts = [(0, piano), (42, cello), (46, harp), (21, accordion), (48, strings), (53, voice_), (47, timpani)]
    return render(parts, bpm, steps)


def map_song(region):
    """A melodia e os acordes originais do mapa (os mesmos de MAP_THEMES) e o andamento."""
    tonic, mode, prog, bpm, *_ = MAP_THEMES[region]
    lead, chords = compose(f'map-{region}', tonic, mode, prog)
    return lead, chords, bpm


def kanto_orchestra():
    """Kanto: nostalgia de Game Boy, agora com piano e baixo gravados: a melodia na onda quadrada (GM 80)
    com o eco (a mesma nota, mais baixa e atrasada), piano macio nos acordes, baixo e bateria leve."""
    lead, chords, bpm = map_song('kanto')
    melody = lead_notes(lead, 82, extra=0.2)
    parts = [
        (80, melody, {'cc': {1: 30}}),
        (80, [(st + 0.75, ln, m, 36) for st, ln, m, v in melody]),  # o eco
        (0, each_chord(chords, lambda b, r, t, c: [(b + k, 9, m, 48) for k in (0, 8) for m in t])),
        (33, each_chord(chords, lambda b, r, t, c: [(b + k, 0.9, r + (12 if k % 2 else 0), 72) for k in range(16)])),
        (10, each_chord(chords, lambda b, r, t, c: [(b + k, 1, [t[0], t[1], t[2], t[1]][k % 4] + 12, 34) for k in range(0, 16, 2)])),
        ('drums', hits(chords, lambda b, bar: [(b, 36, 70)] + [(b + k, 42, 45) for k in (1, 3, 5, 7)])),
    ]
    return render(parts, bpm, len(lead))


def johto_orchestra():
    """Johto (personagem secundário): flauta na melodia, koto dedilhado, violão e baixo acústico, shaker."""
    lead, chords, bpm = map_song('johto')
    parts = [
        (73, lead_notes(lead, 88, extra=0.3), {'cc': {1: 25}}),
        (107, each_chord(chords, lambda b, r, t, c: [(b + k, 2.5, [t[0], t[1], t[2], t[1]][k % 4], 60 if k % 2 == 0 else 45) for k in range(16)])),
        (24, each_chord(chords, lambda b, r, t, c: [(b + k, 3, m, 40) for k in (0, 8) for m in t])),
        (32, each_chord(chords, lambda b, r, t, c: [(b + k, 3.5, r + 12, 75) for k in range(0, 16, 4)])),
        ('drums', hits(chords, lambda b, bar: [(b + k, 82, 45) for k in (1, 3, 5, 7)])),
    ]
    return render(parts, bpm, len(lead))


def hoenn_orchestra():
    """Hoenn: a batalha lendária. Metais e trompas em oitavas, cordas em trêmulo e ostinato, contrabaixo,
    coro, tímpanos e taiko; e, sintetizados por cima, a chuva, o trovão (Kyogre) e a terra roncando (Groudon)."""
    lead, chords, bpm = map_song('hoenn')
    step = 60 / bpm / 2
    n = int(RATE * len(lead) * step)
    rain = np.random.default_rng(77).standard_normal(n)
    sky = (rain - smooth(rain, 6)) * 0.02
    for bar, seed in ((2, 3), (10, 4)):
        m = int(RATE * 2.5)
        i = int(bar * 8 * step * RATE)
        sky[i:i + m] += (smooth(np.random.default_rng(seed).standard_normal(m), 60) * np.exp(-np.linspace(0, 4, m)) * 1.6)[: n - i]
    for bar, seed in ((6, 8), (14, 9)):
        m = int(RATE * 3.0)
        i = int(bar * 8 * step * RATE)
        sky[i:i + m] += (smooth(np.random.default_rng(seed).standard_normal(m), 200) * np.sin(np.linspace(0, np.pi, m)) * 5.0)[: n - i]
    parts = [
        (61, lead_notes(lead, 105, -12, extra=0.1)),
        (60, lead_notes(lead, 80, 0, extra=0.1)),
        (48, lead_notes(lead, 55, 12, extra=0.1)),
        (44, each_chord(chords, lambda b, r, t, c: [(b + k / 2, 0.45, [t[0], t[1], t[0], t[2]][k % 4] - 12, 55 if k % 4 else 68) for k in range(32)])),
        (43, each_chord(chords, lambda b, r, t, c: [(b + k, 0.9, r + (12 if k % 4 == 3 else 0), 85) for k in range(16)])),
        (52, each_chord(chords, lambda b, r, t, c: [(b, 16, m, 55) for m in t])),
        (47, each_chord(chords, lambda b, r, t, c: [(b + bar * 8 + k, 1, r, v) for bar in (0, 1) for k, v in ((0, 110), (3, 80), (4, 100))])),
        (116, each_chord(chords, lambda b, r, t, c: [(b + bar * 8 + k, 1, r + 12, 95) for bar in (0, 1) for k in (0, 4)])),
        ('drums', hits(chords, lambda b, bar: ([(b, 49, 85)] if bar % 2 == 0 else [(b + 5 + r / 2, 38, 55 + 10 * r) for r in range(6)]))),
    ]
    return render(parts, bpm, len(lead), overlay=sky * 0.35)


def sinnoh_orchestra():
    """Sinnoh: suspense, só piano de cauda gravado. A nota grave no pedal, duas notas a meio tom se
    repetindo baixinho, o acorde quebrado devagar com o trítono no fim da frase e a melodia esparsa no agudo."""
    lead, chords, bpm = map_song('sinnoh')
    piano = lead_notes(lead, 76, 12, keep=lambda i: i % 2 == 0, extra=4)
    def left(b, r, t, c):
        low = r - 12 if r >= 40 else r
        out = [(b, 16, low, 80)]
        out += [(b + k, 1.4, low + 12 + (1 if k % 2 else 0), int(38 + 22 * k / 15)) for k in range(16)]
        out += [(b + k, 4, [t[0], t[2], t[1] + 12, (t[0] + 18) if k >= 12 else t[2] + 12][(k // 2) % 4], 52) for k in range(0, 16, 2)]
        return out
    parts = [(0, piano + each_chord(chords, left), {'cc': {64: 0}})]
    return render(parts, bpm, len(lead))


def hisui_orchestra():
    """Hisui: o Japão antigo (a era Meiji de Legends: Arceus). O shakuhachi na melodia, o koto dedilhando o acorde,
    o shamisen nos contratempos, as cordas de fundo e o taikô grave a cada compasso, como ao longe."""
    lead, chords, bpm = map_song('hisui')
    parts = [
        (77, lead_notes(lead, 86, extra=0.3), {'cc': {1: 30}}),
        (107, each_chord(chords, lambda b, r, t, c: [(b + k, 1.6, [t[0], t[1], t[2], t[0] + 12, t[2], t[1]][k % 6] + 12, 58 if k % 4 else 70) for k in range(16)])),
        (106, each_chord(chords, lambda b, r, t, c: [(b + k, 0.6, t[0] + 12, 50) for k in (2, 6, 10, 14)])),
        (49, each_chord(chords, lambda b, r, t, c: [(b, 16, m - 12, 44) for m in t])),
        (116, each_chord(chords, lambda b, r, t, c: [(b + k, 2, 36, v) for k, v in ((0, 92), (8, 70), (11, 54))])),
    ]
    return render(parts, bpm, len(lead))


# (melodia, dobra, acordes, baixo, percussão grave) de cada mapa novo: o mesmo arranjo calmo, com os instrumentos do lugar.
EXTRA_MAP_SOUNDS = {
    'orre': (22, 78, 25, 32, 116), 'fiore': (73, 24, 48, 33, 0), 'almia': (71, 45, 0, 32, 0),
    'oblivia': (12, 75, 46, 33, 116), 'kitakami': (77, 107, 49, 32, 116), 'blueberry': (81, 4, 89, 38, 0),
    'sevii': (12, 73, 24, 33, 0),
}


def extra_map_orchestra(region):
    """Os mapas das regiões fora da série principal (Orre, Fiore, Almia, Oblivia) e das expansões (Kitakami, Blueberry):
    a melodia original no instrumento do lugar, a dobra uma oitava acima, os acordes dedilhados, o baixo e, onde tem,
    o tambor grave a cada compasso."""
    lead, chords, bpm = map_song(region)
    mel, double, comp, bass, drum = EXTRA_MAP_SOUNDS[region]
    parts = [
        (mel, lead_notes(lead, 88, extra=0.2)),
        (double, lead_notes(lead, 44, 12, keep=lambda i: i % 2 == 0)),
        (comp, each_chord(chords, lambda b, r, t, c: [(b + k, 1.4, [t[0], t[1], t[2], t[1]][(k // 2) % 4], 56 if k % 4 else 66) for k in range(0, 16, 2)])),
        (bass, each_chord(chords, lambda b, r, t, c: [(b + k, 2, r + (7 if k == 8 else 0), 80) for k in (0, 4, 8, 12)])),
    ]
    if drum:
        parts.append((drum, each_chord(chords, lambda b, r, t, c: [(b + k, 2, 36, v) for k, v in ((0, 88), (8, 66))])))
    else:
        parts.append(('drums', hits(chords, lambda b, bar: [(b + k, 36, 64) for k in (0, 4)] + [(b + k, 38, 46) for k in (2, 6)] + [(b + k, 42, 34) for k in range(8)])))
    return render(parts, bpm, len(lead))


def unova_orchestra():
    """Unova: porto à noite com clima de boate. Baixo sintetizado saltitante, melodia em serra, a linha em
    espiral, pad e batida de boate (bumbo em todo tempo, palmas, chimbal aberto)."""
    lead, chords, bpm = map_song('unova')
    def bass(b, r, t, c):
        return [(b + bar * 8 + k, ln * 0.95, m, 100) for bar in (0, 1) for k, m, ln in ((0, r, 3), (3, r + 12, 1), (4, r, 2), (6, r + 10, 1), (7, r + 12, 1))]
    def spiral(b, r, t, c):
        sp = [t[0], t[1], t[2], t[0] + 12, t[1] + 12, t[2], t[1], t[0] + 12]
        return [(b + k / 2, 0.4, sp[k % 8] + (12 if (k // 8) % 2 else 0), 38) for k in range(32)]
    parts = [
        (81, lead_notes(lead, 88, extra=0.05), {'cc': {1: 20}}),
        (39, each_chord(chords, bass)),
        (82, each_chord(chords, spiral)),
        (89, each_chord(chords, lambda b, r, t, c: [(b, 16, m - 12, 50) for m in t])),
        ('drums', hits(chords, lambda b, bar: [(b + k, 36, 105) for k in (0, 2, 4, 6)] + [(b + k, 39, 85) for k in (2, 6)] + [(b + k, 46, 60) for k in (1, 3, 5, 7)] + [(b + k / 2, 42, 40) for k in range(16)])),
    ]
    return render(parts, bpm, len(lead))


def alola_orchestra():
    """Alola: praia havaiana. Guitarra deslizando (pitch bend, como a lap steel), ukulele, baixo acústico,
    maracas e bongôs e o mar ao fundo."""
    lead, chords, bpm = map_song('alola')
    swing = 0.15
    step_s = 60 / bpm / 2
    def uke(b, r, t, c):
        strings_ = [t[0] + 12, t[1] + 12, t[2] + 12, t[0] + 24]
        out = []
        for bar in (0, 1):
            for k, down, v in ((0, True, 70), (2, True, 60), (3, False, 45), (5, False, 45), (6, True, 60), (7, False, 45)):
                for j, m in enumerate(strings_ if down else strings_[::-1]):
                    out.append((_sw(b + bar * 8 + k, swing) + j * 0.012 / step_s, 1.3, m, v))
        return out
    parts = [
        (26, lead_notes(lead, 92, swing=swing, extra=0.4), {'glide': True, 'cc': {1: 45}}),
        (24, each_chord(chords, uke)),
        (32, each_chord(chords, lambda b, r, t, c: [(_sw(b + bar * 8 + k, swing), 1.8, m, 80) for bar in (0, 1) for k, m in ((0, r), (3, r + 7), (4, r + 12))])),
        (122, [(0, len(lead), 60, 45)]),
        ('drums', hits(chords, lambda b, bar: [(b + k / 2, 70, 40 if k % 2 else 55) for k in range(16)] + [(b, 61, 75), (b + 3, 60, 65), (b + 4, 61, 70)], swing)),
    ]
    return render(parts, bpm, len(lead))


def galar_orchestra():
    """Galar: abertura de anime de futebol. Guitarra distorcida (aberta na entrada do acorde, abafada em
    colcheias), melodia em sintetizador com metais, baixo, bateria de rock, apito, torcida e palmas."""
    lead, chords, bpm = map_song('galar')
    def guitar(b, r, t, c):
        out = [(b, 3, m, 100) for m in (r + 12, r + 19, r + 24)]
        out += [(b + k, 0.45, m, 70 if k % 2 == 0 else 58) for k in range(3, 16) for m in (r + 12, r + 19)]
        return out
    def kit(b, bar):
        out = rock_kit(b, bar)
        if bar % 4 == 3:
            out += [(b + k, 39, 95) for k in (5, 6, 7)]
        if bar == 0:
            out.append((b, 72, 110))  # o apito do juiz
        return out
    parts = [
        (81, lead_notes(lead, 92, extra=0.05)),
        (61, lead_notes(lead, 75, extra=0.05)),
        (30, each_chord(chords, guitar)),
        (34, each_chord(chords, lambda b, r, t, c: [(b + k, 0.9, r, 95) for k in range(16)])),
        (126, [(0, len(lead), 60, 30)]),
        ('drums', hits(chords, kit)),
    ]
    return render(parts, bpm, len(lead))


def paldea_orchestra():
    """Paldea: escola de anime. Flauta doce e glockenspiel, piano saltitante, pizzicato, baixo, bateria leve
    e o sinal da escola nos sinos tubulares (Carrilhão de Westminster, domínio público)."""
    lead, chords, bpm = map_song('paldea')
    tonic = chords[0][1][0]
    while tonic < 60:
        tonic += 12
    chime = [(j * 4, 4, tonic + d, 85) for j, d in enumerate((4, 0, 2, -5, -5, 2, 4, 0))]
    parts = [
        (74, lead_notes(lead, 90, extra=0.15)),
        (9, lead_notes(lead, 48, 12)),
        (0, each_chord(chords, lambda b, r, t, c: [(b + bar * 8 + k, 1.2, m, v) for bar in (0, 1) for k, v in ((0, 62), (3, 48), (4, 56), (6, 48)) for m in t])),
        (45, each_chord(chords, lambda b, r, t, c: [(b + bar * 8 + k + 1, 0.5, [t[0], t[2], t[1], t[2]][k // 2] + 12, 55) for bar in (0, 1) for k in range(0, 8, 2)])),
        (32, each_chord(chords, lambda b, r, t, c: [(b + bar * 8 + k, 2, m, 80) for bar in (0, 1) for k, m in ((0, r), (4, r + 7))])),
        (14, chime),
        ('drums', hits(chords, lambda b, bar: [(b + k, 36, 70) for k in (0, 4)] + [(b + k, 38, 50) for k in (2, 6)] + [(b + k, 39, 40) for k in (2, 6)] + [(b + k, 82, 40) for k in range(8)])),
    ]
    return render(parts, bpm, len(lead))


# Os lugares da Battle Factory (selvagens e treinadores da rota): a orquestra de batalha com os
# instrumentos do lugar — (melodia, dobra, ostinato, baixo).
PLACE_SOUNDS = {
    'field': (73, 56, 25, 33),       # flauta e trompete, violão, baixo
    'forest': (68, 71, 46, 32),      # oboé e clarinete, harpa, baixo acústico
    'sea': (114, 11, 48, 33),        # steel drum e vibrafone, cordas
    'cave': (60, 8, 44, 43),         # trompa e celesta, cordas em trêmulo, contrabaixo
    'mountain': (60, 56, 48, 43),    # trompa e trompete
    'desert': (68, 104, 48, 32),     # oboé e cítara
    'city': (81, 0, 62, 38),         # sintetizador, piano, metais de sintetizador, baixo sintetizado
    'spooky': (6, 52, 8, 43),        # cravo e coro, celesta
}


def battle_tracks(extras=False):
    """{nome: áudio} do tema de batalha de cada região (líderes e batalhas comuns), com orquestra. Com
    [extras], também a batalha comum antiga, os campeões e os lugares (fora do app por enquanto: os temas
    de campeão estão sendo refeitos; as batalhas comuns e os lugares tocam o tema da região)."""
    out = {}
    for region, (tonic, mode, prog, bpm, duty) in REGION_THEMES.items():
        lead, chords = compose(region, tonic, mode, prog)
        out[f'gym_{region}'] = render(battle_parts(lead, chords, 61, 48, 33, 48), bpm, len(lead))
    if not extras:
        return out
    out['battle_music'] = render(battle_parts(LEAD, CHORDS, 56, 48, 33, 48, extra=[(29, each_chord(CHORDS, lambda b, r, t, c: [(b + k, 0.45, m, 60) for k in (1, 3, 5, 7, 9, 11, 13, 15) for m in (r + 12, r + 19)]))]), BPM, len(LEAD))
    for champion, (tonic, mode, prog, bpm, duty, voice) in CHAMPION_THEMES.items():
        lead, chords = compose(champion, tonic, mode, prog, climax=True)
        choir_ = (52, each_chord(chords, lambda b, r, t, c: [(b, 16, m, 55) for m in t]))
        if voice == 'piano':  # Cynthia e Diantha: o piano na frente
            parts = battle_parts(lead, chords, 0, 48, 43, 48, extra=[choir_])
        else:
            parts = battle_parts(lead, chords, 61, 56, 33, 48, extra=[choir_], kit=lambda b, bar: rock_kit(b, bar, (0, 2, 4, 6)))
        out[f'champion_{champion}'] = render(parts, bpm, len(lead))
    for place, (tonic, mode, prog, bpm, duty) in PLACE_THEMES.items():
        lead, chords = compose(f'place-{place}', tonic, mode, prog)
        melody, double, ost, bass = PLACE_SOUNDS[place]
        out[f'place_{place}'] = render(battle_parts(lead, chords, melody, double, bass, ost), bpm, len(lead))
    return out


def champion_song(name):
    """A melodia e os acordes originais do campeão (os mesmos de CHAMPION_THEMES) e o andamento."""
    tonic, mode, prog, bpm, *_ = CHAMPION_THEMES[name]
    lead, chords = compose(name, tonic, mode, prog, climax=True)
    return lead, chords, bpm


def blue_orchestra():
    """Blue (Kanto), o rival convencido: rock de guitarra com uma pitada de Game Boy. A melodia na onda
    quadrada dobrada pela guitarra solo, guitarra base abafada, baixo de palheta, metais nos contratempos,
    arpejo rápido na onda quadrada e bateria de rock."""
    lead, chords, bpm = champion_song('blue')
    def rhythm(b, r, t, c):
        out = [(b, 1.5, m, 105) for m in (r + 12, r + 19, r + 24)]
        out += [(b + k, 0.4, m, 80 if k % 2 == 0 else 66) for k in range(2, 16) for m in (r + 12, r + 19)]
        return out
    def stabs(b, r, t, c):
        return [(b + bar * 8 + k, 0.4, m, 92) for bar in (0, 1) for k in (3, 7) for m in t]
    def kit(b, bar):
        out = [(b + k, 36, 105) for k in (0, 3, 4)] + [(b + k, 38, 100) for k in (2, 6)]
        out += [(b + k / 2, 42, 55 if k % 2 else 72) for k in range(16)]
        if bar % 2 == 0:
            out.append((b, 49, 100))
        else:
            out += [(b + 6 + r / 4, 38 if r % 2 else 45, 70 + 6 * r) for r in range(8)]
        return out
    parts = [
        (80, lead_notes(lead, 88, extra=0.05)),
        (29, lead_notes(lead, 82, 12, extra=0.05), {'cc': {1: 20}}),
        (30, each_chord(chords, rhythm)),
        (34, each_chord(chords, lambda b, r, t, c: [(b + k, 0.9, r + (12 if k % 4 == 2 else 0), 98) for k in range(16)])),
        (61, each_chord(chords, stabs)),
        (80, each_chord(chords, lambda b, r, t, c: [(b + k / 2, 0.4, [t[0], t[1], t[2], t[1]][k % 4] - 12, 40) for k in range(32)])),
        ('drums', hits(chords, kit)),
    ]
    return render(parts, bpm, len(lead))


def lance_orchestra():
    """Lance (Johto), o mestre dos dragões: orquestra heroica. Trompas na melodia com trompetes uma oitava
    acima, trombones nos acordes, tuba no baixo, cordas em ostinato, coro, tímpanos e taiko (as asas) e
    caixa de marcha com pratos."""
    lead, chords, bpm = champion_song('lance')
    def kit(b, bar):
        out = [(b + k, 38, 70 if k % 2 else 85) for k in range(0, 8, 2)]
        if bar % 2 == 0:
            out += [(b, 49, 105), (b, 57, 80)]
        else:
            out += [(b + 6 + r / 4, 38, 60 + 7 * r) for r in range(8)]
        return out
    parts = [
        (60, lead_notes(lead, 108, extra=0.1)),
        (56, lead_notes(lead, 80, 12, extra=0.1)),
        (57, each_chord(chords, lambda b, r, t, c: [(b + k, 1.6, m, 88) for k in (0, 4, 8, 12) for m in (t[0] - 12, t[1] - 12)])),
        (58, each_chord(chords, lambda b, r, t, c: [(b + k, 1.8, r, 100) for k in range(0, 16, 2)])),
        (48, each_chord(chords, lambda b, r, t, c: [(b + k / 2, 0.45, [t[0], t[1], t[2], t[1]][k % 4], 52 if k % 4 else 66) for k in range(32)])),
        (52, each_chord(chords, lambda b, r, t, c: [(b, 16, m, 58) for m in t])),
        (47, each_chord(chords, lambda b, r, t, c: [(b + bar * 8 + k, 1, r, v) for bar in (0, 1) for k, v in ((0, 115), (3, 85), (4, 105), (6, 80))])),
        (116, each_chord(chords, lambda b, r, t, c: [(b + bar * 8 + k, 1, r + 12, 100) for bar in (0, 1) for k in (0, 4)])),
        ('drums', hits(chords, kit)),
    ]
    return render(parts, bpm, len(lead))


def steven_orchestra():
    """Steven (Hoenn), elegante, das pedras e do aço: o piano na melodia com as cordas, a celesta e os sinos
    (o brilho dos cristais), metais nobres nos acordes, contrabaixo e bateria marcada."""
    lead, chords, bpm = champion_song('steven')
    parts = [
        (0, lead_notes(lead, 100, extra=0.2)),
        (48, lead_notes(lead, 62, 12, extra=0.2)),
        (8, each_chord(chords, lambda b, r, t, c: [(b + k / 2, 0.5, [t[0], t[1], t[2], t[1]][k % 4] + 12, 46) for k in range(32)])),
        (14, each_chord(chords, lambda b, r, t, c: [(b, 6, t[0] + 12, 70), (b + 8, 6, t[2] + 12, 60)])),
        (61, each_chord(chords, lambda b, r, t, c: [(b + k, 2, m, 82) for k in (0, 6, 8, 14) for m in t])),
        (43, each_chord(chords, lambda b, r, t, c: [(b + k, 0.9, r + (12 if k % 4 == 3 else 0), 92) for k in range(16)])),
        (47, each_chord(chords, lambda b, r, t, c: [(b, 2, r, 100), (b + 8, 2, r, 80)])),
        ('drums', hits(chords, lambda b, bar: rock_kit(b, bar, (0, 3, 4)))),
    ]
    return render(parts, bpm, len(lead))


def wallace_orchestra():
    """Wallace (Hoenn, Emerald), o artista da água: a harpa em cascata, a flauta e o violino na melodia, o
    vibrafone (gotas), as cordas fluindo, contrabaixo, tímpano e pratos; dramático e elegante."""
    lead, chords, bpm = champion_song('wallace')
    def cascade(b, r, t, c):
        notes = sorted({m + 12 * o for o in (0, 1) for m in t})
        return [(b + k / 2, 1.5, (notes + notes[::-1][1:-1])[k % (2 * len(notes) - 2)] + 12, 50) for k in range(32)]
    parts = [
        (73, lead_notes(lead, 96, 12, extra=0.2), {'cc': {1: 25}}),
        (40, lead_notes(lead, 78, extra=0.2)),
        (46, each_chord(chords, cascade)),
        (11, each_chord(chords, lambda b, r, t, c: [(b + k, 2, m, 58) for k in (0, 3, 6, 8, 11, 14) for m in (t[0] + 12, t[2] + 12)])),
        (48, each_chord(chords, lambda b, r, t, c: [(b, 16, m, 60) for m in t])),
        (43, each_chord(chords, lambda b, r, t, c: [(b + k, 1.8, r, 92) for k in range(0, 16, 2)])),
        (47, each_chord(chords, lambda b, r, t, c: [(b + r_ / 3, 0.3, r, 45 + 7 * r_) for r_ in range(6)] + [(b + 2, 2, r, 105)])),
        ('drums', hits(chords, lambda b, bar: [(b + k, 36, 95) for k in (0, 4)] + [(b + k, 38, 82) for k in (2, 6)] + [(b + k, 51, 60) for k in range(8)] + ([(b, 49, 95)] if bar % 2 == 0 else []))),
    ]
    return render(parts, bpm, len(lead))


def cynthia_orchestra():
    """Cynthia (Sinnoh): o suspense do piano de Sinnoh virando batalha. O piano na melodia (dobrado uma
    oitava abaixo), a mão esquerda rápida com as duas notas a meio tom (o motivo de Sinnoh), cordas em
    trêmulo, violoncelos, coro, contrabaixo, tímpanos e bateria com o bumbo em todo tempo."""
    lead, chords, bpm = champion_song('cynthia')
    def left(b, r, t, c):
        low = r if r >= 40 else r + 12
        return [(b + k / 2, 0.42, low + (1 if k % 2 else 0), 70 if k % 4 == 0 else 56) for k in range(32)]
    parts = [
        (0, lead_notes(lead, 112, extra=0.1) + lead_notes(lead, 84, -12, extra=0.1) + each_chord(chords, left)),
        (44, each_chord(chords, lambda b, r, t, c: [(b, 16, m + 12, 50) for m in t])),
        (42, each_chord(chords, lambda b, r, t, c: [(b + k, 1, t[0] - 12, 90) for k in (0, 3, 6, 8, 11, 14)])),
        (52, each_chord(chords, lambda b, r, t, c: [(b, 16, m, 62) for m in t])),
        (43, each_chord(chords, lambda b, r, t, c: [(b + k, 0.9, r, 92) for k in range(16)])),
        (47, each_chord(chords, lambda b, r, t, c: [(b + bar * 8 + k, 1, r, v) for bar in (0, 1) for k, v in ((0, 112), (3, 80), (6, 90))])),
        ('drums', hits(chords, lambda b, bar: rock_kit(b, bar, (0, 2, 4, 6)))),
    ]
    return render(parts, bpm, len(lead))


def alder_orchestra():
    """Alder (Unova, Black/White), o guerreiro andarilho: trompete na melodia, violão flamenco em rasgueado,
    taiko e tom-tons tribais, congas, trompas (o chamado de guerra), metais curtos e baixo."""
    lead, chords, bpm = champion_song('alder')
    def rasgueado(b, r, t, c):
        strings_ = [r + 12, t[0], t[1], t[2], t[0] + 12]
        out = []
        for bar in (0, 1):
            for k, v in ((0, 85), (1.5, 60), (2, 75), (3, 65), (4, 85), (5.5, 60), (6, 75), (7, 65)):
                for j, m in enumerate(strings_):
                    out.append((b + bar * 8 + k + j * 0.04, 1.2, m, v))
        return out
    def kit(b, bar):
        out = [(b + k, 41, 100) for k in (0, 3)] + [(b + k, 45, 90) for k in (4, 6)] + [(b + 7, 48, 95)]
        out += [(b + k / 2, 63 if k % 4 else 62, 70) for k in range(16)]
        if bar % 2 == 0:
            out.append((b, 49, 95))
        return out
    parts = [
        (56, lead_notes(lead, 105, extra=0.1)),
        (24, each_chord(chords, rasgueado)),
        (116, each_chord(chords, lambda b, r, t, c: [(b + bar * 8 + k, 1, r + 12, v) for bar in (0, 1) for k, v in ((0, 115), (2, 85), (3, 95), (6, 100))])),
        (60, each_chord(chords, lambda b, r, t, c: [(b, 6, t[0], 85), (b, 6, t[2], 80), (b + 8, 6, t[1], 80)])),
        (61, each_chord(chords, lambda b, r, t, c: [(b + bar * 8 + k, 0.5, m, 90) for bar in (0, 1) for k in (3, 7) for m in t])),
        (33, each_chord(chords, lambda b, r, t, c: [(b + k, 0.9, r + (7 if k % 4 == 2 else 0), 95) for k in range(16)])),
        ('drums', hits(chords, kit)),
    ]
    return render(parts, bpm, len(lead))


def iris_orchestra():
    """Iris (Unova, Black 2/White 2), a jovem dos dragões: pop/rock animado. Sintetizador e trompete na
    melodia, guitarra com overdrive, baixo slap, bateria com palmas, glockenspiel e trompas crescendo."""
    lead, chords, bpm = champion_song('iris')
    def kit(b, bar):
        out = [(b + k, 36, 105) for k in (0, 3, 4)] + [(b + k, 38, 95) for k in (2, 6)] + [(b + k, 39, 70) for k in (2, 6)]
        out += [(b + k, 42, 60 if k % 2 else 72) for k in range(8)]
        if bar % 2 == 0:
            out.append((b, 49, 95))
        else:
            out += [(b + 6 + r / 2, 38, 70 + 8 * r) for r in range(4)]
        return out
    parts = [
        (81, lead_notes(lead, 88, extra=0.05)),
        (56, lead_notes(lead, 82, extra=0.05)),
        (29, each_chord(chords, lambda b, r, t, c: [(b + k, 0.9 if k % 4 else 1.8, m, 78) for k in range(0, 16, 2) for m in (r + 12, r + 19, r + 24)])),
        (36, each_chord(chords, lambda b, r, t, c: [(b + bar * 8 + k, 0.5, m, 100) for bar in (0, 1) for k, m in ((0, r), (2, r + 12), (3, r), (4, r + 7), (6, r + 12), (7, r + 10))])),
        (9, each_chord(chords, lambda b, r, t, c: [(b + k, 1, [t[0], t[1], t[2], t[1]][(k // 2) % 4] + 12, 52) for k in range(0, 16, 2)])),
        (60, each_chord(chords, lambda b, r, t, c: [(b + 8, 8, m, 70) for m in (t[0], t[2])])),
        ('drums', hits(chords, kit)),
    ]
    return render(parts, bpm, len(lead))


def diantha_orchestra():
    """Diantha (Kalos), a atriz: orquestra de cinema, elegante, francesa e dramática. O violino na melodia com
    a voz uma oitava acima, o acordeão discreto (o toque de Kalos), cordas em spiccato, trompas em contracanto,
    piano em acordes quebrados, harpa em glissando, tímpanos, caixa orquestral e pratos."""
    lead, chords, bpm = champion_song('diantha')
    def gliss(b, r, t, c):
        notes = sorted({m + 12 * o for o in (0, 1, 2) for m in t})
        return [(b + j * 0.15, 3, m, 50 + 3 * j) for j, m in enumerate(notes)]
    parts = [
        (40, lead_notes(lead, 104, extra=0.15), {'cc': {1: 30}}),
        (53, lead_notes(lead, 80, 12, extra=0.2)),
        (21, lead_notes(lead, 36, extra=0.1)),
        (48, each_chord(chords, lambda b, r, t, c: [(b + k / 2, 0.3, [t[0], t[2], t[1], t[2]][k % 4] - 12, 66 if k % 4 == 0 else 52) for k in range(32)])),
        (60, each_chord(chords, lambda b, r, t, c: [(b, 7, t[1], 80), (b + 8, 7, t[2], 78)])),
        (0, each_chord(chords, lambda b, r, t, c: [(b + k, 1.5, [t[0], t[1], t[2], t[1]][(k // 2) % 4], 55) for k in range(0, 16, 2)])),
        (46, each_chord(chords, gliss)),
        (43, each_chord(chords, lambda b, r, t, c: [(b + k, 1.8, r, 92) for k in range(0, 16, 2)])),
        (47, each_chord(chords, lambda b, r, t, c: [(b, 2, r, 108), (b + 6, 1, r, 80), (b + 8, 2, r, 95)])),
        ('drums', hits(chords, lambda b, bar: [(b + k, 38, 72 if k % 4 else 88) for k in range(0, 8, 2)] + [(b + k, 36, 90) for k in (0, 4)] + ([(b, 49, 95)] if bar % 2 == 0 else [(b + 6 + r / 4, 38, 60 + 7 * r) for r in range(8)]))),
    ]
    return render(parts, bpm, len(lead))


def kukui_orchestra():
    """Kukui (Alola), o professor lutador: rock havaiano. Guitarra com overdrive deslizando na melodia,
    ukulele em rasgueado rápido, pahu (taiko), bongôs e maracas com bateria de rock, baixo e metais curtos."""
    lead, chords, bpm = champion_song('kukui')
    step_s = 60 / bpm / 2
    def uke(b, r, t, c):
        strings_ = [t[0] + 12, t[1] + 12, t[2] + 12, t[0] + 24]
        out = []
        for k in range(16):
            down = k % 2 == 0
            for j, m in enumerate(strings_ if down else strings_[::-1]):
                out.append((b + k + j * 0.01 / step_s, 0.9, m, 70 if down else 52))
        return out
    def kit(b, bar):
        out = [(b + k, 36, 100) for k in (0, 3, 4)] + [(b + k, 38, 92) for k in (2, 6)]
        out += [(b + k / 2, 70, 45 if k % 2 else 58) for k in range(16)] + [(b + k, 61 if k % 2 else 60, 70) for k in (1, 3, 5, 7)]
        if bar % 2 == 0:
            out.append((b, 49, 95))
        return out
    parts = [
        (29, lead_notes(lead, 96, extra=0.1), {'glide': True, 'cc': {1: 30}}),
        (24, each_chord(chords, uke)),
        (116, each_chord(chords, lambda b, r, t, c: [(b + bar * 8 + k, 1, r + 12, v) for bar in (0, 1) for k, v in ((0, 110), (3, 85), (5, 90))])),
        (34, each_chord(chords, lambda b, r, t, c: [(b + k, 0.9, r + (12 if k % 4 == 3 else 0), 96) for k in range(16)])),
        (61, each_chord(chords, lambda b, r, t, c: [(b + bar * 8 + k, 0.45, m, 88) for bar in (0, 1) for k in (3, 6) for m in t])),
        ('drums', hits(chords, kit)),
    ]
    return render(parts, bpm, len(lead))


def leon_orchestra():
    """Leon (Galar), o campeão invicto: hino de estádio, rock épico de anime com orquestra. Metais e
    sintetizador na melodia com o coro (a torcida) uma oitava abaixo, guitarras distorcidas, baixo, cordas em
    ostinato, tímpanos, bateria de rock, a torcida e as palmas da arquibancada."""
    lead, chords, bpm = champion_song('leon')
    def guitar(b, r, t, c):
        out = [(b, 2.5, m, 108) for m in (r + 12, r + 19, r + 24)]
        out += [(b + k, 0.45, m, 78 if k % 2 == 0 else 64) for k in range(3, 16) for m in (r + 12, r + 19)]
        return out
    def kit(b, bar):
        out = rock_kit(b, bar, (0, 2, 3, 4, 6))
        if bar % 2 == 1:  # as palmas da arquibancada no fim do acorde
            out += [(b + k, 39, 100) for k in (5, 6, 7)]
        return out
    parts = [
        (61, lead_notes(lead, 108, extra=0.1)),
        (81, lead_notes(lead, 78, extra=0.05)),
        (52, lead_notes(lead, 92, -12, extra=0.2)),
        (30, each_chord(chords, guitar)),
        (34, each_chord(chords, lambda b, r, t, c: [(b + k, 0.9, r, 100) for k in range(16)])),
        (48, each_chord(chords, lambda b, r, t, c: [(b + k / 2, 0.45, [t[0], t[1], t[0], t[2]][k % 4], 50 if k % 4 else 64) for k in range(32)])),
        (47, each_chord(chords, lambda b, r, t, c: [(b, 2, r, 115), (b + 8, 2, r, 100)])),
        (126, [(0, len(lead), 60, 42)]),
        ('drums', hits(chords, kit)),
    ]
    return render(parts, bpm, len(lead))


def geeta_orchestra():
    """Geeta (Paldea), fria e no comando: orquestra sombria e contida. Trompas na melodia com o trompete de
    surdina uma oitava acima, violoncelos em ostinato curto e grave, baixo sintetizado pulsando, pad escuro,
    o sino tubular grave a cada acorde e percussão seca (aro, bumbo, chimbal, tímpano esparso)."""
    lead, chords, bpm = champion_song('geeta')
    def kit(b, bar):
        out = [(b + k, 36, 100) for k in (0, 3, 4)] + [(b + k, 37, 85) for k in (2, 6)]
        out += [(b + k, 42, 55) for k in range(8)]
        if bar % 4 == 3:
            out += [(b + 6 + r / 4, 37, 60 + 8 * r) for r in range(8)]
        return out
    parts = [
        (60, lead_notes(lead, 100, extra=0.1)),
        (59, lead_notes(lead, 74, 12, extra=0.1)),
        (42, each_chord(chords, lambda b, r, t, c: [(b + k / 2, 0.35, [t[0], t[0], t[2], t[0]][k % 4] - 24, 76 if k % 4 == 0 else 60) for k in range(32)])),
        (38, each_chord(chords, lambda b, r, t, c: [(b + k, 0.8, r, 95 if k % 2 == 0 else 78) for k in range(16)])),
        (95, each_chord(chords, lambda b, r, t, c: [(b, 16, m - 12, 55) for m in t])),
        (14, each_chord(chords, lambda b, r, t, c: [(b, 8, t[0], 75)])),
        (47, each_chord(chords, lambda b, r, t, c: [(b, 2, r, 105), (b + 11, 1, r, 75)])),
        ('drums', hits(chords, kit)),
    ]
    return render(parts, bpm, len(lead))


def volo_orchestra():
    """Volo (Hisui), o mercador gentil que mostra quem é no fim: o órgão e o coro sombrios, as cordas em trêmulo, o
    cravo correndo no acorde, os metais graves, os tímpanos e a bateria pesada."""
    lead, chords, bpm = champion_song('volo')
    parts = [
        (19, lead_notes(lead, 92, extra=0.05)),
        (52, lead_notes(lead, 70, -12, keep=lambda i: i % 2 == 0, extra=1)),
        (44, each_chord(chords, lambda b, r, t, c: [(b, 16, m - 12, 60) for m in t])),
        (6, each_chord(chords, lambda b, r, t, c: [(b + k / 2, 0.45, [t[0], t[1], t[2], t[1]][k % 4], 50) for k in range(32)])),
        (57, each_chord(chords, lambda b, r, t, c: [(b + k, 1.5, x - 12, 90) for k in (0, 6, 12) for x in (t[0], t[2])])),
        (33, each_chord(chords, lambda b, r, t, c: [(b + k, 0.85, r, 96 if k % 2 == 0 else 80) for k in range(16)])),
        (47, each_chord(chords, lambda b, r, t, c: [(b, 2, r, 104), (b + 8, 2, r, 88)])),
        ('drums', hits(chords, lambda b, bar: rock_kit(b, bar, (0, 3, 4)))),
    ]
    return render(parts, bpm, len(lead))


CHAMPIONS = {'blue': blue_orchestra, 'lance': lance_orchestra, 'steven': steven_orchestra, 'wallace': wallace_orchestra,
             'cynthia': sinnoh_orchestra, 'alder': alder_orchestra, 'iris': iris_orchestra, 'diantha': diantha_orchestra,
             'kukui': kukui_orchestra, 'leon': leon_orchestra, 'geeta': geeta_orchestra,
             'volo': volo_orchestra}  # os campeões já refeitos (os outros tocam o tema da região)


# Os rivais (no Pokelike): cada um com o tema original dele — tônica, escala, progressão e andamento.
RIVAL_THEMES = {
    'blue': (67, 'mixolydian', [0, 6, 3, 4], 168),
    'silver': (64, 'minor', [0, 5, 2, 6], 144),
    'brendan-may': (68, 'major', [0, 4, 5, 3], 150),
    'wally': (65, 'major', [0, 3, 4, 0], 140),
    'barry': (66, 'major', [0, 4, 5, 3], 184),
    'cheren': (60, 'minor', [0, 5, 6, 4], 160),
    'bianca': (70, 'major', [0, 3, 4, 0], 150),
    'hugh': (69, 'minor', [0, 5, 2, 6], 176),
    'n': (62, 'harmonic', [0, 5, 3, 4], 150),
    'serena-calem': (66, 'dorian', [0, 3, 6, 4], 156),
    'shauna': (69, 'major', [0, 4, 5, 3], 150),
    'tierno': (65, 'mixolydian', [0, 6, 3, 4], 120),
    'trevor': (67, 'major', [0, 2, 3, 4], 140),
    'hau': (67, 'major', [0, 3, 4, 0], 152),
    'gladion': (62, 'minor', [0, 5, 6, 4], 164),
    'hop': (62, 'dorian', [0, 3, 6, 4], 150),
    'bede': (64, 'harmonic', [0, 3, 4, 0], 160),
    'marnie': (71, 'minor', [0, 5, 2, 6], 164),
    'nemona': (69, 'major', [0, 3, 4, 4], 168),
    'arven': (65, 'dorian', [0, 3, 6, 4], 128),
    'red': (64, 'minor', [0, 5, 6, 4], 168),
    'lillie': (67, 'major', [0, 5, 3, 4], 136),
    'az': (62, 'harmonic', [0, 3, 5, 4], 112),
    'anabel': (64, 'dorian', [0, 6, 5, 4], 132),
    'dexio': (65, 'mixolydian', [0, 3, 6, 4], 140),
    'sina': (67, 'major', [0, 5, 3, 4], 128),
    'benga': (67, 'dorian', [0, 6, 3, 4], 168),
    'eusine': (62, 'dorian', [0, 3, 6, 4], 124),
    'ryuki': (64, 'phrygian', [0, 1, 6, 4], 172),
    'sordward-e-shielbert': (65, 'major', [0, 4, 5, 3], 132),
}


def rival_song(name):
    tonic, mode, prog, bpm = RIVAL_THEMES[name]
    lead, chords = compose(f'rival-{name}', tonic, mode, prog)
    return lead, chords, bpm


def rival_blue_orchestra():
    """Blue como rival (o "normal", não o de campeão): Game Boy rápido e debochado. A onda quadrada na melodia
    com eco curto, guitarra limpa nos contratempos, baixo andando, arpejo de Game Boy e bateria leve e agitada."""
    lead, chords, bpm = rival_song('blue')
    melody = lead_notes(lead, 90, extra=0.02)
    def kit(b, bar):
        out = [(b + k, 36, 92) for k in (0, 4)] + [(b + k, 38, 85) for k in (2, 6)]
        out += [(b + k / 2, 42, 50 if k % 2 else 66) for k in range(16)]
        if bar % 4 == 0:
            out.append((b, 49, 85))
        elif bar % 4 == 3:
            out += [(b + 7 + r / 4, 38, 65 + 8 * r) for r in range(4)]
        return out
    parts = [
        (80, melody),
        (80, [(st + 0.5, ln, m, 34) for st, ln, m, v in melody]),
        (27, each_chord(chords, lambda b, r, t, c: [(b + k, 0.5, m, 70) for k in range(1, 16, 2) for m in t])),
        (33, each_chord(chords, lambda b, r, t, c: [(b + k, 0.9, [r, r + 7, r + 12, r + 7][k % 4], 90) for k in range(16)])),
        (81, each_chord(chords, lambda b, r, t, c: [(b + k / 2, 0.4, [t[0], t[1], t[2], t[0] + 12][k % 4], 34) for k in range(32)])),
        ('drums', hits(chords, kit)),
    ]
    return render(parts, bpm, len(lead))


def guitar_solo(start, end, chords, tonic, seed, base=64):
    """Um solo de guitarra original na pentatônica menor (a escala dos solos de rock), afinado com os acordes:
    nos tempos fortes e nas notas longas, uma nota do acorde de agora. Frases de 2 compassos que se respondem
    (a pergunta sobe, a resposta desce), com notas rápidas e a última segurada. Devolve (notas, as longas
    para o bend de 1 tom)."""
    rng = np.random.default_rng(seed)
    penta = [0, 3, 5, 7, 10]
    ladder = [m for m in (tonic + 12 * o + iv for o in range(-1, 3) for iv in penta) if base - 2 <= m <= base + 24]
    rhythms = [
        [0, 0.5, 1, 1.5, 2, 3, 3.5, 4, 6],
        [0, 1, 1.5, 2, 2.5, 3, 4, 5, 5.5, 6],
        [0, 0.25, 0.5, 0.75, 1, 2, 2.5, 3, 4, 4.5, 5, 6],
        [0, 1.5, 2, 3.5, 4, 4.5, 5, 5.5, 6],
    ]
    def chord_at(step):
        return chords[int(step // 16) % len(chords)][1]
    def snap(m, step):  # a nota do acorde mais perto (na mesma região)
        pcs = {x % 12 for x in chord_at(step)}
        options = [x for x in range(m - 6, m + 7) if x % 12 in pcs and base - 2 <= x <= base + 24]
        return min(options, key=lambda x: (abs(x - m), x)) if options else m
    out, long_notes, pos, idx, phrase = [], [], start, len(ladder) // 2, 0
    while pos < end:
        rhythm = rhythms[int(rng.integers(len(rhythms)))]
        climb = 1 if phrase % 2 == 0 else -1
        for j, off in enumerate(rhythm):
            at = pos + off
            if at >= end:
                break
            nxt = rhythm[j + 1] if j + 1 < len(rhythm) else 8
            idx = max(0, min(len(ladder) - 1, idx + climb * int(rng.choice([1, 1, 2, 0, -1]))))
            note = ladder[idx]
            length = (nxt - off) * 0.95
            last = j == len(rhythm) - 1
            if off in (0, 4) or last or length >= 1.5:
                note = snap(note, at)
            if last:
                length *= 1.6
                long_notes.append(at)
            out.append((at, length, note, 118 if last or j == 0 else 104))
        pos += 8
        phrase += 1
    return out, long_notes


def rival_silver_orchestra():
    """Silver (Johto): rock clássico com atitude, no estilo dos anos 60. A primeira metade com a melodia na
    guitarra solo (crunch, na frente); a segunda, um solo de guitarra na pentatônica com bends. Guitarra base
    jangle (limpa e brilhante) e outra com crunch, baixo melódico, piano em colcheias e bateria de rock
    clássico com pandeirola e viradas."""
    lead, chords, bpm = rival_song('silver')
    tonic, mode, prog, _ = RIVAL_THEMES['silver']
    steps = len(lead)
    half = steps // 2
    # A melodia nos tempos (sem as notas picadas no contratempo): fica firme em cima da levada.
    melody = lead_notes(lead, 112, maxlen=4, keep=lambda i: i < half and i % 2 == 0, extra=0.1)
    solo, bends = guitar_solo(half, steps, chords, tonic, seed=7)
    def strum(b, r, t, c):  # a guitarra jangle: o acorde nos tempos
        return [(b + k, 1.8, m, 74 if k % 4 == 0 else 62) for k in range(0, 16, 2) for m in (t[0] + 12, t[1] + 12, t[2] + 12)]
    def crunch(b, r, t, c):  # a base com crunch: colcheias retas, travada com o bumbo
        return [(b + k, 0.85, m, 86 if k % 2 == 0 else 72) for k in range(16) for m in (r + 12, r + 19)]
    def bass(b, r, t, c):  # colcheias retas na raiz, com a oitava no fim do compasso
        return [(b + k, 0.85, r + (12 if k % 8 == 7 else 0), 102 if k % 2 == 0 else 88) for k in range(16)]
    def kit(b, bar):
        out = [(b + k, 36, 105) for k in (0, 4, 5)] + [(b + k, 38, 105) for k in (2, 6)]
        out += [(b + k, 42, 70 if k % 2 else 84) for k in range(8)] + [(b + k, 54, 78) for k in (2, 6)]
        if bar % 4 == 3:  # virada só no fim da frase
            out = [x for x in out if x[0] < b + 6] + [(b + 6 + r / 2, (48, 47, 45, 41)[r], 104) for r in range(4)]
        if bar % 4 == 0:
            out.append((b, 49, 100))
        return out
    parts = [
        (29, melody + solo, {'bend': bends, 'cc': {1: 28}, 'amp': {'drive': 14, 'gain': 1.25, 'pan': 0.0}}),
        (27, each_chord(chords, strum), {'amp': {'drive': 3, 'gain': 0.42, 'pan': -0.6}}),
        (28, each_chord(chords, crunch), {'amp': {'drive': 12, 'gain': 0.5, 'pan': 0.6}}),
        (33, each_chord(chords, bass)),
        ('drums', hits(chords, kit)),
    ]
    return render(parts, bpm, steps, soundfont=MUSESCORE)


def pop_kit(b, bar, tamb=True):
    """Levada pop/rock reta: bumbo no 1 e no 3 (e no "e" do 3), caixa no 2 e no 4, chimbal em colcheias,
    pandeirola e virada só no fim da frase."""
    out = [(b + k, 36, 100) for k in (0, 4, 5)] + [(b + k, 38, 98) for k in (2, 6)]
    out += [(b + k, 42, 66 if k % 2 else 80) for k in range(8)] + ([(b + k, 54, 72) for k in (2, 6)] if tamb else [])
    if bar % 4 == 3:
        out = [x for x in out if x[0] < b + 6] + [(b + 6 + r / 2, (48, 47, 45, 41)[r], 100) for r in range(4)]
    if bar % 4 == 0:
        out.append((b, 49, 95))
    return out


def rival_brendan_may_orchestra():
    """Brendan e May (Hoenn), aventura animada: metais alegres na melodia com o trompete, cordas em colcheias,
    glockenspiel, baixo e bateria pop/rock reta."""
    lead, chords, bpm = rival_song('brendan-may')
    melody = lead_notes(lead, 104, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.1)
    parts = [
        (61, melody),
        (56, [(st, ln, m, 78) for st, ln, m, v in melody]),
        (48, each_chord(chords, lambda b, r, t, c: [(b + k, 0.9, m, 58 if k % 2 else 66) for k in range(16) for m in t])),
        (9, each_chord(chords, lambda b, r, t, c: [(b + k, 1, [t[0], t[1], t[2], t[1]][(k // 2) % 4] + 12, 50) for k in range(0, 16, 2)])),
        (33, each_chord(chords, lambda b, r, t, c: [(b + k, 0.85, r + (7 if k % 8 == 6 else 0), 98) for k in range(16)])),
        ('drums', hits(chords, pop_kit)),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def rival_wally_orchestra():
    """Wally (Hoenn), frágil mas determinado. Primeira metade tímida (piano suave e cordas leves); na segunda,
    ele cria coragem: entram bateria, baixo e trompas, e as cordas crescem."""
    lead, chords, bpm = rival_song('wally')
    steps = len(lead)
    half = steps // 2
    piano = lead_notes(lead, 82, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.3)
    piano += each_chord(chords, lambda b, r, t, c: [(b + k, 2.5, [t[0], t[1], t[2], t[1]][(k // 2) % 4] - 12, 48) for k in range(0, 16, 2)])
    parts = [
        (0, piano),
        (48, each_chord(chords, lambda b, r, t, c: [(b, 16, m, 46 if b < half else 72) for m in t])),
        (60, [(st, ln, m, 88) for st, ln, m, v in lead_notes(lead, 88, maxlen=4, keep=lambda i: i >= half and i % 2 == 0, extra=0.1)]),
        (33, each_chord(chords, lambda b, r, t, c: [(b + k, 0.85, r, 96) for k in range(16)] if b >= half else [])),
        ('drums', hits(chords, lambda b, bar: pop_kit(b, bar) if b >= half else ([(b + 7, 38, 40 + 4 * bar)] if bar >= 6 else []))),
    ]
    return render(parts, bpm, steps, soundfont=MUSESCORE)


def rival_barry_orchestra():
    """Barry (Sinnoh), apressado e elétrico: pop-punk rápido. Guitarras base pelo amplificador em colcheias
    retas (dobradas, uma de cada lado), guitarra solo com crunch na melodia, baixo colado nelas, bateria punk
    (bumbo e caixa se revezando, chimbal aberto) e paradas rápidas no fim das frases."""
    lead, chords, bpm = rival_song('barry')
    stop = lambda c: c % 4 == 3
    def power(b, r, t, c):
        if stop(c):  # a parada: dois golpes e silêncio, e volta correndo
            return [(b + k, 0.5, m, 118) for k in (0, 1, 8, 9) for m in (r + 12, r + 19, r + 24)] + [(b + 12 + k / 2, 0.4, m, 96) for k in range(8) for m in (r + 12, r + 19)]
        return [(b + k, 0.85, m, 100 if k % 2 == 0 else 86) for k in range(16) for m in (r + 12, r + 19, r + 24)]
    def bass(b, r, t, c):
        if stop(c):
            return [(b + k, 0.5, r, 118) for k in (0, 1, 8, 9)] + [(b + 12 + k / 2, 0.4, r, 100) for k in range(8)]
        return [(b + k, 0.85, r, 104) for k in range(16)]
    def kit(b, bar):
        c = bar // 2
        if stop(c):
            return [(b + k, 36, 118) for k in (0, 1)] + [(b, 49, 110)] + ([(b + 4 + r / 2, 38, 80 + 10 * r) for r in range(8)] if bar % 2 else [])
        out = [(b + k, 36 if k % 2 == 0 else 38, 105) for k in range(8)]
        out += [(b + k, 46, 70) for k in range(8)]
        if bar % 2 == 0:
            out.append((b, 49, 105))
        return out
    melody = lead_notes(lead, 112, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.05)
    parts = [
        (29, melody, {'cc': {1: 20}, 'amp': {'drive': 16, 'gain': 1.1, 'pan': 0.0}}),
        (28, each_chord(chords, power), {'amp': {'drive': 34, 'gain': 0.8, 'double': True}}),
        (34, each_chord(chords, bass)),
        ('drums', hits(chords, kit)),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def rival_cheren_orchestra():
    """Cheren (Unova), sério e racional: piano em ostinato de semicolcheias (preciso como relógio), violino na
    melodia com cordas em staccato, o tique-taque do wood block, contrabaixo e bateria enxuta."""
    lead, chords, bpm = rival_song('cheren')
    def ostinato(b, r, t, c):
        cell = [t[0], t[1], t[2], t[1] + 12, t[2], t[1], t[0] + 12, t[2]]
        return [(b + k / 2, 0.45, cell[k % 8] - 12, 70 if k % 4 == 0 else 54) for k in range(32)]
    def kit(b, bar):
        out = [(b + k, 36, 92) for k in (0, 4)] + [(b + k, 37, 86) for k in (2, 6)] + [(b + k, 42, 60) for k in range(8)]
        out += [(b + k, 76 if k % 2 == 0 else 77, 72) for k in range(8)]  # o tique-taque
        if bar % 4 == 3:
            out += [(b + 6 + r / 4, 37, 70 + 6 * r) for r in range(8)]
        return out
    parts = [
        (40, lead_notes(lead, 104, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.1), {'cc': {1: 25}}),
        (0, each_chord(chords, ostinato)),
        (45, each_chord(chords, lambda b, r, t, c: [(b + k, 0.4, m, 66) for k in range(0, 16, 2) for m in t])),
        (43, each_chord(chords, lambda b, r, t, c: [(b + k, 0.85, r, 92) for k in range(16)])),
        ('drums', hits(chords, kit)),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def rival_bianca_orchestra():
    """Bianca (Unova), desastrada e doce: flauta na melodia com glockenspiel, cordas em pizzicato saltitantes,
    fagote no baixo (atrapalhado, de desenho animado), bateria leve com palmas e o xilofone "tropeçando"."""
    lead, chords, bpm = rival_song('bianca')
    melody = lead_notes(lead, 100, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.1)
    def trip(b, r, t, c):  # o xilofone tropeçando no fim de cada frase
        if c % 2 == 0:
            return []
        return [(b + 13 + j * 0.5, 0.5, m, 70 + 6 * j) for j, m in enumerate((t[2] + 12, t[1] + 12, t[1] + 11, t[0] + 12, t[0] + 24))]
    parts = [
        (73, melody, {'cc': {1: 20}}),
        (9, [(st, ln, m + 12, 56) for st, ln, m, v in melody]),
        (45, each_chord(chords, lambda b, r, t, c: [(b + k, 0.5, [t[0], t[2], t[1], t[2]][(k // 2) % 4], 70) for k in range(1, 16, 2)])),
        (70, each_chord(chords, lambda b, r, t, c: [(b + k, 0.9, r + 12 + (7 if k % 4 == 2 else 0), 96) for k in range(0, 16, 2)])),
        (13, each_chord(chords, trip)),
        ('drums', hits(chords, lambda b, bar: [(b + k, 36, 80) for k in (0, 4)] + [(b + k, 39, 72) for k in (2, 6)] + [(b + k, 42, 50) for k in range(8)] + ([(b, 49, 70)] if bar % 4 == 0 else []))),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def rival_hugh_orchestra():
    """Hugh (Unova, Black 2/White 2), raivoso e justo: metais fortes na melodia (trompetes e trombones),
    guitarras pesadas pelo amplificador em paredão, baixo, bateria de rock pesada e tímpanos nos acentos."""
    lead, chords, bpm = rival_song('hugh')
    melody = lead_notes(lead, 112, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.1)
    def heavy(b, r, t, c):
        out = [(b, 1.8, m, 112) for m in (r + 12, r + 19, r + 24)]
        out += [(b + k, 0.85, m, 92 if k % 4 == 0 else 74) for k in range(2, 16) for m in (r + 12, r + 19)]
        return out
    def kit(b, bar):
        out = [(b + k, 36, 108) for k in (0, 3, 4)] + [(b + k, 38, 108) for k in (2, 6)] + [(b + k, 42, 72) for k in range(8)]
        if bar % 2 == 0:
            out.append((b, 49, 108))
        if bar % 4 == 3:
            out = [x for x in out if x[0] < b + 6] + [(b + 6 + r / 2, (48, 45, 43, 41)[r], 110) for r in range(4)]
        return out
    parts = [
        (56, melody),
        (57, [(st, ln, m - 12, 96) for st, ln, m, v in melody]),
        (28, each_chord(chords, heavy), {'amp': {'drive': 36, 'gain': 0.75, 'double': True}}),
        (34, each_chord(chords, lambda b, r, t, c: [(b + k, 0.85, r, 104) for k in range(16)])),
        (47, each_chord(chords, lambda b, r, t, c: [(b, 2, r, 112), (b + 8, 2, r, 100)])),
        ('drums', hits(chords, kit)),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def rival_n_orchestra():
    """N (Unova, Black 2/White 2), misterioso e trágico: órgão de igreja e coro na melodia, cordas em trêmulo,
    harpa em arpejo lento, tímpanos e pratos suaves (sem bateria de rock)."""
    lead, chords, bpm = rival_song('n')
    melody = lead_notes(lead, 96, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.3)
    parts = [
        (19, melody + each_chord(chords, lambda b, r, t, c: [(b, 16, m - 12, 60) for m in t])),
        (52, [(st, ln, m, 84) for st, ln, m, v in melody]),
        (44, each_chord(chords, lambda b, r, t, c: [(b, 16, m + 12, 52) for m in t])),
        (46, each_chord(chords, lambda b, r, t, c: [(b + k, 3, [t[0], t[1], t[2], t[0] + 12][(k // 2) % 4], 50) for k in range(0, 16, 2)])),
        (43, each_chord(chords, lambda b, r, t, c: [(b + k, 3.6, r, 86) for k in range(0, 16, 4)])),
        (47, each_chord(chords, lambda b, r, t, c: [(b, 2, r, 100), (b + 8, 2, r, 84)] + ([(b + 12 + q / 3, 0.3, r, 50 + 8 * q) for q in range(12)] if c % 2 else []))),
        ('drums', hits(chords, lambda b, bar: [(b, 49, 70)] if bar % 4 == 0 else [])),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def rival_serena_calem_orchestra():
    """Serena e Calem (Kalos), elegantes e confiantes: violino e piano na melodia, baixo funk, acordeão discreto
    (o toque francês), cordas e bateria com groove."""
    lead, chords, bpm = rival_song('serena-calem')
    melody = lead_notes(lead, 104, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.1)
    def funk(b, r, t, c):
        pattern = [(0, r, 1), (1.5, r + 12, 0.4), (2, r, 0.5), (3, r + 10, 0.4), (3.5, r + 12, 0.4), (4, r + 7, 1), (6, r, 0.5), (7, r + 12, 0.5)]
        return [(b + bar * 8 + k, ln, m, 100) for bar in (0, 1) for k, m, ln in pattern]
    def kit(b, bar):
        out = [(b + k, 36, 98) for k in (0, 3, 5)] + [(b + k, 38, 96) for k in (2, 6)] + [(b + k / 2, 42, 52 if k % 2 else 70) for k in range(16)]
        if bar % 4 == 0:
            out.append((b, 49, 92))
        return out
    parts = [
        (40, melody, {'cc': {1: 28}}),
        (0, [(st, ln, m - 12, 70) for st, ln, m, v in melody] + each_chord(chords, lambda b, r, t, c: [(b + k, 0.6, m, 54) for k in (1, 3, 5, 7, 9, 11, 13, 15) for m in t])),
        (21, [(st, ln, m, 34) for st, ln, m, v in melody]),
        (36, each_chord(chords, funk)),
        (48, each_chord(chords, lambda b, r, t, c: [(b, 16, m + 12, 42) for m in t])),
        ('drums', hits(chords, kit)),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def rival_shauna_orchestra():
    """Shauna (Kalos), alegre e espontânea: pop com acordeão na melodia, violão, palmas, glockenspiel e baixo."""
    lead, chords, bpm = rival_song('shauna')
    melody = lead_notes(lead, 102, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.1)
    parts = [
        (21, melody),
        (9, [(st, ln, m + 12, 50) for st, ln, m, v in melody]),
        (25, each_chord(chords, lambda b, r, t, c: [(b + k, 1.4, m, 70 if k % 4 == 0 else 58) for k in range(0, 16, 2) for m in (t[0] + 12, t[1] + 12, t[2] + 12)])),
        (33, each_chord(chords, lambda b, r, t, c: [(b + k, 0.85, r + (7 if k % 8 == 6 else 0), 96) for k in range(16)])),
        ('drums', hits(chords, lambda b, bar: pop_kit(b, bar) + [(b + k, 39, 84) for k in (2, 6)])),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def rival_tierno_orchestra():
    """Tierno (Kalos), o dançarino: funk/disco. Bumbo em todo tempo, guitarra funk arranhada (pelo amplificador
    limpo), baixo slap, metais curtos, cordas de disco e chimbal aberto nos contratempos."""
    lead, chords, bpm = rival_song('tierno')
    melody = lead_notes(lead, 100, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.05)
    def scratch(b, r, t, c):  # semicolcheias abafadas, com o acorde nos acentos
        return [(b + k / 2, 0.2, m, 90 if k % 4 == 2 else 58) for k in range(32) for m in (t[0] + 12, t[2] + 12)]
    def slap(b, r, t, c):
        pattern = [(0, r), (0.5, r + 12), (1.5, r), (2, r + 12), (3, r + 7), (4, r), (4.5, r + 12), (6, r + 10), (7, r + 12)]
        return [(b + bar * 8 + k, 0.4, m, 104) for bar in (0, 1) for k, m in pattern]
    def kit(b, bar):
        out = [(b + k, 36, 104) for k in (0, 2, 4, 6)] + [(b + k, 39, 90) for k in (2, 6)]
        out += [(b + k, 46, 74) for k in (1, 3, 5, 7)] + [(b + k / 2, 42, 50) for k in range(16)]
        if bar % 4 == 0:
            out.append((b, 49, 90))
        return out
    parts = [
        (61, melody),
        (56, [(st, ln, m + 12, 70) for st, ln, m, v in melody]),
        (28, each_chord(chords, scratch), {'amp': {'drive': 4, 'gain': 0.5, 'pan': -0.4}}),
        (36, each_chord(chords, slap)),
        (48, each_chord(chords, lambda b, r, t, c: [(b, 8, m + 12, 60) for m in t] + [(b + 8, 8, m + 12, 60) for m in t])),
        ('drums', hits(chords, kit)),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def rival_trevor_orchestra():
    """Trevor (Kalos), o estudioso curioso: sintetizador suave na melodia, marimba e celesta em arpejos, sinos
    e bateria eletrônica leve."""
    lead, chords, bpm = rival_song('trevor')
    melody = lead_notes(lead, 96, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.1)
    parts = [
        (80, melody, {'cc': {1: 15}}),
        (12, each_chord(chords, lambda b, r, t, c: [(b + k / 2, 0.45, [t[0], t[1], t[2], t[0] + 12][k % 4], 62) for k in range(32)])),
        (8, each_chord(chords, lambda b, r, t, c: [(b + k, 1, [t[2], t[1], t[0], t[1]][(k // 2) % 4] + 12, 48) for k in range(0, 16, 2)])),
        (14, each_chord(chords, lambda b, r, t, c: [(b, 6, t[0] + 12, 58)])),
        (38, each_chord(chords, lambda b, r, t, c: [(b + k, 0.8, r, 90) for k in range(0, 16, 2)])),
        ('drums', hits(chords, lambda b, bar: [(b + k, 36, 90) for k in (0, 4)] + [(b + k, 40, 80) for k in (2, 6)] + [(b + k / 2, 42, 46) for k in range(16)] + ([(b, 81, 70)] if bar % 2 == 0 else []))),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def rival_hau_orchestra():
    """Hau (Alola), bem-humorado: steel drum na melodia, ukulele em rasgueado alegre, baixo saltitante, marimba
    e bateria leve com bongôs e maracas."""
    lead, chords, bpm = rival_song('hau')
    step_s = 60 / bpm / 2
    melody = lead_notes(lead, 104, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.1)
    def uke(b, r, t, c):
        strings_ = [t[0] + 12, t[1] + 12, t[2] + 12, t[0] + 24]
        out = []
        for bar in (0, 1):
            for k, down, v in ((0, True, 72), (2, True, 62), (3, False, 48), (5, False, 48), (6, True, 62), (7, False, 48)):
                for j, m in enumerate(strings_ if down else strings_[::-1]):
                    out.append((b + bar * 8 + k + j * 0.012 / step_s, 1.2, m, v))
        return out
    parts = [
        (114, melody),
        (24, each_chord(chords, uke)),
        (12, each_chord(chords, lambda b, r, t, c: [(b + k, 0.9, [t[0], t[2], t[1], t[2]][(k // 2) % 4] + 12, 50) for k in range(1, 16, 2)])),
        (32, each_chord(chords, lambda b, r, t, c: [(b + bar * 8 + k, 1.6, m, 92) for bar in (0, 1) for k, m in ((0, r), (3, r + 7), (4, r + 12), (6, r + 7))])),
        ('drums', hits(chords, lambda b, bar: [(b + k, 36, 86) for k in (0, 4)] + [(b + k, 38, 78) for k in (2, 6)] + [(b + k / 2, 70, 40 if k % 2 else 54) for k in range(16)] + [(b + k, 61 if k % 2 else 60, 66) for k in (1, 3, 5, 7)])),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def rival_gladion_orchestra():
    """Gladion (Alola), solitário e rebelde: guitarra elétrica sombria pelo amplificador na melodia (com bends),
    sintetizador escuro em arpejo, pad frio, baixo pesado e bateria firme com prato chinês."""
    lead, chords, bpm = rival_song('gladion')
    melody = lead_notes(lead, 110, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.1)
    bends = [st for st, ln, m, v in melody if ln >= 3]
    def kit(b, bar):
        out = [(b + k, 36, 104) for k in (0, 3, 4)] + [(b + k, 38, 104) for k in (2, 6)] + [(b + k, 42, 66 if k % 2 else 80) for k in range(8)]
        if bar % 2 == 0:
            out += [(b, 49, 100), (b, 52, 80)]
        if bar % 4 == 3:
            out = [x for x in out if x[0] < b + 6] + [(b + 6 + r / 2, (48, 45, 43, 41)[r], 104) for r in range(4)]
        return out
    parts = [
        (29, melody, {'bend': bends, 'cc': {1: 30}, 'amp': {'drive': 18, 'gain': 1.15, 'pan': 0.0}}),
        (28, each_chord(chords, lambda b, r, t, c: [(b + k, 0.85, m, 84 if k % 2 == 0 else 70) for k in range(16) for m in (r + 12, r + 19)]), {'amp': {'drive': 26, 'gain': 0.55, 'double': True}}),
        (81, each_chord(chords, lambda b, r, t, c: [(b + k / 2, 0.4, [t[0], t[1], t[2], t[1]][k % 4] - 12, 40) for k in range(32)])),
        (95, each_chord(chords, lambda b, r, t, c: [(b, 16, m - 12, 50) for m in t])),
        (34, each_chord(chords, lambda b, r, t, c: [(b + k, 0.85, r, 102) for k in range(16)])),
        ('drums', hits(chords, kit)),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def rival_hop_orchestra():
    """Hop (Galar), à sombra do irmão: a primeira metade insegura (guitarra limpa e piano, baixinho, em tom menor);
    na segunda, ele tenta ser o Leon: entram os metais de estádio e a bateria, um eco do hino do irmão, mas contido
    (a torcida fraca, as palmas tímidas): grandioso pela metade, porque ele ainda não chegou lá."""
    lead, chords, bpm = rival_song('hop')
    steps = len(lead)
    half = steps // 2
    melody = lead_notes(lead, 96, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.1)
    first = [n for n in melody if n[0] < half]
    second = [n for n in melody if n[0] >= half]
    parts = [
        (27, first + [(st, ln, m, 86) for st, ln, m, v in second], {'cc': {1: 20}, 'amp': {'drive': 4, 'gain': 0.95, 'pan': 0.0}}),
        (0, each_chord(chords, lambda b, r, t, c: [(b + k, 1.8, [t[0], t[1], t[2], t[1]][(k // 2) % 4] - 12, 46 if b < half else 52) for k in range(0, 16, 2)])),
        (61, [(st, ln, m, 76) for st, ln, m, v in second]),
        (48, each_chord(chords, lambda b, r, t, c: [(b, 16, m, 40 if b < half else 58) for m in t])),
        (33, each_chord(chords, lambda b, r, t, c: [(b + k, 1.8, r, 78) for k in range(0, 16, 4)] if b < half else [(b + k, 0.85, r, 92) for k in range(16)])),
        (126, [(half, half, 60, 22)]),
        ('drums', hits(chords, lambda b, bar: ([(b + k, 42, 44) for k in range(0, 8, 2)] if b < half else pop_kit(b, bar, tamb=False) + ([(b + k, 39, 58) for k in (6, 7)] if bar % 2 == 1 else [])))),
    ]
    return render(parts, bpm, steps, soundfont=MUSESCORE)


def rival_bede_orchestra():
    """Bede (Galar), arrogante e dramático: orquestra barroca. Cravo e violino na melodia, cordas barrocas,
    violoncelo e fagote no baixo contínuo, órgão, tímpanos e bateria contida."""
    lead, chords, bpm = rival_song('bede')
    melody = lead_notes(lead, 104, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.05)
    parts = [
        (6, melody + each_chord(chords, lambda b, r, t, c: [(b + k / 2, 0.45, [t[0], t[1], t[2], t[1]][k % 4], 60) for k in range(32)])),
        (40, [(st, ln, m + 12, 84) for st, ln, m, v in melody], {'cc': {1: 30}}),
        (48, each_chord(chords, lambda b, r, t, c: [(b + k, 0.9, m, 60) for k in range(0, 16, 2) for m in t])),
        (42, each_chord(chords, lambda b, r, t, c: [(b + k, 0.9, [r, r + 12, r + 7, r + 12][(k // 2) % 4], 90) for k in range(0, 16, 2)])),
        (70, each_chord(chords, lambda b, r, t, c: [(b + k, 1.8, r + 12, 70) for k in range(0, 16, 4)])),
        (19, each_chord(chords, lambda b, r, t, c: [(b, 16, m - 12, 46) for m in t])),
        (47, each_chord(chords, lambda b, r, t, c: [(b, 2, r, 104), (b + 8, 2, r, 90)])),
        ('drums', hits(chords, lambda b, bar: [(b + k, 36, 88) for k in (0, 4)] + [(b + k, 38, 80) for k in (2, 6)] + ([(b, 49, 90)] if bar % 4 == 0 else []))),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def rival_marnie_orchestra():
    """Marnie (Galar), emo: rock emo dos anos 2000. A primeira metade contida, com guitarra limpa em arpejos agudos e
    brilhantes (o "twinkle"), baixo esparso e bateria em half-time (a caixa só no 3); na segunda, explode: o
    paredão de guitarras distorcidas, a bateria correndo e a guitarra solo chorando em bends."""
    lead, chords, bpm = rival_song('marnie')
    steps = len(lead)
    half = steps // 2
    melody = lead_notes(lead, 104, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.1)
    bends = [st for st, ln, m, v in melody if st >= half and ln >= 3]
    def twinkle(b, r, t, c):
        cell = [t[0] + 12, t[2] + 12, t[1] + 24, t[2] + 12, t[0] + 24, t[2] + 12, t[1] + 24, t[2] + 12]
        return [(b + k / 2, 0.9, cell[k % 8], 70 if k % 4 == 0 else 56) for k in range(32)]
    def wall(b, r, t, c):
        if b < half:
            return []
        return [(b + k, 0.85, m, 92 if k % 2 == 0 else 76) for k in range(16) for m in (r + 12, r + 19, r + 24)]
    def kit(b, bar):
        if b < half:  # half-time: pesado e lento
            return [(b, 36, 96), (b + 4, 38, 100)] + [(b + k, 42, 56) for k in range(8)] + ([(b, 49, 80)] if bar % 4 == 0 else [])
        out = [(b + k, 36, 106) for k in (0, 3, 4)] + [(b + k, 38, 106) for k in (2, 6)] + [(b + k, 51, 76) for k in range(8)]
        if bar % 2 == 0:
            out.append((b, 49, 108))
        if bar % 4 == 3:
            out = [x for x in out if x[0] < b + 6] + [(b + 6 + r / 2, (48, 45, 43, 41)[r], 106) for r in range(4)]
        return out
    parts = [
        (29, melody, {'bend': bends, 'cc': {1: 35}, 'amp': {'drive': 12, 'gain': 1.0, 'pan': 0.0}}),
        (27, each_chord(chords, twinkle), {'amp': {'drive': 2.5, 'gain': 0.55, 'pan': -0.5}}),
        (28, each_chord(chords, wall), {'amp': {'drive': 34, 'gain': 0.7, 'double': True}}),
        (34, each_chord(chords, lambda b, r, t, c: [(b, 3.5, r, 84), (b + 8, 3.5, r, 80)] if b < half else [(b + k, 0.85, r, 100) for k in range(16)])),
        ('drums', hits(chords, kit)),
    ]
    return render(parts, bpm, steps, soundfont=MUSESCORE)


def rival_nemona_orchestra():
    """Nemona (Paldea), animada e competitiva: pop latino. Trompetes na melodia (banda de salsa), violão de nylon em
    rasgueado espanhol, baixo tumbao (antecipando os acordes) e percussão latina: congas, timbales, claves e cowbell."""
    lead, chords, bpm = rival_song('nemona')
    melody = lead_notes(lead, 108, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.05)
    def strum(b, r, t, c):
        strings_ = [r + 12, t[0], t[1], t[2], t[0] + 12]
        return [(b + bar * 8 + k + j * 0.03, 0.9, m, v) for bar in (0, 1) for k, v in ((0, 80), (1.5, 60), (2, 72), (3, 60), (3.5, 66), (4, 80), (5.5, 60), (6, 72), (7, 60)) for j, m in enumerate(strings_)]
    def tumbao(b, r, t, c):
        nxt = chords[(c + 1) % len(chords)][0]
        nxt = nxt if nxt < 46 else nxt - 12
        return [(b + bar * 8 + k, 1.4, m, 100) for bar in (0, 1) for k, m in ((1.5, r + 7), (3, r), (5.5, r + 7), (7, nxt if bar else r))]
    def kit(b, bar):
        clave = (0, 1.5, 3, 5, 6) if bar % 2 == 0 else (1, 2, 4.5, 6)
        out = [(b + k, 75, 90) for k in clave] + [(b + k, 56, 70) for k in (0, 2, 4, 6)]
        out += [(b + k, 63 if k in (3, 3.5, 7) else 62, 76) for k in (0.5, 1.5, 3, 3.5, 4.5, 5.5, 7)]
        out += [(b + k, 36, 90) for k in (0, 4)] + [(b + 3.5, 65, 88), (b + 7.5, 66, 88)]
        if bar % 4 == 0:
            out.append((b, 49, 92))
        return out
    parts = [
        (56, melody),
        (56, [(st, ln, m - 12, 80) for st, ln, m, v in melody]),
        (24, each_chord(chords, strum)),
        (33, each_chord(chords, tumbao)),
        (0, each_chord(chords, lambda b, r, t, c: [(b + k, 0.5, m, 60) for k in (1, 2.5, 4, 5.5, 9, 10.5, 12, 13.5) for m in t])),
        ('drums', hits(chords, kit)),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def rival_arven_orchestra():
    """Arven (Paldea), tranquilo mas determinado: funk/soul de cozinha. Piano elétrico (Rhodes) na melodia, órgão,
    metais em ataques curtos, baixo com groove e bateria relaxada com notas fantasma na caixa."""
    lead, chords, bpm = rival_song('arven')
    melody = lead_notes(lead, 100, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.1)
    def groove(b, r, t, c):
        pattern = [(0, r, 1.2), (1.5, r + 12, 0.4), (2, r + 10, 0.5), (3, r + 7, 0.8), (4.5, r, 0.4), (5, r + 3, 0.5), (6, r + 5, 0.5), (7, r + 7, 0.6)]
        return [(b + bar * 8 + k, ln, m, 100) for bar in (0, 1) for k, m, ln in pattern]
    def kit(b, bar):
        out = [(b + k, 36, 100) for k in (0, 2.5, 4)] + [(b + k, 38, 100) for k in (2, 6)] + [(b + k, 38, 34) for k in (1.5, 3.5, 5.5, 7.5)]
        out += [(b + k / 2, 42, 50 if k % 2 else 68) for k in range(16)]
        if bar % 4 == 0:
            out.append((b, 49, 86))
        return out
    parts = [
        (4, melody + each_chord(chords, lambda b, r, t, c: [(b + k, 1.2, m, 52) for k in (1.5, 5.5, 9.5, 13.5) for m in t])),
        (17, each_chord(chords, lambda b, r, t, c: [(b, 16, m - 12, 46) for m in t])),
        (61, each_chord(chords, lambda b, r, t, c: [(b + k, 0.4, m, 90) for k in (3.5, 7, 11.5, 15) for m in t])),
        (33, each_chord(chords, groove)),
        ('drums', hits(chords, kit)),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def rival_red_orchestra():
    """Red, o treinador mais forte, calado no topo do Mt. Silver: rock épico com orquestra. A guitarra distorcida na
    melodia (dobrada pelos metais uma oitava abaixo), as cordas correndo em semicolcheias, os metais em ataques no fim
    dos compassos, o coro sustentando os acordes, o vento da neve no fundo (o cume gelado), o piano em oitavas graves, o
    baixo em colcheias e a bateria pesada com bumbo duplo."""
    lead, chords, bpm = rival_song('red')
    melody = lead_notes(lead, 112, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.1)
    def strings(b, r, t, c):  # semicolcheias: a nota do acorde e a vizinha, subindo
        cell = [t[0], t[1], t[2], t[1]]
        return [(b + k / 2, 0.45, cell[k % 4] + 12, 70 if k % 4 == 0 else 58) for k in range(32)]
    def stabs(b, r, t, c):
        return [(b + k, 0.8, m, 100) for k in (6, 7, 14, 15) for m in (t[0], t[2])]
    def kit(b, bar):
        out = [(b + k / 2, 36, 104 if k % 2 == 0 else 88) for k in range(16)] + [(b + k, 38, 110) for k in (2, 6)]
        out += [(b + k, 42, 70) for k in range(8)]
        if bar % 4 == 3:
            out = [x for x in out if x[0] < b + 6] + [(b + 6 + r / 2, (48, 47, 45, 41)[r], 108) for r in range(4)]
        if bar % 2 == 0:
            out.append((b, 49, 104))
        return out
    parts = [
        (30, melody, {'cc': {1: 20}, 'amp': {'drive': 20, 'gain': 1.15, 'pan': 0.0}}),
        (61, [(st, ln, m - 12, 92) for st, ln, m, v in melody]),
        (48, each_chord(chords, strings)),
        (61, each_chord(chords, stabs)),
        (52, each_chord(chords, lambda b, r, t, c: [(b, 16, m, 58) for m in t])),
        (99, each_chord(chords, lambda b, r, t, c: [(b, 16, t[0] + 12, 40)] if c % 2 == 0 else [])),  # o vento da neve
        (0, each_chord(chords, lambda b, r, t, c: [(b + k, 1.8, m, 90) for k in (0, 4, 8, 12) for m in (r, r + 12)])),
        (29, each_chord(chords, lambda b, r, t, c: [(b + k, 0.85, m, 84 if k % 2 == 0 else 70) for k in range(16) for m in (r + 12, r + 19)]), {'amp': {'drive': 32, 'gain': 0.6, 'double': True}}),
        (33, each_chord(chords, lambda b, r, t, c: [(b + k, 0.85, r, 104 if k % 2 == 0 else 90) for k in range(16)])),
        ('drums', hits(chords, kit)),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def rival_lillie_orchestra():
    """Lillie (Alola): delicada, mas determinada (a menina que cresceu e agora luta). O piano na melodia com a flauta
    dobrando uma oitava acima, as cordas em pizzicato, a harpa em arpejos, as cordas longas crescendo por baixo, o baixo
    suave e uma bateria leve (só o chimbal, o aro da caixa e o bumbo macio)."""
    lead, chords, bpm = rival_song('lillie')
    melody = lead_notes(lead, 96, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.15)
    parts = [
        (0, melody),
        (73, [(st, ln, m + 12, 70) for st, ln, m, v in melody]),
        (45, each_chord(chords, lambda b, r, t, c: [(b + k, 0.6, [t[0], t[2], t[1], t[2]][(k // 2) % 4], 66) for k in range(0, 16, 2)])),
        (46, each_chord(chords, lambda b, r, t, c: [(b + k / 2, 0.9, [t[0], t[1], t[2], t[0] + 12][k % 4] + 12, 50) for k in range(32)])),
        (49, each_chord(chords, lambda b, r, t, c: [(b, 16, m - 12, 54) for m in t])),
        (33, each_chord(chords, lambda b, r, t, c: [(b + k, 1.8, r + (7 if k % 8 == 4 else 0), 84) for k in range(0, 16, 2)])),
        ('drums', hits(chords, lambda b, bar: [(b + k, 36, 72) for k in (0, 4.5)] + [(b + k, 37, 66) for k in (2, 6)] + [(b + k, 42, 50) for k in range(8)] + ([(b, 49, 70)] if bar % 4 == 0 else []))),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def rival_az_orchestra():
    """AZ, o antigo rei de Kalos (3.000 anos de tristeza, à procura do Floette dele): uma realeza em ruínas. O cravo
    na melodia (a corte antiga) dobrado pelo violoncelo em lamento, as cordas graves sustentando, o sino distante no
    começo das frases, a harpa em arpejos lentos, os tímpanos marcando devagar e o pad escuro de fundo; sem bateria."""
    lead, chords, bpm = rival_song('az')
    melody = lead_notes(lead, 98, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.25)
    parts = [
        (6, melody),
        (42, [(st, ln, m - 12, 84) for st, ln, m, v in melody]),
        (48, each_chord(chords, lambda b, r, t, c: [(b, 16, m - 12, 62) for m in t])),
        (14, each_chord(chords, lambda b, r, t, c: [(b, 8, t[0] + 12, 70)] if c % 2 == 0 else [])),
        (46, each_chord(chords, lambda b, r, t, c: [(b + k, 1.8, [t[0], t[1], t[2], t[0] + 12][(k // 2) % 4], 52) for k in range(0, 16, 2)])),
        (43, each_chord(chords, lambda b, r, t, c: [(b + k, 3.8, r, 88) for k in (0, 8)])),
        (47, each_chord(chords, lambda b, r, t, c: [(b, 2, r, 100), (b + 8, 2, r, 84)])),
        (89, each_chord(chords, lambda b, r, t, c: [(b, 16, m - 12, 40) for m in t])),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def rival_anabel_orchestra():
    """Anabel, a Cérebro da Frente que virou agente da Polícia Internacional: tema de filme de espião dos anos 60. A
    guitarra grave na melodia (notas cheias, pelo amplificador, com um pouco de drive), o trompete com surdina
    respondendo no fim das frases, as cordas em suspense (notas longas e o semitom por cima), os metais graves em
    acordes curtos, o contrabaixo andando e a bateria de jazz com vassourinha (o balanço discreto)."""
    lead, chords, bpm = rival_song('anabel')
    swing = 0.25
    melody = [(st, ln, m - 12, v) for st, ln, m, v in lead_notes(lead, 104, maxlen=4, keep=lambda i: i % 2 == 0, swing=swing, extra=0.15)]
    answer = [(st + 2, min(ln, 1.5), m + 12, 70) for st, ln, m, v in melody if int(st) % 16 == 8]
    def walk(b, r, t, c):
        line = [r, r + 3, r + 7, r + 10, r + 12, r + 10, r + 7, r + 5]
        return [(_sw(b + k * 2, swing), 1.8, line[k], 96) for k in range(8)]
    def suspense(b, r, t, c):  # as cordas: o acorde longo e o semitom por cima na segunda metade (a tensão)
        return [(b, 16, t[0], 52), (b, 16, t[2], 50), (b + 8, 8, t[2] + 1, 40)]
    parts = [
        (27, melody, {'amp': {'drive': 8, 'gain': 1.0, 'pan': 0.0}}),
        (59, answer),
        (48, each_chord(chords, suspense)),
        (61, each_chord(chords, lambda b, r, t, c: [(b + k, 0.5, m, 86) for k in (3, 11) for m in (t[0] - 12, t[2] - 12)])),
        (32, each_chord(chords, walk)),
        ('drums', hits(chords, lambda b, bar: swing_kit(b, bar, swing), swing)),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def rival_dexio_orchestra():
    """Dexio, o assistente do Professor Sycamore (de Kalos, em Alola): sério, atlético e confiante. O acordeão na
    melodia (o toque francês de Kalos) com a guitarra limpa dobrando, o piano elétrico nos acordes em contratempo, as
    cordas sustentando, o baixo marcado em colcheias (o treino) e a bateria pop firme com palmas no 2 e no 4."""
    lead, chords, bpm = rival_song('dexio')
    melody = lead_notes(lead, 100, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.1)
    parts = [
        (21, melody),
        (27, [(st, ln, m - 12, 74) for st, ln, m, v in melody], {'amp': {'drive': 3, 'gain': 0.7, 'pan': 0.3}}),
        (4, each_chord(chords, lambda b, r, t, c: [(b + k, 0.8, m, 62) for k in (1, 3, 5, 7, 9, 11, 13, 15) for m in t])),
        (49, each_chord(chords, lambda b, r, t, c: [(b, 16, m - 12, 50) for m in t])),
        (33, each_chord(chords, lambda b, r, t, c: [(b + k, 0.85, r + (12 if k % 8 == 7 else 0), 100 if k % 2 == 0 else 86) for k in range(16)])),
        ('drums', hits(chords, lambda b, bar: pop_kit(b, bar, tamb=False) + [(b + k, 39, 84) for k in (2, 6)])),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def rival_sina_orchestra():
    """Sina, a parceira do Dexio, que adora o gelo: o tema irmão do dele, em tom de inverno. O acordeão de Kalos na
    melodia com a flauta dobrando, a celesta em notas soltas e lentas (flocos caindo), as cordas suaves, a harpa nos
    acordes, o baixo leve e a bateria macia com o pandeiro de leve (os sinos de trenó)."""
    lead, chords, bpm = rival_song('sina')
    melody = lead_notes(lead, 96, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.15)
    parts = [
        (21, melody),
        (73, [(st, ln, m + 12, 62) for st, ln, m, v in melody]),
        (8, each_chord(chords, lambda b, r, t, c: [(b + k, 2.5, [t[2], t[0], t[1], t[0]][(k // 4) % 4] + 24, 44) for k in (2, 6, 10, 14)])),
        (49, each_chord(chords, lambda b, r, t, c: [(b, 16, m - 12, 52) for m in t])),
        (46, each_chord(chords, lambda b, r, t, c: [(b + k, 1.6, m, 56) for k in (0, 8) for m in t])),
        (33, each_chord(chords, lambda b, r, t, c: [(b + k, 1.8, r + (7 if k % 8 == 4 else 0), 80) for k in range(0, 16, 2)])),
        ('drums', hits(chords, lambda b, bar: [(b + k, 36, 74) for k in (0, 4)] + [(b + k, 37, 62) for k in (2, 6)] + [(b + k, 54, 46) for k in range(8)] + ([(b, 49, 66)] if bar % 4 == 0 else []))),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def rival_benga_orchestra():
    """Benga, o neto do Alder (o pós-jogo de Black 2/White 2): garoto aventureiro, rock animado. A guitarra na melodia
    dele (pelo amplificador), a guitarra base em colcheias, o baixo correndo, a bateria rápida e, na segunda metade, os
    metais tocando a melodia do tema do avô por cima (o mesmo tom e os mesmos acordes do Alder: o eco da família)."""
    lead, chords, bpm = rival_song('benga')
    steps = len(lead)
    half = steps // 2
    melody = lead_notes(lead, 108, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.05)
    grandpa, _ = compose('alder', 67, 'dorian', [0, 6, 3, 4], climax=True)
    echo = [(st, ln, m - 12, 84) for st, ln, m, v in lead_notes(grandpa, 96, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.1) if half <= st < steps - 1]
    parts = [
        (29, melody, {'amp': {'drive': 12, 'gain': 1.1, 'pan': 0.0}}),
        (61, echo),
        (28, each_chord(chords, lambda b, r, t, c: [(b + k, 0.85, m, 84 if k % 2 == 0 else 70) for k in range(16) for m in (r + 12, r + 19)]), {'amp': {'drive': 22, 'gain': 0.55, 'double': True}}),
        (33, each_chord(chords, lambda b, r, t, c: [(b + k, 0.85, r + (12 if k % 4 == 3 else 0), 100 if k % 2 == 0 else 86) for k in range(16)])),
        ('drums', hits(chords, lambda b, bar: rock_kit(b, bar, (0, 3, 4)))),
    ]
    return render(parts, bpm, steps, soundfont=MUSESCORE)


def rival_eusine_orchestra():
    """Eusine, o místico de capa que passa a vida atrás do Suicune (HeartGold/SoulSilver): misterioso e elegante. A
    flauta na melodia com o órgão suave por baixo (o teclado de mágico), a harpa em arpejos como água correndo (o
    Suicune), as cordas em notas longas, o baixo suave e a bateria leve com o aro da caixa e o chimbal."""
    lead, chords, bpm = rival_song('eusine')
    melody = lead_notes(lead, 98, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.2)
    parts = [
        (73, melody),
        (16, [(st, ln, m - 12, 60) for st, ln, m, v in melody]),
        (46, each_chord(chords, lambda b, r, t, c: [(b + k / 2, 0.9, [t[0], t[1], t[2], t[0] + 12, t[2], t[1]][k % 6] + 12, 48) for k in range(32)])),
        (49, each_chord(chords, lambda b, r, t, c: [(b, 16, m - 12, 54) for m in t])),
        (33, each_chord(chords, lambda b, r, t, c: [(b + k, 1.8, r + (7 if k % 8 == 4 else 0), 82) for k in range(0, 16, 2)])),
        ('drums', hits(chords, lambda b, bar: [(b + k, 36, 76) for k in (0, 3, 4)] + [(b + k, 37, 66) for k in (2, 6)] + [(b + k, 42, 50) for k in range(8)] + ([(b, 49, 66)] if bar % 4 == 0 else []))),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def rival_ryuki_orchestra():
    """Ryuki, o roqueiro de Alola com Pokémon dragão: heavy metal de show. O riff grave em semicolcheias nas duas
    guitarras pesadas (dobradas, nos dois lados), a guitarra solo na melodia, os metais graves rugindo no começo das
    frases (o rugido do dragão), o baixo colado no riff e a bateria de metal com bumbo duplo e prato a cada 2 compassos."""
    lead, chords, bpm = rival_song('ryuki')
    melody = lead_notes(lead, 112, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.05)
    def riff(b, r, t, c):
        return [(b + k / 2, 0.42, r + (1 if k % 8 == 7 else 0), 100 if k % 4 == 0 else 84) for k in range(32)]
    def kit(b, bar):
        out = [(b + k / 2, 36, 110 if k % 2 == 0 else 96) for k in range(16)] + [(b + k, 38, 116) for k in (2, 6)] + [(b + k, 42, 72) for k in range(8)]
        if bar % 2 == 0:
            out.append((b, 49, 112))
        if bar % 4 == 3:
            out = [x for x in out if x[0] < b + 6] + [(b + 6 + r / 4, (48, 47, 45, 41)[r // 2], 110) for r in range(8)]
        return out
    parts = [
        (30, melody, {'cc': {1: 25}, 'amp': {'drive': 26, 'gain': 1.15, 'pan': 0.0}}),
        (30, each_chord(chords, lambda b, r, t, c: [(st, ln, m + 12, v) for st, ln, m, v in riff(b, r, t, c)] + [(st, ln, m + 19, v - 10) for st, ln, m, v in riff(b, r, t, c)]), {'amp': {'drive': 40, 'gain': 0.7, 'double': True}}),
        (61, each_chord(chords, lambda b, r, t, c: [(b, 3, m, 108) for m in (t[0] - 12, t[2] - 12)] if c % 2 == 0 else [])),
        (34, each_chord(chords, riff)),
        ('drums', hits(chords, kit)),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE, squash=1.8)


def rival_sordward_shielbert_orchestra():
    """Sordward e Shielbert, os irmãos que se acham da realeza (o pós-jogo de Sword/Shield): pomposo e meio ridículo. O
    cravo na melodia (a corte antiga) com os trompetes de corte dobrando, as cordas em colcheias marcadas, a tuba no
    "um-pá", os tímpanos, a caixa de marcha (os guardas) e o xilofone tropeçando no fim das frases (a nobreza falsa)."""
    lead, chords, bpm = rival_song('sordward-e-shielbert')
    melody = lead_notes(lead, 102, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.1)
    def trip(b, r, t, c):  # o tropeço: o xilofone descendo meio fora do lugar no fim de cada frase
        return [(b + 14 + q / 3, 0.3, t[2] + 24 - q * 3, 76) for q in range(5)] if c % 2 == 1 else []
    parts = [
        (6, melody),
        (56, [(st, ln, m, 80) for st, ln, m, v in melody]),
        (48, each_chord(chords, lambda b, r, t, c: [(b + k, 0.8, [t[0], t[1], t[2], t[1]][(k // 2) % 4], 60) for k in range(0, 16, 2)])),
        (58, each_chord(chords, lambda b, r, t, c: [(b + k * 2, 1.2, [r, r + 7][k % 2], 100) for k in range(8)])),
        (13, each_chord(chords, trip)),
        (47, each_chord(chords, lambda b, r, t, c: [(b, 2, r, 104), (b + 8, 2, r, 90)])),
        ('drums', hits(chords, lambda b, bar: [(b + k, 36, 84) for k in (0, 4)] + [(b + k, 38, 92) for k in (2, 6)] + [(b + k / 2, 38, 50) for k in (1, 3, 9, 11, 13)] + ([(b, 49, 90)] if bar % 4 == 0 else []))),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


RIVALS = {'blue': rival_blue_orchestra, 'silver': rival_silver_orchestra, 'brendan-may': rival_brendan_may_orchestra,
          'wally': rival_wally_orchestra, 'barry': rival_barry_orchestra, 'cheren': rival_cheren_orchestra,
          'bianca': rival_bianca_orchestra, 'hugh': rival_hugh_orchestra, 'n': rival_n_orchestra,
          'serena-calem': rival_serena_calem_orchestra, 'shauna': rival_shauna_orchestra, 'tierno': rival_tierno_orchestra,
          'trevor': rival_trevor_orchestra, 'hau': rival_hau_orchestra, 'gladion': rival_gladion_orchestra,
          'hop': rival_hop_orchestra, 'bede': rival_bede_orchestra, 'marnie': rival_marnie_orchestra,
          'nemona': rival_nemona_orchestra, 'arven': rival_arven_orchestra, 'red': rival_red_orchestra, 'lillie': rival_lillie_orchestra, 'az': rival_az_orchestra, 'anabel': rival_anabel_orchestra, 'dexio': rival_dexio_orchestra, 'sina': rival_sina_orchestra, 'benga': rival_benga_orchestra, 'eusine': rival_eusine_orchestra, 'ryuki': rival_ryuki_orchestra, 'sordward-e-shielbert': rival_sordward_shielbert_orchestra}  # os rivais já feitos (os outros tocam o tema da região)


# Os vilões: um tema para cada equipe (os comandantes dividem) e um próprio para os personagens importantes.
VILLAIN_THEMES = {
    'team_rocket': (62, 'minor', [0, 3, 4, 0], 150),
    'giovanni': (67, 'harmonic', [0, 5, 3, 4], 100),
    'team_magma': (64, 'phrygian', [0, 1, 0, 6], 160),
    'maxie': (62, 'harmonic', [0, 5, 1, 4], 150),
    'team_aqua': (65, 'dorian', [0, 3, 6, 4], 160),
    'archie': (62, 'minor', [0, 5, 2, 6], 152),
    'team_galactic': (60, 'minor', [0, 5, 6, 4], 158),
    'cyrus': (61, 'minor', [0, 5, 3, 4], 138),
    'team_plasma': (62, 'dorian', [0, 6, 3, 4], 150),
    'colress': (65, 'harmonic', [0, 1, 5, 4], 120),
    'team_flare': (60, 'minor', [0, 3, 6, 4], 128),
    'lysandre': (66, 'harmonic', [0, 3, 5, 4], 132),
    'team_skull': (66, 'minor', [0, 5, 6, 4], 130),
    'guzma': (64, 'phrygian', [0, 1, 0, 6], 135),
    'team_aether': (64, 'major', [0, 2, 5, 3], 140),
    'team_ultra': (71, 'minor', [0, 5, 2, 6], 120),
    'lusamine': (64, 'harmonic', [0, 5, 3, 4], 108),
    'team_star': (69, 'minor', [0, 5, 2, 6], 168),
    'giacomo': (65, 'minor', [0, 5, 6, 4], 140),
    'ortega': (62, 'major', [0, 4, 5, 3], 160),
    'ghetsis': (60, 'phrygian', [0, 1, 5, 4], 104),
    'penny': (63, 'minor', [0, 5, 3, 6], 150),
    'rose': (62, 'harmonic', [0, 5, 3, 4], 138),
    'team_macro_cosmos': (66, 'minor', [0, 5, 6, 3], 126),
    'jessie-e-james': (65, 'harmonic', [0, 3, 5, 4], 144),
    'team_yell': (66, 'minor', [0, 6, 5, 4], 160),
}


def villain_song(name):
    tonic, mode, prog, bpm = VILLAIN_THEMES[name]
    lead, chords = compose(f'villain-{name}', tonic, mode, prog)
    return lead, chords, bpm


def swing_kit(b, bar, swing=0.33, heavy=False):
    """Bateria de jazz com balanço: prato de condução (o "ding, ding-da-ding"), chimbal no 2 e no 4, bumbo leve e
    caixa nos contratempos; [heavy]: bumbo e caixa mais fortes."""
    out = [(b + k, 51, 78) for k in (0, 2, 3, 4, 6, 7)] + [(b + k, 44, 70) for k in (2, 6)]
    out += [(b + k, 36, 96 if heavy else 66) for k in (0, 4)] + [(b + k, 38, 92 if heavy else 52) for k in (3, 7)]
    if bar % 4 == 3:
        out += [(b + 6 + r / 2, 38, 70 + 10 * r) for r in range(4)]
    if bar % 4 == 0:
        out.append((b, 49, 96 if heavy else 78))
    return out


def team_rocket_orchestra():
    """Equipe Rocket (os comandantes e executivos): jazz noir de máfia. Saxofone tenor na melodia com o trompete de
    surdina respondendo, contrabaixo andando, piano nos acordes e bateria de jazz com balanço."""
    lead, chords, bpm = villain_song('team_rocket')
    swing = 0.3
    melody = lead_notes(lead, 104, maxlen=4, swing=swing, extra=0.1)
    answer = [(st + 4, min(ln, 2), m + 7 if m + 7 < 84 else m - 5, 66) for st, ln, m, v in melody if int(st) % 16 < 4]
    def walk(b, r, t, c):
        nxt = chords[(c + 1) % len(chords)][0]
        nxt = nxt if nxt < 46 else nxt - 12
        line = [r, r + 3, r + 7, r + 10, r + 12, r + 10, r + 7, nxt + 1]
        return [(b + k * 2, 1.9, line[k], 96) for k in range(8)]
    def comp(b, r, t, c):
        return [(_sw(b + k, swing), 0.6, m, 58) for k in (1, 3.5, 6, 9, 11.5, 14) for m in (t[0], t[1] + 10 - 10, t[2])]
    parts = [
        (66, melody, {'cc': {1: 30}}),
        (59, answer),
        (32, each_chord(chords, walk)),
        (0, each_chord(chords, comp)),
        ('drums', hits(chords, lambda b, bar: swing_kit(b, bar, swing), swing)),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def giovanni_orchestra():
    """Giovanni, o chefão da máfia: lento, elegante e ameaçador, no estilo dos filmes de máfia italiana. O trompete
    com surdina sozinho na melodia, o bandolim em trêmulo dobrando, o acordeão nos acordes, o baixo descendo meio tom
    por vez no acorde da tônica (a ameaça), o piano grave na nota pedal, cordas graves, violoncelo em contracanto,
    tímpanos e o prato em rufada no fim das frases; sem bateria (o chefe não corre)."""
    lead, chords, bpm = villain_song('giovanni')
    melody = lead_notes(lead, 100, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.2)
    tremolo = [(st + j / 4, 0.24, m, 52) for st, ln, m, v in melody for j in range(int(ln * 4))]
    def bass(b, r, t, c):
        if c % 4 == 0:  # no acorde da tônica, o baixo desce meio tom por vez
            return [(b + k * 4, 3.8, r + 12 - k, 96) for k in range(4)]
        return [(b + k * 4, 3.8, [r + 12, r + 7, r + 12, r + 7][k], 92) for k in range(4)]
    def swell(b, r, t, c):
        return [(b + 12 + q / 4, 0.25, 49, 30 + 6 * q) for q in range(16)] if c % 2 == 1 else []
    parts = [
        (59, melody, {'cc': {1: 35}}),
        (25, tremolo),
        (21, each_chord(chords, lambda b, r, t, c: [(b + k, 3.5, m, 50) for k in (0, 4, 8, 12) for m in t])),
        (45, each_chord(chords, bass)),
        (0, each_chord(chords, lambda b, r, t, c: [(b, 6, r, 96), (b, 6, r + 12, 80), (b + 8, 6, r, 86)])),
        (48, each_chord(chords, lambda b, r, t, c: [(b, 16, m - 12, 56) for m in t])),
        (42, each_chord(chords, lambda b, r, t, c: [(b + 4, 4, t[1] - 12, 74), (b + 12, 4, t[2] - 12, 72)])),
        (47, each_chord(chords, lambda b, r, t, c: [(b, 3, r, 108)] + ([(b + 8, 3, r, 90)] if c % 2 else []))),
        ('drums', each_chord(chords, swell)),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def team_magma_orchestra():
    """Equipe Magma (comandantes): vulcão e indústria. Guitarras pesadas pelo amplificador, baixo sintetizado
    pulsando, percussão metálica (a bigorna, a fábrica), taiko e bumbo pesado."""
    lead, chords, bpm = villain_song('team_magma')
    melody = lead_notes(lead, 110, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.05)
    def kit(b, bar):
        out = [(b + k, 36, 110) for k in (0, 1.5, 3, 4, 5.5)] + [(b + k, 38, 104) for k in (2, 6)]
        out += [(b + k, 53, 80) for k in (1, 3, 5, 7)] + [(b + k, 67, 70) for k in (0.5, 4.5)]  # a bigorna
        if bar % 2 == 0:
            out.append((b, 52, 100))
        return out
    parts = [
        (29, melody, {'amp': {'drive': 22, 'gain': 1.05, 'pan': 0.0}}),
        (28, each_chord(chords, lambda b, r, t, c: [(b + k / 2, 0.22, m, 86 if k % 4 == 0 else 66) for k in range(32) for m in (r + 12, r + 19)]), {'amp': {'drive': 40, 'gain': 0.7, 'double': True}}),
        (38, each_chord(chords, lambda b, r, t, c: [(b + k / 2, 0.4, r, 100 if k % 2 == 0 else 80) for k in range(32)])),
        (116, each_chord(chords, lambda b, r, t, c: [(b + bar * 8 + k, 1, r + 12, 110) for bar in (0, 1) for k in (0, 3, 4)])),
        ('drums', hits(chords, kit)),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def maxie_orchestra():
    """Maxie, o chefe da Equipe Magma, cientista frio e calculista: sintetizador em arpejos gelados por cima de metais
    graves, guitarras pesadas, cordas em trêmulo e tímpanos."""
    lead, chords, bpm = villain_song('maxie')
    melody = lead_notes(lead, 106, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.1)
    parts = [
        (57, [(st, ln, m - 12, 104) for st, ln, m, v in melody]),
        (60, melody),
        (81, each_chord(chords, lambda b, r, t, c: [(b + k / 2, 0.4, [t[0], t[1], t[2], t[1] + 12, t[2] + 12, t[1] + 12, t[2], t[1]][k % 8], 46) for k in range(32)])),
        (28, each_chord(chords, lambda b, r, t, c: [(b + k, 0.85, m, 84 if k % 2 == 0 else 70) for k in range(16) for m in (r + 12, r + 19)]), {'amp': {'drive': 34, 'gain': 0.6, 'double': True}}),
        (44, each_chord(chords, lambda b, r, t, c: [(b, 16, m, 56) for m in t])),
        (58, each_chord(chords, lambda b, r, t, c: [(b + k, 1.8, r, 100) for k in range(0, 16, 2)])),
        (47, each_chord(chords, lambda b, r, t, c: [(b, 2, r, 112), (b + 8, 2, r, 98)])),
        ('drums', hits(chords, lambda b, bar: rock_kit(b, bar, (0, 3, 4)))),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def team_aqua_orchestra():
    """Equipe Aqua (comandantes): rock de pirata. Acordeão e guitarra na melodia com o violino folk (fiddle), pad
    aquático de sintetizador e bateria com balanço (o gingado do mar)."""
    lead, chords, bpm = villain_song('team_aqua')
    swing = 0.25
    melody = lead_notes(lead, 104, maxlen=4, keep=lambda i: i % 2 == 0, swing=swing, extra=0.1)
    parts = [
        (21, melody),
        (110, [(st, ln, m + 12, 76) for st, ln, m, v in melody]),
        (29, melody, {'amp': {'drive': 12, 'gain': 0.55, 'pan': 0.3}}),
        (28, each_chord(chords, lambda b, r, t, c: [(_sw(b + k, swing), 0.85, m, 80) for k in range(16) for m in (r + 12, r + 19)]), {'amp': {'drive': 24, 'gain': 0.5, 'pan': -0.4}}),
        (92, each_chord(chords, lambda b, r, t, c: [(b, 16, m - 12, 54) for m in t])),
        (33, each_chord(chords, lambda b, r, t, c: [(_sw(b + k, swing), 0.85, r + (7 if k % 4 == 2 else 0), 96) for k in range(16)])),
        ('drums', hits(chords, lambda b, bar: pop_kit(b, bar, tamb=False), swing)),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def archie_orchestra():
    """Archie, o chefe da Equipe Aqua, capitão pirata: canção de marinheiro (sea shanty) virada batalha. Metais e
    fiddle na melodia, acordeão, tuba no baixo em "um-pá" e bateria grande com o balanço de navio."""
    lead, chords, bpm = villain_song('archie')
    swing = 0.33
    melody = lead_notes(lead, 108, maxlen=4, keep=lambda i: i % 2 == 0, swing=swing, extra=0.1)
    parts = [
        (61, melody),
        (110, [(st, ln, m + 12, 84) for st, ln, m, v in melody]),
        (21, each_chord(chords, lambda b, r, t, c: [(_sw(b + k, swing), 0.8, m, 60) for k in range(1, 16, 2) for m in t])),
        (58, each_chord(chords, lambda b, r, t, c: [(b + k, 1.6, [r, r + 7][(k // 2) % 2], 104) for k in range(0, 16, 2)])),
        (47, each_chord(chords, lambda b, r, t, c: [(b, 2, r, 108), (b + 8, 2, r, 96)])),
        ('drums', hits(chords, lambda b, bar: [(b + k, 36, 108) for k in (0, 4)] + [(b + k, 38, 104) for k in (2, 6)] + [(_sw(b + k, swing), 42, 70) for k in range(8)] + ([(b, 49, 106)] if bar % 2 == 0 else [(b + 6 + r / 2, 38, 80 + 8 * r) for r in range(4)]), swing)),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def electro_kit(b, bar, heavy=False):
    """Bateria eletrônica: bumbo no 1 e no 3 (e no "e" do 3), caixa eletrônica no 2 e no 4, chimbal em
    semicolcheias e prato a cada 2 compassos."""
    out = [(b + k, 36, 110 if heavy else 100) for k in (0, 4, 5)] + [(b + k, 40, 100) for k in (2, 6)]
    out += [(b + k / 2, 42, 46 if k % 2 else 62) for k in range(16)]
    if bar % 2 == 0:
        out.append((b, 49, 96 if heavy else 84))
    return out


def team_galactic_orchestra():
    """Equipe Galáctica (Mars, Jupiter e Saturn): espaço frio. Sintetizador de serra na melodia, arpejador rápido, pad
    varrendo como vento espacial, baixo sintetizado, bateria eletrônica e a atmosfera."""
    lead, chords, bpm = villain_song('team_galactic')
    melody = lead_notes(lead, 100, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.1)
    parts = [
        (81, melody, {'cc': {1: 25}}),
        (81, each_chord(chords, lambda b, r, t, c: [(b + k / 2, 0.4, [t[0], t[1], t[2], t[0] + 12][k % 4], 44) for k in range(32)])),
        (95, each_chord(chords, lambda b, r, t, c: [(b, 16, m - 12, 58) for m in t])),
        (99, each_chord(chords, lambda b, r, t, c: [(b, 16, t[0] + 12, 40)] if c % 2 == 0 else [])),
        (39, each_chord(chords, lambda b, r, t, c: [(b + k, 0.8, r, 98 if k % 2 == 0 else 80) for k in range(16)])),
        ('drums', hits(chords, electro_kit)),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def cyrus_orchestra():
    """Cyrus, o chefe da Equipe Galáctica: apático, sem emoção nenhuma. A melodia achatada (presa numa faixa estreita,
    muitas notas repetidas, como quem fala sem entonação), todas com a mesma força (sem crescendo nem clímax), o baixo
    numa nota pedal que nunca muda (ele não reage a nada), um ostinato mecânico de sintetizador, órgão reto sem vibrato,
    pad estático e batida de metrônomo, sem pratos nem viradas."""
    lead, chords, bpm = villain_song('cyrus')
    tonic = VILLAIN_THEMES['cyrus'][0]
    flat = []
    for st, ln, m, v in lead_notes(lead, 80, maxlen=4, keep=lambda i: i % 4 == 0, extra=0.0):
        while m > tonic + 7:
            m -= 12
        while m < tonic - 2:
            m += 12
        flat.append((st, ln, m, 80))  # a mesma força sempre
    pedal = low_of(chords[0][0])
    parts = [
        (16, flat, {'cc': {1: 0}}),
        (80, [(st, ln, m + 12, 44) for st, ln, m, v in flat]),
        (81, each_chord(chords, lambda b, r, t, c: [(b + k / 2, 0.4, [tonic, tonic + 7, tonic + 12, tonic + 7][k % 4] - 12, 50) for k in range(32)])),
        (89, each_chord(chords, lambda b, r, t, c: [(b, 16, m - 12, 46) for m in t])),
        (38, [(k, 0.8, pedal, 84) for k in range(len(lead))]),
        ('drums', hits(chords, lambda b, bar: [(b + k, 36, 84) for k in (0, 4)] + [(b + k, 42, 60) for k in range(8)] + [(b + k, 37, 64) for k in (2, 6)])),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE, squash=2.6)


def team_plasma_orchestra():
    """Equipe Plasma (Zinzolin e os comandantes): música de igreja. O órgão de tubos no centro, com figuras rápidas de
    tocata barroca e acordes cheios, a pedaleira no baixo, o coro cantando a melodia em notas longas (canto litúrgico),
    os sinos da igreja no começo das frases e tímpanos; sem bateria. No modo dórico, o das músicas de igreja antigas."""
    lead, chords, bpm = villain_song('team_plasma')
    chant = lead_notes(lead, 96, maxlen=4, keep=lambda i: i % 4 == 0, extra=0.3)
    def toccata(b, r, t, c):  # semicolcheias: a nota do acorde e a vizinha, subindo e descendo (a tocata)
        cell = [t[2] + 12, t[1] + 12, t[2] + 12, t[0] + 12, t[2] + 12, t[1] + 12, t[2] + 12, t[0] + 24]
        return [(b + k / 2, 0.45, cell[k % 8], 72 if k % 4 == 0 else 60) for k in range(32)]
    def chords_(b, r, t, c):
        return [(b + k, 3.8, m, 82) for k in (0, 4, 8, 12) for m in (t[0], t[1], t[2], t[0] + 12)]
    parts = [
        (19, each_chord(chords, toccata) + each_chord(chords, chords_)),
        (19, each_chord(chords, lambda b, r, t, c: [(b + k, 3.8, r, 100) for k in (0, 4, 8, 12)] + [(b + k, 3.8, r - 12 if r >= 36 else r, 88) for k in (0, 8)])),
        (52, chant + [(st, ln, m - 12, 76) for st, ln, m, v in chant]),
        (14, each_chord(chords, lambda b, r, t, c: [(b, 8, t[0] + 12, 90), (b + 0.02, 8, t[0], 70)] if c % 2 == 0 else [])),
        (47, each_chord(chords, lambda b, r, t, c: [(b, 2, r, 106), (b + 8, 2, r, 92)])),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def colress_orchestra():
    """Colress, o cientista obcecado: o laboratório maligno. O teremim grave e sinistro na melodia (deslizando como um
    fantasma), a celesta de caixinha de música de filme de terror com notas que se chocam, cordas graves em trêmulo, o
    zumbido de uma máquina ligada no escuro, a batida de coração (bumbo duplo e lento), golpes metálicos e o trítono nos
    acentos; lento e pesado (half-time)."""
    lead, chords, bpm = villain_song('colress')
    tonic = VILLAIN_THEMES['colress'][0]
    melody = lead_notes(lead, 96, -12, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.4)
    def musicbox(b, r, t, c):  # a caixinha de música: a nota e a vizinha de meio tom (que se chocam)
        return [(b + k, 1.5, m, 46) for k, m in ((0, t[2] + 24), (2, t[2] + 25), (4, t[1] + 24), (6, t[0] + 24), (8, t[2] + 24), (10, t[1] + 25), (12, t[1] + 24), (14, t[0] + 23))]
    def heartbeat(b, bar):
        out = [(b, 36, 104), (b + 0.6, 36, 84), (b + 4, 36, 100), (b + 4.6, 36, 80)] + [(b + 4, 40, 74)]
        if bar % 2 == 1:
            out.append((b + 6, 53, 90))  # o golpe metálico
        return out
    parts = [
        (79, melody, {'glide': True, 'cc': {1: 80}}),
        (8, each_chord(chords, musicbox)),
        (44, each_chord(chords, lambda b, r, t, c: [(b, 16, m - 12, 62) for m in t])),
        (95, each_chord(chords, lambda b, r, t, c: [(b, 16, r + 12, 60), (b, 16, r + 18, 44)])),  # o zumbido, com o trítono
        (38, each_chord(chords, lambda b, r, t, c: [(b + k, 1.8, r, 96) for k in range(0, 16, 4)] + [(b + 6, 0.8, r + 6, 90)])),
        (47, each_chord(chords, lambda b, r, t, c: [(b, 3, r, 104)])),
        ('drums', hits(chords, heartbeat)),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def team_flare_orchestra():
    """Equipe Flare: electro-swing elegante e cruel (jazz dos anos 30 com batida eletrônica). Clarinete na melodia,
    trompetes de surdina em ataques curtos, contrabaixo andando com o baixo sintetizado, piano picotado, bumbo
    eletrônico em todo tempo com o chimbal em balanço e palmas."""
    lead, chords, bpm = villain_song('team_flare')
    swing = 0.33
    melody = lead_notes(lead, 104, maxlen=4, keep=lambda i: i % 2 == 0, swing=swing, extra=0.05)
    def walk(b, r, t, c):
        nxt = chords[(c + 1) % len(chords)][0]
        nxt = nxt if nxt < 46 else nxt - 12
        line = [r, r + 3, r + 7, r + 10, r + 12, r + 10, r + 7, nxt - 1]
        return [(b + k * 2, 1.8, line[k], 98) for k in range(8)]
    def kit(b, bar):
        out = [(b + k, 36, 110) for k in (0, 2, 4, 6)] + [(b + k, 39, 92) for k in (2, 6)]
        out += [(_sw(b + k, swing), 42, 70 if k % 2 else 56) for k in range(8)]
        if bar % 4 == 0:
            out.append((b, 49, 88))
        return out
    parts = [
        (71, melody, {'cc': {1: 20}}),
        (59, each_chord(chords, lambda b, r, t, c: [(_sw(b + k, swing), 0.4, m, 92) for k in (3, 7, 11, 15) for m in (t[0] + 12, t[2] + 12)])),
        (32, each_chord(chords, walk)),
        (38, each_chord(chords, lambda b, r, t, c: [(b + k, 0.5, r, 80) for k in range(0, 16, 2)])),
        (0, each_chord(chords, lambda b, r, t, c: [(_sw(b + k, swing), 0.3, m, 66) for k in (1, 3, 5, 9, 11, 13) for m in t])),
        ('drums', hits(chords, kit, swing)),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def lysandre_orchestra():
    """Lysandre, o chefe da Equipe Flare: grandioso e trágico. As cordas em lamento na melodia com as trompas, o coro e
    o órgão nos acordes, piano grave, tímpanos e os pratos em rufada nos clímax."""
    lead, chords, bpm = villain_song('lysandre')
    melody = lead_notes(lead, 106, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.2)
    parts = [
        (48, melody + [(st, ln, m - 12, 84) for st, ln, m, v in melody]),
        (60, [(st, ln, m - 12, 88) for st, ln, m, v in melody]),
        (52, each_chord(chords, lambda b, r, t, c: [(b, 16, m, 66) for m in t])),
        (19, each_chord(chords, lambda b, r, t, c: [(b, 16, m - 12, 50) for m in t])),
        (0, each_chord(chords, lambda b, r, t, c: [(b + k, 3.5, m, 88) for k in (0, 4, 8, 12) for m in (r + 12, t[0] - 12)])),
        (43, each_chord(chords, lambda b, r, t, c: [(b + k, 1.8, r, 96) for k in range(0, 16, 2)])),
        (47, each_chord(chords, lambda b, r, t, c: [(b, 2, r, 112), (b + 8, 2, r, 96)] + ([(b + 12 + q / 3, 0.3, r, 54 + 7 * q) for q in range(12)] if c % 2 else []))),
        ('drums', each_chord(chords, lambda b, r, t, c: [(b, 2, 49, 110)] + ([(b + 12 + q / 4, 0.25, 49, 36 + 5 * q) for q in range(16)] if c % 2 else []))),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def trap_kit(b, bar, rolls=1):
    """Batida de trap (half-time): bumbo sincopado, palma e caixa no tempo 3, chimbal em semicolcheias com rolos
    rápidos (em fusas) no fim do compasso; [rolls] 2: rolos em mais lugares (mais caótico)."""
    out = [(b + k, 36, 110) for k in (0, 1.5, 5)] + [(b + 4, 39, 104), (b + 4, 38, 90)]
    out += [(b + k / 2, 42, 64 if k % 2 else 78) for k in range(16) if not (k >= 12 and bar % 2 == 1)]
    if bar % 2 == 1 or rolls > 1:
        out += [(b + 6 + r / 4, 42, 56 + 4 * r) for r in range(8)]
    if rolls > 1:
        out += [(b + 2 + r / 4, 42, 60) for r in range(4)]
    if bar % 4 == 0:
        out.append((b, 49, 90))
    return out


def tamborzao(b, bar, heavy=False):
    """A batida do funk carioca (o tamborzão): bumbo em 3+3+2 (em semicolcheias: 1, 4 e 7 de cada metade), palmas no 2
    e no 4, os tambores e as congas fazendo o "tamborzão" e chimbal; [heavy]: bumbo dobrado e mais forte."""
    out = [(b + k, 36, 118 if heavy else 108) for k in (0, 1.5, 4, 5.5)] + [(b + k, 39, 100) for k in (2, 6)]
    out += [(b + k, 45, 84) for k in (3, 7)] + [(b + k, 47, 80) for k in (3.5, 7.5)] + [(b + k, 63, 70) for k in (1, 5)]
    out += [(b + k, 42, 56) for k in (0.5, 2.5, 4.5, 6.5)]
    if heavy:
        out += [(b + k, 36, 100) for k in (2.5, 6.5)]
    if bar % 4 == 0:
        out.append((b, 49, 92))
    return out


def team_skull_orchestra():
    """Equipe Skull (Plumeria e os comandantes): funk carioca. A batida tamborzão, o baixo 808 grave deslizando entre as
    notas, o sintetizador na melodia, o "vocal" curto picotado (a voz "oh" em ataques) e metais."""
    lead, chords, bpm = villain_song('team_skull')
    melody = lead_notes(lead, 100, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.05)
    parts = [
        (81, melody, {'cc': {1: 15}}),
        (53, each_chord(chords, lambda b, r, t, c: [(b + k, 0.35, t[0] + 12, 96) for k in (0, 1.5, 3, 8, 9.5, 11)])),  # o "vocal" picotado
        (61, each_chord(chords, lambda b, r, t, c: [(b + k, 0.4, m, 90) for k in (6, 14) for m in (t[0], t[2])])),
        (38, each_chord(chords, lambda b, r, t, c: [(b, 1.4, r, 116), (b + 1.5, 2, r, 110), (b + 4, 1.4, r + 12, 110), (b + 5.5, 2.5, r, 112),
                                                    (b + 8, 1.4, r, 116), (b + 9.5, 2, r + 7, 110), (b + 12, 1.4, r + 12, 110), (b + 13.5, 2.5, r, 112)]), {'glide': True}),
        ('drums', hits(chords, tamborzao)),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def guzma_orchestra():
    """Guzma, o chefe da Equipe Skull: funk bem agressivo (automotivo/mandelão). O 808 muito distorcido (estourando, pelo
    amplificador), a sirene de sintetizador subindo, o riff de duas notas a meio tom (insistente), golpes de orquestra e o
    tamborzão mais pesado."""
    lead, chords, bpm = villain_song('guzma')
    tonic = VILLAIN_THEMES['guzma'][0]
    riff = []
    for c in range(len(chords)):
        base = c * 16
        for k, m in ((0, tonic), (1, tonic + 1), (2, tonic), (3, tonic + 1), (4, tonic), (6, tonic + 1), (7, tonic + 3)):
            riff += [(base + k, 0.45, m, 104), (base + 8 + k, 0.45, m, 104)]
    siren = [(c * 16 + 12, 4, tonic + 12 + (12 if c % 4 == 3 else 7), 92) for c in range(len(chords)) if c % 2 == 1]
    parts = [
        (81, riff, {'cc': {1: 10}}),
        (81, [(st - 1, 0.2, m - 12, 60) for st, ln, m, v in siren] + siren, {'glide': True}),  # a sirene: desliza de uma oitava abaixo
        (38, each_chord(chords, lambda b, r, t, c: [(b, 1.4, r, 124), (b + 1.5, 2, r, 120), (b + 4, 1.4, r + 12, 118), (b + 5.5, 2.5, r, 120),
                                                    (b + 8, 1.4, r, 124), (b + 9.5, 2, r + 1, 118), (b + 12, 1.4, r + 12, 118), (b + 13.5, 2.5, r, 120)]), {'glide': True, 'amp': {'drive': 18, 'gain': 1.1, 'pan': 0.0}}),
        (55, each_chord(chords, lambda b, r, t, c: [(b, 1, t[0], 110), (b + 8, 1, t[0] + 1, 104)])),
        ('drums', hits(chords, lambda b, bar: tamborzao(b, bar, heavy=True))),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE, squash=1.4)


def team_aether_orchestra():
    """Fundação Aether (Faba e Lusamine): limpa e clínica, bonita mas perturbadora. Sinos e sintetizador puro na melodia,
    pad frio e branco, sinos em arpejo e bateria eletrônica precisa e enxuta."""
    lead, chords, bpm = villain_song('team_aether')
    melody = lead_notes(lead, 96, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.1)
    parts = [
        (80, melody, {'cc': {1: 0}}),
        (14, [(st, ln, m, 60) for st, ln, m, v in melody if int(st) % 4 == 0]),
        (88, each_chord(chords, lambda b, r, t, c: [(b + k / 2, 0.45, [t[0], t[1], t[2], t[0] + 12][k % 4] + 12, 46) for k in range(32)])),
        (89, each_chord(chords, lambda b, r, t, c: [(b, 16, m, 52) for m in t])),
        (38, each_chord(chords, lambda b, r, t, c: [(b + k, 0.8, r, 88) for k in range(0, 16, 2)])),
        ('drums', hits(chords, lambda b, bar: [(b + k, 36, 90) for k in (0, 4)] + [(b + k, 40, 80) for k in (2, 6)] + [(b + k / 2, 42, 44) for k in range(16)])),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def lusamine_orchestra():
    """Lusamine, a presidente da Fundação Aether: melancólica e dominadora. A melancolia no violoncelo solo em lamento
    (com o piano em notas soltas e a voz respondendo ao longe); o domínio nos metais graves em marcha (acordes pesados e
    lentos que mandam), no órgão na nota pedal e nos tímpanos firmes em todo tempo. Ligada à Aether pelos sinos e pelo
    pad frio, no tom dela (Mi), em menor harmônica."""
    lead, chords, bpm = villain_song('lusamine')
    melody = lead_notes(lead, 104, -12, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.3)
    echo = [(st + 2, ln, m + 24, 56) for st, ln, m, v in melody if int(st) % 8 == 0]
    pedal = low_of(chords[0][0])
    parts = [
        (42, melody, {'cc': {1: 40}}),
        (0, [(st, 1.5, m + 12, 60) for st, ln, m, v in melody if int(st) % 4 == 0]),
        (53, echo),
        (57, each_chord(chords, lambda b, r, t, c: [(b + k, 1.6, m, 100 if k % 4 == 0 else 84) for k in (0, 2, 4, 6, 8, 10, 12, 14) for m in (t[0] - 12, t[2] - 12)])),
        (58, each_chord(chords, lambda b, r, t, c: [(b + k, 1.8, r, 104) for k in range(0, 16, 2)])),
        (19, [(k, 16, pedal + 12, 58) for k in range(0, len(lead), 16)]),
        (14, each_chord(chords, lambda b, r, t, c: [(b, 8, t[0] + 12, 58)])),
        (89, each_chord(chords, lambda b, r, t, c: [(b, 16, m, 48) for m in t])),
        (47, each_chord(chords, lambda b, r, t, c: [(b + k, 1.2, r, 112 if k % 8 == 0 else 92) for k in range(0, 16, 2)])),
        ('drums', each_chord(chords, lambda b, r, t, c: [(b, 2, 49, 96)] if c % 2 == 0 else [])),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def team_ultra_orchestra():
    """Ultra Recon (Soliera e Dulse): etérea e alienígena. O sintetizador deslizando como uma voz de outro mundo, coro
    espacial, atmosfera, sinos de cristal e uma pulsação suave."""
    lead, chords, bpm = villain_song('team_ultra')
    melody = lead_notes(lead, 96, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.4)
    parts = [
        (79, melody, {'glide': True, 'cc': {1: 60}}),
        (91, each_chord(chords, lambda b, r, t, c: [(b, 16, m, 60) for m in t])),
        (99, each_chord(chords, lambda b, r, t, c: [(b, 16, t[0] + 12, 46)] if c % 2 == 0 else [])),
        (98, each_chord(chords, lambda b, r, t, c: [(b + k, 3, [t[0], t[2], t[1], t[2]][(k // 4) % 4] + 24, 48) for k in range(0, 16, 4)])),
        (38, each_chord(chords, lambda b, r, t, c: [(b + k, 1.6, r, 82) for k in range(0, 16, 2)])),
        ('drums', hits(chords, lambda b, bar: [(b + k, 36, 84) for k in (0, 4)] + [(b + 4, 40, 70)] + [(b + k, 42, 40) for k in range(8)])),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def team_star_orchestra():
    """Equipe Star (Mela, Atticus, Eri e Penny): a turma rebelde. Punk-rock com guitarras pelo amplificador e
    sintetizadores, o ronco de motor dos Starmobiles no grave e bateria animada."""
    lead, chords, bpm = villain_song('team_star')
    melody = lead_notes(lead, 108, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.05)
    parts = [
        (29, melody, {'amp': {'drive': 16, 'gain': 1.0, 'pan': 0.0}}),
        (81, [(st, ln, m + 12, 60) for st, ln, m, v in melody]),
        (28, each_chord(chords, lambda b, r, t, c: [(b + k, 0.85, m, 92 if k % 2 == 0 else 76) for k in range(16) for m in (r + 12, r + 19, r + 24)]), {'amp': {'drive': 32, 'gain': 0.7, 'double': True}}),
        (38, each_chord(chords, lambda b, r, t, c: [(b + k / 2, 0.4, r, 96 if k % 2 == 0 else 78) for k in range(32)])),  # o motor
        ('drums', hits(chords, lambda b, bar: pop_kit(b, bar, tamb=False))),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def giacomo_orchestra():
    """Giacomo, o DJ do esquadrão Sombrio da Equipe Star: EDM sombrio. Bumbo em todo tempo, baixo sintetizado com
    wobble, sintetizador serrado em acordes que pulsam e o build-up com a caixa acelerando até o "drop"."""
    lead, chords, bpm = villain_song('giacomo')
    melody = lead_notes(lead, 100, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.05)
    def kit(b, bar):
        out = [(b + k, 36, 118) for k in (0, 2, 4, 6)] + [(b + k, 39, 96) for k in (2, 6)] + [(b + k, 46, 70) for k in (1, 3, 5, 7)]
        if bar % 8 == 7:  # o build-up: a caixa acelerando até o drop
            out += [(b + r / 4, 38, 50 + 2 * r) for r in range(32)]
        if bar % 8 == 0:
            out.append((b, 49, 110))
        return out
    parts = [
        (81, melody, {'cc': {1: 20}}),
        (81, each_chord(chords, lambda b, r, t, c: [(b + k / 2, 0.35, m, 74 if k % 4 == 2 else 54) for k in range(32) for m in t])),  # os acordes pulsando
        (39, each_chord(chords, lambda b, r, t, c: [(b + k / 4, 0.24, r + (12 if k % 8 >= 6 else 0), 110 if k % 2 == 0 else 70) for k in range(64)])),  # o wobble
        (95, each_chord(chords, lambda b, r, t, c: [(b, 16, m - 12, 52) for m in t])),
        ('drums', hits(chords, kit)),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def ortega_orchestra():
    """Ortega, do esquadrão Fada da Equipe Star: pop fofo e exagerado (kawaii). Glockenspiel e sintetizador doce na
    melodia, arpejos brilhantes, palmas, baixo saltitante e bateria pop."""
    lead, chords, bpm = villain_song('ortega')
    melody = lead_notes(lead, 100, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.05)
    parts = [
        (9, [(st, ln, m + 12, 80) for st, ln, m, v in melody]),
        (80, melody, {'cc': {1: 15}}),
        (8, each_chord(chords, lambda b, r, t, c: [(b + k / 2, 0.4, [t[0], t[1], t[2], t[0] + 12][k % 4] + 12, 52) for k in range(32)])),
        (36, each_chord(chords, lambda b, r, t, c: [(b + bar * 8 + k, 0.5, m, 98) for bar in (0, 1) for k, m in ((0, r), (1.5, r + 12), (2, r), (3, r + 7), (4, r), (5.5, r + 12), (6, r + 7), (7, r + 12))])),
        ('drums', hits(chords, lambda b, bar: pop_kit(b, bar) + [(b + k, 39, 90) for k in (2, 6)])),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def ghetsis_orchestra():
    """Ghetsis, o verdadeiro chefe da Equipe Plasma: a igreja da Plasma por dentro, escura. O órgão de tubos grave e
    cheio (no frígio, mais sombrio que o dórico da equipe), o coro masculino grave entoando a melodia, o sino fúnebre
    batendo devagar, os metais graves (tuba e trombones) com o trítono nos acentos, contrabaixos em trêmulo e tímpanos
    pesados; lento e sem bateria (ele manda, não corre)."""
    lead, chords, bpm = villain_song('ghetsis')
    chant = lead_notes(lead, 100, -12, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.3)
    def organ(b, r, t, c):
        return [(b + k, 7.8, m, 88) for k in (0, 8) for m in (t[0] - 12, t[0], t[1], t[2])]
    def toll(b, r, t, c):  # o sino fúnebre: no 1 de cada compasso, o último com o trítono
        return [(b, 6, t[0], 86), (b + 8, 6, t[0] + (6 if c % 4 == 3 else 0), 80)]
    parts = [
        (19, each_chord(chords, organ)),
        (19, each_chord(chords, lambda b, r, t, c: [(b, 15.8, r, 100), (b, 15.8, r - 12 if r >= 36 else r, 90)])),
        (53, chant + [(st, ln, m - 12, 80) for st, ln, m, v in chant]),
        (14, each_chord(chords, toll)),
        (57, each_chord(chords, lambda b, r, t, c: [(b + 12, 3.6, t[0] - 12, 96), (b + 12, 3.6, t[0] - 6, 84)] if c % 2 else [(b, 4, t[0] - 12, 92)])),
        (58, each_chord(chords, lambda b, r, t, c: [(b + k, 3.6, r, 100) for k in (0, 8)])),
        (44, each_chord(chords, lambda b, r, t, c: [(b, 16, m - 12, 64) for m in (t[0], t[2])])),
        (47, each_chord(chords, lambda b, r, t, c: [(b, 2, r, 116), (b + 8, 2, r, 100)] + ([(b + 14 + q / 4, 0.25, r, 60 + 6 * q) for q in range(8)] if c % 2 else []))),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def penny_orchestra():
    """Penny, a hacker por trás da Equipe Star: tela escura e código correndo. Sintetizador de onda quadrada na
    melodia (o computador) com ecos picotados de "glitch" (a nota repetida em fusas, como um travamento), arpejador
    rápido, baixo sintetizado em semicolcheias, pad frio e a batida eletrônica seca com o tec-tec do teclado (claves)."""
    lead, chords, bpm = villain_song('penny')
    melody = lead_notes(lead, 100, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.05)
    glitch = [(st + ln - 0.5 + q / 8, 0.1, m + 12, 70 - 6 * q) for st, ln, m, v in melody if ln >= 1.5 and int(st) % 8 == 0 for q in range(4)]
    def kit(b, bar):
        out = [(b + k, 36, 108) for k in (0, 3, 4)] + [(b + k, 40, 96) for k in (2, 6)] + [(b + k / 2, 42, 50 if k % 2 else 64) for k in range(16)]
        out += [(b + k, 75, 54) for k in (0.5, 1.25, 1.75, 3.5, 4.75, 5.25, 7.25)]  # o teclado
        if bar % 4 == 3:
            out += [(b + 6 + r / 4, 40, 60 + 5 * r) for r in range(8)]
        return out
    parts = [
        (80, melody, {'cc': {1: 0}}),
        (80, glitch),
        (81, each_chord(chords, lambda b, r, t, c: [(b + k / 2, 0.3, [t[0], t[2], t[1] + 12, t[2], t[0] + 12, t[2], t[1] + 12, t[2] + 12][k % 8] + 12, 46) for k in range(32)])),
        (39, each_chord(chords, lambda b, r, t, c: [(b + k / 2, 0.4, r + (12 if k % 8 == 6 else 0), 100 if k % 2 == 0 else 78) for k in range(32)])),
        (89, each_chord(chords, lambda b, r, t, c: [(b, 16, m, 46) for m in t])),
        ('drums', hits(chords, kit)),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def rose_orchestra():
    """Rose, o presidente da Macro Cosmos: o empresário poderoso. Orquestra de abertura de evento corporativo: os
    trompetes e as trompas em fanfarra na melodia, os trombones respondendo, as cordas em ostinato motor (a indústria
    que não para), piano em oitavas marcando, caixa de marcha, tímpanos e pratos; grandioso, mas em menor harmônica (o
    sorriso por cima do plano)."""
    lead, chords, bpm = villain_song('rose')
    melody = lead_notes(lead, 110, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.1)
    answer = [(st + 2, min(ln, 1.5), m - 12, 90) for st, ln, m, v in melody if int(st) % 16 == 8]
    def ostinato(b, r, t, c):
        cell = [t[0], t[0], t[1], t[0], t[2], t[0], t[1], t[0]]
        return [(b + k / 2, 0.42, cell[k % 8], 80 if k % 4 == 0 else 64) for k in range(32)]
    def kit(b, bar):
        out = [(b + k, 36, 100) for k in (0, 4)] + [(b + k, 38, 96) for k in (2, 6)] + [(b + k / 2, 38, 50) for k in (1, 3, 9, 11)]
        if bar % 2 == 0:
            out.append((b, 49, 100))
        return out
    parts = [
        (56, melody),
        (60, [(st, ln, m - 12, 92) for st, ln, m, v in melody]),
        (57, answer),
        (48, each_chord(chords, ostinato)),
        (49, each_chord(chords, lambda b, r, t, c: [(b, 16, m, 60) for m in t])),
        (0, each_chord(chords, lambda b, r, t, c: [(b + k, 1.5, m, 86) for k in (0, 3, 6, 8, 11, 14) for m in (r + 12, r + 24)])),
        (43, each_chord(chords, lambda b, r, t, c: [(b + k, 1.8, r, 96) for k in range(0, 16, 2)])),
        (47, each_chord(chords, lambda b, r, t, c: [(b, 2, r, 112), (b + 8, 2, r, 98)])),
        ('drums', hits(chords, kit)),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def team_macro_cosmos_orchestra():
    """Macro Cosmos (a Oleana): fria e corporativa, a secretária eficiente. Piano elétrico limpo na melodia com o
    vibrafone dobrando, um sequenciador mecânico em semicolcheias (a fábrica automatizada), pad de vidro gelado, baixo
    sintetizado reto e batida eletrônica precisa e enxuta (nada fora do lugar)."""
    lead, chords, bpm = villain_song('team_macro_cosmos')
    melody = lead_notes(lead, 96, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.05)
    parts = [
        (4, melody),
        (11, [(st, ln, m + 12, 56) for st, ln, m, v in melody]),
        (81, each_chord(chords, lambda b, r, t, c: [(b + k / 2, 0.22, [t[0], t[0] + 12, t[2], t[0] + 12][k % 4], 44) for k in range(32)]), {'cc': {74: 30}}),
        (92, each_chord(chords, lambda b, r, t, c: [(b, 16, m, 50) for m in t])),
        (38, each_chord(chords, lambda b, r, t, c: [(b + k, 0.9, r, 96) for k in range(0, 16)])),
        ('drums', hits(chords, lambda b, bar: [(b + k, 36, 100) for k in (0, 2, 4, 6)] + [(b + k, 40, 72) for k in (2, 6)] + [(b + k / 2, 42, 40) for k in range(1, 16, 2)] + ([(b, 49, 74)] if bar % 4 == 0 else []))),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def jessie_james_orchestra():
    """Jessie e James, a dupla da Equipe Rocket: vilões teatrais e trapalhões. Um número de cabaré: o trompete e o
    clarinete dividindo a melodia (um responde ao outro, como os dois falando o lema), a tuba no "um-pá", o banjo no
    contratempo, o xilofone nas viradas (a trapalhada), a bateria de marcha com balanço e o prato no fim das frases."""
    lead, chords, bpm = villain_song('jessie-e-james')
    swing = 0.3
    melody = lead_notes(lead, 106, maxlen=4, keep=lambda i: i % 2 == 0, swing=swing, extra=0.05)
    jessie = [n for n in melody if int(n[0]) % 16 < 8]
    james = [(st, ln, m, v - 6) for st, ln, m, v in melody if int(st) % 16 >= 8]
    def tuba(b, r, t, c):
        return [(b + k * 2, 1.2, [r, r + 7][k % 2], 104) for k in range(8)]
    def banjo(b, r, t, c):
        return [(_sw(b + k, swing), 0.4, m, 70) for k in range(1, 16, 2) for m in t]
    def fall(b, r, t, c):  # a trapalhada: o xilofone descendo no fim de cada frase
        return [(b + 14 + q / 4, 0.24, t[2] + 24 - q * 2, 80 - q * 4) for q in range(8)] if c % 2 == 1 else []
    def kit(b, bar):
        out = [(b + k, 36, 100) for k in (0, 4)] + [(b + k, 38, 96) for k in (2, 6)] + [(_sw(b + k, swing), 38, 46) for k in (1, 3, 5, 7)]
        out += [(_sw(b + k, swing), 42, 60) for k in range(8)]
        if bar % 4 == 3:
            out.append((b + 7, 49, 104))
        return out
    parts = [
        (56, jessie),
        (71, james),
        (58, each_chord(chords, tuba)),
        (105, each_chord(chords, banjo)),
        (13, each_chord(chords, fall)),
        ('drums', hits(chords, kit, swing)),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def team_yell_orchestra():
    """Equipe Yell (os torcedores da Marnie, em Spikemuth): torcida organizada com punk. O coro gritando a melodia ("oh",
    em uníssono, como uma arquibancada) com os metais, a guitarra punk em colcheias (pelo amplificador), o baixo, os
    tambores de torcida (surdo e caixa), os apitos no fim das frases, as palmas e a bateria punk."""
    lead, chords, bpm = villain_song('team_yell')
    melody = lead_notes(lead, 104, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.05)
    def kit(b, bar):
        out = [(b + k, 36, 108) for k in (0, 2, 4, 6)] + [(b + k, 38, 104) for k in (1, 3, 5, 7)] + [(b + k, 39, 92) for k in (1, 3, 5, 7)]
        out += [(b + k, 41, 100) for k in (0, 1.5, 4, 5.5)]  # o surdo da torcida
        if bar % 4 == 3:
            out += [(b + 6, 71, 96), (b + 7, 72, 100)]  # os apitos
        if bar % 2 == 0:
            out.append((b, 49, 100))
        return out
    parts = [
        (53, melody + [(st, ln, m - 12, v - 10) for st, ln, m, v in melody]),
        (61, [(st, ln, m - 12, 86) for st, ln, m, v in melody]),
        (29, each_chord(chords, lambda b, r, t, c: [(b + k, 0.85, m, 86 if k % 2 == 0 else 72) for k in range(16) for m in (r + 12, r + 19)]), {'amp': {'drive': 30, 'gain': 0.6, 'double': True}}),
        (33, each_chord(chords, lambda b, r, t, c: [(b + k, 0.85, r, 100 if k % 2 == 0 else 88) for k in range(16)])),
        ('drums', hits(chords, kit)),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


VILLAINS = {'team_rocket': team_rocket_orchestra, 'giovanni': giovanni_orchestra, 'team_magma': team_magma_orchestra,
            'maxie': maxie_orchestra, 'team_aqua': team_aqua_orchestra, 'archie': archie_orchestra,
            'team_galactic': team_galactic_orchestra, 'cyrus': cyrus_orchestra, 'team_plasma': team_plasma_orchestra,
            'colress': colress_orchestra, 'team_flare': team_flare_orchestra, 'lysandre': lysandre_orchestra,
            'team_skull': team_skull_orchestra, 'guzma': guzma_orchestra, 'team_aether': team_aether_orchestra,
            'team_ultra': team_ultra_orchestra, 'lusamine': lusamine_orchestra, 'team_star': team_star_orchestra,
            'giacomo': giacomo_orchestra, 'ortega': ortega_orchestra, 'ghetsis': ghetsis_orchestra, 'penny': penny_orchestra,
            'rose': rose_orchestra, 'team_macro': team_macro_cosmos_orchestra,
            'jessie-e-james': jessie_james_orchestra, 'team_yell': team_yell_orchestra}  # já feitos


# Os temas de ginásio (um por região, para todos os líderes, capitães e kahunas dela) e da Elite dos Quatro (um por
# região). Melodias originais. Cada um no estilo da região.
GYM_THEMES = {
    'kanto': (67, 'mixolydian', [0, 6, 3, 4], 160),
    'johto': (62, 'dorian', [0, 3, 6, 4], 156),
    'hoenn': (65, 'mixolydian', [0, 6, 3, 4], 162),
    'sinnoh': (64, 'minor', [0, 5, 2, 6], 158),
    'unova': (65, 'minor', [0, 5, 6, 4], 128),
    'kalos': (62, 'harmonic', [0, 3, 5, 4], 150),
    'alola': (67, 'major', [0, 4, 5, 3], 140),
    'galar': (66, 'major', [0, 5, 3, 4], 152),
    'paldea': (69, 'major', [0, 3, 4, 5], 168),
    'hisui': (62, 'phrygian', [0, 1, 5, 0], 164),
}
ELITE_THEMES = {
    'elite_kanto': (62, 'harmonic', [0, 5, 3, 4], 144),
    'elite_johto': (64, 'phrygian', [0, 1, 6, 4], 146),
    'elite_hoenn': (62, 'minor', [0, 5, 6, 4], 150),
    'elite_sinnoh': (61, 'harmonic', [0, 3, 5, 4], 148),
    'elite_unova': (60, 'harmonic', [0, 5, 1, 4], 132),
    'elite_kalos': (65, 'harmonic', [0, 5, 3, 4], 144),
    'elite_alola': (64, 'dorian', [0, 6, 3, 4], 150),
    'elite_paldea': (67, 'minor', [0, 5, 6, 4], 160),
}


def gym_song(name):
    tonic, mode, prog, bpm = (GYM_THEMES | ELITE_THEMES)[name]
    lead, chords = compose(f'gym-{name}', tonic, mode, prog)
    return lead, chords, bpm


def gym_kanto_orchestra():
    """Ginásio de Kanto: a nostalgia de Game Boy do mapa, agora em batalha de líder. A onda quadrada na melodia com os
    metais dobrando, as cordas em ostinato, o baixo em colcheias, o piano nos acordes, os tímpanos na entrada do acorde
    e a bateria de rock com o prato a cada 2 compassos."""
    lead, chords, bpm = gym_song('kanto')
    melody = lead_notes(lead, 104, maxlen=4, keep=lambda i: i % 2 == 0, extra=0.1)
    parts = [
        (80, melody, {'cc': {1: 20}}),
        (61, [(st, ln, m - 12, 84) for st, ln, m, v in melody]),
        (48, each_chord(chords, lambda b, r, t, c: [(b + k / 2, 0.45, [t[0], t[1], t[0], t[2]][k % 4], 52 if k % 4 else 64) for k in range(32)])),
        (0, each_chord(chords, lambda b, r, t, c: [(b + k, 1.6, m, 70) for k in (0, 6, 12) for m in t])),
        (33, each_chord(chords, lambda b, r, t, c: [(b + k, 0.85, r + (12 if k % 4 == 3 else 0), 98 if k % 2 == 0 else 84) for k in range(16)])),
        (47, each_chord(chords, lambda b, r, t, c: [(b, 2, r, 100), (b + 8, 2, r, 84)])),
        ('drums', hits(chords, lambda b, bar: rock_kit(b, bar, (0, 3, 4)))),
    ]
    return render(parts, bpm, len(lead), soundfont=MUSESCORE)


def _gym_mel(lead, vel=104, extra=0.1):
    return lead_notes(lead, vel, maxlen=4, keep=lambda i: i % 2 == 0, extra=extra)


def _ostinato(prog, vel=56):
    """Cordas (ou outro) em colcheias firmes no acorde (sem notas agudas rápidas)."""
    return (prog, lambda b, r, t, c: [(b + k, 0.9, [t[0], t[1], t[0], t[2]][k % 4], vel + (8 if k % 4 == 0 else 0)) for k in range(16)])


def _band(chords, lead, bpm, parts, squash=2.6):
    return render([(p, each_chord(chords, f) if callable(f) else f, *o) for p, f, *o in parts], bpm, len(lead), soundfont=MUSESCORE, squash=squash)


def _roots(vel=98, prog=33, octave=4):
    return (prog, lambda b, r, t, c: [(b + k, 0.85, r + (12 if k % octave == octave - 1 else 0), vel if k % 2 == 0 else vel - 14) for k in range(16)])


def _timp():
    return (47, lambda b, r, t, c: [(b, 2, r, 100), (b + 8, 2, r, 84)])


def _pad(prog, vel=54, shift=-12):
    return (prog, lambda b, r, t, c: [(b, 16, m + shift, vel) for m in t])


def gym_johto_orchestra():
    """Ginásio de Johto: a flauta de bambu (shakuhachi) e o koto do mapa, em batalha. A flauta na melodia com os metais
    dobrando, o koto dedilhando o acorde, as cordas firmes, o baixo, o taiko na entrada do acorde e a bateria de rock."""
    lead, chords, bpm = gym_song('johto')
    m = _gym_mel(lead)
    return _band(chords, lead, bpm, [
        (77, m), (61, [(st, ln, x - 12, 82) for st, ln, x, v in m]),
        (107, lambda b, r, t, c: [(b + k, 1.6, [t[0], t[1], t[2], t[1]][(k // 2) % 4], 70) for k in range(0, 16, 2)]),
        _ostinato(48), _roots(), (116, lambda b, r, t, c: [(b, 2, r, 104), (b + 6, 1, r, 90), (b + 8, 2, r, 100)]),
        ('drums', hits(chords, lambda b, bar: rock_kit(b, bar, (0, 3, 4)))),
    ])


def gym_hoenn_orchestra():
    """Ginásio de Hoenn: aventura tropical. Os metais na melodia com o trompete dobrando, a marimba no acorde, as
    cordas firmes, o baixo saltitante, os bongôs e a bateria pop/rock com pandeirola."""
    lead, chords, bpm = gym_song('hoenn')
    m = _gym_mel(lead)
    return _band(chords, lead, bpm, [
        (61, m), (56, [(st, ln, x, 76) for st, ln, x, v in m]),
        (12, lambda b, r, t, c: [(b + k, 0.9, [t[0], t[2], t[1], t[2]][(k // 2) % 4], 64) for k in range(0, 16, 2)]),
        _ostinato(48, 50), _roots(),
        ('drums', hits(chords, lambda b, bar: pop_kit(b, bar) + [(b + k, 60 + (k % 2), 70) for k in (1, 3, 5, 7)])),
    ])


def gym_sinnoh_orchestra():
    """Ginásio de Sinnoh: o piano dramático da região virado rock. O piano em oitavas na melodia com as cordas dobrando,
    a guitarra pesada nas colcheias (pelo amplificador), os metais nos ataques, o baixo, os tímpanos e a bateria de rock."""
    lead, chords, bpm = gym_song('sinnoh')
    m = _gym_mel(lead)
    return _band(chords, lead, bpm, [
        (0, m + [(st, ln, x - 12, v - 10) for st, ln, x, v in m]), (48, [(st, ln, x, 70) for st, ln, x, v in m]),
        (29, lambda b, r, t, c: [(b + k, 0.85, x, 84 if k % 2 == 0 else 70) for k in range(16) for x in (r + 12, r + 19)], {'amp': {'drive': 30, 'gain': 0.55, 'double': True}}),
        (61, lambda b, r, t, c: [(b + k, 0.8, x, 96) for k in (6, 14) for x in (t[0], t[2])]),
        _roots(), _timp(), ('drums', hits(chords, lambda b, bar: rock_kit(b, bar, (0, 3, 4)))),
    ])


def gym_unova_orchestra():
    """Ginásio de Unova: a boate do porto do mapa em batalha. O sintetizador de serra na melodia com os metais em
    ataques, o baixo sintetizado saltitante, o pad, as palmas e a batida de boate (bumbo em todo tempo, chimbal aberto)."""
    lead, chords, bpm = gym_song('unova')
    m = _gym_mel(lead, 100, 0.05)
    return _band(chords, lead, bpm, [
        (81, m, {'cc': {1: 20}}),
        (61, lambda b, r, t, c: [(b + k, 0.5, x, 92) for k in (3, 7, 11, 15) for x in (t[0], t[2])]),
        (38, lambda b, r, t, c: [(b + k, 0.45, r + (12 if k % 2 else 0), 104 if k % 2 == 0 else 86) for k in range(16)]),
        _pad(90, 52),
        ('drums', hits(chords, lambda b, bar: [(b + k, 36, 112) for k in (0, 2, 4, 6)] + [(b + k, 39, 92) for k in (2, 6)] + [(b + k, 46, 70) for k in (1, 3, 5, 7)] + ([(b, 49, 96)] if bar % 4 == 0 else []))),
    ])


def gym_kalos_orchestra():
    """Ginásio de Kalos: elegância francesa em batalha. O acordeão na melodia com o violino dobrando, as cordas em
    colcheias, o piano nos acordes, o baixo, os tímpanos e a bateria com balanço leve."""
    lead, chords, bpm = gym_song('kalos')
    m = _gym_mel(lead)
    return _band(chords, lead, bpm, [
        (21, m), (40, [(st, ln, x, 72) for st, ln, x, v in m]),
        _ostinato(48, 52), (0, lambda b, r, t, c: [(b + k, 1.5, x, 66) for k in (0, 4, 8, 12) for x in t]),
        _roots(94), _timp(), ('drums', hits(chords, lambda b, bar: pop_kit(b, bar, tamb=False), 0.15)),
    ])


def gym_alola_orchestra():
    """Provas e kahunas de Alola: a praia havaiana em batalha. A guitarra deslizando (como a lap steel) na melodia, o
    ukulele em colcheias, os metais nos ataques, o baixo acústico, os tambores de tronco e a bateria animada."""
    lead, chords, bpm = gym_song('alola')
    m = _gym_mel(lead, 100)
    return _band(chords, lead, bpm, [
        (25, m, {'glide': True}),
        (24, lambda b, r, t, c: [(b + k, 0.5, x, 70 if k % 2 == 0 else 56) for k in range(16) for x in t]),
        (61, lambda b, r, t, c: [(b + k, 0.6, x, 90) for k in (6, 14) for x in (t[0], t[2])]),
        _roots(92, 32),
        ('drums', hits(chords, lambda b, bar: pop_kit(b, bar, tamb=False) + [(b + k, 63, 70) for k in (1, 3.5, 5)] + [(b + k, 70, 56) for k in range(8)])),
    ])


def gym_galar_orchestra():
    """Ginásio de Galar: a final no estádio. A guitarra distorcida e os metais na melodia, a torcida cantando ("oh") nos
    acordes, o baixo, os tambores de arquibancada, as palmas no 2 e no 4 e a bateria de rock grande."""
    lead, chords, bpm = gym_song('galar')
    m = _gym_mel(lead)
    return _band(chords, lead, bpm, [
        (30, m, {'amp': {'drive': 16, 'gain': 1.1, 'pan': 0.0}}), (61, [(st, ln, x - 12, 86) for st, ln, x, v in m]),
        (53, lambda b, r, t, c: [(b + k, 1.6, x, 70) for k in (0, 8) for x in t]),
        (29, lambda b, r, t, c: [(b + k, 0.85, x, 80) for k in range(16) for x in (r + 12, r + 19)], {'amp': {'drive': 26, 'gain': 0.5, 'double': True}}),
        _roots(),
        ('drums', hits(chords, lambda b, bar: rock_kit(b, bar, (0, 3, 4)) + [(b + k, 39, 96) for k in (2, 6)] + [(b + k, 60, 84) for k in (0, 1, 4, 5)])),
    ])


def gym_paldea_orchestra():
    """Ginásio de Paldea: a banda da escola de anime. A guitarra na melodia (rock japonês) com o sintetizador doce
    dobrando, a guitarra base, o piano em colcheias, o baixo correndo e a bateria rápida com o prato a cada 2 compassos."""
    lead, chords, bpm = gym_song('paldea')
    m = _gym_mel(lead)
    return _band(chords, lead, bpm, [
        (29, m, {'amp': {'drive': 12, 'gain': 1.05, 'pan': 0.0}}), (80, [(st, ln, x, 60) for st, ln, x, v in m]),
        (28, lambda b, r, t, c: [(b + k, 0.85, x, 82 if k % 2 == 0 else 68) for k in range(16) for x in (r + 12, r + 19)], {'amp': {'drive': 20, 'gain': 0.5, 'double': True}}),
        (0, lambda b, r, t, c: [(b + k, 0.9, x, 60) for k in range(0, 16, 2) for x in t]),
        _roots(100), ('drums', hits(chords, lambda b, bar: pop_kit(b, bar, tamb=False))),
    ])


def elite_kanto_orchestra():
    """Elite dos Quatro de Kanto: o Indigo Plateau, solene e pesado. O órgão e os metais graves na melodia, a onda
    quadrada de Kanto dobrando uma oitava acima (a lembrança do Game Boy), o coro, as cordas firmes, o baixo, os tímpanos
    e a bateria de rock pesada."""
    lead, chords, bpm = gym_song('elite_kanto')
    m = _gym_mel(lead)
    return _band(chords, lead, bpm, [
        (19, [(st, ln, x - 12, 80) for st, ln, x, v in m]), (61, [(st, ln, x - 12, 96) for st, ln, x, v in m]), (80, [(st, ln, x, 56) for st, ln, x, v in m]),
        _pad(52, 60, 0), _ostinato(48, 54), _roots(102), _timp(),
        ('drums', hits(chords, lambda b, bar: rock_kit(b, bar, (0, 3, 4)))),
    ])


def elite_johto_orchestra():
    """Elite dos Quatro de Johto: o frio do Indigo, oriental e sombrio. O koto e a flauta de bambu na melodia em
    frígio, os metais graves, o coro, as cordas firmes, o baixo, o taiko pesado e a bateria de rock."""
    lead, chords, bpm = gym_song('elite_johto')
    m = _gym_mel(lead)
    return _band(chords, lead, bpm, [
        (107, m), (77, [(st, ln, x, 70) for st, ln, x, v in m]), (61, [(st, ln, x - 12, 90) for st, ln, x, v in m]),
        _pad(52, 56, 0), _ostinato(48, 52), _roots(100), (116, lambda b, r, t, c: [(b, 2, r, 110), (b + 4, 1, r, 92), (b + 8, 2, r, 106), (b + 12, 1, r, 92)]),
        ('drums', hits(chords, lambda b, bar: rock_kit(b, bar, (0, 3, 4)))),
    ])


def elite_hoenn_orchestra():
    """Elite dos Quatro de Hoenn: Ever Grande, épica como a batalha lendária do mapa. Os metais e as trompas em oitavas
    na melodia, o coro, as cordas firmes, o contrabaixo, os tímpanos, o taiko e a bateria de rock."""
    lead, chords, bpm = gym_song('elite_hoenn')
    m = _gym_mel(lead)
    return _band(chords, lead, bpm, [
        (61, m), (60, [(st, ln, x - 12, 88) for st, ln, x, v in m]),
        _pad(52, 60, 0), _ostinato(48, 54), _roots(102, 43), _timp(), (116, lambda b, r, t, c: [(b, 2, r, 104), (b + 8, 2, r, 100)]),
        ('drums', hits(chords, lambda b, bar: rock_kit(b, bar, (0, 3, 4)))),
    ])


def elite_sinnoh_orchestra():
    """Elite dos Quatro de Sinnoh: a Liga no alto do mundo, tensa. O piano em oitavas na melodia com o órgão por baixo,
    o coro, as cordas firmes, os metais nos ataques, o baixo, os tímpanos e a bateria de rock pesada."""
    lead, chords, bpm = gym_song('elite_sinnoh')
    m = _gym_mel(lead)
    return _band(chords, lead, bpm, [
        (0, m + [(st, ln, x - 12, v - 10) for st, ln, x, v in m]), (19, [(st, ln, x - 12, 62) for st, ln, x, v in m]),
        _pad(52, 58, 0), _ostinato(48, 54), (61, lambda b, r, t, c: [(b + k, 0.8, x, 98) for k in (6, 14) for x in (t[0], t[2])]),
        _roots(100), _timp(), ('drums', hits(chords, lambda b, bar: rock_kit(b, bar, (0, 3, 4)))),
    ])


def elite_unova_orchestra():
    """Elite dos Quatro de Unova: a boate do mapa virada gótica. O sintetizador de serra na melodia com o órgão, o coro,
    o baixo sintetizado pesado, o pad escuro e a batida eletrônica forte com o prato a cada 2 compassos."""
    lead, chords, bpm = gym_song('elite_unova')
    m = _gym_mel(lead, 100, 0.05)
    return _band(chords, lead, bpm, [
        (81, m, {'cc': {1: 25}}), (19, [(st, ln, x - 12, 66) for st, ln, x, v in m]), _pad(52, 56, 0),
        (38, lambda b, r, t, c: [(b + k, 0.45, r + (12 if k % 2 else 0), 108 if k % 2 == 0 else 90) for k in range(16)]), _pad(95, 46),
        ('drums', hits(chords, lambda b, bar: electro_kit(b, bar, heavy=True))),
    ])


def elite_kalos_orchestra():
    """Elite dos Quatro de Kalos: o castelo da Liga, barroco e grandioso. O cravo e o violino na melodia, o coro, o órgão
    nos acordes, as cordas firmes, o baixo, os tímpanos e a bateria de rock."""
    lead, chords, bpm = gym_song('elite_kalos')
    m = _gym_mel(lead)
    return _band(chords, lead, bpm, [
        (6, m), (40, [(st, ln, x, 76) for st, ln, x, v in m]), _pad(52, 58, 0), _pad(19, 50, 0),
        _ostinato(48, 52), _roots(100), _timp(), ('drums', hits(chords, lambda b, bar: rock_kit(b, bar, (0, 3, 4)))),
    ])


def elite_alola_orchestra():
    """Elite dos Quatro de Alola: o topo do Monte Lanakila. A guitarra deslizando de Alola e os metais na melodia, o
    coro, as cordas firmes, o ukulele, o baixo, os tímpanos e a bateria de rock com os tambores de tronco."""
    lead, chords, bpm = gym_song('elite_alola')
    m = _gym_mel(lead)
    return _band(chords, lead, bpm, [
        (25, m, {'glide': True}), (61, [(st, ln, x - 12, 88) for st, ln, x, v in m]), _pad(52, 58, 0),
        _ostinato(48, 52), (24, lambda b, r, t, c: [(b + k, 0.5, x, 60) for k in range(0, 16, 2) for x in t]),
        _roots(100), _timp(), ('drums', hits(chords, lambda b, bar: rock_kit(b, bar, (0, 3, 4)) + [(b + k, 63, 66) for k in (1, 5)])),
    ])


def elite_paldea_orchestra():
    """Elite dos Quatro de Paldea: a entrevista e depois a batalha, o rock da escola em grande. A guitarra distorcida e os
    metais na melodia, o coro, as cordas firmes, a guitarra base, o baixo, os tímpanos e a bateria rápida."""
    lead, chords, bpm = gym_song('elite_paldea')
    m = _gym_mel(lead)
    return _band(chords, lead, bpm, [
        (30, m, {'amp': {'drive': 18, 'gain': 1.1, 'pan': 0.0}}), (61, [(st, ln, x - 12, 88) for st, ln, x, v in m]), _pad(52, 56, 0),
        (29, lambda b, r, t, c: [(b + k, 0.85, x, 80) for k in range(16) for x in (r + 12, r + 19)], {'amp': {'drive': 26, 'gain': 0.5, 'double': True}}),
        _ostinato(48, 50), _roots(100), _timp(), ('drums', hits(chords, lambda b, bar: rock_kit(b, bar, (0, 3, 4)))),
    ])


def gym_hisui_orchestra():
    """Os Nobres de Hisui (a batalha do guardião e do Nobre furioso): os taikôs em ritmo de guerra, o shamisen em
    colcheias, o shakuhachi e as cordas na melodia, os metais nos ataques e o baixo."""
    lead, chords, bpm = gym_song('hisui')
    m = _gym_mel(lead)
    return _band(chords, lead, bpm, [
        (77, m), (48, [(st, ln, x - 12, 76) for st, ln, x, v in m]),
        (106, lambda b, r, t, c: [(b + k, 0.5, [t[0], t[2], t[1], t[2]][k % 4] + 12, 80 if k % 2 == 0 else 64) for k in range(16)]),
        (61, lambda b, r, t, c: [(b + k, 0.8, x, 96) for k in (0, 6, 12) for x in (t[0], t[2])]),
        _roots(92), (116, lambda b, r, t, c: [(b + k, 1, 36 + (7 if k % 4 == 3 else 0), 110 if k % 4 == 0 else 84) for k in range(0, 16, 1) if k % 2 == 0 or k % 8 == 7]),
        ('drums', hits(chords, lambda b, bar: [(b + k, 36, 100) for k in (0, 3, 4)] + [(b + k, 38, 88) for k in (2, 6)] + [(b + k, 47, 70) for k in (5, 7)])),
    ])


GYMS = {'gym_kanto': gym_kanto_orchestra, 'gym_johto': gym_johto_orchestra, 'gym_hoenn': gym_hoenn_orchestra, 'gym_sinnoh': gym_sinnoh_orchestra,
        'gym_unova': gym_unova_orchestra, 'gym_kalos': gym_kalos_orchestra, 'gym_alola': gym_alola_orchestra, 'gym_galar': gym_galar_orchestra,
        'gym_paldea': gym_paldea_orchestra, 'elite_kanto': elite_kanto_orchestra, 'elite_johto': elite_johto_orchestra,
        'elite_hoenn': elite_hoenn_orchestra, 'elite_sinnoh': elite_sinnoh_orchestra, 'elite_unova': elite_unova_orchestra,
        'elite_kalos': elite_kalos_orchestra, 'elite_alola': elite_alola_orchestra, 'elite_paldea': elite_paldea_orchestra,
        'gym_hisui': gym_hisui_orchestra}  # gym_<região> e elite_<região> já feitos


def mega_orchestra():
    """O tema épico depois da Mega Evolução: orquestra heroica (metais, trompetes, cordas em ostinato,
    contrabaixo, coro, tímpano e pratos), i–VI–III–VII na menor, com a melodia original de sempre."""
    lead, chords = compose('mega-evolution', 64, 'minor', [0, 5, 2, 6], climax=True)
    choir_ = (52, each_chord(chords, lambda b, r, t, c: [(b, 16, m, 60) for m in t]))
    return render(battle_parts(lead, chords, 61, 56, 43, 48, extra=[choir_], kit=lambda b, bar: rock_kit(b, bar, (0, 3, 4))), 160, len(lead))


def dmax_orchestra():
    """O tema da orquestra gigante depois do Dynamax/Gigantamax: lento e pesado. A melodia nos metais em
    três oitavas (tuba, trombones, trompas), coro, cordas em trêmulo no agudo, tímpanos e pratos chineses."""
    lead, chords = compose('dynamax-giant', 64, 'harmonic', [0, 5, 3, 4], climax=True)
    parts = [
        (58, lead_notes(lead, 95, -24, extra=0.1)),
        (57, lead_notes(lead, 100, -12, extra=0.1)),
        (60, lead_notes(lead, 90, 0, extra=0.1)),
        (52, each_chord(chords, lambda b, r, t, c: [(b, 16, m, 70) for m in t] + [(b, 16, m + 12, 50) for m in t])),
        (44, each_chord(chords, lambda b, r, t, c: [(b + k / 4, 0.24, t[(k // 16) % 3] + 12, 45) for k in range(64)])),
        (43, each_chord(chords, lambda b, r, t, c: [(b + k, 1.8, r, 95) for k in range(0, 16, 2)])),
        (47, each_chord(chords, lambda b, r, t, c: [(b + r_ / 3, 0.3, r, 50 + 6 * r_) for r_ in range(9)] + [(b + 3, 2, r, 115), (b + 11, 2, r, 100)])),
        ('drums', hits(chords, lambda b, bar: [(b, 52 if bar % 2 == 0 else 49, 100), (b, 36, 110), (b + 4, 36, 90)])),
    ]
    return render(parts, 120, len(lead))


def mega_fanfare():
    """A fanfarra da Mega Evolução com orquestra: cordas subindo em escala e o rufar do tímpano crescendo
    até o estouro em HIT_AT (o clarão da animação): metais e trompetes no acorde, prato e o brilho do
    glockenspiel descendo."""
    bpm = 120
    step_s = 60 / bpm / 2
    hit = HIT_AT / step_s
    run = [52, 54, 56, 57, 59, 61, 63, 64]
    parts = [
        (48, [(j * hit / len(run), hit / len(run) * 1.1, m, 60 + 6 * j) for j, m in enumerate(run)] + [(hit, 6, m, 95) for m in (64, 68, 71, 76)]),
        (47, [(r * hit / 12, 0.2, 40, 40 + 6 * r) for r in range(12)] + [(hit, 3, 40, 120)]),
        (61, [(hit, 6, m, 115) for m in (52, 59, 64, 68)]),
        (56, [(hit, 6, m, 105) for m in (71, 76)]),
        (9, [(hit + 0.3 + j * 0.18, 2, m, 80) for j, m in enumerate((88, 83, 80, 76, 71))]),
        ('drums', [(hit, 2, 49, 120), (hit, 1, 36, 110)]),
    ]
    return render(parts, bpm, 0, tail=4.2, loop=False, squash=2.2)


def dmax_fanfare():
    """A fanfarra do Dynamax/Gigantamax: a orquestra gigante. Metais graves e coro crescendo, o rufar do
    tímpano subindo e, no estouro (HIT_AT), o acorde em três oitavas com tuba, trombones, coro e prato chinês."""
    bpm = 120
    step_s = 60 / bpm / 2
    hit = HIT_AT / step_s
    parts = [
        (57, [(0, hit, m, 70) for m in (40, 47)] + [(hit, 8, m, 120) for m in (40, 47, 52)]),
        (58, [(hit, 8, m, 120) for m in (28, 35)]),
        (60, [(hit, 8, m, 110) for m in (55, 59, 64)]),
        (52, [(0, hit, m, 55) for m in (52, 59)] + [(hit, 9, m, 110) for m in (52, 55, 59, 64, 67)]),
        (47, [(r * hit / 16, 0.2, 40, 35 + 5 * r) for r in range(16)] + [(hit, 4, 40, 127), (hit, 4, 28, 127)]),
        ('drums', [(hit, 3, 52, 127), (hit, 3, 49, 110), (hit, 1, 35, 127)]),
    ]
    return render(parts, bpm, 0, tail=5.5, loop=False, squash=2.2)


def hifi_tracks():
    """{nome: áudio estéreo} de todas as músicas em loop, com instrumentos gravados."""
    out = {}  # só os temas das regiões (mapa, também nas batalhas), a Mega e o Dynamax; battle_tracks() fica de fora
    out.update({
        'map_kanto': kanto_orchestra(), 'map_johto': johto_orchestra(), 'map_hoenn': hoenn_orchestra(),
        # Sinnoh e a Cynthia trocados (a pedido): o mapa toca o tema que era dela, e ela o que era do mapa.
        'map_sinnoh': cynthia_orchestra(), 'map_unova': unova_orchestra(), 'map_kalos': kalos_orchestra(),
        'map_alola': alola_orchestra(), 'map_galar': galar_orchestra(), 'map_paldea': paldea_orchestra(),
        'map_hisui': hisui_orchestra(),
        **{f'map_{r}': extra_map_orchestra(r) for r in EXTRA_MAP_SOUNDS},
        'mega_theme': mega_orchestra(), 'dmax_theme': dmax_orchestra(),
    })
    out.update({f'champion_{name}': fn() for name, fn in CHAMPIONS.items()})
    out.update({f'rival_{name}': fn() for name, fn in RIVALS.items()})
    out.update({f'villain_{name}': fn() for name, fn in VILLAINS.items()})
    out.update({name: fn() for name, fn in GYMS.items()})
    return out


def save_hifi(name, audio):
    """Um efeito (sem loop) com instrumentos gravados, em MP3 (estéreo)."""
    pcm = (np.clip(audio, -1, 1) * 32767 * 0.9).astype(np.int16)
    path = os.path.join(OUT, f'{name}.mp3')
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 's16le', '-ar', str(HI_RATE), '-ac', '2', '-i', '-',
                    '-c:a', 'libmp3lame', '-b:a', '128k', path], input=pcm.tobytes(), check=True)
    return os.path.getsize(path)


def mega_theme():
    """O tema épico depois da Mega Evolução: orquestra heroica (metais, cordas em ostinato, tambores
    de guerra), i–VI–III–VII na menor, com melodia original."""
    lead, chords = compose('mega-evolution', 64, 'minor', [0, 5, 2, 6], climax=True)
    return music(lead, chords, 160, epic=True, weather=False)


def main():
    os.makedirs(OUT, exist_ok=True)
    sounds = {
        'hit': sfx_hit,
        'super': sfx_super,
        'weak': sfx_weak,
        'faint': sfx_faint,
        'throw': sfx_throw,
        'open': sfx_open,
        'recall': sfx_recall,
        'statup': sfx_statup,
        'statdown': sfx_statdown,
        'heal': sfx_heal,
        'select': sfx_select,
        'shiny': sfx_shiny,
        'victory': sfx_victory,
    }
    # Só alguns: python3 tool/build_battle_sounds.py shiny | music | map_kalos | mega ...
    only = sys.argv[1:]
    if only == ['mega']:  # as fanfarras e os temas da Mega e do Dynamax
        save_hifi('mega', mega_fanfare())
        save_hifi('dmax', dmax_fanfare())
        save_hifi_loop('mega_theme', mega_orchestra())
        save_hifi_loop('dmax_theme', dmax_orchestra())
        return
    if only == ['music']:  # todas as músicas em loop
        for name, audio in hifi_tracks().items():
            save_hifi_loop(name, audio)
        return
    if only:
        loops = {'map_kanto': kanto_orchestra, 'map_johto': johto_orchestra, 'map_hoenn': hoenn_orchestra,
                 'map_sinnoh': cynthia_orchestra, 'map_unova': unova_orchestra, 'map_kalos': kalos_orchestra,
                 'map_alola': alola_orchestra, 'map_galar': galar_orchestra, 'map_paldea': paldea_orchestra,
                 'map_hisui': hisui_orchestra}
        loops.update({f'map_{r}': (lambda r=r: extra_map_orchestra(r)) for r in EXTRA_MAP_SOUNDS})
        loops.update({f'champion_{n}': fn for n, fn in CHAMPIONS.items()})
        loops.update({f'rival_{n}': fn for n, fn in RIVALS.items()})
        loops.update({f'villain_{n}': fn for n, fn in VILLAINS.items()})
        loops.update(GYMS)
        for name in only:
            if name in loops:
                save_hifi_loop(name, loops[name]())
            else:
                save(name, sounds[name]())
        return
    total = 0
    for name, fn in sounds.items():
        total += save(name, fn())
    total += save_hifi('mega', mega_fanfare()) + save_hifi('dmax', dmax_fanfare())
    tracks = hifi_tracks()
    for name, audio in tracks.items():
        total += save_hifi_loop(name, audio)
    print(f'{len(sounds) + 2 + len(tracks)} sons, {total // 1024} KB')


if __name__ == '__main__':
    main()
