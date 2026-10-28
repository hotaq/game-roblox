-- Exact encounter/eligibility code with fake AI transport and real temporary
-- Humanoids/Parts. No Source writes or Play. Does not verify live animation/AI.
return function(configSource,serverSource)
	local function span(first,last)
		local a=assert(serverSource:find(first,1,true));local b=assert(serverSource:find(last,a+#first,true))
		return serverSource:sub(a,b-1)
	end
	local source="local Config=(function()\n"..configSource.."\nend)()\n"..[=[
local folder=Instance.new("Folder");folder.Name="GAME28StateCheck";folder.Parent=game.ServerStorage
local Players,RunService={},game:GetService("RunService")
local zone,clock="StressZone",100
local Workspace={GetAttribute=function()return zone end,GetServerTimeNow=function()return clock end}
local attrs={};local Shared={SetAttribute=function(_,k,v)attrs[k]=v end}
local MapLayout={groundAt=function()return 0 end}
local runs,alive,hp,px,pz,generation={},{},{},{},{},{}
local eliteDamage
local queued={};local task={delay=function(_,f)table.insert(queued,f)end}
local function arena()return Vector3.zero,100 end
local offers=0
local function offer(r)offers+=1;r.cards={"test"}end
local actor,spawns=nil,0
local api={Invoke=function(_,command,token,data)
 if command=="spawn"then
  spawns+=1;actor=Instance.new("Model");actor.Parent=folder
  local root=Instance.new("Part");root.Name="HumanoidRootPart";root.Anchored=true;root.CFrame=token;root.Parent=actor
  local hum=Instance.new("Humanoid");hum.MaxHealth=data.health;hum.Health=data.health;hum.Parent=actor
  return actor
 elseif token~=actor then return nil
 elseif command=="destroy"then actor:Destroy();return true
 elseif command=="damage"then local h=actor:FindFirstChildOfClass("Humanoid");local n=math.min(data.amount,h.Health);h.Health-=n;return n
 elseif command=="members"then return true end
end}
local ServerStorage={FindFirstChild=function()return api end}
]=]..span("local function objectiveEligible(","local function objectiveReset(")
	..span("-- GAME-28 opt-in encounter.","-- END GAME-28 encounter")..[=[
local checks={};local function check(v,label)assert(v,label);table.insert(checks,label)end
local function player(x)
 local c=Instance.new("Model");c.Parent=folder
 local root=Instance.new("Part");root.Name="HumanoidRootPart";root.Anchored=true;root.Position=Vector3.new(x,3,0);root.Parent=c
 local hum=Instance.new("Humanoid");hum.Parent=c
 local p={Character=c,Parent=Players,FindFirstChildOfClass=function()return folder end}
 local r={player=p,hum=hum,start=0,pending=0,kills=0,damage={}};runs[p]=r;return p,r
end
local function flush()for _,f in queued do f()end;table.clear(queued)end
local ok,err=xpcall(function()
 local a,ra=player(0);local b,rb=player(30)
 eliteTick(1);check(eliteState==nil and spawns==0,"default OFF never spawns")
 eliteEnabled=true;eliteTick(1);local state=eliteState
 check(state and spawns==1 and alive[-1],"trigger creates exactly one separate actor")
 check(hp[-1]==450,"two-member HP multiplier applied once")
 eliteTick(1);check(spawns==1,"active encounter does not duplicate spawn")
 local c,rc=player(50);local before=hp[-1]
 eliteDamage(30,rc,"sword",0,0,true);check(hp[-1]==before,"late entrant cannot damage original encounter")
 ra.cards={"existing"};ra.pending=1;ra.pausedAt=clock
 eliteDamage(30,ra,"sword",0,0,true);check(hp[-1]==before,"chooser cannot damage")
 local elapsed=state.elapsed;eliteTick(1);check(state.elapsed==elapsed+1,"active peer keeps deadline moving")
 rb.cards={"existing"};elapsed=state.elapsed;eliteTick(1);check(state.elapsed==elapsed,"all choosing freeze deadline")
 rb.cards=nil;eliteDamage(20,rb,"sword",0,0,false)
 check(rb.damage.sword==20 and hp[-1]==430,"peer gets own actual damage credit")
 eliteDamage(1000,rb,"sword",0,0,false)
 check(state.phase=="defeated" and state.awarded==2,"reward only original roster")
 check(ra.pending==2 and ra.cards[1]=="existing","reward queues behind existing choice")
 check(rb.pending==1 and rb.cards and rc.pending==0,"active peer gets card; late entrant gets none")
 check(rb.damage.sword==450 and rb.kills==1,"overkill capped and one killer statistic")
 eliteFinish(state,"defeated");check(ra.pending==2 and rb.pending==1,"duplicate finish grants nothing")
 check(not alive[-1] and next(state.hud)==nil,"terminal clears proxy and UI")
 eliteTick(99);check(spawns==1,"terminal attempt stays latched while runs exist")
 flush();check(not actor.Parent,"bounded delayed cleanup removes actor")
 table.clear(runs);eliteTick(0);check(eliteState==nil,"empty roster resets attempt")
 runs[a]=ra;runs[b]=rb;ra.cards=nil;rb.cards=nil;ra.pausedAt=nil
 state=eliteSpawn(false);local old=ra;local replacement={player=a,hum=ra.hum,start=clock,pending=0,kills=0,damage={}};runs[a]=replacement
 before=hp[-1];eliteDamage(5,old,"sword",0,0,true);check(hp[-1]==before,"stale run damage rejected")
 rb.hum.Health=0;eliteFinish(state,"defeated")
 check(state.awarded==0 and replacement.pending==0,"replaced run and death-boundary recipient excluded")
 flush();eliteReset();rb.hum:Destroy();runs[b]=nil;ra=replacement
 state=eliteSpawn(false);zone="Map1";eliteTick(0)
 check(state.phase=="cancelled" and not alive[-1] and not actor.Parent,"arena change cancels without reward")
 zone="StressZone";eliteReset();state=eliteSpawn(false);state.elapsed=Config.EliteTrial.Window;eliteTick(0)
 check(state.phase=="expired" and runs[a]==ra and not actor.Parent,"expiry preserves run and removes actor")
 eliteReset();state=eliteSpawn(false);a.Parent=nil;eliteTick(0)
 check(state.phase=="cancelled" and not actor.Parent,"disconnected original member cancels")
 table.clear(runs);eliteTick(0);check(eliteState==nil and not alive[-1],"final state reset")
end,debug.traceback)
folder:Destroy();assert(ok,err);return {ok=true,count=#checks,checks=checks,mode="exact encounter and eligibility; mocked AI transport, not live combat"}
]=]
	return assert(loadstring(source,"GAME28StateExact"))()
end
