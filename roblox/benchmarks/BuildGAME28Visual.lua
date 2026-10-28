-- Disposable GAME28Inspect helper only. Extracts the exact production factory and HUD; no Source assignment.
-- Launch ExecuteMultiplayerTestAsync(1,{name="GAME28Inspect"}) from Edit.
-- Execute returned code in its Server. Keep the Client's NORMAL camera; a 28stud zoom works for art review.
-- For a held windup: _G.GAME28Inspection.control.attack(player.Character), wait0.65s, pause HeavyAttack track.
-- Resume track for recovery/hit validation, then EndTest from this helper only. Never touch the main Edit camera.
return function(aiSource,serverSource)
 local prefix=aiSource:sub(1,assert(aiSource:find("-- Server-only control surface;",1,true))-1)
 prefix=prefix:gsub('Workspace:WaitForChild%("Goblin"%)','ServerStorage:WaitForChild("Goblin"):Clone()')
 prefix=prefix:gsub('folder.Name = "Goblins"','folder.Name = "GAME28VisualActors"')
 local a=assert(serverSource:find("\tfor player in roster do",assert(serverSource:find("local function eliteSpawn",1,true)),true))
 local b=assert(serverSource:find("\n\teliteState=state;",a,true))
 return prefix..[========[
Workspace:SetAttribute("Arena","GAME28Inspection")
local floor=Instance.new("Part");floor.Name="GAME28VisualFloor";floor.Anchored=true;floor.Size=Vector3.new(50,1,35);floor.Position=Vector3.new(1000,159.5,0);floor.Color=Color3.fromRGB(86,125,72);floor.Parent=workspace
local p=Players:GetPlayers()[1];local c=p.Character;local h=c:FindFirstChildOfClass("Humanoid");local r=c.HumanoidRootPart
r.Anchored=true;r.CFrame=CFrame.new(1000,164,-5);h.MaxHealth=10000;h.Health=10000
p:SetAttribute("RunStart",workspace:GetServerTimeNow());p:SetAttribute("RunPausedAt",nil)
local actor=spawnGoblin(CFrame.new(1000,164,0),false,{health=300,members={c},center=Vector3.new(1000,0,0),half=40,manual=true})
actor.HumanoidRootPart.Anchored=true
_G.GAME28Inspection={actor=actor,control=eliteActor,player=p}
local roster={[p]=true};local state={hud={}}
]========]..serverSource:sub(a,b-1).."\n"..[========[
_G.GAME28Inspection.hud=state.hud
return {root=actor.HumanoidRootPart.Position,head=actor.Head.Position,scale=actor:GetScale()}]========]
end

