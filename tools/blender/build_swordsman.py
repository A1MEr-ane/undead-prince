"""Original procedural swordsman, rigid skinning, analytic IK and baked actions.

Run with Blender, or import build() from render_sprites.py. No external assets.
X = facing right, Y = depth (camera is -Y), Z = up.
"""
import argparse
import math
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import ANIMATIONS, OUTPUT, PARTS, map_uv

PI = math.pi
V = Vector
REST = {}
OBJECTS = []


def bone_matrix(a, b):
    """A stable sagittal-plane frame, including at a full ragdoll revolution."""
    a, b = V(a), V(b)
    y = (b - a).normalized()
    x = V((0, -1, 0))
    z = x.cross(y).normalized()
    x = y.cross(z).normalized()
    return Matrix((
        (x.x, y.x, z.x, a.x), (x.y, y.y, z.y, a.y),
        (x.z, y.z, z.z, a.z), (0, 0, 0, 1)))


def uv_material(far=False):
    mat = bpy.data.materials.new('UV_data_far' if far else 'UV_data_near')
    mat.use_nodes = True
    n, links = mat.node_tree.nodes, mat.node_tree.links
    n.clear()
    uv = n.new('ShaderNodeUVMap')
    split = n.new('ShaderNodeSeparateXYZ')
    links.new(uv.outputs['UV'], split.inputs[0])
    normal = n.new('ShaderNodeNewGeometry')
    dot = n.new('ShaderNodeVectorMath')
    dot.operation = 'DOT_PRODUCT'
    dot.inputs[1].default_value = V((.50, -.65, .70)).normalized()
    links.new(normal.outputs['Normal'], dot.inputs[0])
    shade = n.new('ShaderNodeMath')
    shade.operation = 'MULTIPLY_ADD'
    shade.inputs[1].default_value = .5
    shade.inputs[2].default_value = .5
    links.new(dot.outputs['Value'], shade.inputs[0])
    dim = n.new('ShaderNodeMath')
    dim.operation = 'MULTIPLY'
    dim.inputs[1].default_value = .82 if far else 1.0
    links.new(shade.outputs[0], dim.inputs[0])
    pack = n.new('ShaderNodeCombineXYZ')
    links.new(split.outputs['X'], pack.inputs['X'])
    links.new(split.outputs['Y'], pack.inputs['Y'])
    links.new(dim.outputs[0], pack.inputs['Z'])
    emission = n.new('ShaderNodeEmission')
    links.new(pack.outputs[0], emission.inputs['Color'])
    out = n.new('ShaderNodeOutputMaterial')
    links.new(emission.outputs[0], out.inputs['Surface'])
    return mat


def mesh(name, verts, faces, uvs, part, bone, far=False, smooth=False):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    layer = data.uv_layers.new(name='PartsUV')
    for polygon, face_uvs in zip(data.polygons, uvs):
        polygon.use_smooth = smooth
        for index, uv in zip(polygon.loop_indices, face_uvs):
            layer.data[index].uv = map_uv(part, uv)
    ob = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(MATERIALS[bool(far)])
    group = ob.vertex_groups.new(name=bone)
    group.add(list(range(len(verts))), 1.0, 'REPLACE')
    ob['part'] = part
    ob['bone'] = bone
    ob['far_side'] = far
    OBJECTS.append(ob)
    return ob


def tube(name, rings, part, bone, sides=6, far=False, smooth=False):
    """Rings are (centre, radius-X, radius-Y); seam at +X, U goes around Z."""
    verts = [(c[0] + rx * math.cos(2 * PI * i / sides),
              c[1] + ry * math.sin(2 * PI * i / sides), c[2])
             for c, rx, ry in rings for i in range(sides)]
    faces, uvs = [], []
    for j in range(len(rings) - 1):
        for i in range(sides):
            faces.append((j * sides + i, j * sides + (i + 1) % sides,
                          (j + 1) * sides + (i + 1) % sides, (j + 1) * sides + i))
            u0, u1 = i / sides, (i + 1) / sides
            v0, v1 = j / (len(rings) - 1), (j + 1) / (len(rings) - 1)
            uvs.append([(u0, v0), (u1, v0), (u1, v1), (u0, v1)])
    for j, reverse in ((0, True), (len(rings) - 1, False)):
        ids = list(range(j * sides, (j + 1) * sides))
        if reverse:
            ids.reverse()
        faces.append(ids)
        uvs.append([(.5 + .47 * math.cos(2 * PI * (i % sides) / sides),
                     .5 + .47 * math.sin(2 * PI * (i % sides) / sides)) for i in ids])
    return mesh(name, verts, faces, uvs, part, bone, far, smooth)


def ellipsoid(name, centre, radius, part, bone, sides=8, bands=4, far=False, smooth=True):
    # Real shared poles avoid invisible, extremely thin cap polygons.
    verts = [(centre[0], centre[1], centre[2] - radius[2])]
    for j in range(1, bands):
        angle = -PI / 2 + PI * j / bands
        for i in range(sides):
            theta = 2 * PI * i / sides
            verts.append((centre[0] + radius[0] * math.cos(angle) * math.cos(theta),
                          centre[1] + radius[1] * math.cos(angle) * math.sin(theta),
                          centre[2] + radius[2] * math.sin(angle)))
    top = len(verts)
    verts.append((centre[0], centre[1], centre[2] + radius[2]))
    faces, uvs = [], []
    for i in range(sides):
        u0, u1 = i / sides, (i + 1) / sides
        faces.append((0, 1 + (i + 1) % sides, 1 + i))
        uvs.append([((u0 + u1) / 2, 0), (u1, 1 / bands), (u0, 1 / bands)])
        for j in range(bands - 2):
            a, b = 1 + j * sides, 1 + (j + 1) * sides
            faces.append((a + i, a + (i + 1) % sides, b + (i + 1) % sides, b + i))
            uvs.append([(u0, (j + 1) / bands), (u1, (j + 1) / bands),
                        (u1, (j + 2) / bands), (u0, (j + 2) / bands)])
        a = 1 + (bands - 2) * sides
        faces.append((a + i, a + (i + 1) % sides, top))
        uvs.append([(u0, (bands - 1) / bands), (u1, (bands - 1) / bands), ((u0 + u1) / 2, 1)])
    return mesh(name, verts, faces, uvs, part, bone, far, smooth)


def box(name, centre, size, part, bone, far=False):
    x, y, z = centre
    a, b, c = [v / 2 for v in size]
    verts = [(x + dx * a, y + dy * b, z + dz * c)
             for dz in (-1, 1) for dy in (-1, 1) for dx in (-1, 1)]
    faces = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4),
             (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]
    return mesh(name, verts, faces, [[(0, 0), (1, 0), (1, 1), (0, 1)]] * 6, part, bone, far)


def segment(name, a, b, radius, part, bone, far=False):
    """Capped tapered hexagonal limb; correct longitudinal cylindrical UV."""
    a, b = V(a), V(b)
    m = bone_matrix(a, b)
    length = (b - a).length
    verts = []
    for j, r in ((0, radius), (1, radius * .80)):
        for i in range(6):
            q = 2 * PI * i / 6
            verts.append(tuple(m @ V((math.cos(q) * r, j * length, math.sin(q) * r))))
    faces, uvs = [], []
    for i in range(6):
        faces.append((i, 6 + i, 6 + (i + 1) % 6, (i + 1) % 6))
        uvs.append([(i / 6, 0), (i / 6, 1), ((i + 1) / 6, 1), ((i + 1) / 6, 0)])
    faces += [tuple(range(6)), tuple(reversed(range(6, 12)))]
    cap = [(.5 + .48 * math.cos(i * PI / 3), .5 + .48 * math.sin(i * PI / 3)) for i in range(6)]
    uvs += [cap, list(reversed(cap))]
    return mesh(name, verts, faces, uvs, part, bone, far)


def ik(hip, ankle, length_a=.43, length_b=.43):
    hip, ankle = V(hip), V(ankle)
    delta = ankle - hip
    distance = min(delta.length, length_a + length_b - .001)
    direction = delta.normalized()
    along = (length_a ** 2 - length_b ** 2 + distance ** 2) / (2 * distance)
    perpendicular = V((-direction.z, 0, direction.x)).normalized()
    return hip + along * direction + math.sqrt(max(0, length_a ** 2 - along ** 2)) * perpendicular


def lerp(a, b, t):
    if isinstance(a, (tuple, list)):
        return tuple(x + (y - x) * t for x, y in zip(a, b))
    return a + (b - a) * t


def blend(points, time):
    """Piecewise smooth authored poses; rotations are kept unwrapped."""
    if time <= points[0][0]:
        return dict(points[0][1])
    for (t0, a), (t1, b) in zip(points, points[1:]):
        if time <= t1:
            t = (time - t0) / (t1 - t0)
            t = t * t * (3 - 2 * t)
            return {k: lerp(a[k] if k in a else DEFAULT[k], b[k] if k in b else DEFAULT[k], t)
                    for k in a.keys() | b.keys()}
    return dict(points[-1][1])


# Local world-space targets: elbows are derived by two-bone IK, wrists are authored.
DEFAULT = dict(hip=(0, 0, .95), lean=0., head_tilt=0.,
               foot_l=(.07, .15, .12), foot_r=(-.07, -.15, .12),
               wrist_r=(.30, -.30, 1.23), wrist_l=(.38, .23, 1.19),
               sword=35., shield=0., tumble=0.)
SITTING = dict(hip=(-.20, 0, .34), lean=-18.,
               foot_l=(.43, .15, .12), foot_r=(.61, -.15, .12),
               wrist_r=(.27, -.30, .49), wrist_l=(.25, .24, .65), sword=76., shield=12.)
LYING = dict(hip=(-.21, 0, .30), lean=-86., head_tilt=-6.,
             foot_l=(.57, .16, .12), foot_r=(.62, -.16, .12),
             wrist_r=(-.10, -.31, .22), wrist_l=(.02, .24, .43), sword=91., shield=72.)


def pose_parameters(name, t, duration):
    if name == 'idle':
        s = math.sin(2 * PI * t / duration)
        return dict(hip=(0, 0, .95 + .012 * s), lean=1.0 * s,
                    wrist_r=(.30 + .008 * s, -.30, 1.23 + .012 * s), sword=35 + 2 * s)
    if name == 'walk':
        phase = t / duration
        def foot(p, y):
            # First half-cycle is the left swing; second half is the right.
            p %= 1
            if p < .5:
                a = p * 2
                return (-.25 + .5 * a, y, .12 + .15 * math.sin(PI * a))
            return (.25 - .5 * (p - .5) * 2, y, .12)
        s = math.sin(2 * PI * phase)
        return dict(hip=(.025 * s, 0, .91 + .035 * math.cos(4 * PI * phase)), lean=6.,
                    foot_l=foot(phase, .15), foot_r=foot(phase + .5, -.15),
                    wrist_r=(.30 - .07 * s, -.30, 1.23),
                    wrist_l=(.38 + .04 * s, .23, 1.18), sword=35 - 8 * s)
    if name == 'attack':
        return blend([
            (0, {}),
            (.17, dict(hip=(-.08, 0, .90), lean=-12., wrist_r=(-.18, -.30, 1.72), sword=-50.,
                       foot_l=(.15, .15, .12), foot_r=(-.19, -.15, .12))),
            (.25, dict(hip=(-.05, 0, .92), lean=-5., wrist_r=(.01, -.30, 1.78), sword=-24.)),
            (.333, dict(hip=(.10, 0, .89), lean=19., wrist_r=(.64, -.32, 1.32), sword=88.,
                        foot_l=(.27, .15, .12), foot_r=(-.17, -.15, .12))),
            (.41, dict(hip=(.13, 0, .86), lean=24., wrist_r=(.51, -.32, .91), sword=135.,
                       foot_l=(.27, .15, .12), foot_r=(-.17, -.15, .12))),
            (.60, {})], t)
    if name == 'parry':
        return blend([(0, {}), (.13, dict(hip=(-.06, 0, .90), lean=-8., shield=-15.)),
                      (.26, dict(hip=(.04, 0, .89), lean=8., wrist_l=(.70, .23, 1.36), shield=-20.,
                                 wrist_r=(.17, -.31, 1.31), sword=9.)),
                      (.39, dict(hip=(-.04, 0, .87), lean=-10., wrist_l=(.57, .23, 1.34), shield=-8.)),
                      (.65, {})], t)
    if name == 'clash':
        return blend([(0, dict(wrist_r=(.56, -.30, 1.46), sword=47., lean=12.)),
                      (.10, dict(hip=(-.11, 0, .90), lean=-18., wrist_r=(.02, -.30, 1.65), sword=-25.)),
                      (.23, dict(hip=(-.07, 0, .90), lean=-9., wrist_r=(.13, -.30, 1.38), sword=4.)),
                      (.35, {})], t)
    if name == 'fall':
        return blend([(0, {}), (.11, dict(hip=(-.12, 0, .83), lean=-27.,
                                        wrist_r=(.30, -.30, 1.38), sword=54.)),
                      (.23, dict(hip=(-.24, 0, .49), lean=-41.,
                                 foot_l=(.37, .15, .18), foot_r=(.48, -.15, .15),
                                 wrist_r=(.14, -.30, .79), sword=68.)),
                      (.35, SITTING)], t)
    if name == 'sit':
        p = dict(SITTING)
        s = math.sin(2 * PI * t / duration)
        p['lean'] += 2 * s
        p['head_tilt'] = 5 + 3 * s
        return p
    if name == 'rise':
        return blend([(0, SITTING), (.18, dict(hip=(-.11, 0, .39), lean=24.,
                          foot_l=(.35, .15, .12), foot_r=(-.08, -.15, .12),
                          wrist_r=(.30, -.30, .50), sword=85., wrist_l=(.37, .23, .56))),
                      (.37, dict(hip=(.01, 0, .57), lean=33., foot_l=(.30, .15, .12),
                          foot_r=(-.16, -.15, .12), wrist_r=(.41, -.30, .78), sword=57.)),
                      (.60, dict(hip=(.04, 0, .84), lean=16., foot_l=(.20, .15, .12),
                          foot_r=(-.14, -.15, .12))), (.74, {}), (.833, {})], t)
    if name == 'death':
        return blend([(0, {}), (.10, dict(hip=(-.05, 0, .90), lean=-20., sword=60.)),
                      (.25, dict(hip=(-.16, 0, .61), lean=-48.,
                          foot_l=(.35, .15, .12), foot_r=(.41, -.15, .12),
                          wrist_r=(.04, -.31, .60), sword=87.)),
                      (.39, dict(hip=(-.21, 0, .36), lean=-72.,
                          foot_l=(.52, .15, .12), foot_r=(.60, -.15, .12),
                          wrist_r=(-.30, -.31, .29), sword=91.)),
                      (.486, LYING), (.583, LYING)], t)
    if name == 'ragdoll':
        return dict(hip=(0, 0, 1.45), lean=-65., head_tilt=42.,
                    foot_l=(.30, .15, 1.28), foot_r=(.36, -.15, 1.24),
                    wrist_r=(-.13, -.30, 1.68), wrist_l=(-.03, .23, 1.68),
                    sword=132., shield=-20., tumble=360 * t / duration)
    if name == 'hit':
        return blend([(0, dict(hip=(-.09, 0, .91), lean=-19., head_tilt=-12.,
                              wrist_r=(.21, -.30, 1.29), sword=14.)),
                      (.167, dict(hip=(-.03, 0, .93), lean=-7., sword=23.))], t)
    raise ValueError(name)


def skeleton(parameters):
    p = dict(DEFAULT)
    p.update(parameters)
    hip = V(p['hip'])
    rotation = Matrix.Rotation(math.radians(p['lean']), 3, 'Y')
    def body(offset):
        return hip + rotation @ V(offset)
    spine, neck = body((0, 0, .04)), body((.015, 0, .55))
    head_rotation = Matrix.Rotation(math.radians(p['lean'] + p['head_tilt']), 3, 'Y')
    bones = {'root': (hip, body((0, 0, .16))), 'spine': (spine, neck),
             'head': (neck, neck + head_rotation @ V((0, 0, .33)))}
    for suffix, y in (('l', .15), ('r', -.15)):
        h = hip + V((0, y, 0))
        ankle = V(p['foot_' + suffix])
        knee = ik(h, ankle)
        bones['thigh_' + suffix] = (h, knee)
        bones['shin_' + suffix] = (knee, ankle)
        bones['foot_' + suffix] = (ankle, ankle + V((.16, 0, -.025)))
    for suffix, y in (('l', .24), ('r', -.24)):
        shoulder = body((0, y, .49))
        wrist = V(p['wrist_' + suffix])
        # Bend elbows down and back; total reach accommodates the authored lunge.
        elbow = ik(shoulder, wrist, .34, .34)
        # The IK helper picks the forward knee branch; arms use the other branch.
        midpoint = (shoulder + wrist) / 2
        elbow = midpoint * 2 - elbow
        angle = math.radians(p['sword'] if suffix == 'r' else 18 + p['shield'])
        direction = V((math.sin(angle), 0, math.cos(angle)))
        bones['upper_arm_' + suffix] = (shoulder, elbow)
        bones['forearm_' + suffix] = (elbow, wrist)
        bones['hand_' + suffix] = (wrist, wrist + direction * .14)
    if p['tumble']:
        r = Matrix.Rotation(math.radians(p['tumble']), 3, 'Y')
        bones = {k: (hip + r @ (a - hip), hip + r @ (b - hip)) for k, (a, b) in bones.items()}
    return bones


def make_rig(parents=None):
    data = bpy.data.armatures.new('SwordsmanSkeleton')
    rig = bpy.data.objects.new('SwordsmanRig', data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    for name, (a, b) in REST.items():
        bone = data.edit_bones.new(name)
        bone.head, bone.tail = a, b
        bone.matrix = bone_matrix(a, b)
        if name == 'root':
            continue
        parent = 'root'
        if name == 'head' or name.startswith('upper_arm_'):
            parent = 'spine'
        elif name.startswith('forearm_'):
            parent = 'upper_arm_' + name[-1]
        elif name.startswith('hand_'):
            parent = 'forearm_' + name[-1]
        elif name.startswith('shin_'):
            parent = 'thigh_' + name[-1]
        elif name.startswith('foot_'):
            parent = 'shin_' + name[-1]
        bone.parent = data.edit_bones[(parents or {}).get(name, parent)]
    bpy.ops.object.mode_set(mode='OBJECT')
    rig.show_in_front = True
    for ob in OBJECTS:
        modifier = ob.modifiers.new('Rigid bone weights', 'ARMATURE')
        modifier.object = rig
        ob.parent = rig
    return rig


def model():
    tube('coat', [((0, 0, .89), .21, .205), ((0, 0, 1.02), .16, .17),
                  ((0, 0, 1.40), .205, .235), ((.015, 0, 1.48), .17, .215)], 'tunic', 'spine')
    tube('coat_flared_hem', [((0, 0, .81), .25, .25), ((0, 0, 1.02), .17, .18)], 'tunic', 'root')
    tube('hem_trim', [((0, 0, .805), .252, .252), ((0, 0, .855), .24, .24)], 'cloth_trim', 'root')
    tube('belt', [((0, 0, 1.00), .185, .19), ((0, 0, 1.07), .185, .19)], 'leather', 'spine')
    box('belt_buckle', (.185, -.035, 1.035), (.035, .11, .065), 'belt_buckle', 'spine')
    tube('collar', [((.015, 0, 1.46), .135, .145), ((.015, 0, 1.54), .13, .14)], 'cloth_trim', 'head')
    ellipsoid('head', (.04, 0, 1.76), (.218, .198, .246), 'skin', 'head', sides=10, bands=5)
    ellipsoid('nose', (.249, -.01, 1.78), (.072, .077, .065), 'skin', 'head', sides=6, bands=2)
    tube('helmet_dome', [((.025, 0, 1.86), .245, .225), ((.025, 0, 2.00), .22, .20),
                         ((-.01, 0, 2.105), .08, .09), ((-.01, 0, 2.12), .025, .03)], 'helmet', 'head', sides=8)
    tube('helmet_edge', [((.025, 0, 1.855), .252, .235), ((.025, 0, 1.90), .252, .235)], 'metal', 'head', sides=8)
    box('nasal_guard', (.278, -.005, 1.80), (.028, .055, .20), 'helmet', 'head')
    box('eye_near', (.219, -.133, 1.827), (.039, .025, .027), 'eye', 'head')
    box('eye_far', (.219, .133, 1.827), (.039, .025, .027), 'eye', 'head', True)
    for suffix, y in (('l', .15), ('r', -.15)):
        far = suffix == 'l'
        for segment_name, part, r in (('thigh_', 'trousers', .105), ('shin_', 'trousers', .078),
                                       ('upper_arm_', 'sleeves', .102), ('forearm_', 'skin', .077)):
            bone = segment_name + suffix
            segment(bone, *REST[bone], r, part, bone, far)
        ankle = REST['foot_' + suffix][0]
        tube('boot_' + suffix, [((ankle.x + .035, y, .035), .155, .092),
                                ((ankle.x + .035, y, .13), .15, .09),
                                ((ankle.x, y, .27), .076, .077)], 'boots', 'foot_' + suffix, far=far)
        wrist = REST['hand_' + suffix][0]
        ellipsoid('hand_' + suffix, wrist, (.082, .078, .09), 'skin', 'hand_' + suffix,
                  sides=6, bands=2, far=far)
    # The sword is built in the hand frame; diamond cross-section creates a readable ridge.
    a, b = REST['hand_r']
    m = bone_matrix(a, b)
    verts = []
    for longitudinal, width in ((.07, .047), (.64, .037), (.80, .001)):
        for x, z in ((0, -width), (.019, 0), (0, width), (-.019, 0)):
            verts.append(tuple(m @ V((x, longitudinal, z))))
    faces, uvs = [], []
    for j in range(2):
        for i in range(4):
            faces.append((j * 4 + (i + 1) % 4, j * 4 + i,
                          (j + 1) * 4 + i, (j + 1) * 4 + (i + 1) % 4))
            u0, u1 = (0, .5) if i in (0, 3) else (.5, 1)
            uvs.append([(u1, j * .78), (u0, j * .78), (u0, min(1, (j + 1) * .78)),
                        (u1, min(1, (j + 1) * .78))])
    mesh('sword_blade', verts, faces, uvs, 'blade', 'hand_r')
    # Crossguard lies in the image plane, perpendicular to blade direction.
    ob = box('sword_guard', (0, 0, 0), (.21, .045, .045), 'metal', 'hand_r')
    for vertex in ob.data.vertices:
        q = vertex.co.copy()
        vertex.co = m @ V((q.y, .055 + q.z, q.x))
    segment('sword_grip', m @ V((0, -.12, 0)), m @ V((0, .045, 0)), .035, 'leather', 'hand_r')
    ellipsoid('pommel', m @ V((0, -.14, 0)), (.045, .045, .045), 'hilt', 'hand_r', sides=6, bands=2)
    # Shield front points partly towards +X, mostly towards the camera. Its back is thick.
    wrist = REST['hand_l'][0]
    normal = V((.32, -.948, 0)).normalized()
    horizontal = V((.948, .32, 0)).normalized()
    centre = wrist + V((.08, -.03, 0))
    n = 12
    verts = []
    for radius, depth in ((.278, -.045), (.31, -.02), (.31, .045), (.267, .055)):
        for i in range(n):
            angle = 2 * PI * i / n
            verts.append(tuple(centre + horizontal * (radius * math.cos(angle)) +
                               V((0, 0, radius * math.sin(angle))) + normal * depth))
    faces, uvs = [], []
    for j in range(3):
        for i in range(n):
            ids = (j * n + i, j * n + (i + 1) % n, (j + 1) * n + (i + 1) % n, (j + 1) * n + i)
            faces.append(ids)
            uvs.append([(.5 + .49 * math.cos(2 * PI * (k % n) / n),
                         .5 + .49 * math.sin(2 * PI * (k % n) / n)) for k in ids])
    mesh('shield_rim', verts, faces, uvs, 'shield_rim', 'hand_l')
    for front, depth, part in ((True, .057, 'shield_face'), (False, -.046, 'shield_back')):
        verts = [tuple(centre + normal * depth)]
        coords = [(.5, .5)]
        for i in range(n):
            angle = 2 * PI * i / n
            verts.append(tuple(centre + normal * depth + horizontal * (.267 * math.cos(angle)) +
                               V((0, 0, .267 * math.sin(angle)))))
            coords.append((.5 + .49 * math.cos(angle), .5 + .49 * math.sin(angle)))
        faces = [(0, 1 + i, 1 + (i + 1) % n) for i in range(n)]
        if not front:
            faces = [tuple(reversed(f)) for f in faces]
        mesh('shield_front' if front else 'shield_back', verts, faces,
             [[coords[k] for k in f] for f in faces], part, 'hand_l')
    ellipsoid('shield_boss', centre + normal * .065, (.065, .043, .065), 'metal', 'hand_l', sides=6, bands=2)


def apply_pose(rig, parameters, keyframe=None, skeleton_fn=None):
    if 'vertical_scale' in parameters:
        rig.scale.z = parameters['vertical_scale']
        if keyframe is not None:
            rig.keyframe_insert(data_path='scale', index=2, frame=keyframe, group='Body')
    bones = (skeleton_fn or skeleton)(parameters)
    # Blender pose matrices depend on evaluated parents. Assign in hierarchy order.
    for bone in rig.data.bones:
        pb = rig.pose.bones[bone.name]
        pb.rotation_mode = 'QUATERNION'
        matrix = bone_matrix(*bones[bone.name])
        yaw = parameters.get('bone_yaws', {}).get(bone.name, 0.)
        if yaw:
            pivot = Matrix.Translation(bones[bone.name][0])
            matrix = pivot @ Matrix.Rotation(math.radians(yaw), 4, 'Z') @ pivot.inverted() @ matrix
        pb.matrix = matrix
        bpy.context.view_layer.update()
        if keyframe is not None:
            for prop in ('location', 'rotation_quaternion', 'scale'):
                pb.keyframe_insert(data_path=prop, frame=keyframe, group=bone.name)


def build(model_builder=None, skeleton_fn=None, pose_fn=None, bake_times=None,
          *, animation_specs=None, parents=None):
    global REST, MATERIALS
    # Optional .blend export must not write thumbnails outside the chosen output.
    # This is only an in-memory preference; user settings are never saved.
    bpy.context.preferences.filepaths.file_preview_type = 'NONE'
    OBJECTS.clear()
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    # A validation process builds several recipes in one Blender scene. Avoid
    # reusing the previous rig's Actions through Blender's .001 name suffixes.
    for name, *_ in animation_specs or ANIMATIONS:
        previous = bpy.data.actions.get(name)
        if previous:
            bpy.data.actions.remove(previous)
    MATERIALS = {False: uv_material(False), True: uv_material(True)}
    REST = (skeleton_fn or skeleton)({})
    (model_builder or model)()
    rig = make_rig(parents)
    scene = bpy.context.scene
    scene.render.fps = 1000
    for name, count, duration, loop, events in animation_specs or ANIMATIONS:
        rig.animation_data_create()
        rig.animation_data.action = bpy.data.actions.new(name)
        # Millisecond timeline retains the precise .333 s attack event.
        times = ([i * duration / count for i in range(count)] if loop else
                 [i * duration / (count - 1) for i in range(count)])
        if not animation_specs and name == 'attack':
            times = [0, .085, .17, .25, .333, .41, .50, .60]
        if not animation_specs and name == 'parry':
            times = [0, .09, .18, .26, .35, .44, .54, .65]
        if animation_specs:
            from unit_spec import sample_times
            times = sample_times(name, count, duration, loop, events)
        extra = (bake_times or {}).get(name, [])
        for t in sorted(set(times + ([duration] if loop else []) + list(events.values()) + extra)):
            apply_pose(rig, (pose_fn or pose_parameters)(name, t, duration), t * 1000 + 1, skeleton_fn)
        action = rig.animation_data.action
        action['sample_times'] = times
        action['duration'] = duration
        action['loop'] = loop
        action.use_fake_user = True
        for event, t in events.items():
            action.pose_markers.new(event).frame = round(t * 1000 + 1)
        # Linear interpolation between baked millisecond poses avoids Bezier overshoot.
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points:
                            key.interpolation = 'LINEAR'
    rig.animation_data.action = bpy.data.actions['idle']
    scene.frame_set(1)
    counts = dict(objects=len(OBJECTS), bones=len(rig.data.bones),
                  polygons=sum(len(ob.data.polygons) for ob in OBJECTS),
                  triangles=sum(sum(len(p.vertices) - 2 for p in ob.data.polygons) for ob in OBJECTS))
    print('PROCEDURAL_MODEL', counts, flush=True)
    return rig, counts


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--save', type=Path, default=OUTPUT / 'swordsman.blend')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    build()
    args.save.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(args.save))
