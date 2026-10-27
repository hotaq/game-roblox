-- GAME-23 runner. Read and execute in Studio Edit through the existing MCP/plugin context.
-- Requires the matching GoblinHorde/GoblinStressHUD files to have arrived via Rojo.
-- No Script.Source writes. Results are retained in ServerStorage.GAME23Results as JSON StringValues.
-- Each session: 100/500/1000 enemies, repeated twice; 10s warm-up + 20s sample per phase.
-- Do not use background client frame times as device FPS.
local STS=game:GetService("StudioTestService")
assert(STS.EditModeActive,"Finish the current playtest first")
assert(not game.ServerStorage:FindFirstChild("GAME23Results"),"Archive existing GAME23Results first")
local results=Instance.new("Folder")
results.Name="GAME23Results"; results.Parent=game.ServerStorage
results:SetAttribute("Status","Running")
task.spawn(function()
	for _,clients in {1,2,4} do
		results:SetAttribute("Clients",clients)
		local ok,value=pcall(function()
			return STS:ExecuteMultiplayerTestAsync(clients,{name="GAME23Baseline",clients=clients,baseCommit="c8712eaf3fd3c051fa627272f3756fab094a16a2"})
		end)
		local entry=Instance.new("StringValue")
		entry.Name="Clients"..clients
		entry.Value=game:GetService("HttpService"):JSONEncode({callOK=ok,result=if ok then value else tostring(value)})
		entry.Parent=results
		if not ok or typeof(value)~="table" or not value.ok then
			results:SetAttribute("Status","Failed")
			return
		end
		task.wait(3)
	end
	results:SetAttribute("Status","Complete")
end)
return "GAME23 baseline started"
