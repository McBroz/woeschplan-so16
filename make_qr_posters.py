# -*- coding: utf-8 -*-
"""Erzeugt schöne, druckfertige QR-Poster (JPG) für den Wöschplan SO 16."""
import os, math
import qrcode
from qrcode.image.styledpil import StyledPilImage
from qrcode.image.styles.moduledrawers.pil import RoundedModuleDrawer
from qrcode.image.styles.colormasks import SolidFillColorMask
from PIL import Image, ImageDraw, ImageFont, ImageFilter

URL = "https://mcbroz.github.io/woeschplan-so16/"
OUT = r"C:\Users\Del\AWG Dropbox\Alessandro Del Cotto\KI_Manager_Del Cotto\Wöschplan1.0"
FONTS = r"C:\Windows\Fonts"

W, H = 1240, 1754  # A4 @ 150 dpi

def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)

def emoji_font(size):
    return ImageFont.truetype(os.path.join(FONTS, "seguiemj.ttf"), size)

F_BLACK  = "segoeui.ttf"
F_BOLD   = "segoeuib.ttf"
F_BLACKW = "seguibl.ttf"   # Segoe UI Black
F_SEMI   = "seguisb.ttf"

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i]-a[i])*t) for i in range(3))

def vgradient(size, top, bottom):
    w, h = size
    base = Image.new("RGB", (1, h))
    for y in range(h):
        base.putpixel((0, y), lerp(top, bottom, y/(h-1)))
    return base.resize((w, h))

def soft_circle(img, cx, cy, r, color, alpha=255, blur=0):
    layer = Image.new("RGBA", img.size, (0,0,0,0))
    d = ImageDraw.Draw(layer)
    d.ellipse([cx-r, cy-r, cx+r, cy+r], fill=color+(alpha,))
    if blur:
        layer = layer.filter(ImageFilter.GaussianBlur(blur))
    img.alpha_composite(layer)

def sun(img, cx, cy, r, core, glow):
    # glow
    soft_circle(img, cx, cy, int(r*2.1), glow, 90, blur=40)
    # rays
    layer = Image.new("RGBA", img.size, (0,0,0,0))
    d = ImageDraw.Draw(layer)
    for k in range(12):
        a = k * (math.pi/6)
        x1 = cx + math.cos(a)*(r*1.25); y1 = cy + math.sin(a)*(r*1.25)
        x2 = cx + math.cos(a)*(r*1.7);  y2 = cy + math.sin(a)*(r*1.7)
        d.line([x1,y1,x2,y2], fill=core+(230,), width=max(6,r//12))
    img.alpha_composite(layer)
    soft_circle(img, cx, cy, r, core, 255)

def clothes_line(img, x1, y1, x2, y2, palette):
    layer = Image.new("RGBA", img.size, (0,0,0,0))
    d = ImageDraw.Draw(layer)
    # slack line (parabola)
    pts = []
    for i in range(41):
        t = i/40
        x = x1 + (x2-x1)*t
        sag = math.sin(math.pi*t)*46
        y = y1 + (y2-y1)*t + sag
        pts.append((x,y))
    d.line(pts, fill=(120,100,70,150), width=3)
    # hanging clothes
    n = len(palette)
    for i, col in enumerate(palette):
        t = (i+1)/(n+1)
        x = x1 + (x2-x1)*t
        sag = math.sin(math.pi*t)*46
        y = y1 + (y2-y1)*t + sag
        cw, ch = 58, 78
        # peg
        d.line([x, y-6, x, y+4], fill=(150,120,90,220), width=4)
        # shirt: body + sleeves as rounded rect
        d.rounded_rectangle([x-cw//2, y, x+cw//2, y+ch], radius=14, fill=col+(235,))
        d.rounded_rectangle([x-cw//2-14, y+4, x-cw//2+10, y+40], radius=8, fill=col+(235,))
        d.rounded_rectangle([x+cw//2-10, y+4, x+cw//2+14, y+40], radius=8, fill=col+(235,))
        # collar notch
        d.polygon([(x-12,y),(x+12,y),(x,y+16)], fill=(255,255,255,220))
    img.alpha_composite(layer)

def bubbles(img, spots):
    layer = Image.new("RGBA", img.size, (0,0,0,0))
    d = ImageDraw.Draw(layer)
    for (x,y,r) in spots:
        d.ellipse([x-r,y-r,x+r,y+r], fill=(255,255,255,70), outline=(255,255,255,140), width=2)
        d.ellipse([x-r*0.4-r*0.2, y-r*0.4-r*0.2, x-r*0.4+r*0.2, y-r*0.4+r*0.2], fill=(255,255,255,200))
    img.alpha_composite(layer)

def rounded_shadow_card(img, box, radius, fill):
    x0,y0,x1,y1 = box
    sh = Image.new("RGBA", img.size, (0,0,0,0))
    ds = ImageDraw.Draw(sh)
    ds.rounded_rectangle([x0+10,y0+22,x1+10,y1+22], radius=radius, fill=(120,80,30,90))
    sh = sh.filter(ImageFilter.GaussianBlur(26))
    img.alpha_composite(sh)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(box, radius=radius, fill=fill+(255,))

def make_qr(fg, size):
    qr = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_H, box_size=20, border=1)
    qr.add_data(URL); qr.make(fit=True)
    img = qr.make_image(image_factory=StyledPilImage,
                        module_drawer=RoundedModuleDrawer(),
                        color_mask=SolidFillColorMask(front_color=fg, back_color=(255,255,255)))
    return img.convert("RGBA").resize((size,size), Image.LANCZOS)

def center_text(d, cx, y, text, fnt, fill, emoji=False):
    if emoji:
        try:
            bb = d.textbbox((0,0), text, font=fnt, embedded_color=True)
            w = bb[2]-bb[0]
            d.text((cx-w/2, y), text, font=fnt, embedded_color=True)
            return
        except Exception:
            pass
    bb = d.textbbox((0,0), text, font=fnt)
    w = bb[2]-bb[0]
    d.text((cx-w/2, y), text, font=fnt, fill=fill)

def poster(theme):
    img = vgradient((W,H), theme["top"], theme["bottom"]).convert("RGBA")
    # sun
    sun(img, theme["sun_xy"][0], theme["sun_xy"][1], 150, theme["sun"], theme["glow"])
    # bubbles scattered
    bubbles(img, [(160,540,26),(1080,760,34),(120,1180,30),(1110,1300,22),(240,1420,18),(1000,1120,16)])
    # clothesline near top
    clothes_line(img, 120, 300, 1120, 300, theme["clothes"])

    d = ImageDraw.Draw(img)
    # Title
    center_text(d, W//2, 470, "Wöschplan", font(F_BLACKW, 118), theme["ink"])
    center_text(d, W//2, 596, "SO 16", font(F_BLACKW, 92), theme["accent"])
    center_text(d, W//2, 712, "Waschraum-Buchung  ·  6 Wohnungen", font(F_SEMI, 40), theme["ink2"])

    # QR card
    qsize = 560
    cx0 = (W - (qsize+120))//2
    cy0 = 772
    card = [cx0, cy0, cx0+qsize+120, cy0+qsize+120]
    rounded_shadow_card(img, card, 46, (255,255,255))
    qr = make_qr(theme["qr"], qsize)
    img.alpha_composite(qr, (cx0+60, cy0+60))

    # Call to action (dunkel & gut lesbar)
    cta_y = card[3] + 40
    center_text(d, W//2, cta_y, "Scan mich  &  loslegen!", font(F_BLACKW, 60), theme["accent"])
    # URL pill
    url_txt = "mcbroz.github.io/woeschplan-so16"
    fnt = font(F_BOLD, 36)
    bb = d.textbbox((0,0), url_txt, font=fnt); tw = bb[2]-bb[0]
    px = (W-tw-90)//2; py = cta_y+94
    d.rounded_rectangle([px, py, px+tw+90, py+74], radius=37, fill=theme["accent"]+(255,))
    d.text((px+45, py+15), url_txt, font=fnt, fill=(255,255,255))

    # footer
    center_text(d, W//2, py+106, "Einfach scannen · einloggen · Waschzeit sichern",
                font(F_SEMI, 31), theme["ink2"])

    out = os.path.join(OUT, theme["file"])
    img.convert("RGB").save(out, "JPEG", quality=92)
    print("saved", out)

THEMES = [
  dict(file="qr-poster-sonnig.jpg",
       top=(255,238,205), bottom=(255,247,236), sun=(255,150,50), glow=(255,182,39),
       clothes=[(255,140,66),(46,134,171),(76,175,109),(255,182,39),(232,93,93)],
       ink=(58,46,31), ink2=(138,120,96), accent=(255,140,66), qr=(200,90,25),
       sun_xy=(1050,180)),
  dict(file="qr-poster-himmel.jpg",
       top=(206,232,246), bottom=(240,250,255), sun=(255,193,64), glow=(255,214,120),
       clothes=[(46,134,171),(255,140,66),(110,198,232),(76,175,109),(255,182,39)],
       ink=(30,58,74), ink2=(90,120,140), accent=(46,134,171), qr=(30,90,130),
       sun_xy=(190,180)),
  dict(file="qr-poster-frisch.jpg",
       top=(220,244,228), bottom=(247,253,248), sun=(255,182,39), glow=(255,205,110),
       clothes=[(76,175,109),(255,140,66),(46,134,171),(255,182,39),(232,93,93)],
       ink=(35,60,45), ink2=(95,125,105), accent=(76,175,109), qr=(30,110,70),
       sun_xy=(1050,180)),
]

for t in THEMES:
    poster(t)
print("done")
