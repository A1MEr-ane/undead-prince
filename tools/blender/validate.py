"""Artifact and independent ray/UV/light verification. Run with Blender Python."""
import argparse
import json
from pathlib import Path
import sys

import bpy
import numpy as np
from mathutils import Vector
from mathutils.geometry import barycentric_transform

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import OUTPUT, PARTS, read_png, uv_rect


def verify(output, check_rig=True):
    metadata = json.loads((output / 'swordsman_uv.json').read_text())
    atlas = read_png(output / metadata['image'])
    from render_sprites import validate, setup_scene
    result = validate(atlas, metadata)
    size = metadata['frame_size'][0]
    assert atlas.shape == (9 * size, 8 * size, 4)
    assert not atlas[-size:, 5 * size:].any(), 'Unused final three cells must be clear'
    start = 0
    for name, animation in metadata['animations'].items():
        assert animation['start_frame'] == start
        assert len(animation['source_sample_times']) == animation['frame_count']
        assert abs(animation['frame_duration'] * animation['frame_count'] - animation['duration']) < 1e-7
        for frame in metadata['frames'][start:start + animation['frame_count']]:
            x0, y0, x1, y1 = frame['alpha_bbox']
            assert 0 < x0 < x1 < size and 0 < y0 < y1 < size, (name, frame)
        start += animation['frame_count']
    assert start == 69
    bbox = metadata['frames'][0]['alpha_bbox']
    assert size - bbox[3] in (1, 2, 3), bbox
    assert .66 <= (bbox[3] - bbox[1]) / size <= .74, bbox
    assert metadata['animations']['attack']['events']['hit'] == .333
    assert metadata['animations']['attack']['source_sample_times'][4] == .333
    paint = read_png(output / 'parts_preview.png')
    assert paint.shape == (512, 512, 4)
    for name in ('militia', 'veteran', 'undead', 'elite', 'looks', 'uv', 'shading'):
        assert (output / f'preview_{name}.png').is_file()
    result['standing_alpha_bbox'] = bbox
    if check_rig:
        from build_swordsman import build, OBJECTS, REST, skeleton, pose_parameters
        rig, stats = build()
        assert 300 <= stats['polygons'] <= 800 and stats['triangles'] <= 800
        assert stats['bones'] == 15
        assert set(ob['part'] for ob in OBJECTS) == set(PARTS)
        for ob in OBJECTS:
            assert len(ob.modifiers) == 1 and ob.modifiers[0].type == 'ARMATURE'
            assert len(ob.vertex_groups) == 1
            u0, v0, u1, v1 = uv_rect(ob['part'])
            coords = np.array([loop.uv[:] for loop in ob.data.uv_layers.active.data])
            assert coords[:, 0].min() >= u0 - 1e-6 and coords[:, 0].max() <= u1 + 1e-6
            assert coords[:, 1].min() >= v0 - 1e-6 and coords[:, 1].max() <= v1 + 1e-6
        # Authored pose assertions catch swapped stepping and incorrect strike timing.
        left_swing = skeleton(pose_parameters('walk', .667 / 4, .667))
        right_swing = skeleton(pose_parameters('walk', .667 * .75, .667))
        assert left_swing['foot_l'][0].z > left_swing['foot_r'][0].z + .1
        assert right_swing['foot_r'][0].z > right_swing['foot_l'][0].z + .1
        strike = skeleton(pose_parameters('attack', .333, .6))
        hand, tip = strike['hand_r']
        assert (tip - hand).normalized().x > .99 and hand.x > .6
        # Loop endpoints reproduce the same joint positions, including the full turn.
        for name, duration in [('idle', .667), ('walk', .667), ('sit', 1.), ('ragdoll', .517)]:
            a = skeleton(pose_parameters(name, 0, duration))
            b = skeleton(pose_parameters(name, duration, duration))
            assert max((a[key][i] - b[key][i]).length for key in a for i in (0, 1)) < 1e-5
        scene = setup_scene(size, 8, 4)
        scene.frame_set(1)
        graph = bpy.context.evaluated_depsgraph_get()
        light = Vector(metadata['light']['direction'])
        errors_uv, errors_b = [], []
        # Cast independent pixel-centre rays into flat faces. Compare their geometry
        # UVs / normals with the saved PNG. A gamma-converted atlas fails this check.
        for row in range(size):
            for col in range(size):
                if atlas[row, col, 3] != 255:
                    continue
                x = ((col + .5) / size - .5) * 3.05
                z = 1.465 + (.5 - (row + .5) / size) * 3.05
                hit, location, normal, face, ob, matrix = scene.ray_cast(graph, Vector((x, -8, z)), Vector((0, 1, 0)))
                if not hit:
                    continue
                evaluated = ob.evaluated_get(graph)
                data = evaluated.data
                polygon = data.polygons[face]
                if polygon.use_smooth or ob['part'] not in ('tunic', 'sleeves', 'shield_face', 'trousers'):
                    continue
                # Only compare pixels entirely inside one flat polygon. At a UV
                # seam or an overlapping mesh, a centre ray cannot predict the
                # integrated, dominant-island UV of the whole supersample block.
                interior = True
                for dx, dz in ((-.51, -.51), (-.51, .51), (.51, -.51), (.51, .51)):
                    corner = scene.ray_cast(graph, Vector((x + dx * 3.05 / size, -8, z + dz * 3.05 / size)), Vector((0, 1, 0)))
                    if not corner[0] or corner[4].name != ob.name or corner[3] != face:
                        interior = False
                        break
                if not interior:
                    continue
                # UV gradients on triangles/quads are piecewise affine. Choose the
                # containing fan triangle using barycentric weights, then interpolate.
                ids = list(polygon.loop_indices)
                for i in range(1, len(ids) - 1):
                    loops = [ids[0], ids[i], ids[i + 1]]
                    vertices = [matrix @ data.vertices[data.loops[j].vertex_index].co for j in loops]
                    weights = barycentric_transform(location, *vertices, Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
                    if min(weights) < -.0001:
                        continue
                    uv = sum((data.uv_layers.active.data[j].uv * w for j, w in zip(loops, weights)), Vector((0, 0)))
                    sampled = atlas[row, col].astype(float) / 255
                    # Exclude visible part boundaries where the dominant supersample
                    # surface may differ from the surface at the exact pixel centre.
                    if tuple((sampled[:2] * 4).astype(int)) != tuple((np.array(uv) * 4).astype(int)):
                        break
                    expected = (.5 + .5 * normal.dot(light)) * (.82 if ob['far_side'] else 1)
                    errors_uv.append(max(abs(sampled[:2] - np.array(uv))))
                    errors_b.append(abs(sampled[2] - expected))
                    break
        assert len(errors_uv) >= 15, len(errors_uv)
        assert np.percentile(errors_uv, 90) < .007, np.percentile(errors_uv, [50, 90, 100])
        assert np.percentile(errors_b, 90) < .007, np.percentile(errors_b, [50, 90, 100])
        result.update(ray_samples=len(errors_uv), ray_uv_error_p90=round(float(np.percentile(errors_uv, 90)), 5),
                      ray_shade_error_p90=round(float(np.percentile(errors_b, 90)), 5), model=stats,
                      loops_close=True, walk_legs_alternate=True, exact_hit_pose=True)
    print('VALIDATED', json.dumps(result, ensure_ascii=False), flush=True)
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=OUTPUT)
    parser.add_argument('--artifacts-only', action='store_true')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    verify(args.output, not args.artifacts_only)
