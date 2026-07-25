"""Extract individual instruments from the collection GLB and export each as
its own GLB for Godot.

For each target instrument we:
  1. find its mesh object(s) by name,
  2. join them,
  3. clear parents (keep transform) and apply transforms so the mesh lives in
     clean world space,
  4. centre the origin on the geometry,
  5. uniformly scale to a target length along Y (Blender Y -> Godot Z, so the
     instrument ends up pointing front/back, lying flat),
  6. export as assets/models/<id>.glb.

Run headless:
    blender --background --python tools/process_instruments.py
"""
import bpy
import math

SRC = "assets/surgical_instruments_collection.glb"
TARGET_LEN = 0.22  # normalised length (m) along the long axis

TARGETS = {
    "scalpel": "Scalpel handle Nr. 3",
    "hemostat": "Clamp Overholt-Geissend",
    "forceps": "Surgical Tweezers",
    "scissors": "Dissection Scissors Metzenbaum",
    "needle_holder": "Needle holder DeBakey",
}


def fresh_import():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SRC)


def deselect_all():
    bpy.ops.object.select_all(action="DESELECT")


def clear_parents_keep(obj):
    while obj.parent is not None:
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")


def bbox_size(obj):
    coords = [obj.matrix_world @ v.co for v in obj.data.vertices]
    xs = [c.x for c in coords]; ys = [c.y for c in coords]; zs = [c.z for c in coords]
    return (max(xs)-min(xs), max(ys)-min(ys), max(zs)-min(zs))


def clamp_materials(obj):
    """Keep metal from rendering pure-black at grazing angles: cap metallic,
    ensure a bright diffuse base, sensible roughness."""
    for mat in obj.data.materials:
        if not mat.use_nodes:
            continue
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if bsdf is None:
            continue
        base = bsdf.inputs["Base Color"].default_value
        # brighten very dark base colors
        if base[0] + base[1] + base[2] < 0.6:
            bsdf.inputs["Base Color"].default_value = (0.85, 0.85, 0.87, 1.0)
        if bsdf.inputs["Metallic"].default_value > 0.6:
            bsdf.inputs["Metallic"].default_value = 0.6
        if bsdf.inputs["Roughness"].default_value < 0.25:
            bsdf.inputs["Roughness"].default_value = 0.35


def process(name_prefix, out_id):
    meshes = [o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith(name_prefix)]
    if not meshes:
        print("  !! no mesh for", name_prefix)
        return
    deselect_all()
    for m in meshes:
        m.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = out_id

    clear_parents_keep(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # centre origin on geometry, then move geometry so centre is at world 0
    bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="MEDIAN")
    obj.location = (0.0, 0.0, 0.0)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)

    # uniform scale to target length along Y (the long axis)
    sx, sy, sz = bbox_size(obj)
    s = TARGET_LEN / sy
    obj.scale = (s, s, s)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    clamp_materials(obj)

    # lay flat: nothing needed (thin in Z -> thin height in Godot)
    deselect_all()
    obj.select_set(True)
    out = "assets/models/%s.glb" % out_id
    bpy.ops.export_scene.gltf(
        filepath=out, export_format="GLB", use_selection=True, export_apply=True
    )
    print("  wrote", out, "size", bbox_size(obj))


def main():
    for out_id, prefix in TARGETS.items():
        fresh_import()
        print("processing", out_id, "<-", prefix)
        process(prefix, out_id)


main()
