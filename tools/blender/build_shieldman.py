"""Kingdom shieldman recipe: normalized asset spec -> mesh and the T06 rig.

No changes to common.PARTS, animation samples, events, or the runtime contract.
Geometry is rigid low poly; hidden joint caps are omitted to spend triangles on
the dome, face, split tabard and shield silhouette.
"""
import math

from mathutils import Matrix, Vector

import build_swordsman as base
from asset_spec import load_spec

V = Vector
PI = math.pi


class Shieldman:
    def __init__(self, spec):
        self.spec = spec
        self.height = 2.12  # Same standing size and camera as swordsman_uv_v1.
        self.h = {k: v * self.height for k, v in spec['proportions']['landmarks_from_ground'].items()}
        self.width = {k: v * self.height for k, v in spec['proportions']['widths'].items()
                      if isinstance(v, (int, float))}
        self.hand = spec['proportions']['hand_size'] * self.height
        self.lean = spec['proportions']['lean_degrees']
        self.parts = spec['parts']
        self.neutral = dict(hip=(0, 0, self.h['belt']), lean=0., head_tilt=0.,
                            foot_l=(.035, -.22, .12), foot_r=(-.035, .22, .12),
                            wrist_l=(.14, -.49, 1.00), wrist_r=(.11, .36, .96),
                            sword=115., shield=0., tumble=0.)

    def part(self, name, key='uv_part'):
        return self.parts[name][key]

    def skeleton(self, parameters):
        p = dict(self.neutral)
        p.update(parameters)
        hip = V(p['hip'])
        rotation = Matrix.Rotation(math.radians(p['lean']), 3, 'Y')
        def body(offset):
            return hip + rotation @ V(offset)
        shoulder_height = self.h['shoulder'] - self.h['belt']
        neck = body((.015, 0, self.h['chin'] - self.h['belt']))
        head_rotation = Matrix.Rotation(math.radians(p['lean'] + p['head_tilt']), 3, 'Y')
        bones = {'root': (hip, body((0, 0, .16))),
                 'spine': (body((0, 0, .04)), neck),
                 'head': (neck, neck + head_rotation @ V((0, 0, .33)))}
        for suffix, y in (('l', -.16), ('r', .16)):
            h = hip + V((0, y, 0))
            ankle = V(p['foot_' + suffix])
            length = (self.h['belt'] - .12 + .010) / 2
            knee = base.ik(h, ankle, length, length)
            bones['thigh_' + suffix] = (h, knee)
            bones['shin_' + suffix] = (knee, ankle)
            bones['foot_' + suffix] = (ankle, ankle + V((.16, 0, -.025)))
        shoulder_y = self.width['shoulders'] / 2 - .14
        for suffix, y in (('l', -shoulder_y), ('r', shoulder_y)):
            shoulder = body((0, y, shoulder_height))
            wrist = V(p['wrist_' + suffix])
            elbow = shoulder + wrist - base.ik(shoulder, wrist, .31, .31)
            angle = math.radians(p['sword'] if suffix == 'r' else 18 + p['shield'])
            direction = V((math.sin(angle), 0, math.cos(angle)))
            bones['upper_arm_' + suffix] = (shoulder, elbow)
            bones['forearm_' + suffix] = (elbow, wrist)
            bones['hand_' + suffix] = (wrist, wrist + direction * .14)
        if p['tumble']:
            r = Matrix.Rotation(math.radians(p['tumble']), 3, 'Y')
            bones = {k: (hip + r @ (a - hip), hip + r @ (b - hip)) for k, (a, b) in bones.items()}
        return bones

    def pose_parameters(self, name, t, duration):
        old = dict(base.DEFAULT)
        old.update(base.pose_parameters(name, t, duration))
        p = dict(self.neutral)
        for key in ('hip', 'foot_l', 'foot_r', 'wrist_l', 'wrist_r'):
            delta = V(old[key]) - V(base.DEFAULT[key])
            # Keep authored sagittal poses; exchange depth so the shield is near.
            delta.y *= -1
            p[key] = tuple(V(self.neutral[key]) + delta)
        p.update(lean=old['lean'] + self.lean, head_tilt=old['head_tilt'],
                 shield=old['shield'], tumble=old['tumble'])
        # The original key poses survive; only the relaxed sword points down.
        rest_weight = max(0., 1 - abs(old['sword'] - base.DEFAULT['sword']) / 35)
        p['sword'] = old['sword'] + 80 * rest_weight
        if name == 'idle':
            s = math.sin(2 * PI * t / duration)
            p['wrist_l'] = (.14, -.49, 1.00 + .012 * s)
        if name == 'attack':
            guard = math.sin(PI * min(1., t / .41)) if t <= .41 else 0.
            p['wrist_l'] = (.14 + .055 * guard, -.49, 1.00 + .07 * guard)
        if name == 'walk':
            phase = t / duration
            stride = .40
            def foot(q, y):
                q %= 1
                if q < .5:
                    a = q * 2
                    return (-stride / 2 + stride * a, y, .12 + .14 * math.sin(PI * a))
                return (stride / 2 - stride * (q - .5) * 2, y, .12)
            # Each passing pose is highest; the stance sole moves backwards at
            # constant speed. Translating the root at stride/(T/2) plants it.
            bob = .030 * (1 - math.cos(4 * PI * phase)) / 2
            p.update(hip=(0, 0, self.h['belt'] - .035 + bob), lean=self.lean,
                     foot_l=foot(phase, -.22), foot_r=foot(phase + .5, .22))
            for side in ('l', 'r'):
                x, y, z = self.neutral['wrist_' + side]
                leg_x = p['foot_' + side][0]
                p['wrist_' + side] = (x - .22 * leg_x, y, z + bob - .035)
            p['sword'] = 115.
        return p

    def profile(self, name, rings, part, bone, cap_bottom=True, cap_top=True, far=False):
        """rings = [(z, [(x,y), ...]), ...], counterclockwise from above."""
        n = len(rings[0][1])
        vertices = [(x, y, z) for z, ring in rings for x, y in ring]
        faces, uv = [], []
        for j in range(len(rings) - 1):
            for i in range(n):
                faces.append((j*n+i, j*n+(i+1)%n, (j+1)*n+(i+1)%n, (j+1)*n+i))
                uv.append([(i/n, j/(len(rings)-1)), ((i+1)/n, j/(len(rings)-1)),
                           ((i+1)/n, (j+1)/(len(rings)-1)), (i/n, (j+1)/(len(rings)-1))])
        for j, cap in ((0, cap_bottom), (len(rings)-1, cap_top)):
            if cap:
                ids = list(range(j*n, (j+1)*n))
                if j == 0:
                    ids.reverse()
                faces.append(ids)
                uv.append([(.5 + .45*math.cos(2*PI*i/n), .5 + .45*math.sin(2*PI*i/n)) for i in ids])
        return base.mesh(name, vertices, faces, uv, part, bone, far)

    @staticmethod
    def rectangle(rx, ry, x=0):
        return [(x+rx, -ry), (x+rx, ry), (x-rx, ry), (x-rx, -ry)]

    @staticmethod
    def octagon(rx, ry, x=0):
        return [(x+rx*a, ry*b) for a, b in ((1,-.65),(1,.65),(.65,1),(-.65,1),
                                                        (-1,.65),(-1,-.65),(-.65,-1),(.65,-1))]

    def limb(self, name, radius, part, far):
        a, b = base.REST[name]
        matrix = base.bone_matrix(a, b)
        length = (b-a).length
        vertices = [tuple(matrix @ V((sx*radius*r, j*length, sz*radius*r)))
                    for j, r in ((0, 1), (1, .86)) for sx, sz in ((1,-1),(-1,-1),(-1,1),(1,1))]
        faces = [(i, (i+1)%4, 4+(i+1)%4, 4+i) for i in range(4)]
        base.mesh(name, vertices, faces, [[(i/4,0),((i+1)/4,0),((i+1)/4,1),(i/4,1)]
                                         for i in range(4)], part, name, far)

    def model(self):
        h = self.h
        self.profile('tabard_body', [(h['belt'], self.rectangle(.16, .22)),
                     (h['shoulder'], self.rectangle(.15, .255))], self.part('tunic'), 'spine', False, True)
        # Open side shell with V notches on the front and back lower edges.
        hem, belt = h['tunic_hem'], h['belt'] + .015
        vertices = []
        for x in (.19, -.19):
            vertices += [(x,-.29,hem),(x,-.035,hem),(x,0,hem+.15),(x,.035,hem),
                         (x,.29,hem),(x*.84,.22,belt),(x*.84,-.22,belt)]
        front = tuple(range(7))
        faces = [front, tuple(reversed(range(7,14))), (0,6,13,7), (4,11,12,5)]
        uv = [[((vertices[k][1]+.30)/.60, (vertices[k][2]-hem)/(belt-hem)) for k in f] for f in faces]
        # Front is +X; reverse if its projected polygon winds inward.
        base.mesh('split_tabard_skirt', vertices, faces, uv, self.part('tunic'), 'root')
        belt_ob = self.profile('belt', [(h['belt']-.032, self.rectangle(.17,.232)),
                              (h['belt']+.035, self.rectangle(.17,.232))], self.part('belt'), 'spine', False, False)
        self.leather_uv(belt_ob)
        base.box('belt_buckle', (.184,0,h['belt']), (.035,.13,.10), self.part('belt','buckle_uv_part'), 'spine')
        self.profile('collar', [(h['shoulder']-.012,self.octagon(.13,.17,.015)),
                               (h['chin']+.020,self.octagon(.13,.17,.015))], self.part('collar'), 'head', False, True)
        rx, ry = self.width['head']*.405, self.width['head']*.395
        self.profile('head', [(h['chin'],self.octagon(rx*.82,ry*.82,.025)),
                             (h['helmet_brim']+.03,self.octagon(rx,ry,.025))], self.part('head'), 'head', True, False)
        # Hair covers only the rear half of the head, leaving the face open.
        ring = self.octagon(rx*1.025,ry*1.025,.020)
        verts = [(x,y,z) for z in (h['chin']+.025,h['helmet_brim']+.02) for x,y in ring]
        faces = [(i,i+1,i+9,i+8) for i in range(2,6)]
        hair = base.mesh('short_hair',verts,faces,[[(0,.76),(1,.76),(1,.98),(0,.98)]]*4,'leather','head')
        for side, sign in (('l',-1),('r',1)):
            # Small ears and sideburns are simple blocks under the brim.
            base.box('ear_'+side,(-.015,sign*(ry+.020),h['eye']-.055),(.11,.065,.13),self.part('head'),'head')
            burn=base.box('sideburn_'+side,(.11,sign*(ry+.009),h['eye']-.006),(.085,.022,.16),'leather','head')
            self.leather_uv(burn, hair=True)
            # Eye/eyebrow lie on the diagonal front cheek, visible in both views.
            x0, y0 = .025+rx*.91, sign*ry*.78
            tangent = V((-.65,sign*.76,0))
            centre = V((x0,y0,h['eye']))
            for name,z,width,height in (('eye',0,.058,.075),('brow',.058,.105,.022)):
                c=centre+V((.002,sign*.002,z))
                vv=[tuple(c+tangent*dx+V((0,0,dz))) for dx,dz in
                    ((-width/2,-height/2),(width/2,-height/2),(width/2,height/2),(-width/2,height/2))]
                base.mesh(name+'_'+side,vv,[(0,1,2,3)],[[(0,0),(1,0),(1,1),(0,1)]],self.part('eyes'),'head',side=='r')
        # A small triangular wedge nose, with the tip forward of the nasal guard.
        vertices=[(rx+.025,-.065,h['eye']-.09),(rx+.025,.065,h['eye']-.09),
                  (rx+.025,0,h['eye']+.025),(rx+.14,0,h['eye']-.06)]
        faces=[(0,1,2),(0,3,1),(0,2,3),(1,3,2)]
        base.mesh('nose',vertices,faces,[[(0,0),(1,0),(.5,1)]]*4,self.part('head'),'head')
        sides = self.parts['helmet']['sides']
        dome=[]
        for z,r in ((h['helmet_brim'],.48),(h['helmet_brim']+(h['helmet_top']-h['helmet_brim'])*.58,.41),
                    (h['helmet_top'],.10)):
            dome.append((z,[(self.width['head']*r*math.cos(2*PI*i/sides),
                             self.width['head']*r*math.sin(2*PI*i/sides)) for i in range(sides)]))
        self.profile('helmet_dome',dome,self.part('helmet'),'head',False,True)
        self.profile('helmet_brim',[(h['helmet_brim'],self.octagon(self.width['head']/2,self.width['head']/2)),
                                   (h['helmet_brim']+.080,self.octagon(self.width['head']/2,self.width['head']/2))],
                     self.part('helmet','rim_uv_part'),'head',True,True)
        base.box('nasal_guard',(self.width['head']/2+.008,0,h['eye']+.03),(.043,.085,.24),self.part('helmet'),'head')
        for suffix,y in (('l',-.22),('r',.22)):
            far=suffix=='r'
            for segment,part,radius in (('thigh_',self.part('legs'),.085),('shin_',self.part('legs'),.073),
                                       ('upper_arm_',self.part('sleeves'),.097),('forearm_',self.part('sleeves'),.081)):
                self.limb(segment+suffix,radius,part,far)
            ankle=base.REST['foot_'+suffix][0]
            rings=[(.035,self.rectangle(.20,.11,ankle.x+.065)),
                   (.18,self.rectangle(.115,.10,ankle.x+.012))]
            rings=[(z,[(x,yy+y) for x,yy in r]) for z,r in rings]
            self.profile('boot_'+suffix,rings,self.part('boots'),'foot_'+suffix,True,False,far)
            knee=base.REST['shin_'+suffix][0]
            def shin_at(z):
                return ankle+(knee-ankle)*((z-ankle.z)/(knee.z-ankle.z))
            shaft=[]
            for z in (.13,h['boot_top']-.02):
                c=shin_at(z)
                shaft.append((z,[(x,yy+c.y) for x,yy in self.rectangle(.092,.108,c.x)]))
            self.profile('boot_shaft_'+suffix,shaft,self.part('boots'),'shin_'+suffix,False,False,far)
            cuff_centre=shin_at(h['boot_top']-.035)
            cuff=[(z,[(x,yy+cuff_centre.y) for x,yy in self.rectangle(.118,.125,cuff_centre.x)])
                  for z in (h['boot_top']-.075,h['boot_top'])]
            self.profile('boot_cuff_'+suffix,cuff,self.part('boots'),'shin_'+suffix,False,True,far)
            wrist=base.REST['hand_'+suffix][0]
            base.box('fist_'+suffix,wrist,(self.hand*.82,self.hand*.84,self.hand),self.part('hands'),'hand_'+suffix,far)
        self.sword()
        self.shield()

    @staticmethod
    def leather_uv(ob, hair=False):
        from common import uv_rect
        u0,v0,u1,v1=uv_rect('leather')
        for loop in ob.data.uv_layers.active.data:
            v=(loop.uv.y-v0)/(v1-v0)
            loop.uv.y=v0+(v1-v0)*((.76+.22*v) if hair else (.05+.50*v))

    def sword(self):
        a,b=base.REST['hand_r']
        m=base.bone_matrix(a,b)
        length=self.parts['sword']['blade_length']*self.height
        verts=[]
        for z,w in ((.07,.062),(.07+length*.87,.048)):
            verts += [tuple(m @ V((x,z,y))) for x,y in ((0,-w),(.018,0),(0,w),(-.018,0))]
        verts.append(tuple(m @ V((0,.07+length,0))))
        faces=[(i,(i+1)%4,4+(i+1)%4,4+i) for i in range(4)]
        faces += [(4+i,4+(i+1)%4,8) for i in range(4)]
        uv=[[(0,0),(1,0),(1,.87),(0,.87)]]*4 + [[(0,.87),(1,.87),(.5,1)]]*4
        base.mesh('sword_blade',verts,faces,uv,self.part('sword','blade_uv_part'),'hand_r')
        guard=base.box('sword_guard',(0,0,0),(.28,.055,.055),self.part('sword','guard_uv_part'),'hand_r')
        for vertex in guard.data.vertices:
            q=vertex.co.copy()
            vertex.co=m @ V((q.y,.045+q.z,q.x))
        grip=base.box('sword_grip',(0,0,0),(.052,.17,.052),self.part('sword','grip_uv_part'),'hand_r')
        for vertex in grip.data.vertices:
            vertex.co=m @ (vertex.co+V((0,-.06,0)))
        # Cap colour follows the helmet metal, not the wooden grip.
        pommel=base.box('pommel',(0,0,0),(.080,.065,.080),self.part('sword','guard_uv_part'),'hand_r')
        for vertex in pommel.data.vertices:
            vertex.co=m @ (vertex.co+V((0,-.16,0)))

    def shield(self):
        p=self.parts['shield']
        radius=p['diameter']*self.height/2
        depth=p['thickness']*self.height
        n=p['sides']
        centre=base.REST['hand_l'][0]+V((.025,-.045,-.045))
        normal=V((.20,-.98,0)).normalized()
        horizontal=V((.98,.20,0)).normalized()
        vertices=[]
        for r,d in ((radius,-depth/2),(radius,depth/2),(radius*.89,depth/2+.004)):
            for i in range(n):
                q=2*PI*i/n
                vertices.append(tuple(centre+horizontal*(r*math.cos(q))+V((0,0,r*math.sin(q)))+normal*d))
        faces=[(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for j in range(2) for i in range(n)]
        uv=[[ (.5+.49*math.cos(2*PI*(k%n)/n), .5+.49*math.sin(2*PI*(k%n)/n)) for k in face] for face in faces]
        base.mesh('shield_rim',vertices,faces,uv,self.part('shield','rim_uv_part'),'hand_l')
        for front,d,r,key in ((True,depth/2+.005,radius*.89,'face_uv_part'),(False,-depth/2,radius,'back_uv_part')):
            vv=[tuple(centre+normal*d+horizontal*(r*math.cos(2*PI*i/n))+V((0,0,r*math.sin(2*PI*i/n)))) for i in range(n)]
            face=list(range(n)) if front else list(reversed(range(n)))
            uv=[(.5+.49*math.cos(2*PI*i/n),.5+.49*math.sin(2*PI*i/n)) for i in face]
            base.mesh('shield_front' if front else 'shield_back',vv,[face],[uv],self.part('shield',key),'hand_l')

    def build(self):
        rig, stats=base.build(self.model,self.skeleton,self.pose_parameters,
                             bake_times={'walk':[i*.667/64 for i in range(65)]})
        assert stats['triangles'] <= self.spec['triangle_budget']['max'], stats
        rig.name=self.spec['id']+'_rig'
        return rig,stats


def from_spec(path):
    return Shieldman(load_spec(path))
