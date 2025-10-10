-- src/core/enemies/BitRipper.lua
local Enemy = require "src.core.Enemy"
local EnemyAI_DB = require "src/core/ai/EnemyAI_DB"

local BitRipper = {}
BitRipper.__index = BitRipper
setmetatable(BitRipper, {__index = Enemy})

function BitRipper:new(x, y)
    local instance = Enemy:new(x, y, "BIT_RIPPER_SPRITE", ServiceLocator.get("config").activeColors.enemy, "BIT_RIPPER", 20, true, EnemyAI_DB.BitRipper) -- Moderate HP
    setmetatable(instance, BitRipper)

    instance.rangedAttackDamage = 7
    instance.attackRange = 6 -- Max range of its ranged attack
    instance.optimalRangeMin = 3 -- Tries to stay at least this far away
    instance.optimalRangeMax = instance.attackRange -1 -- Tries to stay within this range

    instance.phaseStepChance = 0.33 -- 33% chance to phase step after attacking
    instance.phaseStepRange = 3   -- How far it can teleport

    instance.dataFragmentsValue = love.math.random(8, 18)

    return instance
end

-- The complex act() and executePlannedAction() methods are now removed.
-- All AI logic is handled by the base Enemy:act() which uses the AI definition
-- from EnemyAI_DB. The specific execution for its abilities is also defined there.

-- die() method can be inherited from Enemy.

return BitRipper