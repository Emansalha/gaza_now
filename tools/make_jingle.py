"""Original TV-news style intro for Gaza Now, timed to the splash animation.

0.00-1.50 s  logo spins: rising whoosh + urgent ticking pulse that speeds up
1.50 s       logo lands: impact (timpani + sub drop + crash) and a brass stab
1.50-4.00 s  fanfare motif over a string pad, ticking fades, reverb tail
"""
import subprocess
import sys
import wave

import numpy as np

SR = 44100
DUR = 4.2
N = int(DUR * SR)
rng = np.random.default_rng(7)
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


def adsr(n, a=0.005, d=0.1, s=0.6, r=0.2):
    e = np.ones(n) * s
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    e[:na] = np.linspace(0, 1, na)
    e[na:na + nd] = np.linspace(1, s, nd)
    if nr < n:
        e[-nr:] *= np.linspace(1, 0, nr)
    return e


def brass(f, dur, amp=0.3):
    n = int(dur * SR)
    t = t_(n)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * t) * np.clip(t * 3, 0, 1)
    ph = 2 * np.pi * f * np.cumsum(vib) / SR
    # bright saw-like stack, brightness opens with the attack
    bright = np.clip(t * 18, 0.2, 1)
    s = sum((bright ** (k / 3)) * np.sin(k * ph) / k for k in range(1, 12))
    return amp * s * adsr(n, 0.015, 0.12, 0.7, min(0.35, dur * 0.5))


def strings(f, dur, amp=0.1):
    n = int(dur * SR)
    t = t_(n)
    s = 0
    for det in (-0.004, 0, 0.005):
        ph = 2 * np.pi * f * (1 + det) * t
        s = s + sum(np.sin(k * ph) / k for k in range(1, 7))
    return amp * s / 3 * adsr(n, 0.35, 0.2, 0.8, 0.8)


def timpani(f, dur=1.6, amp=0.9):
    n = int(dur * SR)
    t = t_(n)
    pitch = f * (1 + 0.5 * np.exp(-t * 30))
    s = np.sin(2 * np.pi * np.cumsum(pitch) / SR) + 0.4 * np.sin(2 * np.pi * np.cumsum(pitch * 1.5) / SR)
    noise = rng.normal(0, 1, n) * np.exp(-t * 45) * 0.5
    return amp * (s + noise) * np.exp(-t * 2.6)


def sub_drop(dur=1.2, amp=0.8):
    n = int(dur * SR)
    t = t_(n)
    f = 90 * np.exp(-t * 2.5) + 35
    return amp * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 2.2)


def crash(dur=2.5, amp=0.35):
    n = int(dur * SR)
    t = t_(n)
    s = rng.normal(0, 1, n)
    s = np.diff(np.concatenate([[0], s]))  # brighter (high-pass)
    return amp * s * np.exp(-t * 1.9)


def tick(amp=0.25, f=1850):
    n = int(0.05 * SR)
    t = t_(n)
    return amp * np.sin(2 * np.pi * f * t) * np.exp(-t * 90)


def whoosh(dur=1.5, amp=0.35):
    n = int(dur * SR)
    t = t_(n)
    s = rng.normal(0, 1, n)
    # crude rising band: blend low-passed and high-passed noise over time
    lp = np.convolve(s, np.ones(40) / 40, mode='same')
    hp = s - lp
    x = t / dur
    out = (1 - x) * lp * 3 + x * hp
    env = x ** 1.6
    env[-int(0.06 * SR):] *= np.linspace(1, 0, int(0.06 * SR))  # short silence before the hit
    return amp * out * env


# --- 0.00-1.50: build-up while the logo spins -------------------------------
put(whoosh(1.5), 0.0, gain=0.45)
tt, step = 0.05, 0.22
while tt < 1.48:  # ticks speed up like the slowing spin in reverse
    put(tick(0.22 + 0.15 * tt / 1.5, 1850 if int(tt * 20) % 2 else 1400), tt, pan=0.3 if int(tt * 10) % 2 else -0.3)
    tt += step
    step = max(0.07, step * 0.86)
for k, m in enumerate((50, 53, 57)):  # low pulse rising under the ticks
    put(brass(hz(m), 0.25, 0.10), 0.35 + k * 0.38, gain=1.0)

# --- 1.50: the logo lands ------------------------------------------------------
HIT = 1.50
put(timpani(hz(38)), HIT, gain=1.6)
put(sub_drop(), HIT, gain=1.4)
put(crash(), HIT, pan=0.1, gain=1.3)
for m in (38, 50, 57, 62, 65, 69):  # D minor brass stab, wide voicing
    put(brass(hz(m), 0.6, 0.16), HIT, pan=(m - 55) / 40)

# --- 1.50-4.00: fanfare motif over strings -----------------------------------
for m in (50, 57, 62, 65):
    put(strings(hz(m), 2.6, 0.04), HIT + 0.05, pan=(m - 57) / 30)
motif = [(74, 0.18), (77, 0.18), (81, 0.36), (79, 0.18), (77, 0.18), (74, 0.9)]
at = HIT + 0.55
for m, d in motif:
    put(brass(hz(m), d + 0.05, 0.085), at, pan=-0.1)
    put(brass(hz(m - 12), d + 0.05, 0.08), at, pan=0.1)
    at += d
put(timpani(hz(38), 1.2, 0.25), HIT + 0.55 + 0.72)
for m in (46, 53, 58, 62, 65):  # resolve on B-flat major colour
    put(brass(hz(m), 1.3, 0.07), at - 0.9)
tt = HIT + 0.3
while tt < 3.4:  # soft ticking continues under the fanfare
    put(tick(0.07), tt, pan=0.4)
    tt += 0.25

# --- reverb, fade, normalise ---------------------------------------------------
for delay, g in ((0.029, 0.32), (0.047, 0.27), (0.083, 0.2), (0.131, 0.15), (0.197, 0.1)):
    k = int(delay * SR)
    mix[k:, 0] += g * mix[:-k, 1]
    mix[k:, 1] += g * mix[:-k, 0]
fade = np.ones(N)
fade[-int(0.6 * SR):] = np.linspace(1, 0, int(0.6 * SR)) ** 1.5
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
                '-af', 'acompressor=threshold=-18dB:ratio=3:attack=4:release=150,loudnorm=I=-11:TP=-1:LRA=8',
                '-ar', '44100', '-codec:a', 'libmp3lame', '-b:a', '192k', out], check=True)
print('wrote', out)
