-- The mod's own spoken strings, in one keyed table (template_rpg 20). Game text never goes here: it
-- comes from the game's localization in the game's language.
-- Rules that keep every string translatable into the game's languages (en, fr, de, it, es, es-419,
-- pl, ru, uk, tr, pt-BR, zh-Hans, zh-Hant, ja, ko):
--   * whole phrases with named placeholders ("{name}"), so a translation can reorder them; never
--     build a sentence from fragments in code;
--   * lists through Strings.List (the separator is a string: "、" in Japanese), numbers through
--     Strings.Number (decimal separator), counts through a numeric {n}: Strings.Get picks the plural form ("key_one",
--     "key_few", "key_many"; the plain key is the "other" form);
--   * no case changes in code (labels are written as they are spoken).
-- A language table added later (M8) only needs the keys it translates; missing keys fall back to
-- English.
local Log = Ext.Require("Core/Log.lua")

local Strings = {}

local EN = {
    -- Startup and build gate
    -- Formatting (per language)
    list_separator = ", ",
    sentence_end = ".",
    sentence_separator = " ",
    label_value = "{label}: {value}",
    decimal_separator = ".",

    loaded = "BG3 Access loaded. {key} opens the mod menu.",
    speech_reset = "Speech restarted",
    untested_version = "BG3 Access: untested game or Script Extender version, some features may not work",
    bridge_missing = "BG3 Access native bridge did not answer. Speech will not work. Check bin\\version.dll and bin\\BG3Access (install self-test).",

    -- Generic screen reading
    screen_summary = "{title}. {count} items: {parts}.",
    screen_summary_one_kind = "{title}. {what}.",
    count_items = "{n} items",
    count_items_one = "{n} item",
    count_buttons = "{n} buttons",
    count_buttons_one = "{n} button",
    count_options = "{n} options",
    count_options_one = "{n} option",
    screen_empty = "{title}, nothing to read",
    no_screen = "No screen",
    nothing_selected = "Nothing selected",
    no_item_with_letter = "Nothing starts with {letter}",
    position = "{i} of {n}",
    unavailable = "unavailable",
    target_blind_confirm = "{name}: cannot be aimed at. Enter again uses the game's own order, which may walk the character there first.",
    unavailable_combat_only = "only in combat",
    unavailable_outside_combat = "not during combat",
    unavailable_missing = "missing: {names}",
    unavailable_needs_rage = "only while raging",
    unavailable_needs_status = "needs {name}",
    could_not_activate = "{label}: could not activate, {reason}",

    -- Roles and values
    role_button = "button",
    role_list = "list",
    role_checkbox = "check box",
    role_slider = "slider",
    role_edit = "edit",
    role_tab = "tab",
    checked = "checked",
    not_checked = "not checked",
    selected = "selected",
    option_gone = "option gone",
    no_details = "No details",
    not_bound = "not bound",
    cannot_change = "cannot change this",

    -- Activation failures (Game/Activate)
    reason_gone = "it is gone",
    reason_unavailable = "unavailable",
    reason_no_position = "no click position known",
    reason_no_cursor = "the cursor could not reach it",
    reason_offscreen = "it is not on screen",
    reason_no_path = "no way there was found",
    reason_portal = "the way needs a jump or a climb",
    reason_door_closed = "{door} is closed on the way",
    reason_surface = "{surface} on the way",
    surface_dangerous = "a dangerous surface",
    surface_Fire = "fire", surface_HolyFire = "holy fire", surface_Hellfire = "hellfire", surface_Lava = "lava",
    surface_WaterElectrified = "electrified water", surface_BloodElectrified = "electrified blood",
    surface_WaterCloudElectrified = "electrified steam", surface_PoisonCloud = "a poison cloud",
    surface_CloudkillCloud = "a cloudkill cloud", surface_StinkingCloud = "a stinking cloud",
    surface_CausticBrine = "caustic brine", surface_SpikeGrowth = "spike growth", surface_Vines = "vines",
    surface_WyvernPoison = "wyvern poison", surface_SerpentVenom = "serpent venom",
    reason_blocked = "something blocks the way",
    reason_on_object = "someone or something stands in the way",
    reason_interrupted = "interrupted",
    reason_combat = "a fight started",

    -- Screens
    screen_loading = "Loading",
    screen_video = "Video. Escape skips it.",
    screen_saving = "Saving",
    screen_main_menu = "Main menu",
    screen_difficulty = "Choose difficulty",
    screen_options_tab = "Options, {tab}",
    honour_warning = "Honour mode: one save, deleted if the party dies",
    message_buttons = "Buttons: {labels}",
    choose_button_first = "Choose a button with the arrows first",
    screen_character_creation = "Character creation",
    screen_container = "Container",
    screen_nearby = "Nearby",
    screen_farther = "Farther",
    category_character = "characters",
    category_container = "containers",
    category_loot = "things to pick up",
    category_door = "doors",
    category_other = "other things",
    category_trap = "traps",
    kind_trap = "trap",
    state_wants_to_talk = "wants to talk",
    wants_to_talk = "{name} wants to talk",
    trap_keep_away = "{name} is a trap: the mod does not walk onto it",
    nearby_group_more = "and {n} more",
    screen_dialogue = "Dialogue",
    screen_turn_order = "Turn order",
    screen_actions = "Actions",
    screen_menu = "Mod menu",
    screen_targeting = "Target for {action}",
    cost_action = "action",
    cost_bonus = "bonus action",
    cost_reaction = "reaction",
    item_count_only = "{n} left",
    target_self = "you",
    area_catches = "in the area: {names}",
    area_nobody = "nobody in the area",
    name_relation = "{name} ({relation})",
    target_place_item = "A place on the ground",
    screen_place = "Place for {action}. Arrows move, Enter confirms.",
    buffer_events = "Events",
    buffer_combat = "Combat log",
    buffer_dialogue = "Dialogue",
    category_all = "everything",
    screen_history_title = "History",
    section_intro = "{section}, {count}",
    help_sections = "Tab and Shift Tab go from section to section.",
    menu_group_here = "This screen",
    menu_group_urgent = "Right now",
    menu_group_combat = "Combat",
    menu_group_exploration = "Exploration",
    menu_group_screen = "Reading and screens",
    menu_group_speech = "Speech",
    hotbar_common = "Common actions",
    hotbar_class = "Class actions",
    hotbar_items = "Items",
    hotbar_custom = "Custom hotbar",
    spells_of_level = "Level {level} spells",
    screen_move_toward = "Move toward {name}: as far as this turn allows. Arrows adjust, Enter walks there.",
    reason_no_movement = "no movement left",
    reason_choices_full = "every choice is made; take one back first",
    reason_wrong_item = "the click changed something else; check the list",
    reason_no_effect = "the game did not react",
    move_on_object = "{name} is under the cursor: a click would use it. Move the place first.",
    screen_move = "Where to move. Arrows move, Enter walks there.",
    place_here = "on you",
    dir_ahead = "ahead",
    dir_ahead_right = "ahead right",
    dir_right = "right",
    dir_behind_right = "behind right",
    dir_behind = "behind",
    dir_behind_left = "behind left",
    dir_left = "left",
    dir_ahead_left = "ahead left",
    place_ahead = "{n} ahead",
    place_back = "{n} back",
    place_right = "{n} right",
    place_left = "{n} left",
    place_up = "{n} up",
    place_down = "{n} down",
    place_distance = "{n} meters away",
    place_distance_one = "{n} meter away",
    place_on = "on {name}",
    place_on_self = "your character covers this place",
    place_hidden = "the ground there is hidden",
    movement_cost = "uses {n} meters of movement, {left} left",
    movement_cost_one = "uses {n} meter of movement, {left} left",
    place_possible = "possible",
    target_invalid = "not possible",
    hit_chance = "{n} percent to hit",
    advantage = "advantage",
    disadvantage = "disadvantage",
    damage_range = "{min} to {max} damage",
    heal_range = "heals {min} to {max}",
    save_chance = "{n} percent chance, {ability} saving throw",
    save_only = "{ability} saving throw",
    walks_first = "walks {n} meters first, {left} left",
    walks_first_one = "walks {n} meter first, {left} left",
    opportunity_attack = "provokes an attack of opportunity",
    lethal = "lethal",
    cancelled = "Cancelled",
    combat_started = "Combat: {n} enemies",
    combat_started_one = "Combat: {n} enemy",
    combat_ended = "Combat over",
    turn_of = "Turn: {names}",
    turn_now = "acting now",
    timer_turns_left = "{n} turns left",
    timer_turns_left_one = "{n} turn left",
    timer_count = "{what} {n} of {total}",
    end_turn_confirm = "Still left: {left}. Space again ends the turn.",
    now_controlling = "Now {name}",
    not_in_combat = "Not in combat",
    hp = "{value} of {max} hit points",
    hp_none = "no hit points left",
    resource = "{name} {value} of {max}",
    status_line = "{name}, {hp}. {resources}.",
    status_turns = "{name} {n} turns",
    status_turns_one = "{name} {n} turn",
    movement = "movement {value} of {max} meters",
    spell_slots = "level {level} spell slots {value} of {max}",
    cast_level = "level {n}",
    spell_slots_left = "{n} slots left",
    spell_slots_left_one = "{n} slot left",
    help_actions_levels = "On a spell with several levels, Left and Right choose the spell slot level to cast it with.",
    spell_level = "level {n} spell",
    relation_enemy = "enemy",
    relation_party = "party",
    relation_neutral = "neutral",
    relation_ally = "ally",
    dialogue_option = "{n}. {text}",
    dialogue_option_tagged = "{n}. {tags}: {text}",
    tag_roll = "{name} check",
    plus_number = "plus {n}",
    minus_number = "minus {n}",
    bonus_range = "{min} to {max}",
    roll_check = "{skill} check",
    roll_difficulty = "Difficulty {n}",
    roll_bonus = "Your bonus {bonus}",
    roll_need = "The die must show {n} or more",
    roll_need_not_one = "Anything but a 1 succeeds",
    roll_need_twenty = "Only a 20 succeeds",
    roll_need_range = "The die must show {min} to {max} or more, depending on the bonus dice",
    roll_inspiration = "{n} inspiration points",
    roll_inspiration_one = "{n} inspiration point",
    roll_enter = "Enter rolls",
    roll_rolled = "Rolled {n}",
    roll_other_die = "The other die: {n}",
    roll_total = "Total {n}",
    roll_success = "Success",
    roll_failure = "Failure",
    roll_again_hint = "The mod menu can roll again with inspiration",
    roll_again = "Roll again with inspiration",
    roll_continue = "Enter continues",
    help_roll = "Enter rolls the dice, and after the result continues. Control R reads the check or the result again.",
    dialogue_options = "{n} options",
    dialogue_options_one = "{n} option",
    screen_markers = "Map markers",
    marker_QuestMarker = "objective",
    marker_CharacterNeutral = "character",
    marker_CharacterHostile = "enemy",
    marker_CharacterEnemy = "enemy",
    marker_CharacterFriendly = "ally",
    marker_CharacterParty = "party member",
    marker_other = "marker",
    marker_Waypoint = "waypoint",
    marker_Custom = "your marker",
    item_actions = "Actions: {name}",
    reason_menu_not_open = "the menu did not open",
    screen_examine = "Examine",
    resist_resistant = "resistant to {types}",
    resist_immune = "immune to {types}",
    resist_vulnerable = "vulnerable to {types}",
    walking = "Walking",
    arrived = "Arrived",
    arrived_at = "Arrived: {name}",
    entering_area = "Area: {name}",
    you_are_in = "{name}",
    where_ground = "On {ground}",
    where_facing = "Camera facing {dir}",
    where_open = "You can walk {n} meters {dirs}",
    where_closed = "No way to walk {n} meters from here",
    where_people = "Nearby: {names}",
    where_people_more = "Nearby: {names} and {n} more",
    area_unknown = "No area name here",
    meters = "{n} meters",
    meters_one = "{n} meter",
    state_unexplored = "not searched",
    state_empty = "empty",
    state_dead = "dead",
    state_stealing = "stealing",
    kind_door = "door",
    state_open = "open",
    state_closed = "closed",
    state_locked = "locked",
    using_on_the_way = "Opening {name} on the way",
    climbing_down = "Climbing down {name}",
    using_passage = "Going through {name}",
    kind_passage = "passage",
    climbing = "Climbing {name}",
    kind_ladder = "ladder",
    party_chained = "Party together",
    party_group_together = "{names} together",
    party_group_alone = "{name} alone",
    party_far = "Far from you: {list}",
    party_member_at = "{name} {n} meters away",
    action_party = "Party members",
    screen_party = "Party",
    party_entry = "{i}: {name}",
    party_controlled = "controlled",
    party_already = "You already control {name}",
    help_party = "Up and down arrows read the party in the order of the game's F1 to F4 keys. Enter takes control of a character, Control D reads their full status.",
    going_to = "Going to {name}",
    searching_nearest = "No way goes all the way there; looking for the nearest point",
    walking_nearest = "Walking to the nearest point, {n} meters from it",
    walking_nearest_one = "Walking to the nearest point, {n} meter from it",
    arrived_near = "As close as the ways go: {name} is {n} meters away",
    arrived_near_one = "As close as the ways go: {name} is {n} meter away",
    using = "Using {name}",
    closed = "Closed",
    not_available_here = "Not available here",
    container_empty = "Empty",
    item_count = "{name}, {count}",
    item_value = "value {gold}",
    item_weight = "{kg} kg",
    item_stolen = "stolen",
    item_equipped = "equipped",
    item_new = "new",
    screen_reward = "Reward",
    reward_receives = "{name} receives:",
    reward_choose = "Choose up to {n}, {chosen} chosen",
    reward_accept = "Accept",
    action_screenMessages = "Messages on screen",
    screen_messages_none = "No message on screen",
    screen_message = "Message",
    item_supplies = "{n} camp supplies",
    item_supplies_one = "{n} camp supply",
    move_crosses = "the way crosses {surface}",
    item_grants = "Grants: {actions}",
    action_done = "Done: {label}",
    use_provokes = "Going to {name} provokes an attack of opportunity. Enter again to go anyway.",
    target_aiming = "Turning the camera to aim at {name}",
    equip_costs_action = "Equipping in combat uses your action. Enter again equips {name}.",
    slot_light_source = "Light source",
    item_damage = "Damage {dice}, {type}",
    item_versatile = "two-handed {dice}",
    item_enchantment = "enchantment +{bonus}",
    item_armor_class = "Armour class {ac}",
    item_proficient = "proficient",
    item_not_proficient = "not proficient",
    item_weapon_actions = "Weapon actions: {actions}",
    item_on_equip = "When equipped: {passives}",
    item_used = "{name} used",
    item_equipped_now = "{name} equipped",
    item_unequipped = "{name} unequipped",
    slot_empty = "empty",
    screen_character_panel = "Character",
    section_inventory = "Inventory, {n} items, {gold} gold",
    section_inventory_title = "Inventory",
    section_equipment = "Equipment",
    section_character = "Character sheet",
    sheet_name_level = "{name}, {classes} level {level}",
    sheet_name_level_only = "{name}, level {level}",
    sheet_xp = "Experience {xp} of {next}",
    sheet_ac = "Armour class {n}",
    sheet_class_subclass = "{class} ({subclass})",
    sheet_race = "Race: {race}",
    sheet_background = "Background: {background}",
    sheet_approval = "Approval toward {name}: {rating}",
    sheet_save_proficient = "saving throw proficiency",
    level_up_available = "Level up available",
    level_up_for = "Level up available: {names}",
    help_inventory = "Enter opens a section. In the inventory Enter uses or equips the item, as a double click does; in the equipment Enter unequips. Control D reads the description.",
    none = "none",
    not_selected = "not selected",
    cc_section = "{section}: {value}",
    cc_selected = "{choice} selected",
    cc_locked = "fixed by the origin",
    cc_points = "{n} of {total} points left",
    cc_ability = "{name} {value}, modifier {modifier}",
    cc_bonus = "Bonus {bonus}: {ability}",
    cc_skill = "{name}, {ability}, {state}",
    cc_proficient = "proficient",
    cc_chosen = "{n} of {max} chosen",
    cc_name = "Name",
    cc_name_default = "the game's default",

    -- Help
    tutorial_last_page = "This is the last page. Finish closes it.",
    help_list = "Up and down arrows read, Enter or Space activates, Home and End jump.",
    help_change = "Left and right arrows change values, with Shift in small steps; where there is no value they move like up and down.",
    help_message_box = "Up and down arrows, or left and right, move between the buttons, Enter activates.",
    help_difficulty = "Left and right arrows change the difficulty preset.",
    help_passive = "The game's own keys work here.",
    help_tabs = "Tab and Shift Tab switch tabs, Escape closes.",
    help_back = "Escape goes back.",
    help_nearby = "Enter goes to it and uses it, like a click: talk, open, loot, open or close a door. Tab and Shift Tab go through the sections: everything, nearest first, then one kind at a time: characters, containers, things to pick up, doors, traps, other things. Escape closes. Lists what the game highlights, doors, and the other things around that can be used.",
    help_dialogue = "Lines are read as they come. When options are up: up and down arrows read them, Enter answers; the number keys answer directly. Space skips a line.",
    help_targeting = "Up and down arrows choose a target and read the game's preview. Enter confirms, Escape cancels.",
    help_place = "Arrow keys move the place one meter, relative to the camera: up is away from the camera. Shift with arrows moves five meters. Home comes back to you. Each move reads the game's preview. Enter confirms, Escape cancels.",
    help_menu = "Up and down arrows choose, Tab and Shift Tab go to the next or previous group, a letter jumps to a command starting with it, Enter runs, Escape closes. The list changes with what you are doing.",
    help_history = "Tab and Shift Tab switch between events, combat log and dialogue. Up and down arrows read the lines, newest first. Escape closes.",
    help_hud = "The game's own keys work here. In combat, Space ends the turn; while an action or bonus action is left it asks first, and Space again ends it. Control R reads your character's status.",
    help_markers = "Enter walks there. Escape closes.",
    help_cc = "Enter opens a section. In a section, Control D reads the description of the current choice.",
    help_global = "Mod keys: {keys}.",
    help_key = "{key}: {action}",

    -- Input names (Strings.InputName, Strings.KeyName)
    key_separator = " ",
    input_mouse_middle = "middle mouse button", input_mouse_left2 = "left click", input_mouse_right2 = "right click",
    input_mouse_motion_xpos = "mouse to the right", input_mouse_motion_xneg = "mouse to the left",
    input_numpad = "Numpad {key}",
    input_up = "Up arrow", input_down = "Down arrow", input_left = "Left arrow", input_right = "Right arrow",
    input_pageup = "Page Up", input_pagedown = "Page Down", input_home = "Home", input_end = "End",
    input_del = "Delete", input_insert = "Insert", input_escape = "Escape", input_enter = "Enter",
    input_space = "Space", input_tab = "Tab", input_backspace = "Backspace", input_backtick = "Backtick",
    input_hyphen = "Minus", input_equals = "Equals", input_leftbracket = "Left bracket",
    input_rightbracket = "Right bracket", input_lshift = "Left Shift", input_rshift = "Right Shift",
    input_lctrl = "Left Control", input_rctrl = "Right Control", input_lalt = "Left Alt", input_ralt = "Right Alt",
    input_pause = "Pause", input_left2 = "Left mouse button", input_right2 = "Right mouse button",
    input_middle = "Middle mouse button", input_wheel_ypos = "Mouse wheel up", input_wheel_yneg = "Mouse wheel down",
    input_Ctrl = "Control", input_Shift = "Shift", input_Alt = "Alt", input_Gui = "Windows",

    -- Action names (help, config)
    action_menu = "Mod menu",
    action_help = "Help",
    action_readScreen = "Read the screen",
    action_details = "Details of the current item",
    action_nearby = "Nearby things",
    action_markers = "Map markers and objectives",
    action_status = "Character status",
    action_turnOrder = "Turn order",
    action_actions = "Actions and attacks",
    action_move = "Move",
    action_whereAmI = "Where am I",
    action_farther = "Farther things: destinations up to 150 meters",
    action_levelUp = "Level up",
    screen_level_up = "Level up",
    level_up_title = "Level up, {name}, {from} to {to}",
    level_up_hp = "Hit points {from} to {to}",
    level_up_feature = "New feature: {name}",
    level_up_action = "New action: {name}",
    level_up_slots = "Level {level} spell slots {from} to {to}",
    level_up_resource = "New resource: {name}",
    level_up_pending = "Still to choose, not supported by the mod yet: {choices}",
    level_up_choice_subclass = "subclass",
    level_up_choice_feat = "feat",
    level_up_feat = "Feat",
    level_up_feat_points = "Ability points",
    level_up_feat_skills = "Feat skills",
    level_up_feat_ability = "{name} {value}",
    level_up_feat_plus = "plus {n}",
    feat_taken = "already taken",
    help_level_up_feat = "Feat: Enter on it opens the feats; there Enter chooses one and Ctrl+D describes it. Ability points: Right adds a point, Left takes it back.",
    level_up_waiting = "Waiting until the level up screen takes choices",
    level_up_choice_passive = "class option",
    help_level_up = "Control D describes a feature. Accept finishes the level up; Escape closes it without levelling.",
    help_level_up_spells = "Enter on a spell choice lists the spells; there Enter chooses a spell or takes it back, Control D describes it, and Escape comes back.",
    targets_chosen = "{name}: {n} of {max} targets chosen. Enter adds another, the same or a new one",
    targets_cast_now = "Cast now with {n} of {max} targets",
    log_action = "{actor}: {spell}",
    log_action_target = "{actor}: {spell} on {target}",
    log_again = "then {spell}",
    log_again_target = "then {spell} on {target}",
    log_target = "{target}: {results}",
    log_action_results = "{action}, {results}",
    log_missed = "missed",
    screen_reaction = "Reaction",
    screen_reaction_settings = "Reactions",
    screen_spellbook = "Spell book",
    screen_camp = "Long rest",
    screen_waypoints = "Waypoints",
    screen_explore = "Explore",
    action_stopWalking = "Stop walking",
    walking_stopped = "Stopped",
    reason_cancelled = "stopped",
    reason_no_progress = "the way does not get any closer",
    screen_load_game = "Load game",
    screen_world_map = "Map",
    map_markers = "Markers, {n}",
    map_waypoints = "Waypoints, {n}",
    help_world_map = "Markers: where each is, north up as on the map; Enter closes the map and walks there. Waypoints: Enter travels at once. Escape closes the map.",
    action_loadGame = "Load a saved game",
    save_played = "played {time}",
    loading_save = "Loading {name}",
    action_explore = "Explore: walk in a direction",
    compass_north = "North",
    compass_north_east = "North-east",
    compass_east = "East",
    compass_south_east = "South-east",
    compass_south = "South",
    compass_south_west = "South-west",
    compass_west = "West",
    compass_north_west = "North-west",
    count_of = "{n} {name}",
    explore_meters = "{n} meters walkable",
    explore_meters_one = "{n} meter walkable",
    explore_no_way = "no way",
    explore_blocked = "No way to walk {direction} from here",
    explore_going = "Walking {direction}",
    explore_new = "Now in range: {names}",
    explore_nothing_new = "Arrived. Nothing new in range",
    terrain_two = "{a} and {b}",
    material_Grass = "grass", material_Dirt = "earth", material_Gravel = "gravel", material_Stone = "stone",
    material_Marble = "marble", material_Sand = "sand", material_Water = "water", material_WaterDeep = "deep water",
    material_WaterPuddle = "puddles", material_Forest = "forest floor", material_GroundRocks = "rocks",
    material_Wood = "wood", material_Ash = "ash", material_Mud = "mud", material_Metal = "metal",
    material_Carpet = "carpet", material_Snow = "snow", material_Ice = "ice", material_Chitin = "chitin",
    material_Flesh = "flesh", material_Bone = "bone", material_Glass = "glass",
    help_explore = "Each direction says how far the character can walk that way. Enter walks there and names what comes into range. Directions are the map's: north is up on the world map.",
    action_waypoints = "Waypoints: travel, leave camp",
    waypoints_none = "No waypoints discovered",
    action_signposts = "Signposts you have read",
    screen_signposts = "Signposts",
    signposts_none = "No signpost read in this area yet",
    action_markHere = "Mark this spot",
    action_marks = "Your marks",
    screen_marks = "Marks",
    marks_none = "No marks in this area yet",
    mark_name_near = "{area}, near {thing}",
    mark_unnamed = "Mark",
    mark_added = "Marked: {name}",
    mark_removed = "Mark removed: {name}",
    help_marks = "Spots you marked with \"Mark this spot\". Enter walks there, Delete removes a mark.",
    action_whoSeesMe = "Who can see you",
    seen_by = "Seen by {names}",
    seen_by_nobody = "Nobody sees you",
    action_places = "Places you have been",
    screen_places = "Places",
    places_none = "No named place visited in this area yet",
    place_you_are_here = "you are here",
    dialogue_no_option = "No option {n}",
    tutorial_hint_end_turn = "With the keyboard: Space ends the turn; the mod asks first while an action is left",
    tutorial_hint_equipment = "With the mod: in the character screen, I, Enter on an item equips it",
    tutorial_hint_hotbar = "With the mod: the actions list, Control M then Actions and attacks, has every action and item; nothing needs dragging",
    entry_start = "Typing {label}: {text}. Type, Backspace deletes, Enter confirms, Escape cancels",
    entry_empty = "empty",
    entry_space = "space",
    entry_deleted = "{char} deleted",
    entry_cancelled = "Typing cancelled",
    entry_full = "At most {n} characters",
    roll_total_bonus = "Bonus {bonus}",
    roll_with_advantage = "With advantage: two dice, the higher one counts",
    roll_with_disadvantage = "With disadvantage: two dice, the lower one counts",
    roll_boost_from = "{name} from {owner}, {dice}",
    roll_boosts = "Bonuses you can add: {names}. Control M adds one",
    roll_add_boost = "Add {name} from {owner}, {dice}",
    roll_adding = "Adding {name}",
    roll_boost_added = "{name} added. Bonus {bonus}",
    roll_remove_boost = "Take back {name}",
    roll_boost_removed = "{name} taken back",
    roll_boost_rolled = "{name}: {n}",
    screen_trade = "Trade",
    screen_widget_GameMenu = "Game menu",
    screen_widget_SaveGame = "Save game",
    screen_credits = "Credits",
    screen_widget_ModBrowserSplashScreen = "Mod manager",
    screen_widget_ModBrowser = "Mod manager",
    screen_widget_JournalInspiration = "Inspiration",
    screen_widget_SaveGamePopup = "New save",
    save_overwrite_hint = "Enter overwrites it",
    save_description = "Description",
    screen_book = "Book",
    trade_gold = "Your gold: {gold}. {trader}: {traderGold} gold",
    trade_buy_from = "Buy from {trader}, {n} items",
    trade_buy_from_one = "Buy from {trader}, {n} item",
    trade_sell_from = "Sell {owner}'s items, {n}",
    trade_price = "{gold} gold",
    trade_bought = "Bought {name}. {gold} gold left",
    trade_sold = "Sold {name}. Your gold: {gold}",
    trade_too_expensive = "Not enough gold: {name} costs {price}, you have {gold}",
    trade_trader_poor = "{trader} has only {gold} gold",
    help_trade = "Buy and Sell lists: Enter on an item buys or sells it at once for the price said, as the game's quick trade does. Control D describes the item. Escape closes the trade.",
    help_places = "The named places of this area the party has been to, as the game names them on entering. Enter walks there.",
    travelling_to = "Travelling to {name}",
    action_shortRest = "Short rest",
    action_longRest = "Long rest: go to camp and end the day",
    camp_supplies = "{label}: {selected} of {required}",
    camp_supply_count = "{n} of them",
    camp_supply_used = "{n} used",
    action_spellbook = "Spell book: spells and preparing them",
    spellbook_class = "{class}, {prepared} of {max} prepared",
    spellbook_none = "No spells",
    spellbook_cannot_change = "The game does not allow that now",
    spellbook_full = "All {max} spells to prepare are chosen: unprepare one first",
    spell_state_prepared = "prepared",
    spell_state_unprepared = "not prepared",
    spell_state_always = "always prepared",
    help_spellbook = "Enter prepares or unprepares a spell. Control D describes it.",
    action_reactions = "Reactions settings",
    reaction_character = "{name}, {n} reactions",
    reaction_character_one = "{name}, {n} reaction",
    reaction_mode_always = "always",
    reaction_mode_ask = "ask",
    reaction_mode_never = "never",
    reaction_not_ready = "not prepared",
    help_reaction_settings = "Left and right arrows or Enter change when a reaction is used: always, ask, or never. Ask brings a question when it can be used. Control D describes it.",
    reaction_title = "Reaction? {event}",
    reaction_dont = "Don't react",
    help_reaction = "Enter on a reaction uses it; the last button or Escape lets the moment pass. Control D describes a reaction.",
    spell_choice = "{title}, {chosen} of {max} chosen",
    spell_choice_done = "{title}, {chosen} of {max} chosen, complete",
    spell_choice_cantrips = "Cantrips",
    spell_choice_spells = "Spells",
    spell_chosen = "chosen",
    spell_now_chosen = "{name} chosen",
    spell_now_removed = "{name} taken back",
    spell_param_damage = "{min} to {max} damage",
    spell_param_damage_type = "{min} to {max} {type} damage",
    spell_param_heal = "{min} to {max} hit points",
    spell_range = "range {n} meters",
    spell_range_one = "range {n} meter",
    spell_radius = "radius {n} meters",
    spell_radius_one = "radius {n} meter",
    spell_cone = "cone of {n} meters",
    spell_cone_angle = "cone of {n} meters, {angle} degrees",
    spell_square = "area {n} by {width} meters",
    spell_slot_cost = "level {n} spell slot",
    spell_attack_roll = "attack roll",
    spell_concentration = "concentration",
    spell_ritual = "ritual",
    action_journal = "Journal: quests and objectives",
    screen_journal = "Journal",
    journal_quests = "{n} quests",
    journal_quests_one = "{n} quest",
    journal_objectives = "{n} objectives",
    journal_objectives_one = "{n} objective",
    journal_updated = "updated",
    journal_nothing = "Nothing written",
    help_journal = "Enter opens a category, then a quest; on an objective Enter reads the story so far. Escape goes back.",
    action_history = "History: events, combat log, dialogue",
    action_repeat = "Repeat the last line",
    action_stopSpeech = "Stop speech",
    action_barks = "Barks: everyone's, the party's only, or none",
    action_barks_all = "Barks: everyone's",
    action_barks_party = "Barks: the party's only",
    action_barks_none = "Barks: none",
    action_resetSpeech = "Find the screen reader again",
}

local current = EN

-- Fills "{name}" placeholders. Numbers are written with Strings.Number (at most one decimal, the
-- language's decimal separator), so callers pass numbers, not preformatted text.
local function format(s, args)
    if not args then return s end
    return (s:gsub("{(%w+)}", function(k)
        local v = args[k]
        if v == nil then return "" end
        if type(v) == "number" then return Strings.Number(v, 1) end
        return tostring(v)
    end))
end

-- Plural category of n (CLDR cardinal rules, integers) per language: "one", "few", "many" or
-- "other". Languages without an entry (zh, ja, ko: no plural forms) always use "other".
local PLURALS = {}
local function oneOther(n) return n == 1 and "one" or "other" end
local function slavic(n) -- ru, uk
    local m10, m100 = n % 10, n % 100
    if m10 == 1 and m100 ~= 11 then return "one" end
    if m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14) then return "few" end
    return "many"
end
for _, code in ipairs({ "en", "de", "it", "es", "es-419", "tr", "pt-BR" }) do PLURALS[code] = oneOther end
PLURALS.fr = function(n) return (n == 0 or n == 1) and "one" or "other" end
PLURALS.ru, PLURALS.uk = slavic, slavic
PLURALS.pl = function(n)
    if n == 1 then return "one" end
    local m10, m100 = n % 10, n % 100
    if m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14) then return "few" end
    return "many"
end

local language = "en"

-- The game's language names (Ext.Utils.GetGlobalSwitches().Language: "Spanish" verified
-- 2026-09-24) and the mod's codes; a code without a table of its own uses the one after it
-- (es-419 -> es), then English.
local GAME_LANGUAGES = {
    English = "en", Spanish = "es", LatinSpanish = "es-419", French = "fr", German = "de", Italian = "it",
    Polish = "pl", Russian = "ru", Ukrainian = "uk", Turkish = "tr", BrazilianPortuguese = "pt-BR",
    Chinese = "zh-Hans", ChineseTraditional = "zh-Hant", Japanese = "ja", Korean = "ko",
}
local FALLBACKS = { ["es-419"] = "es" }

-- Loads Strings/<code>.lua (at load time: Ext.Require fails later). nil when there is none.
local function tableFor(code)
    local ok, t = pcall(Ext.Require, "Strings/" .. code .. ".lua")
    return ok and type(t) == "table" and t or nil
end

-- Sets the language of the mod's words: a code, or "auto" for the game's language. Returns the
-- code in use.
function Strings.SetLanguage(choice)
    local code = choice
    if not code or code == "auto" then
        local ok, switches = pcall(Ext.Utils.GetGlobalSwitches)
        code = ok and switches and GAME_LANGUAGES[switches.Language] or "en"
    end
    language = code
    local t = code ~= "en" and (tableFor(code) or (FALLBACKS[code] and tableFor(FALLBACKS[code]))) or nil
    current = t or EN
    return code
end

-- The plural form of key for n: "key_one", "key_few" or "key_many" when the language has that
-- category for n and the table has that key; else key itself (the "other" form). Non-integers are
-- "other" (CLDR: fractions take "other" in en, es, de, it, pt, ru, uk, pl, tr).
local function pluralKey(key, n)
    n = math.floor(n * 10 + 0.5) / 10 -- as spoken (placeholders show one decimal): 1.0001 is "1"
    if n ~= math.floor(n) then return key end
    local rule = PLURALS[language]
    local category = rule and rule(math.abs(n)) or "other"
    if category ~= "other" and current[key .. "_" .. category] then return key .. "_" .. category end
    return key
end

-- Strings.Get("key") or Strings.Get("key", { name = value }). A numeric {n} picks the plural form
-- ("meters" with n = 1 -> "meters_one"), so counted strings need nothing special from callers.
function Strings.Get(key, args)
    if args and type(args.n) == "number" then key = pluralKey(key, args.n) end
    local s = current[key] or EN[key]
    if not s then
        Log.Error("missing string '" .. tostring(key) .. "'")
        return tostring(key)
    end
    return format(s, args)
end

function Strings.Has(key)
    return current[key] ~= nil or EN[key] ~= nil
end

-- A list for speech: { "a", "b" } -> "a, b" (the language's separator). nil, false and "" parts
-- are skipped, wherever they are, so optional parts can be written inline:
-- Strings.List({ label, role, disabled and L("unavailable") }).
function Strings.List(parts)
    local last = 0
    for k in pairs(parts) do
        if type(k) == "number" and k > last then last = k end
    end
    local out = {}
    for i = 1, last do
        local p = parts[i]
        if p and p ~= "" then out[#out + 1] = tostring(p) end
    end
    return table.concat(out, Strings.Get("list_separator"))
end

-- Sentences for speech: each part ends with the language's full stop unless it already ends in
-- punctuation, joined with the language's separator ("." and " "; "。" and "" in Japanese).
-- nil, false and "" parts are skipped, as in Strings.List.
local ENDS_SENTENCE = { ["."] = true, ["!"] = true, ["?"] = true, [":"] = true, [";"] = true }
local WIDE_ENDS = { "…", "。", "！", "？", "：" }

local function endsSentence(p)
    if ENDS_SENTENCE[p:sub(-1)] then return true end
    for _, e in ipairs(WIDE_ENDS) do
        if p:sub(-#e) == e then return true end
    end
    return false
end

function Strings.Sentences(parts)
    local last = 0
    for k in pairs(parts) do
        if type(k) == "number" and k > last then last = k end
    end
    local out = {}
    for i = 1, last do
        local p = parts[i]
        if p and p ~= "" then
            p = tostring(p):gsub("%s+$", "")
            if not endsSentence(p) then p = p .. Strings.Get("sentence_end") end
            out[#out + 1] = p
        end
    end
    return table.concat(out, Strings.Get("sentence_separator"))
end

-- A number for speech with at most `decimals` decimals (default 0), trailing zeros dropped, with
-- the language's decimal separator: 2.25 -> "2.3" / "2,3".
function Strings.Number(v, decimals)
    local s = string.format("%." .. (decimals or 0) .. "f", v)
    if s:find("%.") then s = s:gsub("0+$", ""):gsub("%.$", "") end
    return (s:gsub("%.", Strings.Get("decimal_separator")))
end

-- Spoken name of one input, by the game's raw input name (Game/Input: "up", "f1", "kp_1", "left2",
-- modifiers "Ctrl"...): the string "input_<name>"; keypad keys through "input_numpad"; letters,
-- digits and F-keys need no string ("A", "1", "F1").
local function inputWord(name)
    if Strings.Has("input_" .. name) then return Strings.Get("input_" .. name) end
    local kp = name:match("^kp_(.+)$")
    if kp then return Strings.Get("input_numpad", { key = inputWord(kp) }) end
    return (name:gsub("^num_", ""):upper())
end

-- A game binding for speech: ("f1", { "Ctrl", "Shift" }) -> "Control Shift F1".
function Strings.InputName(input, modifiers)
    local parts = {}
    for _, m in ipairs(modifiers or {}) do parts[#parts + 1] = inputWord(m) end
    parts[#parts + 1] = inputWord(input)
    return table.concat(parts, Strings.Get("key_separator"))
end

-- Mod combos use SDL scancode names ("CTRL+RETURN"); most are the game's input name in upper case.
local SCANCODE_INPUTS = { CTRL = "Ctrl", SHIFT = "Shift", ALT = "Alt", RETURN = "enter", DELETE = "del" }

-- Name of a mod key combo for speech: "CTRL+R" -> "Control R".
function Strings.KeyName(combo)
    local parts = {}
    for p in tostring(combo):gmatch("[^+]+") do
        parts[#parts + 1] = inputWord(SCANCODE_INPUTS[p] or p:lower())
    end
    return table.concat(parts, Strings.Get("key_separator"))
end

return Strings
