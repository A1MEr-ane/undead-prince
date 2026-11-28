"""Paint UV regions and bake the fixed-camera ink treatment into RGBA artwork."""
import numpy as np

from common import PARTS, PART_SIZE, PADDING, write_png
from preview import decode, label, paste
from unit_spec import REACTIONS

INK = (17, 22, 34)
PAGE = (27, 37, 43)
TERRAIN = (62, 77, 72)
MUTED = (151, 168, 166)
EVENT = (230, 179, 102)


def rgb(colour):
    return tuple(bytes.fromhex(colour[1:]))


def paint_tile(spec):
    tile = np.zeros((PART_SIZE, PART_SIZE, 4), np.uint8)
    for part, colour in spec['palette'].items():
        x, y, _ = PARTS[part]
        y = 3 - y
        area = tile[y * 64:(y + 1) * 64, x * 64:(x + 1) * 64]
        area[:] = (*rgb(colour), 255)
        if part == spec['parts']['head']:
            paint_marks(area[..., :3], spec.get('head', {}).get('stamps', []), head=True)
        else:
            paint_marks(area[..., :3], spec.get('marks', {}).get(part, []))
    return tile


def paint_marks(area, stamps, *, head=False):
    if not stamps:
        return
    # Evaluate flat motifs at 4x so their texture edges do not staircase.
    yy, xx = np.mgrid[:256, :256] / 4 + .125
    span = 64 - 2 * PADDING
    u = np.clip((xx - PADDING) / span, 0, 1)
    v = np.clip((64 - yy - PADDING) / span, 0, 1)
    if head:
        v = (v - .30) / .70
    paint = np.broadcast_to(area[0, 0], (256, 256, 3)).copy()
    for stamp in stamps:
        if stamp['shape'] == 'ellipse':
            a, b = stamp['at']
            rx, ry = stamp['radii']
            inside = ((u - a) / rx) ** 2 + ((v - b) / ry) ** 2 <= 1
        else:
            inside = np.zeros(u.shape, bool)
            points = stamp['points']
            for (a, b), (c, d) in zip(points, points[1:] + points[:1]):
                if b != d:
                    inside ^= ((b > v) != (d > v)) & (u < (c - a) * (v - b) / (d - b) + a)
        paint[inside & (v >= 0)] = rgb(stamp['color'])
    area[:] = np.round(paint.reshape(64, 4, 64, 4, 3).mean(axis=(1, 3))).astype(np.uint8)


def art_frame(raw, tile, rim, width):
    """The RGBA export uses the same frame rectangles as the independent UV data."""
    two_tone = raw.copy()
    two_tone[..., 2] = np.where(raw[..., 2] >= 140, 136, 77)
    out = decode(two_tone, tile)
    a = raw[..., 3]
    padded = np.pad(a, width)
    size = a.shape[0]
    extended = np.maximum.reduce([
        padded[width+y:width+y+size, width+x:width+x+size]
        for y in range(-width, width + 1) for x in range(-width, width + 1)
        if x*x + y*y <= width*width
    ])
    near = padded[:size, width:width+size]
    light = (a >= 155) & (near < 125) & (two_tone[..., 2] == 136)
    out[light, :3] = np.round(out[light, :3] * .27 + np.asarray(rim) * .73).astype(np.uint8)
    # The ink is composited under coverage to preserve a soft antialiased edge.
    fill = a.astype(np.float32) / 255
    total = extended.astype(np.float32) / 255
    mix = np.divide(fill, total, out=np.zeros_like(fill), where=total > 0)[..., None]
    out[..., :3] = np.round(out[..., :3] * mix + np.asarray(INK) * (1 - mix)).astype(np.uint8)
    out[..., 3] = extended
    out[extended == 0] = 0
    return out


def frames_from_atlas(atlas, meta):
    return [atlas[y:y + h, x:x + w] for x, y, w, h in (f['rect'] for f in meta['frames'])]


def ink_atlas(atlas, meta, tile, rim):
    ink = np.zeros_like(atlas)
    width = max(1, round(1.45 / preview_scale(meta)))
    for x, y, w, h in (f['rect'] for f in meta['frames']):
        ink[y:y + h, x:x + w] = art_frame(atlas[y:y + h, x:x + w], tile, rim, width)
    return ink


def preview_scale(meta):
    sizing = meta['presentation']
    return sizing['review_pixels_per_model_unit'] / sizing['pixels_per_model_unit']


def resample(sprite, side):
    """Resize straight-alpha artwork with premultiplied bilinear sampling."""
    src = sprite.astype(np.float32) / 255
    src[..., :3] *= src[..., 3:4]
    coords = np.clip((np.arange(side) + .5) * len(src) / side - .5, 0, len(src) - 1)
    lo = coords.astype(int)
    hi = np.minimum(lo + 1, len(src) - 1)
    amount = (coords - lo)[None, :, None]
    horiz = src[:, lo] * (1 - amount) + src[:, hi] * amount
    vert = horiz[lo] * (1 - amount.transpose(1, 0, 2)) + horiz[hi] * amount.transpose(1, 0, 2)
    a = vert[..., 3:4]
    vert[..., :3] = np.divide(vert[..., :3], a, out=np.zeros_like(vert[..., :3]), where=a > 0)
    return np.round(np.clip(vert, 0, 1) * 255).astype(np.uint8)


def draw_sheet(output, meta, frames, names, title):
    size = len(frames[0])
    anchor = round(size * meta['coordinates']['standing_foot_anchor_pixels'][1] / meta['frame_size'][1])
    margin, stride = 146, size + 23
    max_frames = max(meta['animations'][name]['frame_count'] for name in names)
    board = np.full((52 + len(names) * stride, margin + max_frames * (size + 4) + 12, 3), PAGE, np.uint8)
    label(board, title, 12, 13, 2)
    label(board, '1080P SCALE / GOLD = EVENT', 12, 33, colour=MUTED)
    for row, name in enumerate(names):
        action = meta['animations'][name]
        first = action['start_frame']
        y = 48 + row * stride
        label(board, name, 12, y + size // 2 - 7)
        label(board, f'{action["duration"]:.3f} S', 12, y + size // 2 + 6, colour=MUTED)
        for local in range(action['frame_count']):
            i = first + local
            x = margin + local * (size + 4)
            board[y:y + size, x:x + size] = TERRAIN
            board[y + anchor, x:x + size] = (80, 97, 88)
            paste(board, frames[i], x, y, 1)
            label(board, f'{local:02d}', x + 4, y + size + 5,
                  colour=EVENT if i in action['event_frames'].values() else MUTED)
    write_png(output, board)


def draw_overview(output, meta, frames, ident):
    animations = meta['animations']
    poses = [('IDLE', 0), ('STEP', animations['walk']['start_frame'] + 1)]
    attack = animations['attack']
    start, span = attack['start_frame'], attack['frame_count'] - 1
    poses += [('WIND UP', start + round(span * .28)),
              ('CONTACT', attack['event_frames'].get('hit', start + round(span * .5))),
              ('RECOVER', start + round(span * .74))]
    for name in animations:
        if name not in {'idle', 'walk', 'attack', 'parry', 'clash', 'hit', 'death', *REACTIONS}:
            action = animations[name]
            poses.append((name, action['event_frames'].get('hit', action['start_frame'] + action['frame_count'] // 2)))
    poses.append(('FLIP', 0))
    size = len(frames[0])
    span = size + 10
    cols = min(len(poses), max(1, 1420 // span))
    rows = (len(poses) + cols - 1) // cols
    board = np.full((53 + rows * (size + 25), 20 + cols * span, 3), PAGE, np.uint8)
    label(board, f'{ident} / 1080P SCALE', 14, 12, 2)
    label(board, '72 PX INFANTRY BASELINE / SAME CAMERA FOR ALL UNITS', 14, 33, colour=MUTED)
    for col, (name, index) in enumerate(poses):
        x, y = 12 + col % cols * span, 50 + col // cols * (size + 25)
        board[y:y + size, x:x + size] = TERRAIN
        sprite = frames[index]
        paste(board, sprite[:, ::-1] if name == 'FLIP' else sprite, x, y, 1)
        label(board, name, x + 3, y + size + 7)
    write_png(output, board)


def create_previews(atlas, meta, output, spec):
    ident = spec['id']
    tile = paint_tile(spec)
    ink = ink_atlas(atlas, meta, tile, rgb(spec['rim']))
    parts = np.tile(tile, (2, 2, 1))
    texture = meta['part_texture']
    texture['image'] = f'{ident}_parts.png'
    texture['appearances'] = [dict(name=ident, cell=[0, 0])]
    write_png(output / texture['image'], parts)
    write_png(output / f'{ident}_ink.png', ink)

    size = round(meta['frame_size'][0] * preview_scale(meta))
    frames = [resample(frame, size) for frame in frames_from_atlas(ink, meta)]
    moves = [name for name in meta['animations'] if name not in {*REACTIONS, 'hit', 'death'}]
    draw_overview(output / f'{ident}_in_game.png', meta, frames, ident)
    draw_sheet(output / f'{ident}_actions.png', meta, frames, moves, f'{ident} / ACTIONS')
    draw_sheet(output / f'{ident}_reactions.png', meta, frames, REACTIONS, f'{ident} / REACTIONS')
