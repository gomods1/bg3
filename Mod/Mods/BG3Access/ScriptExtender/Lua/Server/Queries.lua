-- Server half: answers the client's read-only queries (Net/Channels) with Osiris queries.
-- Osiris names verified in ref/osiris/OsiIdeHelpers.lua (game 4.1.1.7398727, SE v32):
-- IsOpened(item), IsLocked(item), IsInvisible(item), IsMovable(item) return 1/0. IsTrapDiscovered read 1 for all
-- fifteen spike traps around the Risen Road, every one of them also IsInvisible 1 (2026-09-24):
-- a trap counts as found by the party while it is not invisible.
local Channels = Ext.Require("Net/Channels.lua")
local Log = Ext.Require("Core/Log.lua")

local Queries = {}

local function flag(fn, ...)
    local ok, v = pcall(fn, ...)
    return ok and v == 1
end

function Queries.Start()
    Channels.DoorStates:SetRequestHandler(function(data)
        local out = {}
        for _, uuid in ipairs(data.uuids or {}) do
            out[uuid] = { opened = flag(Osi.IsOpened, uuid), locked = flag(Osi.IsLocked, uuid) }
        end
        return out
    end)
    Channels.TrapStates:SetRequestHandler(function(data)
        local out = {}
        for _, uuid in ipairs(data.uuids or {}) do
            out[uuid] = { discovered = not flag(Osi.IsInvisible, uuid) }
        end
        return out
    end)
    -- Verified 2026-09-24 ("Seta de huevo de dragón" in the goblin sanctum): ServerItem.Template
    -- .Description is the text the game's tooltip shows; Value.Value the gold value, Value.Rarity
    -- an index of ItemDataRarity.
    Channels.ItemInfo:SetRequestHandler(function(data)
        local out = {}
        for _, uuid in ipairs(data.uuids or {}) do
            local e = Ext.Entity.Get(uuid)
            local info = {}
            pcall(function() info.description = Ext.Loca.GetTranslatedString(e.ServerItem.Template.Description.Handle.Handle) end)
            pcall(function()
                info.value = e.Value.Value
                info.rarity = tostring(Ext.Enums.ItemDataRarity[e.Value.Rarity])
            end)
            -- Data.Weight is in grams (healing potions: 100, shown as 0,1 kg).
            pcall(function() info.weight = e.Data.Weight / 1000 end)
            info.locked = flag(Osi.IsLocked, uuid)
            info.movable = flag(Osi.IsMovable, uuid)
            if info.description == "" then info.description = nil end
            out[uuid] = info
        end
        return out
    end)
    Channels.Relations:SetRequestHandler(function(data)
        local out = {}
        for _, uuid in ipairs(data.uuids or {}) do
            if flag(Osi.IsEnemy, uuid, data.to) then
                out[uuid] = "enemy"
            elseif flag(Osi.IsAlly, uuid, data.to) then
                out[uuid] = "ally"
            else
                out[uuid] = "neutral"
            end
        end
        return out
    end)
    Channels.Watchers:SetRequestHandler(function(data)
        local out = {}
        for _, uuid in ipairs(data.uuids or {}) do
            out[uuid] = { sees = flag(Osi.CanSee, uuid, data.target), spotsSneakers = flag(Osi.CanSpotSneakers, uuid) }
        end
        return out
    end)
    Log.Info("server queries registered")
end

return Queries
