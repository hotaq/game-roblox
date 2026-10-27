-- Execute in the Edit plugin/MCP context after Rojo sync. Does not write Script.Source.
-- Pilot: {pilot=true}; full acceptance: default (20 restarts, real 900-second soak).
return function(options)
	options = options or {}
	local sts = game:GetService("StudioTestService")
	assert(sts.EditModeActive,"another test is active")
	assert(game.ServerScriptService.GoblinHorde.Source:find("GAME25Cleanup",1,true),"sync GAME-25 through Rojo")
	local results = Instance.new("Folder")
	results.Name = "GAME25_" .. game:GetService("HttpService"):GenerateGUID(false)
	results:SetAttribute("Status","Running")
	results.Parent = game.ServerStorage
	task.spawn(function()
		local ok, result = pcall(function()
			return sts:ExecuteMultiplayerTestAsync(2,{name="GAME25Cleanup",pilot=options.pilot==true})
		end)
		local report = Instance.new("StringValue")
		report.Name, report.Value = "Report", game:GetService("HttpService"):JSONEncode({callOK=ok,result=result})
		report.Parent = results
		results:SetAttribute("Status",if ok and typeof(result)=="table" and result.ok then "Complete" else "Failed")
	end)
	return results.Name
end
