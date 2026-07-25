"""Generate a low-poly surgical scalpel and export as GLB for Godot.

Run headless:
    blender --background --python tools/make_scalpel.py

Modelled in Blender with length along +X, blade laid flat in the XY plane,
thin in Z. glTF export maps Blender +Z -> Godot +Y (up), so the instrument
ends up lying flat on the tray (XZ plane).
"""
import bpy
import bmesh
from mathutils import Vector

OUT_PATH = "assets/models/scalpel.glb"


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in list(bpy.data.meshes):
        bpy.data.meshes.remove(block)
    for block in list(bpy.data.materials):
        bpy.data.materials.remove(block)


def make_steel_material(name, roughness):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.80, 0.81, 0.83, 1.0)
    bsdf.inputs["Metallic"].default_value = 1.0
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


def make_handle(mat):
    # Slender flat handle along X.
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0))
    obj = bpy.context.active_object
    obj.name = "Handle"
    # length X, width Y, height Z
    obj.scale = (0.090, 0.012, 0.006)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    # shift so handle spans x=-0.060..+0.030
    obj.location.x = -0.015
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    # slight bevel for nicer edges
    bevel = obj.modifiers.new(name="Bevel", type="BEVEL")
    bevel.width = 0.0012
    bevel.segments = 2
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    obj.data.materials.append(mat)
    return obj


def make_blade(mat):
    # Triangular blade: base near handle, sharp tip along +X, thin in Z.
    mesh = bpy.data.meshes.new("BladeMesh")
    obj = bpy.data.objects.new("Blade", mesh)
    bpy.context.collection.objects.link(obj)
    bm = bmesh.new()
    z = 0.0015
    base_x = 0.030
    tip_x = 0.072
    half = 0.008
    v0 = bm.verts.new((base_x, -half, -z))
    v1 = bm.verts.new((base_x, half, -z))
    v2 = bm.verts.new((tip_x, 0.0, -z))
    v3 = bm.verts.new((base_x, -half, z))
    v4 = bm.verts.new((base_x, half, z))
    v5 = bm.verts.new((tip_x, 0.0, z))
    bm.faces.new((v0, v1, v2))          # bottom
    bm.faces.new((v5, v4, v3))          # top
    bm.faces.new((v0, v3, v4, v1))      # base
    bm.faces.new((v1, v4, v5, v2))      # side 1
    bm.faces.new((v2, v5, v3, v0))      # side 2
    bm.to_mesh(mesh)
    bm.free()
    obj.data.materials.append(mat)
    return obj


def main():
    clear_scene()
    handle_mat = make_steel_material("SteelHandle", 0.35)
    blade_mat = make_steel_material("SteelBlade", 0.15)
    handle = make_handle(handle_mat)
    blade = make_blade(blade_mat)

    # Join into one object.
    bpy.ops.object.select_all(action="DESELECT")
    handle.select_set(True)
    blade.select_set(True)
    bpy.context.view_layer.objects.active = handle
    bpy.ops.object.join()
    handle.name = "Scalpel"

    # Origin at the grip centre (around middle of handle).
    bpy.context.scene.cursor.location = (-0.015, 0.0, 0.0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)

    # Export GLB.
    handle.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=OUT_PATH,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
    )
    print("WROTE", OUT_PATH)


main()
