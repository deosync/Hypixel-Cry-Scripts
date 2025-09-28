local inventory = {}

function inventory.getItemInHotbar(id)
    for slot = 0, 8 do
        local item = player.inventory.getStack(slot)
        if item and item.skyblock_id == id then
            return slot
        end
    end
    return nil
end

function inventory.findItemInHotbar(id)
    for slot = 0, 8 do
        local item = player.inventory.getStack(slot)
        if item and string.find(item.skyblock_id, id) then
            return slot
        end
    end
    return nil
end

return inventory