"""Validate recipe assets and check their evaluated Blender actions."""
import math

import bpy
import numpy as np
from mathutils import Vector

import build_swordsman as base
from common import PARTS, read_png, uv_rect
from chibi_body import ChibiBody
from leg_pocket import FRONT, POCKET_BONES, REAR
from render_sprites import validate
from unit_preview import INK, frames_from_atlas, ink_atlas, paint_tile, rgb
from unit_spec import (B_PROPORTIONS, BOW_STRING_BONES, HUMANOID_BONES, MOUNT_PARENTS, PROPORTION_TOLERANCE,
                       WEAPON_BONE, event_frame, presentation, sample_times, uses_shuffle)


def verify_proportions(recipe):
    # Measure mesh extents and actual thigh pivots, including a custom hood or helmet.
    # Measure a mounted rider on their standing rig before applying the seated pose.
    standing = ChibiBody.skeleton(recipe, {})
    rest = recipe.skeleton({})
    unseat = {key: base.bone_matrix(*standing[key]) @ base.bone_matrix(*rest[key]).inverted()
              for key in standing} if recipe.mount else {}
    head, body = [], []
    for obj in recipe.body_objects:
        bone = obj.vertex_groups[0].name
        transform = unseat.get(bone, obj.matrix_world)
        seat = recipe.mount.get('seat', .65) * recipe.height if recipe.mount and obj == recipe.pocket else 0
        zs = [(transform @ vert.co).z - seat for vert in obj.data.vertices]
        body.extend(zs)
        if obj == recipe.garment:
            head.extend(zs[i] for i in obj['head_vertices'])
        elif bone == 'head' and obj.name != 'collar':
            head.extend(zs)
    sole = min(body)
    height = max(body) - sole
    crotch = (standing['thigh_l'][0].z + standing['thigh_r'][0].z) / 2
    measured = {'head': (max(head) - min(head)) / height, 'leg': (crotch - sole) / height}
    for name, expected in B_PROPORTIONS.items():
        assert abs(measured[name] - expected) <= PROPORTION_TOLERANCE, (
            f'{recipe.spec["id"]}: B {name} ratio {measured[name]:.3f} exceeds {expected:.3f} ±{PROPORTION_TOLERANCE}')
    return {key: round(value, 4) for key, value in measured.items()}


def check_crotch(mask, heel_columns, pixels_per_height, standing, label):
    """Measure the open notch against the line through both soles."""
    rear, front = heel_columns
    cut = mask[:, rear:front + 1]
    assert cut.shape[1] > 1 and cut.any(axis=0).all(), f'{label}: legs split across crotch'
    bottom = cut.argmax(axis=0)
    top = len(cut) - 1 - cut[::-1].argmax(axis=0)
    assert (cut.sum(axis=0) == top - bottom + 1).all(), f'{label}: hole in lower body'
    notch = bottom - np.linspace(bottom[0], bottom[-1], len(bottom))
    peak = int(notch.argmax())
    depth = notch[peak]
    assert not standing or depth <= .08 * pixels_per_height, f'{label}: standing notch {depth / pixels_per_height:.1%} > 8%'
    if depth >= .025 * pixels_per_height:
        # A V retains only one third of its width between these levels. A
        # rounded arch retains over half, also when one foot is lifted.
        def width(level):
            below = notch < level * depth
            return np.flatnonzero(below[peak:])[0] + np.flatnonzero(below[:peak][::-1])[0]

        assert width(.75) >= .55 * width(.25), f'{label}: pointed crotch gap'
    return depth / pixels_per_height


def verify_crotch(recipe, rig, lower_body, standing, label):
    # Rasterize the evaluated leg meshes on their own. A long tabard or weapon
    # must not be able to hide a gap. Use the soles' local plane for tumbles.
    scale = 256
    graph = bpy.context.evaluated_depsgraph_get()
    sole = rig.pose.bones[REAR]
    up = (sole.tail - sole.head).normalized()
    forward = up.cross(Vector((0, -1, 0)))
    origin = sole.head

    def project(point):
        delta = point - origin
        return delta.dot(forward) * scale / recipe.height, delta.dot(up) * scale / recipe.height

    surfaces = []
    for obj in lower_body:
        mesh = obj.evaluated_get(graph).data
        mesh.calc_loop_triangles()
        points = np.array([project(vertex.co) for vertex in mesh.vertices])
        surfaces.append(points[[tri.vertices[:] for tri in mesh.loop_triangles]])
    triangles = np.concatenate(surfaces)
    lo = np.floor(triangles.min(axis=(0, 1))).astype(int)
    hi = np.ceil(triangles.max(axis=(0, 1))).astype(int)
    mask = np.zeros(tuple((hi - lo + 1)[::-1]), dtype=bool)
    for triangle in triangles:
        a, b = np.floor(triangle.min(axis=0)).astype(int), np.ceil(triangle.max(axis=0)).astype(int)
        yy, xx = np.ogrid[a[1]:b[1] + 1, a[0]:b[0] + 1]
        edges = [(v[0] - u[0]) * (yy - u[1]) - (v[1] - u[1]) * (xx - u[0])
                 for u, v in zip(triangle, np.roll(triangle, -1, axis=0))]
        if abs((triangle[1, 0] - triangle[0, 0]) * (triangle[2, 1] - triangle[0, 1]) -
               (triangle[1, 1] - triangle[0, 1]) * (triangle[2, 0] - triangle[0, 0])) < 1e-6:
            continue
        mask[a[1] - lo[1]:b[1] - lo[1] + 1, a[0] - lo[0]:b[0] - lo[0] + 1] |= (
            np.logical_and.reduce([edge >= -1e-6 for edge in edges]) |
            np.logical_and.reduce([edge <= 1e-6 for edge in edges]))
    front = round(project(rig.pose.bones[FRONT].head)[0])
    return check_crotch(mask, (-lo[0], front - lo[0]), scale, standing, label)


def verify_assassin_shoe_contrast(raw, ink, spec):
    # Select opaque fill by its UV island, then measure the final shaded artwork.
    cells = raw[..., :2].astype(int) * 4 // 255
    opaque = raw[..., 3] == 255
    parts = spec['parts']
    shoes = opaque & (cells == PARTS[parts['boots']][:2]).all(axis=2)
    clothing = opaque & (cells == PARTS[parts['tunic']][:2]).all(axis=2)
    _, v0, _, v1 = uv_rect(parts['tunic'])
    clothing &= raw[..., 1] < round(255 * (v0 + .30 * (v1 - v0)))
    assert shoes.any() and clothing.any(), 'shadow_assassin idle[0]: shoe and cloth fill must both be visible'
    luma = ink[..., :3] @ np.array([.2126, .7152, .0722])
    ratio = luma[shoes].mean() / luma[clothing].mean()
    assert ratio <= .5, f'shadow_assassin idle[0]: shoe/cloth mean luma {ratio:.3f} > 0.50'
    return round(float(ratio), 4)


def verify_unit(output, meta, recipe, check_rig):
    spec, ident = recipe.spec, recipe.spec['id']
    size, ortho, target_z, margin = recipe.camera
    total = sum(count for _, count, *_ in recipe.animations)
    rows = math.ceil(total / 8)
    assert meta['recipe_sha256'] == spec['_sha256'], f'{ident}: rebuild after editing the recipe'
    assert meta['image'] == f'{ident}_uv.png' and meta['frame_size'] == [size, size]
    assert (meta['columns'], meta['rows'], meta['image_size']) == (8, rows, [8 * size, rows * size])
    assert meta['presentation'] == presentation(spec, size, ortho)
    texture = meta['part_texture']
    assert texture['image'] == f'{ident}_parts.png' and texture['grid'] == [2, 2] and texture['tile_size'] == [256, 256]
    assert texture['appearances'] == [{'name': ident, 'cell': [0, 0]}]
    assert list(texture['regions']) == list(PARTS), 'Keep all existing region descriptors'
    for name, (x, y, _) in PARTS.items():
        assert texture['regions'][name]['cell'] == [x, y]
        assert texture['regions'][name]['uv_rect'] == uv_rect(name)
    coords = meta['coordinates']
    assert (coords['model_forward'], coords['camera_side'], coords['camera_pitch_degrees']) == ('+X', '-Y', 0)
    assert (coords['orthographic_size'], coords['camera_target_z']) == (ortho, target_z)
    assert coords['standing_foot_anchor_pixels'] == [size / 2, size - margin]

    atlas = read_png(output / meta['image'])
    assert atlas.shape == (rows * size, 8 * size, 4)
    result = validate(atlas, meta, total)
    assert len(meta['frames']) == total
    assert list(meta['animations']) == [row[0] for row in recipe.animations]
    frames = frames_from_atlas(atlas, meta)
    start = 0
    for name, count, duration, loop, events in recipe.animations:
        anim = meta['animations'][name]
        assert anim == dict(start_frame=start, frame_count=count, duration=duration, loop=loop,
                            events=events, frame_duration=duration / count,
                            event_frames={key: start + event_frame(t, count, duration) for key, t in events.items()},
                            source_sample_times=sample_times(name, count, duration, loop, events)), name
        for local in range(count):
            i = start + local
            frame = meta['frames'][i]
            assert (frame['index'], frame['local_frame'], frame['animation']) == (i, local, name)
            assert frame['rect'] == [i % 8 * size, i // 8 * size, size, size]
            assert frame['source_time'] == anim['source_sample_times'][local]
            y, x = np.nonzero(frames[i][..., 3])
            assert len(x) and 0 < x.min() <= x.max() < size - 1 and 0 < y.min() <= y.max() < size - 1, (
                f'{ident} {name}[{local}]: transparent cell margin lost')
            assert frame['alpha_bbox'] == [x.min(), y.min(), x.max() + 1, y.max() + 1]
        start += count
    unused = total % 8
    if unused:
        assert not atlas[-size:, unused * size:].any()
    x0, y0, x1, y1 = meta['frames'][0]['alpha_bbox']
    assert abs(y1 - (size - margin)) <= 2, (ident, 'standing foot anchor', y1)
    assert (y1 - y0) / size >= .47, (ident, 'increase standing sprite occupancy', y1 - y0)

    tile = paint_tile(spec)
    parts = read_png(output / texture['image'])
    assert np.array_equal(parts, np.tile(tile, (2, 2, 1)))
    colors = frames[0][..., :2].astype(np.float32) / 255
    assert (tile[np.round((1 - colors[..., 1]) * 255).astype(int),
                 np.round(colors[..., 0] * 255).astype(int), 3][frames[0][..., 3] >= 128] == 255).all()
    occupied = atlas[..., 3] > 0
    cells = set(map(tuple, (atlas[..., :2][occupied].astype(int) * 4 // 255)))
    palette_cells = {PARTS[part][:2] for part in spec['palette']}
    assert cells <= palette_cells, (ident, 'visible pixels reference an unused area', cells - palette_cells)
    ink = read_png(output / f'{ident}_ink.png')
    assert np.array_equal(ink, ink_atlas(atlas, meta, tile, rgb(spec['rim'])))
    ink_frames = frames_from_atlas(ink, meta)
    if ident == 'shadow_assassin':
        standing = meta['animations']['idle']['start_frame']
        result['shoe_cloth_luma_ratio'] = verify_assassin_shoe_contrast(frames[standing], ink_frames[standing], spec)
    for i, frame in enumerate(ink_frames):
        assert not (frame[0, :, 3].any() or frame[-1, :, 3].any() or
                    frame[:, 0, 3].any() or frame[:, -1, 3].any()), (
            ident, meta['frames'][i]['animation'], meta['frames'][i]['local_frame'], 'ink touches the cell border')
    for suffix in ('actions', 'in_game', 'reactions'):
        preview = read_png(output / f'{ident}_{suffix}.png')
        assert preview.ndim == 3 and preview.shape[2] == 3 and min(preview.shape[:2]) > size
        assert (preview <= np.asarray(INK) + 8).all(axis=2).sum() >= 10, f'{ident}: empty {suffix} preview'

    result.update(standing_alpha_bbox=[x0, y0, x1, y1], used_parts=sorted(spec['palette']),
                  visible_parts=[part for part, values in PARTS.items() if values[:2] in cells],
                  actions=len(recipe.animations), frames=total, ink_atlas=True, nonempty_previews=True)
    if check_rig:
        result.update(verify_rig(recipe, meta))
    return result


def verify_rig(recipe, meta):
    spec = recipe.spec
    rig, stats = recipe.build()
    scene = bpy.context.scene
    bones = set(HUMANOID_BONES) | set(POCKET_BONES) | (MOUNT_PARENTS.keys() if recipe.mount else set())
    if recipe.bow:
        bones.update(BOW_STRING_BONES)
    if recipe.has_dropped_weapon:
        bones.add(WEAPON_BONE)
    assert stats == meta['model'] and set(rig.data.bones.keys()) == bones
    proportions = verify_proportions(recipe)
    assert {part for obj in base.OBJECTS for part in obj.get('uv_parts', [obj['part']])} == spec['palette'].keys()
    for obj in base.OBJECTS:
        assert len(obj.modifiers) == 1 and obj.modifiers[0].object == rig
        if obj == recipe.pocket:
            assert set(obj.vertex_groups.keys()) == set(POCKET_BONES)
        elif obj == recipe.garment:
            assert set(obj.vertex_groups.keys()) == {'head', 'spine'}
        else:
            assert len(obj.vertex_groups) == 1 and obj.vertex_groups[0].name in bones
        assert all(abs(sum(g.weight for g in v.groups) - 1) < 1e-6 for v in obj.data.vertices)
        uv = np.array([loop.uv[:] for loop in obj.data.uv_layers.active.data])
        covered = np.zeros(len(uv), bool)
        for part in obj.get('uv_parts', [obj['part']]):
            u0, v0, u1, v1 = uv_rect(part)
            covered |= (uv >= np.array([u0, v0]) - 1e-6).all(axis=1) & (uv <= np.array([u1, v1]) + 1e-6).all(axis=1)
        assert covered.all()
    by_name = {obj.name: obj for obj in base.OBJECTS}
    for name, piece in spec.get('pieces', {}).items():
        assert by_name[name]['part'] == piece['part'] and by_name[name].vertex_groups[0].name == piece['bone']

    def evaluate(name, t):
        action = bpy.data.actions[name]
        rig.animation_data.action = action
        rig.animation_data.action_slot = action.slots[0]
        keyframe = t * 1000 + 1
        scene.frame_set(int(keyframe), subframe=keyframe % 1)
        return {bone.name: (bone.head.copy(), bone.tail.copy()) for bone in rig.pose.bones}

    def distance(a, b):
        return max((a[name][i] - b[name][i]).length for name in a for i in (0, 1))

    tolerance = recipe.height * .003
    scaled = {bone for fields in spec.get('actions', {}).values() for bone in fields.get('bone_scale', {})}
    nocked = recipe.bow.get('nocked_pieces', []) if recipe.bow else []

    def attachment(name, offset):
        rest = rig.data.bones[name]
        point = rest.head_local + recipe.height * Vector(offset)
        return rig.pose.bones[name].matrix @ (rest.matrix_local.inverted() @ point)

    markers = 0
    shuffles = []
    crotch = {'frames': 0, 'standing_depth': 0.}
    lower_body = [recipe.pocket] + [obj for obj in base.OBJECTS
                                   if obj['bone'].startswith(('thigh_', 'shin_', 'foot_'))]
    for name, _, duration, loop, events in recipe.animations:
        action = bpy.data.actions[name]
        assert dict((marker.name, marker.frame) for marker in action.pose_markers) == {
            key: round(t * 1000 + 1) for key, t in events.items()}, name
        if loop:
            assert distance(evaluate(name, 0), evaluate(name, duration)) < tolerance, f'{name}: loop seam'
        for i, t in enumerate(meta['animations'][name]['source_sample_times']):
            current = evaluate(name, t)
            label = f'{spec["id"]} {name}[{i}]'
            if scaled:
                scales = recipe.pose_parameters(name, t, duration).get('bone_scale', {})
                for bone in scaled:
                    start_point, tip = current[bone]
                    ratio = (tip - start_point).length / rig.data.bones[bone].length
                    assert abs(ratio - scales.get(bone, 1.)) < 1e-4, (label, bone, 'bone scale', ratio)
            if recipe.bow:
                bow = recipe.bow
                draw = spec.get('actions', {}).get(name, {}).get('bow_draw')
                drawn = bool(draw and events[draw[0]] <= t < events[draw[1]])
                bottom, top = [attachment(bow['bow_bone'], tip) for tip in bow['tips']]
                nock = (attachment(bow['draw_bone'], bow.get('draw_offset', (0, 0, 0))) if drawn
                        else bottom.lerp(top, .5))
                expected = dict(zip(BOW_STRING_BONES, ((bottom, nock), (nock, top))))
                assert distance(expected, current) < tolerance, (label, 'bow string endpoints')
                graph = bpy.context.evaluated_depsgraph_get()
                for piece in nocked:
                    assert by_name[piece].evaluated_get(graph).hide_render != drawn, (label, piece, 'nock visibility')
            depth = verify_crotch(recipe, rig, lower_body, name == 'idle', label)
            crotch['frames'] += 1
            if name == 'idle':
                crotch['standing_depth'] = round(max(crotch['standing_depth'], depth), 4)
        if uses_shuffle(name, spec.get('actions', {}).get(name, {})):
            reference = evaluate(name, 0)
            for t in meta['animations'][name]['source_sample_times']:
                actual = evaluate(name, t)
                for bone in ('root', 'spine', 'head', 'hand_l', 'hand_r'):
                    assert (actual[bone][0] - reference[bone][0]).length < tolerance, (name, bone, 'shuffle body moved')
                    assert (actual[bone][1] - reference[bone][1]).length < tolerance, (name, bone, 'shuffle body turned')
                for bone in ('foot_l', 'foot_r'):
                    assert abs(actual[bone][0].z - reference[bone][0].z) <= .015 * recipe.height, (
                        name, bone, 'shuffle foot lifts too high')
            for side, other in (('r', 'l'), ('l', 'r')):
                actual = evaluate(name, events[{'r': 'right_step', 'l': 'left_step'}[side]])
                if recipe.mount:
                    lead, trail = (actual[f'mount_fore_{key}_lower'][1] for key in (side, other))
                else:
                    lead, trail = (actual[f'foot_{key}'][0] for key in (side, other))
                assert lead.x > trail.x and abs(lead.z - trail.z) < tolerance, (name, side, 'step must land with the named foot ahead')
            shuffles.append(name)
        for t in set(events.values()):
            expected = recipe.skeleton(recipe.pose_parameters(name, t, duration))
            # A rigid Blender bone preserves its rest length, while an IK target can
            # alter the analytic tail length. Compare exact pivots and directions.
            actual = evaluate(name, t)
            for bone, (a, b) in expected.items():
                p, q = actual[bone]
                assert (a - p).length < tolerance, (name, t, bone, 'event pivot')
                assert (b - a).normalized().dot((q - p).normalized()) > .999, (name, t, bone, 'event axis')
        markers += len(events)
    for before, after in spec.get('transitions', []):
        duration = meta['animations'][before]['duration']
        assert distance(evaluate(before, duration), evaluate(after, 0)) < tolerance, f'{before} -> {after}: pose seam'
    return dict(model=stats, loops_close=True, exact_event_markers=markers,
                checked_transitions=len(spec.get('transitions', [])), proportions=proportions, shuffles=shuffles,
                crotch=crotch)
