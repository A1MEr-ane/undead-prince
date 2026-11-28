"""Build a recipe from the chibi rig, a side-projected head and rigid silhouettes."""
import math

from mathutils import Matrix, Vector

import build_swordsman as base
from chibi_body import ChibiBody
from common import map_uv
from unit_spec import (BASE_ACTIONS, BODIES, LANDMARKS, MOUNT_PARENTS, VECTORS, WIDTHS,
                       animations, camera)

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
        self.animations = animations(spec)
        self.camera = camera(spec)

    def control_value(self, channel, value):
        if channel in VECTORS:
            x, y, z = value
            return (x * self.height, y * self.height, self.ground + z * self.height)
        return value

    def pose_parameters(self, name, t, duration):
        fields = self.spec.get('actions', {}).get(name, {})
        pose = fields.get('pose', name if name in BASE_ACTIONS else 'idle')
        if pose == 'idle':
            p = dict(self.neutral)
            bob = math.sin(math.tau * t / duration)
            hip = V(p['hip'])
            hip.z += .004 * self.height * bob
            p.update(hip=tuple(hip), head_tilt=p['head_tilt'] + 2 * bob)
        else:
            authored_duration = BASE_ACTIONS[pose][2]
            if pose == 'walk':
                authored_duration = duration
            p = super().pose_parameters(pose, t / duration * authored_duration, authored_duration)
        phase = t / duration
        for channel, keys in fields.get('tracks', {}).items():
            value = base.blend([(q, {channel: v}) for q, v in keys], phase)[channel]
            p[channel] = self.control_value(channel, value)
        if self.mount:
            gait = fields.get('mount_gait', self.mount.get('pace', 'trot') if name == 'walk' else 'stand')
            p.update(mount_gait=gait, phase=phase, mounted_pose=pose)
        return p

    def skeleton(self, parameters):
        if self.mount:
            return self.mounted_skeleton(parameters)
        return super().skeleton(parameters)

    def mounted_skeleton(self, p):
        H, g = self.height, self.ground
        seat = self.mount.get('seat', .65)
        gait = p.get('mount_gait', 'stand')
        phase = math.tau * p.get('phase', 0)
        stride = self.mount.get('stride', .16) if gait != 'stand' else 0
        bob = abs(math.sin(phase)) * stride * .16
        rider = dict(self.neutral, **p)
        pose = p.get('mounted_pose', 'idle')
        for side, y in (('l', -.22), ('r', .22)):
            rider[f'foot_{side}'] = (.04 * H, y * H, g - .28 * H)
        offset = V((0, 0, (seat + bob) * H))
        bones = {name: (a + offset, b + offset)
                 for name, (a, b) in super().skeleton(rider).items()}

        def point(x, y, z):
            return V((x * H, y * H, g + (z + bob) * H))

        bones.update(mount_body=(point(-.12, 0, .57), point(.23, 0, .62)),
                     mount_head=(point(.25, 0, .66), point(.47, 0, .88)),
                     mount_tail=(point(-.45, 0, .64), point(-.67, 0, .39)))
        for leg, x in (('fore', .29), ('hind', -.33)):
            for side, y in (('l', -.13), ('r', .13)):
                lead = ((side == 'r') ^ (leg == 'hind')) if gait == 'trot' else side == 'r'
                angle = phase + (math.pi if lead else 0) + (.65 if gait == 'gallop' and leg == 'hind' else 0)
                dx = math.cos(angle) * stride
                lift = max(0, math.sin(angle)) * stride * .5
                prefix = f'mount_{leg}_{side}'
                hip = point(x, y, .54)
                knee = point(x + dx * .45 + (.06 if leg == 'hind' else -.03), y, .27 + lift * .45)
                hoof = point(x + dx, y, .055 + lift - bob)
                bones[prefix + '_upper'] = (hip, knee)
                bones[prefix + '_lower'] = (knee, hoof)
        if pose in ('fall', 'sit', 'rise', 'death', 'ragdoll'):
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
        try:
            self.body_model(include_head=False)
            self.side_head()
        finally:
            base.REST = rest
        if self.mount:
            for obj in base.OBJECTS:
                for vertex in obj.data.vertices:
                    vertex.co += offset
        for name, piece in self.spec.get('pieces', {}).items():
            self.piece(name, piece)
        if self.mount:
            self.mount_model()

    def side_head(self):
        h, H = self.h, self.height
        head = self.spec.get('head', {})
        x = head.get('x', .02) * H
        rx = head.get('radius_x', .205) * H
        bottom, top = h['chin'], h['helmet_top']
        z, rz = (bottom + top) / 2, (top - bottom) / 2
        part = self.part('head')
        obj = base.ellipsoid('side_projected_head', (x, 0, z),
                             (rx, head.get('depth', .18) * H, rz), part, 'head', sides=10, bands=4,
                             smooth=False)
        for loop in obj.data.loops:
            v = obj.data.vertices[loop.vertex_index].co
            # Separate the side-face projection from hands when both use skin.
            u = min(1., max(0., .5 + (v.x - x) / (2 * rx)))
            local_v = min(1., max(0., (v.z - bottom) / (2 * rz)))
            obj.data.uv_layers.active.data[loop.index].uv = map_uv(part, (u, .30 + .70 * local_v))

    def piece(self, name, piece):
        bone = piece['bone']
        H = self.height
        points = [tuple(p) for p in piece['points']]
        area = sum(x0 * z1 - x1 * z0 for (x0, z0), (x1, z1) in zip(points, points[1:] + points[:1]))
        assert abs(area) > 1e-6, f'{name}: zero-area contour'
        if area < 0:
            points.reverse()
        count = len(points)
        centre = base.REST[bone][0] + V(piece.get('offset', (0, 0, 0))) * H
        turn = Matrix.Rotation(math.radians(piece.get('yaw', 0)), 3, 'Z')
        depth = piece['depth'] / 2
        vertices = [centre + turn @ V((x * H, y * H, z * H))
                    for y in (-depth, depth) for x, z in points]
        faces = [list(range(count)), list(reversed(range(count, count * 2)))]
        for i in range(count):
            j = (i + 1) % count
            faces.append((j, i, i + count, j + count))
        # Front plane uses the full existing island. Edges and backs share its colour.
        lo_x, hi_x = min(x for x, _ in points), max(x for x, _ in points)
        lo_z, hi_z = min(z for _, z in points), max(z for _, z in points)
        uv = [((x - lo_x) / (hi_x - lo_x), (z - lo_z) / (hi_z - lo_z)) for x, z in points]
        base.mesh(name, vertices, faces, [[uv[k % count] for k in face] for face in faces],
                  piece['part'], bone, piece.get('far', False))

    def mount_model(self):
        H, g = self.height, self.ground
        parts = self.mount['parts']
        for name, centre, size, part, bone in (
                ('barrel', (-.04, 0, .59), (.46, .18, .20), 'body', 'mount_body'),
                ('neck', (.29, 0, .72), (.18, .12, .24), 'body', 'mount_head'),
                ('muzzle', (.47, 0, .86), (.21, .105, .12), 'face', 'mount_head'),
                ('mane', (.22, 0, .83), (.10, .133, .21), 'mane', 'mount_head'),
                ('ears', (.39, 0, .99), (.064, .069, .095), 'face', 'mount_head'),
                ('saddle', (-.05, 0, .76), (.25, .187, .07), 'tack', 'mount_body'),
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
        rig, stats = base.build(self.model, self.skeleton, self.pose_parameters, animation_specs=self.animations,
                                parents=MOUNT_PARENTS if self.mount else None)
        assert stats['triangles'] <= self.spec['triangle_budget'], (self.spec['id'], stats)
        rig.name = self.spec['id'] + '_rig'
        return rig, stats
