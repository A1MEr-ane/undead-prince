"""Compose the final fix evidence: archer nock/draw/release and cavalry horse head."""
import json
from pathlib import Path
import sys

import numpy as np

ROOT = Path(__file__).resolve().parents[4]
TOOLS = ROOT / 'tools/blender'
sys.path.insert(0, str(TOOLS))

from common import read_png, write_png
from preview import label, paste
from unit_preview import PAGE, TERRAIN, MUTED, frames_from_atlas


def panel(board, sprite, x, y, zoom, caption):
    h, w = sprite.shape[:2]
    board[y:y + h * zoom, x:x + w * zoom] = TERRAIN
    paste(board, sprite, x, y, zoom)
    label(board, caption, x + 2, y + h * zoom + 8)


def main():
    archer = ROOT / 'assets/sprites/units/archer/archer'
    meta = json.loads(archer.with_name('archer_uv.json').read_text())
    frames = frames_from_atlas(read_png(archer.with_name('archer_ink.png')), meta)
    shoot = meta['animations']['shoot']
    picks = [('NOCK / 02', 2), ('FULL DRAW / 05', 5), ('RELEASE / 06', 6)]

    cavalry = ROOT / 'assets/sprites/units/cavalry/cavalry'
    cmeta = json.loads(cavalry.with_name('cavalry_uv.json').read_text())
    cframes = frames_from_atlas(read_png(cavalry.with_name('cavalry_ink.png')), cmeta)
    cidle = cmeta['animations']['idle']['start_frame']
    ccharge = cmeta['animations']['charge']['start_frame'] + 5

    zoom = 3
    cell = 128 * zoom
    gap = 26
    width = 24 + len(picks) * (cell + gap)
    board = np.full((40 + cell + 50 + 330 + 40, max(width, 760), 3), PAGE, np.uint8)
    label(board, 'T88 FINAL FIXES / ARCHER BOWSTRING + ARROW', 14, 13, 2)
    for i, (name, local) in enumerate(picks):
        panel(board, frames[shoot['start_frame'] + local], 24 + i * (cell + gap), 40, zoom, name)
    y = 40 + cell + 50
    label(board, 'CAVALRY HORSE HEAD / 5X CROP', 14, y - 20, 2)
    for i, (name, index) in enumerate((('IDLE', cidle), ('CHARGE', ccharge))):
        crop = cframes[index][38:104, 56:126]
        panel(board, crop, 24 + i * (70 * 5 + 24), y, 5, name)
    out = ROOT / 'reports/agents/T88-drafts/_final_fixes.png'
    write_png(out, board)
    print('WROTE', out, board.shape)


if __name__ == '__main__':
    main()
