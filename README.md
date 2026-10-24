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
- `--test-auto` turns on auto battle at x4.
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
research/           raw dumps: wiki, APK, protos, reddit (not shipped)
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

## Systems

- **Story islands:** 8 islands × Normal / Hard / Hell, 2–5 stages per quest. Hard enemies are +6 levels and Hell +12 (capped at 30); Hell enemies also get ×1.3 HP and ATK (an estimate, not from footage). Each island's stage rows use its own background strip (`assets/fields/`, cut from 1080p footage by `tools/field_strips.gd`; Sprout and Sky keep the APK's forest strip), and the field page shows the original island texts. Robo and Sky battles use their own backgrounds (ssets/battle_bg/, rebuilt by 	ools/battle_bg.gd from frames with an empty enemy side); other islands use the forest.
- **Hunter's Folly** follows the 2016 footage: energy 10/20/30/40/40/40/40, bosses Lowe (Lustful–Envious), Crueltee (Glutton–Greedy) and Vengens (Wrathful), its original description and cave stage strip.
- **Special islands** (`data/special_islands.json`): Material, Spirit and Magic (always open); Training (EXP), Treasure (gold); Jungle, Icicle and Volcano; Hunter's Folly and K9 Kingdom. They follow the wiki's weekday schedule (Training Mon/Wed and Treasure Sundays, as their in-game text says, plus event days), and a closed one opens for 1 hour for 60 gems through the original Purchase dialog. Magic Island fields cost 10 energy and drop their 2-5★ evolution line; Material Island fields cost 5. Deep Ocean and Hunter's Folly battles use the APK's island loading screen. Losing a battle and choosing Forfeit shows the original Quest Failed tip (Edit Team / Go Store / Go Train). Mansion of Madness and Nature Spirit's Forest raids have their own battle backgrounds, cut from footage. Deep Ocean Island is a field chain (as in hJbt19b1z9w): Normal Fields 1-10 and Hard/Hell Fields 1-9, each opened by clearing the one before ("New" tag), Hard/Hell tabs opened by Field 9 of the tab before; energy 5 per field number (7 Frozen Sea 35, 8 Titanic Foot 40), 6 Iron Shark (Shaark) and 9 Mythical Whale (Whalgent, immune to debuffs) speak their footage lines, and 10 Ryugu's Party costs 100 Friend Points for 10 stages against Armin Coral. Rare roamers (Mini Coral and, rarely, Armin Coral on Normal, Turto Papa on Hard, Chibi Lorel on Hell) can join a wave and always drop when beaten. Fields 1-5 are placeholders.
- **Happy Halloween** (HD livestream #1, Oct 2016): event-only, open 13 Oct – 8 Nov each year. Field "1 Jack's carnival" (10 energy, boss Jack-O-Paw, drops Jack and Hallomew) with the original description and island art cut from the stream. Its level, exp and gold, and the other fields the description mentions, are not in the footage.
- **Quest Failed** screen is the APK's `R_d_fieldFailure`: stage name, gold and cubes collected, "Give up any gold or cubes and leave?", Go On for 10 gems (revives the squad) or Forfeit.
- **Sky Tower** (`scripts/systems/sky_tower.gd`, `tower_screen.gd`): 50 floors × 3 rooms, rebuilt from the APK layouts and the 2015 "Sky Tower Floors 1-5" footage (frames in `research/videos/frames_tower`).
  - **Page:** the original `R_towerEnterPage`: Floor List over the tower art (`R_towerFloorSlot`: lock, NEW, selection, a friend's icon on the floor they reached) and an Overall tab (`R_towerRankSlot`, 99 weekly simulated players ranked by floor, then clear time). View My Rank (`R_d_towerRank`) and the Fever gauge sit at the bottom. The right side has the team, the Floor title, a 3-stone Drop List (tap a stone for its stats), the Boss with a "!" Tip (`R_d_towerTip`, original wording), 5 tickets with a timer, "+" to buy a ticket and Enter.
  - **Battle:** sky/tower backdrop and the `battleUnlimited` Fever bar above MP. Each room counts down from 1:30 under a skull; a "time_limit" boss room has 1:00. Stone boxes drop from enemies (black, purple and red `H_cube_03-05`) and collect by the timer. Pause shows the original forfeit warning.
  - **Fever:** 0-100, kept between runs (`tower_fever`), about +6 per enemy-skill hit and +0.25 per basic hit. Tap the Fever tile over the leader for 10 s (real time) of 0-MP leader skills.
  - **Rewards:** the original tower card (`ID_9PATCH_tech` in `R_d_reward`): time, gold, "First Clear Reward" ticket ×1 and boxes, then "Open Cube" reveals each stone (RANK X).
  - **Confirmed floors** (`data/tower_floors.json`): bosses and Drop Lists for floors 6, 15, 24, 27–34, 46, 49 and 50, and the room enemies of 46, 49 and 50, read from 1080p footage. `tools/tower_panels.gd` finds the floor page in a video's frames and names the boss; `tools/match_art.gd` names a monster from any crop. Other floors stay procedural.
  - **Tickets:** 5 max, 1 every 2 h, refunded on a first clear, or bought for 30 gems. A floor entered on a bought ticket has a lower Drop List (as a player described). Unlocks after Moonlight Desert.
- **Magic Stone icons** (`assets/stone_icons/`): the original artwork for all 10 types. Eight come from the M.Stone list in 1080p footage (`research/videos/frames_tower/icons/hd_up`); Steel and Spirit, whose stack counts overlap the art there, come from the 2015 Sky Tower Drop List upscaled 4× (Real-ESRGAN). `tools/stone_icons.gd` (`-- --src=<dir>`) removes the slot, badges and counts. Drawn smaller at low ranks, as in the original.
- **Magic Stones** (`scripts/systems/magic_stones.gd`): 10 types, ranks E to S+, and I/II/III variants from rank B. Crafting, equipping and the 3rd slot use the wiki's costs.
- **Training** uses the wiki's exact tables:
  - the EXP table
  - Boost odds (80/40/20/10/5%), Boost PT and costs
  - Fusion costs (1k–500k)
  - free Evolution
  - EXP feeding
  - Awakening of 6★ monsters to Lv50 (+3 with an identical monster, 5,000 × cap gold)
  - stats growing 4× past Lv30
- **Pets** (`data/pets.json`): 21 pets from the wiki, from the Normal (10k gold) and Rare (50 gems) Pet Cubes. Each gives stats plus a random element passive, with Lv30/33/35 requirements.
- **Store:** Blue, Yellow, Red, Honour and Pet cubes, and a weekly-rotating Mystery Box: a box of 50 prizes (★6~★3, the featured monster guaranteed by the 50th draw) drawn without replacement from a grid of "?" tiles, Draw 1/Draw 10, Reset Box refills it. The Honor tab follows the 2016 footage: Special Monster ★5 (300), Special Material ★5 (100), Special Monster ★4 (50), Awaken Material (500), Yellow Cube (35) and Fire/Water/Nature Evolve Material (35).
- **Music in its original spots.** The APK only ships five tracks; chromaprint matching against the OST
  playlist (`tools/fetch_music.ps1`) showed Title = opening theme, Boss-01 = Sky Tower boss, and the three
  Battle-pvp files = the Arena, duel and PvP League themes. The rest come from the playlist
  (`assets/music/`): Lobby theme on every menu, Sprout (also Material/Spirit and other special islands),
  Lake (also Desert Isle — the same track — and Moonlight Desert), Boneyard and Robo themes, plus Lake,
  Moonlight Desert, Dino Gorge and Robo boss themes. Not in the playlist, so they fall back to Sprout and
  the Sky Tower boss theme: Dino Gorge and Sky Island stages, and the other islands' bosses.
- **Missions** (Daily, Weekly, Endless, Event) and a **28-day attendance calendar** (rewards read from the original).
  The mission lists, goals and rewards are the late-2016 ones read off the Mission screen in footage
  (Sep–Oct 2016): e.g. "Explore any Islands!" 7 → 5,000 gold, "Claim the Sky Tower." 3 → Blue Cube,
  weekly "Clear Daily Mission" 40 → Yellow Cube, "Explore Volcano Island" 7 → Ruburak, endless "Beat N
  [Fire/Water/Nature/Normal] Monsters" and "[Collect] [★N]" chains, and the "[Otc] Explore Magic Island"
  event (Magic Island3 → Blacky). Not seen in footage, so estimated: Beat 250/500 Monsters, Beat 10
  Element Monsters' gold, [Collect] 100 Monsters, Clear Volcano Isle Field 1, and the Elemental Island1/2
  event rewards. "[Collect] [★3–6] N Monsters" counts every non-material monster obtained (duplicates
  included, so ★4 can reach 400); seen tiers are ★6 12 → 3 gems, ★5 75 → 15 gems and ★4 400 → 14 gems,
  the other tiers are estimated. HD livestream #1 adds "Beat 50 [Element] Monsters" → 1 gem, "[Collect]
  25 Monsters" → 1,000 gold, and the October event missions: Explore Deep Ocean Island Normal ×100 → Mini Fifteen long-term Endless missions pay gems in rising tiers: quests, Index discoveries, different monsters at Lv.30, Sky Tower floor reached, Hell islands cleared, raid stages, arena battles, special-island runs, boosts, evolutions, fusions, quest catches, store cubes, daily missions and Friend Points sent.
  Coral, Hard ×70 → Turto Papa, Hell ×50 → Chibi Lorel, and Explore Halloween Island (Normal) 1 ×40 →
  energy (amount estimated at 20). Friends have the original **Send Friend Points** buttons (once per friend per day), which
  the "Send Friend Points." daily counts.
- **2016 weekly events** (`data/events.json`, `scripts/systems/events.gd`): the 15 real "Weekly Events" calendars (4 Jul – 16 Oct 2016, from Nexon's Twitter and Facebook), repeated in order from midnight UTC, plus the Oct–Nov 2016 long events each year. They change gold, cube drops, XP, energy, boost chance/cost, fusion cost, Lv30 gems, friend points and awakening, and open Training/Treasure Island (event-only, as in 2016). Hot Time on the hub shows the next 7 days and which week of the 15 is running. Week 8 includes the 26–27 Aug 2016 make-up events (3x Friend Invite, 3x Gold Special Islands). Friend Invite events multiply the energy a new friend mails you (5 base). `--test-date=YYYY-MM-DD` fakes the date. **Deep Ocean Island** (Sundays; bosses from the wiki, rest estimated). **Elemental Island** (costs gems, Red Cube drops), **loading screens** with the original tips and monster quotes, a 3-slot team until Sprout Island, and unique species per team.
- **Raids** (`data/raids.json`, `scripts/systems/raids.gd`): the wiki's four (Mansion of Madness, Ruined Village, Beauty or the Beast, Pharaoh's Curse, with exact room line-ups), plus the four 2016 **Spirit raids** (Fire Spirit's Cave, Nature Spirit's Forest, Undine's Ocean, Volt's Castle), whose bosses are immune to status effects. Nature, Undine and Volt line-ups, bosses, drops and island art come from the 2016 raid videos (`tools/raid_scan.gd` matches the Stage popups against the icons, `tools/raid_island_art.gd` cuts the islands). Islands sit in chains until you spend the day's key on one (chain-break animation in `scripts/ui/raid_lock.gd`). You lock in 20 monsters and fight 12 rooms with parties of 5. HP and knock-outs carry over, bosses enrage every 20 s, and big gold, no EXP.
- **Visit & duels** (`visit_screen.gd`, original `R_friendMain`): the Visit button on a friend (and on any arena leaderboard row) opens their island with their team, Team Rank/Type and last week's challenge rank. Friends can be challenged with Request duel: a 2:00 PvP battle with the duel HUD and pause ("Give up and leave duel?"), ending in "Match Won!"; the day's first win gives 10 FP. Friends only store a leader, so their other three monsters are generated from their name.
- **Pause** uses the original `R_d_pause` variants: Pause → Stop Quest → "Give up any gold and cubes and leave?" for quests, "Give up and leave match?" for Arena/League, the duel version, and the Sky Tower forfeit.
- **Hot Time:** the hub's HOT TIME! button opens the original "Hot time Benefits" list (`R_d_hotTime`) for today; This Week shows the weekly schedule.
- **Messages** (`scripts/systems/mail.gd`, `scripts/ui/mail_box.gd`): the hub envelope opens the original `R_d_message` box (`R_messageSlotTM` for Team Monster, `R_messageSlotFr` for friends, max 50). Tap a gift to receive it (`R_d_message3`) or Receive All. A welcome gift arrives once, up to 5 friends send Friend Points each day, and PvP League season honour is delivered here. "NEW" shows on the envelope while mail is waiting.
- **Grade sort** orders by the monster's class (S+ > S > A > B > C), then stars and level (Team, Train, Boost, League editor).
- **Arena** (`scripts/systems/arena.gd`): a weekly ladder of 99 simulated rivals whose squads scale to yours. The enemy leader spends MP like a player. Tokens are 10 max, 1 every 10 min (or 1 gem). 51 entries a week pay 30 gems, the top 50% earn Honour, and the Honour Cube summons 4–6★. Battles last 2:00 with the original VS HUD; the Team 1–3 tabs on the VS page switch squads, and a 5 s PvP loading screen (`scripts/ui/loading_screen.gd`) plays after VS. Won battles end with a slow-motion final hit, and leaving any win shows a 5 s loading screen.

## What's reconstructed vs. original

These come straight from the original game, via the wiki and the APK: monster stats, skills and MP costs, support cooldowns, passives, evolutions, elements (Fire > Nature > Water > Fire, ±50%), the energy system (1 per 3 min, cap 40), cube prices, continuing for gems, and screen layout and art.

Fitted to **gameplay footage** (OCR of 11,000+ walkthrough frames): gold, EXP and gem rewards, stages per quest, starting resources, and boost, fusion and evolution rules.

These are **our own tuning**, because the server-side numbers are lost:
- enemy levels per stage and the wave composition
- the drop rates
- the exp curve and boost odds by star difference
- the HP scaling (`BattleUnit.HP_SCALE`) and boss multipliers
- MP regen rate and gacha odds

The original only animated monsters with its own sprite animations, which were lost. Here, monsters are static cutouts with tween-based attack and hit animations.

## Tutorial

A new account plays the original first-time tutorial, rebuilt from the TapGameplay walkthrough
(parts 1-2) frame by frame. All dialogue, boss lines, island texts and the test friend XiaNoro are
in `data/tutorial.json`; `scripts/ui/tutorial.gd` plays it (dialogue band from `R_d_tutorial.xml`,
"New Island!" card, dimmed focus steps with the bouncing APK pointer, Skip button). Chapters:
intro → Sprout-1 (map, stage, friend + Go, skill and support lessons) → boss lines on Sprout-2…6 and
Lake-1…3 → Mini's 3rd slot after Sprout-3 → Goldbat's Store (Friendship + Yellow cube) and new leader
→ team-edit help → Wamiami's missions → Firepaw's boost lesson → Rookie's friends → Ayn's evolution
→ Firepaw's Arena mission ("Defeat the boss of Desert-4", 2,000 gold; the Arena stays locked until it's
done) → G. Drank's Special Islands tour after Desert-10 → Shinoblue's Team Rank / Fusion talk after Moonlight-4.

Story quests outside the tutorial (`scripts/systems/story_quests.gd`, from HD livestream #1), played on
the hub with the same dialogue band and "New Quest!" / "Mission Clear" cards, with the hub bubble showing
progress: Talmag's lost jewel — explore Lake Island 5 times (4,000 gold), capture 5 two-star monsters
(8,000 gold), then after clearing Lake Island explore Lake-12 3 times (Talmag joins you). The stream's
card for step 2 reads "[Collect] [★4] Monsters" while Talmag asks for 2-star ones; the player finished it
with one Lake-9 run, so 2-star is used. Tobiak's six-line talk plays once on the hub after your first
forfeited story battle.

From the walkthrough (parts 1-26): boss lines for ~50 story stages (they also set that stage's boss,
`StageBuilder.story_quest`; Hard/Hell fall back to the Normal line), special-island boss lines
(`monster_lines`), island descriptions and clear rewards, and the island-clear sequence (Firepaw →
"Mission Clear" gem card → next-island line → "New Island!" card, from `R_d_dailyQuest1`). Field slots'
Monster cube lists the stage's monsters. `--test-autosay=<sec>` advances dialogue on a timer;
`--test-continue` reloads the test save.

Also added for it: the ready page (`R_readyPage`), friends (`R_friendBackPage`, offline generated
players, once-a-day borrow, friend points, Friendship Cube = 200 FP), the cube opening
(`cube*_open_*` frames, rarity title, stars, NEW), the loading card (`battleLoadingPage2`), the
"Quest Successful!" card (`R_d_reward`), tap-to-cast support skills, x1.0 / x1.4 speed (the original's two), the battle HUD from `battleBeta.xml` with the `battleIndicator*` HP bars, and team
slots unlocking after Sprout-3 and Sprout-6.

- `--test-newgame` fresh account · `--test-tutauto` plays the whole tutorial by itself (log lines
  start with `TUT`) · `--test-tutdone=intro,map` · `--test-cleared=sprout_island:3` ·
  `--test-reveal=<id>` · `--test-instawin`. Dev menu (F1) has Skip / Replay tutorial and +200 FP.
- `tools/dialog_lines.ps1`, `tools/frame_sheet.ps1`: OCR dialogue lines / contact sheets from footage.

## Raid and Arena

Raids are the APK's "technical dungeon": the Raid tab on the islands map (key 1/1, "Resets in"),
`R_squadChoicePage` to pick up to 20 monsters, `R_technicaldungeonLobby` (20-monster list with HP / KO /
PARTY, party of 5, "Stage n / 12" + GO, the 12-skull road; tap a skull for `R_d_technicaldungeonLobby`).
Raid island art for Mansion / Ruined Village / Beauty from the wiki; spirit raids use the spirit's sprite.
The hub's Arena opens `R_d_selectAnArena` (Arena / PvP League). Arena is `R_pvpEnterPage` (Overall / Friend
rank, Weekly Match Info, 10 tickets, View Reward = `R_d_pvpRewardView`), then `R_pvpStartPage` vs a matched
rival (the ticket is spent on matching; leaving the VS room or giving up in battle shows the original
"Leaving now will be considered forfeit" notice and counts as a loss), and `R_d_pvpResult` (WIN / DRAW / LOSE) after the fight. Weekly honour follows the original table.
PvP League (checked against 2015 footage): `R_pvpGroupEnterPage` waiting room (12 `R_pvpGroupSlot` cards, League
Match Info, 10 tickets, Enter Arena = 2 tickets), `R_pvpGroupEditPage` (Remove / sort / Team Auto; tap a team slot,
then a monster), `R_pvpStartPageGr` (their first 4 shown, 8 hidden), the 12-monster `R_d_pvpResult`, View All Rank
(`R_d_pvpRankGr`) and View Reward (`R_d_pvpGroupRewardView`, honour 300/250/200/160/120/80/60/40 + badges).
`--arg=edit:1`, `--arg=match:1`, `--arg=ranks:1` open those pages.

## Store

`scripts/ui/screens/cubes_screen.gd` on the original `R_shopPage` (Hot / Cube / Energy / Gem / Gold /
Misc / Honor tabs, `R_shopSlot` cards, `R_d_buy2` "Item purchase" box), checked against 2016 footage.
Hot is the Mystery Box (`R_shopSlotLT`): featured + 4 monsters on gold stairs; Draw opens `R_d_lotteryTable` (featured monster on the gold stair, ticked once drawn; the 50 prizes shown as icons, dimmed until drawn, as in the 2015 videos XuRSRB_sws8 and n5dnu2B1vPw), and View Details opens `R_d_lotteryTableReward` (Total x/50, featured + 3). Random Pick 1 50 gems, Random Pick 10 500 gems. The banner's 5 monsters are fixed for the week; Reset Box ("Reset Box success.") refills the box with a different one of them as the featured monster and costs 200 gold doubling with every paid reset that week (6,400 → 12,800 → 25,600 in tMHf6pD2JiY), free once 30 are drawn (0 at 30+/50 in n5dnu2B1vPw). The box holds the featured monster, 4 other ★5-6 (the 3 under View Details), 5 ★5, 15 ★4 and 25 ★3, shuffled.
Earned cubes open free at the front of the Cube tab. Misc sells box slots and 2× EXP / Drop boosts
(`Save.add_item_boost`); Honor has the weekly Special Monster ★5 / Material ★5 / Monster ★4. Gem packs
are shown but can't be bought offline. Debug: `--arg=tab:cube --arg=buy:blue` presses a card.

## Dev menu

Press **F1** anywhere (Esc or F1 closes). Gold / gems / energy / honour, refill Sky Tower
tickets, clear every story island, +100 box slots, and add any monster: search by name, element
(`fire`, `water`, `nature`) or grade (`6*`), set Lv (1-50) and boost (+0-5), click its icon. **Give all** adds one of every monster;
**Remove all** (click twice) deletes every monster except the current team.
**All Magic Stones** adds one of every stone (10 types × E–S+, I/II/III from B = 150) and raises the stone box cap;
**Send test mail** drops four sample messages in the mailbox. **Next event day** / **Next event week** move the
event clock forward (saved as `event_shift`, also moves special-island weekdays); **Real date** resets it.
Changes save immediately; the screen reloads on close (except mid-battle). `scripts/ui/dev_menu.gd`.

## Original menu layouts

The APK's 218 UI layout files are in `data/layouts/` and `scripts/ui/layout.gd` turns them into
Godot controls (cocos coordinates: y up from the parent's bottom-left; pages were authored 1066×640
and are centred). Rebuilt on them so far: main screen (`R_main`, `B_navigation`, `B_monsterTag`),
the top bar on every screen (`R_top2`), Missions (`R_d_dailyQuest`, `R_missionSlot`, `B_rewardIcon`),
attendance (`R_d_attendance`), Adventure map and stage lists (`R_islandChoicePage`, `R_islandSlot`,
`R_fieldChoicePage`, `R_fieldSlot`) and the Team page (`R_teamEditPage`).

- `tools/layout_outline.ps1 <name>` prints a layout's tree; `--layout=A+B` renders raw layouts;
  `tools/render_layouts.ps1 -Out dir -Screen hub [-Arg key:value]` screenshots screens.
- Team page: TEAM 1–3 tabs (`Save.switch_team`, presets in `data.teams`; the active one is `data.team`).
  Monsters in any team are protected from feeding/selling and show "TEAM n" in the list.
- Battle: a ring around each ally's element icon fills with its support cooldown (leader: MP toward the
  cheapest skill) and glows gold when ready.
- `tools/rip_reveals.py <video id>` cuts monsters out of cube-opening footage (single-monster reveal screen) into `research/sprites_rip/<video id>/`, without duplicates; `tools/match_rips.py` matches them to monster ids against the current art and `tools/install_rips.py` copies them into `assets/monsters_cut` (old sprites backed up in `research/monsters_cut_pre_rip`). 69 six-star sprites came from the 110 Red Cubes video (Av0_PQeZR7Y), including Blue Dragongod, which had no art; 40 more (2–6★, mostly from older forest-stage footage) came from the `forest_reveals` and `batch2` sets, which pool several videos and list hand-checked picks in `PICKS`. Footage of any resolution works; RARE/SUPER RARE (blue titles) are detected too. Use `match_rips.py --any-grade` when star counts are unreliable. Needs Python 3 with numpy and opencv-python.
- `tools/clean_cutouts.gd` strips card leftovers ("Lv." label, grade stars) from `assets/monsters_cut`;
  it reads the untouched cutouts in `research/backup_monsters_cut`.
- `tools/refine_sprites.gd` is the last pass on `assets/monsters_cut`: peels the card-brown fringe, drops
  specks, softens the cut edge and lightly sharpens (`--amount=0.45`, no upscaling). It reads
  `research/monsters_cut_v2`, so it can be re-run with a different amount.
- `tools/fetch_wiki_art.ps1` downloads the game's own 92×92 monster icons (814 of 817), island
  pictures and skill icons from the wiki into `assets/icons`, `assets/islands`, `assets/skill_icons`.
- Layout images that were CDN-only fall back to the closest APK sprite (`Layout.FALLBACK`); the
  island map's ocean is drawn in code.

## Not yet done

- Remaining screens still use the code-built UI: Store, Monster Book, Sky Tower, Magic Stones,
  battle HUD and result dialogs, training dialogs, title (layouts exist for all)
- 12 monster portraits are still missing (7 were recovered from footage loading screens; `tools/frame_portraits.gd`)
- Friendship Island (needs FP from friends)
- `tools/install_manual.py [dir]` installs hand-cut art from Desktop/ManualAssets (Monsters -> assets/monsters_cut,
  pets -> assets/pets, Mstones `<grade><colour>stone.png` -> assets/stone_icons/<type>_<grade>.png).
- `tools/patch_islands.py` / `tools/patch_specials.py` apply footage corrections to the island data (re-run after build_db.gd).
  `tools/segment_stages.py`, `tools/boss_sheets.ps1`, `tools/icon_sheet.py`, `tools/find_dialogue.py` and
  `tools/location_check.py` help verify stages against walkthrough footage and wiki locations.
- `tools/cut_sfx.ps1 <video id> <start> <len> <name>` cuts and normalises a sound into assets/sfx.
