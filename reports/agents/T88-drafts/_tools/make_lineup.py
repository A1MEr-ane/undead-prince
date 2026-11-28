"""Compose the seven-unit actual-size lineup from built ink atlases. Draft helper."""
import json
from pathlib import Path
import sys

import numpy as np

ROOT = Path(__file__).resolve().parents[4]
TOOLS = ROOT / 'tools/blender'
sys.path.insert(0, str(TOOLS))

from common import read_png, write_png
from preview import label, paste
from unit_preview import PAGE, TERRAIN, MUTED, frames_from_atlas, preview_scale, resample

UNITS = [
    ('ZOMBIE', ROOT / 'assets/sprites/units/zombie/zombie'),
    ('SHADOW ASSASSIN', ROOT / 'assets/sprites/units/shadow_assassin/shadow_assassin'),
    ('STITCHED GIANT', ROOT / 'reports/agents/T88-drafts/stitched_giant/stitched_giant'),
    ('LICH', ROOT / 'reports/agents/T88-drafts/lich/lich'),
    ('SHIELDMAN', ROOT / 'reports/agents/T88-drafts/shieldman/shieldman'),
    ('ARCHER', ROOT / 'reports/agents/T88-drafts/archer/archer'),
    ('CAVALRY', ROOT / 'reports/agents/T88-drafts/cavalry/cavalry'),
]


def main():
    entries = []
    for name, stem in UNITS:
        meta = json.loads(stem.with_name(stem.name + '_uv.json').read_text())
        ink = read_png(stem.with_name(stem.name + '_ink.png'))
        size = round(meta['frame_size'][0] * preview_scale(meta))
        frame = resample(frames_from_atlas(ink, meta)[0], size)
        anchor = round(size * meta['coordinates']['standing_foot_anchor_pixels'][1] / meta['frame_size'][1])
        height = round(72 * meta['presentation']['standing_height_ratio'])
        entries.append((name, frame, anchor, height))
    gap = 80
    baseline = 330
    width = 30 + sum(frame.shape[1] + gap for _, frame, _, _ in entries)
    board = np.full((baseline + 105, width, 3), PAGE, np.uint8)
    label(board, 'T88 DRAFTS / 1080P ACTUAL SIZE / 72 PX INFANTRY BASELINE', 14, 14, 2)
    label(board, 'B PROPORTION / SAME CAMERA SCALE FOR ALL SEVEN UNITS', 14, 36, colour=MUTED)
    x = 16
    for name, frame, anchor, height in entries:
        y = baseline - anchor
        h, w = frame.shape[:2]
        board[y:y + h, x:x + w] = TERRAIN
        paste(board, frame, x, y, 1)
        label(board, name, x + 2, baseline + 18, 2)
        ratio = height / 72
        label(board, f'{height} PX  {ratio:.2f}X', x + 2, baseline + 38, colour=MUTED)
        x += w + gap
    out = ROOT / 'reports/agents/T88-drafts/_lineup.png'
    write_png(out, board)
    print('WROTE', out, board.shape)


if __name__ == '__main__':
    main()
