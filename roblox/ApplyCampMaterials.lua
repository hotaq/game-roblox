-- Material-only successor to rebuilding FlatGround after texture approval.
-- Run in Edit only after a real client swatch review. Preserves geometry,
-- every Part.Color, Lighting, map/pads and the current palette. Idempotent.
-- options.mode: "preview" (default), "apply", "revert".
return function(options)
 options=options or {};local mode=options.mode or "preview"
 assert(mode=="preview"or mode=="apply"or mode=="revert","invalid mode")
 local camp=assert(workspace:FindFirstChild("FlatGround"),"FlatGround missing")
 local materials=game:GetService("MaterialService");local items,counts={},{}
 local function classify(p)
  local saved=p:GetAttribute("CampSoftKind");if saved then return saved end
  local group=p.Parent.Name;local c,s=p.Color,p.Size
  if p.Material==Enum.Material.Neon or p.Material==Enum.Material.Metal then return nil end
  if group=="Tiles"then
   if (s-Vector3.new(4,1,4)).Magnitude>.01 then return nil end -- leave grass blades alone
   return if c.G>c.R then "grass"else "dirt"
  end
  if group=="Boulder"or group=="SpawnPad"then
   return if c.G/c.R<1.18 then "stone"else nil -- preserve moss accents
  end
  if group~="Palisade"and group~="Gate"and group~="Banner"and group~="Bones"and group~="Campfire"then return nil end
  if math.max(c.R,c.G,c.B)-math.min(c.R,c.G,c.B)<.045 or c.R<.16 then return nil end -- iron bands/eye sockets
  if c.R>c.G*1.7 then return "cloth"end
  if c.B/c.R>.72 and c.R>c.G and c.G>c.B then return "bone"end
  if c.R>c.G*1.15 and c.G>c.B*1.2 then return "bark"end
  if group=="Campfire"and c.G>c.R and c.G/c.R<1.18 then return "stone"end
  return nil
 end
 for i,p in camp:GetDescendants()do
  if p:IsA("BasePart")then
   local kind=classify(p)
   if kind then
    local v=assert(materials:FindFirstChild("Camp_"..kind),"missing variant "..kind)
    assert(v:IsA("MaterialVariant")and v.ColorMap~="","missing color map "..kind)
    table.insert(items,{p=p,kind=kind,v=v,color=p.Color,cf=p.CFrame,size=p.Size})
    counts[kind]=(counts[kind]or 0)+1
   end
  end
  if i%500==0 then task.wait()end
 end
 if mode=="apply"then assert(options.renderVerified==true,"inspect actual client swatches first")end
 local changed=0
 for i,item in items do
  local p=item.p
  if mode=="apply"then
   if not p:GetAttribute("CampSoftKind")then
    p:SetAttribute("CampSoftMaterial",p.Material.Name);p:SetAttribute("CampSoftVariant",p.MaterialVariant)
    p:SetAttribute("CampSoftKind",item.kind)
   end
   p.Material,p.MaterialVariant=item.v.BaseMaterial,item.v.Name;changed+=1
  elseif mode=="revert"and p:GetAttribute("CampSoftKind")then
   p.Material=Enum.Material[p:GetAttribute("CampSoftMaterial")];p.MaterialVariant=p:GetAttribute("CampSoftVariant")
   p:SetAttribute("CampSoftKind",nil);p:SetAttribute("CampSoftMaterial",nil);p:SetAttribute("CampSoftVariant",nil);changed+=1
  end
  assert(p.Color==item.color and p.CFrame==item.cf and p.Size==item.size,"palette/geometry changed")
  if i%300==0 then task.wait()end
 end
 return {mode=mode,eligible=#items,changed=changed,counts=counts,palettePreserved=true,geometryPreserved=true}
end
