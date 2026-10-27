-- Summarize a raw RunGAME25 report without assuming that process memory is all game-script memory.
return function(raw)
	local report = raw.result or raw
	assert(report.ok and not report.pilot, "requires successful full acceptance")
	assert(report.soakSeconds >= 900 and #report.soak >= 15, "incomplete wall-clock soak")
	local cycles = {}
	for _, sample in report.cycles do if sample.measured then table.insert(cycles,sample) end end
	assert(#cycles == 20, "requires twenty post-warmup restart cycles")
	local function range(rows,key,client)
		local lo,hi = math.huge,-math.huge
		for _, row in rows do
			local n = (if client then row.client else row)[key]
			lo,hi = math.min(lo,n),math.max(hi,n)
		end
		return {min=lo,max=hi}
	end
	for _, row in cycles do
		for _, key in {"runs","gems","shots","axes","orphanHits","invalidShots","alive"} do
			assert(row[key] == 0, row.label.." retained server "..key)
		end
		for _, key in {"live","gems","balls","axes","rings","orphanRings","orphanSides","visibleNumbers"} do
			assert(row.client[key] == 0, row.label.." retained client "..key)
		end
		assert(row.client.soundTemplates == 10 and #row.client.errors == 0, "client templates/errors")
	end
	assert(report.afterDisconnect.invalidShots == 0, "disconnected projectile owner")
	assert(report.afterDisconnect.client.orphanRings == 0 and report.afterDisconnect.client.orphanSides == 0, "departed visual owner")
	assert(#report.errors == 0 and #report.final.client.errors == 0, "script errors")
	local tail = {}
	for i=math.max(1,#cycles-4),#cycles do table.insert(tail,cycles[i]) end
	local result = {ok=true,measuredCycles=#cycles,soakSeconds=report.soakSeconds,checks=#report.checks,
		map1Instances=report.map1Instances,cycleServer={},cycleClient={},lastFiveClient={},soakServer={},soakClient={}}
	for _,key in {"memoryMb","luaKb","instances","lastHit"} do
		result.cycleServer[key]=range(cycles,key,false)
		result.soakServer[key]=range(report.soak,key,false)
	end
	for _,key in {"memoryMb","luaKb","instances","hordeInstances","modelPool","gemPool","numberPool","ballPool","uiInstances","soundTemplates"} do
		result.cycleClient[key]=range(cycles,key,true)
		result.lastFiveClient[key]=range(tail,key,true)
		result.soakClient[key]=range(report.soak,key,true)
	end
	result.final=report.final
	return result
end
