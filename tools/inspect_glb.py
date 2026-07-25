"""Inspect a GLB: list objects, meshes, materials, and bounding box sizes."""
import bpy
import sys

PATH = "assets/surgical_instruments_collection.glb"

# Fresh file.
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=PATH)

print("=== OBJECTS ===")
for o in bpy.data.objects:
    if o.type == "MESH":
        bb = [o.matrix_world @ v.co for v in o.data.vertices]
        if bb:
            xs = [v.x for v in bb]; ys = [v.y for v in bb]; zs = [v.z for v in bb]
            sx = max(xs)-min(xs); sy = max(ys)-min(ys); sz = max(zs)-min(zs)
            mats = [m.name for m in o.data.materials]
            print(f"{o.name:40s} size=({sx:.4f}, {sy:.4f}, {sz:.4f}) mats={mats}")
    else:
        print(f"{o.name:40s} type={o.type}")

print("=== MATERIALS ===")
for m in bpy.data.materials:
    print(f"  {m.name}")

print("=== SCENE COLLECTION TREE ===")
def walk(c, d=0):
    for o in c.objects:
        print("  "*d + f"- {o.name} [{o.type}]")
    for child in c.children:
        print("  "*d + f"# {child.name}")
        walk(child, d+1)
walk(bpy.context.scene.collection)
