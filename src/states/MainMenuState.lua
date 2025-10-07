-- src/states/MainMenuState.lua
local GameState = require "src.states.GameState"
local UIHelpers = require "src.ui.ui_helpers"

local MainMenuState = {}
MainMenuState.__index = MainMenuState

function MainMenuState:new()
    local instance = setmetatable({}, MainMenuState)
    instance.options = {"Start New Run", "Load Save (NYI)", "Settings (NYI)", "Exit Game"}
    instance.selectedOption = 1
    instance.title = "//ROGUE_PROCESS"
    instance.subtitle = "Neural Network Intrusion Simulator"
    instance.animationTime = 0
    instance.logoGlitch = 0
    instance.backgroundParticles = {}
    
    -- Initialize background particles
    for i = 1, 20 do
        table.insert(instance.backgroundParticles, {
            x = love.math.random(0, _G.Config.nativeResolution.width),
            y = love.math.random(0, _G.Config.nativeResolution.height),
            vx = love.math.random(-20, 20),
            vy = love.math.random(-20, 20),
            alpha = love.math.random(0.1, 0.3),
            size = love.math.random(1, 3)
        })
    end
    
    return instance
end

function MainMenuState:enter()
    print("Entered Enhanced MainMenuState")
    self.animationTime = 0
    love.graphics.setBackgroundColor(_G.Config.activeColors.background)
end

function MainMenuState:update(dt)
    self.animationTime = self.animationTime + dt
    self.logoGlitch = self.logoGlitch + dt * 10
    
    -- Update background particles
    for _, particle in ipairs(self.backgroundParticles) do
        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt
        
        -- Wrap around screen
        if particle.x < 0 then particle.x = _G.Config.nativeResolution.width end
        if particle.x > _G.Config.nativeResolution.width then particle.x = 0 end
        if particle.y < 0 then particle.y = _G.Config.nativeResolution.height end
        if particle.y > _G.Config.nativeResolution.height then particle.y = 0 end
        
        particle.alpha = 0.1 + 0.2 * math.sin(self.animationTime * 2 + particle.x * 0.01)
    end
end

function MainMenuState:draw()
    local nativeW, nativeH = _G.Config.nativeResolution.width, _G.Config.nativeResolution.height
    
    -- Animated background
    love.graphics.setColor(_G.Config.activeColors.background)
    love.graphics.rectangle("fill", 0, 0, nativeW, nativeH)
    
    -- Draw background particles
    for _, particle in ipairs(self.backgroundParticles) do
        love.graphics.setColor(_G.Config.activeColors.accent[1], _G.Config.activeColors.accent[2], 
                              _G.Config.activeColors.accent[3], particle.alpha)
        love.graphics.circle("fill", particle.x, particle.y, particle.size)
    end
    
    -- Grid overlay effect
    love.graphics.setColor(_G.Config.activeColors.accent[1], _G.Config.activeColors.accent[2], 
                          _G.Config.activeColors.accent[3], 0.1)
    local gridSize = 40
    for x = 0, nativeW, gridSize do
        love.graphics.line(x, 0, x, nativeH)
    end
    for y = 0, nativeH, gridSize do
        love.graphics.line(0, y, nativeW, y)
    end
    
    -- Main title with glitch effect
    local titleY = nativeH / 4
    local glitchOffset = math.sin(self.logoGlitch) * 2
    
    -- Glitch layers
    love.graphics.setFont(_G.Fonts.title)
    love.graphics.setColor(1, 0.2, 0.2, 0.3)
    love.graphics.printf(self.title, glitchOffset - 2, titleY - 1, nativeW, "center")
    love.graphics.setColor(0.2, 1, 0.2, 0.3)
    love.graphics.printf(self.title, glitchOffset + 1, titleY + 1, nativeW, "center")
    
    -- Main title
    UIHelpers.drawTextWithGlow(self.title, nativeW/2, titleY + _G.Fonts.title:getHeight()/2, 
                               _G.Fonts.title, _G.Config.activeColors.accent, "center")
    
    -- Subtitle
    love.graphics.setFont(_G.Fonts.medium)
    love.graphics.setColor(_G.Config.activeColors.ui_text_dim)
    love.graphics.printf(self.subtitle, 0, titleY + _G.Fonts.title:getHeight() + 10, nativeW, "center")
    
    -- Menu options with modern styling
    local optionStartY = nativeH / 2 + 20
    local optionHeight = 40
    local optionWidth = 300
    local optionX = (nativeW - optionWidth) / 2

    for i, option in ipairs(self.options) do
        local optionY = optionStartY + (i - 1) * (optionHeight + 10)
        local isSelected = (i == self.selectedOption)
        local isPressed = false -- You could add this for mouse interactions
        
        UIHelpers.drawButton(optionX, optionY, optionWidth, optionHeight, option, 
                           isSelected, isPressed, self.animationTime)
    end
    
    -- Version info and controls
    love.graphics.setFont(_G.Fonts.small)
    love.graphics.setColor(_G.Config.activeColors.ui_text_dim)
    local versionText = "Use UP/DOWN arrows and ENTER | Built with LÖVE " .. love.getVersion()
    love.graphics.printf(versionText, 0, nativeH - _G.Fonts.small:getHeight() - 10, nativeW, "center")
    
    -- System info panel
    local infoPanelW, infoPanelH = 200, 80
    local infoPanelX, infoPanelY = nativeW - infoPanelW - 20, 20
    UIHelpers.drawPanel(infoPanelX, infoPanelY, infoPanelW, infoPanelH, "SYS_INFO", "compact")
    
    love.graphics.setFont(_G.Fonts.small)
    love.graphics.setColor(_G.Config.activeColors.ui_text_default)
    love.graphics.print("NEURAL_NET: ONLINE", infoPanelX + 10, infoPanelY + 25)
    love.graphics.print("CORES: " .. (_G.MetaProgress and #_G.MetaProgress.data.unlockedAICoreIds or 1), 
                       infoPanelX + 10, infoPanelY + 40)
    love.graphics.print("STATUS: READY", infoPanelX + 10, infoPanelY + 55)
end

function MainMenuState:keypressed(key)
    if key == "up" then
        self.selectedOption = math.max(1, self.selectedOption - 1)
        _G.SFX.play("ui_navigate")
    elseif key == "down" then
        self.selectedOption = math.min(#self.options, self.selectedOption + 1)
        _G.SFX.play("ui_navigate")
    elseif key == "return" or key == "kpenter" then
        local selected = self.options[self.selectedOption]
        _G.SFX.play("ui_select")
        
        if selected == "Start New Run" then
            GameState.switch("newrun")
        elseif selected == "Exit Game" then
            love.event.quit()
        else
            print(selected .. " selected (Not Yet Implemented)")
            _G.SFX.play("ui_error")
        end
    end
end

function MainMenuState:leave()
    print("Left Enhanced MainMenuState")
end

return MainMenuState