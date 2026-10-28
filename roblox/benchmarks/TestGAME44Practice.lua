-- TestGAME44Practice.lua: the dash practice field (Workspace.DashZone from BuildDashZone.luau), production Dash block,
-- real field collision; fake clock, players and remotes. Command bar (Edit):
--   loadstring(<this file>)()(GoblinConfig.Source, GoblinHorde.Source) -> {ok, error, checks}
return function(configSource, serverSource)
	local first = assert(serverSource:find("-- GAME-44 Dash server BEGIN", 1, true))
	local block = serverSource:sub(first, assert(serverSource:find("-- GAME-44 Dash server END", first, true)) - 1)
	local source = "local Config=(function()\n" .. configSource .. "\nend)()\n" .. [=[
local realWorld=workspace
local field=assert(realWorld:FindFirstChild("DashZone"),"build DashZone first")
local center=field:GetAttribute("Center")
local clock=100
local Workspace=setmetatable({GetServerTimeNow=function()return clock end,GetAttribute=function()return "StressZone" end,
 Raycast=function(_,...)return realWorld:Raycast(...)end,Blockcast=function(_,...)return realWorld:Blockcast(...)end,
 GetPartBoundsInBox=function(_,...)return realWorld:GetPartBoundsInBox(...)end,
 GetPartsInPart=function(_,...)return realWorld:GetPartsInPart(...)end,
 FindFirstChild=function(_,n)return realWorld:FindFirstChild(n)end},{__index=realWorld})
local Players={list={}};function Players:GetPlayers()return self.list end
local runs={};local packets={}
local event={OnServerEvent={Connect=function()end},FireAllClients=function(_,...)table.insert(packets,{...})end}
local function remote()return event end
local RunService={Heartbeat={Connect=function()end}}
local function arena()return Vector3.new(400,0,0),58 end
]=] .. block .. [=[
local checks={};local function check(v,label)assert(v,label);table.insert(checks,label)end
local f=Instance.new("Folder");f.Name="GAME44Practice";f.Parent=realWorld
local c=Instance.new("Model");c.Parent=f
local root=Instance.new("Part");root.Name="HumanoidRootPart";root.Size=Vector3.new(2,2,1);root.Parent=c
local h=Instance.new("Humanoid");h.RigType=Enum.HumanoidRigType.R6;h.HipHeight=0;h.Parent=c
local p={Parent=Players,Character=c,attrs={}};function p:SetAttribute(k,v)self.attrs[k]=v end
function p:GetAttribute(k)return self.attrs[k]end
table.insert(Players.list,p)
local function advance(t)local n=math.ceil(t/.01);for _=1,n do clock+=t/n;Dash.step(t/n)end end
local ok,err=xpcall(function()
 root.Anchored=false;root.Position=center+Vector3.new(0,3.05,0)
 check(not Dash.request(p,Vector3.xAxis),"no dash before the field notices you")
 advance(.3);check(p.attrs.DashPractice==true,"standing in the field starts practice")
 local x0=root.Position.X
 for k=1,3 do
  clock+=.13 -- past the request throttle only: no cooldown between dashes
  check(Dash.request(p,if k%2==1 then Vector3.xAxis else -Vector3.xAxis,Vector3.new(0,0,-1)),"practice dash "..k.." starts at once")
  advance(.24);check(not root.Anchored and not p.attrs.RunDashing,"practice dash "..k.." releases the root")
 end
 check(math.abs(root.Position.X-(x0+16))<.05,"three dashes: +16, -16, +16")
 check(root.CFrame.LookVector:Dot(Vector3.new(0,0,-1))>.999,"sidesteps keep the facing")
 root.Position=center+Vector3.new(300,3.05,0);advance(.3)
 check(p.attrs.DashPractice==nil,"leaving the field ends practice")
 clock+=.13;check(not Dash.request(p,Vector3.xAxis),"no dash outside the field without a run")
end,debug.traceback)
f:Destroy()
return {ok=ok,error=if ok then nil else err,checks=checks,count=#checks}
]=]
	return assert(loadstring(source, "GAME44Practice"))()
end
