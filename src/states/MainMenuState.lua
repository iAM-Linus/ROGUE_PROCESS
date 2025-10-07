-- src/states/MainMenuState.lua (Phase 2 - Migrated Version)
-- This version uses the new architecture: BaseState, ServiceLocator, Events
local BaseState = require "src.core.base_state"
local UIHelpers = require "src.ui.ui_helpers"

local MainMenuState = {}
MainMenuState.__index = MainMenuState
setmetatable(MainMenuState, {__index = BaseState})

-- Constructor
function MainMenuState:new(game)
    -- Call BaseState constructor
    local instance = BaseState.new(self, game)
    setmetatable(instance, MainMenuState)
    
    -- State name for debugging
    instance.name = "MainMenuState"
    
    -- Menu options
    instance.options = {"Start New Run", "Load Save (NYI)", "Settings (NYI)", "Exit Game"}
    instance.selectedOption = 1
    
    -- Visual elements
    instance.title = "//ROGUE_PROCESS"
    instance.subtitle = "Neural Network Intrusion Simulator"
    instance.animationTime = 0
    instance.logoGlitch = 0
    instance.backgroundParticles = {}
    
    -- Initialize background particles
    instance:initializeParticles()
    
    return instance
end

-- Initialize visual effects
function MainMenuState:initializeParticles()
    local nativeW = self.config.nativeResolution.width
    local nativeH = self.config.nativeResolution.height
    
    for i = 1, 20 do
        table.insert(self.backgroundParticles, {
            x = love.math.random(0, nativeW),
            y = love.math.random(0, nativeH),
            vx = love.math.random(-20, 20),
            vy = love.math.random(-20, 20),
            alpha = love.math.random(0.1, 0.3),
            size = love.math.random(1, 3)
        })
    end
end

-- State lifecycle: Enter
function MainMenuState:enter(...)
    BaseState.enter(self, ...)
    
    print("[MainMenuState] Entered (Phase 2 version)")
    
    -- Reset animation
    self.animationTime = 0
    
    -- Set background color
    love.graphics.setBackgroundColor(self.config.activeColors.background)
    
    -- Emit event
    if self.events then
        self.events:emit("menu_opened", {state = "main_menu"})
    end
    
    -- Play menu music or sound (if implemented)
    if _G.SFX then
        _G.SFX.play("menu_ambient")
    end
end

-- State lifecycle: Leave
function MainMenuState:leave()
    print("[MainMenuState] Left")
    
    -- Emit event
    if self.events then
        self.events:emit("menu_closed", {state = "main_menu"})
    end
    
    BaseState.leave(self)
end

-- Update logic
function MainMenuState:update(dt)
    BaseState.update(self, dt)
    
    if self.paused then return end
    
    -- Update animations
    self.animationTime = self.animationTime + dt
    self.logoGlitch = self.logoGlitch + dt * 10
    
    -- Update background particles
    local nativeW = self.config.nativeResolution.width
    local nativeH = self.config.nativeResolution.height
    
    for _, particle in ipairs(self.backgroundParticles) do
        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt
        
        -- Wrap around screen
        if particle.x < 0 then particle.x = nativeW end
        if particle.x > nativeW then particle.x = 0 end
        if particle.y < 0 then particle.y = nativeH end
        if particle.y > nativeH then particle.y = 0 end
    end
end

-- Draw logic
function MainMenuState:draw()
    if not self.visible then return end
    
    BaseState.draw(self)
    
    -- Get resources
    local fonts = self.resources:getFonts()
    local nativeW = self.config.nativeResolution.width
    local nativeH = self.config.nativeResolution.height
    
    -- Draw background particles
    self:drawBackgroundParticles()
    
    -- Draw title with glitch effect
    self:drawTitle(fonts, nativeW, nativeH)
    
    -- Draw menu options
    self:drawMenuOptions(fonts, nativeW, nativeH)
    
    -- Draw version text
    self:drawVersionInfo(fonts, nativeW, nativeH)
    
    -- Draw system info panel
    self:drawSystemInfo(fonts, nativeW, nativeH)
end

-- Draw background particles
function MainMenuState:drawBackgroundParticles()
    love.graphics.setColor(self.config.activeColors.accent[1], 
                          self.config.activeColors.accent[2], 
                          self.config.activeColors.accent[3], 0.3)
    
    for _, particle in ipairs(self.backgroundParticles) do
        love.graphics.setColor(self.config.activeColors.accent[1], 
                              self.config.activeColors.accent[2], 
                              self.config.activeColors.accent[3], 
                              particle.alpha)
        love.graphics.circle("fill", particle.x, particle.y, particle.size)
    end
end

-- Draw title with glitch effect
function MainMenuState:drawTitle(fonts, nativeW, nativeH)
    love.graphics.setFont(fonts.title)
    
    -- Glitch effect
    local glitchOffset = 0
    if math.sin(self.logoGlitch) > 0.9 then
        glitchOffset = love.math.random(-3, 3)
    end
    
    -- Shadow/glitch layer
    love.graphics.setColor(self.config.activeColors.highlight[1] * 0.5,
                          self.config.activeColors.highlight[2] * 0.5,
                          self.config.activeColors.highlight[3] * 0.5, 0.5)
    love.graphics.printf(self.title, glitchOffset - 2, 60 + glitchOffset, nativeW, "center")
    
    -- Main title
    love.graphics.setColor(self.config.activeColors.highlight)
    love.graphics.printf(self.title, 0, 60, nativeW, "center")
    
    -- Subtitle
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(self.config.activeColors.text)
    love.graphics.printf(self.subtitle, 0, 95, nativeW, "center")
end

-- Draw menu options
function MainMenuState:drawMenuOptions(fonts, nativeW, nativeH)
    local menuY = nativeH / 2 - 20
    local itemHeight = 30
    
    love.graphics.setFont(fonts.medium)
    
    for i, option in ipairs(self.options) do
        local yPos = menuY + (i - 1) * itemHeight
        local isSelected = (i == self.selectedOption)
        
        if isSelected then
            -- Selection highlight with pulse
            local pulse = 0.7 + 0.3 * math.sin(self.animationTime * 3)
            love.graphics.setColor(self.config.activeColors.highlight[1] * pulse,
                                  self.config.activeColors.highlight[2] * pulse,
                                  self.config.activeColors.highlight[3] * pulse, 0.3)
            
            local boxW = fonts.medium:getWidth(option) + 20
            local boxX = (nativeW - boxW) / 2
            love.graphics.rectangle("fill", boxX, yPos - 3, boxW, itemHeight - 10)
            
            -- Selected text
            love.graphics.setColor(self.config.activeColors.highlight)
            love.graphics.printf("> " .. option .. " <", 0, yPos, nativeW, "center")
        else
            -- Unselected text
            love.graphics.setColor(self.config.activeColors.ui_text_default)
            love.graphics.printf(option, 0, yPos, nativeW, "center")
        end
    end
end

-- Draw version info
function MainMenuState:drawVersionInfo(fonts, nativeW, nativeH)
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(self.config.activeColors.ui_text_default[1],
                          self.config.activeColors.ui_text_default[2],
                          self.config.activeColors.ui_text_default[3], 0.5)
    
    local versionText = "v0.1.0-alpha | Phase 2 Architecture"
    love.graphics.printf(versionText, 0, nativeH - fonts.small:getHeight() - 10, nativeW, "center")
end

-- Draw system info panel
function MainMenuState:drawSystemInfo(fonts, nativeW, nativeH)
    local infoPanelW, infoPanelH = 200, 80
    local infoPanelX, infoPanelY = nativeW - infoPanelW - 20, 20
    
    UIHelpers.drawPanel(infoPanelX, infoPanelY, infoPanelW, infoPanelH, "SYS_INFO", "compact")
    
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(self.config.activeColors.ui_text_default)
    
    love.graphics.print("NEURAL_NET: ONLINE", infoPanelX + 10, infoPanelY + 25)
    
    -- Get unlocked cores count from MetaProgress
    local coreCount = 1
    if _G.MetaProgress and _G.MetaProgress.data and _G.MetaProgress.data.unlockedAICoreIds then
        coreCount = 0
        for _ in pairs(_G.MetaProgress.data.unlockedAICoreIds) do
            coreCount = coreCount + 1
        end
    end
    love.graphics.print("CORES: " .. coreCount, infoPanelX + 10, infoPanelY + 40)
    love.graphics.print("STATUS: READY", infoPanelX + 10, infoPanelY + 55)
end

-- Handle keyboard input
function MainMenuState:keypressed(key, scancode, isRepeat)
    if key == "up" then
        self.selectedOption = math.max(1, self.selectedOption - 1)
        if _G.SFX then _G.SFX.play("ui_navigate") end
        return true
        
    elseif key == "down" then
        self.selectedOption = math.min(#self.options, self.selectedOption + 1)
        if _G.SFX then _G.SFX.play("ui_navigate") end
        return true
        
    elseif key == "return" or key == "kpenter" then
        local selected = self.options[self.selectedOption]
        if _G.SFX then _G.SFX.play("ui_select") end
        
        self:handleMenuSelection(selected)
        return true
    end
    
    return false
end

-- Handle menu selection
function MainMenuState:handleMenuSelection(selected)
    if selected == "Start New Run" then
        -- Emit event before transition
        if self.events then
            self.events:emit("menu_option_selected", {option = "new_run"})
        end
        
        -- Transition to new run state
        -- For Phase 2, we'll use legacy GameState for states not yet migrated
        if _G.GameState then
            _G.GameState.switch("newrun")
        else
            -- Future: use new StateManager when all states migrated
            self.stateManager:switch("newrun")
        end
        
    elseif selected == "Exit Game" then
        -- Emit exit event
        if self.events then
            self.events:emit("menu_option_selected", {option = "exit"})
            self.events:emit("game_exit_requested", {})
        end
        
        love.event.quit()
        
    else
        -- Not yet implemented
        print(selected .. " selected (Not Yet Implemented)")
        if _G.SFX then _G.SFX.play("ui_error") end
        
        if self.events then
            self.events:emit("menu_option_selected", {option = selected, implemented = false})
        end
    end
end

return MainMenuState