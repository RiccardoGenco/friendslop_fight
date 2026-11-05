# Unisce le pose a terra (a) e in aria (b) di un eroe in un foglio di sei pose, con la stessa misura di pixel.
import sys, numpy as np
from PIL import Image
sys.path.insert(0, __import__("os").path.dirname(__file__))
import riduci_pose as P
B = "/mnt/user-data/uploads/bozze"
hero, va, vb = sys.argv[1], sys.argv[2], sys.argv[3]
pa = P.split(P.clean(Image.open(f"{B}/ff2_{hero}_a_0000{va}_.png").convert("RGBA")))
pb = P.split(P.clean(Image.open(f"{B}/ff2_{hero}_b_0000{vb}_.png").convert("RGBA")))
approx = np.median([P.estimate(p) for p in pa])
hpx = np.median([p.size[1] for p in pa])
while hpx / approx > 80: approx *= 2
# le pose in aria possono essere disegnate piu' piccole: misura dei pixel stimata a parte,
# portata a una dimensione simile a quella delle pose a terra
approx_b = np.median([P.estimate(p) for p in pb])
ha = np.median([p.size[1] for p in pa]) / approx
hb = np.median([p.size[1] for p in pb])
if hb / approx_b > ha * 1.25: approx_b = hb / ha
if abs(approx_b - approx) / approx < 0.2: approx_b = approx
# disegnate alla stessa scala (altezze in pixel simili): stessa misura di pixel
hpa = np.median([p.size[1] for p in pa]); hpb = max(p.size[1] for p in pb)
if 0.75 < hpb / hpa < 1.3: approx_b = approx
skip_fall = len(sys.argv) > 4 and sys.argv[4] == "nofall"
sm = [P.strip_ground(P.snap(p, approx)) for p in pa[:3]] + [P.strip_ground(P.snap(p, approx_b)) for p in pb[:3]]
print("cella aria %.1f" % approx_b)
print(hero, "pose", len(pa), len(pb), "cella %.1f" % approx, "altezze", [s.size[1] for s in sm])
if skip_fall: sm[4] = sm[3]          # caduta sbagliata: si usa la posa di salto
sheet = P.pack(sm, f"{hero}_full.png"); P.preview(sheet, f"{hero}_full_prev.png", 4)
