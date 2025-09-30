-- Config start
local COUGHT_DELAY_MIN = 2   -- Minimum delay before cought
local COUGHT_DELAY_MAX = 4   -- Maximum delay before cought
local ABILITY_DELAY = 23   -- Delay before pressing the ability
local HORIZONTAL_RANGE = 4.25 -- Максимальное горизонтальное расстояние
local VERTICAL_RANGE = 4.5   -- Максимальное вертикальное расстояние
local RELEASE_DELAY_MIN = 1 -- Delay before pushing up
local RELEASE_DELAY_MAX = 2 -- Delay before pushing up
local ENTITY_CHECK_DELAY = 2 -- Delay the next check that the entity is nearby
local ENTITY_SPAWN_DELAY = 10 -- Delay in checking that the entity has appeared
local PREFIX = "§7[§6Hypixel Cry§7]" -- Chat prefix
local MODE = "Normal" -- "OneShot", "Normal"
local SPEED = "Fastest" -- "Fastest", "Normal"
local BLACKLISTED_CREATURES_FOR_ABILITY = {
    "Titanoboa",
    -- Добавьте сюда другие названия сущностей, которые должны останавливать скрипт
}
-- Config end

local inv = require("inventory_utils")

local FISHGROD_SLOT = 0
local ABILITY_SLOT = 1

local state = {
    tick = 0,
    phase = "idle", -- "idle", "pressing", "pressed", "ability", "releasing"
    targetEntity = {}
}

local caught = 0
local abilities = 0
local killed = 0

local PRESS_DELAY = 1
local RELEASE_DELAY = 1

local macroStartTime = nil -- Время начала работы макроса на точке
local totalMacroTime = 0 -- Общее время работы макроса
macroStartTime = os.time()

local started = false
local scriptStopped = false

local clockEmojis = {"🕐","🕑","🕒","🕓","🕔","🕕","🕖","🕗","🕘","🕙","🕚","🕛"}
local emojiIndex = 1
local emojiChangeDelay = 10  -- количество тиков между сменой эмодзи
local emojiTick = 0

function animateClockEmoji()
  emojiTick = emojiTick + 1
  if emojiTick >= emojiChangeDelay then
    emojiTick = 0
    emojiIndex = emojiIndex + 1
    if emojiIndex > #clockEmojis then
      emojiIndex = 1
    end
  end
  return clockEmojis[emojiIndex]
end

register2DRenderer(function(context)
    local scale = context.getWindowScale()

	local rod_item = inv.findItemInHotbar("ROD")
	if rod_item then
		FISHGROD_SLOT = rod_item
	end
	
	local ability_item = inv.findItemInHotbar("YETI_SWORD")
	if not ability_item then
		ability_item = inv.findItemInHotbar("HYPERION")
	end
	ABILITY_SLOT = ability_item
	
	if player.input.getSelectedSlot() ~= rod_item and player.input.getSelectedSlot() ~= ability_item then
		macroStartTime = os.time()
		return
	end
	if scriptStopped then
        local scale = context.getWindowScale()
        local stopText = "§cSCRIPT STOPPED - Blacklisted creature detected!"
        local textWidth = context.getTextWidth(stopText)
        local centerX = (scale.width - textWidth) / 2
        local centerY = scale.height / 2
        
        local obj = {
            x = centerX, y = centerY, scale = 1,
            text = stopText,
            red = 0, green = 0, blue = 0
        }
        context.renderText(obj)
        return
    end

    local elapsed = totalMacroTime
    if macroStartTime then
        elapsed = elapsed + (os.time() - macroStartTime)
    end
	
	local status = "✖"
	if player.fishHook then
		status = "✔"
	elseif state.phase == "spawn_chech" or state.phase == "ability" then
		status = "⚔"
	end
	
    -- Форматирование времени в часы, минуты, секунды
    local hours = math.floor(elapsed / 3600)
    local minutes = math.floor((elapsed % 3600) / 60)
    local seconds = elapsed % 60
	local timeStr = string.format("%02d:%02d:%02d", hours, minutes, seconds)
	if hours == 0 then
		timeStr = string.format("%02d:%02d", minutes, seconds)
		if minutes == 0 then
			timeStr = string.format("%02d", seconds)
		end
	end

    -- Тексты для отображения на экране
    local titleText = "§9AFK Fishing " .. status
    local abilitiesText = "§b🎣 " .. caught .. " §c⚔ " .. killed .. " §6☄ " .. abilities
	if MODE == "OneShot" then
		abilitiesText = "§b🎣 " .. caught .. " §6☄ " .. abilities
	end
	if not ability_item then
		abilitiesText = "§b🎣 " .. caught
	end
    local timeText = "§f" .. animateClockEmoji() .. " " .. timeStr

    -- Получаем ширину текстов для центрирования
    local titleWidth = context.getTextWidth(titleText)
    local abilitiesWidth = context.getTextWidth(abilitiesText)
    local timeWidth = context.getTextWidth(timeText)

    -- Позиции по центру с вертикальными смещениями
    local centerXTitle = (scale.width - titleWidth) / 2
    local centerYTitle = scale.height / 2 - 25
    local centerXAbilities = (scale.width - abilitiesWidth) / 2
    local centerYAbilities = scale.height / 2 - 15
    local centerXTime = (scale.width - timeWidth) / 2
    local centerYTime = scale.height / 2 + 8	

    -- Отрисовка текста на экране
    context.renderText({x = centerXTitle, y = centerYTitle, scale = 1, text = titleText, red = 0, green = 0, blue = 0})
    context.renderText({x = centerXAbilities, y = centerYAbilities, scale = 1, text = abilitiesText, red = 0, green = 0, blue = 0})
    context.renderText({x = centerXTime, y = centerYTime, scale = 1, text = timeText, red = 0, green = 0, blue = 0})
end)

local trackedEntities = {}

local function isEntityInRange(entity)
    if not entity then return false end
    
    local playerPos = player.getPos()
    if not playerPos then return false end
    
    -- Получаем координаты игрока и сущности
    local px, py, pz = playerPos.x, playerPos.y, playerPos.z
    local ex, ey, ez = entity.x, entity.y, entity.z
    
    -- Вычисляем горизонтальное расстояние (игнорируя высоту)
    local horizontalDistance = math.sqrt((px - ex)^2 + (pz - ez)^2)
    
    -- Вычисляем вертикальное расстояние (разница по высоте)
    local verticalDistance = math.abs(py - ey)
    
    -- Проверяем оба условия
    local isHorizontalInRange = horizontalDistance <= HORIZONTAL_RANGE
    local isVerticalInRange = verticalDistance <= VERTICAL_RANGE
    
    return isHorizontalInRange and isVerticalInRange, horizontalDistance, verticalDistance
end

-- Функция для проверки наличия чернокованных сущностей
local function hasBlacklistedCreature()
    local entities = world.getEntities()
    
    for index, entity in ipairs(entities) do
        if entity ~= nil then
            local entityName = entity.display_name
            if entityName then
                -- Проверяем каждое название из черного списка
                for _, blacklistedName in ipairs(BLACKLISTED_CREATURES_FOR_ABILITY) do
                    if string.find(entityName, blacklistedName) then
                        local isInRange = isEntityInRange(entity)
                        if isInRange then
                            return true, entityName, blacklistedName
                        end
                    end
                end
            end
        end
    end
    
    return false, nil, nil
end
-- Функция для проверки наличия нужной сущности поблизости
local function hasTargetEntityNearby()
	local eyePos = player.getEyePosition()
    local entities = world.getEntities()
    local currentEntities = {}
    local foundAny = false
    
    -- Собираем все текущие сущности
    for index, entity in ipairs(entities) do
        if entity ~= nil then
            local entityName = entity.display_name
			if isEntityInRange(entity) and
				entity.uuid ~= player.entity.uuid and 
				entity.type ~= "entity.minecraft.experience_orb" and 
				entity.type ~= "entity.minecraft.fishing_bobber" and 
				entity.type ~= "entity.minecraft.item" and
				entity.type ~= "entity.minecraft.falling_block" and 
				entity.type ~= "entity.minecraft.bat" then
				
				if entity.type ~= "entity.minecraft.armor_stand" then
					--player.addMessage(entity.type)
				end
				if entity.type == "entity.minecraft.squid" or 
					entity.type == "entity.minecraft.zombie" or 
					entity.type == "entity.minecraft.skeleton" or
					entity.type == "entity.minecraft.silverfish" or
					entity.type == "entity.minecraft.guardian" or
					entity.type == "entity.minecraft.witch" or
					entity.type == "entity.minecraft.rabbit" or
					entity.type == "entity.minecraft.iron_golem" or 
					entity.type == "entity.minecraft.ocelot" or
					entity.type == "entity.minecraft.chicken" or 
					entity.type == "entity.minecraft.slime" or 
					entity.type == "entity.minecraft.cow" or
					entity.type == "entity.minecraft.mooshroom" then
					
					--currentEntities[entity.uuid] = true
					foundAny = true
					
					-- Если это новая сущность, добавляем в отслеживаемые
					if not trackedEntities[entity.uuid] then
						--trackedEntities[entity.uuid] = true
					end
				elseif entityName and string.find(entityName, "Lv")  then
					currentEntities[entity.uuid] = true
					foundAny = true
					
					-- Если это новая сущность, добавляем в отслеживаемые
					if not trackedEntities[entity.uuid] then
						trackedEntities[entity.uuid] = true
					end
				end
			end
        end
    end
    
    -- Проверяем, какие сущности исчезли (были убиты)
    for uuid, _ in pairs(trackedEntities) do
        if not currentEntities[uuid] then
            -- Сущность исчезла - увеличиваем счетчик убитых
            killed = killed + 1
            trackedEntities[uuid] = nil  -- Удаляем из отслеживаемых
        end
    end
    
    -- Очищаем trackedEntities от сущностей, которые больше не существуют
    for uuid, _ in pairs(trackedEntities) do
        if not currentEntities[uuid] then
            trackedEntities[uuid] = nil
        end
    end
	
	if foundAny then
		PRESS_DELAY = math.floor(math.random(COUGHT_DELAY_MIN, COUGHT_DELAY_MAX))
		RELEASE_DELAY = math.floor(math.random(RELEASE_DELAY_MIN, RELEASE_DELAY_MAX))
	end
    
    return foundAny
end

registerClientTickPre(function()
	if not scriptStopped then
        local hasBlacklisted, entityName, blacklistedName = hasBlacklistedCreature()
        if hasBlacklisted then
            scriptStopped = true
            player.addMessage(PREFIX .. " §cSCRIPT STOPPED! Detected blacklisted creature: " .. " §c(Matched: §e" .. blacklistedName .. "§c)")
            player.addMessage(PREFIX .. " §cPlease kill the creature and restart the script manually.")
            return
        end
    end

    if player.fishHook == nil and not started then
		player.input.setSelectedSlot(FISHGROD_SLOT)
        player.input.silentUse(FISHGROD_SLOT)
        started = true
    elseif player.fishHook then
		started = true
	end

    local entities = world.getEntities()
    local foundTarget = false

    -- Поиск целевой entity (рыболовной)
    for index, entity in ipairs(entities) do
        if entity ~= nil then
            local entityName = entity.name
            if entityName and (string.find(entityName, "!!!") or string.find(entityName, "ǃǃǃ") or string.find(entityName, "ꜝꜝꜝ")) and player.fishHook and (state.targetEntity.uuid ~= entity.uuid) then
                foundTarget = true

                if state.phase == "idle" then
                    state.targetEntity = entity
                    state.phase = "pressing"
                    state.tick = 0
                end
                break
            end
        end
    end

    -- Обработка состояний
    if state.phase == "pressing" then
        player.input.setSelectedSlot(FISHGROD_SLOT)
        state.tick = state.tick + 1
        if state.tick >= PRESS_DELAY then
            player.input.silentUse(FISHGROD_SLOT)
            if MODE == "OneShot" and ABILITY_SLOT then
                player.input.silentUse(ABILITY_SLOT)
                abilities = abilities + 1
                state.phase = "releasing"
                state.tick = 0
            else
                caught = caught + 1
                state.phase = "pressed"
                state.tick = 0
            end
        end
    elseif state.phase == "pressed" then
        state.tick = state.tick + 1
		local hasLvEntity = hasTargetEntityNearby()
        if hasLvEntity or state.tick >= ENTITY_SPAWN_DELAY then
			if ABILITY_SLOT then
				state.phase = "ability"
			else
				state.phase = "releasing"
			end
			if SPEED == "Fastest" then
				state.tick = ENTITY_CHECK_DELAY
			else
				state.tick = 0
			end
        end
    elseif state.phase == "ability" then
        state.tick = state.tick + 1
        
        -- Задержка перед проверкой сущности
        if state.tick <= ENTITY_CHECK_DELAY then
            return
        end
        
        -- Проверяем наличие сущности с "Lv" поблизости
        local hasLvEntity = hasTargetEntityNearby()
        
        if hasLvEntity then
            player.input.setSelectedSlot(ABILITY_SLOT)
            -- Вычисляем тики после задержки
            local ticksAfterDelay = state.tick - ENTITY_CHECK_DELAY
            
            -- Первая проверка после задержки - используем сразу
            if ticksAfterDelay == 1 then
                player.input.silentUse(ABILITY_SLOT)
                abilities = abilities + 1
                player.addMessage(PREFIX .. " §cUsed ability immediately - §3Sea Creature §centity nearby")
                state.tick = ENTITY_CHECK_DELAY + 2
            else
                if ticksAfterDelay >= ABILITY_DELAY then
                    player.input.silentUse(ABILITY_SLOT)
                    abilities = abilities + 1
                    player.addMessage(PREFIX .. " §cUsed ability after delay - §3Sea Creature §centity nearby")
                    state.tick =  ENTITY_CHECK_DELAY + 2
                end
            end
        else
            player.addMessage(PREFIX .. " §cNo §3Sea Creature §centity nearby, skipping damage ability")
			if SPEED == "Fastest" then
				player.input.setSelectedSlot(FISHGROD_SLOT)
				player.input.silentUse(FISHGROD_SLOT)
				state.phase = "idle"
			else
				state.phase = "releasing"
			end
            state.tick = 0
        end
    elseif state.phase == "releasing" then
        state.tick = state.tick + 1
        if state.tick >= RELEASE_DELAY then
            player.input.silentUse(FISHGROD_SLOT)
            state.phase = "idle"
            state.tick = 0
        end
    end
end)

return "loaded"