# Goblin enemy - stage 5: bake + export for Roblox.
# Builds Goblin_ExportRig (deform bones only, no constraints), bakes every action onto it with visual
# keying (IK + floor guards resolved to plain FK keys), then writes:
#   export/Goblin.fbx              skinned model, rest pose, no animation (import with 3D Importer)
#   export/anims/<Action>.fbx      deform-rig animation, one per action (Animation Editor > Import > From FBX)
# Settings follow create.roblox.com/docs/art/modeling/export-requirements (checked 2026-10-24):
# Path Mode Copy + Embed Textures, Apply Scalings = FBX Unit Scale, Add Leaf Bones off, Bake Animation
# only for animation files.
import bpy, os

ROOT = os.environ.get("GOBLIN_ROOT", "/Users/chinnaphat/Desktop/cedt/roblox/goblin")
SRC, EXP = "Goblin_Rig", "Goblin_ExportRig"
MESHES = ("Goblin_Body", "Goblin_Armor", "Goblin_Eyes", "Goblin_Sword")


def fbx(path, objs, anim):
    bpy.ops.object.mode_set(mode="OBJECT") if bpy.context.object and bpy.context.object.mode != "OBJECT" else None
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.hide_set(False)
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=path, use_selection=True, object_types={"ARMATURE", "MESH"},
        apply_scale_options="FBX_SCALE_UNITS", axis_forward="-Z", axis_up="Y",
        path_mode="COPY", embed_textures=True, use_custom_props=True,
        add_leaf_bones=False, primary_bone_axis="Y", secondary_bone_axis="X",
        use_armature_deform_only=True, mesh_smooth_type="FACE",
        bake_anim=anim, bake_anim_use_all_actions=False, bake_anim_use_nla_strips=False,
        bake_anim_force_startend_keying=False, bake_anim_simplify_factor=0.0,
    )


def make_export_rig(src):
    old = bpy.data.objects.get(EXP)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    arm = src.data.copy()
    arm.name = EXP
    rig = bpy.data.objects.new(EXP, arm)
    src.users_collection[0].objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for eb in list(arm.edit_bones):
        if not eb.use_deform:
            arm.edit_bones.remove(eb)
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
        c = pb.constraints.new("COPY_TRANSFORMS")
        c.target, c.subtarget = src, pb.name
    return rig


def retarget_meshes(rig):
    for n in MESHES:
        ob = bpy.data.objects[n]
        mw = ob.matrix_world.copy()
        ob.parent = rig
        ob.matrix_world = mw
        ob.modifiers["Armature"].object = rig


def bake(rig, src, action):
    src.animation_data.action = action
    if action.slots:
        src.animation_data.action_slot = action.slots[0]
    f0, f1 = (int(x) for x in action.frame_range)
    scn = bpy.context.scene
    scn.frame_start, scn.frame_end = f0, f1
    bpy.context.view_layer.objects.active = rig
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="POSE")
    rig.animation_data_create()
    rig.animation_data.action = None
    bpy.ops.nla.bake(frame_start=f0, frame_end=f1, only_selected=False, visual_keying=True,
                     clear_constraints=False, use_current_action=False, bake_types={"POSE"})
    bpy.ops.object.mode_set(mode="OBJECT")
    baked = rig.animation_data.action
    out = "EXP_" + action.name
    if bpy.data.actions.get(out):
        bpy.data.actions.remove(bpy.data.actions[out])
    baked.name = out
    baked.use_fake_user = True
    for k in ("loop", "priority", "events"):
        if k in action:
            baked[k] = action[k]
    return baked


def run():
    src = bpy.data.objects[SRC]
    keep = src.animation_data.action
    os.makedirs(os.path.join(ROOT, "export", "anims"), exist_ok=True)
    rig = make_export_rig(src)
    retarget_meshes(rig)
    src_actions = [a for a in bpy.data.actions if "loop" in a and not a.name.startswith("EXP_")]

    # model: rest pose
    rig.animation_data_create()
    rig.animation_data.action = None
    for c in [c for pb in rig.pose.bones for c in pb.constraints]:
        c.mute = True
    for pb in rig.pose.bones:
        pb.location, pb.rotation_quaternion = (0, 0, 0), (1, 0, 0, 0)
    fbx(os.path.join(ROOT, "export", "Goblin.fbx"), [rig] + [bpy.data.objects[n] for n in MESHES], False)

    # animations: one file each, armature only
    for c in [c for pb in rig.pose.bones for c in pb.constraints]:
        c.mute = False
    baked = [bake(rig, src, a) for a in src_actions]
    for c in [c for pb in rig.pose.bones for c in pb.constraints]:
        c.mute = True
    for act in baked:
        rig.animation_data.action = act
        if act.slots:
            rig.animation_data.action_slot = act.slots[0]
        f0, f1 = (int(x) for x in act.frame_range)
        bpy.context.scene.frame_start, bpy.context.scene.frame_end = f0, f1
        fbx(os.path.join(ROOT, "export", "anims", act.name[4:] + ".fbx"), [rig], True)
    rig.animation_data.action = None
    for c in [c for pb in rig.pose.bones for c in pb.constraints]:
        c.mute = False  # export rig follows the control rig again, so the viewport previews any action
    src.animation_data.action = keep
    if keep and keep.slots:
        src.animation_data.action_slot = keep.slots[0]
    print("exported model +", len(baked), "animations")


if __name__ == "__main__":
    run()
