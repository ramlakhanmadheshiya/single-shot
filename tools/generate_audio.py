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
