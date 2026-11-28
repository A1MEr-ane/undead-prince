"""Reusable spec-driven chibi body and the existing fifteen-bone rigid rig.

Units are derived from the spec's ground landmarks and widths. Meshes use the
sixteen existing UV islands; skin V < .25 is reserved for hands/ears, the head
uses V=.30..1 so face paint never appears on the gloves. +X forward, -Y near.
Equipment recipes subclass this body; no dependency on shieldman geometry.
"""
import math
import bmesh
from mathutils import Matrix, Vector

import build_swordsman as base
from common import uv_rect

V = Vector
PI = math.pi
HEAD_UV_MIN = .30


def face_uv(proportions, full_head=False):
    """Eye centres in the head's reserved skin subrectangle (local island UV).

    full_head is for exposed skulls, where the painted skin region runs all the
    way from chin to crown instead of stopping under a helmet brim.
    """
    h=proportions['landmarks_from_ground']
    top=h['helmet_top'] if full_head else h['helmet_brim']+.06
    v=HEAD_UV_MIN+(1-HEAD_UV_MIN)*(h['eye']-h['chin'])/(top-h['chin'])
    # Front cheeks share a frontal projection: round vertical eyes in front,
    # with only the near eye visible in the pure side silhouette.
    return ((.27,v),(.73,v))


class ChibiBody:
    def __init__(self, spec, height=1.92):
        self.spec, self.height = spec, height
        self.ground = .035  # Preserve the v1 camera and foot anchor.
        p = spec['proportions']
        self.h = {k: self.ground + v*height for k, v in p['landmarks_from_ground'].items()}
        self.width = {k: v*height for k, v in p['widths'].items() if isinstance(v, (int, float))}
        self.hand = self.width['hand_diameter']
        self.lean = p['lean_degrees']
        self.parts = spec['parts']
        self.shoulder_offsets = {'l': 0., 'r': 0.}
        self.leg_y = self.width['shoulders']*.18
        self.ankle_z = self.ground + (self.h['boot_top']-self.ground)*.55
        self.leg_length = (self.h['crotch']-self.ankle_z)*.505
        self.arm_length = (self.h['shoulder']-self.h['belt'])*.74
        self.neutral = dict(hip=(0, 0, self.h['belt']), lean=0., head_tilt=0.,
            foot_l=(.018*height, -self.leg_y, self.ankle_z),
            foot_r=(-.018*height, self.leg_y, self.ankle_z),
            wrist_l=(.08*height, -self.width['shoulders']*.47, self.h['belt']-.02*height),
            wrist_r=(.05*height, self.width['shoulders']*.47, self.h['belt']-.02*height),
            sword=115., shield=0., tumble=0.)
        self.head_centre = (self.h['chin']+self.h['helmet_brim']+.06*height)/2
        self.head_radius = (self.h['helmet_brim']+.06*height-self.h['chin'])/2

    def part(self, name, key='uv_part'):
        return self.parts[name][key]

    def skeleton(self, parameters):
        p = dict(self.neutral)
        p.update(parameters)
        hip = V(p['hip'])
        rotation = Matrix.Rotation(math.radians(p['lean']), 3, 'Y')
        def body(offset):
            return hip + rotation @ V(offset)
        neck = body((.008*self.height, 0, self.h['chin']-self.h['belt']))
        head_rotation = Matrix.Rotation(math.radians(p['lean']+p['head_tilt']), 3, 'Y')
        bones = {'root': (hip, body((0, 0, .075*self.height))),
                 'spine': (body((0, 0, .02*self.height)), neck),
                 'head': (neck, neck+head_rotation @ V((0, 0, self.head_radius)))}
        for suffix, y in (('l', -self.leg_y), ('r', self.leg_y)):
            # Hip joints really are at the crotch, not at the waist belt.
            joint = body((0, y, self.h['crotch']-self.h['belt']))
            ankle = V(p['foot_'+suffix])
            knee = base.ik(joint, ankle, self.leg_length, self.leg_length)
            bones['thigh_'+suffix] = (joint, knee)
            bones['shin_'+suffix] = (knee, ankle)
            bones['foot_'+suffix] = (ankle, ankle+V((self.width['foot_length']*.55, 0, 0)))
        shoulder_y = self.width['shoulders']*.5-self.height*.051
        for suffix, y in (('l', -shoulder_y), ('r', shoulder_y)):
            shoulder = body((self.shoulder_offsets[suffix], y,
                             self.h['shoulder']-self.h['belt']-.024*self.height))
            wrist = V(p['wrist_'+suffix])
            elbow = shoulder+wrist-base.ik(shoulder, wrist, self.arm_length, self.arm_length)
            angle = math.radians(p['sword'] if suffix == 'r' else 18+p['shield'])
            direction = V((math.sin(angle), 0, math.cos(angle)))
            bones['upper_arm_'+suffix] = (shoulder, elbow)
            bones['forearm_'+suffix] = (elbow, wrist)
            bones['hand_'+suffix] = (wrist, wrist+direction*self.hand*.6)
        if p['tumble']:
            r = Matrix.Rotation(math.radians(p['tumble']), 3, 'Y')
            bones = {k: (hip+r@(a-hip), hip+r@(b-hip)) for k,(a,b) in bones.items()}
        return bones

    def pose_parameters(self, name, t, duration):
        H,g=self.height,self.ground
        p=dict(self.neutral)
        p['lean']=self.lean
        def xyz(x,y,z):
            return (x*H,y*H,g+z*H)
        def pose(**values):
            result=dict(p)
            result.update(values)
            return result
        def blend(points):
            return base.blend([(time,pose(**values)) for time,values in points],t)
        sit=dict(hip=xyz(-.08,0,.13),lean=-22.,head_tilt=8.,
            foot_l=xyz(.10,-self.leg_y/H,.0605),foot_r=xyz(.13,self.leg_y/H,.0605),
            wrist_l=xyz(.20,-.24,.24),wrist_r=xyz(.18,.24,.25),sword=108.,shield=18.)
        lying=dict(hip=xyz(-.04,0,.18),lean=-86.,head_tilt=-4.,
            foot_l=xyz(.18,-self.leg_y/H,.0605),foot_r=xyz(.20,self.leg_y/H,.0605),
            wrist_l=xyz(.12,-.27,.18),wrist_r=xyz(.11,.28,.13),sword=91.,shield=65.)
        if name=='idle':
            s=math.sin(2*PI*t/duration)
            p=pose(hip=xyz(0,0,.32+.003*s),head_tilt=1.2*s,
                   wrist_l=xyz(.255,-.235,.367+.004*s))
        elif name=='walk':
            phase=t/duration
            # Scale the previous shuffle by the new leg length, not long-leg angles.
            leg_ratio=(self.h['crotch']-g)/H/.24
            stride,lift=H*.05*leg_ratio,H*.025*leg_ratio
            def foot(q,y):
                q%=1
                if q<.5:
                    a=q*2
                    return (-stride/2+stride*a,y,self.ankle_z+lift*math.sin(PI*a))
                return (stride/2-stride*(q-.5)*2,y,self.ankle_z)
            p=pose(foot_l=foot(phase,-self.leg_y),foot_r=foot(phase+.5,self.leg_y))
        elif name=='attack':
            # Wind-up stays outside the enlarged head in depth; the hit is horizontal.
            p=blend([(0,{}),(.17,dict(hip=xyz(-.03,0,.30),lean=-9.,
                wrist_r=xyz(-.12,.29,.70),sword=-44.)),
                (.25,dict(hip=xyz(-.02,0,.305),lean=-4.,wrist_r=xyz(-.03,.29,.72),sword=-22.)),
                (.333,dict(hip=xyz(.035,0,.30),lean=14.,wrist_r=xyz(.26,.29,.51),sword=90.,
                    foot_l=xyz(.07,-self.leg_y/H,.0605),foot_r=xyz(-.05,self.leg_y/H,.0605))),
                (.41,dict(hip=xyz(.045,0,.29),lean=18.,wrist_r=xyz(.25,.29,.37),sword=125.)),(.60,{})])
            guard=math.sin(PI*min(1.,t/.41)) if t<=.41 else 0.
            x,y,z=self.neutral['wrist_l']
            p['wrist_l']=(x-.03*H*guard,y+.015*H*guard,z+.008*H*guard)
        elif name=='parry':
            push=base.blend([(0,dict(shield=0.)),(.13,dict(shield=.15)),
                (.26,dict(shield=1.)),(.39,dict(shield=.5)),(.65,dict(shield=0.))],t)['shield']
            x,y,z=self.neutral['wrist_l']
            p=pose(wrist_l=(x+.075*H*push,y+.02*H*push,z+.012*H*push),shield=-12*push)
        elif name=='clash':
            p=blend([(0,dict(lean=12.,wrist_r=xyz(.24,.28,.55),sword=52.)),
                (.10,dict(hip=xyz(-.04,0,.29),lean=-20.,head_tilt=-7.,wrist_r=xyz(-.04,.29,.64),sword=-24.)),
                (.23,dict(hip=xyz(-.02,0,.30),lean=-10.,wrist_r=xyz(.10,.27,.48),sword=65.)),(.35,{})])
        elif name=='fall':
            p=blend([(0,{}),(.11,dict(hip=xyz(-.04,0,.275),lean=-28.,head_tilt=-10.,
                wrist_r=xyz(.12,.27,.43),sword=108.)),
                (.23,dict(hip=xyz(-.075,0,.17),lean=-35.,head_tilt=6.,
                foot_l=xyz(.14,-self.leg_y/H,.08),foot_r=xyz(.20,self.leg_y/H,.07),
                wrist_l=xyz(.22,-.25,.27),wrist_r=xyz(.17,.26,.30),sword=108.,shield=16.)),(.35,sit)])
        elif name=='sit':
            p=pose(**sit)
            s=math.sin(2*PI*t/duration)
            p['lean']+=2*s
            p['head_tilt']+=3*s
        elif name=='rise':
            p=blend([(0,sit),(.18,dict(hip=xyz(-.045,0,.15),lean=22.,head_tilt=-8.,
                foot_l=xyz(.06,-self.leg_y/H,.0605),foot_r=xyz(-.025,self.leg_y/H,.0605),
                wrist_l=xyz(.26,-.25,.25),wrist_r=xyz(.23,.28,.25),sword=108.)),
                (.37,dict(hip=xyz(0,0,.21),lean=24.,head_tilt=-12.,
                foot_l=xyz(.08,-self.leg_y/H,.0605),foot_r=xyz(-.05,self.leg_y/H,.0605),
                wrist_l=xyz(.28,-.25,.30),wrist_r=xyz(.21,.28,.32),sword=112.)),
                (.60,dict(hip=xyz(.01,0,.29),lean=10.,head_tilt=-4.)),(.74,{}),(.833,{})])
        elif name=='death':
            p=blend([(0,{}),(.10,dict(hip=xyz(-.02,0,.30),lean=-24.,head_tilt=-10.)),
                (.25,dict(hip=xyz(-.05,0,.24),lean=-52.,head_tilt=4.,
                foot_l=xyz(.13,-self.leg_y/H,.0605),foot_r=xyz(.18,self.leg_y/H,.0605),
                wrist_l=xyz(.20,-.27,.24),wrist_r=xyz(.13,.28,.22),sword=101.,shield=40.)),
                (.39,dict(hip=xyz(-.05,0,.19),lean=-75.,head_tilt=-2.,
                foot_l=xyz(.19,-self.leg_y/H,.0605),foot_r=xyz(.23,self.leg_y/H,.0605),
                wrist_l=xyz(.14,-.27,.18),wrist_r=xyz(.11,.28,.15),sword=96.,shield=60.)),
                (.486,lying),(.583,lying)])
        elif name=='ragdoll':
            p=pose(hip=(0,0,1.45),lean=-65.,head_tilt=28.,
                foot_l=(.20*H,-self.leg_y,1.30),foot_r=(.22*H,self.leg_y,1.30),
                wrist_l=(-.02*H,-.27*H,1.55),wrist_r=(-.03*H,.29*H,1.55),
                sword=132.,shield=-20.,tumble=360*t/duration)
        elif name=='hit':
            p=blend([(0,dict(hip=xyz(-.035,0,.29),lean=-24.,head_tilt=-16.,
                wrist_r=xyz(.08,.27,.41),sword=110.)),
                (.167,dict(hip=xyz(-.01,0,.31),lean=-8.,head_tilt=-5.))])
        else:
            raise ValueError(name)
        return p

    def profile(self, name, rings, part, bone, cap_bottom=True, cap_top=True, far=False):
        n = len(rings[0][1])
        vertices = [(x, y, z) for z, ring in rings for x, y in ring]
        faces, uv = [], []
        for j in range(len(rings)-1):
            for i in range(n):
                faces.append((j*n+i, j*n+(i+1)%n, (j+1)*n+(i+1)%n, (j+1)*n+i))
                uv.append([(i/n,j/(len(rings)-1)),((i+1)/n,j/(len(rings)-1)),
                           ((i+1)/n,(j+1)/(len(rings)-1)),(i/n,(j+1)/(len(rings)-1))])
        for j, cap in ((0,cap_bottom),(len(rings)-1,cap_top)):
            if cap:
                ids = list(range(j*n,(j+1)*n))
                if j == 0:
                    ids.reverse()
                faces.append(ids)
                uv.append([(.5+.45*math.cos(2*PI*i/n),.5+.45*math.sin(2*PI*i/n)) for i in ids])
        return base.mesh(name, vertices, faces, uv, part, bone, far)

    @staticmethod
    def ring(rx, ry, x=0, y=0, sides=8):
        return [(x+rx*math.cos(2*PI*i/sides), y+ry*math.sin(2*PI*i/sides)) for i in range(sides)]

    @staticmethod
    def remap_v(ob, low, high):
        _,v0,_,v1 = uv_rect(ob['part'])
        for loop in ob.data.uv_layers.active.data:
            v=(loop.uv.y-v0)/(v1-v0)
            loop.uv.y=v0+(v1-v0)*(low+(high-low)*v)

    @classmethod
    def leather_uv(cls, ob, hair=False):
        cls.remap_v(ob,.76 if hair else .05,.98 if hair else .55)

    def limb(self, name, radius, part, far):
        a,b=base.REST[name]
        m=base.bone_matrix(a,b)
        length=(b-a).length
        n=5 if name.startswith(('thigh_', 'shin_')) else 6
        verts=[tuple(m@V((math.cos(2*PI*i/n)*radius*r,j*length,math.sin(2*PI*i/n)*radius*r)))
               for j,r in ((0,1),(1,.94)) for i in range(n)]
        faces=[(i,n+i,n+(i+1)%n,(i+1)%n) for i in range(n)]
        uvs=[[(i/n,0),(i/n,1),((i+1)/n,1),((i+1)/n,0)] for i in range(n)]
        # Close joints: rigid segments rotate independently and expose end faces.
        if name.startswith('upper_arm_'):
            faces.append(tuple(reversed(range(n,2*n))))
            uvs.append([(.5+.45*math.cos(2*PI*i/n),.5+.45*math.sin(2*PI*i/n)) for i in range(n)])
        return base.mesh(name,verts,faces,uvs,part,name,far)

    def glove(self, name, centre, part, bone, far):
        # Icosahedra keep a round silhouette in front AND side views for 20 tris.
        phi=(1+math.sqrt(5))/2
        points=[V(p).normalized() for p in ((-1,phi,0),(1,phi,0),(-1,-phi,0),(1,-phi,0),
            (0,-1,phi),(0,1,phi),(0,-1,-phi),(0,1,-phi),(phi,0,-1),(phi,0,1),(-phi,0,-1),(-phi,0,1))]
        # Normalize each axis's extent so hand_diameter remains an actual size.
        extent=[max(abs(p[i]) for p in points) for i in range(3)]
        verts=[tuple(V(centre)+V(tuple(p[i]/extent[i]*self.hand/2 for i in range(3)))) for p in points]
        faces=[(0,11,5),(0,5,1),(0,1,7),(0,7,10),(0,10,11),(1,5,9),(5,11,4),(11,10,2),
            (10,7,6),(7,1,8),(3,9,4),(3,4,2),(3,2,6),(3,6,8),(3,8,9),
            (4,9,5),(2,4,11),(6,2,10),(8,6,7),(9,8,1)]
        ob=base.mesh(name,verts,faces,[[(.3,.06),(.7,.06),(.5,.20)]]*20,part,bone,far,smooth=True)
        return ob

    def body_model(self, exposed_head=False, include_head=True, *, style='clothed', segmented_legs=True):
        """Build the shared body. exposed_head keeps the whole cranium and omits
        the hair, ears and mouth so a skull recipe can replace them."""
        h,H=self.h,self.height
        # Pear outline: progressively wider towards the hem, without a pinched waist.
        body_scale = {'clothed': 1, 'fitted': .80, 'bones': .41}[style]
        self.profile('tabard_body', [(h['belt'], self.ring(.133*H*body_scale,.163*H*body_scale,sides=6)),
            (h['shoulder'], self.ring(.105*H*body_scale,.150*H*body_scale,.05*H if style == 'fitted' else 0,sides=6))],
            self.part('tunic'), 'spine', False, True)
        if style == 'clothed':
            hem,belt=h['tunic_hem'],h['belt']+.008*H
            rings=[self.ring(.151*H,.182*H),self.ring(.133*H,.163*H)]
            verts=[(x,y,z+(.035*H if row==0 and i in (0,4) else 0))
                   for row,(z,ring) in enumerate(zip((hem,belt),rings)) for i,(x,y) in enumerate(ring)]
            faces=[(i,(i+1)%8,8+(i+1)%8,8+i) for i in range(8)]
            uv=[[(0,0),(1,0),(1,1),(0,1)]]*8
            base.mesh('split_tabard_skirt',verts,faces,uv,self.part('tunic'),'root')
        belt_scale = max(.75, body_scale)
        belt_ob=self.profile('belt',[(z,self.ring(.138*H*belt_scale,.169*H*belt_scale))
            for z in (h['belt']-.020*H, h['belt']+.020*H)],self.part('belt'),'spine',False,False)
        self.leather_uv(belt_ob)
        if 'buckle_uv_part' in self.parts['belt']:
            base.box('belt_buckle',(.141*H,0,h['belt']),(.022*H,.075*H,.055*H),self.part('belt','buckle_uv_part'),'spine')
        self.profile('collar',[(h['shoulder']-.008*H,self.ring(.085*H,.12*H,.008*H,sides=6)),
            (h['chin']+.008*H,self.ring(.085*H,.12*H,.008*H,sides=6))],self.part('collar'),'head',False,True)
        if include_head:
            self.legacy_head(exposed_head)
        for side in ('l','r'):
            far=side=='r'
            limbs = [('upper_arm_', self.part('sleeves'), .051*H), ('forearm_', self.part('sleeves'), .046*H)]
            if segmented_legs:
                limbs[:0] = [('thigh_', self.part('legs'), .047*H), ('shin_', self.part('legs'), .045*H)]
            for segment,part,radius in limbs:
                self.limb(segment+side,radius*(.76 if style == 'bones' else 1),part,far)
            if segmented_legs:
                ankle=base.REST['foot_'+side][0]
                foot_offset=ankle.z-self.ankle_z if not include_head else 0
                length=self.width['foot_length']
                self.profile('boot_'+side,[(self.ground+foot_offset,self.ring(length/2,.053*H,ankle.x+.020*H,ankle.y,sides=6)),
                    (self.ground+foot_offset+.065*H,self.ring(length*.42,.048*H,ankle.x+.014*H,ankle.y,sides=6))],
                    self.part('boots'),'foot_'+side,True,True,far)
                self.profile('boot_cuff_'+side,[(self.ground+foot_offset+.062*H,self.ring(.052*H,.056*H,ankle.x,ankle.y,sides=6)),
                    (h['boot_top']+foot_offset,self.ring(.052*H,.056*H,ankle.x,ankle.y,sides=6))],
                    self.part('boots'),'shin_'+side,False,True,far)
            self.glove('fist_'+side,base.REST['hand_'+side][0],self.part('hands'),'hand_'+side,far)

    def legacy_head(self, exposed_head):
        h,H=self.h,self.height
        head=base.ellipsoid('head',(.008*H,0,self.head_centre),
            (self.width['head']*.46,self.width['head']*.45,self.head_radius),self.part('head'),'head',sides=8,bands=6)
        bm=bmesh.new()
        bm.from_mesh(head.data)
        if not exposed_head:
            # The upper cap is completely inside the helmet, including in animations.
            bmesh.ops.delete(bm,geom=[f for f in bm.faces if min(v.co.z for v in f.verts)>h['helmet_brim']],context='FACES')
            bm.to_mesh(head.data)
        bm.free()
        from common import map_uv
        for polygon in head.data.polygons:
            radial=math.hypot(polygon.normal.x,polygon.normal.y)
            front=radial>1e-6 and polygon.normal.x/radial>.7
            for index in polygon.loop_indices:
                point=head.data.vertices[head.data.loops[index].vertex_index].co
                u=(.5+.46*point.y/(self.width['head']*.45)) if front else .06
                v=HEAD_UV_MIN+(1-HEAD_UV_MIN)*(point.z-h['chin'])/(2*self.head_radius)
                head.data.uv_layers.active.data[index].uv=map_uv('skin',(u,v))
        if not exposed_head:
            # Rear hair follows the spherical head rather than forming a vertical box.
            vertices=[]
            for j in (2,3,4,5):
                angle=-PI/2+PI*j/6
                z=self.head_centre+self.head_radius*math.sin(angle)
                r=math.cos(angle)*1.015
                vertices += [(H*.008+self.width['head']*.466*r*math.cos(PI/2+i*PI/4),
                              self.width['head']*.456*r*math.sin(PI/2+i*PI/4),z) for i in range(5)]
            faces=[(j*5+i,j*5+i+1,(j+1)*5+i+1,(j+1)*5+i) for j in range(3) for i in range(4)]
            base.mesh('short_hair',vertices,faces,[[(0,.76),(1,.76),(1,.98),(0,.98)]]*12,'leather','head')
            for side,sign in (('l',-1),('r',1)):
                ear=base.ellipsoid('ear_'+side,(-.012*H,sign*self.width['head']*.446,h['eye']-.045*H),
                    (.039*H,.027*H,.047*H),self.part('head'),'head',sides=6,bands=2)
                # Poles along depth leave a round hexagonal ear in the side silhouette.
                c=V((-.012*H,sign*self.width['head']*.446,h['eye']-.045*H))
                for vertex in ear.data.vertices:
                    q=vertex.co-c
                    vertex.co=c+V((q.x,-q.z*.027/.047,q.y*.047/.027))
                self.remap_v(ear,.02,.22)
            # Small mouth remains in the existing eye island; eyes and brows are skin paint.
            z=h['eye']-.081*H
            # Front face is piecewise planar along the sphere's latitude bands.
            lat=(z-self.head_centre)/self.head_radius
            r=(1+(1-math.sqrt(.75))*lat/.5) if lat<0 else 1
            x=.008*H+self.width['head']*.46*r+.001*H
            verts=[(x,y,z+dz) for y,dz in ((-.017*H,-.002*H),(.017*H,-.002*H),(.017*H,.002*H),(-.017*H,.002*H))]
            base.mesh('mouth',verts,[(0,1,2,3)],[[(0,0),(1,0),(1,1),(0,1)]],self.part('eyes'),'head')
