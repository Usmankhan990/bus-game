# Blender script: Home aur booster buttons ke 3D icons (apna design).
# Chalane ka tareeqa (project folder mein):
#   blender.exe -b --python tool/blender/make_icons.py -- assets/icons [naam ...]
# Natija: assets/icons/<naam>.png (transparent, 384x384)

import math
import os
import sys

import bpy

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "assets/icons"
ONLY = ARGS[1:]
if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)


def srgb(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def col(h):
    return tuple(srgb(int(h[i:i + 2], 16) / 255) for i in (0, 2, 4)) + (1,)


def mat(name, h, rough=.25, coat=.6, metal=0.0, emit=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = col(h)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    if "Coat Weight" in p.inputs:
        p.inputs["Coat Weight"].default_value = coat
    if emit:
        p.inputs["Emission Color"].default_value = col(emit)
        p.inputs["Emission Strength"].default_value = .6
    return m


def smooth(o, m, bevel=0.0, seg=4):
    if bevel:
        mod = o.modifiers.new("b", "BEVEL")
        mod.width = bevel
        mod.segments = seg
    bpy.ops.object.shade_smooth()
    o.data.materials.append(m)
    return o


def box(size, loc, m, bevel=.08, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    return smooth(o, m, bevel)


def cyl(r, depth, loc, m, rot=(0, 0, 0), bevel=.03, verts=64):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, location=loc, rotation=rot, vertices=verts)
    return smooth(bpy.context.object, m, bevel, 3)


def ball(r, loc, m, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=48, ring_count=24)
    o = bpy.context.object
    o.scale = scale
    return smooth(o, m)


def text(s, loc, size, m, rot=(math.radians(90), 0, 0), extrude=.06):
    bpy.ops.object.text_add(location=loc, rotation=rot)
    t = bpy.context.object
    t.data.body = s
    t.data.size = size
    t.data.extrude = extrude
    t.data.bevel_depth = .012
    t.data.align_x = "CENTER"
    t.data.align_y = "CENTER"
    t.data.materials.append(m)
    return t


def scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 48
    sc.cycles.use_denoising = True
    sc.render.film_transparent = True
    sc.render.resolution_x = sc.render.resolution_y = 384
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.exposure = .25
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (1, 1, 1, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = .55
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 2.4
    sun.data.angle = math.radians(10)
    sun.rotation_euler = (math.radians(35), math.radians(-25), math.radians(20))
    sc.collection.objects.link(sun)
    key = bpy.data.objects.new("key", bpy.data.lights.new("key", "AREA"))
    key.data.energy = 260
    key.data.size = 4
    key.location = (-3, -4, 5)
    key.rotation_euler = (math.radians(45), 0, math.radians(-35))
    sc.collection.objects.link(key)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.lens = 60
    sc.collection.objects.link(cam)
    sc.camera = cam
    bpy.ops.object.empty_add(location=(0, 0, .45))
    target = bpy.context.object
    cam.location = (2.2, -5.2, 3.4)
    tr = cam.constraints.new("TRACK_TO")
    tr.target = target
    tr.track_axis = "TRACK_NEGATIVE_Z"
    tr.up_axis = "UP_Y"
    return sc, cam


def gift(body_hex, ribbon_hex, s=1.0, loc=(0, 0, 0)):
    body = mat("gift", body_hex, .3, .7)
    rib = mat("ribbon", ribbon_hex, .25, .8)
    x, y, z = loc
    box((1.3 * s, 1.3 * s, 1.0 * s), (x, y, z + .5 * s), body, .06 * s)
    box((1.42 * s, 1.42 * s, .28 * s), (x, y, z + 1.08 * s), body, .07 * s)
    box((.26 * s, 1.46 * s, 1.26 * s), (x, y, z + .62 * s), rib, .03 * s)
    box((1.46 * s, .26 * s, 1.26 * s), (x, y, z + .62 * s), rib, .03 * s)
    for side in (-1, 1):
        ball(.3 * s, (x + side * .26 * s, y, z + 1.38 * s), rib, (1.1, .55, .75))
    ball(.13 * s, (x, y, z + 1.32 * s), rib)


def coin(m, edge, loc, rot=(0, 0, 0), r=.55):
    c = cyl(r, .16, loc, m, rot)
    t = cyl(r * .78, .17, loc, edge, rot, .01)
    return c, t


def build(kind):
    gold = mat("gold", "FFC21A", .2, .4, .6)
    gold_in = mat("gold_in", "F29E0C", .3, .3, .5)
    white = mat("white", "FFFFFF", .35, .4)
    if kind == "daily":
        gift("33C46A", "FFD23F")
    elif kind == "checkin":
        gift("2EC4C6", "FF5E7E", .9, (-.15, 0, 0))
        green = mat("green", "35D04A", .25, .6)
        cyl(.5, .22, (.75, -.45, .55), green, (math.radians(90), 0, 0))
        t = text("✓", (.75, -.58, .53), .75, white)
    elif kind in ("shop", "coins"):
        for i in range(4):
            coin(gold, gold_in, (-.35 + (i % 2) * .08, .1, .1 + i * .17))
        c, t = coin(gold, gold_in, (.5, -.3, .62), (math.radians(80), 0, math.radians(-15)), .6)
        text("$", (.47, -.42, .62), .7, mat("dollar", "C77A00", .3), (math.radians(80), 0, math.radians(-15)))
    elif kind == "supplies":
        wood = mat("crate", "C9813F", .55, .2)
        dark = mat("crate_dark", "8E5524", .6, .1)
        box((1.6, 1.1, .8), (0, 0, .4), wood, .05)
        for z in (.12, .68):
            box((1.64, 1.14, .1), (0, 0, z), dark, .02)
        for i, (x, y) in enumerate([(-.4, .1), (0, -.1), (.4, .15), (-.15, .25), (.25, -.25)]):
            coin(gold, gold_in, (x, y, .86 + (i % 2) * .08), (math.radians(20), math.radians(10 * i), 0), .3)
        ball(.22, (.55, -.35, 1.0), mat("gem", "3D8BFF", .05, 1), (1, 1, 1.2))
    elif kind == "spin":
        cols = ["FF4F5E", "FFC21A", "35D04A", "3D8BFF", "A24DF0", "FF8A1F", "2EC4C6", "FF6FB5"]
        rot = (math.radians(70), 0, 0)
        import bmesh
        for i, h in enumerate(cols):
            # Pizza ke tukde jaisa hissa (beech + 8 nuqte kinare par), phir mota
            me = bpy.data.meshes.new(f"w{i}")
            bm = bmesh.new()
            pts = [bm.verts.new((0, 0, 0))]
            for k in range(9):
                a = (i + k / 8) * 2 * math.pi / 8
                pts.append(bm.verts.new((math.cos(a) * .95, math.sin(a) * .95, 0)))
            f = bm.faces.new(pts)
            ext = bmesh.ops.extrude_face_region(bm, geom=[f])
            bmesh.ops.translate(bm, vec=(0, 0, .16),
                                verts=[e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)])
            bm.to_mesh(me)
            bm.free()
            o = bpy.data.objects.new(f"w{i}", me)
            bpy.context.scene.collection.objects.link(o)
            o.location = (0, -.08, .9)
            o.rotation_euler = rot
            o.data.materials.append(mat(f"w{i}", h, .3, .6))
        bpy.ops.mesh.primitive_torus_add(major_radius=1.0, minor_radius=.1, location=(0, 0, .9), rotation=rot)
        smooth(bpy.context.object, gold)
        cyl(.18, .3, (0, -.05, .9), gold, rot)
        bpy.ops.mesh.primitive_cone_add(radius1=.18, depth=.35, location=(0, .25, 2.0), rotation=(math.radians(160), 0, 0))
        smooth(bpy.context.object, mat("pointer", "FF4F5E", .3))
        cyl(.08, 1.0, (0, .3, .35), gold, (0, 0, 0))
    elif kind == "noads":
        red = mat("red", "FF4F5E", .25, .7)
        rot = (math.radians(75), 0, 0)
        cyl(.95, .2, (0, 0, .9), white, rot)
        bpy.ops.mesh.primitive_torus_add(major_radius=.95, minor_radius=.14, location=(0, 0, .9), rotation=rot)
        smooth(bpy.context.object, red)
        text("AD", (0, -.12, .9), .72, mat("ink", "3A3F4B", .4), (math.radians(75), 0, 0), .05)
        box((1.75, .2, .24), (0, -.2, .9), red, .08, (math.radians(75), math.radians(-45), 0))
    elif kind == "vip":
        crown_y = 0
        cyl(.8, .55, (0, crown_y, .45), gold, bevel=.05)
        for i in range(5):
            a = i * 2 * math.pi / 5 + math.pi / 2
            x, y = math.cos(a) * .7, math.sin(a) * .7
            bpy.ops.mesh.primitive_cone_add(radius1=.22, depth=.65, location=(x, y, 1.0))
            smooth(bpy.context.object, gold)
            ball(.11, (x, y, 1.36), gold)
        gems = ["FF4F5E", "3D8BFF", "35D04A"]
        for i, h in enumerate(gems):
            a = math.radians(-120 + i * 30)
            ball(.13, (math.cos(a) * .82, math.sin(a) * .82, .45), mat(f"g{i}", h, .05, 1), (1, .6, 1))
    elif kind == "sort":
        cols = ["FF4F5E", "FF4F5E", "3D8BFF", "3D8BFF"]
        for i, h in enumerate(cols):
            m = mat(f"p{i}", h, .3, .7)
            x = -.9 + i * .6
            ball(.28, (x, 0, .42), m, (1, .85, 1.3))
            ball(.24, (x, 0, .98), m)
    elif kind == "shuffle":
        cols = ["FF4F5E", "FFC21A", "35D04A", "3D8BFF", "A24DF0", "FF8A1F"]
        dark = mat("core", "2A2F3A", .4, .2)
        box((1.5, 1.5, 1.5), (0, 0, .85), dark, .1)
        k = 0
        for face in range(3):
            for i in range(3):
                for j in range(3):
                    m = mat(f"c{k}", cols[(i * 3 + j + face * 2) % 6], .25, .7)
                    k += 1
                    a, b = (i - 1) * .48, (j - 1) * .48
                    if face == 0:
                        box((.42, .42, .06), (a, b, 1.62), m, .05)
                    elif face == 1:
                        box((.42, .06, .42), (a, -.77, .85 + b), m, .05)
                    else:
                        box((.06, .42, .42), (.77, a, .85 + b), m, .05)


def frame(sc, cam):
    """Camera ko cheez ke beech par aur itna qareeb rakho ke frame bhar jaye"""
    from mathutils import Vector
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    bpy.context.view_layer.update()
    for o in sc.objects:
        if o.type not in ("MESH", "FONT"):
            continue
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    center = (lo + hi) / 2
    radius = (hi - lo).length / 2
    target = cam.constraints[0].target
    target.location = center
    d = Vector((2.2, -5.2, 3.4)).normalized()
    cam.location = center + d * (radius / .3 / .95)


def render(kind):
    sc, cam = scene()
    build(kind)
    frame(sc, cam)
    sc.render.filepath = os.path.join(OUT, f"{kind}.png")
    bpy.ops.render.render(write_still=True)
    print("ICON", kind, flush=True)


KINDS = ["daily", "checkin", "shop", "supplies", "spin", "noads", "vip", "sort", "shuffle"]
if __name__ == "__main__":
    for k in (ONLY or KINDS):
        render(k)
