# ROADMAP (from gate.md section 14)

Tick only what was verified in the running game. Status detail lives in `STATUS.md`.

## M0 Foundation
- [x] Recon: build, hashes, launch without launcher, profile paths (CLAUDE.md)
- [x] Script Extender v32 installed on the dev game; runtime log; DeveloperMode hot reload
- [x] Native half loads (own version.dll proxy; decision in CLAUDE.md)
- [x] Extraction: GUI XAML from Game.pak (extract/, gitignored); default engine input config
- [x] Other paks' XAML (Gustav: mod browser; GustavX: photo mode; Patch8: lobby, connectivity) in
  the index, later paks first; console overrides left out
- [ ] Extraction: story header, stats, localization
- [x] Bridge channel chosen by measurement (hooked SaveFile -> pipe, ~35 µs)
- [x] Prism speaks through NVDA (log verified; by-ear confirmation pending)
- [x] Build/version gate (SE version, game version -> spoken warning; bridge watchdog speaks when Lua never starts)
- [x] Logs: speech.log, bridge.log, SE runtime log
- [x] Config file (config.json, defaults merged, bad values logged)
- [x] Install/uninstall scripts (install/, tools/package.py; verified on the real game, fresh profile)
- [x] Playtest harness (tools/game.py: launch/stop/shot/press/click/lua/logs)
- [x] Game key bindings dumped; mod key plan (Ctrl+letter layer)
- [x] Controller-UI spike (gate 5.4): decided without it (see CLAUDE.md "Decisions")
- [x] Movement spike (gate 8.1): verified clicks on the ground with the engine's routes (Travel)

## M1 Every text the game shows
- [x] Dialogue lines with speaker, options, answering by keyboard (tags, dice, history buffer todo)
- [x] Tutorial popups
- [x] Dialogue option tags (class, roll), dice roll screen (plain check), combat log, review buffers (History)
- [x] Books, notes and letters (paragraph list)
- [x] Dice roll bonuses (Guidance: add, spoken total with the bonus die)
- [x] "Wants to talk" (the "!" over companions and others): announced, and in Nearby
- [x] Loading screen hints (read as they rotate)
- [x] Barks: all / the party's only / none (mod menu); dialogue lines spoken as they are said
- [x] Examine window read (items: name, short line, description, value, weight)
- [x] Examine a character: "Acciones: <name>" in Nearby, then "Examinar" (the game's world context
  menu): name, class and subclass, level, race, background, hit points, armour class, abilities,
  traits, approval, resistances, statuses (Gale, Chock the ogre); the character panel's sheet
  reads the same way
- [x] Quest reward window (RewardPanel: it waits for Accept): quest, what was done, who receives
  what, items to choose, Accept (verified: "Recompensa: Salva a Arabella ... Colgante de Komira")
- [x] "Mensajes en pantalla" (mod menu): every short-lived text on screen now: the cursor's lines,
  the hotbar's "cannot act" line, the banner, side tutorials; the hotbar's "No se puede
  controlar: ..." is also said when it appears
- [ ] Other notifications; inspiration reroll with a point (offered only then)

## M2 Menus
- [x] First-run: EULA, explicit content, gamma, splash (readable + operable by keyboard)
- [x] Main menu (buttons; New Game, Options)
- [x] Difficulty selection (announce preset)
- [x] Options: every tab and row type (key rebinding still todo)
- [x] Message boxes (quit confirmation)
- [x] Save a new game (game menu); load (mod menu and game menu)
- [x] Overwrite a save (the character's saves as a list)
- [x] Save description (typed)
- [x] Credits (2403 lines: headings with their names); the mod manager's first page (mod.io's
  terms: read, Close by a verified click; accepting is left to the player); back to the main menu
  (confirmation), the game over box
- [ ] Other confirmations, errors, the mod manager past its terms, profile select (Pause: the
  keyboard UI shows nothing and SE's game state stays "Running": nothing to read, 2026-09-24)

## M3 Character creation
- [x] Origin, race, subrace, class, background choices with descriptions; point buy; racial bonuses; class skills; summary; random; finish
- [x] Spells and cantrips (wizard, high elf cantrip: verified clicks)
- [x] Name (typed in the mod's text entry, set in the game's box: "Mira" reached the game)
- [ ] Feats, multiclass, appearance presets, voice, guardian (the guardian step did not come up
  after "Aventurarse" in this build: straight to the intro video)
## M4 Exploration
- [x] Nearby list (game highlight + doors with state), travel by verified clicks along engine routes, doors on the way, camera turning
- [x] Map markers / objectives list and travel there
- [x] Ladders on routes (click the ladder); Move command (place cursor walk)
- [x] Engine routes checked (2026-09-24): no pathfinding of our own is needed; targets snapped to
  walkable ground, a shut door on the way is named, clicks on ledges refused, Stop walking
- [x] Places: the named sub-areas the party has entered (the game's names, remembered in the save),
  walk there
- [x] Traps: named as traps, left out while invisible (undetected), Enter never walks onto one
- [ ] Traps: verify detection makes them visible; routes that avoid them
- [x] Signposts: a verified click reads them (the character says the directions)
- [ ] Signposts as destinations: built (a sign used from a list: the reader's next line is kept
  with the save, Server/Signposts; mod menu "Señales que has leído"); not yet heard: the Blighted
  Village sign hangs behind a pillar and its click did nothing
- [x] Stealth: "Quién te ve" (mod menu) and, while sneaking, who comes to notice the character,
  "Nadie te ve", and who sees it when sneaking ends (server Osiris CanSee: false for a hidden
  character); being spotted heard (goblins on the Blighted Village path)
- [x] The player's own marks (a blind player's custom map markers): "Marcar este lugar" names the
  spot after the area and the nearest thing, "Tus marcas" walks back (Enter) or removes (Delete);
  kept with the save (Server/Marks); arriving at a point is said
- [x] Nearby says "enemigo" / "aliado" for characters out of combat (server relation; enemy not
  yet heard)
- [x] The farther list holds everything Nearby leaves out (close things far above or below, doors
  20-40 m away were in neither list)
- [x] Routes stop before dangerous surfaces (fire, lava, electrified water, poison clouds...)
- [x] Detours: a step aside (safe route, nearest the target) when a surface blocks; a hopeless
  case ends naming the surface
- [x] Ways round dangerous surfaces planned on the AI grid (Game/SafeRoute), verified 105 m round
  a fire patch that closed a gully
- [x] Things' context menus in Nearby and Markers ("Acciones: <cosa>", mod menu): a verified
  right click opens the game's own menu as a list (pick up, dig, throw, examine...); digging with
  the shovel verified (a chest came up); too close to aim at: a step back, then a camera turn
- [x] Explore says the ground in each direction (tile materials: grass, gravel, sand, deep water...)
- [x] Markers no route reaches: walk to the nearest reachable point (verified: goblin camp)
- [ ] More destinations without seeing the map: people of the area beyond the loaded range (the
  server knows all 911 characters of the level), the map itself described; then retest a walk to
  a place no list offered (the grove gate from the chapel needed a dev-console point once)
- [x] Where am I: area, ground, camera facing, open directions, people nearby; item details in lists
- [x] Party follow check: 4 s after a walk, party members more than 20 m away are named (verified
  with the party unchained by the game's G key)
- [x] Party chain changes spoken: the game's G key splits everyone ("Tav, por su cuenta. ...") or
  joins them ("Grupo unido") (CurrentPlayer.PartyGroups)
- [x] World cursor: the Move command's cursor (arrows, Shift for 5 m) reads the place and the
  game's preview; outside combat Enter walks there (Travel), in combat it is the previewed click
- [ ] Jumps on routes (research 2026-09-25: routes can be planned from any point by setting the
  path's SourceAdjusted, so a jump search is possible; Auntie Ethel's teahouse was not reachable
  from the Blighted Village side and the gap was not a jump)
- [x] Ladders down a cliff (the character's body on the top: step back, then the tactical camera)
- [x] A shut door on the only way is walked up to and tried (a key in the pack opens it)
## M5 Combat
- [x] Combat start, whose turn with resources, turn order list, status key
- [x] Actions list; targeting with preview; confirm by game command (melee verified)
- [x] Combat log narrated
- [x] Place cursor / area placement with area estimate, shouts, items (potions, scrolls), movement, statuses, end-turn confirm, party switch
- [x] Reactions prompt (use / don't react), log coalescing per actor (grouped mode), off-screen targets
- [x] Upcast: Left/Right in the actions list choose the slot level (armed at level 2, verified)
- [x] Spell preparation (spellbook: Gale's new level 2 spells prepared, then on the hotbar)
- [x] Reaction settings list (per character: always / ask / never, with descriptions)
- [ ] Aiming in tight interiors: in the dark worg pens every target out of combat refused the
  cursor and the camera turn hit a pillar; the game's tactical camera (O) fixed it by hand. Built:
  targeting switches it on as its last try (Camera.SetTactical, pitch -82 vs -52..-56) and back
  when targeting ends; not yet exercised by the mod itself
- [x] Targeting reopens when a game screen (a quick save) closed it with the action still armed
- [x] Grouping beyond one phrase: several lines about one character said once, the shared start
  once ("Tav: ha recogido 1 Olla, 1 Provisiones, 3 Oro"; at least two shared words, else listed
  whole); an area's banner is not said twice ("Aldea marchita" + "Zona: Aldea marchita")
- [x] Downed / death saves / game over (worg pens fight); upcast spells cast in a fight (Guiding
  Bolt, Magic Missile with four darts, Healing Word)
- [x] Throw: step 1 lists only what the character can lift (movable, not too heavy), step 2
  where it goes (creatures, things, a place); a fork, a pot and a chair thrown; "Lanzar" from an
  item's actions and the game's own keys (X, number keys) are followed by the mod's targeting
- [x] The cursor never rests on an enemy after targeting (parked on the minimap): the game's
  hover preview of the main-hand attack ("No tienes suficientes recursos: Acción") no longer
  sticks nor passes for an armed action; the preview's "[1]" reads filled; combat start/end not
  said around the game menu
- [x] The worg pens fight (8 enemies, allied bear) won by keyboard; failed confirms say the
  game's reason; slow aims say the camera is turning; damage to things named right
- [ ] Opportunity-attack warning before walking to a thing in combat (built, not yet heard);
  faster aiming at targets on ledges
## M6 Inventory and progression
- [x] Character panel: inventory (use/equip), equipment, sheet
- [x] Level up: features, HP, resources, subclass list, spell choices (verified grid clicks), Accept
- [x] Trading: quick trade (buy/sell lists with prices, gold after each exchange)
- [x] Level up: passive choices (Wildheart hearts; the same selectors hold fighting styles,
  maneuvers, metamagic), spell slot lines, letter jumps in long lists, waiting out the intro
- [ ] Level up: feats, ability improvements, spell replacement, prepare tab; barter mode
- [x] Loot: Enter takes one item (TakeItemCommand.ActionCommand(item)), Space takes all
- [x] Item actions in the character panel: the game's own context menu (send to camp, to a
  companion, drop, split, examine...) as a sub-list from the mod menu (verified: bucket to Gale);
  what was done is said ("Hecho: Enviar a: Gale")
- [x] Weapon and armour details (Ctrl+D): damage dice and type, versatile die, properties,
  weapon class, proficiency of the character, weapon actions, armour class, enchantment, weight
  (inventory, equipment, loot, trade)
- [x] The character panel names its character and follows [ ] / F1-F4 to another party member
- [x] Equip from the floor (Acciones > Equipar), a disarmed weapon taken back in combat
- [ ] Equipping in combat confirmed first (spends the action): built, not yet heard
- [ ] Learning a scroll (Gale: "Aprender conjuro", needs 50 gold): read, not done
## M7 Blindfold playthrough, act by act
## M8 Polish (verbosity, cues, localization of mod strings, co-op decision)
- [x] Game language detected (GlobalSwitches.Language), Spanish table (all keys), strings checker
- [x] Tutorials that speak of the mouse get the keyboard way after them (end turn, equipment,
  hotbar; keyed by TutorialName from the static data TutorialUnifiedEntry)
- [x] Other languages: Strings/<code>.lua for the game's 15 languages (es-419 uses es), written by
  translation agents from English and es.lua, checked by tools/check_strings.py and compiled in
  the game's Lua; French heard in game. Game terms not yet compared with each language's own loca.
- [ ] Hints for the other mouse tutorials (summons, allies' button, photo mode)
Localization: Core/Strings (phrases, List, Sentences, Number, CLDR plural forms for the game's 15
languages, key names as strings), the game language detected, every language's table present
with English as the fallback. New strings need adding to every Strings/<code>.lua (the checker
lists what a language lacks).
## M9 Release (README, installer, package)
- [x] Package and player README (dist/, install/README.md); Nexus page text, generated key list: todo
