-- User-authorized gameplay feature, not tied to the paused Elite prototype.
return {
	name="Jade Dash", controls={keyboard="Q",gamepad="B",touch="DASH button above Jump"},
	intent="An intentional short escape through a crowd, with a clear travel direction and readable cooldown.",
	tuning={distance=16,duration=.22,cooldown=4,shield=.18},
	rules={
		"Active living run, grounded, not seated/anchored/choosing a card; move direction, otherwise facing.",
		"Server validates finite vectors and cooldown, anchors only for its short movement lease, sweeps a body box each substep.",
		"Stop on walls, large rises, unsupported ledges or arena boundary; no air dash, wall teleport, extra damage or charges.",
		"Invisible ForceField protects TakeDamage during first180ms (including hazards). No protection for remaining40ms.",
		"Real-time4s cooldown continues while choosing; pause/end/death/leave cancels dash and removes only owned shield.",
		"Distance doesn't scale with Speed passive or mud. Terrain traversal remains walking/jumping; large steps stop dash.",
		"Server-authoritative movement, no client prediction in v1; evaluate input feel under realistic latency before closure.",
	},
	art={
		"Bright jade wind ribbons with thin warm gold centre, three translucent block silhouettes, ten pixel flecks and six speed lines.",
		"All effects local, collision-free, texture-independent; no fullscreen flash, camera shake, FOV change or lights.",
		"150stud distance cull, eight concurrent effects, max46 transient parts per dash; everything removed within620ms.",
		"Cyan glossy button, ink outline, gold recharge strip, FredokaOne to match approved GAME40; hidden during menus.",
	},
	verification="Exact real-collision/lifecycle fixture plus source compile; live synced solo/team controls and rendered VFX/UI review required before done.",
	api="https://create.roblox.com/docs/reference/engine/classes/WorldRoot#Blockcast",
}
