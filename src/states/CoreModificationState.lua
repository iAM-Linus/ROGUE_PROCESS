-- src/states/CoreModificationState.lua
local BaseState = require "src.core.base_state"
local UIHelpers = require 'src.ui.ui_helpers'
local CoreModificationDB = require "src.core.CoreModificationDB"

local CoreModificationState = {}
CoreModificationState.__index = CoreModificationState
setmetatable(CoreModificationState, { __index = BaseState })

function CoreModificationState:new(game)
    local instance = BaseState.new(self, game)
    setmetatable(instance, CoreModificationState)
    instance.name = "CoreModificationState"

    instance.player = nil
    instance.availableMods = {}
    instance.selectedOption = 1
    instance.title = "CORE_MODIFICATION >> SYSTEM_UPGRADE_PROTOCOL"
    instance.scrollOffset = 0
    instance.itemsPerPage = 4
    instance.animationTime = 0

    -- Enhanced animation properties
    instance.backgroundParticles = {}
    instance.dataStreams = {}
    instance.glitchEffects = {}
    instance.selectionPulse = 0
    instance.transitionPhase = 0
    instance.isTransitioning = false

    -- Initialize background effects
    instance:initializeBackgroundEffects()

    return instance
end

function CoreModificationState:initializeBackgroundEffects()
    -- Data stream particles
    for i = 1, 50 do
        table.insert(self.backgroundParticles, {
            x = love.math.random(0, self.config.nativeResolution.width),
            y = love.math.random(0, self.config.nativeResolution.height),
            vx = love.math.random(-30, 30),
            vy = love.math.random(-50, 50),
            life = love.math.random(2, 6),
            maxLife = love.math.random(2, 6),
            alpha = love.math.random(0.1, 0.3),
            size = love.math.random(1, 3),
            char = love.math.random() < 0.5 and "0" or "1",
            color = { 0.2, 0.8, 1, 1 }
        })
    end

    -- Data streams
    for i = 1, 8 do
        table.insert(self.dataStreams, {
            x = i * (self.config.nativeResolution.width / 8),
            speed = love.math.random(20, 60),
            density = love.math.random(0.1, 0.3),
            phase = love.math.random() * math.pi * 2
        })
    end

    -- Glitch effects
    for i = 1, 15 do
        table.insert(self.glitchEffects, {
            x = love.math.random(0, self.config.nativeResolution.width),
            y = love.math.random(0, self.config.nativeResolution.height),
            width = love.math.random(50, 200),
            height = love.math.random(2, 8),
            intensity = love.math.random(0.3, 0.8),
            duration = love.math.random(0.1, 0.3),
            elapsed = 0,
            active = false
        })
    end
end

function CoreModificationState:enter(player)
    BaseState.enter(self, player)

    print("Entered Enhanced CoreModificationState")
    self.player = player

    -- Emit event
    if self.events then
        self.events:emit("core_modification_entered", {
            playerName = player and player.name or "unknown",
            availableModsCount = self.availableMods and #self.availableMods or 0
        })
    end

    if not self.player then
        print("ERROR: No player provided to CoreModificationState")
        GameState.switch("gameplay")
        return
    end

    self:refreshAvailableMods()
    self.selectedOption = 1
    self.scrollOffset = 0
    self.animationTime = 0
    self.transitionPhase = 0
    self.isTransitioning = true

    -- Trigger entrance animation
    self:triggerGlitchBurst()

    print(string.format("[CoreModState:enter] Player DF: %d, Available mods: %d",
        self.player.dataFragments, #self.availableMods))

    love.graphics.setBackgroundColor(self.config.activeColors.background)
end

function CoreModificationState:refreshAvailableMods()
    print("[CoreModState] Refreshing available mods...")
    if not self.player then
        print("ERROR: No player available for refreshing mods")
        self.availableMods = {}
        return
    end

    self.availableMods = CoreModificationDB.getAvailableForPlayer(self.player)
    print(string.format("[CoreModState] Found %d available modifications", #self.availableMods))

    -- Adjust selection bounds
    self.selectedOption = math.max(1, math.min(self.selectedOption, math.max(1, #self.availableMods)))

    -- Adjust scroll bounds
    if #self.availableMods <= self.itemsPerPage then
        self.scrollOffset = 0
    else
        self.scrollOffset = math.max(0, math.min(self.scrollOffset, #self.availableMods - self.itemsPerPage))

        if self.selectedOption > self.scrollOffset + self.itemsPerPage then
            self.scrollOffset = self.selectedOption - self.itemsPerPage
        elseif self.selectedOption < self.scrollOffset + 1 then
            self.scrollOffset = self.selectedOption - 1
        end
        self.scrollOffset = math.max(0, self.scrollOffset)
    end
end

function CoreModificationState:triggerGlitchBurst()
    for _, effect in ipairs(self.glitchEffects) do
        if love.math.random() < 0.6 then
            effect.active = true
            effect.elapsed = 0
            effect.x = love.math.random(0, self.config.nativeResolution.width)
            effect.y = love.math.random(0, self.config.nativeResolution.height)
        end
    end
end

function CoreModificationState:update(dt)
    BaseState.update(self, dt)

    if self.paused then return end

    self.animationTime = self.animationTime + dt
    self.selectionPulse = self.selectionPulse + dt * 4

    -- Handle transition animation
    if self.isTransitioning then
        self.transitionPhase = math.min(1, self.transitionPhase + dt * 3)
        if self.transitionPhase >= 1 then
            self.isTransitioning = false
        end
    end

    -- Update background particles
    for i = #self.backgroundParticles, 1, -1 do
        local particle = self.backgroundParticles[i]
        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt
        particle.life = particle.life - dt

        -- Wrap around screen
        if particle.x < -10 then particle.x = self.config.nativeResolution.width + 10 end
        if particle.x > self.config.nativeResolution.width + 10 then particle.x = -10 end
        if particle.y < -10 then particle.y = self.config.nativeResolution.height + 10 end
        if particle.y > self.config.nativeResolution.height + 10 then particle.y = -10 end

        -- Reset life if expired
        if particle.life <= 0 then
            particle.life = particle.maxLife
            particle.alpha = love.math.random(0.1, 0.3)
        end
    end

    -- Update glitch effects
    for _, effect in ipairs(self.glitchEffects) do
        if effect.active then
            effect.elapsed = effect.elapsed + dt
            if effect.elapsed >= effect.duration then
                effect.active = false
            end
        elseif love.math.random() < 0.002 then -- Random activation
            effect.active = true
            effect.elapsed = 0
            effect.x = love.math.random(0, self.config.nativeResolution.width)
            effect.y = love.math.random(0, self.config.nativeResolution.height)
        end
    end
end

function CoreModificationState:drawEnhancedBackground()
    local nativeW, nativeH = self.config.nativeResolution.width, self.config.nativeResolution.height

    -- Base background
    love.graphics.setColor(self.config.activeColors.background)
    love.graphics.rectangle("fill", 0, 0, nativeW, nativeH)

    -- Animated circuit grid
    love.graphics.setColor(self.config.activeColors.accent[1], self.config.activeColors.accent[2],
        self.config.activeColors.accent[3], 0.08)

    local gridSize = 32
    local gridOffset = self.animationTime * 10

    for x = 0, nativeW + gridSize, gridSize do
        local adjustedX = (x + gridOffset) % (nativeW + gridSize)
        love.graphics.line(adjustedX, 0, adjustedX, nativeH)
    end

    for y = 0, nativeH + gridSize, gridSize do
        local adjustedY = (y + gridOffset * 0.7) % (nativeH + gridSize)
        love.graphics.line(0, adjustedY, nativeW, adjustedY)
    end

    -- Data streams
    for _, stream in ipairs(self.dataStreams) do
        UIHelpers.drawDataStream(stream.x - 5, 0, 10, nativeH,
            stream.speed + math.sin(self.animationTime + stream.phase) * 10,
            stream.density, self.config.activeColors.accent)
    end

    -- Background particles
    love.graphics.setFont(_G.Fonts.small)
    for _, particle in ipairs(self.backgroundParticles) do
        local alpha = particle.alpha * (particle.life / particle.maxLife)
        love.graphics.setColor(particle.color[1], particle.color[2], particle.color[3], alpha)
        love.graphics.print(particle.char, particle.x, particle.y)
    end

    -- Glitch effects
    for _, effect in ipairs(self.glitchEffects) do
        if effect.active then
            local glitchAlpha = effect.intensity * (1 - effect.elapsed / effect.duration)
            love.graphics.setColor(1, 0.2, 0.8, glitchAlpha)
            love.graphics.rectangle("fill", effect.x, effect.y, effect.width, effect.height)

            -- RGB separation effect
            love.graphics.setColor(1, 0, 0, glitchAlpha * 0.5)
            love.graphics.rectangle("fill", effect.x - 2, effect.y, effect.width, effect.height)
            love.graphics.setColor(0, 1, 0, glitchAlpha * 0.5)
            love.graphics.rectangle("fill", effect.x + 2, effect.y, effect.width, effect.height)
        end
    end

    -- Transition effect
    if self.isTransitioning then
        local transitionAlpha = 1 - self.transitionPhase
        love.graphics.setColor(self.config.activeColors.accent[1], self.config.activeColors.accent[2],
            self.config.activeColors.accent[3], transitionAlpha * 0.3)

        -- Scanning lines effect
        for i = 0, 20 do
            local y = (self.transitionPhase * nativeH * 1.2) + i * 15 - nativeH * 0.1
            if y >= 0 and y <= nativeH then
                love.graphics.rectangle("fill", 0, y, nativeW, 2)
            end
        end
    end
end

function CoreModificationState:draw()
    if not self.visible then return end

    BaseState.draw(self)

    local config = self.config or _G.Config
    local fonts = self.resources and self.resources:getFonts() or _G.Fonts
    local nativeW, nativeH = config.nativeResolution.width, config.nativeResolution.height

    -- Enhanced animated background
    self:drawEnhancedBackground()

    local panelMargin = 40
    local panelX = panelMargin
    local panelY = 50
    local panelW = nativeW - 2 * panelMargin
    local panelH = nativeH - 2 * panelY - 30

    -- Main panel with enhanced styling
    local pX, pY, pW, pH = UIHelpers.drawPanel(panelX, panelY, panelW, panelH, self.title, "highlighted")

    -- Enhanced resource display with animations
    love.graphics.setFont(fonts.large)
    local resourceText = string.format("AVAILABLE_DATA_FRAGMENTS: %d", self.player and self.player.dataFragments or 0)

    -- Animated resource counter
    local resourcePulse = 0.9 + 0.1 * math.sin(self.animationTime * 3)
    local resourceColor = { config.activeColors.pickup[1] * resourcePulse,
        config.activeColors.pickup[2] * resourcePulse,
        config.activeColors.pickup[3] * resourcePulse, 1 }

    UIHelpers.drawTextWithGlow(resourceText, pX + pW / 2, pY + 20, fonts.large,
        resourceColor, "center", 0.4)

    local currentContentY = pY + 60

    if #self.availableMods == 0 then
        -- Enhanced "no mods" display
        UIHelpers.drawHolographicText(">> ALL_SYSTEMS_OPTIMIZED: No further modifications available <<",
            pX + pW / 2 - fonts.medium:getWidth(">> ALL_SYSTEMS_OPTIMIZED: No further modifications available <<") / 2,
            currentContentY + 100, fonts.medium,
            config.activeColors.text_success, self.animationTime)
    else
        -- Enhanced modification list with better visual hierarchy
        local listItems = {}
        for i, modDef in ipairs(self.availableMods) do
            local currentLevel = self.player:getCoreModificationLevel(modDef.id)
            local cost = type(modDef.cost) == "function" and modDef.cost(self.player, currentLevel + 1) or modDef.cost
            local canAfford = self.player.dataFragments >= cost

            local statusIcon = canAfford and "✓" or "✗"
            local levelText = string.format("Lv.%d/%d", currentLevel, (modDef.maxLevel or 1))
            local mainText = string.format("%s [%d DF] %s %s", statusIcon, cost, modDef.name, levelText)
            local detailText = modDef.description

            -- Add prerequisites info if any
            if modDef.prerequisites then
                detailText = detailText .. "\
   REQ: "
                for pi, pId in ipairs(modDef.prerequisites) do
                    local prereqMod = CoreModificationDB.getById(pId)
                    detailText = detailText .. prereqMod.name
                    if pi < #modDef.prerequisites then detailText = detailText .. ", " end
                end
            end

            -- Add tags info
            if modDef.tags then
                detailText = detailText .. "\
   TAGS: " .. table.concat(modDef.tags, ", ")
            end

            table.insert(listItems, {
                text = mainText .. "\
" .. detailText,
                disabled = not canAfford,
                isAffordable = canAfford
            })
        end

        love.graphics.setFont(fonts.small)
        local itemHeight = 80
        self:drawEnhancedSelectableList(listItems, self.selectedOption,
            pX + 20, currentContentY, pW - 40,
            itemHeight, self.itemsPerPage, self.scrollOffset)
    end

    -- Enhanced controls with pulsing effect
    local controlsY = nativeH - 35
    local controlsPulse = 0.7 + 0.3 * math.sin(self.animationTime * 2)
    local controlsColor = { config.activeColors.ui_text_dim[1] * controlsPulse,
        config.activeColors.ui_text_dim[2] * controlsPulse,
        config.activeColors.ui_text_dim[3] * controlsPulse, 1 }

    UIHelpers.drawTextWithGlow("INTERFACE: ↑↓ Navigate | ENTER Purchase | ESC Return",
        nativeW / 2, controlsY, fonts.small,
        controlsColor, "center", 0.2)
end

function CoreModificationState:drawEnhancedSelectableList(items, selectedIndex, x, y, width, itemHeight, maxVisibleItems,
                                                          scrollOffset)
    scrollOffset = scrollOffset or 0
    maxVisibleItems = maxVisibleItems or #items

    -- Enhanced background for the list area
    local listBgColor = { self.config.activeColors.background[1], self.config.activeColors.background[2],
        self.config.activeColors.background[3], 0.6 }
    love.graphics.setColor(listBgColor)
    UIHelpers.drawRoundedRect(x - 10, y - 5, width + 20, maxVisibleItems * itemHeight + 10, 8, "fill")

    for i = 1, maxVisibleItems do
        local itemActualIndex = i + scrollOffset

        if itemActualIndex > #items then break end

        local item = items[itemActualIndex]
        local currentY = y + (i - 1) * itemHeight
        local displayText = item.text
        local isSelected = (itemActualIndex == selectedIndex)

        -- Enhanced selection highlighting with multiple effects
        if isSelected then
            local pulse = 0.7 + 0.3 * math.sin(self.selectionPulse)
            local slideOffset = math.sin(self.animationTime * 4) * 3

            -- Multi-layer selection background
            local highlightColor = self.config.activeColors.highlight

            -- Outer glow with animation
            love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], 0.3 * pulse)
            UIHelpers.drawRoundedRect(x - 12, currentY - 6, width + 24, itemHeight + 4, 6, "fill")

            -- Main selection background with slide animation
            local selectionAlpha = 0.5 * pulse
            love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], selectionAlpha)
            UIHelpers.drawRoundedRect(x - 8 + slideOffset, currentY - 3, width + 16, itemHeight, 4, "fill")

            -- Selection border with animated intensity
            love.graphics.setColor(highlightColor[1] * pulse, highlightColor[2] * pulse, highlightColor[3] * pulse, 0.9)
            UIHelpers.drawRoundedRect(x - 8 + slideOffset, currentY - 3, width + 16, itemHeight, 4, "line")

            -- Animated selection indicators
            love.graphics.setColor(highlightColor)
            love.graphics.setFont(_G.Fonts.medium)
            local indicatorAlpha = 0.8 + 0.2 * math.sin(self.animationTime * 6)
            love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], indicatorAlpha)
            love.graphics.print(">>", x - 25, currentY + itemHeight / 2 - _G.Fonts.medium:getHeight() / 2)
            love.graphics.print("<<", x + width + 8, currentY + itemHeight / 2 - _G.Fonts.medium:getHeight() / 2)

            -- Particle effects for selected item
            for j = 1, 4 do
                local particleAngle = self.animationTime * 2 + j * (math.pi / 2)
                local particleRadius = 8 + math.sin(self.animationTime * 3 + j) * 4
                local particleX = x + width / 2 + math.cos(particleAngle) * particleRadius
                local particleY = currentY + itemHeight / 2 + math.sin(particleAngle) * particleRadius

                love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], 0.6)
                love.graphics.circle("fill", particleX, particleY, 1)
            end

            displayText = ">> " .. displayText
        elseif item.disabled then
            -- Enhanced disabled state
            local disabledPulse = 0.3 + 0.1 * math.sin(self.animationTime + itemActualIndex)
            love.graphics.setColor(0.4, 0.4, 0.4, disabledPulse)
            UIHelpers.drawRoundedRect(x - 4, currentY - 1, width + 8, itemHeight - 2, 2, "fill")
            love.graphics.setColor(0.6, 0.4, 0.4, 1)
        else
            -- Subtle hover effect for non-selected items
            local hoverAlpha = 0.08 + 0.04 * math.sin(self.animationTime * 2 + itemActualIndex)
            love.graphics.setColor(self.config.activeColors.text[1], self.config.activeColors.text[2],
                self.config.activeColors.text[3], hoverAlpha)
            UIHelpers.drawRoundedRect(x - 4, currentY - 1, width + 8, itemHeight - 2, 2, "fill")

            -- Color based on affordability
            if item.isAffordable then
                love.graphics.setColor(self.config.activeColors.text)
            else
                love.graphics.setColor(self.config.activeColors.text_warning)
            end
        end

        -- Multi-line text with enhanced formatting
        love.graphics.setFont(_G.Fonts.small)

        -- Text shadow for better readability
        if isSelected then
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.printf(displayText, x + 2, currentY + 2, width, "left")
        end

        -- Main text with appropriate coloring
        love.graphics.printf(displayText, x, currentY, width, "left")
    end

    -- Enhanced scrollbar
    if #items > maxVisibleItems then
        local scrollbarX = x + width + 15
        local scrollbarWidth = 8
        local scrollbarHeight = maxVisibleItems * itemHeight

        -- Animated track
        local trackPulse = 0.3 + 0.1 * math.sin(self.animationTime * 2)
        love.graphics.setColor(self.config.activeColors.accent[1], self.config.activeColors.accent[2],
            self.config.activeColors.accent[3], trackPulse)
        UIHelpers.drawRoundedRect(scrollbarX, y, scrollbarWidth, scrollbarHeight, 4, "fill")

        -- Track border with glow
        love.graphics.setColor(self.config.activeColors.accent[1], self.config.activeColors.accent[2],
            self.config.activeColors.accent[3], 0.8)
        UIHelpers.drawRoundedRect(scrollbarX, y, scrollbarWidth, scrollbarHeight, 4, "line")

        -- Animated thumb
        local thumbHeight = math.max(24, scrollbarHeight * (maxVisibleItems / #items))
        local scrollableRange = #items - maxVisibleItems
        local thumbY = y
        if scrollableRange > 0 then
            thumbY = y + (scrollOffset / scrollableRange) * (scrollbarHeight - thumbHeight)
        end

        -- Thumb with enhanced animation
        local thumbPulse = 0.8 + 0.4 * math.sin(self.animationTime * 3)
        love.graphics.setColor(self.config.activeColors.highlight[1] * thumbPulse,
            self.config.activeColors.highlight[2] * thumbPulse,
            self.config.activeColors.highlight[3] * thumbPulse, 0.9)
        UIHelpers.drawRoundedRect(scrollbarX, thumbY, scrollbarWidth, thumbHeight, 4, "fill")

        -- Thumb highlight with flow effect
        local flowOffset = (self.animationTime * 20) % thumbHeight
        love.graphics.setColor(1, 1, 1, 0.4)
        love.graphics.rectangle("fill", scrollbarX + 1, thumbY + flowOffset - 8, scrollbarWidth - 2, 16)
    end
end

function CoreModificationState:keypressed(key)
    print(string.format("[CoreModState:keypressed] Key: %s, #availableMods: %d, selectedOption: %d",
        key, #self.availableMods, self.selectedOption))

    -- Block input during transition
    if self.isTransitioning then return true end

    -- Handle case where no mods are available
    if #self.availableMods == 0 then
        if key == "escape" then
            -- Emit event
            if self.events then
                self.events:emit("core_modification_cancelled", { reason = "no_mods" })
            end

            -- Return to gameplay
            self.stateManager:pop()
        end
        return true
    end

    local oldSelected = self.selectedOption
    local oldScroll = self.scrollOffset

    if key == "up" then
        self.selectedOption = math.max(1, self.selectedOption - 1)
        if self.selectedOption < self.scrollOffset + 1 then
            self.scrollOffset = math.max(0, self.selectedOption - 1)
        end
        _G.SFX.play("ui_navigate")
        self:triggerSelectionEffect()
    elseif key == "down" then
        self.selectedOption = math.min(#self.availableMods, self.selectedOption + 1)
        if self.selectedOption > self.scrollOffset + self.itemsPerPage then
            self.scrollOffset = math.min(#self.availableMods - self.itemsPerPage, self.selectedOption - self
                .itemsPerPage)
            self.scrollOffset = math.max(0, self.scrollOffset)
        end
        _G.SFX.play("ui_navigate")
        self:triggerSelectionEffect()
    elseif key == "return" or key == "kpenter" then
        local modDef = self.availableMods[self.selectedOption]
        if modDef then
            local currentLevel = self.player:getCoreModificationLevel(modDef.id)
            local cost = type(modDef.cost) == "function" and modDef.cost(self.player, currentLevel + 1) or modDef.cost

            print(string.format("[CoreModState] Attempting to purchase: %s (Cost: %d, Player DF: %d)",
                modDef.name, cost, self.player.dataFragments))

            local success, message = self.player:purchaseCoreModification(modDef.id)
            print(string.format("[CoreModState] Purchase result: success=%s, message=%s", tostring(success), message))

            -- Emit event
            if self.events then
                if success then
                    self.events:emit("core_modification_purchased", {
                        modificationId = modDef.id,
                        modificationName = modDef.name,
                        cost = cost,
                        message = message
                    })
                else
                    self.events:emit("core_modification_purchase_failed", {
                        modificationId = modDef.id,
                        reason = message,
                        message = message
                    })
                end
            end

            ---- Log message to gameplay if available
            --local gameplay = _G.GameState and _G.GameState.get("gameplay") or nil
            --if gameplay and gameplay.logMessage then
            --    local config = self.config or _G.Config
            --    gameplay:logMessage(message, success and config.activeColors.pickup or { 1, 0.5, 0.5, 1 })
            --end

            if success then
                _G.SFX.play("ui_select")
                self:refreshAvailableMods()
                self:triggerPurchaseEffect()
            else
                _G.SFX.play("ui_error")
                self:triggerErrorEffect()
            end
        end
    elseif key == "escape" then
        _G.SFX.play("ui_back")

        -- Emit event
        if self.events then
            self.events:emit("core_modification_cancelled", { reason = "user_escape" })
        end

        -- Return to gameplay
        self.stateManager:pop()
    end

    return true
end

function CoreModificationState:triggerSelectionEffect()
    -- Reset selection pulse for smooth animation
    self.selectionPulse = 0
end

function CoreModificationState:triggerPurchaseEffect()
    -- Trigger glitch burst for successful purchase
    self:triggerGlitchBurst()

    -- Add some particle effects
    for i = 1, 10 do
        table.insert(self.backgroundParticles, {
            x = self.config.nativeResolution.width / 2,
            y = self.config.nativeResolution.height / 2,
            vx = love.math.random(-100, 100),
            vy = love.math.random(-100, 100),
            life = 2,
            maxLife = 2,
            alpha = 0.8,
            size = 2,
            char = "✓",
            color = self.config.activeColors.pickup
        })
    end
end

function CoreModificationState:triggerErrorEffect()
    -- Trigger red glitch effects for errors
    for _, effect in ipairs(self.glitchEffects) do
        if love.math.random() < 0.4 then
            effect.active = true
            effect.elapsed = 0
            effect.intensity = 1.0
        end
    end
end

function CoreModificationState:leave()
    print("Left Enhanced CoreModificationState")
    
    -- Emit event
    if self.events then
        self.events:emit("core_modification_left", {})
    end
    
    self.player = nil
    
    BaseState.leave(self)
end

return CoreModificationState
