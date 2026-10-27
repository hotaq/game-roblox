-- Pure analysis of RunGAME24's result table; does not alter the game.
return function(report)
	local groups={}
	for _,phase in report.phases do
		local key=phase.population.."/"..phase.layout.."/"..phase.repeatIndex
		local group=groups[key] or {population=phase.population,layout=phase.layout,repeatIndex=phase.repeatIndex}
		groups[key]=group
		local clients,total={},0
		for _,client in phase.clients do
			local rate=client.bytes/client.seconds/1024
			table.insert(clients,{KiBps=rate,bytes=client.bytes,seconds=client.seconds,packets=client.packets,visible=client.visual.count})
			total+=rate
		end
		group[phase.mode]={clients=clients,meanKiBps=total/#clients,stepMs=phase.stepMs,sendMs=phase.sendMs}
	end
	local rows={}
	for _,group in groups do
		if group.broadcast and group.nearby then
			group.savedPercent=100*(1-group.nearby.meanKiBps/group.broadcast.meanKiBps)
			group.sendP95DeltaMs=group.nearby.sendMs.p95-group.broadcast.sendMs.p95
		end
		table.insert(rows,group)
	end
	table.sort(rows,function(a,b)
		if a.population~=b.population then return a.population<b.population end
		if a.layout~=b.layout then return a.layout<b.layout end
		return a.repeatIndex<b.repeatIndex
	end)
	return {ok=report.ok,checks=#report.checks,phaseCount=#report.phases,map1Instances=report.map1Instances,
		rows=rows,limits="Serialized buffers only; includes swings, excludes framing/scalars/weapon FX tables. Background test: no FPS claim."}
end
