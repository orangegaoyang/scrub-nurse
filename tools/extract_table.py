"""Extract one side table (Beistelltisch) from the instrument-table collection
and export as a standalone GLB, with origin at the base centre so it is easy
to place on the floor in Godot.

Run: blender --background --python tools/extract_table.py
"""
import bpy

SRC = "assets/surgical__instrument_table_collection.glb"
OBJ_NAME = "Object_2"   # Beistelltisch (cleaned side table)
OUT = "assets/models/mayo.glb"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)

obj = bpy.data.objects.get(OBJ_NAME)
assert obj is not None, "object not found"

# Select only this object and unlink the rest (so export contains only it).
bpy.ops.object.select_all(action="DESELECT")
obj.select_set(True)
bpy.context.view_layer.objects.active = obj

# Clear parent chain keeping world transform, then apply.
while obj.parent is not None:
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# Origin to base center: move origin to median, then shift down so min Z == 0
bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="MEDIAN")
coords = [obj.matrix_world @ v.co for v in obj.data.vertices]
min_z = min(c.z for c in coords)
cx = sum(c.x for c in coords) / len(coords)
cy = sum(c.y for c in coords) / len(coords)
obj.location = (obj.location.x - cx, obj.location.y - cy, obj.location.z - min_z)
bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)

bpy.ops.object.select_all(action="DESELECT")
obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_apply=True)
print("WROTE", OUT)
