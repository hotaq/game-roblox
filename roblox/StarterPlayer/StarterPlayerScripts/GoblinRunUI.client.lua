-- GoblinRunUI (LocalScript, StarterPlayer.StarterPlayerScripts)
-- The run's three screens in the Megabonk-style look (UI mockup board "HUD v2"): pixel font (Arcade), white text with
-- a dark outline straight on the game, no heavy boxes, everything at the edges so the horde stays in view.
--   HUD      top-left: kills, gems, HP bar, 2x2 weapons with LV; top centre: run clock; top right: LV + thin XP bar;
--            bottom centre: passives; a small HP bar under your feet. Shown while the player has a run (RunLevel
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
	props.FontFace = FONT
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
local function button(label: string, color: Color3, textColor: Color3, width: number)
	local b = new("TextButton", { Size = UDim2.fromOffset(width, 44), BackgroundColor3 = color, AutoButtonColor = true, FontFace = FONT, Text = label, TextSize = 18, TextColor3 = textColor }, { corner(6), stroke(3) })
	return b
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

-- An item icon: glyph on the item's colour; LV text under it (weapons) or a number in the corner (passives).
local function icon(size: number, under: boolean)
	local glyph = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, FontFace = FONT, TextSize = size * 0.65, TextColor3 = INK, Text = "" })
	local tile = new("Frame", { Size = UDim2.fromOffset(size, size), BackgroundColor3 = WHITE }, { corner(6), stroke(2), glyph })
	local level = if under
		then text({ Position = UDim2.fromOffset(-6, size + 1), Size = UDim2.fromOffset(size + 12, 12), TextSize = 11, Text = "" })
		else text({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 6, 1, 8), Size = UDim2.fromOffset(16, 14), TextSize = 12, Text = "" })
	level.Parent = tile
	level.ZIndex = 4 -- above the art
	return { tile = tile, glyph = glyph, level = level, prefix = if under then "LV " else "", art = art(tile, { glyph }, tile) }
end

local killLabel = text({ Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, Text = "0", TextSize = 16, LayoutOrder = 2 })
local gemLabel = text({ Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, Text = "0", TextSize = 16, TextColor3 = Color3.fromRGB(159, 228, 255), LayoutOrder = 4 })
local stats = new("Frame", { Size = UDim2.fromOffset(180, 18), BackgroundTransparency = 1, LayoutOrder = 1 }, {
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
local hpTrack, hpFill = bar(UDim2.fromOffset(168, 14), RED)
hpTrack.LayoutOrder = 2
local hpLabel = text({ Size = UDim2.fromScale(1, 1), Text = "100 / 100", TextSize = 11, ZIndex = 2 })
hpLabel.Parent = hpTrack
local weaponSlots = {}
local weaponGrid = new("Frame", { Size = UDim2.fromOffset(92, 100), BackgroundTransparency = 1, LayoutOrder = 3 }, {
	new("UIGridLayout", { CellSize = UDim2.fromOffset(34, 48), CellPadding = UDim2.fromOffset(12, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
})
for k = 1, R.WeaponSlots do
	local s = icon(34, true)
	-- the grid sizes its children to the 34x48 cell, so the tile sits in a holder with room for the LV line
	new("Frame", { BackgroundTransparency = 1, LayoutOrder = k, Parent = weaponGrid }, { s.tile })
	weaponSlots[k] = s
end
local topLeft = new("Frame", { Position = UDim2.fromOffset(14, 8), Size = UDim2.fromOffset(190, 160), BackgroundTransparency = 1 }, {
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	stats,
	hpTrack,
	weaponGrid,
})

local timeLabel = text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.fromOffset(160, 34), Text = "00:00", TextSize = 32 }, 3)

local levelLabel = text({ Size = UDim2.fromOffset(150, 28), Text = "LV 1", TextSize = 28, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Right }, 3)
local xpTrack, xpFill = bar(UDim2.fromOffset(150, 8), GEM)
xpTrack.Position = UDim2.fromOffset(0, 32)
local topRight = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 4), Size = UDim2.fromOffset(150, 42), BackgroundTransparency = 1 }, { levelLabel, xpTrack })

local passiveSlots = {}
local passiveRow = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(R.PassiveSlots * 38, 30), BackgroundTransparency = 1 }, {
	list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center),
})
for k = 1, R.PassiveSlots do
	local s = icon(30, false)
	s.tile.LayoutOrder = k
	s.tile.Parent = passiveRow
	passiveSlots[k] = s
end

local hud = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, { topLeft, timeLabel, topRight, passiveRow })
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

local function refreshHUD()
	local level = player:GetAttribute("RunLevel")
	hud.Visible = level ~= nil
	feet.Enabled = level ~= nil
	if not level then
		return
	end
	levelLabel.Text = "LV " .. level
	xpFill.Size = UDim2.fromScale(math.clamp((player:GetAttribute("RunXP") or 0) / (player:GetAttribute("RunXPNext") or 1), 0, 1), 1)
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

local levelTitle = text({ Size = UDim2.fromOffset(500, 40), Text = "LEVEL UP!", TextSize = 36, TextColor3 = GOLD, LayoutOrder = 1 }, 3)
local levelSub = text({ Size = UDim2.fromOffset(500, 20), Text = "PICK ONE", TextSize = 15, LayoutOrder = 2 })
local cardRow = new("Frame", { Size = UDim2.fromOffset(3 * 196 + 2 * 14, 236), BackgroundTransparency = 1, LayoutOrder = 3 }, {
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 14) }),
})
local rerollButton = button("REROLL (2)", Color3.fromRGB(74, 63, 94), WHITE, 170)
local takeButton = button("TAP A CARD", Color3.fromRGB(140, 132, 150), INK, 170)
levelUp = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = SHADE, BackgroundTransparency = 0.35, Visible = false, ZIndex = 5 }, {
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(640, 340), BackgroundTransparency = 1 }, {
		new("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		levelTitle,
		levelSub,
		cardRow,
		new("Frame", { Size = UDim2.fromOffset(360, 48), BackgroundTransparency = 1, LayoutOrder = 9 }, {
			list(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center),
			rerollButton,
			takeButton,
		}),
	}),
})
levelUp.Parent = gui

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
		return def, rarity, if c.level == 1 then "NEW" else string.format("LV %d > %d", c.level - 1, c.level), string.format(def.Text, math.round(amount*(if def.Flat then 1 else 100))), c.level == 1
	end
	return def, rarity, "", string.format("Heal %d HP", R.Heal), false
end

local function selectCard(k: number?)
	picked = k
	for i, b in cardButtons do
		b.stroke.Color = if i == k then GOLD else b.rarityColor
		b.stroke.Thickness = if i == k then 5 else 3
		b.button.Position = UDim2.fromOffset(0, if i == k then 0 else 8) -- lifted when picked
	end
	takeButton.Text = if k then "TAKE IT!" else "TAP A CARD"
	takeButton.BackgroundColor3 = if k then GOLD else Color3.fromRGB(140, 132, 150)
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
		local s = stroke(3, rarity.Color)
		local glyph = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, FontFace = FONT, Text = def.Icon, TextSize = 30, TextColor3 = INK })
		local iconTile = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 30), Size = UDim2.fromOffset(64, 64), BackgroundColor3 = def.Color }, { corner(8), stroke(3), glyph })
		setArt(art(iconTile, { glyph }, iconTile), if c.kind == "heal" then "heart" elseif c.kind == "evolve" then "evo_"..c.id else c.id)
		local b = new("TextButton", { Size = UDim2.fromOffset(196, 226), Position = UDim2.fromOffset(0, 8), BackgroundColor3 = SHADE, BackgroundTransparency = 0.15, Text = "", AutoButtonColor = false }, {
			corner(8),
			s,
			text({ Position = UDim2.fromOffset(10, 6), Size = UDim2.fromOffset(100, 16), Text = rarity.Name, TextSize = 13, TextColor3 = rarity.Color, TextXAlignment = Enum.TextXAlignment.Left }),
			text({ Position = UDim2.new(1, -90, 0, 6), Size = UDim2.fromOffset(80, 16), Text = if isNew then "NEW!" else "", TextSize = 13, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Right }),
			iconTile,
			text({ Position = UDim2.fromOffset(4, 102), Size = UDim2.new(1, -8, 0, 24), Text = def.Name, TextSize = 18, TextScaled = false }),
			text({ Position = UDim2.fromOffset(0, 128), Size = UDim2.new(1, 0, 0, 16), Text = levelText, TextSize = 13, TextColor3 = GOLD }),
			text({ Position = UDim2.fromOffset(12, 152), Size = UDim2.new(1, -24, 0, 64), Text = desc, TextSize = 14, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Color3.fromRGB(230, 224, 240) }),
		})
		local holder = new("Frame", { Size = UDim2.fromOffset(196, 234), BackgroundTransparency = 1 }, { b })
		holder.Parent = cardRow
		b.Activated:Connect(function()
			selectCard(k)
		end)
		cardButtons[k] = { holder = holder, button = b, stroke = s, rarityColor = rarity.Color }
	end
	levelSub.Text = string.format("LV %d  -  PICK ONE", level)
	rerollButton.Text = string.format("REROLL (%d)", rerolls)
	rerollButton.Visible = rerolls > 0
	selectCard(nil)
	levelUp.Visible = true
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

-- A stat: small label over a big number, no box.
local function stat(label: string, order: number)
	local value = text({ Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 32), Text = "", TextSize = 30 }, 3)
	return new("Frame", { Size = UDim2.fromOffset(170, 52), BackgroundTransparency = 1, LayoutOrder = order }, {
		text({ Size = UDim2.new(1, 0, 0, 16), Text = label, TextSize = 13, TextColor3 = Color3.fromRGB(217, 210, 230) }),
		value,
	}), value
end
local timeStat, timeValue = stat("SURVIVED", 1)
local killStat, killValue = stat("GOBLINS BONKED", 2)
local levelStat, levelValue = stat("LEVEL", 3)
local damageList = new("Frame", { Size = UDim2.fromOffset(540, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 3 }, {
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local lobbyButton = button("LOBBY", Color3.fromRGB(74, 63, 94), WHITE, 140)
local againButton = button("PLAY AGAIN", GOLD, INK, 180)
local results = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = SHADE, BackgroundTransparency = 0.35, Visible = false, ZIndex = 6 }, {
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(600, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = SHADE, BackgroundTransparency = 0.2 }, {
		corner(8),
		stroke(3),
		new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 16), PaddingLeft = UDim.new(0, 24), PaddingRight = UDim.new(0, 24) }),
		new("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		text({ Size = UDim2.new(1, 0, 0, 38), Text = "GREAT RUN!", TextSize = 34, TextColor3 = GOLD, LayoutOrder = 1 }, 3),
		new("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, LayoutOrder = 2 }, {
			list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center),
			timeStat,
			killStat,
			levelStat,
		}),
		damageList,
		new("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, LayoutOrder = 9 }, {
			list(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center),
			lobbyButton,
			againButton,
		}),
	}),
})
results.Parent = gui

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
		local track, fill = bar(UDim2.new(1, -240, 0, 10), def.Color)
		track.Position = UDim2.fromOffset(186, 4)
		fill.Size = UDim2.fromScale(pct / 100, 1)
		new("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = k, Parent = damageList }, {
			text({ Size = UDim2.fromOffset(180, 18), Text = if d.level==6 then string.upper(Config.Evolutions[d.id].Name).." EVO"else string.format("%s LV %d", string.upper(def.Name), d.level), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left }),
			track,
			text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(44, 18), Text = pct .. "%", TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right }),
		})
	end
	results.Visible = true
end)
againButton.Activated:Connect(function()
	results.Visible = false
	Shared.RunRestart:FireServer()
end)
lobbyButton.Activated:Connect(function()
	results.Visible = false
	Shared.RunLobby:FireServer()
end)

-- Fit the 640x340 overlays on small screens (and let them grow a little on big ones).
local function fit()
	local v = Workspace.CurrentCamera.ViewportSize
	scale.Scale = math.clamp(math.min(v.X / 680, (v.Y - 40) / 360), 0.6, 1.3)
end
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
fit()
gui.Parent = player:WaitForChild("PlayerGui")
feet.Parent = player.PlayerGui
refreshHUD()
