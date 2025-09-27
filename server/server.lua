local Core = exports.vorp_core:GetCore()

CreateThread(function()
    local item = Config.CampFireItem
    exports.vorp_inventory:registerUsableItem(item, function(data)
        exports.vorp_inventory:subItemById(data.source, data.item.id)
        TriggerClientEvent("vorp:campfire", data.source)
    end)
end)

Core.Callback.Register("vorp_crafting:GetJob", function(source, cb)
    local user = Core.getUser(source)
    if not user or type(user.getUsedCharacter) ~= "function" then
        cb(nil); return
    end
    local char = user.getUsedCharacter()
    cb(char and char.job or nil)
end)

RegisterNetEvent('vorp:openInv', function()
    local _source = source
    exports.vorp_inventory:openInventory(_source)
end)

RegisterNetEvent('vorp:startcrafting', function(craftable, countz)
    local _source = source
    local Character = Core.getUser(_source).getUsedCharacter()

    local Webhook = '' -- Set your webhook URL here
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
    local itemsToRemove = {}
    local requiredItems = {}


    for _, item in ipairs(crafting.Items) do
        requiredItems[item.name] = {
            required = item.count * countz,
            found = 0,
            canUseDecay = item.canUseDecay,
            take = item.take
        }
    end

    local inventory = exports.vorp_inventory:getUserInventoryItems(_source)
    if not inventory then return end

    for _, value in pairs(inventory) do
        local reqItem = requiredItems[value.name]
        if reqItem then
            if reqItem.canUseDecay then
                if value.isDegradable then
                    if value.percentage >= reqItem.canUseDecay then
                        reqItem.found = reqItem.found + value.count
                        if reqItem.take == nil or reqItem.take == true then
                            table.insert(itemsToRemove, { data = value, count = math.min(value.count, reqItem.required) })
                        end
                    end
                else
                    reqItem.found = reqItem.found + value.count
                    if reqItem.take == nil or reqItem.take == true then
                        table.insert(itemsToRemove, { data = value, count = math.min(value.count, reqItem.required) })
                    end
                end
            else
                reqItem.found = reqItem.found + value.count
                if reqItem.take == nil or reqItem.take == true then
                    table.insert(itemsToRemove, { data = value, count = math.min(value.count, reqItem.required) })
                end
            end
        end
    end

    local craftcheck = true
    for itemName, data in pairs(requiredItems) do
        if data.found < data.required then
            craftcheck = false
            break
        end
    end

    if not craftcheck then
        return Core.NotifyObjective(_source, _U('NotEnough'), 5000)
    end

    -- Differentiate between items and weapons
    if crafting.Type == "weapon" then
        local ammo = { ["nothing"] = 0 }
        local components = {}

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
                    Core.AddWebhook(GetPlayerName(_source), Webhook, _U('WebhookWeapon') .. ' ' .. v.name)
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
                    Core.AddWebhook(GetPlayerName(_source), Webhook, _U('WebhookItem') .. ' x' .. countx .. ' ' .. v.name)
                end
            end

            TriggerClientEvent("vorp:crafting", _source, crafting.Animation)
        else
            TriggerClientEvent("vorp:TipRight", _source, _U('TooFull'), 3000)
        end
    end
end)

-- =====================================================================
-- =============== Crafting sanity check (DB + images) =================
-- =====================================================================
local INV_RES_NAME = GetConvar("vorp_inventory_resource", "vorp_inventory")
local INV_RES_PATH = GetResourcePath(INV_RES_NAME) -- absolute path to resource folder (nil if resource not found)
local DB_MODE = "none"

-- Detect DB adapter and expose a unified checker
local function db_item_exists(name)
    if not name or name == "" then return false end
    local sql = "SELECT 1 FROM items WHERE item = ? LIMIT 1"

    if exports.oxmysql then
        if exports.oxmysql.scalarSync then
            DB_MODE = "oxmysql:scalarSync"
            local ok, val = pcall(function()
                return exports.oxmysql:scalarSync(sql, { name })
            end)
            if ok then return val ~= nil end
        elseif exports.oxmysql.executeSync then
            DB_MODE = "oxmysql:executeSync"
            local ok, rows = pcall(function()
                return exports.oxmysql:executeSync(sql, { name })
            end)
            if ok then return rows and rows[1] ~= nil end
        end
    end

    return false
end

local function file_exists(path)
    if not path then return false end
    local f = io.open(path, "rb")
    if f then f:close() return true end
    return false
end

local function image_exists(name)
    if not INV_RES_PATH then return nil end -- nil => we cannot check (resource not found), we make no noise
    local p = ("%s/html/img/items/%s.png"):format(INV_RES_PATH, name)
    return file_exists(p)
end

-- Helpers
local function trim(s)
    return type(s) == "string" and (s:gsub("^%s+", ""):gsub("%s+$", "")) or s
end

-- main scan
LabelLUT = LabelLUT or {}

Core.Callback.Register("vorp_crafting:GetLabelLUT", function(source, cb)
    cb(LabelLUT or {})
end)

local function is_weapon_name(s) return type(s)=="string" and s:upper():find("^WEAPON_") ~= nil end
local function lower_or_nil(s) return (type(s)=="string" and s~="") and s:lower() or nil end

local function dump_table_lua(tbl)
    if type(tbl) ~= "table" then
        return tostring(tbl)
    end
    local parts = {}
    for k,v in pairs(tbl) do
        local key = tostring(k)
        local val
        if type(v) == "string" then
            val = string.format("%q", v) -- quoted string
        else
            val = tostring(v)
        end
        table.insert(parts, key .. " = " .. val)
    end
    return "{ " .. table.concat(parts, ", ") .. " }"
end

local function scan_crafting_refs()
    local missingDB, missingIMG, malformedReward, missingWeapons = {}, {}, {}, {}
    local checkedDB, checkedIMG = {}, {}

    for _, recipe in ipairs(Config.Crafting or {}) do
        -- 1) Ingredients
        for __, it in ipairs(recipe.Items or {}) do
            local nm = trim(it.name)
            if nm and nm ~= "" then
                -- DB check
                if not checkedDB[nm] then
                    if not db_item_exists(nm) then
                        missingDB[nm] = true
                    end
                    checkedDB[nm] = true
                end

                -- PNG check
                if INV_RES_PATH and not checkedIMG[nm] then
                    local exists = image_exists(nm)
                    if exists == false and not missingDB[nm] then
                        missingIMG[nm] = true
                    end
                    checkedIMG[nm] = true
                end
            else
                malformedReward[#malformedReward+1] = ("empty ingredient in recipe: %s"):format(recipe.Text or "unknown")
            end
        end

        -- 2) Rewards
        for ridx, r in ipairs(recipe.Reward or {}) do
            local rn = trim(r.name)
            if not rn or rn == "" then
                local dump = dump_table_lua(r)
                local dbg = recipe.Text or ("index="..ridx)
                malformedReward[#malformedReward+1] =
                    ("malformed reward in recipe %s → %s"):format(dbg, dump)
            else
                if recipe.Type == "weapon" and is_weapon_name(rn) then
                    local wn = lower_or_nil(rn)
                    if not (LabelLUT[wn] and LabelLUT[wn].label) then
                        missingWeapons[rn] = true
                    end
                else
                    -- DB check
                    if not checkedDB[rn] then
                        if not db_item_exists(rn) then
                            missingDB[rn] = true
                        end
                        checkedDB[rn] = true
                    end
                    -- PNG check
                    if INV_RES_PATH and not checkedIMG[rn] then
                        local exists = image_exists(rn)
                        if exists == false and not missingDB[rn] then
                            missingIMG[rn] = true
                        end
                        checkedIMG[rn] = true
                    end
                end
            end
        end
    end

    -- Exit early if no problems
    if not next(malformedReward) and not next(missingDB) and not next(missingIMG) and not next(missingWeapons) then
        return
    end

    -- Structured logs
    if #malformedReward > 0 then
        print("^1[CONFIG] Invalid recipes detected:^7")
        for _, msg in ipairs(malformedReward) do
            print("   ^1recipe^7 = "..msg)
        end
    end

    if next(missingDB) then
        print("^1[DATABASE] Missing items in DB:^7")
        for nm in pairs(missingDB) do
            print(("   ^1item name^7 = %s"):format(nm))
        end
    end

    if next(missingIMG) then
        print("^6[INVENTORY] Items without PNG icons:^7")
        for nm in pairs(missingIMG) do
            print(("   ^6image name^7 = %s"):format(nm))
        end
    end

    if next(missingWeapons) then
        print("^3[INVENTORY] Missing weapons in config/weapons.lua:^7")
        for nm in pairs(missingWeapons) do
            print(("   ^3weapon name^7 = %s"):format(nm))
        end
    end

    print("^5[INFO] When all errors are fixed, this debug output will disappear.^7")
end

-- =====================================================================
-- Item Labels LUT for Crafting, Single-init, deduplicated logging.
-- =====================================================================
local _lut_inited = false   -- guard to prevent double init

-- ---------- DB helpers ----------
local function qmarks(n) local t = {} for i=1,n do t[i]="?" end return table.concat(t, ",") end

-- DB adapter wrapper
local function db_fetch_all(sql, params)
  if exports.oxmysql and exports.oxmysql.executeSync then
    return exports.oxmysql:executeSync(sql, params or {}) or {}
  end
  print("^7 No oxmysql adapter. Item labels will be empty.")
  return {}
end

-- ---------- Collect all item keys from recipes (ingredients + item-type rewards) ----------
local function collect_item_keys()
    local set = {}
    local function add(n)
        if type(n) == "string" and n ~= "" then set[n:lower()] = true end
    end

    for _, r in ipairs(Config.Crafting or {}) do
        for _, it in ipairs(r.Items or {}) do add(it.name) end
        for _, rw in ipairs(r.Reward or {}) do
            if not (r.Type == "weapon" and is_weapon_name(rw.name)) then
                add(rw.name)
            end
        end
    end

    local arr = {}
    for k in pairs(set) do arr[#arr + 1] = k end
    table.sort(arr)
    return arr
end

-- ---------- Build/Refresh LUT ----------
local function refresh_items_into_lut(out)
    local keys = collect_item_keys()
    if #keys == 0 then
        return 0, 0
    end

    local sql = ("SELECT item, label, `desc`, `limit` FROM items WHERE LOWER(item) IN (%s)")
        :format(qmarks(#keys))
    local rows = db_fetch_all(sql, keys)
    local matched, seen = 0, {}

    for _, r in ipairs(rows) do
        local k = lower_or_nil(r.item)
        if k and not seen[k] then
            out[k] = {
                label = r.label or r.item,
                desc  = r["desc"] or "",
                limit = tonumber(r["limit"]) or nil
            }
            seen[k] = true
            matched = matched + 1
        end
    end

    return matched, #keys
end

local function refresh_weapons_into_lut(out)
    local file = LoadResourceFile(INV_RES_NAME, "config/weapons.lua")
    if not file then
        print(("^7 weapons.lua not found in resource '%s' (skipping weapon labels)."):format(INV_RES_NAME))
        return 0, 0
    end

    -- run the file in a sandbox to capture SharedData.Weapons
    local env = { }
    local chunk, err = load(file, "@weapons.lua", "t", env)
    if not chunk then
        print("^7 Failed to load weapons.lua: "..tostring(err))
        return 0, 0
    end

    local ok, runtimeErr = pcall(chunk)
    if not ok then
        print("^7 Failed to execute weapons.lua: "..tostring(runtimeErr))
        return 0, 0
    end

    local W = env.SharedData and env.SharedData.Weapons or {}
    local matched, total = 0, 0
    for hash, def in pairs(W) do
        total = total + 1
        local k = lower_or_nil(hash)
        if k and type(def)=="table" then
        out[k] = out[k] or {} -- don't overwrite DB items
        out[k].label = def.Name or out[k].label or hash
        out[k].desc  = def.Desc or out[k].desc or ""
        out[k].limit = out[k].limit -- keep whatever was there (usually nil for weapons)
        matched = matched + 1
        end
    end

    return matched, total
end

-- ---------- One-time init (register callback, prime LUT) ----------
local function init_labels_lut_once()
    if _lut_inited then return end
    _lut_inited = true
    LabelLUT = {}
    refresh_items_into_lut(LabelLUT)
    refresh_weapons_into_lut(LabelLUT)
end

-- Single initialization/re-initialization path at resource start/restart
AddEventHandler("onResourceStart", function(resName)
    if resName ~= GetCurrentResourceName() then return end
    init_labels_lut_once()
    if Config.CraftingDiagnostics then
        SetTimeout(1000, scan_crafting_refs)
    end
end)

-- Callback for the client/services/vui.lua
Core.Callback.Register("vorp_crafting:GetLabelLUT", function(source, cb)
    if not _lut_inited then init_labels_lut_once() end
    cb(LabelLUT or {})
end)
