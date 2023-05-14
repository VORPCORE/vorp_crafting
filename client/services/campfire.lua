local campfire = 0

function placeCampfire()
    if campfire ~= 0 then
        SetEntityAsMissionEntity(campfire)
        DeleteObject(campfire)
        campfire = 0
    end

    local playerPed = PlayerPedId()
    Animations.playAnimation(playerPed, "campfire")

    progressbar.start(_U('PlaceFire'), 20000, function ()
        Animations.endAnimation("campfire")
        Animations.endAnimations() 
        local x,y,z = table.unpack(GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 2.0, -1.55))
        
        local prop = Citizen.InvokeNative("0x509D5878EB39E842", GetHashKey(Config.PlaceableCampfire), x, y, z, true, true, false) --createObject
        SetEntityHeading(prop, GetEntityHeading(PlayerPedId()))
        PlaceObjectOnGroundProperly(prop)
        campfire = prop
    end)
end

RegisterNetEvent('vorp:campfire')
AddEventHandler('vorp:campfire', function()
    placeCampfire()
end)

if Config.Commands.campfire == true then
    RegisterCommand("campfire", function(source, args, rawCommand)
        placeCampfire()
    end, false)
end

if Config.Commands.extinguish == true then
    RegisterCommand('extinguish', function(source, args, rawCommand)
        if campfire ~= 0 then
            SetEntityAsMissionEntity(campfire)
            TaskStartScenarioInPlace(PlayerPedId(), GetHashKey('WORLD_HUMAN_BUCKET_POUR_LOW'), 7000, true, false, false, false)
            TriggerEvent("vorp:TipRight", _U('PutOutFire'), 7000)
            Wait(7000)
            ClearPedTasksImmediately(PlayerPedId())
            DeleteObject(campfire)
            campfire = 0            
        end
    end, false)
end