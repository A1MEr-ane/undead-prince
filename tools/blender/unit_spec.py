"""Schema and sampling for data-only units. Also runs under system Python."""
import math
import re

from common import ANIMATIONS, OUTPUT, PARTS, ROOT

UNIT_SPECS = ROOT / 'assets/specs/units'
UNIT_OUTPUT = OUTPUT / 'units'

CELL_SIZE = 128
FPS = 12
BODIES = {
    'normal': (1.92, 3.05),
    'large': (1.92 * 1.7, 3.05 * 1.7),
    'mounted': (1.92, 5.05),
}
REVIEW_PIXELS_PER_UNIT = 72 / BODIES['normal'][0]
B_PROPORTIONS = {'head': 1 / 2.3, 'leg': .22}
PROPORTION_TOLERANCE = .03
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
SCALARS = {'lean', 'head_tilt', 'sword', 'shield', 'tumble', 'spread', 'vertical_scale'}
STEP_EVENTS = {'right_step': 0, 'left_step': 2}
REACTIONS = ('hit_light', 'hit_heavy', 'knockback', 'stun', 'hit_arrow',
             'fall', 'sit', 'rise', 'ragdoll', 'death_slash', 'death_pierce', 'death_crush')


def clip(name, count, loop=False, **events):
    return name, count, count / FPS, loop, {key: frame / FPS for key, frame in events.items()}


# Legacy swordsman timings stay in common.ANIMATIONS. Recipe clips play at 12 fps.
UNIT_ACTIONS = {row[0]: row for row in (
    clip('idle', 6, True), clip('walk', 4, True, **STEP_EVENTS),
    clip('attack', 8, hit=4), clip('parry', 8, block=3), clip('clash', 4, contact=0),
    clip('fall', 4, ground_contact=4), clip('sit', 12, True), clip('rise', 10, standing=8),
    clip('ragdoll', 6, True), clip('hit_light', 4, impact=0), clip('hit_heavy', 7, impact=1),
    clip('knockback', 6, impact=1, ground_contact=6), clip('stun', 8, True),
    clip('hit_arrow', 6, impact=1),
    clip('death_slash', 7, ground_contact=5), clip('death_pierce', 7, ground_contact=5),
    clip('death_crush', 6, ground_contact=4),
    clip('hit', 4, impact=0), clip('death', 7, ground_contact=5),
)}
LEGACY_ACTIONS = {row[0]: row for row in ANIMATIONS}
ID = r'[a-z][a-z0-9_]*'


def event_frame(t, count, duration):
    return min(count - 1, math.floor(t * count / duration + 1e-8))


def sample_times(name, count, duration, loop, events):
    times = [duration * (i / (count if loop else count - 1)) for i in range(count)]
    # Show each authored event pose on the same frame that is on screen at t.
    events_by_frame = {}
    for t in events.values():
        index = event_frame(t, count, duration)
        if events_by_frame.setdefault(index, t) != t:
            raise ValueError(f'{name}: distinct event times share frame {index}; add frames or adjust timing')
        times[index] = t
    assert times[0] == 0 and (loop or times[-1] == duration), (
        f'{name}: preserve frame 0 and the final non-loop sample for the endpoints')
    assert all(a < b for a, b in zip(times, times[1:])), f'{name}: event pose samples out of order'
    return times


def animations(spec):
    rows = dict(UNIT_ACTIONS)
    for name, fields in spec.get('actions', {}).items():
        _, count, _, loop, events = rows.get(name, (None, None, None, None, {}))
        count = fields.get('frames', count)
        rows[name] = (name, count, fields.get('duration', count / FPS),
                      fields.get('loop', loop), fields.get('events', events))
    return list(rows.values())


def camera(spec):
    size = CELL_SIZE
    _, scale = BODIES[spec['body']]
    settings = spec.get('camera', {})
    scale = settings.get('ortho', scale)
    margin = settings.get('foot_margin', size / 32)
    return size, scale, .035 + scale * (.5 - margin / size), margin


def presentation(spec, size, ortho):
    height, _ = BODIES[spec['body']]
    if spec['body'] == 'mounted':
        height *= 1 + spec['mount'].get('seat', .65)
    return dict(body=spec['body'], standing_height_ratio=height / BODIES['normal'][0],
                pixels_per_model_unit=size / ortho, review_pixels_per_model_unit=REVIEW_PIXELS_PER_UNIT)


def uses_shuffle(name, fields):
    return fields.get('pose', name) == 'walk' and fields.get('mount_gait', 'shuffle') == 'shuffle'


def validate_recipe(spec):
    def number(value):
        return type(value) in (int, float) and math.isfinite(value)

    def colour(value):
        return isinstance(value, str) and re.fullmatch(r'#[0-9a-fA-F]{6}', value)

    def vector(value, size):
        return isinstance(value, list) and len(value) == size and all(map(number, value))

    assert set(spec) <= {'id', 'recipe', 'body', 'parts', 'palette', 'rim', 'triangle_budget', 'camera', 'body_style',
                         'landmarks', 'widths', 'head', 'marks', 'neutral', 'pieces', 'actions',
                         'mount', 'scattered', 'transitions'}, 'Unknown unit recipe fields'
    body = spec['body']
    assert body in BODIES, f'Unknown body {body}'
    assert spec.get('body_style', 'clothed') in ('clothed', 'bones', 'fitted')
    size, scale, _, margin = camera(spec)
    assert scale > 0 and 1 <= margin < size / 4, 'Invalid camera framing'
    assert set(spec.get('camera', {})) <= {'ortho', 'foot_margin'}
    h = LANDMARKS | spec.get('landmarks', {})
    assert h.keys() == LANDMARKS.keys() and all(number(v) for v in h.values())
    assert 0 < h['boot_top'] < h['crotch'] < h['tunic_hem'] < h['belt'] < h['shoulder'] <= h['chin'] < h['eye'] < h['helmet_brim'] < h['helmet_top']
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
    expected_parts = set(spec['parts'].values()) | set(mount.get('parts', {}).values())
    expected_parts.update(piece['part'] for piece in spec.get('pieces', {}).values())
    assert expected_parts == palette.keys(), 'Specify exactly the occupied UV regions in palette'
    assert set(spec.get('head', {})) <= {'x', 'depth', 'radius_x', 'profile', 'stamps'}
    head = spec.get('head', {})
    assert number(head.get('x', 0))
    for key in ('depth', 'radius_x'):
        assert .08 <= head.get(key, .19) <= .27, f'Invalid head {key}'

    def contour(points):
        assert len(points) >= 3 and all(vector(p, 2) for p in points)
        assert len(set(map(tuple, points))) == len(points), 'Repeated contour point'
        assert abs(sum(a * d - c * b for (a, b), (c, d) in zip(points, points[1:] + points[:1]))) > 1e-6, (
            'Zero-area contour')

    if 'profile' in head:
        contour(head['profile'])
        assert all(0 <= v <= 1 for p in head['profile'] for v in p)

    def check_stamp(stamp):
        assert set(stamp) <= {'shape', 'at', 'radii', 'points', 'color'}
        assert colour(stamp['color'])
        if stamp['shape'] == 'ellipse':
            assert vector(stamp['at'], 2) and vector(stamp['radii'], 2)
            assert all(0 <= v <= 1 for v in stamp['at']) and all(0 < v <= 1 for v in stamp['radii'])
        else:
            assert stamp['shape'] == 'polygon'
            contour(stamp['points'])
            assert all(vector(p, 2) and all(0 <= v <= 1 for v in p) for p in stamp['points'])

    assert spec['parts']['head'] not in spec.get('marks', {}), 'Use head.stamps for the head projection'
    for part, stamps in spec.get('marks', {}).items():
        assert part in palette, f'Marks on unused region {part}'
        for stamp in stamps:
            check_stamp(stamp)
    for stamp in head.get('stamps', []):
        check_stamp(stamp)

    bones = set(HUMANOID_BONES) | (MOUNT_PARENTS.keys() if mount else set())
    for name, piece in spec.get('pieces', {}).items():
        assert re.fullmatch(ID, name) and set(piece) <= {'bone', 'part', 'points', 'depth', 'offset', 'yaw', 'far'}
        assert piece['bone'] in bones and piece['part'] in palette, f'{name}: unknown bone or missing part colour'
        contour(piece['points'])
        assert 0 < piece['depth'] <= 1 and vector(piece.get('offset', [0, 0, 0]), 3), name
        assert number(piece.get('yaw', 0)) and type(piece.get('far', False)) is bool, name

    scattered = spec.get('scattered', {})
    assert scattered.keys() <= bones
    assert all(vector(pose, 4) for pose in scattered.values()), 'Scattered bones use [x, y, z, pitch]'

    def check_value(channel, value):
        valid = vector(value, 3) if channel in VECTORS else channel in SCALARS and number(value)
        assert valid, f'Invalid pose channel {channel}: {value}'
        if channel == 'spread':
            assert scattered and 0 <= value <= 1, 'spread needs scattered targets and a value in [0, 1]'
        if channel == 'vertical_scale':
            assert .2 <= value <= 1, 'vertical_scale must be in [.2, 1]'

    for channel, value in spec.get('neutral', {}).items():
        assert channel not in ('spread', 'vertical_scale'), 'The rest rig must be standing'
        check_value(channel, value)
    for name, count, duration, loop, events in animations(spec):
        fields = spec.get('actions', {}).get(name, {})
        assert re.fullmatch(ID, name) and set(fields) <= {
            'frames', 'duration', 'loop', 'events', 'pose', 'tracks', 'mount_gait'}, name
        assert fields.get('pose', name if name in UNIT_ACTIONS else 'idle') in UNIT_ACTIONS.keys() | {'neutral'}, name
        assert type(count) is int and 2 <= count <= 32 and number(duration) and type(loop) is bool, name
        assert math.isclose(duration * FPS, count, abs_tol=1e-7), f'{name}: clips must play at 12 fps'
        assert all(re.fullmatch(ID, event) and number(t) and 0 <= t <= duration
                   and (not loop or t < duration) for event, t in events.items()), name
        assert fields.get('mount_gait', 'stand') in ('stand', 'shuffle', 'trot', 'gallop'), name
        assert mount or 'mount_gait' not in fields, name
        if uses_shuffle(name, fields):
            assert count == 4 and loop and events == UNIT_ACTIONS['walk'][4], f'{name}: keep the two shuffle step points'
            for channel, keys in fields.get('tracks', {}).items():
                if channel not in ('foot_l', 'foot_r'):
                    assert all(value == keys[0][1] for _, value in keys), f'{name}: lock the upper body'
        sample_times(name, count, duration, loop, events)
        for channel, keys in fields.get('tracks', {}).items():
            assert len(keys) >= 2 and keys[0][0] == 0 and keys[-1][0] == 1, (name, channel)
            assert all(a[0] < b[0] for a, b in zip(keys, keys[1:])), (name, channel)
            assert not loop or keys[0][1] == keys[-1][1], (name, channel, 'loop must close')
            for _, value in keys:
                check_value(channel, value)
    names = {row[0] for row in animations(spec)}
    for pair in spec.get('transitions', []):
        assert len(pair) == 2 and set(pair) <= names, f'Unknown transition {pair}'
