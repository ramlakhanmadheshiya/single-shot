#!/usr/bin/env python3
"""Generate original, license-free UI tones and a looping menu waltz."""
import math, struct, wave
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"assets/audio"; OUT.mkdir(parents=True,exist_ok=True)
RATE=22050
def tone(name, freqs, duration, volume, decay):
    with wave.open(str(OUT/name),"wb") as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(RATE)
        data=bytearray()
        for i in range(int(RATE*duration)):
            t=i/RATE; env=min(1.0,t*80)*math.exp(-decay*t)
            value=sum(math.sin(2*math.pi*hz*t)/(j+1) for j,hz in enumerate(freqs))/len(freqs)
            data.extend(struct.pack("<h",int(max(-1,min(1,value*env*volume))*32767)))
        f.writeframes(data)
tone("ui_click.wav",[660,990],.11,.20,13); tone("ui_hover.wav",[880],.065,.09,18); tone("ui_back.wav",[523,392],.20,.16,7)
notes=[130.81,164.81,196.0,246.94,220.0,174.61,146.83,196.0]
with wave.open(str(OUT/"menu_waltz.wav"),"wb") as f:
    f.setnchannels(1); f.setsampwidth(2); f.setframerate(RATE); data=bytearray()
    for i in range(RATE*48):
        t=i/RATE; beat=int(t/2); phase=t%2; root=notes[(beat//3)%len(notes)]
        third=root*(1.25 if (beat//3)%2==0 else 1.2); melody=notes[(beat+2)%len(notes)]*2
        env=.45+.55*math.sin(math.pi*phase/2); edge=max(0,min(1,t/.35,(48-t)/.35))
        v=(.055*math.sin(2*math.pi*root*t)+.025*math.sin(2*math.pi*third*t)+.012*math.sin(2*math.pi*melody*t)*env)*edge
        data.extend(struct.pack("<h",int(v*32767)))
    f.writeframes(data)

# Short original game sounds.
tone("game_shot.wav",[240,510,880],.20,.24,9)
tone("game_bounce.wav",[340,680],.13,.20,16)
tone("game_bounce_2.wav",[390,590],.12,.21,15)
tone("game_bounce_3.wav",[290,740],.14,.18,15)
tone("game_ghoul_hit.wav",[420,520,710],.16,.23,11)
tone("game_ghoul_death.wav",[610,390,210],.42,.25,5)
tone("game_ghoul_death_2.wav",[570,340,180],.46,.23,4.5)
tone("game_crate_hit.wav",[155,220,310],.18,.24,14)
tone("game_win.wav",[523,659,784,1047],.62,.22,2.8)
tone("game_try_again.wav",[392,330,247],.54,.2,3.5)
tone("game_star_ding.wav",[880,1175,1568],.35,.19,5)
