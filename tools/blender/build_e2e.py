"""T64 end-to-end test unit: undead grunt with exposed skull, short sword and round shield.

This is a pipeline smoke test, not a shipping unit. It inherits the shared chibi
body and the shieldman equipment recipe, then replaces only the head silhouette
and scale-sensitive equipment. No new bones, actions or atlas fields are added.
"""
import math

import bpy

import build_swordsman as base
from build_shieldman import Shieldman

PI = math.pi

class E2EGrunt(Shieldman):
    def __init__(self, spec):
        super().__init__(spec)
        # The skull fills chin..crown; the helmeted recipe instead hides its upper
        # cranium above helmet_brim.
        self.head_centre = (self.h['chin'] + self.h['helmet_top']) / 2
        self.head_radius = (self.h['helmet_top'] - self.h['chin']) / 2
        self.face_full_head = True
        # The shared width convention measures the helmet brim. An exposed skull
        # is widened to the same width so the two recipes use one measurement.
        self.head_y_fill = .5 / .45
        self.proportion_probes = dict(top='head', brim='skull_brow', head='head',
            hem='split_tabard_skirt', boot_cuff='boot_cuff_l', shoulder='tabard_body',
            belt='belt', boots=('boot_l', 'boot_r'), head_width='head',
            arms=('upper_arm_r', 'upper_arm_l'), foot='boot_l', hand='fist_l')
        self.sword_obstacles = ('head', 'skull_jaw', 'skull_brow')

    def model(self):
        self.body_model(exposed_head=True)
        head = bpy.data.objects['head']
        for vertex in head.data.vertices:
            vertex.co.y *= self.head_y_fill
        self.skull_brow()
        self.skull_jaw()
        self.skull_socket()
        self.skull_mouth()
        self.sword()
        self.shield()

    def skull_brow(self):
        # Hidden measurement probe: the exposed skull has no brim geometry, but
        # the shared proportion contract still reports a brow landmark.
        h, H = self.h, self.height
        base.box('skull_brow', (.008 * H, 0, h['helmet_brim'] + .003 * H),
                 (.010 * H, .010 * H, .006 * H), self.part('head'), 'head')

    def skull_jaw(self):
        h, H = self.h, self.height
        width = self.width['head']
        base.ellipsoid('skull_jaw', (.030 * H, 0, h['chin'] + .028 * H),
            (width * .30, width * .32, .044 * H), self.part('teeth'), 'head', sides=6, bands=2)

    def skull_socket(self):
        # The painted face lives on the +X front wedge, which is almost edge-on
        # in the pure side camera. A flat near-side socket keeps the skull
        # readable at 64 px without touching the shared head UV contract.
        h, H = self.h, self.height
        width = self.width['head']
        cx = .008 * H + width * .20
        cy = -width * .5 * math.sqrt(max(.05, 1 - (.20 / .46) ** 2))
        cz = h['eye'] + .008 * H
        radius_x, radius_z = width * .14, width * .16
        n = 12
        verts = [(cx, cy, cz)]
        for i in range(n):
            angle = 2 * PI * i / n
            verts.append((cx + radius_x * math.cos(angle), cy, cz + radius_z * math.sin(angle)))
        faces = [(0, 1 + i, 1 + (i + 1) % n) for i in range(n)]
        uv = [[(.5 + .49 * math.cos(2 * PI * i / n), .5 + .49 * math.sin(2 * PI * i / n))
               for i in face] for face in faces]
        base.mesh('skull_socket_l', verts, faces, uv, self.part('eyes'), 'head')

    def skull_mouth(self):
        h, H = self.h, self.height
        width = self.width['head']
        # Short side mouth line, again for the pure profile read. The front
        # mouth itself is painted on the skin island.
        base.box('skull_mouth_l', (.008 * H + width * .15, -width * .49, h['chin'] + .090 * H),
                 (.090 * H, .010 * H, .014 * H), self.part('eyes'), 'head')

    def build(self):
        rig, stats = base.build(self.model, self.skeleton, self.pose_parameters,
                                bake_times={'walk': [i * .667 / 256 for i in range(257)]})
        assert stats['triangles'] <= self.spec['triangle_budget']['max'], stats
        rig.name = self.spec['id'] + '_rig'
        return rig, stats


def from_spec(path):
    from asset_spec import load_spec
    return E2EGrunt(load_spec(path))
