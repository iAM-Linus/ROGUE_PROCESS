-- src/core/AICoreDB.lua
local config = ServiceLocator.get("config") -- For default player stats if needed

local AICoreDB = {}

--[[
Each AI Core definition:
{
    id = "unique_id",
    name = "Display Name / PID Fragment",
    description = "Flavor text or brief description of its specialty.",
    char = "@", -- Player character symbol for this core
    color = {r,g,b,a}, -- Player color for this core

    baseStats = {
        hp = 100,
        cpu = 50,
        cpuRegen = 1,
        -- Add other base stats if player gets more (e.g., baseAttackPower)
    },
    startingSubroutineId = "subroutine_id_string", -- ID of the subroutine they start with
    -- OR startingSubroutineChoices = {"id1", "id2"} if they get a choice

    passivePerk = { -- Optional
        id = "perk_id",
        name = "Perk Name",
        description = "Perk Description",
        apply = function(playerInstance) -- Modifies the player instance directly
            -- e.g., playerInstance.visionRadius = playerInstance.visionRadius + 2
        end
    },
    unlockCondition = "default" or "meta_currency" or "achievement_id", -- How it's unlocked
    metaCost = 0 -- If unlocked by meta-currency
}
--]]

AICoreDB.Cores = {
    standard_pid = {
        id = "standard_pid",
        name = "Assist Core 0",
        quadName = "PLAYER_DEFAULT",
        description = "A balanced, adaptable processing unit. Standard configuration.",
        char = config.playerChar or "@",
        color = config.activeColors.player,
        baseStats = {
            hp = config.playerIntegrity or 100,
            cpu = config.playerCPUCycles or 50,
            cpuRegen = config.playerCPURegen or 1,
            attack = 10 -- Assuming a base attack power
        },
        startingSubroutineId = nil, -- Starts with no subroutine, relies on first cache
        unlockCondition = "default"
    },
    assault_core_alpha = {
        id = "assault_core_alpha",
        name = "Assault Core 7",
        quadName = "PLAYER_ASSAULT",
        description = "Optimized for direct offensive subroutines. Higher CPU, lower integrity.",
        char = "A", -- Alpha symbol
        color = {1, 0.6, 0.6, 1}, -- Reddish tint
        baseStats = {
            hp = 80,
            cpu = 65,
            cpuRegen = 1,
            attack = 12
        },
        startingSubroutineId = "laser_exe", -- Starts with LASER.EXE
        unlockCondition = "default" -- For testing, make it default. Later: "Defeat first boss"
    },
    stealth_core_sigma = {
        id = "stealth_core_sigma",
        name = "Stealth Core 9",
        quadName = "PLAYER_STEALTH",
        description = "Adept at evasion and system manipulation. Lower base attack.",
        char = "Σ", -- Sigma symbol
        color = {0.4, 0.7, 0.9, 1}, -- Bluish/Cyan
        baseStats = {
            hp = 90,
            cpu = 55,
            cpuRegen = 2, -- Better CPU regen for utility
            attack = 7
        },
        startingSubroutineId = "firewall_sys", -- Example: starts with a defensive one
        -- passivePerk = {
        --     id = "evasive_routines",
        --     name = "Evasive Routines",
        --     description = "+10% chance to ignore a hit (not implemented yet)",
        --     apply = function(player) player.dodgeChance = (player.dodgeChance or 0) + 0.10 end
        -- },
        unlockCondition = "default" -- Example: Needs to be unlocked
    },
    -- Add more cores here
}

function AICoreDB.getById(id)
    return AICoreDB.Cores[id]
end

-- Function to get available cores for player selection
-- In a real game, this would check _G.MetaProgress.unlockedCores or similar
function AICoreDB.getSelectableCores()
    local selectable = {}
    for id, coreDef in pairs(AICoreDB.Cores) do
        if coreDef.unlockCondition == "default" then -- For now, only show default ones
            table.insert(selectable, coreDef)
        -- Later, you'd check a global save data for other unlock conditions:
        -- elseif _G.MetaProgressData:isCoreUnlocked(id) then
        --    table.insert(selectable, coreDef)
        end
    end
    table.sort(selectable, function(a,b) return a.name < b.name end)
    return selectable
end

return AICoreDB