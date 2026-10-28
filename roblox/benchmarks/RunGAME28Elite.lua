-- Run only in Edit, after normal Rojo sync; hidden disposable helper windows.
return function(clients, review)
	local sts=game:GetService("StudioTestService");assert(sts.EditModeActive)
	local f=Instance.new("Folder");f.Name="GAME28_"..game:GetService("HttpService"):GenerateGUID(false);f.Parent=game.ServerStorage
	f:SetAttribute("Status","Running")
	task.spawn(function()
		local ok,result=pcall(function()return sts:ExecuteMultiplayerTestAsync(clients or 1,{name="GAME28Elite",clients=clients or 1,review=review==true})end)
		local v=Instance.new("StringValue");v.Name="Report";v.Value=game:GetService("HttpService"):JSONEncode({callOK=ok,result=result});v.Parent=f
		f:SetAttribute("Status",if ok and typeof(result)=="table" and result.ok then "Complete"else "Failed")
	end)
	return f.Name
end
