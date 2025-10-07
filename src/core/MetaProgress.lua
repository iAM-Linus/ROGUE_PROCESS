-- src/core/MetaProgress.lua
local Helpers = require "src.utils.helpers" -- For deepCopy if needed for defaults
local serpent = require 'src.utils.serpent'

local MetaProgress = {
    -- Default values if no save file is found
    data = {
        selectedAICoreId = "standard_pid",
        unlockedAICoreIds = { ["standard_pid"] = true }, -- Only standard core unlocked by default
        metaCurrency = 0, -- e.g., "Archived Data Scraps"
        highestNodeReached = 0,
        -- Add any other persistent stats or flags here
        -- Example: completedTutorial = false,
        -- Example: unlockedSubroutines = { ["laser_exe"] = true } -- if some subroutines need unlocking
    },
    saveFileName = "rogue_process_meta.dat",
    isLoaded = false
}

-- Function to get a deep copy of the default data
function MetaProgress:_getDefaultData()
    return Helpers.deepCopy(self.data) -- Use deepCopy to avoid modifying the original self.data table
end

function MetaProgress:load()
    local fileData, size = love.filesystem.read(self.saveFileName)
    if fileData and size and size > 0 then
        -- Use serpent.load to deserialize the string back into a Lua table
        -- The {safe=true} option makes serpent avoid running arbitrary code.
        local success, loadedTableOrError = pcall(serpent.load, fileData, {safe = true})

        if success and type(loadedTableOrError) == "table" then
            local loadedTable = loadedTableOrError
            local defaultData = self:_getDefaultData()
            for k, v in pairs(defaultData) do
                if loadedTable[k] == nil then
                    loadedTable[k] = v
                end
            end
            self.data = loadedTable
            self.isLoaded = true
            print("MetaProgress: Loaded data from " .. self.saveFileName)
            -- For debugging, you can print the loaded structure:
            -- print("Loaded data structure:", serpent.block(self.data))
            return true
        else
            print("MetaProgress: Error loading/decoding data from " .. self.saveFileName .. ". Using defaults. Error: " .. tostring(loadedTableOrError))
            self.data = self:_getDefaultData()
        end
    else
        print("MetaProgress: No save file found or file empty (" .. self.saveFileName .. "). Using defaults.")
        self.data = self:_getDefaultData()
    end
    self.isLoaded = true
    return false
end

function MetaProgress:save()
    if not self.isLoaded then
        print("MetaProgress: Attempted to save before loading. Aborting save.")
        return false
    end
    
    -- Use serpent.dump to serialize the self.data table into a string.
    -- Options:
    --   comment = false: Don't add "-- LUA" comments.
    --   indent = "  ": Use two spaces for indentation (makes file human-readable).
    --   sortkeys = true: Good for consistency if you compare save files.
    --   compact = true: For a more compact, less readable output.
    local success, serializedDataOrError = pcall(serpent.dump, self.data, {
        comment = false, 
        sortkeys = true, 
        indent = "  ", 
        fatal = false -- if true, serpent errors on non-serializable values, if false, it might skip them or use placeholders
    })

    if success then
        local serializedData = serializedDataOrError
        if love.filesystem.write(self.saveFileName, serializedData) then
            print("MetaProgress: Data saved to " .. self.saveFileName)
            return true
        else
            print("MetaProgress: Error writing data to " .. self.saveFileName)
        end
    else
        print("MetaProgress: Error serializing data for saving. Error: " .. tostring(serializedDataOrError))
    end
    return false
end

-- === Getter and Setter examples (remain the same) ===

function MetaProgress:getSelectedAICoreId()
    return self.data.selectedAICoreId or "standard_pid"
end

function MetaProgress:setSelectedAICoreId(coreId)
    self.data.selectedAICoreId = coreId
    self:save() 
end

function MetaProgress:isCoreUnlocked(coreId)
    return self.data.unlockedAICoreIds and self.data.unlockedAICoreIds[coreId] == true
end

function MetaProgress:unlockCore(coreId)
    if not self.data.unlockedAICoreIds then self.data.unlockedAICoreIds = {} end
    if not self:isCoreUnlocked(coreId) then
        self.data.unlockedAICoreIds[coreId] = true
        print("MetaProgress: Unlocked AI Core - " .. coreId)
        self:save()
        return true
    end
    return false
end

function MetaProgress:getMetaCurrency()
    return self.data.metaCurrency or 0
end

function MetaProgress:addMetaCurrency(amount)
    self.data.metaCurrency = (self.data.metaCurrency or 0) + amount
    print("MetaProgress: Added " .. amount .. " meta currency. Total: " .. self.data.metaCurrency)
    self:save()
end

function MetaProgress:spendMetaCurrency(amount)
    if (self.data.metaCurrency or 0) >= amount then
        self.data.metaCurrency = self.data.metaCurrency - amount
        print("MetaProgress: Spent " .. amount .. " meta currency. Remaining: " .. self.data.metaCurrency)
        self:save()
        return true
    end
    return false
end

-- Add more getters/setters for other meta progress items as needed

return MetaProgress