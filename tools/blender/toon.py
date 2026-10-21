"""Shared Blender helpers for Dog Eat Dog prop renders.

The look: flat three-tone cel shading baked into an emission shader (so the
result does not depend on scene lights), plus an inverted-hull ink outline,
rendered orthographic on a transparent background. Every prop is built from
primitives in code, so a sheet re-renders from source with no .blend file.

Runs under the `bpy` module (pip install bpy) or `blender -b -P`.
"""

import math

import bmesh
import bpy
from mathutils import Matrix, Vector

# Light direction the cel bands are cut against (world space, upper left front).
LIGHT = Vector((-0.45, -0.55, 0.70)).normalized()
INK = "#1d1622"
OUTLINE_WIDTH = 0.035


def srgb(hex_color):
    """'#rrggbb' -> linear RGBA (emission colours are linear)."""
    h = hex_color.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (*out, 1.0)


def shade(hex_color, k, cool=0.0):
    """Darken/lighten a hex colour by k; cool pushes shadows toward violet."""
    h = hex_color.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    r, g, b = r * k, g * k, b * k
    if cool:
        r, g, b = r * (1 - cool * 0.5), g * (1 - cool), b + (255 - b) * cool * 0.35
    clamp = lambda v: max(0, min(255, int(v)))
    return "#%02x%02x%02x" % (clamp(r), clamp(g), clamp(b))


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _MATS.clear()


_MATS = {}


def toon(hex_color):
    """Cached three-band cel material for a base colour."""
    if hex_color in _MATS:
        return _MATS[hex_color]
    mat = bpy.data.materials.new("toon_" + hex_color)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    light = nt.nodes.new("ShaderNodeCombineXYZ")
    light.inputs[0].default_value, light.inputs[1].default_value, light.inputs[2].default_value = LIGHT
    dot = nt.nodes.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    nt.links.new(geo.outputs["Normal"], dot.inputs[0])
    nt.links.new(light.outputs[0], dot.inputs[1])
    remap = nt.nodes.new("ShaderNodeMapRange")
    remap.inputs["From Min"].default_value = -1.0
    nt.links.new(dot.outputs["Value"], remap.inputs["Value"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.0, srgb(shade(hex_color, 0.68, cool=0.18))
    els[1].position, els[1].color = 0.47, srgb(hex_color)
    hi = els.new(0.90)
    hi.color = srgb(shade(hex_color, 1.12))
    nt.links.new(remap.outputs["Result"], ramp.inputs["Fac"])
    emit = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(ramp.outputs["Color"], emit.inputs["Color"])
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(emit.outputs[0], out.inputs["Surface"])
    _MATS[hex_color] = mat
    return mat


def flat(hex_color):
    """Unshaded colour (pupils, ink details, highlights)."""
    key = "flat" + hex_color
    if key in _MATS:
        return _MATS[key]
    mat = bpy.data.materials.new(key)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    emit = nt.nodes.new("ShaderNodeEmission")
    emit.inputs["Color"].default_value = srgb(hex_color)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(emit.outputs[0], out.inputs["Surface"])
    _MATS[key] = mat
    return mat


def _outline_mat():
    """Ink where the flipped hull faces the camera's back; clear elsewhere."""
    if "outline" in _MATS:
        return _MATS["outline"]
    mat = bpy.data.materials.new("outline")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    ink = nt.nodes.new("ShaderNodeEmission")
    ink.inputs["Color"].default_value = srgb(INK)
    clear = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(geo.outputs["Backfacing"], mix.inputs["Fac"])
    nt.links.new(ink.outputs[0], mix.inputs[1])
    nt.links.new(clear.outputs[0], mix.inputs[2])
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    _MATS["outline"] = mat
    return mat


def _link(obj, mat, parent):
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    if parent is not None:
        obj.parent = parent
    return obj


def sphere(loc, scale, mat, rot=(0, 0, 0), parent=None, segs=40, outline=True):
    me = bpy.data.meshes.new("sphere")
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=segs // 2, radius=1.0)
    for f in bm.faces:
        f.smooth = True
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("sphere", me)
    obj.location, obj.scale = loc, scale
    obj.rotation_euler = [math.radians(a) for a in rot]
    obj["outline"] = outline
    return _link(obj, mat, parent)


def box(loc, scale, mat, rot=(0, 0, 0), parent=None, bevel=0.0, outline=True):
    me = bpy.data.meshes.new("box")
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=2.0)
    if bevel:
        bmesh.ops.bevel(bm, geom=bm.edges[:] + bm.verts[:], offset=bevel, segments=3,
                        affect="EDGES", profile=0.5)
        for f in bm.faces:
            f.smooth = True
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("box", me)
    obj.location, obj.scale = loc, scale
    obj.rotation_euler = [math.radians(a) for a in rot]
    obj["outline"] = outline
    return _link(obj, mat, parent)


def cylinder(loc, radius, depth, mat, rot=(0, 0, 0), parent=None, segs=48, scale=(1, 1, 1),
             cap_smooth=False, outline=True, r2=None):
    me = bpy.data.meshes.new("cyl")
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=radius,
                          radius2=radius if r2 is None else r2, depth=depth)
    for f in bm.faces:
        f.smooth = len(f.verts) == 4 or cap_smooth
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("cyl", me)
    obj.location, obj.scale = loc, scale
    obj.rotation_euler = [math.radians(a) for a in rot]
    obj["outline"] = outline
    return _link(obj, mat, parent)


def limb(p0, p1, radius, mat, parent=None, r1=None):
    """Capsule from p0 to p1 (a tapered cylinder plus sphere caps)."""
    p0, p1 = Vector(p0), Vector(p1)
    r1 = radius if r1 is None else r1
    axis = p1 - p0
    rot = Vector((0, 0, 1)).rotation_difference(axis.normalized()).to_euler()
    cyl = cylinder((p0 + p1) / 2, radius, axis.length, mat, parent=parent, r2=r1)
    cyl.rotation_euler = rot
    sphere(p0, (radius,) * 3, mat, parent=parent, segs=24)
    sphere(p1, (r1,) * 3, mat, parent=parent, segs=24)
    return cyl


def tube(points, radius, mat, parent=None, taper=(1.0, 1.0), outline=True):
    """Smooth tube through points; radius fades taper[0] -> taper[1]."""
    cu = bpy.data.curves.new("tube", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = 6
    cu.use_fill_caps = True
    sp = cu.splines.new("NURBS")
    sp.points.add(len(points) - 1)
    n = len(points)
    for i, p in enumerate(points):
        sp.points[i].co = (*p, 1.0)
        sp.points[i].radius = taper[0] + (taper[1] - taper[0]) * i / max(1, n - 1)
    sp.use_endpoint_u = True
    sp.order_u = min(4, n)
    sp.resolution_u = 16
    obj = bpy.data.objects.new("tube", cu)
    obj["outline"] = outline
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    if parent is not None:
        obj.parent = parent
    return obj


def bake(outline_width=OUTLINE_WIDTH):
    """Bake every object to a world-space mesh, then add ink hulls."""
    dg = bpy.context.evaluated_depsgraph_get()
    for obj in list(bpy.context.scene.objects):
        if obj.type not in {"MESH", "CURVE"}:
            continue
        ev = obj.evaluated_get(dg)
        me = bpy.data.meshes.new_from_object(ev)
        me.transform(obj.matrix_world)
        new = bpy.data.objects.new(obj.name, me)
        new["outline"] = obj.get("outline", True)
        bpy.context.collection.objects.link(new)
        bpy.data.objects.remove(obj)
    for obj in list(bpy.context.scene.objects):
        if obj.type == "EMPTY":
            bpy.data.objects.remove(obj)
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH" or not obj["outline"]:
            continue
        me = obj.data.copy()
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bm.normal_update()
        for v in bm.verts:
            v.co += v.normal * outline_width
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        me.materials.clear()
        me.materials.append(_outline_mat())
        hull = bpy.data.objects.new(obj.name + "_ink", me)
        bpy.context.collection.objects.link(hull)


def render(path, size=512, margin=1.12, view="front"):
    """Fit an orthographic camera to the scene and render a transparent PNG."""
    scene = bpy.context.scene
    lo = Vector((1e9,) * 3)
    hi = Vector((-1e9,) * 3)
    for obj in scene.objects:
        if obj.type != "MESH":
            continue
        for v in obj.data.vertices:
            co = obj.matrix_world @ v.co
            lo = Vector(map(min, lo, co))
            hi = Vector(map(max, hi, co))
    centre = (lo + hi) / 2
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = max(hi.x - lo.x, hi.z - lo.z) * margin
    cam = bpy.data.objects.new("cam", cam_data)
    cam.location = (centre.x, lo.y - 20, centre.z)
    cam.rotation_euler = (math.radians(90), 0, 0)
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = False
    scene.cycles.transparent_max_bounces = 32
    scene.cycles.max_bounces = 0
    scene.render.film_transparent = True
    scene.render.resolution_x = scene.render.resolution_y = size
    scene.render.filter_size = 1.2
    scene.view_settings.view_transform = "Standard"
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
