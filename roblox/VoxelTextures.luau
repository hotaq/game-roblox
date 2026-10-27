-- VoxelTextures.luau: Command Bar (Edit mode). Switches workspace.VoxelArena (+ Baseplate, SpawnLocation) between
-- the pixel textures (MaterialService.Voxel_*) and flat colors (each texture's average color).
-- Flat is the fallback while freshly uploaded textures wait for Roblox moderation (they render white until then).
local TEXTURED = false -- set true once the textures load, then run again

local FLAT = { -- average color of goblin/textures/voxel/<name>.png
	grass = Color3.fromRGB(98, 190, 70), -- BedWars-style rich green (texture average is 124, 211, 76)
	dirt = Color3.fromRGB(170, 116, 72), -- darker than the texture average so grass-block sides read
	mossy_stone = Color3.fromRGB(146, 154, 158), -- mid gray like BedWars stone (texture average reads too pale)
	ruin_brick = Color3.fromRGB(205, 193, 152),
	bark = Color3.fromRGB(139, 101, 59),
	leaves = Color3.fromRGB(86, 175, 70),
	water = Color3.fromRGB(71, 186, 235),
}
local MaterialService = game:GetService("MaterialService")

local parts = { workspace:FindFirstChild("Baseplate"), workspace:FindFirstChildOfClass("SpawnLocation") }
for _, d in workspace.VoxelArena:GetDescendants() do
	if d:IsA("BasePart") then
		table.insert(parts, d)
	end
end

local n = 0
for _, p in parts do
	-- remember which texture and tint each block had the first time it is switched
	local tex = p:GetAttribute("VoxelTex") or p.MaterialVariant:match("^Voxel_(.+)")
	if tex and FLAT[tex] then
		if not p:GetAttribute("VoxelTex") then
			p:SetAttribute("VoxelTex", tex)
			p:SetAttribute("VoxelTint", p.Color.R)
		end
		local k = p:GetAttribute("VoxelTint")
		if TEXTURED then
			local v = MaterialService["Voxel_" .. tex]
			p.Material, p.MaterialVariant, p.Color = v.BaseMaterial, v.Name, Color3.new(k, k, k)
		else
			p.Material, p.MaterialVariant, p.Color = Enum.Material.SmoothPlastic, "", FLAT[tex]:Lerp(Color3.new(0, 0, 0), 1 - k)
		end
		n += 1
	end
end
return ("%s: %d parts"):format(if TEXTURED then "textured" else "flat", n)
