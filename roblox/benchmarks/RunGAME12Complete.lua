-- Background Edit launcher. All runtime sources arrive via Rojo; no Source assignment.
return function(options)
	options=options or {};local sts=game:GetService("StudioTestService");assert(sts.EditModeActive,"test already active")
	assert(game.ServerScriptService.GoblinHorde.Source:find("GAME12CompleteTest",1,true),"sync complete fixture first")
	local f=Instance.new("Folder");f.Name="GAME12Complete_"..game:GetService("HttpService"):GenerateGUID(false)
	f:SetAttribute("Status","Running");f.Parent=game.ServerStorage
	task.spawn(function()
		local ok,result=pcall(function()return sts:ExecuteMultiplayerTestAsync(options.clients or 2,{name="GAME12Complete",clients=options.clients or 2,reviewSeconds=options.reviewSeconds or 0})end)
		local v=Instance.new("StringValue");v.Name="Report";v.Value=game:GetService("HttpService"):JSONEncode({callOK=ok,result=result});v.Parent=f
		f:SetAttribute("Status",if ok and typeof(result)=="table"and result.ok then "Complete"else "Failed")
	end)
	return f.Name
end
