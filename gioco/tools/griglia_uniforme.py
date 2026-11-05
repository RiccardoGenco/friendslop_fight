# Riduzione "corretta" della pixel art generata: trova la griglia vera (misura e sfasamento della cella)
# e prende per ogni cella il colore dominante (k-centroidi, k=2), senza fare medie tra colori diversi.
import sys, numpy as np
from PIL import Image

def load(src):
    im = np.array(Image.open(src).convert("RGBA")).astype(float)
    a = im[..., 3]
    ys, xs = np.where(a > 128)
    return im[ys.min():ys.max() + 1, xs.min():xs.max() + 1]

def sample(im, k, ox, oy, center_only=True):
    H, W = im.shape[:2]
    nh, nw = int((H - oy) / k), int((W - ox) / k)
    out = np.zeros((nh, nw, 4))
    for j in range(nh):
        for i in range(nw):
            y0, x0 = oy + j * k, ox + i * k
            m = k * 0.25
            blk = im[int(y0 + m):int(y0 + k - m) or 1, int(x0 + m):int(x0 + k - m) or 1].reshape(-1, 4)
            if len(blk) == 0: continue
            op = blk[blk[:, 3] > 128]
            if len(op) < len(blk) * 0.5: continue
            c = op[:, :3]
            # k-centroidi con k=2: si tiene il gruppo piu' numeroso
            a, b = c[0], c[-1]
            for _ in range(4):
                da = ((c - a) ** 2).sum(1); db = ((c - b) ** 2).sum(1)
                ga, gb = c[da <= db], c[da > db]
                if len(ga): a = ga.mean(0)
                if len(gb): b = gb.mean(0)
            col = a if len(ga) >= len(gb) else b
            out[j, i, :3] = col; out[j, i, 3] = 255
    return out

def score(im, k, ox, oy):
    # errore di ricostruzione: la cella giusta rende ogni blocco quasi uniforme
    H, W = im.shape[:2]
    err, n = 0, 0
    for y0 in np.arange(oy, H - k, k):
        for x0 in np.arange(ox, W - k, k):
            blk = im[int(y0):int(y0 + k), int(x0):int(x0 + k)]
            op = blk[..., 3] > 128
            if op.mean() > 0.9:
                c = blk[..., :3][op]
                err += c.std(0).mean(); n += 1
    return err / max(n, 1)

if __name__ == "__main__":
    src, out = sys.argv[1], sys.argv[2]
    im = load(src)
    best = None
    for k in np.arange(float(sys.argv[3]), float(sys.argv[4]), 0.1):
        for ox in np.arange(0, k, k / 5):
            for oy in np.arange(0, k, k / 5):
                s = score(im, k, ox, oy)
                if best is None or s < best[0]: best = (s, k, ox, oy)
    s, k, ox, oy = best
    print("cella %.2f px, sfasamento %.1f %.1f, errore %.1f" % (k, ox, oy, s))
    res = sample(im, k, ox, oy)
    img = Image.fromarray(res.astype(np.uint8), "RGBA")
    img = img.crop(img.getbbox())
    img.save(out); print("misura nativa", img.size)
