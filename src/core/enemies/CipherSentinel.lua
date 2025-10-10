-- src/core/enemies/CipherSentinel.lua
local Enemy = require "src.core.Enemy"
local EnemyAI_DB = require "src/core/ai/EnemyAI_DB"

local CipherSentinel = {}
CipherSentinel.__index = CipherSentinel
setmetatable(CipherSentinel, {__index = Enemy})

function CipherSentinel:new(x, y)
    -- Bluish/Cyan color, high HP, blocks movement
    local instance = Enemy:new(x, y, "CIPHER_SENTINEL_SPRITE", ServiceLocator.get("config").activeColors.enemy, "CIPHER_SENTINEL", 75, true, EnemyAI_DB.CipherSentinel) 
    setmetatable(instance, CipherSentinel)

    instance.baseAttackPower = 6
    instance.visionRadius = 5 -- Shorter vision, more defensive

    instance.encryptRange = 3           -- Range to find an ally to encrypt
    instance.encryptShieldAmount = 15
    instance.encryptShieldDuration = 3
    
    instance.dataFragmentsValue = love.math.random(15, 30) -- Drops more fragments

    return instance
end

-- The complex act() and executePlannedAction() methods are now removed.
-- All AI logic is handled by the base Enemy:act() which uses the AI definition
-- from EnemyAI_DB. The specific execution for its abilities is also defined there.

-- die() method can be inherited from Enemy if default data fragment drop is sufficient.

return CipherSentinel