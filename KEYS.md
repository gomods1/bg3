# KEYS

Every keyboard shortcut a blind player uses with BG3 Access: the mod's own keys and the game's
own keys, each marked **confirmed** (pressed in the running game with the mod, result checked in
the speech log or on screen; where and when is noted) or **untested** (a default binding or a mod
key that exists but was not exercised). Game 4.1.1.7398727, SE v32, keyboard/mouse UI, Spanish
game, 2026-09-24. Keep this file current whenever a key is added, changed or verified; the README
key list (M9) is generated from it.

Mod keys are rebindable in `%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Script Extender\BG3Access\config.json`
(section `keys`). Scancode names follow SDL ("CTRL+R", "SHIFT+TAB").

## 1. Mod keys, everywhere

One key opens the mod menu; everything the mod can do is in it, filtered to what is available right
now (design rule: new features go in the menu, not on new keys). Only the keys that act on the
focused item are direct.

| Key | Action | Status |
|---|---|---|
| Ctrl+M | Mod menu: the commands available here (Up/Down, Enter runs, Escape closes) | confirmed (in combat; over the Actions list) |
| Ctrl+R | Read the whole screen / list (in dialogue: last line and the options) | confirmed (EULA, main menu, options, difficulty, character creation, loot, dialogue, lists) |
| Ctrl+D | Details of the current item (option description, choice description, item description; in Nearby lists the item's value, rarity and the game's description) | confirmed (options rows, character creation choices, loot items, a mushroom in Nearby) |

Menu commands (in menu order; each can get a direct key in config.json, `keys.<id>`, default none):

| Command (id) | Shown when | Status |
|---|---|---|
| Actions and attacks (`actions`): the hotbar, items included (count left); Enter arms one, a potion is drunk at once | in game (HUD) | confirmed (Tav, Lae'zel; through the menu: Jump, Cleave, Fire Bolt, main-hand attack, healing potion, scroll of revivify armed) |
| Move (`move`): the place cursor with nothing armed; Enter walks there (in combat the game's preview says the meters it costs) | in game, nothing armed | confirmed (Lae'zel in combat: "uses 4 meters of movement, 1 left", walked 4.4 m) |
| Turn order (`turnOrder`): HP, relation, distance, who is acting | in combat | confirmed in the menu list; list itself confirmed with the old key |
| Party members (`party`): the party in the order of the game's F1-F4 ("1: Tav, controlado, 32 de 32 puntos de golpe", "2: Gale, 20 de 20..., 2 metros, detrás, Voracidad arcana"), "acting now" in combat; Enter takes control of that character (the portrait's own command), Ctrl+D reads the full status line | in game (HUD) | confirmed (Blighted Village, session 8: three members listed in F-key order, Enter on Corazón Sombrío -> "Ahora Corazón Sombrío" 0.2 s later; in combat untested) |
| Reactions settings (`reactions`): each party member's reactions, always / ask / never (the game's L panel); Left/Right or Enter change, Ctrl+D describes | in game (HUD) | confirmed (Tav's attack of opportunity: ask -> never -> always -> ask) |
| Spell book (`spellbook`): the selected character's class spells by level with the game's titles and their state (prepared, not prepared, always prepared); Enter prepares / unprepares, Ctrl+D describes | in game, the character has a class spell book | confirmed (Gale: Magic Missile and Shield prepared, Witch Bolt unprepared; "All 5 spells to prepare are chosen: unprepare one first") |
| Character status (`status`): HP, action, bonus action, reaction, class resources, movement | a character is selected | confirmed with the old key (Tav, Lae'zel) |
| Nearby things (`nearby`): the game's highlights, doors with state, and every other usable thing and character within 25 m, with distance and direction; Enter goes there and uses it (in combat: an object within 3 m is used with a click, anything else opens the Move cursor toward it) | in game (HUD) | confirmed (nautiloid; the transponder used in combat) |
| Map markers and objectives (`markers`); Enter walks there (in combat: the Move cursor toward it, see below) | in game (HUD) | confirmed (nautiloid "Ruta de escape", "Puente de mando", "Transpondedor" in combat) |
| Short rest (`shortRest`): the game's short rest for the party | in game, out of combat, a short rest left | confirmed (chapel: the party healed 11, 8, 7) |
| Long rest (`longRest`): the game's long rest: its questions (message boxes), camp, then the supplies screen (see below) | in game, out of combat | confirmed (camp: 40 supplies used, the night scene, everyone at full health) |
| Waypoints (`waypoints`): the discovered waypoints (in camp: "Abandonar el campamento"); Enter travels there (the game's GoToWaypoint) | in game, out of combat | confirmed (left camp for the chapel entrance through the game's command; the list itself read outside camp) |
| Places (`places`): the named places of this area the party has been to (the game's own names, as announced on entering), nearest first, "you are here" for the current one; Enter walks there | in game, out of combat | confirmed (grove: El Hueco <-> Estanque sagrado both ways; kept through quick save and load) |
| Stop walking (`stopWalking`): ends the walk in progress (Travel) at its next step; first in the menu while a walk is under way | a mod walk is under way | confirmed (grove, walking to Arron: "Stopped") |
| Explore (`explore`): the eight compass directions (north = up on the world map), each with how far the character can walk that way and what the ground is like ("arena y agua profunda"); Enter walks there and names what came into range | in game, out of combat | built; walking tested from the chapel (see PLAYTEST) |
| Load a saved game (`loadGame`): the game's load screen, read by the mod: saves newest first with place, date and play time; Enter loads | in game | confirmed (QuickSave_8 loaded) |
| Where am I (`whereAmI`): the area's name, the ground underfoot, which way the camera faces, the directions one can walk (15 m, else 6 m) and the people within 20 m | in game (HUD) | confirmed (the sanctum) |
| Farther things (`farther`): usable things, doors and characters 40 to 150 m away (the game loads about that far), same keys as Nearby | in game (HUD) | confirmed (beach: Gale's bag 96 m, travelled there) |
| Level up (`levelUp`): opens the level up of the selected character, or of the first one waiting | a party member can level up | confirmed (Shadowheart; Tav's was opened by the game's command during testing) |
| Journal (`journal`): categories, quests, objectives; Enter on an objective reads the story so far | in game (HUD) | confirmed ("Misión principal", "Encuentra una cura") |
| Read the screen (`readScreen`), also Ctrl+R | always | confirmed through the menu (read the Actions list underneath) |
| Details of the current item (`details`), also Ctrl+D | always | confirmed with the key |
| Help (`help`): the screen's keys, then the direct keys | always | confirmed through the menu (in combat) |
| History (`history`): review buffers Events, Combat log, Dialogue, newest first | always | confirmed (combat log and events after a fight) |
| Repeat the last line (`repeat`): the line before the menu opened | always | confirmed through the menu (in combat) |
| Stop speech (`stopSpeech`) | always | untested (NVDA: Ctrl alone stops speech anyway) |
| Find the screen reader again (`resetSpeech`) | always | confirmed with the old key ("Speech restarted") |

"Confirmed with the old key": verified in session 2 when every command had its own Ctrl+letter
(config v1: Ctrl+H, E, G, S, T, A, L, Shift+S, Shift+R); the command code is the same, now reached
through the menu. config.json v1 files are migrated: the old default letters are removed, letters
the player set are kept.

The game binds Ctrl only on C, V, X, Y, Z (text editing), so the mod uses Ctrl + other letters.
Do not bind Insert or Caps Lock (NVDA modifiers).

Mod menu command added in session 7: "Mensajes en pantalla" (what the game shows on screen right
now outside windows: the cursor's lines, "No se puede controlar: ...", the banner, side tutorials;
none of them needs dismissing). The quest reward window is a list: Enter on Aceptar takes the
reward (it waits until then).

## 2. Mod keys inside screens and lists

These are claimed only while the screen or list is in front; elsewhere they stay the game's.

| Key | Where | Action | Status |
|---|---|---|---|
| Tab / Shift+Tab | every list with sections (NAVIGATION.md, since 2026-09-29): History (events, combat log, dialogue), Nearby and Farther (everything, then each kind), the mod menu (its groups), Actions (the hotbars), Spell book (the spell levels), loot from several containers | the next / previous section, "name, N items" said first; a list with one section leaves Tab to the game | offline tests (tests/lua/sections_test.lua); in game untested |
| Up / Down | every list screen (menus, options, message boxes, character creation, loot, mod lists) | previous / next item, inside the section (no wrap) | confirmed (inside a section: untested) |
| Home / End | list screens | first / last item | confirmed |
| Enter, Space, Numpad Enter | list screens | activate (button, choice, open section) | confirmed (Enter, Space); Numpad Enter untested |
| Left / Right | option rows, tick boxes, sliders, character creation abilities and racial bonuses | change the value | confirmed |
| Left / Right | every list, on an item without a value | previous / next item, like Up / Down (since 2026-09-29; before, the key went to the game). Difficulty keeps the game's own Left / Right | untested |
| Shift+Left / Shift+Right | sliders | small step | untested |
| Tab / Shift+Tab | options | next / previous tab | confirmed (every tab) |
| Up / Down, Left / Right | message boxes | move between buttons; Tab / Shift+Tab say the button again (one section) | confirmed (Left/Right, before 2026-09-29); Tab untested |
| Escape / Backspace | a sub-list (character creation section) | back to the parent list | confirmed (Escape) |
| Escape | Nearby, Map markers, Turn order, Actions lists | close the list | confirmed |
| Up / Down | dialogue, when the options are up | read the options | confirmed |
| Enter | dialogue options | answer (presses the game's own key for that answer) | confirmed |
| Up / Down | targeting | choose a target; the game's preview is read (hit %, damage, walk, attack of opportunity) | confirmed |
| Enter | targeting | use the armed action on the target (game command; a verified click when the game must walk first, for objects and several-target spells; refused with the game's reason when not possible); for several-target spells each Enter adds one target, the list stays open, and "Cast now" casts with fewer | confirmed (melee attacks; Fire Bolt with a walk; Help; Healing Word on oneself; Magic Missile's three darts) |
| Escape | targeting | cancel the armed action (the game's cancel) | untested |
| Enter | targeting, last item "A place on the ground" (Projectile and Throw actions) | open the place cursor | confirmed (Fire Bolt) |
| Arrows | place cursor (Jump, area actions, a place for Fire Bolt) | move the place 1 m relative to the camera (Up = away from the camera); the offset and the game's preview are read | confirmed (Up, Right) |
| Shift+arrows | place cursor | move 5 m | confirmed (Shift+Up) |
| Home | place cursor | back to the character | untested |
| Ctrl+M on the dice roll screen | dice roll | "Add Guía from Corazón Sombrío, 1d4" (each bonus the party can add; a verified click on it), "Take back Guía", "Roll again" (inspiration, when the game offers it) | confirmed for adding Guidance (Kagha's Intimidation check: "Guía added. Bonus plus 3 to plus 6", then "Rolled 18. Guía: 4. Total 24. Success") |
| Left / Right | actions list, on a spell with several levels | the spell slot level to cast it with ("nivel 2, quedan 2 espacios"); Enter arms that level's variant | confirmed (Gale's Proyectil mágico at level 2: armed, targeting opened, cancelled) |
| (mod menu) "Comentarios: de todos / solo del grupo / ninguno" | anywhere | switches which barks are spoken (config speech.barks; the events history keeps them all); bindable as keys.barks | confirmed (switched to "solo del grupo", saved in config.json) |
| G (the game's) | in game | group mode: splits the whole party or chains it again; the mod says the new groups ("Grupo unido", "Tav, por su cuenta. ...") | confirmed |
| Ctrl+M on an inventory item | character panel, inventory list | "Acciones: <item>": the game's context menu for that item as a list (drop, throw, add to hotbar, send to camp, send to a companion, examine...); Enter chooses; Escape closes it | confirmed (bucket sent to Gale) |
| (mod menu) "Quién te ve" | in game | who notices the controlled character now ("Te ven: Guerrero goblin, Goblin Ojo Avizor"; hidden: "Nadie te ve"); while sneaking (the game's C) the same is said by itself as it changes | confirmed |
| (mod menu) "Marcar este lugar" | in game | keeps where the character stands, named after the area and the nearest thing ("Marcado: Bosque, junto a Señal") | confirmed |
| (mod menu) "Tus marcas" | in game, out of combat | the marks of this area, nearest first; Enter walks there ("Llegada: ..."), Delete removes one | confirmed (walked back 7 m; removed) |
| (mod menu) "Señales que has leído" | in game, out of combat | the signs read in this area, named by what they said, nearest first; Enter walks there and reads again | untested (no sign read since it was built) |
| Ctrl+M on a Nearby or Markers entry | Nearby, Markers | "Acciones: <thing>": walks there when farther than 6 m, then the game's context menu for it (a verified right click) as a list: pick up, "Usar (Tav)" on a dirt mound (digs with a shovel in the inventory), throw, examine (items and characters: the Examine window is then read as a list)... | confirmed (shovel picked up; mound dug; Gale and an ogre examined) |
| Enter / Space | loot window | Enter takes the item under focus; Space (the game's) takes everything | confirmed (Blighted Village chest and barrel) |
| A letter | mod menu, mod lists (Nearby, Places...), sub-lists (spell choices, subclasses, hearts...) | jump to the next item starting with that letter (accents ignored; wraps; "Nada empieza por Q"); not on screens mirroring the game's own, where letters stay the game's | confirmed (Gale's 40 spells: R, P; mod menu: C, S) |
| Letters, digits, Space, Backspace, Enter, Escape | typing a text (character creation: Nombre) | letters and digits are said as typed (Shift: capital, first letter capital), Backspace deletes ("x borrado"), Up/Down read the text, Enter confirms, Escape cancels; no accents or ñ yet | confirmed ("Mira") |
| Up / Down, Ctrl+R, Escape | book, note or letter | the title, then one line per paragraph (the game's whole text, not its pages); Ctrl+R reads everything; Escape (the game's) closes | confirmed ("Aventuras ilustradas de Balduran", El Hueco, 15 paragraphs) |
| Up / Down, Enter, Escape | save screen (game menu: Guardar partida) | "Nueva partida guardada" (then the popup's Guardar), then this character's saves newest first: Enter overwrites (the game asks Sí/No) | confirmed (new save and overwrite, new game "Mira") |
| Up / Down, Enter, Escape, Ctrl+D | trade screen | your gold and the trader's; "Buy from Arron, 53 items" and one "Sell <name>'s items" list per party member; Enter on an item buys or sells it at once (the game's quick trade), "Bought ..., 4 gold left"; too expensive is refused with the prices; Ctrl+D describes; "Vender mercancía" when wares are marked; Escape back / closes | confirmed (Arron: sold a hat, bought a mushroom, refusal) |
| Up / Down, Enter | world map (M) | where am I, markers (compass direction, distance; Enter closes the map and walks there), waypoints (Enter travels) | confirmed (lists; walked from the grove entrance to "Salva a los refugiados"; a shut gate is named: "Verja levadiza reparada is closed on the way") |
| Enter | place cursor | use the action there, only when the game's preview says possible | confirmed (Jump, Fire Bolt) |
| Escape | place cursor | cancel the armed action (the game's cancel) | confirmed ("Cancelled", Cleave) |
| Up / Down, Enter | level up, a spell choice ("Conjuros, 0 of 2 chosen") | Enter opens the spell list; there Enter chooses or takes back a spell (verified click on the game's button), Ctrl+D describes it, Escape comes back | confirmed (Gale: Burning Hands, Longstrider, Magic Missile, Shield) |
| Up / Down, Enter | reaction prompt | a reaction (Enter uses it) or "No reaccionar" | confirmed (Reckless Attack used; not reacting) |
| Up / Down, Enter, Escape | mod menu | choose, run, close | confirmed |
| Space | in game, combat, the party's turn, an action or bonus action left | first press says what is left ("Still left: Acción adicional. Space again ends the turn."), a second press within 8 s ends the turn (the game's key). Off with config `combat.confirmEndTurn` | confirmed (Tav, Lae'zel) |
| Ctrl+R | in game (HUD only) | the controlled character's status | untested |
| Tab / Shift+Tab | Nearby, Farther | the sections: everything (nearest first), then one kind at a time (characters, containers, things to pick up, doors, traps, other); replaced Left / Right 2026-09-29 | untested |
| Enter | character panel (the game's I): Inventory / Equipment / Character sheet sections | open the section | confirmed |
| Enter | character panel, an inventory item | use it as a double click does (equip, drink...) | confirmed (hat equipped) |
| Enter | character panel, an equipment slot | unequip | confirmed (hat) |
| Ctrl+D | character panel items and slots | the item's description | untested |
| Enter | level up, "Aceptar" | finish (a verified click on the game's button; unavailable while choices remain) | confirmed (Tav, Shadowheart) |
| Ctrl+D | level up, a feature | its description | untested |
| Escape | level up | the game's: close without levelling | confirmed |
| Up / Down | History | read the lines, newest first | confirmed |
| Tab / Shift+Tab | History | switch buffer (empty ones left out); replaced Left / Right 2026-09-29 | confirmed 2026-09-29 at the main menu, keys sent through the router from the dev channel ("Historial. Sucesos, 3 elementos...", Tab: "Registro de combate, 1 elemento", wraps; Down stops at the section end) |
| Escape | History | close | confirmed |
| Ctrl+D | dialogue options | what the answer's tags mean (the game's tooltip, e.g. the class tag) | confirmed (Bárbaro tag) |
| Enter, Space, Numpad Enter | dice roll screen (skill checks) | roll, then after the result go on (the game's command for its Enter binding: a real Enter did nothing there) | confirmed (Strength check) |

Space is never taken in dialogue (skip line), targeting or the actions list (end turn): it stays
the game's. On the HUD in combat it is taken once for the end-turn confirmation (above).

## 3. Game keys that work with the mod (the game's own bindings)

Confirmed means pressed with the mod running and the effect checked.

| Key | Game action | Status |
|---|---|---|
| Any key | Splash screen "press any key" | confirmed |
| Left / Right | Difficulty preset (the mod announces each) | confirmed |
| Escape | Close options (Back), skip videos, finish tutorial popups, close loot, cancel | confirmed (options, videos, tutorial, loot, map) |
| 1 to 9, 0 (number row) | Choose a dialogue answer directly | confirmed (answer 3) |
| Space | End turn in combat | confirmed |
| F1 to F4 | Select party member 1 to 4 (the mod says who, with the status in combat). Since session 8 the switch is said at once after the player's own key (before: after a 0.8 s quiet wait that tells it from the game's own switch at the start of the party's turn) | confirmed (F2 -> Lae'zel, F1 -> Tav; session 8: F2 -> "Ahora Gale" within the key press, F1 -> "Ahora Tav" 0.3 s later) |
| F5 | Quick save | confirmed |
| F8 | Quick load | confirmed |
| M | Map | confirmed (opens; the map screen itself is not made accessible yet) |
| I | Inventory (character panel; the mod reads it as sections) | confirmed |
| Q / E | Rotate the camera (the mod also uses them to turn the camera for travel and targeting) | confirmed (injected) |
| Left Alt | Show world highlights (the mod uses it for the Nearby list) | confirmed (injected) |
| [ ] | Previous / next character; with the character panel open it switches to that character's inventory, equipment and sheet ("Personaje: Gale. Inventario. 6 botones.") | confirmed (session 7) |
| Space (combat, twice within 8 s) | End turn when an action or bonus action is left (the mod says what is left first); the party ends one character at a time | confirmed |
| Escape (reaction popup) | The mod: "No reaccionar" (the game's Escape there opened the game menu) | built, not yet pressed in play (session 7) |
| Escape (combat, nothing armed) | Opens the game menu. The "No tienes suficientes recursos" cursor label is not a dialog: the mod clears it by moving the cursor off the enemy | confirmed (session 7) |

## 4. Game keys not yet confirmed with the mod

Default bindings (dumped from the game; CLAUDE.md "Game key bindings"). Expected to work because
the mod does not claim them outside its own screens, but not exercised yet:

| Keys | Game action |
|---|---|
| Space (outside combat) | skip dialogue line, take all (loot) |
| Shift+Space | enter / leave turn-based mode, flee |
| Tab | party / character view |
| I, J, K, N, H, B, L | inventory, journal, spells, character, alchemy, tadpole powers, reactions |
| C, Shift+C, G | sneak, group stealth, group mode |
| Z, X, V, F, R | jump, throw, shove, switch weapon set, dual wielding (an action the game arms by its own key, X or a hotbar number included, is followed by the mod's targeting list after 0.7 s: X lists what can be thrown, then where; confirmed for X and V "Objetivo para Empujar"; the hotbar numbers had no slots bound in this save) |
| Y, U, P, T, O | short rest, combat mode, inspiration, pin tooltip, tactical camera |
| W A S D, arrows, Home, PgUp/PgDn | camera move, center, zoom (arrows are claimed by mod lists only while a list is open) |
| F9, F10 | photo mode, presentation |
| Backtick, Pause | highlight characters, pause |
| Numpad 0 to 9, - = | hotbar slots |

## 5. Keys the mod uses internally (injected, not for the player)

ESCAPE (Back in options, cancel targeting and the place cursor), the mouse X1 side button (pressed
before every mod click: the game swallows the first mouse press after keyboard input; X1 is bound
to nothing), the key bound to an answer's event (UISelectSlotN ->
number keys), UIAccept (Enter) for buttons bound to it, LALT (hide highlights), Q/E (camera),
F5/F8 only in the test harness.
