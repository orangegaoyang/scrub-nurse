"""Generate a surgical scalpel and export as GLB for Godot.

Length is modelled along Blender's Y axis so that after glTF export
(Blender +Y -> Godot -Z) the instrument lies pointing front/back (the same
orientation as the placeholder boxes), i.e. "竖着" on the tray.

Run headless:
    blender --background --python tools/make_scalpel.py
"""
import bpy
import bmesh

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
    bsdf.inputs["Base Color"].default_value = (0.86, 0.87, 0.89, 1.0)
    bsdf.inputs["Metallic"].default_value = 0.95
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


def make_handle(mat):
    # Length along Y: spans y = -0.125 .. +0.020
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, -0.0525, 0.0))
    obj = bpy.context.active_object
    obj.name = "Handle"
    obj.scale = (0.018, 0.145, 0.008)  # width X, length Y, thickness Z
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel = obj.modifiers.new(name="Bevel", type="BEVEL")
    bevel.width = 0.0018
    bevel.segments = 2
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    obj.data.materials.append(mat)
    return obj


def make_blade(mat):
    # Triangular blade pointing +Y, thin in Z.
    mesh = bpy.data.meshes.new("BladeMesh")
    obj = bpy.data.objects.new("Blade", mesh)
    bpy.context.collection.objects.link(obj)
    bm = bmesh.new()
    z = 0.003
    base_y = 0.020
    tip_y = 0.125
    half = 0.012
    v0 = bm.verts.new((-half, base_y, -z))
    v1 = bm.verts.new((half, base_y, -z))
    v2 = bm.verts.new((0.0, tip_y, -z))
    v3 = bm.verts.new((-half, base_y, z))
    v4 = bm.verts.new((half, base_y, z))
    v5 = bm.verts.new((0.0, tip_y, z))
    bm.faces.new((v0, v1, v2))          # bottom
    bm.faces.new((v5, v4, v3))          # top
    bm.faces.new((v0, v3, v4, v1))      # base
    bm.faces.new((v1, v4, v5, v2))      # side
    bm.faces.new((v2, v5, v3, v0))      # side
    bm.to_mesh(mesh)
    bm.free()
    obj.data.materials.append(mat)
    return obj


def main():
    clear_scene()
    handle_mat = make_steel_material("SteelHandle", 0.35)
    blade_mat = make_steel_material("SteelBlade", 0.12)
    handle = make_handle(handle_mat)
    blade = make_blade(blade_mat)

    bpy.ops.object.select_all(action="DESELECT")
    handle.select_set(True)
    blade.select_set(True)
    bpy.context.view_layer.objects.active = handle
    bpy.ops.object.join()
    handle.name = "Scalpel"

    # Origin already at world centre (geometry is symmetric about 0).
    handle.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=OUT_PATH,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
    )
    print("WROTE", OUT_PATH)


main()
