-- Execute this repository file in Studio's Edit plugin/MCP context; never paste it into a production Script.
-- Returns a launcher accepting {clients=1|2, reviewSeconds=0..60}. Only run where tests remain in background.
-- Results remain in ServerStorage; production code must have arrived through Rojo first.
return function(options)
	options = options or {}
	local clients = options.clients or 1
	assert(clients == 1 or clients == 2, "Axe acceptance supports one or two clients")
	local STS = game:GetService("StudioTestService")
	assert(STS.EditModeActive, "A test is already running")
	local server = game.ServerScriptService.GoblinHorde.Source
	local participant = game.StarterPlayer.StarterPlayerScripts.GoblinStressHUD.Source
	assert(server:find("both real clients render", 1, true), "Sync the latest axe fixture through Rojo first")
	assert(participant:find("CanLeaveTest", 1, true), "Sync the latest axe client participant through Rojo first")
	local results = Instance.new("Folder")
	results.Name = "GAME12AxeAcceptance_" .. game:GetService("HttpService"):GenerateGUID(false)
	results:SetAttribute("Status", "Running")
	results:SetAttribute("Clients", clients)
	results.Parent = game.ServerStorage
	task.spawn(function()
		local args = {name="GAME12Axe",clients=clients,reviewSeconds=math.clamp(options.reviewSeconds or 0,0,60)}
		local ok, value = pcall(function()
			if clients == 2 then return STS:ExecuteMultiplayerTestAsync(2,args) end
			return STS:ExecutePlayModeAsync(args)
		end)
		local entry = Instance.new("StringValue")
		entry.Name = "Report"
		entry.Value = game:GetService("HttpService"):JSONEncode({callOK=ok,result=value})
		entry.Parent = results
		results:SetAttribute("Status", if ok and typeof(value)=="table" and value.ok then "Complete" else "Failed")
	end)
	return results.Name
end
