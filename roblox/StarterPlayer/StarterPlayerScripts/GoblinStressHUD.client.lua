-- GoblinStressHUD (LocalScript, StarterPlayer.StarterPlayerScripts) - Studio-only goblin load-test panel.
-- Buttons ask GoblinAI for more or fewer Humanoid goblins, or GoblinHorde for more or fewer horde goblins ("H"), in
-- workspace.StressZone, and move you between the zone and the camp. The panel shows client FPS next to the server
-- numbers both scripts publish (Goblin.Stress and Goblin.Horde attributes).
-- In Studio the client and server share one machine, so both sides' costs show up in both FPS numbers.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

if not RunService:IsStudio() then
	return
end
local stress = ReplicatedStorage:WaitForChild("Goblin"):WaitForChild("Stress")
local horde = ReplicatedStorage.Goblin:WaitForChild("Horde")
local player = Players.LocalPlayer

-- GAME-12 real-client acceptance participant, enabled only by the server's named test.
if ReplicatedStorage.Goblin:GetAttribute("GAME12AxeActive") then
	task.spawn(function()
		local bridge=ReplicatedStorage.Goblin:WaitForChild("GAME12AxeTest",30)
		if not bridge then return end
		local peak,nonCosmetic,errors=0,0,{}
		game:GetService("ScriptContext").Error:Connect(function(message,_,source)
			if source and string.find(source.Name,"Goblin",1,true) then table.insert(errors,message) end
		end)
		local function countAxes()
			local n=0; local folder=workspace:FindFirstChild("Horde")
			if folder then for _,m in folder:GetChildren() do if m.Name=="BoomerangAxe" then
				n+=1
				for _,p in m:GetDescendants() do if p:IsA("BasePart") and (p.CanCollide or p.CanTouch or p.CanQuery) then nonCosmetic+=1 end end
			end end end
			peak=math.max(peak,n); return n
		end
		RunService.RenderStepped:Connect(countAxes)
		bridge.OnClientInvoke=function(action)
			if action=="pick" then ReplicatedStorage.Goblin.RunPick:FireServer(1);return true end
			if action=="leave" then
				local service=game:GetService("StudioTestService")
				assert(service:CanLeaveTest(),"client cannot leave this test")
				task.delay(.1,function() service:LeaveTest() end)
				return true
			end
			local icons=0
			local ui=player.PlayerGui:FindFirstChild("GoblinRunUI")
			if ui then for _,d in ui:GetDescendants() do if d.Name=="AxeIcon" and d.Visible then
				local visible=true;local p=d.Parent
				while p and p~=ui do if p:IsA("GuiObject") and not p.Visible then visible=false end;p=p.Parent end
				if visible then icons+=1 end
			end end end
			return {axes=countAxes(),peakAxes=peak,nonCosmeticParts=nonCosmetic,visibleAxeIcons=icons,errors=errors}
		end
		-- GoblinRunUI parents its ScreenGui only after connecting all card handlers.
		-- A second Studio client can load this participant earlier than that UI.
		assert(player:WaitForChild("PlayerGui"):WaitForChild("GoblinRunUI",45),"axe acceptance UI readiness timeout")
		bridge:InvokeServer("ready")
	end)
end

-- GAME-23 measurement participant. The server creates this flag only for the named test.
if ReplicatedStorage.Goblin:GetAttribute("GAME23Active") then
	task.spawn(function()
		local Stats=game:GetService("Stats")
		local bridge=ReplicatedStorage.Goblin:WaitForChild("GAME23Benchmark",30)
		if not bridge then return end
		local center=Workspace:WaitForChild("StressZone"):GetAttribute("Center")
		local camera=Workspace.CurrentCamera
		camera.CameraType=Enum.CameraType.Scriptable
		camera.CFrame=CFrame.lookAt(center+Vector3.new(70,65,70),center)
		local sample
		local function summary(values)
			table.sort(values)
			if #values==0 then return {n=0} end
			return {n=#values,p50=values[math.ceil(#values*0.5)],p95=values[math.ceil(#values*0.95)],max=values[#values]}
		end
		local errors={}
		game:GetService("ScriptContext").Error:Connect(function(message,_,source)
			if source and string.find(source.Name,"Goblin",1,true) then table.insert(errors,{source=source.Name,message=message}) end
		end)
		RunService.RenderStepped:Connect(function(dt)
			if not sample then return end
			table.insert(sample.frame,dt*1000)
			table.insert(sample.cpu,Stats.RenderCPUFrameTime*1000)
			table.insert(sample.gpu,Stats.RenderGPUFrameTime*1000)
		end)
		ReplicatedStorage.Goblin.HordeSnap.OnClientEvent:Connect(function(b)
			if sample then sample.bytes+=buffer.len(b); sample.packets+=1 end
		end)
		local lastStats=0
		RunService.Heartbeat:Connect(function()
			if not sample or os.clock()-lastStats<1 then return end
			lastStats=os.clock()
			table.insert(sample.memory,Stats:GetTotalMemoryUsageMb())
			table.insert(sample.instances,Stats.InstanceCount)
			table.insert(sample.receive,Stats.DataReceiveKbps)
		end)
		bridge.OnClientInvoke=function(action)
			if action=="begin" then
				sample={frame={},cpu={},gpu={},memory={},instances={},receive={},bytes=0,packets=0,start=os.clock()}
				return true
			elseif action=="finish" then
				local s=assert(sample,"no active sample")
				sample=nil
				local elapsed=os.clock()-s.start
				local folder=workspace:FindFirstChild("Horde")
				local models,visible=0,0
				if folder then for _,m in folder:GetChildren() do if m:IsA("Model") then
					models+=1; local root=m:FindFirstChild("HumanoidRootPart")
					if root and root.Position.Y>-500 then visible+=1 end
				end end end
				return {seconds=elapsed,frameMs=summary(s.frame),renderCpuMs=summary(s.cpu),renderGpuMs=summary(s.gpu),
					memoryMb=summary(s.memory),instances=summary(s.instances),totalReceiveKbps=summary(s.receive),
					snapshotPayloadKiBps=s.bytes/elapsed/1024,packets=s.packets,models=models,visible=visible,errors=errors}
			end
			return false
		end
		bridge:InvokeServer("ready")
	end)
end

local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn = "GoblinStressHUD", false
local panel = Instance.new("Frame")
panel.Size, panel.Position = UDim2.fromOffset(230, 304), UDim2.new(0, 12, 0.5, -152)
panel.BackgroundColor3, panel.BackgroundTransparency = Color3.new(0, 0, 0), 0.35
panel.Parent = gui
local pad = Instance.new("UIPadding")
pad.PaddingTop, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 8)
pad.Parent = panel

local label = Instance.new("TextLabel")
label.Size, label.BackgroundTransparency = UDim2.new(1, 0, 0, 186), 1
label.Font, label.TextSize, label.TextColor3 = Enum.Font.Code, 14, Color3.new(1, 1, 1)
label.TextXAlignment, label.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
label.Parent = panel

local buttons = Instance.new("Frame")
buttons.Size, buttons.Position, buttons.BackgroundTransparency = UDim2.new(1, 0, 0, 96), UDim2.fromOffset(0, 192), 1
buttons.Parent = panel
local grid = Instance.new("UIGridLayout")
grid.CellSize, grid.CellPadding = UDim2.new(1 / 3, -4, 0, 28), UDim2.fromOffset(4, 4)
grid.Parent = buttons

local function count(): number
	return stress:GetAttribute("Count") or 0
end
local function goTo(part: BasePart?)
	local char = player.Character
	if part and char then
		char:PivotTo(part.CFrame + Vector3.new(0, 4, 0))
	end
end
local function button(text: string, onClick: () -> ())
	local b = Instance.new("TextButton")
	b.Text, b.Font, b.TextSize = text, Enum.Font.GothamBold, 14
	b.BackgroundColor3, b.TextColor3 = Color3.fromRGB(60, 60, 60), Color3.new(1, 1, 1)
	b.Parent = buttons
	b.Activated:Connect(onClick)
end
button("+10", function()
	stress:FireServer(count() + 10)
end)
button("+50", function()
	stress:FireServer(count() + 50)
end)
button("-10", function()
	stress:FireServer(math.max(0, count() - 10))
end)
button("Clear", function()
	stress:FireServer(0)
end)
button("H +100", function()
	horde:FireServer((horde:GetAttribute("Target") or 0) + 100)
end)
button("H -100", function()
	horde:FireServer(math.max(0, (horde:GetAttribute("Target") or 0) - 100))
end)
button("H Clear", function()
	horde:FireServer(0)
end)
button("Zone", function()
	local zone = Workspace:FindFirstChild("StressZone")
	goTo(zone and zone:FindFirstChild("TesterPad"))
end)
button("Camp", function()
	goTo(Workspace:FindFirstChildOfClass("SpawnLocation"))
end)
gui.Parent = player:WaitForChild("PlayerGui")

local frames, t0 = 0, os.clock()
RunService.RenderStepped:Connect(function()
	frames += 1
	local dt = os.clock() - t0
	if dt < 1 then
		return
	end
	local fps = math.round(frames / dt)
	frames, t0 = 0, os.clock()
	player:SetAttribute("ClientFPS", fps) -- for scripted benchmarks
	local a, h = stress:GetAttributes(), horde:GetAttributes()
	label.Text = ("Goblins     %d\nHorde       %d / %d\nHorde sim   %.2f ms  %d KB/s\nClient FPS  %d\nServer FPS  %d\nHeartbeat   %.1f ms\nPhysics     %.1f ms\nMemory      %d MB\nPaths/s     %d\nRays/s      %d"):format(
		a.Count or 0,
		h.Count or 0,
		h.Target or 0,
		h.SimMs or 0,
		h.KBps or 0,
		fps,
		a.ServerFPS or 0,
		a.HeartbeatMs or 0,
		a.PhysicsMs or 0,
		a.MemoryMb or 0,
		a.PathsPerSec or 0,
		a.RaysPerSec or 0
	)
end)
