-- Exact production dash + pause lifecycle, real Workspace collision and Humanoids.
-- Fake clock/player/remotes only; does not claim client/network acceptance. No Source writes.
return function(configSource,serverSource)
	local function span(a,b)
		local first=assert(serverSource:find(a,1,true))
		return serverSource:sub(first,assert(serverSource:find(b,first+#a,true))-1)
	end
	local source="local Config=(function()\n"..configSource.."\nend)()\n"..[=[
local realWorld=workspace
local f=Instance.new("Folder");f.Name="GAME44Exact";f.Parent=realWorld
local base=Vector3.new(10000,1000,10000)
local floor=Instance.new("Part");floor.Size=Vector3.new(120,1,120);floor.Position=base-Vector3.new(0,.5,0);floor.Anchored=true;floor.Parent=f
local clock,area=100,"Test"
local Workspace=setmetatable({GetServerTimeNow=function()return clock end,GetAttribute=function()return area end,
 Raycast=function(_,...)return realWorld:Raycast(...)end,Blockcast=function(_,...)return realWorld:Blockcast(...)end,
 GetPartBoundsInBox=function(_,...)return realWorld:GetPartBoundsInBox(...)end,FindFirstChild=function()return nil end},{__index=realWorld})
local Players={list={}};function Players:GetPlayers()return self.list end
local runs={};local packets={}
local event={OnServerEvent={Connect=function()end},FireAllClients=function(_,...)table.insert(packets,{...})end}
local function remote()return event end
local RunService={Heartbeat={Connect=function()end}}
local function arena()return base,100 end
]=]..span("-- GAME-44 Dash server BEGIN","-- GAME-44 Dash server END")
	..span("local function pauseRun(","local function offer(")..[=[
local checks={};local function check(v,label)assert(v,label);table.insert(checks,label)end
local function make(x)
 local c=Instance.new("Model");c.Parent=f
 local root=Instance.new("Part");root.Name="HumanoidRootPart";root.Size=Vector3.new(2,2,1);root.Position=base+Vector3.new(x or 0,3,0);root.Parent=c
 local h=Instance.new("Humanoid");h.RigType=Enum.HumanoidRigType.R6;h.HipHeight=0;h.Parent=c
 local p={Parent=Players,Character=c,attrs={}};function p:SetAttribute(k,v)self.attrs[k]=v end
 local r={player=p,hum=h,start=clock};runs[p]=r;table.insert(Players.list,p);return p,r,root
end
local function advance(t)
 local n=math.ceil(t/.01);for _=1,n do clock+=t/n;Dash.step(t/n)end
end
local function reset(p,r,root,x)
 Dash.cancel(r);clock+=5;r.cards=nil;r.pausedAt=nil;r.hum.Health=100;p.Parent=Players;p.Character=r.hum.Parent;runs[p]=r
 root.Anchored=false;root.Position=base+Vector3.new(x or 0,3,0);root.AssemblyLinearVelocity=Vector3.zero
end
local ok,err=xpcall(function()
 local p,r,root=make()
 check(not Dash.request(p,"bad"),"invalid payload rejected")
 clock+=.2;check(not Dash.request(p,Vector3.new(0/0,0,0)),"NaN rejected")
 clock+=.2;check(not Dash.request(p,Vector3.new(math.huge,0,0)),"infinite direction rejected")
 clock+=.2;check(not Dash.request(p,Vector3.zero),"zero direction rejected")
 reset(p,r,root);check(Dash.request(p,Vector3.xAxis),"grounded active run starts")
 local shield=r.dash.shield;check(root.Anchored and not r.hum.AutoRotate and p.attrs.RunDashing,"movement lease and replicated state acquired")
 r.hum:TakeDamage(10);check(r.hum.Health==100,"engine shield prevents damage")
 check(not Dash.request(p,Vector3.xAxis),"repeat request throttled")
 advance(.19);check(shield.Parent==nil and r.dash~=nil,"shield expires before dash finishes")
 r.hum:TakeDamage(10);check(r.hum.Health==90,"damage resumes after shield window")
 advance(.04);check(not r.dash and not root.Anchored and r.hum.AutoRotate and not p.attrs.RunDashing,"normal finish releases root and state")
 check(math.abs(root.Position.X-base.X-16)<.025,"distance exactly16stud on clear level ground")
 check(not Dash.request(p,Vector3.xAxis),"server cooldown prevents early repeat")
 reset(p,r,root);local wall=Instance.new("Part");wall.Size=Vector3.new(.1,8,20);wall.Position=base+Vector3.new(6,4,0);wall.Anchored=true;wall.Parent=f
 check(Dash.request(p,Vector3.xAxis),"dash toward distant thin wall starts")
 advance(.3);check(root.Position.X<base.X+4.8 and not r.dash,"body sweep stops before thin wall")
 reset(p,r,root,6);check(not Dash.request(p,Vector3.xAxis),"initial wall overlap rejected")
 wall:Destroy()
 reset(p,r,root,54);check(Dash.request(p,Vector3.xAxis),"near ledge starts")
 advance(.3);check(root.Position.X<base.X+60 and not r.dash,"ledge guard stops before unsupported centre")
 reset(p,r,root);root.Position+=Vector3.new(0,8,0);check(not Dash.request(p,Vector3.xAxis),"air dash rejected")
 reset(p,r,root);root.Anchored=true;check(not Dash.request(p,Vector3.xAxis),"foreign anchored root rejected")
 reset(p,r,root);r.hum.Sit=true;check(not Dash.request(p,Vector3.xAxis),"seated dash rejected");r.hum.Sit=false
 reset(p,r,root);r.cards={};check(not Dash.request(p,Vector3.xAxis),"card chooser cannot dash")
 reset(p,r,root);check(Dash.request(p,Vector3.xAxis),"pause transition starts")
 local old=r.dash.shield;pauseRun(r,clock)
 check(not r.dash and old.Parent==nil and root.Anchored and r.pauseAnchored==false,"card pause cancels dash before acquiring root")
 resumeRun(r,clock+.1);check(not root.Anchored and not r.pauseShield,"resume restores unanchored root, no shield leak")
 reset(p,r,root);Dash.request(p,Vector3.xAxis);area="Other";advance(.01)
 check(not r.dash and not root.Anchored,"arena change cancels immediately");area="Test"
 reset(p,r,root);Dash.request(p,Vector3.xAxis);p.Character=Instance.new("Model");p.Character.Parent=f;advance(.01)
 check(not r.dash and not root.Anchored,"character replacement cancels old lease")
 reset(p,r,root);Dash.request(p,Vector3.xAxis);p.Parent=nil;advance(.01)
 check(not r.dash and not root.Anchored,"disconnect invalidates active dash")
 reset(p,r,root);Dash.request(p,Vector3.xAxis);r.hum.Health=0;advance(.01)
 check(not r.dash and not root.Anchored,"death cancels and removes shield")
 reset(p,r,root);Dash.request(p,Vector3.xAxis);local foreign=Instance.new("ForceField");foreign.Name="OtherShield";foreign.Parent=p.Character
 Dash.cancel(r);Dash.cancel(r);check(foreign.Parent==p.Character,"idempotent cleanup preserves unrelated shield");foreign:Destroy()
 for _=1,50 do reset(p,r,root);assert(Dash.request(p,Vector3.xAxis));advance(.24)end
 local shields=0;for _,v in f:GetDescendants() do if v:IsA("ForceField")then shields+=1 end end
 check(shields==0 and not r.dash,"50 repeated dashes leave zero shields/state")
 check(#packets>0 and packets[1][1]=="start" and packets[2][1]=="stop","bounded start/stop effect protocol")
end,debug.traceback)
for _,r in runs do Dash.cancel(r)end
f:Destroy()
return {ok=ok,error=if ok then nil else err,checks=checks,count=#checks}
]=]
	return assert(loadstring(source,"GAME44Exact"))()
end
