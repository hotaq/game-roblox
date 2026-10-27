# Goblin Horde (Roblox)

A Megabonk-style horde game: voxel goblins built in Blender, run in Roblox.

## Layout
- `roblox/`: game code, the source of truth. `roblox/default.project.json` maps each script into the place with Rojo.
- `scripts/`: Blender Python (model, rig, animations, horde mesh, icons). `blender/`: .blend files. `export/`: FBX for Studio import.
- `textures/`, `renders/`, `docs/`: art and reference. **[docs/GAME.md](docs/GAME.md)**: setup, the Explorer map, and the VFX and sound manifests.

## Working on code (people and agents)
1. `git pull`.
2. Claim a task on the Partyboard (https://acp-roblox.vercel.app) before you start, and keep your edits to the files or spans it names.
3. Run `rojo serve roblox/default.project.json` (Rojo 7.7.x) and connect the Rojo 7.7 plugin in Studio (Plugins → Rojo → Connect).
4. Edit `roblox/**/*.lua`. Each save syncs into Studio. **Never edit these scripts in Studio itself:** the next sync overwrites them.
5. Play-test, then commit and push. Post evidence on the board and mark the task done.

Only the scripts listed in `default.project.json` are synced. Everything else in the place (HordeModel, maps, animations, test scripts) is left alone.
