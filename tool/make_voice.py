"""Records the guided demo's voice-over with the Kokoro text-to-speech model.

Setup (once):
  python3 -m venv venv && venv/bin/pip install kokoro-onnx soundfile
  Download kokoro-v1.0.int8.onnx and voices-v1.0.bin from
  https://github.com/thewh1teagle/kokoro-onnx/releases (model-files-v1.0) into MODEL_DIR.
Run:
  venv/bin/python tool/make_voice.py MODEL_DIR assets/voice tool/voice_script.json
Needs ffmpeg. One MP3 per demo step per language: assets/voice/<lang>/NN.mp3.
"""
import json, sys, subprocess, os
import numpy as np, soundfile as sf
from kokoro_onnx import Kokoro
d = sys.argv[1]; out = sys.argv[2]
k = Kokoro(d+"/kokoro-v1.0.int8.onnx", d+"/voices-v1.0.bin")
script = json.load(open(sys.argv[3], encoding="utf-8"))
cfg = {"en": ("af_heart", "en-us", 1.0), "hi": ("hf_alpha", "hi", 0.95)}
durs = {}
for lang, lines in script.items():
    voice, code, speed = cfg[lang]
    os.makedirs(f"{out}/{lang}", exist_ok=True)
    for i, text in enumerate(lines, 1):
        a, sr = k.create(text, voice=voice, speed=speed, lang=code)
        a = np.concatenate([np.zeros(int(sr*0.15)), a, np.zeros(int(sr*0.25))]).astype(np.float32)
        wav = f"{out}/tmp.wav"; sf.write(wav, a, sr)
        mp3 = f"{out}/{lang}/{i:02d}.mp3"
        subprocess.run(["ffmpeg","-y","-loglevel","error","-i",wav,"-ac","1","-ar","24000","-b:a","64k",mp3], check=True)
        durs.setdefault(lang, []).append(round(len(a)/sr, 2))
        print(lang, i, durs[lang][-1], flush=True)
os.remove(f"{out}/tmp.wav")
print(json.dumps(durs))
