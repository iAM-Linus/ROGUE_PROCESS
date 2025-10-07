-- src/global.lua
local M = {
    Config = nil,
    GameState = nil,
    Helpers = nil,
    Fonts = nil,
    CompositeShader = nil,
    MainSceneCanvas = nil,
    SelectedAICoreId = "standard_pid",
    UnlockedAICores = { ["standard_pid"] = true, ["assault_core_alpha"] = true },

    MetaProgressData = {
        unlockedCoreIds = { ["standard_pid"] = true },
        metaCurrency = 0,
        isCoreUnlocked = function(self, coreId)
            for idKey, _ in pairs(self.unlockedCoreIds) do -- Iterate keys if it's a map
                if idKey == coreId then return true end
            end
            return false
        end,
        unlockCore = function(self, coreId)
            if not self:isCoreUnlocked(coreId) then
                self.unlockedCoreIds[coreId] = true -- Add to map
                print("MetaProgress: Unlocked AI Core - " .. coreId)
                -- TODO: Save M.MetaProgressData to a file here
            end
        end,
        loadProgress = function(self)
            -- TODO: Load from file
            print("MetaProgress: Loaded (stub).")
        end,
        saveProgress = function(self)
            -- TODO: Save to file
            print("MetaProgress: Saved (stub).")
        end
    },

    AICoreDB = nil,
    SubroutineDB = nil,
    CoreModificationDB = nil,
    ParticleFX = nil
}

-- This function would be called from main.lua after all these are loaded
function M.initialize(refs)
    M.Config = refs.Config
    M.GameState = refs.GameState
    M.Helpers = refs.Helpers
    M.Fonts = refs.Fonts
    M.AICoreDB = refs.AICoreDB
    M.SubroutineDB = refs.SubroutineDB
    M.CoreModificationDB = refs.CoreModificationDB
    M.ParticleFX = refs.ParticleFX
    -- Shader and Canvas are set directly in main.lua's love.load/resize
    -- MetaProgressData can be loaded here
    M.MetaProgressData:loadProgress()
    print("Global context initialized.")
end

return M