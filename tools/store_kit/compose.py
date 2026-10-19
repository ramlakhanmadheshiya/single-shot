"""Composes a game's Google Play store images from raw captures and a small spec.

Run from the project root, after capturing (godot --path . res://kit/tools/capture.tscn):
  python3 kit/tools/store/compose.py            # reads store/store.json, writes assets/store/
"""

import json
import math
import os
import random
import re
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SPEC = "store/store.json"
RAW = "build/store/raw"
OUT = "assets/store"
SUPER = 2  # draw rounded masks at 2x and downsample for clean edges

LIMITS = {"title": 30, "short": 80, "full": 4000}
PHONE = (1080, 1920)
TABLET = (1920, 1080)
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
# Play's rules for text in graphics (checked 2026-09): nothing that suggests ranking, price, a Play
# category or a promotion, and no call to action.
BANNED = [r"\bbest\b", r"#1\b", r"\btop\b", r"\bnew\b", r"\bdiscount", r"\bsale\b", r"\bfree\b",
          r"\b(download|install|play|try|get it) now\b"]


def rgb(hex_colour):
    h = hex_colour.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def contrast(a, b):
    """WCAG contrast ratio between two colours."""
    def lum(c):
        ch = [v / 255 for v in c]
        ch = [v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4 for v in ch]
        return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2]
    hi, lo = sorted((lum(a), lum(b)), reverse=True)
    return (hi + 0.05) / (lo + 0.05)


class Style:
    def __init__(self, spec):
        self.colours = {k: rgb(v) for k, v in spec["colours"].items()}
        self.dark = spec.get("dark", False)
        self.fonts = spec["fonts"]
        self.pieces = [rgb(c) for c in spec.get("pieces", [])] or [self.colours["accent"]]
        self.decor = spec.get("decor", "glows")
        c = self.colours
        self.ink = c["ink"]
        # The brand's muted grey is tuned for its own background. On a tinted one it needs more weight.
        self.quiet = mix(c["muted"], c["ink"], 0.35)

    def face(self, role, size):
        face = ImageFont.truetype(self.fonts[role], max(8, int(size)))
        weight = self.fonts.get(role + "_weight")
        if weight:
            face.set_variation_by_axes([weight])
        return face

    def tint(self, i):
        return self.pieces[i % len(self.pieces)]

    def base(self, i):
        return mix(self.colours["bg"], self.tint(i), 0.08 if self.dark else 0.16)

    def highlight(self, i):
        """Pushed towards the ink until it reads as large text on the shot's background."""
        piece = self.tint(i)
        colour = mix(piece, WHITE, 0.1) if self.dark else piece
        t = 0.0
        while contrast(colour, self.base(i)) < 3.2 and t < 1.0:
            t += 0.05
            colour = mix(piece, self.ink, t)
        return colour

    def surface(self):
        """Opaque, so nothing behind shows through the chips' words."""
        return mix(self.colours["bg"], WHITE, 0.14 if self.dark else 0.85) + (255,)


def place(canvas, layer, x, y):
    """alpha_composite that lets the layer hang off any edge."""
    x, y = int(round(x)), int(round(y))
    left, top = max(0, -x), max(0, -y)
    right, bottom = min(layer.width, canvas.width - x), min(layer.height, canvas.height - y)
    if right > left and bottom > top:
        canvas.alpha_composite(layer.crop((left, top, right, bottom)), (x + left, y + top))


def gradient(size, top, bottom):
    w, h = size
    t = np.linspace(0.0, 1.0, h)[:, None, None]
    rows = np.array(top)[None, None, :] * (1 - t) + np.array(bottom)[None, None, :] * t
    return Image.fromarray(np.repeat(rows, w, axis=1).astype(np.uint8), "RGB")


def glow(canvas, centre, radius, colour, alpha, power=1.6):
    d = max(2, int(radius * 2))
    yy, xx = np.mgrid[0:d, 0:d]
    r = np.hypot(xx - d / 2, yy - d / 2) / (d / 2)
    a = (np.clip(1 - r, 0, 1) ** power * alpha * 255).astype(np.uint8)
    layer = Image.new("RGBA", (d, d), colour + (0,))
    layer.putalpha(Image.fromarray(a, "L"))
    place(canvas, layer, centre[0] - d / 2, centre[1] - d / 2)


def rounded_mask(size, radius):
    w, h = size
    big = Image.new("L", (w * SUPER, h * SUPER), 0)
    ImageDraw.Draw(big).rounded_rectangle([0, 0, w * SUPER - 1, h * SUPER - 1], radius=radius * SUPER, fill=255)
    return big.resize(size, Image.LANCZOS)


def disc_mask(d):
    big = Image.new("L", (d * 4, d * 4), 0)
    ImageDraw.Draw(big).ellipse([0, 0, d * 4 - 1, d * 4 - 1], fill=255)
    return big.resize((d, d), Image.LANCZOS)


def drop(canvas, layer, x, y, style, depth=1.0):
    """The shadow is cast from the layer's own alpha, so tilted cards and round callouts cast their real
    shape."""
    tone = BLACK if style.dark else mix(style.ink, BLACK, 0.3)
    strength = (150 if style.dark else 70) * depth
    for blur, offset, share in ((int(40 * depth) + 6, 28 * depth, 1.0), (8, 6 * depth, 0.55)):
        pad = blur * 3
        shade = Image.new("RGBA", (layer.width + pad * 2, layer.height + pad * 2), tone + (0,))
        alpha = Image.new("L", shade.size, 0)
        alpha.paste(layer.split()[3].point(lambda v: int(v * strength * share / 255)), (pad, pad))
        shade.putalpha(alpha.filter(ImageFilter.GaussianBlur(blur)))
        place(canvas, shade, x - pad, y - pad + offset)
    place(canvas, layer, x, y)


def tilted(layer, angle):
    """Rotates with a transparent margin first, so the edges come out smooth instead of stepped."""
    if not angle:
        return layer
    pad = Image.new("RGBA", (layer.width + 8, layer.height + 8), (0, 0, 0, 0))
    pad.paste(layer, (4, 4))
    return pad.rotate(angle, resample=Image.BICUBIC, expand=True)


def autocrop(img, bg, threshold=18, margin=0.04):
    """With the HUD hidden, whatever is not background is the playfield and its shadow."""
    px = img.load()
    w, h = img.size
    step = max(1, min(w, h) // 400)
    xs, ys = [], []
    for y in range(0, h, step):
        for x in range(0, w, step):
            r, g, b = px[x, y]
            if abs(r - bg[0]) + abs(g - bg[1]) + abs(b - bg[2]) > threshold:
                xs.append(x)
                ys.append(y)
    if not xs:
        return img
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    m = int(max(x1 - x0, y1 - y0) * margin)
    return img.crop((max(0, x0 - m), max(0, y0 - m), min(w, x1 + m), min(h, y1 + m)))


def raw_image(name):
    return Image.open(os.path.join(RAW, name + ".png")).convert("RGB")


def framed_raw(name, style, crop=None):
    """`crop` is "auto" for the playfield, or a box in fractions of the frame."""
    raw = raw_image(name)
    if crop == "auto":
        return autocrop(raw, style.colours.get("board_bg", style.colours["bg"]))
    if crop:
        w, h = raw.size
        return raw.crop((int(crop[0] * w), int(crop[1] * h), int(crop[2] * w), int(crop[3] * h)))
    return raw


def card(raw, width, style, radius=None):
    """The hairline edge makes it read as a screen without drawing a phone around it, since Play asks for
    no device imagery."""
    scale = width / raw.width
    screen = raw.resize((int(width), int(round(raw.height * scale))), Image.LANCZOS).convert("RGBA")
    radius = radius or int(width) // 15
    framed = Image.new("RGBA", screen.size, (0, 0, 0, 0))
    framed.paste(screen, (0, 0), rounded_mask(screen.size, radius))
    edge = Image.new("RGBA", (screen.width * SUPER, screen.height * SUPER), (0, 0, 0, 0))
    ink = WHITE if style.dark else style.ink
    ImageDraw.Draw(edge).rounded_rectangle([0, 0, edge.width - 1, edge.height - 1], radius=radius * SUPER,
                                           outline=ink + (40 if style.dark else 26,), width=2 * SUPER)
    framed.alpha_composite(edge.resize(screen.size, Image.LANCZOS))
    return framed


def wrap(draw, text, face, max_width):
    words, lines, line = text.split(), [], ""
    for word in words:
        trial = (line + " " + word).strip()
        if draw.textlength(trial, font=face) <= max_width or not line:
            line = trial
        else:
            lines.append(line)
            line = word
    if line:
        lines.append(line)
    return lines


def balanced(draw, text, face, max_width):
    """The fewest lines that fit, then as even as those lines allow, so a headline never ends on one
    stranded word."""
    lines = wrap(draw, text, face, max_width)
    low, high = max_width * 0.4, max_width
    while high - low > 4:
        mid = (low + high) / 2
        if len(wrap(draw, text, face, mid)) == len(lines):
            high = mid
        else:
            low = mid
    return wrap(draw, text, face, high)


def marked(text):
    return [(w.replace("*", ""), "*" in w) for w in text.split()]


class Words:
    """Measured once, so the layout can make room for the words."""

    def __init__(self, shot, style, head_size, sub_size, max_width, align="centre"):
        self.style, self.align, self.max_width = style, align, max_width
        self.head = style.face("head", head_size)
        self.sub = style.face("ui", sub_size)
        self.chip = style.face("ui", sub_size * 0.92)
        probe = ImageDraw.Draw(Image.new("RGB", (8, 8)))
        self.heads = []
        # A newline in a caption is a line break it asks for, and each part is balanced on its own.
        for part in shot["caption"].split("\n"):
            words = marked(part)
            k = 0
            for line in balanced(probe, " ".join(w for w, _ in words), self.head, max_width):
                n = len(line.split())
                self.heads.append(words[k:k + n])
                k += n
        self.subs = balanced(probe, shot["sub"], self.sub, max_width * 0.92) if shot.get("sub") else []
        self.chips = shot.get("chips", [])
        self.head_step = self.head.size * 1.1
        self.sub_step = self.sub.size * 1.32
        self.chip_h = int(self.chip.size * 2.1)
        self.height = len(self.heads) * self.head_step
        if self.subs:
            self.height += self.sub.size * 0.55 + len(self.subs) * self.sub_step
        if self.chips:
            self.height += self.chip.size * 0.9 + self.chip_h

    def draw(self, canvas, x, y, colour):
        """Draws the block with its top at y: centred on x, or starting at x when left aligned."""
        draw = ImageDraw.Draw(canvas)
        space = draw.textlength(" ", font=self.head)
        for line in self.heads:
            width = sum(draw.textlength(w, font=self.head) for w, _ in line) + space * (len(line) - 1)
            cx = x - width / 2 if self.align == "centre" else x
            for word, lit in line:
                draw.text((cx, y), word, font=self.head, fill=colour if lit else self.style.ink)
                cx += draw.textlength(word, font=self.head) + space
            y += self.head_step
        if self.subs:
            y += self.sub.size * 0.55
            for line in self.subs:
                width = draw.textlength(line, font=self.sub)
                draw.text((x - width / 2 if self.align == "centre" else x, y), line, font=self.sub,
                          fill=self.style.quiet)
                y += self.sub_step
        if self.chips:
            y += self.chip.size * 0.9
            pills = [pill(c, self.chip, self.style, i) for i, c in enumerate(self.chips)]
            gap = int(self.chip.size * 0.6)
            total = sum(p.width for p in pills) + gap * (len(pills) - 1)
            cx = x - total / 2 if self.align == "centre" else x
            for p in pills:
                place(canvas, p, cx, y)
                cx += p.width + gap

    def box(self, x, y):
        width = self.max_width
        left = x - width / 2 if self.align == "centre" else x
        return (left, y, left + width, y + self.height)


def pill(text, face, style, index, dot=True):
    probe = ImageDraw.Draw(Image.new("RGB", (8, 8)))
    h = int(face.size * 2.1)
    pad = int(face.size * 0.95)
    dot_d = int(face.size * 0.55) if dot else 0
    gap = int(face.size * 0.5) if dot else 0
    w = int(pad * 2 + dot_d + gap + probe.textlength(text, font=face))
    big = Image.new("RGBA", (w * SUPER, h * SUPER), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    d.rounded_rectangle([0, 0, w * SUPER - 1, h * SUPER - 1], radius=h * SUPER // 2, fill=style.surface(),
                        outline=(WHITE if style.dark else style.ink) + (30,), width=SUPER * 2)
    if dot:
        cy = h * SUPER / 2
        d.ellipse([pad * SUPER, cy - dot_d * SUPER / 2, (pad + dot_d) * SUPER, cy + dot_d * SUPER / 2],
                  fill=style.tint(index) + (255,))
    layer = big.resize((w, h), Image.LANCZOS)
    box = probe.textbbox((0, 0), text, font=face)
    ImageDraw.Draw(layer).text((pad + dot_d + gap, (h - (box[3] + box[1])) / 2), text, font=face, fill=style.ink)
    return layer


def background(size, style, index, keep_out):
    w, h = size
    tint, other = style.tint(index), style.tint(index + 2)
    base = style.base(index)
    if style.dark:
        img = gradient(size, mix(base, WHITE, 0.05), mix(base, BLACK, 0.4))
    else:
        img = gradient(size, mix(base, WHITE, 0.55), mix(base, tint, 0.1))
    canvas = img.convert("RGBA")
    big = max(w, h)
    glow(canvas, (w * 0.92, h * 0.04), big * 0.42, tint, 0.34 if style.dark else 0.42)
    glow(canvas, (w * 0.04, h * 0.98), big * 0.38, other, 0.24 if style.dark else 0.3)
    DECOR[style.decor](canvas, style, random.Random(index * 7919 + w), keep_out)
    return canvas


def spots(rng, size, keep_out, count, radius, reach=1.2):
    """Each keep-out box is grown by how far a spot's drawing reaches: `reach` times its radius."""
    w, h = size
    out, tries = [], 0
    while len(out) < count and tries < count * 200:
        tries += 1
        r = rng.uniform(*radius)
        x, y = rng.uniform(-0.04 * w, 1.04 * w), rng.uniform(-0.02 * h, 1.02 * h)
        m = r * reach
        if any(x0 - m < x < x1 + m and y0 - m < y < y1 + m for x0, y0, x1, y1 in keep_out):
            continue
        if any(math.hypot(x - ox, y - oy) < (r + orr) * 1.3 for ox, oy, orr in out):
            continue
        out.append((x, y, r))
    return out


def sphere(colour, d):
    s = d * 3
    yy, xx = np.mgrid[0:s, 0:s] / s
    light = np.hypot(xx - 0.36, yy - 0.3) / 0.86
    lit = np.array(mix(colour, WHITE, 0.32), dtype=float)
    deep = np.array(mix(colour, BLACK, 0.3), dtype=float)
    t = np.clip(light, 0, 1)[..., None] ** 1.3
    body = (lit * (1 - t) + deep * t).astype(np.uint8)
    img = Image.fromarray(body, "RGB").convert("RGBA")
    img.putalpha(disc_mask(s))
    shine = Image.new("RGBA", (s, s), WHITE + (0,))
    sa = Image.new("L", (s, s), 0)
    ImageDraw.Draw(sa).ellipse([s * 0.22, s * 0.14, s * 0.48, s * 0.34], fill=170)
    shine.putalpha(sa.filter(ImageFilter.GaussianBlur(s * 0.04)))
    img.alpha_composite(shine)
    return img.resize((d, d), Image.LANCZOS)


def padded(layer, pad, colour):
    """A margin of transparent `colour`, so a blur has room to spread and does not pull in black at its
    edges."""
    out = Image.new("RGBA", (layer.width + pad * 2, layer.height + pad * 2), colour + (0,))
    out.alpha_composite(layer, (pad, pad))
    return out


def decor_spheres(canvas, style, rng, keep_out):
    w, h = canvas.size
    unit = min(w, h)
    for i, (x, y, r) in enumerate(spots(rng, canvas.size, keep_out, 9, (unit * 0.022, unit * 0.072))):
        colour = style.pieces[i % len(style.pieces)]
        pad = int(r)
        ball = padded(sphere(colour, int(r * 2)), pad, colour)
        if r > unit * 0.052:
            # The big ones sit nearer the camera, so they blur: depth without drawing a scene.
            ball = ball.filter(ImageFilter.GaussianBlur(r * 0.1))
        tone = mix(style.ink, BLACK, 0.3)
        shade = Image.new("RGBA", ball.size, tone + (0,))
        shade.putalpha(ball.split()[3].point(lambda v: v // 5))
        place(canvas, shade.filter(ImageFilter.GaussianBlur(r * 0.3)), x - r - pad, y - r - pad + r * 0.25)
        place(canvas, ball, x - r - pad, y - r - pad)


def decor_glows(canvas, style, rng, keep_out):
    w, h = canvas.size
    unit = min(w, h)
    rings = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw_ring = ImageDraw.Draw(rings)
    for i, (x, y, r) in enumerate(spots(rng, canvas.size, keep_out, 12, (unit * 0.008, unit * 0.028))):
        colour = style.pieces[i % len(style.pieces)]
        glow(canvas, (x, y), r * 4.5, colour, 0.35, power=2.2)
        core = Image.new("RGBA", (int(r * 2), int(r * 2)), mix(colour, WHITE, 0.15) + (0,))
        core.putalpha(disc_mask(int(r * 2)).point(lambda v: int(v * 0.95)))
        place(canvas, core, x - r, y - r)
        ring = r * rng.uniform(3.5, 5.5)
        if i % 3 == 0 and not any(x0 < x + ring and x - ring < x1 and y0 < y + ring and y - ring < y1
                                  for x0, y0, x1, y1 in keep_out):
            draw_ring.ellipse([x - ring, y - ring, x + ring, y + ring], outline=colour + (70,), width=2)
    canvas.alpha_composite(rings)


def decor_stars(canvas, style, rng, keep_out):
    w, h = canvas.size
    unit = min(w, h)
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for k in range(3):
        cx, cy = rng.uniform(-0.3, 1.3) * w, rng.uniform(1.0, 1.5) * h if k % 2 else -rng.uniform(0.0, 0.5) * h
        rx = rng.uniform(0.7, 1.3) * max(w, h)
        d.ellipse([cx - rx, cy - rx * 0.62, cx + rx, cy + rx * 0.62], outline=WHITE + (22,), width=2)
    for _ in range(int(w * h / 9000)):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        r = rng.choice((0.8, 1.0, 1.2, 1.6, 2.2))
        d.ellipse([x - r, y - r, x + r, y + r], fill=WHITE + (rng.randint(50, 200),))
    canvas.alpha_composite(layer)
    for i, (x, y, r) in enumerate(spots(rng, canvas.size, keep_out, 6, (unit * 0.007, unit * 0.014), reach=3.5)):
        colour = mix(style.pieces[i % len(style.pieces)], WHITE, 0.3)
        glow(canvas, (x, y), r * 5, colour, 0.4, power=2.4)
        m = r * 3
        spark = Image.new("RGBA", (int(m * 2), int(m * 2)), (0, 0, 0, 0))
        k = r * 0.32
        ImageDraw.Draw(spark).polygon([(m, 0), (m + k, m - k), (m * 2, m), (m + k, m + k), (m, m * 2),
                                       (m - k, m + k), (0, m), (m - k, m - k)], fill=colour + (230,))
        place(canvas, spark, x - m, y - m)


DECOR = {"spheres": decor_spheres, "glows": decor_glows, "stars": decor_stars}


class Placed:
    def __init__(self, x, y, scale, size):
        self.x, self.y, self.scale, self.size = x, y, scale, size

    def at(self, fx, fy):
        return self.x + fx * self.size[0] * self.scale, self.y + fy * self.size[1] * self.scale


def swipe(canvas, start, end, style, colour):
    """The shadow lets it read on a light board as well as a dark one."""
    unit = (canvas.width if canvas.width < canvas.height else canvas.height) / 1080
    s = SUPER
    (x0, y0), (x1, y1) = (start[0] * s, start[1] * s), (end[0] * s, end[1] * s)
    length = math.hypot(x1 - x0, y1 - y0)
    big = Image.new("RGBA", (canvas.width * s, canvas.height * s), colour + (0,))
    d = ImageDraw.Draw(big)
    steps = max(2, int(length / 4))
    for i in range(steps):
        t = i / (steps - 1)
        r = (5 + 17 * t) * unit * s
        x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        d.ellipse([x - r, y - r, x + r, y + r], fill=colour + (int(40 + 200 * t ** 1.5),))
    ring = 62 * unit * s
    d.ellipse([x1 - ring, y1 - ring, x1 + ring, y1 + ring], outline=colour + (120,), width=int(6 * unit * s))
    tip = 42 * unit * s
    d.ellipse([x1 - tip, y1 - tip, x1 + tip, y1 + tip], fill=WHITE + (250,), outline=colour + (255,),
              width=int(8 * unit * s))
    layer = big.resize(canvas.size, Image.LANCZOS)
    drop(canvas, layer, 0, 0, style, 0.3)


def zoom(canvas, raw, placed, spec, style, colour):
    w, h = canvas.size
    fx, fy = spec["at"]
    span = spec.get("span", 0.3) * raw.width
    cx, cy = fx * raw.width, fy * raw.height
    src = raw.crop((int(cx - span / 2), int(cy - span / 2), int(cx + span / 2), int(cy + span / 2)))
    d = int(spec.get("size", 0.42) * min(w, h) * (1.0 if w < h else 1.6))
    ring = max(6, d // 34)
    lens = Image.new("RGBA", (d, d), (0, 0, 0, 0))
    lens.paste(src.resize((d, d), Image.LANCZOS).convert("RGBA"), (0, 0), disc_mask(d))
    rim = Image.new("RGBA", (d * 2, d * 2), (0, 0, 0, 0))
    ImageDraw.Draw(rim).ellipse([0, 0, d * 2 - 1, d * 2 - 1], outline=WHITE + (255,), width=ring * 2)
    lens.alpha_composite(rim.resize((d, d), Image.LANCZOS))
    sx, sy = placed.at(fx, fy)
    sr = span / 2 * placed.scale
    tx, ty = spec["to"][0] * w, spec["to"][1] * h
    angle = math.atan2(ty - sy, tx - sx)
    line = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(line)
    ld.line([(sx + math.cos(angle) * sr, sy + math.sin(angle) * sr),
             (tx - math.cos(angle) * d / 2, ty - math.sin(angle) * d / 2)], fill=WHITE + (255,), width=ring)
    ld.ellipse([sx - sr, sy - sr, sx + sr, sy + sr], outline=WHITE + (255,), width=ring)
    drop(canvas, line, 0, 0, style, 0.35)
    drop(canvas, lens, tx - d / 2, ty - d / 2, style, 1.1)


def chevron(canvas, centre, size, style, colour):
    x, y = centre
    d = int(size)
    big = Image.new("RGBA", (d * SUPER, d * SUPER), (0, 0, 0, 0))
    bd = ImageDraw.Draw(big)
    bd.ellipse([0, 0, d * SUPER - 1, d * SUPER - 1], fill=colour + (255,))
    s = d * SUPER
    bd.line([(s * 0.3, s * 0.42), (s * 0.5, s * 0.6), (s * 0.7, s * 0.42)], fill=WHITE + (255,),
            width=int(s * 0.09), joint="curve")
    drop(canvas, big.resize((d, d), Image.LANCZOS), x - d / 2, y - d / 2, style, 0.4)


# Each takes the shot, the style, the stage box it may fill (x0, y0, x1, y1) and the canvas size, and
# returns the boxes its frames cover (so decoration keeps clear) and a painter that draws them.

def layout_screen(shot, style, stage, size, index):
    x0, y0, x1, y1 = stage
    raw = framed_raw(shot["raw"], style, shot.get("crop"))
    w, h = size
    portrait = w < h
    width = (x1 - x0) * shot.get("width", 0.84) if portrait else (h * 1.02) * raw.width / raw.height
    framed = card(raw, width, style)
    x = (x0 + x1 - framed.width) / 2
    y = y0
    placed = Placed(x, y, framed.width / raw.width, raw.size)

    def paint(canvas):
        drop(canvas, framed, x, y, style)
        if shot.get("swipe"):
            fx0, fy0, fx1, fy1 = shot["swipe"]
            swipe(canvas, placed.at(fx0, fy0), placed.at(fx1, fy1), style, style.highlight(index))
        if shot.get("zoom"):
            zoom(canvas, raw, placed, shot["zoom"], style, style.highlight(index))
    return [(x, y, x + framed.width, y + framed.height)], paint


def layout_pair(shot, style, stage, size, index):
    x0, y0, x1, y1 = stage
    first, second = (framed_raw(r, style, shot.get("crop", "auto")) for r in shot["raws"])
    gap = (y1 - y0) * 0.075
    room = (y1 - y0) - gap - (y1 - y0) * 0.03
    width = min((x1 - x0) * 0.8, room / (first.height / first.width + second.height / second.width))
    a, b = card(first, width, style), card(second, width, style)
    x = (x0 + x1 - width) / 2
    ya = y0
    yb = ya + a.height + gap
    placed = Placed(x, ya, width / first.width, first.size)

    def paint(canvas):
        drop(canvas, a, x, ya, style)
        drop(canvas, b, x, yb, style)
        chevron(canvas, ((x0 + x1) / 2, ya + a.height + gap / 2), gap * 0.86, style, style.highlight(index))
        if shot.get("swipe"):
            fx0, fy0, fx1, fy1 = shot["swipe"]
            swipe(canvas, placed.at(fx0, fy0), placed.at(fx1, fy1), style, style.highlight(index))
    return [(x, ya, x + width, ya + a.height), (x, yb, x + width, yb + b.height)], paint


def layout_grid(shot, style, stage, size, index):
    x0, y0, x1, y1 = stage
    crops = shot.get("crops") or [shot.get("crop", "auto")] * len(shot["raws"])
    frames = [framed_raw(r, style, c) for r, c in zip(shot["raws"], crops)]
    cols = 2
    rows = math.ceil(len(frames) / cols)
    face = style.face("ui", min(size) * 0.032)
    # Each label sits on its frame's bottom edge, so a row only needs room for the half that hangs below.
    label_h = face.size * 1.5
    gap = (x1 - x0) * 0.05
    cell_w = ((x1 - x0) - gap * (cols + 1)) / cols
    tall = max(f.height / f.width for f in frames)
    cell_w = min(cell_w, ((y1 - y0) - rows * label_h - gap * (rows - 1)) / rows / tall)
    grid_w = cell_w * cols + gap * (cols - 1)
    gx = (x0 + x1 - grid_w) / 2
    cards = [card(f, cell_w, style, radius=int(cell_w / 11)) for f in frames]
    row_h = cell_w * tall + label_h + gap
    gy = y0 + max(0.0, ((y1 - y0) - (row_h * rows - gap)) / 2)
    boxes, spots_ = [], []
    for i, c in enumerate(cards):
        cx = gx + (i % cols) * (cell_w + gap)
        cy = gy + (i // cols) * row_h + (cell_w * tall - c.height) / 2
        spots_.append((cx, cy))
        boxes.append((cx, cy, cx + c.width, cy + c.height + label_h))

    def paint(canvas):
        for i, (c, (cx, cy)) in enumerate(zip(cards, spots_)):
            drop(canvas, c, cx, cy, style, 0.8)
            tag = pill(shot["labels"][i], face, style, i)
            place(canvas, tag, cx + (c.width - tag.width) / 2, cy + c.height - tag.height * 0.45)
    return boxes, paint


def layout_fan(shot, style, stage, size, index):
    x0, y0, x1, y1 = stage
    w, h = size
    frames = [framed_raw(r, style, shot.get("crop")) for r in shot["raws"]]
    strip = framed_raw(shot["strip"], style, "auto") if shot.get("strip") else None
    chips = shot.get("strip_chips", [])
    face = style.face("ui", min(size) * 0.03)
    strip_h = (y1 - y0) * 0.17 if strip else (face.size * 5.2 if chips else 0)
    room_h = (y1 - y0) - strip_h - face.size * 3.4
    angle = shot.get("angle", 9)
    # A tilted side card stands taller than it is, by its width times the sine, and sits a little lower,
    # so the cards are sized for the side ones to end inside the room left above the labels.
    tall = frames[1].height / frames[1].width
    lean = math.radians(angle)
    width = min((x1 - x0) * 0.47, room_h * 0.88 / (tall * math.cos(lean) + math.sin(lean)))
    spread = (x1 - x0) * 0.3
    top = y0 + room_h * 0.03
    placed = []
    for i, f in enumerate(frames):
        side = i - 1
        layer = tilted(card(f, width, style), -side * angle)
        placed.append((layer, (x0 + x1) / 2 + side * spread - layer.width / 2, top + abs(side) * room_h * 0.06, side))
    boxes = [(lx + layer.width * 0.1, ly, lx + layer.width * 0.9, ly + layer.height) for layer, lx, ly, _ in placed]
    label_y = max(ly + layer.height for layer, _, ly, _ in placed) + face.size * 0.6
    # Each label sits under its own card, so long ones would overlap their neighbours: a smaller face if needed.
    centres = [lx + layer.width / 2 for layer, lx, _, _ in placed]
    tag_face = face
    for scale in (1.0, 0.92, 0.85, 0.78, 0.72):
        tag_face = style.face("ui", face.size * scale)
        widths = [pill(shot["labels"][i], tag_face, style, 0).width for i in range(len(placed))]
        if all((widths[i] + widths[i + 1]) / 2 + tag_face.size * 0.4 <= centres[i + 1] - centres[i]
               for i in range(len(placed) - 1)):
            break
    boxes.append((x0, label_y, x1, label_y + face.size * 2.2))
    if strip_h:
        boxes.append((x0, y1 - strip_h, x1, y1))

    def paint(canvas):
        for layer, lx, ly, side in sorted(placed, key=lambda p: -abs(p[3])):
            drop(canvas, layer, lx, ly, style, 0.9)
        for i, (layer, lx, ly, side) in enumerate(placed):
            tag = pill(shot["labels"][i], tag_face, style, i + index)
            place(canvas, tag, lx + (layer.width - tag.width) / 2, label_y)
        if strip:
            # The strip on a plate of its own background, rounded, so it reads as one more card.
            sw = min((x1 - x0) * 0.94 - 40, (strip_h * 0.9 - 24) * strip.width / strip.height)
            s = strip.resize((int(sw), int(sw * strip.height / strip.width)), Image.LANCZOS)
            plate = Image.new("RGB", (s.width + 40, s.height + 24), strip.getpixel((0, 0)))
            plate.paste(s, (20, 12))
            plated = plate.convert("RGBA")
            plated.putalpha(rounded_mask(plate.size, plate.height // 3))
            drop(canvas, plated, (x0 + x1 - plated.width) / 2, y1 - strip_h + (strip_h - plated.height) / 2, style, 0.6)
        if chips:
            # One row if a slightly smaller face fits it there, two rows otherwise.
            small = face
            for scale in (1.0, 0.92, 0.85, 0.8):
                small = style.face("ui", face.size * scale)
                if sum(pill(c, small, style, 0).width for c in chips) + small.size * 0.5 * len(chips) < (x1 - x0) * 0.96:
                    break
            row(canvas, [pill(c, small, style, i) for i, c in enumerate(chips)], (x0 + x1) / 2,
                y1 - strip_h + face.size * 1.4, (x1 - x0) * 0.96, small.size * 0.5)
    return boxes, paint


def row(canvas, pills, centre_x, y, max_width, gap):
    lines, line = [], []
    for p in pills:
        if line and sum(q.width for q in line) + gap * len(line) + p.width > max_width:
            lines.append(line)
            line = []
        line.append(p)
    lines.append(line)
    for line in lines:
        total = sum(p.width for p in line) + gap * (len(line) - 1)
        x = centre_x - total / 2
        for p in line:
            place(canvas, p, x, y)
            x += p.width + gap
        y += line[0].height + gap


def layout_pop(shot, style, stage, size, index):
    x0, y0, x1, y1 = stage
    w, h = size
    portrait = w < h
    raw = framed_raw(shot["raw"], style, shot.get("crop"))
    share = framed_raw(shot["pop"], style, shot.get("pop_crop"))
    base_w = (x1 - x0) * 0.74 if portrait else (h * 0.98) * raw.width / raw.height
    base = card(raw, base_w, style)
    bx = x0 + (x1 - x0) * 0.03
    by = y0
    # The card lifts off over the board, leaving the stars on the sheet below it in view.
    pop_w = (x1 - x0) * 0.62 if portrait else base_w * 0.95
    pop = tilted(card(share, pop_w, style, radius=int(pop_w / 22)), -shot.get("angle", 6))
    px = x1 - pop.width + (x1 - x0) * 0.02 if portrait else bx + base_w * 0.55
    py = y0 - (y1 - y0) * 0.03 if portrait else y0 + (y1 - y0) * 0.02

    def paint(canvas):
        drop(canvas, base, bx, by, style)
        drop(canvas, pop, px, py, style, 1.4)
    return [(bx, by, bx + base.width, by + base.height), (px, py, px + pop.width, py + pop.height)], paint


LAYOUTS = {"screen": layout_screen, "pair": layout_pair, "grid": layout_grid, "fan": layout_fan, "pop": layout_pop}


def screenshot(shot, index, style, size=PHONE):
    w, h = size
    words = Words(shot, style, w * 0.098, w * 0.037, w * 0.86)
    top = h * 0.055
    band = max(h * 0.245, top + words.height + h * 0.04)
    text_y = top + (band - h * 0.035 - top - words.height) / 2
    stage = (w * 0.04, band, w * 0.96, h * 0.985)
    boxes, paint = LAYOUTS[shot.get("layout", "screen")](shot, style, stage, size, index)
    canvas = background(size, style, index, boxes + [words.box(w / 2, text_y)])
    paint(canvas)
    words.draw(canvas, w / 2, text_y, style.highlight(index))
    return canvas.convert("RGB")


def tablet_screenshot(shot, index, style, size=TABLET):
    w, h = size
    left = w * 0.075
    words = Words(shot, style, h * 0.098, h * 0.036, w * 0.35, align="left")
    text_y = (h - words.height) / 2
    stage = (w * 0.45, h * 0.09, w * 0.97, h * 0.97)
    boxes, paint = LAYOUTS[shot.get("layout", "screen")](shot, style, stage, size, index)
    canvas = background(size, style, index, boxes + [words.box(left, text_y)])
    paint(canvas)
    words.draw(canvas, left, text_y, style.highlight(index))
    return canvas.convert("RGB")


def feature(spec, style, size=(1024, 500), text=True):
    w, h = size
    hero = raw_image(spec["feature"]["raw"])
    crop = spec["feature"].get("crop")
    if crop:
        hero = hero.crop(tuple(int(v) for v in crop))
    elif spec["feature"].get("autocrop", True):
        hero = autocrop(hero, style.colours["bg"])
    art_h = int(h * (0.86 if text else 0.8))
    art = hero.resize((int(hero.width * art_h / hero.height), art_h), Image.LANCZOS).convert("RGBA")
    art = Image.composite(art, Image.new("RGBA", art.size, (0, 0, 0, 0)), rounded_mask(art.size, art_h // 12))
    art = tilted(art, spec["feature"].get("tilt", -4))
    ax = int(w * 0.52) if text else (w - art.width) // 2
    ay = (h - art.height) // 2
    keep = [(ax, ay, ax + art.width, ay + art.height)]
    if text:
        keep.append((0, h * 0.2, w * 0.5, h * 0.8))
    canvas = background(size, style, spec["feature"].get("tint", 0), keep)
    drop(canvas, art, ax, ay, style, 0.8)
    if text:
        draw = ImageDraw.Draw(canvas)
        left = int(w * 0.07)
        room = ax - left - int(w * 0.04)
        size = int(h * 0.3)
        while size > 40 and draw.textlength(spec["wordmark"], font=style.face("display", size)) > room:
            size -= 4
        mark = style.face("display", size)
        tag = style.face("ui", h * 0.058)
        mark_box = draw.textbbox((0, 0), spec["wordmark"], font=mark)
        mark_h = mark_box[3] - mark_box[1]
        top = (h - mark_h) / 2 - h * 0.08
        draw.text((left, top - mark_box[1]), spec["wordmark"], font=mark, fill=style.ink)
        draw.text((left + 6, top + mark_h + h * 0.06), spec["tagline"], font=tag, fill=style.quiet)
    return canvas.convert("RGB")


def logo(spec, style, size=(600, 400)):
    w, h = size
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    face = style.face("display", h * 0.42)
    box = draw.textbbox((0, 0), spec["wordmark"], font=face)
    tw, th = box[2] - box[0], box[3] - box[1]
    ink = style.colours.get("logo", style.ink)
    draw.text(((w - tw) / 2 - box[0], (h - th) / 2 - box[1]), spec["wordmark"], font=face, fill=ink)
    return canvas


def listing(spec):
    text = spec["listing"]
    problems = [k for k, n in LIMITS.items() if len(text.get(k, "")) > n]
    lines = [
        "# Play Store listing: %s" % spec["name"],
        "",
        "Generated by kit/tools/store/compose.py from store/store.json. Limits are checked on every run.",
        "",
        "## App name (%d / %d)" % (len(text["title"]), LIMITS["title"]),
        "", text["title"], "",
        "## Short description (%d / %d)" % (len(text["short"]), LIMITS["short"]),
        "", text["short"], "",
        "## Full description (%d / %d)" % (len(text["full"]), LIMITS["full"]),
        "", text["full"], "",
        "## Release notes", "", text.get("release_notes", ""), "",
        "## Category and tags", "", text.get("category", ""), "",
    ]
    return "\n".join(lines), problems


def policy(spec):
    texts = [spec["wordmark"], spec["tagline"]]
    for shot in spec["phone"] + spec["tablet"]:
        texts += [shot["caption"].replace("*", ""), shot.get("sub", "")] + shot.get("chips", []) + shot.get("labels", [])
    return ["%r matches %s" % (t, b) for t in texts for b in BANNED if re.search(b, t, re.IGNORECASE)]


def name_of(shot, prefix):
    return (shot.get("name") or shot.get("raw") or shot["raws"][0]).replace(prefix, "")


def main():
    spec = json.load(open(SPEC))
    style = Style(spec)
    only = [a[5:].split(",") for a in sys.argv[1:] if a.startswith("only=")]
    only = only[0] if only else None
    for sub in ("screenshots/phone", "screenshots/tablet7", "screenshots/tablet10"):
        folder = os.path.join(OUT, sub)
        os.makedirs(folder, exist_ok=True)
        if not only:
            # A set that shrank must not leave its old last shots behind for the upload to pick up.
            for old in os.listdir(folder):
                if old.endswith(".png"):
                    os.remove(os.path.join(folder, old))
    for i, shot in enumerate(spec["phone"]):
        name = name_of(shot, "phone_")
        if only and name not in only:
            continue
        path = os.path.join(OUT, "screenshots/phone/%02d_%s.png" % (i + 1, name))
        screenshot(shot, i, style).save(path)
        print("wrote", path)
    for i, shot in enumerate(spec["tablet"]):
        name = name_of(shot, "tablet_")
        if only and name not in only:
            continue
        image = tablet_screenshot(shot, i, style)
        for folder in ("tablet7", "tablet10"):
            path = os.path.join(OUT, "screenshots/%s/%02d_%s.png" % (folder, i + 1, name))
            image.save(path)
            print("wrote", path)
    if only:
        return
    feature(spec, style).save(os.path.join(OUT, "feature_graphic_1024x500.png"))
    feature(spec, style, (1920, 1080), text=False).save(os.path.join(OUT, "gpg_pc_feature_1920x1080.png"))
    logo(spec, style).save(os.path.join(OUT, "gpg_pc_logo_600x400.png"))
    icon = Image.open(spec["icon"]).convert("RGBA").resize((512, 512), Image.LANCZOS)
    icon.save(os.path.join(OUT, "play_store_icon_512.png"))
    text, problems = listing(spec)
    open(os.path.join(OUT, "listing.md"), "w").write(text)
    print("wrote feature graphic, pc images, icon and listing.md")
    words = policy(spec)
    for problem in words:
        print("NOT ALLOWED IN A GRAPHIC: %s" % problem)
    if problems:
        print("OVER LIMIT: %s" % ", ".join(problems))
    if problems or words:
        sys.exit(1)


if __name__ == "__main__":
    main()
