-- Undo the GAME-11 material pass using its saved per-part properties.
-- Does not rebuild the map or change Lighting. Safe to run again.
local definitions = {
	Grass = {name = "Camp_grass", fallback = Color3.fromRGB(117,178,77)},
	Wood = {name = "Camp_bark", fallback = Color3.fromRGB(122,94,70)},
	Ground = {name = "Camp_dirt", fallback = Color3.fromRGB(170,132,96)},
	Limestone = {name = "Camp_bone", fallback = Color3.fromRGB(227,216,191)},
	Fabric = {name = "Camp_cloth", fallback = Color3.fromRGB(195,67,56)},
	Slate = {name = "Camp_stone", fallback = Color3.fromRGB(146,155,134)},
}
local camp = assert(workspace:FindFirstChild("FlatGround"), "FlatGround missing")
local count = #camp:GetDescendants()
local parts = camp:GetDescendants()
for _,name in {"Baseplate", "SpawnLocation"} do
	local part = workspace:FindFirstChild(name)
	if part then table.insert(parts,part) end
end
local pending = {}
-- Validate the whole pass before changing anything, preserving later edits.
for i,part in parts do
	if part:IsA("BasePart") and part:GetAttribute("CampOriginalColor") then
		local color = part:GetAttribute("CampOriginalColor")
		local material = part:GetAttribute("CampOriginalMaterial")
		local variant = part:GetAttribute("CampOriginalVariant")
		local def = definitions[material]
		assert(typeof(color) == "Color3" and def and type(variant) == "string", "Incomplete backup: "..part:GetFullName())
		local base = def.fallback
		local k = math.clamp((color.R/base.R+color.G/base.G+color.B/base.B)/3,0,1)
		local expected = Color3.new(k,k,k)
		assert(part.Material.Name == material and part.MaterialVariant == def.name, "Material changed since GAME-11: "..part:GetFullName())
		assert(math.abs(part.Color.R-expected.R)<0.005 and math.abs(part.Color.G-expected.G)<0.005 and math.abs(part.Color.B-expected.B)<0.005, "Color changed since GAME-11: "..part:GetFullName())
		table.insert(pending,{part=part,color=color,material=material,variant=variant})
	end
	if i%300==0 then task.wait() end
end
for i,saved in pending do
	local part = saved.part
	part.Color = saved.color
	part.Material = Enum.Material[saved.material]
	part.MaterialVariant = saved.variant
	assert(part.Color == saved.color and part.Material.Name == saved.material and part.MaterialVariant == saved.variant, "Restoration mismatch")
	part:SetAttribute("CampOriginalColor",nil)
	part:SetAttribute("CampOriginalMaterial",nil)
	part:SetAttribute("CampOriginalVariant",nil)
	if i%300==0 then task.wait() end
end
assert(#camp:GetDescendants() == count, "Geometry changed unexpectedly")
return {restored=#pending, geometryCount=count}
