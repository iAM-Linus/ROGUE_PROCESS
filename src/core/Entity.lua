-- src/core/Entity.lua
local CoreModificationDB = require 'src.core.CoreModificationDB'
local Entity = {}
Entity.__index = Entity

function Entity:new(x, y, char_or_quadName, color_or_nil, name, blocksMovementOverride, hp)
    local instance = setmetatable({}, Entity)
    instance.x = x
    instance.y = y
    instance.quadName = char_or_quadName -- Now this will store the quad name
    instance.spriteColor = color_or_nil or {1,1,1,1} -- Store a tint color, default to white
    --instance.char = char
    --instance.color = color or _G.Config.activeColors.default
    instance.name = name or "ENTITY"
    
    if blocksMovementOverride ~= nil then
        instance.blocksMovement = blocksMovementOverride
    else
        instance.blocksMovement = true -- Default to true if not specified
    end

    instance.hp = hp or 10 -- Default health
    instance.maxHp = hp or 10

    instance.isDead = false
    instance.currentMap = nil -- Will be set when added to a map
    instance.activeStatusEffects = {}
    instance.plannedAction = nil

    -- Animation properties
    instance.animX = x -- Animated position (smoothly moves to actual x,y)
    instance.animY = y
    instance.targetX = x -- Target position for smooth movement
    instance.targetY = y
    instance.moveSpeed = 8 -- Speed of position interpolation
    instance.bobOffset = 0 -- For idle bobbing animation
    instance.flashTimer = 0 -- For damage flash effect
    instance.scaleX = 1 -- For scale animations (damage, death, etc.)
    instance.scaleY = 1
    instance.rotation = 0 -- For rotation animations
    instance.glowIntensity = 0 -- For glow effects
    instance.lastDamageTime = 0
    instance.deathAnimationProgress = 0
    instance.isAnimatingDeath = false

    return instance
end

function Entity:updateAnimation(dt)
    if self.isDead and not self.isAnimatingDeath then
        self.isAnimatingDeath = true
        self.deathAnimationProgress = 0
        
        -- Add death animation to global animation manager if available
        local gs = _G.GameState.current()
        if gs and gs.animationManager then
            gs.animationManager:addFlashEffect({1, 0.3, 0.3, 0.8}, 0.6, 0.3)
            gs.animationManager:addPulseEffect(
                self.animX * _G.Config.spriteSize + _G.Config.spriteSize/2,
                self.animY * _G.Config.spriteSize + _G.Config.spriteSize/2,
                _G.Config.spriteSize * 2,
                {1, 0.5, 0.5, 1},
                0.8
            )
        end
    end
    
    if self.isAnimatingDeath then
        self.deathAnimationProgress = math.min(1, self.deathAnimationProgress + dt * 3)
        self.scaleX = 1 + math.sin(self.deathAnimationProgress * math.pi) * 0.5
        self.scaleY = 1 + math.sin(self.deathAnimationProgress * math.pi) * 0.5
        self.rotation = self.deathAnimationProgress * math.pi * 2
        self.glowIntensity = (1 - self.deathAnimationProgress) * 0.8
    else
        -- Smooth position interpolation
        local lerpSpeed = self.moveSpeed * dt
        self.animX = self.animX + (self.targetX - self.animX) * lerpSpeed
        self.animY = self.animY + (self.targetY - self.animY) * lerpSpeed
        
        -- Idle bobbing animation for living entities
        if not self.isDead then
            self.bobOffset = math.sin(love.timer.getTime() * 2 + self.x * 0.5 + self.y * 0.3) * 1.5
        end
        
        -- Damage flash effect
        if self.flashTimer > 0 then
            self.flashTimer = self.flashTimer - dt
            self.glowIntensity = self.flashTimer * 2
        end
        
        -- Reset scale and rotation for living entities
        self.scaleX = 1 + math.sin(love.timer.getTime() * 4 + self.x) * 0.02 -- Subtle breathing
        self.scaleY = 1 + math.cos(love.timer.getTime() * 4 + self.y) * 0.02
        self.rotation = 0
    end
end

function Entity:move(dx, dy)
    self.x = self.x + dx
    self.y = self.y + dy
    self.targetX = self.x  -- Set animation target
    self.targetY = self.y
    
    -- Add movement trail effect
    local gs = _G.GameState.current()
    if gs and gs.animationManager and not self.isDead then
        gs.animationManager:addParticleTrail(
            self.animX * _G.Config.spriteSize + _G.Config.spriteSize/2,
            self.animY * _G.Config.spriteSize + _G.Config.spriteSize/2,
            self.targetX * _G.Config.spriteSize + _G.Config.spriteSize/2,
            self.targetY * _G.Config.spriteSize + _G.Config.spriteSize/2,
            3, self.spriteColor, 0.3
        )
    end
end

function Entity:draw(tileScreenX, tileScreenY, visualSize)
    -- Update animation
    self:updateAnimation(love.timer.getDelta())
    
    -- Calculate animated screen position
    local animScreenX = tileScreenX + (self.animX - self.x) * visualSize
    local animScreenY = tileScreenY + (self.animY - self.y) * visualSize + self.bobOffset
    
    -- Apply glow effect
    if self.glowIntensity > 0 then
        love.graphics.setColor(1, 1, 1, self.glowIntensity * 0.5)
        for dx = -2, 2 do
            for dy = -2, 2 do
                if dx ~= 0 or dy ~= 0 then
                    self:drawSprite(animScreenX + dx, animScreenY + dy, visualSize, true)
                end
            end
        end
    end
    
    -- Main sprite drawing with transformations
    love.graphics.push()
    love.graphics.translate(animScreenX + visualSize/2, animScreenY + visualSize/2)
    love.graphics.scale(self.scaleX, self.scaleY)
    love.graphics.rotate(self.rotation)
    love.graphics.translate(-visualSize/2, -visualSize/2)
    
    self:drawSprite(0, 0, visualSize, false)
    
    love.graphics.pop()
    
    -- Status effect indicators
    self:drawStatusEffects(animScreenX, animScreenY, visualSize)
end

function Entity:drawSprite(x, y, visualSize, isGlow)
    local quadData = SpriteManager.getQuadData(self.quadName)
    if quadData and quadData.quad and quadData.image and quadData.spriteWidth and quadData.spriteHeight then
        local color = self.spriteColor or {1,1,1,1}
        if isGlow then
            love.graphics.setColor(color[1], color[2], color[3], color[4] * 0.3)
        else
            love.graphics.setColor(color)
        end
        
        love.graphics.draw(quadData.image, quadData.quad, x, y, 0,
                           visualSize / quadData.spriteWidth,
                           visualSize / quadData.spriteHeight)
    else
        -- Fallback character drawing with animation
        love.graphics.setFont(_G.Fonts.medium)
        if isGlow then
            love.graphics.setColor(self.spriteColor[1], self.spriteColor[2], self.spriteColor[3], 0.3)
        else
            love.graphics.setColor(self.spriteColor or {1,0,1,1})
        end
        
        local char = "?"
        if type(self.quadName) == "string" and #self.quadName > 0 then 
            char = self.quadName:sub(1,1) 
        end
        
        love.graphics.print(char,
                            math.floor(x + visualSize / 2 - (_G.Fonts.medium:getWidth(char) / 2)),
                            math.floor(y + visualSize / 2 - (_G.Fonts.medium:getHeight() / 2)))
    end
end

function Entity:drawStatusEffects(x, y, visualSize)
    if #self.activeStatusEffects == 0 then return end
    
    local time = love.timer.getTime()
    local effectY = y - 15
    
    for i, effect in ipairs(self.activeStatusEffects) do
        local effectX = x + (i - 1) * 12 - (#self.activeStatusEffects - 1) * 6
        local bobAmount = math.sin(time * 3 + i) * 2
        
        -- Effect background
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.circle("fill", effectX + 6, effectY + bobAmount, 6)
        
        -- Effect icon/text
        local effectColor = {1, 1, 1, 1}
        if effect.id == "shield" then effectColor = {0.3, 0.7, 1, 1}
        elseif effect.id == "stun" then effectColor = {1, 1, 0.3, 1}
        elseif effect.id == "corrupt_dot" then effectColor = {1, 0.3, 1, 1}
        end
        
        love.graphics.setColor(effectColor)
        love.graphics.setFont(_G.Fonts.small)
        local iconChar = effect.id == "shield" and "◈" or 
                        effect.id == "stun" and "✦" or 
                        effect.id == "corrupt_dot" and "◐" or "●"
        
        love.graphics.printf(iconChar, effectX, effectY + bobAmount - 4, 12, "center")
        
        -- Duration indicator
        if effect.duration and effect.duration > 0 then
            love.graphics.setColor(effectColor[1], effectColor[2], effectColor[3], 0.8)
            love.graphics.print(tostring(effect.duration), effectX + 8, effectY + bobAmount + 3)
        end
    end
end

function Entity:drawHealthBar(x, y, visualSize)
    if self.isDead or self.hp >= self.maxHp then return end
    
    local barWidth = visualSize * 0.8
    local barHeight = 4
    local barX = x + (visualSize - barWidth) / 2
    local barY = y - 8
    
    -- Background
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
    
    -- Health fill with color gradient
    local healthPercent = self.hp / self.maxHp
    local healthColor = {1, 0.3, 0.3, 1}
    if healthPercent > 0.6 then
        healthColor = {0.3, 1, 0.3, 1}
    elseif healthPercent > 0.3 then
        healthColor = {1, 1, 0.3, 1}
    end
    
    love.graphics.setColor(healthColor)
    love.graphics.rectangle("fill", barX, barY, barWidth * healthPercent, barHeight)
    
    -- Animated pulse for low health
    if healthPercent < 0.3 then
        local pulse = 0.3 + 0.7 * math.sin(love.timer.getTime() * 6)
        love.graphics.setColor(1, 0.3, 0.3, pulse * 0.5)
        love.graphics.rectangle("fill", barX, barY, barWidth * healthPercent, barHeight)
    end
    
    -- Border
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.rectangle("line", barX, barY, barWidth, barHeight)
end

function Entity:takeDamage(amount, attackerName)
    local actualAmount = amount
    local shieldEffectInstance = nil

    -- Check for active shield status effect
    for _, effect in ipairs(self.activeStatusEffects) do
        if effect.id == "shield" and effect.data and effect.data.amount > 0 then
            shieldEffectInstance = effect
            break
        end
    end

    if shieldEffectInstance then
        local absorbed = math.min(actualAmount, shieldEffectInstance.data.amount)
        shieldEffectInstance.data.amount = shieldEffectInstance.data.amount - absorbed
        actualAmount = actualAmount - absorbed
        
        local gameplayState = _G.GameState.current()
        if gameplayState and gameplayState.logMessage then
            local shieldMsg = string.format("%s's %s absorbs %d damage! (Shield: %d left)", self.name, shieldEffectInstance.name or "Shield", absorbed, shieldEffectInstance.data.amount)
            gameplayState:logMessage(shieldMsg, Config.activeColors.accent)
            if shieldEffectInstance.data.amount <= 0 then
                 gameplayState:logMessage(self.name .. "'s " .. (shieldEffectInstance.name or "Shield") .. " depleted!", Config.activeColors.accent)
            end
        end
    end

    if actualAmount <= 0 and shieldEffectInstance then -- All damage absorbed by shield
        return string.format("%s's attack fully absorbed by %s's %s.", attackerName or "Attack", self.name, shieldEffectInstance.name or "Shield")
    elseif actualAmount <=0 then -- No damage to apply, but no shield involved
        return string.format("%s's attack dealt no damage to %s.", attackerName or "Attack", self.name)
    end

    -- Apply remaining damage
    self.hp = self.hp - actualAmount
    local message = string.format("%s takes %d damage from %s.", self.name, actualAmount, attackerName or "UNKNOWN_SOURCE")

    local gameplayState = _G.GameState.current() -- Assuming current state is GameplayState
    if gameplayState and gameplayState.triggerScreenShake then
        local shakeIntensity = 3 -- Default shake for generic enemy damage
        if amount > self.maxHp * 0.25 then -- If damage is significant (e.g., >25% of max HP)
            shakeIntensity = 6
        end
        gameplayState:triggerScreenShake(shakeIntensity)
    end

    if actualAmount > 0 then
        if self == _G.GameState.current().player then -- If player is hit
            _G.SFX.play("enemy_attack_hit") -- Or a specific "player_hurt" sound
        else -- An enemy is hit
            _G.SFX.play("player_attack_hit")
        end
    end

    -- Add visual feedback
    self.flashTimer = 0.3
    self.lastDamageTime = love.timer.getTime()
    
    local gs = _G.GameState.current()
    if gs and gs.animationManager then
        -- Screen shake for significant damage
        if amount > self.maxHp * 0.2 then
            gs.animationManager:addScreenShake(5, 0.2)
        end
        
        -- Floating damage text
        gs.animationManager:addFloatingText(
            "-" .. amount,
            self.animX * _G.Config.spriteSize + _G.Config.spriteSize/2,
            self.animY * _G.Config.spriteSize,
            {1, 0.3, 0.3, 1},
            _G.Fonts.medium,
            {vy = -60, duration = 1.2}
        )
        
        -- Impact flash
        gs.animationManager:addFlashEffect({1, 0.8, 0.8, 0.4}, 0.8, 0.15)
    end

    if self.hp <= 0 then
        self.hp = 0
        self:die()
        message = message .. " " .. self.name .. " is destroyed!"
    end
    return message -- Return message for logging
end

function Entity:hasStatusEffect(effectId)
    for _, effect in ipairs(self.activeStatusEffects) do
        if effect.id == effectId then
            return true
        end
    end
    return false
end

function Entity:addStatusEffect(effectData)
    -- Check for stun resistance if this is the player and the effect is stun
    if self == _G.GameState.current().player and effectData.id == "stun" then -- Assuming player is accessible
        if self:hasCoreModificationFlag("error_correction_1") then
            local modDef = CoreModificationDB.getById("error_correction_1")
            if modDef and modDef.getEffectValue then
                local resistChance = modDef.getEffectValue(self, self:getCoreModificationLevel("error_correction_1"))
                if love.math.random() < resistChance then
                    _G.GameState.current():logMessage(self.name .. " resisted " .. (effectData.name or "Stun") .. " due to ECC Memory!", Config.activeColors.pickup)
                    return -- Effect resisted
                end
            end
        end
    end
    -- effectData should be a table like: {id="stun", name="Stunned", duration=2, data={...}}
    local existingEffect = nil
    for i, effect in ipairs(self.activeStatusEffects) do
        if effect.id == effectData.id then
            existingEffect = effect
            break
        end
    end

    if existingEffect then
        -- Refresh duration
        existingEffect.duration = math.max(existingEffect.duration, effectData.duration)
        print(self.name .. " refreshed status effect: " .. effectData.name .. " (Duration: " .. existingEffect.duration .. ")")
    else
        -- Add new effect (copy)
        local newEffect = {}
        for k, v in pairs(effectData) do newEffect[k] = v end
        table.insert(self.activeStatusEffects, newEffect)
        print(self.name .. " gained status effect: " .. effectData.name .. " (Duration: " .. effectData.duration .. ")")
    end
    -- TODO: Add visual indicator change?
end

function Entity:processStatusEffectsStartTurn()
    if self:hasStatusEffect("stun") then
        _G.GameState.current():logMessage(self.name .. " is stunned and cannot act!", {1, 1, 0.5, 1})
        return true
    end
    -- Add checks for other action-preventing effects here (e.g., frozen)
    return false -- Can act
end

function Entity:processStatusEffectsEndTurn(gameplayState)
    local effectsToRemove = {}

    for i, effect in ipairs(self.activeStatusEffects) do
        -- Apply end-of-turn damage/healing effects
        if effect.id == "corrupt_dot" and effect.data and effect.data.damage then
            local dmg = effect.data.damage
            local logMsg = self:takeDamage(dmg, effect.name or "Corruption")
            gameplayState:logMessage(logMsg, Config.activeColors.enemy)
        end
        -- Add other end-of-turn effects here

        -- Tick duration
        effect.duration = effect.duration - 1
        if effect.duration <= 0 then
            table.insert(effectsToRemove, i) -- Mark for removal
            gameplayState:logMessage(self.name .. " 's " .. effect.name .. " effect wore off.", Config.activeColors.text)
        end
    end

    -- Remove expired effects (iterate backwards)
    for i = #effectsToRemove, 1, -1 do
        local indexToRemove = effectsToRemove[i]
        table.remove(self.activeStatusEffects, indexToRemove)
    end
end

function Entity:die()
    self.isDead = true
    self.quadName = "TOMBSTONE_SPRITE"
    self.color = {0.5, 0.5, 0.5, 1} -- Grey
    self.blocksMovement = false -- Corpses don't block movement
    self.name = "Destroyed " .. self.name
    self.activeStatusEffects = {} -- Clear status effects on death
    -- Further death logic (e.g., drop loot) can be added here or in subclasses

    -- Spawn Death Particles
    local gameplayState = _G.GameState.current()

    if gameplayState and gameplayState.objective == "defeat_boss" and self == gameplayState.currentBossEntity then
        gameplayState:logMessage(self.name .. " DEFEATED! Exit portal activated.", Config.activeColors.pickup)
        gameplayState.objectiveMet = true
        if gameplayState.map.exitPortal then
            gameplayState.map.exitPortal.active = true
            gameplayState.map.exitPortal.char = "X" -- Change back to active char
            -- Optional: Spawn exit portal if it wasn't there
            -- if not (gameplayState.map.exitPortal.x > 0) then ... place it ... end
        end
        -- Trigger boss reward sequence (will be handled when player exits)
    end

    _G.SFX.play("enemy_die")

    if gameplayState and gameplayState.systemCorruption then -- Check for the module
        if self.isEnemy then 
            gameplayState.systemCorruption:add(gameplayState.systemCorruption.corruptionPerKill or 1)
        end
    end

    if gameplayState and ParticleFX then
        ParticleFX.spawnDeathExplosion(gameplayState, self)
    end
end

function Entity:act(player, map, entities)
    -- Default entity does nothing on its turn
    -- Returns true if an action was taken, false otherwise
    return false
end


return Entity