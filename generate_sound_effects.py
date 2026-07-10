#!/usr/bin/env python3
"""
generate_sound_effects.py

Synthesizes two short placeholder sound effects for the quiz's
SoundService (assets/sounds/correct.mp3, assets/sounds/incorrect.mp3) —
these were the last unfinished item on the handoff doc's to-do list
("Sound effects assets — files not included"). No network access is
needed for actual sound libraries (freesound.org / mixkit.co aren't
reachable from this environment), so these are pure sine-wave synthesis:
simple, royalty-free-by-construction, and good enough to unblock testing.
Swap them out for real recorded/licensed sounds whenever you like —
SoundService doesn't care how the files were made.

correct.mp3   — quick two-note ascending chime (C6 -> E6), bright and short
incorrect.mp3 — quick two-note descending buzz (A4 -> F4), lower and short

Run from project root: python3 generate_sound_effects.py
Requires ffmpeg on PATH for the wav->mp3 encode step (already present in
most dev environments; install via your OS package manager if missing).
"""

import subprocess
import wave
import struct
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parent
OUT_DIR = ROOT / "assets" / "sounds"
SAMPLE_RATE = 44100


def _tone(freq: float, duration_s: float, amplitude: float = 0.3) -> np.ndarray:
    """One sine-wave tone with a short attack/decay envelope to avoid
    clicks at the start/end of the sample."""
    n = int(SAMPLE_RATE * duration_s)
    t = np.linspace(0, duration_s, n, endpoint=False)
    wave_data = np.sin(2 * np.pi * freq * t)

    # Short linear fade in/out (~8ms) so notes don't click when
    # concatenated or when playback starts/stops abruptly.
    fade_n = max(1, int(SAMPLE_RATE * 0.008))
    envelope = np.ones(n)
    envelope[:fade_n] = np.linspace(0, 1, fade_n)
    envelope[-fade_n:] = np.linspace(1, 0, fade_n)

    return (wave_data * envelope * amplitude).astype(np.float64)


def _write_wav(path: Path, samples: np.ndarray):
    clipped = np.clip(samples, -1.0, 1.0)
    ints = (clipped * 32767).astype(np.int16)
    with wave.open(str(path), "w") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SAMPLE_RATE)
        f.writeframes(struct.pack(f"<{len(ints)}h", *ints))


def _wav_to_mp3(wav_path: Path, mp3_path: Path):
    subprocess.run(
        ["ffmpeg", "-y", "-i", str(wav_path), "-codec:a", "libmp3lame",
         "-qscale:a", "4", str(mp3_path)],
        check=True, capture_output=True,
    )
    wav_path.unlink()


def build_correct():
    # C6 (1046.5 Hz) -> E6 (1318.5 Hz), bright ascending "success" chime.
    note1 = _tone(1046.5, 0.10, amplitude=0.35)
    gap = np.zeros(int(SAMPLE_RATE * 0.02))
    note2 = _tone(1318.5, 0.16, amplitude=0.35)
    samples = np.concatenate([note1, gap, note2])
    wav_path = OUT_DIR / "correct.wav"
    _write_wav(wav_path, samples)
    _wav_to_mp3(wav_path, OUT_DIR / "correct.mp3")


def build_incorrect():
    # A4 (440 Hz) -> F4 (349.2 Hz), lower descending "try again" tone.
    note1 = _tone(440.0, 0.10, amplitude=0.3)
    gap = np.zeros(int(SAMPLE_RATE * 0.02))
    note2 = _tone(349.2, 0.18, amplitude=0.3)
    samples = np.concatenate([note1, gap, note2])
    wav_path = OUT_DIR / "incorrect.wav"
    _write_wav(wav_path, samples)
    _wav_to_mp3(wav_path, OUT_DIR / "incorrect.mp3")


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    build_correct()
    build_incorrect()
    for name in ("correct.mp3", "incorrect.mp3"):
        size = (OUT_DIR / name).stat().st_size
        print(f"  wrote assets/sounds/{name} ({size} bytes)")


if __name__ == "__main__":
    main()