"""Sons da batalha, sintetizados aqui (nada copiado de jogo): efeitos no
estilo 8-bit e uma música de batalha chiptune original em loop.

Saída: assets/database/sounds/<nome>.mp3 (o site copia com o resto do banco).

Uso: pip install lameenc numpy && python3 tool/build_battle_sounds.py
"""

import os

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


def music():
    bars = len(LEAD) // 8
    total = bars * 8 * STEP
    n = int(RATE * total)
    out = np.zeros(n)
    step_n = int(RATE * STEP)

    def put(start_step, signal, offset=0):
        i = int(start_step * RATE * STEP) + offset
        end = min(n, i + len(signal))
        out[i:end] += signal[: end - i]

    # Melodia (pulso 25%), nota a nota, ligando as repetidas.
    i = 0
    while i < len(LEAD):
        note = LEAD[i]
        length = 1
        while i + length < len(LEAD) and LEAD[i + length] == 0 and length < 2:
            length += 1
        if note:
            d = STEP * length * 0.95
            sig = pulse(freq(note), d, 0.25) * env(int(RATE * d), 0.004, 0.04) * 0.22
            # Vibrato leve nas notas longas.
            put(i, sig)
        i += length

    for c, (root, tones) in enumerate(CHORDS):
        base = c * 16
        # Baixo (triângulo): raiz em oitavas, colcheias.
        for k in range(16):
            m = root + (12 if k % 2 else 0)
            d = STEP * 0.9
            put(base + k, triangle(freq(m), d) * env(int(RATE * d), 0.002, 0.02) * 0.35)
        # Arpejo (pulso 12,5%) em semicolcheias, bem baixinho.
        for k in range(32):
            m = tones[k % 3] - 12
            d = STEP / 2 * 0.9
            sig = pulse(freq(m), d, 0.125) * env(int(RATE * d), 0.001, 0.01) * 0.07
            put(base + k / 2, sig)

    # Bateria (ruído): bumbo nos tempos 1 e 3, caixa no 2 e 4, chimbal nos contratempos.
    for b in range(bars):
        for beat in range(4):
            s = b * 8 + beat * 2
            if beat in (0, 2):
                kick_n = int(RATE * 0.12)
                put(s, pulse(np.linspace(140, 45, kick_n), 0.12, 0.5) * decay(kick_n, 30) * 0.3)
            else:
                sn = int(RATE * 0.12)
                put(s, noise(0.12, 13 + b, 1) * decay(sn, 28) * 0.18)
            hh = int(RATE * 0.04)
            put(s + 1, noise(0.04, 17 + beat, 1) * decay(hh, 90) * 0.08)
    return out


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
        'victory': sfx_victory(),
    }
    total = 0
    for name, sig in sounds.items():
        total += save(name, sig)
    total += save('battle_music', music(), bitrate=64)
    print(f'{len(sounds) + 1} sons, {total // 1024} KB')


if __name__ == '__main__':
    main()
