-- Normal Rojo source sync first. Hidden StudioTestService helpers, no Source writes.
return function(options)
 options=options or {};options.name="GAME11Complete";options.clients=options.clients or 2
 local sts=game:GetService("StudioTestService");assert(sts.EditModeActive)
 assert(game.ServerScriptService.GoblinHorde.Source:find("GAME11Test",1,true),"sync fixture first")
 local folder=Instance.new("Folder");folder.Name="GAME11_"..game:GetService("HttpService"):GenerateGUID(false);folder.Parent=game.ServerStorage
 folder:SetAttribute("Status","Running")
 task.spawn(function()
  local ok,result=pcall(function()return sts:ExecuteMultiplayerTestAsync(options.clients,options)end)
  local v=Instance.new("StringValue");v.Name="Report";v.Value=game:GetService("HttpService"):JSONEncode({callOK=ok,result=result});v.Parent=folder
  folder:SetAttribute("Status",if ok and typeof(result)=="table"and result.ok then "Complete"else "Failed")
 end)
 return folder.Name
end
