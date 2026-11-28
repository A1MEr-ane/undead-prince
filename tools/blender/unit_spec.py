"""Schema and sampling for data-only units. Also runs under system Python."""
import math
import re

from common import ANIMATIONS, PARTS

BODIES = {
    'normal': (1.92, 64, 3.05),
    'large': (2.88, 96, 4.575),
    'mounted': (1.92, 128, 6.10),
}
LANDMARKS = dict(boot_top=.11, crotch=.22, tunic_hem=.265, belt=.32, shoulder=.55,
                 chin=.56, eye=.735, helmet_brim=.81, helmet_top=1.)
WIDTHS = dict(head=.46, shoulders=.44, foot_length=.14, hand_diameter=.11)
BODY_PARTS = ('tunic', 'belt', 'collar', 'head', 'legs', 'sleeves', 'boots', 'hands')
MOUNT_PARTS = ('body', 'face', 'mane', 'legs', 'hooves', 'tack')
HUMANOID_BONES = ('root', 'spine', 'head') + tuple(
    f'{part}_{side}' for side in ('l', 'r')
    for part in ('thigh', 'shin', 'foot', 'upper_arm', 'forearm', 'hand'))
MOUNT_PARENTS = {**dict(mount_body='root', mount_head='mount_body', mount_tail='mount_body'),
                 **{f'mount_{leg}_{side}_{joint}': ('mount_body' if joint == 'upper'
                     else f'mount_{leg}_{side}_upper') for leg in ('fore', 'hind')
                     for side in ('l', 'r') for joint in ('upper', 'lower')}}
VECTORS = {'hip', 'foot_l', 'foot_r', 'wrist_l', 'wrist_r'}
ANGLES = {'lean', 'head_tilt', 'sword', 'shield', 'tumble'}
BASE_ACTIONS = {row[0]: row for row in ANIMATIONS}
ID = r'[a-z][a-z0-9_]*'


def event_frame(t, count, duration):
    return min(count - 1, math.floor(t * count / duration + 1e-8))


def sample_times(name, count, duration, loop, events):
    times = [i * duration / (count if loop else count - 1) for i in range(count)]
    # Show each authored event pose on the same frame that is on screen at t.
    events_by_frame = {}
    for t in events.values():
        index = event_frame(t, count, duration)
        if events_by_frame.setdefault(index, t) != t:
            raise ValueError(f'{name}: distinct event times share frame {index}; add frames or adjust timing')
        times[index] = t
    assert times[0] == 0 and (loop or times[-1] == duration), (
        f'{name}: preserve frame 0 and the final non-loop sample for the endpoints')
    return times


def animations(spec):
    rows = dict(BASE_ACTIONS)
    for name, fields in spec.get('actions', {}).items():
        _, count, duration, loop, events = rows.get(name, (None, None, None, None, {}))
        rows[name] = (name, fields.get('frames', count), fields.get('duration', duration),
                      fields.get('loop', loop), fields.get('events', events))
    return list(rows.values())


def camera(spec):
    _, size, scale = BODIES[spec['body']]
    settings = spec.get('camera', {})
    scale = settings.get('ortho', scale)
    margin = settings.get('foot_margin', size / 32)
    return size, scale, .035 + scale * (.5 - margin / size), margin


def validate_recipe(spec):
    def number(value):
        return type(value) in (int, float) and math.isfinite(value)

    def colour(value):
        return isinstance(value, str) and re.fullmatch(r'#[0-9a-fA-F]{6}', value)

    def vector(value, size):
        return isinstance(value, list) and len(value) == size and all(map(number, value))

    assert set(spec) <= {'id', 'recipe', 'body', 'parts', 'palette', 'rim', 'triangle_budget', 'camera',
                         'landmarks', 'widths', 'head', 'neutral', 'pieces', 'actions', 'mount'}, 'Unknown unit recipe fields'
    body = spec['body']
    assert body in BODIES, f'Unknown body {body}'
    size, scale, _, margin = camera(spec)
    assert scale > 0 and 1 <= margin < size / 4, 'Invalid camera framing'
    assert set(spec.get('camera', {})) <= {'ortho', 'foot_margin'}
    h = LANDMARKS | spec.get('landmarks', {})
    assert h.keys() == LANDMARKS.keys() and all(number(v) for v in h.values())
    assert 0 < h['boot_top'] < h['crotch'] < h['tunic_hem'] < h['belt'] < h['shoulder'] <= h['chin'] < h['eye'] < h['helmet_brim'] < h['helmet_top']
    assert h['crotch'] == .22 and h['chin'] == .56 and h['helmet_top'] == 1, 'Preserve approved B proportions'
    widths = WIDTHS | spec.get('widths', {})
    assert widths.keys() == WIDTHS.keys() and all(number(v) and v > 0 for v in widths.values())
    assert type(spec['triangle_budget']) is int and spec['triangle_budget'] > 0
    assert spec['parts'].keys() == set(BODY_PARTS) and set(spec['parts'].values()) <= set(PARTS)
    mount = spec.get('mount', {})
    if body == 'mounted':
        assert set(mount) <= {'parts', 'seat', 'stride', 'pace'}
        assert mount['parts'].keys() == set(MOUNT_PARTS) and set(mount['parts'].values()) <= set(PARTS)
        assert .45 <= mount.get('seat', .65) <= .85
        assert 0 < mount.get('stride', .16) <= .30
        assert mount.get('pace', 'trot') in ('trot', 'gallop')
    else:
        assert not mount, 'mount must use the mounted body'
    palette = spec['palette']
    assert palette.keys() <= PARTS.keys() and all(map(colour, palette.values())), 'Use quoted #RRGGBB for each occupied region'
    assert colour(spec['rim'])
    assert (set(spec['parts'].values()) | set(mount.get('parts', {}).values())) <= palette.keys()
    assert set(spec.get('head', {})) <= {'x', 'depth', 'radius_x', 'stamps'}
    for key in ('depth', 'radius_x'):
        assert .08 <= spec.get('head', {}).get(key, .19) <= .27, f'Invalid head {key}'
    for stamp in spec.get('head', {}).get('stamps', []):
        assert set(stamp) <= {'shape', 'at', 'radii', 'points', 'color'}
        assert colour(stamp['color'])
        if stamp['shape'] == 'ellipse':
            assert vector(stamp['at'], 2) and vector(stamp['radii'], 2)
            assert all(0 <= v <= 1 for v in stamp['at']) and all(0 < v <= 1 for v in stamp['radii'])
        else:
            assert stamp['shape'] == 'polygon' and len(stamp['points']) >= 3
            assert all(vector(p, 2) and all(0 <= v <= 1 for v in p) for p in stamp['points'])
    bones = set(HUMANOID_BONES) | (MOUNT_PARENTS.keys() if mount else set())
    for name, piece in spec.get('pieces', {}).items():
        assert re.fullmatch(ID, name) and set(piece) <= {'bone', 'part', 'points', 'depth', 'offset', 'yaw', 'far'}
        assert piece['bone'] in bones and piece['part'] in palette, f'{name}: unknown bone or missing part colour'
        assert len(piece['points']) >= 3 and all(vector(p, 2) for p in piece['points']), name
        assert 0 < piece['depth'] <= 1 and vector(piece.get('offset', [0, 0, 0]), 3), name

    def check_value(channel, value):
        assert vector(value, 3) if channel in VECTORS else (
            channel in ANGLES and number(value)), f'Invalid pose channel {channel}: {value}'

    for channel, value in spec.get('neutral', {}).items():
        check_value(channel, value)
    for name, count, duration, loop, events in animations(spec):
        fields = spec.get('actions', {}).get(name, {})
        assert re.fullmatch(ID, name) and set(fields) <= {
            'frames', 'duration', 'loop', 'events', 'pose', 'tracks', 'mount_gait'}, name
        assert fields.get('pose', name if name in BASE_ACTIONS else 'idle') in BASE_ACTIONS, name
        assert type(count) is int and 2 <= count <= 32 and number(duration) and duration > 0 and type(loop) is bool, name
        assert all(re.fullmatch(ID, event) and number(t) and 0 <= t <= duration
                   and (not loop or t < duration) for event, t in events.items()), name
        assert fields.get('mount_gait', 'stand') in ('stand', 'trot', 'gallop'), name
        assert mount or 'mount_gait' not in fields, name
        sample_times(name, count, duration, loop, events)
        for channel, keys in fields.get('tracks', {}).items():
            assert len(keys) >= 2 and keys[0][0] == 0 and keys[-1][0] == 1, (name, channel)
            assert all(a[0] < b[0] for a, b in zip(keys, keys[1:])), (name, channel)
            assert not loop or keys[0][1] == keys[-1][1], (name, channel, 'loop must close')
            for _, value in keys:
                check_value(channel, value)
