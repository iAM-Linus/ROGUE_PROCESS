-- src/core/enemies/DataLeech.lua
local Enemy = require "src.core.Enemy" -- Inherit from Enemy
local EnemyAI_DB = require "src/core/ai/EnemyAI_DB"

local DataLeech = {}
DataLeech.__index = DataLeech
setmetatable(DataLeech, {__index = Enemy}) -- Inherit from Enemy

function DataLeech:new(x, y)
    local instance = Enemy:new(x, y, "DATA_LEECH_SPRITE", ServiceLocator.get("config").activeColors.enemy, "DATA_LEECH", 25, true, EnemyAI_DB.DataLeech) -- Magenta, 25 HP
    setmetatable(instance, DataLeech)

    -- visionRadius is inherited from Enemy (default 7), can override if needed
    -- instance.visionRadius = 6 
    instance.leechAmount = 5
    
    instance.dataFragmentsValue = love.math.random(3, 10) -- Override default

    return instance
end

-- The complex act() and executePlannedAction() methods are now removed.
-- All AI logic is handled by the base Enemy:act() which uses the AI definition
-- from EnemyAI_DB. The specific execution for its abilities is also defined there.

-- DataLeech:die() can be removed if Enemy:die() is sufficient.
-- function DataLeech:die()
--     Enemy.die(self)
-- end

return DataLeech