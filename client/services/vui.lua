uiopen = false

VUI = {}

local Core = exports.vorp_core:GetCore()
local LabelsLUT = {}
local fetchedOnce = false

local function fetchLabelsLUTSync()
    local ok, result = pcall(function()
        return Core.Callback.TriggerAwait("vorp_crafting:GetLabelLUT")
    end)

    if ok and type(result) == "table" then
        LabelsLUT = result
    else
        if not fetchedOnce then
            print("^3[CRAFTING]^7 Failed to fetch LabelLUT (will retry on next open).")
            fetchedOnce = true
        end
    end
end

-- === Open UI ===
VUI.OpenUI = function(location)
    local allText = _all()
    if not allText then return end

    uiopen = true

    -- Collect categories for this location
    local Categories = {}
    if not location or location.Categories == 0 or location.Categories == nil then
        Categories = Config.Categories
    else
        for _, ident in pairs(location.Categories) do
            for _, cat in ipairs(Config.Categories) do
                if ident == cat.ident then
                    Categories[#Categories+1] = cat
                    break
                end
            end
        end
    end

    if Config.KneelingAnimation then
        Animations.forceRestScenario(true)
    end

    -- Ensure LUT is available
    fetchLabelsLUTSync()

    SendNUIMessage({
        type       = "vorp-craft-open",
        craftables = Config.Crafting,
        categories = Categories,
        crafttime  = Config.CraftTime,
        style      = Config.Styles,
        language   = allText,
        location   = location,
        job        = LocalPlayer.state.Character.Job,
        labels     = LabelsLUT,
    })
    SetNuiFocus(true, true)
end

-- === Animations / Focus handling ===
VUI.Animate = function()
    SendNUIMessage({
        type = 'vorp-craft-animate'
    })
    SetNuiFocus(true, false)
end

VUI.Refocus = function()
    SetNuiFocus(true, true)
end

-- === NUI Callbacks ===
RegisterNUICallback('vorp-craft-close', function(args, cb)
    SetNuiFocus(false, false)
    uiopen = false
    if Config.KneelingAnimation then
        Animations.forceRestScenario(false)
    end
    cb('ok')
end)

RegisterNUICallback('vorp-openinv', function(args, cb)
    TriggerServerEvent('vorp:openInv')
    cb('ok')
end)

RegisterNUICallback('vorp-craftevent', function(args, cb)
    local count = tonumber(args.quantity)
    if count ~= nil and count ~= 'close' and count ~= '' and count > 0 then
        TriggerServerEvent('vorp:startcrafting', args.craftable, count, args.location)
        cb('ok')
    else
        TriggerEvent("vorp:TipBottom", _U('InvalidAmount'), 4000)
        cb('invalid')
    end
end)
