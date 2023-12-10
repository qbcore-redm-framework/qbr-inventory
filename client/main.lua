local PlayerData = exports['qbr-core']:GetPlayerData()
local sharedItems = exports['qbr-core']:GetItems()
local sid = GetPlayerServerId(PlayerId())
local currentOtherInventory
local inInventory = false
local isHotbar = false
local CurrentStash
local CurrentDrop
local isLoggedIn
local Drops = {}

--------------------------------------------------------------------------
---- FUNCTIONS
--------------------------------------------------------------------------

local function HasItem(items, amount)
    local isTable = type(items) == 'table'
    local isArray = isTable and table.type(items) == 'array' or false
    local totalItems = #items
    local count = 0
    local kvIndex = 2
	if isTable and not isArray then
        totalItems = 0
        for _ in pairs(items) do totalItems += 1 end
        kvIndex = 1
    end
    for _, itemData in pairs(PlayerData.items) do
        if isTable then
            for k, v in pairs(items) do
                local itemKV = {k, v}
                if itemData and itemData.name == itemKV[kvIndex] and ((amount and itemData.amount >= amount) or (not isArray and itemData.amount >= v) or (not amount and isArray)) then
                    count += 1
                end
            end
            if count == totalItems then
                return true
            end
        else -- Single item as string
            if itemData and itemData.name == items and (not amount or (itemData and amount and itemData.amount >= amount)) then
                return true
            end
        end
    end
    return false
end

exports("HasItem", HasItem)

local function GetItemAmount(item, maxslot)
    local maxslot = maxslot or #PlayerData.items
    for i=1, maxslot do
        local slot = PlayerData.items[i]
        if slot and slot.name == item then
            return slot.amount, i
        end
    end
    return nil
end

exports("GetItemAmount", GetItemAmount)

local function GetSlotData(from, to)
    return table.move(PlayerData.items, from, to, from, {})
end

exports("GetSlotData", GetSlotData)

local function DrawText3Ds(coords, text)
    local onScreen,_x,_y=GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z)
    SetTextScale(0.35, 0.35)
    SetTextFontForCurrentCommand(1)
    SetTextColor(255, 255, 255, 215)
    local str = CreateVarString(10, "LITERAL_STRING", text, Citizen.ResultAsLong())
    SetTextCentre(1)
    DisplayText(str,_x,_y)
end

local function closeInventory()
    SendNUIMessage({action = "close"})
end

local function ToggleHotbar(toggle)
    local HotbarItems = {
        [1] = PlayerData.items[1],
        [2] = PlayerData.items[2],
        [3] = PlayerData.items[3],
        [4] = PlayerData.items[4],
        [5] = PlayerData.items[5],
        [41] = PlayerData.items[41],
    }

    if toggle then
        SendNUIMessage({action = "toggleHotbar", open = true, items = HotbarItems})
    else
        SendNUIMessage({action = "toggleHotbar", open = false})
    end
end

local function LoadAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(0)
    end
end

--------------------------------------------------------------------------
---- EVENTS & HANDLERS
--------------------------------------------------------------------------

AddStateBagChangeHandler('isLoggedIn', ('player:%s'):format(sid), function(_, _, value)
    LocalPlayer.state:set("inv_busy", not value, true)
    PlayerData = value and exports['qbr-core']:GetPlayerData() or {}
    isLoggedIn = value
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    PlayerData = val
end)

RegisterNetEvent('qbr-inventory:client:UpdateItems', function(slot, data)
    if not slot or not tonumber(slot) then return end
    PlayerData.items[slot] = data
end)

RegisterNetEvent('inventory:client:CheckOpenState', function(type, id, label)
    local name = exports['qbr-core']:SplitStr(label, "-")[2]
    if type == "stash" then
        if name ~= CurrentStash or CurrentStash == nil then
            TriggerServerEvent('inventory:server:SetIsOpenState', false, type, id)
        end
    elseif type == "drop" then
        if name ~= CurrentDrop or CurrentDrop == nil then
            TriggerServerEvent('inventory:server:SetIsOpenState', false, type, id)
        end
    end
end)

RegisterNetEvent('inventory:client:ItemBox', function(itemData, type, amount)
    SendNUIMessage({
        action = "itemBox",
        item = itemData,
        type = type,
        amount = amount or 1,
    })
end)

AddEventHandler('inventory:client:requiredItems', function(items)
    local bool = items or false
    local itemTable = {}
    if bool then
        for i=1, #items do
            local item = sharedItems[items[i]]
            itemTable[#itemTable+1] = {item = item.name, label = item.label, image = item.image}
        end
    end
    SendNUIMessage({action = "requiredItem", items = itemTable, toggle = bool})
end)

RegisterNetEvent('inventory:server:RobPlayer', function(TargetId)
    SendNUIMessage({action = "RobMoney", TargetId = TargetId})
end)

RegisterNetEvent('inventory:client:OpenInventory', function(PlayerAmmo, inventory, other)
    if not IsEntityDead(PlayerPedId()) then
        ToggleHotbar(false)
        SetNuiFocus(true, true)
        if other then
            currentOtherInventory = other.name
        end
        SendNUIMessage({
            action = "open",
            inventory = inventory,
            slots = MaxInventorySlots,
            other = other,
            maxweight = exports['qbr-core']:GetConfig().Player.MaxWeight,
            Ammo = PlayerAmmo,
            maxammo = Config.MaximumAmmoValues,
        })
        inInventory = true
    end
end)

RegisterNetEvent('inventory:client:UpdatePlayerInventory', function(isError)
    SendNUIMessage({
        action = "update",
        inventory = PlayerData.items,
        maxweight = exports['qbr-core']:GetConfig().Player.MaxWeight,
        slots = MaxInventorySlots,
        error = isError,
    })
end)

RegisterNetEvent("inventory:client:AddDropItem", function(dropId, player, coords)
    local forward = GetEntityForwardVector(GetPlayerPed(GetPlayerFromServerId(player)))
    local ped     = PlayerPedId()
    local forward = GetEntityForwardVector(ped)
    local model = `p_cs_lootsack02x`
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end
    local _coords = coords + forward * 1.6
    local obj = CreateObject(model, _coords.x, _coords.y, _coords.z-0.90)
    PlaceObjectOnGroundProperly(obj)
    SetEntityAsMissionEntity(obj, true, true)
    FreezeEntityPosition(obj , true)
    PlaySoundFrontend("show_info", "Study_Sounds", true, 0)
    SetModelAsNoLongerNeeded(model)
    Drops[dropId] = {id = dropId, coords = GetEntityCoords(obj), object = obj}
    closeInventory()
end)

RegisterNetEvent('inventory:client:RemoveDropItem', function(dropId)
    local obj = Drops[dropId].object
    Drops[dropId] = nil
    DeleteObject(obj)
    SetEntityAsNoLongerNeeded(obj)
end)

RegisterNetEvent('inventory:client:DropItemAnim', function()
    SendNUIMessage({action = ""})
    local dict = "amb_camp@world_camp_jack_throw_rocks_casual@male_a@idle_a"
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(10) end
    TaskPlayAnim(PlayerPedId(), dict, "idle_a", 1.0, 8.0, -1, 1, 0, false, false, false)
    Wait(1200)
    PlaySoundFrontend("CHECKPOINT_PERFECT", "HUD_MINI_GAME_SOUNDSET", true, 1)
    Wait(1000)
    ClearPedTasks(PlayerPedId())
end)

RegisterNetEvent('inventory:client:SetCurrentStash', function(stash)
    CurrentStash = stash
end)

RegisterNetEvent('qbr-inventory:client:giveAnim', function()
    LoadAnimDict('mp_common')
	TaskPlayAnim(PlayerPedId(), 'mp_common', 'givetake1_b', 8.0, 1.0, -1, 16, 0, 0, 0, 0)
end)

--------------------------------------------------------------------------
---- Commands
--------------------------------------------------------------------------

RegisterCommand('closeinv', closeInventory)

--------------------------------------------------------------------------
---- NUI CALLBACKS
--------------------------------------------------------------------------

RegisterNUICallback('RobMoney', function(data)
    TriggerServerEvent("police:server:RobPlayer", data.TargetId)
end)

RegisterNUICallback('Notify', function(data)
    exports['qbr-core']:Notify(9, data.message, data.type)
end)

RegisterNUICallback('getCombineItem', function(data, cb)
    cb(sharedItems[data.item])
end)

RegisterNUICallback("CloseInventory", function()
    if currentOtherInventory == "none-inv" then
        CurrentDrop = nil
        CurrentStash = nil
        SetNuiFocus(false, false)
        inInventory = false
        ClearPedTasks(PlayerPedId())
        return
    end
    if CurrentStash ~= nil then
        TriggerServerEvent("inventory:server:SaveInventory", "stash", CurrentStash)
        CurrentStash = nil
    else
        TriggerServerEvent("inventory:server:SaveInventory", "drop", CurrentDrop)
        CurrentDrop = nil
    end
    SetNuiFocus(false, false)
    inInventory = false
end)

RegisterNUICallback("UseItem", function(data)
    TriggerServerEvent("inventory:server:UseItem", data.inventory, data.item)
end)

RegisterNUICallback("combineItem", function(data)
    Wait(150)
    TriggerServerEvent('inventory:server:combineItem', data.reward, data.fromItem, data.toItem)
end)

RegisterNUICallback('combineWithAnim', function(data)
    local ped = PlayerPedId()
    local combineData = data.combineData
    local aDict = combineData.anim.dict
    local aLib = combineData.anim.lib
    local animText = combineData.anim.text
    local animTimeout = combineData.anim.timeOut

    exports['qbr-core']:Progressbar("combine_anim", animText, animTimeout, false, true, {
        disableMovement = false,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = aDict,
        anim = aLib,
        flags = 16,
    }, {}, {}, function() -- Done
        StopAnimTask(ped, aDict, aLib, 1.0)
        TriggerServerEvent('inventory:server:combineItem', combineData.reward, data.requiredItem, data.usedItem)
    end, function() -- Cancel
        StopAnimTask(ped, aDict, aLib, 1.0)
        exports['qbr-core']:Notify(9, Lang:t("error.failed"), 5000, 0, 'mp_lobby_textures', 'cross', 'COLOR_WHITE')
    end)
end)

RegisterNUICallback("SetInventoryData", function(data)
    TriggerServerEvent("inventory:server:SetInventoryData", data.fromInventory, data.toInventory, data.fromSlot, data.toSlot, data.fromAmount, data.toAmount)
end)

RegisterNUICallback("PlayDropFail", function()
    PlaySound(-1, "Place_Prop_Fail", "DLC_Dmod_Prop_Editor_Sounds", 0, 0, 1)
end)

RegisterNUICallback("GiveItem", function(data)
    local ped = PlayerPedId()
    local player, distance = exports['qbr-core']:GetClosestPlayer(GetEntityCoords(ped))
    if player ~= -1 and distance < 3 then
        if (data.inventory == 'player') then
            local playerId = GetPlayerServerId(player)
            SetCurrentPedWeapon(ped,'WEAPON_UNARMED',true)
            TriggerServerEvent("inventory:server:GiveItem", playerId, data.inventory, data.item, data.amount)
        else
            exports['qbr-core']:Notify(9, Lang:t("error.not_owned"), 5000, 0, 'mp_lobby_textures', 'cross', 'COLOR_WHITE')
        end
    else
        exports['qbr-core']:Notify(9, Lang:t("error.no_near"), 5000, 0, 'mp_lobby_textures', 'cross', 'COLOR_WHITE')
    end
end)

--------------------------------------------------------------------------
---- THREADS
--------------------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(0)
        if IsDisabledControlJustReleased(0, 0xB238FE0B) and IsInputDisabled(0) then -- key open inventory Tab Key
				if not PlayerData.metadata["isdead"] and not PlayerData.metadata["inlaststand"] and not PlayerData.metadata["ishandcuffed"] and not IsPauseMenuActive() then
					local ped = PlayerPedId()
                    if CurrentDrop ~= 0 then
						TriggerServerEvent("inventory:server:OpenInventory", "drop", CurrentDrop)
					else
						TriggerServerEvent("inventory:server:OpenInventory")
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(0)
        DisableControlAction(0, 0xE6F612E4)
        DisableControlAction(0, 0x1CE6D9EB)
        DisableControlAction(0, 0x1CE6D9EB)
        DisableControlAction(0, 0x8F9F9E58)
        DisableControlAction(0, 0xAB62E997)
        DisableControlAction(0, 0x26E9DC00)
        DisableControlAction(0, 0xAC4BD4F1) -- Disable Weapon Wheel and Item Wheel
        DisableControlAction(0, 0xB238FE0B) -- Disable Quick Select for Weapons
        if IsDisabledControlPressed(0, 0xE6F612E4) and IsInputDisabled(0) then  -- 1  slot
			if not PlayerData.metadata["isdead"] and not PlayerData.metadata["inlaststand"] and not PlayerData.metadata["ishandcuffed"] then
				TriggerServerEvent("inventory:server:UseItemSlot", 1)
			end
        end

        if IsDisabledControlPressed(0, 0x1CE6D9EB) and IsInputDisabled(0) then  -- 2 slot
			if not PlayerData.metadata["isdead"] and not PlayerData.metadata["inlaststand"] and not PlayerData.metadata["ishandcuffed"] then
				TriggerServerEvent("inventory:server:UseItemSlot", 2)
			end
        end

        if IsDisabledControlPressed(0, 0x4F49CC4C) and IsInputDisabled(0) then -- 3 slot
			if not PlayerData.metadata["isdead"] and not PlayerData.metadata["inlaststand"] and not PlayerData.metadata["ishandcuffed"] then
				TriggerServerEvent("inventory:server:UseItemSlot", 3)
			end
        end

        if IsDisabledControlPressed(0, 0x8F9F9E58) and IsInputDisabled(0) then  -- 4 slot
			if not PlayerData.metadata["isdead"] and not PlayerData.metadata["inlaststand"] and not PlayerData.metadata["ishandcuffed"] then
				TriggerServerEvent("inventory:server:UseItemSlot", 4)
			end
        end

        if IsDisabledControlPressed(0, 0xAB62E997) and IsInputDisabled(0) then -- 5 slot
			if not PlayerData.metadata["isdead"] and not PlayerData.metadata["inlaststand"] and not PlayerData.metadata["ishandcuffed"] then
				TriggerServerEvent("inventory:server:UseItemSlot", 5)
			end
        end

        if IsDisabledControlJustPressed(0, 0x26E9DC00) and IsInputDisabled(0) then -- z  Hotbar
            isHotbar = not isHotbar
            ToggleHotbar(isHotbar)
        end
    end
end)

CreateThread(function()
    while true do
        if Drops and next(Drops) then
            local pos = GetEntityCoords(PlayerPedId(), true)
            for k, v in pairs(Drops) do
                if Drops[k] then
                    local dist = #(pos - v.coords)
                    if dist < 7.5 then
                        if dist < 2 then
                            CurrentDrop = k
                        else
                            CurrentDrop = nil
                        end
                    end
                end
            end
        end
        Wait(500)
    end
end)