"""Build, animate, render and preview the entire swordsman asset in one command.

blender -b --factory-startup -P tools/blender/render_sprites.py -- --supersample 8
"""
import argparse
import json
import math
from pathlib import Path
import sys
import tempfile
import time

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import ANIMATIONS, OUTPUT, PARTS, PART_SIZE, uv_rect, write_png
from build_swordsman import build, OBJECTS


def setup_scene(size, supersample, threads, ortho=3.05, target_z=1.465):
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 1
    scene.cycles.use_denoising = False
    scene.cycles.seed = 19
    scene.cycles.use_animated_seed = False
    scene.cycles.pixel_filter_type = 'BOX'
    scene.render.filter_size = .01
    scene.render.threads_mode = 'FIXED'
    scene.render.threads = threads
    scene.render.resolution_x = scene.render.resolution_y = size * supersample
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'OPEN_EXR'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.image_settings.color_depth = '32'
    scene.view_settings.view_transform = 'Raw'
    scene.view_settings.look = 'None'
    scene.view_settings.exposure = 0
    scene.view_settings.gamma = 1
    scene.render.use_compositing = False
    scene.render.use_sequencer = False
    scene.world.color = (0, 0, 0)
    data = bpy.data.cameras.new('SideOrthographic')
    data.type = 'ORTHO'
    data.ortho_scale = ortho
    camera = bpy.data.objects.new('SideOrthographic', data)
    bpy.context.collection.objects.link(camera)
    camera.location = (0, -8, target_z)
    camera.rotation_euler = (Vector((0, 0, target_z)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
    scene.camera = camera
    return scene


def downsample(raw, size, factor):
    """Resolve coverage, but never interpolate RG between unrelated part islands.

    One Cycles sample per supersample pixel gives unmixed surface data. Within
    each output pixel select its dominant part island, then average that island's
    UVs only. Alpha and B still integrate all covered samples. Background RGB=0.
    """
    blocks = raw.reshape(size, factor, size, factor, 4).transpose(0, 2, 1, 3, 4).reshape(size, size, factor * factor, 4)
    alpha = blocks[..., 3]
    # EXR pixels are premultiplied. With one sample alpha is normally 0 or 1.
    straight = np.divide(blocks[..., :3], alpha[..., None], out=np.zeros_like(blocks[..., :3]), where=alpha[..., None] > 1e-7)
    region = np.minimum(3, (straight[..., 0] * 4).astype(int)) + 4 * np.minimum(3, (straight[..., 1] * 4).astype(int))
    votes = np.stack([(alpha * (region == i)).sum(axis=2) for i in range(16)], axis=-1)
    dominant = votes.argmax(axis=-1)
    weight = alpha * (region == dominant[..., None])
    result = np.zeros((size, size, 4), np.float32)
    result[..., :2] = (straight[..., :2] * weight[..., None]).sum(axis=2) / np.maximum(weight.sum(axis=2)[..., None], 1e-8)
    result[..., 2] = (straight[..., 2] * alpha).sum(axis=2) / np.maximum(alpha.sum(axis=2), 1e-8)
    result[..., 3] = alpha.mean(axis=2)
    return np.round(np.clip(result, 0, 1) * 255).astype(np.uint8)


def bounds():
    graph = bpy.context.evaluated_depsgraph_get()
    points = [ob.evaluated_get(graph).matrix_world @ Vector(v)
              for ob in OBJECTS for v in ob.evaluated_get(graph).bound_box]
    return [min(p[i] for p in points) for i in range(3)], [max(p[i] for p in points) for i in range(3)]


def run(args):
    start = time.monotonic()
    args.output.mkdir(parents=True, exist_ok=True)
    recipe = None
    unit_spec = None
    if args.spec:
        from asset_spec import load_spec
        spec = load_spec(args.spec)
        if spec.get('recipe') == 'unit':
            from build_unit import Unit
            recipe = Unit(spec)
            unit_spec = spec
        else:
            from build_shieldman import from_spec
            recipe = from_spec(args.spec)
        rig, model_stats = recipe.build()
    else:
        rig, model_stats = build()
    prefix = recipe.spec['id'] if recipe else 'swordsman'
    size = args.size
    ortho, target_z, margin = 3.05, 1.465, size * .095 / 3.05
    actions = ANIMATIONS
    if unit_spec:
        from unit_spec import event_frame
        size, ortho, target_z, margin = recipe.camera
        actions = recipe.animations
    scene = setup_scene(size, args.supersample, args.threads, ortho, target_z)
    total = sum(count for _, count, *_ in actions)
    rows = math.ceil(total / 8)
    atlas = np.zeros((rows * size, 8 * size, 4), np.uint8)
    animations, frame_records = {}, []
    index = 0
    with tempfile.TemporaryDirectory(prefix='swordsman-') as directory:
        exr = str(Path(directory) / 'linear.exr')
        for name, count, duration, loop, events in actions:
            action = bpy.data.actions[name]
            rig.animation_data.action = action
            rig.animation_data.action_slot = action.slots[0]
            samples = list(action['sample_times'])
            animations[name] = dict(start_frame=index, frame_count=count, duration=duration, loop=loop,
                frame_duration=duration / count, events=events,
                event_frames={key: index + (event_frame(t, count, duration) if unit_spec else
                               min(count - 1, int(t / duration * count))) for key, t in events.items()},
                source_sample_times=samples)
            for local, t in enumerate(samples):
                scene.frame_set(int(t * 1000 + 1), subframe=(t * 1000 + 1) % 1)
                rig.location = (0, 0, 0)
                bpy.context.view_layer.update()
                lo, hi = bounds()
                # Grounded actions can dip slightly through the floor at contact.
                # Only lift penetrations; never recenter or rescale individual poses.
                lift = max(0, .035 - lo[2]) if name != 'ragdoll' else 0
                rig.location.z = lift
                bpy.context.view_layer.update()
                lo, hi = bounds()
                if unit_spec:
                    limit = ortho * (.5 - 1 / size)
                    assert -limit < lo[0] <= hi[0] < limit and target_z - limit < lo[2] <= hi[2] < target_z + limit, (
                        f'{prefix} {name}[{local}]: pose exceeds camera; adjust tracks or framing', lo, hi)
                else:
                    assert lo[0] > -1.49 and hi[0] < 1.49 and lo[2] > -.05 and hi[2] < 2.95, (name, local, lo, hi)
                scene.render.filepath = exr
                bpy.ops.render.render(write_still=True)
                img = bpy.data.images.load(exr, check_existing=False)
                dim = size * args.supersample
                values = np.empty(dim * dim * 4, np.float32)
                img.pixels.foreach_get(values)
                raw = values.reshape(dim, dim, 4)[::-1].copy()
                bpy.data.images.remove(img)
                rgba = downsample(raw, size, args.supersample)
                row, column = divmod(index, 8)
                x, y = column * size, row * size
                atlas[y:y + size, x:x + size] = rgba
                occupied = np.argwhere(rgba[..., 3] > 0)
                frame_records.append(dict(index=index, animation=name, local_frame=local,
                    rect=[x, y, size, size], source_time=t,
                    alpha_bbox=[int(occupied[:, 1].min()), int(occupied[:, 0].min()),
                                int(occupied[:, 1].max() + 1), int(occupied[:, 0].max() + 1)],
                    ground_lift=round(lift, 6)))
                print(f'SPRITE {index + 1}/{total} {name}[{local}] t={t:.3f}', flush=True)
                index += 1
    rig.location = (0, 0, 0)
    rig.animation_data.action = bpy.data.actions['idle']
    rig.animation_data.action_slot = bpy.data.actions['idle'].slots[0]
    scene.frame_set(1)
    write_png(args.output / f'{prefix}_uv.png', atlas)
    metadata = dict(format='swordsman_uv_v1', image=f'{prefix}_uv.png',
        frame_size=[size, size], columns=8, rows=rows, total_frames=total,
        image_size=[8 * size, rows * size], order='row_major', image_origin='top_left',
        channels=dict(R='part UV.u, linear UNORM8', G='part UV.v, linear UNORM8, bottom-left UV origin',
                      B='(0.5 + 0.5 * dot(world_normal, light_direction)) * side_factor',
                      A='linear coverage, straight alpha'),
        color_space='linear data; no sRGB, gamma, ICC, tone mapping or premultiplied storage',
        sampling=dict(atlas='nearest; no mipmaps; disable sRGB; clamp each frame',
                      parts='bilinear; decode parts_preview RGB from sRGB to linear before lighting',
                      brightness='multiply linear parts RGB by 2 * B; B=0.5 is neutral',
                      antialiasing='supersample, dominant UV island, coverage alpha'),
        coordinates=dict(model_forward='+X', camera_side='-Y', model_up='+Z',
                         camera_pitch_degrees=0, orthographic_size=ortho, camera_target_z=target_z,
                         game_vertical_compensation=1.154700538,
                         standing_foot_anchor_pixels=[size / 2, size - margin]),
        light=dict(direction=list(Vector((.50, -.65, .70)).normalized()), near_side_factor=1., far_limb_factor=.82),
        render=dict(engine='Cycles CPU', samples=1, supersample=args.supersample,
                    color_management='Raw, exposure 0, gamma 1; float EXR intermediate'),
        part_texture=dict(image='parts_preview.png', tile_size=[PART_SIZE, PART_SIZE], grid=[2, 2],
                          uv_origin='bottom_left_within_appearance', region_grid=[4, 4], padding_pixels=4,
                          regions={name: dict(cell=[x, y], uv_rect=uv_rect(name), description=description)
                                   for name, (x, y, description) in PARTS.items()}),
        animations=animations, frames=frame_records, model=model_stats)
    if unit_spec:
        from unit_preview import create_previews
        from unit_spec import presentation
        metadata['recipe_sha256'] = unit_spec['_sha256']
        metadata['presentation'] = presentation(unit_spec, size, ortho)
        create_previews(atlas, metadata, args.output, unit_spec)
    elif recipe:
        from shieldman_preview import create_previews, render_views
        create_previews(atlas, metadata, args.output, recipe.spec)
    else:
        from preview import create_previews
        create_previews(atlas, metadata, args.output)
    metadata['validation'] = validate(atlas, metadata, total if unit_spec else 69)
    (args.output / f'{prefix}_uv.json').write_text(json.dumps(metadata, indent=2, ensure_ascii=False) + '\n')
    if args.save_blend:
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_as_mainfile(filepath=str(args.output / f'{prefix}.blend'))
    if recipe and not unit_spec and not args.skip_views:
        render_views(rig, recipe, args.output, args.threads)
        if args.compare_with:
            from shieldman_preview import create_comparison
            create_comparison(args.compare_with,args.output,prefix)
    print('COMPLETE', json.dumps(metadata['validation']), f'{time.monotonic() - start:.1f}s', flush=True)


def validate(atlas, metadata, expected_total=69):
    covered = atlas[..., 3] > 0
    edge = (atlas[..., 3] > 0) & (atlas[..., 3] < 255)
    uv = atlas[..., :2][covered] / 255.
    assert metadata['total_frames'] == expected_total
    assert edge.sum() > 0, 'Expected antialiased coverage'
    assert not (atlas[~covered] != 0).any(), 'Transparent data must be zero'
    # Every covered UV must be inside one padded region (UNORM quantization tolerance).
    cells = uv * 4 % 1
    assert (cells >= .04).all() and (cells <= .96).all(), 'UVs crossed part-region padding'
    assert len({tuple(x) for x in atlas[..., :2][covered]}) > 500, 'Expected continuous UV gradients'
    return dict(covered_pixels=int(covered.sum()), antialiased_pixels=int(edge.sum()),
                shade_range=[int(atlas[..., 2][covered].min()), int(atlas[..., 2][covered].max())],
                all_frames_inside_cell=True, uv_islands_valid=True, transparent_rgb_zero=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--size', type=int, default=64)
    parser.add_argument('--supersample', type=int, choices=(2, 4, 8), default=8)
    parser.add_argument('--threads', type=int, default=4)
    parser.add_argument('--output', type=Path, default=OUTPUT)
    parser.add_argument('--save-blend', action='store_true', help='Optional inspectable rig/actions; not needed at runtime')
    parser.add_argument('--skip-views', action='store_true', help='Skip optional 768px legacy model views')
    parser.add_argument('--spec', type=Path, help='Asset YAML; output files use spec.id')
    parser.add_argument('--compare-with', type=Path, help='Preserved v4 equipped side PNG for an old/new review sheet')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    run(args)
