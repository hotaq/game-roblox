-- Edit-context functional regression runner. Pass the current repository source strings.
-- Executes exact production function spans with controlled runs/targets and real temporary Parts.
-- Does not write Script.Source, start Play, or claim multiplayer transport/animation verification.
return function(configSource, serverSource, clientSource)
	local function span(first, last)
		local a=assert(serverSource:find(first,1,true),first)
		local b=assert(serverSource:find(last,a+#first,true),last)
		return serverSource:sub(a,b-1)
	end
	local source="local Config=(function()\n"..configSource.."\nend)()\n"..[=[
local H,R,W,P=Config.Horde,Config.Run,Config.Weapons,Config.Passives
local Workspace=workspace
local alive,px,pz,hp,generation={},{},{},{},{}
local swingAt,nextSwing,kvx,kvz,stunUntil,slowUntil={},{},{},{},{},{}
local free,top,count,dead,deadFirstGem,gems,nextGem={},0,0,{},0,{},0
local deathEvents={}
local runs={};local rng=Random.new(12)
local function arena() return Vector3.zero,200 end
local fx={FireAllClients=function() end}
local runOver={FireClient=function() end}
]=]..span("local axes, axeSerial", "-- `run` =")
		..span("local function kill(", "-- The run arena:")
		..span("local grid = {}", "---------------------------------------------------------------- runs, XP, cards")
		..span("local function rollRarity(", "local function offer(")
		..span("local function restoreRunSpeed(", "local function startRun(")
		..span("local hitLog = {}", "local function moveShots(")
		..[=[
local checks={}
local function check(value,label) assert(value,label);table.insert(checks,label) end
local function near(a,b) return math.abs(a-b)<0.0001 end
local folder=Instance.new("Folder");folder.Name="GAME12AxeFunctionalTest";folder.Parent=Workspace
local function makeRun(x)
 local character=Instance.new("Model");character.Parent=folder
 local root=Instance.new("Part");root.Name="HumanoidRootPart";root.Anchored=true;root.CanCollide=false;root.Position=Vector3.new(x,4,0);root.Parent=character
 local hum=Instance.new("Humanoid");hum.Parent=character
 local player={Character=character,SetAttribute=function() end}
 local run={player=player,hum=hum,start=Workspace:GetServerTimeNow(),level=1,gems=0,kills=0,
  weapons={axe=1},wOrder={"axe"},passives={},pOrder={},bonus={might=0,area=0,haste=0,magnet=0,force=0},damage={},cd={}}
 runs[player]=run;return run,root
end
local function targets(entries)
 table.clear(grid);table.clear(alive);table.clear(free);top=#entries;count=#entries
 for i,e in entries do
  alive[i]=true;px[i],pz[i],hp[i]=e[1],e[2],e[3] or 1000
  generation[i]=(generation[i] or 0)+1;kvx[i],kvz[i],stunUntil[i],slowUntil[i]=0,0,0,0
  local k=key(px[i]//CELL,pz[i]//CELL);grid[k]=grid[k] or {};table.insert(grid[k],i)
 end
end
local function reset(run,root)
 clearRunAxes(run.player);run.cd.axe=0;root.CFrame=CFrame.new(0,4,0);runs[run.player]=run
 run.bonus={might=0,area=0,haste=0,magnet=0,force=0};run.weapons={axe=1}
end
local ok,err=xpcall(function()
 local run,root=makeRun(0)
 targets({{8,0}});fireWeapons(run,root,0)
 check(#axes==1,"creates one axe toward nearest enemy")
 for _=1,90 do pruneAxes();moveAxes(1/30) end
 check(hp[1]==968 and run.damage.axe==32 and #axes==0,"exactly one outgoing and one return hit, then catch")
 reset(run,root);targets({{8,0}});fireWeapons(run,root,0);local a=axes[1];moveAxes(.4)
 check(hp[1]==984,"long frame uses swept hit")
 axeSweep(a,0,0,16,0);check(hp[1]==984,"repeat sweep does not double hit same incarnation")
 generation[1]+=1;axeSweep(a,0,0,16,0);check(hp[1]==968,"reused slot can be hit as new enemy")
 reset(run,root);targets({{8,0}});fireWeapons(run,root,0);a=axes[1];moveAxes(24/38)
 root.CFrame+=Vector3.new(0,0,8);pruneAxes();moveAxes(.1)
 check(a.leg==2 and a.z>0,"return tracks owner movement")
 for _=1,100 do moveAxes(1/30) end;check(#axes==0,"moving owner catches axe")
 reset(run,root);targets({{8,0}});fireWeapons(run,root,0);axes[1].age=4.49;moveAxes(.02)
 check(#axes==0,"lifetime expires with bounded cleanup")
 reset(run,root);targets({{8,0}});fireWeapons(run,root,0);root.CFrame+=Vector3.new(60,0,0);pruneAxes()
 check(#axes==0,"teleport invalidates projectile")
 reset(run,root);targets({{8,0}});fireWeapons(run,root,0);root.Position=Vector3.new(210,4,0);pruneAxes()
 check(#axes==0,"arena exit invalidates projectile")
 run.cd.axe=0;fireWeapons(run,root,0);check(#axes==0,"outside owner cannot immediately create another axe")
 reset(run,root);targets({{8,0}});fireWeapons(run,root,0);runs[run.player]=nil;pruneAxes()
 check(#axes==0,"disconnected run no longer owns a projectile")
 reset(run,root);targets({{8,0}});fireWeapons(run,root,0);runs[run.player]={};pruneAxes()
 check(#axes==0,"replacement run cannot inherit old projectile")
 reset(run,root);targets({{8,0}});fireWeapons(run,root,0);local old=run.player.Character;run.player.Character=Instance.new("Model");pruneAxes()
 check(#axes==0,"character replacement clears projectile");run.player.Character:Destroy();run.player.Character=old
 reset(run,root);targets({{8,0}});fireWeapons(run,root,0);endRun(run.player)
 check(#axes==0 and runs[run.player]==nil,"real endRun clears owned axes")
 reset(run,root);targets({{8,0}});for _=1,6 do run.cd.axe=0;fireWeapons(run,root,0) end
 check(#axes==3,"three-projectile per-run limit")
 reset(run,root);targets({});fireWeapons(run,root,0);check(#axes==0,"no target does not throw")
 reset(run,root);targets({{0,0}});fireWeapons(run,root,0)
 check(axes[1].dx==0 and axes[1].dz==-1,"zero-distance target uses finite direction")
 reset(run,root);targets({{8,0,16}});local kills=run.kills;fireWeapons(run,root,0);moveAxes(.4);moveAxes(.4)
 local gemsCount=0;for _ in gems do gemsCount+=1 end
 check(run.kills==kills+1 and gemsCount==1,"lethal hit credits one kill and one XP gem")
 for level=1,5 do
  reset(run,root);targets({{8,0}});run.weapons.axe=level;run.bonus={might=.5,area=.5,haste=.5,magnet=0,force=1}
  fireWeapons(run,root,0);local s=Config.weaponStats("axe",level);a=axes[1]
  check(near(a.damage,s.Damage*1.5) and near(a.radius,s.Radius*1.5) and near(a.left,s.Range*1.5) and near(run.cd.axe,s.Cooldown*.5),"level "..level.." and passive scaling")
  moveAxes(.4);check(kvx[1]~=0 or kvz[1]~=0,"level "..level.." Force interaction")
 end
 -- Two actual independent run records/projectiles, not a fake untouched result counter.
 reset(run,root);local second,root2=makeRun(100);targets({{8,0},{108,0}})
 local oldDamage=run.damage.axe or 0
 fireWeapons(run,root,0);fireWeapons(second,root2,0)
 for _=1,90 do pruneAxes();moveAxes(1/30) end
 check(near((run.damage.axe or 0)-oldDamage,32) and second.damage.axe==32 and hp[1]==968 and hp[2]==968,"two runs keep damage ownership separate")
 targets({{8,0},{108,0}});run.cd.axe=0;second.cd.axe=0;fireWeapons(run,root,0);fireWeapons(second,root2,0)
 endRun(run.player);check(#axes==1 and axes[1].run==second,"ending one run preserves another player's axe")
 clearRunAxes(second.player)
 reset(run,root);run.weapons={sword=1};run.wOrder={"sword"};local offered=false
 for _=1,100 do for _,c in makeCards(run) do if c.id=="axe" and c.level==1 then offered=true end end end
 check(offered,"axe appears in ordinary new-weapon card pool")
 run.weapons={axe=5};run.wOrder={"axe"}
 local maxOffered=false
 for _=1,50 do for _,c in makeCards(run) do if c.id=="axe" then maxOffered=true end end end
 check(not maxOffered,"max axe is excluded from upgrade pool")
end,debug.traceback)
folder:Destroy()
return {ok=ok,error=if ok then nil else tostring(err),checks=checks,count=#checks,mode="isolated production functions, not live multiplayer"}
]=]
	local report = assert(loadstring(source))()
	if not report.ok or not clientSource then return report end
	local a = assert(clientSource:find("local axeViews = {}", 1, true))
	local b = assert(clientSource:find("-- END GAME-12 axe visual", a, true))
	local visualSource = [=[
local folder=Instance.new("Folder");folder.Name="GAME12AxeVisualTest";folder.Parent=workspace
]=] .. clientSource:sub(a,b-1) .. [=[
local checks={}
local function check(value,label) assert(value,label);table.insert(checks,label) end
local ok,err=xpcall(function()
 for _,level in {1,3,5} do
  local model,trail=makeAxeVisual(folder,level,1)
  local parts=0
  for _,p in model:GetDescendants() do
   if p:IsA("BasePart") then
    parts+=1
    assert(p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery)
    assert(p.Material==Enum.Material.Plastic)
   end
  end
  check(parts==(if level==5 then 15 else 13),"level "..level.." bounded cosmetic Plastic geometry")
  check(model:GetPivot().Position.Magnitude<.0001 and math.abs(trail.Lifetime-.1)<.00001 and trail.LightEmission==0,"level "..level.." centered pivot and short non-emissive trail")
  model:Destroy()
 end
 local owner={Character=folder}
 receiveAxes({{1,owner,10,20,4,1.8,1,0}})
 local model=axeViews[1].model
 check((model:GetPivot().Position-Vector3.new(10,4,20)).Magnitude<.001,"first snapshot places visual correctly")
 receiveAxes({{1,owner,12,22,4,1.8,1,.1}})
 check(axeViews[1].model==model and axeViews[1].tx==12 and axeViews[1].targetAge==.1,"next snapshot reuses model and updates targets")
 receiveAxes({})
 check(next(axeViews)==nil and model.Parent==nil,"empty snapshot destroys visual")
end,debug.traceback)
folder:Destroy()
return {ok=ok,error=if ok then nil else tostring(err),checks=checks,count=#checks}
]=]
	local visual = assert(loadstring(visualSource))()
	report.visual = visual
	report.ok = report.ok and visual.ok
	return report
end
