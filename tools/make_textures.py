#!/usr/bin/env python3
"""Draws the bar textures of Media/textures as 256x64 uncompressed TGA files.

Every texture is grey: a status bar multiplies it by the colour chosen in the
options, so a white pixel shows that colour and a darker one shades it. They
all stay between 0.45 and 1.0 so the colour is still recognisable, and the
patterns are anti-aliased: a hard pixel edge stretched over a 500 pixel bar
is what makes a texture look cheap.
Run it from the addon folder after changing a recipe below.
"""
import math
import os
import struct

W, H = 256, 64
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Media", "textures")

TOP = 1.5 / H     # Height of the light line along the top edge
BOTTOM = 1.5 / H  # Height of the shadow line along the bottom edge


def smoothstep(a, b, x):
    if a == b:
        return 0.0 if x < a else 1.0
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def band(t, center, width):
    """A soft bump peaking at center, 0 further than width away."""
    return math.exp(-(((t - center) / width) ** 2))


def edges(value, t, light=1.0, shadow=0.45):
    """The crisp top light and bottom shadow that make a bar read as solid."""
    if t <= TOP:
        return light
    if t >= 1 - BOTTOM:
        return shadow
    return value


def glaze(x, y, t, u):
    """Glossy: a wide specular sweep over the upper half."""
    base = 0.92 - 0.34 * smoothstep(0.0, 1.0, t)
    return edges(base + 0.26 * band(t, 0.24, 0.17), t)


def satin(x, y, t, u):
    """A quiet gradient, the one that fits any interface."""
    return edges(0.97 - 0.30 * t ** 1.3, t, 1.0, 0.5)


def minimal(x, y, t, u):
    """Almost flat: all the shape comes from the two edges."""
    return edges(0.93 - 0.07 * t, t, 1.0, 0.55)


def tube(x, y, t, u):
    """Rounded: the light runs along the middle, the bar looks cylindrical."""
    away = abs(t - 0.46) * 2
    return edges(1.0 - 0.46 * away ** 1.5, t, 0.72, 0.5)


def bevel(x, y, t, u):
    """Two faces split by a bright line, like a brushed aluminium bar."""
    if t < 0.5:
        value = 0.95 - 0.08 * (t * 2)
    else:
        value = 0.66 - 0.10 * ((t - 0.5) * 2)
    return edges(value + 0.30 * band(t, 0.5, 0.035), t, 1.0, 0.45)


def brushed(x, y, t, u):
    """Fine horizontal grain, soft enough to stay a texture and not noise."""
    grain = 0.04 * math.sin(y * 2.3) + 0.025 * math.sin(y * 7.1 + 1.3)
    return edges(0.90 - 0.26 * t + grain, t, 1.0, 0.47)


def linen(x, y, t, u):
    """A woven cross-hatch, very low contrast."""
    weave = 0.035 * (math.sin(x * 0.80) + math.sin(y * 0.80))
    return edges(0.90 - 0.22 * t + weave, t, 1.0, 0.5)


def diagonal(x, y, t, u):
    """Soft diagonal stripes: the edges are shaded, never stepped."""
    phase = ((x + y * 1.6) % 22) / 22
    stripe = smoothstep(0.0, 0.22, phase) - smoothstep(0.5, 0.72, phase)
    return edges(0.80 - 0.20 * t + 0.19 * stripe, t, 1.0, 0.47)


def glass(x, y, t, u):
    """A clear pane: bright above the cut, dimmer below, with bounced light."""
    if t < 0.47:
        value = 0.99 - 0.16 * (t / 0.47)
    else:
        value = 0.60 - 0.06 * ((t - 0.47) / 0.53) + 0.14 * smoothstep(0.75, 1.0, t)
    return edges(value, t, 1.0, 0.5)


def ember(x, y, t, u):
    """A glow held in the middle of the bar, for the brighter colours."""
    return edges(0.52 + 0.46 * band(t, 0.46, 0.33), t, 0.9, 0.45)


RECIPES = {
    "glaze": glaze,
    "satin": satin,
    "minimal": minimal,
    "tube": tube,
    "bevel": bevel,
    "brushed": brushed,
    "linen": linen,
    "diagonal": diagonal,
    "glass": glass,
    "ember": ember,
}


def write(name, recipe):
    # 18 byte header: uncompressed true colour, 32 bits, top row first
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, W, H, 32, 0x28)
    pixels = bytearray()
    for y in range(H):
        t = (y + 0.5) / H
        for x in range(W):
            u = (x + 0.5) / W
            value = min(max(recipe(x, y, t, u), 0.0), 1.0)
            grey = int(value * 255 + 0.5)
            pixels += bytes((grey, grey, grey, 255))  # BGRA
    path = os.path.join(OUT, name + ".tga")
    with open(path, "wb") as f:
        f.write(header)
        f.write(pixels)
    return path


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for old in os.listdir(OUT):
        if old.endswith(".tga") and old[:-4] not in RECIPES:
            os.remove(os.path.join(OUT, old))
    for name, recipe in RECIPES.items():
        print(write(name, recipe))
