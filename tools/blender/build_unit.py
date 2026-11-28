"""Build a recipe from the chibi rig, a side-projected head and rigid silhouettes."""
import math

from mathutils import Matrix, Vector

import build_swordsman as base
from chibi_body import ChibiBody
from common import map_uv
from leg_pocket import build_pocket, guides
from unit_motion import POSES, posed, shuffle
from unit_spec import (BODIES, BOW_STRING_BONES, LANDMARKS, LEGACY_ACTIONS, MOUNT_PARENTS,
                       UNIT_ACTIONS, VECTORS, WEAPON_BONE, WIDTHS, animations, camera)

V = Vector


class Unit(ChibiBody):
    def __init__(self, spec):
        geometry = dict(spec, proportions=dict(landmarks_from_ground=LANDMARKS | spec.get('landmarks', {}),
                        widths=WIDTHS | spec.get('widths', {}), lean_degrees=0),
                        parts={key: {'uv_part': value} for key, value in spec['parts'].items()})
        super().__init__(geometry, BODIES[spec['body']][0])
        self.spec = spec
        self.neutral.update({k: self.control_value(k, v) for k, v in spec.get('neutral', {}).items()})
        self.lean = self.neutral['lean']
        self.mount = spec.get('mount')
        self.parents = MOUNT_PARENTS if self.mount else {}
        self.bow = spec.get('bow_string')
        self.near_shoulder_drop = spec.get('near_shoulder_drop', 0.) * self.height
        self.scattered = spec.get('scattered', {})
        self.has_dropped_weapon = WEAPON_BONE in self.scattered
        self.garment = None
        self.animations = animations(spec)
        self.camera = camera(spec)

    def control_value(self, channel, value):
        if channel in VECTORS:
            x, y, z = value
            return (x * self.height, y * self.height, self.ground + z * self.height)
        return value

    def pose_parameters(self, name, t, duration):
        fields = self.spec.get('actions', {}).get(name, {})
        pose = fields.get('pose', name if name in UNIT_ACTIONS else 'idle')
        pose = {'hit': 'hit_light', 'death': 'death_slash'}.get(pose, pose)
        phase = t / duration
        if pose == 'neutral':
            p = dict(self.neutral)
        elif pose == 'idle':
            p = dict(self.neutral)
            bob = math.sin(math.tau * t / duration)
            hip = V(p['hip'])
            hip.z += .004 * self.height * bob
            p.update(hip=tuple(hip), head_tilt=p['head_tilt'] + 2 * bob)
        elif pose == 'walk':
            p = shuffle(self, phase)
        elif pose in POSES or pose == 'stun':
            p = posed(self, pose, phase)
        else:
            legacy = 'death' if pose == 'death_slash' else pose
            authored_duration = LEGACY_ACTIONS[legacy][2]
            p = super().pose_parameters(legacy, phase * authored_duration, authored_duration)
            if pose == 'ragdoll':
                tuck = dict(hip=(0, 0, .72), foot_l=(.14, -.08, .69), foot_r=(.163, .08, .66),
                            wrist_l=(.06, -.24, .80), wrist_r=(.07, .23, .82))
                p.update({key: self.control_value(key, value) for key, value in tuck.items()})
        for channel, keys in fields.get('tracks', {}).items():
            value = base.blend([(q, {channel: v}) for q, v in keys], phase)[channel]
            p[channel] = self.control_value(channel, value)
        if fields.get('bone_scale'):
            p['bone_scale'] = {
                bone: base.blend([(q, {bone: value}) for q, value in keys], phase)[bone]
                for bone, keys in fields['bone_scale'].items()
            }
        if 'bow_draw' in fields:
            nock, release = fields['bow_draw']
            p['bow_drawn'] = fields['events'][nock] <= t < fields['events'][release]
        elif self.bow:
            p['bow_drawn'] = False
        p.setdefault('vertical_scale', 1.)
        if self.mount:
            gait = fields.get('mount_gait', 'shuffle' if pose == 'walk' else 'stand')
            p.update(mount_gait=gait, phase=phase, mounted_pose=pose)
        return p

    def skeleton(self, parameters):
        if self.mount:
            bones = self.mounted_skeleton(parameters)
        else:
            bones = super().skeleton(parameters)
        if self.has_dropped_weapon:
            bones[WEAPON_BONE] = bones['hand_r']
        if scales := parameters.get('bone_scale'):
            self.scale_bones(bones, scales)
        spread = parameters.get('spread', 0)
        feet = bones.copy() if parameters else None
        if spread:
            rest = self.skeleton({})
            for name, (x, y, z, pitch) in self.scattered.items():
                a, b = bones[name]
                start = a.lerp(V(self.control_value('hip', (x, y, z))), spread)
                direction = b - a
                rest_direction = rest[name][1] - rest[name][0]
                turn = Matrix.Rotation(math.radians(pitch), 3, 'Y') @ rest_direction
                direction = direction.slerp(turn, spread, turn)
                bones[name] = (start, start + direction)
        bones.update(guides(self, bones, feet, spread if 'root' in self.scattered else 0))
        if self.bow:
            bottom, nock, top = self.bow_points(bones, parameters)
            bones.update(zip(BOW_STRING_BONES, ((bottom, nock), (nock, top))))
        return bones

    def scale_bones(self, bones, scales):
        offsets = {'root': V((0, 0, 0))}
        for name, (start, end) in bones.items():
            offset = offsets[base.bone_parent(name, self.parents)]
            stretch = scales.get(name, 1.)
            rest_start, rest_end = base.REST[name]
            extension = (end - start).normalized() * ((rest_end - rest_start).length * (stretch - 1.))
            # The analytic tail defines the axis. The rig scales the mesh's rest length.
            bones[name] = (start + offset, start + offset + (end - start) * stretch)
            offsets[name] = offset + extension

    def bow_points(self, bones, parameters):
        def attachment(bone, offset):
            delta = V(offset) * self.height
            if not parameters:
                return bones[bone][0] + delta
            rest = base.bone_matrix(*base.REST[bone])
            local = rest.inverted().to_3x3() @ delta
            local.y *= parameters.get('bone_scale', {}).get(bone, 1.)
            return base.bone_matrix(*bones[bone]) @ local

        bow = self.bow
        bottom, top = (attachment(bow['bow_bone'], tip) for tip in bow['tips'])
        nock = bottom.lerp(top, .5)
        if parameters.get('bow_drawn'):
            nock = attachment(bow['draw_bone'], bow.get('draw_offset', (0, 0, 0)))
        return bottom, nock, top

    def mounted_skeleton(self, p):
        H, g = self.height, self.ground
        seat = self.mount.get('seat', .65)
        gait = p.get('mount_gait', 'stand')
        phase = math.tau * p.get('phase', 0)
        stride = self.mount.get('stride', .16) if gait != 'stand' else 0
        if gait == 'shuffle':
            stride *= .45
        bob = abs(math.sin(phase)) * stride * .16 if gait in ('trot', 'gallop') else 0
        rider = dict(self.neutral, **p)
        pose = p.get('mounted_pose', 'idle')
        for side, y in (('l', -.158), ('r', .158)):
            rider[f'foot_{side}'] = (.036 * H, y * H, g + .087 * H)
        offset = V((0, 0, (seat + bob) * H))
        bones = {name: (a + offset, b + offset)
                 for name, (a, b) in super().skeleton(rider).items()}

        def point(x, y, z):
            return V((x * H, y * H, g + (z + bob) * H))

        bones.update(mount_body=(point(-.12, 0, .49), point(.23, 0, .54)),
                     mount_head=(point(.25, 0, .66), point(.47, 0, .88)),
                     mount_tail=(point(-.45, 0, .64), point(-.67, 0, .39)))
        for leg, x in (('fore', .29), ('hind', -.33)):
            bend = .04 if leg == 'fore' else .06
            upper = math.hypot(.20, bend) * H
            lower = math.hypot(.115, bend) * H
            for side, y in (('l', -.13), ('r', .13)):
                lead = ((side == 'l') ^ (leg == 'hind')) if gait in ('shuffle', 'trot') else side == 'r'
                angle = phase + (math.pi if lead else 0) + (.65 if gait == 'gallop' and leg == 'hind' else 0)
                lift = max(0, math.sin(angle)) * stride * (.12 if gait == 'shuffle' else .5)
                prefix = f'mount_{leg}_{side}'
                hip = point(x, y, .37)
                hoof_z = .055 + lift - bob
                reach = math.sqrt(max(0, (upper + lower - .001)**2 - ((.37 - hoof_z) * H)**2)) / H
                dx = max(-reach, min(reach, math.cos(angle) * stride))
                hoof = point(x + dx, y, hoof_z)
                if leg == 'fore':
                    knee = hip + hoof - base.ik(hip, hoof, lower, upper)
                else:
                    knee = base.ik(hip, hoof, upper, lower)
                bones[prefix + '_upper'] = (hip, knee)
                bones[prefix + '_lower'] = (knee, hoof)
        if pose == 'knockback':
            displacement = V(p['hip']) - V(self.neutral['hip'])
            for name in MOUNT_PARENTS:
                a, b = bones[name]
                bones[name] = (a + displacement, b + displacement)
        if pose in ('fall', 'sit', 'rise', 'death_slash', 'death_pierce', 'death_crush', 'ragdoll'):
            # Keep mount and rider one silhouette through the existing same-atlas actions.
            knockdown, lean, tuck = .22 * H, p.get('lean', 0), p.get('tumble', 0)
            strength = min(1., abs(lean) / 86)
            pivot = V((0, 0, g + .55 * H))
            turn = Matrix.Rotation(math.radians(tuck + lean * .62), 3, 'Y')
            offset = V((0, 0, -knockdown * strength))
            if pose == 'ragdoll':
                offset.z = .53 * H
                # Remove the solo humanoid flip before turning the combined rig.
                neutral = self.skeleton({})
                bones.update({key: neutral[key] for key in neutral if not key.startswith('mount_')})
            bones = {name: (pivot + turn @ (a - pivot) + offset, pivot + turn @ (b - pivot) + offset)
                     for name, (a, b) in bones.items()}
        return bones

    def model(self):
        rest = base.REST
        offset = V((0, 0, self.mount.get('seat', .65) * self.height if self.mount else 0))
        if self.mount:
            base.REST = {name: (a - offset, b - offset) for name, (a, b) in rest.items()}
        style = self.spec.get('body_style', 'clothed')
        hood = self.spec.get('head', {}).get('garment')
        try:
            self.body_model(include_head=False, style=style, segmented_legs=False, include_clothing=hood is None)
            if hood:
                self.garment = self.joined_garment(hood)
            else:
                self.side_head()
        finally:
            base.REST = rest
        if self.mount:
            for obj in base.OBJECTS:
                for vertex in obj.data.vertices:
                    vertex.co += offset
        self.pocket = build_pocket(self, style)
        for name, piece in self.spec.get('pieces', {}).items():
            self.piece(name, piece)
        if self.bow:
            self.bow_string_model()
        self.body_objects = tuple(obj for obj in base.OBJECTS
                                  if self.spec.get('pieces', {}).get(obj.name, {}).get('bone', 'head') == 'head')
        if self.mount:
            self.mount_model()
        head_part = self.part('head')
        for obj in base.OBJECTS:
            if obj not in (self.pocket, self.garment) and obj['part'] == head_part and obj.name != 'side_projected_head':
                self.remap_v(obj, .02, .23)

    def bow_string_model(self):
        radius = self.bow['width'] * self.height / 2
        for name in BOW_STRING_BONES:
            start, end = base.REST[name]
            frame = base.bone_matrix(start, end)
            length = (end - start).length
            # Overlap the caps by half a string width at the shared nock.
            vertices = [frame @ V((x, y, z)) for z in (-radius, radius)
                        for y in (-radius, length + radius) for x in (-radius, radius)]
            faces = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4),
                     (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]
            base.mesh(name, vertices, faces, [[(.5, .5)] * 4] * 6, self.bow['part'], name)

    def joined_garment(self, rows):
        """Skin a closed hood and torso to the head and spine through the shoulder."""
        H, g = self.height, self.ground
        chin = (self.h['chin'] - g) / H
        head = self.spec['head']
        rings = []
        weights, head_vertices = [], []
        for z, back, front, depth in rows:
            bevel = (front - back) * .11
            ring = [(front, 0), (front - bevel, depth), (back + bevel, depth),
                    (back, 0), (back + bevel, -depth), (front - bevel, -depth)]
            rings.append((g + z * H, [(x * H, y * H) for x, y in ring]))
            t = min(1., max(0., (z - chin + .075) / .155))
            weights.extend([t * t * (3 - 2 * t)] * len(ring))
            if z >= chin - 1e-8:
                head_vertices.extend(range(len(weights) - len(ring), len(weights)))
        part = self.part('head')
        obj = self.profile('joined_hood_and_torso', rings, part, 'head')
        obj['head_vertices'] = head_vertices
        hood = obj.vertex_groups['head']
        spine = obj.vertex_groups.new(name='spine')
        for i, weight in enumerate(weights):
            if weight == 0:
                hood.remove([i])
            else:
                hood.add([i], weight, 'REPLACE')
            if weight < 1:
                spine.add([i], 1 - weight, 'REPLACE')
        for loop in obj.data.loops:
            co = obj.data.vertices[loop.vertex_index].co
            u = .5 + (co.x / H - head.get('x', .02)) / (2 * head.get('radius_x', .23))
            v = (co.z - self.h['chin']) / (self.h['helmet_top'] - self.h['chin'])
            v = .30 + .70 * v if v > 0 else .30 + .37 * v
            obj.data.uv_layers.active.data[loop.index].uv = map_uv(part, (min(1., max(0., u)), v))
        return obj

    def side_head(self):
        h, H = self.h, self.height
        head = self.spec.get('head', {})
        x = head.get('x', .02) * H
        rx = head.get('radius_x', self.width['head'] / H / 2) * H
        bottom, top = h['chin'], h['helmet_top']
        z, rz = (bottom + top) / 2, (top - bottom) / 2
        part = self.part('head')
        depth = head.get('depth', .18) * H
        if 'profile' in head:
            points = [(2 * rx * (u - .5), 2 * rz * (v - .5)) for u, v in head['profile']]
            obj = self.prism('side_projected_head', points, V((x, 0, z)), depth, part, 'head',
                             bevel=.87)
        else:
            obj = base.ellipsoid('side_projected_head', (x, 0, z),
                                 (rx, depth, rz), part, 'head', sides=10, bands=4, smooth=False)
        for loop in obj.data.loops:
            v = obj.data.vertices[loop.vertex_index].co
            # Separate the side-face projection from hands when both use skin.
            u = min(1., max(0., .5 + (v.x - x) / (2 * rx)))
            local_v = min(1., max(0., (v.z - bottom) / (2 * rz)))
            obj.data.uv_layers.active.data[loop.index].uv = map_uv(part, (u, .30 + .70 * local_v))

    def piece(self, name, piece):
        bone = piece['bone']
        H = self.height
        centre = base.REST[bone][0] + V(piece.get('offset', (0, 0, 0))) * H
        points = [(x * H, z * H) for x, z in piece['points']]
        self.prism(name, points, centre, piece['depth'] * H / 2, piece['part'], bone,
                   yaw=piece.get('yaw', 0), far=piece.get('far', False))

    @staticmethod
    def prism(name, points, centre, depth, part, bone, *, yaw=0, far=False, bevel=1):
        area = sum(x0 * z1 - x1 * z0 for (x0, z0), (x1, z1) in zip(points, points[1:] + points[:1]))
        if area < 0:
            points = points[::-1]
        count = len(points)
        turn = Matrix.Rotation(math.radians(yaw), 3, 'Z')
        rings = [(-depth, bevel), (depth, bevel)]
        if bevel < 1:
            rings[1:1] = [(-depth * .66, 1), (depth * .66, 1)]
        vertices = [centre + turn @ V((x * factor, y, z * factor))
                    for y, factor in rings for x, z in points]
        faces = [list(range(count)), list(reversed(range(len(vertices) - count, len(vertices))))]
        for row in range(len(rings) - 1):
            a = row * count
            for i in range(count):
                j = (i + 1) % count
                faces.append((a + j, a + i, a + i + count, a + j + count))
        # Front plane uses the full existing island. Edges and backs share its colour.
        lo_x, hi_x = min(x for x, _ in points), max(x for x, _ in points)
        lo_z, hi_z = min(z for _, z in points), max(z for _, z in points)
        uv = [((x - lo_x) / (hi_x - lo_x), (z - lo_z) / (hi_z - lo_z)) for x, z in points]
        return base.mesh(name, vertices, faces, [[uv[k % count] for k in face] for face in faces],
                         part, bone, far)

    def mount_model(self):
        H, g = self.height, self.ground
        parts = self.mount['parts']
        for name, centre, size, part, bone in (
                ('barrel', (-.04, 0, .49), (.46, .21, .28), 'body', 'mount_body'),
                ('neck', (.29, 0, .72), (.18, .12, .24), 'body', 'mount_head'),
                ('muzzle', (.47, 0, .86), (.21, .105, .12), 'face', 'mount_head'),
                ('mane', (.22, 0, .83), (.10, .133, .21), 'mane', 'mount_head'),
                ('ears', (.39, 0, .99), (.064, .069, .095), 'face', 'mount_head'),
                ('saddle', (-.05, 0, .74), (.25, .217, .07), 'tack', 'mount_body'),
                ('tail', (-.57, 0, .52), (.16, .07, .17), 'mane', 'mount_tail')):
            x, y, z = centre
            base.ellipsoid('horse_' + name, (x * H, y * H, g + z * H), tuple(v * H for v in size),
                           parts[part], bone, sides=6, bands=3, smooth=False)
        for leg in ('fore', 'hind'):
            for side in ('l', 'r'):
                for joint, width in (('upper', .078), ('lower', .049)):
                    bone = f'mount_{leg}_{side}_{joint}'
                    a, b = base.REST[bone]
                    base.segment(bone, a, b, width * H, parts['legs'], bone, side == 'r')
                base.box(f'horse_hoof_{leg}_{side}', b - V((0, 0, .016 * H)),
                         (.12 * H, .11 * H, .078 * H), parts['hooves'], bone, side == 'r')

    def build(self):
        bake_times, scaled_bones = {}, set()
        for name, _, duration, _, _ in self.animations:
            scales = self.spec.get('actions', {}).get(name, {}).get('bone_scale', {})
            if scales:
                scaled_bones.update(scales)
                bake_times[name] = [phase * duration for keys in scales.values() for phase, _ in keys]
        rig, stats = base.build(self.model, self.skeleton, self.pose_parameters, animation_specs=self.animations,
                                parents=self.parents, bake_times=bake_times, scaled_bones=scaled_bones,
                                span_bones=BOW_STRING_BONES if self.bow else ())
        if self.bow:
            nocked = self.bow.get('nocked_pieces', ())
            for obj in base.OBJECTS:
                if obj.name not in nocked:
                    continue
                for prop in ('hide_render', 'hide_viewport'):
                    driver = obj.driver_add(prop).driver
                    driver.type = 'SCRIPTED'
                    visible = driver.variables.new()
                    visible.name = 'drawn'
                    visible.type = 'SINGLE_PROP'
                    visible.targets[0].id = rig
                    visible.targets[0].data_path = '["bow_drawn"]'
                    driver.expression = '1 - drawn'
        assert stats['triangles'] <= self.spec['triangle_budget'], (self.spec['id'], stats)
        rig.name = self.spec['id'] + '_rig'
        return rig, stats
