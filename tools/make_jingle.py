"""Original, serious news intro for Gaza Now, timed to the splash animation.

0.00-1.50 s  logo spins: low string drone swells, deep pulses, a soft riser
1.50 s       logo lands: cinematic low hit (sub drop + low drum + low brass "braam")
1.50-4.20 s  solemn piano motif in D minor over strings, slow fade
"""
import subprocess
import sys
import wave

import numpy as np

SR = 44100
DUR = 4.4
N = int(DUR * SR)
rng = np.random.default_rng(11)
mix = np.zeros((N, 2))


def t_(n):
    return np.arange(n) / SR


def hz(m):
    return 440 * 2 ** ((m - 69) / 12)


def put(sig, at, pan=0.0, gain=1.0):
    i = int(at * SR)
    j = min(N, i + len(sig))
    if j <= i:
        return
    l, r = np.sqrt((1 - pan) / 2), np.sqrt((1 + pan) / 2)
    mix[i:j, 0] += gain * l * sig[: j - i]
    mix[i:j, 1] += gain * r * sig[: j - i]


def env(n, a, r):
    e = np.ones(n)
    na, nr = int(a * SR), int(r * SR)
    e[:na] = np.linspace(0, 1, na) ** 2
    if nr < n:
        e[-nr:] *= np.linspace(1, 0, nr) ** 1.5
    return e


def strings(f, dur, amp, attack=0.8):
    n = int(dur * SR)
    t = t_(n)
    s = 0
    for det in (-0.003, 0.0, 0.004):
        ph = 2 * np.pi * f * (1 + det) * t + rng.uniform(0, 6)
        s = s + sum(np.sin(k * ph) / (k ** 1.3) for k in range(1, 8))
    return amp * s / 3 * env(n, attack, min(1.0, dur * 0.4))


def low_pulse(amp=0.7):
    n = int(0.6 * SR)
    t = t_(n)
    f = 70 * np.exp(-t * 8) + 38
    return amp * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 6)


def riser(dur=1.4, amp=0.12):
    n = int(dur * SR)
    t = t_(n)
    s = rng.normal(0, 1, n)
    lp = np.convolve(s, np.ones(60) / 60, mode='same')
    x = t / dur
    e = x ** 2.2
    e[-int(0.08 * SR):] *= np.linspace(1, 0, int(0.08 * SR))  # silence just before the hit
    return amp * lp * 4 * e


def sub_drop(dur=2.0, amp=1.0):
    n = int(dur * SR)
    t = t_(n)
    f = 75 * np.exp(-t * 2.0) + 30
    return amp * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 1.6)


def low_drum(dur=1.8, amp=0.9):
    n = int(dur * SR)
    t = t_(n)
    p = hz(33) * (1 + 0.4 * np.exp(-t * 25))
    s = np.sin(2 * np.pi * np.cumsum(p) / SR) + 0.3 * np.sin(2 * np.pi * np.cumsum(p * 2.3) / SR)
    noise = np.convolve(rng.normal(0, 1, n), np.ones(30) / 30, mode='same') * np.exp(-t * 30) * 2
    return amp * (s + noise) * np.exp(-t * 2.2)


def braam(f, dur=2.2, amp=0.2):
    """Low, slightly rough brass swell, as in film trailers."""
    n = int(dur * SR)
    t = t_(n)
    ph = 2 * np.pi * f * t
    bright = np.clip(1 - t / 1.2, 0.25, 1)
    s = sum((bright ** (k / 4)) * np.sin(k * ph + 0.3 * np.sin(2 * np.pi * 3 * t)) / k for k in range(1, 16))
    return amp * s * env(n, 0.02, 1.4)


def piano(f, dur=2.2, amp=0.25):
    n = int(dur * SR)
    t = t_(n)
    s = 0
    for k, a in enumerate((1, .5, .3, .18, .1, .06), start=1):
        fk = f * k * np.sqrt(1 + 0.0004 * k * k)  # slight string inharmonicity
        s = s + a * np.sin(2 * np.pi * fk * t) * np.exp(-t * (1.6 + 0.9 * k))
    hammer = rng.normal(0, 1, n) * np.exp(-t * 300) * 0.05
    return amp * (s + hammer) * env(n, 0.003, 0.4)


# --- 0.00-1.50 while the logo spins -------------------------------------------
for m, a in ((38, 0.10), (45, 0.07), (50, 0.05)):  # D2, A2, D3 drone
    put(strings(hz(m), 4.2, a, attack=1.3), 0.0, pan=(m - 45) / 20)
for at, g in ((0.05, 0.5), (0.65, 0.65), (1.05, 0.8)):  # slow, deep pulses
    put(low_pulse(), at, gain=g)
put(riser(), 0.1)

# --- 1.50 the logo lands ---------------------------------------------------------
HIT = 1.50
put(sub_drop(), HIT, gain=1.3)
put(low_drum(), HIT, gain=1.2)
for m in (26, 38, 45):  # D1, D2, A2
    put(braam(hz(m)), HIT, gain=1.0)

# --- 1.50-4.20 solemn piano over strings -------------------------------------------
for m, a in ((57, 0.045), (62, 0.04), (65, 0.035)):  # A3 D4 F4 pad (D minor)
    put(strings(hz(m), 2.8, a, attack=0.6), HIT + 0.1, pan=(m - 61) / 12)
melody = [(74, 0.0), (69, 0.45), (65, 0.9), (70, 1.45), (69, 1.9)]  # D5 A4 F4 Bb4 A4
for m, dt in melody:
    put(piano(hz(m), 2.4, 0.22), HIT + 0.35 + dt, pan=-0.15)
    put(piano(hz(m - 12), 2.4, 0.08), HIT + 0.35 + dt, pan=0.15)
put(piano(hz(50), 2.6, 0.14), HIT + 0.35)        # low D under the first note
put(piano(hz(46), 2.4, 0.12), HIT + 0.35 + 1.45)  # low Bb under the turn

# --- reverb (longer, darker), fade, normalise ----------------------------------------
wet = np.convolve(mix[:, 0] + mix[:, 1], np.ones(8) / 8, mode='same')  # dull the tail
for delay, g in ((0.031, 0.36), (0.053, 0.3), (0.089, 0.24), (0.137, 0.18), (0.211, 0.13), (0.307, 0.09)):
    k = int(delay * SR)
    mix[k:, 0] += g * wet[:-k] * 0.5
    mix[k:, 1] += g * wet[:-k] * 0.5
fade = np.ones(N)
fade[-int(0.9 * SR):] = np.linspace(1, 0, int(0.9 * SR)) ** 1.6
mix *= fade[:, None]
mix /= np.max(np.abs(mix)) * 1.05

out = sys.argv[1]
wav = '/tmp/intro.wav'
with wave.open(wav, 'wb') as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes((mix * 32767).astype(np.int16).tobytes())
subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav,
                '-af', 'acompressor=threshold=-20dB:ratio=2.5:attack=8:release=200,loudnorm=I=-12:TP=-1:LRA=9',
                '-ar', '44100', '-codec:a', 'libmp3lame', '-b:a', '192k', out], check=True)
print('wrote', out)
