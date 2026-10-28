-- Build a disposable Client/MCP fixture from exact production lifecycle spans.
-- Launch a hidden StudioTestService session first; execute returned code in its client.
-- Does not assign any Script.Source. End the disposable session after screenshots.
return function(clientSource)
 local a=assert(clientSource:find("local function acquire()",1,true))
 local b=assert(clientSource:find("local function free(slot:",a,true))
 return [====[local Players=game:GetService("Players");local Shared=game.ReplicatedStorage.Goblin
local Config=require(Shared.GoblinConfig);local RunService=game:GetService("RunService")
local template=Shared.HordeModel:Clone();template:ScaleTo(Config.Horde.ModelScale)
local box,boxSize=template:GetBoundingBox()
local hipY=template:GetPivot().Position.Y-(box.Position.Y-boxSize.Y/2)
local HIDDEN=CFrame.new(0,-1000,0);local pool,live={},{}
local folder=Instance.new("Folder");folder.Name="GAME11VisualReview";folder.Parent=workspace
local function animation(n)local a=Instance.new("Animation");a.AnimationId=Config.Animations[n];return a end
local RUN,DEATH,SWING,FLINCH=animation("Run"),animation("Death"),animation("Attack1"),animation("HitFront")
]====]..clientSource:sub(a,b-1)..[====[
local report={cycles=0,peakCorpses=0,maxClearSeconds=0,mesh=template:FindFirstChildWhichIsA("MeshPart",true).MeshId,scale=template:GetScale(),errors={}}
_G.GAME11ReviewReport=report
local base=Vector3.new(1000,120,0)
local floor=Instance.new("Part");floor.Size=Vector3.new(50,1,30);floor.Anchored=true;floor.Color=Color3.fromRGB(93,128,75);floor.Position=base-Vector3.new(0,.5,0);floor.Parent=folder
local function position(e,x)e.root.CFrame=CFrame.new(base+Vector3.new(x,hipY,0));end
RunService:BindToRenderStep("GAME11ReviewCamera",Enum.RenderPriority.Last.Value+10,function()
 workspace.CurrentCamera.CameraType=Enum.CameraType.Scriptable
 workspace.CurrentCamera.CFrame=CFrame.lookAt(base+Vector3.new(0,10,-23),base+Vector3.new(0,2,0))
end)
for _,g in Players.LocalPlayer.PlayerGui:GetChildren() do if g:IsA("ScreenGui")then g.Enabled=false end end
local assets={};for _,a in {RUN,DEATH,SWING,FLINCH}do table.insert(assets,a)end
game:GetService("ContentProvider"):PreloadAsync(assets)
task.spawn(function()
 local ok,err=xpcall(function()
 for cycle=1,20 do
  local e=acquire();position(e,0);task.wait(.12)
  local start=os.clock();beginDeath(e,start)
  while #corpses>0 do report.peakCorpses=math.max(report.peakCorpses,#corpses);task.wait()end
  report.maxClearSeconds=math.max(report.maxClearSeconds,os.clock()-start)
  assert(e.root.CFrame==HIDDEN and not e.death.IsPlaying and e.fadeParts[1].LocalTransparencyModifier==0,"real model cleanup failed")
  report.cycles=cycle
 end
 report.done=true;report.pool=#pool
 -- Fixed real-animation poses for readable comparison; no runtime Script changed.
 local elapsed={0,.2,.44,.525,.59}
 for i,t in elapsed do
  local e=acquire();position(e,(i-3)*7);e.run:Stop(0);e.death:Play(0,1,0);e.death.TimePosition=t*2.5
  for _,p in e.fadeParts do p.LocalTransparencyModifier=math.clamp((t-.45)/.15,0,1)end
  local gui=Instance.new("BillboardGui");gui.Size=UDim2.fromOffset(130,40);gui.StudsOffset=Vector3.new(0,4,0);gui.AlwaysOnTop=true;gui.Parent=e.root
  local l=Instance.new("TextLabel");l.Size=UDim2.fromScale(1,1);l.BackgroundTransparency=1;l.TextColor3=Color3.new(1,1,1);l.TextStrokeTransparency=0;l.TextScaled=true;l.Text=string.format("%.3f s",t);l.Parent=gui
 end
 end,debug.traceback)
 if not ok then table.insert(report.errors,err)end
end)
return {started=true,scale=report.scale,mesh=report.mesh}]====]
end

