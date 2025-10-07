-- src/states/NewRunState.lua - Enhanced with modern animations and visuals
local GameState = _G.GameState
local Helpers = require 'src.utils.Helpers'
local UIHelpers = require "src.ui.ui_helpers"
local AICoreDB = require "src.core.AICoreDB"
local SubroutineDB = require "src.core.SubroutineDB"
local Timer = require 'src.utils.Timer'

local NewRunState = {}
NewRunState.__index = NewRunState

function NewRunState:new()
    local instance = setmetatable({}, NewRunState)
    instance.title = "// INITIALIZE_NEW_PROCESS //"
    
    instance.selectableCores = {}
    instance.selectedCoreIndex = 1
    instance.targetCoreIndex = 1
    instance.currentDisplayCoreIndex = 1

    -- Enhanced animation system for core display
    instance.coreDisplaySlots = {
        prev = { x_offset_factor = -0.35, scale = 0.7, alpha = 0.5, char = "", color = {1,1,1,1}, glow = 0 },
        current = { x_offset_factor = 0, scale = 1.0, alpha = 1.0, char = "", color = {1,1,1,1}, glow = 1 },
        next = { x_offset_factor = 0.35, scale = 0.7, alpha = 0.5, char = "", color = {1,1,1,1}, glow = 0 }
    }
    instance.isCoreAnimating = false
    instance.tweenDuration = 0.3
    instance.coreRotation = 0
    instance.coreEnergyLevel = 0
    
    instance.availableStartingSubs = {}
    instance.selectedSubroutineIndex = 1

    instance.uiElements = {
        back = {text = "BACK", x = 0, y = 0, w = 0, h = 0, id = "back", glow = 0},
        start = {text = "START", x = 0, y = 0, w = 0, h = 0, id = "start", glow = 0}
    }
    instance.selectedUIElement = "core"
    
    -- Enhanced visual effects
    instance.animationTime = 0
    instance.selectionPulse = 0
    instance.dataStreamEffects = {}
    instance.coreInitialization = {
        active = false,
        progress = 0,
        particles = {}
    }
    instance.neuralNetworkLines = {}
    instance.backgroundParticles = {}
    instance.hologramEffects = {}
    instance.scanlinePhase = 0
    instance.matrixCode = {}
    instance.initializationBeam = {
        active = false,
        progress = 0,
        intensity = 0
    }
    
    -- Initialize visual effects
    instance:initializeVisualEffects()
    
    return instance
end

function NewRunState:initializeVisualEffects()
    local nativeW = _G.Config.nativeResolution.width
    local nativeH = _G.Config.nativeResolution.height
    
    -- Neural network connection lines
    for i = 1, 15 do
        table.insert(self.neuralNetworkLines, {
            startX = love.math.random(0, nativeW),
            startY = love.math.random(0, nativeH),
            endX = love.math.random(0, nativeW),
            endY = love.math.random(0, nativeH),
            pulse = love.math.random() * math.pi * 2,
            intensity = love.math.random(0.2, 0.8),
            phase = love.math.random() * math.pi * 2
        })
    end
    
    -- Background data particles
    for i = 1, 35 do
        table.insert(self.backgroundParticles, {
            x = love.math.random(0, nativeW),
            y = love.math.random(0, nativeH),
            vx = love.math.random(-20, 20),
            vy = love.math.random(-20, 20),
            life = love.math.random(5, 10),
            maxLife = love.math.random(5, 10),
            size = love.math.random(1, 3),
            char = love.math.random() < 0.5 and "·" or "○",
            color = _G.Config.activeColors.accent,
            phase = love.math.random() * math.pi * 2
        })
    end
    
    -- Data stream effects
    for i = 1, 8 do
        table.insert(self.dataStreamEffects, {
            x = i * (nativeW / 8),
            y = 0,
            speed = love.math.random(30, 80),
            particles = {},
            nextSpawn = 0
        })
        
        -- Initialize particles for each stream
        local stream = self.dataStreamEffects[i]
        for j = 1, 6 do
            table.insert(stream.particles, {
                y = love.math.random(-200, -50),
                char = love.math.random() < 0.3 and "1" or "0",
                alpha = love.math.random(0.3, 0.9)
            })
        end
    end
    
    -- Hologram effects for core display area
    for i = 1, 3 do
        table.insert(self.hologramEffects, {
            x = nativeW * 0.2 + i * (nativeW * 0.6 / 3),
            y = nativeH * 0.3,
            width = 60,
            height = 20,
            phase = love.math.random() * math.pi * 2,
            intensity = love.math.random(0.3, 0.7),
            flicker = 0
        })
    end
    
    -- Matrix-style code rain
    for i = 1, 20 do
        local codeString = ""
        for j = 1, love.math.random(3, 8) do
            codeString = codeString .. (love.math.random() < 0.5 and "0" or "1")
        end
        
        table.insert(self.matrixCode, {
            x = love.math.random(0, nativeW),
            y = love.math.random(-100, -20),
            code = codeString,
            speed = love.math.random(20, 60),
            alpha = love.math.random(0.2, 0.6)
        })
    end
    
    -- Core initialization particles
    for i = 1, 30 do
        table.insert(self.coreInitialization.particles, {
            angle = (i / 30) * math.pi * 2,
            radius = love.math.random(40, 80),
            speed = love.math.random(0.5, 2),
            life = love.math.random(2, 5),
            maxLife = love.math.random(2, 5),
            size = love.math.random(1, 3),
            color = _G.Config.activeColors.highlight
        })
    end
end

function NewRunState:enter()
    print("Entered Enhanced NewRunState")
    self.selectableCores = AICoreDB.getSelectableCores()
    if #self.selectableCores == 0 then
        print("ERROR: No selectable AI Cores found! Adding default.")
        local defaultCore = AICoreDB.getById("standard_pid")
        if defaultCore then 
            table.insert(self.selectableCores, defaultCore) 
        else 
            error("Default core not found!") 
        end
    end

    self.targetCoreIndex = 1
    self.currentDisplayCoreIndex = 1
    self:updateCoreDisplaySlots(true)
    self:updateDisplayedCoreInfo()
    self.selectedUIElement = "core"
    
    -- Reset animation state
    self.animationTime = 0
    self.selectionPulse = 0
    self.coreRotation = 0
    self.coreEnergyLevel = 0
    self.scanlinePhase = 0
    
    -- Start core initialization effect
    self.coreInitialization.active = true
    self.coreInitialization.progress = 0
    
    love.graphics.setBackgroundColor(_G.Config.activeColors.background)
end

function NewRunState:update(dt)
    Timer.update(dt)
    
    self.animationTime = self.animationTime + dt
    self.selectionPulse = self.selectionPulse + dt * 3
    self.coreRotation = self.coreRotation + dt * 0.5
    self.coreEnergyLevel = self.coreEnergyLevel + dt * 2
    self.scanlinePhase = self.scanlinePhase + dt * 4
    
    -- Update core initialization
    if self.coreInitialization.active then
        self.coreInitialization.progress = math.min(1, self.coreInitialization.progress + dt * 0.3)
        
        -- Update initialization particles
        for _, particle in ipairs(self.coreInitialization.particles) do
            particle.angle = particle.angle + particle.speed * dt
            particle.life = particle.life - dt
            
            if particle.life <= 0 then
                particle.life = particle.maxLife
                particle.angle = love.math.random() * math.pi * 2
                particle.radius = love.math.random(40, 80)
            end
        end
        
        if self.coreInitialization.progress >= 0.8 then
            self.coreInitialization.active = false
        end
    end
    
    -- Update neural network lines
    for _, line in ipairs(self.neuralNetworkLines) do
        line.pulse = line.pulse + dt * 2
        line.phase = line.phase + dt * 1.5
        line.intensity = 0.2 + 0.6 * math.sin(line.pulse) * math.sin(line.phase)
    end
    
    -- Update background particles
    for _, particle in ipairs(self.backgroundParticles) do
        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt
        particle.phase = particle.phase + dt * 2
        particle.life = particle.life - dt
        
        -- Wrap around screen
        if particle.x < -10 then particle.x = _G.Config.nativeResolution.width + 10 end
        if particle.x > _G.Config.nativeResolution.width + 10 then particle.x = -10 end
        if particle.y < -10 then particle.y = _G.Config.nativeResolution.height + 10 end
        if particle.y > _G.Config.nativeResolution.height + 10 then particle.y = -10 end
        
        if particle.life <= 0 then
            particle.life = particle.maxLife
        end
    end
    
    -- Update data streams
    for _, stream in ipairs(self.dataStreamEffects) do
        stream.nextSpawn = stream.nextSpawn - dt
        
        -- Spawn new particles
        if stream.nextSpawn <= 0 then
            stream.nextSpawn = love.math.random(0.5, 1.5)
            table.insert(stream.particles, {
                y = -20,
                char = love.math.random() < 0.3 and "1" or "0",
                alpha = love.math.random(0.3, 0.9)
            })
        end
        
        -- Update existing particles
        for i = #stream.particles, 1, -1 do
            local particle = stream.particles[i]
            particle.y = particle.y + stream.speed * dt
            particle.alpha = particle.alpha * 0.998
            
            if particle.y > _G.Config.nativeResolution.height + 20 or particle.alpha < 0.1 then
                table.remove(stream.particles, i)
            end
        end
    end
    
    -- Update hologram effects
    for _, effect in ipairs(self.hologramEffects) do
        effect.phase = effect.phase + dt * 2
        effect.flicker = 0.7 + 0.3 * math.sin(self.animationTime * 8 + effect.phase)
    end
    
    -- Update matrix code rain
    for _, code in ipairs(self.matrixCode) do
        code.y = code.y + code.speed * dt
        
        if code.y > _G.Config.nativeResolution.height + 50 then
            code.y = love.math.random(-100, -20)
            code.x = love.math.random(0, _G.Config.nativeResolution.width)
        end
    end
    
    -- Update initialization beam
    if self.initializationBeam.active then
        self.initializationBeam.progress = math.min(1, self.initializationBeam.progress + dt * 3)
        self.initializationBeam.intensity = math.sin(self.initializationBeam.progress * math.pi) * 
                                           (1 + math.sin(self.animationTime * 12) * 0.4)
        
        if self.initializationBeam.progress >= 1 then
            self.initializationBeam.active = false
        end
    end
    
    -- Update UI element glow effects
    for _, element in pairs(self.uiElements) do
        if self.selectedUIElement == element.id then
            element.glow = math.min(1, element.glow + dt * 4)
        else
            element.glow = math.max(0, element.glow - dt * 3)
        end
    end
end

function NewRunState:drawEnhancedBackground()
    local nativeW, nativeH = _G.Config.nativeResolution.width, _G.Config.nativeResolution.height
    
    -- Base background with subtle gradient
    love.graphics.setColor(_G.Config.activeColors.background)
    love.graphics.rectangle("fill", 0, 0, nativeW, nativeH)
    
    -- Matrix code rain
    love.graphics.setFont(_G.Fonts.small)
    for _, code in ipairs(self.matrixCode) do
        love.graphics.setColor(_G.Config.activeColors.accent[1], _G.Config.activeColors.accent[2], 
                              _G.Config.activeColors.accent[3], code.alpha)
        love.graphics.print(code.code, code.x, code.y)
    end
    
    -- Neural network connection lines
    for _, line in ipairs(self.neuralNetworkLines) do
        local alpha = line.intensity * 0.3
        love.graphics.setColor(_G.Config.activeColors.accent[1], _G.Config.activeColors.accent[2], 
                              _G.Config.activeColors.accent[3], alpha)
        love.graphics.setLineWidth(1)
        love.graphics.line(line.startX, line.startY, line.endX, line.endY)
        
        -- Add nodes at connection points
        love.graphics.setColor(_G.Config.activeColors.accent[1], _G.Config.activeColors.accent[2], 
                              _G.Config.activeColors.accent[3], alpha * 2)
        love.graphics.circle("fill", line.startX, line.startY, 2)
        love.graphics.circle("fill", line.endX, line.endY, 2)
    end
    
    -- Data stream effects
    love.graphics.setFont(_G.Fonts.small)
    for _, stream in ipairs(self.dataStreamEffects) do
        for _, particle in ipairs(stream.particles) do
            love.graphics.setColor(_G.Config.activeColors.accent[1], _G.Config.activeColors.accent[2], 
                                  _G.Config.activeColors.accent[3], particle.alpha)
            love.graphics.print(particle.char, stream.x, particle.y)
        end
    end
    
    -- Background particles with trails
    love.graphics.setFont(_G.Fonts.small)
    for _, particle in ipairs(self.backgroundParticles) do
        local alpha = (particle.life / particle.maxLife) * (0.5 + 0.5 * math.sin(particle.phase))
        love.graphics.setColor(particle.color[1], particle.color[2], particle.color[3], alpha * 0.4)
        love.graphics.print(particle.char, particle.x, particle.y)
    end
    
    -- Hologram effects
    for _, effect in ipairs(self.hologramEffects) do
        local distortion = math.sin(effect.phase) * 1.5
        local alpha = effect.intensity * effect.flicker
        
        -- Holographic rectangle
        love.graphics.setColor(_G.Config.activeColors.accent[1], _G.Config.activeColors.accent[2], 
                              _G.Config.activeColors.accent[3], alpha * 0.2)
        love.graphics.rectangle("fill", effect.x + distortion, effect.y, effect.width, effect.height)
        
        -- Holographic border
        love.graphics.setColor(_G.Config.activeColors.accent[1], _G.Config.activeColors.accent[2], 
                              _G.Config.activeColors.accent[3], alpha * 0.6)
        love.graphics.rectangle("line", effect.x + distortion, effect.y, effect.width, effect.height)
    end
    
    -- Core selection area highlight
    if self.selectedUIElement == "core" then
        local pulse = 0.3 + 0.4 * math.sin(self.selectionPulse)
        love.graphics.setColor(_G.Config.activeColors.highlight[1], _G.Config.activeColors.highlight[2], 
                              _G.Config.activeColors.highlight[3], pulse * 0.3)
        
        local coreAreaX = nativeW * 0.25
        local coreAreaY = nativeH * 0.2
        local coreAreaW = nativeW * 0.5
        local coreAreaH = nativeH * 0.5
        
        -- Animated selection field
        UIHelpers.drawRoundedRect(coreAreaX - 15, coreAreaY - 15, coreAreaW + 30, coreAreaH + 30, 12, "line")
        
        -- Selection particles
        for i = 1, 8 do
            local angle = self.animationTime * 2 + i * (math.pi / 4)
            local radius = 25 + math.sin(self.animationTime * 3 + i) * 8
            local particleX = coreAreaX + coreAreaW/2 + math.cos(angle) * radius
            local particleY = coreAreaY + coreAreaH/2 + math.sin(angle) * radius
            
            love.graphics.setColor(_G.Config.activeColors.highlight[1], _G.Config.activeColors.highlight[2], 
                                  _G.Config.activeColors.highlight[3], pulse * 0.8)
            love.graphics.circle("fill", particleX, particleY, 2)
        end
    end
    
    -- Initialization beam effect
    if self.initializationBeam.active then
        local beamY = nativeH * 0.7
        local beamWidth = nativeW * self.initializationBeam.progress
        local beamAlpha = self.initializationBeam.intensity * 0.5
        
        -- Main beam
        love.graphics.setColor(_G.Config.activeColors.pickup[1], 
                              _G.Config.activeColors.pickup[2], 
                              _G.Config.activeColors.pickup[3], beamAlpha)
        love.graphics.rectangle("fill", 0, beamY - 2, beamWidth, 4)
        
        -- Beam glow
        love.graphics.setColor(_G.Config.activeColors.pickup[1], 
                              _G.Config.activeColors.pickup[2], 
                              _G.Config.activeColors.pickup[3], beamAlpha * 0.3)
        love.graphics.rectangle("fill", 0, beamY - 6, beamWidth, 12)
    end
    
    -- Scanline effects
    love.graphics.setColor(_G.Config.activeColors.accent[1], _G.Config.activeColors.accent[2], 
                          _G.Config.activeColors.accent[3], 0.05)
    for y = 0, nativeH, 4 do
        local scanlineAlpha = 0.02 + 0.03 * math.sin(self.scanlinePhase + y * 0.1)
        love.graphics.setColor(_G.Config.activeColors.accent[1], _G.Config.activeColors.accent[2], 
                              _G.Config.activeColors.accent[3], scanlineAlpha)
        love.graphics.line(0, y, nativeW, y)
    end
end

-- ... (keeping all the existing core display and info update methods) ...

function NewRunState:updateCoreDisplaySlots(instant)
    if #self.selectableCores == 0 then return end

    local oldTargetCoreIndex = self.currentDisplayCoreIndex
    local newTargetCoreIndex = self.targetCoreIndex

    local slots = self.coreDisplaySlots
    local newCurrentCoreDef = self.selectableCores[newTargetCoreIndex]
    local newPrevIndex = newTargetCoreIndex - 1; if newPrevIndex < 1 then newPrevIndex = #self.selectableCores end
    local newPrevCoreDef = self.selectableCores[newPrevIndex]
    local newNextIndex = newTargetCoreIndex + 1; if newNextIndex > #self.selectableCores then newNextIndex = 1 end
    local newNextCoreDef = self.selectableCores[newNextIndex]

    if instant then
        slots.current.char = newCurrentCoreDef.char; slots.current.color = newCurrentCoreDef.color or _G.Config.activeColors.player
        slots.current.scale = 1.0; slots.current.alpha = 1.0; slots.current.x_offset_factor = 0; slots.current.glow = 1

        slots.prev.char = newPrevCoreDef.char; slots.prev.color = newPrevCoreDef.color or _G.Config.activeColors.player
        slots.prev.scale = 0.7; slots.prev.alpha = (#self.selectableCores > 1) and 0.5 or 0; slots.prev.x_offset_factor = -0.35; slots.prev.glow = 0
        
        slots.next.char = newNextCoreDef.char; slots.next.color = newNextCoreDef.color or _G.Config.activeColors.player
        slots.next.scale = 0.7; slots.next.alpha = (#self.selectableCores > 1) and 0.5 or 0; slots.next.x_offset_factor = 0.35; slots.next.glow = 0
        
        self.currentDisplayCoreIndex = self.targetCoreIndex
        self:updateDisplayedCoreInfo()
    else
        self.isCoreAnimating = true
        print("[NewRunState] Starting SLIDE tweens. TargetCore: " .. newCurrentCoreDef.name)

        local targetStates = {
            current = {scale = 1.0, alpha = 1.0, x_offset_factor = 0, glow = 1},
            prev    = {scale = 0.7, alpha = (#self.selectableCores > 1) and 0.5 or 0, x_offset_factor = -0.35, glow = 0},
            next    = {scale = 0.7, alpha = (#self.selectableCores > 1) and 0.5 or 0, x_offset_factor = 0.35, glow = 0}
        }

        local direction = 0
        if newTargetCoreIndex == oldTargetCoreIndex + 1 or (oldTargetCoreIndex == #self.selectableCores and newTargetCoreIndex == 1) then
            direction = 1
        elseif newTargetCoreIndex == oldTargetCoreIndex - 1 or (oldTargetCoreIndex == 1 and newTargetCoreIndex == #self.selectableCores) then
            direction = -1
        end

        if direction == 1 then
            print("  Sliding Right")
            slots.current.char = newPrevCoreDef.char; slots.current.color = newPrevCoreDef.color
            Timer.tween(self.tweenDuration, slots.current, targetStates.prev, "linear")

            slots.next.char = newCurrentCoreDef.char; slots.next.color = newCurrentCoreDef.color
            Timer.tween(self.tweenDuration, slots.next, targetStates.current, "linear")
            
            slots.prev.char = newNextCoreDef.char; slots.prev.color = newNextCoreDef.color
            Timer.tween(self.tweenDuration, slots.prev, targetStates.next, "linear")

            local temp_current = slots.current
            slots.current = slots.next
            slots.next = slots.prev
            slots.prev = temp_current

        elseif direction == -1 then
            print("  Sliding Left")
            slots.current.char = newNextCoreDef.char; slots.current.color = newNextCoreDef.color
            Timer.tween(self.tweenDuration, slots.current, targetStates.next, "linear")

            slots.prev.char = newCurrentCoreDef.char; slots.prev.color = newCurrentCoreDef.color
            Timer.tween(self.tweenDuration, slots.prev, targetStates.current, "linear")

            slots.next.char = newPrevCoreDef.char; slots.next.color = newPrevCoreDef.color
            Timer.tween(self.tweenDuration, slots.next, targetStates.prev, "linear")

            local temp_current = slots.current
            slots.current = slots.prev
            slots.prev = slots.next
            slots.next = temp_current
        else 
            if slots.current.scale ~= targetStates.current.scale or slots.current.alpha ~= targetStates.current.alpha or slots.current.x_offset_factor ~= targetStates.current.x_offset_factor then
                Timer.tween(self.tweenDuration, slots.current, targetStates.current, "linear")
            end
            if #self.selectableCores > 1 then
                if slots.prev.scale ~= targetStates.prev.scale or slots.prev.alpha ~= targetStates.prev.alpha or slots.prev.x_offset_factor ~= targetStates.prev.x_offset_factor then
                    Timer.tween(self.tweenDuration, slots.prev, targetStates.prev, "linear")
                end
                if slots.next.scale ~= targetStates.next.scale or slots.next.alpha ~= targetStates.next.alpha or slots.next.x_offset_factor ~= targetStates.next.x_offset_factor then
                    Timer.tween(self.tweenDuration, slots.next, targetStates.next, "linear")
                end
            end
        end
        
        Timer.after(self.tweenDuration + 0.01, function()
            self.isCoreAnimating = false
            self.currentDisplayCoreIndex = self.targetCoreIndex 
            self:updateCoreDisplaySlots(true)
            print("Core animation SLIDE sequence FINISHED. isCoreAnimating: false")
        end)
    end
end

function NewRunState:updateDisplayedCoreInfo()
    if #self.selectableCores == 0 then return end
    local coreData = self.selectableCores[self.targetCoreIndex]
    if not coreData then return end

    self.availableStartingSubs = {}
    if coreData.startingSubroutineId then
        local subDef = SubroutineDB.getById(coreData.startingSubroutineId)
        if subDef then
            table.insert(self.availableStartingSubs, {
                id = subDef.id,
                name = subDef.name,
                description = (subDef.effects.level_1 and subDef.effects.level_1.description_suffix) or subDef.description
            })
        else
            table.insert(self.availableStartingSubs, {id="none", name="[ERROR: Sub Missing]", description=""})
        end
    elseif coreData.startingSubroutineChoices then
        for _, subId in ipairs(coreData.startingSubroutineChoices) do
            local subDef = SubroutineDB.getById(subId)
            if subDef then
                table.insert(self.availableStartingSubs, {id=subDef.id, name=subDef.name, description=(subDef.effects.level_1 and subDef.effects.level_1.description_suffix) or subDef.description})
            end
        end
    else
        table.insert(self.availableStartingSubs, {id="none", name="[No Initial Subroutine]", description="Acquire via Subroutine Cache."})
    end
    self.selectedSubroutineIndex = 1
end

function NewRunState:draw()
    local nativeW, nativeH = _G.Config.nativeResolution.width, _G.Config.nativeResolution.height
    
    -- Enhanced animated background
    self:drawEnhancedBackground()

    -- Enhanced title with holographic effects
    love.graphics.setFont(_G.Fonts.large)
    UIHelpers.drawHolographicText(self.title, nativeW/2 - _G.Fonts.large:getWidth(self.title)/2, 
                                  25, _G.Fonts.large, _G.Config.activeColors.accent, self.animationTime)

    if #self.selectableCores == 0 then return end

    local selectedCoreDataForInfo = self.selectableCores[self.targetCoreIndex]

    -- Enhanced layout with better proportions
    local panelPadding = math.floor(nativeW * 0.025)
    local panelTopY = math.floor(nativeH * 0.18)
    local panelBottomY = nativeH - math.floor(nativeH * 0.12)
    local panelHeight = panelBottomY - panelTopY
    
    local baseStatsPanelW = math.floor(nativeW * 0.28)
    local coreDisplayW = math.floor(nativeW * 0.32)
    local subPanelW = math.floor(nativeW * 0.28)

    local baseStatsPanelX = panelPadding
    local coreDisplayCenterX = baseStatsPanelX + baseStatsPanelW + panelPadding + coreDisplayW / 2
    local subPanelX = baseStatsPanelX + baseStatsPanelW + panelPadding + coreDisplayW + panelPadding

    -- 1. Enhanced Base Stats Panel
    if selectedCoreDataForInfo then
        local bsPX, bsPY, bsPW, bsPH = UIHelpers.drawPanel(baseStatsPanelX, panelTopY, baseStatsPanelW, panelHeight, 
                                                           "CORE_SPECS", "highlighted")
        
        -- Enhanced stats display with animations
        love.graphics.setFont(_G.Fonts.medium)
        local statY = bsPY + 15
        local statLineHeight = _G.Fonts.medium:getHeight() + 8
        
        -- Animated stats header
        local headerPulse = 0.8 + 0.2 * math.sin(self.animationTime * 2)
        love.graphics.setColor(_G.Config.activeColors.highlight[1] * headerPulse, 
                              _G.Config.activeColors.highlight[2] * headerPulse, 
                              _G.Config.activeColors.highlight[3] * headerPulse, 1)
        love.graphics.print("SPECIFICATIONS:", bsPX + 10, statY)
        statY = statY + statLineHeight + 5
        
        -- Enhanced stat display with visual bars
        for statName, statValue in pairs(selectedCoreDataForInfo.baseStats) do
            love.graphics.setColor(_G.Config.activeColors.text)
            love.graphics.setFont(_G.Fonts.small)
            love.graphics.print(string.upper(statName) .. ":", bsPX + 15, statY)
            
            -- Value with glow effect
            love.graphics.setFont(_G.Fonts.medium)
            local valuePulse = 0.9 + 0.1 * math.sin(self.animationTime * 3)
            love.graphics.setColor(_G.Config.activeColors.pickup[1] * valuePulse, 
                                  _G.Config.activeColors.pickup[2] * valuePulse, 
                                  _G.Config.activeColors.pickup[3] * valuePulse, 1)
            love.graphics.print(tostring(statValue), bsPX + bsPW - 60, statY - 2)
            
            -- Animated stat bar
            local barWidth = 80
            local barHeight = 4
            local maxStatValue = (statName == "hp" and 150) or (statName == "cpu" and 100) or (statName == "attack" and 20) or 10
            local statPercent = math.min(1, statValue / maxStatValue)
            
            love.graphics.setColor(_G.Config.activeColors.background[1], _G.Config.activeColors.background[2], 
                                  _G.Config.activeColors.background[3], 0.8)
            love.graphics.rectangle("fill", bsPX + 15, statY + statLineHeight - 8, barWidth, barHeight)
            
            -- Animated fill
            local fillColor = _G.Config.activeColors.highlight
            if statName == "hp" then fillColor = _G.Config.activeColors.player
            elseif statName == "cpu" then fillColor = {0.3, 0.7, 1, 1}
            elseif statName == "attack" then fillColor = {1, 0.5, 0.3, 1}
            end
            
            love.graphics.setColor(fillColor[1], fillColor[2], fillColor[3], 0.8)
            love.graphics.rectangle("fill", bsPX + 15, statY + statLineHeight - 8, 
                                   barWidth * statPercent, barHeight)
            
            -- Flowing highlight
            local flowOffset = (self.animationTime * 40) % (barWidth * statPercent)
            love.graphics.setColor(1, 1, 1, 0.4)
            love.graphics.rectangle("fill", bsPX + 15 + flowOffset - 8, statY + statLineHeight - 8, 16, barHeight)
            
            statY = statY + statLineHeight + 5
        end
        
        -- Core type indicator
        love.graphics.setFont(_G.Fonts.small)
        love.graphics.setColor(_G.Config.activeColors.accent)
        love.graphics.print("TYPE: " .. (selectedCoreDataForInfo.type or "STANDARD"), bsPX + 15, statY + 10)
    end

    -- 2. Enhanced AI Core Selection Display with particle effects
    self:drawEnhancedCoreDisplay(coreDisplayCenterX, panelTopY, coreDisplayW, panelHeight, selectedCoreDataForInfo)

    -- 3. Enhanced Starting Subroutine Panel
    if selectedCoreDataForInfo then
        local subPX, subPY, subPW, subPH = UIHelpers.drawPanel(subPanelX, panelTopY, subPanelW, panelHeight, 
                                                               "INIT_ROUTINES", "default")
        
        self:drawEnhancedSubroutinePanel(subPX, subPY, subPW, subPH)
    end

    -- 4. Enhanced Bottom Navigation with animated buttons
    self:drawEnhancedNavigation(nativeW, nativeH, panelPadding)
end

function NewRunState:drawEnhancedCoreDisplay(centerX, panelY, displayW, panelH, selectedCoreData)
    local coreDisplayY = panelY + math.floor(panelH * 0.35)
    
    -- Core initialization effects
    if self.coreInitialization.active then
        local progress = self.coreInitialization.progress
        
        -- Initialization particles
        for _, particle in ipairs(self.coreInitialization.particles) do
            local particleX = centerX + math.cos(particle.angle) * particle.radius * progress
            local particleY = coreDisplayY + math.sin(particle.angle) * particle.radius * progress
            
            local alpha = (particle.life / particle.maxLife) * progress
            love.graphics.setColor(particle.color[1], particle.color[2], particle.color[3], alpha)
            love.graphics.circle("fill", particleX, particleY, particle.size)
        end
        
        -- Initialization ring
        love.graphics.setColor(_G.Config.activeColors.highlight[1], _G.Config.activeColors.highlight[2], 
                              _G.Config.activeColors.highlight[3], 0.6 * progress)
        love.graphics.circle("line", centerX, coreDisplayY, 60 * progress)
    end
    
    -- Enhanced core character display with effects
    love.graphics.setFont(_G.Fonts.title)
    
    for slotName, slotData in pairs(self.coreDisplaySlots) do
        if slotData.alpha > 0.01 and slotData.char ~= "" then
            local char = slotData.char
            local color = slotData.color
            local scale = slotData.scale
            local alpha = slotData.alpha
            local glow = slotData.glow or 0
            local x_offset = slotData.x_offset_factor * displayW * 0.8
            
            -- Core energy field
            if glow > 0.1 then
                local energyRadius = 30 + math.sin(self.coreEnergyLevel) * 8
                love.graphics.setColor(color[1], color[2], color[3], glow * 0.3)
                love.graphics.circle("line", centerX + x_offset, coreDisplayY, energyRadius)
                
                -- Energy particles
                for i = 1, 6 do
                    local angle = self.coreRotation + i * (math.pi / 3)
                    local radius = energyRadius - 5
                    local particleX = centerX + x_offset + math.cos(angle) * radius
                    local particleY = coreDisplayY + math.sin(angle) * radius
                    
                    love.graphics.setColor(color[1], color[2], color[3], glow * 0.6)
                    love.graphics.circle("fill", particleX, particleY, 2)
                end
            end
            
            -- Main character with enhanced effects
            local font = _G.Fonts.title
            local charW = font:getWidth(char) * scale
            local charH = font:getHeight() * scale
            local charX = centerX + x_offset - charW / 2
            local charY = coreDisplayY - charH / 2
            
            -- Character glow layers
            if glow > 0.1 then
                for i = 1, 3 do
                    love.graphics.setColor(color[1], color[2], color[3], glow * 0.2)
                    love.graphics.printf(char, charX + i, charY, font:getWidth(char) * 2, nil, nil, scale, scale)
                    love.graphics.printf(char, charX - i, charY, font:getWidth(char) * 2, nil, nil, scale, scale)
                    love.graphics.printf(char, charX, charY + i, font:getWidth(char) * 2, nil, nil, scale, scale)
                    love.graphics.printf(char, charX, charY - i, font:getWidth(char) * 2, nil, nil, scale, scale)
                end
            end
            
            -- Main character
            love.graphics.setColor(color[1], color[2], color[3], alpha)
            love.graphics.printf(char, charX, charY, font:getWidth(char) * 2, nil, nil, scale, scale)
            
            -- Selection underline with animation
            if slotName == "current" and scale > 0.95 then
                local underlineY = charY + charH * 0.9
                local underlineWidth = charW + math.sin(self.animationTime * 4) * 4
                local underlineX = centerX + x_offset - underlineWidth / 2
                
                love.graphics.setLineWidth(4 * scale)
                love.graphics.setColor(color[1], color[2], color[3], alpha * 0.8)
                love.graphics.line(underlineX, underlineY, underlineX + underlineWidth, underlineY)
                love.graphics.setLineWidth(1)
            end
        end
    end

    -- Enhanced core name and description
    if selectedCoreData then
        local coreNameY = panelY + math.floor(panelH * 0.65)
        local coreDescY = panelY + math.floor(panelH * 0.78)
        
        -- Core name with holographic effect
        love.graphics.setFont(_G.Fonts.large)
        UIHelpers.drawHolographicText(selectedCoreData.name, 
                                      centerX - _G.Fonts.large:getWidth(selectedCoreData.name)/2, 
                                      coreNameY, _G.Fonts.large, 
                                      _G.Config.activeColors.highlight, self.animationTime)
        
        -- Core description with subtle animation
        love.graphics.setFont(_G.Fonts.medium)
        local descPulse = 0.8 + 0.2 * math.sin(self.animationTime * 1.5)
        love.graphics.setColor(_G.Config.activeColors.text[1] * descPulse, 
                              _G.Config.activeColors.text[2] * descPulse, 
                              _G.Config.activeColors.text[3] * descPulse, 1)
        love.graphics.printf(selectedCoreData.description, 
                           centerX - displayW/2 + 20, coreDescY, displayW - 40, "center")
    end

    -- Core selection indicators
    if self.selectedUIElement == "core" then
        local indicatorPulse = 0.7 + 0.3 * math.sin(self.selectionPulse)
        love.graphics.setColor(_G.Config.activeColors.highlight[1], _G.Config.activeColors.highlight[2], 
                              _G.Config.activeColors.highlight[3], indicatorPulse)
        
        -- Navigation arrows
        if #self.selectableCores > 1 then
            love.graphics.setFont(_G.Fonts.large)
            love.graphics.print("◄", centerX - displayW/2 - 20, coreDisplayY - _G.Fonts.large:getHeight()/2)
            love.graphics.print("►", centerX + displayW/2 + 5, coreDisplayY - _G.Fonts.large:getHeight()/2)
        end
        
        -- Selection field
        love.graphics.setColor(_G.Config.activeColors.highlight[1], _G.Config.activeColors.highlight[2], 
                              _G.Config.activeColors.highlight[3], indicatorPulse * 0.2)
        UIHelpers.drawRoundedRect(centerX - displayW/2, panelY + panelH*0.2, displayW, panelH*0.5, 8, "fill")
        
        love.graphics.setColor(_G.Config.activeColors.highlight[1], _G.Config.activeColors.highlight[2], 
                              _G.Config.activeColors.highlight[3], indicatorPulse * 0.6)
        UIHelpers.drawRoundedRect(centerX - displayW/2, panelY + panelH*0.2, displayW, panelH*0.5, 8, "line")
    end
end

function NewRunState:drawEnhancedSubroutinePanel(subPX, subPY, subPW, subPH)
    love.graphics.setFont(_G.Fonts.medium)
    local subItemY = subPY + 20
    local subItemLineHeight = _G.Fonts.medium:getHeight() + 8
    
    -- Enhanced subroutine display
    if #self.availableStartingSubs > 0 then
        local subInfo = self.availableStartingSubs[1]
        
        -- Subroutine name with glow
        local namePulse = 0.9 + 0.1 * math.sin(self.animationTime * 2)
        love.graphics.setColor(_G.Config.activeColors.pickup[1] * namePulse, 
                              _G.Config.activeColors.pickup[2] * namePulse, 
                              _G.Config.activeColors.pickup[3] * namePulse, 1)
        love.graphics.print(subInfo.name, subPX + 15, subItemY)
        
        -- Enhanced description
        love.graphics.setFont(_G.Fonts.small)
        love.graphics.setColor(_G.Config.activeColors.text)
        love.graphics.printf(subInfo.description, subPX + 20, subItemY + subItemLineHeight + 5, subPW - 40, "left")
        
        -- Status indicator
        love.graphics.setColor(_G.Config.activeColors.accent)
        love.graphics.print("● READY", subPX + 15, subItemY + subItemLineHeight * 3)
    end
    
    -- Enhanced subroutine slot visualization
    local slotSize = math.floor(subPW * 0.22)
    local slotPadding = 8
    local slotsPerRow = 3
    local startY = subPY + subPH - 100
    
    for i = 0, 5 do
        local row = math.floor(i / slotsPerRow)
        local col = i % slotsPerRow
        local slotX = subPX + (subPW - (slotsPerRow * slotSize + (slotsPerRow - 1) * slotPadding)) / 2 + 
                      col * (slotSize + slotPadding)
        local slotY = startY + row * (slotSize + slotPadding)
        
        -- Slot background with animation
        local slotPulse = 0.3 + 0.2 * math.sin(self.animationTime * 2 + i * 0.5)
        love.graphics.setColor(_G.Config.activeColors.accent[1], _G.Config.activeColors.accent[2], 
                              _G.Config.activeColors.accent[3], slotPulse)
        UIHelpers.drawRoundedRect(slotX, slotY, slotSize, slotSize, 4, "fill")
        
        -- Slot border
        love.graphics.setColor(_G.Config.activeColors.accent)
        UIHelpers.drawRoundedRect(slotX, slotY, slotSize, slotSize, 4, "line")
        
        -- Slot number
        love.graphics.setFont(_G.Fonts.small)
        love.graphics.setColor(_G.Config.activeColors.text)
        love.graphics.print(tostring(i + 1), slotX + slotSize/2 - 4, slotY + slotSize/2 - 6)
        
        -- First slot gets special treatment if there's a starting subroutine
        if i == 0 and #self.availableStartingSubs > 0 and self.availableStartingSubs[1].id ~= "none" then
            love.graphics.setColor(_G.Config.activeColors.pickup[1], _G.Config.activeColors.pickup[2], 
                                  _G.Config.activeColors.pickup[3], 0.4)
            UIHelpers.drawRoundedRect(slotX + 1, slotY + 1, slotSize - 2, slotSize - 2, 3, "fill")
            
            love.graphics.setColor(_G.Config.activeColors.pickup)
            love.graphics.print("●", slotX + slotSize/2 - 2, slotY + slotSize/2 + 8)
        end
    end
end

function NewRunState:drawEnhancedNavigation(nativeW, nativeH, panelPadding)
    love.graphics.setFont(_G.Fonts.large)
    local buttonW = _G.Fonts.large:getWidth("START") + math.floor(nativeW * 0.06)
    local buttonH = _G.Fonts.large:getHeight() + math.floor(nativeH * 0.025)
    
    -- Update button positions
    self.uiElements.back.x = panelPadding
    self.uiElements.back.y = nativeH - buttonH - panelPadding
    self.uiElements.back.w = buttonW
    self.uiElements.back.h = buttonH
    
    self.uiElements.start.x = nativeW - buttonW - panelPadding
    self.uiElements.start.y = nativeH - buttonH - panelPadding
    self.uiElements.start.w = buttonW
    self.uiElements.start.h = buttonH

    -- Enhanced button drawing
    for id, btn in pairs(self.uiElements) do
        local isSelected = (self.selectedUIElement == id)
        local glowIntensity = btn.glow
        
        -- Button glow effect
        if glowIntensity > 0.1 then
            for i = 1, 4 do
                love.graphics.setColor(_G.Config.activeColors.highlight[1], _G.Config.activeColors.highlight[2], 
                                      _G.Config.activeColors.highlight[3], glowIntensity * 0.1)
                UIHelpers.drawRoundedRect(btn.x - i*2, btn.y - i*2, btn.w + i*4, btn.h + i*4, 6 + i, "line")
            end
        end
        
        -- Button background
        local bgAlpha = isSelected and (0.3 + 0.2 * math.sin(self.animationTime * 4)) or 0.1
        love.graphics.setColor(_G.Config.activeColors.highlight[1], _G.Config.activeColors.highlight[2], 
                              _G.Config.activeColors.highlight[3], bgAlpha)
        UIHelpers.drawRoundedRect(btn.x, btn.y, btn.w, btn.h, 6, "fill")
        
        -- Button border with animation
        local borderPulse = isSelected and (0.8 + 0.4 * math.sin(self.animationTime * 6)) or 0.6
        love.graphics.setColor(_G.Config.activeColors.highlight[1] * borderPulse, 
                              _G.Config.activeColors.highlight[2] * borderPulse, 
                              _G.Config.activeColors.highlight[3] * borderPulse, 1)
        UIHelpers.drawRoundedRect(btn.x, btn.y, btn.w, btn.h, 6, "line")
        
        -- Button text with effects
        local textPulse = isSelected and (0.9 + 0.2 * math.sin(self.animationTime * 8)) or 1
        love.graphics.setColor(_G.Config.activeColors.text[1] * textPulse, 
                              _G.Config.activeColors.text[2] * textPulse, 
                              _G.Config.activeColors.text[3] * textPulse, 1)
        
        local textX = btn.x + btn.w/2 - _G.Fonts.large:getWidth(btn.text)/2
        local textY = btn.y + btn.h/2 - _G.Fonts.large:getHeight()/2
        
        -- Text glow for selected button
        if isSelected and glowIntensity > 0.3 then
            love.graphics.setColor(_G.Config.activeColors.highlight[1], _G.Config.activeColors.highlight[2], 
                                  _G.Config.activeColors.highlight[3], glowIntensity * 0.3)
            for dx = -1, 1 do
                for dy = -1, 1 do
                    if dx ~= 0 or dy ~= 0 then
                        love.graphics.print(btn.text, textX + dx, textY + dy)
                    end
                end
            end
        end
        
        love.graphics.setColor(_G.Config.activeColors.text[1] * textPulse, 
                              _G.Config.activeColors.text[2] * textPulse, 
                              _G.Config.activeColors.text[3] * textPulse, 1)
        love.graphics.print(btn.text, textX, textY)
        
        -- Selection particles for buttons
        if isSelected and glowIntensity > 0.5 then
            for i = 1, 4 do
                local angle = self.animationTime * 3 + i * (math.pi / 2)
                local radius = 8 + math.sin(self.animationTime * 4 + i) * 3
                local particleX = btn.x + btn.w/2 + math.cos(angle) * radius
                local particleY = btn.y + btn.h/2 + math.sin(angle) * radius
                
                love.graphics.setColor(_G.Config.activeColors.highlight[1], _G.Config.activeColors.highlight[2], 
                                      _G.Config.activeColors.highlight[3], glowIntensity * 0.8)
                love.graphics.circle("fill", particleX, particleY, 1.5)
            end
        end
    end
end

function NewRunState:keypressed(key)
    if self.isCoreAnimating then return true end

    if key == "left" then
        if self.selectedUIElement == "core" then
            if #self.selectableCores > 1 then
                self.targetCoreIndex = self.targetCoreIndex - 1
                if self.targetCoreIndex < 1 then self.targetCoreIndex = #self.selectableCores end
                self:updateCoreDisplaySlots(false)
                self:updateDisplayedCoreInfo()
                self:triggerCoreSelectionEffect()
            end
        elseif self.selectedUIElement == "start" then
            self.selectedUIElement = "back"
        end
        _G.SFX.play("ui_navigate")
    elseif key == "right" then
        if self.selectedUIElement == "core" then
            if #self.selectableCores > 1 then
                self.targetCoreIndex = self.targetCoreIndex + 1
                if self.targetCoreIndex > #self.selectableCores then self.targetCoreIndex = 1 end
                self:updateCoreDisplaySlots(false)
                self:updateDisplayedCoreInfo()
                self:triggerCoreSelectionEffect()
            end
        elseif self.selectedUIElement == "back" then
            self.selectedUIElement = "start"
        end
        _G.SFX.play("ui_navigate")
    elseif key == "up" then
        if self.selectedUIElement == "back" or self.selectedUIElement == "start" then
            self.selectedUIElement = "core"
        end
        _G.SFX.play("ui_navigate")
    elseif key == "down" then
        if self.selectedUIElement == "core" then
            self.selectedUIElement = "back"
        end
        _G.SFX.play("ui_navigate")
    elseif key == "return" or key == "kpenter" then
        if self.selectedUIElement == "start" then
            if #self.selectableCores > 0 then
                _G.SFX.play("ui_select")
                self:triggerInitializationEffect()
                
                _G.MetaProgress:setSelectedAICoreId(self.selectableCores[self.targetCoreIndex].id)
                local gameplay = GameState.get("gameplay");
                if gameplay then gameplay.isInitialized = false end
                
                -- Delay state switch to show initialization animation
                love.timer.sleep(0.4)
                GameState.switch("gameplay", {resetLevel = true})
            end
        elseif self.selectedUIElement == "back" then
            _G.SFX.play("ui_back")
            GameState.switch("mainmenu")
        end
    elseif key == "escape" then
        _G.SFX.play("ui_back")
        GameState.switch("mainmenu")
    end

    return true 
end

function NewRunState:triggerCoreSelectionEffect()
    -- Add core selection particles
    local centerX = _G.Config.nativeResolution.width * 0.5
    local centerY = _G.Config.nativeResolution.height * 0.4
    
    for i = 1, 8 do
        table.insert(self.backgroundParticles, {
            x = centerX,
            y = centerY,
            vx = love.math.random(-60, 60),
            vy = love.math.random(-60, 60),
            life = 1.5,
            maxLife = 1.5,
            size = 2,
            char = "◦",
            color = _G.Config.activeColors.highlight,
            phase = 0
        })
    end
end

function NewRunState:triggerInitializationEffect()
    -- Activate initialization beam
    self.initializationBeam.active = true
    self.initializationBeam.progress = 0
    self.initializationBeam.intensity = 0
    
    -- Add initialization particles
    for i = 1, 20 do
        table.insert(self.backgroundParticles, {
            x = love.math.random(0, _G.Config.nativeResolution.width),
            y = _G.Config.nativeResolution.height * 0.7,
            vx = love.math.random(-80, 80),
            vy = love.math.random(-40, 40),
            life = 2.5,
            maxLife = 2.5,
            size = 3,
            char = "●",
            color = _G.Config.activeColors.pickup,
            phase = 0
        })
    end
end

function NewRunState:leave()
    print("Left Enhanced NewRunState")
end

return NewRunState