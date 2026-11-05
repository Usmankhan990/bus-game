"""Shared native Blender mesh helpers from the original project renderer."""

import math

import bpy

def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def hex_color(h):
    r, g, b = (int(h[i : i + 2], 16) / 255 for i in (0, 2, 4))
    return (srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b), 1.0)

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
