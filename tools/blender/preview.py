"""Generate four painted part tiles and decode a UV atlas without external assets.

Uses Blender's bundled numpy. RGB previews and part paint are ordinary sRGB;
the UV atlas itself remains raw linear data. All images use our PNG writer.
"""
import argparse
import json
from pathlib import Path
import sys

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import OUTPUT, PARTS, PART_SIZE, read_png, uv_rect, write_png

LOOKS = [
    ('militia', 'KINGDOM MILITIA', ['385e99', 'e4e1ce', 'b5bdc7', 'ddb18e', '675444', '414c62', 'c8cdd5']),
    ('veteran', 'KINGDOM VETERAN', ['943c40', 'd6b15a', '9ba5b5', 'd8a480', '4e3b32', '4b3942', 'd4c28e']),
    ('undead', 'REVENANT GUARD', ['514362', 'a59cab', '737484', 'c8d6ce', '49404d', '33313e', 'a8adc0']),
    ('elite', 'REVENANT ELITE', ['296665', 'a7d9bf', '779b99', 'c5e1d6', '333f40', '2d4349', 'a7d8cc']),
]


def rgb(code):
    return np.array([int(code[i:i + 2], 16) / 255. for i in (0, 2, 4)])


def paint_tile(palette):
    """Each padded region is evaluated analytically, including its gutters."""
    primary, trim, iron, skin, leather, trousers, steel = map(rgb, palette)
    tile = np.zeros((PART_SIZE, PART_SIZE, 4), np.float32)
    tile[..., 3] = 1
    for name, (cx, cy, _) in PARTS.items():
        yy, xx = np.mgrid[0:64, 0:64]
        u = np.clip((xx - 4) / 56, 0, 1)
        v = np.clip((63 - yy - 4) / 56, 0, 1)
        x, y = 2 * u - 1, 2 * v - 1
        r = np.sqrt(x * x + y * y)
        base = {'skin': skin, 'helmet': iron, 'tunic': primary, 'cloth_trim': trim,
                'sleeves': primary, 'trousers': trousers, 'boots': leather * .65,
                'leather': leather, 'shield_face': primary, 'shield_rim': trim * .76,
                'shield_back': leather, 'metal': iron, 'blade': steel,
                'hilt': trim * .8, 'eye': rgb('1b2028'), 'belt_buckle': trim}[name]
        colour = np.broadcast_to(base, (64, 64, 3)).copy()
        if name in ('tunic', 'sleeves', 'trousers'):
            folds = .89 + .08 * np.cos(u * np.pi * 12) + .025 * np.sin(v * 12 + u * 30)
            colour *= folds[..., None]
            if name == 'tunic':
                panel = (np.abs(u - .75) < .09) & (v > .15)
                colour[panel] = trim * (.92 + .05 * np.cos(v[panel, None] * 16))
                colour[v < .09] = trim * .78
                stitch = (np.abs(u - .75) > .105) & (np.abs(u - .75) < .12) & (v > .2)
                colour[stitch & ((v * 20 % 1) < .36)] = trim * .75
        elif name in ('helmet', 'metal', 'hilt', 'belt_buckle'):
            colour *= (.76 + .20 * u + .14 * np.exp(-((u - .66) / .10) ** 2))[..., None]
            if name == 'helmet':
                colour[(v < .17) | (np.abs(u - .5) < .018)] *= .70
                rivets = (np.abs(v - .24) < .025) & (np.abs(u * 8 % 1 - .5) < .065)
                colour[rivets] = trim
        elif name == 'skin':
            colour *= (.93 + .06 * v)[..., None]
        elif name in ('leather', 'boots', 'shield_back'):
            colour *= (.86 + .10 * np.cos(v * 34) ** 6)[..., None]
            if name == 'boots':
                colour[(v > .72) & (v < .80)] = leather * .90
            if name == 'shield_back':
                colour[np.abs(x) < .14] *= .70
        elif name == 'shield_face':
            # Painted quarter field, a pale chevron and central lozenge.
            colour[(x > 0) ^ (y > 0)] = primary * .70
            emblem = (np.abs(y - (.20 - .68 * np.abs(x))) < .12) & (np.abs(x) < .66)
            diamond = np.abs(x) * 1.5 + np.abs(y - .32) < .21
            colour[emblem | diamond] = trim
            colour[(r > .85) & (r < .92)] = trim * .76
            colour[r > .94] *= .65
            grain = .95 + .035 * np.cos(x * 25)
            colour *= grain[..., None]
        elif name == 'shield_rim':
            colour *= (.76 + .20 * (y + 1) / 2)[..., None]
            theta = np.arctan2(y, x)
            rivets = (r > .88) & (r < .98) & (np.cos(theta * 12) > .90)
            colour[rivets] = iron * 1.12
        elif name == 'blade':
            colour *= (.72 + .25 * (u > .5) + .20 * np.exp(-((u - .5) / .06) ** 2))[..., None]
            colour[(u < .05) | (u > .95)] = steel * 1.09
            colour[(np.abs(u - .5) < .025) & (v < .40)] *= .84
        row = (3 - cy) * 64
        tile[row:row + 64, cx * 64:cx * 64 + 64, :3] = np.clip(colour, 0, 1)
    return np.round(tile * 255).astype(np.uint8)


def srgb_to_linear(c):
    return np.where(c <= .04045, c / 12.92, ((c + .055) / 1.055) ** 2.4)


def linear_to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= .0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - .055)


def decode(atlas, tile):
    uv = atlas[..., :2].astype(np.float32) / 255
    x, y = uv[..., 0] * (PART_SIZE - 1), (1 - uv[..., 1]) * (PART_SIZE - 1)
    x0, y0 = x.astype(int), y.astype(int)
    x1, y1 = np.minimum(x0 + 1, PART_SIZE - 1), np.minimum(y0 + 1, PART_SIZE - 1)
    dx, dy = (x - x0)[..., None], (y - y0)[..., None]
    paint = srgb_to_linear(tile[..., :3].astype(np.float32) / 255)
    colour = ((paint[y0, x0] * (1 - dx) + paint[y0, x1] * dx) * (1 - dy) +
              (paint[y1, x0] * (1 - dx) + paint[y1, x1] * dx) * dy)
    shade = atlas[..., 2:3].astype(np.float32) / 255 * 2
    rgba = np.empty_like(atlas)
    rgba[..., :3] = np.round(linear_to_srgb(colour * shade) * 255).astype(np.uint8)
    rgba[..., 3] = atlas[..., 3]
    rgba[atlas[..., 3] == 0] = 0
    return rgba


# Small bitmap labels keep the pipeline independent of system fonts and Pillow.
FONT = {
    'A':'01110 10001 10001 11111 10001 10001 10001', 'B':'11110 10001 10001 11110 10001 10001 11110',
    'C':'01111 10000 10000 10000 10000 10000 01111', 'D':'11110 10001 10001 10001 10001 10001 11110',
    'E':'11111 10000 10000 11110 10000 10000 11111', 'F':'11111 10000 10000 11110 10000 10000 10000',
    'G':'01111 10000 10000 10111 10001 10001 01111', 'H':'10001 10001 10001 11111 10001 10001 10001',
    'I':'11111 00100 00100 00100 00100 00100 11111', 'J':'00111 00010 00010 00010 10010 10010 01100',
    'K':'10001 10010 10100 11000 10100 10010 10001', 'L':'10000 10000 10000 10000 10000 10000 11111',
    'M':'10001 11011 10101 10101 10001 10001 10001', 'N':'10001 11001 10101 10011 10001 10001 10001',
    'O':'01110 10001 10001 10001 10001 10001 01110', 'P':'11110 10001 10001 11110 10000 10000 10000',
    'Q':'01110 10001 10001 10001 10101 10010 01101', 'R':'11110 10001 10001 11110 10100 10010 10001',
    'S':'01111 10000 10000 01110 00001 00001 11110', 'T':'11111 00100 00100 00100 00100 00100 00100',
    'U':'10001 10001 10001 10001 10001 10001 01110', 'V':'10001 10001 10001 10001 10001 01010 00100',
    'W':'10001 10001 10001 10101 10101 10101 01010', 'X':'10001 10001 01010 00100 01010 10001 10001',
    'Y':'10001 10001 01010 00100 00100 00100 00100', 'Z':'11111 00001 00010 00100 01000 10000 11111',
    '0':'01110 10001 10011 10101 11001 10001 01110', '1':'00100 01100 00100 00100 00100 00100 01110',
    '2':'01110 10001 00001 00010 00100 01000 11111', '3':'11110 00001 00001 01110 00001 00001 11110',
    '4':'00010 00110 01010 10010 11111 00010 00010', '5':'11111 10000 10000 11110 00001 00001 11110',
    '6':'01110 10000 10000 11110 10001 10001 01110', '7':'11111 00001 00010 00100 01000 01000 01000',
    '8':'01110 10001 10001 01110 10001 10001 01110', '9':'01110 10001 10001 01111 00001 00001 01110',
    '.':'00000 00000 00000 00000 00000 00110 00110', '-':'00000 00000 00000 11111 00000 00000 00000',
    '_':'00000 00000 00000 00000 00000 00000 11111', '/':'00001 00010 00010 00100 01000 01000 10000',
}


def label(canvas, text, x, y, scale=1, colour=(210, 218, 223)):
    for ch in text.upper():
        if ch in FONT:
            mask = np.array([[c == '1' for c in row] for row in FONT[ch].split()])
            mask = np.repeat(np.repeat(mask, scale, axis=0), scale, axis=1)
            region = canvas[y:y + 7 * scale, x:x + 5 * scale, :3]
            region[mask] = colour
        x += 6 * scale


def paste(canvas, sprite, x, y, scale=3):
    s = np.repeat(np.repeat(sprite, scale, axis=0), scale, axis=1)
    h, w = s.shape[:2]
    alpha = s[..., 3:4].astype(float) / 255
    target = canvas[y:y + h, x:x + w, :3]
    # Blend in linear space to make the partial-coverage silhouette inspectable.
    target[:] = np.round(linear_to_srgb(srgb_to_linear(s[..., :3] / 255) * alpha +
                                       srgb_to_linear(target / 255) * (1 - alpha)) * 255).astype(np.uint8)


def background(width, height):
    yy, xx = np.mgrid[0:height, 0:width]
    values = np.where((xx // 24 + yy // 24) % 2 == 0, 39, 44).astype(np.uint8)
    return np.repeat(values[..., None], 3, axis=2)


def contact_sheet(decoded, metadata, title):
    size = metadata['frame_size'][0]
    scale = 3
    cell = size * scale
    margin, row_height = 124, cell + 25
    canvas = background(margin + 10 * cell + 12, len(metadata['animations']) * row_height + 44)
    label(canvas, title + ' / UV DECODE / X3', 12, 12, 2)
    for row, (name, animation) in enumerate(metadata['animations'].items()):
        y = row * row_height + 40
        label(canvas, name, 10, y + 52, 2)
        label(canvas, f'{animation["duration"]:.3f} S', 10, y + 78)
        for local in range(animation['frame_count']):
            frame = animation['start_frame'] + local
            rect = metadata['frames'][frame]['rect']
            x0, y0, w, h = rect
            x = margin + local * cell
            paste(canvas, decoded[y0:y0 + h, x0:x0 + w], x, y, scale)
            label(canvas, f'{frame:02d}', x + 8, y + cell + 7)
            # Mark the runtime event frame below its pose.
            if frame in animation['event_frames'].values():
                label(canvas, 'EVENT', x + 37, y + cell + 7, colour=(235, 187, 94))
    return canvas


def create_previews(atlas, metadata, output):
    paints = [paint_tile(palette) for _, _, palette in LOOKS]
    parts = np.concatenate([np.concatenate(paints[:2], axis=1), np.concatenate(paints[2:], axis=1)], axis=0)
    write_png(output / 'parts_preview.png', parts)
    metadata['part_texture']['appearances'] = [dict(name=name, label=title, tile=[i % 2, i // 2],
        pixel_rect=[(i % 2) * PART_SIZE, (i // 2) * PART_SIZE, PART_SIZE, PART_SIZE])
        for i, (name, title, _) in enumerate(LOOKS)]
    decoded = []
    for paint, (name, title, _) in zip(paints, LOOKS):
        image = decode(atlas, paint)
        decoded.append(image)
        write_png(output / f'preview_{name}.png', contact_sheet(image, metadata, title))
    # Four skins, four useful poses, exact same UV atlas.
    size = metadata['frame_size'][0]
    overview = background(4 * size * 4, 4 * (size * 4 + 25) + 42)
    for i, (name, title, _) in enumerate(LOOKS):
        label(overview, title, i * size * 4 + 8, 12)
        for row, (animation, local) in enumerate([('idle', 0), ('attack', 4), ('parry', 3), ('death', 6)]):
            frame = metadata['animations'][animation]['start_frame'] + local
            x, y, w, h = metadata['frames'][frame]['rect']
            paste(overview, decoded[i][y:y + h, x:x + w], i * size * 4, 38 + row * (size * 4 + 25), 4)
            label(overview, animation, i * size * 4 + 8, 38 + row * (size * 4 + 25) + size * 4 + 7)
    write_png(output / 'preview_looks.png', overview)
    uv_preview = background(atlas.shape[1] * 3, atlas.shape[0] * 3)
    paste(uv_preview, atlas, 0, 0, 3)
    write_png(output / 'preview_uv.png', uv_preview)
    shading = atlas.copy()
    shading[..., :3] = atlas[..., 2:3]
    b_preview = background(atlas.shape[1] * 3, atlas.shape[0] * 3)
    paste(b_preview, shading, 0, 0, 3)
    write_png(output / 'preview_shading.png', b_preview)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=OUTPUT)
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    metadata = json.loads((args.output / 'swordsman_uv.json').read_text())
    atlas = read_png(args.output / 'swordsman_uv.png')
    create_previews(atlas, metadata, args.output)
    print('PREVIEWS', args.output)
