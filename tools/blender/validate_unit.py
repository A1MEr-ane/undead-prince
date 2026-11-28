"""Validate recipe assets and check their evaluated Blender actions."""
import math

import bpy
import numpy as np

import build_swordsman as base
from common import PARTS, read_png, uv_rect
from render_sprites import validate
from unit_preview import frames_from_atlas, ink_atlas, paint_tile, rgb
from unit_spec import HUMANOID_BONES, MOUNT_PARENTS, event_frame, sample_times


def verify_unit(output, meta, recipe, check_rig):
    spec, ident = recipe.spec, recipe.spec['id']
    size, ortho, target_z, margin = recipe.camera
    total = sum(count for _, count, *_ in recipe.animations)
    rows = math.ceil(total / 8)
    assert meta['recipe_sha256'] == spec['_sha256'], f'{ident}: rebuild after editing the recipe'
    assert meta['image'] == f'{ident}_uv.png' and meta['frame_size'] == [size, size]
    assert (meta['columns'], meta['rows'], meta['image_size']) == (8, rows, [8 * size, rows * size])
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
    for i, frame in enumerate(frames_from_atlas(ink, meta)):
        assert not (frame[0, :, 3].any() or frame[-1, :, 3].any() or
                    frame[:, 0, 3].any() or frame[:, -1, 3].any()), (
            ident, meta['frames'][i]['animation'], meta['frames'][i]['local_frame'], 'ink touches the cell border')
    for suffix in ('actions', '48px'):
        preview = read_png(output / f'{ident}_{suffix}.png')
        assert preview.ndim == 3 and preview.shape[2] == 3 and min(preview.shape[:2]) > size
        assert (preview == [17, 22, 34]).all(axis=2).sum() >= 10, f'{ident}: empty {suffix} preview'

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
    bones = set(HUMANOID_BONES) | (MOUNT_PARENTS.keys() if recipe.mount else set())
    assert stats == meta['model'] and set(rig.data.bones.keys()) == bones
    assert set(obj['part'] for obj in base.OBJECTS) == spec['palette'].keys()
    for obj in base.OBJECTS:
        assert len(obj.modifiers) == 1 and obj.modifiers[0].object == rig
        assert len(obj.vertex_groups) == 1 and obj.vertex_groups[0].name in bones
        assert all(len(v.groups) == 1 and abs(v.groups[0].weight - 1) < 1e-6 for v in obj.data.vertices)
        u0, v0, u1, v1 = uv_rect(obj['part'])
        uv = np.array([loop.uv[:] for loop in obj.data.uv_layers.active.data])
        assert (uv >= np.array([u0, v0]) - 1e-6).all() and (uv <= np.array([u1, v1]) + 1e-6).all()
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
    markers = 0
    for name, _, duration, loop, events in recipe.animations:
        action = bpy.data.actions[name]
        assert dict((marker.name, marker.frame) for marker in action.pose_markers) == {
            key: round(t * 1000 + 1) for key, t in events.items()}, name
        if loop:
            assert distance(evaluate(name, 0), evaluate(name, duration)) < tolerance, f'{name}: loop seam'
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
                checked_transitions=len(spec.get('transitions', [])))
