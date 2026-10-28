-- Exact production dash: the server's gates and window (GoblinHorde "GAME-44 Dash server" block, fake clock / players /
-- remotes, real Workspace collision and Humanoids) and the client mover that moves the root (GoblinRunUI "GAME-44 Dash
-- mover" block, on a real part). Does not claim client/network acceptance. No Source writes. Command bar (Edit):
--   loadstring(<this file>)()(GoblinConfig.Source, GoblinHorde.Source, GoblinRunUI.Source) -> {ok, error, checks}
return function(configSource,serverSource,uiSource)
	local function span(source,a,b)
		local first=assert(source:find(a,1,true))
		return source:sub(first,assert(source:find(b,first+#a,true))-1)
	end
	local source="local Config=(function()\n"..configSource.."\nend)()\n"..[=[
local realWorld=workspace
local f=Instance.new("Folder");f.Name="GAME44Exact";f.Parent=realWorld
local base=Vector3.new(10000,1000,10000)
local floor=Instance.new("Part");floor.Size=Vector3.new(120,1,120);floor.Position=base-Vector3.new(0,.5,0);floor.Anchored=true;floor.Parent=f
local clock,area=100,"Test"
local Workspace=setmetatable({GetServerTimeNow=function()return clock end,GetAttribute=function()return area end,
 Raycast=function(_,...)return realWorld:Raycast(...)end,Blockcast=function(_,...)return realWorld:Blockcast(...)end,
 GetPartBoundsInBox=function(_,...)return realWorld:GetPartBoundsInBox(...)end,
 GetPartsInPart=function(_,...)return realWorld:GetPartsInPart(...)end,FindFirstChild=function()return nil end},{__index=realWorld})
local Players={list={}};function Players:GetPlayers()return self.list end
local runs={};local packets={}
local event={OnServerEvent={Connect=function()end},FireAllClients=function(_,...)table.insert(packets,{...})end}
local function remote()return event end
local RunService={Heartbeat={Connect=function()end}}
local arenaHalf=100
local function arena()return base,arenaHalf end
]=]..span(serverSource,"-- GAME-44 Dash server BEGIN","-- GAME-44 Dash server END")
	..span(serverSource,"local function pauseRun(","local function offer(")
	.."\ndo\nlocal Workspace=realWorld\n"..span(uiSource,"-- GAME-44 Dash mover BEGIN","-- GAME-44 Dash mover END").."\n_G.GAME44Mover=DashMover\nend\n"..[=[
local DashMover=_G.GAME44Mover;_G.GAME44Mover=nil
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
local function last(kind)for k=#packets,1,-1 do if packets[k][1]==kind then return packets[k] end end end
-- What the dasher's client does with a start packet: run the real mover until it stops, 60 frames a second.
local function fly(root,h)
 local s=last("start");local m=DashMover.start(root,h,s[4],s[6],s[7],{root.Parent})
 local frames=0;repeat frames+=1 until not DashMover.step(m,1/60) or frames>60
 local during=h.AutoRotate;DashMover.stop(m);return during
end
local ok,err=xpcall(function()
 local p,r,root=make()
 -- server: gates and the dash window
 check(not Dash.request(p,"bad"),"invalid payload rejected")
 clock+=.2;check(not Dash.request(p,Vector3.new(0/0,0,0)),"NaN rejected")
 clock+=.2;check(not Dash.request(p,Vector3.new(math.huge,0,0)),"infinite direction rejected")
 clock+=.2;check(not Dash.request(p,Vector3.zero),"zero direction rejected")
 reset(p,r,root);check(Dash.request(p,Vector3.xAxis),"grounded active run starts")
 local s=last("start");local shield=r.dash.shield
 check(p.attrs.RunDashing and not root.Anchored,"state acquired; the root stays with its client (not anchored)")
 check(typeof(s[7])=="table" and s[7].air==false and s[7].half==arenaHalf and typeof(s[7].size)=="Vector3","start carries the path rules")
 r.hum:TakeDamage(10);check(r.hum.Health==100,"engine shield prevents damage")
 check(not Dash.request(p,Vector3.xAxis),"repeat request throttled")
 advance(.19);check(shield.Parent==nil and r.dash~=nil,"shield expires before dash finishes")
 r.hum:TakeDamage(10);check(r.hum.Health==90,"damage resumes after shield window")
 advance(.04);check(not r.dash and not p.attrs.RunDashing and last("stop")[4]==false,"window ends after Duration; stop is not early")
 check(not Dash.request(p,Vector3.xAxis),"server cooldown prevents early repeat")
 reset(p,r,root,6);local wall=Instance.new("Part");wall.Size=Vector3.new(.1,8,20);wall.Position=base+Vector3.new(6,4,0);wall.Anchored=true;wall.Parent=f
 check(not Dash.request(p,Vector3.xAxis),"initial wall overlap rejected")
 reset(p,r,root,4.4);check(not Dash.request(p,Vector3.xAxis),"wall right ahead rejected")
 wall:Destroy()
 reset(p,r,root,99.5);check(not Dash.request(p,Vector3.xAxis),"start outside the arena bounds rejected")
 reset(p,r,root);root.Position+=Vector3.new(0,8,0)
 check(Dash.request(p,Vector3.xAxis) and last("start")[7].air==true,"air dash starts")
 advance(.24);clock+=5;check(not Dash.request(p,Vector3.xAxis),"one air dash per jump")
 root.Position=base+Vector3.new(0,3,0);advance(.02);clock+=5;root.Position+=Vector3.new(0,8,0)
 check(Dash.request(p,-Vector3.xAxis),"landing refreshes the air dash");advance(.24)
 reset(p,r,root);root.Anchored=true;check(not Dash.request(p,Vector3.xAxis),"foreign anchored root rejected")
 reset(p,r,root);r.hum.Sit=true;check(not Dash.request(p,Vector3.xAxis),"seated dash rejected");r.hum.Sit=false
 reset(p,r,root);r.cards={};check(not Dash.request(p,Vector3.xAxis),"card chooser cannot dash")
 reset(p,r,root);check(Dash.request(p,Vector3.xAxis),"pause transition starts")
 local old=r.dash.shield;pauseRun(r,clock)
 check(not r.dash and old.Parent==nil and last("stop")[4]==true and root.Anchored,"card pause ends the dash early, then anchors")
 resumeRun(r,clock+.1);check(not root.Anchored and not r.pauseShield,"resume restores unanchored root, no shield leak")
 reset(p,r,root);Dash.request(p,Vector3.xAxis);area="Other";advance(.01)
 check(not r.dash and last("stop")[4]==true,"arena change cancels early");area="Test"
 reset(p,r,root);Dash.request(p,Vector3.xAxis);p.Character=Instance.new("Model");p.Character.Parent=f;advance(.01)
 check(not r.dash,"character replacement cancels")
 reset(p,r,root);Dash.request(p,Vector3.xAxis);p.Parent=nil;advance(.01)
 check(not r.dash,"disconnect invalidates active dash")
 reset(p,r,root);Dash.request(p,Vector3.xAxis);r.hum.Health=0;advance(.01)
 check(not r.dash,"death cancels and removes shield")
 reset(p,r,root);Dash.request(p,Vector3.xAxis);local foreign=Instance.new("ForceField");foreign.Name="OtherShield";foreign.Parent=p.Character
 Dash.cancel(r);Dash.cancel(r);check(foreign.Parent==p.Character,"idempotent cleanup preserves unrelated shield");foreign:Destroy()
 reset(p,r,root);check(Dash.request(p,Vector3.xAxis,Vector3.new(0,0,-1)) and last("start")[6]:Dot(Vector3.new(0,0,-1))>.999,"start carries the facing")
 reset(p,r,root);check(Dash.request(p,Vector3.xAxis,Vector3.new(0/0,0,0)) and last("start")[6]:Dot(Vector3.xAxis)>.999,"invalid facing falls back to dir")
 for _=1,50 do reset(p,r,root);assert(Dash.request(p,Vector3.xAxis));advance(.24)end
 local shields=0;for _,v in f:GetDescendants() do if v:IsA("ForceField")then shields+=1 end end
 check(shields==0 and not r.dash,"50 repeated dashes leave zero shields/state")
 -- client mover: what actually moves the root
 reset(p,r,root);Dash.request(p,Vector3.xAxis,Vector3.new(0,0,-1));local during=fly(root,r.hum)
 check(math.abs(root.Position.X-base.X-16)<.05 and math.abs(root.Position.Y-base.Y-3)<.01,"mover: 16 studs on clear level ground")
 check(root.CFrame.LookVector:Dot(Vector3.new(0,0,-1))>.999 and during==false and r.hum.AutoRotate,"mover: keeps facing, AutoRotate off while dashing")
 reset(p,r,root);wall=Instance.new("Part");wall.Size=Vector3.new(.1,8,20);wall.Position=base+Vector3.new(6,4,0);wall.Anchored=true;wall.Parent=f
 Dash.request(p,Vector3.xAxis);fly(root,r.hum);check(root.Position.X<base.X+4.8,"mover: body sweep stops before a thin wall");wall:Destroy()
 local kit=game.ServerStorage:FindFirstChild("Map1Kit");local template=kit and kit:FindFirstChild("Prop_TempleGate")
 if template then
  local gate=template:Clone();gate.Parent=f;gate:PivotTo(CFrame.new(base))
  reset(p,r,root);check(Dash.request(p,Vector3.zAxis),"real Map1 mesh gate hole permits dash despite bounding overlap")
  fly(root,r.hum);check(root.Position.Z>base.Z+15.9,"mover: crosses the temple gate's collision opening")
  gate:Destroy()
 end
 reset(p,r,root,54);Dash.request(p,Vector3.xAxis);fly(root,r.hum)
 check(root.Position.X<base.X+60,"mover: a ground dash stops at the ledge")
 reset(p,r,root,54);root.Position+=Vector3.new(0,8,0);r.airDash=nil;Dash.request(p,Vector3.xAxis);local y=root.Position.Y;fly(root,r.hum)
 check(root.Position.X>base.X+69.9 and math.abs(root.Position.Y-y)<.01,"mover: an air dash flies level over the ledge")
 reset(p,r,root,50);arenaHalf=55;r.airDash=nil;Dash.request(p,Vector3.xAxis);fly(root,r.hum)
 check(root.Position.X<base.X+53.5,"mover: the arena boundary stops the body");arenaHalf=100
end,debug.traceback)
for _,r in runs do Dash.cancel(r)end
f:Destroy()
return {ok=ok,error=if ok then nil else err,checks=checks,count=#checks}
]=]
	return assert(loadstring(source,"GAME44Exact"))()
end
