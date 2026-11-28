"""Render one recipe pose for visual inspection. Draft helper, not part of the pipeline."""
import argparse
from pathlib import Path
import sys

import bpy
from mathutils import Vector

TOOLS = Path(__file__).resolve().parents[4] / 'tools/blender'
sys.path.insert(0, str(TOOLS))

from asset_spec import load_spec
from build_unit import Unit
from render_sprites import setup_scene


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--spec', type=Path, required=True)
    parser.add_argument('--action', required=True)
    parser.add_argument('--time', type=float, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--size', type=int, default=512)
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    spec = load_spec(args.spec)
    recipe = Unit(spec)
    rig, _ = recipe.build()
    size, ortho, target_z, margin = recipe.camera
    scene = setup_scene(size, 2, 4, ortho, target_z)
    action = bpy.data.actions[args.action]
    rig.animation_data.action = action
    rig.animation_data.action_slot = action.slots[0]
    frame = args.time * 1000 + 1
    scene.frame_set(int(frame), subframe=frame % 1)
    bpy.context.view_layer.update()
    # Lift only penetrations, matching the sprite renderer.
    graph = bpy.context.evaluated_depsgraph_get()
    points = [ob.evaluated_get(graph).matrix_world @ Vector(v)
              for ob in bpy.data.objects if ob.type == 'MESH'
              for v in ob.evaluated_get(graph).bound_box]
    lo = min(p.z for p in points)
    if args.action != 'ragdoll' and lo < .035:
        rig.location.z = .035 - lo
        bpy.context.view_layer.update()
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.film_transparent = False
    scene.world.color = (.06, .09, .08)
    scene.render.filepath = str(args.output)
    bpy.ops.render.render(write_still=True)
    # Print the vertical extents that matter for the overhead-fist review.
    graph = bpy.context.evaluated_depsgraph_get()
    for name in ('side_projected_head', 'fist_wrap_l', 'fist_wrap_r',
                 'upper_arm_l', 'forearm_l', 'hand_l'):
        ob = bpy.data.objects.get(name)
        if not ob:
            continue
        zs = [(ob.evaluated_get(graph).matrix_world @ v.co).z for v in ob.evaluated_get(graph).data.vertices]
        print(f'BOUND {name} z={min(zs):.3f}..{max(zs):.3f}', flush=True)


if __name__ == '__main__':
    main()
