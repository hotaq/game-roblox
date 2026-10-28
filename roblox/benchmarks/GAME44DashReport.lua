-- GAME-44 evidence, 2026-10-28. NOT a completion certificate; integrated Rojo acceptance pending.
return {
 status="implemented; awaiting normal Rojo sync for integrated acceptance",
 implementation="da98e1a plus subsequent collision/cleanup refinement in this report's commit",
 exact={count=37,ok=true,rawJSON=[====[{"ok":true,"count":37,"checks":{"37":"bounded start/stop effect protocol","35":"cleanup preserves velocity after another mover releases root","29":"resume restores unanchored root, no shield leak","1":"invalid payload rejected","3":"infinite direction rejected","2":"NaN rejected","5":"grounded active run starts","4":"zero direction rejected","7":"engine shield prevents damage","6":"movement lease and replicated state acquired","9":"shield expires before dash finishes","8":"repeat request throttled","27":"pause transition starts","17":"real Map1 mesh gate hole permits dash despite bounding overlap","13":"server cooldown prevents early repeat","21":"boundary approach starts inside arena","11":"normal finish releases root and state","23":"air dash rejected","36":"50 repeated dashes leave zero shields/state","34":"idempotent cleanup preserves unrelated shield","28":"card pause cancels dash before acquiring root","33":"death cancels and removes shield","32":"disconnect invalidates active dash","31":"character replacement cancels old lease","30":"arena change cancels immediately","15":"body sweep stops before thin wall","18":"dash crosses actual temple gate collision opening","19":"near ledge starts","25":"seated dash rejected","14":"dash toward distant thin wall starts","24":"foreign anchored root rejected","16":"initial wall overlap rejected","26":"card chooser cannot dash","20":"ledge guard stops before unsupported centre","12":"distance exactly16stud on clear level ground","22":"arena boundary stops body before leaving","10":"damage resumes after shield window"}}]====]},
 regressions={weaponHandlers=48,compiledLuaSources=9,generatedReviewSourcesCompile=true},
 candidateMultiplayer={
  mode="Exact candidate blocks executed through MCP in a hidden disposable two-client helper, isolated run table; no Script.Source writes.",
  player1Distance=16.00006103515625,player2Distance=15.9998779296875,
  after450ms={anchored=false,cooldownText="3.6s"},
  peerVisual={acceptedRepeats=24,startEvents=24,stopEvents=24,peakConcurrent=1,errors=0},
  cleanup={activeEffects=0,effectFolders=0,activeServerDashes=0,shields=0,anchoredRoots=0,autoRotateRestored=true},
  ui={hiddenDuringCardPause=true,menuActionPasses=true,hiddenAfterRunEnd=true,size={96,72}},
  pilot="First UI review rendered correctly; fixture export failed because CRLF prevented string replacement. Fixed LF normalization before second helper. Not a gameplay failure.",
 },
 visual={
  inspected="Jade ribbons, warm gold centre/speed lines, three block afterimages, pixel burst; cyan outlined Fredoka button.",
  still="GAME44DashFullStyle; held130ms pose, Trail lifetime20s solely for capture. Not a real-time duration claim.",
  bounds={maxEffects=8,maxPartsPerEffect=46,maxLifetime=.62,cullDistance=150},
  helpersEnded=true,mainCameraUntouched=true,checkedWindowHandles=0,
 },
 pending={
  "Main Edit still has no GAME44 markers in Config/Horde/HordeClient/RunUI. Need normal owner-host pull/Rojo; request posted, no repeated user prompt.",
  "Verify exact four mapped files, then exercise actual integrated run + card pause/end/death and two-client gameplay.",
  "Check Q / real gamepad B / touch button on phone landscape; candidate handler and UI state tested, physical device input not claimed.",
  "Check dash feel under realistic network latency and on Map1 stairs/slopes; large height transitions intentionally stop.",
 },
 reproduction={
  "TestGAME44Dash(configSource,serverSource):37 checks with current Map1 temple gate present (35 if asset absent).",
  "RunGAME44Review(2) from Edit; BuildGAME44Review sources in helper Server/Clients; never assign Source.",
  "Client _G.GAME44UI.action('GoblinDash',Enum.UserInputState.Begin) exercises real request RemoteEvent.",
  "BuildGAME44Pose returns a held art review. EndTest from own helper server afterwards.",
 },
}

