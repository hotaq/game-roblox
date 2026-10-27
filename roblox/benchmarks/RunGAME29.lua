-- Run in Edit/MCP. All runtime code arrives through Rojo; disposable background helpers.
return function(clients)
	assert(clients==1 or clients==2)
	local sts=game:GetService("StudioTestService");assert(sts.EditModeActive)
	assert(game.ServerScriptService.GoblinHorde.Source:find("GAME29Test",1,true),"sync GAME29 first")
	local f=Instance.new("Folder");f.Name="GAME29_"..game:GetService("HttpService"):GenerateGUID(false)
	f:SetAttribute("Status","Running");f.Parent=game.ServerStorage
	task.spawn(function()
		local ok,result=pcall(function()return sts:ExecuteMultiplayerTestAsync(clients,{name="GAME29Objective",clients=clients})end)
		local value=Instance.new("StringValue");value.Name="Report";value.Value=game:GetService("HttpService"):JSONEncode({callOK=ok,result=result});value.Parent=f
		f:SetAttribute("Status",if ok and typeof(result)=="table"and result.ok then "Complete"else "Failed")
	end)
	return f.Name
end
