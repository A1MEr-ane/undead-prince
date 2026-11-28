"""Skin one rounded lower-body mesh to the waist and two foot lobes."""
from mathutils import Vector

import build_swordsman as base
from common import map_uv

REAR, FRONT, WAIST = POCKET_BONES = ('pocket_rear', 'pocket_front', 'pocket_waist')
# Half of the sole outline, in fractions of standing height, from notch to outer edge.
SOLE = ((0., .069), (.018, .068), (.037, .062), (.056, .040),
        (.088, 0.), (.119, .008), (.141, .033), (.154, .086))
HALF_SPAN = .088


def clamp(value, low, high):
    return max(low, min(high, value))


def rest_guides(unit):
    H = unit.height
    seat = unit.mount.get('seat', .65) * H if unit.mount else 0
    return {
        REAR: Vector((-HALF_SPAN * H, 0, unit.ankle_z + seat)),
        FRONT: Vector((HALF_SPAN * H, 0, unit.ankle_z + seat)),
        WAIST: Vector((0, 0, unit.h['belt'] + seat)),
    }


def guides(unit, bones, feet, spread):
    """Move the lobes in silhouette order even when left and right trade places."""
    rest = rest_guides(unit)
    H = unit.height
    forward = Vector((1, 0, 0))
    near = Vector((0, -1, 0))
    anchors = rest
    if feet is not None:
        axis = (feet['foot_l'][1] - feet['foot_l'][0]).normalized()
        up = near.cross(axis)
        rear, front = sorted((feet[f'foot_{side}'][0] for side in ('l', 'r')), key=axis.dot)
        center = (rear + front) / 2
        span = clamp((front - rear).dot(axis) / 2, .050 * H, .128 * H)
        # A slight side bias distinguishes the two planted shuffle poses.
        center += axis * clamp((feet['foot_l'][0] - feet['foot_r'][0]).dot(axis) * .10, -.016 * H, .016 * H)
        rear = center - axis * span + up * (rear - center).dot(up)
        front = center + axis * span + up * (front - center).dot(up)
        waist = feet['root'][0].copy()
        waist += up * max(0., max(rear.dot(up), front.dot(up)) + .093 * H - waist.dot(up))
        anchors = {REAR: rear, FRONT: front, WAIST: waist}
        forward = axis
        if spread:
            # Scattered bones carry the waist and feet as a single intact piece.
            # Interpolate their offsets in the pocket's own plane to avoid folding.
            hip, tip = bones['root']
            forward = axis.slerp((tip - hip).normalized().cross(near), spread)
            old_hip = feet['root'][0]
            for name, point in anchors.items():
                delta = point - old_hip
                local = Vector((delta.dot(axis), delta.y, delta.dot(up)))
                local = local.lerp(rest[name] - rest[WAIST], spread)
                anchors[name] = hip + forward * local.x - near * local.y + near.cross(forward) * local.z
    return {name: (point, point + near.cross(forward) * (.075 * H)) for name, point in anchors.items()}


def build_pocket(unit, style):
    H = unit.height
    ankle = rest_guides(unit)[REAR].z
    floor = ankle - (unit.ankle_z - unit.ground)
    belt = base.REST[WAIST][0].z
    # One strip mesh per side, closed around the perimeter. UV bands give the
    # boots, visible lower legs and waist separate colours on the same surface.
    sole = [(-x, z) for x, z in reversed(SOLE[1:])] + list(SOLE)
    count = len(sole)
    width_scale = max(.92, unit.width['foot_length'] / (.157 * H))
    parts = (unit.part('boots'), unit.part('legs'), unit.part('belt' if style == 'bones' else 'legs'))
    cuff = unit.spec.get('shoe_cuff')
    vertices, coords, weights = [], [], []
    for side, rows in ((-1, (0, 1, 2, 3)), (1, (0, 2, 3))):
        for x, z in sole:
            edge = abs(x) / SOLE[-1][0]
            toe = clamp(.5 + x * width_scale / (2 * HALF_SPAN), 0., 1.)
            upper_foot = cuff if cuff is not None else max(z + .021, .081)
            levels = (z, max(z + .010, .047), upper_foot, (belt - floor) / H + .009 - .047 * edge**3)
            for row in rows:
                level = levels[row]
                # Move each sole and its colour bands together; pulling a
                # band toward the waist can otherwise cut across the arch.
                waist_weight = float(row == 3)
                depth = (.85 + .15 * row / 3) * (1 - .52 * edge**4) * .136
                local_x = x * width_scale * (1 - .32 * waist_weight)
                vertices.append((local_x * H, side * depth * H, floor + level * H))
                coords.append(((x / SOLE[-1][0] + 1) / 2, row / 3))
                weights.append(((1 - toe) * (1 - waist_weight), toe * (1 - waist_weight), waist_weight))

    faces, bands = [], []

    def face(indices, band):
        faces.append(indices)
        bands.append(band)

    back = count * 4
    foot_band = 0 if cuff is not None else 1
    rear_band = 0 if cuff is not None else 2
    for col in range(count - 1):
        a, b = col * 4, back + col * 3
        for row, band in enumerate((0, foot_band, 2)):
            i = a + row
            face((i, i + 4, i + 5, i + 1), band)
        face((b + 1, b + 4, b + 3, b), rear_band)
        face((b + 2, b + 5, b + 4, b + 1), 2)
        face((a + 4, a, b, b + 3), 0)
        face((a + 3, a + 7, b + 5, b + 2), 2)
    a, b = (count - 1) * 4, back + (count - 1) * 3
    face((0, 1, 2, back + 1, back), foot_band)
    face((2, 3, back + 2, back + 1), 2)
    face((a + 2, a + 1, a, b, b + 1), foot_band)
    face((a + 3, a + 2, b + 1, b + 2), 2)

    obj = base.mesh('leg_pocket', vertices, faces, [[coords[v] for v in f] for f in faces], parts[2], WAIST)
    obj['uv_parts'] = list(dict.fromkeys(parts))
    uv = obj.data.uv_layers.active.data
    for polygon, band in zip(obj.data.polygons, bands):
        part = parts[band]
        for index, vertex in zip(polygon.loop_indices, polygon.vertices):
            u, v = coords[vertex]
            if part == unit.part('head'):
                v = .02 + .21 * v
            uv[index].uv = map_uv(part, (u, v))
    obj.vertex_groups.clear()
    groups = [obj.vertex_groups.new(name=name) for name in POCKET_BONES]
    for i, values in enumerate(weights):
        for group, weight in zip(groups, values):
            if weight > 0:
                group.add([i], weight, 'REPLACE')
    return obj
