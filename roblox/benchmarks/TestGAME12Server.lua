-- Exact server functions with controlled owners, real Humanoid/Parts and captured remotes.
-- No Script.Source writes; complements actual network acceptance.
return function(configSource,serverSource)
	local function span(a,b)local first=assert(serverSource:find(a,1,true));return serverSource:sub(first,assert(serverSource:find(b,first+#a,true))-1)end
	local code="local Config=(function()\n"..configSource.."\nend)()\n"..[=[
local H,R,W,P=Config.Horde,Config.Run,Config.Weapons,Config.Passives
local Workspace,Players=workspace,{}
local alive,px,pz,hp,generation={},{},{},{},{}
local swingAt,nextSwing,kvx,kvz,stunUntil,slowUntil={},{},{},{},{},{}
local free,top,count,dead,deadFirstGem,gems,nextGem={},0,0,{},0,{},0
local deathEvents={};local runs={};local rng=Random.new(120)
local function arena()return Vector3.zero,200 end
local packets={};local fx={FireAllClients=function(_,kind,data)table.insert(packets,{kind=kind,data=data})end}
local runOver={FireClient=function()end};local levelUp={FireClient=function()end}
local function remote()local r={};r.OnServerEvent={Connect=function(_,f)r.callback=f end};return r end
local pickCard,rerollCards=remote(),remote()
]=]..span("local axes, axeSerial","-- `run` =")..span("local function kill(","-- The run arena:")
		..span("local grid = {}","---------------------------------------------------------------- runs, XP, cards")
		..span("local function publish(","restart.OnServerEvent")
		..span("local hitLog = {}","---------------------------------------------------------------- simulation")..[=[
local checks={};local function check(v,label)assert(v,label);table.insert(checks,label)end
local function near(a,b)return math.abs(a-b)<.0001 end
local folder=Instance.new("Folder");folder.Name="GAME12ServerExact";folder.Parent=workspace
local function owner(x)
 local ch=Instance.new("Model");ch.Parent=folder;local root=Instance.new("Part");root.Name="HumanoidRootPart";root.Anchored=true;root.CFrame=CFrame.new(x,4,0);root.Parent=ch
 local hum=Instance.new("Humanoid");hum.Parent=ch
 local p={Parent=Players,Character=ch,attributes={},SetAttribute=function(self,k,v)self.attributes[k]=v end}
 startRun(p,hum);return runs[p],root
end
local function target(entries)
 table.clear(alive);table.clear(grid);table.clear(free);top=#entries;count=top
 for i,e in entries do alive[i],px[i],pz[i],hp[i]=true,e[1],e[2],1000;generation[i]=(generation[i]or 0)+1;kvx[i],kvz[i],stunUntil[i],slowUntil[i]=0,0,0,0;local k=key(px[i]//CELL,pz[i]//CELL);grid[k]=grid[k]or {};table.insert(grid[k],i)end
end
local ok,err=xpcall(function()
 local r,root=owner(0)
 for _,id in W.Order do
  r.weapons={[id]=5};r.wOrder={id};local pair=Config.Evolutions[id].Passive;r.passives={[pair]=1};r.pOrder={pair};r.evolved={};r.pending=2;r.rerolls=2;offer(r)
  local first=r.offerId;pickCard.callback(r.player,1.5,first);check(r.offerId==first,"fractional card index rejected for "..id)
  pickCard.callback(r.player,1,first);check(r.evolved[id]and r.weapons[id]==5 and #r.wOrder==1,"real pick handler evolves "..id.." in place")
  local second=r.offerId;pickCard.callback(r.player,1,first);check(r.offerId==second and r.pending==1,"queued offer resists stale "..id.." pick")
  rerollCards.callback(r.player,first);check(r.rerolls==2,"stale "..id.." reroll rejected")
  rerollCards.callback(r.player,second);check(r.rerolls==1 and r.offerId~=second,"current "..id.." reroll creates new identity")
  r.cards=nil;r.pending=0;r.offerId=nil;r.pausedAt=nil
 end
 r.weapons={totem=5};r.wOrder={"totem"};r.evolved={};r.bonus={might=.3,area=.5,haste=.25,force=1,duration=.75,projectile=0,speed=0,luck=0}
 target({{5,0},{10,0},{15,0},{40,0}});fireWeapons(r,root,0);moveTotems(.01)
 check(#totems==1 and near(totems[1].duration,10.5)and totems[1].range==33,"Duration and Area affect deployed totem")
 check(near(hp[1],967.5)and near(hp[3],967.5)and hp[4]==1000,"Might damage and nearest three respect range")
 check(stunUntil[1]==0 and kvx[1]>0,"totem Force knockback without stun")
 local old=hp[1];moveTotems(.1);check(hp[1]==old,"pulse interval prevents same-tick repeat")
 moveTotems(.51);check(hp[1]<old,"Haste shortens actual pulse interval")
 r.cd.totem=0;fireWeapons(r,root,0);r.cd.totem=0;fireWeapons(r,root,0);check(#totems==2,"deployed totem cap two")
 local peer,root2=owner(60);peer.weapons={totem=1};peer.wOrder={"totem"};fireWeapons(peer,root2,0)
 check(#totems==3,"two owners retain independent cap")
 endRun(r.player);check(#totems==1 and totems[1].run==peer,"endRun removes exactly owner totems")
 root2.Position+=Vector3.new(60,0,0);pruneTotems();check(#totems==0,"teleport prunes stationary weapon")
 peer.cd.totem=0;fireWeapons(peer,root2,0);peer.player.Parent=nil;pruneTotems();check(#totems==0,"disconnected owner pruned")
 peer.player.Parent=Players;peer.cd.totem=0;fireWeapons(peer,root2,0);peer.player.Character=Instance.new("Model");pruneTotems();check(#totems==0,"replaced character pruned");peer.player.Character:Destroy();peer.player.Character=root2.Parent
 peer.cd.totem=0;fireWeapons(peer,root2,0);root2.Position=Vector3.new(210,4,0);pruneTotems();check(#totems==0,"arena exit pruned")
 root2.Position=Vector3.new(60,4,0);peer.cd.totem=0;fireWeapons(peer,root2,0);moveTotems(5);check(#totems==0,"lifetime ends at active deadline")
 r,root=owner(0);r.weapons={fire=5,axe=5};r.wOrder={"fire","axe"};r.evolved={fire=true,axe=true};r.bonus.duration=.75;r.bonus.projectile=5;target({{5,0}});fireWeapons(r,root,0)
 check(#shots==10 and #axes==7,"evolved volley uses projectile bonus")
 check(near(shots[1].t,Config.weaponStats("fire",6).Range*1.75/Config.weaponStats("fire",6).Speed),"fireball lifetime uses Duration")
 for _=1,5 do r.cd.axe=0;fireWeapons(r,root,0)end;check(#axes==16,"active axe cap across repeated volleys")
 for level=1,5 do r.cards={{kind="passive",id="speed",level=level,rarity=3}};r.pending=1;r.pausedAt=Workspace:GetServerTimeNow();r.offerId=nil;pickCard.callback(r.player,1)end
 check(r.hum.WalkSpeed>r.baseWalkSpeed,"real passive handler applies Speed")
 endRun(r.player);check(r.hum.WalkSpeed==r.baseWalkSpeed,"real endRun restores engine speed value")
end,debug.traceback)
folder:Destroy();assert(ok,err);return {ok=true,checks=checks,count=#checks,mode="exact production handlers/combat; network separately verified"}
]=]
	return assert(loadstring(code,"GAME12ServerExact"))()
end
