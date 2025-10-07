-- src/core/managers/HUDManager.lua - Modernized version
local Helpers = require 'src.utils.Helpers'
local UIHelpers = require "src.ui.ui_helpers"

local HUDManager = {}
HUDManager.__index = HUDManager

function HUDManager:new()
    local instance = setmetatable({}, HUDManager)
    instance.animationTime = 0
    instance.statusEffectTimer = 0
    instance.minimapPulse = 0
    print("Modern HUDManager initialized.")
    return instance
end

function HUDManager:update(dt)
    self.animationTime = self.animationTime + dt
    self.statusEffectTimer = self.statusEffectTimer + dt
    self.minimapPulse = self.minimapPulse + dt * 2
end

function HUDManager:draw(player, map, turnManager, gameMessageLog,
                       currentMode, lookCursor, targetCursor, targetingSubroutine,
                       currentSector, currentFloorInSector, systemCorruptionPercent)
    if not player or not map or not turnManager then return end

    local nativeW, nativeH = _G.Config.nativeResolution.width, _G.Config.nativeResolution.height
    local fontMedium = _G.Fonts.medium
    local fontSmall = _G.Fonts.small
    local outerPadding = 8
    local panelPadding = 6

    -- === 1. TOP BAR - Player Status ===
    self:drawTopStatusBar(player, currentSector, currentFloorInSector, systemCorruptionPercent, 
                         nativeW, fontMedium, fontSmall, outerPadding)

    -- === 2. BOTTOM BAR - Message Log + Controls ===
    self:drawBottomBar(gameMessageLog, nativeW, nativeH, fontSmall, outerPadding, panelPadding)

    -- === 3. RIGHT SIDEBAR ===
    self:drawRightSidebar(player, map, turnManager, currentMode, lookCursor, targetCursor, 
                         targetingSubroutine, nativeW, nativeH, fontSmall, outerPadding, panelPadding)
end

function HUDManager:drawTopStatusBar(player, currentSector, currentFloorInSector, systemCorruptionPercent, 
                                   nativeW, fontMedium, fontSmall, outerPadding)
    local topBarHeight = 50
    local topBarY = outerPadding
    
    -- Main status panel
    local contentX, contentY, contentW, contentH = UIHelpers.drawPanel(
        outerPadding, topBarY, nativeW - 2 * outerPadding, topBarHeight, nil, "compact"
    )
    
    -- Player stats with visual bars
    local statY = contentY + 5
    local barHeight = 8
    local barSpacing = 20
    
    -- Health bar
    local healthPercent = player.hp / player.maxHp
    local healthColor = {0.8, 0.3, 0.3, 1}
    if healthPercent > 0.7 then healthColor = {0.3, 0.8, 0.3, 1}
    elseif healthPercent > 0.3 then healthColor = {0.8, 0.8, 0.3, 1} end
    
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(_G.Config.activeColors.text)
    love.graphics.print("INT", contentX, statY - 2)
    
    UIHelpers.drawProgressBar(contentX + 25, statY, 100, barHeight, healthPercent, healthColor)
    
    love.graphics.setColor(_G.Config.activeColors.text)
    love.graphics.print(string.format("%d/%d", player.hp, player.maxHp), contentX + 130, statY - 2)
    
    -- CPU bar
    local cpuPercent = player.cpuCycles / player.maxCPUCycles
    local cpuColor = {0.3, 0.7, 1.0, 1}
    
    love.graphics.print("CPU", contentX + 200, statY - 2)
    UIHelpers.drawProgressBar(contentX + 225, statY, 100, barHeight, cpuPercent, cpuColor)
    love.graphics.print(string.format("%d/%d (+%d)", player.cpuCycles, player.maxCPUCycles, player.cpuRegenRate), 
                       contentX + 330, statY - 2)
    
    -- Additional info on second line
    local infoY = statY + barHeight + 8
    love.graphics.setColor(_G.Config.activeColors.accent)
    love.graphics.print(string.format("DATA: %d | NODE: S%d-F%d | SYS_CORRUPT: %d%%", 
                       player.dataFragments, currentSector, currentFloorInSector, systemCorruptionPercent), 
                       contentX, infoY)
    
    -- Status effects with animations
    if player and #player.activeStatusEffects > 0 then
        local effectX = contentX + 450
        for i, effect in ipairs(player.activeStatusEffects) do
            local effectColor = _G.Config.activeColors.highlight
            local pulse = 0.7 + 0.3 * math.sin(self.statusEffectTimer * 2 + i)
            
            love.graphics.setColor(effectColor[1] * pulse, effectColor[2] * pulse, effectColor[3] * pulse, 1)
            
            local effectText = (effect.name or effect.id)
            if effect.duration then effectText = effectText .. "(" .. effect.duration .. ")" end
            if effect.id == "shield" and effect.data and effect.data.amount then
                effectText = effectText .. "[" .. effect.data.amount .. "]"
            end
            
            love.graphics.print(effectText, effectX, statY - 2)
            effectX = effectX + fontSmall:getWidth(effectText) + 10
        end
    end
end

function HUDManager:drawBottomBar(gameMessageLog, nativeW, nativeH, fontSmall, outerPadding, panelPadding)
    local bottomBarHeight = 80
    local bottomBarY = nativeH - bottomBarHeight - outerPadding
    
    -- Message log panel (70% width)
    local logWidth = math.floor(nativeW * 0.7) - outerPadding
    local logContentX, logContentY, logContentW, logContentH = UIHelpers.drawPanel(
        outerPadding, bottomBarY, logWidth, bottomBarHeight, "EVENT_LOG", "default"
    )
    
    -- Draw messages with fade effect
    love.graphics.setFont(fontSmall)
    local lineHeight = fontSmall:getHeight() + 2
    local maxLines = math.floor(logContentH / lineHeight)
    
    for i = 1, math.min(#gameMessageLog, maxLines) do
        local entry = gameMessageLog[i]
        local alpha = 1.0 - (i - 1) * 0.15 -- Fade older messages
        local messageColor = {
            (entry.color and entry.color[1] or 1) * alpha,
            (entry.color and entry.color[2] or 1) * alpha,
            (entry.color and entry.color[3] or 1) * alpha,
            alpha
        }
        
        love.graphics.setColor(messageColor)
        local messageY = logContentY + (i - 1) * lineHeight
        love.graphics.printf(entry.text or "[nil]", logContentX, messageY, logContentW, "left")
    end
    
    -- Controls panel (30% width)
    local controlsX = logWidth + outerPadding * 2
    local controlsWidth = nativeW - controlsX - outerPadding
    local controlsContentX, controlsContentY, controlsContentW, controlsContentH = UIHelpers.drawPanel(
        controlsX, bottomBarY, controlsWidth, bottomBarHeight, "CONTROLS", "compact"
    )
    
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(_G.Config.activeColors.ui_text_dim)
    
    local controls = {
        "↑↓←→ Move",
        "1-4 Subroutines", 
        "X Look Mode",
        "C Core Mods",
        "SPC Wait"
    }
    
    for i, control in ipairs(controls) do
        love.graphics.print(control, controlsContentX, controlsContentY + (i - 1) * (fontSmall:getHeight() + 1))
    end
end

function HUDManager:drawRightSidebar(player, map, turnManager, currentMode, lookCursor, targetCursor, 
                                   targetingSubroutine, nativeW, nativeH, fontSmall, outerPadding, panelPadding)
    local sidebarWidth = 200
    local sidebarX = nativeW - sidebarWidth - outerPadding
    local topBarHeight = 60
    local bottomBarHeight = 90
    local sidebarY = topBarHeight + outerPadding
    local sidebarHeight = nativeH - topBarHeight - bottomBarHeight - outerPadding * 3
    
    local currentY = sidebarY
    
    -- === MINIMAP ===
    local minimapHeight = 120
    local mmContentX, mmContentY, mmContentW, mmContentH = UIHelpers.drawPanel(
        sidebarX, currentY, sidebarWidth, minimapHeight, "NAV-SCAN", "default"
    )
    
    self:drawMinimap(map, player, turnManager, mmContentX, mmContentY, mmContentW, mmContentH)
    currentY = currentY + minimapHeight + 10
    
    -- === SUBROUTINES ===
    local subHeight = 140
    if currentY + subHeight < nativeH - bottomBarHeight - outerPadding then
        local subContentX, subContentY, subContentW, subContentH = UIHelpers.drawPanel(
            sidebarX, currentY, sidebarWidth, subHeight, "SUBROUTINES", "default"
        )
        
        self:drawSubroutineList(player, currentMode, targetingSubroutine, 
                               subContentX, subContentY, subContentW, subContentH, fontSmall)
        currentY = currentY + subHeight + 10
    end
    
    -- === TARGET/LOOK INFO ===
    local remainingHeight = nativeH - bottomBarHeight - outerPadding - currentY
    if remainingHeight > 60 then
        self:drawInspectionPanel(map, currentMode, lookCursor, targetCursor, 
                               sidebarX, currentY, sidebarWidth, remainingHeight, fontSmall)
    end
end

function HUDManager:drawMinimap(map, player, turnManager, x, y, width, height)
    local tileSize = math.max(2, math.min(width / map.width, height / map.height))
    local mapPixelW = map.width * tileSize
    local mapPixelH = map.height * tileSize
    local offsetX = x + (width - mapPixelW) / 2
    local offsetY = y + (height - mapPixelH) / 2
    
    -- Map background
    love.graphics.setColor(0.1, 0.1, 0.15, 0.8)
    love.graphics.rectangle("fill", offsetX, offsetY, mapPixelW, mapPixelH)
    
    -- Draw tiles
    for mapY = 1, map.height do
        for mapX = 1, map.width do
            local tileX = offsetX + (mapX - 1) * tileSize
            local tileY = offsetY + (mapY - 1) * tileSize
            
            if map:isExplored(mapX, mapY) then
                local tile = map:getTile(mapX, mapY)
                local tileColor = tile.color
                
                if map:isInFov(mapX, mapY) then
                    love.graphics.setColor(tileColor[1] * 1.2, tileColor[2] * 1.2, tileColor[3] * 1.2, 1)
                else
                    love.graphics.setColor(tileColor[1] * 0.6, tileColor[2] * 0.6, tileColor[3] * 0.6, 0.8)
                end
                
                love.graphics.rectangle("fill", tileX, tileY, tileSize, tileSize)
                
                -- Exit portal
                if mapX == map.exitPortal.x and mapY == map.exitPortal.y and map:isInFov(mapX, mapY) and map.exitPortal.active then
                    local pulse = 0.7 + 0.3 * math.sin(self.minimapPulse)
                    love.graphics.setColor(_G.Config.activeColors.accent[1] * pulse, 
                                          _G.Config.activeColors.accent[2] * pulse, 
                                          _G.Config.activeColors.accent[3] * pulse, 1)
                    love.graphics.rectangle("fill", tileX, tileY, tileSize, tileSize)
                end
            end
        end
    end
    
    -- Player (pulsing)
    if player then
        local pulse = 0.8 + 0.4 * math.sin(self.animationTime * 3)
        love.graphics.setColor(_G.Config.activeColors.player[1] * pulse, 
                              _G.Config.activeColors.player[2] * pulse, 
                              _G.Config.activeColors.player[3] * pulse, 1)
        local playerX = offsetX + (player.x - 1) * tileSize
        local playerY = offsetY + (player.y - 1) * tileSize
        UIHelpers.drawRoundedRect(playerX, playerY, tileSize, tileSize, tileSize/3, "fill")
    end
    
    -- Enemies
    love.graphics.setColor(_G.Config.activeColors.enemy)
    for _, entity in ipairs(turnManager:getEntities()) do
        if entity ~= player and not entity.isDead and map:isInFov(entity.x, entity.y) then
            local enemyX = offsetX + (entity.x - 1) * tileSize
            local enemyY = offsetY + (entity.y - 1) * tileSize
            love.graphics.rectangle("fill", enemyX, enemyY, tileSize, tileSize)
        end
    end
    
    -- Pickups
    love.graphics.setColor(_G.Config.activeColors.pickup)
    for _, entity in ipairs(map:getAllEntities()) do
        if entity.isPickup and map:isInFov(entity.x, entity.y) then
            local pickupX = offsetX + (entity.x - 1) * tileSize
            local pickupY = offsetY + (entity.y - 1) * tileSize
            love.graphics.circle("fill", pickupX + tileSize/2, pickupY + tileSize/2, tileSize/3)
        end
    end
end

function HUDManager:drawSubroutineList(player, currentMode, targetingSubroutine, x, y, width, height, font)
    love.graphics.setFont(font)
    local lineHeight = font:getHeight() + 4
    local gameplayState = _G.GameState.current()
    
    for i = 1, player.maxSubroutines do
        local sub = player.subroutines[i]
        local slotY = y + (i - 1) * lineHeight
        
        -- Slot background
        local slotColor = {0.15, 0.15, 0.2, 0.5}
        if sub then slotColor = {0.2, 0.25, 0.3, 0.7} end
        
        love.graphics.setColor(slotColor)
        UIHelpers.drawRoundedRect(x, slotY, width, lineHeight - 2, 3, "fill")
        
        -- Slot number
        love.graphics.setColor(_G.Config.activeColors.accent)
        love.graphics.print("[" .. i .. "]", x + 4, slotY + 2)
        
        if sub then
            local subName = sub:getName():gsub(" Lvl.%d", "")
            local actualCost = sub:getActualCpuCost(player)
            local canAfford = player.cpuCycles >= actualCost
            local isOnCooldown = sub.currentCooldown > 0
            
            local textColor = _G.Config.activeColors.ui_text_dim
            local statusText = ""
            
            if currentMode == gameplayState.Mode.TARGETING and targetingSubroutine == sub then
                textColor = _G.Config.activeColors.highlight
                statusText = " (TARGETING)"
            elseif isOnCooldown then
                textColor = {0.6, 0.6, 0.6, 1}
                statusText = string.format(" [CD:%d]", sub.currentCooldown)
            elseif not canAfford then
                textColor = {0.8, 0.5, 0.5, 1}
                statusText = string.format(" (CPU:%d!)", actualCost)
            else
                textColor = _G.Config.activeColors.player
                statusText = string.format(" (%d)", actualCost)
            end
            
            love.graphics.setColor(textColor)
            love.graphics.print(subName .. statusText, x + 30, slotY + 2)
            
            -- Cooldown indicator
            if isOnCooldown then
                local cdPercent = sub.currentCooldown / (sub.definition.cooldown or 1)
                UIHelpers.drawProgressBar(x + width - 40, slotY + 2, 35, lineHeight - 6, 
                                        1 - cdPercent, {0.8, 0.4, 0.4, 0.8})
            end
        else
            love.graphics.setColor(_G.Config.activeColors.ui_text_dim)
            love.graphics.print("---- EMPTY ----", x + 30, slotY + 2)
        end
    end
end

function HUDManager:drawInspectionPanel(map, currentMode, lookCursor, targetCursor, x, y, width, height, font)
    local entityToInspect = nil
    local panelTitle = "SCAN_DATA"
    local targetX, targetY = nil, nil
    
    if currentMode == _G.GameState.current().Mode.LOOKING and lookCursor and lookCursor.visible then
        entityToInspect = map:getEntityAt(lookCursor.x, lookCursor.y)
        panelTitle = entityToInspect and entityToInspect.name or string.format("TILE (%d,%d)", lookCursor.x, lookCursor.y)
        targetX, targetY = lookCursor.x, lookCursor.y
    elseif currentMode == _G.GameState.current().Mode.TARGETING and targetCursor and targetCursor.visible then
        entityToInspect = map:getEntityAt(targetCursor.x, targetCursor.y)
        panelTitle = entityToInspect and entityToInspect.name or string.format("TARGET (%d,%d)", targetCursor.x, targetCursor.y)
        targetX, targetY = targetCursor.x, targetCursor.y
    end
    
    if not targetX then return end
    
    local contentX, contentY, contentW, contentH = UIHelpers.drawPanel(x, y, width, height, panelTitle, "highlighted")
    
    love.graphics.setFont(font)
    local lineHeight = font:getHeight() + 2
    local currentLine = 0
    
    if entityToInspect and entityToInspect.hp then
        love.graphics.setColor(_G.Config.activeColors.text)
        love.graphics.print("HP: " .. entityToInspect.hp .. "/" .. entityToInspect.maxHp, 
                           contentX, contentY + currentLine * lineHeight)
        currentLine = currentLine + 1
        
        -- HP bar
        local hpPercent = entityToInspect.hp / entityToInspect.maxHp
        local hpColor = {0.8, 0.3, 0.3, 1}
        UIHelpers.drawProgressBar(contentX, contentY + currentLine * lineHeight, 
                                contentW - 10, 6, hpPercent, hpColor)
        currentLine = currentLine + 1
        
        -- Status effects
        if #entityToInspect.activeStatusEffects > 0 then
            love.graphics.setColor(_G.Config.activeColors.accent)
            love.graphics.print("Effects:", contentX, contentY + currentLine * lineHeight)
            currentLine = currentLine + 1
            
            for _, effect in ipairs(entityToInspect.activeStatusEffects) do
                local effectText = (effect.name or effect.id) .. " (" .. effect.duration .. ")"
                love.graphics.setColor(_G.Config.activeColors.ui_text_default)
                love.graphics.print("• " .. effectText, contentX + 8, contentY + currentLine * lineHeight)
                currentLine = currentLine + 1
            end
        end
    else
        -- Tile info
        local tile = map:getTile(targetX, targetY)
        love.graphics.setColor(_G.Config.activeColors.text)
        love.graphics.print("Terrain: " .. (tile.walkable and "Floor" or "Wall"), 
                           contentX, contentY + currentLine * lineHeight)
        currentLine = currentLine + 1
        love.graphics.print("LOS: " .. (tile.transparent and "Clear" or "Blocked"), 
                           contentX, contentY + currentLine * lineHeight)
    end
end

return HUDManager