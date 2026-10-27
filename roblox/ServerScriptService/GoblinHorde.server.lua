-- GoblinHorde (Script, ServerScriptService)
-- Megabonk-style horde: hundreds of goblins that are plain data on the server (position, health), not Humanoids.
-- Every step they run at the nearest player and push apart (spatial hash); one that reaches a player stops and swings
-- (clients play Attack1) and the hit lands after a wind-up, only if the player is still in reach. A weapon hit slows
-- a goblin; most also stun it briefly (cancelling a wind-up) and, with the Force passive, knock it back.
-- SendRate times a second all clients get one buffer of {x, z} per slot (4 bytes; the slot number is implicit, free
-- slots are a sentinel, and the client works out facing from movement) plus the slots that died; GoblinHordeClient
-- draws pooled client-only models from that (the single-mesh Goblin.HordeModel).
-- No physics, no pathfinding: the arena (workspace.StressZone, or Map1 via its pad) is flat at y = 0. Humanoid goblins
-- (GoblinAI) stay for elites.
-- Runs: entering the arena starts one (PlayPad / Map1Pad by the spawn teleport there). Weapons (Config.Weapons) fire on
-- their own and hit the same goblin arrays; each kill drops an XP gem; level-ups pause the horde while the player
-- picks 1 of 3 cards (GoblinRunUI); dying ends the run with a results screen. Player attributes carry the HUD state.
-- Studio test: GoblinStressHUD's H buttons override the horde size (Goblin.Horde remote).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Goblin")
local Config = require(Shared:WaitForChild("GoblinConfig"))
local H, R, W, P = Config.Horde, Config.Run, Config.Weapons, Config.Passives

-- Fallback client model for when Goblin.HordeModel is missing: GoblinAI's stripped template, with an
-- AnimationController instead of a Humanoid and no collisions.
local model = ServerStorage:WaitForChild("Goblin"):Clone()
model:FindFirstChildOfClass("Humanoid"):Destroy()
local controller = Instance.new("AnimationController")
Instance.new("Animator").Parent = controller
controller.Parent = model
CollectionService:RemoveTag(model, Config.Tag) -- the per-goblin GoblinVFX rig is too heavy for a horde
for _, d in model:GetDescendants() do
	if d:IsA("BasePart") then
		d.Anchored = d.Name == "HumanoidRootPart"
		d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = false, false, false, false
	end
end
model.Name = "HordeSource"
model.Parent = Shared

local function remote(name: string): RemoteEvent
	local r = Shared:FindFirstChild(name) or Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = Shared
	return r
end
local snap, died, gemTaken, hits, fx = remote("HordeSnap"), remote("HordeDied"), remote("HordeGems"), remote("HordeHits"), remote("HordeFx")
local swingsOut = remote("HordeSwing")
local levelUp, pickCard, rerollCards, runOver = remote("RunLevelUp"), remote("RunPick"), remote("RunReroll"), remote("RunOver")
local restart, toLobby = remote("RunRestart"), remote("RunLobby")
local gemState = remote("HordeGemState")

-- Goblins live in stable slots (parallel arrays): a slot keeps its number for life, so snapshots needn't carry ids.
-- Freed slots are reused first, which keeps `top` (the highest live slot, i.e. the snapshot length) near the count.
local alive, px, pz, hp = {}, {}, {}, {}
local generation = {} -- axe hit identity includes the incarnation of a reused horde slot
local swingAt, nextSwing = {}, {} -- wind-up start (nil = not swinging) and earliest next swing, per slot
local kvx, kvz, stunUntil, slowUntil = {}, {}, {}, {} -- knockback velocity (fades), stun and slow end times, per slot
local swings = {} -- slots that started a swing this step (sent at once, not with the 10 Hz snapshot)
local free, top, count, override = {}, 0, 0, nil :: number?
local dead, deadFirstGem = {}, 0 -- slots killed since the last send; each dropped gem number deadFirstGem + k - 1
local gems, nextGem = {}, 0 -- gem number -> {x, z}
local clearedGems = {} -- final-run drops to retire on clients after any queued death packet
local deathEvents, pickedPositions = {}, {} -- preserve identity/position even if a slot is reused before sending
local views, viewReadyAt = {}, {} -- Player -> {slots=slot/incarnation, gems=id/server gem record}
local networkMode, networkSample = "nearby", nil -- broadcast is available only to the named Studio comparison
local rng = Random.new()
local NONE = -32768 -- x of a free slot in a snapshot
local runs = {} -- Player -> run state
local axes, axeSerial, axesDirty = {}, 0, false
local function clearRunAxes(player)
	for k = #axes, 1, -1 do
		if axes[k].run.player == player then
			table.remove(axes, k)
			axesDirty = true
		end
	end
end

-- `run` = the run whose weapon killed it (counts the kill, drops a gem); nil = despawned quietly.
local function kill(i: number, run)
	alive[i], swingAt[i] = false, nil
	count -= 1
	table.insert(free, i)
	if run then
		run.kills += 1
		if #dead == 0 then
			deadFirstGem = nextGem
		end
		table.insert(dead, i)
		table.insert(deathEvents, {slot=i, incarnation=generation[i] or 0, x=px[i], z=pz[i]})
		gems[nextGem] = { x = px[i], z = pz[i] }
		nextGem = (nextGem + 1) % 65536
	end
	while top > 0 and not alive[top] do
		top -= 1
	end
end

-- The run arena: workspace.StressZone unless a pad switched the Workspace "Arena" attribute (e.g. to "Map1"). A zone
-- carries Center and Size attributes, and optionally Spawn (where pads drop you; defaults to Center).
local function arena(): (Vector3?, number, Vector3?)
	local zone = Workspace:FindFirstChild(Workspace:GetAttribute("Arena") or "StressZone")
	if not zone then
		return nil, 0, nil
	end
	local center = zone:GetAttribute("Center")
	return center, zone:GetAttribute("Size") / 2 - 2, zone:GetAttribute("Spawn") or center
end

-- Spatial hash of live goblins, rebuilt each step (positions move < 0.5 stud per step, so it stays good enough).
local grid = {}
local CELL = H.Spacing
local function key(cx: number, cz: number): number
	return cx * 100003 + cz
end
local function around(x: number, z: number, r: number, fn: (number) -> ())
	local r2 = r * r
	for cx = (x - r) // CELL, (x + r) // CELL do
		for cz = (z - r) // CELL, (z + r) // CELL do
			local c = grid[key(cx, cz)]
			if c then
				for _, i in c do
					if alive[i] and (px[i] - x) ^ 2 + (pz[i] - z) ^ 2 <= r2 then
						fn(i)
					end
				end
			end
		end
	end
end

---------------------------------------------------------------- runs, XP, cards

local function publish(run)
	local pl = run.player
	local w, p = {}, {}
	for _, id in run.wOrder do
		table.insert(w, id .. "=" .. run.weapons[id])
	end
	for _, id in run.pOrder do
		table.insert(p, id .. "=" .. run.passives[id])
	end
	pl:SetAttribute("RunStart", run.start)
	pl:SetAttribute("RunLevel", run.level)
	pl:SetAttribute("RunXP", run.xp)
	pl:SetAttribute("RunXPNext", run.next)
	pl:SetAttribute("RunKills", run.kills)
	pl:SetAttribute("RunGems", run.gems)
	pl:SetAttribute("RunLoadout", table.concat(w, ",") .. ";" .. table.concat(p, ","))
	pl:SetAttribute("RunArea", run.bonus.area) -- the client sizes the Fire Ring with it
end

local function rollRarity(): number
	local total = 0
	for _, r in R.Rarity do
		total += r.Weight
	end
	local roll = rng:NextNumber(0, total)
	for i, r in R.Rarity do
		roll -= r.Weight
		if roll <= 0 then
			return i
		end
	end
	return 1
end

-- Up to 3 different cards: upgrades for what the run has, new picks while slots are free; a heal once all is maxed.
local function makeCards(run)
	local pool = {}
	for _, id in W.Order do
		local lv = run.weapons[id]
		if lv and lv < #W[id].Levels then
			table.insert(pool, { kind = "weapon", id = id, level = lv + 1 })
		elseif not lv and #run.wOrder < R.WeaponSlots then
			table.insert(pool, { kind = "weapon", id = id, level = 1 })
		end
	end
	for _, id in P.Order do
		local lv = run.passives[id]
		if lv and lv < P.MaxLevel then
			table.insert(pool, { kind = "passive", id = id, level = lv + 1 })
		elseif not lv and #run.pOrder < R.PassiveSlots then
			table.insert(pool, { kind = "passive", id = id, level = 1 })
		end
	end
	local cards = {}
	while #cards < 3 and #pool > 0 do
		local c = table.remove(pool, rng:NextInteger(1, #pool))
		c.rarity = rollRarity()
		table.insert(cards, c)
	end
	if #cards == 0 then
		cards[1] = { kind = "heal", rarity = 1 }
	end
	return cards
end

local function offer(run)
	run.pausedAt = run.pausedAt or Workspace:GetServerTimeNow() -- the run clock stops while picking
	run.cards = makeCards(run)
	levelUp:FireClient(run.player, run.cards, run.rerolls, run.level)
end

local function gainXP(run, n: number)
	run.xp += n
	while run.xp >= run.next do
		run.xp -= run.next
		run.level += 1
		run.next = math.round(run.next * R.XPGrowth + 1)
		run.pending += 1
	end
	if run.pending > 0 and not run.cards then
		offer(run)
	end
	publish(run)
end

local function endRun(player: Player)
	clearRunAxes(player)
	local run = runs[player]
	if not run then
		return
	end
	runs[player] = nil
	run.rocks = nil
	local damage = {}
	for _, id in run.wOrder do
		table.insert(damage, { id = id, level = run.weapons[id], amount = math.round(run.damage[id] or 0) })
	end
	runOver:FireClient(player, {
		time = Workspace:GetServerTimeNow() - run.start,
		kills = run.kills,
		level = run.level,
		damage = damage,
	})
	for _, a in { "RunStart", "RunLevel", "RunXP", "RunXPNext", "RunKills", "RunGems", "RunLoadout", "RunArea" } do
		player:SetAttribute(a, nil)
	end
end

local function startRun(player: Player, hum: Humanoid)
	local run = {
		player = player,
		hum = hum,
		start = Workspace:GetServerTimeNow(),
		level = 1,
		xp = 0,
		next = R.XPFirst,
		kills = 0,
		gems = 0,
		weapons = { sword = 1 },
		wOrder = { "sword" },
		passives = {},
		pOrder = {},
		bonus = { might = 0, area = 0, haste = 0, magnet = 0, force = 0 },
		damage = {},
		cd = {},
		pending = 0,
		cards = nil,
		rerolls = R.Rerolls,
	}
	runs[player] = run
	publish(run)
	hum.Died:Once(function()
		endRun(player)
	end)
end

pickCard.OnServerEvent:Connect(function(player, index)
	local run = runs[player]
	local c = run and run.cards and typeof(index) == "number" and run.cards[index]
	if not c then
		return
	end
	if c.kind == "weapon" then
		if not run.weapons[c.id] then
			table.insert(run.wOrder, c.id)
		end
		run.weapons[c.id] = c.level
	elseif c.kind == "passive" then
		if not run.passives[c.id] then
			table.insert(run.pOrder, c.id)
		end
		run.passives[c.id] = c.level
		run.bonus[c.id] += P[c.id].Per * R.Rarity[c.rarity].Mult
	else
		run.hum.Health = math.min(run.hum.MaxHealth, run.hum.Health + R.Heal)
	end
	run.pending -= 1
	run.cards = nil
	if run.pending > 0 then
		offer(run)
	else
		run.start += Workspace:GetServerTimeNow() - run.pausedAt
		run.pausedAt = nil
	end
	publish(run)
end)

rerollCards.OnServerEvent:Connect(function(player)
	local run = runs[player]
	if run and run.cards and run.rerolls > 0 then
		run.rerolls -= 1
		offer(run)
	end
end)

restart.OnServerEvent:Connect(function(player)
	local center, _, spawn = arena()
	if runs[player] or not center then
		return
	end
	player:LoadCharacter()
	if player.Character then
		player.Character:PivotTo(CFrame.new(spawn + Vector3.new(0, 4, 0)))
	end
end)

toLobby.OnServerEvent:Connect(function(player)
	if not runs[player] then
		player:LoadCharacter()
	end
end)

Players.PlayerRemoving:Connect(function(player)
	clearRunAxes(player)
	if runs[player] then runs[player].rocks=nil end
	runs[player] = nil
	views[player], viewReadyAt[player] = nil, nil
end)

-- The client asks once after all listeners are connected. Rate-limit resync requests.
remote("HordeReady").OnServerEvent:Connect(function(player)
	local now = os.clock()
	if now - (viewReadyAt[player] or -math.huge) >= 2 then
		views[player], viewReadyAt[player] = nil, now
	end
end)

-- Glowing pads beside the spawn that send you into an arena. With no run going, a pad switches the arena to its zone;
-- during a run every pad sends you to the arena already in use, so players always share one horde.
-- A pad with warp instead just teleports you to the spot warp() returns (nothing happens if it returns nil).
local function makePad(name: string, position: Vector3, color: Color3, caption: string, zone: string?, warp: (() -> Vector3?)?)
	local pad = Instance.new("Part")
	pad.Name = name
	pad.Anchored, pad.CanCollide = true, false
	pad.Size, pad.Position = Vector3.new(6, 0.4, 6), position
	pad.Material, pad.Color = Enum.Material.Neon, color
	local label = Instance.new("BillboardGui")
	label.Size, label.StudsOffset, label.AlwaysOnTop = UDim2.fromOffset(160, 50), Vector3.new(0, 3, 0), true
	local text = Instance.new("TextLabel")
	text.Size, text.BackgroundTransparency, text.Text = UDim2.fromScale(1, 1), 1, caption
	text.FontFace, text.TextScaled = Font.fromEnum(Enum.Font.FredokaOne), true
	text.TextColor3, text.TextStrokeTransparency = Color3.new(1, 1, 1), 0
	text.Parent = label
	label.Parent = pad
	pad.Parent = Workspace
	local busy = {}
	pad.Touched:Connect(function(hit)
		local char = hit.Parent
		local player = char and Players:GetPlayerFromCharacter(char)
		if not player or busy[player] then
			return
		end
		local spot
		if warp then
			spot = warp()
		elseif Workspace:FindFirstChild(zone) then
			if next(runs) == nil then
				Workspace:SetAttribute("Arena", zone)
			end
			local center, _, spawn = arena()
			spot = center and spawn
		end
		if spot then
			busy[player] = true
			char:PivotTo(CFrame.new(spot + Vector3.new(0, 4, 0)))
			task.delay(1, function()
				busy[player] = nil
			end)
		end
	end)
end
makePad("PlayPad", Vector3.new(11, 1.2, 10), Color3.fromRGB(255, 210, 90), "PLAY", "StressZone")
makePad("Map1Pad", Vector3.new(11, 1.2, 20), Color3.fromRGB(110, 220, 120), "MAP 1", "Map1")
-- The sword FX showcase (Workspace.SwordFXZone, place content from roblox/BuildSwordFXZone.luau) and back
local fxView = Workspace:FindFirstChild("SwordFXZone") and Workspace.SwordFXZone:FindFirstChild("ViewPad")
if fxView then
	makePad("SwordFXPad", Vector3.new(11, 1.2, 30), Color3.fromRGB(255, 80, 60), "SWORD FX", nil, function()
		return fxView.Position
	end)
	makePad("SwordFXBackPad", fxView.Position + Vector3.new(10, 0.7, 0), Color3.fromRGB(255, 210, 90), "BACK", nil, function()
		local spawnPad = Workspace:FindFirstChild("SpawnLocation")
		return spawnPad and spawnPad.Position
	end)
end

---------------------------------------------------------------- weapons

local hitLog = {} -- Player -> {slot, damage, ...} for floating numbers, sent with the snapshot; +32768 = it stunned
local hitVersions = {} -- Player -> incarnation per hit pair
local shots = {} -- live fireballs

-- A weapon hit from (fromX, fromZ): damage and a slow; if `stuns`, also a short stun that cancels a wind-up, and with
-- the Force passive a push away from that point (knock = the weapon's share of it).
local function hit(i: number, dmg: number, run, weapon: string, fromX: number, fromZ: number, knock: number, stuns: boolean)
	local dx, dz = px[i] - fromX, pz[i] - fromZ
	local d = math.sqrt(dx * dx + dz * dz)
	if d > 0.01 and run.bonus.force > 0 and knock > 0 then
		local v = H.Knockback * knock * run.bonus.force
		kvx[i], kvz[i] = dx / d * v, dz / d * v
	end
	local now = Workspace:GetServerTimeNow()
	slowUntil[i] = now + H.SlowTime
	if stuns then
		stunUntil[i], swingAt[i] = now + H.Stun, nil
	end
	local before = hp[i]
	hp[i] -= dmg
	run.damage[weapon] = (run.damage[weapon] or 0) + math.min(dmg, before)
	local log = hitLog[run.player]
	if not log then
		log = {}
		hitLog[run.player] = log
	end
	if #log < 80 then -- 40 numbers a send is plenty to read
		table.insert(log, i)
		table.insert(log, math.min(math.round(dmg), 32767) + (if stuns then 32768 else 0))
		local versions = hitVersions[run.player] or {}
		hitVersions[run.player] = versions
		table.insert(versions, generation[i] or 0)
	end
	if hp[i] <= 0 then
		kill(i, run)
	end
end

local function nearest(x: number, z: number, n: number): { number }
	local best, dist = {}, {}
	for i = 1, top do
		if alive[i] then
			local d = (px[i] - x) ^ 2 + (pz[i] - z) ^ 2
			if #best < n or d < dist[#best] then
				local k = #best + 1
				while k > 1 and dist[k - 1] > d do
					k -= 1
				end
				table.insert(best, k, i)
				table.insert(dist, k, d)
				best[n + 1], dist[n + 1] = nil, nil
			end
		end
	end
	return best
end

-- GAME-12 axe: authoritative swept hits, once per incarnation per leg. No client damage requests.
local function axeSweep(a, x0, z0, x1, z1)
	local dx, dz = x1 - x0, z1 - z0
	local length2 = dx * dx + dz * dz
	around((x0 + x1) / 2, (z0 + z1) / 2, math.sqrt(length2) / 2 + a.radius, function(i)
		local incarnation = generation[i] or 0
		if a.hit[i] == incarnation then return end
		local t = if length2 > 0 then math.clamp(((px[i] - x0) * dx + (pz[i] - z0) * dz) / length2, 0, 1) else 0
		local ex, ez = px[i] - (x0 + t * dx), pz[i] - (z0 + t * dz)
		if ex * ex + ez * ez <= a.radius * a.radius then
			a.hit[i] = incarnation
			hit(i, a.damage, a.run, "axe", x0, z0, a.knock, true)
		end
	end)
end

local function pruneAxes()
	local center, half = arena()
	for k = #axes, 1, -1 do
		local a = axes[k]
		local root = a.root
		local valid = runs[a.run.player] == a.run and a.run.hum.Health > 0
			and a.run.player.Character == root.Parent and root:IsDescendantOf(Workspace)
		local pos = root.Position
		if not valid or not center or math.abs(pos.X - center.X) > half + 2 or math.abs(pos.Z - center.Z) > half + 2
			or (pos - a.lastOwner).Magnitude > 48 then
			table.remove(axes, k) -- cancel on death, leave, respawn, arena exit or teleport; never reward
			axesDirty = true
		else
			a.lastOwner = pos
		end
	end
end

local function moveAxes(dt: number)
	for k = #axes, 1, -1 do
		local a = axes[k]
		a.age += dt
		local remaining, done = dt, a.age >= 4.5
		while remaining > 0.00001 and not done do
			local x0, z0 = a.x, a.z
			if a.leg == 1 then
				local travel = math.min(a.left, a.speed * remaining)
				a.x, a.z = x0 + a.dx * travel, z0 + a.dz * travel
				a.left -= travel
				remaining -= travel / a.speed
				axeSweep(a, x0, z0, a.x, a.z)
				if a.left < 0.00001 then
					a.leg = 2
					table.clear(a.hit) -- the same living target can be hit once more on return
				end
			else
				local pos = a.root.Position -- home to the owner's CURRENT position
				local dx, dz = pos.X - x0, pos.Z - z0
				local distance = math.sqrt(dx * dx + dz * dz)
				local travel = math.min(distance, a.returnSpeed * remaining)
				if distance > 0.00001 then a.x, a.z = x0 + dx / distance * travel, z0 + dz / distance * travel end
				axeSweep(a, x0, z0, a.x, a.z)
				done = distance <= travel + 0.00001
				remaining = 0
			end
		end
		if done then table.remove(axes, k); axesDirty = true end
	end
end
-- END GAME-12 axe simulation

-- GAME-12 Orbit Rocks: server contact sweeps, one shared cooldown per target incarnation.
local rockSerial, rocksWereVisible = 0, false
local function validRockOwner(run, root)
	local center,half=arena()
	local pos=root.Position
	return runs[run.player]==run and run.player.Parent==Players and run.hum.Health>0
		and run.player.Character==root.Parent and root:IsDescendantOf(Workspace) and center
		and math.abs(pos.X-center.X)<=half+2 and math.abs(pos.Z-center.Z)<=half+2
end
local function pruneRocks()
	for _,run in runs do
		local state=run.rocks
		if state and (not run.weapons.rocks or not validRockOwner(run,state.root)
			or (state.root.Position-state.lastOwner).Magnitude>48) then run.rocks=nil end
	end
end
local function rockSweep(run,state,x0,z0,x1,z1,s)
	local dx,dz=x1-x0,z1-z0
	local length2=dx*dx+dz*dz
	around((x0+x1)/2,(z0+z1)/2,math.sqrt(length2)/2+state.radius,function(slot)
		local incarnation=generation[slot] or 0
		local previous=state.hit[slot]
		if previous and previous.incarnation==incarnation and previous.untilAge>state.age then return end
		local t=if length2>0 then math.clamp(((px[slot]-x0)*dx+(pz[slot]-z0)*dz)/length2,0,1) else 0
		local ex,ez=px[slot]-x0-dx*t,pz[slot]-z0-dz*t
		if alive[slot] and ex*ex+ez*ez<=state.radius*state.radius then
			state.hit[slot]={incarnation=incarnation,untilAge=state.age+s.Interval*(1-math.min(run.bonus.haste,0.6))}
			hit(slot,s.Damage*(1+run.bonus.might),run,"rocks",x0,z0,s.Knock,false)
		end
	end)
end
local function moveRocks(run,root,dt)
	local level=run.weapons.rocks
	if not level or not validRockOwner(run,root) then run.rocks=nil;return end
	local s=Config.weaponStats("rocks",level)
	local pos=root.Position
	local state=run.rocks
	local radius,orbit=s.Radius*(1+run.bonus.area),s.Orbit*(1+run.bonus.area)
	if not state or state.root~=root or state.level~=level or state.radius~=radius
		or (pos-state.lastOwner).Magnitude>48 then
		rockSerial+=1
		state={serial=rockSerial,root=root,lastOwner=pos,x=pos.X,z=pos.Z,y=pos.Y-0.7,
			phase=0,age=0,hit={},radius=radius,orbit=orbit,count=s.Count,level=level}
		run.rocks=state
	end
	-- Normal simulation supplies 1/30s. Bound exceptional callers and subdivide curved motion.
	dt=math.clamp(dt,0,0.25)
	local delta=s.Speed*dt
	local steps=math.max(1,math.ceil(delta/0.2))
	for sub=1,steps do
		local t0,t1=(sub-1)/steps,sub/steps
		state.age+=dt/steps
		for k=1,s.Count do
			local angle=state.phase+(k-1)*math.pi*2/s.Count
			local x0=state.x+(pos.X-state.x)*t0+math.cos(angle+delta*t0)*orbit
			local z0=state.z+(pos.Z-state.z)*t0+math.sin(angle+delta*t0)*orbit
			local x1=state.x+(pos.X-state.x)*t1+math.cos(angle+delta*t1)*orbit
			local z1=state.z+(pos.Z-state.z)*t1+math.sin(angle+delta*t1)*orbit
			rockSweep(run,state,x0,z0,x1,z1,s)
		end
	end
	state.phase=(state.phase+delta)%(math.pi*2)
	state.x,state.z,state.y,state.lastOwner=pos.X,pos.Z,pos.Y-0.7,pos
	for slot,record in state.hit do
		if not alive[slot] or generation[slot]~=record.incarnation or record.untilAge<=state.age then state.hit[slot]=nil end
	end
end
local function sendRocks()
	local packet={}
	for _,run in runs do
		local s=run.rocks
		if s then table.insert(packet,{run.player,s.serial,s.x,s.z,s.y,s.phase,s.count,s.radius,s.orbit,s.level}) end
	end
	if #packet>0 or rocksWereVisible then fx:FireAllClients("rocks",packet) end
	rocksWereVisible=#packet>0
end
-- END GAME-12 rocks simulation

local function fireWeapons(run, root: BasePart, dt: number)
	if run.weapons.rocks then moveRocks(run,root,dt) end
	local pos = root.Position
	local haste = 1 - math.min(run.bonus.haste, 0.6)
	local might = 1 + run.bonus.might
	local area = 1 + run.bonus.area
	for id, lv in run.weapons do
		if id=="rocks" then continue end -- continuous contacts use their own per-target cooldown
		run.cd[id] = (run.cd[id] or 0) - dt
		if run.cd[id] > 0 then
			continue
		end
		local s = Config.weaponStats(id, lv)
		if id == "sword" then
			run.cd[id] = s.Cooldown * haste
			-- Aim at the nearest goblin (Megabonk-style), so turning around is never the player's job.
			local look = root.CFrame.LookVector
			local lx, lz = look.X, look.Z
			local aim = nearest(pos.X, pos.Z, 1)[1]
			if aim then
				local dx, dz = px[aim] - pos.X, pz[aim] - pos.Z
				local d = math.sqrt(dx * dx + dz * dz)
				if d > 0.01 then
					lx, lz = dx / d, dz / d
				end
			end
			local cosHalf = math.cos(math.rad(s.Arc / 2))
			around(pos.X, pos.Z, s.Range * area, function(i)
				local dx, dz = px[i] - pos.X, pz[i] - pos.Z
				local d = math.max(math.sqrt(dx * dx + dz * dz), 0.01)
				local dot = (dx * lx + dz * lz) / d
				if dot >= cosHalf or (s.Back and -dot >= cosHalf) then
					hit(i, s.Damage * might, run, id, pos.X, pos.Z, s.Knock, s.Stun ~= false)
				end
			end)
			fx:FireAllClients("slash", run.player, s.Range * area, s.Arc, s.Back == true, lx, lz)
		elseif id == "ring" then
			run.cd[id] = s.Interval * haste
			around(pos.X, pos.Z, s.Radius * area, function(i)
				hit(i, s.Damage * might, run, id, pos.X, pos.Z, s.Knock, s.Stun ~= false)
			end)
		elseif id == "axe" then
			local center, half = arena()
			if runs[run.player] ~= run or run.hum.Health <= 0 or run.player.Character ~= root.Parent
				or not center or math.abs(pos.X - center.X) > half + 2 or math.abs(pos.Z - center.Z) > half + 2 then
				run.cd[id] = 0.1; continue
			end
			local owned = 0
			for _, a in axes do if a.run == run then owned += 1 end end
			if owned >= 3 then run.cd[id] = 0.1; continue end
			local aim = nearest(pos.X, pos.Z, 1)[1]
			if not aim then run.cd[id] = 0.1; continue end
			local dx, dz = px[aim] - pos.X, pz[aim] - pos.Z
			local distance = math.sqrt(dx * dx + dz * dz)
			if distance < 0.001 then dx, dz, distance = 0, -1, 1 end
			run.cd[id] = s.Cooldown * haste
			axeSerial += 1
			table.insert(axes, { id = axeSerial, run = run, root = root, lastOwner = pos,
				x = pos.X, z = pos.Z, dx = dx / distance, dz = dz / distance, y = pos.Y - 0.4,
				left = s.Range * area, radius = s.Radius * area, speed = s.Speed, returnSpeed = s.ReturnSpeed,
				damage = s.Damage * might, knock = s.Knock, level = lv, leg = 1, age = 0, hit = {} })
			axesDirty = true
		elseif id == "fire" then
			local aims = nearest(pos.X, pos.Z, s.Count)
			if #aims == 0 then
				run.cd[id] = 0.25 -- nothing to shoot yet: look again soon
				continue
			end
			run.cd[id] = s.Cooldown * haste
			local range = s.Range * area
			for k = 1, s.Count do
				local i = aims[(k - 1) % #aims + 1]
				local a = math.atan2(pz[i] - pos.Z, px[i] - pos.X) + (k - 1 >= #aims and (k % 2 * 2 - 1) * 0.25 or 0)
				local dx, dz = math.cos(a), math.sin(a)
				table.insert(shots, { x = pos.X, z = pos.Z, dx = dx, dz = dz, speed = s.Speed, t = range / s.Speed, pierce = s.Pierce, dmg = s.Damage * might, knock = s.Knock, stuns = s.Stun ~= false, run = run, hit = {} })
				fx:FireAllClients("fire", pos.X, pos.Z, dx, dz, s.Speed, range)
			end
		end
	end
end

local function moveShots(dt: number)
	for k = #shots, 1, -1 do
		local s = shots[k]
		s.x += s.dx * s.speed * dt
		s.z += s.dz * s.speed * dt
		s.t -= dt
		local done = s.t <= 0
		if not done then
			around(s.x, s.z, 1.6, function(i)
				if not done and not s.hit[i] then
					s.hit[i] = true
					hit(i, s.dmg, s.run, "fire", s.x - s.dx, s.z - s.dz, s.knock, s.stuns) -- pushed along the shot
					s.pierce -= 1
					done = s.pierce < 0
				end
			end)
		end
		if done then
			table.remove(shots, k)
		end
	end
end

---------------------------------------------------------------- simulation

-- Players to chase: {root, hum, run}, refreshed every step.
local targets = {}
local lastHit: { [Humanoid]: number } = {}
local taken = {} -- Player -> gem numbers picked up since the last send

local function step(dt: number)
	pruneAxes() -- also runs while the existing global card pause is active
	pruneRocks()
	-- Lifetime cleanup must run even when another player is choosing a card.
	for k = #shots, 1, -1 do
		local run = shots[k].run
		if runs[run.player] ~= run or run.player.Parent ~= Players or run.hum.Health <= 0
			or run.player.Character ~= run.hum.Parent then
			table.remove(shots, k)
		end
	end
	for hum in lastHit do
		if hum.Health <= 0 or not hum:IsDescendantOf(Workspace) then lastHit[hum] = nil end
	end
	local center, half = arena()
	local now = Workspace:GetServerTimeNow()
	table.clear(targets)
	for _, pl in Players:GetPlayers() do
		local c = pl.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if h and r and h.Health > 0 then
			local p = r.Position
			local inside = center and math.abs(p.X - center.X) <= half + 2 and math.abs(p.Z - center.Z) <= half + 2
			if inside and not runs[pl] then
				startRun(pl, h)
			end
			table.insert(targets, { root = r, hum = h, run = runs[pl], inside = inside })
		end
	end

	-- Survivors-style pause: nothing moves or hurts while someone is picking a card.
	for _, run in runs do
		if run.cards then
			return
		end
	end

	table.clear(grid)
	for i = 1, top do
		if not alive[i] then
			continue
		end
		local k = key(px[i] // CELL, pz[i] // CELL)
		local c = grid[k]
		if c then
			table.insert(c, i)
		else
			grid[k] = { i }
		end
	end

	local sp2 = H.Spacing * H.Spacing
	local contact2 = H.ContactRange * H.ContactRange
	local reach2 = H.AttackReach * H.AttackReach
	for i = 1, top do
		if not alive[i] then
			continue
		end
		local x, z = px[i], pz[i]
		local best, bt = math.huge, nil
		for _, t in targets do
			local p = t.root.Position
			local d = (p.X - x) ^ 2 + (p.Z - z) ^ 2
			if d < best then
				best, bt = d, t
			end
		end
		-- Swing: start one when close, land it after the wind-up if the player didn't step away. Swinging = standing.
		local swinging = swingAt[i] ~= nil
		local stunned = now < stunUntil[i]
		if swinging and now - swingAt[i] >= H.AttackWindup then
			swingAt[i], nextSwing[i], swinging = nil, now + H.AttackCooldown, false
			if bt and best < reach2 and now - (lastHit[bt.hum] or 0) > H.IFrames then
				lastHit[bt.hum] = now
				bt.hum:TakeDamage(H.ContactDamage)
			end
		elseif not swinging and not stunned and bt and best < contact2 and now >= (nextSwing[i] or 0) then
			swingAt[i], swinging = now, true
			table.insert(swings, i)
		end
		local vx, vz = 0, 0
		if bt and best > 0.25 and not swinging and not stunned then
			local d = math.sqrt(best)
			local p = bt.root.Position
			local speed = if now < slowUntil[i] then H.Speed * H.Slow else H.Speed
			vx, vz = (p.X - x) / d * speed, (p.Z - z) / d * speed
		end
		local cx, cz = x // CELL, z // CELL
		for ox = -1, 1 do
			for oz = -1, 1 do
				local c = grid[key(cx + ox, cz + oz)]
				if c then
					for _, j in c do
						local ex, ez = x - px[j], z - pz[j]
						local e2 = ex * ex + ez * ez
						if j ~= i and e2 < sp2 and e2 > 1e-6 then -- grid only holds live slots
							local e = math.sqrt(e2)
							local push = (H.Spacing - e) / e * H.Push
							vx += ex * push
							vz += ez * push
						end
					end
				end
			end
		end
		local fade = math.exp(-H.KnockbackDecay * dt)
		vx, vz = vx + kvx[i], vz + kvz[i]
		kvx[i], kvz[i] = kvx[i] * fade, kvz[i] * fade
		x, z = x + vx * dt, z + vz * dt
		if center then
			x, z = math.clamp(x, center.X - half, center.X + half), math.clamp(z, center.Z - half, center.Z + half)
		end
		px[i], pz[i] = x, z
	end
	if #swings > 0 then -- right away: the swing animation must show before its hit lands
		local b = buffer.create(#swings * 2)
		for k, i in swings do
			buffer.writeu16(b, (k - 1) * 2, i)
		end
		if networkMode == "broadcast" then
			swingsOut:FireAllClients(b)
			if networkSample then
				for _, player in Players:GetPlayers() do networkSample.bytes[player]=(networkSample.bytes[player] or 0)+buffer.len(b) end
			end
		else
			for player, view in views do
				local selected = {}
				for _, slot in swings do
					if view.slots[slot] == (generation[slot] or 0) then table.insert(selected,slot) end
				end
				if #selected > 0 then
					local ids, versions = buffer.create(#selected*2), buffer.create(#selected*4)
					for k, slot in selected do
						buffer.writeu16(ids,(k-1)*2,slot); buffer.writeu32(versions,(k-1)*4,generation[slot] or 0)
					end
					swingsOut:FireClient(player,ids,versions)
					if networkSample then networkSample.bytes[player]=(networkSample.bytes[player] or 0)+buffer.len(ids)+buffer.len(versions) end
				end
			end
		end
		table.clear(swings)
	end

	-- Weapons, fireballs, gem pickup.
	for _, t in targets do
		if t.run then
			fireWeapons(t.run, t.root, dt)
		end
	end
	moveShots(dt)
	moveAxes(dt)
	for g, gem in gems do
		for _, t in targets do
			if t.run then
				local p = t.root.Position
				local reach = R.PickupRange * (1 + t.run.bonus.magnet)
				if (gem.x - p.X) ^ 2 + (gem.z - p.Z) ^ 2 < reach * reach then
					pickedPositions[g] = gem
					gems[g] = nil
					local list = taken[t.run.player] or {}
					taken[t.run.player] = list
					table.insert(list, g)
					t.run.gems += 1
					gainXP(t.run, R.GemXP)
					break
				end
			end
		end
	end

	-- Horde size and toughness grow with the longest run; spawn on a ring around a player in the arena.
	local longest = nil
	for _, run in runs do
		longest = math.max(longest or 0, now - run.start)
	end
	local target = override or (longest and math.min(R.MaxAlive, math.floor(R.StartAlive + R.AlivePerMinute * longest / 60))) or 0
	local spawnAt = {}
	for _, t in targets do
		if t.inside then
			table.insert(spawnAt, t.root.Position)
		end
	end
	if center and #spawnAt > 0 then
		local health = H.MaxHealth * (1 + R.HealthPerMinute * (longest or 0) / 60)
		for _ = 1, math.min(target - count, 20) do
			local t = spawnAt[rng:NextInteger(1, #spawnAt)]
			local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(H.SpawnRing[1], H.SpawnRing[2])
			local i = table.remove(free) or top + 1
			top, count = math.max(top, i), count + 1
			alive[i], hp[i] = true, health
			generation[i] = (generation[i] or 0) + 1
			kvx[i], kvz[i], stunUntil[i], slowUntil[i] = 0, 0, 0, 0
			px[i] = math.clamp(t.X + math.cos(a) * r, center.X - half, center.X + half)
			pz[i] = math.clamp(t.Z + math.sin(a) * r, center.Z - half, center.Z + half)
		end
	end
	while count > target do
		kill(top)
	end
	if not longest then -- nobody playing: sweep leftover gems
		for id in gems do table.insert(clearedGems, id) end
		table.clear(gems)
	end
end

local function sendBroadcast(): number
	if #axes > 0 or axesDirty then
		local packet = {}
		for _, a in axes do
			table.insert(packet, { a.id, a.run.player, a.x, a.z, a.y, a.radius, a.level, a.age })
		end
		fx:FireAllClients("axes", packet) -- same 10 Hz cadence as the horde; positions are authoritative
		axesDirty = false
	end
	if #dead > 0 then -- before the snapshot, so the client knows these are deaths and not just gone
		local b = buffer.create(2 + #dead * 2)
		buffer.writeu16(b, 0, deadFirstGem)
		for k, i in dead do
			buffer.writeu16(b, k * 2, i)
		end
		died:FireAllClients(b)
		table.clear(dead)
	end
	if #clearedGems > 0 then
		-- Retire these IDs after their death notifications; a newly started run keeps its own drops.
		fx:FireAllClients("clearGems", clearedGems)
		table.clear(clearedGems)
	end
	for player, list in taken do
		local b = buffer.create(#list * 2)
		for k, g in list do
			buffer.writeu16(b, (k - 1) * 2, g)
		end
		gemTaken:FireAllClients(player, b)
	end
	table.clear(taken)
	for player, log in hitLog do
		local b = buffer.create(#log * 2)
		for k, v in log do
			buffer.writeu16(b, (k - 1) * 2, math.clamp(v, 0, 65535))
		end
		hits:FireClient(player, b)
	end
	table.clear(hitLog)
	for _, run in runs do
		publish(run) -- kills change between level-ups; unchanged attributes cost nothing to set
	end
	local b = buffer.create(2 + top * 4)
	buffer.writeu16(b, 0, top)
	for i = 1, top do
		local o = 2 + (i - 1) * 4
		if alive[i] then
			buffer.writei16(b, o, math.clamp(math.round(px[i] * 8), NONE + 1, 32767)) -- 1/8 stud, +-4096 studs
			buffer.writei16(b, o + 2, math.clamp(math.round(pz[i] * 8), NONE, 32767))
		else
			buffer.writei16(b, o, NONE)
		end
	end
	snap:FireAllClients(b)
	return buffer.len(b)
end

-- GAME-24 transport. A full snapshot carries coordinates in slot order; a compact snapshot
-- carries the same coordinates only for set bits in its slot mask. Incarnations are sent
-- when a slot enters/re-enters/reuses, so old death/hit/swing events cannot affect its replacement.
local function quantize(value)
	return math.clamp(math.round(value*8), NONE+1, 32767)
end
local function inView(position, x, z, radius)
	return position and (position.X-x)^2+(position.Z-z)^2 <= radius*radius
end
local function buildView(previous, position)
	local selected, births, total = {}, {}, 0
	for slot=1,top do
		if alive[slot] then
			local incarnation = generation[slot] or 0
			local radius = if previous[slot]==incarnation then H.ViewLeave else H.ViewEnter
			if inView(position,px[slot],pz[slot],radius) then
				selected[slot]=incarnation; total+=1
				if previous[slot]~=incarnation then table.insert(births,slot) end
			end
		end
	end
	local maskBytes = math.ceil(top/8)
	if total==0 then return selected,buffer.create(2),nil,nil end
	local compact = maskBytes+total*4 < top*4
	local mask = if compact then buffer.create(maskBytes) else nil
	local packet = buffer.create(2+(if compact then total else top)*4)
	buffer.writeu16(packet,0,top)
	local offset=2
	for slot=1,top do
		if selected[slot]~=nil then
			if mask then
				local byte=(slot-1)//8
				buffer.writeu8(mask,byte,bit32.bor(buffer.readu8(mask,byte),bit32.lshift(1,(slot-1)%8)))
			end
			buffer.writei16(packet,offset,quantize(px[slot]))
			buffer.writei16(packet,offset+2,quantize(pz[slot])); offset+=4
		elseif not compact then
			buffer.writei16(packet,offset,NONE); offset+=4
		end
	end
	local identities = if #births>0 then buffer.create(#births*6) else nil
	for k,slot in births do
		buffer.writeu16(identities,(k-1)*6,slot)
		buffer.writeu32(identities,(k-1)*6+2,selected[slot])
	end
	return selected,packet,mask,identities
end

local function sendNearby(): number
	local totalBytes, recipients = 0,0
	local function emit(player,event,...)
		local bytes=0
		for _,value in {...} do if typeof(value)=="buffer" then bytes+=buffer.len(value) end end
		totalBytes+=bytes
		if networkSample then networkSample.bytes[player]=(networkSample.bytes[player] or 0)+bytes end
		event:FireClient(player,...)
	end
	if #axes>0 or axesDirty then
		local packet={}
		for _,a in axes do table.insert(packet,{a.id,a.run.player,a.x,a.z,a.y,a.radius,a.level,a.age}) end
		fx:FireAllClients("axes",packet); axesDirty=false
	end
	for _,player in Players:GetPlayers() do
		recipients+=1
		local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local position=root and root.Position
		local view=views[player] or {slots={},gems={}}
		views[player]=view
		local deaths={}
		for _,event in deathEvents do
			if view.slots[event.slot]==event.incarnation and inView(position,event.x,event.z,H.ViewLeave) then
				table.insert(deaths,event)
			end
		end
		if #deaths>0 then
			local packet=buffer.create(#deaths*6)
			for k,event in deaths do
				buffer.writeu16(packet,(k-1)*6,event.slot)
				buffer.writeu32(packet,(k-1)*6+2,event.incarnation)
			end
			emit(player,died,packet,true)
		end
		local selected,packet,mask,identities=buildView(view.slots,position)
		view.slots=selected
		emit(player,snap,packet,mask,identities)
		local log, versions=hitLog[player],hitVersions[player]
		if log then
			local visibleHits={}
			for k=1,#log,2 do
				local incarnation=versions[(k+1)//2]
				if selected[log[k]]==incarnation then table.insert(visibleHits,{log[k],log[k+1],incarnation}) end
			end
			if #visibleHits>0 then
				local values,ids=buffer.create(#visibleHits*4),buffer.create(#visibleHits*4)
				for k,hitData in visibleHits do
					buffer.writeu16(values,(k-1)*4,hitData[1]); buffer.writeu16(values,(k-1)*4+2,hitData[2])
					buffer.writeu32(ids,(k-1)*4,hitData[3])
				end
				emit(player,hits,values,ids)
			end
		end
		-- Pickups include position: even a gem born and collected between snapshots can fly to its owner.
		for picker,list in taken do
			local visible={}
			for _,id in list do
				local gem=pickedPositions[id]
				if gem and (picker==player or view.gems[id] or inView(position,gem.x,gem.z,H.ViewEnter)) then
					table.insert(visible,id)
				end
			end
			if #visible>0 then
				local ids,positions=buffer.create(#visible*2),buffer.create(#visible*4)
				for k,id in visible do
					local gem=pickedPositions[id]
					buffer.writeu16(ids,(k-1)*2,id)
					buffer.writei16(positions,(k-1)*4,quantize(gem.x)); buffer.writei16(positions,(k-1)*4+2,quantize(gem.z))
				end
				emit(player,gemTaken,picker,ids,positions)
			end
		end
		local known,added,removed={},{},{}
		for id,gem in gems do
			local radius=if view.gems[id]==gem then H.ViewLeave else H.ViewEnter
			if inView(position,gem.x,gem.z,radius) then
				known[id]=gem
				if view.gems[id]~=gem then table.insert(added,id) end
			end
		end
		for id,gem in view.gems do if known[id]~=gem then table.insert(removed,id) end end
		if #added>0 or #removed>0 then
			local addPacket,removePacket=buffer.create(#added*6),buffer.create(#removed*2)
			for k,id in added do
				buffer.writeu16(addPacket,(k-1)*6,id)
				buffer.writei16(addPacket,(k-1)*6+2,quantize(gems[id].x)); buffer.writei16(addPacket,(k-1)*6+4,quantize(gems[id].z))
			end
			for k,id in removed do buffer.writeu16(removePacket,(k-1)*2,id) end
			emit(player,gemState,addPacket,removePacket)
		end
		view.gems=known
	end
	for _,run in runs do publish(run) end
	table.clear(dead); table.clear(deathEvents); table.clear(clearedGems)
	table.clear(hitLog); table.clear(hitVersions); table.clear(taken); table.clear(pickedPositions)
	return totalBytes/math.max(recipients,1)
end

local function send(): number
	sendRocks()
	if networkMode=="broadcast" then
		local bytes=sendBroadcast()
		if networkSample then for _,p in Players:GetPlayers() do networkSample.bytes[p]=(networkSample.bytes[p] or 0)+bytes end end
		table.clear(deathEvents); table.clear(hitVersions); table.clear(pickedPositions)
		return bytes
	end
	return sendNearby()
end

-- GAME-23: opt-in measurement only; normal Studio/production runs do not allocate samples.
local benchmarkArgs, benchmarkSample
local axeTestArgs
local rocksTestArgs
local cleanupTestArgs
local networkTestArgs, networkManual
if RunService:IsStudio() then
	local ok, args = pcall(function() return game:GetService("StudioTestService"):GetTestArgs() end)
	if ok and typeof(args) == "table" and args.name == "GAME23Baseline" then
		benchmarkArgs = args
	end
	if ok and typeof(args) == "table" and args.name == "GAME12Axe" then
		axeTestArgs = args
		Shared:SetAttribute("GAME12AxeActive", true)
	end
	if ok and typeof(args)=="table" and args.name=="GAME12Rocks" then
		rocksTestArgs=args;Shared:SetAttribute("GAME12RocksActive",true)
	end
	if ok and typeof(args) == "table" and args.name == "GAME25Cleanup" then
		cleanupTestArgs = args
		Shared:SetAttribute("GAME25Active", true)
	end
	if ok and typeof(args) == "table" and args.name == "GAME24Network" then
		networkTestArgs = args
		Shared:SetAttribute("GAME24Active", true)
	end
end
local simAcc, sendAcc, statAcc = 0, 0, 0
local simTime, sentBytes = 0, 0
RunService.Heartbeat:Connect(function(dt)
	if benchmarkSample then table.insert(benchmarkSample.heartbeat,dt*1000) end
	simAcc += dt
	sendAcc += dt
	statAcc += dt
	while simAcc >= 1 / H.SimRate do
		simAcc -= 1 / H.SimRate
		local t0 = os.clock()
		if not axeTestArgs and not rocksTestArgs and not cleanupTestArgs and not networkManual then step(1 / H.SimRate) end -- named fixtures drive exact steps
		local elapsed = os.clock() - t0
		if networkSample then table.insert(networkSample.step,elapsed*1000) end
		simTime += elapsed
		if benchmarkSample then
			table.insert(benchmarkSample.step,elapsed*1000)
			table.insert(benchmarkSample.count,count)
		end
	end
	if sendAcc >= 1 / H.SendRate then
		sendAcc = 0
		local t0 = os.clock()
		local bytes = send()
		if networkSample then table.insert(networkSample.send,(os.clock()-t0)*1000) end
		sentBytes += bytes
		if benchmarkSample then
			table.insert(benchmarkSample.send,(os.clock()-t0)*1000)
			benchmarkSample.bytes += bytes
		end
	end
end)

-- GAME-12: opt-in acceptance fixture. Normal play never creates this bridge or alters characters.
if axeTestArgs then
	local STS = game:GetService("StudioTestService")
	local bridge = Instance.new("RemoteFunction")
	bridge.Name, bridge.Parent = "GAME12AxeTest", Shared
	local ready, errors, checks = {}, {}, {}
	local finished = false
	local function finish(report)
		if finished then return end
		finished = true
		STS:EndTest(report)
	end
	task.delay(180, function() finish({ok=false,error="axe acceptance deadline",checks=checks,errors=errors}) end)
	bridge.OnServerInvoke = function(player) ready[player] = true; return true end
	game:GetService("ScriptContext").Error:Connect(function(message, _, source)
		if source and string.find(source.Name, "Goblin", 1, true) then table.insert(errors, message) end
	end)
	local function check(value, label)
		assert(value, label); table.insert(checks, label)
	end
	local function untilTrue(fn, timeout)
		local deadline = os.clock() + timeout
		repeat if fn() then return end; task.wait(0.05) until os.clock() > deadline
		error("fixture timeout")
	end
	task.spawn(function()
		local report = { checks = checks, errors = errors, mode = "real clients / deterministic server fixture", clients = axeTestArgs.clients or 1 }
		local ok, err = xpcall(function()
			untilTrue(function() return #Players:GetPlayers() >= (axeTestArgs.clients or 1) end, 45)
			local player = Players:GetPlayers()[1]
			untilTrue(function() return ready[player] and player.Character and player.Character:FindFirstChild("HumanoidRootPart") end, 45)
			Workspace:SetAttribute("Arena", "StressZone")
			local center = assert(arena())
			local root, hum = player.Character.HumanoidRootPart, player.Character:FindFirstChildOfClass("Humanoid")
			root.Anchored = true
			root.CFrame = CFrame.new(center + Vector3.new(0, 4, 0))
			Instance.new("ForceField", player.Character).Visible = false
			startRun(player, hum)
			local run = runs[player]
			local function target(x, z, health)
				alive[1], px[1], pz[1], hp[1] = true, center.X+x, center.Z+z, health or 1000
				generation[1] = (generation[1] or 0)+1
				kvx[1],kvz[1],stunUntil[1],slowUntil[1] = 0,0,0,0
				top,count=1,1; table.clear(free); table.clear(grid)
				grid[key(px[1]//CELL,pz[1]//CELL)]={1}
			end
			local function throw()
				clearRunAxes(player); run.cd.axe=0; fireWeapons(run,root,0)
				check(#axes==1,"throw creates one authoritative axe")
				return axes[1]
			end
			local function travel()
				for _=1,160 do
					pruneAxes(); moveAxes(1/30); task.wait(1/30)
					if #axes==0 then return end
				end
				error("axe did not return")
			end
			-- Exercise the real card remote, then real HUD/loadout replication.
			run.cards={{kind="weapon",id="axe",level=1,rarity=1}}; run.pending=1
			run.pausedAt=Workspace:GetServerTimeNow()
			levelUp:FireClient(player,run.cards,run.rerolls,run.level)
			local beforePick
			untilTrue(function()
				beforePick=bridge:InvokeClient(player,"report")
				return beforePick.visibleAxeIcons>=1
			end,5)
			check(beforePick.visibleAxeIcons>=1,"axe pixel art visible on real upgrade card")
			bridge:InvokeClient(player,"pick")
			untilTrue(function() return run.weapons.axe==1 and not run.cards end,5)
			check(table.find(run.wOrder,"axe")~=nil,"real card selection acquires axe")
			run.weapons={axe=1}; run.wOrder={"axe"}; publish(run)
			target(8,0); local damage=run.damage.axe or 0; throw(); travel()
			check(hp[1]==968 and run.damage.axe-damage==32,"one hit per target on each leg, correct damage ownership")
			check(stunUntil[1]>0,"axe applies existing stun interaction")
			local first=bridge:InvokeClient(player,"report")
			check(first.peakAxes>=1 and first.nonCosmeticParts==0,"client rendered non-colliding non-queryable axe")
			check(first.visibleAxeIcons>=1,"axe pixel art visible in real HUD")
			-- A single large step must sweep through enemies, not skip them.
			target(8,0); local a=throw(); moveAxes(0.4)
			check(hp[1]==984,"swept hit prevents tunneling on a long step")
			axeSweep(a,center.X,center.Z,center.X+16,center.Z)
			check(hp[1]==984,"same incarnation cannot be hit twice on one leg")
			generation[1]+=1
			axeSweep(a,center.X,center.Z,center.X+16,center.Z)
			check(hp[1]==968,"reused slot is a new hit identity")
			-- A projectile from a previous run must not survive a replacement run for the same player.
			runs[player]={};pruneAxes()
			check(#axes==0,"replaced run identity cancels old projectile")
			runs[player]=run
			clearRunAxes(player); target(8,0,16); local kills=run.kills; throw(); moveAxes(0.4)
			check(run.kills==kills+1 and not alive[1],"lethal axe hit credits kill once and drops existing XP gem")
			local gemCount=0; for _ in gems do gemCount+=1 end
			moveAxes(0.4); check(run.kills==kills+1 and gemCount==1,"no duplicate kill or gem from dead target")
			table.clear(gems); table.clear(dead)
			-- Passive scaling and higher tiers use the same path, not separate damage code.
			run.weapons.axe=5; run.bonus.might=0.5; run.bonus.area=0.5; run.bonus.haste=0.5; run.bonus.force=1
			target(8,0); a=throw()
			check(a.damage==51 and math.abs(a.radius-3.6)<0.0001 and a.left==45 and run.cd.axe==0.9,"Might Area Haste and Lv5 stats applied")
			moveAxes(0.4); check(kvx[1]~=0 or kvz[1]~=0,"Force knockback applied")
			run.bonus.might=0;run.bonus.area=0;run.bonus.haste=0;run.bonus.force=0
			run.weapons.axe=1
			-- Return target moves; cancellation also runs during the global card pause.
			target(8,0); a=throw(); moveAxes(24/38)
			root.CFrame+=Vector3.new(0,0,8); pruneAxes(); moveAxes(0.1)
			check(a.leg==2 and a.z>center.Z,"return homes to moving owner")
			travel(); check(#axes==0,"catch cleans up server projectile")
			root.CFrame=CFrame.new(center+Vector3.new(0,4,0)); target(8,0); a=throw()
			run.cards={{kind="weapon",id="axe",level=2,rarity=1}}
			local age,x=a.age,a.x; step(1/30)
			check(a.age==age and a.x==x,"existing global upgrade pause freezes axe")
			root.CFrame+=Vector3.new(80,0,0); step(1/30)
			check(#axes==0,"teleport cancels axe even while paused")
			run.cards=nil;root.CFrame=CFrame.new(center+Vector3.new(0,4,0))
			target(8,0);a=throw();a.age=4.49;moveAxes(0.02)
			check(#axes==0,"maximum lifetime bounds projectile retention")
			target(8,0);throw();endRun(player)
			check(#axes==0 and runs[player]==nil,"run end cancels axes immediately")
			task.wait(0.4)
			local last=bridge:InvokeClient(player,"report")
			check(last.axes==0,"client visual cleaned up after run end")
			check(#last.errors==0 and #errors==0,"no captured Goblin server/client errors")
			report.client=last;report.firstClient=first
			if (axeTestArgs.reviewSeconds or 0) > 0 then
				Workspace:SetAttribute("Arena", if Workspace:FindFirstChild("Map1") then "Map1" else "StressZone")
				center = assert(arena())
				root.CFrame=CFrame.new(center+Vector3.new(0,4,20))
				startRun(player,hum);run=runs[player]
				run.weapons={axe=1};run.wOrder={"axe"};publish(run)
				Shared:SetAttribute("GAME12ReviewPlayer",player.UserId)
				Shared:SetAttribute("GAME12ReviewStage","motion")
				local deadline=os.clock()+math.min(axeTestArgs.reviewSeconds,60)
				while os.clock()<deadline do
					target(8,20)
					fireWeapons(run,root,1/30);pruneAxes();moveAxes(1/30)
					task.wait(1/30)
				end
				Shared:SetAttribute("GAME12ReviewStage",nil)
				endRun(player)
				Workspace:SetAttribute("Arena","StressZone");center=assert(arena())
			end
			if (axeTestArgs.clients or 1) == 2 then
				local other
				for _,p in Players:GetPlayers() do if p~=player then other=p;break end end
				untilTrue(function() return other and ready[other] and other.Character and other.Character:FindFirstChild("HumanoidRootPart") end,30)
				local root2,hum2=other.Character.HumanoidRootPart,other.Character:FindFirstChildOfClass("Humanoid")
				root2.Anchored=true
				root.CFrame=CFrame.new(center+Vector3.new(-50,4,0))
				root2.CFrame=CFrame.new(center+Vector3.new(50,4,0))
				Instance.new("ForceField",other.Character).Visible=false
				startRun(player,hum);startRun(other,hum2)
				local run2=runs[other];run=runs[player]
				for _,r in {run,run2} do
					r.weapons={axe=1};r.wOrder={"axe"};r.cd.axe=0;publish(r)
				end
				target(-42,0)
				alive[2],px[2],pz[2],hp[2]=true,center.X+58,center.Z,1000
				generation[2]=(generation[2] or 0)+1
				kvx[2],kvz[2],stunUntil[2],slowUntil[2]=0,0,0,0
				top,count=2,2;grid[key(px[2]//CELL,pz[2]//CELL)]={2}
				fireWeapons(run,root,0);fireWeapons(run2,root2,0)
				moveAxes(.15);task.wait(.4)
				local seen1,seen2=bridge:InvokeClient(player,"report"),bridge:InvokeClient(other,"report")
				check(seen1.axes==2 and seen2.axes==2,"both real clients render both players' axes")
				travel()
				check(run.damage.axe==32 and run2.damage.axe==32 and hp[1]==968 and hp[2]==968,"two real players keep hit credit separate")
				run.cd.axe=0;run2.cd.axe=0;fireWeapons(run,root,0);fireWeapons(run2,root2,0)
				endRun(player);task.wait(.4)
				check(#axes==1 and axes[1].run==run2 and bridge:InvokeClient(other,"report").axes==1,"ending one real run preserves the other axe on server and client")
				clearRunAxes(other);startRun(player,hum);run=runs[player]
				run.weapons={axe=1};run.wOrder={"axe"};publish(run)
				run.cd.axe=0;run2.cd.axe=0;fireWeapons(run,root,0);fireWeapons(run2,root2,0)
				bridge:InvokeClient(other,"leave")
				untilTrue(function() return other.Parent~=Players end,10)
				task.wait(.4)
				check(#axes==1 and axes[1].run==run and runs[other]==nil and bridge:InvokeClient(player,"report").axes==1,"disconnect removes only departing player's axe on remaining client")
				hum.Health=0
				untilTrue(function() return runs[player]==nil end,5);task.wait(.4)
				local final=bridge:InvokeClient(player,"report")
				check(#axes==0 and final.axes==0,"death clears final player's server and client axes")
				check(#seen1.errors==0 and #seen2.errors==0 and #final.errors==0 and #errors==0,"no captured two-client Goblin errors")
				report.multiplayer={observers={seen1,seen2},remainingClient=final}
			end
		end,debug.traceback)
		report.ok,report.error=ok,if ok then nil else tostring(err)
		finish(report)
	end)
end

-- GAME-23: isolated stress fixture, enabled only by explicit StudioTestService arguments.
if benchmarkArgs then
	local STS = game:GetService("StudioTestService")
	local Stats = game:GetService("Stats")
	local bridge = Instance.new("RemoteFunction")
	bridge.Name, bridge.Parent = "GAME23Benchmark", Shared
	Shared:SetAttribute("GAME23Active", true)
	local ready, replies, errors = {}, {}, {}
	local activeRequest = 0
	bridge.OnServerInvoke = function(player, action, request, value)
		if action == "ready" then ready[player] = true
		elseif action == "report" and request == activeRequest and typeof(value) == "table" then replies[player] = value end
		return true
	end
	game:GetService("ScriptContext").Error:Connect(function(message, _, source)
		if source and string.find(source.Name, "Goblin", 1, true) then table.insert(errors, {source=source.Name,message=message}) end
	end)
	local function summary(values)
		table.sort(values)
		if #values == 0 then return {n=0} end
		return {n=#values,p50=values[math.ceil(#values*0.5)],p95=values[math.ceil(#values*0.95)],max=values[#values]}
	end
	local function untilTrue(fn, timeout, message)
		local deadline = os.clock()+timeout
		repeat if fn() then return end task.wait(0.1) until os.clock()>deadline
		error(message)
	end
	-- Client calls are issued asynchronously and bounded by this server deadline.
	local function clientsCommand(list, action)
		activeRequest += 1
		table.clear(replies)
		local request = activeRequest
		for _,player in list do
			task.spawn(function()
				local ok, value = pcall(function() return bridge:InvokeClient(player, action, request) end)
				if ok and activeRequest == request then replies[player] = value end
			end)
		end
		untilTrue(function()
			for _,player in list do if replies[player] == nil then return false end end
			return true
		end, 20, "client measurement timeout: "..action)
		local out = {}
		for i,player in list do out[i] = replies[player] end
		return out
	end
	local finished = false
	local function finish(result)
		if finished then return end
		finished = true
		benchmarkSample = nil
		STS:EndTest(result)
	end
	task.delay(420, function() finish({ok=false,error="GAME23 timeout",errors=errors}) end)
	task.spawn(function()
		local report = {schema=1,baseCommit=benchmarkArgs.baseCommit,fixture="circle24-speed12-no-weapons-shield",
			studioVersion=version(),placeId=game.PlaceId,placeVersion=game.PlaceVersion,
			clients=benchmarkArgs.clients,seed=23001,warmupSeconds=10,sampleSeconds=20,phases={},errors=errors,
			renderContext="background simulated clients; not device FPS"}
		local ok, err = xpcall(function()
			assert(benchmarkArgs.clients==1 or benchmarkArgs.clients==2 or benchmarkArgs.clients==4,"unsupported client count")
			untilTrue(function()
				local list=Players:GetPlayers()
				if #list~=benchmarkArgs.clients then return false end
				for _,p in list do if not ready[p] or not p.Character or not p.Character:FindFirstChild("HumanoidRootPart") then return false end end
				return true
			end, 60, "players/measurement clients not ready")
			local list=Players:GetPlayers()
			table.sort(list,function(a,b) return a.UserId<b.UserId end)
			local center=assert(arena(),"StressZone missing")
			for _,p in list do
				local root=p.Character.HumanoidRootPart
				root.Anchored=true
				p.Character:PivotTo(CFrame.new(center+Vector3.new(24,4,0)))
				local shield=Instance.new("ForceField")
				shield.Visible=false; shield.Parent=p.Character
			end
			untilTrue(function() for _,p in list do if not runs[p] then return false end end return true end, 15, "runs did not start")
			-- A fixed enemy count isolates horde simulation/render/network cost from upgrades and DPS.
			-- These changes affect this disposable test session only, never saved Config.
			for _,p in list do
				local run=runs[p]
				run.weapons,run.wOrder={},{}
				run.cards,run.pausedAt,run.pending=nil,nil,0
			end
			table.clear(gems)
			table.clear(shots)
			for repeatIndex=1,2 do
				for _,population in {100,500,1000} do
					benchmarkSample=nil
					for i=1,top do if alive[i] then kill(i) end end
					rng=Random.new(23001)
					override=population
					local routeStart=os.clock()
					local mover=RunService.Heartbeat:Connect(function()
						local angle=(os.clock()-routeStart)*0.5
						for i,p in list do
							local a=angle+(i-1)*math.pi*2/#list
							p.Character:PivotTo(CFrame.new(center+Vector3.new(math.cos(a)*24,4,math.sin(a)*24)))
						end
					end)
					task.wait(report.warmupSeconds)
					assert(count==population,"population failed to stabilize")
					for _,run in runs do assert(not run.cards,"unexpected upgrade pause") end
					clientsCommand(list,"begin")
					local sample={step={},send={},heartbeat={},memory={},instances={},count={},bytes=0}
					benchmarkSample=sample
					local start=os.clock()
					local baselineMemory=Stats:GetTotalMemoryUsageMb()
					local baselineInstances=Stats.InstanceCount
					repeat
						table.insert(sample.memory,Stats:GetTotalMemoryUsageMb())
						table.insert(sample.instances,Stats.InstanceCount)
						task.wait(1)
					until os.clock()-start>=report.sampleSeconds
					local elapsed=os.clock()-start
					benchmarkSample=nil
					mover:Disconnect()
					local clients=clientsCommand(list,"finish")
					local nmin=math.huge
					for _,n in sample.count do nmin=math.min(nmin,n) end
					local phase={repeatIndex=repeatIndex,population=population,seconds=elapsed,
						stepMs=summary(sample.step),sendMs=summary(sample.send),heartbeatMs=summary(sample.heartbeat),
						memoryMb=summary(sample.memory),instances=summary(sample.instances),
						memoryStartMb=baselineMemory,instancesStart=baselineInstances,
						minAlive=nmin,maxAlive=count,snapshotPayloadKiBps=sample.bytes/elapsed/1024,clientReports=clients}
					assert(nmin==population and count==population,"population changed during sample")
					table.insert(report.phases,phase)
				end
			end
		end, debug.traceback)
		report.ok, report.error = ok, if ok then nil else tostring(err)
		finish(report)
	end)
end

-- GAME-25: deterministic lifecycle workload, real clients/remotes/deaths, opt-in only.
-- Simulation is advanced at real-time cadence; pooled capacity is reported separately from live state.
if cleanupTestArgs then
	local sts, stats = game:GetService("StudioTestService"), game:GetService("Stats")
	local bridge = Instance.new("RemoteFunction")
	bridge.Name, bridge.Parent = "GAME25Cleanup", Shared
	local ready, errors = {}, {}
	bridge.OnServerInvoke = function(player) ready[player]=true; return true end
	game:GetService("ScriptContext").Error:Connect(function(message,_,source)
		if source and source.Name:find("Goblin",1,true) then table.insert(errors,message) end
	end)
	local report = {pilot=cleanupTestArgs.pilot==true,cycles={},soak={},checks={},errors=errors,workload=100,settleSeconds=5}
	local finished = false
	local function finish()
		if finished then return end
		finished=true; sts:EndTest(report)
	end
	task.delay(1500,function() report.ok=false; report.error="cleanup deadline"; finish() end)
	local function check(value,label)
		assert(value,label); table.insert(report.checks,label)
	end
	local function untilTrue(fn)
		local deadline=os.clock()+50
		repeat if fn() then return end; task.wait(0.05) until os.clock()>deadline
		error("cleanup participant/character timeout")
	end
	local function size(t) local n=0; for _ in t do n+=1 end; return n end
	local function snapshot(player,label)
		local orphanHits, invalidShots = 0,0
		for hum in lastHit do if not hum:IsDescendantOf(Workspace) then orphanHits+=1 end end
		for _, shot in shots do if runs[shot.run.player]~=shot.run then invalidShots+=1 end end
		local value={label=label,at=os.clock(),runs=size(runs),gems=size(gems),shots=#shots,axes=#axes,
			lastHit=size(lastHit),orphanHits=orphanHits,invalidShots=invalidShots,alive=count,
			hitLog=size(hitLog),taken=size(taken),memoryMb=stats:GetTotalMemoryUsageMb(),
			instances=stats.InstanceCount,luaKb=gcinfo(),client=bridge:InvokeClient(player,"snapshot")}
		Shared:SetAttribute("GAME25Progress",label)
		return value
	end
	local function quiet(value)
		local c=value.client
		return value.runs==0 and value.gems==0 and value.shots==0 and value.axes==0 and value.orphanHits==0
			and value.alive==0 and c.live==0 and c.gems==0 and c.balls==0 and c.axes==0 and c.rings==0
			and c.orphanRings==0 and c.orphanSides==0 and c.visibleNumbers==0 and c.flashPool==24
	end
	task.spawn(function()
		local ok, err=xpcall(function()
			untilTrue(function() return #Players:GetPlayers()==2 and size(ready)==2 end)
			local list=Players:GetPlayers()
			table.sort(list,function(a,b) return a.UserId<b.UserId end)
			local player,peer=list[1],list[2]
			Workspace:SetAttribute("Arena","StressZone")
			local center=assert(arena())
			report.map1Present=Workspace:FindFirstChild("Map1")~=nil
			report.map1Instances=report.map1Present and #Workspace.Map1:GetDescendants() or 0
			local function beginRun(p)
				local previous=p.Character
				bridge:InvokeClient(p,"restart")
				untilTrue(function() return p.Character and p.Character~=previous and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChildOfClass("Humanoid") end)
				local root,hum=p.Character.HumanoidRootPart,p.Character:FindFirstChildOfClass("Humanoid")
				root.Anchored=true; root.CFrame=CFrame.new(center+Vector3.new(0,4,0))
				hum.MaxHealth=1000000; hum.Health=1000000
				for _,d in p.Character:GetChildren() do if d:IsA("ForceField") then d:Destroy() end end
				startRun(p,hum)
				local run=runs[p]
				run.weapons={sword=1,fire=1,ring=1,axe=1}; run.wOrder={"sword","fire","ring","axe"}; run.next=1e9
				publish(run)
				return run,root
			end
			local function targets100()
				while count>0 do kill(top) end
				table.clear(free)
				for i=1,100 do
					local angle=i*math.pi*2/100
					alive[i],px[i],pz[i],hp[i]=true,center.X+math.cos(angle)*20,center.Z+math.sin(angle)*20,1e8
					generation[i]=(generation[i] or 0)+1
					kvx[i],kvz[i],stunUntil[i],slowUntil[i],nextSwing[i]=0,0,0,0,0
				end
				top,count,override=100,100,100
				px[1],pz[1]=center.X+1,center.Z
			end
			local function drive(seconds)
				local stop=os.clock()+seconds
				repeat step(1/H.SimRate); task.wait(1/H.SimRate) until os.clock()>=stop
			end
			local function endAndSettle(p)
				local old=p.Character
				p.Character:FindFirstChildOfClass("Humanoid").Health=0
				untilTrue(function() return runs[p]==nil end)
				override=nil; step(1/H.SimRate); send()
				bridge:InvokeClient(p,"lobby")
				untilTrue(function() return p.Character and p.Character~=old and p.Character:FindFirstChild("HumanoidRootPart") end)
				p.Character.HumanoidRootPart.Anchored=true
				task.wait(5)
			end
			-- A departing peer owns an actual fireball/ring/slash while the survivor's card pauses simulation.
			local run,root=beginRun(player)
			local peerRun,peerRoot=beginRun(peer)
			targets100(); drive(0.4)
			peerRun.cd.fire=0; fireWeapons(peerRun,peerRoot,0); send()
			run.pending=1; offer(run)
			task.wait(0.5)
			report.beforeDisconnect=snapshot(player,"before-disconnect")
			bridge:InvokeClient(peer,"leave")
			untilTrue(function() return peer.Parent~=Players end)
			drive(1); task.wait(2)
			report.afterDisconnect=snapshot(player,"after-disconnect-paused")
			if not report.pilot then
				check(report.afterDisconnect.invalidShots==0,"departed run has no fireball reference during card pause")
				check(report.afterDisconnect.client.orphanRings==0 and report.afterDisconnect.client.orphanSides==0,"departed player visual references released")
			end
			ready[peer]=nil; peer=nil; peerRun=nil; peerRoot=nil; list=nil
			bridge:InvokeClient(player,"pick")
			untilTrue(function() return run.cards==nil end)
			drive(2); endAndSettle(player)
			-- Three warmups then twenty measured cycles. Pilot records three without assertions about cleanup.
			for cycle=1,(report.pilot and 3 or 23) do
				run,root=beginRun(player); targets100(); send(); task.wait(0.3)
				-- Land a real contact hit before weapons can stun the nearest target.
				for id in run.weapons do run.cd[id]=10 end
				swingAt[1]=Workspace:GetServerTimeNow()-H.AttackWindup-0.01
				step(1/H.SimRate)
				for id in run.weapons do run.cd[id]=0 end
				drive(1)
				for i=90,99 do if alive[i] then kill(i,run) end end
				send(); drive(1)
				-- Offer/reroll/card UI is rebuilt each cycle; consume via the production remote.
				run.level=2; run.pending=1; offer(run); task.wait(0.2)
				bridge:InvokeClient(player,"pick")
				untilTrue(function() return run.cards==nil end)
				endAndSettle(player)
				local value=snapshot(player,"cycle-"..cycle)
				value.measured=cycle>3; table.insert(report.cycles,value)
				if not report.pilot then check(quiet(value),"cycle "..cycle.." live state clean after five seconds") end
			end
			if report.pilot then return end
			-- After repeated restarts, one remote packet still creates exactly one fireball and one sound.
			run,root=beginRun(player); targets100(); send(); task.wait(1)
			local before=bridge:InvokeClient(player,"snapshot")
			fx:FireClient(player,"fire",center.X,center.Z,1,0,1,5)
			local packet=buffer.create(4); buffer.writeu16(packet,0,1); buffer.writeu16(packet,2,7)
			hits:FireClient(player,packet); task.wait(0.1)
			local after=bridge:InvokeClient(player,"snapshot")
			check(after.balls-before.balls==1,"one fire event creates one visual after twenty restarts")
			check(after.visibleNumbers-before.visibleNumbers==1,"one hit creates one damage label")
			check((after.sounds.Hit or 0)-(before.sounds.Hit or 0)==1,"one hit plays one sound")
			task.wait(5.2)
			endAndSettle(player)
			report.soakBaseline=snapshot(player,"soak-clean-baseline")
			run,root=beginRun(player); targets100()
			-- Continuous fixed 100-goblin workload. Health reset prevents incidental deaths; one controlled
			-- kill/second drops a gem at the player's feet, exercising the real pickup/tween path without
			-- allowing uncollected gameplay drops to accumulate. The fixture never clears client pools.
			local began=os.clock(); local nextDrop, nextSample=0,60
			while os.clock()-began<900 do
				local elapsed=os.clock()-began
				for i=1,top do if alive[i] then hp[i]=1e8 end end
				if elapsed>=nextDrop then
					nextDrop+=1
					if alive[1] then px[1],pz[1]=center.X,center.Z; kill(1,run); send() end
				end
				step(1/H.SimRate)
				if elapsed>=nextSample then
					local value=snapshot(player,"soak-"..nextSample)
					value.elapsed=elapsed; table.insert(report.soak,value); nextSample+=60
				end
				task.wait(1/H.SimRate)
			end
			report.soakSeconds=os.clock()-began
			table.insert(report.soak,snapshot(player,"soak-900"))
			endAndSettle(player)
			report.final=snapshot(player,"complete")
			check(report.soakSeconds>=900,"full fifteen-minute wall-clock soak")
			check(quiet(report.final),"soak live state clean after five seconds")
			check(report.final.client.soundTemplates==10,"sound template count unchanged")
			check(#errors==0 and #report.final.client.errors==0,"no Goblin script errors")
		end,debug.traceback)
		report.ok,report.error=ok,if ok then nil else tostring(err)
		finish()
	end)
end

-- GAME-12 Rocks: opt-in real two-client acceptance. No changes to ordinary startup.
if rocksTestArgs then
	local sts=game:GetService("StudioTestService")
	local bridge=Instance.new("RemoteFunction");bridge.Name,bridge.Parent="GAME12RocksTest",Shared
	local ready,checks,errors={},{},{}
	bridge.OnServerInvoke=function(p) ready[p]=true;return true end
	local finished=false
	local function finish(report) if not finished then finished=true;sts:EndTest(report) end end
	task.delay(240,function() finish({ok=false,error="Rocks deadline",checks=checks,errors=errors}) end)
	game:GetService("ScriptContext").Error:Connect(function(message,_,source)
		if source and source.Name:find("Goblin",1,true) then table.insert(errors,message) end
	end)
	local function check(v,label) assert(v,label);table.insert(checks,label) end
	local function waitFor(fn,label)
		local stop=os.clock()+45
		repeat if fn() then return end;task.wait(.05) until os.clock()>stop
		error("Rocks timeout: "..label)
	end
	local function snapshot(p) return bridge:InvokeClient(p,"report") end
	task.spawn(function()
		local report={checks=checks,errors=errors,clients=2,mode="real card/replication/ownership/lifecycle"}
		local ok,err=xpcall(function()
			waitFor(function()
				if #Players:GetPlayers()~=2 then return false end
				for _,p in Players:GetPlayers() do if not ready[p] or not p.Character or not p.Character:FindFirstChild("HumanoidRootPart") then return false end end
				return true
			end,"two participants")
			Workspace:SetAttribute("Arena","Map1");override=0
			local center=assert(arena());report.map1Instances=#Workspace.Map1:GetDescendants()
			local list=Players:GetPlayers();local a,b=list[1],list[2]
			local function prepare(p,x)
				local root,hum=p.Character.HumanoidRootPart,p.Character:FindFirstChildOfClass("Humanoid")
				root.Anchored=true;root.CFrame=CFrame.new(center+Vector3.new(x,4,0))
				Instance.new("ForceField",p.Character).Visible=false;startRun(p,hum)
				local run=runs[p];run.weapons={};run.wOrder={};run.next=1e9;publish(run)
				return run,root
			end
			local ra,rootA=prepare(a,-10);local rb,rootB=prepare(b,10)
			local function acquire(p,run)
				run.cards={{kind="weapon",id="rocks",level=1,rarity=1}};run.pending=1
				run.pausedAt=Workspace:GetServerTimeNow()
				levelUp:FireClient(p,run.cards,run.rerolls,run.level)
				waitFor(function() return snapshot(p).icons>=1 end,"rocks card art")
				check(snapshot(p).icons>=1,"real rocks card icon visible for "..p.Name)
				bridge:InvokeClient(p,"pick");waitFor(function() return run.weapons.rocks==1 and not run.cards end,"pick")
				check(table.find(run.wOrder,"rocks")~=nil,"real card selection acquires rocks for "..p.Name)
			end
			acquire(a,ra);acquire(b,rb)
			local function target(x,z,health)
				while count>0 do kill(top) end;table.clear(free);table.clear(grid)
				alive[1],px[1],pz[1],hp[1]=true,x,z,health or 1000
				generation[1]=(generation[1] or 0)+1;kvx[1],kvz[1],stunUntil[1],slowUntil[1]=0,0,0,0
				top,count=1,1;grid[key(x//CELL,z//CELL)]={1}
			end
			target(rootA.Position.X+7,0);fireWeapons(ra,rootA,0);fireWeapons(rb,rootB,0);send()
			waitFor(function() return snapshot(a).rocks==4 and snapshot(b).rocks==4 end,"both owners visible")
			check(snapshot(a).rocks==4 and snapshot(b).rocks==4,"both real clients see both owners' two stones")
			check(ra.damage.rocks==12 and not rb.damage.rocks and hp[1]==988,"server gives contact damage only to the correct owner")
			check(stunUntil[1]==0,"rocks do not permanently stun enemies")
			local old=hp[1];fireWeapons(ra,rootA,0);check(hp[1]==old,"same-frame overlaps do not duplicate damage")
			generation[1]+=1;fireWeapons(ra,rootA,0);check(hp[1]==old-12,"reused slot receives a fresh contact")
			for _,level in {1,3,5} do
				ra.weapons.rocks=level;publish(ra);fireWeapons(ra,rootA,0);send()
				local expected=Config.weaponStats("rocks",level).Count+2
				waitFor(function() return snapshot(a).rocks==expected and snapshot(b).rocks==expected end,"level visuals")
				check(snapshot(a).rocks==expected and snapshot(b).rocks==expected,"level "..level.." stone count replicated to both clients")
			end
			check(snapshot(a).nonCosmetic==0 and snapshot(b).nonCosmetic==0,"all stones are anchored and non-colliding/non-queryable")
			check(snapshot(a).icons>=1 and snapshot(b).icons>=1,"rocks art appears in both HUDs")
			ra.cards={{kind="heal"}};local phaseA,phaseB=ra.rocks.phase,rb.rocks.phase
			for _=1,10 do step(1/H.SimRate) end
			check(ra.rocks.phase==phaseA and rb.rocks.phase==phaseB,"global card pause freezes both authoritative orbits")
			rootA.Position+=Vector3.new(60,0,0);step(1/H.SimRate);send()
			waitFor(function() return snapshot(a).rocks==2 and snapshot(b).rocks==2 end,"paused teleport cleanup")
			check(not ra.rocks and rb.rocks~=nil,"teleport cleanup runs during card pause and preserves peer")
			ra.cards=nil;rootA.CFrame=CFrame.new(center+Vector3.new(-10,4,0))
			ra.weapons.rocks=1;ra.rocks=nil;target(rootA.Position.X+7,0,12)
			local kills,gained=ra.kills,ra.gems;fireWeapons(ra,rootA,0);send()
			check(ra.kills==kills+1 and not alive[1],"lethal rock contact awards exactly one kill")
			rootA.Position+=Vector3.new(7,0,0);step(1/H.SimRate);send()
			check(ra.gems==gained+1,"real pickup awards exactly one gem after rock kill")
			-- Optional actual client motion review, anchored on existing Map1.
			rootA.CFrame=CFrame.new(center+Vector3.new(-10,4,0));rootB.CFrame=CFrame.new(center+Vector3.new(10,4,0))
			ra.weapons.rocks=5;rb.weapons.rocks=1;publish(ra);publish(rb)
			bridge:InvokeClient(a,"review");bridge:InvokeClient(b,"review")
			Shared:SetAttribute("GAME12RocksProgress","review")
			local stop=os.clock()+math.clamp(rocksTestArgs.reviewSeconds or 0,0,60)
			repeat fireWeapons(ra,rootA,1/H.SimRate);fireWeapons(rb,rootB,1/H.SimRate);task.wait(1/H.SimRate) until os.clock()>=stop
			report.review={a=snapshot(a),b=snapshot(b)}
			Shared:SetAttribute("GAME12RocksProgress","cleanup")
			endRun(a);send();waitFor(function() return snapshot(b).rocks==2 end,"one run end")
			check(not ra.rocks and snapshot(b).rocks==2,"ending one run removes only its stones")
			local oldCharacter=a.Character;a:LoadCharacter();waitFor(function() return a.Character~=oldCharacter and a.Character:FindFirstChild("HumanoidRootPart") end,"respawn")
			ra,rootA=prepare(a,-10);ra.weapons={rocks=1};ra.wOrder={"rocks"};publish(ra);fireWeapons(ra,rootA,0);send()
			waitFor(function() return snapshot(a).rocks==4 end,"new run")
			check(snapshot(a).rocks==4,"new character/run creates one fresh orbit")
			bridge:InvokeClient(b,"leave");waitFor(function() return b.Parent~=Players end,"peer disconnect")
			send();waitFor(function() return snapshot(a).rocks==2 end,"departed visuals")
			check(runs[b]==nil and snapshot(a).rocks==2,"real departure releases peer orbit and preserves survivor")
			ra.hum.Health=0;waitFor(function() return runs[a]==nil end,"death");send()
			waitFor(function() return snapshot(a).rocks==0 end,"final cleanup")
			check(not ra.rocks and snapshot(a).rocks==0,"death clears final server/client orbit")
			check(#errors==0 and #snapshot(a).errors==0 and #report.review.b.errors==0,"zero captured Goblin errors")
		end,debug.traceback)
		report.ok,report.error=ok,if ok then nil else tostring(err);finish(report)
	end)
end

-- GAME-24 same-scene broadcast/interest comparison and real-client lifecycle acceptance.
if networkTestArgs then
	local sts=game:GetService("StudioTestService")
	local bridge=Instance.new("RemoteFunction");bridge.Name,bridge.Parent="GAME24Network",Shared
	local ready,errors={},{}
	bridge.OnServerInvoke=function(player) ready[player]=true;return true end
	Players.PlayerRemoving:Connect(function(player) ready[player]=nil end)
	game:GetService("ScriptContext").Error:Connect(function(message,_,source)
		if source and source.Name:find("Goblin",1,true) then table.insert(errors,message) end
	end)
	local report={checks={},phases={},errors=errors,quick=networkTestArgs.quick==true,enter=H.ViewEnter,leave=H.ViewLeave,
		baseline="original dense broadcast sender; same simulation and frozen test scene",renderContext="background; not device FPS"}
	local finished=false
	local function finish()
		if finished then return end
		finished=true;networkSample=nil;sts:EndTest(report)
	end
	task.delay(900,function() report.ok=false;report.error="GAME24 deadline";finish() end)
	local function waitFor(fn,label)
		local deadline=os.clock()+60
		repeat if fn() then return end;task.wait(0.05) until os.clock()>deadline
		error("GAME24 timeout: "..label)
	end
	local function check(value,label) assert(value,label);table.insert(report.checks,label) end
	local function snapshot(player) return bridge:InvokeClient(player,"snapshot") end
	local function deliver() send();task.wait(0.35) end
	local function percentiles(values)
		table.sort(values)
		return {n=#values,p50=values[math.ceil(#values*.5)] or 0,p95=values[math.ceil(#values*.95)] or 0,max=values[#values] or 0}
	end
	task.spawn(function()
		local ok,err=xpcall(function()
			networkManual=true
			waitFor(function()
				if #Players:GetPlayers()~=2 then return false end
				for _,p in Players:GetPlayers() do if not ready[p] or not p.Character or not p.Character:FindFirstChild("HumanoidRootPart") then return false end end
				return true
			end,"two clients ready")
			Workspace:SetAttribute("Arena","Map1")
			local center=assert(arena())
			report.map1Instances=#Workspace.Map1:GetDescendants()
			local list=Players:GetPlayers();table.sort(list,function(a,b) return a.UserId<b.UserId end)
			local a,b=list[1],list[2]
			local function place(player,x,z)
				local root=player.Character.HumanoidRootPart
				root.Anchored=true;root.CFrame=CFrame.new(center+Vector3.new(x,4,z or 0))
			end
			local function prepare(player,x)
				waitFor(function() return ready[player] and player.Character and player.Character:FindFirstChild("HumanoidRootPart") end,"new client ready")
				place(player,x)
				local hum=player.Character:FindFirstChildOfClass("Humanoid")
				local shield=Instance.new("ForceField");shield.Visible=false;shield.Parent=player.Character
				if not runs[player] then startRun(player,hum) end
				local run=runs[player];run.weapons,run.wOrder={},{};run.next=1e9;publish(run)
			end
			prepare(a,-120);prepare(b,120)
			local function clearWorld()
				while count>0 do kill(top) end
				table.clear(free);table.clear(gems);table.clear(grid)
				table.clear(dead);table.clear(deathEvents);table.clear(taken);table.clear(pickedPositions)
				table.clear(hitLog);table.clear(hitVersions);override=0
			end
			local function target(slot,x,z)
				if not alive[slot] then count+=1 end
				top=math.max(top,slot);alive[slot]=true
				px[slot],pz[slot],hp[slot]=center.X+x,center.Z+z,1e8
				generation[slot]=(generation[slot] or 0)+1
				kvx[slot],kvz[slot],stunUntil[slot],slowUntil[slot],nextSwing[slot],swingAt[slot]=0,0,0,0,0,nil
			end
			if not report.quick then
				for repeatIndex=1,2 do
					for _,population in {100,1000} do
						for _,layout in {"clustered","separated"} do
							local modes=if repeatIndex==1 then {"broadcast","nearby"} else {"nearby","broadcast"}
							for _,mode in modes do
								networkManual=true;networkSample=nil;networkMode=mode;clearWorld();table.clear(views)
								local spread=if layout=="separated" then 120 else 4
								place(a,-spread);place(b,spread)
								for slot=1,population do
									local group=if slot<=population/2 then -spread else spread
									local angle=slot*2.3999632297
									target(slot,group+math.cos(angle)*20,math.sin(angle)*20)
								end
								override=population;networkManual=false
								Shared:SetAttribute("GAME24Progress",mode.."-"..layout.."-"..population.."-"..repeatIndex)
								task.wait(5)
								bridge:InvokeClient(a,"begin");bridge:InvokeClient(b,"begin")
								local sample={bytes={},step={},send={}};networkSample=sample
								local began=os.clock();task.wait(15);local elapsed=os.clock()-began
								networkSample=nil
								local clients={bridge:InvokeClient(a,"finish"),bridge:InvokeClient(b,"finish")}
								local expected=if mode=="broadcast" or layout=="clustered" then population else population/2
								for index,p in list do
									check(clients[index].visual.count==expected,"phase visible count "..mode.."/"..layout.."/"..population.."/"..index)
									check(#clients[index].errors==0,"phase client error free")
									local serverBytes=sample.bytes[p] or 0
									check(math.abs(clients[index].bytes-serverBytes)/math.max(serverBytes,1)<.1,"client/server payload agrees within ten percent")
									clients[index].serverBytes=serverBytes
								end
								table.insert(report.phases,{repeatIndex=repeatIndex,population=population,layout=layout,mode=mode,
									seconds=elapsed,stepMs=percentiles(sample.step),sendMs=percentiles(sample.send),clients=clients})
							end
						end
					end
				end
			end
			networkManual=true;networkMode="nearby";clearWorld();table.clear(views)
			Shared:SetAttribute("GAME24Progress","lifecycle")
			place(a,-120);place(b,120);target(1,-120,0);target(2,120,0);deliver()
			waitFor(function() return snapshot(a).count==1 and snapshot(b).count==1 end,"initial client snapshots")
			report.initial={a=snapshot(a),b=snapshot(b),aPosition=tostring(a.Character.HumanoidRootPart.Position),bPosition=tostring(b.Character.HumanoidRootPart.Position),top=top,count=count,center=tostring(center)}
			check(snapshot(a).count==1 and snapshot(b).count==1,"two separated clients receive their own nearby enemy")
			-- Radius edges and teleport, including repeated visibility changes without pool growth.
			clearWorld();target(1,0,0);place(a,-250);deliver()
			check(snapshot(a).count==0,"outside enter radius hidden")
			place(a,-191);deliver();check(snapshot(a).count==1,"entry appears")
			place(a,-220);deliver();check(snapshot(a).count==1,"hysteresis retained")
			place(a,-225);deliver();check(snapshot(a).count==0,"exit removed")
			local poolBefore=snapshot(a).models
			for _=1,20 do place(a,0);deliver();place(a,-250);deliver() end
			check(snapshot(a).count==0 and snapshot(a).models<=math.max(poolBefore,1),"twenty visibility cycles leave no stale model or growing pool")
			place(a,0);deliver()
			local oldGeneration=generation[1]
			kill(1);target(1,40,0);deliver()
			local current=snapshot(a)
			check(current.slots["1"].incarnation==generation[1] and current.slots["1"].x==center.X+40,"silent slot reuse has fresh identity and position")
			local death=buffer.create(6);buffer.writeu16(death,0,1);buffer.writeu32(death,2,oldGeneration)
			local hitPacket,versionPacket=buffer.create(4),buffer.create(4)
			buffer.writeu16(hitPacket,0,1);buffer.writeu16(hitPacket,2,32775);buffer.writeu32(versionPacket,0,oldGeneration)
			local swingPacket=buffer.create(2);buffer.writeu16(swingPacket,0,1)
			died:FireClient(a,death,true);hits:FireClient(a,hitPacket,versionPacket);swingsOut:FireClient(a,swingPacket,versionPacket)
			task.wait(.3);local after=snapshot(a)
			check(after.count==1 and after.events.deaths==current.events.deaths and after.events.hits==current.events.hits and after.events.swings==current.events.swings,"stale death/hit/swing cannot affect reused slot")
			buffer.writeu32(versionPacket,0,generation[1])
			hits:FireClient(a,hitPacket,versionPacket);swingsOut:FireClient(a,swingPacket,versionPacket)
			task.wait(.25);local valid=snapshot(a)
			check(valid.events.hits==after.events.hits+1 and valid.events.swings==after.events.swings+1,"current-incarnation hit and swing each render once")
			-- A visible death and two different incarnations killed before the next send.
			clearWorld();place(a,0);place(b,4);target(1,10,0);deliver()
			local beforeA,beforeB=snapshot(a),snapshot(b)
			local gem1=nextGem;local killsBefore=runs[a].kills
			kill(1,runs[a]);target(1,11,0);kill(1,runs[a]);deliver()
			after=snapshot(a)
			check(after.events.deaths==beforeA.events.deaths+1 and snapshot(b).events.deaths==beforeB.events.deaths+1,"each client animates only the incarnation it actually saw")
			check(after.gems[tostring(gem1)] and after.gems[tostring((gem1+1)%65536)] and runs[a].kills==killsBefore+2,"both kills retain distinct authoritative gems and credit")
			-- Hidden death remains collectable when the observer arrives later.
			clearWorld();place(a,-120);place(b,120);target(1,130,0);deliver()
			beforeA=snapshot(a);local hiddenGem=nextGem;kill(1,runs[b]);deliver()
			after=snapshot(a);check(after.events.deaths==beforeA.events.deaths and not after.gems[tostring(hiddenGem)],"hidden death has no stale observer corpse/gem")
			place(a,115);deliver();check(snapshot(a).gems[tostring(hiddenGem)]~=nil,"teleport/entry recovers an existing gem without replaying death")
			place(b,-120);place(a,130);local gained=runs[a].gems
			step(1/H.SimRate);deliver();task.wait(.3)
			check(runs[a].gems==gained+1 and not snapshot(a).gems[tostring(hiddenGem)],"arriving player collects hidden-death gem exactly once")
			-- Birth and pickup in one send interval still render one pickup effect.
			clearWorld();place(a,0);target(1,1,0);deliver();beforeA=snapshot(a);gained=runs[a].gems
			kill(1,runs[a]);step(1/H.SimRate);deliver();task.wait(.3);after=snapshot(a)
			check(after.events.pickups==beforeA.events.pickups+1 and next(after.gems)==nil and runs[a].gems==gained+1,"same-interval kill/pickup renders once and leaves no gem")
			-- Receiver restart on the same player: explicit handshake resends identities and drops.
			clearWorld();target(1,10,0);kill(1,runs[a]);target(1,20,0);deliver()
			local persistentGem=(nextGem-1)%65536
			bridge:InvokeClient(a,"resync");task.wait(.4);deliver();after=snapshot(a)
			check(after.slots["1"] and after.gems[tostring(persistentGem)],"receiver resync restores existing enemy and gem")
			-- Real departure, late join, then another fresh connection using StudioTestService.
			local oldPeer=b;bridge:InvokeClient(b,"leave")
			waitFor(function() return oldPeer.Parent~=Players end,"peer leave")
			check(views[oldPeer]==nil and runs[oldPeer]==nil,"disconnect releases per-player view and run state")
			for joinIndex=1,2 do
				sts:AddPlayers(1)
				waitFor(function() return #Players:GetPlayers()==2 end,"replacement connection")
				local joined
				for _,p in Players:GetPlayers() do if p~=a then joined=p end end
				prepare(joined,0);deliver()
				local state
				waitFor(function()
					state=snapshot(joined)
					return state.slots["1"] and state.gems[tostring(persistentGem)]
				end,"fresh connection snapshot "..joinIndex)
				check(state.slots["1"] and state.gems[tostring(persistentGem)],"fresh connection "..joinIndex.." gets existing enemy and gem")
				check(#state.errors==0,"fresh connection error free")
				if joinIndex==1 then
					bridge:InvokeClient(joined,"leave");waitFor(function() return joined.Parent~=Players end,"late join leave")
					check(views[joined]==nil,"late join state released before next connection")
				else b=joined end
			end
			for player in views do check(player.Parent==Players,"no departed player view reference") end
			clearWorld();deliver()
			check(snapshot(a).count==0 and next(snapshot(a).gems)==nil and snapshot(b).count==0 and next(snapshot(b).gems)==nil,"final snapshot clears enemies and gems on both clients")
			check(#errors==0 and #snapshot(a).errors==0 and #snapshot(b).errors==0,"no Goblin script errors")
		end,debug.traceback)
		report.ok,report.error=ok,if ok then nil else tostring(err)
		finish()
	end)
end

if RunService:IsStudio() then -- load-test controls; never in a live server
	local ctl = remote("Horde")
	ctl.OnServerEvent:Connect(function(_, n)
		if typeof(n) == "number" then
			override = if n > 0 then math.clamp(math.floor(n), 1, 3000) else nil -- 0 = back to the run's own size
		end
	end)
	while true do
		task.wait(1)
		ctl:SetAttribute("Count", count)
		ctl:SetAttribute("Target", override or count)
		ctl:SetAttribute("SimMs", simTime / statAcc * 1000 / H.SimRate) -- per step
		ctl:SetAttribute("KBps", sentBytes / statAcc / 1024) -- per client
		simTime, sentBytes, statAcc = 0, 0, 0
	end
end
