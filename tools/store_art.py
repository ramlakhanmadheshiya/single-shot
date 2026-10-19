"""Single Shot's own store art, composed from the raws tests/capture.gd renders.

It uses the kit's composer (tools/store_kit/compose.py) as a library for what is already right (caption
fitting and balancing, shadows, the swipe and zoom callouts, the pair/grid/pop layouts and Play's banned
words) and replaces the look: backgrounds, decoration, card frames, colours and the feature graphic.

Three art directions, so the owner can pick one:
  A  One line   - a single ricochet path runs across the top of the whole carousel, banking off small
                  walls, and pops a target on the last shot. Each shot wears its own chapter's colours.
  B  Indigo     - the app icon's indigo night, cream words, a coral bullseye; quiet and minimal.
  C  Geometry   - a sheet of graph paper; a protractor and the real shot angle are drawn over the room.

Run from the game folder, after capturing the raws:
  godot --fixed-fps 60 --disable-vsync --always-on-top --path . res://tests/capture.tscn -- build/store/raw --store-raw
  .venv/bin/python -I tools/store_art.py sheet                # phase 1: shots 1-3, a tablet, the feature, A/B/C
  .venv/bin/python -I tools/store_art.py full B               # every phone and tablet shot in one direction
  .venv/bin/python -I tools/store_art.py install C            # the chosen direction (C), copied into store/
  godot --headless --path . -s res://tools/render_icon.gd -- store/icon_512.png
Outputs go to build/store/<direction>/. Direction C (Geometry) is the one in use.
"""

import json
import math
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "store_kit"))
import compose as kit  # noqa: E402
from PIL import Image, ImageDraw, ImageFilter  # noqa: E402

ROOT = os.path.dirname(HERE)
RAW = os.path.join(ROOT, "build", "store", "raw")
OUT = os.path.join(ROOT, "build", "store")
kit.RAW = RAW
FONT = os.path.join(ROOT, "assets", "fonts", "Outfit-Variable.ttf")
FONTS = {"head": FONT, "head_weight": 600, "ui": FONT, "ui_weight": 500, "display": FONT, "display_weight": 300}
PHONE, TABLET, TABLET10, FEATURE = (1080, 1920), (1920, 1080), (2560, 1440), (1024, 500)
WORDMARK, TAGLINE = "Single Shot", "A quiet ricochet puzzle"

# Conversion order: the gesture, the satisfying moment, the hint, then the rest.
SHOTS = [
    {"name": "aim", "raw": "aim", "caption": "Aim with one *drag*.",
     "sub": "The dotted line shows your first two bounces", "swipe": True},
    {"name": "clear", "raw": "after", "tablet_layout": "pair", "pair": ["before", "after"], "marks": "bounce",
     "caption": "Pop them all in *one* shot.", "sub": "Bank off walls and glass to clear every target"},
    {"name": "hint", "raw": "hint", "caption": "See the *exact* path.",
     "sub": "A hint draws the shot that clears the room", "zoom": True},
    {"name": "chapters", "layout": "grid", "raws": ["grid_glass", "grid_drift", "grid_prism", "grid_shift"],
     "labels": ["Glass", "Drift", "Prism", "Shift"], "caption": "Learn one *idea* at a time.",
     "sub": "Glass, drift, prism and shift, a chapter each"},
    {"name": "drift", "raw": "drift", "marks": "bounce", "caption": "Time the *drift*.",
     "sub": "Release when the platform meets its outline"},
    {"name": "prism", "raw": "prism", "marks": "split", "caption": "Split the orb in *two*.",
     "sub": "A prism turns one shot into a pair of paths"},
    {"name": "share", "layout": "pop", "raw": "won", "caption": "Share your *clean* shot.",
     "sub": "Every clear makes a card of the path you took"},
    {"name": "title", "raw": "title", "caption": "Think at your own *pace*.",
     "sub": "A calm puzzle about one perfect angle",
     "chips": ["No timers", "Plays offline", "Daily hints"]},
]


# --- helpers ------------------------------------------------------------------

def rgb(h):
    return kit.rgb(h)


def meta(name):
    with open(os.path.join(RAW, name + ".json")) as f:
        return json.load(f)


def raw(name):
    return kit.raw_image(name)


def board_crop(name, pad=0.012):
    b = meta(name)["board"]
    return [max(0, b[0] - pad), max(0, b[1] - pad * 0.56), min(1, b[2] + pad), min(1, b[3] + pad * 0.56)]


def in_crop(p, crop):
    return [(p[0] - crop[0]) / (crop[2] - crop[0]), (p[1] - crop[1]) / (crop[3] - crop[1])]


def chapter_colours(name):
    return {k: rgb(v) for k, v in meta(name)["colours"].items()}


def style_for(bg, ink, muted, accent, star, dark=False):
    spec = {"colours": {"bg": "#%02x%02x%02x" % bg, "ink": "#%02x%02x%02x" % ink,
                        "muted": "#%02x%02x%02x" % muted, "accent": "#%02x%02x%02x" % accent},
            "fonts": FONTS, "dark": dark, "pieces": ["#%02x%02x%02x" % accent]}
    return Look(spec, star)


class Look(kit.Style):
    """The starred word takes one fixed colour per direction, pushed to read as large text."""

    def __init__(self, spec, star):
        super().__init__(spec)
        self.star = star

    def highlight(self, i=0):
        colour, t = self.star, 0.0
        while kit.contrast(colour, self.colours["bg"]) < 3.0 and t < 1.0:
            t += 0.05
            colour = kit.mix(self.star, self.ink, t)
        return colour


def first_raw(shot):
    return shot.get("raw") or shot["raws"][0]


def raw_name(shot, form, key=None):
    """phone_aim / tablet_aim; grid raws and the share card keep their own names."""
    base = key or first_raw(shot)
    if base.startswith("grid_"):
        return base
    return "%s_%s" % (form, base)


def fit_card(raw_img, box, frame, max_w=1.0):
    x0, y0, x1, y1 = box
    width = min((x1 - x0) * max_w, (y1 - y0) * raw_img.width / raw_img.height)
    return frame(raw_img, width)


def swipe_points(name):
    """A finger dragging out from the launcher along the aim, as the game reads a drag."""
    m = meta(name)
    a, b = m["aim"][0], m["aim"][1]
    s = [a[0] + (b[0] - a[0]) * 0.12, a[1] + (b[1] - a[1]) * 0.12]
    e = [a[0] + (b[0] - a[0]) * 0.42, a[1] + (b[1] - a[1]) * 0.42]
    return s, e


def zoom_spec(name, to):
    """The hint vertex with the most targets near it, so the lens shows a bounce and a pop."""
    m = meta(name)
    pts = [p for line in m["hint"] for p in line[1:-1]]
    w, h = m["size"]

    def near(p):
        return sum(1 for t in m["targets"] if math.hypot((t[0] - p[0]) * w, (t[1] - p[1]) * h) < w * 0.16)
    inner = [p for p in pts if 0.2 < p[0] < 0.8 and 0.22 < p[1] < 0.78] or pts
    best = max(inner, key=near) if inner else m["launcher"]
    return {"at": best, "span": 0.3, "to": to, "size": 0.4}


def stage_screen(canvas_size, box, shot, form, look, frame, colour):
    """One framed screen in `box`, with the swipe or the zoom drawn on it."""
    name = raw_name(shot, form)
    img = raw(name)
    card = fit_card(img, box, frame, 0.86 if form == "phone" else 1.0)
    x = (box[0] + box[2] - card.width) / 2
    y = box[1] + max(0, (box[3] - box[1] - card.height) / 2) if form == "tablet" else box[1]
    placed = kit.Placed(x, y, card.width / img.width, img.size)

    def paint(canvas):
        kit.drop(canvas, card, x, y, look)
        if shot.get("swipe"):
            s, e = swipe_points(name)
            kit.swipe(canvas, placed.at(*s), placed.at(*e), look, colour)
        if shot.get("zoom"):
            at = meta(name)["hint"] and zoom_spec(name, [0, 0])["at"]
            sx, sy = placed.at(*at)
            # The lens sits on the side of the frame away from what it magnifies.
            tx = (x + card.width * (0.27 if at[0] > 0.5 else 0.73)) / canvas.width
            ty = (y + card.height * (0.3 if at[1] > 0.45 else 0.7)) / canvas.height
            kit.zoom(canvas, img, placed, zoom_spec(name, [tx, ty]), look, colour)
    return [(x, y, x + card.width, y + card.height)], paint, placed


def stage(canvas_size, box, shot, form, look, frame, colour):
    layout = shot.get("layout", "screen")
    if layout == "screen":
        boxes, paint, _ = stage_screen(canvas_size, box, shot, form, look, frame, colour)
        return boxes, paint
    kit.card = lambda r, width, style, radius=None: frame(r, width, radius)
    spec = dict(shot)
    if layout == "pair":
        names = [raw_name(shot, form, k) for k in shot["raws"]]
        crop = board_crop(names[0])
        spec.update(raws=names, crop=crop)
        s, e = swipe_points(names[0])
        spec["swipe"] = in_crop(s, crop) + in_crop(e, crop)
    elif layout == "grid":
        spec["crops"] = [board_crop(r) for r in shot["raws"]]
    elif layout == "pop":
        spec.update(raw=raw_name(shot, form), pop=raw_name(shot, form, "won_card"))
    look.highlight = lambda i=0: colour
    return kit.LAYOUTS[layout](spec, look, box, canvas_size, 0)


def rounded(img, width, radius, outline=None, outline_w=2):
    scale = width / img.width
    screen = img.resize((int(width), int(round(img.height * scale))), Image.LANCZOS).convert("RGBA")
    out = Image.new("RGBA", screen.size, (0, 0, 0, 0))
    out.paste(screen, (0, 0), kit.rounded_mask(screen.size, radius))
    if outline:
        s = kit.SUPER
        edge = Image.new("RGBA", (screen.width * s, screen.height * s), (0, 0, 0, 0))
        ImageDraw.Draw(edge).rounded_rectangle([0, 0, edge.width - 1, edge.height - 1], radius=radius * s,
                                               outline=outline, width=outline_w * s)
        out.alpha_composite(edge.resize(screen.size, Image.LANCZOS))
    return out


def dots(draw, a, b, colour, spacing, r, start=0.0):
    length = math.hypot(b[0] - a[0], b[1] - a[1])
    s = start
    while s < length:
        t = s / length
        x, y = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
        draw.ellipse([x - r, y - r, x + r, y + r], fill=colour)
        s += spacing
    return s - length


def supersampled(size, painter):
    """Draws at 2x on a transparent layer and returns it at size, for smooth dots and arcs."""
    s = kit.SUPER
    big = Image.new("RGBA", (size[0] * s, size[1] * s), (0, 0, 0, 0))
    painter(ImageDraw.Draw(big), s)
    return big.resize(size, Image.LANCZOS)


def capsule(draw, cx, cy, length, thick, colour, s):
    draw.rounded_rectangle([(cx - length / 2) * s, (cy - thick / 2) * s, (cx + length / 2) * s, (cy + thick / 2) * s],
                           radius=thick / 2 * s, fill=colour)


def bullseye(canvas, cx, cy, r, coral=(255, 107, 91), ring=(255, 244, 238), halo=True):
    if halo:
        kit.glow(canvas, (cx, cy), r * 3.4, coral, 0.45, power=1.8)

    def paint(d, s):
        d.ellipse([(cx - r) * s, (cy - r) * s, (cx + r) * s, (cy + r) * s], fill=coral + (255,))
        rr, w = r * 0.44, r * 0.19
        d.ellipse([(cx - rr) * s, (cy - rr) * s, (cx + rr) * s, (cy + rr) * s], outline=ring + (255,), width=int(w * s))
    canvas.alpha_composite(supersampled(canvas.size, paint))


def text_block(shot, look, size, form, align="centre", width=0.86):
    w, h = size
    if form == "phone":
        return kit.Words(shot, look, w * 0.094, w * 0.036, w * width, align)
    return kit.Words(shot, look, h * 0.092, h * 0.034, w * 0.34, align)


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.convert("RGB").save(path)


# --- A: one line -------------------------------------------------------------

class OneLine:
    key, title = "A", "One line"
    ink = rgb("#2D2A4A")
    coral = rgb("#FF5D5D")
    flash = rgb("#FF8A5B")

    def colours(self, shot):
        return chapter_colours(raw_name(shot, "phone"))

    def look(self, shot):
        c = self.colours(shot)
        bg = kit.mix(c["top"], c["bottom"], 0.35)
        return style_for(bg, c["ink"], kit.mix(c["ink"], bg, 0.45), c["accent"], c["target"])

    def frame(self, img, width, radius=None):
        return rounded(img, width, radius or int(width / 16), (255, 255, 255, 200), 3)

    def background(self, size, shot):
        c = self.colours(shot)
        w, h = size
        canvas = kit.gradient(size, kit.mix(c["top"], (255, 255, 255), 0.3), c["bottom"]).convert("RGBA")
        kit.glow(canvas, (w * 0.85, h * 0.12), max(w, h) * 0.5, (255, 255, 255), 0.5)

        def grid(d, s):
            step = min(w, h) / 18
            y = step * 0.5
            while y < h:
                x = step * 0.5
                while x < w:
                    d.ellipse([(x - 1.6) * s, (y - 1.6) * s, (x + 1.6) * s, (y + 1.6) * s], fill=c["ink"] + (22,))
                    x += step
                y += step
        canvas.alpha_composite(supersampled(size, grid))
        return canvas

    def line(self, canvas, index, count, band):
        """The carousel's one shot: bounces at a third, a half and four fifths of every frame, alternating
        top and bottom walls, so where it leaves one shot is where it enters the next."""
        w, h = canvas.size
        top, bot = band
        pts = [(0.07 * w, (top + bot) / 2)]
        k = 0
        for shot in range(count):
            for fx in (0.2, 0.5, 0.8):
                pts.append((shot * w + fx * w, top if k % 2 == 0 else bot))
                k += 1
        end = ((count - 1) * w + 0.9 * w, (top + bot) / 2)
        pts.append(end)
        off = index * w
        local = [(x - off, y) for x, y in pts]
        thick, wall = h * 0.0085, w * 0.13

        def paint(d, s):
            carry = 0.0
            for i in range(len(local) - 1):
                a, b = local[i], local[i + 1]
                spacing = w * 0.024
                carry = dots(d, (a[0] * s, a[1] * s), (b[0] * s, b[1] * s), self.ink + (190,), spacing * s,
                             w * 0.0058 * s, carry * s) / s
            for i, (x, y) in enumerate(local[1:-1]):
                up = y == top
                capsule(d, x, y - thick * 1.6 if up else y + thick * 1.6, wall, thick * 2, self.ink + (255,), s)
                sign = 1 if up else -1
                for ang in (-35, 0, 35):
                    r0, r1 = h * 0.012, h * 0.026
                    dx, dy = math.sin(math.radians(ang)), math.cos(math.radians(ang)) * sign
                    d.line([((x + dx * r0) * s, (y + dy * r0) * s), ((x + dx * r1) * s, (y + dy * r1) * s)],
                           fill=self.flash + (230,), width=int(w * 0.006 * s))
            if index == 0:
                lx, ly = local[0]
                r = h * 0.019
                d.ellipse([(lx - r) * s, (ly - r) * s, (lx + r) * s, (ly + r) * s], outline=self.ink + (255,),
                          width=int(w * 0.005 * s))
                d.ellipse([(lx - r * 0.45) * s, (ly - r * 0.45) * s, (lx + r * 0.45) * s, (ly + r * 0.45) * s],
                          fill=self.ink + (255,))
        canvas.alpha_composite(supersampled(canvas.size, paint))
        if index == count - 1:
            tx, ty = local[-1]
            r = h * 0.021
            for k2, alpha in ((2.2, 70), (1.65, 120)):
                ring = supersampled(canvas.size, lambda d, s, k2=k2, alpha=alpha: d.ellipse(
                    [(tx - r * k2) * s, (ty - r * k2) * s, (tx + r * k2) * s, (ty + r * k2) * s],
                    outline=self.coral + (alpha,), width=int(w * 0.004 * s)))
                canvas.alpha_composite(ring)
            bullseye(canvas, tx, ty, r, self.coral, (255, 255, 255), halo=False)

    def phone(self, shot, index, count):
        w, h = PHONE
        look = self.look(shot)
        band = (h * 0.032, h * 0.092)
        words = text_block(shot, look, PHONE, "phone")
        text_y = h * 0.118
        box = (w * 0.05, text_y + words.height + h * 0.03, w * 0.95, h * 0.975)
        canvas = self.background(PHONE, shot)
        self.line(canvas, index, count, band)
        boxes, paint = stage(PHONE, box, shot, "phone", look, self.frame, look.highlight())
        paint(canvas)
        words.draw(canvas, w / 2, text_y, look.highlight())
        return canvas

    def tablet(self, shot, index, count):
        w, h = TABLET
        look = self.look(shot)
        canvas = self.background(TABLET, shot)
        self.line(canvas, index, count, (h * 0.045, h * 0.12))
        words = text_block(shot, look, TABLET, "tablet", "left")
        box = (w * 0.47, h * 0.17, w * 0.95, h * 0.97)
        boxes, paint = stage(TABLET, box, shot, "tablet", look, self.frame, look.highlight())
        paint(canvas)
        words.draw(canvas, w * 0.075, h * 0.17 + (h * 0.8 - words.height) / 2, look.highlight())
        return canvas

    def feature(self):
        w, h = FEATURE
        shot = {"raw": "hero_dawn"}
        c = chapter_colours("hero_dawn")
        canvas = kit.gradient(FEATURE, kit.mix(c["top"], (255, 255, 255), 0.3), c["bottom"]).convert("RGBA")
        kit.glow(canvas, (w * 0.3, h * 0.3), w * 0.5, (255, 255, 255), 0.5)
        self.line(canvas, 0, 1, (h * 0.07, h * 0.2))
        hero(canvas, "hero_dawn", self.frame, style_for(c["top"], self.ink, self.ink, c["accent"], c["target"]),
             x=w * 0.62, top=h * 0.27, height=h * 0.68, tilt=-4)
        wordmark(canvas, self.ink, kit.mix(self.ink, c["top"], 0.4), x=w * 0.07, y=h * 0.42, room=w * 0.5)
        return canvas


def hero(canvas, name, frame, look, x, top, height, tilt):
    img = raw(name).crop(tuple(int(v * s) for v, s in zip(board_crop(name, 0.0), raw(name).size * 2)))
    card = frame(img, height * img.width / img.height, int(height / 16))
    card = kit.tilted(card, tilt)
    kit.drop(canvas, card, x, top, look, 0.8)


def wordmark(canvas, ink, quiet, x, y, room, mark_size=None):
    w, h = canvas.size
    d = ImageDraw.Draw(canvas)
    size = mark_size or int(h * 0.24)
    face = kit.ImageFont.truetype(FONT, size)
    face.set_variation_by_axes([400])
    while d.textlength(WORDMARK, font=face) > room and size > 30:
        size -= 2
        face = kit.ImageFont.truetype(FONT, size)
        face.set_variation_by_axes([400])
    box = d.textbbox((0, 0), WORDMARK, font=face)
    d.text((x, y - box[1] - (box[3] - box[1])), WORDMARK, font=face, fill=ink)
    tag = kit.ImageFont.truetype(FONT, int(h * 0.062))
    tag.set_variation_by_axes([500])
    d.text((x + 4, y + h * 0.05), TAGLINE, font=tag, fill=quiet)


# --- B: indigo, the icon's night ------------------------------------------------

class Indigo:
    key, title = "B", "Indigo"
    top, mid, bottom = rgb("#3A2F7A"), rgb("#241E52"), rgb("#15122F")
    cream, coral, lav = rgb("#F4F1FF"), rgb("#FF6B5B"), rgb("#B4ACE3")

    def look(self, shot=None):
        return style_for(self.mid, self.cream, self.lav, self.coral, self.coral, dark=True)

    def frame(self, img, width, radius=None):
        return rounded(img, width, radius or int(width / 16), self.cream + (90,), 2)

    def background(self, size):
        w, h = size
        canvas = kit.gradient(size, self.top, self.bottom).convert("RGBA")
        kit.glow(canvas, (w * 0.2, -h * 0.02), max(w, h) * 0.55, (110, 96, 210), 0.35)
        kit.glow(canvas, (w * 1.0, h * 1.0), max(w, h) * 0.5, self.coral, 0.12)
        return canvas

    def mark(self, canvas, cx, cy, r):
        bullseye(canvas, cx, cy, r, self.coral, (255, 244, 238))

    def phone(self, shot, index, count):
        w, h = PHONE
        look = self.look()
        canvas = self.background(PHONE)
        self.mark(canvas, w / 2, h * 0.062, w * 0.026)
        words = text_block(shot, look, PHONE, "phone")
        text_y = h * 0.1
        box = (w * 0.05, text_y + words.height + h * 0.03, w * 0.95, h * 0.975)
        boxes, paint = stage(PHONE, box, shot, "phone", look, self.frame, self.coral)
        paint(canvas)
        words.draw(canvas, w / 2, text_y, self.coral)
        return canvas

    def tablet(self, shot, index, count):
        w, h = TABLET
        look = self.look()
        canvas = self.background(TABLET)
        words = text_block(shot, look, TABLET, "tablet", "left")
        ty = (h - words.height) / 2 + h * 0.03
        self.mark(canvas, w * 0.075 + h * 0.026, ty - h * 0.07, h * 0.026)
        box = (w * 0.47, h * 0.06, w * 0.95, h * 0.95)
        boxes, paint = stage(TABLET, box, shot, "tablet", look, self.frame, self.coral)
        paint(canvas)
        words.draw(canvas, w * 0.075, ty, self.coral)
        return canvas

    def feature(self):
        w, h = FEATURE
        canvas = self.background(FEATURE)
        hero(canvas, "hero_prism", self.frame, self.look(), x=w * 0.6, top=h * 0.08, height=h * 0.9, tilt=-4)
        self.mark(canvas, w * 0.07 + h * 0.05, h * 0.2, h * 0.05)
        wordmark(canvas, self.cream, self.lav, x=w * 0.07, y=h * 0.56, room=w * 0.5)
        return canvas


# --- C: geometry, graph paper and the real angle --------------------------------

class CropPlaced:
    """Maps raw-frame fractions onto a card made from a crop of that frame."""

    def __init__(self, x, y, card, crop):
        self.x, self.y, self.w, self.h, self.crop = x, y, card.width, card.height, crop

    def at(self, fx, fy):
        c = self.crop
        return (self.x + (fx - c[0]) / (c[2] - c[0]) * self.w, self.y + (fy - c[1]) / (c[3] - c[1]) * self.h)


def interior_vertex(line):
    """The bounce farthest from the room's edges, where an angle mark reads best."""
    best, score = None, -1.0
    for k in range(1, len(line) - 1):
        x, y = line[k]
        s = min(x, 1 - x, y, 1 - y)
        if s > score:
            best, score = k, s
    return best


class Geometry:
    key, title = "C", "Geometry"
    paper, ink, coral, blue = rgb("#F8F5EE"), rgb("#2B2E4A"), rgb("#E4553F"), rgb("#4C6FA8")

    def look(self, shot=None):
        return style_for(self.paper, self.ink, kit.mix(self.ink, self.paper, 0.35), self.coral, self.coral)

    def frame(self, img, width, radius=None):
        return rounded(img, width, radius or int(width / 34), self.ink + (255,), max(2, int(width / 300)))

    def background(self, size):
        w, h = size

        def grid(d, s):
            step = min(w, h) / 30
            for horizontal in (False, True):
                i, v = 0, 0.0
                while v < (h if horizontal else w):
                    a = 60 if i % 5 == 0 else 26
                    if horizontal:
                        d.line([(0, v * s), (w * s, v * s)], fill=self.blue + (a,), width=s)
                    else:
                        d.line([(v * s, 0), (v * s, h * s)], fill=self.blue + (a,), width=s)
                    v += step
                    i += 1
        canvas = Image.new("RGBA", size, self.paper + (255,))
        canvas.alpha_composite(supersampled(size, grid))
        return canvas

    def label(self, canvas, text, x, y, unit):
        face = kit.ImageFont.truetype(FONT, int(unit * 0.034))
        face.set_variation_by_axes([600])
        pill = kit.pill(text, face, self.look(), 0, dot=False)
        kit.drop(canvas, pill, x - pill.width / 2, y - pill.height / 2, self.look(), 0.25)

    def protractor(self, canvas, centre, radius, angle_deg, label=True):
        """A half protractor on the launcher, with the shot's real angle in coral."""
        cx, cy = centre
        unit = min(canvas.size)

        def paint(d, s):
            r = radius
            d.pieslice([(cx - r) * s, (cy - r) * s, (cx + r) * s, (cy + r) * s], 180, 360,
                       fill=(255, 255, 255, 120), outline=self.ink + (200,), width=int(unit * 0.003 * s))
            for deg in range(0, 181, 5):
                a = math.radians(180 + deg)
                long_ = deg % 30 == 0
                r0 = r * (0.86 if long_ else 0.92)
                d.line([((cx + math.cos(a) * r0) * s, (cy + math.sin(a) * r0) * s),
                        ((cx + math.cos(a) * r) * s, (cy + math.sin(a) * r) * s)],
                       fill=self.ink + (200 if long_ else 120,), width=int(unit * (0.0026 if long_ else 0.0016) * s))
            a0 = 180 if angle_deg < -90 else 360
            lo, hi = sorted((a0, 360 + angle_deg))
            rr = r * 0.55
            d.pieslice([(cx - rr) * s, (cy - rr) * s, (cx + rr) * s, (cy + rr) * s], lo, hi,
                       fill=self.coral + (70,), outline=self.coral + (255,), width=int(unit * 0.003 * s))
            a = math.radians(angle_deg)
            d.line([(cx * s, cy * s), ((cx + math.cos(a) * r * 1.02) * s, (cy + math.sin(a) * r * 1.02) * s)],
                   fill=self.coral + (255,), width=int(unit * 0.004 * s))
        canvas.alpha_composite(supersampled(canvas.size, paint))
        if label:
            text = "%.1f°" % abs(angle_deg if angle_deg > -90 else 180 + angle_deg)
            a0 = -180 if angle_deg < -90 else 0
            bis = math.radians((a0 + angle_deg) / 2)
            self.label(canvas, text, cx + math.cos(bis) * radius * 0.72, cy + math.sin(bis) * radius * 0.72, unit)

    def angle_mark(self, canvas, centre, legs, unit, text=None, reach=1.0):
        """Two legs out of one point and the arc between them: angle in, angle out, or a split."""
        b = centre
        angs = [math.degrees(math.atan2(q[1] - b[1], q[0] - b[0])) for q in legs]

        def paint(d, s):
            for ang in angs:
                a = math.radians(ang)
                r = unit * 0.09 * reach
                d.line([(b[0] * s, b[1] * s), ((b[0] + math.cos(a) * r) * s, (b[1] + math.sin(a) * r) * s)],
                       fill=self.coral + (255,), width=int(unit * 0.004 * s))
            lo, hi = sorted(angs)
            if hi - lo > 180:
                lo, hi = hi, lo + 360
            r = unit * 0.05 * reach
            d.arc([(b[0] - r) * s, (b[1] - r) * s, (b[0] + r) * s, (b[1] + r) * s], lo, hi,
                  fill=self.coral + (255,), width=int(unit * 0.004 * s))
            k = unit * 0.009
            d.ellipse([(b[0] - k) * s, (b[1] - k) * s, (b[0] + k) * s, (b[1] + k) * s], fill=self.coral + (255,))
        canvas.alpha_composite(supersampled(canvas.size, paint))
        if text:
            lo, hi = sorted(angs)
            mid = math.radians((lo + hi) / 2 + (180 if hi - lo > 180 else 0))
            self.label(canvas, text, b[0] + math.cos(mid) * unit * 0.1 * reach, b[1] + math.sin(mid) * unit * 0.1 * reach, unit)

    def bounce_marks(self, canvas, placed, name, unit):
        m = meta(name)
        line = (m.get("hint") or m["solution"])[0]
        if len(line) < 3:
            return
        k = interior_vertex(line)
        pts = [placed.at(*line[i]) for i in (k - 1, k, k + 1)]
        self.angle_mark(canvas, pts[1], [pts[0], pts[2]], unit)

    def split_marks(self, canvas, placed, name, unit):
        sol = meta(name)["solution"]
        if len(sol) < 3:
            return
        at = placed.at(*sol[1][0])
        self.angle_mark(canvas, at, [placed.at(*sol[1][1]), placed.at(*sol[2][1])], unit, "64°", 1.15)

    def tape(self, canvas, box, unit):
        x0, y0, x1, _ = box
        for fx, angle in ((0.14, -8), (0.86, 7)):
            strip = Image.new("RGBA", (int(unit * 0.13), int(unit * 0.035)), (255, 236, 196, 170))
            strip = kit.tilted(strip, angle)
            kit.place(canvas, strip, x0 + (x1 - x0) * fx - strip.width / 2, y0 + unit * 0.004 - strip.height / 2)

    def annotate(self, canvas, shot, form, placed, unit, card_w):
        name = raw_name(shot, form)
        m = meta(name)
        if shot.get("swipe") and "aim" in m:
            l = placed.at(*m["launcher"])
            p0, p1 = placed.at(*m["aim"][0]), placed.at(*m["aim"][1])
            self.protractor(canvas, l, card_w * 0.16, math.degrees(math.atan2(p1[1] - p0[1], p1[0] - p0[0])))
        elif shot.get("marks") == "split":
            self.split_marks(canvas, placed, name, unit)
        elif shot.get("marks") == "bounce":
            self.bounce_marks(canvas, placed, name, unit)

    # Layouts. Each returns the boxes it covered, after painting.

    def screen(self, canvas, box, shot, form, words_box=None):
        unit = min(canvas.size)
        name = raw_name(shot, form)
        img = raw(name)
        card = fit_card(img, box, self.frame, 0.86 if form == "phone" else 1.0)
        x = (box[0] + box[2] - card.width) / 2
        if form == "tablet" and shot.get("zoom"):
            x = box[2] - card.width
        y = box[1] if form == "phone" else box[1] + (box[3] - box[1] - card.height) / 2
        placed = kit.Placed(x, y, card.width / img.width, img.size)
        kit.drop(canvas, card, x, y, self.look())
        self.tape(canvas, (x, y, x + card.width, y + card.height), unit)
        if shot.get("swipe"):
            s, e = swipe_points(name)
            kit.swipe(canvas, placed.at(*s), placed.at(*e), self.look(), self.coral)
        if shot.get("zoom"):
            at = zoom_spec(name, [0, 0])["at"]
            if form == "phone":
                tx = (x + card.width * (0.27 if at[0] > 0.5 else 0.73)) / canvas.width
                ty = (y + card.height * (0.3 if at[1] > 0.45 else 0.7)) / canvas.height
                spec = zoom_spec(name, [tx, ty])
            else:
                # On a tablet the lens sits on the paper, between the words and the screen.
                tx = (box[0] + x) / 2 / canvas.width
                spec = zoom_spec(name, [tx, 0.55])
                spec["size"] = 0.3
            kit.zoom(canvas, img, placed, spec, self.look(), self.coral)
        self.annotate(canvas, shot, form, placed, unit, card.width)
        return [(x, y, x + card.width, y + card.height)]

    def pair(self, canvas, box, shot, form):
        """Before and after side by side on a tablet, stacked on a phone."""
        unit = min(canvas.size)
        names = [raw_name(shot, form, k) for k in shot["pair"]]
        crop = board_crop(names[0])
        imgs = [raw(n) for n in names]
        imgs = [i.crop((int(crop[0] * i.width), int(crop[1] * i.height), int(crop[2] * i.width), int(crop[3] * i.height)))
                for i in imgs]
        bw, bh = box[2] - box[0], box[3] - box[1]
        ratio = imgs[0].height / imgs[0].width
        gap = unit * 0.1
        width = min((bw - gap) / 2, bh / ratio)
        cards = [self.frame(i, width) for i in imgs]
        total = width * 2 + gap
        x0 = box[0] + (bw - total) / 2
        y = box[1] + (bh - cards[0].height) / 2
        spots = [(x0, y), (x0 + width + gap, y)]
        for c, (x, yy) in zip(cards, spots):
            kit.drop(canvas, c, x, yy, self.look())
            self.tape(canvas, (x, yy, x + c.width, yy + c.height), unit)
        # The arrow between them, drawn as a ruled line with a head.
        ax0, ax1, ay = x0 + width + gap * 0.22, x0 + width + gap * 0.78, y + cards[0].height / 2

        def arrow(d, s):
            wd = int(unit * 0.006 * s)
            d.line([(ax0 * s, ay * s), (ax1 * s, ay * s)], fill=self.coral + (255,), width=wd)
            k = gap * 0.18
            d.line([((ax1 - k) * s, (ay - k) * s), (ax1 * s, ay * s), ((ax1 - k) * s, (ay + k) * s)],
                   fill=self.coral + (255,), width=wd, joint="curve")
        canvas.alpha_composite(supersampled(canvas.size, arrow))
        before = CropPlaced(spots[0][0], spots[0][1], cards[0], crop)
        after = CropPlaced(spots[1][0], spots[1][1], cards[1], crop)
        s, e = swipe_points(names[0])
        kit.swipe(canvas, before.at(*s), before.at(*e), self.look(), self.coral)
        self.bounce_marks(canvas, after, names[1], unit)
        return [(x, yy, x + c.width, yy + c.height) for c, (x, yy) in zip(cards, spots)]

    def grid(self, canvas, box, shot, form):
        unit = min(canvas.size)
        frames = []
        for r in shot["raws"]:
            img = raw(r)
            c = board_crop(r)
            frames.append(img.crop((int(c[0] * img.width), int(c[1] * img.height), int(c[2] * img.width), int(c[3] * img.height))))
        ratio = frames[0].height / frames[0].width
        face = kit.ImageFont.truetype(FONT, int(unit * 0.034))
        face.set_variation_by_axes([600])
        bw, bh = box[2] - box[0], box[3] - box[1]
        boxes = []
        if form == "phone":
            gap = bw * 0.06
            label_h = face.size * 1.6
            width = min((bw - gap) / 2, (bh - gap - label_h * 2) / 2 / ratio)
            gx = box[0] + (bw - width * 2 - gap) / 2
            spots = [(gx + (i % 2) * (width + gap), box[1] + (i // 2) * (width * ratio + label_h + gap)) for i in range(4)]
        else:
            # A row that zigzags like a bank shot, using the landscape width.
            # Overlapping a little, like prints pinned on the sheet.
            gap = -bw * 0.045
            rise = bh * 0.2
            width = min((bw - gap * 3) / 4, (bh - rise - face.size * 2) / ratio)
            gx = box[0] + (bw - width * 4 - gap * 3) / 2
            top = box[1] + (bh - width * ratio - rise - face.size * 2) / 2
            spots = [(gx + i * (width + gap), top + (rise if i % 2 else 0)) for i in range(4)]
        tilts = [0, 0, 0, 0] if form == "phone" else [-3, 2.5, -2, 3]
        for i, (f, (x, y)) in enumerate(zip(frames, spots)):
            c = kit.tilted(self.frame(f, width), tilts[i])
            kit.drop(canvas, c, x, y, self.look(), 0.8)
            self.tape(canvas, (x, y, x + c.width, y + c.height), unit * 0.7)
            tag = kit.pill(shot["labels"][i], face, self.look(), 0)
            kit.place(canvas, tag, x + (c.width - tag.width) / 2, y + c.height - tag.height * 0.4)
            boxes.append((x, y, x + c.width, y + c.height))
        return boxes

    def pop(self, canvas, box, shot, form):
        """The won screen, and the share card it made lifted off it, tilted and taped."""
        unit = min(canvas.size)
        base_img = raw(raw_name(shot, form))
        card_img = raw(raw_name(shot, form, "won_card"))
        bw, bh = box[2] - box[0], box[3] - box[1]
        if form == "phone":
            base = fit_card(base_img, (box[0], box[1], box[0] + bw * 0.78, box[3]), self.frame)
            bx, by = box[0] + bw * 0.02, box[1]
            pw = bw * 0.47
            pop = kit.tilted(self.frame(card_img, pw, int(pw / 26)), -6)
            px, py = box[2] - pop.width, box[3] - pop.height - bh * 0.005
        else:
            base = fit_card(base_img, box, self.frame)
            bx, by = box[2] - base.width, box[1] + (bh - base.height) / 2
            pw = bw * 0.46
            pop = kit.tilted(self.frame(card_img, pw, int(pw / 26)), 6)
            px, py = bx - pw * 0.72, box[1] + bh * 0.16
        kit.drop(canvas, base, bx, by, self.look())
        self.tape(canvas, (bx, by, bx + base.width, by + base.height), unit)
        kit.drop(canvas, pop, px, py, self.look(), 1.4)
        return [(bx, by, bx + base.width, by + base.height), (px, py, px + pop.width, py + pop.height)]

    def compose(self, size, shot, form):
        w, h = size
        look = self.look()
        canvas = self.background(size)
        layout = shot.get("tablet_layout" if form == "tablet" else "layout", shot.get("layout", "screen"))
        wide = layout in ("pair", "grid", "pop") or bool(shot.get("zoom"))
        if form == "phone":
            words = text_block(shot, look, size, form, "left", 0.84)
        else:
            words = kit.Words(shot, look, h * 0.092, h * 0.034, w * (0.25 if wide else 0.34), "left")
        if form == "phone":
            tx, ty = w * 0.08, h * 0.06
            box = (w * 0.05, ty + words.height + h * 0.035, w * 0.95, h * 0.975)
        else:
            tx, ty = w * 0.07, (h - words.height) / 2
            box = (w * (0.36 if wide else 0.47), h * 0.07, w * 0.96, h * 0.95)
        getattr(self, layout)(canvas, box, shot, form)
        words.draw(canvas, tx, ty, self.coral)
        return canvas

    def phone(self, shot, index, count, size=PHONE):
        return self.compose(size, shot, "phone")

    def tablet(self, shot, index, count, size=TABLET):
        return self.compose(size, shot, "tablet")

    def feature(self):
        w, h = FEATURE
        canvas = self.background(FEATURE)
        name = "hero_dawn"
        full = raw(name)
        crop = board_crop(name, 0.0)
        img = full.crop((int(crop[0] * full.width), int(crop[1] * full.height), int(crop[2] * full.width), int(crop[3] * full.height)))
        height = h * 0.84
        card = self.frame(img, height * img.width / img.height, int(height / 34))
        x, y = w * 0.62, h * 0.08
        kit.drop(canvas, card, x, y, self.look(), 0.6)
        self.tape(canvas, (x, y, x + card.width, y + card.height), min(w, h) * 1.6)
        placed = CropPlaced(x, y, card, crop)
        m = meta(name)
        sol = m["solution"][0]
        l, p1 = placed.at(*m["launcher"]), placed.at(*sol[1])
        self.protractor(canvas, l, card.width * 0.3, math.degrees(math.atan2(p1[1] - l[1], p1[0] - l[0])), label=False)
        wordmark(canvas, self.ink, kit.mix(self.ink, self.paper, 0.4), x=w * 0.07, y=h * 0.52, room=w * 0.5)
        return canvas


DIRECTIONS = {"A": OneLine(), "B": Indigo(), "C": Geometry()}


# --- outputs -------------------------------------------------------------------

def check_words(shots):
    texts = [WORDMARK, TAGLINE]
    for s in shots:
        texts += [s["caption"].replace("*", ""), s.get("sub", "")] + s.get("chips", []) + s.get("labels", [])
        head = s["caption"].replace("*", "")
        if len(head) > 28 or len(s.get("sub", "")) > 55:
            raise SystemExit("caption too long: %r / %r" % (head, s.get("sub")))
    bad = ["%r matches %s" % (t, b) for t in texts for b in kit.BANNED if kit.re.search(b, t, kit.re.IGNORECASE)]
    if bad:
        raise SystemExit("NOT ALLOWED IN A GRAPHIC: " + "; ".join(bad))


def render(key, shots, tablets):
    d = DIRECTIONS[key]
    folder = os.path.join(OUT, key)
    out = {"phone": [], "tablet": []}
    for i, shot in enumerate(shots):
        path = os.path.join(folder, "phone", "%02d_%s.png" % (i + 1, shot["name"]))
        save(d.phone(shot, i, len(shots)), path)
        out["phone"].append(path)
    for i, shot in enumerate(tablets):
        for sub, size in (("tablet7", TABLET), ("tablet10", TABLET10)):
            img = d.tablet(shot, i, len(tablets), size) if key == "C" else d.tablet(shot, i, len(tablets))
            path = os.path.join(folder, sub, "%02d_%s.png" % (i + 1, shot["name"]))
            save(img, path)
            out.setdefault(sub, []).append(path)
        out["tablet"].append(out["tablet7"][-1])
    path = os.path.join(folder, "feature_graphic_1024x500.png")
    save(d.feature(), path)
    out["feature"] = path
    for p in out["phone"] + out["tablet"] + [path]:
        im = Image.open(p)
        assert im.mode == "RGB", p
    print("wrote", folder)
    return out


def sheet(results, path):
    pw, ph = 360, 640
    gap, pad, label_w = 14, 40, 120
    tw = 640
    th = int(tw * 1080 / 1920)
    fh = ph - th - gap
    fw = int(fh * 1024 / 500)
    row_w = label_w + 3 * pw + 2 * 6 + pad + max(tw, fw)
    W = pad * 2 + row_w
    H = pad * 2 + len(results) * (ph + 80) - 40
    s = Image.new("RGB", (W, H), (236, 234, 230))
    d = ImageDraw.Draw(s)
    big = kit.ImageFont.truetype(FONT, 64)
    big.set_variation_by_axes([600])
    small = kit.ImageFont.truetype(FONT, 22)
    small.set_variation_by_axes([500])
    y = pad
    for key, res in results.items():
        d.text((pad, y), key, font=big, fill=(40, 40, 60))
        d.text((pad, y + 76), DIRECTIONS[key].title, font=small, fill=(90, 90, 110))
        x = pad + label_w
        for p in res["phone"][:3]:
            s.paste(Image.open(p).resize((pw, ph), Image.LANCZOS), (x, y))
            x += pw + 6
        x += pad - 6
        s.paste(Image.open(res["tablet"][0]).resize((tw, th), Image.LANCZOS), (x, y))
        s.paste(Image.open(res["feature"]).resize((fw, fh), Image.LANCZOS), (x, y + th + gap))
        y += ph + 80
    s.save(path)
    print("wrote", path)


def main():
    args = sys.argv[1:]
    mode = args[0] if args else "sheet"
    keys = [a for a in args[1:] if a in DIRECTIONS] or list(DIRECTIONS)
    if mode == "sheet":
        shots = SHOTS[:3]
        check_words(shots)
        results = {k: render(k, shots, shots[:1]) for k in keys}
        default = os.path.join(OUT, "store-directions.png")
        target = next((a[6:] for a in args if a.startswith("sheet=")), default)
        sheet(results, target)
    elif mode == "full":
        check_words(SHOTS)
        for k in keys:
            render(k, SHOTS, SHOTS)
    elif mode == "install":
        # The chosen direction, rendered in full and copied over the game's store graphics.
        key = keys[0] if args[1:] else "C"
        check_words(SHOTS)
        render(key, SHOTS, SHOTS)
        store = os.path.join(ROOT, "store")
        for sub in ("", "tablet7", "tablet10"):
            folder = os.path.join(store, "screenshots", sub)
            os.makedirs(folder, exist_ok=True)
            for old in os.listdir(folder):
                if old.endswith(".png"):
                    os.remove(os.path.join(folder, old))
            src = os.path.join(OUT, key, sub or "phone")
            for f in sorted(os.listdir(src)):
                shutil.copy(os.path.join(src, f), os.path.join(folder, f))
        shutil.copy(os.path.join(OUT, key, "feature_graphic_1024x500.png"), os.path.join(store, "feature_graphic.png"))
        print("installed direction %s into store/" % key)
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
