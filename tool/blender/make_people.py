# Blender script: hujoom ke chhote 3D log (apna design: topi, hoodie, pair).
# Chalane ka tareeqa (project folder mein):
#   blender.exe -b --python tool/blender/make_people.py -- <out folder> [quick]
# Natija: walker_<rang>_<rukh>_<frame>.webp
#   rang 0-7 (gaadiyon jaise), rukh 0-7 (0 = screen ke upar ki taraf munh,
#   ghadi ki sui ki taraf 45 degree), frame 0-3 (0 aur 2 = khade, 1 aur 3 = qadam).
# Camera gaadiyon wala hi (ortho, 45 degree jhuka): lib/game/render/sprite_bank.dart

import math
import os
import sys

import bpy

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "assets/people"
QUICK = "quick" in ARGS
os.makedirs(OUT, exist_ok=True)

COLORS = ['EF394C', '329CF5', '20BD78', 'FFD21C', '9B35ED', 'FF8B24', 'ED48BF', '22D8D5']
TILT = math.radians(45)
FRAME = 1.2   # tasveer kitne world units ki (game: PassengerPainter)
AIM_Z = .55    # camera kis oonchai par nishana leta hai
RES = 96


def srgb(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def col(h):
    return tuple(srgb(int(h[i:i + 2], 16) / 255) for i in (0, 2, 4)) + (1,)


def mat(name, h, rough=.45, coat=.2):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = col(h)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Coat Weight"].default_value = coat
    return m


def smooth(o, m):
    bpy.ops.object.shade_smooth()
    o.data.materials.append(m)
    return o


def ball(r, loc, m, parent, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=32, ring_count=16)
    o = bpy.context.object
    o.scale = scale
    o.parent = parent
    return smooth(o, m)


def limb(r, length, top, m, parent):
    """Upar [top] par jod (pivot) wala gol-sira cylinder; parent ko ghumane se jhoolta hai"""
    bpy.ops.object.empty_add(location=top)
    pivot = bpy.context.object
    pivot.parent = parent
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=length, vertices=20,
                                        location=(top[0], top[1], top[2] - length / 2))
    c = bpy.context.object
    smooth(c, m)
    c.parent = pivot
    c.matrix_parent_inverse = pivot.matrix_world.inverted()
    end = ball(r, (top[0], top[1], top[2] - length), m, pivot)
    end.matrix_parent_inverse = pivot.matrix_world.inverted()
    return pivot


def setup():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 16
    sc.cycles.use_denoising = True
    sc.render.threads_mode = "FIXED"
    sc.render.threads = 8
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "WEBP"
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.image_settings.quality = 92
    sc.render.resolution_x = sc.render.resolution_y = RES
    sc.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("w")
    sc.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (.75, .82, 1, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = .35
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 2.8
    sun.data.angle = math.radians(15)
    sun.rotation_euler = (math.radians(20), math.radians(-16), math.radians(25))
    sc.collection.objects.link(sun)
    area = bpy.data.objects.new("soft", bpy.data.lights.new("soft", "AREA"))
    area.data.energy = 40
    area.data.size = 4
    area.location = (-2, -3, 4)
    area.rotation_euler = (math.radians(40), 0, math.radians(-30))
    sc.collection.objects.link(area)
    bpy.ops.mesh.primitive_plane_add(size=10)
    bpy.context.object.is_shadow_catcher = True
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = FRAME
    cam.location = (0, -12 * math.sin(TILT), AIM_Z + 12 * math.cos(TILT))
    cam.rotation_euler = (TILT, 0, 0)
    sc.collection.objects.link(cam)
    sc.camera = cam
    return sc


def build():
    """Insaan: munh +Y ki taraf. Rang wale materials wapis deta hai."""
    bpy.ops.object.empty_add()
    root = bpy.context.object
    shirt = mat("shirt", COLORS[0], .5, .3)
    cap = mat("cap", COLORS[0], .35, .5)
    skin = mat("skin", "F2C29B", .55, .1)
    pants = mat("pants", "34405A", .7, 0)
    shoe = mat("shoe", "F4F4F4", .5, .1)
    eye = mat("eye", "1C1F26", .3, .4)

    legs = [limb(.075, .3, (x, 0, .36), pants, root) for x in (-.09, .09)]
    for lg in legs:
        s = ball(.085, (lg.location.x, .035, .06), shoe, lg, (1, 1.35, .7))
        s.matrix_parent_inverse = lg.matrix_world.inverted()
    # Hoodie (gol jism) aur peeche hood
    ball(.23, (0, 0, .56), shirt, root, (1, .8, 1.08))
    ball(.13, (0, -.14, .76), shirt, root, (1.2, .7, .6))
    arms = [limb(.06, .28, (x, 0, .7), shirt, root) for x in (-.24, .24)]
    for a in arms:
        h = ball(.06, (a.location.x, 0, .4), skin, a)
        h.matrix_parent_inverse = a.matrix_world.inverted()
    # Sar, aankhen, topi aur us ka chhajja (aage)
    ball(.175, (0, 0, .93), skin, root)
    for x in (-.06, .06):
        ball(.026, (x, .158, .93), eye, root, (1, .6, 1.25))
    # Chhoti beanie topi (sirf sar ka upar wala hissa), chehra khula
    ball(.18, (0, -.02, 1.0), cap, root, (1, 1, .62))
    ball(.035, (0, -.02, 1.11), mat("pom", "FFFFFF", .6, 0), root)
    return root, legs, arms, (shirt, cap)


def pose(legs, arms, frame):
    # 0, 2: seedhe khade; 1: baayan pair aage, 3: daayan pair aage
    swing = {0: 0, 1: 1, 2: 0, 3: -1}[frame] * math.radians(28)
    legs[0].rotation_euler = (swing, 0, 0)
    legs[1].rotation_euler = (-swing, 0, 0)
    arms[0].rotation_euler = (-swing * .9, 0, 0)
    arms[1].rotation_euler = (swing * .9, 0, 0)


sc = setup()
root, legs, arms, colored = build()
for ci in ([0] if QUICK else range(8)):
    for m in colored:
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = col(COLORS[ci])
    for d in ([0, 2, 3, 4] if QUICK else range(8)):
        root.rotation_euler = (0, 0, -d * 2 * math.pi / 8)
        for fr in range(4):
            path = os.path.join(OUT, f"walker_{ci}_{d}_{fr}.webp")
            if os.path.exists(path):
                continue
            pose(legs, arms, fr)
            sc.render.filepath = path
            bpy.ops.render.render(write_still=True)
    print("PEOPLE", ci, flush=True)
print("DONE", flush=True)
