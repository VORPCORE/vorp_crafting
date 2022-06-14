keys = Config.Keys
local iscrafting = false
local keyopen = false
local campJob = Config.CampfireJobLock

Citizen.CreateThread(function()
    UIPrompt.initialize()

    -- Get user job so clientside views can be hidden properly
    TriggerServerEvent('vorp:findjob')

    while true do
        Citizen.Wait(1)
        -- Check for craftable object starters
        local player = PlayerPedId()
        local Coords = GetEntityCoords(player)
        for k, v in pairs(Config.CraftingProps) do
            local campfire = DoesObjectOfTypeExistAtCoords(Coords.x, Coords.y, Coords.z, Config.Distances.campfire,
                GetHashKey(v), 0) -- prop required to interact
            if campfire ~= false and iscrafting == false and uiopen == false then
                local jobcheck = false
                if campJob == 0 then
                    jobcheck = true
                end

                if campJob ~= 0 then
                    for k, v in pairs(campJob) do
                        if v == job then
                            jobcheck = true
                        end
                    end
                end

                if jobcheck then
                    UIPrompt.activate('Campfire')

                    if Citizen.InvokeNative(0xC92AC953F0A982AE, CraftPrompt) then
                        -- Get user job so clientside views can be hidden properly
                        TriggerServerEvent('vorp:findjob')
                        Wait(500) -- Wait to allow findjob some time to return

                        if keyopen == false then
                            VUI.OpenUI({ id = 'campfires' })
                        end
                    end
                end
            end
        end

        -- Check for craftable location starters
        for k, loc in pairs(Config.Locations) do
            local dist = GetDistanceBetweenCoords(loc.x, loc.y, loc.z, Coords.x, Coords.y, Coords.z, 0)
            if Config.Distances.locations > dist and uiopen == false then
                local jobcheck = false
                if loc.Job == 0 then
                    jobcheck = true
                end

                if loc.Job ~= 0 then
                    for k, v in pairs(loc.Job) do
                        if v == job then
                            jobcheck = true
                        end
                    end
                end

                if jobcheck then
                    UIPrompt.activate(loc.name)
                    if Citizen.InvokeNative(0xC92AC953F0A982AE, CraftPrompt) then
                        TriggerServerEvent('vorp:findjob')
                        Wait(500)
                        if keyopen == false then
                            VUI.OpenUI(loc)
                        end
                    end
                end
            end
        end

        -- Hide the native rest prompts while the crafting menu is open
        if (uiopen == true or iscrafting == true) then
            Citizen.InvokeNative(0xF1622CE88A1946FB)
        end
    end
end)

RegisterNetEvent("vorp:setjob")
AddEventHandler("vorp:setjob", function(rjob)
    job = rjob
end)

RegisterNetEvent("vorp:crafting")
AddEventHandler("vorp:crafting", function(animation)
    local playerPed = PlayerPedId()
    iscrafting = true

    VUI.Animate()

    if not animation then
        animation = "craft"
    end

    Animations.playAnimation(playerPed, animation)
    exports['progressBars']:startUI(Config.CraftTime, _U('Crafting'))

    Wait(Config.CraftTime)

    Animations.endAnimation(animation)

    TriggerEvent("vorp:TipRight", _U('FinishedCrafting'), 4000)
    VUI.Refocus()

    keyopen = false
    iscrafting = false
end)
