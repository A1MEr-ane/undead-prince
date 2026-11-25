"""Spec palettes, flat painted heraldry and ordinary shaded model review renders."""
import math
from pathlib import Path
import tempfile

import bpy
import numpy as np
from mathutils import Vector

from common import PARTS, PART_SIZE, read_png, write_png
from preview import rgb, decode, contact_sheet, background, paste, label, linear_to_srgb
from build_swordsman import OBJECTS, apply_pose


def colour(value):
    return rgb(value.lstrip('#'))


def paint_tile(look, proportions):
    tile=np.zeros((PART_SIZE,PART_SIZE,4),np.uint8)
    tile[...,3]=255
    aa=4
    yy,xx=np.mgrid[0:64*aa,0:64*aa]/aa
    u=np.clip((xx-4)/56,0,1)
    v=np.clip((63-yy-4)/56,0,1)
    x,y=2*u-1,2*v-1
    for name,(cx,cy,_) in PARTS.items():
        value=look.get(name,look['leather'])
        base=colour(value['base'] if isinstance(value,dict) else value)
        # Three broad painted planes, deliberately no noise, rivets or stitching.
        factor=np.where(u<.28,.86,np.where(u>.73,1.06,1.))
        if name in ('helmet','metal','blade','shield_rim'):
            factor=np.where(u<.47,.84,np.where(u>.56,1.06,1.))
        if name in ('boots','leather','shield_back'):
            factor=np.where(v<.26,.85,np.where(v>.72,1.06,1.))
        c=base[None,None,:]*factor[...,None]
        skull=bool(look.get('skull'))
        if skull and name=='helmet':
            # The jaw samples the helmet island in the e2e recipe; dark columns
            # break up the bone block into readable teeth in profile.
            ink=colour(look['eye'])
            tooth_gap=(v<.60)&((((u*9)%1.0)<.30))
            c[tooth_gap]=ink
        if name=='skin':
            from chibi_body import face_uv, HEAD_UV_MIN
            ink=colour(look['eye'])
            eyes=face_uv(proportions,skull)
            for eye_u,eye_v in eyes:
                du,dv=u-eye_u,v-eye_v
                if skull:
                    # Large, slightly tilted sockets; no brows on a skull.
                    socket=(du/.052)**2+(dv/.067)**2 <= 1
                    c[socket]=ink
                else:
                    eye=(du/.026)**2+(dv/.057)**2 <= 1
                    slope=-.22 if eye_u<.5 else .22
                    brow=(np.abs(du)<.060)&(np.abs(dv-.095-slope*du)<.017)
                    c[eye|brow]=ink
            if skull:
                # Inverted triangular nasal cavity under the eye line.
                h=proportions['landmarks_from_ground']
                top=h['helmet_top']
                eye_v=eyes[0][1]
                nose_top, nose_bottom=eye_v-.075,eye_v-.185
                t=(nose_top-v)/(nose_top-nose_bottom)
                nose=(v<nose_top)&(v>nose_bottom)&(np.abs(u-.5)<(.010+.022*t))
                c[nose]=ink
                # A dark mouth with a few lighter tooth columns over the jaw.
                teeth_v=HEAD_UV_MIN+(1-HEAD_UV_MIN)*((h['chin']+.055)-h['chin'])/(top-h['chin'])
                mouth=(np.abs(v-teeth_v)<.022)&(np.abs(u-.5)<.105)
                c[mouth]=ink
                teeth=mouth&((((u-.5)*12)%1.0)<.55)
                c[teeth]=base[None,:]*factor[teeth,None]
        if name=='leather':
            c[v>.68]=colour(look['hair'])*np.where(u[v>.68,None]<.4,.86,1.)
        if name=='shield_face':
            import re
            emblem=colour(re.search(r'#[0-9A-Fa-f]{6}',value['emblem'])[0])
            bend=colour(re.search(r'#[0-9A-Fa-f]{6}',value['bend'])[0])
            # Sixteen alternating vertices make an eight-ray sun, upright in UV.
            angle=np.arange(16)*math.pi/8
            radius=np.where(np.arange(16)%2==0,.86,.36)
            px,py=radius*np.cos(angle),radius*np.sin(angle)
            inside=np.zeros(x.shape,bool)
            for i in range(16):
                j=(i-1)%16
                crossing=((py[i]>y)!=(py[j]>y)) & (x<(px[j]-px[i])*(y-py[i])/(py[j]-py[i]+1e-12)+px[i])
                inside ^= crossing
            c[inside]=emblem
            c[inside & (x<-.20)]=emblem*.92
            stripe=np.abs(y-x)<.24
            c[stripe]=bend
            c[stripe & (x<-.20)]=bend*.88
        row=(3-cy)*64
        resolved=c.reshape(64,aa,64,aa,3).mean(axis=(1,3))
        tile[row:row+64,cx*64:cx*64+64,:3]=np.round(np.clip(resolved,0,1)*255).astype(np.uint8)
    return tile


def create_previews(atlas, metadata, output, spec):
    prefix=spec['id']
    looks=[(key,value) for key,value in spec['looks'].items() if isinstance(value,dict)]
    assert 1 <= len(looks) <= 4, 'The v1 part texture has four appearance slots'
    paints=[paint_tile(value,spec['proportions']) for _,value in looks]
    # Keep the existing 2x2 texture contract; unused slots repeat the first look.
    slots=(paints+[paints[0]]*4)[:4]
    parts=np.concatenate([np.concatenate(slots[:2],axis=1),np.concatenate(slots[2:],axis=1)],axis=0)
    write_png(output/f'{prefix}_parts.png',parts)
    metadata['part_texture']['image']=f'{prefix}_parts.png'
    metadata['part_texture']['appearances']=[dict(name=key,label=key.upper(),tile=[i%2,i//2],
        pixel_rect=[i%2*256,i//2*256,256,256]) for i,(key,_) in enumerate(looks)]
    for (name,_),paint in zip(looks,paints):
        decoded = decode(atlas,paint)
        write_png(output/f'{prefix}_preview_{name}.png',contact_sheet(decoded,metadata,name.upper()))
        if name == looks[0][0]:
            walk_metadata = dict(metadata, animations={'walk': metadata['animations']['walk']})
            write_png(output/f'{prefix}_preview_walk.png',contact_sheet(decoded,walk_metadata,name.upper()+' WALK'))
    for name,source in (('uv',atlas),('shading',atlas.copy())):
        if name=='shading':
            source[...,:3]=source[...,2:3]
        canvas=background(source.shape[1]*3,source.shape[0]*3)
        paste(canvas,source,0,0,3)
        write_png(output/f'{prefix}_preview_{name}.png',canvas)


def render_views(rig, recipe, output, threads):
    """Diffuse texture + area lights; these are model renders, not UV previews.

    Body front/side/back share one orthographic camera scale and an A pose like
    the reference. Equipment is shown separately in its actual idle pose.
    """
    prefix=recipe.spec['id']
    scene=bpy.context.scene
    rig.animation_data.action=None
    rig.location=(0,0,0)
    material=bpy.data.materials.new(prefix+'_ordinary_paint')
    material.use_nodes=True
    nodes=material.node_tree.nodes
    bsdf=nodes.get('Principled BSDF')
    bsdf.inputs['Roughness'].default_value=1
    bsdf.inputs['Specular IOR Level'].default_value=0
    texture=nodes.new('ShaderNodeTexImage')
    texture.image=bpy.data.images.load(str(output/f'{prefix}_parts.png'),check_existing=False)
    texture.interpolation='Linear'
    # Existing UVs are local to a 256 tile; the PNG retains the 2x2 contract.
    mapping=nodes.new('ShaderNodeVectorMath')
    mapping.operation='MULTIPLY_ADD'
    mapping.inputs[1].default_value=(.5,.5,1)
    mapping.inputs[2].default_value=(0,.5,0)
    uv=nodes.new('ShaderNodeUVMap')
    links=material.node_tree.links
    links.new(uv.outputs['UV'],mapping.inputs[0])
    links.new(mapping.outputs[0],texture.inputs['Vector'])
    links.new(texture.outputs['Color'],bsdf.inputs['Base Color'])
    for ob in OBJECTS:
        ob.data.materials.clear()
        ob.data.materials.append(material)
    scene.render.resolution_x=scene.render.resolution_y=768
    scene.cycles.samples=32
    scene.cycles.use_denoising=True
    scene.render.threads=threads
    scene.render.filter_size=1.0
    scene.world.use_nodes=True
    world=scene.world.node_tree.nodes.get('Background')
    world.inputs['Color'].default_value=(.70,.75,.85,1)
    world.inputs['Strength'].default_value=.65
    for name,position,energy,size in (('Key',(3,-4,6),400,4),('Fill',(-3,2,4),180,4)):
        data=bpy.data.lights.new(name,'AREA')
        data.energy=energy
        data.shape='DISK'
        data.size=size
        ob=bpy.data.objects.new(name,data)
        bpy.context.collection.objects.link(ob)
        ob.location=position
        ob.rotation_euler=(Vector((0,0,1))-ob.location).to_track_quat('-Z','Y').to_euler()
    camera=scene.camera
    camera.data.ortho_scale=2.48
    equipment=[ob for ob in OBJECTS if ob.name.startswith(('shield_','sword_','pommel'))]
    for ob in equipment:
        ob.hide_render=True
    H=recipe.height
    # Relax the short arms to an A pose using the same proportions as the body.
    apply_pose(rig,dict(wrist_l=(.01*H,-.29*H,recipe.h['belt']-.025*H),
                        wrist_r=(.01*H,.29*H,recipe.h['belt']-.025*H)),skeleton_fn=recipe.skeleton)
    with tempfile.TemporaryDirectory(prefix=prefix+'-views-') as directory:
        for view,position in (('front',(8,0,1.06)),('side',(0,-8,1.06)),('back',(-8,0,1.06)),
                              ('equipped',(5,-8,2.3)), ('equipped_side',(0,-8,1.06))):
            if view.startswith('equipped'):
                for ob in equipment:
                    ob.hide_render=False
                apply_pose(rig,recipe.pose_parameters('idle',0,.667),skeleton_fn=recipe.skeleton)
                camera.data.ortho_scale=2.70
            camera.location=position
            camera.rotation_euler=(Vector((0,0,1.06))-camera.location).to_track_quat('-Z','Y').to_euler()
            scene.render.filepath=str(Path(directory)/'view.exr')
            bpy.ops.render.render(write_still=True)
            image=bpy.data.images.load(scene.render.filepath,check_existing=False)
            raw=np.empty(768*768*4,np.float32)
            image.pixels.foreach_get(raw)
            raw=raw.reshape(768,768,4)[::-1]
            alpha=raw[...,3:4]
            # Composite over a neutral reference background in linear light.
            rgb_linear=raw[...,:3]+np.array([.62,.64,.67])*(1-alpha)
            write_png(output/f'{prefix}_view_{view}.png',np.round(linear_to_srgb(rgb_linear)*255).astype(np.uint8))
            bpy.data.images.remove(image)
            print('MODEL_VIEW',view,flush=True)


def create_comparison(old_image, output, prefix):
    """Preserve the actual v4 render supplied before rebuilding the current asset."""
    old=read_png(old_image)
    new=read_png(output/f'{prefix}_view_equipped_side.png')
    assert old.shape==new.shape==(768,768,3), 'Compare the same ordinary side view'
    canvas=background(1536,818)
    label(canvas,'OLD V4',24,15,3)
    label(canvas,'B / 2.3 HEADS / HEAD 44 / LEGS 22',792,15,2)
    canvas[50:,:768]=old
    canvas[50:,768:]=new
    write_png(output/f'{prefix}_comparison_v4_B.png',canvas)
