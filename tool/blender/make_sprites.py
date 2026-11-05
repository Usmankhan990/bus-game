# Blender script: game ki gaadiyon aur passengers ki 3D tasveerein (sprites) banata hai.
# Sab model yahin code se bante hain (kisi ki copy nahi).
#
# Chalane ka tareeqa (project folder mein):
#   blender.exe -b --python tool/blender/make_sprites.py -- assets/sprites
#   (aakhir mein "quick" likhein to sirf ek gaadi aur ek passenger banega)
#
# Natija:
#   vehicle_<lambai>_<rang>_<rukh>.webp  (rukh 0-15, har 22.5 degree, 0 = upar)
#   person_<rang>.webp

import math
import os
import sys

import bpy

ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "assets/sprites"
QUICK = "quick" in ARGS
os.makedirs(OUT, exist_ok=True)

# Game ke rang (lib/game/render/palette.dart ke busColors ke mutabiq)
# Halke (pastel) khilone jaise rang, magar ek doosre se saaf alag
COLORS = [
    "F0646E",  # laal (coral)
    "5BA4F2",  # neela
    "4CC98C",  # hara (mint)
    "FFCF4A",  # peela
    "A98AEE",  # jamni (lavender)
    "FF9E52",  # narangi (peach)
    "F58BC4",  # gulabi
    "48CFD3",  # firozi
]

PX_PER_UNIT = 100  # 1 board unit = itne pixel
BODY_W = 0.78  # gaadi ki chaurai (units), game ke BusData.bodyWidth jaisi
TILT = math.radians(24)  # camera kitna tirchha (game mein bhi yahi: SpriteBank.tilt)
DIRECTIONS = 16


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_color(h):
    r, g, b = (int(h[i : i + 2], 16) / 255 for i in (0, 2, 4))
    return (srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b), 1.0)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 14
    scene.cycles.use_denoising = True
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "WEBP"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.quality = 88
    scene.view_settings.view_transform = "Standard"

    world = bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (1, 1, 1, 1)
    bg.inputs[1].default_value = 0.6

    # Suraj: upar baayen se (har tasveer mein ek hi taraf se, taa ke saaye ek jaise hon)
    sun_data = bpy.data.lights.new("Sun", type="SUN")
    sun_data.energy = 3.6
    sun_data.angle = math.radians(6)
    sun = bpy.data.objects.new("Sun", sun_data)
    sun.rotation_euler = (math.radians(16), math.radians(-14), math.radians(15))
    scene.collection.objects.link(sun)

    # Zameen jo sirf saaya pakadti hai (tasveer mein zameen nazar nahi aati)
    bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, 0))
    ground = bpy.context.active_object
    ground.is_shadow_catcher = True
    return scene


def material(name, rgba, rough=0.35, coat=0.4, emission=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = rgba
    p.inputs["Roughness"].default_value = rough
    if "Coat Weight" in p.inputs:
        p.inputs["Coat Weight"].default_value = coat
    if emission is not None:
        p.inputs["Emission Color"].default_value = emission
        p.inputs["Emission Strength"].default_value = 1.2
    return m


def rounded_box(size, loc, bevel, mat, parent, segments=5):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.active_object
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    mod = o.modifiers.new("bevel", "BEVEL")
    mod.width = bevel
    mod.segments = segments
    bpy.ops.object.shade_smooth()
    o.data.materials.append(mat)
    o.parent = parent
    return o


def cylinder(loc, radius, depth, mat, parent, rot=(0, math.radians(90), 0)):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=loc, rotation=rot)
    o = bpy.context.active_object
    mod = o.modifiers.new("bevel", "BEVEL")
    mod.width = radius * 0.3
    mod.segments = 3
    bpy.ops.object.shade_smooth()
    o.data.materials.append(mat)
    o.parent = parent
    return o


def sphere(loc, radius, mat, parent=None, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=loc, segments=48, ring_count=24)
    o = bpy.context.active_object
    o.scale = scale
    bpy.ops.object.shade_smooth()
    o.data.materials.append(mat)
    if parent:
        o.parent = parent
    return o


def tilted_camera(scene, frame_units):
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = frame_units
    cam = bpy.data.objects.new("Cam", cam_data)
    d = 12
    cam.location = (0, -d * math.sin(TILT), d * math.cos(TILT))
    cam.rotation_euler = (TILT, 0, 0)
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.resolution_x = round(frame_units * PX_PER_UNIT)
    scene.render.resolution_y = round(frame_units * PX_PER_UNIT)
    scene.render.resolution_percentage = 100


def build_vehicle(length, color_hex, with_arrow=True):
    """Khilone jaisi gaadi. Aage ka hissa +Y taraf. Sab hisse ek 'root' ke bachche."""
    L = length - 0.12
    W = BODY_W
    bpy.ops.object.empty_add(location=(0, 0, 0))
    root = bpy.context.active_object

    base = hex_color(color_hex)
    body_mat = material("body", base, rough=0.28, coat=0.7)
    dark = tuple(c * 0.5 for c in base[:3]) + (1,)
    trim_mat = material("trim", dark, rough=0.5, coat=0.2)
    glass_mat = material("glass", hex_color("26385A"), rough=0.08, coat=1.0)
    tire_mat = material("tire", hex_color("24262C"), rough=0.75, coat=0.0)
    light_mat = material("light", hex_color("FFF6C2"), emission=hex_color("FFF6C2"))
    tail_mat = material("tail", hex_color("FF3B30"), rough=0.2)
    white_mat = material("white", hex_color("F4F6FA"), rough=0.3, coat=0.5)

    # Neeche ka gehra chassis aur moti body
    rounded_box((W, L, 0.18), (0, 0, 0.17), 0.07, trim_mat, root)
    rounded_box((W * 0.98, L * 0.99, 0.36), (0, 0, 0.4), 0.13, body_mat, root)

    if length <= 2:
        cab_len, cab_y, cab_h = L * 0.52, -L * 0.06, 0.3
    else:
        cab_len, cab_y, cab_h = L - 0.42, -0.08, 0.34
    cab_z = 0.58 + cab_h / 2
    # Cabin ka sheesha (charon taraf)
    rounded_box((W * 0.86, cab_len, cab_h), (0, cab_y, cab_z), 0.1, glass_mat, root)
    # Van/bus: sheeshon ke beech khambe (khidkiyon jaisa)
    if length >= 3:
        n = int(cab_len / 0.42)
        for k in range(1, n):
            y = cab_y - cab_len / 2 + k * cab_len / n
            rounded_box((W * 0.88, 0.07, cab_h * 0.96), (0, y, cab_z), 0.02, body_mat, root, 2)
    # Chhat: body se thoda halka rang, taa ke upar se shakal saaf dikhe
    roof_z = cab_z + cab_h / 2 + 0.03
    roof_mat = material("roof", tuple(c + (1 - c) * 0.16 for c in base[:3]) + (1,), rough=0.3, coat=0.6)
    rounded_box((W * 0.84, cab_len - 0.04, 0.07), (0, cab_y, roof_z), 0.04, roof_mat, root, 4)
    # Chhat par bada safed teer (gaadi ke rukh mein, gehre kinare ke saath)
    arrow_len = min(cab_len * 0.8, 0.95)
    if with_arrow:
        arrow(W * 0.62, arrow_len, (0, cab_y, roof_z + 0.035), white_mat, trim_dark_mat(), root)

    # Pahiye
    r = 0.16
    ys = [L / 2 - 0.32, -L / 2 + 0.3]
    if length >= 4:
        ys.append(-L / 2 + 0.78)
    for y in ys:
        for x in (-W / 2 + 0.02, W / 2 - 0.02):
            cylinder((x, y, r), r, 0.14, tire_mat, root)

    # Aage lights, peeche laal lights
    for x in (-W * 0.3, W * 0.3):
        sphere((x, L / 2 - 0.03, 0.42), 0.06, light_mat, root, scale=(1, 0.6, 0.8))
        sphere((x, -L / 2 + 0.03, 0.42), 0.05, tail_mat, root, scale=(1, 0.6, 0.8))
    return root


def trim_dark_mat():
    return material("arrow_edge", hex_color("3A3F4B"), rough=0.5, coat=0.0)


def arrow(width, length, loc, mat, edge_mat, parent):
    """Teer ki 2D shakal ko thoda utha kar (extrude) 3D banana. Nok +Y taraf."""
    import bmesh

    def shape(scale):
        w, l = width * scale, length * scale
        return [
            (0, l / 2),
            (w / 2, l * 0.02),
            (w * 0.17, l * 0.02),
            (w * 0.17, -l / 2),
            (-w * 0.17, -l / 2),
            (-w * 0.17, l * 0.02),
            (-w / 2, l * 0.02),
        ]

    for scale, mat_i, height, z in ((1.18, edge_mat, 0.02, 0.0), (1.0, mat, 0.035, 0.012)):
        mesh = bpy.data.meshes.new("arrow")
        bm = bmesh.new()
        verts = [bm.verts.new((x, y, 0)) for x, y in shape(scale)]
        face = bm.faces.new(verts)
        ext = bmesh.ops.extrude_face_region(bm, geom=[face])
        moved = [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]
        bmesh.ops.translate(bm, vec=(0, 0, height), verts=moved)
        bm.to_mesh(mesh)
        bm.free()
        o = bpy.data.objects.new("arrow", mesh)
        bpy.context.scene.collection.objects.link(o)
        o.location = (loc[0], loc[1], loc[2] + z)
        o.data.materials.append(mat_i)
        o.parent = parent


def build_person(color_hex):
    """Chhota cartoon insaan: gol sar, lamba gol jism, baazu, pair aur aankhen.
    Poora ek hi rang (hujoom mein rang door se pehchana jaye). Munh -Y (camera) ki taraf."""
    base = hex_color(color_hex)
    mat = material("person", base, rough=0.3, coat=0.7)
    dark = material("person_dark", tuple(c * 0.55 for c in base[:3]) + (1,), rough=0.5)
    eye = material("eye", hex_color("1E1E28"), rough=0.3)
    shine = material("shine", hex_color("FFFFFF"), rough=0.2, emission=hex_color("FFFFFF"))
    # Pair
    for x in (-0.1, 0.1):
        sphere((x, 0, 0.07), 0.09, dark, scale=(1, 1.3, 0.7))
    # Jism (neeche se chaura gol)
    sphere((0, 0, 0.36), 0.25, mat, scale=(1, 0.85, 1.25))
    # Baazu
    for x in (-0.25, 0.25):
        sphere((x, 0, 0.38), 0.085, mat, scale=(1, 1, 2.0))
    # Sar
    sphere((0, 0, 0.84), 0.22, mat)
    # Aankhen (camera ki taraf)
    for x in (-0.075, 0.075):
        sphere((x, -0.19, 0.87), 0.04, eye, scale=(1, 0.6, 1.2))
        sphere((x - 0.012, -0.215, 0.89), 0.012, shine)


# ---------------- Render ----------------

lengths = (3,) if QUICK else (2, 3, 4)
colors = list(enumerate(COLORS))[:1] if QUICK else list(enumerate(COLORS))
dirs = (0, 2) if QUICK else range(DIRECTIONS)

for length in lengths:
    for ci, col in colors:
        todo = [
            di
            for di in dirs
            if not os.path.exists(os.path.join(OUT, f"vehicle_{length}_{ci}_{di}.webp"))
        ]
        if not todo:
            continue
        scene = reset_scene()
        root = build_vehicle(length, col)
        # Tasveer itni bari ho ke har rukh mein gaadi poori aaye
        tilted_camera(scene, length + 0.9)
        for di in dirs:
            path = os.path.join(OUT, f"vehicle_{length}_{ci}_{di}.webp")
            # Pehle se bani tasveer dobara na banao (render beech mein ruk jaye to aage se chale)
            if os.path.exists(path) and os.path.getsize(path) > 0:
                continue
            # Game mein angle ghadi ki sui ki taraf; Blender mein Z-rotation ulti taraf
            root.rotation_euler = (0, 0, -di * 2 * math.pi / DIRECTIONS)
            scene.render.filepath = os.path.join(OUT, f"vehicle_{length}_{ci}_{di}.webp")
            bpy.ops.render.render(write_still=True)
            print("BANI:", scene.render.filepath, flush=True)

for ci, col in colors:
    scene = reset_scene()
    scene.cycles.samples = 32
    build_person(col)
    tilted_camera(scene, 1.15)
    scene.render.resolution_x = 112
    scene.render.resolution_y = 112
    scene.camera.location = (
        0,
        -12 * math.sin(TILT),
        0.45 + 12 * math.cos(TILT),
    )
    scene.render.filepath = os.path.join(OUT, f"person_{ci}.webp")
    bpy.ops.render.render(write_still=True)
    print("BANI:", scene.render.filepath, flush=True)

# Home screen ke liye saamne se dikhte log (line mein khade)
for ci, col in colors:
    path = os.path.join(OUT, f"person_front_{ci}.webp")
    if os.path.exists(path) and os.path.getsize(path) > 0:
        continue
    scene = reset_scene()
    scene.cycles.samples = 32
    build_person(col)
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 1.25
    cam = bpy.data.objects.new("Cam", cam_data)
    front = math.radians(76)
    cam.location = (0, -12 * math.sin(front), 0.52 + 12 * math.cos(front))
    cam.rotation_euler = (front, 0, 0)
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.resolution_x = 128
    scene.render.resolution_y = 128
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("BANI:", path, flush=True)


# ---------------- Home screen ki badi bus ----------------
# Saamne se khadi oonchi city bus: bada sheesha, upar gehri plate (game wahan
# "LEVEL X" likhti hai), lights, bumper. Apna design, kisi ki copy nahi.
def build_home_bus(color_hex):
    bpy.ops.object.empty_add(location=(0, 0, 0))
    root = bpy.context.active_object
    base = hex_color(color_hex)
    body = material("body", base, rough=0.3, coat=0.8)
    dark = material("trim", tuple(c * 0.45 for c in base[:3]) + (1,), rough=0.5)
    white = material("white", hex_color("F7F8FB"), rough=0.3, coat=0.5)
    glass = material("glass", hex_color("2A3B5E"), rough=0.06, coat=1.0)
    plate = material("plate", hex_color("2B2F3A"), rough=0.4, coat=0.2)
    grey = material("grey", hex_color("5B606C"), rough=0.5)
    tire = material("tire", hex_color("24262C"), rough=0.8, coat=0.0)
    light = material("light", hex_color("FFF6C2"), emission=hex_color("FFF6C2"))
    amber = material("amber", hex_color("FFB238"), emission=hex_color("FFB238"))

    W, L, H = 2.3, 5.0, 2.7
    fy = L / 2  # saamne wala chehra
    # Jism: neeche gehra, beech rangeen, chhat safed
    rounded_box((W, L, 0.5), (0, 0, 0.45), 0.12, dark, root)
    rounded_box((W, L, H - 0.55), (0, 0, 0.55 + (H - 0.55) / 2), 0.22, body, root)
    rounded_box((W * 0.92, L * 0.95, 0.16), (0, 0, H + 0.03), 0.07, white, root)
    # Side ki khirkiyan
    for side in (-1, 1):
        rounded_box((0.06, L * 0.86, 0.8), (side * W / 2, -0.1, 1.85), 0.04, glass, root)
        for k in range(1, 5):
            y = -0.1 - L * 0.43 + k * L * 0.86 / 5
            rounded_box((0.08, 0.09, 0.82), (side * W / 2, y, 1.85), 0.02, body, root, 2)
    # Saamne ka bada sheesha aur beech ki patti
    rounded_box((W * 0.84, 0.1, 1.0), (0, fy, 1.62), 0.1, glass, root)
    rounded_box((0.06, 0.12, 1.0), (0, fy + 0.01, 1.62), 0.02, body, root, 2)
    # Upar plate (safed kinara + gehri plate)
    rounded_box((W * 0.74, 0.1, 0.42), (0, fy + 0.01, 2.43), 0.05, white, root, 3)
    rounded_box((W * 0.68, 0.12, 0.33), (0, fy + 0.02, 2.43), 0.04, plate, root, 3)
    # Lights, grille, bumper
    for x in (-0.78, 0.78):
        sphere((x, fy + 0.02, 0.86), 0.17, white, root, scale=(1, 0.4, 1))
        sphere((x, fy + 0.07, 0.86), 0.13, light, root, scale=(1, 0.4, 1))
        sphere((x * 1.18, fy + 0.04, 0.86), 0.06, amber, root, scale=(1, 0.4, 1))
    for k in range(3):
        rounded_box((0.8, 0.08, 0.06), (0, fy + 0.02, 0.74 + k * 0.12), 0.02, grey, root, 2)
    rounded_box((W * 1.02, 0.3, 0.26), (0, fy + 0.04, 0.36), 0.1, grey, root)
    # Shishay (mirrors) dono taraf
    for side in (-1, 1):
        # Jism se nikalta bazu aur us par sheesha
        rounded_box((0.3, 0.06, 0.06), (side * (W / 2 + 0.1), fy - 0.15, 2.05), 0.02, dark, root, 2)
        rounded_box((0.12, 0.1, 0.36), (side * (W / 2 + 0.24), fy - 0.12, 1.88), 0.04, dark, root, 3)
    # Pahiye
    for y in (L / 2 - 0.9, -L / 2 + 0.9):
        for side in (-1, 1):
            cylinder((side * (W / 2 - 0.12), y, 0.42), 0.42, 0.34, tire, root)
    return root


scene = reset_scene()
scene.cycles.samples = 64
build_home_bus(COLORS[0])
bpy.ops.object.empty_add(location=(0, 1.2, 1.35))
target = bpy.context.active_object
cam_data = bpy.data.cameras.new("Cam")
cam_data.lens = 100
cam = bpy.data.objects.new("Cam", cam_data)
cam.location = (1.6, 2.5 + 11.0, 3.0)
scene.collection.objects.link(cam)
track = cam.constraints.new("TRACK_TO")
track.target = target
track.track_axis = "TRACK_NEGATIVE_Z"
track.up_axis = "UP_Y"
scene.camera = cam
scene.render.resolution_x = 520
scene.render.resolution_y = 560
scene.render.filepath = os.path.join(OUT, "home_bus.webp")
bpy.ops.render.render(write_still=True)
print("BANI:", scene.render.filepath, flush=True)
