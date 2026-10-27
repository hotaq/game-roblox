-- Execute in Edit/MCP after Rojo sync; creates background disposable test contexts.
return function(options)
	options=options or {}
	local sts=game:GetService("StudioTestService")
	assert(sts.EditModeActive,"another test is active")
	assert(game.ServerScriptService.GoblinHorde.Source:find("GAME24Network",1,true),"sync GAME-24 via Rojo first")
	local folder=Instance.new("Folder")
	folder.Name="GAME24_"..game:GetService("HttpService"):GenerateGUID(false)
	folder:SetAttribute("Status","Running");folder.Parent=game.ServerStorage
	task.spawn(function()
		local ok,result=pcall(function()
			return sts:ExecuteMultiplayerTestAsync(2,{name="GAME24Network",quick=options.quick==true})
		end)
		local value=Instance.new("StringValue")
		value.Name,value.Value="Report",game:GetService("HttpService"):JSONEncode({callOK=ok,result=result})
		value.Parent=folder
		folder:SetAttribute("Status",if ok and typeof(result)=="table" and result.ok then "Complete" else "Failed")
	end)
	return folder.Name
end
