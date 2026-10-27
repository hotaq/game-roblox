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
		-- A full matrix exceeds StringValue's 200k character limit. Preserve full evidence in chunks,
		-- with the useful comparison fields in the compact Report read by analysis tools.
		local encoded=game:GetService("HttpService"):JSONEncode({callOK=ok,result=result})
		local raw=Instance.new("Folder");raw.Name="RawReport";raw.Parent=folder
		for offset=1,#encoded,180000 do
			local chunk=Instance.new("StringValue");chunk.Name=string.format("%04d",(offset-1)//180000+1)
			chunk.Value=encoded:sub(offset,offset+179999);chunk.Parent=raw
		end
		if ok and typeof(result)=="table" then
			for _,phase in result.phases or {} do
				for _,client in phase.clients do
					client.visual.slots=nil;client.visual.gems=nil
				end
			end
		end
		local value=Instance.new("StringValue")
		value.Name,value.Value="Report",game:GetService("HttpService"):JSONEncode({callOK=ok,result=result})
		value.Parent=folder
		folder:SetAttribute("Status",if ok and typeof(result)=="table" and result.ok then "Complete" else "Failed")
	end)
	return folder.Name
end
