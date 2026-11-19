# Monster Squad+

An offline, single-player remake of Nexon's **Monster Squad** (2014, shut down 9 Dec 2016), built in Godot 4.7.

The original servers and patch CDN are gone. The original game data and monster art went with them. This project rebuilds the game from three sources:

| Source | What it gave us |
|---|---|
| Original APK (`monster-squad-2-00-17317.apk`) | UI sprites (2,962), skill effects, music & SFX, fonts, the original screen layouts (`research/apk_assets/*.xml`), the game-data schema (`research/protos/`) and the server API list |
| [Monster Squad Wiki](https://monster-squad.fandom.com) (Fandom) | 817 monsters: stats, skills, support skills, passives, evolution trees, plus 8 story islands with stage-by-stage enemies, and 795 portraits |
| r/monstersquad | Archived for reference (`research/reddit/`) |
| YouTube (130 videos + the 26-part TapGameplay walkthrough) | Real reward numbers, quest structure, UI layout, and the training, Sky Tower, Arena and raid rules: see `research/videos/findings.md` |

## Running

Open the folder in Godot 4.7 and press **F5**. The main scene is `scenes/main.tscn`.

Debug flags (pass after `--`):
- `--screen=<title|starter|hub|islands|squad|cubes|book|battle>` opens a screen directly.
- `--test-save` uses a throwaway save (`user://test_save.json`) with a starter squad.
- `--test-auto` turns on auto battle at x4. `--test-repeat` turns on Auto Repeat.
- `--test-team=id,id,...` and `--test-level=N` set the test squad.
- `--test-special=<island_id>:<quest>` plays a special-island quest directly.
- `--test-tower=<floor>` plays a Sky Tower floor directly. `--test-raid=<raid_id>:<room>` fills the box and fights a raid room. `--test-arena=<rival index>` fights an arena rival. `--test-stones` adds sample stones, and `--test-log` prints each battle's result.
- `--test-args=<json>` passes arguments to the start screen.
- `--shot=<file.png>@<seconds>` saves a screenshot and quits.

## Layout

```
scripts/autoload/   DB (game data), Save (profile/progress), Sfx (audio)
scripts/battle/     BattleEngine + BattleUnit (pure logic), StageBuilder (waves & rewards)
scripts/ui/         UI kit, screens, battle visuals
data/               monsters.json, islands.json (generated)
assets/apk/         assets from the APK      assets/monsters*/  wiki portraits + cutouts
tools/              data pipeline (not shipped)  tests/  balance simulation
research/           raw dumps: wiki, APK, protos, reddit, videos (not shipped; a junction to F:\monster-squad+\research)
```

## Video research tools

`research/bin` holds yt-dlp and ffmpeg. `tools/vtt_to_text.ps1` turns captions into transcripts, `tools/scan_videos.ps1` extracts frames and OCRs them, `tools/ocr_results.ps1` reads the result screens, and `tools/contact_sheet.ps1` builds frame grids for review. Downloaded videos are for local reference only; don't redistribute them.

`research/videos/wanted.tsv` lists further videos to mine and what each one shows (Sky Tower floors 24–50, raids, PvP League, duels, menus, 1080p footage for assets). `tools/fetch_videos.ps1` downloads them at up to 1080p into `research/videos/video_hd` and extracts a frame every 2 s into `research/videos/frames_hd/<id>`.

## Rebuilding data

```
godot --headless --path . --script res://tools/build_db.gd          # wiki -> data/*.json
godot --headless --path . --script res://tools/slice_atlases.gd     # APK atlases -> sprites
godot --headless --path . --script res://tools/cutout_portraits.gd  # card screenshots -> battle sprites
godot --headless --path . res://tests/sim_battle.tscn               # balance report
```

`research/build_report.txt` lists skill descriptions the parser couldn't read. Those skills fall back to an effect guessed from the skill's icon.

