-- TestGAME43Solid.lua: Command Bar (Edit, Map1 built). Checks GoblinHorde's Solid block (GAME-43): goblins chasing a
-- target behind a tree trunk slide round it, never stand inside it, and still arrive (head-on even/odd slots and angled).
local src = game.ServerScriptService.GoblinHorde.Source
assert(loadstring(src), "GoblinHorde does not compile")
local block = assert(src:match("(local Solid = {}\ndo.-\nend)\n\nlocal function step"), "Solid block not found")
local Solid = loadstring("local Workspace = workspace\nlocal function key(cx, cz) return cx * 100003 + cz end\n" .. block .. "\nreturn Solid")()
local cells = Solid.map()
local tree
for _, m in workspace.Map1.Forest:GetChildren() do
	if m.Name ~= "Tree_Bush" then
		tree = m
		break
	end
end
local p = tree:GetPivot().Position
local _, size = tree:GetBoundingBox()
local r = math.min(size.X, size.Z) * 0.12
for _, case in { { 0, 2 }, { 0, 3 }, { 2.5, 4 } } do
	local x, z = p.X - r - 8, p.Z + case[1]
	local tx, tz = p.X + r + 12, p.Z
	local arrived = false
	for _ = 1, 200 do
		local dx, dz = tx - x, tz - z
		local d = math.sqrt(dx * dx + dz * dz)
		if d < 1 then
			arrived = true
			break
		end
		local x0, z0 = x, z
		x, z = Solid.push(cells, x + dx / d * 0.5, z + dz / d * 0.5, x0, z0, case[2])
		assert((x - p.X) ^ 2 + (z - p.Z) ^ 2 >= r * r - 1e-3, "goblin inside the trunk")
	end
	assert(arrived, ("slot %d from z%+.1f never got round the trunk"):format(case[2], case[1]))
end
return "TestGAME43Solid: PASS"
