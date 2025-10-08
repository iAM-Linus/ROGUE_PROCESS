-- src/states/SubroutineChoiceState.lua - Enhanced with modern animations and visuals
local SubroutineDB = require "src.core.SubroutineDB"
local UIHelpers = require "src.ui.ui_helpers"
local BaseState = require "src.core.base_state"

local SubroutineChoiceState = {}
SubroutineChoiceState.__index = SubroutineChoiceState
setmetatable(SubroutineChoiceState, { __index = BaseState })

function SubroutineChoiceState:new(game)
    local instance = BaseState.new(self, game)
    setmetatable(instance, SubroutineChoiceState)
    instance.name = "SubroutineChoiceState"
    instance.player = nil
    instance.choices = {}
    instance.displayListItems = {}
    instance.selectedOption = 1
    instance.title = "SUBROUTINE_CACHE >> INTEGRATION_PROTOCOL"
    instance.scrollOffset = 0
    instance.itemsPerPage = 3
    instance.animationTime = 0

    -- Enhanced animation properties
    instance.scanlineEffect = 0
    instance.matrixRain = {}
    instance.integrationBeam = {
        active = false,
        progress = 0,
        intensity = 0
    }
    instance.hologramEffects = {}
    instance.dataFlowParticles = {}
    instance.transitionPhase = 0
    instance.isTransitioning = false
    instance.selectionGlow = 0
    instance.cacheAnalysis = {
        active = false,
        progress = 0,
        scanLines = {}
    }

    -- Initialize visual effects
    instance:initializeVisualEffects()

    return instance
end

function SubroutineChoiceState:initializeVisualEffects()
    -- Matrix rain effect
    local nativeW = self.config.nativeResolution.width
    local nativeH = self.config.nativeResolution.height

    for i = 1, 25 do
        table.insert(self.matrixRain, {
            x = love.math.random(0, nativeW),
            y = love.math.random(-nativeH, 0),
            speed = love.math.random(50, 150),
            length = love.math.random(10, 30),
            chars = {},
            alpha = love.math.random(0.3, 0.8)
        })

        -- Generate character trail for each rain drop
        local rainDrop = self.matrixRain[#self.matrixRain]
        for j = 1, rainDrop.length do
            table.insert(rainDrop.chars, {
                char = love.math.random() < 0.7 and string.char(love.math.random(65, 90)) or
                    (love.math.random() < 0.5 and "0" or "1"),
                brightness = 1 - (j / rainDrop.length) * 0.8
            })
        end
    end

    -- Data flow particles
    for i = 1, 40 do
        table.insert(self.dataFlowParticles, {
            x = love.math.random(0, nativeW),
            y = love.math.random(0, nativeH),
            vx = love.math.random(-30, 30),
            vy = love.math.random(-20, 20),
            life = love.math.random(3, 7),
            maxLife = love.math.random(3, 7),
            size = love.math.random(1, 3),
            char = love.math.random() < 0.3 and "●" or "○",
            color = self.config.activeColors.accent,
            trail = {}
        })
    end

    -- Hologram effects
    for i = 1, 5 do
        table.insert(self.hologramEffects, {
            x = love.math.random(50, nativeW - 50),
            y = love.math.random(100, nativeH - 100),
            width = love.math.random(80, 150),
            height = love.math.random(20, 40),
            phase = love.math.random() * math.pi * 2,
            intensity = love.math.random(0.2, 0.6),
            flicker = 0
        })
    end

    -- Cache analysis scan lines
    for i = 1, 8 do
        table.insert(self.cacheAnalysis.scanLines, {
            y = i * (nativeH / 8),
            speed = love.math.random(20, 60),
            intensity = love.math.random(0.3, 0.8)
        })
    end
end

function SubroutineChoiceState:enter(player)
    BaseState.enter(self, player)
    print("Entered Enhanced SubroutineChoiceState")
    self.player = player
    self:generateAndFormatChoices()
    self.selectedOption = 1
    self.scrollOffset = 0
    self.animationTime = 0
    self.transitionPhase = 0
    self.isTransitioning = true
    self.selectionGlow = 0

    -- Start cache analysis animation
    self.cacheAnalysis.active = true
    self.cacheAnalysis.progress = 0

    love.graphics.setBackgroundColor(self.config.activeColors.background)

    if self.events then
        self.events:emit("subroutine_choice_entered", {
            playerName = player and player.name or "unknown"
        })
    end
end

function SubroutineChoiceState:update(dt)
    BaseState.update(self, dt)

    if self.paused then return end

    self.animationTime = self.animationTime + dt
    self.scanlineEffect = self.scanlineEffect + dt * 3
    self.selectionGlow = self.selectionGlow + dt * 4

    -- Handle transition animation
    if self.isTransitioning then
        self.transitionPhase = math.min(1, self.transitionPhase + dt * 2.5)
        if self.transitionPhase >= 0.8 then
            self.isTransitioning = false
        end
    end

    -- Update cache analysis
    if self.cacheAnalysis.active then
        self.cacheAnalysis.progress = math.min(1, self.cacheAnalysis.progress + dt * 0.8)
        if self.cacheAnalysis.progress >= 1 then
            self.cacheAnalysis.active = false
        end
    end

    -- Update matrix rain
    for _, drop in ipairs(self.matrixRain) do
        drop.y = drop.y + drop.speed * dt

        -- Randomly change characters
        if love.math.random() < 0.1 then
            for _, charData in ipairs(drop.chars) do
                if love.math.random() < 0.3 then
                    charData.char = love.math.random() < 0.7 and string.char(love.math.random(65, 90)) or
                        (love.math.random() < 0.5 and "0" or "1")
                end
            end
        end

        -- Reset if off screen
        if drop.y > self.config.nativeResolution.height + drop.length * 15 then
            drop.y = -drop.length * 15
            drop.x = love.math.random(0, self.config.nativeResolution.width)
        end
    end

    -- Update data flow particles
    for i = #self.dataFlowParticles, 1, -1 do
        local particle = self.dataFlowParticles[i]

        -- Add to trail
        table.insert(particle.trail, 1, { x = particle.x, y = particle.y, alpha = 1 })
        if #particle.trail > 8 then
            table.remove(particle.trail)
        end

        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt
        particle.life = particle.life - dt

        -- Update trail alpha
        for j, trailPoint in ipairs(particle.trail) do
            trailPoint.alpha = trailPoint.alpha * 0.95
        end

        -- Wrap around screen
        if particle.x < -10 then particle.x = self.config.nativeResolution.width + 10 end
        if particle.x > self.config.nativeResolution.width + 10 then particle.x = -10 end
        if particle.y < -10 then particle.y = self.config.nativeResolution.height + 10 end
        if particle.y > self.config.nativeResolution.height + 10 then particle.y = -10 end

        -- Reset if expired
        if particle.life <= 0 then
            particle.life = particle.maxLife
            particle.trail = {}
        end
    end

    -- Update hologram effects
    for _, effect in ipairs(self.hologramEffects) do
        effect.phase = effect.phase + dt * 2
        effect.flicker = math.sin(self.animationTime * 15 + effect.phase) * 0.3 + 0.7
    end

    -- Update integration beam
    if self.integrationBeam.active then
        self.integrationBeam.progress = math.min(1, self.integrationBeam.progress + dt * 2)
        self.integrationBeam.intensity = math.sin(self.integrationBeam.progress * math.pi) *
            (1 + math.sin(self.animationTime * 8) * 0.3)

        if self.integrationBeam.progress >= 1 then
            self.integrationBeam.active = false
        end
    end
end

function SubroutineChoiceState:generateAndFormatChoices()
    self.choices = SubroutineDB.getChoices(3, self.player.subroutines)
    self.displayListItems = {}

    if #self.choices == 0 then
        table.insert(self.displayListItems, {
            text = ">>> CACHE_CORRUPTED: No compatible subroutines detected <<<",
            details = "RECOMMENDATION: Seek alternative data sources",
            type = "none",
            disabled = true
        })
        return
    end

    for _, choiceData in ipairs(self.choices) do
        local listItem = { type = choiceData.type, originalChoiceData = choiceData }
        local mainText = ""
        local detailText = ""

        if choiceData.type == "new" then
            local def = SubroutineDB.getById(choiceData.subroutineId)
            mainText = string.format(">> [NEW_INTEGRATION] %s", def.name)
            detailText = string.format("   TYPE: %s | FUNCTION: %s", def.type or "SYSTEM", def.description)
            local effectData = def.effects.level_1
            local cost = (effectData.data and effectData.data.cpuCost) or def.cpuCost
            detailText = detailText .. string.format("\n   CPU_COST: %d | EFFECT: %s",
                cost, effectData.description_suffix or "")
            if def.range then
                detailText = detailText .. string.format(" | RANGE: %d", def.range)
            end
            listItem.subroutineId = choiceData.subroutineId
        elseif choiceData.type == "upgrade" then
            local subInst = choiceData.subroutineInstance
            local def = subInst.definition
            local nextLevel = subInst.level + 1
            mainText = string.format(">> [UPGRADE_PROTOCOL] %s", def.name)
            detailText = string.format("   UPGRADE: Lv.%d -> Lv.%d | TYPE: %s",
                subInst.level, nextLevel, def.type or "SYSTEM")
            if nextLevel <= def.maxLevel then
                local effectData = def.effects["level_" .. nextLevel]
                local cost = (effectData.data and effectData.data.cpuCost) or def.cpuCost
                detailText = detailText .. string.format("\n   CPU_COST: %d | NEW_EFFECT: %s",
                    cost, effectData.description_suffix or "")
            end
            listItem.subroutineInstance = subInst
        end

        listItem.text = mainText .. "\n" .. detailText
        listItem.disabled = false
        table.insert(self.displayListItems, listItem)
    end
end

function SubroutineChoiceState:drawEnhancedBackground()
    local nativeW, nativeH = self.config.nativeResolution.width,
        self.config.nativeResolution.height

    -- Base background
    love.graphics.setColor(self.config.activeColors.background)
    love.graphics.rectangle("fill", 0, 0, nativeW, nativeH)

    -- Matrix rain effect
    love.graphics.setFont((self.resources and self.resources:getFonts() or _G.Fonts).small)
    for _, drop in ipairs(self.matrixRain) do
        for i, charData in ipairs(drop.chars) do
            local charY = drop.y + i * 12
            if charY > -12 and charY < nativeH + 12 then
                local alpha = drop.alpha * charData.brightness * (i == 1 and 1 or 0.7)
                if i == 1 then
                    -- Bright head of the trail
                    love.graphics.setColor(1, 1, 1, alpha)
                else
                    -- Fading trail
                    love.graphics.setColor(self.config.activeColors.accent[1],
                        self.config.activeColors.accent[2],
                        self.config.activeColors.accent[3], alpha)
                end
                love.graphics.print(charData.char, drop.x, charY)
            end
        end
    end

    -- Animated grid overlay
    love.graphics.setColor(self.config.activeColors.accent[1],
        self.config.activeColors.accent[2],
        self.config.activeColors.accent[3], 0.1)

    local gridSize = 40
    local gridPhase = self.animationTime * 0.5

    for x = 0, nativeW, gridSize do
        local alpha = 0.05 + 0.05 * math.sin(gridPhase + x * 0.01)
        love.graphics.setColor(self.config.activeColors.accent[1],
            self.config.activeColors.accent[2],
            self.config.activeColors.accent[3], alpha)
        love.graphics.line(x, 0, x, nativeH)
    end

    for y = 0, nativeH, gridSize do
        local alpha = 0.05 + 0.05 * math.sin(gridPhase + y * 0.01)
        love.graphics.setColor(self.config.activeColors.accent[1],
            self.config.activeColors.accent[2],
            self.config.activeColors.accent[3], alpha)
        love.graphics.line(0, y, nativeW, y)
    end

    -- Data flow particles with trails
    love.graphics.setFont((self.resources and self.resources:getFonts() or _G.Fonts).small)
    for _, particle in ipairs(self.dataFlowParticles) do
        -- Draw trail
        for i, trailPoint in ipairs(particle.trail) do
            local alpha = trailPoint.alpha * (particle.life / particle.maxLife)
            love.graphics.setColor(particle.color[1], particle.color[2], particle.color[3], alpha * 0.5)
            love.graphics.print("·", trailPoint.x, trailPoint.y)
        end

        -- Draw main particle
        local alpha = particle.life / particle.maxLife
        love.graphics.setColor(particle.color[1], particle.color[2], particle.color[3], alpha)
        love.graphics.print(particle.char, particle.x, particle.y)
    end

    -- Hologram effects
    for _, effect in ipairs(self.hologramEffects) do
        local distortion = math.sin(effect.phase) * 2
        local alpha = effect.intensity * effect.flicker

        -- Holographic rectangle with distortion
        love.graphics.setColor(self.config.activeColors.accent[1],
            self.config.activeColors.accent[2],
            self.config.activeColors.accent[3], alpha * 0.3)
        love.graphics.rectangle("fill", effect.x + distortion, effect.y, effect.width, effect.height)

        -- Holographic border
        love.graphics.setColor(self.config.activeColors.accent[1],
            self.config.activeColors.accent[2],
            self.config.activeColors.accent[3], alpha * 0.8)
        love.graphics.rectangle("line", effect.x + distortion, effect.y, effect.width, effect.height)

        -- Scan lines
        for i = 0, effect.height, 3 do
            local lineAlpha = alpha * 0.4 * (0.8 + 0.2 * math.sin(self.animationTime * 4 + i))
            love.graphics.setColor(self.config.activeColors.accent[1],
                self.config.activeColors.accent[2],
                self.config.activeColors.accent[3], lineAlpha)
            love.graphics.line(effect.x + distortion, effect.y + i,
                effect.x + effect.width + distortion, effect.y + i)
        end
    end

    -- Cache analysis scan lines
    if self.cacheAnalysis.active then
        for _, scanLine in ipairs(self.cacheAnalysis.scanLines) do
            local scanX = (self.cacheAnalysis.progress * (nativeW + 100)) - 50
            local alpha = scanLine.intensity * (1 - math.abs(self.cacheAnalysis.progress - 0.5) * 2)

            love.graphics.setColor(self.config.activeColors.highlight[1],
                self.config.activeColors.highlight[2],
                self.config.activeColors.highlight[3], alpha)
            love.graphics.rectangle("fill", scanX, scanLine.y, 40, 2)

            -- Scan beam glow
            love.graphics.setColor(self.config.activeColors.highlight[1],
                self.config.activeColors.highlight[2],
                self.config.activeColors.highlight[3], alpha * 0.3)
            love.graphics.rectangle("fill", scanX - 20, scanLine.y - 1, 80, 4)
        end
    end

    -- Integration beam effect
    if self.integrationBeam.active then
        local beamY = nativeH / 2
        local beamWidth = nativeW * self.integrationBeam.progress
        local beamAlpha = self.integrationBeam.intensity * 0.6

        -- Main beam
        love.graphics.setColor(self.config.activeColors.pickup[1],
            self.config.activeColors.pickup[2],
            self.config.activeColors.pickup[3], beamAlpha)
        love.graphics.rectangle("fill", 0, beamY - 3, beamWidth, 6)

        -- Beam glow
        love.graphics.setColor(self.config.activeColors.pickup[1],
            self.config.activeColors.pickup[2],
            self.config.activeColors.pickup[3], beamAlpha * 0.3)
        love.graphics.rectangle("fill", 0, beamY - 8, beamWidth, 16)
    end

    -- Transition scan effect
    if self.isTransitioning then
        local scanAlpha = (1 - self.transitionPhase) * 0.8
        love.graphics.setColor(self.config.activeColors.accent[1],
            self.config.activeColors.accent[2],
            self.config.activeColors.accent[3], scanAlpha)

        -- Multiple scanning beams
        for i = 0, 3 do
            local scanY = (self.transitionPhase * nativeH * 1.3) + i * 40 - nativeH * 0.15
            if scanY >= -10 and scanY <= nativeH + 10 then
                love.graphics.rectangle("fill", 0, scanY, nativeW, 3)

                -- Beam particles
                for j = 0, nativeW, 20 do
                    if love.math.random() < 0.3 then
                        love.graphics.circle("fill", j, scanY + 1, 1)
                    end
                end
            end
        end
    end
end

function SubroutineChoiceState:draw()
    if not self.visible then return end

    BaseState.draw(self)

    local config = self.config or _G.Config
    local nativeW, nativeH = config.nativeResolution.width, config.nativeResolution.height

    -- Enhanced animated background
    self:drawEnhancedBackground()

    local panelMargin = 30
    local panelX = panelMargin
    local panelY = 30
    local panelW = nativeW - 2 * panelMargin
    local panelH = nativeH - 2 * panelY - 25

    -- Main integration panel with enhanced effects
    local pX, pY, pW, pH = UIHelpers.drawPanel(panelX, panelY, panelW, panelH, self.title, "highlighted")

    -- Enhanced player status with animations
    love.graphics.setFont((self.resources and self.resources:getFonts() or _G.Fonts).medium)
    local statusPulse = 0.8 + 0.2 * math.sin(self.animationTime * 2)
    local statusText = string.format("ACTIVE_PROCESS: %s | CPU: %d/%d | INTEGRITY: %d%%",
        self.player.name, self.player.cpuCycles, self.player.maxCPUCycles,
        math.floor((self.player.hp / self.player.maxHp) * 100))

    UIHelpers.drawHolographicText(statusText,
        pX + pW / 2 - (self.resources and self.resources:getFonts() or _G.Fonts).medium:getWidth(statusText) / 2,
        pY + 15, (self.resources and self.resources:getFonts() or _G.Fonts).medium,
        { self.config.activeColors.accent[1] * statusPulse,
            self.config.activeColors.accent[2] * statusPulse,
            self.config.activeColors.accent[3] * statusPulse, 1 },
        self.animationTime)

    local currentContentY = pY + 50

    if #self.displayListItems == 0 or (#self.displayListItems == 1 and self.displayListItems[1].type == "none") then
        -- Enhanced "no options" display
        local errorText = self.displayListItems[1] and self.displayListItems[1].text or
            "ERROR: No integration options available."
        UIHelpers.drawHolographicText(errorText,
            pX + pW / 2 - (self.resources and self.resources:getFonts() or _G.Fonts).medium:getWidth(errorText) / 2,
            currentContentY + 80, (self.resources and self.resources:getFonts() or _G.Fonts).medium,
            { 1, 0.5, 0.5, 1 }, self.animationTime)
    else
        -- Enhanced selectable list with better visual hierarchy
        love.graphics.setFont((self.resources and self.resources:getFonts() or _G.Fonts).small)
        local itemHeight = 90 -- Increased for better spacing and detail
        self:drawEnhancedIntegrationList(self.displayListItems, self.selectedOption,
            pX + 15, currentContentY, pW - 30,
            itemHeight, self.itemsPerPage, self.scrollOffset)
    end

    -- Enhanced controls with animated effects
    local controlsY = nativeH - 40
    local controlsPulse = 0.6 + 0.4 * math.sin(self.animationTime * 1.5)
    local controlsColor = { self.config.activeColors.ui_text_dim[1] * controlsPulse,
        self.config.activeColors.ui_text_dim[2] * controlsPulse,
        self.config.activeColors.ui_text_dim[3] * controlsPulse, 1 }

    UIHelpers.drawTextWithGlow("INTERFACE: ↑↓ Navigate | ENTER Integrate | ESC Abort",
        nativeW / 2, controlsY, (self.resources and self.resources:getFonts() or _G.Fonts).small,
        controlsColor, "center", 0.3)
end

function SubroutineChoiceState:drawEnhancedIntegrationList(items, selectedIndex, x, y, width, itemHeight, maxVisibleItems,
                                                           scrollOffset)
    scrollOffset = scrollOffset or 0
    maxVisibleItems = maxVisibleItems or #items

    -- Enhanced background for the integration chamber
    love.graphics.setColor(self.config.activeColors.background[1],
        self.config.activeColors.background[2],
        self.config.activeColors.background[3], 0.8)
    UIHelpers.drawRoundedRect(x - 12, y - 8, width + 24, maxVisibleItems * itemHeight + 16, 10, "fill")

    -- Integration chamber border with glow
    local chamberGlow = 0.6 + 0.4 * math.sin(self.animationTime * 2)
    love.graphics.setColor(self.config.activeColors.highlight[1],
        self.config.activeColors.highlight[2],
        self.config.activeColors.highlight[3], chamberGlow * 0.4)
    UIHelpers.drawRoundedRect(x - 12, y - 8, width + 24, maxVisibleItems * itemHeight + 16, 10, "line")

    for i = 1, maxVisibleItems do
        local itemActualIndex = i + scrollOffset

        if itemActualIndex > #items then break end

        local item = items[itemActualIndex]
        local currentY = y + (i - 1) * itemHeight
        local displayText = item.text
        local isSelected = (itemActualIndex == selectedIndex)

        -- Enhanced selection highlighting with integration effects
        if isSelected then
            local pulse = 0.7 + 0.3 * math.sin(self.selectionGlow)
            local integrationGlow = 0.5 + 0.5 * math.sin(self.animationTime * 6)

            -- Multi-layer selection background with integration theme
            local highlightColor = self.config.activeColors.highlight

            -- Outer integration field
            love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], 0.2 * pulse)
            UIHelpers.drawRoundedRect(x - 15, currentY - 8, width + 30, itemHeight + 6, 8, "fill")

            -- Main selection background with data flow animation
            love.graphics.setColor(highlightColor[1] * pulse, highlightColor[2] * pulse,
                highlightColor[3] * pulse, 0.4)
            UIHelpers.drawRoundedRect(x - 10, currentY - 5, width + 20, itemHeight, 6, "fill")

            -- Integration border with animated intensity
            love.graphics.setColor(highlightColor[1] * integrationGlow, highlightColor[2] * integrationGlow,
                highlightColor[3] * integrationGlow, 0.9)
            UIHelpers.drawRoundedRect(x - 10, currentY - 5, width + 20, itemHeight, 6, "line")

            -- Data stream indicators
            love.graphics.setColor(highlightColor)
            love.graphics.setFont((self.resources and self.resources:getFonts() or _G.Fonts).medium)
            local indicatorAlpha = 0.7 + 0.3 * math.sin(self.animationTime * 8)
            love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], indicatorAlpha)

            -- Animated brackets
            local bracketOffset = math.sin(self.animationTime * 4) * 2
            love.graphics.print(">>", x - 30 - bracketOffset,
                currentY + itemHeight / 2 -
                (self.resources and self.resources:getFonts() or _G.Fonts).medium:getHeight() / 2)
            love.graphics.print("<<", x + width + 12 + bracketOffset,
                currentY + itemHeight / 2 -
                (self.resources and self.resources:getFonts() or _G.Fonts).medium:getHeight() / 2)

            -- Integration particles
            for j = 1, 8 do
                local particleAngle = self.animationTime * 1.5 + j * (math.pi / 4)
                local particleRadius = 15 + math.sin(self.animationTime * 3 + j) * 5
                local particleX = x + width / 2 + math.cos(particleAngle) * particleRadius
                local particleY = currentY + itemHeight / 2 + math.sin(particleAngle) * particleRadius

                love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], 0.5)
                love.graphics.circle("fill", particleX, particleY, 1.5)
            end

            -- Data integration flow lines
            local flowAlpha = 0.4 + 0.6 * math.sin(self.animationTime * 5)
            love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], flowAlpha)
            for k = 0, width, 20 do
                local flowY = currentY + itemHeight / 2 + math.sin(self.animationTime * 3 + k * 0.1) * 3
                love.graphics.circle("fill", x + k, flowY, 1)
            end

            displayText = ">> SELECTED FOR INTEGRATION <<\n" .. displayText
        elseif item.disabled then
            -- Enhanced disabled state with corruption effect
            local corruptionAlpha = 0.2 + 0.1 * math.sin(self.animationTime * 2 + itemActualIndex)
            love.graphics.setColor(0.5, 0.2, 0.2, corruptionAlpha)
            UIHelpers.drawRoundedRect(x - 5, currentY - 2, width + 10, itemHeight - 4, 4, "fill")
            love.graphics.setColor(0.7, 0.3, 0.3, 1)

            -- Corruption indicators
            love.graphics.setFont((self.resources and self.resources:getFonts() or _G.Fonts).small)
            love.graphics.print(">> CORRUPTED DATA <<", x, currentY)
        else
            -- Subtle available state with data ready indicators
            local readyAlpha = 0.05 + 0.03 * math.sin(self.animationTime * 1.5 + itemActualIndex)
            love.graphics.setColor(self.config.activeColors.text[1],
                self.config.activeColors.text[2],
                self.config.activeColors.text[3], readyAlpha)
            UIHelpers.drawRoundedRect(x - 5, currentY - 2, width + 10, itemHeight - 4, 4, "fill")

            love.graphics.setColor(self.config.activeColors.text)

            -- Data ready indicators
            love.graphics.setFont((self.resources and self.resources:getFonts() or _G.Fonts).small)
            local readyPulse = 0.6 + 0.4 * math.sin(self.animationTime * 3 + itemActualIndex)
            love.graphics.setColor(self.config.activeColors.accent[1],
                self.config.activeColors.accent[2],
                self.config.activeColors.accent[3], readyPulse * 0.4)
            love.graphics.print("○", x - 15,
                currentY + itemHeight / 2 -
                (self.resources and self.resources:getFonts() or _G.Fonts).small:getHeight() / 2)
        end

        -- Multi-line text with enhanced formatting and type indicators
        love.graphics.setFont((self.resources and self.resources:getFonts() or _G.Fonts).small)

        -- Text shadow for better readability
        if isSelected then
            love.graphics.setColor(0, 0, 0, 0.8)
            love.graphics.printf(displayText, x + 3, currentY + 3, width, "left")
        end

        -- Main text with appropriate coloring and type-based styling
        if isSelected then
            local textPulse = 0.9 + 0.1 * math.sin(self.animationTime * 4)
            love.graphics.setColor(self.config.activeColors.text[1] * textPulse,
                self.config.activeColors.text[2] * textPulse,
                self.config.activeColors.text[3] * textPulse, 1)
        elseif item.disabled then
            love.graphics.setColor(0.6, 0.4, 0.4, 1)
        else
            love.graphics.setColor(self.config.activeColors.text)
        end

        love.graphics.printf(displayText, x, currentY, width, "left")

        -- Integration type indicators
        if not item.disabled then
            love.graphics.setFont((self.resources and self.resources:getFonts() or _G.Fonts).small)
            local typeColor = self.config.activeColors.accent
            if item.type == "new" then
                typeColor = self.config.activeColors.pickup
                love.graphics.setColor(typeColor[1], typeColor[2], typeColor[3], 0.8)
                love.graphics.print("[NEW]", x + width - 40, currentY + 5)
            elseif item.type == "upgrade" then
                typeColor = self.config.activeColors.highlight
                love.graphics.setColor(typeColor[1], typeColor[2], typeColor[3], 0.8)
                love.graphics.print("[UPG]", x + width - 40, currentY + 5)
            end
        end
    end

    -- Enhanced scrollbar with integration theme
    if #items > maxVisibleItems then
        local scrollbarX = x + width + 20
        local scrollbarWidth = 10
        local scrollbarHeight = maxVisibleItems * itemHeight

        -- Animated track with data flow
        local trackPulse = 0.4 + 0.2 * math.sin(self.animationTime * 2)
        love.graphics.setColor(self.config.activeColors.accent[1],
            self.config.activeColors.accent[2],
            self.config.activeColors.accent[3], trackPulse)
        UIHelpers.drawRoundedRect(scrollbarX, y, scrollbarWidth, scrollbarHeight, 5, "fill")

        -- Track border with integration glow
        love.graphics.setColor(self.config.activeColors.accent[1],
            self.config.activeColors.accent[2],
            self.config.activeColors.accent[3], 0.9)
        UIHelpers.drawRoundedRect(scrollbarX, y, scrollbarWidth, scrollbarHeight, 5, "line")

        -- Animated thumb with data indicators
        local thumbHeight = math.max(30, scrollbarHeight * (maxVisibleItems / #items))
        local scrollableRange = #items - maxVisibleItems
        local thumbY = y
        if scrollableRange > 0 then
            thumbY = y + (scrollOffset / scrollableRange) * (scrollbarHeight - thumbHeight)
        end

        -- Thumb with enhanced integration animation
        local thumbPulse = 0.8 + 0.4 * math.sin(self.animationTime * 4)
        love.graphics.setColor(self.config.activeColors.highlight[1] * thumbPulse,
            self.config.activeColors.highlight[2] * thumbPulse,
            self.config.activeColors.highlight[3] * thumbPulse, 0.95)
        UIHelpers.drawRoundedRect(scrollbarX, thumbY, scrollbarWidth, thumbHeight, 5, "fill")

        -- Data flow effect on thumb
        local flowOffset = (self.animationTime * 30) % thumbHeight
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.rectangle("fill", scrollbarX + 2, thumbY + flowOffset - 12, scrollbarWidth - 4, 24)

        -- Integration indicators on track
        for i = 0, 2 do
            local indicatorY = y + (i / 2) * scrollbarHeight
            local indicatorAlpha = 0.4 + 0.6 * math.sin(self.animationTime * 3 + i)
            love.graphics.setColor(self.config.activeColors.highlight[1],
                self.config.activeColors.highlight[2],
                self.config.activeColors.highlight[3], indicatorAlpha)
            love.graphics.circle("fill", scrollbarX + scrollbarWidth / 2, indicatorY, 2)
        end
    end
end

function SubroutineChoiceState:keypressed(key)
    -- Block input during transition
    if self.isTransitioning then return true end

    if #self.displayListItems == 0 or (#self.displayListItems == 1 and self.displayListItems[1].type == "none") then
        if key == "escape" or key == "return" or key == "kpenter" then
            -- Return to gameplay using legacy bridge temporarily
            if _G.GameState then
                _G.GameState.switch("gameplay")
                local gameplay = _G.GameState.get("gameplay")
                if gameplay and gameplay.resume then gameplay:resume() end
            end
        end
        return true
    end

    if key == "up" then
        self.selectedOption = math.max(1, self.selectedOption - 1)
        if self.selectedOption < self.scrollOffset + 1 then
            self.scrollOffset = math.max(0, self.selectedOption - 1)
        end
        _G.SFX.play("ui_navigate")
        self:triggerSelectionEffect()
    elseif key == "down" then
        self.selectedOption = math.min(#self.choices, self.selectedOption + 1)
        if self.selectedOption > self.scrollOffset + self.itemsPerPage then
            self.scrollOffset = math.min(#self.choices - self.itemsPerPage, self.selectedOption - self.itemsPerPage)
            self.scrollOffset = math.max(0, self.scrollOffset)
        end
        _G.SFX.play("ui_navigate")
        self:triggerSelectionEffect()
    elseif key == "return" or key == "kpenter" then
        _G.SFX.play("ui_select")
        self:triggerIntegrationEffect()

        local chosenRawData = self.choices[self.selectedOption]

        if chosenRawData and chosenRawData.type ~= "none" then
            if chosenRawData.type == "new" then
                self.player:learnSubroutine(chosenRawData.subroutineId)

                -- Emit event
                if self.events then
                    local subDef = SubroutineDB.getById(chosenRawData.subroutineId)
                    self.events:emit("subroutine_learned", {
                        subroutineId = chosenRawData.subroutineId,
                        subroutineName = subDef and subDef.name or "unknown",
                        message = "INTEGRATION_COMPLETE: " .. (subDef and subDef.name or "unknown")
                    })
                end

                --if gameplay then
                --    local subDef = SubroutineDB.getById(chosenRawData.subroutineId)
                --    gameplay:logMessage("INTEGRATION_COMPLETE: " .. subDef.name,
                --        self.config.activeColors.pickup)
                --end
            elseif chosenRawData.type == "upgrade" then
                self.player:upgradeSubroutine(chosenRawData.subroutineInstance)

                -- Emit event
                if self.events then
                    self.events:emit("subroutine_upgraded", {
                        subroutineName = chosenRawData.subroutineInstance:getName(),
                        newLevel = chosenRawData.subroutineInstance.level,
                        message = "UPGRADE_COMPLETE: " .. chosenRawData.subroutineInstance:getName()
                    })
                end

                --if gameplay then
                --    gameplay:logMessage("UPGRADE_COMPLETE: " .. chosenRawData.subroutineInstance:getName(),
                --        self.config.activeColors.pickup)
                --end
            end
        else
            -- Emit failure event
            if self.events then
                self.events:emit("subroutine_choice_failed", {
                    message = "CACHE_ANALYSIS_FAILED: No compatible data found."
                })
            end
            --if gameplay then
            --    gameplay:logMessage("CACHE_ANALYSIS_FAILED: No compatible data found.",
            --        self.config.activeColors.text)
            --end
        end

        -- Delay state switch to show integration animation
        love.timer.sleep(0.3)

        -- Return to gameplay
        self.stateManager:switch("gameplay")
    elseif key == "escape" then
        _G.SFX.play("ui_back")

        -- Emit event
        if self.events then
            self.events:emit("subroutine_choice_cancelled", {
                message = "INTEGRATION_ABORTED: Cache remains sealed."
            })
        end

        --local gameplay = _G.GameState and _G.GameState.get("gameplay") or nil
        --if gameplay then
        --    gameplay:logMessage("INTEGRATION_ABORTED: Cache remains sealed.",
        --        self.config.activeColors.text)
        --end

        -- Return to gameplay
        self.stateManager:switch("gameplay")
    end
    return true
end

function SubroutineChoiceState:triggerSelectionEffect()
    -- Reset selection glow for smooth animation
    self.selectionGlow = 0

    -- Add selection particles
    for i = 1, 5 do
        table.insert(self.dataFlowParticles, {
            x = self.config.nativeResolution.width / 2,
            y = 150 + (self.selectedOption - 1) * 90,
            vx = love.math.random(-50, 50),
            vy = love.math.random(-30, 30),
            life = 1.5,
            maxLife = 1.5,
            size = 2,
            char = "◦",
            color = self.config.activeColors.highlight,
            trail = {}
        })
    end
end

function SubroutineChoiceState:triggerIntegrationEffect()
    -- Activate integration beam
    self.integrationBeam.active = true
    self.integrationBeam.progress = 0
    self.integrationBeam.intensity = 0

    -- Add integration particles
    for i = 1, 15 do
        table.insert(self.dataFlowParticles, {
            x = love.math.random(0, self.config.nativeResolution.width),
            y = self.config.nativeResolution.height / 2,
            vx = love.math.random(-100, 100),
            vy = love.math.random(-50, 50),
            life = 2,
            maxLife = 2,
            size = 3,
            char = "●",
            color = self.config.activeColors.pickup,
            trail = {}
        })
    end
end

function SubroutineChoiceState:leave()
    print("Left Enhanced SubroutineChoiceState")

    if self.events then
        self.events:emit("subroutine_choice_left", {})
    end

    self.choices = {}
    self.displayListItems = {}
    self.player = nil

    BaseState.leave(self)
end

return SubroutineChoiceState
