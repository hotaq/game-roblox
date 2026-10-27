-- GoblinHordeClient (LocalScript, StarterPlayer.StarterPlayerScripts)
-- Draws the GoblinHorde goblins: each snapshot gives {x, z} per slot; every frame the pooled client-only models ease
-- toward their latest position and face the nearest player (also while knocked back); all roots move in one
-- BulkMoveTo. Each model runs its own Run loop and plays Attack1 when the server says it swings; a death plays the
-- Death clip in place (off the slot, which the server may refill at once), then the model goes back to the pool.
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
local Config = require(Shared:WaitForChild("GoblinConfig"))
local AnimData = require(Shared:WaitForChild("GoblinAnimData"))
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
		for _, part in m:GetDescendants() do -- client-only: the player must never stand on or bump into one
			if part:IsA("BasePart") then
				part.CanCollide, part.CanTouch = false, false
			end
		end
		m.Parent = folder
		local animator = m:FindFirstChildOfClass("AnimationController"):FindFirstChildOfClass("Animator")
		e = { root = m:FindFirstChild("HumanoidRootPart"), run = animator:LoadAnimation(RUN), death = animator:LoadAnimation(DEATH), swing = animator:LoadAnimation(SWING), flinch = animator:LoadAnimation(FLINCH) }
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
	table.insert(pool, e)
end

local function free(slot: number)
	local e = live[slot]
	if e then
		live[slot] = nil
		recycle(e)
	end
end

local roots = {} -- every player's root this snapshot: goblins always face the nearest one
Shared:WaitForChild("HordeSnap").OnClientEvent:Connect(function(b: buffer)
	local n = buffer.readu16(b, 0)
	table.clear(roots)
	for _, pl in Players:GetPlayers() do
		local r = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
		if r then
			table.insert(roots, r.Position)
		end
	end
	for slot = 1, n do
		local o = 2 + (slot - 1) * 4
		local xi = buffer.readi16(b, o)
		if xi == NONE then
			free(slot) -- despawned without dying (deaths left the slot already)
			continue
		end
		local x, z = xi / 8, buffer.readi16(b, o + 2) / 8
		local e = live[slot]
		if not e then
			e = acquire()
			e.x, e.z, e.tx, e.tz, e.yaw, e.tyaw = x, z, x, z, 0, 0
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
	local p = pooled(gemPool, function()
		return fxPart(Vector3.one * 0.8, Color3.fromRGB(95, 208, 255))
	end)
	p.CFrame = CFrame.new(x, GEM_Y, z) * CFrame.Angles(math.rad(45), 0, math.rad(45))
	gems[g] = p
end

local deathLength = AnimData.Death.length
Shared:WaitForChild("HordeDied").OnClientEvent:Connect(function(b: buffer)
	local firstGem = buffer.readu16(b, 0)
	for o = 2, buffer.len(b) - 2, 2 do
		local slot = buffer.readu16(b, o)
		local e = live[slot]
		if e then
			dropGem((firstGem + o / 2 - 1) % 65536, e.x, e.z)
			live[slot] = nil -- stays where it fell: only live models get moved
			e.run:Stop(0.1)
			e.swing:Stop(0.1)
			e.death:Play(0.1)
			task.delay(deathLength, recycle, e)
		end
	end
end)

Shared:WaitForChild("HordeSwing").OnClientEvent:Connect(function(b: buffer)
	for o = 0, buffer.len(b) - 2, 2 do
		local e = live[buffer.readu16(b, o)]
		if e then
			e.swing:Play(0.05) -- the server lands the hit at AttackWindup, around this clip's HitStart
		end
	end
end)

Shared:WaitForChild("HordeGems").OnClientEvent:Connect(function(player: Player, b: buffer)
	local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	for o = 0, buffer.len(b) - 2, 2 do
		local g = buffer.readu16(b, o)
		local p = gems[g]
		if p then
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
Shared:WaitForChild("HordeHits").OnClientEvent:Connect(function(b: buffer)
	for o = 0, buffer.len(b) - 4, 4 do
		local e = live[buffer.readu16(b, o)]
		if not e then
			continue
		end
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
-- How the slash looks at each Wooden Sword level, so every upgrade is visibly cooler: wood, gold, a double
-- slash, glowing energy, then a legendary max level. width is the leading edge as a fraction of the range;
-- echo adds a second, smaller crescent right behind; light makes the edge glow.
local SLASH_TIERS = {
	{ colors = colors({ 0, 150, 100, 55 }, { 0.8, 205, 160, 105 }, { 1, 255, 245, 220 }), width = 0.45, sparks = 4 },
	{ colors = colors({ 0, 255, 110, 20 }, { 0.8, 255, 200, 60 }, { 1, 255, 255, 235 }), width = 0.6, sparks = 8 },
	{ colors = colors({ 0, 255, 110, 20 }, { 0.8, 255, 200, 60 }, { 1, 255, 255, 235 }), width = 0.65, sparks = 10, echo = true },
	{
		colors = colors({ 0, 40, 90, 255 }, { 0.75, 80, 220, 255 }, { 1, 240, 255, 255 }),
		width = 0.7,
		sparks = 14,
		echo = true,
		light = Color3.fromRGB(90, 200, 255),
	},
	{
		colors = colors({ 0, 150, 60, 255 }, { 0.45, 255, 80, 200 }, { 0.8, 255, 210, 80 }, { 1, 255, 255, 240 }),
		width = 0.8,
		sparks = 22,
		echo = true,
		light = Color3.fromRGB(255, 120, 220),
	},
}
local function swordTier(player: Player)
	local level = tonumber(string.match(player:GetAttribute("RunLoadout") or "", "sword=(%d+)")) or 1
	return SLASH_TIERS[math.clamp(level, 1, #SLASH_TIERS)]
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
	local light = Instance.new("PointLight")
	light.Range, light.Brightness, light.Enabled = 10, 3, false
	light.Parent = head
	return { part = p, tail = tail, head = head, beam = beam, sparks = sparks, arc = arc, light = light }
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
	-- Ink slash at every tier: the black edge stays, the white takes the tier colour (wood, gold, energy blue, pink).
	-- Glowing it (LightEmission 1) washed out once the back slash made a full ring at tier 4+.
	s.arc.Color = ColorSequence.new(tier.light or tier.colors.Keypoints[2].Value)
	local inkR = r * (ink or 1)
	s.arc.Size = keys({ 0, inkR * 1.3 }, { 1, inkR * 1.45 }) -- crescent radius is ~0.95 x Size: just outside the arc, clear of the horde
	-- Rotation 0 points the crescent at +Z; the arc is centred on the middle of the swing
	s.arc.Rotation = NumberRange.new(math.deg((from + to) / 2) - 90)
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
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		draw(from + (to - from) * easeOut((t - CLOSE) / SWEEP), from + (to - from) * easeOut(t / SWEEP))
		if t >= SWEEP and not sparked then
			sparked = true
			s.sparks:Emit(tier.sparks)
			if ink then -- one ink crescent per slash; the echo's would stack into a muddy ring
				s.arc:Emit(1)
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
	if level == 5 then
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

Shared:WaitForChild("HordeFx").OnClientEvent:Connect(function(kind: string, ...)
	if kind == "slash" then
		local player, range, arc, back, lx, lz = ...
		local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local aim, half, tier = math.atan2(lz, lx), math.rad(arc / 2), swordTier(player)
		local side = -(swingSide[player] or 1)
		swingSide[player] = side
		slash(root, range, aim - half * side, aim + half * side, tier)
		if back then
			-- Smaller, a beat later: the two ink crescents read as two strokes instead of closing into a hoop
			task.delay(0.08, slash, root, range, aim + math.pi + half * side, aim + math.pi - half * side, tier, 0.7)
		end
	elseif kind == "axes" then
		receiveAxes(...)
	elseif kind == "fire" then
		local x, z, dx, dz, speed, range = ...
		local p = pooled(ballPool, function()
			return fxPart(Vector3.one * 1.3, Color3.fromRGB(255, 140, 50), Enum.PartType.Ball)
		end)
		table.insert(balls, { part = p, x = x, z = z, dx = dx, dz = dz, speed = speed, left = range })
	end
end)

-- Fire Ring: a flat glowing disc under every player whose loadout has it.
local RING = Config.Weapons.ring
local rings = {} -- Player -> part
local function ringRadius(player: Player): number?
	local lv = tonumber(string.match(player:GetAttribute("RunLoadout") or "", "ring=(%d)"))
	return lv and Config.weaponStats("ring", lv).Radius * (1 + (player:GetAttribute("RunArea") or 0))
end

local parts, cframes = {}, {}
RunService.RenderStepped:Connect(function(dt)
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
		local r = ringRadius(player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local ring = rings[player]
		if r and root then
			if not ring then
				ring = fxPart(Vector3.one, RING.Color, Enum.PartType.Cylinder)
				ring.Transparency = 0.75
				rings[player] = ring
			end
			ring.Size = Vector3.new(0.15, r * 2, r * 2)
			ring.CFrame = CFrame.new(root.Position.X, 0.1, root.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
		elseif ring then
			ring:Destroy()
			rings[player] = nil
		end
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
