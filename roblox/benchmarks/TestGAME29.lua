-- Exact objective state machine. Real temporary marker/characters; no production Source writes.
return function(serverSource)
	local a=assert(serverSource:find("local objectiveEnabled=",1,true))
	local b=assert(serverSource:find("-- END GAME-29 objective prototype",a,true))
	local code=[=[
local Workspace,Players=workspace,{}
local RunService={IsStudio=function()return true end}
local Config={ObjectiveTrial={Enabled=false,Trigger=30,Window=35,Hold=8,Radius=8,Decay=1}}
local Shared={SetAttribute=function()end}
local runs={}
local function arena()return Vector3.zero,200,Vector3.new(0,0,24)end
local function offer(run) run.offers=(run.offers or 0)+1;run.cards={offered=true} end
]=]..serverSource:sub(a,b-1)..[=[
local checks={};local function check(v,label)assert(v,label);table.insert(checks,label)end
local folder=Instance.new("Folder");folder.Name="GAME29Boundary";folder.Parent=workspace
local function owner(x)
 local model=Instance.new("Model");model.Parent=folder
 local root=Instance.new("Part");root.Name="HumanoidRootPart";root.Anchored=true;root.Position=Vector3.new(x,4,0);root.Parent=model
 local hum=Instance.new("Humanoid");hum.Parent=model
 local player={Parent=Players,Character=model};local run={hum=hum,pending=0,player=player};runs[player]=run
 return player,run,root
end
local function reset() objectiveReset();table.clear(runs);folder:ClearAllChildren() end
local function start() objectiveTick(30,false);assert(objectiveState.phase=="active");return objectiveState end
local ok,err=xpcall(function()
 local p,r,root=owner(0);objectiveTick(100,false)
 check(not objectiveState and r.pending==0,"disabled option creates no state/marker/reward")
 objectiveEnabled=true;objectiveTick(10,true);check(objectiveState.age==0,"card pause does not advance trigger")
 local s=start();root.Position=Vector3.new(30,4,0);objectiveTick(35,false)
 check(s.phase=="expired" and r.pending==0 and runs[p]==r,"ignored objective expires without affecting run")
 objectiveTick(100,false);check(objectiveState==s and not s.marker,"terminal attempt cannot respawn or retain marker")
 reset();p,r,root=owner(0);s=start();objectiveTick(3,false);root.Position=Vector3.new(30,4,0);objectiveTick(2,false)
 check(s.progress==1,"leaving to dodge decays progress instead of awarding")
 local progress,time=s.progress,s.elapsed;objectiveTick(100,true)
 check(s.progress==progress and s.elapsed==time,"pause freezes hold and deadline")
 root.Position=Vector3.new(0,4,0);objectiveTick(7,false)
 check(s.phase=="success" and r.pending==1 and r.offers==1,"one successful hold creates one ordinary offer")
 objectiveFinish(s,"success");objectiveTick(100,false)
 check(r.pending==1 and r.objectiveRewards==1,"duplicate completion and later ticks cannot reward twice")
 check(next(s.roster)==nil and s.marker==nil,"terminal state releases run references and marker")
 reset();local p1,r1,root1=owner(0);local p2,r2,root2=owner(100);s=start()
 local existing={existing=true};r2.cards=existing;r2.pending=2;objectiveTick(8,false)
 check(r1.objectiveRewards==1 and r2.objectiveRewards==1,"distant original living teammate receives team reward")
 check(r2.cards==existing and r2.pending==3 and not r2.offers,"reward queues behind existing offer without replacement")
 reset();p1,r1,root1=owner(30);s=start();p2,r2,root2=owner(0);objectiveTick(8,false)
 check(s.progress==0 and not r2.objectiveRewards,"late join cannot contribute to original attempt")
 root1.Position=Vector3.new(0,4,0);objectiveTick(8,false)
 check(r1.objectiveRewards==1 and not r2.objectiveRewards,"late join cannot receive completion reward")
 reset();p1,r1,root1=owner(0);p2,r2,root2=owner(0);s=start();r2.hum.Health=0;objectiveTick(8,false)
 check(r1.objectiveRewards==1 and not r2.objectiveRewards,"death at commit is excluded from reward")
 reset();p1,r1,root1=owner(0);p2,r2,root2=owner(0);s=start();p2.Parent=nil;objectiveTick(0,true)
 check(s.roster[p2]==nil,"disconnect releases identity during card pause")
 objectiveTick(8,false);check(r1.objectiveRewards==1 and not r2.objectiveRewards,"disconnect before commit receives nothing")
 reset();p1,r1,root1=owner(0);p2,r2,root2=owner(0);s=start()
 local replacement={hum=r2.hum,player=p2,pending=0};runs[p2]=replacement;objectiveTick(8,false)
 check(not replacement.objectiveRewards and not r2.objectiveRewards,"replacement run cannot inherit previous run's eligibility")
 local old=s;reset();p,r,root=owner(0);s=start();objectiveFinish(old,"success")
 check(r.pending==0 and s.phase=="active","stale previous-attempt callback cannot award new run")
 root.Position=Vector3.new(0,20,0);objectiveTick(8,false);check(s.progress==0,"height outside zone cannot build progress")
 root.Position=Vector3.new(0,4,0);r.hum.Health=0;objectiveTick(0,true)
 check(s.phase=="cancelled" and next(s.roster)==nil,"last original death cancels even while paused")
 reset();p1,r1,root1=owner(0);p2,r2,root2=owner(0);s=start();root2.Position=Vector3.new(250,4,0);objectiveTick(8,false)
 check(r1.objectiveRewards==1 and not r2.objectiveRewards,"outside arena is excluded at reward commit")
 table.clear(runs);objectiveTick(0,true);check(objectiveState==nil,"empty server clears attempt latch")
end,debug.traceback)
objectiveReset();folder:Destroy();assert(ok,err)
return {ok=true,count=#checks,checks=checks,mode="exact objective span, not live playtest"}
]=]
	return assert(loadstring(code,"GAME29Exact"))()
end
