"""Render the rounded in-game bus models. Never overwrites legacy sprites.

With Blender: blender -b --python tool/blender/render_reference_sprites.py -- assets/sprites_v2
With bpy: PYTHONPATH=<bpy install> python tool/blender/render_reference_sprites.py -- assets/sprites_v2
Append 'quick' for the red medium bus facing up, right and diagonally.
"""
import math
import os
import sys
import time
from pathlib import Path

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from sprite_geometry import (
    arrow, cylinder, hex_color, material, rounded_box, sphere,
)

args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
project = Path(__file__).resolve().parents[2]
out = str(project / (args[0] if args else 'assets/sprites_v2'))
quick = 'quick' in args
os.makedirs(out, exist_ok=True)

COLORS = ['EF394C', '329CF5', '20BD78', 'FFD21C', '9B35ED', 'FF8B24', 'ED48BF', '22D8D5']
TILT = math.radians(45)  # game mein bhi yahi: SpriteBank.tilt


def scene_setup(length):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE' if 'eevee' in args else 'CYCLES'
    if 'eevee' in args:
        scene.eevee.taa_render_samples = 16
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 18
    scene.cycles.use_adaptive_sampling = True
    scene.cycles.adaptive_min_samples = 4
    scene.cycles.adaptive_threshold = .10
    scene.cycles.use_denoising = True
    scene.render.threads_mode = 'FIXED'
    scene.render.threads = 8
    scene.render.film_transparent = True
    scene.render.use_persistent_data = True
    scene.render.image_settings.file_format = 'WEBP'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.image_settings.quality = 94
    scene.view_settings.view_transform = 'Standard'
    scene.view_settings.look = 'None'
    scene.view_settings.exposure = 0
    world = bpy.data.worlds.new('Soft studio')
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs[0].default_value = (.72, .80, 1.0, 1)
    world.node_tree.nodes['Background'].inputs[1].default_value = .22
    sun_data = bpy.data.lights.new('Soft sun', 'SUN')
    sun_data.energy = 2.6
    sun_data.angle = math.radians(12)
    sun = bpy.data.objects.new('Soft sun', sun_data)
    sun.rotation_euler = (math.radians(20), math.radians(-16), math.radians(25))
    scene.collection.objects.link(sun)
    light = bpy.data.lights.new('Large softbox', 'AREA')
    light.energy = 120
    light.shape = 'DISK'
    light.size = 5
    obj = bpy.data.objects.new('Large softbox', light)
    scene.collection.objects.link(obj)
    obj.location = (-3, 4, 7)
    obj.rotation_euler = (.25, -.35, -.2)
    fill = bpy.data.lights.new('Fill', 'AREA')
    fill.energy = 35
    fill.size = 4
    obj = bpy.data.objects.new('Fill', fill)
    scene.collection.objects.link(obj)
    obj.location = (4, -1, 5)
    if 'eevee' not in args:
        bpy.ops.mesh.primitive_plane_add(size=40)
        bpy.context.object.is_shadow_catcher = True
    camera_data = bpy.data.cameras.new('Camera')
    camera_data.type = 'ORTHO'
    camera_data.ortho_scale = length + .9
    camera = bpy.data.objects.new('Camera', camera_data)
    camera.location = (0, -12 * math.sin(TILT), 12 * math.cos(TILT))
    camera.rotation_euler = (TILT, 0, 0)
    scene.collection.objects.link(camera)
    scene.camera = camera
    scene.render.resolution_x = round((length + .9) * 90)
    scene.render.resolution_y = scene.render.resolution_x
    scene.render.resolution_percentage = 100
    return scene


def lighter(base, k):
    return tuple(c + (1 - c) * k for c in base[:3]) + (1,)


def darker(base, k):
    return tuple(c * k for c in base[:3]) + (1,)


def build_bus(length, color, with_arrow=True, style=''):
    """Teen alag shakal ki khilona gaadiyan (apna design):
    2 = car (bonnet, beech mein sheeshe wala cabin, dikki),
    3 = van (chhoti nose, 3 khirkiyan), 4 = bus (lambi, 5 khirkiyan, safed patti).
    Chaurai, lambai aur chhat ki oonchai (~0.85) game ke hit-test ke mutabiq hain.
    [style]: Garage ki khaas gaadiyan (taxi, sports, police, icecream, school, double).
    """
    w, l = .78, length - .12
    bpy.ops.object.empty_add()
    root = bpy.context.object
    base = hex_color(color)
    # Chamakdar car paint (coat se roshni ka aks), gehre tinted sheeshe
    body = material('Body', base, rough=.24, coat=.5)
    roof = material('Roof', lighter(base, .04), rough=.22, coat=.5)
    skirt = material('Skirt', darker(base, .5), rough=.45)
    # Neela-gehra sheesha (aasman ka aks), upar se bhi khirkiyan saaf dikhen
    glass = material('Side glass', hex_color('2C4F70'), rough=.04, coat=1.0)
    windshield = material('Windshield', hex_color('1F3A55'), rough=.03, coat=1.0)
    tire = material('Rubber', hex_color('1F2329'), rough=.8, coat=0)
    hub = material('Rim', hex_color('D9DEE4'), rough=.15, coat=.8)
    chrome = material('Chrome', hex_color('E3E8EE'), rough=.12, coat=.8)
    seam = material('Seam', darker(base, .35), rough=.5)
    ac = material('AC unit', hex_color('BFC6CF'), rough=.4, coat=.2)
    white = material('White', hex_color('FFFFFF'), rough=.45)
    edge = material('Arrow outline', hex_color('33465A'), rough=.5)
    headlamp = material('Headlamp', hex_color('FFF6C2'), rough=.3, emission=hex_color('FFF6C2'))
    taillamp = material('Rear lamp', hex_color('FF5A4E'), rough=.3)

    # Chassis aur neeche ki moti body
    rounded_box((w, l, .16), (0, 0, .17), .07, skirt, root)
    rounded_box((w * .98, l * .99, .30), (0, 0, .38), .14, body, root, 6)
    # Kandhe ki halki ubhri lakeer (body ko gehrai deti hai)
    rounded_box((w * 1.0, l * .93, .035), (0, 0, .47), .015, body, root, 2)

    if length <= 2:
        # Car: cabin beech se thoda peeche, aage lamba bonnet
        cab_l, cab_y, pillars = l * .50, -l * .07, 2
        band_w, roof_w, top = w * .84, w * .74, .85
    elif length == 3:
        cab_l, cab_y, pillars = l - .34, -.08, 3
        band_w, roof_w, top = w * .92, w * .82, .80
    else:
        cab_l, cab_y, pillars = l - .28, -.05, 5
        band_w, roof_w, top = w * .92, w * .84, .80
    band_h = .26
    if style == 'sports':
        # Neechi, lambi bonnet wali tez gaadi
        cab_l, cab_y, band_h, top = l * .40, -l * .12, .17, .72
    elif style == 'school':
        # Aage nikli hui nose (engine bahar)
        cab_l, cab_y = l - .8, -.33
    elif style == 'double':
        top = 1.16

    # Sheeshon ki patti
    band_z = .53 + band_h / 2
    rounded_box((band_w, cab_l, band_h), (0, cab_y, band_z), .07, glass, root)
    # Khirkiyon ke beech khambe
    for k in range(1, pillars):
        y = cab_y - cab_l / 2 + k * cab_l / pillars
        rounded_box((band_w * 1.01, .055, band_h * .98), (0, y, band_z), .015, body, root, 2)
    # Saamne ka gehra sheesha (gaadi ka munh saaf pata chale)
    rounded_box((band_w * .9, .06, band_h * .9), (0, cab_y + cab_l / 2 - .01, band_z), .03, windshield, root, 3)
    # Khirkiyon ke neeche chrome ki patli patti
    rounded_box((w * .99, cab_l * .98, .025), (0, cab_y, .535), .01, chrome, root, 2)
    # Bus: side par safed patti aur do darwazon ki lakeerein
    if length >= 4:
        rounded_box((w * 1.0, l * .9, .05), (0, 0, .43), .02, white, root, 2)
        for dy in (l / 2 - .55, -.15):
            for x in (-w * .495, w * .495):
                for off in (-.11, .11):
                    rounded_box((.012, .012, .3), (x, dy + off, .39), .004, seam, root, 1)
    # Side shishay (saamne, khirkiyon ki oonchai par)
    # (sheeshe ke bilkul saath, chhoti dandi se jude hue)
    my = cab_y + cab_l / 2 - .06
    for side in (-1, 1):
        rounded_box((.05, .03, .03), (side * (band_w / 2 + .02), my, band_z), .01, body, root, 2)
        rounded_box((.05, .08, .07), (side * (band_w / 2 + .055), my, band_z + .02), .02, body, root, 2)

    # Chhat (body ke rang ki, chamakdar). Car mein thodi peeche, taa ke upar se
    # saamne ka tirchha sheesha dikhe.
    roof_h = top - (band_z + band_h / 2) + .04
    if style == 'double':
        # Doosri manzil: beech ki patti, upar sheeshe, aur patli chhat
        rounded_box((w * .97, cab_l, .1), (0, cab_y, .84), .04, body, root, 3)
        rounded_box((band_w, cab_l, .22), (0, cab_y, 1.0), .06, glass, root)
        for k in range(1, pillars):
            y = cab_y - cab_l / 2 + k * cab_l / pillars
            rounded_box((band_w * 1.01, .055, .21), (0, y, 1.0), .015, body, root, 2)
        roof_h = .09
    if length <= 2:
        roof_l, roof_y = cab_l * .74, cab_y - cab_l * .11
    else:
        roof_l, roof_y = cab_l - .01, cab_y
    rounded_box((roof_w, roof_l, roof_h), (0, roof_y, top - roof_h / 2), .06, roof, root, 4)
    if length >= 4:
        # Bus ki chhat par peeche AC unit
        rounded_box((w * .5, .5, .07), (0, -l * .3, top + .02), .03, ac, root, 3)
        arrow_y = l * .12
    else:
        arrow_y = roof_y + roof_l * .02
    arrow_len = min(.80, roof_l * (.68 if length <= 2 else .5))
    if style == 'taxi':
        # Chhat ke aage sign, teer thoda peeche
        arrow_y -= roof_l * .12
        arrow_len *= .8
    elif style in ('police', 'icecream'):
        # Chhat ke aage wale hisse par bari batti/cone, teer peeche
        arrow_y = roof_y - roof_l * .2
        arrow_len *= .75
    if with_arrow:
        arrow(.44, arrow_len, (0, arrow_y, top), white, edge, root)

    front_roof = roof_y + roof_l / 2
    if style == 'taxi':
        sign = material('Taxi sign', hex_color('FFF3B0'), rough=.3, emission=hex_color('FFE680'))
        rounded_box((w * .42, .13, .1), (0, front_roof - .1, top + .05), .03, sign, root, 3)
        # Side par chess jaisi patti
        dark = material('Checker', hex_color('1E2128'), rough=.5)
        for k in range(10):
            y = -l * .42 + k * l * .084
            for side in (-1, 1):
                rounded_box((.012, l * .042, .045), (side * w * .495, y, .45 + (k % 2) * .045),
                            .004, dark, root, 1)
    elif style == 'police':
        red = material('Police red', hex_color('FF2D3B'), rough=.2, emission=hex_color('FF2D3B'))
        blue = material('Police blue', hex_color('2D7BFF'), rough=.2, emission=hex_color('2D7BFF'))
        bar_y = roof_y + roof_l * .3
        rounded_box((w * .86, .2, .05), (0, bar_y, top + .025), .02, chrome, root, 2)
        for x, m in ((-w * .22, red), (w * .22, blue)):
            rounded_box((w * .38, .17, .13), (x, bar_y, top + .1), .05, m, root, 4)
        rounded_box((w * 1.0, l * .82, .06), (0, -.05, .43), .02, white, root, 2)
    elif style == 'icecream':
        wafer = material('Wafer', hex_color('E0A458'), rough=.6)
        scoop = material('Scoop', hex_color('FFB3D1'), rough=.35, coat=.4)
        cy = roof_y + roof_l * .27
        bpy.ops.mesh.primitive_cone_add(radius1=.05, radius2=.24, depth=.42,
                                        location=(0, cy, top + .21))
        cone = bpy.context.object
        bpy.ops.object.shade_smooth()
        cone.data.materials.append(wafer)
        cone.parent = root
        sphere((0, cy, top + .48), .24, scoop, root)
        sphere((.05, cy - .04, top + .68), .12, white, root)
        # Side par bechne ki khirki
        rounded_box((.03, l * .34, .16), (w * .5, -l * .12, .62), .02, white, root, 2)
    elif style == 'sports':
        # Bonnet par do safed race stripes aur peeche spoiler
        for x in (-.07, .07):
            rounded_box((.05, l * .96, .012), (x, 0, .535), .004, white, root, 1)
        for x in (-w * .32, w * .32):
            rounded_box((.04, .04, .1), (x, -l / 2 + .1, .58), .01, skirt, root, 1)
        rounded_box((w * .92, .12, .03), (0, -l / 2 + .1, .64), .012, body, root, 2)
    elif style == 'school':
        rounded_box((w * .9, .5, .2), (0, l / 2 - .3, .58), .08, body, root, 4)
        rounded_box((w * .5, .08, .1), (0, l / 2 - .02, .5), .02, chrome, root, 2)
        dark = material('School stripe', hex_color('1E2128'), rough=.5)
        for z in (.33, .47):
            rounded_box((w * 1.0, l * .86, .025), (0, -.1, z), .01, dark, root, 1)

    # Pahiye (bus mein teen jodi)
    ys = [l / 2 - .30, -l / 2 + .30]
    if length >= 4:
        ys.append(-l / 2 + .72)
    arch = material('Wheel arch', hex_color('15181D'), rough=.9, coat=0)
    for y in ys:
        for x in (-w / 2 + .02, w / 2 - .02):
            out_x = -1 if x < 0 else 1
            # Wheel ke gird gehra arch (fender ka kata hua hissa)
            cylinder((x + out_x * .035, y, .19), .2, .02, arch, root)
            cylinder((x, y, .16), .16, .13, tire, root)
            cylinder((x + out_x * .07, y, .16), .1, .015, hub, root)
            # Rim ke 5 spoke (gehre khaane)
            for k in range(5):
                a = k * 2 * math.pi / 5
                rounded_box((.012, .035, .035),
                            (x + out_x * .079, y + math.cos(a) * .06, .16 + math.sin(a) * .06),
                            .01, tire, root, 1)
            cylinder((x + out_x * .08, y, .16), .03, .012, chrome, root)
    # Aage peeche bumper aur lights
    grille = material('Grille', hex_color('2A2F37'), rough=.5, coat=.2)
    plate = material('Plate', hex_color('F4F1E6'), rough=.5)
    for y in (-l / 2, l / 2):
        s = 1 if y > 0 else -1
        rounded_box((w * .86, .07, .08), (0, y, .26), .03, chrome, root, 3)
        for x in (-w * .32, w * .32):
            rounded_box((.14, .05, .085), (x, y + s * .005, .42), .03,
                        headlamp if y > 0 else taillamp, root, 4)
        if y > 0:
            # Lights ke beech grille
            rounded_box((w * .38, .04, .09), (0, y + .004, .41), .02, grille, root, 2)
        rounded_box((.2, .02, .07), (0, y + s * .03, .33), .01, plate, root, 2)
    # Darwazon ki patli lakeerein (car aur van)
    if length <= 3:
        for dy in ([cab_y + cab_l * .02] if length <= 2 else [cab_y + cab_l * .2, cab_y - cab_l * .2]):
            for x in (-w * .495, w * .495):
                rounded_box((.008, .012, .26), (x, dy, .4), .004, seam, root, 1)
    return root, body, roof, skirt


def render_splash(path, cam_loc=(2.6, 3.9, 2.1), length=3):
    """Splash/icon ke liye peeli 3D van, saamne-daayen tirchhe angle se (512x512)."""
    scene = scene_setup(length)
    build_bus(length, 'FFC21A', with_arrow=False)
    scene.view_settings.exposure = .45
    bpy.ops.object.empty_add(location=(0, .2, .42))
    target = bpy.context.object
    cam = scene.camera
    cam.data.type = 'PERSP'
    cam.data.lens = 50
    cam.location = cam_loc
    cam.rotation_euler = (0, 0, 0)
    track = cam.constraints.new('TRACK_TO')
    track.target = target
    track.track_axis = 'TRACK_NEGATIVE_Z'
    track.up_axis = 'UP_Y'
    scene.cycles.samples = 64
    scene.render.resolution_x = scene.render.resolution_y = 512
    scene.render.image_settings.file_format = 'PNG'
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print('SPLASH', path, flush=True)


if 'splash' in args:
    render_splash(os.path.join(out, 'splash_bus.png'))
    sys.exit(0)
# Garage ki khaas gaadiyan: (naam, lambai)
SKINS = [('taxi', 2), ('sports', 2), ('police', 3), ('icecream', 3), ('school', 4), ('double', 4)]

if 'skins' in args:
    started = time.time()
    only = [a[5:] for a in args if a.startswith('only=')]
    for name, length in [sk for sk in SKINS if not only or sk[0] in only]:
        scene = None
        for ci in ([0] if quick else range(8)):
            directions = [0, 3] if quick else range(16)
            pending = [d for d in directions
                       if not os.path.exists(os.path.join(out, f'skin_{name}_{ci}_{d}.webp'))]
            if not pending:
                continue
            if scene is None:
                scene = scene_setup(length)
                root, body_mat, roof_mat, skirt_mat = build_bus(length, COLORS[ci], style=name)
            base = hex_color(COLORS[ci])
            for mat, value in [(body_mat, base), (roof_mat, lighter(base, .04)),
                               (skirt_mat, darker(base, .5))]:
                mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = value
            for direction in pending:
                root.rotation_euler = (0, 0, -direction * 2 * math.pi / 16)
                scene.render.filepath = os.path.join(out, f'skin_{name}_{ci}_{direction}.webp')
                bpy.ops.render.render(write_still=True)
                print('RENDERED', scene.render.filepath, f'{time.time()-started:.1f}s', flush=True)
    print('DONE', f'{time.time()-started:.1f}s', flush=True)
    sys.exit(0)

if 'icon' in args:
    # Icon: chhoti moti gaadi, munh zyada saamne aur qareeb se
    render_splash(os.path.join(out, 'icon_bus.png'), cam_loc=(1.35, 3.2, 1.55), length=2)
    sys.exit(0)

started = time.time()
for length in [2, 3, 4]:
    scene = None
    for ci in ([0] if quick else range(8)):
        directions = [0, 3] if quick else range(16)
        pending = [d for d in directions if not os.path.exists(os.path.join(out, f'vehicle_{length}_{ci}_{d}.webp'))]
        if not pending:
            continue
        if scene is None:
            scene = scene_setup(length)
            root, body_mat, roof_mat, skirt_mat = build_bus(length, COLORS[ci])
        base = hex_color(COLORS[ci])
        for mat, value in [
            (body_mat, base),
            (roof_mat, lighter(base, .04)),
            (skirt_mat, darker(base, .5)),
        ]:
            mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = value
        for direction in pending:
            root.rotation_euler = (0, 0, -direction*2*math.pi/16)
            scene.render.filepath = os.path.join(out, f'vehicle_{length}_{ci}_{direction}.webp')
            bpy.ops.render.render(write_still=True)
            print('RENDERED', scene.render.filepath, f'{time.time()-started:.1f}s', flush=True)
print('DONE', f'{time.time()-started:.1f}s', flush=True)
