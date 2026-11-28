"""Paint UV regions and bake the fixed-camera ink treatment into RGBA artwork."""
import numpy as np

from common import PARTS, PART_SIZE, PADDING, write_png
from preview import decode, label, paste


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


def art_frame(raw, tile, rim):
    """The RGBA export uses the same frame rectangles as the independent UV data."""
    two_tone = raw.copy()
    two_tone[..., 2] = np.where(raw[..., 2] >= 140, 136, 77)
    out = decode(two_tone, tile)
    a = raw[..., 3]
    padded = np.pad(a, 1)
    near = padded[:-2, 1:-1]
    left = padded[1:-1, :-2]
    extended = np.maximum.reduce([near, left, padded[2:, 1:-1], padded[1:-1, 2:], a])
    light = (a >= 155) & (near < 125) & (two_tone[..., 2] == 136)
    out[light, :3] = np.round(out[light, :3] * .27 + np.asarray(rim) * .73).astype(np.uint8)
    # The ink is composited under coverage to preserve a soft antialiased edge.
    fill = a.astype(np.float32) / 255
    total = extended.astype(np.float32) / 255
    mix = np.divide(fill, total, out=np.zeros_like(fill), where=total > 0)[..., None]
    out[..., :3] = np.round(out[..., :3] * mix + np.array([17, 22, 34]) * (1 - mix)).astype(np.uint8)
    out[..., 3] = extended
    out[extended == 0] = 0
    return out


def frames_from_atlas(atlas, meta):
    return [atlas[y:y + h, x:x + w] for x, y, w, h in (f['rect'] for f in meta['frames'])]


def ink_atlas(atlas, meta, tile, rim):
    ink = np.zeros_like(atlas)
    for x, y, w, h in (f['rect'] for f in meta['frames']):
        ink[y:y + h, x:x + w] = art_frame(atlas[y:y + h, x:x + w], tile, rim)
    return ink


def create_previews(atlas, meta, output, spec):
    ident = spec['id']
    tile = paint_tile(spec)
    ink = ink_atlas(atlas, meta, tile, rgb(spec['rim']))
    frames = frames_from_atlas(ink, meta)
    parts = np.tile(tile, (2, 2, 1))
    texture = meta['part_texture']
    texture['image'] = f'{ident}_parts.png'
    texture['appearances'] = [dict(name=ident, cell=[0, 0])]
    write_png(output / texture['image'], parts)
    write_png(output / f'{ident}_ink.png', ink)

    size = meta['frame_size'][0]
    margin, stride = 152, size + 18
    max_frames = max(an['frame_count'] for an in meta['animations'].values())
    canvas = np.full((46 + len(meta['animations']) * stride, margin + max_frames * (size + 4) + 12, 3),
                     [37, 44, 45], np.uint8)
    label(canvas, f'{ident} / ART REVIEW / 1X', 12, 13, 2)
    for row, (name, action) in enumerate(meta['animations'].items()):
        first = action['start_frame']
        y = 40 + row * stride
        label(canvas, name, 12, y + size // 2 - 7)
        label(canvas, f'{action["duration"]:.3f} S', 12, y + size // 2 + 4, colour=(151, 168, 166))
        for local in range(action['frame_count']):
            i = first + local
            x = margin + local * (size + 4)
            paste(canvas, frames[i], x, y, 1)
            ink = (230, 179, 102) if i in action['event_frames'].values() else (151, 168, 166)
            label(canvas, f'{local:02d}', x + 4, y + size + 3, colour=ink)
    write_png(output / f'{ident}_actions.png', canvas)

    poses = [('IDLE', 0), ('WALK', meta['animations']['walk']['start_frame'] + 2)]
    for name, action in meta['animations'].items():
        if name == 'attack' or name not in ('idle', 'walk', 'parry', 'clash', 'sit', 'ragdoll', 'fall', 'rise', 'death', 'hit'):
            middle = action['start_frame'] + action['frame_count'] // 2
            interior = [i for i in action['event_frames'].values()
                        if action['start_frame'] < i < action['start_frame'] + action['frame_count'] - 1]
            poses.append((name, interior[0] if interior else middle))
    # Scale from the solid idle footprint and lock that scale across all poses.
    footprint = np.flatnonzero((frames[0][..., 3] >= 128).any(axis=1))
    scaled = round(size * 48 / (footprint[-1] - footprint[0] + 1))
    coords = ((np.arange(scaled) + .5) * size / scaled).astype(int)
    converted = [frames[i][coords[:, None], coords] for _, i in poses]
    converted.append(converted[0][:, ::-1])
    poses.append(('FLIP', 0))
    span = scaled + 26
    board = np.empty((scaled + 99, max(span * len(poses), 466), 3), np.uint8)
    board[:48] = [26, 35, 39]
    board[48:-34] = [66, 72, 58]
    board[-34:] = [26, 35, 39]
    label(board, f'{ident} / 48 PX', 14, 15, 2)
    for col, (sprite, (name, _)) in enumerate(zip(converted, poses)):
        x = (board.shape[1] - span * len(poses)) // 2 + col * span + 10
        paste(board, sprite, x, 56, 1)
        label(board, name, x + 4, board.shape[0] - 22)
    write_png(output / f'{ident}_48px.png', board)
