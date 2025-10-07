-- src/core/Pickup.lua
local Entity = require "src.core.Entity"

local Pickup = {}
Pickup.__index = Pickup
setmetatable(Pickup, {__index = Entity})

function Pickup:new(x, y, char, color, name, pickupType, data)
    -- Pickups don't block movement and have no HP by default
    local instance = Entity:new(x, y, char, color, name, false, 0)
    setmetatable(instance, Pickup)
    instance.pickupType = pickupType -- e.g., "DATA_FRAGMENT", "SUBROUTINE_CACHE"
    instance.data = data or {} -- Any specific data for the pickup
    instance.isPickup = true -- Flag to identify as pickup
    print("Pickup created: " .. name .. ", blocksMovement: " .. tostring(instance.blocksMovement))
    return instance
end

-- Static factory for Subroutine Cache
function Pickup.newSubroutineCache(x, y)
    return Pickup:new(x, y, "SUBROUTINE_CACHE_QUAD", _G.Config.activeColors.pickup, "SUBROUTINE_CACHE", "SUBROUTINE_CACHE")
end

function Pickup.newDataFragment(x,y, amount)
    amount = amount or love.math.random(5,20)
    return Pickup:new(x,y, "DATA_FRAGMENT_QUAD", _G.Config.activeColors.pickup, "DATA_FRAGMENT", "DATA_FRAGMENT", {value = amount})
end

function Pickup.newRepairNanites(x,y, amount)
    amount = amount or love.math.random(15,30) -- Heal amount
    return Pickup:new(x,y, "REPAIR_NANITES_QUAD", {0.4, 0.9, 0.4, 1}, "REPAIR_NANITES", "REPAIR_NANITES", {value = amount}) -- Greenish
end

function Pickup.newEnergyCell(x,y, amount)
    amount = amount or love.math.random(10,25) -- CPU restore amount
    return Pickup:new(x,y, "ENERGY_CELL_QUAD", {0.4, 0.7, 1.0, 1}, "ENERGY_CELL", "ENERGY_CELL", {value = amount}) -- Bluish
end

-- Pickups don't act or take damage in the usual sense
function Pickup:act() return false end
function Pickup:takeDamage() end -- Immune

return Pickup