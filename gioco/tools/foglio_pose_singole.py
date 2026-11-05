# Foglio di sei pose da immagini singole (una posa per immagine), ridotte come il gatto approvato:
# cella fissa vicina a quella dell'immagine di riferimento, sfasamento cercato per ogni immagine.
import sys, numpy as np
from PIL import Image
sys.path.insert(0, __import__("os").path.dirname(__file__))
import griglia_uniforme as N
import riduci_pose as P

def reduce(path, k0):
    im = Image.open(path).convert("RGBA")
    im = P.clean(im)
    arr = np.array(im).astype(float)
    a = arr[..., 3]; ys, xs = np.where(a > 128)
    arr = arr[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    best = None
    for k in np.arange(k0 - 0.4, k0 + 0.41, 0.1):
        for ox in np.linspace(0, k, 6, endpoint=False):
            for oy in np.linspace(0, k, 6, endpoint=False):
                s = N.score(arr, k, ox, oy)
                if best is None or s < best[0]: best = (s, k, ox, oy)
    s, k, ox, oy = best
    res = Image.fromarray(N.sample(arr, k, ox, oy).astype(np.uint8), "RGBA")
    res = P.strip_ground(res.crop(res.getbbox()))
    return res, k

if __name__ == "__main__":
    out, k0, files = sys.argv[1], float(sys.argv[2]), sys.argv[3:]
    sm = []
    for f in files:
        r, k = reduce(f, k0); sm.append(r); print(f.split("/")[-1], "cella %.1f" % k, r.size)
    sheet = P.pack(sm, out); P.preview(sheet, out.replace(".png", "_prev.png"), 4)
