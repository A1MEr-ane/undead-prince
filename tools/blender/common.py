"""Shared, dependency-free data/PNG helpers. UV arrays use a top-left image origin."""
from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / 'assets' / 'sprites'
GRID = 4
PART_SIZE = 256
PADDING = 4
# Cell coordinates have the conventional UV bottom-left origin.
PARTS = {
    'skin': (0, 3, 'Rounded head, nose and hands; cylindrical / spherical'),
    'helmet': (1, 3, 'Helmet dome and nasal guard; cylindrical'),
    'tunic': (2, 3, 'Coat and flared skirt; cylindrical, seam at +X'),
    'cloth_trim': (3, 3, 'Collar and hem; cylindrical'),
    'sleeves': (0, 2, 'Upper arms; cylindrical'),
    'trousers': (1, 2, 'Thighs and shins; cylindrical'),
    'boots': (2, 2, 'Boots; side planar / cylindrical'),
    'leather': (3, 2, 'Belt and sword grip; cylindrical'),
    'shield_face': (0, 1, 'Shield front; circular planar UV, centre (0.5, 0.5)'),
    'shield_rim': (1, 1, 'Thick shield rim; radial front mapping'),
    'shield_back': (2, 1, 'Shield back; circular planar mapping'),
    'metal': (3, 1, 'Helmet rim, shield boss and crossguard'),
    'blade': (0, 0, 'Blade; U across width, V from guard to tip'),
    'hilt': (1, 0, 'Pommel and grip fittings'),
    'eye': (2, 0, 'Eyes; planar'),
    'belt_buckle': (3, 0, 'Buckle; planar'),
}
ANIMATIONS = [
    ('idle', 6, .667, True, {}),
    ('walk', 8, .667, True, {'left_step': .3335, 'right_step': .000}),
    ('attack', 8, .600, False, {'hit': .333}),
    ('parry', 8, .650, False, {'block': .260}),
    ('clash', 4, .350, False, {'contact': .000}),
    ('fall', 4, .350, False, {'ground_contact': .350}),
    ('sit', 6, 1.000, True, {}),
    ('rise', 10, .833, False, {'standing': .740}),
    ('death', 7, .583, False, {'ground_contact': .486}),
    ('ragdoll', 6, .517, True, {}),
    ('hit', 2, .167, False, {'impact': .000}),
]


def uv_rect(name):
    x, y, _ = PARTS[name]
    return [(x * 64 + PADDING) / PART_SIZE,
            (y * 64 + PADDING) / PART_SIZE,
            ((x + 1) * 64 - PADDING) / PART_SIZE,
            ((y + 1) * 64 - PADDING) / PART_SIZE]


def map_uv(name, uv):
    u0, v0, u1, v1 = uv_rect(name)
    return (u0 + uv[0] * (u1 - u0), v0 + uv[1] * (v1 - v0))


def write_png(path, array):
    """Write exact 8-bit channel values, with no sRGB/gAMA/ICC chunks."""
    import numpy as np
    a = np.asarray(array, dtype=np.uint8)
    h, w, c = a.shape
    assert c in (3, 4)
    def chunk(kind, value):
        return struct.pack('>I', len(value)) + kind + value + struct.pack('>I', zlib.crc32(kind + value) & 0xffffffff)
    raw = b''.join(b'\0' + a[y].tobytes() for y in range(h))
    data = b'\x89PNG\r\n\x1a\n'
    data += chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6 if c == 4 else 2, 0, 0, 0))
    data += chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_bytes(data)


def read_png(path):
    """Read the deliberately simple, unfiltered PNGs emitted by write_png."""
    import numpy as np
    data = Path(path).read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    pos, compressed = 8, b''
    while pos < len(data):
        size = struct.unpack('>I', data[pos:pos + 4])[0]
        kind, payload = data[pos + 4:pos + 8], data[pos + 8:pos + 8 + size]
        if kind == b'IHDR':
            w, h, depth, colour, _, _, _ = struct.unpack('>IIBBBBB', payload)
            assert depth == 8 and colour in (2, 6)
        elif kind == b'IDAT':
            compressed += payload
        pos += size + 12
    c = 4 if colour == 6 else 3
    rows = np.frombuffer(zlib.decompress(compressed), np.uint8).reshape(h, w * c + 1)
    assert (rows[:, 0] == 0).all(), 'Only our filter-0 PNGs are supported'
    return rows[:, 1:].reshape(h, w, c).copy()
