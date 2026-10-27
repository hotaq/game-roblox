-- Paste into Studio's Command Bar (Edit mode) once after every Import 3D of export/Goblin.fbx.
-- Fixes two importer issues seen 2026-10-25:
--  1. Extra bones (Ear_*, Cloth_*, Weapon, VFX_*) land HRP-height (3.1696 studs) too low in their part's frame,
--     so ears/cloth/sword skin around the wrong pivot. Humanoid rebuilds bones from OriginalPosition at runtime,
--     so that value is shifted too (it's stored in the part frame for nested bones as well).
--  2. The Sword and Eyes MeshParts import with no joint and fall off in Play: weld them.
local OFFSET = Vector3.new(0, 3.1696, 0) -- = HumanoidRootPart centre height at import; re-measure if the rig changes
local m = workspace.Goblin
for _, b in m:GetDescendants() do
	if b:IsA("Bone") then
		if b.Parent:IsA("BasePart") then
			b.CFrame = CFrame.new(OFFSET) * b.CFrame
		end
		local o = b:FindFirstChild("OriginalPosition")
		if o then
			o.Value += OFFSET
		end
	end
end
for part, to in { Sword = "RightHand", Eyes = "Head" } do
	local p = m[part]
	p.CanCollide, p.CanTouch, p.Massless = false, false, true
	local w = Instance.new("WeldConstraint")
	w.Name, w.Part0, w.Part1, w.Parent = part .. "Weld", m[to], p, p
end
-- 3. Performance: the HumanoidRootPart does the colliding; limbs keep only CanQuery (raycast/hitbox hits).
--    Humanoid turns limb CanCollide back on at runtime, so limbs go in a collision group that collides with
--    nothing. (CollisionFidelity can't be set from a script, and doesn't matter once limbs never collide.)
--    The eyes are too small to be worth a shadow.
local PhysicsService = game:GetService("PhysicsService")
if not PhysicsService:IsCollisionGroupRegistered("GoblinLimbs") then
	PhysicsService:RegisterCollisionGroup("GoblinLimbs")
end
for _, g in PhysicsService:GetRegisteredCollisionGroups() do
	PhysicsService:CollisionGroupSetCollidable("GoblinLimbs", g.name, false)
end
for _, p in m:GetDescendants() do
	if p:IsA("MeshPart") then
		p.CanTouch, p.CollisionGroup = false, "GoblinLimbs"
	end
end
m.Eyes.CastShadow = false
game:GetService("CollectionService"):AddTag(m, "Goblin")
