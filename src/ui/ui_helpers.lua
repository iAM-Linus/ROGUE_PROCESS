-- src/ui/ui_helpers.lua - Fixed version with ASCII-safe characters
local config = ServiceLocator.get("config")
local fonts = ServiceLocator.get("fonts")

local UIHelpers = {}

-- Enhanced panel drawing with animated borders and glow effects
function UIHelpers.drawPanel(x, y, width, height, title, style)
    style = style or "default"
    local time = love.timer.getTime()
    
    -- Use simple ASCII characters that work everywhere
    local borderChars = {
        topLeft = "+", topRight = "+", bottomLeft = "+", bottomRight = "+",
        h = "-", v = "|", titleLeft = "+", titleMid = "-", titleRight = "+"
    }

    local font = fonts.small
    local titleFont = fonts.medium
    local charW = font:getWidth(borderChars.h)
    local charH = font:getHeight()
    local titleTextHeight = titleFont:getHeight()

    -- Style-based colors with animation
    local borderColor = config.activeColors.ui_panel_border
    local titleColor = config.activeColors.ui_panel_title
    local bgColor = nil
    local glowIntensity = 0
    
    if style == "highlighted" then
        local pulse = 0.7 + 0.3 * math.sin(time * 3)
        borderColor = {config.activeColors.highlight[1] * pulse, 
                      config.activeColors.highlight[2] * pulse, 
                      config.activeColors.highlight[3] * pulse, 1}
        titleColor = borderColor
        glowIntensity = pulse * 0.3
    elseif style == "compact" then
        borderColor = {config.activeColors.ui_panel_border[1] * 0.7, 
                      config.activeColors.ui_panel_border[2] * 0.7, 
                      config.activeColors.ui_panel_border[3] * 0.7, 
                      config.activeColors.ui_panel_border[4] or 1}
    elseif style == "warning" then
        local flash = 0.8 + 0.4 * math.sin(time * 6)
        borderColor = {1, 0.5, 0.2, flash}
        titleColor = borderColor
        glowIntensity = flash * 0.4
    end

    -- Background with subtle animation
    if bgColor then
        love.graphics.setColor(bgColor)
        love.graphics.rectangle("fill", x, y, width, height)
    end
    
    -- Glow effect for highlighted panels
    if glowIntensity > 0 then
        love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], glowIntensity)
        for i = 1, 3 do
            love.graphics.setLineWidth(i)
            love.graphics.rectangle("line", x - i, y - i, width + i*2, height + i*2)
        end
        love.graphics.setLineWidth(1)
    end

    -- Animated border drawing
    love.graphics.setColor(borderColor)
    love.graphics.setFont(font)

    -- Top border with title
    local topRow = borderChars.topLeft
    if title and title ~= "" then
        local titleDisplay = " " .. title .. " "
        local titlePixelWidth = titleFont:getWidth(titleDisplay)
        local availableSpaceForLine = width - 2 * charW
        local titleFitsInLine = titlePixelWidth <= availableSpaceForLine - 2 * charW

        if titleFitsInLine then
            local lineCharsBeforeTitle = math.floor((availableSpaceForLine - titlePixelWidth - 2*charW) / 2 / charW)
            topRow = topRow .. string.rep(borderChars.h, lineCharsBeforeTitle) .. borderChars.titleLeft
            topRow = topRow .. string.rep(" ", math.ceil(titlePixelWidth/charW))
            topRow = topRow .. borderChars.titleRight
            local lineCharsAfterTitle = math.floor(availableSpaceForLine / charW) - lineCharsBeforeTitle - math.ceil(titlePixelWidth/charW) - 2
            topRow = topRow .. string.rep(borderChars.h, math.max(0, lineCharsAfterTitle))
        else
            topRow = topRow .. string.rep(borderChars.h, math.floor(availableSpaceForLine / charW))
        end
    else
        topRow = topRow .. string.rep(borderChars.h, math.floor((width - 2 * charW) / charW))
    end
    topRow = topRow .. borderChars.topRight
    
    love.graphics.print(topRow, x, y)

    -- Animated title text with glow
    if title and title ~= "" then
        love.graphics.setFont(titleFont)
        local titleDisplay = " " .. title .. " "
        local titlePixelWidth = titleFont:getWidth(titleDisplay)
        local titleX = x + charW + math.floor(((width - 2*charW) - titlePixelWidth)/2)
        local titleY = y + (charH - titleTextHeight)/2
        
        -- Title glow effect
        if glowIntensity > 0 then
            love.graphics.setColor(titleColor[1], titleColor[2], titleColor[3], glowIntensity)
            for dx = -1, 1 do
                for dy = -1, 1 do
                    if dx ~= 0 or dy ~= 0 then
                        love.graphics.print(titleDisplay, titleX + dx, titleY + dy)
                    end
                end
            end
        end
        
        love.graphics.setColor(titleColor)
        love.graphics.print(titleDisplay, titleX, titleY)
    end

    -- Bottom and side borders with animation
    love.graphics.setColor(borderColor)
    love.graphics.setFont(font)
    
    local bottomRow = borderChars.bottomLeft .. string.rep(borderChars.h, math.floor((width - 2 * charW) / charW)) .. borderChars.bottomRight
    love.graphics.print(bottomRow, x, y + height - charH)

    -- Animated side borders
    for i = 1, math.floor(height / charH) - 2 do
        local sideAlpha = 0.8 + 0.2 * math.sin(time * 2 + i * 0.5)
        love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], sideAlpha)
        love.graphics.print(borderChars.v, x, y + i * charH)
        love.graphics.print(borderChars.v, x + width - charW, y + i * charH)
        love.graphics.setColor(borderColor) -- Reset for consistency
    end
    
    local padding = charW * 2
    return x + padding, y + charH + (title and title ~= "" and titleTextHeight > charH and titleTextHeight - charH or 0) + padding/2, 
           width - 2 * padding, height - charH - (title and title ~= "" and titleTextHeight > charH and titleTextHeight - charH or 0) - charH - padding
end

-- Enhanced text with multiple glow effects and animations
function UIHelpers.drawTextWithGlow(text, x, y, font, color, align, glowIntensity)
    align = align or "left"
    glowIntensity = glowIntensity or 0.3
    color = color or {1, 1, 1, 1}
    local time = love.timer.getTime()
    
    love.graphics.setFont(font)
    
    -- Calculate position based on alignment
    local drawX = x
    if align == "center" then
        drawX = x - font:getWidth(text) / 2
    elseif align == "right" then
        drawX = x - font:getWidth(text)
    end
    
    -- Multi-layer glow effect
    local glowLayers = {
        {offset = 3, alpha = glowIntensity * 0.2},
        {offset = 2, alpha = glowIntensity * 0.4},
        {offset = 1, alpha = glowIntensity * 0.6}
    }
    
    for _, layer in ipairs(glowLayers) do
        love.graphics.setColor(color[1], color[2], color[3], layer.alpha)
        for dx = -layer.offset, layer.offset do
            for dy = -layer.offset, layer.offset do
                if dx ~= 0 or dy ~= 0 then
                    love.graphics.print(text, drawX + dx, y + dy)
                end
            end
        end
    end
    
    -- Subtle text animation
    local textPulse = 0.95 + 0.05 * math.sin(time * 4)
    love.graphics.setColor(color[1] * textPulse, color[2] * textPulse, color[3] * textPulse, color[4] or 1)
    love.graphics.print(text, drawX, y)
end

-- Enhanced button with hover effects and animations
function UIHelpers.drawButton(x, y, width, height, text, isSelected, isPressed, animationTime)
    animationTime = animationTime or love.timer.getTime()
    
    local buttonColor = config.activeColors.ui_panel_border
    local textColor = config.activeColors.ui_text_default
    local bgColor = nil
    local glowIntensity = 0
    
    if isSelected then
        local pulse = 0.7 + 0.3 * math.sin(animationTime * 4)
        buttonColor = {config.activeColors.highlight[1] * pulse, 
                      config.activeColors.highlight[2] * pulse, 
                      config.activeColors.highlight[3] * pulse, 1}
        textColor = config.activeColors.highlight
        bgColor = {config.activeColors.highlight[1] * 0.1, 
                  config.activeColors.highlight[2] * 0.1, 
                  config.activeColors.highlight[3] * 0.1, 0.3}
        glowIntensity = pulse * 0.4
        
        -- Particle effects around selected button
        for i = 1, 3 do
            local particleAngle = animationTime * 2 + i * (math.pi * 2 / 3)
            local particleRadius = 5 + math.sin(animationTime * 3 + i) * 3
            local particleX = x + width/2 + math.cos(particleAngle) * particleRadius
            local particleY = y + height/2 + math.sin(particleAngle) * particleRadius
            
            love.graphics.setColor(buttonColor[1], buttonColor[2], buttonColor[3], 0.6)
            love.graphics.circle("fill", particleX, particleY, 1)
        end
    end
    
    if isPressed then
        bgColor = {config.activeColors.highlight[1] * 0.3, 
                  config.activeColors.highlight[2] * 0.3, 
                  config.activeColors.highlight[3] * 0.3, 0.5}
        glowIntensity = 0.6
    end
    
    -- Glow effect
    if glowIntensity > 0 then
        love.graphics.setColor(buttonColor[1], buttonColor[2], buttonColor[3], glowIntensity * 0.3)
        for i = 1, 4 do
            UIHelpers.drawRoundedRect(x - i, y - i, width + i*2, height + i*2, 4 + i, "line")
        end
    end
    
    -- Background with animation
    if bgColor then
        love.graphics.setColor(bgColor)
        UIHelpers.drawRoundedRect(x, y, width, height, 4, "fill")
    end
    
    -- Main button border with scan line effect
    love.graphics.setColor(buttonColor)
    UIHelpers.drawRoundedRect(x, y, width, height, 4, "line")
    
    -- Animated scan line for selected buttons
    if isSelected then
        local scanY = y + (animationTime * 60) % height
        love.graphics.setColor(buttonColor[1], buttonColor[2], buttonColor[3], 0.6)
        love.graphics.rectangle("fill", x + 2, scanY, width - 4, 1)
    end
    
    -- Text with subtle animation
    love.graphics.setFont(fonts.medium)
    local textPulse = isSelected and (0.9 + 0.1 * math.sin(animationTime * 8)) or 1
    love.graphics.setColor(textColor[1] * textPulse, textColor[2] * textPulse, textColor[3] * textPulse, textColor[4] or 1)
    local textX = x + width/2 - fonts.medium:getWidth(text)/2
    local textY = y + height/2 - fonts.medium:getHeight()/2
    love.graphics.print(text, textX, textY)
end

-- Enhanced progress bar with animations and effects
function UIHelpers.drawProgressBar(x, y, width, height, percentage, color, backgroundColor)
    percentage = math.max(0, math.min(1, percentage))
    backgroundColor = backgroundColor or {0.2, 0.2, 0.2, 0.8}
    color = color or config.activeColors.highlight
    local time = love.timer.getTime()
    
    -- Background with subtle pulse
    local bgPulse = 0.8 + 0.2 * math.sin(time * 2)
    love.graphics.setColor(backgroundColor[1] * bgPulse, backgroundColor[2] * bgPulse, backgroundColor[3] * bgPulse, backgroundColor[4])
    UIHelpers.drawRoundedRect(x, y, width, height, height/4, "fill")
    
    -- Progress fill with animation
    if percentage > 0 then
        local fillWidth = width * percentage
        
        -- Animated gradient effect
        local segments = math.max(1, math.floor(fillWidth / 4))
        for i = 0, segments - 1 do
            local segmentX = x + (fillWidth / segments) * i
            local segmentWidth = fillWidth / segments
            local segmentIntensity = 0.8 + 0.4 * math.sin(time * 4 + i * 0.3)
            
            love.graphics.setColor(color[1] * segmentIntensity, color[2] * segmentIntensity, color[3] * segmentIntensity, color[4] or 1)
            UIHelpers.drawRoundedRect(segmentX, y, segmentWidth, height, height/4, "fill")
        end
        
        -- Flowing highlight effect
        local flowOffset = (time * 30) % fillWidth
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.rectangle("fill", x + flowOffset - 10, y, 20, height)
        
        -- Top highlight line
        love.graphics.setColor(color[1] * 1.2, color[2] * 1.2, color[3] * 1.2, (color[4] or 1) * 0.8)
        love.graphics.rectangle("fill", x, y, fillWidth, 1)
    end
    
    -- Border with glow for critical values
    local borderColor = config.activeColors.ui_panel_border
    if percentage < 0.25 then
        local criticalFlash = 0.8 + 0.4 * math.sin(time * 8)
        borderColor = {1, 0.3, 0.3, criticalFlash}
        
        -- Critical glow effect
        love.graphics.setColor(1, 0.3, 0.3, criticalFlash * 0.3)
        for i = 1, 3 do
            UIHelpers.drawRoundedRect(x - i, y - i, width + i*2, height + i*2, height/4 + i, "line")
        end
    end
    
    love.graphics.setColor(borderColor)
    UIHelpers.drawRoundedRect(x, y, width, height, height/4, "line")
end

-- Enhanced rounded rectangle with better visual effects
function UIHelpers.drawRoundedRect(x, y, width, height, radius, mode)
    mode = mode or "line"
    radius = math.min(radius, width/2, height/2)
    
    if radius <= 0 then
        love.graphics.rectangle(mode, x, y, width, height)
        return
    end
    
    -- Simplified rounded rectangle using regular rectangles and circles
    if mode == "fill" then
        -- Main rectangles
        love.graphics.rectangle("fill", x + radius, y, width - 2*radius, height)
        love.graphics.rectangle("fill", x, y + radius, width, height - 2*radius)
        
        -- Corner circles for smooth rounding
        love.graphics.circle("fill", x + radius, y + radius, radius)
        love.graphics.circle("fill", x + width - radius, y + radius, radius)
        love.graphics.circle("fill", x + radius, y + height - radius, radius)
        love.graphics.circle("fill", x + width - radius, y + height - radius, radius)
    else
        -- For line mode, just draw a regular rectangle for simplicity
        love.graphics.rectangle("line", x, y, width, height)
    end
end

-- Enhanced selectable list with smooth animations and better visuals
function UIHelpers.drawSelectableList(items, selectedIndex, x, y, width, itemHeight, maxVisibleItems, scrollOffset, animationTime)
    scrollOffset = scrollOffset or 0
    maxVisibleItems = maxVisibleItems or #items
    animationTime = animationTime or love.timer.getTime()

    -- Background panel for the list
    love.graphics.setColor(config.activeColors.background[1], config.activeColors.background[2], config.activeColors.background[3], 0.3)
    UIHelpers.drawRoundedRect(x - 8, y - 4, width + 16, maxVisibleItems * itemHeight + 8, 6, "fill")

    for i = 1, maxVisibleItems do
        local itemActualIndex = i + scrollOffset
        
        if itemActualIndex > #items then break end

        local item = items[itemActualIndex]
        local currentY = y + (i - 1) * itemHeight
        local displayText = item.text
        local isSelected = (itemActualIndex == selectedIndex)

        -- Enhanced selection highlighting with multiple effects
        if isSelected then
            local pulse = 0.8 + 0.2 * math.sin(animationTime * 3)
            local slideOffset = math.sin(animationTime * 4) * 2
            
            -- Multi-layer selection background
            local highlightColor = config.activeColors.highlight
            
            -- Outer glow
            love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], 0.2 * pulse)
            UIHelpers.drawRoundedRect(x - 8, currentY - 4, width + 16, itemHeight, 4, "fill")
            
            -- Main selection background with slide animation
            love.graphics.setColor(highlightColor[1] * pulse, highlightColor[2] * pulse, highlightColor[3] * pulse, 0.4)
            UIHelpers.drawRoundedRect(x - 6 + slideOffset, currentY - 2, width + 12, itemHeight - 2, 3, "fill")
            
            -- Selection border with animation
            love.graphics.setColor(highlightColor[1] * pulse, highlightColor[2] * pulse, highlightColor[3] * pulse, 0.8)
            UIHelpers.drawRoundedRect(x - 6 + slideOffset, currentY - 2, width + 12, itemHeight - 2, 3, "line")
            
            -- Animated selection indicator (simple arrow using ASCII)
            love.graphics.setColor(highlightColor)
            love.graphics.setFont(fonts.small)
            love.graphics.print(">", x - 15, currentY + itemHeight/2 - fonts.small:getHeight()/2)
            
            -- Particle effects for selected item
            for j = 1, 2 do
                local particleX = x + width + 10 + math.sin(animationTime * 2 + j) * 5
                local particleY = currentY + itemHeight/2 + math.cos(animationTime * 3 + j) * 8
                love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], 0.6)
                love.graphics.circle("fill", particleX, particleY, 1)
            end
            
            love.graphics.setColor(config.activeColors.text)
            displayText = ">> " .. displayText
        elseif item.disabled then
            love.graphics.setColor(0.5, 0.5, 0.5, 1)
        else
            -- Subtle hover effect for non-selected items
            local hoverAlpha = 0.05 + 0.02 * math.sin(animationTime + itemActualIndex)
            love.graphics.setColor(config.activeColors.text[1], config.activeColors.text[2], config.activeColors.text[3], hoverAlpha)
            UIHelpers.drawRoundedRect(x - 4, currentY - 1, width + 8, itemHeight - 2, 2, "fill")
            
            love.graphics.setColor(config.activeColors.text)
        end
        
        -- Multi-line text support with better formatting
        love.graphics.setFont(fonts.small)
        
        -- Text shadow for better readability
        if isSelected then
            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.printf(displayText, x + 1, currentY + 1, width, "left")
        end
        
        -- Main text
        if isSelected then
            love.graphics.setColor(config.activeColors.text)
        elseif item.disabled then
            love.graphics.setColor(0.5, 0.5, 0.5, 1)
        else
            love.graphics.setColor(config.activeColors.text)
        end
        
        love.graphics.printf(displayText, x, currentY, width, "left")
    end

    -- Enhanced scrollbar with animation
    if #items > maxVisibleItems then
        local scrollbarX = x + width + 12
        local scrollbarWidth = 6
        local scrollbarHeight = maxVisibleItems * itemHeight
        
        -- Track with glow effect
        love.graphics.setColor(config.activeColors.accent[1], config.activeColors.accent[2], 
                              config.activeColors.accent[3], 0.3)
        UIHelpers.drawRoundedRect(scrollbarX, y, scrollbarWidth, scrollbarHeight, 3, "fill")
        
        -- Track border
        love.graphics.setColor(config.activeColors.accent[1], config.activeColors.accent[2], 
                              config.activeColors.accent[3], 0.6)
        UIHelpers.drawRoundedRect(scrollbarX, y, scrollbarWidth, scrollbarHeight, 3, "line")
        
        -- Animated thumb
        local thumbHeight = math.max(20, scrollbarHeight * (maxVisibleItems / #items))
        local scrollableRange = #items - maxVisibleItems
        local thumbY = y
        if scrollableRange > 0 then
            thumbY = y + (scrollOffset / scrollableRange) * (scrollbarHeight - thumbHeight)
        end
        
        -- Thumb glow
        local thumbPulse = 0.8 + 0.2 * math.sin(animationTime * 4)
        love.graphics.setColor(config.activeColors.accent[1] * thumbPulse, 
                              config.activeColors.accent[2] * thumbPulse, 
                              config.activeColors.accent[3] * thumbPulse, 0.8)
        UIHelpers.drawRoundedRect(scrollbarX, thumbY, scrollbarWidth, thumbHeight, 3, "fill")
        
        -- Thumb highlight
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.rectangle("fill", scrollbarX + 1, thumbY + 1, scrollbarWidth - 2, 1)
    end
end

-- Simple loading spinner using ASCII characters
function UIHelpers.drawLoadingSpinner(x, y, radius, color, animationTime)
    color = color or config.activeColors.accent
    animationTime = animationTime or love.timer.getTime()
    
    local chars = {"|", "/", "-", "\\"}
    local charIndex = math.floor(animationTime * 8) % #chars + 1
    
    love.graphics.setFont(fonts.medium)
    love.graphics.setColor(color)
    love.graphics.print(chars[charIndex], x, y)
end

-- Data stream effect using simple characters
function UIHelpers.drawDataStream(x, y, width, height, speed, density, color)
    speed = speed or 50
    density = density or 0.1
    color = color or config.activeColors.accent
    
    local time = love.timer.getTime() * speed
    love.graphics.setColor(color[1], color[2], color[3], 0.6)
    
    for i = 0, width, 8 do
        local streamY = (y + (time + i * 2) % (height + 40)) - 20
        if love.math.random() < density then
            local chars = {"0", "1", "|", ".", ":", ";"}
            local char = chars[love.math.random(1, #chars)]
            love.graphics.setFont(fonts.small)
            love.graphics.print(char, x + i, streamY)
        end
    end
end

-- Holographic text effect with ASCII-safe implementation
function UIHelpers.drawHolographicText(text, x, y, font, baseColor, animationTime)
    animationTime = animationTime or love.timer.getTime()
    baseColor = baseColor or {0.3, 0.9, 1, 1}
    
    love.graphics.setFont(font)
    
    -- Holographic distortion
    local distortion = math.sin(animationTime * 10) * 1
    
    -- RGB color separation effect
    love.graphics.setColor(1, 0.3, 0.3, 0.3)
    love.graphics.print(text, x - 1 + distortion, y)
    
    love.graphics.setColor(0.3, 1, 0.3, 0.3)
    love.graphics.print(text, x + 1 - distortion, y)
    
    love.graphics.setColor(0.3, 0.3, 1, 0.3)
    love.graphics.print(text, x, y + math.sin(animationTime * 15))
    
    -- Main text with flicker
    local flicker = 0.8 + 0.2 * math.sin(animationTime * 20)
    love.graphics.setColor(baseColor[1] * flicker, baseColor[2] * flicker, baseColor[3] * flicker, baseColor[4])
    love.graphics.print(text, x, y)
    
    -- Scanlines using simple lines
    love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], 0.1)
    for i = 0, font:getHeight(), 2 do
        love.graphics.line(x, y + i, x + font:getWidth(text), y + i)
    end
end

return UIHelpers