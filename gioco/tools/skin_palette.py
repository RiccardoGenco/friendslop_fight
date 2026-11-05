# Skin per scambio di palette: regole in HSV (tonalita' in gradi) applicate ai colori del foglio.
import colorsys, numpy as np
from PIL import Image

def rule(h=(0, 360), s=(0, 1), v=(0, 1), H=None, sm=1, sa=0, vm=1, va=0):
    return (h, s, v, H, sm, sa, vm, va)

FUR_OR = (12, 48)      # arancio del pelo (gatto, volpe)
SKINS = {
  "gatto_2": [  # Siamese: pelo crema, punte scure, vestito chiaro
    rule(h=FUR_OR, s=(0.45, 1), v=(0.55, 1), H=34, sm=0.28, va=0.12),
    rule(h=FUR_OR, s=(0.45, 1), v=(0, 0.55), H=20, sm=0.55, vm=0.55),
    rule(h=(190, 270), s=(0.15, 1), H=230, sm=0.15, va=0.5),
  ],
  "gatto_3": [  # Ombra: pelo nero fumo, fascia e vestito viola
    rule(h=FUR_OR, s=(0.3, 1), H=260, sm=0.25, vm=0.32),
    rule(h=(25, 60), s=(0, 0.3), v=(0.6, 1), H=260, sm=0.3, vm=0.55),
    rule(h=(190, 270), s=(0.15, 1), H=275, sm=1.6, va=0.1),
    rule(h=(340, 360), s=(0.4, 1), H=285, sm=0.8, va=0.15),
    rule(h=(0, 12), s=(0.4, 1), H=285, sm=0.8, va=0.15),
  ],
  "rana_2": [   # Velenosa: rana blu con pancia gialla, armatura nera
    rule(h=(70, 160), s=(0.25, 1), H=215, sm=1.1),
    rule(h=(40, 70), s=(0.15, 1), v=(0.6, 1), H=52, sm=1.6, va=0.05),
    rule(h=(340, 360), s=(0.35, 1), H=230, sm=0.15, vm=0.35),
    rule(h=(0, 20), s=(0.35, 1), H=230, sm=0.15, vm=0.35),
  ],
  "rana_3": [   # Oro: rana dorata, armatura bianca
    rule(h=(70, 160), s=(0.25, 1), H=45, sm=1.0, va=0.12),
    rule(h=(340, 360), s=(0.35, 1), H=40, sm=0.1, vm=1.2, va=0.35),
    rule(h=(0, 20), s=(0.35, 1), H=40, sm=0.1, vm=1.2, va=0.35),
  ],
  "orso_2": [   # Polare: orso bianco, cappello e pantaloni blu
    rule(h=(10, 45), s=(0.2, 1), H=210, sm=0.08, va=0.5),
    rule(h=(340, 360), s=(0.35, 1), H=220, sm=0.9, vm=0.8),
    rule(h=(0, 10), s=(0.35, 1), H=220, sm=0.9, vm=0.8),
  ],
  "orso_3": [   # Fantasma: orso azzurro spettrale
    rule(h=(10, 45), s=(0.2, 1), H=180, sm=0.9, va=0.25),
    rule(h=(340, 360), s=(0.35, 1), H=190, sm=0.7, vm=0.7),
    rule(h=(0, 10), s=(0.35, 1), H=190, sm=0.7, vm=0.7),
    rule(s=(0, 0.15), v=(0.75, 1), H=170, sa=0.25),
  ],
  "volpe_2": [  # Artica: volpe bianca, bandana blu, camicia grigia
    rule(h=FUR_OR, s=(0.35, 1), v=(0.45, 1), H=210, sm=0.08, va=0.4),
    rule(h=(340, 360), s=(0.35, 1), H=215, sm=1.0),
    rule(h=(0, 12), s=(0.35, 1), H=215, sm=1.0),
    rule(h=(195, 250), s=(0.2, 1), H=220, sm=0.15),
  ],
  "volpe_3": [  # Fuoco: volpe rosso fuoco, bandana gialla
    rule(h=FUR_OR, s=(0.35, 1), H=8, sm=1.2),
    rule(h=(340, 360), s=(0.35, 1), H=48, sm=1.0, va=0.15),
    rule(h=(0, 8), s=(0.35, 1), H=48, sm=1.0, va=0.15),
    rule(h=(195, 250), s=(0.2, 1), H=5, sm=0.6, vm=0.45),
  ],
  "coniglio_2": [  # Neve: coniglio bianco, elmo d'oro, tunica blu
    rule(h=(15, 50), s=(0.2, 0.75), v=(0.55, 1), H=35, sm=0.12, va=0.25),
    rule(h=(15, 50), s=(0.2, 1), v=(0, 0.55), H=220, sm=0.9, va=0.1),
    rule(s=(0, 0.18), v=(0.35, 0.85), H=45, sm=0, sa=0.75, va=0.1),
  ],
  "coniglio_3": [  # Runico: coniglio viola, elmo color acquamarina
    rule(h=(15, 50), s=(0.2, 1), v=(0.5, 1), H=265, sm=0.9, vm=0.8),
    rule(h=(15, 50), s=(0.2, 1), v=(0, 0.5), H=255, sm=0.8, vm=0.7),
    rule(s=(0, 0.18), v=(0.35, 0.85), H=170, sm=0, sa=0.7, va=0.1),
  ],
  "procione_2": [  # Albino: procione bianco, maschera rosa, vestito cremisi
    rule(s=(0, 0.18), v=(0.4, 0.95), H=0, sm=0, sa=0.05, va=0.3),
    rule(s=(0, 0.25), v=(0.15, 0.4), H=345, sm=0, sa=0.55, va=0.35),
    rule(s=(0, 0.25), v=(0, 0.15), H=350, sm=0, sa=0.7, va=0.25),
  ],
  "procione_3": [  # Notturno: procione blu notte, occhi gialli
    rule(s=(0, 0.2), v=(0.35, 1), H=220, sm=0, sa=0.45, vm=0.65),
    rule(s=(0, 0.2), v=(0.12, 0.35), H=225, sm=0, sa=0.5, vm=0.8),
  ],
}

def apply(img, rules):
    a = np.array(img.convert("RGBA")).astype(float) / 255
    out = a.copy()
    cols = {}
    H, W = a.shape[:2]
    for y in range(H):
        for x in range(W):
            if a[y, x, 3] == 0: continue
            key = tuple(a[y, x, :3])
            if key not in cols:
                h, s, v = colorsys.rgb_to_hsv(*key)
                hd = h * 360
                res = key
                for (hr, sr, vr, Hn, sm, sa, vm, va) in rules:
                    if hr[0] <= hd <= hr[1] and sr[0] <= s <= sr[1] and vr[0] <= v <= vr[1]:
                        nh = (Hn / 360) if Hn is not None else h
                        ns = min(1, max(0, s * sm + sa)); nv = min(1, max(0, v * vm + va))
                        res = colorsys.hsv_to_rgb(nh, ns, nv)
                        break
                cols[key] = res
            out[y, x, :3] = cols[key]
    return Image.fromarray((out * 255).astype(np.uint8), "RGBA")

if __name__ == "__main__":
    import sys
    rows = []
    for hero in ("gatto", "rana", "orso", "volpe", "coniglio", "procione"):
        base = Image.open(f"{hero}_sheet.png" if hero != "gatto" else "gatto_sheet.png")
        row = [base]
        for k in (2, 3):
            im = apply(base, SKINS[f"{hero}_{k}"]); im.save(f"{hero}_{k}.png"); row.append(im)
        rows.append(row)
    z = 3
    W = max(sum(r.size[0] for r in row) + 40 for row in rows) * z
    Hh = sum(max(r.size[1] for r in row) + 4 for row in rows) * z
    sheet = Image.new("RGBA", (W, Hh), (50, 52, 70, 255)); y = 0
    for row in rows:
        x = 0
        for r in row:
            sheet.alpha_composite(r.resize((r.size[0] * z, r.size[1] * z), Image.NEAREST), (x, y)); x += (r.size[0] + 20) * z
        y += (max(r.size[1] for r in row) + 4) * z
    sheet.save("skins_preview.png")
