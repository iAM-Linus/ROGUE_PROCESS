-- src/core/enemies/FirewallNode.lua
local Enemy = require "src.core.Enemy" -- Inherit from Enemy
local EnemyAI_DB = require "src/core/ai/EnemyAI_DB"

local FirewallNode = {}
FirewallNode.__index = FirewallNode
setmetatable(FirewallNode, {__index = Enemy}) -- Inherit from Enemy

function FirewallNode:new(x, y)
    -- Call Enemy constructor. Firewall Node doesn't block player movement.
    local instance = Enemy:new(x, y, "FIREWALL_NODE_SPRITE", _G.Config.activeColors.enemy, "FIREWALL_NODE", 50, false, EnemyAI_DB.FirewallNode)
    setmetatable(instance, FirewallNode)

    instance.pulseDamage = 8
    instance.pulseRange = 5
    instance.pulseDirection = love.math.random(1, 4) -- 1:Up, 2:Right, 3:Down, 4:Left
    
    instance.dataFragmentsValue = love.math.random(10, 25) -- Override default from Enemy

    return instance
end

-- The complex act() and executePlannedAction() methods are now removed.
-- All AI logic is handled by the base Enemy:act() which uses the AI definition
-- from EnemyAI_DB. The specific execution for its abilities is also defined there.

-- FirewallNode:die() can be removed if Enemy:die() is sufficient.
-- The base Enemy:die() already handles dropping self.dataFragmentsValue.
-- function FirewallNode:die()
--     Enemy.die(self) -- Call parent's die method
--     -- Add any FirewallNode-specific death effects here, if any
-- end

return FirewallNode