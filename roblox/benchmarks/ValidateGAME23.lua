-- Pass two decoded batch tables from GAME23Batch1/2.lua into the returned function.
-- This validates evidence completeness; it does not run or modify the game.
return function(batches)
	assert(#batches==2,"two independent batches required")
	local phases,primary,clients=0,0,0
	for _,batch in batches do
		for _,players in {1,2,4} do
			local session=assert(batch["Clients"..players],"missing client scenario")
			assert(session.callOK and session.result.ok,"session failed")
			local result=session.result
			assert(#result.errors==0 and #result.phases==6,"errors or incomplete session")
			local seen={}
			for _,p in result.phases do
				assert(p.population==100 or p.population==500 or p.population==1000,"invalid population")
				assert(p.repeatIndex==1 or p.repeatIndex==2,"invalid round")
				local key=p.repeatIndex..":"..p.population
				assert(not seen[key],"duplicate phase");seen[key]=true
				assert(p.seconds>=20 and p.stepMs.n>=550,"insufficient sample")
				assert(p.minAlive==p.population and p.maxAlive==p.population,"population mismatch")
				assert(#p.clientReports==players,"missing client")
				for _,q in {p.stepMs,p.sendMs,p.heartbeatMs} do
					assert(q.p50>=0 and q.p50<=q.p95 and q.p95<=q.max,"invalid quantiles")
				end
				for _,c in p.clientReports do
					assert(#c.errors==0 and c.visible==p.population,"client errors or missing visible models")
					assert(c.models==(if p.repeatIndex==1 then p.population else 1000),"unexpected pool state")
					assert(c.packets>=150 and c.frameMs.n>0,"missing samples")
					assert(math.abs(c.snapshotPayloadKiBps/p.snapshotPayloadKiBps-1)<0.1,"payload disagreement")
					clients+=1
				end
				phases+=1
				if p.repeatIndex==1 then primary+=1 end
			end
		end
	end
	return {valid=true,batches=#batches,phases=phases,primaryPhases=primary,clientReports=clients}
end
