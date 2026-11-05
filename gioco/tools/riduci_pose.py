# Dalle generazioni a tre pose al foglio del gioco: separa le pose, toglie le ombre piatte,
# stima la misura dei pixel, riduce con la griglia non uniforme (snap) e allinea i piedi.
import sys, numpy as np
from PIL import Image
from scipy import ndimage
from griglia_pixel import snap

def clean(img):
    A = np.array(img.convert("RGBA"))
    lab, n = ndimage.label(A[..., 3] > 60)
    for i, sl in enumerate(ndimage.find_objects(lab), 1):
        h = sl[0].stop - sl[0].start; w = sl[1].stop - sl[1].start
        area = (lab[sl] == i).sum()
        if (h <= 14 and w > 3 * h) or area < 60:
            A[..., 3][sl][lab[sl] == i] = 0
    return Image.fromarray(A, "RGBA")

def split(img, expected=3):
    ps = split_cols(img)
    if len(ps) >= expected: return ps
    # pose che si toccano: taglio nelle colonne piu' vuote vicino a 1/3 e 2/3
    A = np.array(img); op = A[..., 3] > 128
    xs = np.where(op.any(0))[0]; x0, x1 = xs.min(), xs.max() + 1
    cnt = op[:, x0:x1].sum(0).astype(float)
    w = x1 - x0; cutsx = [x0]
    for t in range(1, expected):
        c = int(w * t / expected); r = int(w * 0.12)
        seg = cnt[c - r:c + r]
        cutsx.append(x0 + c - r + int(np.argmin(seg)))
    cutsx.append(x1)
    out = []
    for a, b in zip(cutsx[:-1], cutsx[1:]):
        sub = img.crop((a, 0, b, img.size[1])); m = np.array(sub)[..., 3] > 128
        ys = np.where(m.any(1))[0]
        out.append(sub.crop((0, ys.min() - 2, sub.size[0], ys.max() + 3)))
    return out

def split_cols(img):
    A = np.array(img); op = A[..., 3] > 128
    cols = op.any(0); fr, x = [], 0
    while x < len(cols):
        if cols[x]:
            x0 = x
            while x < len(cols) and cols[x]: x += 1
            if x - x0 > 25: fr.append([x0, x])
        else: x += 1
    merged = []
    for f in fr:
        if merged and f[0] - merged[-1][1] < 20: merged[-1][1] = f[1]
        else: merged.append(f)
    poses = []
    for x0, x1 in merged:
        ys = np.where(op[:, x0:x1].any(1))[0]
        poses.append(img.crop((x0 - 2, ys.min() - 2, x1 + 2, ys.max() + 3)))
    return poses

def estimate(img):
    im = np.array(img).astype(float); rgb, op = im[..., :3], im[..., 3] > 128
    dx = (np.abs(np.diff(rgb, axis=1)).sum(2) * (op[:, 1:] & op[:, :-1])).sum(0)
    pk = [i for i in range(1, len(dx) - 1) if dx[i] > dx[i - 1] and dx[i] >= dx[i + 1] and dx[i] > dx.mean()]
    sp = np.diff(pk); sp = sp[(sp >= 3) & (sp <= 30)]
    return float(np.median(sp)) if len(sp) else 8.0

def process(files, approx=None):
    poses = []
    for f in files:
        img = clean(Image.open(f).convert("RGBA"))
        ps = split(img)
        poses += ps
    if approx is None:
        approx = np.median([estimate(p) for p in poses[:3]])
        # pixel troppo piccoli (eroe oltre ~80 pixel): celle doppie, cosi' resta intorno ai 60
        hpx = np.median([p.size[1] for p in poses])
        while hpx / approx > 80: approx *= 2
    out = [strip_ground(snap(p, approx)) for p in poses]
    return out, approx

def strip_ground(img):
    # linee di terra: nella parte bassa, pixel di una riga che non hanno nulla ne' sopra ne' sotto
    a = np.array(img); op = a[..., 3] > 0
    H, W = op.shape
    for y in range(int(H * 0.7), H):
        row = op[y]
        up = op[y - 1] if y > 0 else np.zeros(W, bool)
        dn = op[y + 1] if y + 1 < H else np.zeros(W, bool)
        lone = row & ~up & ~dn
        if lone.sum() >= max(4, 0.25 * row.sum()):
            a[y, lone, 3] = 0
    # puntini isolati rimasti (1-3 pixel staccati dal corpo)
    lab, n = ndimage.label(a[..., 3] > 0, structure=np.ones((3, 3)))
    sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
    for i, sz in enumerate(sizes, 1):
        if sz <= 3: a[lab == i, 3] = 0
    res = Image.fromarray(a, "RGBA")
    return res.crop(res.getbbox())

def pack(smalls, out):
    anchors = []
    for s in smalls:
        a = np.array(s)[..., 3] > 0; hh = a.shape[0]
        ys, xs = np.where(a[int(hh * 0.45):int(hh * 0.95)])
        anchors.append(int(np.median(xs)) if len(xs) else s.size[0] // 2)
    left = max(anchors) + 2; right = max(s.size[0] - an for s, an in zip(smalls, anchors)) + 2
    fw, fh = left + right, max(s.size[1] for s in smalls) + 2
    sheet = Image.new("RGBA", (fw * len(smalls), fh), (0, 0, 0, 0))
    for i, (s, an) in enumerate(zip(smalls, anchors)):
        sheet.alpha_composite(s, (i * fw + left - an, fh - s.size[1]))
    sheet.save(out)
    open(out.replace(".png", ".lua"), "w").write("return { fw = %d, fh = %d, ox = %d, frames = %d }\n" % (fw, fh, left, len(smalls)))
    return sheet

def preview(sheet, out, z=5):
    p = Image.new("RGBA", (sheet.size[0] * z, sheet.size[1] * z), (50, 52, 70, 255))
    p.alpha_composite(sheet.resize((sheet.size[0] * z, sheet.size[1] * z), Image.NEAREST)); p.save(out)

if __name__ == "__main__":
    out = sys.argv[1]; files = sys.argv[2:]
    smalls, approx = process(files)
    print("pose", len(smalls), "pixel del modello ~%.1f px" % approx, "altezze", [s.size[1] for s in smalls])
    sheet = pack(smalls, out); preview(sheet, out.replace(".png", "_prev.png"))
