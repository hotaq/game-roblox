-- GoblinRunUI (LocalScript, StarterPlayer.StarterPlayerScripts)
-- The run's three screens in the Megabonk-style look (UI mockup board "HUD v2"): pixel font (Arcade), white text with
-- a dark outline straight on the game, no heavy boxes, everything at the edges so the horde stays in view.
--   HUD      (UI-kit look, GAME-40) top-left: kills, gems, HP pill with a heart badge, a row of weapon slots with LV;
--            top centre: run clock; bottom centre: XP pill with a level badge, passives above it; a small HP bar
--            under your feet. Shown while the player has a run (RunLevel
--            attribute, set by GoblinHorde). Top-left sits below Roblox's own menu buttons (IgnoreGuiInset off).
--   Level up 3 cards from Goblin.RunLevelUp, outlined in their rarity colour; tap one, then Take it! (two taps so a
--            stray tap can't pick); Reroll.
--   Results  from Goblin.RunOver: time, kills, level, damage share per weapon; Play Again (back to the arena) or Lobby.
-- Card text comes from GoblinConfig, so the server only sends {kind, id, level, rarity}.
-- Icons are pixel art from one sprite sheet (Config.Icons). Until Roblox approves that upload it won't load, so every
-- icon keeps a glyph-on-colour fallback underneath and swaps to the art as soon as the sheet loads.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Goblin")
local Config = require(Shared:WaitForChild("GoblinConfig"))
local W, P, R = Config.Weapons, Config.Passives, Config.Run
local player = Players.LocalPlayer

local FONT = Font.fromEnum(Enum.Font.Arcade)
local INK = Color3.fromRGB(26, 20, 32) -- outlines
local SHADE = Color3.fromRGB(20, 14, 30) -- translucent panels and dimming
local GOLD = Color3.fromRGB(255, 210, 90)
local GEM = Color3.fromRGB(95, 208, 255)
local RED = Color3.fromRGB(229, 72, 77)
local WHITE = Color3.new(1, 1, 1)

-- new(class, props, children): one instance with its properties and children.
local function new(class: string, props, children)
	local o = Instance.new(class)
	for k, v in props or {} do
		o[k] = v
	end
	for _, c in children or {} do
		c.Parent = o
	end
	return o
end
local function corner(r: number)
	return new("UICorner", { CornerRadius = UDim.new(0, r) })
end
local function stroke(t: number, color: Color3?)
	return new("UIStroke", { Thickness = t, Color = color or INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
-- Outlined text: white (or given colour) with a thick dark edge, readable on any part of the map.
local function text(props, outline: number?)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.FontFace = props.FontFace or FONT
	props.TextColor3 = props.TextColor3 or WHITE
	local label = new("TextLabel", props)
	new("UIStroke", { Thickness = outline or 2, Color = INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = label })
	return label
end
local function bar(size: UDim2, color: Color3)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = color, BorderSizePixel = 0 })
	local track = new("Frame", { Size = size, BackgroundColor3 = INK, BorderSizePixel = 0 }, { stroke(2), fill })
	return track, fill
end

-- UI-kit look (owner's reference 2026-10-28, the bright Figma UI v3): chunky rounded pieces with a thick ink outline,
-- glossy plastic fills, FredokaOne. Used by all three screens (GAME-40).
local KIT_FONT = Font.fromEnum(Enum.Font.FredokaOne)
local KIT_INK = Color3.fromRGB(20, 17, 43)
local KIT_RED = Color3.fromRGB(255, 59, 78)
local KIT_CYAN = Color3.fromRGB(32, 201, 230)
local KIT_YELLOW = Color3.fromRGB(255, 210, 63)
local KIT_TRACK = Color3.fromRGB(58, 52, 88)
local KIT_TILE = Color3.fromRGB(236, 240, 255)
local KIT_GREEN = Color3.fromRGB(61, 220, 90)
local KIT_BLUE = Color3.fromRGB(61, 139, 255)
local KIT_PURPLE = Color3.fromRGB(162, 89, 255)
local KIT_ORANGE = Color3.fromRGB(255, 154, 31)
local KIT_IDLE = Color3.fromRGB(170, 165, 190) -- a button that can't be pressed yet

local function kitText(props, outline: number?)
	props.FontFace = KIT_FONT
	local label = text(props, outline)
	label:FindFirstChildOfClass("UIStroke").Color = KIT_INK
	return label
end
local function pill()
	return new("UICorner", { CornerRadius = UDim.new(0.5, 0) })
end
-- Plastic shine: the top half keeps the colour, the bottom half is a shade darker.
local function gloss()
	local dark = Color3.fromRGB(205, 205, 215)
	return new("UIGradient", { Rotation = 90, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, WHITE), ColorSequenceKeypoint.new(0.5, WHITE),
		ColorSequenceKeypoint.new(0.52, dark), ColorSequenceKeypoint.new(1, dark),
	}) })
end
-- A pill bar: dark track, glossy fill, value text on top.
local function kitBar(width: number, height: number, color: Color3)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = color, BorderSizePixel = 0 }, { pill(), gloss() })
	local label = kitText({ Size = UDim2.fromScale(1, 1), Text = "", TextSize = height - 6, ZIndex = 2 })
	local track = new("Frame", { Size = UDim2.fromOffset(width, height), BackgroundColor3 = KIT_TRACK, BorderSizePixel = 0 }, { pill(), stroke(3, KIT_INK), fill, label })
	return track, fill, label
end
-- A round glossy badge that caps the left end of a bar.
local function badge(size: number, color: Color3)
	return new("Frame", { Size = UDim2.fromOffset(size, size), BackgroundColor3 = color, ZIndex = 3 }, { pill(), stroke(3, KIT_INK), gloss() })
end
-- A kit panel: white body under a red header strip with the title, thick ink outline; `body` items stack below.
local function panel(title: string, width: number, body)
	local header = new("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = KIT_RED, BorderSizePixel = 0 }, {
		corner(16),
		new("Frame", { Position = UDim2.new(0, 0, 1, -16), Size = UDim2.new(1, 0, 0, 16), BackgroundColor3 = KIT_RED, BorderSizePixel = 0 }), -- squares off the strip's bottom corners
		kitText({ Size = UDim2.fromScale(1, 1), Text = title, TextSize = 32, ZIndex = 2 }, 3),
	})
	local content = new("Frame", { Position = UDim2.fromOffset(0, 50), Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, {
		new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 16), PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20) }),
		new("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for _, item in body do
		item.Parent = content
	end
	return new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(width, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = WHITE }, { corner(16), stroke(4, KIT_INK), header, content })
end
-- Kit motion: an overlay fades in and its panel pops with a little overshoot; buttons and cards grow on hover and
-- squish when pressed (the press also works on touch).
local QUICK = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local function scaleOf(g: GuiObject): UIScale
	return g:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = g })
end
local function popIn(g: GuiObject, delay: number?, from: number?)
	local s = scaleOf(g)
	s.Scale = from or 0.4
	TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, delay or 0), { Scale = 1 }):Play()
end
local function showOverlay(overlay: GuiObject, body: GuiObject)
	overlay.BackgroundTransparency = 1
	overlay.Visible = true
	TweenService:Create(overlay, TweenInfo.new(0.2), { BackgroundTransparency = 0.35 }):Play()
	popIn(body)
end
local function bouncy(b: GuiButton, hover: number?)
	local s = scaleOf(b)
	local function to(v: number)
		TweenService:Create(s, QUICK, { Scale = v }):Play()
	end
	b.MouseEnter:Connect(function()
		to(hover or 1.06)
	end)
	b.MouseLeave:Connect(function()
		to(1)
	end)
	b.MouseButton1Down:Connect(function()
		to(0.92)
	end)
	b.MouseButton1Up:Connect(function()
		to(hover or 1.06)
	end)
end
-- A kit button: glossy colour pill, thick ink outline, white outlined label (change it through b.Label.Text).
-- Returns the holder (put that in layouts, toggle its Visible) and the button: UIScale scales around the AnchorPoint
-- and a scaled child reflows a UIListLayout, so the button sits centred in a fixed-size holder and grows in place.
local function button(label: string, color: Color3, width: number)
	local b = new("TextButton", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, AutoButtonColor = true, Text = "" }, {
		corner(14),
		stroke(3, KIT_INK),
		gloss(),
		kitText({ Name = "Label", Size = UDim2.fromScale(1, 1), Text = label, TextSize = 22 }),
	})
	bouncy(b)
	return new("Frame", { Size = UDim2.fromOffset(width, 50), BackgroundTransparency = 1 }, { b }), b
end
local function info(kind: string, id: string?)
	if kind == "weapon" then
		return W[id]
	elseif kind == "passive" then
		return P[id]
	end
	return { Name = "Snack", Icon = "+", Color = Color3.fromRGB(240, 90, 90) }
end
local function clock(seconds: number): string
	return string.format("%02d:%02d", seconds // 60, seconds % 60)
end
local function list(dir: Enum.FillDirection, pad: number, align: Enum.HorizontalAlignment?)
	return new("UIListLayout", { FillDirection = dir, Padding = UDim.new(0, pad), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = align or Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Center })
end

-- art(parent, fallback, tile): a sprite-sheet icon over `parent`; `fallback` instances show until the sheet has loaded,
-- and `tile` (a coloured frame) turns see-through once the art is up. setArt picks which icon it shows.
local ICONS = Config.Icons
local iconsReady = false
local arts = {}
-- Standalone pixel axe art; no upload/moderation dependency and no edits to the shared GAME-15 sheet.
local function axeIcon(parent)
	local holder = new("Frame", { Name = "AxeIcon", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 3, Parent = parent })
	local pixels = {
		"................", "..OOO.....OOO...", ".OEEEOOOOOEEEO..", ".OESSSGGGSSSEO..",
		".OESSSGGGSSSEO..", ".OESSSGGGSSSEO..", ".OEEEOHHHOEEEO..", "..OOO.OHO.OOO...",
		"......OHO.......", "......OHO.......", "......OHO.......", "......OBO.......",
		"......OBO.......", ".....OGGGO......", "......OOO.......", "................",
	}
	local palette = { O = INK, E = Color3.fromRGB(224,234,221), S = Color3.fromRGB(130,151,157),
		G = Color3.fromRGB(207,157,67), H = Color3.fromRGB(121,77,43), B = Color3.fromRGB(58,39,31) }
	for y, row in pixels do
		local x = 1
		while x <= #row do
			local c, last = row:sub(x,x), x
			while last < #row and row:sub(last+1,last+1) == c do last += 1 end
			if palette[c] then
				new("Frame", { BorderSizePixel = 0, BackgroundColor3 = palette[c], ZIndex = 3,
					Position = UDim2.fromScale((x-1)/16, (y-1)/16), Size = UDim2.fromScale((last-x+1)/16, 1/16), Parent = holder })
			end
			x = last + 1
		end
	end
	return holder
end
local function rocksIcon(parent)
	local holder=new("Frame",{Name="RocksIcon",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Visible=false,ZIndex=3,Parent=parent})
	local pixels={"................",".....GGGG.......","...GG....GG.....","..G........G....",".G..OOOO....G...",".G.OMMMLO...G...","G..OLSSSO....G..","G..OLSSSO....G..","G...OOOO..OOO.G.",".G.......OMMLO..",".G.......OLSSO..","..G......OLSSO..","...GG.....OOO...",".....GGGGG......","................","................"}
	local palette={O=INK,G=Color3.fromRGB(205,169,85),M=Color3.fromRGB(88,119,62),L=Color3.fromRGB(179,185,162),S=Color3.fromRGB(122,136,126)}
	for y,row in pixels do
		local x=1
		while x<=#row do
			local c,last=row:sub(x,x),x
			while last<#row and row:sub(last+1,last+1)==c do last+=1 end
			if palette[c] then new("Frame",{BorderSizePixel=0,BackgroundColor3=palette[c],ZIndex=3,Position=UDim2.fromScale((x-1)/16,(y-1)/16),Size=UDim2.fromScale((last-x+1)/16,1/16),Parent=holder}) end
			x=last+1
		end
	end
	return holder
end
local roundTwoIcons={totem=true,duration=true,projectile=true,speed=true,luck=true}
local function roundTwoIcon(parent,key)
	local holder=new("Frame",{Name=key.."Icon",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=3,Parent=parent})
	local function pixel(x,y,w,h,color)
		new("Frame",{BorderSizePixel=0,Position=UDim2.fromScale(x/16,y/16),Size=UDim2.fromScale(w/16,h/16),BackgroundColor3=color,ZIndex=3,Parent=holder})
	end
	local gold=Color3.fromRGB(220,180,88)
	if key=="totem"then
		pixel(2,13,12,2,INK);pixel(3,12,10,2,Color3.fromRGB(139,153,132));pixel(5,5,6,8,INK)
		pixel(6,6,4,6,Color3.fromRGB(106,126,119));pixel(4,4,8,2,gold);pixel(6,7,1,1,GEM);pixel(9,7,1,1,GEM)
		pixel(7,9,2,3,gold);pixel(7,1,2,3,GEM);pixel(3,5,1,5,INK);pixel(12,5,1,5,INK)
	else
		pixel(2,2,12,13,INK);pixel(3,3,10,10,P[key].Color);pixel(4,13,9,1,WHITE);pixel(3,3,2,10,gold)
		local patterns={duration={"#####",".#.#.","..#..",".#.#.","#####"},projectile={"..#..","..##.","#####","..##.","..#.."},speed={"#.#..",".#.#.","..#.#",".#.#.","#.#.."},luck={".#.#.","#####",".###.","#####",".#.#."}}
		for y,row in patterns[key]do for x=1,#row do if row:sub(x,x)=="#"then pixel(x+5,y+4,1,1,INK)end end end
	end
	return holder
end
local function setArt(a, key: string?)
	a.key = key
	local cell = key and ICONS.Cells[key]
	if cell then
		a.image.ImageRectOffset = Vector2.new(cell[1], cell[2])
	end
	local showArt = iconsReady and cell ~= nil
	local stand = if showArt then nil else (key and key:gsub("^evo_","")) -- reuse base art while an evolved atlas cell is unavailable
	if a.roundTwo and a.roundTwoKey~=stand then a.roundTwo:Destroy();a.roundTwo=nil end
	if roundTwoIcons[stand]and not a.roundTwo then a.roundTwo=roundTwoIcon(a.image.Parent,stand);a.roundTwoKey=stand end
	if stand == "axe" and not a.axe then a.axe = axeIcon(a.image.Parent) end
	if a.axe then a.axe.Visible = stand == "axe" end
	if stand=="rocks" and not a.rocks then a.rocks=rocksIcon(a.image.Parent) end
	if a.rocks then a.rocks.Visible=stand=="rocks" end
	a.image.Visible = showArt
	for _, f in a.fallback do
		f.Visible = not showArt and stand ~= "axe" and stand ~= "rocks" and not roundTwoIcons[stand]
	end
	if a.tile then
		a.tile.BackgroundTransparency = if showArt then 1 else 0
		local edge = a.tile:FindFirstChildOfClass("UIStroke")
		if edge then
			edge.Enabled = not showArt
		end
	end
end
local function art(parent: GuiObject, fallback, tile: Frame?)
	local image = new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = ICONS.Image, ImageRectSize = Vector2.new(ICONS.Cell, ICONS.Cell), ZIndex = 3, Visible = false, Parent = parent })
	local a = { image = image, fallback = fallback, tile = tile }
	table.insert(arts, a)
	return a
end
task.spawn(function() -- wait until the sheet loads, then swap every icon to its art
	-- A shown ImageLabel's IsLoaded, not PreloadAsync: PreloadAsync reports Failure for this sheet even when it loads.
	local probe = new("ScreenGui", { Name = "GoblinIconProbe" }, { new("ImageLabel", { Image = ICONS.Image, Size = UDim2.fromOffset(1, 1), ImageTransparency = 0.99, BackgroundTransparency = 1 }) })
	probe.Parent = player:WaitForChild("PlayerGui")
	while not probe:FindFirstChildOfClass("ImageLabel").IsLoaded do
		task.wait(1)
	end
	probe:Destroy()
	iconsReady = true
	for _, a in arts do
		if a.image.Parent then
			setArt(a, a.key)
		end
	end
end)

local gui = new("ScreenGui", { Name = "GoblinRunUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
local scale = new("UIScale", {}) -- fits the fixed-size overlays to small phones
scale.Parent = gui

---------------------------------------------------------------- HUD

-- An item slot: an empty kit tile (always shown) holding the item's icon tile (glyph on the item's colour until the
-- sheet loads); LV text under it (weapons) or a number in the corner (passives). Both hide with the icon tile.
local function icon(size: number, under: boolean)
	local inner = size - 10
	local glyph = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, FontFace = KIT_FONT, TextSize = inner * 0.6, TextColor3 = KIT_INK, Text = "" })
	local tile = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(inner, inner), BackgroundColor3 = WHITE }, { corner(6), stroke(2, KIT_INK), glyph })
	local slot = new("Frame", { Size = UDim2.fromOffset(size, size), BackgroundColor3 = KIT_TILE }, { corner(10), stroke(3, KIT_INK), gloss(), tile })
	local level = if under
		then kitText({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 8), Size = UDim2.fromOffset(size + 12, 14), TextSize = 14, Text = "" })
		else kitText({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 10, 1, 10), Size = UDim2.fromOffset(16, 14), TextSize = 14, Text = "" })
	level.Parent = tile
	level.ZIndex = 4 -- above the art
	return { slot = slot, tile = tile, glyph = glyph, level = level, prefix = if under then "LV " else "", art = art(tile, { glyph }, tile) }
end

local killLabel = kitText({ Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, Text = "0", TextSize = 18, LayoutOrder = 2 })
local gemLabel = kitText({ Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, Text = "0", TextSize = 18, TextColor3 = Color3.fromRGB(159, 228, 255), LayoutOrder = 4 })
local stats = new("Frame", { Size = UDim2.fromOffset(200, 20), BackgroundTransparency = 1, LayoutOrder = 1 }, {
	list(Enum.FillDirection.Horizontal, 5),
	killLabel,
	gemLabel,
})
-- Skull and gem: drawn with frames until the icon sheet loads.
do
	local eyes = {
		new("Frame", { Position = UDim2.fromOffset(4, 6), Size = UDim2.fromOffset(3, 3), BackgroundColor3 = INK, BorderSizePixel = 0 }),
		new("Frame", { Position = UDim2.fromOffset(9, 6), Size = UDim2.fromOffset(3, 3), BackgroundColor3 = INK, BorderSizePixel = 0 }),
	}
	local skull = new("Frame", { Size = UDim2.fromOffset(16, 16), BackgroundColor3 = WHITE, LayoutOrder = 1, Parent = stats }, { corner(8), stroke(2), eyes[1], eyes[2] })
	setArt(art(skull, eyes, skull), "skull")
	local diamond = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(9, 9), Rotation = 45, BackgroundColor3 = GEM }, { stroke(2) })
	local gemHolder = new("Frame", { Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1, LayoutOrder = 3, Parent = stats }, { diamond })
	setArt(art(gemHolder, { diamond }), "gem")
end
-- HP: red pill bar capped by a white heart badge.
local hpTrack, hpFill, hpLabel = kitBar(196, 24, KIT_RED)
hpTrack.Position = UDim2.fromOffset(22, 6)
local heart = badge(36, WHITE)
do
	local plus = kitText({ Size = UDim2.fromScale(1, 1), Text = "+", TextSize = 24, TextColor3 = KIT_RED })
	local holder = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.78, 0.78), BackgroundTransparency = 1, Parent = heart }, { plus })
	setArt(art(holder, { plus }), "heart")
end
local hpGroup = new("Frame", { Size = UDim2.fromOffset(220, 36), BackgroundTransparency = 1, LayoutOrder = 2 }, { hpTrack, heart })
local weaponSlots = {}
local weaponRow = new("Frame", { Size = UDim2.fromOffset(R.WeaponSlots * 56 - 8, 70), BackgroundTransparency = 1, LayoutOrder = 3 }, {
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})
for k = 1, R.WeaponSlots do
	local s = icon(48, true)
	s.slot.LayoutOrder = k
	s.slot.Parent = weaponRow
	weaponSlots[k] = s
end
local topLeft = new("Frame", { Position = UDim2.fromOffset(14, 8), Size = UDim2.fromOffset(230, 160), BackgroundTransparency = 1 }, {
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	stats,
	hpGroup,
	weaponRow,
})

local timeLabel = kitText({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.fromOffset(160, 36), Text = "00:00", TextSize = 34 }, 3)

-- XP along the bottom centre: cyan pill bar capped by a yellow level badge; passives sit just above it.
local xpTrack, xpFill, xpLabel = kitBar(340, 24, KIT_CYAN)
xpTrack.Position = UDim2.fromOffset(24, 9)
local levelBadge = badge(42, KIT_YELLOW)
levelBadge.AnchorPoint, levelBadge.Position = Vector2.new(0.5, 0.5), UDim2.fromOffset(21, 21) -- pulses from its centre
local levelLabel = kitText({ Size = UDim2.fromScale(1, 1), Text = "1", TextSize = 22 })
levelLabel.Parent = levelBadge
local bottomBar = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(364, 42), BackgroundTransparency = 1 }, { xpTrack, levelBadge })

local passiveSlots = {}
local passiveRow = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -62), Size = UDim2.fromOffset(R.PassiveSlots * 44, 36), BackgroundTransparency = 1 }, {
	list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center),
})
for k = 1, R.PassiveSlots do
	local s = icon(36, false)
	s.slot.LayoutOrder = k
	s.slot.Parent = passiveRow
	passiveSlots[k] = s
end

local hud = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, { topLeft, timeLabel, bottomBar, passiveRow })
hud.Parent = gui

-- Small HP bar under your own feet (Megabonk-style), so your eyes can stay on the fight.
local feetTrack, feetFill = bar(UDim2.fromScale(1, 1), RED)
local feet = new("BillboardGui", { Name = "GoblinRunFeetHP", Size = UDim2.fromOffset(44, 7), StudsOffset = Vector3.new(0, -3.1, 0), AlwaysOnTop = true, Enabled = false, ResetOnSpawn = false }, { feetTrack })

local function fillSlots(slots, items: string, defs)
	local owned = {}
	for id, lv in string.gmatch(items or "", "(%w+)=(%d+)") do
		table.insert(owned, { id = id, lv = lv })
	end
	for k, s in slots do
		local it = owned[k]
		s.tile.Visible = it ~= nil
		if it then
			s.tile.BackgroundColor3 = defs[it.id].Color
			s.glyph.Text = defs[it.id].Icon
			s.level.Text = if defs==W and tonumber(it.lv)==6 then "EVO"else s.prefix .. it.lv
			s.level.TextColor3=if defs==W and tonumber(it.lv)==6 then GOLD else WHITE
			setArt(s.art, if defs==W and tonumber(it.lv)==6 then "evo_"..it.id else it.id)
		end
	end
end

local shownLevel
local function refreshHUD()
	local level = player:GetAttribute("RunLevel")
	hud.Visible = level ~= nil
	feet.Enabled = level ~= nil
	if not level then
		return
	end
	levelLabel.Text = tostring(level)
	if level ~= shownLevel then
		if shownLevel then
			popIn(levelBadge, 0, 1.6) -- the badge pulses on a level-up (not when the HUD first shows)
		end
		shownLevel = level
	end
	local xp, xpNext = player:GetAttribute("RunXP") or 0, player:GetAttribute("RunXPNext") or 1
	xpFill.Size = UDim2.fromScale(math.clamp(xp / xpNext, 0, 1), 1)
	xpLabel.Text = string.format("%d / %d", math.floor(xp), math.floor(xpNext))
	killLabel.Text = tostring(player:GetAttribute("RunKills") or 0)
	gemLabel.Text = tostring(player:GetAttribute("RunGems") or 0)
	local w, p = string.match(player:GetAttribute("RunLoadout") or ";", "^(.-);(.*)$")
	fillSlots(weaponSlots, w, W)
	fillSlots(passiveSlots, p, P)
end
player.AttributeChanged:Connect(refreshHUD)

local levelUp: Frame -- the level-up overlay, built below
RunService.Heartbeat:Connect(function()
	local start = player:GetAttribute("RunStart")
	if start and not levelUp.Visible then -- the server stops the run clock while a card is being picked
		timeLabel.Text = clock(Workspace:GetServerTimeNow() - start)
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		local f = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
		hpFill.Size, feetFill.Size = UDim2.fromScale(f, 1), UDim2.fromScale(f, 1)
		hpLabel.Text = string.format("%d / %d", math.ceil(hum.Health), hum.MaxHealth)
		feet.Adornee = char:FindFirstChild("HumanoidRootPart")
	end
end)

---------------------------------------------------------------- level up

local KIT_CARD = { KIT_CYAN, KIT_BLUE, KIT_PURPLE } -- card colour per rarity (common, rare, epic); evolve cards are orange
local levelSub = kitText({ Size = UDim2.fromOffset(500, 22), Text = "PICK ONE", TextSize = 20, TextColor3 = KIT_INK, LayoutOrder = 1 }, 0)
local cardRow = new("Frame", { Size = UDim2.fromOffset(3 * 196 + 2 * 14, 264), BackgroundTransparency = 1, LayoutOrder = 2 }, {
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 14) }),
})
local rerollHolder, rerollButton = button("REROLL (2)", KIT_CYAN, 180)
local takeHolder, takeButton = button("TAP A CARD", KIT_IDLE, 180)
levelUp = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = SHADE, BackgroundTransparency = 0.35, Visible = false, ZIndex = 5 }, {
	panel("LEVEL UP!", 3 * 196 + 2 * 14 + 40, {
		levelSub,
		cardRow,
		new("Frame", { Size = UDim2.fromOffset(380, 50), BackgroundTransparency = 1, LayoutOrder = 9 }, {
			list(Enum.FillDirection.Horizontal, 14, Enum.HorizontalAlignment.Center),
			rerollHolder,
			takeHolder,
		}),
	}),
})
levelUp.Parent = gui
local levelPanel = levelUp:FindFirstChildOfClass("Frame")

local picked: number? = nil
local currentOfferId
local cardButtons = {}

local function cardText(c)
	local def = info(c.kind, c.id)
	local rarity = R.Rarity[c.rarity] or R.Rarity[1]
	if c.kind=="evolve"then
		local e=Config.Evolutions[c.id];local w=W[c.id]
		return {Name=e.Name,Icon=w.Icon,Color=w.Color},{Name="EVOLVE",Color=GOLD},"LV5 + "..string.upper(P[e.Passive].Name),e.Text,false
	elseif c.kind == "weapon" then
		local desc=def.Levels[c.level].Text
		if c.level==5 then desc..="\nEvolve with "..P[Config.Evolutions[c.id].Passive].Name end
		return def, rarity, if c.level == 1 then "NEW WEAPON" else string.format("LV %d > %d", c.level - 1, c.level), desc, c.level == 1
	elseif c.kind == "passive" then
		local amount=Config.passiveAmount(c.id,c.rarity)
		return def, rarity, if c.level == 1 then "NEW PASSIVE" else string.format("LV %d > %d", c.level - 1, c.level), string.format(def.Text, math.round(amount*(if def.Flat then 1 else 100))), c.level == 1
	end
	return def, rarity, "", string.format("Heal %d HP", R.Heal), false
end

local function selectCard(k: number?)
	picked = k
	for i, b in cardButtons do
		b.stroke.Color = if i == k then KIT_YELLOW else KIT_INK
		b.stroke.Thickness = if i == k then 6 else 3
		b.button.Position = UDim2.new(0.5, 0, 1, if i == k then -8 else 0) -- lifted when picked
	end
	takeButton.Label.Text = if k then "TAKE IT!" else "TAP A CARD"
	takeButton.BackgroundColor3 = if k then KIT_GREEN else KIT_IDLE
end

local function showCards(cards, rerolls: number, level: number, offerId)
	currentOfferId=offerId
	for _, b in cardButtons do
		b.holder:Destroy()
	end
	table.clear(cardButtons)
	for i = #arts, 1, -1 do -- forget the old cards' icons
		if not arts[i].image.Parent then
			table.remove(arts, i)
		end
	end
	for k, c in cards do
		local def, rarity, levelText, desc, isNew = cardText(c)
		local s = stroke(3, KIT_INK)
		local glyph = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, FontFace = KIT_FONT, Text = def.Icon, TextSize = 30, TextColor3 = KIT_INK })
		local iconTile = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(56, 56), BackgroundColor3 = def.Color }, { corner(8), stroke(2, KIT_INK), glyph })
		setArt(art(iconTile, { glyph }, iconTile), if c.kind == "heal" then "heart" elseif c.kind == "evolve" then "evo_"..c.id else c.id)
		-- glossy tile in the rarity's colour: rarity top-left, NEW! pill top-right, icon on a white plate, name,
		-- yellow level pill, description on a white box
		local b = new("TextButton", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromOffset(196, 236), BackgroundColor3 = if c.kind == "evolve" then KIT_ORANGE else (KIT_CARD[c.rarity] or KIT_CYAN), Text = "", AutoButtonColor = false }, {
			corner(16),
			s,
			gloss(),
			kitText({ Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(100, 18), Text = rarity.Name, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left }),
			new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 30), Size = UDim2.fromOffset(70, 70), BackgroundColor3 = WHITE }, { corner(14), stroke(3, KIT_INK), iconTile }),
			kitText({ Position = UDim2.fromOffset(6, 104), Size = UDim2.new(1, -12, 0, 26), Text = def.Name, TextSize = 22 }),
			new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 134), Size = UDim2.fromOffset(150, 22), BackgroundColor3 = KIT_YELLOW, Visible = levelText ~= "" }, {
				pill(),
				stroke(2, KIT_INK),
				kitText({ Size = UDim2.fromScale(1, 1), Text = levelText, TextSize = 14, TextColor3 = KIT_INK }, 0),
			}),
			new("Frame", { Position = UDim2.fromOffset(8, 162), Size = UDim2.new(1, -16, 0, 66), BackgroundColor3 = WHITE }, {
				corner(10),
				kitText({ Position = UDim2.fromOffset(6, 4), Size = UDim2.new(1, -12, 1, -8), Text = desc, TextSize = 14, TextWrapped = true, TextColor3 = KIT_INK }, 0),
			}),
		})
		if isNew then
			new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 6), Size = UDim2.fromOffset(52, 20), BackgroundColor3 = KIT_YELLOW, Parent = b }, {
				pill(),
				stroke(2, KIT_INK),
				kitText({ Size = UDim2.fromScale(1, 1), Text = "NEW!", TextSize = 13, TextColor3 = KIT_INK }, 0),
			})
		end
		local holder = new("Frame", { Size = UDim2.fromOffset(196, 244), BackgroundTransparency = 1 }, { b })
		holder.Parent = cardRow
		-- anchored bottom-centre, so the pop and the hover grow upward (never into the buttons) and the fixed-size
		-- holder keeps the row from reflowing
		popIn(b, 0.08 + 0.07 * k, 0) -- the cards pop in one after another
		bouncy(b, 1.04)
		b.Activated:Connect(function()
			selectCard(k)
		end)
		cardButtons[k] = { holder = holder, button = b, stroke = s }
	end
	levelSub.Text = string.format("LV %d  -  PICK ONE", level)
	rerollButton.Label.Text = string.format("REROLL (%d)", rerolls)
	rerollHolder.Visible = rerolls > 0
	selectCard(nil)
	if not levelUp.Visible then -- a reroll only re-deals the cards
		showOverlay(levelUp, levelPanel)
	end
end

Shared:WaitForChild("RunLevelUp").OnClientEvent:Connect(showCards)
takeButton.Activated:Connect(function()
	if picked then
		levelUp.Visible = false
		Shared.RunPick:FireServer(picked,currentOfferId)
	end
end)
rerollButton.Activated:Connect(function()
	Shared.RunReroll:FireServer(currentOfferId)
end)

---------------------------------------------------------------- results

-- A stat: small label over a big number on a glossy colour tile, centred in a fixed-size holder so its pop-in
-- doesn't reflow the row.
local statTiles = {}
local function stat(label: string, order: number, color: Color3)
	local value = kitText({ Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 36), Text = "", TextSize = 32 }, 3)
	local tile = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundColor3 = color }, {
		corner(14),
		stroke(3, KIT_INK),
		gloss(),
		kitText({ Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 20), Text = label, TextSize = 15 }),
		value,
	})
	table.insert(statTiles, tile)
	return new("Frame", { Size = UDim2.fromOffset(176, 70), BackgroundTransparency = 1, LayoutOrder = order }, { tile }), value
end
local timeStat, timeValue = stat("SURVIVED", 1, KIT_CYAN)
local killStat, killValue = stat("GOBLINS BONKED", 2, KIT_PURPLE)
local levelStat, levelValue = stat("LEVEL", 3, KIT_ORANGE)
local damageList = new("Frame", { Size = UDim2.fromOffset(560, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 3 }, {
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local lobbyHolder, lobbyButton = button("LOBBY", KIT_CYAN, 150)
local againHolder, againButton = button("PLAY AGAIN", KIT_GREEN, 200)
local results = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = SHADE, BackgroundTransparency = 0.35, Visible = false, ZIndex = 6 }, {
	panel("GREAT RUN!", 600, {
		new("Frame", { Size = UDim2.new(1, 0, 0, 70), BackgroundTransparency = 1, LayoutOrder = 2 }, {
			list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center),
			timeStat,
			killStat,
			levelStat,
		}),
		damageList,
		new("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1, LayoutOrder = 9 }, {
			list(Enum.FillDirection.Horizontal, 14, Enum.HorizontalAlignment.Center),
			lobbyHolder,
			againHolder,
		}),
	}),
})
results.Parent = gui
local resultsPanel = results:FindFirstChildOfClass("Frame")

Shared:WaitForChild("RunOver").OnClientEvent:Connect(function(r)
	levelUp.Visible = false
	timeValue.Text = clock(r.time)
	killValue.Text = tostring(r.kills)
	levelValue.Text = tostring(r.level)
	for _, c in damageList:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local total = 0
	for _, d in r.damage do
		total += d.amount
	end
	table.sort(r.damage, function(a, b)
		return a.amount > b.amount
	end)
	for k, d in r.damage do
		local def = W[d.id]
		local pct = if total > 0 then math.round(d.amount / total * 100) else 0
		local track, fill = kitBar(270, 16, def.Color)
		track.Position = UDim2.fromOffset(200, 3)
		fill.Size = UDim2.fromScale(pct / 100, 1)
		new("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = k, Parent = damageList }, {
			kitText({ Size = UDim2.fromOffset(190, 22), Text = if d.level==6 then string.upper(Config.Evolutions[d.id].Name).." EVO"else string.format("%s LV %d", string.upper(def.Name), d.level), TextSize = 16, TextColor3 = KIT_INK, TextXAlignment = Enum.TextXAlignment.Left }, 0),
			track,
			kitText({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(60, 22), Text = pct .. "%", TextSize = 16, TextColor3 = KIT_INK, TextXAlignment = Enum.TextXAlignment.Right }, 0),
		})
	end
	showOverlay(results, resultsPanel)
	for k, tile in statTiles do
		popIn(tile, 0.1 + 0.07 * k, 0)
	end
end)
againButton.Activated:Connect(function()
	results.Visible = false
	Shared.RunRestart:FireServer()
end)
lobbyButton.Activated:Connect(function()
	results.Visible = false
	Shared.RunLobby:FireServer()
end)

-- Fit the ~660x420 kit panels on small screens (and let them grow a little on big ones).
local function fit()
	local v = Workspace.CurrentCamera.ViewportSize
	scale.Scale = math.clamp(math.min(v.X / 690, (v.Y - 20) / 440), 0.6, 1.3)
end
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
fit()
gui.Parent = player:WaitForChild("PlayerGui")
feet.Parent = player.PlayerGui
refreshHUD()
