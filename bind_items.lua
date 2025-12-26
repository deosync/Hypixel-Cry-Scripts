local inventory = require("libs/inventory_utils")
local glfwKeys  = require("libs/GLFW_keys")

local show_keybinds = true

local key_florid = 88   -- X
local key_aotv   = 4    -- Mouse5
local key_rogue  = 82   -- R

local waiting_bind = nil   -- "florid" / "aotv" / "rogue"

local GLFW_KEY_END = 269   -- End [web:66]

local function keyName(code)
    return glfwKeys.name(code)
end

--------------------------------------------------
-- ОБРАБОТЧИК КЛАВИШ
--------------------------------------------------
registerKeyEvent(function(key, action)
    -- Toggle GUI по End
    if key == GLFW_KEY_END and action == "Press" then
        show_keybinds = not show_keybinds
        return
    end

    -- Режим ребинда
    if waiting_bind and action == "Press" then
        if waiting_bind == "florid" then
            key_florid = key
        elseif waiting_bind == "aotv" then
            key_aotv = key
        elseif waiting_bind == "rogue" then
            key_rogue = key
        end
        player.addMessage("New key for " .. waiting_bind .. ": " .. keyName(key))
        waiting_bind = nil
        return
    end

    if action ~= "Press" then return end
    if player.inventory.isAnyScreenOpened() then return end

    if key == key_florid then
        local slot = inventory.findItemInHotbar("FLORID_ZOMBIE_SWORD")
        if slot then player.input.silentUse(slot) end
    elseif key == key_aotv then
        local slot = inventory.findItemInHotbar("ASPECT_OF_THE_VOID")
        if slot then player.input.silentUse(slot) end
    elseif key == key_rogue then
        local slot = inventory.findItemInHotbar("ROGUE_SWORD")
        if slot then player.input.silentUse(slot) end
    end
end)

--------------------------------------------------
-- IMGUI ОКНО
--------------------------------------------------
registerImGuiRenderEvent(function()
    if not show_keybinds then return end

    local flags = imgui.constants.WindowFlags_NoResize +
                  imgui.constants.WindowFlags_NoCollapse

    if imgui.begin("Quick Use", flags) then
        imgui.text("Quick item usage binds")
        imgui.separator()

        -- Кнопка "Hide" (то же, что End)
        if imgui.button("Hide", 50, 18) then
            show_keybinds = false
        end

        imgui.separator()

        -- Florid
        imgui.bulletText("Florid Zombie: " .. keyName(key_florid))
        imgui.sameLine(200, 0)
        if imgui.button(waiting_bind == "florid" and "Press key..." or "Rebind##florid", 90, 18) then
            waiting_bind = "florid"
            player.addMessage("Press new key for Florid")
        end

        -- AOTV
        imgui.bulletText("AOTV: " .. keyName(key_aotv))
        imgui.sameLine(200, 0)
        if imgui.button(waiting_bind == "aotv" and "Press key..." or "Rebind##aotv", 90, 18) then
            waiting_bind = "aotv"
            player.addMessage("Press new key for AOTV")
        end

        -- Rogue
        imgui.bulletText("Rogue Sword: " .. keyName(key_rogue))
        imgui.sameLine(200, 0)
        if imgui.button(waiting_bind == "rogue" and "Press key..." or "Rebind##rogue", 90, 18) then
            waiting_bind = "rogue"
            player.addMessage("Press new key for Rogue Sword")
        end
    end
    imgui.endBegin()
end)
