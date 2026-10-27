-- GoblinHorde (Script, ServerScriptService)
-- Megabonk-style horde: hundreds of goblins that are plain data on the server (position, health), not Humanoids.
-- Every step they run at the nearest player and push apart (spatial hash); one that reaches a player stops and swings
-- (clients play Attack1) and the hit lands after a wind-up, only if the player is still in reach. A weapon hit slows
-- a goblin; most also stun it briefly (cancelling a wind-up) and, with the Force passive, knock it back.
-- SendRate times a second all clients get one buffer of {x, z} per slot (4 bytes; the slot number is implicit, free
-- slots are a sentinel, and the client works out facing from movement) plus the slots that died; GoblinHordeClient
-- draws pooled client-only models from that (the single-mesh Goblin.HordeModel).
-- No physics, no pathfinding: the arena (workspace.StressZone for now) is open and flat at y = 0. Humanoid goblins
-- (GoblinAI) stay for elites.
-- Runs: entering the arena starts one (PlayPad by the spawn teleports there). Weapons (Config.Weapons) fire on
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

-- Goblins live in stable slots (parallel arrays): a slot keeps its number for life, so snapshots needn't carry ids.
-- Freed slots are reused first, which keeps `top` (the highest live slot, i.e. the snapshot length) near the count.
local alive, px, pz, hp = {}, {}, {}, {}
local swingAt, nextSwing = {}, {} -- wind-up start (nil = not swinging) and earliest next swing, per slot
local kvx, kvz, stunUntil, slowUntil = {}, {}, {}, {} -- knockback velocity (fades), stun and slow end times, per slot
local swings = {} -- slots that started a swing this step (sent at once, not with the 10 Hz snapshot)
local free, top, count, override = {}, 0, 0, nil :: number?
local dead, deadFirstGem = {}, 0 -- slots killed since the last send; each dropped gem number deadFirstGem + k - 1
local gems, nextGem = {}, 0 -- gem number -> {x, z}
local rng = Random.new()
local NONE = -32768 -- x of a free slot in a snapshot
local runs = {} -- Player -> run state

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
		gems[nextGem] = { x = px[i], z = pz[i] }
		nextGem = (nextGem + 1) % 65536
	end
	while top > 0 and not alive[top] do
		top -= 1
	end
end

local function arena(): (Vector3?, number)
	local zone = Workspace:FindFirstChild("StressZone")
	if not zone then
		return nil, 0
	end
	return zone:GetAttribute("Center"), zone:GetAttribute("Size") / 2 - 2
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
	local run = runs[player]
	if not run then
		return
	end
	runs[player] = nil
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
	local center = arena()
	if runs[player] or not center then
		return
	end
	player:LoadCharacter()
	if player.Character then
		player.Character:PivotTo(CFrame.new(center + Vector3.new(0, 4, 0)))
	end
end)

toLobby.OnServerEvent:Connect(function(player)
	if not runs[player] then
		player:LoadCharacter()
	end
end)

Players.PlayerRemoving:Connect(function(player)
	runs[player] = nil
end)

-- A glowing pad beside the spawn that sends you into the arena.
do
	local pad = Instance.new("Part")
	pad.Name = "PlayPad"
	pad.Anchored, pad.CanCollide = true, false
	pad.Size, pad.Position = Vector3.new(6, 0.4, 6), Vector3.new(11, 1.2, 10)
	pad.Material, pad.Color = Enum.Material.Neon, Color3.fromRGB(255, 210, 90)
	local label = Instance.new("BillboardGui")
	label.Size, label.StudsOffset, label.AlwaysOnTop = UDim2.fromOffset(160, 50), Vector3.new(0, 3, 0), true
	local text = Instance.new("TextLabel")
	text.Size, text.BackgroundTransparency, text.Text = UDim2.fromScale(1, 1), 1, "PLAY"
	text.FontFace, text.TextScaled = Font.fromEnum(Enum.Font.FredokaOne), true
	text.TextColor3, text.TextStrokeTransparency = Color3.new(1, 1, 1), 0
	text.Parent = label
	label.Parent = pad
	pad.Parent = Workspace
	local busy = {}
	pad.Touched:Connect(function(hit)
		local char = hit.Parent
		local player = char and Players:GetPlayerFromCharacter(char)
		local center = arena()
		if player and center and not busy[player] then
			busy[player] = true
			char:PivotTo(CFrame.new(center + Vector3.new(0, 4, 0)))
			task.delay(1, function()
				busy[player] = nil
			end)
		end
	end)
end

---------------------------------------------------------------- weapons

local hitLog = {} -- Player -> {slot, damage, ...} for floating numbers, sent with the snapshot; +32768 = it stunned
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

local function fireWeapons(run, root: BasePart, dt: number)
	local pos = root.Position
	local haste = 1 - math.min(run.bonus.haste, 0.6)
	local might = 1 + run.bonus.might
	local area = 1 + run.bonus.area
	for id, lv in run.weapons do
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
		swingsOut:FireAllClients(b)
		table.clear(swings)
	end

	-- Weapons, fireballs, gem pickup.
	for _, t in targets do
		if t.run then
			fireWeapons(t.run, t.root, dt)
		end
	end
	moveShots(dt)
	for g, gem in gems do
		for _, t in targets do
			if t.run then
				local p = t.root.Position
				local reach = R.PickupRange * (1 + t.run.bonus.magnet)
				if (gem.x - p.X) ^ 2 + (gem.z - p.Z) ^ 2 < reach * reach then
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
			kvx[i], kvz[i], stunUntil[i], slowUntil[i] = 0, 0, 0, 0
			px[i] = math.clamp(t.X + math.cos(a) * r, center.X - half, center.X + half)
			pz[i] = math.clamp(t.Z + math.sin(a) * r, center.Z - half, center.Z + half)
		end
	end
	while count > target do
		kill(top)
	end
	if not longest then -- nobody playing: sweep leftover gems
		table.clear(gems)
	end
end

local function send(): number
	if #dead > 0 then -- before the snapshot, so the client knows these are deaths and not just gone
		local b = buffer.create(2 + #dead * 2)
		buffer.writeu16(b, 0, deadFirstGem)
		for k, i in dead do
			buffer.writeu16(b, k * 2, i)
		end
		died:FireAllClients(b)
		table.clear(dead)
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

-- GAME-23: opt-in measurement only; normal Studio/production runs do not allocate samples.
local benchmarkArgs, benchmarkSample
if RunService:IsStudio() then
	local ok, args = pcall(function() return game:GetService("StudioTestService"):GetTestArgs() end)
	if ok and typeof(args) == "table" and args.name == "GAME23Baseline" then
		benchmarkArgs = args
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
		step(1 / H.SimRate)
		local elapsed = os.clock() - t0
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
		sentBytes += bytes
		if benchmarkSample then
			table.insert(benchmarkSample.send,(os.clock()-t0)*1000)
			benchmarkSample.bytes += bytes
		end
	end
end)

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
			for _,p in list do runs[p].wOrder={} end
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
