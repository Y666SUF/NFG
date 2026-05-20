"""Generate placeholder win-sound WAVs into static/win-sounds/ (replace with your own MP3s later)."""
from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "static" / "win-sounds"


def _write_wav(path: Path, samples: list[float], rate: int = 44100) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        frames = bytearray()
        n = len(samples)
        for i, s in enumerate(samples):
            e = 1.0
            if n > 80:
                e = min(1.0, i / (n * 0.05)) * min(1.0, (n - i) / (n * 0.12) + 0.2)
            v = max(-1.0, min(1.0, s * e))
            frames.extend(struct.pack("<h", int(v * 32000)))
        w.writeframes(frames)


def tone(freq: float, t_sec: float, rate: int) -> list[float]:
    n = int(rate * t_sec)
    return [0.4 * math.sin(2 * math.pi * freq * (i / rate)) for i in range(n)]


def chirp(f0: float, f1: float, t_sec: float, rate: int) -> list[float]:
    n = int(rate * t_sec)
    out = []
    for i in range(n):
        t = i / rate
        f = f0 + (f1 - f0) * (i / max(1, n - 1))
        out.append(0.45 * math.sin(2 * math.pi * f * t))
    return out


def main() -> None:
    rate = 44100
    specs: dict[str, list[float]] = {
        "classic.wav": tone(880, 0.18, rate) + tone(1174, 0.22, rate),
        "airhorn.wav": chirp(180, 520, 0.35, rate) + chirp(200, 480, 0.25, rate),
        "vine.wav": chirp(90, 220, 0.12, rate) + [0.0] * int(0.08 * rate) + chirp(400, 120, 0.28, rate),
        "bruh.wav": chirp(280, 140, 0.45, rate),
        "victory.wav": tone(523, 0.12, rate) + tone(659, 0.12, rate) + tone(784, 0.2, rate),
        "goofy.wav": tone(400, 0.08, rate)
        + tone(600, 0.08, rate)
        + tone(350, 0.08, rate)
        + tone(550, 0.12, rate),
    }
    for name, samples in specs.items():
        _write_wav(OUT / name, samples, rate)
    readme = OUT / "README.txt"
    readme.write_text(
        "Bundled sounds are short synthetic placeholders.\n"
        "Replace any .wav with your own file (keep the same filename) — MP3 also works if you rename and update win_sounds.WIN_SOUNDS file extension.\n"
        "Use only sounds you have rights to use on stream.\n",
        encoding="utf-8",
    )
    print("Wrote:", OUT)


if __name__ == "__main__":
    main()
