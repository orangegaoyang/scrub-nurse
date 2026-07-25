"""Create a reach-out animation for the (already-rigged) Mixamo doctor and
export a scaled GLB. Direct bone rotation (calibrated) instead of IK.

Model faces -Y (eyes/toes face -Y), so "forward" is -Y. In the T-pose the
right arm points -X. Calibrated:
  RightArm rot X=+90  -> arm lowered to the side (rest)
  RightArm rot Z=-90  -> arm swung forward (reach, hand toward -Y)

Run: blender --background --python tools/rig_doctor.py
"""
import bpy
import math
from mathutils import Euler

SRC = "assets/doctor.glb"
OUT = "assets/models/doctor.glb"
SCALE = 0.01  # cm -> m  (~1.82 m tall)

R_ARM = "mixamorig:RightArm_035"
L_ARM = "mixamorig:LeftArm_011"
REACH_ANIM = "Reach"


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SRC)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")

    ico = bpy.data.objects.get("Icosphere")
    if ico:
        bpy.data.objects.remove(ico, do_unlink=True)

    for r in [o for o in bpy.data.objects if o.parent is None]:
        r.scale = Vector_or_one()

    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")

    rarm = arm.pose.bones[R_ARM]
    larm = arm.pose.bones[L_ARM]
    for pb in (rarm, larm):
        pb.rotation_mode = "XYZ"

    def set_rest():
        rarm.rotation_euler = Euler((math.radians(90), 0, 0), "XYZ")  # arm down
        larm.rotation_euler = Euler((math.radians(-90), 0, 0), "XYZ")  # arm down

    def set_reach():
        rarm.rotation_euler = Euler((0, 0, math.radians(-90)), "XYZ")  # forward
        larm.rotation_euler = Euler((math.radians(-90), 0, 0), "XYZ")  # stays down

    scene = bpy.context.scene
    scene.frame_start = 1
    scene.frame_end = 18

    # keyframes
    scene.frame_set(1); set_rest()
    rarm.keyframe_insert("rotation_euler", frame=1)
    larm.keyframe_insert("rotation_euler", frame=1)
    scene.frame_set(18); set_reach()
    rarm.keyframe_insert("rotation_euler", frame=18)
    larm.keyframe_insert("rotation_euler", frame=18)

    bpy.ops.object.mode_set(mode="OBJECT")

    # keep only our action
    if arm.animation_data and arm.animation_data.action:
        arm.animation_data.action.name = REACH_ANIM
    baked = arm.animation_data.action if arm.animation_data else None
    for act in list(bpy.data.actions):
        if act is not baked:
            bpy.data.actions.remove(act)

    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.data.objects:
        o.select_set(o.type in ("ARMATURE", "MESH"))
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(
        filepath=OUT, export_format="GLB", use_selection=True,
        export_apply=True, export_animations=True,
    )
    print("WROTE", OUT)


def Vector_or_one():
    from mathutils import Vector
    return Vector((SCALE, SCALE, SCALE))


main()
