-- GoblinHordeClient (LocalScript, StarterPlayer.StarterPlayerScripts)
-- Draws the GoblinHorde goblins: each snapshot gives {x, z} per slot; every frame the pooled client-only models ease
-- toward their latest position and face the nearest player (also while knocked back); all roots move in one
-- BulkMoveTo. Each model runs its own Run loop and plays Attack1 when the server says it swings; a death plays the
-- shortened Death fall in place (off the slot, which the server may refill at once), then returns to the pool.
-- The model is Goblin.HordeModel, the single-mesh goblin (BuildHordeModel.luau); without it, the 17-part
-- Goblin.HordeSource is used as-is.
-- Also draws the run's effects: XP gems where goblins die (fly to whoever picks them up), floating damage numbers for
-- your own hits (a stunning hit also flinches that goblin and flashes a white outline around it; Fire Ring burns
-- don't), sword slashes, fireballs and every player's Fire Ring.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Goblin")
local networkObserved = if RunService:IsStudio() and Shared:GetAttribute("GAME24Active")
	then {deaths=0,hits=0,swings=0,pickups=0} else nil
local Config = require(Shared:WaitForChild("GoblinConfig"))
local template = Shared:FindFirstChild("HordeModel") or Shared:WaitForChild("HordeSource")
local HIP_Y = template:GetPivot().Position.Y
local HIDDEN = CFrame.new(0, -1000, 0)
local NONE = -32768 -- x of a free slot
local SMOOTH = 12 -- how fast a model catches up with the latest snapshot (1/s)

local folder = Instance.new("Folder")
folder.Name = "Horde"
folder.Parent = Workspace

local function animation(name: string): Animation
	local a = Instance.new("Animation")
	a.AnimationId = Config.Animations[name]
	return a
end
local RUN, DEATH, SWING, FLINCH = animation("Run"), animation("Death"), animation("Attack1"), animation("HitFront")

local pool, live = {}, {} -- live: slot -> entry

local function acquire()
	local e = table.remove(pool)
	if not e then
		local m = template:Clone()
		local fadeParts = {}
		for _, part in m:GetDescendants() do -- client-only: the player must never stand on or bump into one
			if part:IsA("BasePart") then
				part.CanCollide, part.CanTouch = false, false
				table.insert(fadeParts, part)
			end
		end
		m.Parent = folder
		local animator = m:FindFirstChildOfClass("AnimationController"):FindFirstChildOfClass("Animator")
		e = { root = m:FindFirstChild("HumanoidRootPart"), run = animator:LoadAnimation(RUN), death = animator:LoadAnimation(DEATH), swing = animator:LoadAnimation(SWING), flinch = animator:LoadAnimation(FLINCH) }
		e.fadeParts = fadeParts
		e.run.Looped = true
		e.run.Priority = Enum.AnimationPriority.Movement
		e.death.Priority, e.swing.Priority, e.flinch.Priority = Enum.AnimationPriority.Action, Enum.AnimationPriority.Action, Enum.AnimationPriority.Action2
	end
	e.run:Play(0)
	e.run:AdjustSpeed(Config.Horde.Speed / Config.AI.RunSpeed) -- the Run clip is paced for RunSpeed
	return e
end

local function recycle(e)
	e.run:Stop(0)
	e.death:Stop(0)
	e.swing:Stop(0)
	e.flinch:Stop(0)
	e.root.CFrame = HIDDEN
	for _, part in e.fadeParts do part.LocalTransparencyModifier = 0 end
	table.insert(pool, e)
end

-- Keep the authored fall (BodyFall at 1.1 s), skip the long hold/dissolve tail.
-- A bounded queue replaces one delayed callback per kill. Retire the oldest corpse
-- on overflow; no callback can later recycle a model that has already been reused.
local deathLength, DEATH_SPEED, DEATH_FADE, MAX_CORPSES = 0.6, 2.5, 0.15, 64
local corpses = {}
local function advanceDeaths(now)
	for i = #corpses, 1, -1 do
		local e = corpses[i]
		local left = e.deathUntil - now
		if left <= 0 then
			table.remove(corpses, i)
			recycle(e)
		elseif left < DEATH_FADE then
			for _, part in e.fadeParts do part.LocalTransparencyModifier = 1 - left / DEATH_FADE end
		end
	end
end
local function beginDeath(e, now)
	if #corpses >= MAX_CORPSES then recycle(table.remove(corpses, 1)) end
	e.run:Stop(0)
	e.swing:Stop(0)
	e.flinch:Stop(0) -- Action2 must not mask the fall after the killing hit.
	e.death:Play(0.04, 1, DEATH_SPEED)
	e.deathUntil = now + deathLength
	table.insert(corpses, e)
end
RunService.Heartbeat:Connect(function() advanceDeaths(os.clock()) end)

local function free(slot: number)
	local e = live[slot]
	if e then
		live[slot] = nil
		recycle(e)
	end
end

local roots = {} -- every player's root this snapshot: goblins always face the nearest one
Shared:WaitForChild("HordeSnap").OnClientEvent:Connect(function(b: buffer, mask: buffer?, identities: buffer?)
	local n = buffer.readu16(b, 0)
	local births = {}
	if identities then
		for offset=0,buffer.len(identities)-6,6 do
			births[buffer.readu16(identities,offset)]=buffer.readu32(identities,offset+2)
		end
	end
	table.clear(roots)
	for _, pl in Players:GetPlayers() do
		local r = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
		if r then
			table.insert(roots, r.Position)
		end
	end
	local o = 2
	for slot = 1, n do
		if mask and bit32.band(buffer.readu8(mask,(slot-1)//8),bit32.lshift(1,(slot-1)%8))==0 then
			free(slot)
			continue
		end
		local xi = buffer.readi16(b, o)
		local zi = buffer.readi16(b, o+2)
		o += 4
		if xi == NONE then
			free(slot) -- despawned without dying (deaths left the slot already)
			continue
		end
		local x, z = xi / 8, zi / 8
		local e = live[slot]
		if e and births[slot]~=nil and e.incarnation~=births[slot] then
			free(slot); e=nil -- a silently despawned/reused slot must not inherit its old model state
		end
		if not e then
			e = acquire()
			e.x, e.z, e.tx, e.tz, e.yaw, e.tyaw = x, z, x, z, 0, 0
			e.incarnation = births[slot] or 0
			live[slot] = e
		end
		local best, dx, dz = math.huge, 0, 0
		for _, p in roots do
			local ox, oz = p.X - x, p.Z - z
			if ox * ox + oz * oz < best then
				best, dx, dz = ox * ox + oz * oz, ox, oz
			end
		end
		if best > 0.01 and best < math.huge then
			e.tyaw = math.atan2(-dx, -dz) -- Roblox looks down -Z
		end
		e.tx, e.tz = x, z
	end
	for slot in live do
		if slot > n then
			free(slot)
		end
	end
end)

-- Effects: small pools of anchored, non-colliding parts.
local function fxPart(size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material, p.Size, p.Color, p.Shape = Enum.Material.Neon, size, color, shape or Enum.PartType.Block
	p.Parent = folder
	return p
end
local function pooled(list, make)
	return table.remove(list) or make()
end

local gemPool, gems = {}, {} -- gem number -> part
local GEM_Y = 1.2
local function dropGem(g: number, x: number, z: number)
	local p = gems[g] or pooled(gemPool, function()
		return fxPart(Vector3.one * 0.8, Color3.fromRGB(95, 208, 255))
	end)
	p.CFrame = CFrame.new(x, GEM_Y, z) * CFrame.Angles(math.rad(45), 0, math.rad(45))
	gems[g] = p
end

Shared:WaitForChild("HordeGemState").OnClientEvent:Connect(function(added: buffer, removed: buffer)
	for offset=0,buffer.len(removed)-2,2 do
		local id=buffer.readu16(removed,offset)
		local part=gems[id]
		if part then gems[id]=nil; part.CFrame=HIDDEN; table.insert(gemPool,part) end
	end
	for offset=0,buffer.len(added)-6,6 do
		dropGem(buffer.readu16(added,offset),buffer.readi16(added,offset+2)/8,buffer.readi16(added,offset+4)/8)
	end
end)

Shared:WaitForChild("HordeDied").OnClientEvent:Connect(function(b: buffer, versioned: boolean?)
	local firstGem = if versioned then 0 else buffer.readu16(b, 0)
	local stride = if versioned then 6 else 2
	for o = (if versioned then 0 else 2), buffer.len(b) - stride, stride do
		local slot = buffer.readu16(b, o)
		local e = live[slot]
		if e and (not versioned or e.incarnation==buffer.readu32(b,o+2)) then
			if networkObserved then networkObserved.deaths+=1 end
			if not versioned then dropGem((firstGem + o / 2 - 1) % 65536, e.x, e.z) end
			live[slot] = nil -- stays where it fell: only live models get moved
			beginDeath(e, os.clock())
		end
	end
end)

Shared:WaitForChild("HordeSwing").OnClientEvent:Connect(function(b: buffer, identities: buffer?)
	for o = 0, buffer.len(b) - 2, 2 do
		local e = live[buffer.readu16(b, o)]
		if e and (not identities or e.incarnation==buffer.readu32(identities,o*2)) then
			if networkObserved then networkObserved.swings+=1 end
			e.swing:Play(0.05) -- the server lands the hit at AttackWindup, around this clip's HitStart
		end
	end
end)

Shared:WaitForChild("HordeGems").OnClientEvent:Connect(function(player: Player, b: buffer, positions: buffer?)
	local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	for o = 0, buffer.len(b) - 2, 2 do
		local g = buffer.readu16(b, o)
		if not gems[g] and positions then
			dropGem(g,buffer.readi16(positions,o*2)/8,buffer.readi16(positions,o*2+2)/8)
		end
		local p = gems[g]
		if p then
			if networkObserved then networkObserved.pickups+=1 end
			gems[g] = nil
			local tween = TweenService:Create(p, TweenInfo.new(0.2), { CFrame = if root then root.CFrame else p.CFrame })
			tween.Completed:Once(function()
				p.CFrame = HIDDEN
				table.insert(gemPool, p)
			end)
			tween:Play()
		end
	end
end)

-- White hit flash around the goblin's silhouette. Roblox draws at most 31 Highlights at once, so a small pool, each lit
-- for FLASH seconds; a hit with none free just skips the flash.
local FLASH = 0.12
local flashPool = {}
for _ = 1, 24 do
	local h = Instance.new("Highlight")
	h.FillColor, h.OutlineColor = Color3.new(1, 1, 1), Color3.new(1, 1, 1)
	h.FillTransparency, h.OutlineTransparency = 0.55, 0
	h.DepthMode, h.Enabled = Enum.HighlightDepthMode.Occluded, false
	h.Parent = folder
	table.insert(flashPool, h)
end
local function flash(model: Model)
	local h = table.remove(flashPool)
	if h then
		h.Adornee, h.Enabled = model, true
		task.delay(FLASH, function()
			h.Enabled, h.Adornee = false, nil
			table.insert(flashPool, h)
		end)
	end
end

-- Floating numbers for the local player's hits: {slot, damage} pairs; damage >= 32768 marks a stunning hit.
local numberPool = {}
local swordImpact -- (goblin entries) -> hit sparks, freeze, camera kick; defined with the slash code below
local lastSlash = 0 -- os.clock() of the local player's last sword slash
Shared:WaitForChild("HordeHits").OnClientEvent:Connect(function(b: buffer, identities: buffer?)
	local struck = {}
	for o = 0, buffer.len(b) - 4, 4 do
		local e = live[buffer.readu16(b, o)]
		if not e or (identities and e.incarnation~=buffer.readu32(identities,o)) then
			continue
		end
		table.insert(struck, e)
		if networkObserved then networkObserved.hits+=1 end
		local value = buffer.readu16(b, o + 2)
		if value >= 32768 then -- stunned: the server cancelled its wind-up
			e.swing:Stop(0.05)
			e.flinch:Play(0.05)
			flash(e.root.Parent)
		end
		local n = pooled(numberPool, function()
			local anchor = fxPart(Vector3.one * 0.1, Color3.new(), nil)
			anchor.Transparency = 1
			local gui = Instance.new("BillboardGui")
			gui.Size, gui.AlwaysOnTop = UDim2.fromOffset(60, 30), true
			local label = Instance.new("TextLabel")
			label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
			label.FontFace, label.TextSize = Font.fromEnum(Enum.Font.FredokaOne), 22
			label.TextColor3, label.TextStrokeColor3, label.TextStrokeTransparency = Color3.fromRGB(255, 226, 122), Color3.fromRGB(74, 42, 16), 0
			label.Parent = gui
			gui.Parent = anchor
			return { anchor = anchor, gui = gui, label = label }
		end)
		n.label.Text = tostring(value % 32768)
		n.label.TextTransparency, n.label.TextStrokeTransparency = 0, 0
		local start = CFrame.new(e.x + math.random() - 0.5, HIP_Y + 2.5, e.z + math.random() - 0.5)
		n.anchor.CFrame = start
		TweenService:Create(n.anchor, TweenInfo.new(0.6), { CFrame = start + Vector3.new(0, 2.5, 0) }):Play()
		local fade = TweenService:Create(n.label, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 })
		fade.Completed:Once(function()
			table.insert(numberPool, n)
		end)
		fade:Play()
	end
	-- Hits carry no weapon, so the ones landing right after the local player's slash count as sword hits
	if #struck > 0 and os.clock() - lastSlash < 0.35 then
		swordImpact(struck)
	end
end)

-- Weapon effects. Slash: a crescent (a Beam bent into a circular arc around the player) whose head sweeps the arc in
-- SWEEP seconds while its tail follows CLOSE seconds behind and closes it; sparks fly off the end, and it alternates
-- direction each swing. The arc is rebuilt from angles every frame, so it stays smooth at any frame rate.
-- Fireball: flies straight to its range.
local SWEEP, CLOSE = 0.12, 0.1
local sweepPool, balls, ballPool = {}, {}, {}
local swingSide = {} -- Player -> 1 / -1, flipped every slash
local function keys(...)
	local k = {}
	for i, v in { ... } do
		k[i] = NumberSequenceKeypoint.new(v[1], v[2])
	end
	return NumberSequence.new(k)
end
local function colors(...) -- ColorSequence from { time, r, g, b } stops
	local k = {}
	for i, v in { ... } do
		k[i] = ColorSequenceKeypoint.new(v[1], Color3.fromRGB(v[2], v[3], v[4]))
	end
	return ColorSequence.new(k)
end
-- How the slash looks at each sword level: the default sword skin (black blade, red deepening with the level, like
-- ReplicatedStorage.Swords); a future skin swaps this table. Every level adds one thing you can see:
-- Lv2 light (the edge glows), Lv3 echo (a second, smaller crescent right behind) + scorch (a burnt crescent left on the
-- ground), Lv4 wave (a red shockwave ring from the player; the back slash comes from Config), Lv5 glitter (embers
-- along the arc) + smoke (black puffs off the edge). width is the leading edge as a fraction of the range.
local SLASH_TIERS = {
	{ colors = colors({ 0, 40, 30, 34 }, { 0.8, 120, 40, 40 }, { 1, 235, 215, 210 }), width = 0.45, sparks = 4 },
	{
		colors = colors({ 0, 60, 20, 24 }, { 0.8, 180, 40, 40 }, { 1, 255, 225, 215 }),
		width = 0.6,
		sparks = 8,
		light = Color3.fromRGB(220, 40, 40),
	},
	{
		colors = colors({ 0, 80, 18, 22 }, { 0.8, 210, 40, 40 }, { 1, 255, 230, 220 }),
		width = 0.65,
		sparks = 10,
		echo = true,
		light = Color3.fromRGB(235, 45, 40),
		scorch = true,
	},
	{
		colors = colors({ 0, 110, 14, 20 }, { 0.75, 235, 45, 40 }, { 1, 255, 235, 225 }),
		width = 0.7,
		sparks = 14,
		echo = true,
		light = Color3.fromRGB(255, 60, 50),
		scorch = true,
		wave = true,
	},
	{
		colors = colors({ 0, 140, 10, 20 }, { 0.45, 255, 50, 40 }, { 0.8, 255, 150, 70 }, { 1, 255, 245, 230 }),
		width = 0.8,
		sparks = 22,
		echo = true,
		light = Color3.fromRGB(255, 90, 60),
		scorch = true,
		wave = true,
		glitter = Color3.fromRGB(255, 80, 40),
		smoke = true,
	},
}
local function swordTier(player: Player)
	local level = tonumber(string.match(player:GetAttribute("RunLoadout") or "", "sword=(%d+)")) or 1
	return SLASH_TIERS[math.clamp(level, 1, #SLASH_TIERS)]
end

-- Sword hit impact: a flash and sparks in the tier's red on each goblin hit, its run frozen for HITSTOP (a hit-stop
-- on the enemy only; the world keeps moving), and a camera kick for the attacker that grows with the goblins hit.
local HITSTOP = 0.06
-- One attachment per goblin hit in a batch: Emit spawns where the emitter is when particles next update, so moving a
-- single emitter between Emit calls in one frame would put every hit's sparks on the last goblin.
local impacts = {}
for i = 1, 8 do -- a crowd hit stays readable and cheap
	local at = Instance.new("Attachment")
	at.Parent = Workspace.Terrain
	local flash = Instance.new("ParticleEmitter")
	flash.Texture, flash.Rate, flash.LightEmission = Config.Textures.Burst, 0, 0.6
	flash.Size, flash.Lifetime, flash.Speed = keys({ 0, 1.4 }, { 1, 2.6 }), NumberRange.new(0.1, 0.14), NumberRange.new(0)
	flash.Transparency, flash.Rotation = keys({ 0, 0 }, { 1, 1 }), NumberRange.new(0, 360)
	flash.Parent = at
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture, sparks.Rate, sparks.LightEmission = Config.Textures.Spark, 0, 0.8
	sparks.Orientation = Enum.ParticleOrientation.VelocityParallel
	sparks.Size, sparks.Lifetime, sparks.Speed = keys({ 0, 0.35 }, { 1, 0 }), NumberRange.new(0.15, 0.3), NumberRange.new(12, 20)
	sparks.SpreadAngle, sparks.Acceleration, sparks.Drag = Vector2.new(180, 180), Vector3.new(0, -40, 0), 4
	sparks.Parent = at
	impacts[i] = { at = at, flash = flash, sparks = sparks }
end
swordImpact = function(struck)
	local red = swordTier(Players.LocalPlayer).colors.Keypoints[2].Value
	for i, e in struck do
		local fx = impacts[i]
		if not fx then
			break
		end
		fx.at.WorldPosition = Vector3.new(e.x, HIP_Y + 1.5, e.z)
		fx.flash.Color = ColorSequence.new(Color3.new(1, 1, 1), red)
		fx.sparks.Color = ColorSequence.new(Color3.fromRGB(255, 230, 200), red)
		fx.flash:Emit(1)
		fx.sparks:Emit(5)
		if e.run.Speed > 0 then
			e.hitstopSpeed = e.run.Speed
		end
		e.run:AdjustSpeed(0)
		task.delay(HITSTOP, function()
			e.run:AdjustSpeed(e.hitstopSpeed or Config.Horde.Speed / Config.AI.RunSpeed)
		end)
	end
	local hum = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		local kick = math.min(#struck, 4) * 0.06
		hum.CameraOffset = Vector3.new((math.random() * 2 - 1) * kick, (math.random() * 2 - 1) * kick, 0)
		task.delay(0.05, function()
			hum.CameraOffset = Vector3.zero
		end)
	end
end
local function newSweeper()
	local p = fxPart(Vector3.one * 0.2, Color3.new(1, 1, 1))
	p.Transparency = 1
	local tail, head = Instance.new("Attachment"), Instance.new("Attachment")
	tail.Parent, head.Parent = p, p
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = tail, head
	beam.Texture, beam.TextureMode = Config.Textures.Slash, Enum.TextureMode.Stretch
	-- No light emission: additive glow washed out on the pale arena floor
	beam.Segments, beam.FaceCamera, beam.LightEmission, beam.LightInfluence = 20, false, 0, 0
	beam.Transparency = keys({ 0, 1 }, { 0.6, 0.15 }, { 1, 0 })
	beam.Enabled = false
	beam.Parent = p
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture, sparks.Rate, sparks.LightEmission = Config.Textures.Spark, 0, 1
	sparks.Size = keys({ 0, 0.6 }, { 1, 0 })
	sparks.Lifetime, sparks.Speed = NumberRange.new(0.2, 0.35), NumberRange.new(8, 16)
	sparks.SpreadAngle, sparks.Drag = Vector2.new(60, 60), 5
	sparks.Parent = head
	-- Ink slash: one flat 4x4 flipbook crescent played over the finished arc (velocity up + VelocityPerpendicular = lies flat)
	local arc = Instance.new("ParticleEmitter")
	arc.Texture, arc.Rate, arc.LockedToPart = Config.Textures.SlashArc, 0, true
	arc.FlipbookLayout, arc.FlipbookMode = Enum.ParticleFlipbookLayout.Grid4x4, Enum.ParticleFlipbookMode.OneShot
	arc.EmissionDirection, arc.Orientation = Enum.NormalId.Top, Enum.ParticleOrientation.VelocityPerpendicular
	arc.Speed, arc.Lifetime = NumberRange.new(0.01), NumberRange.new(0.3)
	arc.Transparency = keys({ 0, 0 }, { 0.8, 0 }, { 1, 1 })
	arc.Parent = p
	-- Glitter (tiers with `glitter`): twinkles shed by the sweeping edge, left hanging along the arc
	local glitter = Instance.new("ParticleEmitter")
	glitter.Texture, glitter.Rate, glitter.LightEmission = Config.Textures.Spark, 0, 1
	glitter.Size = keys({ 0, 0 }, { 0.2, 1.2 }, { 1, 0 })
	glitter.Lifetime, glitter.Speed = NumberRange.new(0.4, 0.7), NumberRange.new(0.5, 2)
	glitter.SpreadAngle, glitter.Acceleration = Vector2.new(180, 180), Vector3.new(0, 2, 0)
	glitter.Rotation, glitter.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-180, 180)
	glitter.Parent = head
	-- Scorch (tiers with `scorch`): the same ink crescent, dark red and slow, left burnt on the ground after the slash
	local scorch = arc:Clone()
	scorch.Lifetime, scorch.Color = NumberRange.new(0.9), ColorSequence.new(Color3.fromRGB(70, 8, 8))
	scorch.Transparency = keys({ 0, 0.15 }, { 0.5, 0.35 }, { 1, 1 })
	scorch.Parent = p
	-- Shockwave (tiers with `wave`): a flat ring that races out from the player as the slash starts
	local wave = Instance.new("ParticleEmitter")
	wave.Texture, wave.Rate, wave.LockedToPart, wave.LightEmission = Config.Textures.SlashWave, 0, true, 0.4
	wave.EmissionDirection, wave.Orientation = Enum.NormalId.Top, Enum.ParticleOrientation.VelocityPerpendicular
	wave.Speed, wave.Lifetime = NumberRange.new(0.01), NumberRange.new(0.35)
	wave.Transparency = keys({ 0, 0.1 }, { 1, 1 })
	wave.Parent = p
	-- Smoke (tiers with `smoke`): black puffs shed by the sweeping edge, drifting up
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture, smoke.Rate, smoke.Color = Config.Textures.SlashSmoke, 0, ColorSequence.new(Color3.fromRGB(25, 15, 15))
	smoke.Size, smoke.Transparency = keys({ 0, 1 }, { 1, 2.6 }), keys({ 0, 0.35 }, { 1, 1 })
	smoke.Lifetime, smoke.Speed = NumberRange.new(0.6, 0.9), NumberRange.new(1, 3)
	smoke.SpreadAngle, smoke.Acceleration = Vector2.new(180, 180), Vector3.new(0, 4, 0)
	smoke.Rotation, smoke.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-60, 60)
	smoke.Parent = head
	local light = Instance.new("PointLight")
	light.Range, light.Brightness, light.Enabled = 10, 3, false
	light.Parent = head
	return { part = p, tail = tail, head = head, beam = beam, sparks = sparks, arc = arc, glitter = glitter, light = light, scorch = scorch, wave = wave, smoke = smoke }
end
local function easeOut(t: number): number
	t = math.clamp(t, 0, 1)
	return 1 - (1 - t) ^ 3
end
-- One sweep from angle `from` to `to` (radians in the XZ plane), following the player while it swings.
-- `ink` scales the ink crescent (nil = none, for the echo sweep).
local function sweep(root: BasePart, range: number, from: number, to: number, tier, ink: number?)
	local s = pooled(sweepPool, newSweeper)
	local t0, r, side, sparked = os.clock(), range * 0.65, math.sign(to - from), false
	s.beam.Width0, s.beam.Width1 = 0.15, range * tier.width -- thin tail, thick leading edge
	s.beam.Color, s.sparks.Color = tier.colors, tier.colors
	s.light.Enabled, s.light.Color = tier.light ~= nil, tier.light or Color3.new(1, 1, 1)
	-- Ink slash at every tier: the black edge stays, the white takes the tier colour (deeper red each level).
	-- Glowing it (LightEmission 1) washed out once the back slash made a full ring at tier 4+.
	s.arc.Color = ColorSequence.new(tier.light or tier.colors.Keypoints[2].Value)
	if tier.glitter then
		s.glitter.Color = ColorSequence.new({ -- a quick white flash, then the tier's glitter colour
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.15, tier.glitter),
			ColorSequenceKeypoint.new(1, tier.glitter),
		})
	end
	local inkR = r * (ink or 1)
	s.arc.Size = keys({ 0, inkR * 1.3 }, { 1, inkR * 1.45 }) -- crescent radius is ~0.95 x Size: just outside the arc, clear of the horde
	-- Rotation 0 points the crescent at +Z; the arc is centred on the middle of the swing
	s.arc.Rotation = NumberRange.new(math.deg((from + to) / 2) - 90)
	s.scorch.Size, s.scorch.Rotation = keys({ 0, inkR * 1.35 }, { 1, inkR * 1.4 }), s.arc.Rotation
	if tier.wave and ink then
		s.wave.Color = ColorSequence.new(tier.light or tier.colors.Keypoints[2].Value)
		s.wave.Size = keys({ 0, r * 0.4 }, { 1, range * 2.2 })
	end
	local function point(at: Attachment, a: number, c: Vector3)
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		-- X (the curve axis) along the swing, Y outward: the ribbon lies flat
		at.WorldCFrame = CFrame.fromMatrix(c + out * r, Vector3.new(-out.Z, 0, out.X) * side, out)
	end
	local function draw(tailAngle: number, headAngle: number)
		local c = root.Position - Vector3.new(0, 0.4, 0)
		s.part.CFrame = CFrame.new(c)
		point(s.tail, tailAngle, c)
		point(s.head, headAngle, c)
		-- Bezier handle length that makes the curve a circular arc
		local k = 4 / 3 * math.tan(math.abs(headAngle - tailAngle) / 4) * r
		s.beam.CurveSize0, s.beam.CurveSize1 = k, k
	end
	draw(from, from)
	s.beam.Enabled = true
	if tier.wave and ink then
		s.wave:Emit(1)
	end
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		draw(from + (to - from) * easeOut((t - CLOSE) / SWEEP), from + (to - from) * easeOut(t / SWEEP))
		if tier.glitter and ink and t < SWEEP then
			s.glitter:Emit(3)
		end
		if tier.smoke and ink and t < SWEEP then
			s.smoke:Emit(1)
		end
		if t >= SWEEP and not sparked then
			sparked = true
			s.sparks:Emit(tier.sparks)
			if ink then -- one ink crescent per slash; the echo's would stack into a muddy ring
				s.arc:Emit(1)
				if tier.scorch then
					s.scorch:Emit(1)
				end
			end
		end
		if t >= SWEEP + CLOSE then
			conn:Disconnect()
			s.beam.Enabled, s.light.Enabled = false, false
			task.delay(0.4, function()
				s.part.CFrame = HIDDEN
				table.insert(sweepPool, s)
			end)
		end
	end)
end
-- A full slash: the main crescent, plus a smaller echo right behind it from the double-slash tier up.
local function slash(root: BasePart, range: number, from: number, to: number, tier, ink: number?)
	sweep(root, range, from, to, tier, ink or 1)
	if tier.echo then
		task.delay(0.05, sweep, root, range * 0.75, from, to, tier)
	end
end
-- GAME-12 axe visual: voxel silhouette, matte steel/wood, restrained gold/jade accents.
-- Snapshot-driven: no independent client projectile simulation or damage prediction.
local axeViews = {}
local function makeAxeVisual(parent: Instance, level: number, scale: number)
	local model = Instance.new("Model")
	model.Name = "BoomerangAxe"
	local wood = Color3.fromRGB(98, 61, 36)
	local steel = Color3.fromRGB(130, 151, 157)
	local edge = Color3.fromRGB(224, 234, 221)
	local trim = if level >= 2 then Color3.fromRGB(207, 157, 67) else Color3.fromRGB(148, 104, 53)
	local inlay = if level >= 4 then Color3.fromRGB(74, 185, 150) else trim
	local function block(name, size, pos, color)
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame, p.Color = name, size * scale, CFrame.new(pos * scale), color
		p.Material = Enum.Material.Plastic
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
		p.Parent = model
		return p
	end
	local hub = block("Binding", Vector3.new(0.52, 0.48, 0.72), Vector3.new(0, 0, -0.5), trim)
	model.PrimaryPart = hub
	block("OakHaft", Vector3.new(0.3, 0.32, 2.7), Vector3.new(0, 0, 0.3), wood)
	block("Grip", Vector3.new(0.42, 0.4, 0.6), Vector3.new(0, 0, 1.14), Color3.fromRGB(58, 39, 31))
	block("Pommel", Vector3.new(0.48, 0.44, 0.25), Vector3.new(0, 0, 1.55), trim)
	for _, side in {-1, 1} do
		block("SteelCheek", Vector3.new(0.75, 0.32, 0.88), Vector3.new(side * 0.58, 0, -0.5), steel)
		block("Blade", Vector3.new(0.42, 0.28, 1.38), Vector3.new(side * 1.12, 0, -0.5), steel)
		block("CuttingEdge", Vector3.new(0.18, 0.24, 1.64), Vector3.new(side * 1.42, 0, -0.5), edge)
		block("Rivet", Vector3.new(0.24, 0.12, 0.24), Vector3.new(side * 0.64, 0.22, -0.5), trim)
	end
	block("Crest", Vector3.new(0.28, 0.12, 0.4), Vector3.new(0, 0.29, -0.5), inlay)
	if level >= 5 then
		for _, side in {-1, 1} do
			block("GoldInlay", Vector3.new(0.15, 0.08, 0.66), Vector3.new(side * 1.03, 0.2, -0.5), trim)
		end
	end
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(1.4, 0, -0.15) * scale, Vector3.new(1.4, 0, 0.15) * scale
	a0.Parent, a1.Parent = hub, hub
	local trail = Instance.new("Trail")
	trail.Name, trail.Attachment0, trail.Attachment1 = "ShortSpinTrail", a0, a1
	trail.Color = ColorSequence.new(trim, edge)
	trail.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1)})
	trail.Lifetime, trail.MinLength, trail.LightEmission, trail.FaceCamera = 0.1, 0.08, 0, true
	trail.Parent = hub
	-- Pivot at the shaft centre, not the off-centre binding part.
	model.WorldPivot = CFrame.identity
	hub.PivotOffset = CFrame.new(0, 0, 0.5 * scale)
	model.Parent = parent
	return model, trail
end

local function receiveAxes(packet)
	local seen = {}
	for _, row in packet do
		local id, owner, x, z, y, radius, level, age = table.unpack(row)
		local character = owner and owner.Character
		if not character then continue end
		local v = axeViews[id]
		if not v then
			local model, trail = makeAxeVisual(folder, level, radius / 1.8)
			v = { model = model, trail = trail, owner = owner, character = character, x = x, z = z, age = age }
			axeViews[id] = v
			model:PivotTo(CFrame.new(x, y, z) * CFrame.Angles(0, age * 18, 0))
		end
		v.tx, v.tz, v.y, v.targetAge = x, z, y, age
		seen[id] = true
	end
	for id, v in axeViews do
		if not seen[id] then v.model:Destroy(); axeViews[id] = nil end
	end
end
-- END GAME-12 axe visual

-- GAME-12 rocks visual: matte ruin stones; geometry never participates in hit detection.
local rockViews={}
local function makeRockVisual(parent,level,radius)
	local model=Instance.new("Model");model.Name="OrbitRock"
	local scale=radius/1.25
	local stone=if level>=5 then Color3.fromRGB(101,112,104) else Color3.fromRGB(130,139,126)
	local function piece(class,name,size,cf,color)
		local p=Instance.new(class);p.Name=name;p.Size=size*scale;p.CFrame=CFrame.new(cf.Position*scale)*cf.Rotation
		p.Color=color;p.Material=Enum.Material.Plastic;p.Anchored=true
		p.CanCollide,p.CanTouch,p.CanQuery,p.CastShadow=false,false,false,false;p.Parent=model
		return p
	end
	local core=piece("Part","Stone",Vector3.new(1.65,1.35,1.45),CFrame.identity,stone)
	model.PrimaryPart=core
	piece("WedgePart","Facet",Vector3.new(.65,1.3,1.45),CFrame.new(.85,0,0)*CFrame.Angles(0,0,math.pi/2),Color3.fromRGB(96,107,99))
	piece("WedgePart","LightFacet",Vector3.new(.6,1.25,1.35),CFrame.new(-.8,0,0)*CFrame.Angles(0,0,-math.pi/2),Color3.fromRGB(164,171,151))
	piece("Part","Moss",Vector3.new(.65,.12,.8),CFrame.new(-.45,.72,.12),Color3.fromRGB(88,119,62))
	local gold=if level>=5 then Color3.fromRGB(227,185,85) else Color3.fromRGB(172,148,91)
	piece("Part","Rune",Vector3.new(.16,.68,.06),CFrame.new(.1,.02,-.75),gold)
	piece("Part","RuneTop",Vector3.new(.5,.14,.06),CFrame.new(.1,.3,-.75),gold)
	piece("Part","TopRune",Vector3.new(.14,.06,.72),CFrame.new(.25,.7,0),gold)
	piece("Part","TopRuneBar",Vector3.new(.48,.06,.14),CFrame.new(.25,.7,-.28),gold)
	if level>=3 then piece("Part","RuneBase",Vector3.new(.5,.14,.06),CFrame.new(.1,-.25,-.75),gold) end
	model.WorldPivot=CFrame.identity;model.Parent=parent
	return model
end
local function clearRockView(owner)
	local v=rockViews[owner]
	if v then for _,m in v.models do m:Destroy() end;rockViews[owner]=nil end
end
local function receiveRocks(packet)
	local seen={}
	for _,row in packet do
		local owner,serial,x,z,y,phase,count,radius,orbit,level=table.unpack(row)
		local character=owner and owner.Character
		if not character then continue end
		local v=rockViews[owner]
		if v and (v.serial~=serial or v.character~=character) then clearRockView(owner);v=nil end
		if not v then
			v={serial=serial,character=character,models={},x=x,z=z,phase=phase}
			for _=1,count do table.insert(v.models,makeRockVisual(folder,level,radius)) end
			rockViews[owner]=v
		end
		v.tx,v.tz,v.y,v.targetPhase,v.orbit=x,z,y,phase,orbit
		seen[owner]=true
	end
	for owner in rockViews do if not seen[owner] then clearRockView(owner) end end
end
-- END GAME-12 rocks visual

-- GAME-12 totem visual: ruin stone, moss and a small cyan rune core. No physical hitboxes.
local totemViews={}
local activeBolts=0
local function makeTotemVisual(parent,level)
	local model=Instance.new("Model");model.Name="LightningTotem"
	local stone=Color3.fromRGB(100,115,109);local gold=Color3.fromRGB(205,164,78)
	local cyan=if level>=6 then Color3.fromRGB(183,241,231)else Color3.fromRGB(75,188,204)
	local function block(name,size,pos,color,material)
		local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=CFrame.new(pos);p.Color=color
		p.Material=material or Enum.Material.Plastic;p.Anchored=true
		p.CanCollide,p.CanTouch,p.CanQuery,p.CastShadow=false,false,false,false;p.Parent=model;return p
	end
	local base=block("Plinth",Vector3.new(2.8,.45,2.8),Vector3.new(0,.225,0),stone);model.PrimaryPart=base
	block("Step",Vector3.new(2.1,.45,2.1),Vector3.new(0,.675,0),Color3.fromRGB(143,150,130))
	block("CarvedStone",Vector3.new(1.35,2.2,1.35),Vector3.new(0,2,0),stone)
	block("Moss",Vector3.new(.7,.12,.8),Vector3.new(-.6,.95,.25),Color3.fromRGB(82,120,61))
	block("Brow",Vector3.new(1.7,.3,1.6),Vector3.new(0,2.75,0),gold)
	for _,side in {-1,1}do
		block("Eye",Vector3.new(.28,.24,.08),Vector3.new(side*.35,2.35,-.72),cyan,Enum.Material.Neon)
		if level>=3 then block("Wing",Vector3.new(.4,1.1,.6),Vector3.new(side*1,2.3,0),stone)end
	end
	block("Rune",Vector3.new(.18,.8,.08),Vector3.new(0,1.5,-.72),gold)
	block("Crown",Vector3.new(1.6,.3,1.6),Vector3.new(0,3.25,0),stone)
	local core=block("StormCore",Vector3.new(.65,.8,.65),Vector3.new(0,3.8,0),cyan,Enum.Material.Neon)
	core.CFrame*=CFrame.Angles(0,math.pi/4,0)
	if level>=5 then
		for _,side in {-1,1}do block("CrownProng",Vector3.new(.25,.85,.25),Vector3.new(side*.7,3.7,0),gold)end
	end
	if level>=6 then block("AncientSeal",Vector3.new(.9,.12,.9),Vector3.new(0,4.35,0),gold)end
	base.PivotOffset=CFrame.new(0,-.225,0);model.Parent=parent;return model
end
local function receiveTotems(packet)
	local seen={}
	for _,row in packet do
		local id,owner,x,z,y,level=table.unpack(row)
		if not owner or not owner.Character then continue end
		local v=totemViews[id]
		if not v then
			v={model=makeTotemVisual(folder,level),owner=owner,character=owner.Character};totemViews[id]=v
			v.model:PivotTo(CFrame.new(x,y,z))
		end
		seen[id]=true
	end
	for id,v in totemViews do if not seen[id]then v.model:Destroy();totemViews[id]=nil end end
end
local function drawLightning(packet)
	local camera=Workspace.CurrentCamera
	for _,row in packet do
		if activeBolts>=16 then break end
		local x,z,y,tx,tz,level=table.unpack(row)
		local start,finish=Vector3.new(x,y,z),Vector3.new(tx,y-1.5,tz)
		if not camera or (camera.CFrame.Position-start).Magnitude>180 then continue end
		activeBolts+=1;local pieces={};local previous=start
		for k=1,3 do
			local point=start:Lerp(finish,k/3)+(if k==3 then Vector3.zero else Vector3.new(.4*(if k==1 then 1 else -1),.45,0))
			local length=(point-previous).Magnitude
			local p=Instance.new("Part");p.Name="TotemBolt";p.Size=Vector3.new(.09,.09,math.max(length,.01))
			p.CFrame=if length>.001 then CFrame.lookAt((previous+point)/2,point)else CFrame.new(point)
			p.Color=if level>=6 then Color3.fromRGB(234,244,178)else Color3.fromRGB(145,231,239)
			p.Material=Enum.Material.Neon;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
			p.Parent=folder;table.insert(pieces,p);previous=point
		end
		task.delay(.14,function()for _,p in pieces do p:Destroy()end;activeBolts-=1 end)
	end
end
-- END GAME-12 totem visual

-- One sword swing around `root` aimed at (lx, lz); `key` remembers which way the last swing went so they alternate.
local function swing(key: any, root: BasePart, tier, range: number, arc: number, back: boolean?, lx: number, lz: number)
	local aim, half = math.atan2(lz, lx), math.rad(arc / 2)
	local side = -(swingSide[key] or 1)
	swingSide[key] = side
	slash(root, range, aim - half * side, aim + half * side, tier)
	if back then
		-- Smaller, a beat later: the two ink crescents read as two strokes instead of closing into a hoop
		task.delay(0.08, slash, root, range, aim + math.pi + half * side, aim + math.pi - half * side, tier, 0.7)
	end
end

-- Sword FX showcase (Workspace.SwordFXZone, built by roblox/BuildSwordFXZone.luau): station LvN swings forever at sword
-- level N, with that level's Range/Arc/Back from Config, while the local player is within 120 studs. Place-only.
task.spawn(function()
	local zone = Workspace:WaitForChild("SwordFXZone", 10)
	if not zone then
		return
	end
	local levels = Config.Weapons.sword.Levels
	while true do
		local char = Players.LocalPlayer.Character
		local me = char and char:FindFirstChild("HumanoidRootPart")
		if me and (me.Position - zone:GetPivot().Position).Magnitude < 120 then
			local stats = {}
			for n = 1, #SLASH_TIERS do
				for k, v in levels[n] or {} do
					stats[k] = v -- levels only list what changes, so stats build up level by level
				end
				local station = zone:FindFirstChild("Lv" .. n)
				if station then
					swing(station, station, SLASH_TIERS[n], stats.Range, stats.Arc, stats.Back, 0, 1)
				end
			end
		end
		task.wait(1.6)
	end
end)

Shared:WaitForChild("HordeFx").OnClientEvent:Connect(function(kind: string, ...)
	if kind == "slash" then
		local player, range, arc, back, lx, lz = ...
		local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			swing(player, root, swordTier(player), range, arc, back, lx, lz)
		end
		if player == Players.LocalPlayer then
			lastSlash = os.clock()
		end
	elseif kind == "clearGems" then
		local ids = ...
		for _, id in ids do
			local gem = gems[id]
			if gem then
				gems[id] = nil
				gem.CFrame = HIDDEN
				table.insert(gemPool, gem)
			end
		end
	elseif kind == "axes" then
		receiveAxes(...)
	elseif kind == "rocks" then
		receiveRocks(...)
	elseif kind=="totems" then
		receiveTotems(...)
	elseif kind=="lightning" then
		drawLightning(...)
	elseif kind == "fire" then
		local x, z, dx, dz, speed, range = ...
		local p = pooled(ballPool, function()
			return fxPart(Vector3.one * 1.3, Color3.fromRGB(255, 140, 50), Enum.PartType.Ball)
		end)
		table.insert(balls, { part = p, x = x, z = z, dx = dx, dz = dz, speed = speed, left = range })
	end
end)

-- Fire Ring (GAME-41): a faint disc plus fire that builds up by level, like the sword's SLASH_TIERS:
--   Lv1 flames along the edge, Lv2 + embers rising, Lv3 + a slowly turning fire circle on the ground,
--   Lv4 + a burn pulse each damage tick (flare at the edge, smoke and sparks inside), Lv5 taller and denser,
--   Lv6 = the evolved Inferno Halo: red fire and a second ring of flames inside.
-- The pulse runs on the local clock at the level's Interval; it shows the rhythm, it isn't synced to server ticks.
local RING = Config.Weapons.ring
local TEX = Config.Textures
local rings = {} -- Player or showcase key -> ring fx
local CIRCLE_LIFE = 6 -- seconds per ground-circle particle
local ringRay = RaycastParams.new()
ringRay.FilterType = Enum.RaycastFilterType.Exclude
local function seq(a: number, b: number?): NumberSequence
	return NumberSequence.new(a, b or a)
end
local function emitter(parent: Instance, props): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.LightEmission, e.Rate = 1, 0
	for k, v in props do
		e[k] = v
	end
	e.Parent = parent
	return e
end
-- Flames rising off a flat disc host (Shape Disc; ShapePartial ~0.08 keeps them on the rim, 1 fills it).
local function flames(host: BasePart, rim: number, size: number, speed: NumberRange, life: NumberRange, color: ColorSequence)
	return emitter(host, {
		Texture = TEX.RingFlame, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Shape = Enum.ParticleEmitterShape.Disc, ShapePartial = rim, EmissionDirection = Enum.NormalId.Top,
		Speed = speed, Lifetime = life, Size = seq(size, size * 0.3), Color = color, LightEmission = 0.75, -- 1 turned red fire yellow on grass
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.7, 0.4), NumberSequenceKeypoint.new(1, 1) }),
	})
end
local function ringFx(tier: number)
	local evo = tier >= 6
	local hot = if evo then Color3.fromRGB(255, 45, 35) else Color3.fromRGB(255, 140, 40)
	local core = if evo then Color3.fromRGB(255, 190, 110) else Color3.fromRGB(255, 235, 130)
	local fire = ColorSequence.new(core, hot)
	local fx = { tier = tier, r = 0, nextPulse = 0, interval = Config.weaponStats("ring", tier).Interval }
	fx.disc = fxPart(Vector3.one, if evo then Color3.fromRGB(170, 25, 20) else RING.Color, Enum.PartType.Cylinder)
	fx.disc.Transparency = 0.88
	fx.host = fxPart(Vector3.one, hot)
	fx.host.Transparency = 1
	fx.flames = flames(fx.host, 0.08, if tier >= 5 then 2.6 else 1.7, NumberRange.new(1.5, 3), NumberRange.new(0.45, 0.7), fire)
	if tier >= 2 then
		fx.embers = emitter(fx.host, {
			Texture = TEX.Spark, Shape = Enum.ParticleEmitterShape.Disc, ShapePartial = 1, EmissionDirection = Enum.NormalId.Top,
			Speed = NumberRange.new(3, 6), Acceleration = Vector3.new(0, 2, 0), SpreadAngle = Vector2.new(15, 15),
			Lifetime = NumberRange.new(0.8, 1.5), Size = seq(0.35, 0), Color = fire,
		})
	end
	if tier >= 3 then -- a flat turning particle, re-emitted by placeRing; LockedToPart keeps it under the player
		local center = Instance.new("Attachment")
		center.Parent = fx.host
		fx.spin = if evo then -35 else 20
		fx.circle = emitter(center, {
			Texture = TEX.RingCircle, Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.01), Lifetime = NumberRange.new(CIRCLE_LIFE),
			LockedToPart = true, RotSpeed = NumberRange.new(fx.spin), Color = ColorSequence.new(hot), LightEmission = 0.5,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.08, 0.3),
				NumberSequenceKeypoint.new(0.92, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		})
		fx.nextCircle = 0
	end
	if tier >= 4 then
		fx.pulse = flames(fx.host, 0.08, 3.2, NumberRange.new(5, 8), NumberRange.new(0.3, 0.45), fire)
		fx.smoke = emitter(fx.host, {
			Texture = TEX.RingSmoke, Shape = Enum.ParticleEmitterShape.Disc, ShapePartial = 1, EmissionDirection = Enum.NormalId.Top,
			Speed = NumberRange.new(2, 3), Lifetime = NumberRange.new(0.8, 1.2), Size = seq(1.5, 3.5), LightEmission = 0,
			Color = ColorSequence.new(Color3.fromRGB(70, 45, 40)), Transparency = seq(0.45, 1), Rotation = NumberRange.new(0, 360),
		})
		fx.sparks = emitter(fx.host, {
			Texture = TEX.RingBurst, Shape = Enum.ParticleEmitterShape.Disc, ShapePartial = 1, EmissionDirection = Enum.NormalId.Top,
			Speed = NumberRange.new(0.5), Lifetime = NumberRange.new(0.25, 0.35), Size = seq(2.5, 0.5), Color = fire,
			Rotation = NumberRange.new(0, 360),
		})
	end
	if evo then
		fx.inner = fxPart(Vector3.one, hot)
		fx.inner.Transparency = 1
		fx.innerFlames = flames(fx.inner, 0.15, 2, NumberRange.new(2, 4), NumberRange.new(0.4, 0.6), fire)
	end
	return fx
end
local function sizeRing(fx, r: number)
	fx.r = r
	fx.disc.Size = Vector3.new(0.15, r * 2, r * 2)
	fx.host.Size = Vector3.new(r * 2, 0.2, r * 2)
	local edge = 2 * math.pi * r
	fx.flames.Rate = edge * (if fx.tier >= 5 then 2 else 1.3)
	if fx.embers then
		fx.embers.Rate = r * (if fx.tier >= 5 then 3 else 1.5)
	end
	if fx.circle then
		fx.circle.Size = seq(r * 1.05) -- a particle's Size reads as about its radius; this sits just past the rim flames
	end
	if fx.inner then
		fx.inner.Size = Vector3.new(r, 0.2, r)
		fx.innerFlames.Rate = edge * 0.7
	end
end
local function dropRing(key)
	local fx = rings[key]
	if fx then
		fx.disc:Destroy()
		fx.host:Destroy()
		if fx.inner then
			fx.inner:Destroy()
		end
		rings[key] = nil
	end
end
Players.PlayerRemoving:Connect(function(player)
	clearRockView(player)
	dropRing(player)
	swingSide[player] = nil
end)
local function ringLevel(player: Player): (number?, number?)
	local lv = tonumber(string.match(player:GetAttribute("RunLoadout") or "", "ring=(%d)"))
	return lv, lv and Config.weaponStats("ring", lv).Radius * (1 + (player:GetAttribute("RunArea") or 0))
end
-- placeRing(key, pos, r, tier): keeps key's ring on the ground at pos (the feet, not a fixed height: Map1's grass and
-- plaza tiles stand above y = 0 and used to swallow the disc and circle) with radius r; no pos or r removes it.
local function placeRing(key, pos: Vector3?, r: number?, tier: number?)
	local fx = rings[key]
	if fx and not (pos and r and fx.tier == tier) then
		dropRing(key)
		fx = nil
	end
	if not (pos and r and tier) then
		return
	end
	if not fx then
		fx = ringFx(tier)
		rings[key] = fx
	end
	if fx.r ~= r then
		sizeRing(fx, r)
	end
	fx.disc.CFrame = CFrame.new(pos.X, pos.Y + 0.1, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
	fx.host.CFrame = CFrame.new(pos.X, pos.Y + 0.3, pos.Z)
	if fx.inner then
		fx.inner.CFrame = fx.host.CFrame
	end
	local now = os.clock()
	if fx.circle and now >= fx.nextCircle then
		-- A fresh copy every few seconds, started at the angle the old one has reached, so the hand-over doesn't jump.
		-- (A single forever-particle could get dropped by the engine and never come back.)
		fx.nextCircle = now + CIRCLE_LIFE * 0.92
		fx.circle.Rotation = NumberRange.new((now * fx.spin) % 360)
		fx.circle:Emit(1)
	end
	if fx.pulse and now >= fx.nextPulse then
		fx.nextPulse = now + fx.interval
		fx.pulse:Emit(math.round(r * 2))
		fx.smoke:Emit(3)
		fx.sparks:Emit(4)
	end
end
-- Fire Ring showcase (SwordFXZone Ring1..Ring6, Ring6 = evolved): drawn like a player's ring while you're near.
-- Looked up every frame: with streaming the stations only arrive once you walk over there.
local RING_SHOW = {}
for n = 1, 6 do
	RING_SHOW[n] = Config.weaponStats("ring", n).Radius
end

-- Weapon showcase (SwordFXZone stations from BuildSwordFXZone.luau; n = 6 is the evolved form), with the in-run
-- visuals at each level's Config stats: Fire1-6 shoot fireballs and Axe1-6 throw axes outward, Rocks1-6 orbit,
-- Totem1-6 zap; GalleryA/B stand every Sword_PhaseN of the new and old sword sets, turning. Client-only, and only
-- while you're within SHOW_NEAR of the WeaponFloor; everything is cleared when you leave.
local SHOW_NEAR = 280
local GALLERY = { A = "SwordsShadow", B = "Swords" }
local showStats = {}
for _, id in { "fire", "axe", "rocks", "totem" } do
	showStats[id] = {}
	for n = 1, 6 do
		showStats[id][n] = Config.weaponStats(id, n)
	end
end
local show = { rocks = {}, totems = {}, axes = {}, gallery = {}, next = {} }
local function clearShow()
	for _, list in { show.rocks, show.totems, show.gallery } do
		for k, v in list do
			for _, m in (if typeof(v) == "table" then v else { v }) do
				m:Destroy()
			end
			list[k] = nil
		end
	end
	for k, a in show.axes do
		a.model:Destroy()
		show.axes[k] = nil
	end
	table.clear(show.next)
end
local function due(key: string, every: number, now: number): boolean
	if now >= (show.next[key] or 0) then
		show.next[key] = now + every
		return true
	end
	return false
end
RunService.Heartbeat:Connect(function(dt)
	local zone = Workspace:FindFirstChild("SwordFXZone")
	local floor = zone and zone:FindFirstChild("WeaponFloor")
	local me = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not (floor and me and (me.Position - floor.Position).Magnitude < SHOW_NEAR) then
		if next(show.next) or next(show.gallery) then
			clearShow()
		end
		return
	end
	local now = os.clock()
	for n = 1, 6 do
		-- Rocks: Count stones on the Orbit circle, turning at Speed.
		local s, st = zone:FindFirstChild("Rocks" .. n), showStats.rocks[n]
		if s then
			show.rocks[n] = show.rocks[n] or {}
			local list = show.rocks[n]
			for k = #list + 1, st.Count do
				list[k] = makeRockVisual(folder, n, st.Radius)
			end
			for k, m in list do
				local angle = now * st.Speed + (k - 1) * math.pi * 2 / #list
				m:PivotTo(CFrame.new(s.Position + Vector3.new(math.cos(angle) * st.Orbit, 1.2, math.sin(angle) * st.Orbit))
					* CFrame.Angles(0.12 * math.sin(angle), -angle + 0.3, 0.15))
			end
		end
		-- Totem: standing on the floor, zapping Targets points inside its Range every Interval.
		s, st = zone:FindFirstChild("Totem" .. n), showStats.totem[n]
		if s then
			local ground = s.Position - Vector3.new(0, s.Size.Y / 2, 0)
			if not show.totems[n] then
				show.totems[n] = makeTotemVisual(folder, n)
				show.totems[n]:PivotTo(CFrame.new(ground))
			end
			if due("zap" .. n, st.Interval, now) then
				local bolts = {}
				for _ = 1, st.Targets do
					local a, d = math.random() * math.pi * 2, st.Range * (0.3 + math.random() * 0.4)
					table.insert(bolts, { ground.X, ground.Z, ground.Y + 3.8, ground.X + math.cos(a) * d, ground.Z + math.sin(a) * d, n })
				end
				drawLightning(bolts)
			end
		end
		-- Fireball: Count balls fanned out toward -x every Cooldown, flying their Range.
		s, st = zone:FindFirstChild("Fire" .. n), showStats.fire[n]
		if s and due("fire" .. n, st.Cooldown, now) then
			for k = 1, st.Count do
				local a = math.pi + (k - (st.Count + 1) / 2) * 0.12
				local p = pooled(ballPool, function()
					return fxPart(Vector3.one * 1.3, Color3.fromRGB(255, 140, 50), Enum.PartType.Ball)
				end)
				table.insert(balls, { part = p, x = s.Position.X, z = s.Position.Z, dx = math.cos(a), dz = math.sin(a), speed = st.Speed, left = st.Range })
			end
		end
		-- Axe: Count axes thrown toward +x every Cooldown, out to Range at Speed and back at ReturnSpeed.
		s, st = zone:FindFirstChild("Axe" .. n), showStats.axe[n]
		if s and due("axe" .. n, st.Cooldown, now) then
			local count = st.Count or 1
			for k = 1, count do
				local a = (k - (count + 1) / 2) * 0.35
				table.insert(show.axes, {
					model = makeAxeVisual(folder, n, st.Radius / 1.8), from = s.Position, dir = Vector3.new(math.cos(a), 0, math.sin(a)),
					d = 0, back = false, age = 0, st = st,
				})
			end
		end
	end
	for k = #show.axes, 1, -1 do
		local a = show.axes[k]
		a.age += dt
		if not a.back then
			a.d += a.st.Speed * dt
			a.back = a.d >= a.st.Range
		else
			a.d -= a.st.ReturnSpeed * dt
		end
		if a.back and a.d <= 0 then
			a.model:Destroy()
			table.remove(show.axes, k)
		else
			a.model:PivotTo(CFrame.new(a.from + a.dir * a.d + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, a.age * 18, 0))
		end
	end
	-- Gallery: the grip on the stand, blade up, turning slowly.
	for row, setName in GALLERY do
		local set = ReplicatedStorage:FindFirstChild(setName)
		for n = 1, 5 do
			local stand, src = zone:FindFirstChild("Gallery" .. row .. n), set and set:FindFirstChild("Sword_Phase" .. n)
			local key = row .. n
			if stand and src and not show.gallery[key] then
				local m = src:Clone()
				for _, d in m:GetDescendants() do
					if d:IsA("BasePart") then
						d.Anchored, d.CanCollide, d.CanQuery = true, false, false
					end
				end
				m:SetAttribute("GripToPivot", m.PrimaryPart.CFrame:ToObjectSpace(m:GetPivot()))
				m.Parent = folder
				show.gallery[key] = m
			end
			local m = show.gallery[key]
			if m and stand then
				m:PivotTo(CFrame.new(stand.Position + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, now * 0.8 + n, 0) * m:GetAttribute("GripToPivot"))
			end
		end
	end
end)

local parts, cframes = {}, {}
RunService.RenderStepped:Connect(function(dt)
	for id,v in totemViews do
		local hum=v.character:FindFirstChildOfClass("Humanoid")
		if v.owner.Parent~=Players or v.owner.Character~=v.character or not hum or hum.Health<=0 or not v.owner:GetAttribute("RunStart")then
			v.model:Destroy();totemViews[id]=nil
		end
	end
	local rockAlpha=1-math.exp(-dt*24)
	for owner,v in rockViews do
		local hum=v.character:FindFirstChildOfClass("Humanoid")
		if owner.Parent~=Players or owner.Character~=v.character or not hum or hum.Health<=0 or not owner:GetAttribute("RunStart") then
			clearRockView(owner)
		else
			v.x+=(v.tx-v.x)*rockAlpha;v.z+=(v.tz-v.z)*rockAlpha
			v.phase+=((v.targetPhase-v.phase+math.pi)%(math.pi*2)-math.pi)*rockAlpha
			for k,m in v.models do
				local angle=v.phase+(k-1)*math.pi*2/#v.models
				m:PivotTo(CFrame.new(v.x+math.cos(angle)*v.orbit,v.y,v.z+math.sin(angle)*v.orbit)*CFrame.Angles(.12*math.sin(angle),-angle+.3,.15))
			end
		end
	end
	local axeAlpha = 1 - math.exp(-dt * 24)
	for id, v in axeViews do
		local hum = v.character:FindFirstChildOfClass("Humanoid")
		if v.owner.Parent ~= Players or v.owner.Character ~= v.character or not hum or hum.Health <= 0
			or not v.owner:GetAttribute("RunStart") then
			v.model:Destroy(); axeViews[id] = nil
		else
			v.x += (v.tx - v.x) * axeAlpha
			v.z += (v.tz - v.z) * axeAlpha
			v.age += (v.targetAge - v.age) * axeAlpha -- also freezes when the server's card pause freezes it
			v.model:PivotTo(CFrame.new(v.x, v.y, v.z) * CFrame.Angles(0, v.age * 18, 0))
		end
	end
	for k = #balls, 1, -1 do
		local b = balls[k]
		local step = b.speed * dt
		b.x += b.dx * step
		b.z += b.dz * step
		b.left -= step
		if b.left <= 0 then
			b.part.CFrame = HIDDEN
			table.insert(ballPool, b.part)
			table.remove(balls, k)
		else
			b.part.CFrame = CFrame.new(b.x, HIP_Y, b.z)
		end
	end
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local lv, r = ringLevel(player)
		local ground
		if root and r then -- the ground under the player, so the ring stays down while they jump
			ringRay.FilterDescendantsInstances = { folder, player.Character, Workspace:FindFirstChild("Horde") }
			local hit = Workspace:Raycast(root.Position, Vector3.new(0, -12, 0), ringRay)
			ground = if hit then hit.Position else root.Position - Vector3.new(0, 3, 0)
		end
		placeRing(player, ground, r, lv)
	end
	local myRoot = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local showZone = Workspace:FindFirstChild("SwordFXZone")
	for n, r in RING_SHOW do
		local s = showZone and showZone:FindFirstChild("Ring" .. n)
		local near = s and myRoot and (myRoot.Position - s.Position).Magnitude < 150
		placeRing("show" .. n, if near then s.Position - Vector3.new(0, s.Size.Y / 2 - 0.05, 0) else nil, r, n) -- floor top under the station
	end

	local a = 1 - math.exp(-dt * SMOOTH)
	table.clear(parts)
	table.clear(cframes)
	for _, e in live do
		e.x += (e.tx - e.x) * a
		e.z += (e.tz - e.z) * a
		e.yaw += ((e.tyaw - e.yaw + math.pi) % (math.pi * 2) - math.pi) * a -- shortest way round
		table.insert(parts, e.root)
		table.insert(cframes, CFrame.new(e.x, HIP_Y, e.z) * CFrame.Angles(0, e.yaw, 0))
	end
	Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end)

-- GAME-25: opt-in observations of the real tables; no counters or extra instances in normal play.
if RunService:IsStudio() and Shared:GetAttribute("GAME25Active") then
	local probe = Instance.new("BindableFunction")
	probe.Name = "GAME25VisualProbe"
	probe.OnInvoke = function()
		local function size(t) local n=0; for _ in t do n+=1 end; return n end
		local orphanRings, orphanSides, visibleNumbers = 0, 0, 0
		for p in rings do if typeof(p) == "Instance" and p.Parent ~= Players then orphanRings+=1 end end
		for p in swingSide do if p:IsA("Player") and p.Parent ~= Players then orphanSides+=1 end end
		for _, d in folder:GetDescendants() do
			if d:IsA("TextLabel") and d.TextTransparency < 1 then visibleNumbers+=1 end
		end
		return {live=size(live),modelPool=#pool,gems=size(gems),gemPool=#gemPool,balls=#balls,ballPool=#ballPool,
			axes=size(axeViews),rings=size(rings),orphanRings=orphanRings,orphanSides=orphanSides,
			flashPool=#flashPool,numberPool=#numberPool,visibleNumbers=visibleNumbers,sweepPool=#sweepPool,
			hordeInstances=#folder:GetDescendants()}
	end
	probe.Parent = Shared
end

-- Resend initial identities/gems after every receiver is connected (including late joins).
if networkObserved then
	local probe=Instance.new("BindableFunction")
	probe.Name="GAME24VisualProbe"
	probe.OnInvoke=function(action)
		if action=="resync" then
			for slot in live do free(slot) end
			for id,part in gems do gems[id]=nil;part.CFrame=HIDDEN;table.insert(gemPool,part) end
			Shared.HordeReady:FireServer()
			return true
		end
		local slots, drops, n={}, {}, 0
		for id,e in live do slots[tostring(id)]={incarnation=e.incarnation,x=e.tx,z=e.tz};n+=1 end
		for id,part in gems do drops[tostring(id)]={x=part.Position.X,z=part.Position.Z} end
		return {slots=slots,gems=drops,count=n,events=table.clone(networkObserved),models=#pool+n}
	end
	probe.Parent=Shared
end
Shared:WaitForChild("HordeReady"):FireServer()
