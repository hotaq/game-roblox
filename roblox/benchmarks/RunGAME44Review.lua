-- Hidden disposable candidate review; never starts Play in the owner's main window.
return function(clients)
	local sts=game:GetService("StudioTestService");assert(sts.EditModeActive)
	local f=Instance.new("Folder");f.Name="GAME44_"..game:GetService("HttpService"):GenerateGUID(false);f.Parent=game.ServerStorage
	f:SetAttribute("Status","Running")
	task.spawn(function()
		local ok,r=pcall(function()return sts:ExecuteMultiplayerTestAsync(clients or 2,{name="GAME44Review"})end)
		local v=Instance.new("StringValue");v.Name="Report";v.Value=game:GetService("HttpService"):JSONEncode({callOK=ok,result=r});v.Parent=f
		f:SetAttribute("Status",if ok and type(r)=="table" and r.ok then "Complete" else "Failed")
	end)
	return f.Name
end
