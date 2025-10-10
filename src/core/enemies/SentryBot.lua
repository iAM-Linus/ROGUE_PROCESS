-- src/core/enemies/SentryBot.lua
local Enemy = require "src.core.Enemy" -- CHANGE THIS from Entity
local EnemyAI_DB = require "src/core/ai/EnemyAI_DB"

local SentryBot = {}
SentryBot.__index = SentryBot
setmetatable(SentryBot, {__index = Enemy}) -- INHERIT FROM ENEMY

function SentryBot:new(x, y)
    -- Call the Enemy constructor, which in turn calls Entity constructor
    local instance = Enemy:new(x, y, "SENTRY_BOT_SPRITE", ServiceLocator.get("config").activeColors.enemy, "SENTRY_BOT", 30, true, EnemyAI_DB.SentryBot)
    setmetatable(instance, SentryBot) -- Set metatable to SentryBot for its specific methods

    instance.baseAttackPower = 5
    -- visionRadius is inherited from Enemy, but can be overridden:
    -- instance.visionRadius = 10 
    instance.fleeThreshold = instance.maxHp * 0.3 -- Specific to SentryBot's fleeing logic
    
    -- dataFragmentsValue is inherited from Enemy, but can be overridden:
    instance.dataFragmentsValue = love.math.random(5, 15) 
    
    return instance
end

-- The complex act() and executePlannedAction() methods are now removed.
-- All AI logic is handled by the base Enemy:act() which uses the AI definition
-- from EnemyAI_DB.

-- SentryBot:die() can be removed if the base Enemy:die() (which drops dataFragmentsValue) is sufficient.
-- If SentryBot has unique death behavior beyond that, override it and call Enemy.die(self)
-- function SentryBot:die()
--     Enemy.die(self) -- Call parent's die method
--     -- Add any SentryBot-specific death effects here
-- end

return SentryBot