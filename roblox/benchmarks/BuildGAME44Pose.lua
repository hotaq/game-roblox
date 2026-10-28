-- Art review only: hold exact VFX at130ms; Trail lifetime extended to20s for capture.
-- Execute returned code on a disposable review Client. EndTest cleans everything.
return function(configSource,clientSource)
 local first=assert(clientSource:find("-- GAME-44 Dash VFX BEGIN",1,true))
 local last=assert(clientSource:find('\tlocal event=Shared:WaitForChild("RunDash")',first,true))
 return [========[local Config=(function()
]========]..configSource..[========[
end)()
local Workspace=workspace
local frameClock=0;local os={clock=function()return frameClock end}
]========]..clientSource:sub(first,last-1)..[========[
local old=_G.GAME44Frozen
if old then if old.avatar then old.avatar:Destroy()end;if old.e then old.e.folder:Destroy()end end
local source=game.Players.LocalPlayer.Character;local arch=source.Archivable;source.Archivable=true
local dummy=source:Clone();source.Archivable=arch;dummy.Name="GAME44FrozenPose"
for _,p in dummy:GetDescendants()do
if p:IsA("LuaSourceContainer")then p:Destroy()
elseif p:IsA("BasePart")then p.Anchored=true;p.CanCollide=false;p.LocalTransparencyModifier=0 end end
dummy.Parent=workspace
local cf=CFrame.lookAt(Vector3.new(991,163,0),Vector3.new(1007,163,0))
dummy:PivotTo(cf)
local actor={Character=dummy}
begin(actor,444,Vector3.xAxis,workspace:GetServerTimeNow())
local e=active[1];assert(e)
for _,t in e.trails do t.Lifetime=20 end
update();task.wait(.08)
frameClock=.065;dummy:PivotTo(cf+Vector3.new(5,0,0));update();task.wait(.08)
frameClock=.13;dummy:PivotTo(cf+Vector3.new(10,0,0));update();task.wait(.08)
dummy:PivotTo(cf+Vector3.new(14,0,0));task.wait(.08)
_G.GAME44Frozen={avatar=dummy,e=e}
return {parts=#e.bits,ghosts=e.ghosts,trails=#e.trails,mode="held130ms pose; trail lifetime extended for capture only"}
end]========]
end

