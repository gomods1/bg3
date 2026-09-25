-- Client <-> server channels (SE NetChannel API, verified present in SE v32). Required by both
-- bootstraps so each side registers the same names. The server half answers read-only queries
-- about game state that only the server knows (Server/Queries); it never acts for the player.
local Channels = {}

-- Door states: request { uuids = { uuid, ... } } -> reply { [uuid] = { opened = bool, locked = bool } }
Channels.DoorStates = Ext.Net.CreateChannel(ModuleUUID, "BG3Access_DoorStates")

-- Trap states: request { uuids } -> reply { [uuid] = { discovered = bool } } (Server/Queries:
-- discovered = not invisible)
Channels.TrapStates = Ext.Net.CreateChannel(ModuleUUID, "BG3Access_TrapStates")

-- World items: request { uuids } -> reply { [uuid] = { description (text), value, rarity (enum
-- name, "Common"...), weight (kg), locked, movable } } (Server/Queries: the item's template and Value component; the client's
-- item entity carries neither the template nor its description)
Channels.ItemInfo = Ext.Net.CreateChannel(ModuleUUID, "BG3Access_ItemInfo")

-- Places the party has been: request { character = uuid } -> reply { places = { { name,
-- position = {x,y,z} (where the party entered it), current = bool } } } (Server/Places)
Channels.Places = Ext.Net.CreateChannel(ModuleUUID, "BG3Access_Places")

-- Characters' relation to a party member: request { uuids, to = uuid } -> reply { [uuid] =
-- "enemy" / "ally" / "neutral" } (Server/Queries: Osiris IsEnemy / IsAlly)
Channels.Relations = Ext.Net.CreateChannel(ModuleUUID, "BG3Access_Relations")

-- Who sees a character: request { uuids, target = uuid } -> reply { [uuid] = { sees = bool,
-- spotsSneakers = bool } } (Server/Queries: Osiris CanSee(uuid, target), CanSpotSneakers(uuid))
Channels.Watchers = Ext.Net.CreateChannel(ModuleUUID, "BG3Access_Watchers")

-- The player's marks (Server/Marks): request { op = "list" | "add" (name, position) | "remove"
-- (id), character = uuid } -> reply { marks = { { id, name, position } } } on its level
Channels.Marks = Ext.Net.CreateChannel(ModuleUUID, "BG3Access_Marks")

-- Read signposts (Server/Signposts): request { uuid, text } stores what a sign said (reply {});
-- request { character = uuid } -> reply { signposts = { { uuid, text, position } } } on its level
Channels.RememberSignpost = Ext.Net.CreateChannel(ModuleUUID, "BG3Access_RememberSignpost")
Channels.Signposts = Ext.Net.CreateChannel(ModuleUUID, "BG3Access_Signposts")

return Channels
