# Blender script: har shehar ki nishani (khilona jaisi 3D imarat, apna design).
# Chalane ka tareeqa (project folder mein):
#   blender.exe -b --python tool/blender/make_landmarks.py -- assets/sprites [naam ...]
# Natija: city_<naam>.png (transparent, 512x512). Game aur safar ka map dono
# inhein istemal karte hain (lib/models/city.dart).

import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_icons import ball, box, cyl, frame, mat, scene, smooth  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "assets/sprites"
ONLY = ARGS[1:]
os.makedirs(OUT, exist_ok=True)


def cone(r1, r2, depth, loc, m, verts=48, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(radius1=r1, radius2=r2, depth=depth, location=loc,
                                    vertices=verts, rotation=rot)
    return smooth(bpy.context.object, m)


def dome(r, loc, m, squash=1.0):
    """Aadha gola (gumbad)"""
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=48, ring_count=24)
    o = bpy.context.object
    o.scale = (1, 1, squash)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="DESELECT")
    bpy.ops.object.mode_set(mode="OBJECT")
    for v in o.data.vertices:
        v.select = v.co.z < -1e-4
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.delete(type="VERT")
    bpy.ops.object.mode_set(mode="OBJECT")
    return smooth(o, m)


def lattice(r1, r2, depth, loc, m, thick=.035):
    """Jaali wala 4 kono ka minaar (wireframe)"""
    bpy.ops.mesh.primitive_cone_add(radius1=r1, radius2=r2, depth=depth, location=loc,
                                    vertices=4, rotation=(0, 0, math.pi / 4))
    o = bpy.context.object
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.subdivide(number_cuts=6)
    bpy.ops.object.mode_set(mode="OBJECT")
    w = o.modifiers.new("w", "WIREFRAME")
    w.thickness = thick
    o.data.materials.append(m)
    return o


def palm(x, y, h):
    """Khajoor: thoda jhuka tana aur upar sabz pattay"""
    trunk = mat("trunk", "9A7246", .7, .1)
    leaf = mat("palm", "3E9E45", .5, .2)
    cyl(.06, h, (x, y, h / 2), trunk, (0, math.radians(6), 0), .01, 16)
    top = (x + math.sin(math.radians(6)) * h / 2, y, h)
    for i in range(7):
        a = i * 2 * math.pi / 7
        box((.62, .14, .03), (top[0] + math.cos(a) * .3, top[1] + math.sin(a) * .3, top[2] - .06),
            leaf, .02, (0, math.radians(18), a))


def ground(h, size=(3.2, 3.2)):
    box((size[0], size[1], .18), (0, 0, -.09), mat("ground", h, .6, .2), .08)


def build(name):
    white = mat("white", "F5F3EE", .35, .4)
    if name == "karachi":
        ground("E9D6A8")
        sea = mat("sea", "3AA6E0", .1, .9)
        box((3.2, .7, .1), (0, 1.3, .02), sea, .04)
        dark = mat("arch", "3A4A5C", .4, .2)
        box((1.7, 1.7, 1.15), (0, 0, .575), white, .05)
        # Har taraf oonchi mehraab (neeche chaukor, upar gol)
        for side in range(4):
            a = side * math.pi / 2
            x, y = math.sin(a) * .855, -math.cos(a) * .855
            box((.5, .06, .62), (x, y, .45), dark, .02, (0, 0, a))
            cyl(.25, .06, (x, y, .76), dark, (math.radians(90), 0, a), .01)
        box((1.3, 1.3, .22), (0, 0, 1.26), white, .05)
        cyl(.62, .3, (0, 0, 1.52), white)
        dome(.66, (0, 0, 1.66), white, 1.35)
        cyl(.035, .35, (0, 0, 2.7), mat("gold", "E6B422", .2, .5, .6))
        # Clifton ke saahil jaise do khajoor
        for x, y in ((-1.25, .95), (1.3, .9)):
            palm(x, y, 1.5)
    elif name == "islamabad":
        ground("8CCB6E")
        # Peeche Margalla jaisi hari pahariyan
        hill = mat("hill", "4F9A4A", .7, .1)
        for x, r, h in ((-1.1, 1.0, 1.1), (.15, 1.3, 1.5), (1.3, .95, 1.0)):
            ball(r, (x, 1.45, 0), hill, (1, .5, h / r))
        white = mat("marble", "F7F6F2", .3, .5)
        # Khaime jaisi chhat: 8 kono wali, seedhe tez kinare (flat shading)
        bpy.ops.mesh.primitive_cone_add(radius1=1.05, radius2=0, depth=1.7,
                                        location=(0, 0, 1.05), vertices=8,
                                        rotation=(0, 0, math.pi / 8))
        tent = bpy.context.object
        tent.data.materials.append(white)
        # Har kinare ka beech thoda andar (asli khaime jaisa jhukao)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.subdivide(number_cuts=1)
        bpy.ops.object.mode_set(mode="OBJECT")
        for v in tent.data.vertices:
            k = (v.co.z + .85) / 1.7
            if .05 < k < .95:
                f = 1 - .18 * math.sin(math.pi * k)
                v.co.x *= f
                v.co.y *= f
        box((2.1, 2.1, .2), (0, 0, .1), mat("base", "D9D6CC", .5, .2), .04)
        # Chaar patle, oonche minaar
        for x in (-.95, .95):
            for y in (-.95, .95):
                cyl(.07, 2.5, (x, y, 1.25), white, verts=24)
                cyl(.1, .06, (x, y, 1.9), white, verts=24)
                cone(.08, 0, .4, (x, y, 2.7), white, 24)
    elif name == "lahore":
        ground("8BCB6A")
        white = mat("marble", "F3F1EA", .35, .45)
        red = mat("sandstone", "B5523B", .5, .3)
        # Phool ki pattiyon jaisa chabootra
        cyl(1.25, .16, (0, 0, .08), red, verts=64)
        for i in range(8):
            a = i * math.pi / 4
            ball(.42, (math.cos(a) * .72, math.sin(a) * .72, .3), white, (1, 1, .55))
        cyl(.55, .3, (0, 0, .3), white, verts=48)
        # Oonchai ke saath patla hota minar, beech mein chhajje
        cone(.36, .17, 2.6, (0, 0, 1.75), white, 32)
        for z, r in ((1.2, .36), (2.1, .28), (2.9, .22)):
            cyl(r, .06, (0, 0, z), white, verts=32)
        dome(.2, (0, 0, 3.05), white, 1.4)
        cyl(.02, .3, (0, 0, 3.45), mat("gold", "E6B422", .2, .5, .6))
    elif name == "dubai":
        ground("EED9A9")
        glass = mat("glass", "A9C8E0", .08, .9, .5)
        h = 0.0
        for i, (r, d) in enumerate([(.55, .9), (.45, .8), (.36, .7), (.28, .6), (.2, .5), (.13, .45)]):
            cyl(r, d, (0, 0, h + d / 2), glass, verts=6)
            h += d
        cone(.08, .0, 1.1, (0, 0, h + .55), mat("spire", "D8E2EA", .15, .6, .7))
    elif name == "london":
        ground("7FBF62")
        stone = mat("stone", "D9B98A", .5, .3)
        box((.8, .8, 2.6), (0, 0, 1.3), stone, .03)
        for side in range(4):
            a = side * math.pi / 2
            loc = (math.sin(a) * .41, -math.cos(a) * .41, 2.1)
            cyl(.3, .04, loc, white, (math.radians(90), 0, a), .01)
            hand = mat("hand", "222831", .4)
            box((.03, .02, .22), (loc[0] - math.cos(a) * 0, loc[1], 2.18), hand, .005,
                (0, 0, a))
        box((.9, .9, .25), (0, 0, 2.62), stone, .03)
        cone(.62, 0, 1.0, (0, 0, 3.25), mat("roof", "3D5B55", .4, .3), 4, (0, 0, math.pi / 4))
        # Saath mein chhoti laal double-decker
        red = mat("bus", "E0302F", .25, .7)
        box((.55, 1.3, .7), (1.0, -.6, .38), red, .08)
        glass = mat("glass", "22303F", .05, 1)
        for z in (.3, .58):
            box((.57, 1.1, .13), (1.0, -.6, z), glass, .03)
    elif name == "paris":
        ground("A6D17E")
        bronze = mat("bronze", "8A6A4A", .45, .4, .4)
        lattice(1.0, .45, 1.2, (0, 0, .6), bronze, .05)
        box((1.0, 1.0, .1), (0, 0, 1.22), bronze, .02)
        lattice(.45, .18, 1.5, (0, 0, 2.0), bronze, .035)
        box((.42, .42, .08), (0, 0, 2.76), bronze, .02)
        lattice(.18, .03, 1.2, (0, 0, 3.4), bronze, .025)
    elif name == "newyork":
        ground("9AA7B5")
        glass = mat("glass", "6E8FB3", .1, .9, .4)
        stone = mat("deco", "C9C2B3", .4, .3)
        box((1.0, 1.0, 1.4), (0, 0, .7), stone, .03)
        box((.75, .75, 1.0), (0, 0, 1.9), stone, .03)
        box((.5, .5, .8), (0, 0, 2.8), stone, .03)
        cone(.2, .0, .9, (0, 0, 3.65), mat("spire", "D8DEE5", .15, .6, .8))
        for x, y, hgt in ((-1.1, .4, 1.8), (1.1, .5, 2.2), (-.9, -.8, 1.2), (1.0, -.7, 1.4)):
            box((.6, .6, hgt), (x, y, hgt / 2), glass, .02)
    elif name == "tokyo":
        ground("F3C3D3")
        red = mat("red", "E8432F", .35, .5)
        lattice(.9, .38, 1.4, (0, 0, .7), red, .05)
        box((.85, .85, .2), (0, 0, 1.45), white, .04)
        lattice(.38, .16, 1.3, (0, 0, 2.2), red, .04)
        box((.45, .45, .16), (0, 0, 2.9), white, .03)
        cone(.08, 0, .9, (0, 0, 3.45), red)
        # Saath mein chhota pagoda
        for i in range(3):
            box((.7 - i * .15, .7 - i * .15, .25), (1.15, -.6, .15 + i * .32), white, .02)
            cone(.55 - i * .12, .1, .14, (1.15, -.6, .33 + i * .32), mat(f"pr{i}", "3B3F4A", .4), 4,
                 (0, 0, math.pi / 4))


NAMES = ["karachi", "lahore", "islamabad", "dubai", "london", "paris", "newyork", "tokyo"]
for n in (ONLY or NAMES):
    sc, cam = scene()
    sc.render.resolution_x = sc.render.resolution_y = 512
    build(n)
    frame(sc, cam)
    sc.render.filepath = os.path.join(OUT, f"city_{n}.png")
    bpy.ops.render.render(write_still=True)
    print("CITY", n, flush=True)
