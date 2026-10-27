-- Builds an MCP command for a disposable GAME29VisualOnly two-client helper.
-- Executes the exact objective span with a controlled run table; never writes Script.Source.
-- Real PlayerGui/replication, mocked reward delivery (ordinary cards covered by live acceptance).
return function(serverSource)
 local a=assert(serverSource:find("local objectiveEnabled=",1,true))
 local b=assert(serverSource:find("-- END GAME-29 objective prototype",a,true))
 return [=[
assert(game:GetService("StudioTestService"):GetTestArgs().name=="GAME29VisualOnly")
game.ServerScriptService.GoblinHorde.Enabled=false -- disposable helper only; isolate ordinary combat
local Workspace,Players,RunService=workspace,game.Players,game:GetService("RunService")
local Config={ObjectiveTrial=table.clone(require(game.ReplicatedStorage.Goblin.GoblinConfig).ObjectiveTrial)}
Config.ObjectiveTrial.Enabled=true
local Shared=Instance.new("Folder");Shared.Name="GAME29HUDProbe";Shared.Parent=game.ServerStorage
local runs={};local list=Players:GetPlayers();assert(#list==2)
local zone=Vector3.new(1000,4,94)
local function arena()return Vector3.new(1000,0,0),198,Vector3.new(1000,0,118)end
local function offer(run)run.cards=true end
for i,p in list do
 p:LoadCharacter();p.Character:WaitForChild("HumanoidRootPart");p.Character:WaitForChild("Humanoid")
 local root=p.Character.HumanoidRootPart;root.Anchored=true;root.CFrame=CFrame.new(zone+Vector3.new((i-1)*30,0,0))
 Instance.new("ForceField",p.Character).Visible=false
 runs[p]={hum=p.Character:FindFirstChildOfClass("Humanoid"),pending=0}
end
]=]..serverSource:sub(a,b-1)..[=[
objectiveTick(30,false)
local invoke=Instance.new("BindableFunction");invoke.Name="Action";invoke.Parent=Shared
invoke.OnInvoke=function(action)
 if action=="progress"then objectiveTick(3,false)
 elseif action=="remove-first"then runs[list[1]]=nil;objectiveTick(0,true)
 elseif action=="success"then list[2].Character.HumanoidRootPart.Position=zone;objectiveTick(8,false)
 elseif action=="reset"then objectiveReset();objectiveTick(30,false);objectiveReset()
 end
 local out={phase=objectiveState and objectiveState.phase,progress=objectiveState and objectiveState.progress,players={}}
 for _,p in list do
  local ui=p.PlayerGui:FindFirstChild("OptionalHoldTrialUI")
  out.players[p.Name]={hud=ui~=nil,text=ui and ui.TextLabel.Text,pending=runs[p]and runs[p].pending}
 end
 return out
end
return {players={list[1].Name,list[2].Name},phase=objectiveState.phase}
]=]
end
