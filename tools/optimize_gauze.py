"""Optimize Gauze.glb: downscale its 2K textures, scale the mesh to instrument
size (~0.4 m), center it, clamp the material so it isn't pure-black metal.
Overwrites the file in place.

Run: blender --background --python tools/optimize_gauze.py
"""
import bpy

SRC = "assets/models/Gauze.glb"
OUT = "assets/models/Gauze.glb"
TARGET = 0.4  # max dimension, matches other instrument GLBs (MODEL_SCALE 0.5 -> ~0.2 m)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SRC)

    # downscale textures to 512
    for img in bpy.data.images:
        if max(img.size) > 512:
            img.scale(512, 512)

    # join meshes
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for m in meshes:
        m.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = "Gauze"

    while obj.parent is not None:
        bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # scale to TARGET on the largest dimension
    bb = [obj.matrix_world @ v.co for v in obj.data.vertices]
    xs = [v.x for v in bb]; ys = [v.y for v in bb]; zs = [v.z for v in bb]
    maxd = max(max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))
    s = TARGET / maxd
    obj.scale = (s, s, s)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    # center origin
    bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="MEDIAN")
    obj.location = (0.0, 0.0, 0.0)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)

    # clamp material
    for mat in obj.data.materials:
        if not mat.use_nodes:
            continue
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if bsdf is None:
            continue
        base = bsdf.inputs["Base Color"].default_value
        if base[0] + base[1] + base[2] < 0.6:
            bsdf.inputs["Base Color"].default_value = (0.9, 0.9, 0.9, 1.0)
        if bsdf.inputs["Metallic"].default_value > 0.6:
            bsdf.inputs["Metallic"].default_value = 0.3
        if bsdf.inputs["Roughness"].default_value < 0.25:
            bsdf.inputs["Roughness"].default_value = 0.35

    # drop non-mesh helpers
    for o in list(bpy.data.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_apply=True)
    print("WROTE", OUT)


main()
