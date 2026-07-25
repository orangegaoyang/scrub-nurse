"""Create a reach-out animation for the (already-rigged) Mixamo doctor and
export a scaled GLB. Model ships in T-pose at ~182 cm units.

We scale the root down to ~1.82 m, drive both arms to a relaxed rest via IK
on the forearms, keyframe the right-hand IK target forward (the "reach") and
back, bake the IK to pose keys, drop helpers, and export with the "Reach"
action.

Run: blender --background --python tools/rig_doctor.py
"""
import bpy
import math
from mathutils import Vector

SRC = "assets/doctor.glb"
OUT = "assets/models/doctor.glb"
SCALE = 0.01  # cm -> m

R_FORE = "mixamorig:RightForeArm_036"
L_FORE = "mixamorig:LeftForeArm_012"


def add_empty(name, loc):
    e = bpy.data.objects.new(name, None)
    e.location = loc
    bpy.context.collection.objects.link(e)
    return e


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SRC)

    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")

    # drop stray debug sphere
    ico = bpy.data.objects.get("Icosphere")
    if ico:
        bpy.data.objects.remove(ico, do_unlink=True)

    # scale the root (children inherit) so the model is ~1.82 m
    roots = [o for o in bpy.data.objects if o.parent is None]
    for r in roots:
        r.scale = Vector((SCALE, SCALE, SCALE))

    # --- POSE mode for IK + keying ---
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")

    rh_rest = Vector((-0.22, 0.08, 1.12))
    rh_reach = Vector((-0.10, 0.48, 1.40))
    lh_rest = Vector((0.22, 0.08, 1.12))

    rh_target = add_empty("RH_Target", rh_rest)
    lh_target = add_empty("LH_Target", lh_rest)
    rh_pole = add_empty("RH_Pole", (-0.45, -0.30, 1.40))
    lh_pole = add_empty("LH_Pole", (0.45, -0.30, 1.40))

    def add_ik(bone_name, target, pole):
        pb = arm.pose.bones[bone_name]
        ik = pb.constraints.new("IK")
        ik.target = target
        ik.chain_count = 2
        ik.pole_target = pole
        ik.pole_angle = math.radians(-90)
        ik.use_tail = True

    add_ik(R_FORE, rh_target, rh_pole)
    add_ik(L_FORE, lh_target, lh_pole)

    scene = bpy.context.scene
    scene.frame_start = 1
    scene.frame_end = 18

    # Two keyframes only: rest (f1) -> reach (f18). Clean forward reach.
    for f, v in [(1, rh_rest), (18, rh_reach)]:
        rh_target.location = v
        rh_target.keyframe_insert("location", frame=f)
    for f in (1, 18):
        lh_target.location = lh_rest
        lh_target.keyframe_insert("location", frame=f)

    # bake IK result into the armature, then remove helpers
    bpy.ops.pose.select_all(action="SELECT")
    bpy.ops.nla.bake(
        only_selected=False,
        visual_keying=True,
        clear_constraints=True,
        bake_types={"POSE"},
    )
    # bake the rest frame into the skeleton so the default pose (no anim) is
    # arms-down, not the T-pose.
    bpy.context.scene.frame_set(1)
    bpy.ops.pose.select_all(action="SELECT")
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    for e in (rh_target, lh_target, rh_pole, lh_pole):
        bpy.data.objects.remove(e, do_unlink=True)

    if arm.animation_data and arm.animation_data.action:
        arm.animation_data.action.name = "Reach"

    # remove the original T-pose action so only "Reach" ships
    baked = arm.animation_data.action if arm.animation_data else None
    for act in list(bpy.data.actions):
        if act is not baked:
            bpy.data.actions.remove(act)

    # --- export armature + meshes ---
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.data.objects:
        o.select_set(o.type in ("ARMATURE", "MESH"))
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(
        filepath=OUT,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_animations=True,
    )
    print("WROTE", OUT)


main()
