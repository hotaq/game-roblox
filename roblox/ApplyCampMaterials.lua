-- Apply the existing soft textures to the existing camp, without rebuilding geometry or lighting.
-- Run from Edit after reading this file. Original properties are retained as attributes for recovery.
local definitions={
	Grass={name="Camp_grass",fallback=Color3.fromRGB(117,178,77)},
	Wood={name="Camp_bark",fallback=Color3.fromRGB(122,94,70)},
	Ground={name="Camp_dirt",fallback=Color3.fromRGB(170,132,96)},
	Limestone={name="Camp_bone",fallback=Color3.fromRGB(227,216,191)},
	Fabric={name="Camp_cloth",fallback=Color3.fromRGB(195,67,56)},
	Slate={name="Camp_stone",fallback=Color3.fromRGB(146,155,134)},
}
local report={assets={},counts={},changed=0}
for material,def in definitions do
	local variant=assert(game.MaterialService:FindFirstChild(def.name),"Missing "..def.name)
	assert(variant:IsA("MaterialVariant") and variant.BaseMaterial.Name==material,"Wrong base material")
	local probe=Instance.new("ImageLabel"); probe.Image=variant.ColorMap
	local loaded=false
	game:GetService("ContentProvider"):PreloadAsync({probe},function(_,status) loaded=status==Enum.AssetFetchStatus.Success end)
	probe:Destroy(); assert(loaded,"Image unavailable: "..def.name)
	report.assets[def.name]=variant.ColorMap
end
local function apply(part)
	local def=definitions[part.Material.Name]
	if not def then return end
	if part.MaterialVariant==def.name then
		report.counts[def.name]=(report.counts[def.name] or 0)+1
		return
	end
	if part.MaterialVariant~="" then return end -- preserve any other deliberately assigned variant
	local original=part.Color
	part:SetAttribute("CampOriginalColor",original)
	part:SetAttribute("CampOriginalMaterial",part.Material.Name)
	part:SetAttribute("CampOriginalVariant",part.MaterialVariant)
	-- Recover BuildFlatGround's original scalar tint from its baked fallback colour.
	local base=def.fallback
	local k=math.clamp((original.R/base.R+original.G/base.G+original.B/base.B)/3,0,1)
	part.Color=Color3.new(k,k,k)
	part.MaterialVariant=def.name
	report.counts[def.name]=(report.counts[def.name] or 0)+1
	report.changed+=1
end
local camp=assert(workspace:FindFirstChild("FlatGround"),"FlatGround missing")
local before=#camp:GetDescendants()
for i,part in camp:GetDescendants() do
	if part:IsA("BasePart") then apply(part) end
	if i%300==0 then task.wait() end
end
for _,name in {"Baseplate","SpawnLocation"} do
	local part=workspace:FindFirstChild(name)
	if part and part:IsA("BasePart") then apply(part) end
end
assert(#camp:GetDescendants()==before,"Geometry changed unexpectedly")
report.geometryCount=before
return report
