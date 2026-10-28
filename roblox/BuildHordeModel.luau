-- BuildHordeModel.luau: Command Bar (Edit mode). Turns the imported single-mesh goblin (export/GoblinHorde.fbx from
-- scripts/12_horde_mesh.py, imported with File > Import as workspace.GoblinHorde) into
-- ReplicatedStorage.Goblin.HordeModel for GoblinHordeClient: 1 skinned MeshPart instead of 17, ~30 instances
-- instead of 216.
-- Every bone's bind frame equals its joint frame, so the existing Goblin_* animations drive it unchanged once the rig
-- mirrors the KeyframeSequence pose tree: the MeshPart is named LowerTorso (the Root joint's Part1) and its Bone
-- instances go UpperTorso > Head > Ear_L ... (rebuilt here from the mesh's bind pose; the importer's are replaced).
-- Re-run after re-importing. Deletes workspace.GoblinHorde when done.
-- Goblin v2 (export/GoblinV2Horde.fbx, same rig): import it as workspace.GoblinV2Horde instead; it wins when both
-- are present and keeps the texture the importer uploaded with it.
local AssetService = game:GetService("AssetService")
local RIGID = { Root = true, HumanoidRootNode = true, LowerTorso = true } -- move with the MeshPart itself: no Bone
local imported = workspace:FindFirstChild("GoblinV2Horde") or workspace.GoblinHorde
-- v1: the 17-part goblin's ColorMap, since the importer's own re-upload of the pixel atlas looks blurry
local ATLAS = if imported.Name == "GoblinHorde" then "rbxassetid://125017663072921" else nil
-- v2 is drawn at 0.7x (4.5 studs, under the player's height; owner: "too big"). The client reads the hip height from
-- the pivot, so the model is lowered after scaling to keep the feet on y = 0.
local SCALE = if ATLAS then 1 else 0.7
local source = workspace.Goblin -- for the HumanoidRootPart and the Root joint's HumanoidRootPart side
local mesh = imported:FindFirstChildOfClass("MeshPart"):Clone()
mesh:ClearAllChildren()

-- Bind pose (mesh space = part space: the importer centers the mesh and MeshSize equals Size).
local em = AssetService:CreateEditableMeshAsync(Content.fromUri(mesh.MeshId))
local bind, parentOf = {}, {}
for _, b in em:GetBones() do
	local name = em:GetBoneName(b)
	local p = em:GetBoneParent(b)
	bind[name], parentOf[name] = em:GetBoneCFrame(b), if p ~= 0 then em:GetBoneName(p) else nil
end
em:Destroy()

local model = Instance.new("Model")
model.Name = "HordeModel"
local hrp = source.HumanoidRootPart:Clone()
hrp:ClearAllChildren()
hrp.Anchored, hrp.Transparency, hrp.CanCollide, hrp.CanTouch = true, 1, false, false
hrp.Parent = model
model.PrimaryPart = hrp
mesh.Name = "LowerTorso"
mesh.TextureID = ATLAS or mesh.TextureID
mesh.Anchored = false
mesh.CanCollide, mesh.CanQuery, mesh.CanTouch, mesh.CastShadow = false, false, false, false
mesh.Parent = model

local rootJoint = source:FindFirstChild("Root", true) :: AnimationConstraint
local a0 = rootJoint.Attachment0:Clone()
a0.Parent = hrp
local a1 = Instance.new("Attachment")
a1.Name, a1.CFrame = rootJoint.Attachment1.Name, bind.LowerTorso -- the LowerTorso bone sits on the Root joint frame
a1.Parent = mesh
local joint = Instance.new("AnimationConstraint")
joint.Name, joint.Attachment0, joint.Attachment1, joint.IsKinematic = "Root", a0, a1, true
joint.Parent = hrp
mesh.CFrame = hrp.CFrame * a0.CFrame * a1.CFrame:Inverse() -- rest pose, so the saved model already looks right

local made = {}
local function bone(name: string): Instance
	if RIGID[name] then
		return mesh
	end
	if not made[name] then
		local parent = bone(parentOf[name])
		local b = Instance.new("Bone")
		b.Name = name
		b.CFrame = if parent == mesh then bind[name] else bind[parentOf[name]]:Inverse() * bind[name]
		b.Parent = parent
		made[name] = b
	end
	return made[name]
end
for name in bind do
	bone(name)
end

local controller = Instance.new("AnimationController")
Instance.new("Animator").Parent = controller
controller.Parent = model

if SCALE ~= 1 then
	model:ScaleTo(SCALE) -- scales the bones and attachments too; the Animator scales clip translations to match
	model:PivotTo(model:GetPivot() - Vector3.new(0, mesh.Position.Y - mesh.Size.Y / 2, 0))
end

local shared = game.ReplicatedStorage.Goblin
local old = shared:FindFirstChild("HordeModel")
if old then
	old:Destroy()
end
model.Parent = shared
imported:Destroy()
return ("HordeModel: mesh %s, texture %s, %d instances"):format(mesh.MeshId, mesh.TextureID, #model:GetDescendants() + 1)
