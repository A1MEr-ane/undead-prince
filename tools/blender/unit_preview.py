"""Paint existing UV regions from YAML and render the review style offscreen."""
import numpy as np

from common import PARTS, PART_SIZE, PADDING, write_png
from preview import decode, label, paste


def rgb(colour):
    return tuple(bytes.fromhex(colour[1:]))


def paint_tile(spec):
    tile = np.zeros((PART_SIZE, PART_SIZE, 4), np.uint8)
    tile[..., 3] = 255
    for part, colour in spec['palette'].items():
        x, y, _ = PARTS[part]
        y = 3 - y
        tile[y * 64:(y + 1) * 64, x * 64:(x + 1) * 64, :3] = rgb(colour)
    x, y, _ = PARTS[spec['parts']['head']]
    y = 3 - y
    area = tile[y * 64:(y + 1) * 64, x * 64:(x + 1) * 64, :3]
    # Evaluate flat motifs at 4x so their texture edges do not staircase.
    yy, xx = np.mgrid[:256, :256] / 4 + .125
    span = 64 - 2 * PADDING
    u = (xx - PADDING) / span
    v = ((64 - yy - PADDING) / span - .30) / .70
    paint = np.broadcast_to(area[0, 0], (256, 256, 3)).copy()
    for stamp in spec.get('head', {}).get('stamps', []):
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
    return tile


def art_frame(raw, tile, rim):
    """Review composite only. Runtime textures retain the UV v1 data."""
    two_tone = raw.copy()
    two_tone[..., 2] = np.where(raw[..., 2] >= 140, 136, 77)
    out = decode(two_tone, tile)
    a = raw[..., 3]
    padded = np.pad(a, 1)
    size = len(a)
    near = padded[:-2, 1:-1]
    left = padded[1:-1, :-2]
    extended = np.maximum.reduce([near, left, padded[2:, 1:-1], padded[1:-1, 2:], a])
    # One source-pixel dark outline. Light runs inside the upper-left edge.
    outline = (a < 50) & (extended > 80)
    out[outline] = [22, 21, 28, 255]
    light = (a >= 190) & ((near < 50) | (left < 50))
    out[light, :3] = np.round(out[light, :3] * .34 + np.asarray(rim) * .66).astype(np.uint8)
    return out


def frames_from_atlas(atlas, meta):
    return [atlas[y:y + h, x:x + w] for x, y, w, h in (f['rect'] for f in meta['frames'])]


def review_frames(atlas, meta, spec):
    tile = paint_tile(spec)
    frames = [art_frame(frame, tile, rgb(spec['rim'])) for frame in frames_from_atlas(atlas, meta)]
    return tile, frames


def create_previews(atlas, meta, output, spec):
    ident = spec['id']
    tile, frames = review_frames(atlas, meta, spec)
    parts = np.tile(tile, (2, 2, 1))
    texture = meta['part_texture']
    texture['image'] = f'{ident}_parts.png'
    texture['appearances'] = [dict(name=ident, cell=[0, 0])]
    write_png(output / texture['image'], parts)

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

    idle, walk, attack = (meta['animations'][n] for n in ('idle', 'walk', 'attack'))
    indices = [idle['start_frame'], walk['start_frame'] + 2,
               next(iter(attack['event_frames'].values()), attack['start_frame'] + attack['frame_count'] // 2)]
    # Scale from the solid idle footprint and lock that scale across all poses.
    footprint = np.flatnonzero((frames[0][..., 3] >= 128).any(axis=1))
    scaled = round(size * 48 / (footprint[-1] - footprint[0] + 1))
    coords = ((np.arange(scaled) + .5) * size / scaled).astype(int)
    converted = [frames[i][coords[:, None], coords] for i in indices]
    span = scaled + 26
    board = np.empty((scaled + 99, max(span * 4, 466), 3), np.uint8)
    board[:48] = [26, 35, 39]
    board[48:-34] = [66, 72, 58]
    board[-34:] = [26, 35, 39]
    label(board, f'{ident} / 48 PX', 14, 15, 2)
    for col, (sprite, name) in enumerate(zip([*converted, converted[0][:, ::-1]],
                                             ['IDLE', 'WALK', 'ATTACK', 'FLIP'])):
        x = (board.shape[1] - span * 4) // 2 + col * span + 10
        paste(board, sprite, x, 56, 1)
        label(board, name, x + 4, board.shape[0] - 22)
    write_png(output / f'{ident}_48px.png', board)
