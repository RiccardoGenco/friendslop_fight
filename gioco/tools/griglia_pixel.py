# Riduzione della pixel art generata con griglia non uniforme: i tagli tra le celle stanno dove i colori
# cambiano davvero (picchi del profilo dei bordi); ogni cella prende il suo colore dominante.
import sys, numpy as np
from PIL import Image

def cuts(profile, approx):
    n = len(profile)
    thr = profile.mean() * 0.8
    peaks = [i for i in range(1, n - 1) if profile[i] >= profile[i - 1] and profile[i] >= profile[i + 1] and profile[i] > thr]
    # tiene il picco piu' forte tra quelli troppo vicini
    sel = []
    for p in sorted(peaks, key=lambda i: -profile[i]):
        if all(abs(p - q) >= approx * 0.6 for q in sel): sel.append(p)
    sel = sorted(sel)
    # riempie i buchi troppo larghi con tagli regolari
    out = [0]
    for p in sel + [n]:
        gap = p - out[-1]
        if gap > approx * 1.6:
            m = int(round(gap / approx))
            for j in range(1, m): out.append(out[-1] + gap / m * 0 + (p - out[-1]) * 0 + gap / m * 1 if False else out[-1] + gap / m)
        if p - out[-1] >= approx * 0.5: out.append(p)
    return [int(round(c)) for c in out]

def dominant(c):
    a, b = c[0], c[-1]
    for _ in range(5):
        da = ((c - a) ** 2).sum(1); db = ((c - b) ** 2).sum(1)
        ga, gb = c[da <= db], c[da > db]
        if len(ga): a = ga.mean(0)
        if len(gb): b = gb.mean(0)
    return a if len(ga) >= len(gb) else b

def snap(img, approx):
    im = np.array(img.convert("RGBA")).astype(float)
    rgb, op = im[..., :3], im[..., 3] > 128
    dx = (np.abs(np.diff(rgb, axis=1)).sum(2) * (op[:, 1:] | op[:, :-1])).sum(0)
    dy = (np.abs(np.diff(rgb, axis=0)).sum(2) * (op[1:] | op[:-1])).sum(1)
    cx = cuts(np.concatenate([dx, [0]]), approx); cy = cuts(np.concatenate([dy, [0]]), approx)
    H, W = len(cy) - 1, len(cx) - 1
    out = np.zeros((H, W, 4), np.uint8)
    for j in range(H):
        for i in range(W):
            y0, y1, x0, x1 = cy[j], cy[j + 1], cx[i], cx[i + 1]
            # solo il centro della cella, lontano dai bordi sfumati
            my, mx = max(0, (y1 - y0) // 4), max(0, (x1 - x0) // 4)
            blk = im[y0 + my:y1 - my or None, x0 + mx:x1 - mx or None].reshape(-1, 4)
            if len(blk) == 0: continue
            o = blk[blk[:, 3] > 128]
            if len(o) >= len(blk) * 0.5:
                out[j, i, :3] = dominant(o[:, :3]); out[j, i, 3] = 255
    res = Image.fromarray(out, "RGBA")
    return res.crop(res.getbbox())

if __name__ == "__main__":
    img = Image.open(sys.argv[1]).convert("RGBA")
    a = np.array(img)[..., 3]; ys, xs = np.where(a > 128)
    img = img.crop((xs.min() - 2, ys.min() - 2, xs.max() + 3, ys.max() + 3))
    r = snap(img, float(sys.argv[3]))
    r.save(sys.argv[2]); print("misura", r.size)
