import sys, numpy as np
from PIL import Image
sys.path.insert(0, ".")
src, out, target_h = sys.argv[1], sys.argv[2], int(sys.argv[3])
im = Image.open(src).convert("RGBA")
A = np.array(im)
op = A[..., 3] > 128
cols = op.any(0)
# pose separate da colonne vuote (ignoro i pezzetti stretti)
frames, x = [], 0
while x < len(cols):
    if cols[x]:
        x0 = x
        while x < len(cols) and cols[x]: x += 1
        if x - x0 > 15: frames.append((x0, x))
    else: x += 1
# unisco pezzi vicini (es. fascia staccata dalla testa)
merged = []
for f in frames:
    if merged and f[0] - merged[-1][1] < 12: merged[-1] = (merged[-1][0], f[1])
    else: merged.append(f)
print("pose trovate", len(merged))
crops = []
for x0, x1 in merged:
    sub = op[:, x0:x1]; ys = np.where(sub.any(1))[0]
    crops.append(im.crop((x0, ys.min(), x1, ys.max() + 1)))
# stessa scala per tutte: l'altezza della posa ferma diventa target_h
k = target_h / crops[0].size[1]
from riduci_sprite import shrink
smalls = []
for i, c in enumerate(crops):
    c.save("tmp_pose.png")
    h = max(8, round(c.size[1] * k))
    s = shrink("tmp_pose.png", h, 32)
    smalls.append(s)
# punto d'appoggio: mediana x dei pixel opachi nella meta' bassa (corpo e gambe, non la coda)
anchors = []
for s in smalls:
    a = np.array(s)[..., 3] > 0
    hh = a.shape[0]
    ys, xs = np.where(a[int(hh * 0.45):int(hh * 0.95)])
    anchors.append(int(np.median(xs)) if len(xs) else s.size[0] // 2)
left = max(an for an in anchors) + 2
right = max(s.size[0] - an for s, an in zip(smalls, anchors)) + 2
fw, fh = left + right, max(s.size[1] for s in smalls) + 2
sheet = Image.new("RGBA", (fw * len(smalls), fh), (0, 0, 0, 0))
for i, (s, an) in enumerate(zip(smalls, anchors)):
    sheet.alpha_composite(s, (i * fw + left - an, fh - s.size[1]))
sheet.save(out)
open(out.replace(".png", ".lua"), "w").write(
    "return { fw = %d, fh = %d, ox = %d, frames = %d }\n" % (fw, fh, left, len(smalls)))
z = 6
prev = Image.new("RGBA", (sheet.size[0] * z, sheet.size[1] * z), (50, 52, 70, 255))
prev.alpha_composite(sheet.resize((sheet.size[0] * z, sheet.size[1] * z), Image.NEAREST))
prev.save("sheet_preview.png")
print("frame", fw, fh, "ancora", left)
