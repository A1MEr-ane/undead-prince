"""Artifact and independent ray/UV/light verification. Run with Blender Python."""
import argparse
from collections import Counter
import json
import math
from pathlib import Path
import sys

import bpy
import numpy as np
from mathutils import Vector
from mathutils.geometry import barycentric_transform

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import ANIMATIONS, OUTPUT, PARTS, read_png, uv_rect


def verify(output, check_rig=True, spec_path=None):
    recipe = None
    if spec_path:
        from build_shieldman import from_spec
        recipe = from_spec(spec_path)
    prefix = recipe.spec['id'] if recipe else 'swordsman'
    metadata = json.loads((output / f'{prefix}_uv.json').read_text())
    assert metadata['format'] == 'swordsman_uv_v1'
    assert metadata['frame_size'] == [64, 64]
    assert metadata['columns'] == 8 and metadata['rows'] == 9
    assert metadata['image_size'] == [512, 576]
    assert list(metadata['part_texture']['regions']) == list(PARTS)
    assert list(metadata['animations']) == [a[0] for a in ANIMATIONS]
    for name, count, duration, loop, events in ANIMATIONS:
        animation = metadata['animations'][name]
        assert (animation['frame_count'], animation['duration'], animation['loop'], animation['events']) == (count, duration, loop, events)
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
    paint = read_png(output / metadata['part_texture']['image'])
    assert paint.shape == (512, 512, 4)
    if recipe:
        from shieldman_preview import paint_tile
        expected = [key for key, value in recipe.spec['looks'].items() if isinstance(value, dict)]
        assert [look['name'] for look in metadata['part_texture']['appearances']] == expected
        assert metadata['part_texture']['grid'] == [2, 2]
        assert metadata['part_texture']['tile_size'] == [256, 256]
        for i, look in enumerate(expected):
            assert (output / f'{prefix}_preview_{look}.png').is_file()
            x,y=(i%2)*256,(i//2)*256
            assert np.array_equal(paint[y:y+256,x:x+256], paint_tile(recipe.spec['looks'][look]))
        for name in ('uv', 'shading'):
            assert (output / f'{prefix}_preview_{name}.png').is_file()
        for name in ('front', 'side', 'back', 'equipped', 'equipped_side'):
            assert read_png(output / f'{prefix}_view_{name}.png').shape == (768, 768, 3)
    else:
        for name in ('militia', 'veteran', 'undead', 'elite', 'looks', 'uv', 'shading'):
            assert (output / f'preview_{name}.png').is_file()
    result['standing_alpha_bbox'] = bbox
    if check_rig:
        from build_swordsman import build, OBJECTS, REST, skeleton, pose_parameters
        if recipe:
            rig, stats = recipe.build()
            skeleton, pose_parameters = recipe.skeleton, recipe.pose_parameters
            assert stats == metadata['model']
            assert stats['triangles'] <= recipe.spec['triangle_budget']['max']
            validate_spec_model(recipe, rig, OBJECTS)
            validate_shield_poses(recipe, rig, OBJECTS)
        else:
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
        assert (tip - hand).normalized().x > .99
        assert hand.x > (recipe.neutral['wrist_r'][0] + .3 if recipe else .6)
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
    print('VALIDATED', prefix, json.dumps(result, ensure_ascii=False), flush=True)
    return result


def validate_spec_model(recipe, rig, objects):
    """Measure the built meshes and the baked walk, beyond checking config data."""
    by_name = {ob.name: ob for ob in objects}
    h = recipe.h
    def zs(name):
        return [v.co.z for v in by_name[name].data.vertices]
    for measured, expected in ((max(zs('helmet_dome')),h['helmet_top']),
                               (min(zs('helmet_brim')),h['helmet_brim']),
                               (min(zs('head')),h['chin']),
                               (min(zs('split_tabard_skirt')),h['tunic_hem']),
                               (max(zs('boot_cuff_l')),h['boot_top']),
                               (max(zs('tabard_body')),h['shoulder'])):
        assert abs(measured-expected) < 1e-5, (measured,expected)
    assert 'shield_boss' not in by_name
    assert len(by_name['helmet_dome'].data.vertices) == recipe.parts['helmet']['sides']*3
    diameter = max(zs('shield_rim'))-min(zs('shield_rim'))
    assert abs(diameter-recipe.parts['shield']['diameter']*recipe.height) < 1e-5
    assert by_name['shield_front']['bone'] == 'hand_l' and not by_name['shield_front']['far_side']
    assert by_name['forearm_l']['part'] == recipe.part('sleeves')
    assert by_name['forearm_r']['part'] == recipe.part('sleeves')
    duration=.667
    # Passing is highest, opposite arms/legs, no foot sliding while planted.
    contact=recipe.pose_parameters('walk',0,duration)
    passing=recipe.pose_parameters('walk',duration/4,duration)
    assert passing['hip'][2] > contact['hip'][2] + .02
    for side in ('l','r'):
        samples=[recipe.pose_parameters('walk',duration*i/32,duration) for i in range(33)]
        feet=np.array([p['foot_'+side][0] for p in samples])
        hands=np.array([p['wrist_'+side][0] for p in samples])
        assert np.corrcoef(feet,hands)[0,1] < -.99
    scene=bpy.context.scene
    rig.animation_data.action=bpy.data.actions['walk']
    rig.animation_data.action_slot=bpy.data.actions['walk'].slots[0]
    drift=[]
    for side,start in (('r',.02),('l',.52)):
        planted=[]
        for phase in np.linspace(start,start+.44,15):
            t=phase*duration
            scene.frame_set(int(t*1000+1),subframe=(t*1000+1)%1)
            bpy.context.view_layer.update()
            ankle=rig.pose.bones['foot_'+side].head.copy()
            planted.append(ankle+Vector((.8/duration*t,0,0)))
        drift.append(max((p-planted[0]).length for p in planted))
    assert max(drift) < .006, drift
    rig.animation_data.action=bpy.data.actions['idle']
    rig.animation_data.action_slot=bpy.data.actions['idle'].slots[0]
    scene.frame_set(1)
    print('SPEC_MODEL',recipe.spec['id'],'triangles='+str(sum(sum(len(p.vertices)-2 for p in ob.data.polygons) for ob in objects)),
          'walk_stance_drift='+str([round(d,6) for d in drift]),flush=True)


def validate_shield_poses(recipe, rig, objects):
    """Check baked shield orientation and the required pure-side visibility."""
    by_name = {ob.name: ob for ob in objects}
    scene = bpy.context.scene
    direction = Vector((0, 1, 0))
    poses, visibility = {}, []
    samples = [('idle', 0)] + [('walk', i*.667/8) for i in range(8)]
    samples += [('attack', .17), ('parry', .26)]
    for name, t in samples:
        action = bpy.data.actions[name]
        rig.animation_data.action = action
        rig.animation_data.action_slot = action.slots[0]
        scene.frame_set(int(t*1000+1), subframe=(t*1000+1)%1)
        graph = bpy.context.evaluated_depsgraph_get()
        front = by_name['shield_front'].evaluated_get(graph)
        normal = (front.matrix_world.to_3x3() @ front.data.polygons[0].normal).normalized()
        centre = front.matrix_world @ (sum((v.co for v in front.data.vertices), Vector()) / len(front.data.vertices))
        yaw = math.degrees(math.atan2(-normal.y, normal.x))
        poses[name] = (centre.copy(), yaw)
        fist = by_name['fist_l'].evaluated_get(graph)
        assert max((fist.matrix_world @ v.co-centre).dot(normal) for v in fist.data.vertices) < 0, (name, 'fist through shield')
        if name not in ('idle', 'walk'):
            continue
        assert abs(yaw-recipe.shield_yaw) < 1, (name, yaw)
        counts = Counter()
        for row in range(64):
            for col in range(64):
                x = ((col+.5)/64-.5)*3.05
                z = 1.465+(.5-(row+.5)/64)*3.05
                hit = scene.ray_cast(graph, Vector((x, -8, z)), direction)
                if not hit[0]:
                    continue
                counts[hit[4].name] += 1
                # Look behind the shield to catch it cutting into the head or
                # the stepping legs, even if some of those parts remain visible.
                if hit[4].name.startswith('shield_'):
                    for _ in range(4):
                        hit = scene.ray_cast(graph, hit[1]+direction*.0001, direction)
                        if not hit[0] or not hit[4].name.startswith('shield_'):
                            break
                    if hit[0]:
                        hidden = hit[4].name
                        assert hidden not in ('head', 'nose', 'short_hair', 'nasal_guard'), (name, t, hidden)
                        assert not hidden.startswith(('helmet_', 'thigh_', 'shin_', 'boot')), (name, t, hidden)
        visible = dict(upper_tunic=counts['tabard_body'], far_shoulder=counts['upper_arm_r'])
        for side in ('l', 'r'):
            visible['leg_'+side] = counts['thigh_'+side]+counts['shin_'+side]
            visible['boot_'+side] = sum(counts['boot'+segment+side] for segment in ('_', '_shaft_', '_cuff_'))
        assert visible['upper_tunic'] >= 16 and min(visible.values()) > 0, (name, t, visible)
        visibility.append(visible)
    idle, attack, parry = (poses[name] for name in ('idle', 'attack', 'parry'))
    assert recipe.h['belt'] < idle[0].z < recipe.h['shoulder']
    assert idle[0].x > .2
    assert attack[0].x < idle[0].x-.02, (idle, attack)
    assert parry[0].x > idle[0].x+.1 and 0 < parry[1] < idle[1]-15, (idle, parry)
    rig.animation_data.action = bpy.data.actions['idle']
    rig.animation_data.action_slot = bpy.data.actions['idle'].slots[0]
    scene.frame_set(1)
    print('SPEC_SHIELD', recipe.spec['id'], 'idle_yaw='+str(round(idle[1], 2)),
          'parry_yaw='+str(round(parry[1], 2)),
          'side_visible_min='+json.dumps({key: min(v[key] for v in visibility) for key in visibility[0]}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=OUTPUT)
    parser.add_argument('--artifacts-only', action='store_true')
    parser.add_argument('--spec', type=Path, help='Only validate this spec asset; default validates T06 and k2_shieldman')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    if args.spec:
        verify(args.output, not args.artifacts_only, args.spec)
    else:
        verify(args.output, not args.artifacts_only)
        from asset_spec import DEFAULT_SPEC
        verify(args.output, not args.artifacts_only, DEFAULT_SPEC)
