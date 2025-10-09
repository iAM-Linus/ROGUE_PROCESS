-- src/core/ai/EnemyAI_DB.lua
local AIBehaviors = require "src/core/ai/AIBehaviors"

local EnemyAI_DB = {}

--[[
    AI Definition Structure:
    - behaviors: A list of potential actions, sorted by priority.
      - state: The AI state in which this behavior is valid (e.g., "hunting", "fleeing").
      - plan: The function from AIBehaviors that returns an action plan.
      - abilityId (optional): A unique ID for cooldown tracking.
      - maxCooldown (optional): The cooldown duration in turns for this ability.
]]

EnemyAI_DB.SentryBot = {
    behaviors = {
        { state = "fleeing",    plan = AIBehaviors.planMoveAwayFromPlayer },
        { state = "hunting",    plan = AIBehaviors.planAttackIfAdjacent },
        { state = "hunting",    plan = AIBehaviors.planMoveToPlayer },
        { state = "patrolling", plan = AIBehaviors.planRandomWalk },
    }
}

EnemyAI_DB.DataLeech = {
    behaviors = {
        { state = "hunting", plan = AIBehaviors.planLeechCPU, abilityId = "leech_cpu", maxCooldown = 2 },
        { state = "hunting", plan = AIBehaviors.planMoveToPlayer },
        { state = "patrolling", plan = AIBehaviors.planRandomWalk },
    }
}

EnemyAI_DB.FirewallNode = {
    behaviors = {
        -- This enemy doesn't move, its state is always 'hunting' in a sense.
        -- We'll use the 'idle' state to represent its stationary nature.
        { state = "idle", plan = AIBehaviors.planPulse, abilityId = "pulse", maxCooldown = 4 },
        { state = "hunting", plan = AIBehaviors.planPulse, abilityId = "pulse", maxCooldown = 4 },
        { state = "patrolling", plan = AIBehaviors.planPulse, abilityId = "pulse", maxCooldown = 4 },
    }
}

EnemyAI_DB.GlitchSwarmer = {
    behaviors = {
        { state = "hunting",    plan = AIBehaviors.planReplicate, abilityId = "replicate", maxCooldown = 5 },
        { state = "hunting",    plan = AIBehaviors.planAttackIfAdjacent },
        { state = "hunting",    plan = AIBehaviors.planMoveToPlayer },
        { state = "patrolling", plan = AIBehaviors.planRandomWalk },
    }
}

EnemyAI_DB.CipherSentinel = {
    behaviors = {
        { state = "hunting",    plan = AIBehaviors.planAttackIfAdjacent },
        { state = "guarding",   plan = AIBehaviors.planEncryptAlly, abilityId = "encrypt", maxCooldown = 4 },
        { state = "hunting",    plan = AIBehaviors.planEncryptAlly, abilityId = "encrypt", maxCooldown = 4 },
        { state = "hunting",    plan = AIBehaviors.planMoveToPlayer },
        { state = "guarding",   plan = AIBehaviors.planRandomWalk }, -- Can wander a bit while guarding
    }
}

EnemyAI_DB.BitRipper = {
    behaviors = {
        { state = "hunting", plan = AIBehaviors.planRangedAttack, abilityId = "ranged_attack", maxCooldown = 1 },
        { state = "hunting", plan = AIBehaviors.planRepositionForRange },
        { state = "patrolling", plan = AIBehaviors.planRandomWalk },
    }
}


return EnemyAI_DB