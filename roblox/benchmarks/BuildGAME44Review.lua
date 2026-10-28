-- Candidate-block review in disposable StudioTestService helpers, BEFORE integrated Rojo acceptance.
-- Launch RunGAME44Review from Edit. Execute server code once in its Server, client code in each Client.
-- Never assign Script.Source. All helpers stay hidden; EndTest from the helper server when finished.
-- The UI uses real RemoteEvents and players, with isolated run state on a temporary flat platform.
return function(configSource,serverSource,clientSource,uiSource)
 local function span(s,a,b)local i=assert(s:find(a,1,true));return s:sub(i,assert(s:find(b,i+#a,true))-1)end
 local function lf(s)return (s:gsub("\r\n","\n"))end
 local block=span(serverSource,"-- GAME-44 Dash server BEGIN","-- GAME-44 Dash server END")
 local vfx=lf(span(clientSource,"-- GAME-44 Dash VFX BEGIN","-- GAME-44 Dash VFX END"))
 vfx=vfx:gsub("\tRunService.Heartbeat:Connect%(update%)\nend","\tRunService.Heartbeat:Connect(update)\n_G.GAME44FX={active=active,begin=begin,update=update}\nend")
 local ui=lf(span(uiSource,"-- GAME-44 Dash UI BEGIN","-- GAME-44 Dash UI END"))
 ui=ui:gsub("\tupdateDash%(%)\nend","\tupdateDash()\n_G.GAME44UI={request=request,update=updateDash,holder=holder,gui=dashGui,label=label,hint=hint,action=action}\nend")
 return {
 server=[========[local Config=(function()
]========]..configSource..[========[
end)()
local Players=game:GetService("Players");local Workspace=workspace
local Shared=game.ReplicatedStorage.Goblin
local connections={}
local realRun=game:GetService("RunService")
local RunService={Heartbeat={Connect=function(_,f)local c=realRun.Heartbeat:Connect(f);table.insert(connections,c);return c end}}
local runs={}
local base=Vector3.new(1000,160,0)
local folder=Instance.new("Folder");folder.Name="GAME44ReviewScene";folder.Parent=workspace
local floor=Instance.new("Part");floor.Size=Vector3.new(90,1,50);floor.Anchored=true;floor.Position=base-Vector3.new(0,.5,0);floor.Color=Color3.fromRGB(85,115,80);floor.Material=Enum.Material.SmoothPlastic;floor.Parent=folder
local function arena()return base,44 end
local function remote(n)local e=Instance.new("RemoteEvent");e.Name=n;e.Parent=Shared;return e end
]========]..block..[========[
for i,p in Players:GetPlayers() do
assert(p.Character)
local h=p.Character:FindFirstChildOfClass("Humanoid")
for _,o in p.Character:GetChildren() do if o:IsA("ForceField") then o:Destroy() end end
local r=p.Character.HumanoidRootPart;r.Anchored=false;r.CFrame=CFrame.lookAt(base+Vector3.new(-9,3,(i-1)*8),base+Vector3.new(8,3,(i-1)*8))
runs[p]={player=p,hum=h,start=Workspace:GetServerTimeNow()}
p:SetAttribute("RunStart",Workspace:GetServerTimeNow());p:SetAttribute("RunLevel",1)
end
_G.GAME44Review={Dash=Dash,runs=runs,base=base,connections=connections,folder=folder}
return {players=#Players:GetPlayers(),ready=true}]========],
 client=[========[local Config=(function()
]========]..lf(configSource)..[========[
end)()
local Players=game:GetService("Players");local ReplicatedStorage=game:GetService("ReplicatedStorage");local RunService=game:GetService("RunService");local TweenService=game:GetService("TweenService");local Workspace=workspace
local Shared=ReplicatedStorage.Goblin;local player=Players.LocalPlayer
local W,P,R=Config.Weapons,Config.Passives,Config.Run
local levelUp,results={Visible=false},{Visible=false}
for _,g in player.PlayerGui:GetChildren()do if g:IsA("ScreenGui")then g.Enabled=false end end
]========]..lf(span(uiSource,"local FONT","-- art(parent")).."\n"..vfx.."\n"..ui.."\n"..[========[RunService:BindToRenderStep("GAME44ReviewCamera",Enum.RenderPriority.Last.Value+10,function()
workspace.CurrentCamera.CameraType=Enum.CameraType.Scriptable
workspace.CurrentCamera.CFrame=CFrame.lookAt(Vector3.new(1000,174,22),Vector3.new(1000,162,0))
end)
return {ready=true,screen=workspace.CurrentCamera.ViewportSize}]========]
 }
end

