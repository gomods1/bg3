# STATUS

Read this first, then `PLAYTEST.md` (what was exercised with which character and path, what was
not, and which assumptions may break elsewhere) and `KEYS.md` (every shortcut, mod and game,
confirmed or not).

**Next session starts with "Next session: start here" below (jumping on routes first; user,
2026-09-25).**

## Current state (session 7, 2026-09-25)

Latest save: `96_village_sw_teahouse_gap` (the party fully rested at the Blighted Village's
south-west edge; the quest reward window, "Mensajes en pantalla" and many combat fixes are in; the
teahouse is not reachable by any route found). Earlier in the session:
Where the test game was mid-session: act 1, the "Templo profanado" under the Shattered Sanctum: Priestess
Gut is dead (killed by Tav alone in her chapel, looted), Tav escaped through her quarters;
Shadowheart and Gale are up in the Sanctum by the hanging cage; the goblin camp is not hostile
in this branch. Left: Dror Ragzlin, Minthara, the prisoner Liam. Saves: `67_session7_start`
(Blighted Village path, from 63) ... `73_worg_pens_won`, `74_halsin_talked`, `75_camp_rested`,
`76_minthara_talked`, `77_torture_room_won`, `78_gut_chapel`, `79/80` (branch: Tav dies later),
`81_gut_chapel_rested`, `82_gut_setup`, `83_gut_killed_rested`, `84_gut_escaped`,
`85_rested_before_halsin`, `86_chapel_door_fight`, `87_temple_retreat` (latest: the party in the
Templo profanado after retreating, nearly dead).
Session 7 so far:
- **The "resources" message** the user asked about: "No tienes suficientes recursos: Acción" is
  the game's cursor label for the main-hand attack it previews while the cursor rests on an enemy
  in combat (no dialog; nothing to dismiss; Escape opened the game menu instead). The mod's
  targeting left the cursor on its last target, so the label stuck and the HUD even took the
  hover for an armed attack (it opened targeting by itself after spells). Fixed: the cursor is
  parked on the minimap before any armed action is followed (Activate.Park; verified: label gone,
  a real attack still confirmed and killed Sarnoso); the mod's preview reads the label with its
  "[1]" filled ("No tienes suficientes recursos: Acción", from the shown text).
- Combat start/end is no longer said around the game menu, the map and other HUD-hiding screens.
- Items: Ctrl+D on inventory, equipment, loot and trade items gives the weapon's damage dice and
  type, versatile dice, properties, weapon class and whether the character is proficient, the
  weapon actions it unlocks, armour class, enchantment, weight (Game/ItemStats). The character
  panel names whose it is and follows [ ] / F1-F4 to another party member. The empty light
  source slot (no name in the game) is left out. Item moved to Gale ("Enviar a"), learning a
  scroll read ("Aprender conjuro (Necesitas 50 de oro...), no disponible").
- Barks: the same line is not repeated within 5 minutes (Volo's song looped every minute).
- Passages: a use that moved nobody falls back to the thing's menu "Usar" (the worg pens'
  entrance: the plain click got "No puedes llegar", the menu's Usar went round and in).
- Dev: `source tools/mod.sh` (modcmd, modsel, modlist), `press rbracket`.
- **The worg pens fight won by keyboard** (6 rounds, 8 enemies, Halsin allied; details in
  PLAYTEST session 7), then Halsin's talk, a long rest with Withers and the Dream Visitor.
  Fixed on the way: damage to things named right, the game's refusal reason on a failed confirm,
  a spoken notice while the camera turns to aim, equipping in combat confirmed first (it spends
  the action), an opportunity-attack warning before walking to a thing in combat, context menu
  actions confirmed ("Hecho: Enviar a: Gale"), area banners not repeated.
- Open: Magic Missile at 4 darts on two far goblins fired 2 (blocked?); aiming at targets on
  ledges is slow (hover points, camera turn, tactical view: up to 16 s).
- Then Minthara's talk, the torture room fight (won), Priestess Gut killed twice (the first
  branch lost Tav to the goblins outside her door; the second escaped through her quarters).
  Fixed on the way: the picking check (darts went to the enemy behind the chosen one), a door
  clicked shut after opening, markers' double arrival, a new armed action not followed, cancels
  checked, a close target looked at from the side, actions' availability read live, items that
  grant spells and passives described. Two fights at once work (each follows the selected
  character).
- Then (saves 85-87): an 8-enemy fight at Gut's door, lost and retreated from; fixed on the way:
  hover searches no longer overlap (wrong target, minute-long previews), confirms aim first,
  Escape over a reaction declines it, the hotbar's "cannot act" messages are spoken ("No se
  puede controlar: derribado"), trips open a shut door on the only way. Party in the Templo
  profanado at 4/1/5 HP, supplies nearly out.
- Then (saves 88-91): partial rests, food bought from Grat with the loot (supplies now said per
  item), the party regrouped, down the "Raíces nudosas" (ladder climbs down fixed: step back,
  tactical camera), Scratch befriended. Latest: `91_scratch_befriended` in the forest below the
  Blighted Village; Auntie Ethel 119 m away with no route (jumps on routes still missing).
- Then (saves 92-93): the grove reached by exploring north from the Roadside Cliffs (its gate
  opens as the party comes), Auntie Ethel met (she was in the grove), Arabella's quest completed.
  Latest: `93_arabella_done` in the Emerald Grove. Left in act 1: Dror Ragzlin and Minthara (the
  Sanctum is partly hostile after Gut), Auntie Ethel's house, the refugees' quest.

## State at the start of session 7 (session 6, 2026-09-25)

Where the test game is: act 1, Blighted Village, on the forest path below the ogres' platform
(Tav, Shadowheart, Gale, level 3; the ogres friendly after an Intimidation check). Latest saves:
`60_dug_chest`, `61_throws`, `62_marks`, `63_marks_persist`. Session 6 added: world context menus
(Acciones on things and characters: dig, pick up, examine), examining characters, whole throws,
following actions the game arms by its own keys, relations, stealth, marks, signpost memory,
the farther list as the complement of Nearby, scene waits during trips (details below and in
PLAYTEST.md). The three items of the earlier session goal (level-up spell choices, the reaction
pop-up, grouped combat log for big fights) were done and verified in session 5.

## State at the end of session 5 (2026-09-24)

Game 4.1.1.7398727, Script Extender v32 (release channel), Prism 0.18.2, NVDA. Game language Spanish.
Nothing from sessions 2 to 5 is committed yet (commit when the user asks).
Where the test game is: act 1, inside the Emerald Grove (the druids let the party pass: "Kagha
quiere verte"), near the "Salva a los refugiados" objective; Tav at 1 HP. Saves (`game.py saves`):
`12_grove_gate_won_laezel_caged` ... `17_grove_after_stop_walking`; older ones back to the nautiloid.

The three items of the session goal are done and verified in play:
- Level-up spell choices: Gale's level 2 spells picked in the game's own grid by verified clicks
  (Magic Missile, Shield), read as lists with each spell's details (Screens/LevelUp, SpellChoiceList).
- Reactions: the game's reaction pop-up read and answered (Shield used when a goblin hit Gale at
  the grove gate; "don't react" also verified); per-reaction settings in the mod menu.
- Big fights: the combat log is grouped per actor's turn (8 enemies plus allies at the grove gate).

Session 5: pathfinding checked (the engine's routes are enough, see CLAUDE.md "Exploration
facts"); travel fixes (targets snapped to walkable ground, a shut door named, ledge clicks refused,
scenes on the way end a trip silently, progress along the route, far fallback clicks, four camera
views, stuck camera nudged); Stop walking; duplicate map markers merged; **Places** (mod menu): the
named sub-areas the party has entered, remembered in the save, walk there (verified both ways in
the grove); **trading** (quick trade with Arron: buy, sell, refusals); map marker walks reach
traders the client has not loaded yet. **Player installer** (install/, `python tools/package.py`):
finds the game, gets the Script Extender from GitHub, copies files, registers the mod, desktop
shortcut without the launcher, self-test, manifest-based uninstall; verified on the real game from
a fresh profile (the release build read the EULA). **Books** read as paragraphs. **Dice roll
bonuses** (Guidance added by a verified click; totals wait for the bonus dice). Story played with
the mod: Kagha and Arabella, Shadowheart's talk, Nettie's whole scene (save 27: find Halsin).
Fixed on the way: a new answer set replacing another is announced (a number key had chosen from an
unheard list), "No option N", tutorial markup cleaned, heal results joined to the action line.
**The mod speaks Spanish** (game language detected; `Strings/es.lua`; English stays the fallback;
config `speech.language`). `tools/check_strings.py` found a shadowed key ("place_here").
**Travel never walks into dangerous surfaces** (fire killed Tav once on a route; routes are now
checked tile by tile against the walker's own surface influences). Undetected traps are no longer
listed. The "!" (wants to talk) is announced. Loading hints are read.
Latest (session 5, saves 36-40): the party walked from the Risen Road to the Blighted Village and
the goblin camp gate by heading for the quest marker ("walking to the nearest point"), talked past
both goblin posts (checks with Guidance), and reached level 3 by keyboard (Wildheart barbarian with
the bear heart, cleric, wizard spells by first letter). Fixed on the way: the needed die with
bonus dice, a total read too early, tutorial Enter, a click on a corpse, the stuck level-up intro.
Then: upcasting (Left/Right on a spell in the actions list: Magic Missile armed at level 2),
Gale's spells prepared in the spellbook, a long rest from the goblin camp (the Dream Visitor), the
Shattered Sanctum entered through its oak doors, companions talked to in under a second (a near
target that cannot be clicked is looked at first). Throw: its first step works for light items
only (heavy ones are not pickable in throw mode). Saves 36-44.
After that (saves 45-50): dialogue lines spoken when the game says them (not in bursts); rolls
fixed (reroll offered only with inspiration, "anything but a 1", Enter during the dice queued);
barks setting (all / party / none); Where am I (area, ground, camera facing, open directions,
people); Nearby groups repeated scenery ("Vela ... y 19 más") and Ctrl+D reads an item's value,
weight and description (asked of the server); walks take passages ("Entrada al cubil de
huargos") and ladders from the top, and never "use" a ladder or passage as an obstacle; a
companion's long remark no longer ends a walk; a 9-round fight in the worg pens by keyboard
(reactions, upcasts, downed and revived, death saves, game over and loading) — lost, save 50 is
before it.
Then: Travel split into Travel (the trip loop), TravelClicks (route to clicks) and TravelWaits;
only doors are used "on the way" (a shelf was opened as an obstacle); the party's chain changes
(the game's G key) are spoken; "far from you" after a walk verified; the mod's words in all 15 of
the game's languages (translation agents; tools/check_strings.py 0 errors; every table compiled
in the game's Lua; French heard); credits, the mod manager's first page, back to the main menu;
the XAML index includes the Gustav/GustavX/Patch8 pages.
Then (saves 53-57, Blighted Village): the Move cursor walks there outside combat; loot: Enter takes
one item, Space takes all; in the character panel, "Acciones: <item>" (mod menu) opens the game's
own context menu for the item as a list (send to camp, to a companion, drop, examine...: the
bucket went to Gale); the Examine window is read. Then (saves 58-60): things in Nearby/Markers have "Acciones" too (the
game's world context menu by a verified right click; a step back when the thing is underfoot):
the shovel picked up, a dirt mound dug, a chest came up (owned: the game refuses it in plain
sight); side tutorials no longer repeat; locked containers are named. Session 6: examining
characters (Acciones > Examinar on anyone in Nearby: class, subclass, race, background, HP, AC,
abilities, traits, approval), one sheet reader shared with the character panel (Game/Characters.Sheet,
Screens/SheetWords); context menus flipped at the screen's edge are clicked right. Whole throws
(save 61): an action the game arms itself (X, number keys, an item's "Lanzar") gets the mod's
targeting (Screens/Hud follows it); step 1 lists only what can be lifted (Game/Throwing), step 2
where; place clicks are checked and repeated once (a lost click). The farther list now holds
everything Nearby leaves out; trips wait out a remark that starts just after a failed click;
signposts are remembered when read from a list (Server/Signposts; not yet heard). The player's
own marks ("Marcar este lugar", "Tus marcas": Server/Marks) stand in for custom map markers.
Stealth: "Quién te ve" and announcements while sneaking (Exploration/Stealth, Game/Watchers).
Grouped speech: several log lines about one character merge ("Tav: ha recogido 1 Olla, 1
Provisiones"); area banners are not doubled; walks stuck within 5 m of a point end "as close as
the ways go". Level-up spell choices re-verified from save 38 (Gale: Misty Step, Scorching
Ray); a replay of the worg pens fight could not be started (targets out of cursor reach, see
PLAYTEST); a stealth spotting was heard for real ("Te ven: Guerrero goblin, ..." then the
goblin: "¿Tienes algo que ocultar?"). The worg pens fight replayed (save 66): reaction pop-ups
read and answered twice, the grouped log over five rounds with 7 enemies; fixes: repeated log
lines dropped, no following of an armed action that cannot be used. Next: examining characters, the world context
menu (right click on people), throw with a light object.
Later in session 5: **ways round dangerous surfaces** planned by the mod on the game's own AI
grid (Game/SafeRoute: walls, slopes, steps and burning tiles read tile by tile), verified going
105 m round a fire that closed a gully; signposts read by walking to them (Enter); detours; doors waited for while opening; character
creation name typing (Screens/TextEntry); saving (new save and overwrite, from the game menu);
game menu buttons by verified clicks; "[IE_...]" placeholders as key names; mouse-worded tutorials
get the keyboard way; the prologue replayed in Spanish with a new character (saves 32-33: "Mira",
helm fight). The main Tav game is saves 30-31 (Risen Road / chapel).
Character creation spell choices verified (wizard). Game menu: titled, Load by a verified click;
message boxes fall back to their command when the game ignores the injected key. The dev setup was restored afterwards
(`python tools/deploy.py`, dev config and profile files from before the test). The .pak was not rebuilt while the game ran: run `python tools/deploy.py` before a
player test (dev runs use the loose files). Next: more destinations (people of the area beyond the
loaded range; the map described), ROADMAP M4.

### Works in the running game (verified; details and limits in PLAYTEST.md)

Foundation
- Native bridge (version.dll proxy): Prism speech, Lua->native channel, mouse, watchdog (speaks
  when the Lua half never starts, e.g. after a crash left ModCrashSanityCheck), speech recovery
  (re-checks for a screen reader every 5 s while on SAPI; the menu's "Find the screen reader
  again" forces it). Clicks: an X1 press before each click (the game swallows the first press
  after keyboard input).
- Lua structure (CLAUDE.md "Architecture"): Core (Config file, keyed Strings, named key actions,
  Help, build Gate), Game (the only layer naming engine things), Screens (router registry,
  ListScreen with nested lists, Controls), Exploration, Combat, Net (client<->server channels),
  Server (read-only Osiris queries).
- Mod menu (Ctrl+M): every mod command, filtered to what is available now; direct keys only
  Ctrl+R (read screen) and Ctrl+D (details); any command can be bound in config.json.
- Localizable strings (Core/Strings): phrases, lists, sentences, numbers, plural forms per language.

Menus
- First-run screens, main menu (availability from the VM), difficulty, options (every tab and row
  type, key bindings read), message boxes (with check box), tutorial popups, loot (Take all),
  character creation gameplay part (choices, point buy, racial bonuses, skills, summary, random,
  finish), videos announced, saving announced.

In game
- Dialogue reader: every line with speaker, options with their tags ("Bárbaro, Fuerza check: ..."),
  Ctrl+D for a tag's meaning, answer with Enter or number keys; lines are not re-read when the
  conversation comes back after the dice roll or a tutorial.
- Dice roll screen (skill checks): check, difficulty, bonus, the number the die needs; Enter rolls;
  "Rolled 14. Total 17. Success."; Enter continues.
- History (mod menu): review buffers Events, Combat log, Dialogue.
- Story timers (the minimap countdown) announced each turn; notification banners (quests...);
  area names and "Where am I"; journal (quests, objectives, story); level up available.
- Character panel (I): inventory (use/equip by Enter), equipment (unequip), character sheet.
- Level up: features, hit points, new actions and resources, Accept; subclass list; **spell
  choices** (the game's spell panel opened by its tab, each spell with the game's title and full
  details, chosen or taken back by verified clicks on the game's own buttons: Gale 1 -> 2 done by
  keyboard); the game chains the next character's level up and the screen follows.
- "Farther things" (40-150 m) to pick destinations in the open world.
- Nearby list (game highlight + doors with state) and map markers/objectives, both with "go there
  and use it" through Travel: verified clicks along the engine's route, doors opened on the way,
  ladders climbed (click on the ladder), camera turned along the route, stops when a screen opens.
- Move (mod menu): the place cursor with nothing armed; Enter walks there (in combat the game's
  preview says the meters).
- Combat: start and turns announced with resources, turn order, status, actions list, targeting
  with the game's preview (hit %, damage, walk, attack of opportunity) and confirmation through the
  game's own command (no mouse), combat log narrated (both sides). The first fight (3 imps) was
  won by keyboard only. Shouts (Rage) confirmed on the character. Place cursor for Jump, area and
  ground-targeted actions (verified: Jump, Fire Bolt at the ground, Cleave), with who the area
  catches. Items: potions drunk, scrolls armed. Statuses with turns in status and turn order.
  Movement in combat (Move; "move toward" a Nearby entry or marker: the Move cursor at the
  farthest point this turn reaches). Objects within 3 m used by a click in combat. End-turn
  confirmation. Party switch announced. Spells: slots in status lines, spell levels, healing and
  saving-throw previews (Healing Word cast on Lae'zel). The helm fight was played to the
  transponder by keyboard.
- (session 4) Combat log grouped per actor's turn (config combat.log "grouped"/"full"): results
  per target, kills and downed first, the enemy's tail before the next turn line. Reaction prompt:
  what happened (the game's own text with the roll), each reaction with its description, use it or
  "don't react". Targets off screen: the camera is centred on them first. The game's refusal
  reasons are read ("¡Un obstáculo bloquea el paso!"). Walk-first ranged spells confirmed by a
  verified click; a command that does nothing is reported. The grave robbers' fight (4 enemies,
  10 rounds) was won by keyboard.
- Spell book (mod menu): class spells with state, prepare / unprepare. Reactions settings (mod
  menu): always / ask / never per reaction and party member.
- The goblin attack at the grove gate (8 enemies, allies): grouped narration, Magic Missile's three
  darts, Shield as a reaction. Reaching it needed a travel point typed in the dev console: no list
  offered the gate (see Known gaps: exploration).
- Targeting out of combat and objects that can be attacked (Lae'zel's cage freed by Fire Bolt).
- Rests (mod menu): short rest; long rest with the game's questions, travel to camp and the
  supplies screen (verified: full rest in camp, the night scene played). Nearby lists party
  members (a click on a companion talks to them: Gale's camp conversation).

### Rules from the user (also in CLAUDE.md and memory)
- Nothing a sighted player can reach may be hidden from the lists just because the game's
  highlight skips it; hidden-until-found objects are to be researched, not guessed.
- No magic movement: characters move and act only as a player would (verified clicks, the game's
  own commands and keys); pathfinding only decides where to click and describes routes.
- Blind players cannot use a mouse: every action needs a keyboard path; prefer game commands.
- Skip cinematics during development.
- Document thoroughly what was tested with which character and path (PLAYTEST.md).

### Known gaps (short list; the full list is PLAYTEST.md sections 3 and 4)
- Character creation: spell/cantrip and passive selectors, name, appearance, guardian.
- Combat: Throw (pick the object first), upcasting, several reactions at once, stale damage in previews
  of non-damage actions, targets the cursor cannot reach at all.
- Spells: the level-up "prepare" tab is not read (the spell book command does the same job).
- Dialogue: roll failure / inspiration re-roll / bonuses (Guidance) untested; race/deity tags.
- Exploration: Nearby = the game's highlight + doors + every other usable thing and non-party
  character within 25 m (user rule: nothing reachable may be left out because the highlight skips
  it). Open: how the game marks objects hidden until found (perception checks, secret doors,
  traps) so they are announced the way the game reveals them. Also: where am I, jumps on routes,
  stealth, traps.
- Trading, camp chest and leaving camp, map screen, save/load screens; inventory: other
  characters, drop/split/move items, weapon details.
- Side tutorials and notification toasts are not read.
- Review buffers (template_rpg 11) not built.
- The bridge cannot tell Lua that a click was refused (game not in the foreground).
- Localization: no second language table yet, the game language is not detected (M8).
- Installer, README, uninstall.

## Next session: start here (user, 2026-09-25)

The user asked to begin the next session with these open items, jumping first. Test game: save
`96_village_sw_teahouse_gap` (party rested at the Blighted Village's south-west edge).

1. **Jumps on routes.** Trips cannot reach places a player gets to by jumping (or by ways the
   pathfinder does not plan): Auntie Ethel's teahouse ("Tetería" objective) had no route from
   the Blighted Village, the Roadside Cliffs or the forest below the village (PLAYTEST session 7).
   What is known (CLAUDE.md "Exploration facts"): routes can be planned from any point by
   setting the path's `SourceAdjusted`/`SourceOriginal`, so a jump search is possible: points
   reachable from the character, landings within the character's jump distance from which the
   target is reachable, then walk there and use the character's own Jump (the Place cursor, as
   verified for Jump in combat). First find out how a sighted player reaches the teahouse (a
   path, a jump, a region that connects only once loaded), then build it and retest that trip.
2. **Slow aiming** at targets on ledges (10-16 s: body heights, box points, camera turn, tactical
   view in turn). Now announced ("Girando la cámara...") but should be faster (e.g. try the
   tactical view earlier, fewer points per view).
3. **Combat movement and use**: a Move toward something could end farther than its preview
   said; walk-and-use with one click when the preview allows (built, not heard); the
   opportunity-attack warning before a use (built, not heard); moves warn of dangerous
   surfaces (built, not heard).
4. **Stacks in trade**: a stack (Provisiones x3, 300 gold) can only be bought whole; find how the
   game buys part of a stack (split dialog / barter) and offer it.
5. **Unhandled or generic screens**: the tadpole powers screen (TadpolePowersTree, opened by
   itself once during end-turn presses: find out why); message boxes now titled "Mensaje";
   optional quest reward choices (built, not met).
6. **Still to hear in play** (PLAYTEST session 7 "Not yet heard"): the passage fallback (menu
   "Usar" when a passage click moves nobody), the "Has usado: <item>" fill, the talk-click retry.
7. Game questions seen, not explained: Magic Missile at 4 darts on two far goblins fired 2;
   Arcane Recovery unavailable after a short rest; Tav's ranged attack once unavailable.
8. Campaign: act 1 left: Dror Ragzlin and Minthara (the Sanctum is partly hostile after Gut; a
   fight at her door was lost), Auntie Ethel's house, the refugees' quest; level 4 at 1800 XP
   (Tav 796) brings feats and ability improvements, not built yet (M6).

## Older backlog (sessions 4-5)

0. **The world map, accessibly (user, 2026-09-24).** (Progress: the Explore command walks in a
   compass direction; the chapel -> grove gate trip now works by player means with it. Left: the
   map screen itself read by the mod, custom markers, faster travel.) Reaching the grove gate this session needed a
   travel point typed in the dev console: not something a player can do, and it does not count as
   a tested path. Build a proper way to read and use the map (its markers, areas, points of
   interest, the way there) and then retest that exact trip by the player's means: from the
   chapel entrance (save 08_chapel_rested) to the Emerald Grove gate, past Lae'zel's cage.

1. Exploration: research hidden-until-found objects (perception checks: compare an entity before
   and after the game reveals it), where am I, jumps on routes (Jump as the character's action),
   grouping long Nearby lists.
2. Act 1 (done: level ups, a 4-enemy fight with grouped log and reactions, rests and camp,
   Gale's camp talk): leaving camp / waypoints (fast travel), looting the grave robbers, Astarion,
   the goblin fight at the grove gate (many enemies and allies), the first trader.
3. Character creation with other classes (PLAYTEST.md section 5): spell and passive selectors,
   name entry, appearance presets, guardian; then a caster in combat (slots, upcast).
4. Notifications and side tutorials.
5. Character creation's spell and cantrip selectors (Game/SpellChoices is shared),
   then feats, ability improvements, passives. Then trading (M6), then act 1 blindfold chunks
   (M7).
6. Installer (`install/install.ps1`) + uninstall, README.
