import sys, numpy as np
from PIL import Image
def shrink(src, target_h, colors=24):
    im = Image.open(src).convert("RGBA")
    a = np.array(im)[..., 3]
    ys, xs = np.where(a > 128)
    im = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    w, h = im.size
    tw = max(1, round(w * target_h / h))
    arr = np.array(im).astype(float)
    out = np.zeros((target_h, tw, 4), np.uint8)
    for j in range(target_h):
        for i in range(tw):
            y0, y1 = int(j * h / target_h), int((j + 1) * h / target_h)
            x0, x1 = int(i * w / tw), int((i + 1) * w / tw)
            blk = arr[y0:max(y1, y0 + 1), x0:max(x1, x0 + 1)]
            if (blk[..., 3] > 128).mean() > 0.45:
                # colore piu' frequente (moda approssimata) dei pixel opachi del blocco
                op = blk[blk[..., 3] > 128][:, :3]
                q = (op // 24).astype(int)
                keys, inv, cnt = np.unique(q, axis=0, return_inverse=True, return_counts=True)
                m = cnt.argmax()
                out[j, i, :3] = op[inv.ravel() == m].mean(0)
                out[j, i, 3] = 255
    small = Image.fromarray(out, "RGBA")
    rgb = small.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    return Image.merge("RGBA", (*rgb.split(), small.split()[3]))
if __name__ == "__main__":
    src = sys.argv[1]
    sheet = []
    for th in (44, 52, 60):
        s = shrink(src, th); s.save("gatto_%d.png" % th); sheet.append(s)
    W = sum(s.size[0] * 8 + 20 for s in sheet); H = max(s.size[1] * 8 for s in sheet)
    bg = Image.new("RGBA", (W, H), (50, 52, 70, 255)); x = 0
    for s in sheet:
        bg.alpha_composite(s.resize((s.size[0] * 8, s.size[1] * 8), Image.NEAREST), (x, H - s.size[1] * 8)); x += s.size[0] * 8 + 20
    bg.save("confronto.png")
