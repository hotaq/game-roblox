-- Exact client lifecycle/receiver spans, deterministic clock. Run in Studio Edit.
-- Counters measure retained models, not FPS, GPU time or whole-process memory.
return function(clientSource, baselineSource)
	local function span(source, first, last)
		local a = assert(source:find(first, 1, true), first)
		local b = assert(source:find(last, a + #first, true), last)
		return source:sub(a, b - 1)
	end
	local function run(source, baseline)
		local lifecycle = span(source, "local function recycle(e)", "local function free(slot:")
		local deaths = span(source, 'Shared:WaitForChild("HordeDied")', 'Shared:WaitForChild("HordeSwing")')
		local code = [=[
local clock, created, plays, legacyGems = 0, 0, 0, 0
local callbacks, delayed, pool, live = {}, {}, {}, {}
local HIDDEN, NONE = CFrame.new(0,-1000,0), -32768
local os = {clock=function() return clock end}
local task = {delay=function(duration,fn,e) table.insert(delayed,{at=clock+duration,fn=fn,e=e}) end}
local RunService = {Heartbeat={Connect=function(_,fn) callbacks.tick=fn end}}
local Shared = {WaitForChild=function(_,name) return {OnClientEvent={Connect=function(_,fn) callbacks[name]=fn end}} end}
local Players = {GetPlayers=function() return {} end}
local function track()
 return {playing=false, Stop=function(self) self.playing=false end,
 Play=function(self) self.playing=true;plays+=1 end}
end
local function acquire()
 local e=table.remove(pool)
 if not e then
  created+=1
  e={root={CFrame=CFrame.new()},fadeParts={{LocalTransparencyModifier=0}},
   run=track(),swing=track(),flinch=track(),death=track()}
 end
 e.run:Play();return e
end
]=] .. lifecycle .. [=[
local function free(slot) if live[slot] then recycle(live[slot]);live[slot]=nil end end
local function dropGem() legacyGems+=1 end
]=] .. span(source, "local roots = {}", "-- Effects: small pools") ..
			(if baseline then "\nlocal deathLength=2\n" else "\n") .. deaths .. [=[
local checks={}
local function check(value,label) assert(value,label);table.insert(checks,label) end
local function tick(t)
 clock=t
 if callbacks.tick then callbacks.tick() end
 for i=#delayed,1,-1 do local d=delayed[i];if d.at<=clock then table.remove(delayed,i);d.fn(d.e) end end
end
local function snap(n,generation)
 local b,ids=buffer.create(2+n*4),buffer.create(n*6);buffer.writeu16(b,0,n)
 for i=1,n do buffer.writei16(b,2+(i-1)*4,i);buffer.writei16(b,4+(i-1)*4,0)
  buffer.writeu16(ids,(i-1)*6,i);buffer.writeu32(ids,(i-1)*6+2,generation) end
 callbacks.HordeSnap(b,nil,ids)
end
local function kill(n,generation)
 local b=buffer.create(n*6)
 for i=1,n do buffer.writeu16(b,(i-1)*6,i);buffer.writeu32(b,(i-1)*6+2,generation) end
 callbacks.HordeDied(b,true)
end
local function uniquePool()
 local seen={};for _,e in pool do assert(not seen[e],"double pooled model");seen[e]=true end
 for _,e in live do assert(not seen[e],"live model also in pool") end
end
snap(1,1);local old=live[1];old.flinch:Play();kill(1,1)
check(live[1]==nil and old.death.playing,"death detaches model from slot")
local played=plays;kill(1,1);check(plays==played,"duplicate death ignored")
snap(1,2);local replacement=live[1];kill(1,1)
check(live[1]==replacement,"stale incarnation cannot kill replacement")
check(legacyGems==0,"versioned deaths leave XP to authoritative gem stream")
]=] .. (if baseline then "" else [=[
check(not old.flinch.playing and not old.run.playing and not old.swing.playing,"all competing tracks stop")
tick(0.525);check(math.abs(old.fadeParts[1].LocalTransparencyModifier-0.5)<1e-6,"last 150ms fades halfway")
tick(0.6);check(old.root.CFrame==HIDDEN and #corpses==0,"corpse expires at 600ms")
check(old.fadeParts[1].LocalTransparencyModifier==0 and not old.death.playing,"recycle resets opacity and stops track")
check(live[1]==replacement and replacement.run.playing,"expiry never retires reused slot")
]=]) .. [=[
tick(3);snap(0,0);uniquePool()
local warmCreated=created
for cycle=1,20 do
 tick(10+cycle*3);snap(1000,cycle);kill(1000,cycle);uniquePool()
]=] .. (if baseline then "" else [=[
 check(#corpses==64,"burst capped at 64 corpses cycle "..cycle)
]=]) .. [=[
 tick(clock+3);uniquePool()
 check(#pool==created,"all burst models returned once cycle "..cycle)
 if cycle==1 then warmCreated=created else check(created==warmCreated,"capacity stable cycle "..cycle) end
end
-- Same 10-second churn, one kill and immediate slot replacement per fixed interval.
local measures={}
for _,rate in {20,60,120} do
 tick(clock+3);table.clear(pool);created=0;table.clear(live)
 local start=clock;local peak=0;local modelSeconds=0
 snap(1,1)
 for i=1,rate*10 do
  tick(start+i/rate);kill(1,i);snap(1,i+1)
  local retained=created-#pool-1
  peak=math.max(peak,retained);modelSeconds+=retained/rate
 end
 table.insert(measures,{killsPerSecond=rate,peakCorpses=peak,capacity=created,corpseSeconds=modelSeconds})
 tick(clock+3);snap(0,0);check(#pool==created,"churn ends with zero retained corpses at "..rate.."/s");uniquePool()
end
-- Legacy sender still produces exactly one gem per visible death.
snap(1,1);local b=buffer.create(4);buffer.writeu16(b,0,65535);buffer.writeu16(b,2,1)
callbacks.HordeDied(b);callbacks.HordeDied(b)
check(legacyGems==1,"legacy duplicate does not duplicate XP visual")
tick(clock+3);uniquePool()
return {ok=true,count=#checks,checks=checks,measures=measures}
]=]
		return assert(loadstring(code, if baseline then "GAME11Baseline" else "GAME11Candidate"))()
	end
	return {candidate=run(clientSource,false),baseline=if baselineSource then run(baselineSource,true) else nil,
		mode="exact receiver/lifecycle spans with controlled time and mock animation tracks; not live visual/FPS evidence"}
end
