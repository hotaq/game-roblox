-- GoblinVFX (ModuleScript, ReplicatedStorage.Goblin) - client-side effects for goblin enemies.
--
-- attach(model) gives a goblin its per-model effects (sword trail, eye light, glint, stun stars) and listens to
-- its Animator: every animation the server plays replicates here, and the timed events in GoblinAnimData fire
-- the matching effect. One-shot bursts (dust, sparks, smoke...) come from a single shared set of world-space
-- emitters, so 20 goblins cost the same emitters as one.
--
-- Skinned meshes don't move their parts with the animation, so the effects follow the rig's VFX_* bones:
-- each frame the locator attachments copy Bone.TransformedWorldCFrame (goblins within UpdateDistance only).
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.GoblinConfig)
local AnimData = require(script.Parent.GoblinAnimData)

local VFX = Config.VFX
local GoblinVFX = {}

local FALLBACK = { -- built-in textures used until the PNGs are uploaded
	Slash = "",
	Spark = "rbxasset://textures/particles/sparkles_main.dds",
	Burst = "rbxasset://textures/particles/sparkles_main.dds",
	Dust = "rbxasset://textures/particles/smoke_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Ring = "rbxasset://textures/particles/sparkles_main.dds",
	Pixel = "",
}

local function tex(key: string): string
	local id = Config.Textures[key]
	if not id or id == "" or id == "rbxassetid://0" then
		return FALLBACK[key]
	end
	return id
end

local function colors(a: Color3, b: Color3?): ColorSequence
	return ColorSequence.new(a, b or a)
end

local function curve(points: { { number } }): NumberSequence
	local kp = {}
	for _, p in points do
		table.insert(kp, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(kp)
end

local C = {
	Trail = colors(Color3.fromRGB(120, 230, 230), Color3.fromRGB(230, 255, 255)),
	TrailHeavy = colors(Color3.fromRGB(255, 160, 60), Color3.fromRGB(255, 70, 40)),
	Eye = Color3.fromRGB(255, 210, 60),
	EyeAngry = Color3.fromRGB(255, 90, 30),
}

-- Shared one-shot emitters: name -> ParticleEmitter properties. All particles live in world space.
local SPEC = {
	Sparks = {
		Texture = "Spark", Color = colors(Color3.fromRGB(255, 240, 170), Color3.fromRGB(255, 140, 40)),
		Size = curve({ { 0, 0.9 }, { 1, 0 } }), Lifetime = NumberRange.new(0.15, 0.3), Speed = NumberRange.new(14, 26),
		SpreadAngle = Vector2.new(70, 70), Drag = 6, Acceleration = Vector3.new(0, -40, 0), LightEmission = 1,
	},
	HitFlash = {
		Texture = "Burst", Color = colors(Color3.new(1, 1, 1), Color3.fromRGB(255, 230, 140)),
		Size = curve({ { 0, 1.5 }, { 1, 4 } }), Transparency = curve({ { 0, 0 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.12), Speed = NumberRange.new(0), LightEmission = 1, ZOffset = 1,
		Rotation = NumberRange.new(0, 360),
	},
	Dust = {
		Texture = "Dust", Color = colors(Color3.fromRGB(150, 120, 85), Color3.fromRGB(120, 95, 70)),
		Size = curve({ { 0, 0.7 }, { 1, 2 } }), Transparency = curve({ { 0, 0.25 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.45, 0.7), Speed = NumberRange.new(2, 4), SpreadAngle = Vector2.new(80, 80),
		Drag = 4, Acceleration = Vector3.new(0, 1, 0), Rotation = NumberRange.new(0, 360),
	},
	DustRing = {
		Texture = "Dust", Color = colors(Color3.fromRGB(160, 130, 95), Color3.fromRGB(120, 95, 70)),
		Size = curve({ { 0, 1.2 }, { 1, 3.4 } }), Transparency = curve({ { 0, 0.15 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(9, 13), SpreadAngle = Vector2.new(88, 88),
		Drag = 6, Acceleration = Vector3.new(0, 2, 0), Rotation = NumberRange.new(0, 360),
	},
	Ring = { -- flat on the ground: velocity points up, particle faces along it
		Texture = "Ring", Color = colors(Color3.fromRGB(255, 70, 40)), Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		Size = curve({ { 0, 1 }, { 1, 10 } }), Transparency = curve({ { 0, 0.1 }, { 0.7, 0.4 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.5), Speed = NumberRange.new(0.01), LightEmission = 1,
	},
	Smoke = {
		Texture = "Smoke", Color = colors(Color3.fromRGB(60, 60, 64), Color3.fromRGB(30, 30, 34)),
		Size = curve({ { 0, 1 }, { 1, 3.2 } }), Transparency = curve({ { 0, 0.3 }, { 1, 1 } }),
		Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(40, 40),
		Acceleration = Vector3.new(0, 2, 0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-30, 30),
	},
	Pixels = { -- dissolve cubes: green flecks drifting up and fading dark
		Texture = "Pixel", Color = colors(Color3.fromRGB(110, 190, 70), Color3.fromRGB(25, 35, 20)),
		Size = curve({ { 0, 0.45 }, { 1, 0.15 } }), Transparency = curve({ { 0, 0 }, { 0.8, 0.2 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(2, 5), SpreadAngle = Vector2.new(60, 60),
		Acceleration = Vector3.new(0, 6, 0), Drag = 1, Rotation = NumberRange.new(0, 90), RotSpeed = NumberRange.new(-90, 90),
	},
}

local fxFolder: Folder
local shared: { [string]: { att: Attachment, emitter: ParticleEmitter } } = {}

local function makeEmitter(spec, parent: Instance): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	for k, v in spec do
		e[k] = if k == "Texture" then tex(v) else v
	end
	e.Parent = parent
	return e
end

local function host(): Folder
	if not fxFolder then
		fxFolder = Instance.new("Folder")
		fxFolder.Name = "GoblinFX"
		local part = Instance.new("Part")
		part.Name = "SharedEmitters"
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
		part.Transparency, part.Size = 1, Vector3.one * 0.2
		part.Parent = fxFolder
		for name, spec in SPEC do
			local att = Instance.new("Attachment")
			att.Name = name
			att.Parent = part
			shared[name] = { att = att, emitter = makeEmitter(spec, att) }
		end
		fxFolder.Parent = Workspace
	end
	return fxFolder
end

function GoblinVFX.burst(name: string, position: Vector3, count: number)
	host()
	local s = shared[name]
	s.att.WorldCFrame = CFrame.new(position)
	s.emitter:Emit(count)
end

-- Server-confirmed hit (wired up in the integration stage); heavy = bigger sparks.
function GoblinVFX.impact(position: Vector3, heavy: boolean?)
	GoblinVFX.burst("HitFlash", position, 1)
	GoblinVFX.burst("Sparks", position, if heavy then 16 else 8)
end

local active: { [Model]: any } = {}

-- World CFrame of a named point: an extra Bone (VFX_*, Ear_*...) or, for R15 body joints, the MeshPart itself.
local function boneCF(h, name: string): CFrame?
	local b = h.bones[name]
	if b then
		return b.TransformedWorldCFrame
	end
	local p = h.model:FindFirstChild(name)
	return if p and p:IsA("BasePart") then p.CFrame else nil
end

local function ground(h, position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { h.model, host() }
	local hit = Workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -8, 0), params)
	return if hit then hit.Position else position
end

local function footDust(h, count: number)
	local l, r = boneCF(h, "LeftFoot"), boneCF(h, "RightFoot")
	if not (l and r) then
		return
	end
	local foot = if l.Position.Y < r.Position.Y then l else r -- the planted foot is the lower one
	GoblinVFX.burst("Dust", ground(h, foot.Position), count)
end

local function rootPos(h): Vector3 -- feet level under the HumanoidRootPart
	local root, hum = h.model:FindFirstChild("HumanoidRootPart"), h.model:FindFirstChildWhichIsA("Humanoid")
	if root and hum then
		return root.Position - Vector3.new(0, hum.HipHeight + root.Size.Y / 2, 0)
	end
	return h.model:GetPivot().Position
end

local function eyeFlare(h, seconds: number)
	if h.dead then
		return
	end
	h.light.Color, h.light.Brightness = C.EyeAngry, VFX.EyeLightBrightness * 4
	TweenService:Create(h.light, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Brightness = VFX.EyeLightBrightness,
		Color = C.Eye,
	}):Play()
end

local function dissolve(h)
	h.dead = true
	h.light.Enabled, h.trail.Enabled, h.stars.Enabled = false, false, false
	for _, d in h.model:GetDescendants() do
		if d:IsA("BasePart") then
			TweenService:Create(d, TweenInfo.new(VFX.DeathFadeTime), { LocalTransparencyModifier = 1 }):Play()
		end
	end
	task.spawn(function()
		for _ = 1, 4 do
			if not h.model.Parent then
				return
			end
			for _, part in h.model:GetChildren() do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					local jitter = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
					GoblinVFX.burst("Pixels", part.Position + jitter, 2)
				end
			end
			GoblinVFX.burst("Smoke", rootPos(h), 3)
			task.wait(VFX.DeathFadeTime / 4)
		end
	end)
end

local EVENTS = {
	Swing = function(h, anim)
		h.trail.Color = if anim == "HeavyAttack" then C.TrailHeavy else C.Trail
		h.trail.Enabled, h.trailAnim = true, anim
	end,
	HitEnd = function(h)
		task.delay(0.06, function()
			h.trail.Enabled = false
		end)
	end,
	Footstep = function(h)
		footDust(h, 4)
	end,
	LungeStart = function(h)
		footDust(h, 8)
		GoblinVFX.burst("DustRing", ground(h, rootPos(h)), 10)
	end,
	Telegraph = function(h)
		GoblinVFX.burst("Ring", ground(h, rootPos(h)) + Vector3.new(0, 0.1, 0), 1)
		h.glint:Emit(1)
		eyeFlare(h, 1.0)
	end,
	Impact = function(h)
		local tip = boneCF(h, "VFX_BladeTip")
		local p = ground(h, if tip then tip.Position else rootPos(h))
		GoblinVFX.burst("DustRing", p, 14)
		GoblinVFX.burst("Sparks", p + Vector3.new(0, 0.3, 0), 14)
	end,
	Alert = function(h)
		eyeFlare(h, 0.5)
	end,
	StunStars = function(h)
		h.stars.Enabled = true
	end,
	BodyFall = function(h)
		GoblinVFX.burst("DustRing", ground(h, rootPos(h)), 10)
	end,
	Dissolve = dissolve,
}
EVENTS.Footstep2 = EVENTS.Footstep

function GoblinVFX.fire(model: Model, event: string, anim: string?)
	local h = active[model]
	local f = EVENTS[event]
	if h and f then
		f(h, anim)
	end
end

local idToName = {}
for name, id in Config.Animations do
	if id ~= "rbxassetid://0" then
		idToName[id] = name
	end
end

local function watchAnimator(h, animator: Animator)
	local function onPlayed(track: AnimationTrack)
		local name = track.Animation and idToName[track.Animation.AnimationId]
		if not (name and AnimData[name]) then
			return
		end
		for _, t in h.tracks do
			if t.track == track then
				t.last = -1 -- replayed before we saw it stop: restart its events, don't double them
				return
			end
		end
		table.insert(h.tracks, { track = track, name = name, events = AnimData[name].events, last = -1 })
	end
	table.insert(h.conns, animator.AnimationPlayed:Connect(onPlayed))
	for _, track in animator:GetPlayingAnimationTracks() do -- goblin streamed in mid-animation
		onPlayed(track)
	end
end

function GoblinVFX.attach(model: Model)
	if active[model] then
		return active[model]
	end
	local h = { model = model, bones = {}, att = {}, tracks = {}, conns = {}, dead = false }
	for _, d in model:GetDescendants() do
		if d:IsA("Bone") then
			h.bones[d.Name] = d
		end
	end
	local anchor = Instance.new("Part")
	anchor.Name = model.Name .. "_VFX"
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency, anchor.Size = 1, Vector3.one * 0.2
	for _, name in { "BladeBase", "BladeTip", "Eyes", "HeadTop" } do
		local a = Instance.new("Attachment")
		a.Name = name
		a.Parent = anchor
		h.att[name] = a
	end
	h.anchor = anchor

	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = h.att.BladeBase, h.att.BladeTip
	trail.Texture, trail.TextureMode = tex("Slash"), Enum.TextureMode.Stretch
	trail.Lifetime, trail.MinLength, trail.LightEmission = VFX.TrailLifetime, 0.05, 0.7
	trail.Transparency = curve({ { 0, 0.15 }, { 1, 1 } })
	trail.Color, trail.Enabled = C.Trail, false
	trail.Parent = anchor
	h.trail = trail

	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Shadows = C.Eye, VFX.EyeLightBrightness, VFX.EyeLightRange, false
	light.Parent = h.att.Eyes
	h.light = light

	h.glint = makeEmitter({
		Texture = "Spark", Color = colors(Color3.new(1, 1, 1), Color3.fromRGB(255, 120, 60)), LockedToPart = true,
		Size = curve({ { 0, 0 }, { 0.3, 2.4 }, { 1, 0 } }), Lifetime = NumberRange.new(0.4), Speed = NumberRange.new(0),
		LightEmission = 1, ZOffset = 1, RotSpeed = NumberRange.new(180),
	}, h.att.BladeTip)
	h.stars = makeEmitter({
		Texture = "Spark", Color = colors(Color3.fromRGB(255, 230, 90)), LockedToPart = true,
		Size = curve({ { 0, 0 }, { 0.2, 0.6 }, { 1, 0 } }), Lifetime = NumberRange.new(0.9), Speed = NumberRange.new(1.5),
		SpreadAngle = Vector2.new(180, 20), Rate = 6, LightEmission = 1,
	}, h.att.HeadTop)
	h.stars.Enabled = false

	-- eyes glow through the imported SurfaceAppearance emissive map; no material change needed

	anchor.Parent = host()
	active[model] = h

	local animator = model:FindFirstChildWhichIsA("Animator", true)
	if animator then
		watchAnimator(h, animator)
	else
		table.insert(h.conns, model.DescendantAdded:Connect(function(d)
			if d:IsA("Animator") then
				watchAnimator(h, d)
			end
		end))
	end
	table.insert(h.conns, model.Destroying:Connect(function()
		GoblinVFX.detach(model)
	end))
	return h
end

function GoblinVFX.detach(model: Model)
	local h = active[model]
	if not h then
		return
	end
	active[model] = nil
	for _, c in h.conns do
		c:Disconnect()
	end
	h.anchor:Destroy()
end

-- Events between last and now (handles looped tracks wrapping past their end).
local function crossed(t, last: number, now: number, length: number): boolean
	if now >= last then
		return t > last and t <= now
	end
	return t > last and t <= length or t <= now
end

-- Only the nearest MaxActive goblins get bone tracking and animation events, and the nearest MaxEyeLights their eye
-- light: in a crowd of hundreds nobody can see the rest, and those bone reads alone cost ~1 ms a frame at 500.
local order = {}
RunService.PreSimulation:Connect(function()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local camPos = camera.CFrame.Position
	table.clear(order)
	for _, h in active do
		h.dist = (rootPos(h) - camPos).Magnitude
		table.insert(order, h)
	end
	table.sort(order, function(a, b)
		return a.dist < b.dist
	end)
	for rank, h in order do
		local model, dist = h.model, h.dist
		local near = rank <= VFX.MaxActive and dist < VFX.UpdateDistance
		if near and not h.preview then
			for name, a in h.att do
				local cf = boneCF(h, "VFX_" .. name)
				if cf then
					a.WorldCFrame = cf
				end
			end
		end
		h.light.Enabled = near and rank <= VFX.MaxEyeLights and not h.dead and dist < VFX.EyeLightDistance
		for i = #h.tracks, 1, -1 do
			local t = h.tracks[i]
			local track: AnimationTrack = t.track
			if not track.IsPlaying then
				if t.name == "Stun" then
					h.stars.Enabled = false
				end
				if t.name == h.trailAnim then -- interrupted mid-swing
					h.trail.Enabled = false
				end
				table.remove(h.tracks, i)
				continue
			end
			local now = track.TimePosition
			if near then
				for _, ev in t.events do
					if crossed(ev[2], t.last, now, track.Length) then
						GoblinVFX.fire(model, ev[1], t.name)
					end
				end
			end
			t.last = now
		end
	end
end)

-- Preview helper: sweeps the blade locators in an arc (no animation needed) so the trail can be judged.
function GoblinVFX.previewSwing(model: Model, heavy: boolean?)
	local h = active[model]
	if not h then
		return
	end
	h.preview = true
	h.trail.Color = if heavy then C.TrailHeavy else C.Trail
	local pivot = model:GetPivot()
	local center = pivot.Position + Vector3.new(0, 1.5, 0)
	local t0 = os.clock()
	local conn
	conn = RunService.PreSimulation:Connect(function()
		local a = math.clamp((os.clock() - t0) / 0.25, 0, 1)
		local dir = (pivot * CFrame.Angles(0, math.rad(90 - 180 * a), 0)).LookVector
		h.att.BladeBase.WorldCFrame = CFrame.new(center + dir * 1.5)
		h.att.BladeTip.WorldCFrame = CFrame.new(center + dir * 4)
		h.trail.Enabled = a > 0 and a < 1
		if a >= 1 then
			conn:Disconnect()
			task.delay(VFX.TrailLifetime, function()
				h.preview = false
			end)
		end
	end)
end

return GoblinVFX
