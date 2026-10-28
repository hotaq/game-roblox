-- Regression: shared Config.Animations contains non-goblin clips such as Skeleton BoneThrow.
-- Execute the exact production loading loop on a disposable real Animator; never edit Source.
return function(configSource,animDataSource,aiSource)
	local first=assert(aiSource:find("\tlocal tracks: {",1,true))
	local last=assert(aiSource:find("\n\tlocal state =",first,true))
	local code="local Config=(function()\n"..configSource.."\nend)()\nlocal AnimData=(function()\n"..animDataSource.."\nend)()\n"..[=[
local model=workspace.Goblin:Clone();model.Name="GAME28AnimationCheck"
model:PivotTo(CFrame.new(10000,10000,10000));model.Parent=workspace
local ok,result=xpcall(function()
local animator=model:FindFirstChildWhichIsA("Animator",true) or Instance.new("Animator",model:FindFirstChildOfClass("Humanoid"))
]=]..aiSource:sub(first,last-1)..[=[
local count,expected=0,0
for name in AnimData do if Config.Animations[name]then expected+=1;assert(tracks[name],name.." missing")end end
for name,track in tracks do
 assert(AnimData[name],"foreign clip loaded")
 assert(track.Priority==Enum.AnimationPriority[AnimData[name].priority] and track.Looped==AnimData[name].looped)
 count+=1;track:Destroy()
end
assert(count==expected and tracks.BoneThrow==nil and Config.Animations.BoneThrow~=nil)
return {tracks=count,skeletonExcluded=true,metadataPreserved=true}
end,debug.traceback)
model:Destroy();return {ok=ok,result=result}
]=]
	return assert(loadstring(code,"GAME28AnimationLoader"))()
end
