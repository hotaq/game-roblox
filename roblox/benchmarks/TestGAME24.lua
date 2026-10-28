-- Exact producer/consumer transport spans; run in Edit/MCP, no saved Source writes.
return function(serverSource,clientSource)
	local function span(source,first,last)
		local a=assert(source:find(first,1,true),first)
		local b=assert(source:find(last,a+#first,true),last)
		return source:sub(a,b-1)
	end
	local source=[=[
local H={ViewEnter=192,ViewLeave=224}; local NONE=-32768
local alive,px,pz,generation={},{},{},{}; local top,count=0,0
]=]..span(serverSource,"local function quantize(","local function sendNearby(")..[=[
local callbacks,live,pool,roots={},{},{},{}
local Players={GetPlayers=function() return {} end}
local Shared={WaitForChild=function(_,name) return {OnClientEvent={Connect=function(_,fn) callbacks[name]=fn end}} end}
local recycled,deaths,legacyGems=0,0,0
local function track() return {Stop=function() end,Play=function() deaths+=1 end} end
local function acquire() return {run=track(),swing=track(),death=track(),flinch=track()} end
local function recycle(_) recycled+=1 end
local function free(slot) if live[slot] then recycle(live[slot]);live[slot]=nil end end
]=]..span(clientSource,"local roots = {}", "-- Effects: small pools")..[=[
local AnimData={Death={length=2}}
local task={delay=function() end}
local function dropGem() legacyGems+=1 end
local function beginDeath(e) e.death:Play() end -- lifecycle is checked by TestGAME11Death
]=]..span(clientSource,'Shared:WaitForChild("HordeDied")','Shared:WaitForChild("HordeSwing")')..[=[
local checks={}
local function check(v,label) assert(v,label);table.insert(checks,label) end
local function world(n)
 table.clear(alive);table.clear(px);table.clear(pz);table.clear(generation)
 top,count=n,n
 for i=1,n do alive[i]=true;px[i]=0;pz[i]=0;generation[i]=1 end
end
local function deliver(previous,position)
 local selected,b,mask,ids=buildView(previous,position)
 callbacks.HordeSnap(b,mask,ids)
 return selected,b,mask,ids
end
world(1000)
local view,b,mask,ids=deliver({},Vector3.zero)
check(not mask and buffer.len(b)==4002,"cluster uses original compact dense coordinate size")
check(buffer.len(ids)==6000 and live[1000].incarnation==1,"initial identities accompany all new visible slots")
view,b,mask,ids=deliver(view,Vector3.zero)
check(not ids,"steady state sends no repeated incarnation list")
for i=501,1000 do px[i]=300 end
view,b,mask=deliver(view,Vector3.zero)
check(mask and buffer.len(b)+buffer.len(mask)==2127,"half-visible 1000-slot packet is 2127 vs 4002 bytes")
check(live[500]~=nil and live[501]==nil and live[1000]==nil,"masked absence frees every far model")
for _,i in {1,8,9,16,17,1000} do px[i]=0 end
for i=1,1000 do if i~=1 and i~=8 and i~=9 and i~=16 and i~=17 and i~=1000 then px[i]=300 end end
view=deliver(view,Vector3.zero)
local visible=0;for _ in live do visible+=1 end
check(visible==6 and live[8] and live[9] and live[1000],"bit boundaries and high sparse slots decode correctly")
world(100);px[100]=300
view,b,mask=deliver({},Vector3.zero)
check(not mask and buffer.len(b)==402 and live[100]==nil,"dense fallback retains absent-slot sentinel")
world(1);px[1]=193
view=deliver({},Vector3.zero);check(live[1]==nil,"outside enter radius is initially hidden")
px[1]=191;view=deliver(view,Vector3.zero);check(live[1]~=nil,"enter radius creates model")
px[1]=220;view=deliver(view,Vector3.zero);check(live[1]~=nil,"hysteresis keeps an existing neighbour")
px[1]=225;view=deliver(view,Vector3.zero);check(live[1]==nil,"leave radius retires model")
px[1]=0;view=deliver(view,Vector3.zero)
local old=live[1];generation[1]=2;px[1]=40
view=deliver(view,Vector3.zero)
check(live[1]~=old and live[1].x==40 and live[1].incarnation==2,"silent slot reuse resets model identity and position")
local death=buffer.create(6);buffer.writeu16(death,0,1);buffer.writeu32(death,2,1)
callbacks.HordeDied(death,true)
check(live[1]~=nil and deaths==0,"old incarnation death cannot kill replacement")
buffer.writeu32(death,2,2);callbacks.HordeDied(death,true)
check(live[1]==nil and deaths==1 and legacyGems==0,"versioned death animates once and leaves gems to their own stream")
callbacks.HordeDied(death,true);check(deaths==1,"duplicate death does not duplicate the corpse")
view=deliver({},Vector3.zero);generation[1]=3;px[1]=220
view=deliver(view,Vector3.zero);check(live[1]==nil,"new incarnation outside enter radius cannot inherit old hysteresis")
view,b,mask,ids=deliver(view,nil)
check(buffer.len(b)==2 and not mask and not ids and next(live)==nil,"missing character sends minimal empty snapshot")
return {ok=true,count=#checks,checks=checks,mode="exact transport spans, not live-network evidence"}
]=]
	return assert(loadstring(source,"GAME24TransportBoundaries"))()
end
