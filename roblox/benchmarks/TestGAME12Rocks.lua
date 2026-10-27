-- Exact server/visual spans with controlled owners and real temporary models; no Source writes.
return function(configSource,serverSource,clientSource)
	local function span(source,first,last)
		local a=assert(source:find(first,1,true));local b=assert(source:find(last,a+#first,true));return source:sub(a,b-1)
	end
	local code="local Config=(function()\n"..configSource.."\nend)()\n"..[=[
local Workspace,Players=workspace,{}
local alive,px,pz,generation={},{},{},{}
local runs,hits={},{}
local function arena() return Vector3.zero,200 end
local function around(x,z,r,fn) for id in alive do if (px[id]-x)^2+(pz[id]-z)^2<=r*r then fn(id) end end end
local function hit(id,damage,run,weapon,x,z,knock,stun) table.insert(hits,{id=id,damage=damage,run=run,weapon=weapon,knock=knock,stun=stun}) end
local lastPacket
local fx={FireAllClients=function(_,kind,packet) lastPacket=packet end}
]=]..span(serverSource,"local rockSerial,", "-- END GAME-12 rocks simulation")..[=[
local W,P,R=Config.Weapons,Config.Passives,Config.Run
local rng={NextNumber=function() return 0 end,NextInteger=function(_,_,high) return high end}
]=]..span(serverSource,"local function rollRarity(","local function offer(")..[=[
local checks={}
local function check(v,label) assert(v,label);table.insert(checks,label) end
local folder=Instance.new("Folder");folder.Name="GAME12RocksFunctional";folder.Parent=Workspace
local function owner(x)
 local character=Instance.new("Model");character.Parent=folder
 local root=Instance.new("Part");root.Anchored=true;root.CFrame=CFrame.new(x,4,0);root.Parent=character
 local hum=Instance.new("Humanoid");hum.Parent=character
 local player={Parent=Players,Character=character}
 local run={player=player,hum=hum,weapons={rocks=1},bonus={area=0,might=0,haste=0,force=0}}
 runs[player]=run;return run,root
end
local function targets(x,z)
 table.clear(alive);table.clear(px);table.clear(pz);table.clear(hits)
 alive[1]=true;px[1],pz[1]=x,z;generation[1]=(generation[1] or 0)+1
end
local ok,err=xpcall(function()
 local run,root=owner(0)
 targets(7,0);moveRocks(run,root,0)
 check(#hits==1 and hits[1].damage==12 and hits[1].weapon=="rocks" and not hits[1].stun,"initial contact deals configured non-stunning damage")
 local state=run.rocks;rockSweep(run,state,7,0,7,0,Config.weaponStats("rocks",1))
 check(#hits==1,"overlapping stones share one target cooldown")
 state.age=.56;rockSweep(run,state,7,0,7,0,Config.weaponStats("rocks",1));check(#hits==2,"same incarnation can be hit after cooldown")
 generation[1]+=1;rockSweep(run,state,7,0,7,0,Config.weaponStats("rocks",1));check(#hits==3,"reused slot does not inherit prior incarnation cooldown")
 targets(7*math.cos(.18),7*math.sin(.18));run.rocks=nil;moveRocks(run,root,.2)
 check(#hits==1,"subdivided curved sweep hits between endpoint angles once")
 run.rocks=nil;targets(100,100);moveRocks(run,root,0)
 targets(9.5,.1);root.Position=Vector3.new(5,4,0);moveRocks(run,root,1/30)
 check(#hits==1 and run.rocks.x==5,"ordinary owner movement sweeps contacts and follows the new centre")
 targets(25,0);root.Position=Vector3.new(60,4,0);moveRocks(run,root,1/30)
 check(#hits==0 and run.rocks.x==60,"teleport resets orbit without sweeping through intervening targets")
 root.Position=Vector3.new(0,4,0);run.rocks=nil
 for level=1,5 do
  run.weapons.rocks=level;run.bonus={area=.5,might=.3,haste=.25,force=1}
  targets(10.5,0);moveRocks(run,root,0);local s=Config.weaponStats("rocks",level)
  check(run.rocks.count==s.Count and run.rocks.radius==s.Radius*1.5 and run.rocks.orbit==10.5,"level "..level.." count and Area scaling")
  check(#hits==1 and math.abs(hits[1].damage-s.Damage*1.3)<.001 and math.abs(run.rocks.hit[1].untilAge-s.Interval*.75)<.001,"level "..level.." Might and Haste scaling")
 end
 local other,root2=owner(0);targets(7,0);run.rocks=nil;run.weapons.rocks=1;run.bonus={area=0,might=0,haste=0,force=0}
 moveRocks(run,root,0);moveRocks(other,root2,0)
 check(#hits==2 and hits[1].run~=hits[2].run,"two owners retain independent hit cooldown and credit")
 sendRocks();check(#lastPacket==2,"one snapshot includes both owners")
 run.hum.Health=0;pruneRocks();sendRocks();check(not run.rocks and other.rocks and #lastPacket==1,"dead owner disappears without clearing peer")
 other.player.Parent=nil;pruneRocks();sendRocks();check(not other.rocks and #lastPacket==0,"disconnect clears final orbit snapshot")
 other.player.Parent=Players;moveRocks(other,root2,0);root2.Position=Vector3.new(210,4,0);pruneRocks();moveRocks(other,root2,0)
 check(not other.rocks,"arena exit cannot recreate orbit")
 root2.Position=Vector3.new(0,4,0);moveRocks(other,root2,0);other.weapons.rocks=nil;pruneRocks();check(not other.rocks,"unequipped orbit is released")
 other.weapons.rocks=1;moveRocks(other,root2,0);local previous=other.player.Character;other.player.Character=Instance.new("Model");pruneRocks()
 check(not other.rocks,"replaced character cannot retain orbit");other.player.Character:Destroy();other.player.Character=previous
 moveRocks(other,root2,0);for i=1,100 do other.rocks.hit[i]={incarnation=-1,untilAge=99} end
 moveRocks(other,root2,1/30);local n=0;for _ in other.rocks.hit do n+=1 end;check(n<=1,"stale incarnation ledger entries are bounded and pruned")
 local cardsRun={weapons={},wOrder={},passives={},pOrder={}}
 for _,id in P.Order do cardsRun.passives[id]=P.MaxLevel;table.insert(cardsRun.pOrder,id) end
 local cards=makeCards(cardsRun);check(cards[1].id=="rocks" and cards[1].level==1,"rocks participates in ordinary new-weapon card pool")
 cardsRun.weapons.rocks=5;cardsRun.wOrder={"rocks"};cards=makeCards(cardsRun)
 local hasRocks=false;for _,c in cards do if c.id=="rocks" then hasRocks=true end end
 check(not hasRocks,"max-level rocks does not appear as another upgrade")
 cardsRun.weapons={sword=5,fire=5,ring=5,axe=5};cardsRun.wOrder={"sword","fire","ring","axe"};cards=makeCards(cardsRun)
 check(cards[1].kind=="heal","full weapon slots prevent acquiring a fifth weapon")
end,debug.traceback)
folder:Destroy();assert(ok,err)
return checks
]=]
	local checks=assert(loadstring(code,"RocksExactServer"))()
	local visual=[=[
local folder=Instance.new("Folder");folder.Name="RocksVisualTest";folder.Parent=workspace
]=]..span(clientSource,"local rockViews={}","-- END GAME-12 rocks visual")..[=[
local checks={};local function check(v,label) assert(v,label);table.insert(checks,label) end
local ok,err=xpcall(function()
 for _,level in {1,3,5} do
  local model=makeRockVisual(folder,level,1.25);local parts=0
  for _,p in model:GetDescendants() do if p:IsA("BasePart") then
   assert(not p.CanCollide and not p.CanTouch and not p.CanQuery and p.Anchored and p.Material==Enum.Material.Plastic);parts+=1
  end end
  check(parts<=9 and parts>=8,"level "..level.." bounded matte cosmetic geometry")
  model:Destroy()
 end
 local owner={Character=Instance.new("Model")}
 receiveRocks({{owner,1,10,0,3,0,2,1.25,7,1}})
 check(#rockViews[owner].models==2,"snapshot creates exact stone count")
 local original=rockViews[owner].models[1]
 receiveRocks({{owner,1,11,0,3,.1,2,1.25,7,1}})
 check(rockViews[owner].models[1]==original and rockViews[owner].tx==11,"steady snapshot reuses geometry")
 receiveRocks({{owner,2,11,0,3,.1,4,1.55,7,5}})
 check(#rockViews[owner].models==4 and original.Parent==nil,"new generation replaces level/count geometry")
 receiveRocks({});check(next(rockViews)==nil and #folder:GetChildren()==0,"empty snapshot destroys all orbit models")
 owner.Character:Destroy()
end,debug.traceback)
folder:Destroy();assert(ok,err);return checks
]=]
	local visualChecks=assert(loadstring(visual,"RocksExactVisual"))()
	return {ok=true,server=checks,visual=visualChecks,count=#checks+#visualChecks,mode="exact production spans; live network checked separately"}
end
