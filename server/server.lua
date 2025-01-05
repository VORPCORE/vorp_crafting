local Core = exports.vorp_core:GetCore()

CreateThread(function()
    local item = Config.CampFireItem
    exports.vorp_inventory:registerUsableItem(item, function(data)
        exports.vorp_inventory:subItemById(data.source, data.item.id)
        TriggerClientEvent("vorp:campfire", data.source)
    end)
end)

Core.Callback.Register("vorp_crafting:GetJob", function(source, cb)
    local Character = Core.getUser(source).getUsedCharacter
    local job = Character.job
    cb(job)
end)

RegisterNetEvent('vorp:openInv', function()
    local _source = source
    exports.vorp_inventory:openInventory(_source)
end)

RegisterNetEvent('vorp:startcrafting', function(craftable, countz)
    local _source = source
    local Character = Core.getUser(_source).getUsedCharacter

    local function getServerCraftable()
        local crafting = nil
        for _, v in ipairs(Config.Crafting) do
            if v.Text == craftable.Text then
                crafting = v
                break
            end
        end

        return crafting
    end

    local crafting = getServerCraftable()

    if not crafting then
        return
    end

    local playerjob = Character.job
    local job = crafting.Job
    local craft = false

    if job == 0 then
        craft = true
    end

    if job ~= 0 then
        for _, v in pairs(job) do
            if v == playerjob then
                craft = true
            end
        end
    end

    if not craft then
        Core.NotifyObjective(_source, _U('NotJob'), 5000)
        return
    end

    if not crafting then
        return
    end

    local reward = crafting.Reward
    local craftcheck = false
    local craftcheck_1 = false
    local itemsToRemove = {}

    local inventory = exports.vorp_inventory:getUserInventoryItems(source)
    if not inventory then return end

    for _, value in pairs(inventory) do
        for _, item in ipairs(crafting.Items) do
            if value.name == item.name then
                --if can usedecay then check if theres any item with that percentage to craft
                if item.canUseDecay and value.isDegradable then
                    if value.percentage >= item.canUseDecay then
                        local pcount = value.count
                        local icount = item.count * countz
                        if pcount >= icount then
                            craftcheck = true
                            if item.take == nil or item.take == true then
                                table.insert(itemsToRemove, { data = value, count = item.count * countz })
                            end
                        end
                    end
                end

                if not item.canUseDecay and not value.isDegradable then
                    local pcount = value.count
                    local icount = item.count * countz
                    if pcount >= icount then
                        craftcheck_1 = true
                        if item.take == nil or item.take == true then
                            table.insert(itemsToRemove, { data = value, count = item.count * countz })
                        end
                    end
                end
            end
        end
    end

    -- both  must be true
    if not craftcheck or not craftcheck_1 then
        return Core.NotifyObjective(_source, _U('NotEnough'), 5000)
    end

    -- Differentiate between items and weapons
    if crafting.Type == "weapon" then
        local ammo = { ["nothing"] = 0 }
        local components = {}

        --[[  local count = 0
        for _, rwd in pairs(crafting.Reward) do
            count = count + rwd.count
        end ]]

        for index, v in ipairs(reward) do
            local canCarry = exports.vorp_inventory:canCarryWeapons(_source, v.count * countz, nil, v.name)
            if not canCarry then
                return Core.NotifyObjective(_source, _U('WeaponsFull'), 5000)
            end
        end

        if #itemsToRemove > 0 then
            for _, value in ipairs(itemsToRemove) do
                exports.vorp_inventory:subItemById(_source, value.data.id, nil, nil, value.count)
            end
        end

        for _ = 1, countz do
            for _, v in ipairs(reward) do
                for _ = 1, v.count do
                    exports.vorp_inventory:createWeapon(_source, v.name, ammo, components)
                    Core.AddWebhook(GetPlayerName(_source), Config.Webhook, _U('WebhookWeapon') .. ' ' .. v.name)
                end
            end
        end

        TriggerClientEvent("vorp:crafting", _source, crafting.Animation)
    elseif crafting.Type == "item" then
        local addcount = 0
        local cancarry = false

        if not crafting.UseCurrencyMode then
            for _, rwd in ipairs(reward) do
                local counta = rwd.count * countz
                addcount     = addcount + counta
                cancarry     = exports.vorp_inventory:canCarryItem(_source, rwd.name, counta)
            end
        end

        if crafting.UseCurrencyMode or cancarry then
            if #itemsToRemove > 0 then
                for _, value in ipairs(itemsToRemove) do
                    exports.vorp_inventory:subItemById(_source, value.data.id, nil, nil, value.count)
                end
            end

            for _, v in ipairs(crafting.Reward) do
                local countx = v.count * countz
                if crafting.UseCurrencyMode ~= nil and crafting.CurrencyType ~= nil and crafting.UseCurrencyMode then
                    Character.addCurrency(crafting.CurrencyType, countx)
                else
                    exports.vorp_inventory:addItem(_source, v.name, countx)
                    Core.AddWebhook(GetPlayerName(_source), Config.Webhook, _U('WebhookItem') .. ' x' .. countx .. ' ' .. v.name)
                end
            end

            TriggerClientEvent("vorp:crafting", _source, crafting.Animation)
        else
            TriggerClientEvent("vorp:TipRight", _source, _U('TooFull'), 3000)
        end
    end
end)
