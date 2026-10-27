-- Exact production spans, temporary models only. Complements real solo/team fixture.
return function(configSource,serverSource,clientSource)
	local function span(s,a,b)local first=assert(s:find(a,1,true));return s:sub(first,assert(s:find(b,first+#a,true))-1)end
	local code="local Config=(function()\n"..configSource.."\nend)()\n"..[=[
local W,P,R=Config.Weapons,Config.Passives,Config.Run
local fraction=0;local rng={NextNumber=function(_,low,high)return low+(high-low)*fraction end,NextInteger=function(_,low)return low end}
]=]..span(serverSource,"local function rollRarity(","local function offer(")..[=[
local checks={};local function check(v,label)assert(v,label);table.insert(checks,label)end
local before,after={0,0,0},{0,0,0}
for i=1,1000 do fraction=(i-.5)/1000;before[rollRarity(0)]+=1;after[rollRarity(1)]+=1 end
check(after[1]<before[1]and after[2]>before[2]and after[3]>before[3],"Luck raises Rare and Epic probability and lowers Common")
fraction=.5;check(rollRarity(9)==rollRarity(1)and rollRarity(-5)==rollRarity(0),"Luck probability clamps at both bounds")
for _,id in W.Order do
 local r={weapons={[id]=5},wOrder={id},passives={},pOrder={},evolved={}}
 check(not Config.canEvolve(r,id),id.." needs its exact passive")
 r.passives[Config.Evolutions[id].Passive]=1;local c=makeCards(r)
 check(c[1].kind=="evolve"and c[1].id==id,id.." evolution reserved in normal card pool")
 r.evolved[id]=true;local found=false;for _,v in makeCards(r)do if v.id==id then found=true end end
 check(not found,id.." evolved weapon has no repeat card")
 local stats=Config.weaponStats(id,6);for k,v in Config.Evolutions[id].Stats do assert(stats[k]==v)end
 check(stats.Damage>Config.weaponStats(id,5).Damage,id.." shared level6 stats strengthen base weapon")
end
local r={weapons={sword=5,fire=5,ring=5,axe=5},wOrder={"sword","fire","ring","axe"},passives={might=5,projectile=5,area=5,speed=5,luck=5},pOrder={"might","projectile","area","speed","luck"},evolved={}}
for _,c in makeCards(r)do assert(c.kind=="evolve")end
check(true,"full slots still permit evolution and exclude new acquisitions")
r.evolved={sword=true,fire=true,ring=true,axe=true};check(makeCards(r)[1].kind=="heal","fully maxed and evolved loadout falls back to heal")
return {checks=checks,rarity={before=before,after=after}}
]=]
	local result=assert(loadstring(code,"CompleteCardsExact"))()
	local visual=[=[
local Workspace=workspace;local folder=Instance.new("Folder");folder.Name="GAME12TotemVisualProbe";folder.Parent=workspace
]=]..span(clientSource,"local totemViews={}","-- END GAME-12 totem visual")..[=[
local checks={};local function check(v,label)assert(v,label);table.insert(checks,label)end
local ok,err=xpcall(function()
 for _,level in {1,3,5,6}do
  local m=makeTotemVisual(folder,level);local n=0
  m:PivotTo(CFrame.new(12,3,7))
  for _,p in m:GetDescendants()do if p:IsA("BasePart")then n+=1;assert(p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery)end end
  check(n<=20 and n>=10,"totem Lv"..level.." bounded cosmetic geometry")
  check((m:GetPivot().Position-Vector3.new(12,3,7)).Magnitude<.001,"totem Lv"..level.." ground pivot")
  check((m:FindFirstChild("AncientSeal")~=nil)==(level==6),"totem Lv"..level.." distinct evolved seal")
  m:Destroy()
 end
 local owner={Character=Instance.new("Model")}
 receiveTotems({{1,owner,0,0,0,1}});local first=totemViews[1].model
 receiveTotems({{1,owner,0,0,0,1}});check(totemViews[1].model==first,"steady totem snapshots reuse model")
 receiveTotems({{2,owner,1,0,0,6}});check(first.Parent==nil and totemViews[2]~=nil,"replacement snapshot retires old generation")
 receiveTotems({});check(next(totemViews)==nil and #folder:GetChildren()==0,"empty snapshot clears all models")
 local camera=Workspace.CurrentCamera;local original=camera.CFrame;camera.CFrame=CFrame.new(0,10,10)
 local packet={};for i=1,100 do packet[i]={0,0,4,5,5,6}end
 drawLightning(packet);check(activeBolts==16 and #folder:GetChildren()==48,"100 requested bolts bound to16 bolts and48 segments")
 drawLightning(packet);check(#folder:GetChildren()==48,"same-frame extra strikes cannot exceed visual cap")
 task.wait(.25);check(activeBolts==0 and #folder:GetChildren()==0,"transient lightning releases parts and counter")
 camera.CFrame=original;owner.Character:Destroy()
end,debug.traceback)
folder:Destroy();assert(ok,err);return checks
]=]
	result.visual=assert(loadstring(visual,"CompleteVisualExact"))();result.ok=true;result.count=#result.checks+#result.visual;return result
end
