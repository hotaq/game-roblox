# Goblin enemy - preview panel: 3D View sidebar (N) > "Goblin" tab, one button per animation.
# Stored in goblin.blend as a registered text block, so it loads with the file (needs Auto Run Python Scripts;
# otherwise open the Scripting tab and press Run Script on goblin_preview_panel.py).
import bpy

RIG = "Goblin_Rig"


def clips():
    return sorted(a.name for a in bpy.data.actions if "loop" in a and not a.name.startswith("EXP_"))


class GOBLIN_OT_play(bpy.types.Operator):
    bl_idname = "goblin.play"
    bl_label = "Play Goblin Animation"
    action: bpy.props.StringProperty()

    def execute(self, context):
        rig = bpy.data.objects[RIG]
        act = bpy.data.actions[self.action]
        rig.animation_data.action = act
        if act.slots:
            rig.animation_data.action_slot = act.slots[0]
        scn = context.scene
        scn.frame_start, scn.frame_end = (int(f) for f in act.frame_range)
        scn.frame_set(scn.frame_start)
        if not context.screen.is_animation_playing:
            bpy.ops.screen.animation_play()
        return {"FINISHED"}


class GOBLIN_PT_preview(bpy.types.Panel):
    bl_label = "Goblin Animations"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "Goblin"

    def draw(self, context):
        rig = bpy.data.objects.get(RIG)
        cur = rig.animation_data.action.name if rig and rig.animation_data and rig.animation_data.action else ""
        col = self.layout.grid_flow(columns=2, even_columns=True, align=True)
        for name in clips():
            op = col.operator("goblin.play", text=name, depress=(name == cur))
            op.action = name
        row = self.layout.row()
        playing = context.screen.is_animation_playing
        row.operator("screen.animation_play", text="Pause" if playing else "Play", icon="PAUSE" if playing else "PLAY")
        row.label(text="frame %d / %d" % (context.scene.frame_current, context.scene.frame_end))


def setup_scene():
    """Preview floor, sun and camera (01_build_model wipes them), control rig hidden so its sticks don't cover
    the model. Goblin_ExportRig deforms the meshes and follows Goblin_Rig, so the model still animates."""
    import math
    scn = bpy.context.scene
    if "Floor" not in bpy.data.objects:
        me = bpy.data.meshes.new("Floor")
        me.from_pydata([(-4, -4, 0), (4, -4, 0), (4, 4, 0), (-4, 4, 0)], [], [(0, 1, 2, 3)])
        mat = bpy.data.materials.get("M_Floor") or bpy.data.materials.new("M_Floor")
        mat.use_nodes = True
        next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.3, 0.3, 0.31, 1)
        me.materials.append(mat)
        scn.collection.objects.link(bpy.data.objects.new("Floor", me))
    if "Sun" not in bpy.data.objects:
        sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
        sun.rotation_euler = (math.radians(50), 0, math.radians(25))
        scn.collection.objects.link(sun)
    bpy.data.objects["Sun"].data.energy = 2.0  # tuned for the Standard view transform
    if "Camera" not in bpy.data.objects:
        cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
        cam.location, cam.rotation_euler = (1.9, -3.4, 1.5), (math.radians(79), 0, math.radians(29))
        scn.collection.objects.link(cam)
        scn.camera = cam
    for n in ("Goblin_Rig", "Goblin_ExportRig"):
        if n in bpy.data.objects:
            bpy.data.objects[n].hide_set(True)


setup_scene()
for c in (GOBLIN_OT_play, GOBLIN_PT_preview):
    if hasattr(bpy.types, c.__name__):
        bpy.utils.unregister_class(getattr(bpy.types, c.__name__))
    bpy.utils.register_class(c)
