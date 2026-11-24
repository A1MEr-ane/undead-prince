"""Kingdom shieldman: shared chibi body plus bowl helmet, sword and shield."""
import math
from mathutils import Vector
import build_swordsman as base
from asset_spec import load_spec
from chibi_body import ChibiBody

V = Vector
PI = math.pi


class Shieldman(ChibiBody):
    def __init__(self, spec):
        super().__init__(spec)
        H = self.height
        self.shield_yaw = self.parts['shield']['face_yaw_degrees']
        self.shoulder_offsets['r']=-.075*H
        self.neutral.update(wrist_l=(.255*H,-.235*H,self.h['belt']+.047*H),
                            wrist_r=(.075*H,.19*H,self.h['belt']+.045*H))

    def pose_parameters(self, name, t, duration):
        p=super().pose_parameters(name,t,duration)
        yaw=self.shield_yaw
        if name=='attack':
            guard=math.sin(PI*min(1.,t/.41)) if t<=.41 else 0.
            yaw-=8*guard
        elif name=='parry':
            push=base.blend([(0,dict(shield=0.)),(.13,dict(shield=.15)),
                (.26,dict(shield=1.)),(.39,dict(shield=.5)),(.65,dict(shield=0.))],t)['shield']
            yaw-=24*push
        p['bone_yaws']={'hand_l':self.shield_yaw-yaw}
        return p

    def model(self):
        self.body_model()
        h,H=self.h,self.height
        n=self.parts['helmet']['sides']
        dome=[(z,self.ring(self.width['head']*r,self.width['head']*r,sides=n))
            for z,r in ((h['helmet_brim'],.475),
                (h['helmet_brim']+(h['helmet_top']-h['helmet_brim'])*.68,.35),
                (h['helmet_top'],.10))]
        self.profile('helmet_dome',dome,self.part('helmet'),'head',False,True)
        self.profile('helmet_brim',[(h['helmet_brim'],self.ring(self.width['head']/2,self.width['head']/2)),
            (h['helmet_brim']+.065*H,self.ring(self.width['head']/2,self.width['head']/2))],
            self.part('helmet','rim_uv_part'),'head',True,False)
        # Rounded lower tip, with no protruding nose beneath it.
        x=self.width['head']/2+.004*H
        z0,z1=h['eye']-.025*H,h['helmet_brim']+.025*H
        y=.026*H
        front=[(x,-y,z1),(x,y,z1),(x,y,z0+.012*H),(x,0,z0),(x,-y,z0+.012*H)]
        vertices=front+[(xx-.018*H,yy,zz) for xx,yy,zz in front]
        faces=[(0,1,2,3,4),(9,8,7,6,5)]+[(i,5+i,5+(i+1)%5,(i+1)%5) for i in range(5)]
        base.mesh('nasal_guard',vertices,faces,[[(j/(len(f)-1),.5) for j in range(len(f))] for f in faces],self.part('helmet'),'head')
        self.sword()
        self.shield()

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
        angle=math.radians(self.shield_yaw)
        normal=V((math.cos(angle),-math.sin(angle),0))
        horizontal=V((math.sin(angle),math.cos(angle),0))
        centre=base.REST['hand_l'][0]+normal*(self.hand*.60)+V((0,0,-.045))
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
                             bake_times={'walk':[i*.667/256 for i in range(257)]})
        assert stats['triangles'] <= self.spec['triangle_budget']['max'], stats
        rig.name=self.spec['id']+'_rig'
        return rig,stats


def from_spec(path):
    return Shieldman(load_spec(path))
