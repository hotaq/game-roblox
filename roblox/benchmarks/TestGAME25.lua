-- Boundary regression for the exact production cleanup spans; run in Studio Edit/MCP.
-- Complements (does not replace) the live restart/disconnect/soak fixture.
return function(serverSource,clientSource)
	local a=assert(serverSource:find("\t-- Lifetime cleanup must run",1,true))
	local b=assert(serverSource:find("\tlocal center, half = arena()",a,true))
	local prune=serverSource:sub(a,b-1)
	a=assert(clientSource:find('\telseif kind == "clearGems" then',1,true))
	a=assert(clientSource:find("\n",a,true))+1
	b=assert(clientSource:find('\telseif kind == "axes" then',a,true))
	local retire=clientSource:sub(a,b-1)
	local source=[=[
local Players,Workspace={},workspace
local runs,shots,lastHit={},{},{}
local checks={}
local function check(v,label) assert(v,label); table.insert(checks,label) end
local folder=Instance.new("Folder");folder.Name="GAME25BoundaryTest";folder.Parent=Workspace
local function owner()
 local character=Instance.new("Model");character.Parent=folder
 local hum=Instance.new("Humanoid");hum.Parent=character
 local player={Parent=Players,Character=character}
 local run={player=player,hum=hum};runs[player]=run
 return run
end
local function prune()
]=]..prune..[=[
end
local gems,gemPool,HIDDEN={},{},CFrame.new(0,-1000,0)
local function retire(...)
]=]..retire..[=[
end
local ok,err=xpcall(function()
 local active,ended,dead,left,replaced=owner(),owner(),owner(),owner(),owner()
 runs[ended.player]=nil;dead.hum.Health=0;left.player.Parent=nil;replaced.player.Character=nil
 for _,r in {active,ended,dead,left,replaced} do table.insert(shots,{run=r}) end
 lastHit[active.hum]=1;lastHit[dead.hum]=2
 local old=Instance.new("Humanoid");lastHit[old]=3
 prune()
 check(#shots==1 and shots[1].run==active,"only the current living connected owner retains a fireball")
 check(lastHit[active.hum]==1 and lastHit[dead.hum]==nil and lastHit[old]==nil,"cooldown retains current humanoid, releases dead and unparented ones")
 prune();check(#shots==1,"repeated cleanup preserves a valid projectile")
 old:Destroy()
 for _,id in {1,99} do local p=Instance.new("Part");p.Anchored=true;p.Parent=folder;gems[id]=p end
 retire({1,2})
 check(gems[1]==nil and gems[99]~=nil and #gemPool==1,"retired IDs cannot clear a newer run's gem")
 check(gemPool[1].CFrame==HIDDEN,"retired visual is hidden and returned to pool")
 retire({1,2});check(#gemPool==1,"duplicate or already-picked retirement does not double-pool")
end,debug.traceback)
folder:Destroy()
return {ok=ok,error=err,checks=checks,count=#checks,mode="isolated exact cleanup spans"}
]=]
	return assert(loadstring(source,"GAME25Boundaries"))()
end
