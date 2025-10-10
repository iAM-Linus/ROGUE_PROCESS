-- src/core/enemies/Sector1Guardian.lua
local Boss = require "src.core.bosses.Boss"

local Sector1Guardian = {}
Sector1Guardian.__index = Sector1Guardian
setmetatable(Sector1Guardian, {__index = Boss})

function Sector1Guardian:new(x, y)
    -- Call the Boss constructor
    -- The bossId "sector_1_guardian" must match a key in BossBehaviorDB.Behaviors
    local instance = Boss:new(x, y, "B", {1,0.1,0.1,1}, "SECTOR_1_GUARDIAN", 150, "sector_1_guardian")
    setmetatable(instance, Sector1Guardian)

    instance.dataFragmentsValue = 100 -- Override from Boss/Enemy

    -- Any other specific properties for this guardian
    return instance
end

-- It can inherit act() and executePlannedAction() from Boss.lua if the behavior
-- defined in BossBehaviorDB is sufficient and uses generic action types.
-- If it needs very unique execution logic not covered by the DB's execute functions,
-- you can override executePlannedAction here.

return Sector1Guardian