# Mette l'icona del gioco (assets/icon.png, il gatto ninja) dentro love.exe.
# Sostituisce le icone gia' presenti con immagini della stessa misura, quindi il file resta valido.
# Uso: python3 tools/icona_exe.py love.exe FriendslopFight_base.exe
# Poi l'exe del gioco: copy /b FriendslopFight_base.exe + gioco.love FriendslopFight.exe
import sys, struct
import pefile
from PIL import Image

src = Image.open("assets/icon.png").convert("RGBA")

def dib(im):
    w, h = im.size
    hdr = struct.pack("<IiiHHIIiiII", 40, w, h * 2, 1, 32, 0, 0, 0, 0, 0, 0)
    px = bytearray()
    for y in range(h - 1, -1, -1):
        for x in range(w):
            r, g, b, a = im.getpixel((x, y))
            px += bytes((b, g, r, a))
    return hdr + bytes(px) + bytes(((w + 31) // 32) * 4 * h)

pe = pefile.PE(sys.argv[1])
raw = bytearray(open(sys.argv[1], "rb").read())
for t in pe.DIRECTORY_ENTRY_RESOURCE.entries:
    if t.id != 3:
        continue
    for e in t.directory.entries:
        for l in e.directory.entries:
            d = l.data.struct
            n = int(((d.Size - 40) / 4.125) ** 0.5 + 0.5)   # 32 bit + maschera
            im = src.resize((n, n), Image.NEAREST if n >= 128 else Image.LANCZOS)
            data = dib(im)
            if len(data) != d.Size:
                print("misura diversa, salto", n)
                continue
            off = pe.get_offset_from_rva(d.OffsetToData)
            raw[off:off + d.Size] = data
open(sys.argv[2], "wb").write(raw)
print("fatto", sys.argv[2])
