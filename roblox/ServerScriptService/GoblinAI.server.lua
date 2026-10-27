-- GoblinAI (Script, ServerScriptService)
-- Server brain for every goblin: Idle -> Patrol -> Alert (detect) -> Chase -> Attack, plus Stun (any hit
-- reaction: flinch, knockback, guard break) and Dead. Movement uses PathfindingService. Hits are
-- server-authoritative: a box in front of the goblin is checked only between each attack's HitStart and HitEnd
-- (GoblinAnimData), one hit per target per swing. Client VFX follow the animations on their own
-- (GoblinVFXClient); confirmed hits are sent on ReplicatedStorage.Goblin.Impact for the spark burst.
-- Spawns one copy of workspace.Goblin per Config.AI.SpawnPoints into workspace.Goblins and respawns them. GoblinShowcase uses the same
-- template, so keep only one of the two scripts enabled.
-- Load test (Studio only): GoblinStressHUD asks for N extra goblins in workspace.StressZone (BuildStressZone.luau);
-- server numbers go out once a second as attributes on ReplicatedStorage.Goblin.Stress.
-- Damaging a goblin: Humanoid:TakeDamage(). Put an ObjectValue "creator" (Value = the Player) in its Humanoid
-- first, the classic weapon convention, and it turns on whoever hit it.
local Debris = game:GetService("Debris")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Goblin")
local Config = require(Shared:WaitForChild("GoblinConfig"))
local AnimData = require(Shared:WaitForChild("GoblinAnimData"))
local AI = Config.AI

local impact = Shared:FindFirstChild("Impact") or Instance.new("RemoteEvent")
impact.Name = "Impact"
impact.Parent = Shared

local template = Workspace:WaitForChild("Goblin")
template.Parent = ServerStorage -- runtime only; the place file keeps the original
-- Strip what the importer left on the rig (~170 of its 310 instances, all copied into every clone): editor poses,
-- original-size values, and the ragdoll ball sockets / no-collision pairs (Death is an animation, not a ragdoll).
for _, d in template:GetDescendants() do
	if d.Name == "InitialPoses" or d.Name == "AnimSaves" or d:IsA("BallSocketConstraint") or d:IsA("NoCollisionConstraint")
		or (d:IsA("ValueBase") and (d.Name == "OriginalPosition" or d.Name == "OriginalSize" or d.Name == "AvatarPartScaleType"))
	then
		d:Destroy()
	end
end
local folder = Instance.new("Folder") -- every live goblin; lets line-of-sight rays skip them with one filter entry
folder.Name = "Goblins"
folder.Parent = Workspace
local HIP_Y = template:GetPivot().Position.Y -- pivot height above the ground

local rng = Random.new()
local perf = { paths = 0, rays = 0 } -- per-second counters for the load test
local COMBO = { "Attack1", "Attack2", "Attack3" }

local function eventTime(anim: string, event: string): number?
	for _, e in AnimData[anim].events do
		if e[1] == event then
			return e[2]
		end
	end
	return nil
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Horizontal shove for `duration` seconds. Works on player characters too: the owning client simulates the constraint.
local function push(root: BasePart, velocity: Vector3, duration: number)
	local att = Instance.new("Attachment")
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0, lv.RelativeTo = att, Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis, lv.SecondaryTangentAxis = Vector3.xAxis, Vector3.zAxis
	lv.PlaneVelocity = Vector2.new(velocity.X, velocity.Z)
	lv.MaxForce = math.huge
	lv.Parent = att
	att.Parent = root
	Debris:AddItem(att, duration)
end

local function liveCharacters(): { Model }
	local list = {}
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if h and h.Health > 0 and c:FindFirstChild("HumanoidRootPart") then
			table.insert(list, c)
		end
	end
	return list
end

local function alive(c: Model?): BasePart?
	local h = c and c.Parent and c:FindFirstChildOfClass("Humanoid")
	return if h and h.Health > 0 then c:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local rayParams = RaycastParams.new() -- shared by every goblin: built once, not per ray
rayParams.FilterType, rayParams.RespectCanCollide = Enum.RaycastFilterType.Exclude, true -- grass tufts don't block
rayParams.FilterDescendantsInstances = { folder }

local spawnGoblin

function spawnGoblin(home: CFrame, respawn: boolean): Model
	local g = template:Clone()
	g:PivotTo(home)
	g.Parent = folder
	local root = g:FindFirstChild("HumanoidRootPart") :: BasePart
	local hum = g:FindFirstChildOfClass("Humanoid") :: Humanoid
	local animator = g:FindFirstChildWhichIsA("Animator", true) or Instance.new("Animator", hum)
	hum.MaxHealth, hum.Health = AI.MaxHealth, AI.MaxHealth
	hum.BreakJointsOnDeath = false -- the Death clip plays instead of falling apart
	for _, st in { "Climbing", "Swimming", "Seated", "FallingDown", "Ragdoll", "GettingUp", "Flying", "PlatformStanding" } do
		hum:SetStateEnabled(Enum.HumanoidStateType[st], false) -- fewer states for the humanoid to test every step
	end
	root:SetNetworkOwner(nil) -- otherwise the nearest player gets physics ownership and the brain stutters

	local tracks: { [string]: AnimationTrack } = {}
	for name, id in Config.Animations do
		local a = Instance.new("Animation")
		a.AnimationId = id
		local t = animator:LoadAnimation(a)
		t.Priority, t.Looped = Enum.AnimationPriority[AnimData[name].priority], AnimData[name].looped
		tracks[name] = t
	end

	local state = "Idle"
	local target: Model? = nil
	local lastSeen = 0
	local cooldown = { HeavyAttack = 0, LungeAttack = 0 }
	local combo = 0
	local recent = {} -- {time, damage} of recent hits, for the guard break
	local action: AnimationTrack? = nil -- current one-shot (attack, alert, reaction)
	local loco: AnimationTrack? = nil

	local function playAction(name: string): AnimationTrack
		if action and action.IsPlaying then
			action:Stop(0.1)
		end
		action = tracks[name]
		action:Play(0.1)
		return action
	end

	local function face(pos: Vector3, alpha: number)
		local look = flat(pos - root.Position)
		if look.Magnitude > 0.1 then
			root.CFrame = root.CFrame:Lerp(CFrame.lookAt(root.Position, root.Position + look), alpha)
		end
	end

	-- Path following: moveTo() plans (re-planning at most once a second for a moving goal), followPath() steps it.
	local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
	local waypoints, wi, pathGoal, pathTime = {}, 0, nil :: Vector3?, 0
	local function moveTo(goal: Vector3, speed: number)
		hum.WalkSpeed = speed
		if pathGoal and (goal - pathGoal).Magnitude < 3 and os.clock() - pathTime < 1 then
			return
		end
		pathGoal, pathTime = goal, os.clock()
		perf.paths += 1
		local ok = pcall(path.ComputeAsync, path, root.Position, goal)
		if ok and path.Status == Enum.PathStatus.Success then
			waypoints, wi = path:GetWaypoints(), 2 -- 1 is where we stand
		else
			waypoints, wi = { { Position = goal, Action = Enum.PathWaypointAction.Walk } }, 1 -- straight line
		end
	end
	local function followPath(): boolean -- true once the path is done
		local wp = waypoints[wi]
		if wp and flat(wp.Position - root.Position).Magnitude < 2 then
			wi += 1
			wp = waypoints[wi]
		end
		if not wp then
			return true
		end
		if wp.Action == Enum.PathWaypointAction.Jump then
			hum.Jump = true
		end
		hum:MoveTo(wp.Position)
		return false
	end
	local function stop()
		waypoints, wi, pathGoal = {}, 0, nil
		hum:MoveTo(root.Position)
	end

	local function canSee(c: Model): boolean
		local eye = root.Position + Vector3.new(0, 2, 0)
		perf.rays += 1
		local hit = Workspace:Raycast(eye, c.HumanoidRootPart.Position - eye, rayParams)
		return hit == nil or hit.Instance:IsDescendantOf(c)
	end
	local function findTarget(): Model?
		local best, bestD = nil, AI.DetectRange
		for _, c in liveCharacters() do
			local d = (c.HumanoidRootPart.Position - root.Position).Magnitude
			if d < bestD and canSee(c) then
				best, bestD = c, d
			end
		end
		return best
	end

	local function updateLoco()
		local speed = flat(root.AssemblyLinearVelocity).Magnitude
		local want
		if state == "Dead" or state == "Stun" then
			want = nil
		elseif hum:GetState() == Enum.HumanoidStateType.Freefall then
			want = tracks.Fall
		elseif speed > 1 then
			want = if speed > AI.WalkSpeed + 2 then tracks.Run else tracks.Walk
		else
			want = if target then tracks.CombatIdle else tracks.Idle
		end
		if want ~= loco then
			if loco then
				loco:Stop(0.2)
			end
			loco = want
			if want then
				want:Play(0.2)
			end
		end
		if want == tracks.Walk or want == tracks.Run then -- keep the feet matched to the ground speed
			want:AdjustSpeed(speed / (if want == tracks.Run then AI.RunSpeed else AI.WalkSpeed))
		end
	end

	-- One check of the swing hitbox; `hit` remembers who this swing already damaged.
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	local function swing(name: string, hit: { [Model]: boolean })
		local spec = AI.Attacks[name]
		local chars = liveCharacters()
		local isChar = {}
		for _, c in chars do
			isChar[c] = true
		end
		overlap.FilterDescendantsInstances = chars
		local box = root.CFrame * CFrame.new(0, 0, -spec.Reach / 2)
		for _, part in Workspace:GetPartBoundsInBox(box, Vector3.new(spec.Width, 6, spec.Reach), overlap) do
			local c = part.Parent
			while c and not isChar[c] do
				c = c.Parent
			end
			if c and not hit[c] then
				hit[c] = true
				local croot = c.HumanoidRootPart
				c:FindFirstChildOfClass("Humanoid"):TakeDamage(spec.Damage)
				if spec.Knockback > 0 then
					local away = flat(croot.Position - root.Position)
					push(croot, (if away.Magnitude > 0.1 then away.Unit else root.CFrame.LookVector) * spec.Knockback, 0.2)
				end
				impact:FireAllClients(croot.Position:Lerp(root.Position, 0.3), spec.Heavy)
			end
		end
	end

	local function attack(name: string)
		state = "Attack"
		stop()
		hum.AutoRotate = false
		local track = playAction(name)
		local hitStart, hitEnd = eventTime(name, "HitStart"), eventTime(name, "HitEnd")
		local recover = eventTime(name, "Recover") or track.Length
		local lungeAt = eventTime(name, "LungeStart")
		local hit = {}
		while track.IsPlaying and state == "Attack" do
			local t = track.TimePosition
			local tr = alive(target)
			if tr and t < hitStart then -- keep tracking the target until the blade comes down
				face(tr.Position, 0.35)
			end
			if lungeAt and t >= lungeAt then
				lungeAt = nil
				push(root, root.CFrame.LookVector * AI.LungeSpeed, AI.LungeTime)
			end
			if t >= hitStart and t <= hitEnd then
				swing(name, hit)
			end
			if t >= recover then
				track:Stop(0.3)
				break
			end
			RunService.Heartbeat:Wait()
		end
		if state == "Attack" then
			hum.AutoRotate = true
			state = "Chase"
			task.wait(rng:NextNumber(AI.AttackGap[1], AI.AttackGap[2]))
		end
	end

	-- Reactions lock the goblin in state "Stun" until the clip recovers (or StunTime for a guard break).
	local reactId = 0
	local function react(name: string, from: Vector3?)
		reactId += 1
		local id = reactId
		state = "Stun"
		stop()
		hum.AutoRotate = false
		local track = playAction(name)
		if name == "Knockback" then
			local away = from and flat(root.Position - from)
			push(root, (if away and away.Magnitude > 0.1 then away.Unit else -root.CFrame.LookVector) * AI.KnockbackSpeed, 0.35)
		end
		task.delay(if name == "Stun" then AI.StunTime else eventTime(name, "Recover") or track.Length, function()
			if reactId == id and state == "Stun" then
				track:Stop(0.2)
				hum.AutoRotate = true
				state = if target then "Chase" else "Idle"
			end
		end)
	end

	local function hitAnim(from: Vector3?): string
		if from then
			local d = root.CFrame:PointToObjectSpace(from)
			if math.abs(d.X) > math.abs(d.Z) then
				return if d.X < 0 then "HitLeft" else "HitRight"
			end
		end
		return "HitFront"
	end

	local lastHealth = hum.Health
	hum.HealthChanged:Connect(function(hp)
		local dmg = lastHealth - hp
		lastHealth = hp
		if dmg <= 0 or hp <= 0 or state == "Dead" then
			return
		end
		local creator = hum:FindFirstChild("creator")
		local player = creator and creator:IsA("ObjectValue") and creator.Value
		local ch = player and player:IsA("Player") and player.Character
		local from = alive(ch)
		if from then -- turn on whoever hit us
			target, lastSeen = ch, os.clock()
		end
		local now, sum = os.clock(), 0
		table.insert(recent, { now, dmg })
		for i = #recent, 1, -1 do
			if now - recent[i][1] > AI.StunWindow then
				table.remove(recent, i)
			else
				sum += recent[i][2]
			end
		end
		if dmg >= AI.KnockbackDamage then
			react("Knockback", from and from.Position)
		elseif sum >= AI.StunDamage then
			table.clear(recent)
			react("Stun")
		elseif state ~= "Attack" and state ~= "Stun" then -- light hits don't interrupt a swing
			react(hitAnim(from and from.Position))
		end
	end)

	hum.StateChanged:Connect(function(_, new)
		if state == "Dead" then
			return
		elseif new == Enum.HumanoidStateType.Jumping then
			tracks.Jump:Play(0.05)
		elseif new == Enum.HumanoidStateType.Landed then
			tracks.Land:Play(0.05)
		end
	end)

	hum.Died:Connect(function()
		state = "Dead"
		stop()
		for _, t in animator:GetPlayingAnimationTracks() do
			t:Stop(0.1)
		end
		root.Anchored = true
		local death = tracks.Death
		death:Play(0.1)
		task.wait(death.Length - 0.05)
		death:AdjustSpeed(0) -- hold the last frame while the client dissolve runs
		task.wait(Config.VFX.DeathFadeTime + 0.5)
		g:Destroy()
		if respawn then
			task.wait(AI.RespawnTime)
			spawnGoblin(home, true)
		end
	end)

	local function playerNear(): boolean
		for _, c in liveCharacters() do
			if (c.HumanoidRootPart.Position - root.Position).Magnitude < AI.SleepRange then
				return true
			end
		end
		return false
	end

	task.spawn(function()
		local idleUntil = os.clock() + rng:NextNumber(AI.IdleTime[1], AI.IdleTime[2])
		local asleep = false
		while g.Parent and state ~= "Dead" do
			-- Sleep while nobody is near: an anchored root skips humanoid physics, and the brain ticks once a second.
			local sleep = (state == "Idle" or state == "Patrol") and not playerNear()
			if sleep ~= asleep then
				asleep = sleep
				root.Anchored = sleep
				if sleep then
					stop()
					state = "Idle"
				else
					root:SetNetworkOwner(nil) -- unanchoring hands ownership back to the nearest player
				end
			end
			updateLoco()
			if asleep then
				task.wait(1)
				continue
			end
			local now = os.clock()
			if state == "Idle" or state == "Patrol" then
				local seen = alive(target) and target or findTarget()
				if seen then
					target, lastSeen, state = seen, now, "Alert"
					stop()
					face(seen.HumanoidRootPart.Position, 1)
					playAction("Alert")
					task.wait(eventTime("Alert", "Recover"))
					if state == "Alert" then
						state = "Chase"
					end
				elseif state == "Idle" and now > idleUntil then
					local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(3, AI.PatrolRadius)
					state = "Patrol"
					moveTo(home.Position + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), AI.WalkSpeed)
				elseif state == "Patrol" and followPath() then
					state, idleUntil = "Idle", now + rng:NextNumber(AI.IdleTime[1], AI.IdleTime[2])
				end
			elseif state == "Chase" then
				local tr = alive(target)
				if tr and canSee(target) then
					lastSeen = now
				end
				if not tr or now - lastSeen > AI.LoseTime or (tr.Position - root.Position).Magnitude > AI.LoseRange then
					target, state = nil, "Patrol" -- walk home, then idle
					moveTo(home.Position, AI.WalkSpeed)
				else
					local d = flat(tr.Position - root.Position).Magnitude
					if d <= AI.AttackRange then
						if now > cooldown.HeavyAttack and rng:NextNumber() < AI.HeavyChance then
							cooldown.HeavyAttack = now + AI.HeavyCooldown
							attack("HeavyAttack")
						else
							combo = combo % #COMBO + 1
							attack(COMBO[combo])
						end
					elseif d >= AI.LungeRange[1] and d <= AI.LungeRange[2] and now > cooldown.LungeAttack and lastSeen == now then
						cooldown.LungeAttack = now + AI.LungeCooldown
						face(tr.Position, 1)
						attack("LungeAttack")
					elseif d < 12 and lastSeen == now then -- close and in sight: run straight at them
						hum.WalkSpeed = AI.RunSpeed
						stop()
						hum:MoveTo(tr.Position)
					else
						moveTo(tr.Position, AI.RunSpeed)
						followPath()
					end
				end
			end
			task.wait(AI.ThinkInterval)
		end
	end)
	return g
end

for _, p in AI.SpawnPoints do
	local pos = p + Vector3.new(0, HIP_Y, 0)
	spawnGoblin(CFrame.lookAt(pos, pos + Vector3.zAxis), true) -- face the gate
end

if RunService:IsStudio() then -- never in a live server: a client asking for 500 goblins would be a free DoS
	local Stats = game:GetService("Stats")
	local stress = Shared:FindFirstChild("Stress") or Instance.new("RemoteEvent")
	stress.Name = "Stress"
	stress.Parent = Shared
	local crowd = {}
	stress.OnServerEvent:Connect(function(_, n)
		local zone = Workspace:FindFirstChild("StressZone")
		if typeof(n) ~= "number" or not zone then
			return
		end
		n = math.clamp(math.floor(n), 0, 500)
		for i = #crowd, 1, -1 do -- dead ones are gone already
			if not crowd[i].Parent then
				table.remove(crowd, i)
			end
		end
		while #crowd > n do
			table.remove(crowd):Destroy()
		end
		local c, half = zone:GetAttribute("Center"), zone:GetAttribute("Size") / 2 - 6
		while #crowd < n do
			local pos = c + Vector3.new(rng:NextNumber(-half, half), HIP_Y, rng:NextNumber(-half, half - 12))
			table.insert(crowd, spawnGoblin(CFrame.lookAt(pos, pos + Vector3.zAxis), false))
			if #crowd % 10 == 0 then
				task.wait() -- spread the clone + 21 LoadAnimation calls over frames
			end
		end
		stress:SetAttribute("Count", #crowd)
	end)
	local frames = 0
	RunService.Heartbeat:Connect(function()
		frames += 1
	end)
	while true do
		task.wait(1)
		stress:SetAttribute("ServerFPS", frames)
		stress:SetAttribute("HeartbeatMs", Stats.HeartbeatTimeMs)
		stress:SetAttribute("PhysicsMs", Stats.PhysicsStepTimeMs)
		stress:SetAttribute("MemoryMb", Stats:GetTotalMemoryUsageMb())
		stress:SetAttribute("PathsPerSec", perf.paths)
		stress:SetAttribute("RaysPerSec", perf.rays)
		frames, perf.paths, perf.rays = 0, 0, 0
	end
end
