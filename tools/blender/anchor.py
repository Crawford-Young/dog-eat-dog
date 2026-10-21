"""Issue #24 style anchor: the dog standing (front), walking (side), stinky,
plus an alarm clock. Renders one PNG per item and a labelled review sheet.

    python3 tools/blender/anchor.py <out_dir>
"""

import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import toon  # noqa: E402
from toon import flat, limb, sphere, tube  # noqa: E402

FUR = "#d9964f"
CREAM = "#f6e3c3"
EAR = "#7a4a2a"
NOSE = "#2a1d24"
WHITE = "#fbf7f0"
PUPIL = "#1d1622"
TONGUE = "#ec7b8a"
STINK = "#9cc24a"
MUD = "#7c5b3a"


def dog(pose="stand"):
    """The office dog, bipedal, facing -Y. pose: stand | walk | stinky."""
    root = bpy.data.objects.new("root", None)
    bpy.context.collection.objects.link(root)
    stinky = pose == "stinky"
    walk = pose == "walk"
    fur = toon.shade(FUR, 0.86, cool=0.1) if stinky else FUR
    p = root
    m_fur, m_cream, m_ear = toon.toon(fur), toon.toon(CREAM), toon.toon(EAR)
    slump = 0.08 if stinky else 0.0  # head sinks when the dog is wrecked

    # torso + belly
    sphere((0, 0, 1.0), (0.56, 0.46, 0.66), m_fur, parent=p)
    sphere((0, -0.2, 0.93), (0.42, 0.3, 0.48), m_cream, parent=p, outline=False)
    # head
    hz = 2.02 - slump
    sphere((0, 0, hz), (0.64, 0.56, 0.56), m_fur, parent=p)
    sphere((0, -0.44, hz - 0.17), (0.33, 0.28, 0.23), m_cream, parent=p)
    sphere((0, -0.72, hz - 0.07), (0.13, 0.08, 0.095), toon.toon(NOSE), parent=p)
    sphere((-0.04, -0.79, hz - 0.04), (0.03, 0.02, 0.022), flat(WHITE), parent=p, outline=False)
    # mouth: a grin, or a flat tired line when stinky
    if stinky:
        tube([(-0.13, -0.66, hz - 0.3), (0, -0.67, hz - 0.31), (0.13, -0.66, hz - 0.29)],
             0.018, flat(PUPIL), parent=p, outline=False)
    else:
        tube([(-0.17, -0.63, hz - 0.24), (-0.08, -0.69, hz - 0.33), (0.0, -0.7, hz - 0.31),
              (0.08, -0.69, hz - 0.33), (0.17, -0.63, hz - 0.24)],
             0.02, flat(PUPIL), parent=p, outline=False)
        sphere((0.05, -0.64, hz - 0.37), (0.07, 0.04, 0.06), toon.toon(TONGUE), parent=p)
    # eyes
    for s in (-1, 1):
        ex, ey, ez = 0.22 * s, -0.45, hz + 0.13
        sphere((ex, ey, ez), (0.13, 0.08, 0.16), toon.toon(WHITE), parent=p)
        sphere((ex + 0.02 * s * (0 if walk else 1), ey - 0.065, ez - 0.02),
               (0.07, 0.03, 0.09), flat(PUPIL), parent=p, outline=False)
        sphere((ex - 0.02, ey - 0.09, ez + 0.03), (0.022, 0.01, 0.026), flat(WHITE),
               parent=p, outline=False)
        if stinky:  # heavy lids
            sphere((ex, ey - 0.005, ez + 0.05), (0.145, 0.088, 0.13), m_fur, parent=p)
        # brows
        tilt = -14 * s if stinky else 10 * s
        sphere((ex, ey + 0.02, ez + 0.24), (0.11, 0.04, 0.03), toon.toon(EAR),
               rot=(0, tilt, 0), parent=p, outline=False)
    # floppy ears
    droop = 10 if stinky else 0
    for s in (-1, 1):
        sphere((0.6 * s, 0.04, hz - 0.2 - droop / 100), (0.16, 0.11, 0.42), m_ear,
               rot=(0, -14 * s + droop * s, 0), parent=p)

    # arms + paws
    swing = 0.28 if walk else 0.0
    for s in (-1, 1):
        sh = (0.48 * s, 0, 1.38 - slump)
        if walk:
            hand = (0.6 * s, -swing * s, 0.82)
        elif stinky:
            hand = (0.62 * s, 0.05, 0.72)
        else:
            hand = (0.7 * s, -0.06, 0.82)
        limb(sh, hand, 0.13, m_fur, parent=p, r1=0.12)
        sphere(hand, (0.16, 0.15, 0.15), m_cream, parent=p)
    # legs + feet
    for s in (-1, 1):
        hip = (0.26 * s, 0, 0.56)
        if walk:
            fy, fz = swing * 1.2 * s, 0.12 + (0.05 if s > 0 else 0.0)
        else:
            fy, fz = 0.0, 0.12
        knee_y = fy * 0.5
        limb(hip, (0.27 * s, knee_y, 0.3), 0.17, m_fur, parent=p, r1=0.15)
        limb((0.27 * s, knee_y, 0.3), (0.28 * s, fy, fz + 0.04), 0.15, m_fur, parent=p, r1=0.14)
        sphere((0.28 * s, fy - 0.12, fz), (0.19, 0.27, 0.11), m_cream, parent=p)
    # tail
    wag = 0.35 if walk else 0.18
    tail_pts = ([(0, 0.4, 0.75), (0.05, 0.62, 0.62), (0.08, 0.78, 0.55)] if stinky else
                [(0, 0.4, 0.8), (0.05, 0.7, 0.95), (wag, 0.85, 1.25)])
    tube(tail_pts, 0.1, m_fur, parent=p, taper=(1.0, 0.55))

    if stinky:
        m_mud = toon.toon(MUD)
        for loc, sc in [((0.28, -0.4, 1.22), (0.12, 0.05, 0.09)),
                        ((-0.3, -0.38, 0.78), (0.1, 0.05, 0.07)),
                        ((0.27, -0.16, 0.3), (0.08, 0.05, 0.06)),
                        ((-0.3, -0.5, hz + 0.33), (0.1, 0.05, 0.06))]:
            sphere(loc, sc, m_mud, parent=p, outline=False)
        m_stink = toon.toon(STINK)
        for x, z0, ph in [(-0.95, 1.1, 0.0), (0.98, 1.3, 1.6), (-0.55, 2.55, 0.8),
                          (0.65, 2.6, 2.4)]:
            pts = [(x + 0.1 * math.sin(ph + i * 1.6), -0.3, z0 + i * 0.16) for i in range(6)]
            tube(pts, 0.05, m_stink, taper=(0.4, 1.0))
        for fx, fz in [(-0.85, 2.85), (0.95, 2.05), (0.15, 3.0)]:
            sphere((fx, -0.4, fz), (0.07, 0.06, 0.06), toon.toon(PUPIL))
            for s in (-1, 1):
                sphere((fx + 0.07 * s, -0.38, fz + 0.08), (0.07, 0.02, 0.045),
                       flat("#dde8f0"), rot=(0, 30 * s, 0), outline=True)
    if walk:
        root.rotation_euler = (0, 0, math.radians(-90))
        root.rotation_euler.x = math.radians(-4)  # slight forward lean
    return root


def alarm_clock():
    red = toon.toon("#d64541")
    metal = toon.toon("#c9ccd6")
    face_c = toon.toon("#fff4dc")
    ink = flat(PUPIL)
    # body faces the camera (-Y)
    toon.cylinder((0, 0, 1.0), 0.85, 0.5, red, rot=(90, 0, 0), cap_smooth=False)
    toon.cylinder((0, -0.26, 1.0), 0.7, 0.04, face_c, rot=(90, 0, 0))
    for i in range(12):
        a = math.radians(i * 30)
        r = 0.58
        long = i % 3 == 0
        toon.box((r * math.sin(a), -0.29, 1.0 + r * math.cos(a)),
                 (0.025, 0.01, 0.07 if long else 0.04), ink, rot=(0, math.degrees(a), 0),
                 outline=False)
    # hands at 10:10
    for deg, length, w in [(-60, 0.36, 0.035), (60, 0.5, 0.025)]:
        a = math.radians(deg)
        toon.box((length / 2 * math.sin(a), -0.3, 1.0 + length / 2 * math.cos(a)),
                 (w, 0.01, length / 2), ink, rot=(0, deg, 0), outline=False)
    sphere((0, -0.31, 1.0), (0.05, 0.02, 0.05), toon.toon("#d64541"), outline=False)
    # bells + hammer
    for s in (-1, 1):
        a = math.radians(38 * s)
        cx, cz = 0.78 * math.sin(a), 1.0 + 0.78 * math.cos(a)
        sphere((cx, 0, cz), (0.36, 0.3, 0.26), metal, rot=(0, 38 * s, 0))
        toon.cylinder((cx * 0.8, 0, cz - 0.05), 0.04, 0.2, metal, rot=(0, 38 * s, 0))
    toon.cylinder((0, 0.05, 1.98), 0.035, 0.22, metal)
    sphere((0, 0.05, 2.12), (0.09, 0.09, 0.09), metal)
    # feet
    for s in (-1, 1):
        sphere((0.5 * s, 0, 0.17), (0.13, 0.13, 0.12), metal)
        limb((0.42 * s, 0, 0.32), (0.5 * s, 0, 0.2), 0.05, metal)
    # wake-up shakes
    for s in (-1, 1):
        for k, r in enumerate((1.25, 1.45)):
            pts = [(s * r * math.sin(math.radians(a)), -0.1, 1.0 + r * math.cos(math.radians(a)))
                   for a in (40 + 6 * k, 60, 80 - 6 * k)]
            pts = [(s * abs(x), y, z) for x, y, z in pts]
            tube(pts, 0.035, ink, outline=False)


ITEMS = [
    ("dog_front", "dog standing (front)", lambda: dog("stand")),
    ("dog_walk", "dog walking (side)", lambda: dog("walk")),
    ("dog_stinky", "dog stinky", lambda: dog("stinky")),
    ("alarm_clock", "alarm clock", alarm_clock),
]


def main(out):
    os.makedirs(out, exist_ok=True)
    only = set(sys.argv[2:])
    for name, _label, build in ITEMS:
        if only and name not in only:
            continue
        toon.reset()
        build()
        toon.bake()
        toon.render(os.path.join(out, name + ".png"))
    sheet(out)


def sheet(out, cell=512, pad=32, bg=(46, 52, 64)):
    from PIL import Image, ImageDraw, ImageFont

    cols = len(ITEMS)
    label_h = 48
    img = Image.new("RGB", (cols * (cell + pad) + pad, cell + label_h + pad * 2), bg)
    draw = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("DejaVuSans.ttf", 26)
    except OSError:
        font = ImageFont.load_default()
    for i, (name, label, _b) in enumerate(ITEMS):
        x = pad + i * (cell + pad)
        path = os.path.join(out, name + ".png")
        if os.path.exists(path):
            art = Image.open(path).convert("RGBA")
            img.paste(art, (x, pad), art)
        tw = draw.textlength(label, font=font)
        draw.text((x + (cell - tw) / 2, pad + cell + 10), label, fill=(235, 235, 240), font=font)
    img.save(os.path.join(out, "sheet_anchor.png"))


if __name__ == "__main__":
    main(sys.argv[1])
