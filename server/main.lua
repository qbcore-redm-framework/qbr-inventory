local Drops, Stashes, ShopItems, Active = {}, {}, {}, {}
local sharedItems = exports['qbr-core']:GetItems()
-- Functions

local function recipeContains(recipe, fromItem)
	for _, v in pairs(recipe.accept) do
		if v == fromItem.name then
			return true
		end
	end
	return false
end

local function hasCraftItems(source, CostItems, amount)
	local Player = exports['qbr-core']:GetPlayer(source)
	for k, v in pairs(CostItems) do
		if Player.Functions.GetItemByName(k) ~= nil then
			if Player.Functions.GetItemByName(k).amount < (v * amount) then
				return false
			end
		else
			return false
		end
	end
	return true
end

local function IsOwnedHorse(id)
    local result = exports.oxmysql:scalarSync('SELECT id from horses WHERE id = ?', {id})
    if result then return true else return false end
end

-- Shop Items
local function SetupShopItems(shop, shopItems)
	local items = {}
	if shopItems and next(shopItems) then
		for k, item in pairs(shopItems) do
			local itemInfo = sharedItems[item.name:lower()]
			if itemInfo then
				items[k] = {
					name = itemInfo["name"],
					amount = tonumber(item.amount),
					info = item.info or "",
					label = itemInfo["label"],
					description = itemInfo["description"] or "",
					weight = itemInfo["weight"],
					type = itemInfo["type"],
					unique = itemInfo["unique"],
					useable = itemInfo["useable"],
					price = item.price,
					image = itemInfo["image"],
					slot = k,
				}
			end
		end
	end
	return items
end

-- Stash Items
local function GetStashItems(stashId)
	local items = {}
	local result = exports.oxmysql:scalarSync('SELECT items FROM stashitems WHERE stash = ?', {stashId})
	if result then
		local stashItems = json.decode(result)
		if stashItems then
			for k, item in pairs(stashItems) do
				local itemInfo = sharedItems[item.name:lower()]
				if itemInfo then
					items[item.slot] = {
						name = itemInfo["name"],
						amount = tonumber(item.amount),
						info = item.info or "",
						label = itemInfo["label"],
						description = itemInfo["description"] or "",
						weight = itemInfo["weight"],
						type = itemInfo["type"],
						unique = itemInfo["unique"],
						useable = itemInfo["useable"],
						image = itemInfo["image"],
						slot = item.slot,
					}
				end
			end
		end
	end
	return items
end

local function SaveStashItems(stashId, items)
	if Stashes[stashId].label ~= Lang:t("info.stash_none") then
		if items then
			for slot, item in pairs(items) do
				item.description = nil
			end
			exports.oxmysql:insert('INSERT INTO stashitems (stash, items) VALUES (:stash, :items) ON DUPLICATE KEY UPDATE items = :items', {
				['stash'] = stashId,
				['items'] = json.encode(items)
			})
			Active[Stashes[stashId].isOpen] = nil
			Stashes[stashId].isOpen = false
		end
	end
end

local function AddToStash(stashId, slot, otherslot, itemName, amount, info)
	local amount = tonumber(amount)
	local ItemData = sharedItems[itemName]
	if not ItemData.unique then
		if Stashes[stashId].items[slot] and Stashes[stashId].items[slot].name == itemName then
			Stashes[stashId].items[slot].amount = Stashes[stashId].items[slot].amount + amount
		else
			local itemInfo = sharedItems[itemName:lower()]
			Stashes[stashId].items[slot] = {
				name = itemInfo["name"],
				amount = amount,
				info = info or "",
				label = itemInfo["label"],
				description = itemInfo["description"] or "",
				weight = itemInfo["weight"],
				type = itemInfo["type"],
				unique = itemInfo["unique"],
				useable = itemInfo["useable"],
				image = itemInfo["image"],
				slot = slot,
			}
		end
	else
		if Stashes[stashId].items[slot] and Stashes[stashId].items[slot].name == itemName then
			local itemInfo = sharedItems[itemName:lower()]
			Stashes[stashId].items[otherslot] = {
				name = itemInfo["name"],
				amount = amount,
				info = info or "",
				label = itemInfo["label"],
				description = itemInfo["description"] or "",
				weight = itemInfo["weight"],
				type = itemInfo["type"],
				unique = itemInfo["unique"],
				useable = itemInfo["useable"],
				image = itemInfo["image"],
				slot = otherslot,
			}
		else
			local itemInfo = sharedItems[itemName:lower()]
			Stashes[stashId].items[slot] = {
				name = itemInfo["name"],
				amount = amount,
				info = info or "",
				label = itemInfo["label"],
				description = itemInfo["description"] or "",
				weight = itemInfo["weight"],
				type = itemInfo["type"],
				unique = itemInfo["unique"],
				useable = itemInfo["useable"],
				image = itemInfo["image"],
				slot = slot,
			}
		end
	end
end

local function RemoveFromStash(stashId, slot, itemName, amount)
	local amount = tonumber(amount)
	if Stashes[stashId].items[slot] ~= nil and Stashes[stashId].items[slot].name == itemName then
		if Stashes[stashId].items[slot].amount > amount then
			Stashes[stashId].items[slot].amount = Stashes[stashId].items[slot].amount - amount
		else
			Stashes[stashId].items[slot] = nil
			if next(Stashes[stashId].items) == nil then
				Stashes[stashId].items = {}
			end
		end
	else
		Stashes[stashId].items[slot] = nil
		if Stashes[stashId].items == nil then
			Stashes[stashId].items[slot] = nil
		end
	end
end

-- Drop items
local function AddToDrop(dropId, slot, itemName, amount, info)
	local amount = tonumber(amount)
	if Drops[dropId].items[slot] ~= nil and Drops[dropId].items[slot].name == itemName then
		Drops[dropId].items[slot].amount = Drops[dropId].items[slot].amount + amount
	else
		local itemInfo = sharedItems[itemName:lower()]
		Drops[dropId].items[slot] = {
			name = itemInfo["name"],
			amount = amount,
			info = info or "",
			label = itemInfo["label"],
			description = itemInfo["description"] or "",
			weight = itemInfo["weight"],
			type = itemInfo["type"],
			unique = itemInfo["unique"],
			useable = itemInfo["useable"],
			image = itemInfo["image"],
			slot = slot,
			id = dropId,
		}
	end
end

local function RemoveFromDrop(dropId, slot, itemName, amount)
	if Drops[dropId].items[slot] ~= nil and Drops[dropId].items[slot].name == itemName then
		if Drops[dropId].items[slot].amount > amount then
			Drops[dropId].items[slot].amount = Drops[dropId].items[slot].amount - amount
		else
			Drops[dropId].items[slot] = nil
			if next(Drops[dropId].items) == nil then
				Drops[dropId].items = {}
			end
		end
	else
		Drops[dropId].items[slot] = nil
		if Drops[dropId].items == nil then
			Drops[dropId].items[slot] = nil
		end
	end
end

local function CreateDropId()
	if Drops ~= nil then
		local id = math.random(10000, 99999)
		local dropid = id
		while Drops[dropid] ~= nil do
			id = math.random(10000, 99999)
			dropid = id
		end
		return dropid
	else
		local id = math.random(10000, 99999)
		local dropid = id
		return dropid
	end
end

local function CreateNewDrop(source, fromSlot, toSlot, itemAmount)
	local Player = exports['qbr-core']:GetPlayer(source)
	local itemData = Player.Functions.GetItemBySlot(fromSlot)
	local coords = GetEntityCoords(GetPlayerPed(source))
	if Player.Functions.RemoveItem(itemData.name, itemAmount, itemData.slot) then
		if string.find(itemData.name, 'weapon') then
			TriggerClientEvent("qbr-weapons:client:CheckWeapon", source, itemData.name)
		end
		local itemInfo = sharedItems[itemData.name:lower()]
		local dropId = CreateDropId()
		Drops[dropId] = {}
		Drops[dropId].items = {}

		Drops[dropId].items[toSlot] = {
			name = itemInfo["name"],
			amount = itemAmount,
			info = itemData.info or "",
			label = itemInfo["label"],
			description = itemInfo["description"] or "",
			weight = itemInfo["weight"],
			type = itemInfo["type"],
			unique = itemInfo["unique"],
			useable = itemInfo["useable"],
			image = itemInfo["image"],
			slot = toSlot,
			id = dropId,
		}
		TriggerEvent("qbr-log:server:CreateLog", "drop", "New Item Drop", "red", "**".. GetPlayerName(source) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..source.."*) dropped new item; name: **"..itemData.name.."**, amount: **" .. itemAmount .. "**")
		TriggerClientEvent("inventory:client:DropItemAnim", source)
		TriggerClientEvent("inventory:client:AddDropItem", -1, dropId, source, coords)
	else
		TriggerClientEvent("QBCore:Notify", source, Lang:t("error.not_owned"), 5000, 0, 'mp_lobby_textures', 'cross', 'COLOR_WHITE')
		return
	end
end

AddEventHandler('playerDropped', function()
    local src = source
    local id = Active[src]
    if not id or not Stashes[id] then return end
    SaveStashItems(id, Stashes[id].items)
    Active[src] = nil
end)

-- Events

RegisterNetEvent('inventory:server:combineItem', function(item, fromItem, toItem)
	local src = source
	local ply = exports['qbr-core']:GetPlayer(src)

	-- Check that inputs are not nil
	-- Most commonly when abusing this exploit, this values are left as
	if fromItem == nil  then return end
	if toItem == nil then return end

	-- Check that they have the items
	local fromItem = ply.Functions.GetItemByName(fromItem)
	local toItem = ply.Functions.GetItemByName(toItem)

	if fromItem == nil  then return end
	if toItem == nil then return end

	-- Check the recipe is valid
	local recipe = sharedItems[toItem.name].combinable

	if recipe and recipe.reward ~= item then return end
	if not recipeContains(recipe, fromItem) then return end

	TriggerClientEvent('inventory:client:ItemBox', src, sharedItems[item], 'add')
	ply.Functions.AddItem(item, 1)
	ply.Functions.RemoveItem(fromItem.name, 1)
	ply.Functions.RemoveItem(toItem.name, 1)
end)

RegisterNetEvent('inventory:server:CraftItems', function(itemName, itemCosts, amount, toSlot, points)
	local src = source
	local Player = exports['qbr-core']:GetPlayer(src)
	local amount = tonumber(amount)
	if not itemName or not itemCosts then return end
	for k, v in pairs(itemCosts) do
		if not Player.Functions.RemoveItem(k, (v*amount)) then return end
	end
	Player.Functions.AddItem(itemName, amount, toSlot)
	Player.Functions.SetMetaData("craftingrep", Player.PlayerData.metadata["craftingrep"]+(points*amount))
	TriggerClientEvent("inventory:client:UpdatePlayerInventory", src, false)
end)

RegisterNetEvent('inventory:server:CraftAttachment', function(itemName, itemCosts, amount, toSlot, points)
	local src = source
	local Player = exports['qbr-core']:GetPlayer(src)
	local amount = tonumber(amount)
	if not itemName or not itemCosts then return end
	for k, v in pairs(itemCosts) do
		if not Player.Functions.RemoveItem(k, (v*amount)) then return end
	end
	Player.Functions.AddItem(itemName, amount, toSlot)
	TriggerClientEvent("inventory:client:UpdatePlayerInventory", src, false)
end)

RegisterNetEvent('inventory:server:SetIsOpenState', function(IsOpen, type, id)
	if not IsOpen then
		if type == "stash" then
			Stashes[id].isOpen = false
		elseif type == "drop" then
			Drops[id].isOpen = false
		end
	end
end)

RegisterNetEvent('inventory:server:OpenInventory', function(name, id, other)
	local src = source
	local ply = Player(src)
	local Player = exports['qbr-core']:GetPlayer(src)
	if not ply.state.inv_busy then
		if name and id then
			local secondInv = {}
			if name == "stash" then
				if Stashes[id] then
					if Stashes[id].isOpen then
						local Target = exports['qbr-core']:GetPlayer(Stashes[id].isOpen)
						if Target then
							TriggerClientEvent('inventory:client:CheckOpenState', Stashes[id].isOpen, name, id, Stashes[id].label)
						else
							Stashes[id].isOpen = false
						end
					end
				end
				local maxweight = 1000000
				local slots = 50
				if other then
					maxweight = other.maxweight or 1000000
					slots = other.slots or 50
				end
				secondInv.name = "stash-"..id
				secondInv.label = Lang:t("info.stash")..id
				secondInv.maxweight = maxweight
				secondInv.inventory = {}
				secondInv.slots = slots
				if Stashes[id] and Stashes[id].isOpen then
					secondInv.name = "none-inv"
					secondInv.label = "Stash-None"
					secondInv.maxweight = 1000000
					secondInv.inventory = {}
					secondInv.slots = 0
				else
					local stashItems = GetStashItems(id)
					if next(stashItems) then
						secondInv.inventory = stashItems
						Stashes[id] = {}
						Active[src] = id
						Stashes[id].items = stashItems
						Stashes[id].isOpen = src
						Stashes[id].label = secondInv.label
					else
						Stashes[id] = {}
						Active[src] = id
						Stashes[id].items = {}
						Stashes[id].isOpen = src
						Stashes[id].label = secondInv.label
					end
				end
			elseif name == "shop" then
				secondInv.name = "itemshop-"..id
				secondInv.label = other.label
				secondInv.maxweight = 900000
				secondInv.inventory = SetupShopItems(id, other.items)
				ShopItems[id] = {}
				ShopItems[id].items = other.items
				secondInv.slots = #other.items
			elseif name == "crafting" then
				secondInv.name = "crafting"
				secondInv.label = other.label
				secondInv.maxweight = 900000
				secondInv.inventory = other.items
				secondInv.slots = #other.items
			elseif name == "attachment_crafting" then
				secondInv.name = "attachment_crafting"
				secondInv.label = other.label
				secondInv.maxweight = 900000
				secondInv.inventory = other.items
				secondInv.slots = #other.items
			elseif name == "otherplayer" then
				local OtherPlayer = exports['qbr-core']:GetPlayer(tonumber(id))
				if OtherPlayer then
					secondInv.name = "otherplayer-"..id
					secondInv.label = "Player-"..id
					secondInv.maxweight = exports['qbr-core']:GetConfig().Player.MaxWeight
					secondInv.inventory = OtherPlayer.PlayerData.items
					if Player.PlayerData.job.name == "police" and Player.PlayerData.job.onduty then
						secondInv.slots = exports['qbr-core']:GetConfig().Player.MaxInvSlots
					else
						secondInv.slots = exports['qbr-core']:GetConfig().Player.MaxInvSlots - 1
					end
					Wait(250)
				end
			else
				if Drops[id] then
					if Drops[id].isOpen then
						local Target = exports['qbr-core']:GetPlayer(Drops[id].isOpen)
						if Target then
							TriggerClientEvent('inventory:client:CheckOpenState', Drops[id].isOpen, name, id, Drops[id].label)
						else
							Drops[id].isOpen = false
						end
					end
				end
				if Drops[id] and not Drops[id].isOpen then
					secondInv.name = id
					secondInv.label = Lang:t("info.dropped")..tostring(id)
					secondInv.maxweight = 100000
					secondInv.inventory = Drops[id].items
					secondInv.slots = 30
					Drops[id].isOpen = src
					Drops[id].label = secondInv.label
				else
					secondInv.name = "none-inv"
					secondInv.label = Lang:t("info.dropped_none")
					secondInv.maxweight = 100000
					secondInv.inventory = {}
					secondInv.slots = 0
				end
			end
			TriggerClientEvent("inventory:client:OpenInventory", src, {}, Player.PlayerData.items, secondInv)
		else
			TriggerClientEvent("inventory:client:OpenInventory", src, {}, Player.PlayerData.items)
		end
	else
		TriggerClientEvent('QBCore:Notify', src, 9, Lang:t("error.no_access"), 5000, 0, 'mp_lobby_textures', 'cross', 'COLOR_WHITE')
	end
end)

RegisterNetEvent('inventory:server:SaveInventory', function(type, id)
	if type == "stash" then
		SaveStashItems(id, Stashes[id].items)
	elseif type == "drop" then
		if Drops[id] then
			Drops[id].isOpen = false
			if Drops[id].items == nil or next(Drops[id].items) == nil then
				Drops[id] = nil
				TriggerClientEvent("inventory:client:RemoveDropItem", -1, id)
			end
		end
	end
end)

RegisterNetEvent('inventory:server:UseItemSlot', function(slot)
	local src = source
	local Player = exports['qbr-core']:GetPlayer(src)
	local itemData = Player.Functions.GetItemBySlot(slot)
	if itemData then
		local itemInfo = sharedItems[itemData.name]
		if itemData.type == "weapon" then
			TriggerClientEvent("qbr-weapons:client:UseWeapon", src, itemData)
			TriggerClientEvent('inventory:client:ItemBox', src, itemInfo, "use")
		elseif itemData.useable then
			TriggerClientEvent("QBCore:Client:UseItem", src, itemData)
			TriggerClientEvent('inventory:client:ItemBox', src, itemInfo, "use")
		end
	end
end)

RegisterNetEvent('inventory:server:UseItem', function(inventory, item)
	local src = source
	local Player = exports['qbr-core']:GetPlayer(src)
	if inventory == "player" or inventory == "hotbar" then
		local itemData = Player.Functions.GetItemBySlot(item.slot)
		if itemData then
			TriggerClientEvent("QBCore:Client:UseItem", src, itemData)
		end
	end
end)

RegisterNetEvent('inventory:server:SetInventoryData', function(fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount)
	local src = source
	local Player = exports['qbr-core']:GetPlayer(src)
	fromSlot = tonumber(fromSlot)
	toSlot = tonumber(toSlot)

	if (fromInventory == "player" or fromInventory == "hotbar") and (exports['qbr-core']:SplitStr(toInventory, "-")[1] == "itemshop" or toInventory == "crafting") then
		return
	end

	if fromInventory == "player" or fromInventory == "hotbar" then
		local fromItemData = Player.Functions.GetItemBySlot(fromSlot)
		local fromAmount = tonumber(fromAmount) ~= nil and tonumber(fromAmount) or fromItemData.amount
		if fromItemData ~= nil and fromItemData.amount >= fromAmount then
			if toInventory == "player" or toInventory == "hotbar" then
				local toItemData = Player.Functions.GetItemBySlot(toSlot)
				Player.Functions.RemoveItem(fromItemData.name, fromAmount, fromSlot)
				if string.find(fromItemData.name, 'weapon') then
					TriggerClientEvent("qbr-weapons:client:CheckWeapon", src, fromItemData.name)
				end
				if toItemData ~= nil then
					local toAmount = tonumber(toAmount) ~= nil and tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						Player.Functions.RemoveItem(toItemData.name, toAmount, toSlot)
						Player.Functions.AddItem(toItemData.name, toAmount, fromSlot, toItemData.info)
					end
				else
					--Player.PlayerData.items[fromSlot] = nil
				end
				Player.Functions.AddItem(fromItemData.name, fromAmount, toSlot, fromItemData.info)
			elseif exports['qbr-core']:SplitStr(toInventory, "-")[1] == "otherplayer" then
				local playerId = tonumber(exports['qbr-core']:SplitStr(toInventory, "-")[2])
				local OtherPlayer = exports['qbr-core']:GetPlayer(playerId)
				local toItemData = OtherPlayer.PlayerData.items[toSlot]
				Player.Functions.RemoveItem(fromItemData.name, fromAmount, fromSlot)
				if string.find(fromItemData.name, 'weapon') then
					TriggerClientEvent("qbr-weapons:client:CheckWeapon", src, fromItemData.name)
				end
				if toItemData ~= nil then
					local itemInfo = sharedItems[toItemData.name:lower()]
					local toAmount = tonumber(toAmount) ~= nil and tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						OtherPlayer.Functions.RemoveItem(itemInfo["name"], toAmount, fromSlot)
						Player.Functions.AddItem(toItemData.name, toAmount, fromSlot, toItemData.info)
						TriggerEvent("qbr-log:server:CreateLog", "robbing", "Swapped Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | *"..src.."*) swapped item; name: **"..itemInfo["name"].."**, amount: **" .. toAmount .. "** with name: **" .. fromItemData.name .. "**, amount: **" .. fromAmount.. "** with player: **".. GetPlayerName(OtherPlayer.PlayerData.source) .. "** (citizenid: *"..OtherPlayer.PlayerData.citizenid.."* | id: *"..OtherPlayer.PlayerData.source.."*)")
					end
				else
					local itemInfo = sharedItems[fromItemData.name:lower()]
					TriggerEvent("qbr-log:server:CreateLog", "robbing", "Dropped Item", "red", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | *"..src.."*) dropped new item; name: **"..itemInfo["name"].."**, amount: **" .. fromAmount .. "** to player: **".. GetPlayerName(OtherPlayer.PlayerData.source) .. "** (citizenid: *"..OtherPlayer.PlayerData.citizenid.."* | id: *"..OtherPlayer.PlayerData.source.."*)")
				end
				local itemInfo = sharedItems[fromItemData.name:lower()]
				OtherPlayer.Functions.AddItem(itemInfo["name"], fromAmount, toSlot, fromItemData.info)
			elseif exports['qbr-core']:SplitStr(toInventory, "-")[1] == "stash" then
				local stashId = exports['qbr-core']:SplitStr(toInventory, "-")[2]
				local toItemData = Stashes[stashId].items[toSlot]
				Player.Functions.RemoveItem(fromItemData.name, fromAmount, fromSlot)
				if string.find(fromItemData.name, 'weapon') then
					TriggerClientEvent("qbr-weapons:client:CheckWeapon", src, fromItemData.name)
				end
				if toItemData ~= nil then
					local itemInfo = sharedItems[toItemData.name:lower()]
					local toAmount = tonumber(toAmount) ~= nil and tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						RemoveFromStash(stashId, toSlot, itemInfo["name"], toAmount)
						Player.Functions.AddItem(toItemData.name, toAmount, fromSlot, toItemData.info)
						TriggerEvent("qbr-log:server:CreateLog", "stash", "Swapped Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) swapped item; name: **"..itemInfo["name"].."**, amount: **" .. toAmount .. "** with name: **" .. fromItemData.name .. "**, amount: **" .. fromAmount .. "** - stash: *" .. stashId .. "*")
					end
				else
					local itemInfo = sharedItems[fromItemData.name:lower()]
					TriggerEvent("qbr-log:server:CreateLog", "stash", "Dropped Item", "red", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) dropped new item; name: **"..itemInfo["name"].."**, amount: **" .. fromAmount .. "** - stash: *" .. stashId .. "*")
				end
				local itemInfo = sharedItems[fromItemData.name:lower()]
				AddToStash(stashId, toSlot, fromSlot, itemInfo["name"], fromAmount, fromItemData.info)
			else
				-- drop
				toInventory = tonumber(toInventory)
				if toInventory == nil or toInventory == 0 then
					CreateNewDrop(src, fromSlot, toSlot, fromAmount)
				else
					local toItemData = Drops[toInventory].items[toSlot]
					Player.Functions.RemoveItem(fromItemData.name, fromAmount, fromSlot)
					if string.find(fromItemData.name, 'weapon') then
						TriggerClientEvent("qbr-weapons:client:CheckWeapon", src, fromItemData.name)
					end
					if toItemData ~= nil then
						local itemInfo = sharedItems[toItemData.name:lower()]
						local toAmount = tonumber(toAmount) ~= nil and tonumber(toAmount) or toItemData.amount
						if toItemData.name ~= fromItemData.name then
							Player.Functions.AddItem(toItemData.name, toAmount, fromSlot, toItemData.info)
							RemoveFromDrop(toInventory, fromSlot, itemInfo["name"], toAmount)
							TriggerEvent("qbr-log:server:CreateLog", "drop", "Swapped Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) swapped item; name: **"..itemInfo["name"].."**, amount: **" .. toAmount .. "** with name: **" .. fromItemData.name .. "**, amount: **" .. fromAmount .. "** - dropid: *" .. toInventory .. "*")
						end
					else
						local itemInfo = sharedItems[fromItemData.name:lower()]
						TriggerEvent("qbr-log:server:CreateLog", "drop", "Dropped Item", "red", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) dropped new item; name: **"..itemInfo["name"].."**, amount: **" .. fromAmount .. "** - dropid: *" .. toInventory .. "*")
					end
					local itemInfo = sharedItems[fromItemData.name:lower()]
					AddToDrop(toInventory, toSlot, itemInfo["name"], fromAmount, fromItemData.info)
				end
			end
		else
			TriggerClientEvent("QBCore:Notify", src, Lang:t("error.not_owned"), 5000, 0, 'mp_lobby_textures', 'cross', 'COLOR_WHITE')
		end
	elseif exports['qbr-core']:SplitStr(fromInventory, "-")[1] == "otherplayer" then
		local playerId = tonumber(exports['qbr-core']:SplitStr(fromInventory, "-")[2])
		local OtherPlayer = exports['qbr-core']:GetPlayer(playerId)
		local fromItemData = OtherPlayer.PlayerData.items[fromSlot]
		local fromAmount = tonumber(fromAmount) ~= nil and tonumber(fromAmount) or fromItemData.amount
		if fromItemData ~= nil and fromItemData.amount >= fromAmount then
			local itemInfo = sharedItems[fromItemData.name:lower()]
			if toInventory == "player" or toInventory == "hotbar" then
				local toItemData = Player.Functions.GetItemBySlot(toSlot)
				OtherPlayer.Functions.RemoveItem(itemInfo["name"], fromAmount, fromSlot)
				if string.find(fromItemData.name, 'weapon') then
					TriggerClientEvent("qbr-weapons:client:CheckWeapon", OtherPlayer.PlayerData.source, fromItemData.name)
				end
				if toItemData ~= nil then
					local itemInfo = sharedItems[toItemData.name:lower()]
					local toAmount = tonumber(toAmount) ~= nil and tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						Player.Functions.RemoveItem(toItemData.name, toAmount, toSlot)
						OtherPlayer.Functions.AddItem(itemInfo["name"], toAmount, fromSlot, toItemData.info)
						TriggerEvent("qbr-log:server:CreateLog", "robbing", "Swapped Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) swapped item; name: **"..toItemData.name.."**, amount: **" .. toAmount .. "** with item; **"..itemInfo["name"].."**, amount: **" .. toAmount .. "** from player: **".. GetPlayerName(OtherPlayer.PlayerData.source) .. "** (citizenid: *"..OtherPlayer.PlayerData.citizenid.."* | *"..OtherPlayer.PlayerData.source.."*)")
					end
				else
					TriggerEvent("qbr-log:server:CreateLog", "robbing", "Retrieved Item", "green", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) took item; name: **"..fromItemData.name.."**, amount: **" .. fromAmount .. "** from player: **".. GetPlayerName(OtherPlayer.PlayerData.source) .. "** (citizenid: *"..OtherPlayer.PlayerData.citizenid.."* | *"..OtherPlayer.PlayerData.source.."*)")
				end
				Player.Functions.AddItem(fromItemData.name, fromAmount, toSlot, fromItemData.info)
			else
				local toItemData = OtherPlayer.PlayerData.items[toSlot]
				OtherPlayer.Functions.RemoveItem(itemInfo["name"], fromAmount, fromSlot)
				if toItemData ~= nil then
					local itemInfo = sharedItems[toItemData.name:lower()]
					local toAmount = tonumber(toAmount) ~= nil and tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						local itemInfo = sharedItems[toItemData.name:lower()]
						OtherPlayer.Functions.RemoveItem(itemInfo["name"], toAmount, toSlot)
						OtherPlayer.Functions.AddItem(itemInfo["name"], toAmount, fromSlot, toItemData.info)
					end
				else
					--Player.PlayerData.items[fromSlot] = nil
				end
				local itemInfo = sharedItems[fromItemData.name:lower()]
				OtherPlayer.Functions.AddItem(itemInfo["name"], fromAmount, toSlot, fromItemData.info)
			end
		else
			TriggerClientEvent("QBCore:Notify", src, Lang:t("error.not_exist"), 5000, 0, 'mp_lobby_textures', 'cross', 'COLOR_WHITE')
		end
	elseif exports['qbr-core']:SplitStr(fromInventory, "-")[1] == "stash" then
		local stashId = exports['qbr-core']:SplitStr(fromInventory, "-")[2]
		local fromItemData = Stashes[stashId].items[fromSlot]
		local fromAmount = tonumber(fromAmount) ~= nil and tonumber(fromAmount) or fromItemData.amount
		if fromItemData ~= nil and fromItemData.amount >= fromAmount then
			local itemInfo = sharedItems[fromItemData.name:lower()]
			if toInventory == "player" or toInventory == "hotbar" then
				local toItemData = Player.Functions.GetItemBySlot(toSlot)
				RemoveFromStash(stashId, fromSlot, itemInfo["name"], fromAmount)
				if toItemData ~= nil then
					local itemInfo = sharedItems[toItemData.name:lower()]
					local toAmount = tonumber(toAmount) ~= nil and tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						Player.Functions.RemoveItem(toItemData.name, toAmount, toSlot)
						AddToStash(stashId, fromSlot, toSlot, itemInfo["name"], toAmount, toItemData.info)
						TriggerEvent("qbr-log:server:CreateLog", "stash", "Swapped Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) swapped item; name: **"..toItemData.name.."**, amount: **" .. toAmount .. "** with item; name: **"..fromItemData.name.."**, amount: **" .. fromAmount .. "** stash: *" .. stashId .. "*")
					else
						TriggerEvent("qbr-log:server:CreateLog", "stash", "Stacked Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) stacked item; name: **"..toItemData.name.."**, amount: **" .. toAmount .. "** from stash: *" .. stashId .. "*")
					end
				else
					TriggerEvent("qbr-log:server:CreateLog", "stash", "Received Item", "green", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) received item; name: **"..fromItemData.name.."**, amount: **" .. fromAmount.. "** stash: *" .. stashId .. "*")
				end
				Player.Functions.AddItem(fromItemData.name, fromAmount, toSlot, fromItemData.info)
			else
				local toItemData = Stashes[stashId].items[toSlot]
				RemoveFromStash(stashId, fromSlot, itemInfo["name"], fromAmount)
				if toItemData ~= nil then
					local itemInfo = sharedItems[toItemData.name:lower()]
					local toAmount = tonumber(toAmount) ~= nil and tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						local itemInfo = sharedItems[toItemData.name:lower()]
						RemoveFromStash(stashId, toSlot, itemInfo["name"], toAmount)
						AddToStash(stashId, fromSlot, toSlot, itemInfo["name"], toAmount, toItemData.info)
					end
				else
					--Player.PlayerData.items[fromSlot] = nil
				end
				local itemInfo = sharedItems[fromItemData.name:lower()]
				AddToStash(stashId, toSlot, fromSlot, itemInfo["name"], fromAmount, fromItemData.info)
			end
		else
			TriggerClientEvent("QBCore:Notify", src, Lang:t("error.not_exist"), 5000, 0, 'mp_lobby_textures', 'cross', 'COLOR_WHITE')
		end
	elseif exports['qbr-core']:SplitStr(fromInventory, "-")[1] == "itemshop" then
		local shopType = exports['qbr-core']:SplitStr(fromInventory, "-")[2]
		local itemData = ShopItems[shopType].items[fromSlot]
		local itemInfo = sharedItems[itemData.name:lower()]
		local bankBalance = Player.PlayerData.money["bank"]
		local price = tonumber((itemData.price*fromAmount))

		if exports['qbr-core']:SplitStr(shopType, "_")[1] == "Dealer" then
			if exports['qbr-core']:SplitStr(itemData.name, "_")[1] == "weapon" then
				price = tonumber(itemData.price)
				if Player.Functions.RemoveMoney("cash", price, "dealer-item-bought") then
					itemData.info.serie = tostring(exports['qbr-core']:RandomInt(2) .. exports['qbr-core']:RandomStr(3) .. exports['qbr-core']:RandomInt(1) .. exports['qbr-core']:RandomStr(2) .. exports['qbr-core']:RandomInt(3) .. exports['qbr-core']:RandomStr(4))
					Player.Functions.AddItem(itemData.name, 1, toSlot, itemData.info)
					TriggerClientEvent('qbr-drugs:client:updateDealerItems', src, itemData, 1)
					TriggerClientEvent('QBCore:Notify', src, 9, Lang:t("success.bought_item", {item = itemInfo["label"]}), 5000, 0, 'hud_textures', 'check', 'COLOR_WHITE')
					TriggerEvent("qbr-log:server:CreateLog", "dealers", "Dealer item bought", "green", "**"..GetPlayerName(src) .. "** bought a " .. itemInfo["label"] .. " for $"..price)
				else
					TriggerClientEvent('QBCore:Notify', src, 9, Lang:t("error.no_cash"), 5000, 0, 'mp_lobby_textures', 'cross', 'COLOR_WHITE')
				end
			else
				if Player.Functions.RemoveMoney("cash", price, "dealer-item-bought") then
					Player.Functions.AddItem(itemData.name, fromAmount, toSlot, itemData.info)
					TriggerClientEvent('qbr-drugs:client:updateDealerItems', src, itemData, fromAmount)
					TriggerClientEvent('QBCore:Notify', src, 9, itemInfo["label"] .. " bought!", 5000, 0, 'hud_textures', 'check', 'COLOR_WHITE')
					TriggerEvent("qbr-log:server:CreateLog", "dealers", "Dealer item bought", "green", "**"..GetPlayerName(src) .. "** bought a " .. itemInfo["label"] .. "  for $"..price)
				else
					TriggerClientEvent('QBCore:Notify', src, 9, Lang:t("error.no_cash"), 5000, 0, 'mp_lobby_textures', 'cross', 'COLOR_WHITE')
				end
			end
		elseif exports['qbr-core']:SplitStr(shopType, "_")[1] == "Itemshop" then
			if Player.Functions.RemoveMoney("cash", price, "itemshop-bought-item") then
                if exports['qbr-core']:SplitStr(itemData.name, "_")[1] == "weapon" then
                    itemData.info.serie = tostring(exports['qbr-core']:RandomInt(2) .. exports['qbr-core']:RandomStr(3) .. exports['qbr-core']:RandomInt(1) .. exports['qbr-core']:RandomStr(2) .. exports['qbr-core']:RandomInt(3) .. exports['qbr-core']:RandomStr(4))
                end
				Player.Functions.AddItem(itemData.name, fromAmount, toSlot, itemData.info)
				TriggerEvent('qbr-shops:server:UpdateShopItems', exports['qbr-core']:SplitStr(shopType, "_")[2], fromSlot, fromAmount)
				TriggerClientEvent('QBCore:Notify', src, 9, Lang:t("success.bought_item", {item = itemInfo["label"]}), 5000, 0, 'hud_textures', 'check', 'COLOR_WHITE')
				TriggerEvent("qbr-log:server:CreateLog", "shops", "Shop item bought", "green", "**"..GetPlayerName(src) .. "** bought a " .. itemInfo["label"] .. " for $"..price)
			elseif bankBalance >= price then
				Player.Functions.RemoveMoney("bank", price, "itemshop-bought-item")
                if exports['qbr-core']:SplitStr(itemData.name, "_")[1] == "weapon" then
                    itemData.info.serie = tostring(exports['qbr-core']:RandomInt(2) .. exports['qbr-core']:RandomStr(3) .. exports['qbr-core']:RandomInt(1) .. exports['qbr-core']:RandomStr(2) .. exports['qbr-core']:RandomInt(3) .. exports['qbr-core']:RandomStr(4))
                end
				Player.Functions.AddItem(itemData.name, fromAmount, toSlot, itemData.info)
				TriggerEvent('qbr-shops:server:UpdateShopItems', exports['qbr-core']:SplitStr(shopType, "_")[2], fromSlot, fromAmount)
				TriggerClientEvent('QBCore:Notify', src, 9, Lang:t("success.bought_item", {item = itemInfo["label"]}), 5000, 0, 'hud_textures', 'check', 'COLOR_WHITE')
				TriggerEvent("qbr-log:server:CreateLog", "shops", "Shop item bought", "green", "**"..GetPlayerName(src) .. "** bought a " .. itemInfo["label"] .. " for $"..price)
			else
				TriggerClientEvent('QBCore:Notify', src, 9, "You don't have enough cash..", 5000, 0, 'mp_lobby_textures', 'cross', 'COLOR_WHITE')
			end
		else
			if Player.Functions.RemoveMoney("cash", price, "unkown-itemshop-bought-item") then
				Player.Functions.AddItem(itemData.name, fromAmount, toSlot, itemData.info)
				TriggerClientEvent('QBCore:Notify', src, 9, Lang:t("success.bought_item", {item = itemInfo["label"]}), 5000, 0, 'hud_textures', 'check', 'COLOR_WHITE')
				TriggerEvent("qbr-log:server:CreateLog", "shops", "Shop item bought", "green", "**"..GetPlayerName(src) .. "** bought a " .. itemInfo["label"] .. " for $"..price)
			elseif bankBalance >= price then
				Player.Functions.RemoveMoney("bank", price, "unkown-itemshop-bought-item")
				Player.Functions.AddItem(itemData.name, fromAmount, toSlot, itemData.info)
				TriggerClientEvent('QBCore:Notify', src, 9, Lang:t("success.bought_item", {item = itemInfo["label"]}), 5000, 0, 'hud_textures', 'check', 'COLOR_WHITE')
				TriggerEvent("qbr-log:server:CreateLog", "shops", "Shop item bought", "green", "**"..GetPlayerName(src) .. "** bought a " .. itemInfo["label"] .. " for $"..price)
			else
				TriggerClientEvent('QBCore:Notify', src, 9, Lang:t("error.no_cash"), 5000, 0, 'mp_lobby_textures', 'cross', 'COLOR_WHITE')
			end
		end
	elseif fromInventory == "attachment_crafting" then
		local itemData = Config.AttachmentCrafting[fromSlot]
		if hasCraftItems(src, itemData.costs, fromAmount) then
			TriggerClientEvent("inventory:client:CraftAttachment", src, itemData.name, itemData.costs, fromAmount, toSlot, itemData.points)
		else
			TriggerClientEvent("inventory:client:UpdatePlayerInventory", src, true)
			TriggerClientEvent('QBCore:Notify', src, 9, Lang:t("error.missing_item"), 5000, 0, 'mp_lobby_textures', 'cross', 'COLOR_WHITE')
		end
	elseif fromInventory == "crafting" then
		local itemData = Config.CraftingItems[fromSlot]
		if hasCraftItems(src, itemData.costs, fromAmount) then
			TriggerClientEvent("inventory:client:CraftItems", src, itemData.name, itemData.costs, fromAmount, toSlot, itemData.points)
		else
			TriggerClientEvent("inventory:client:UpdatePlayerInventory", src, true)
			TriggerClientEvent('QBCore:Notify', src, 9, Lang:t("error.missing_item"), 5000, 0, 'mp_lobby_textures', 'cross', 'COLOR_WHITE')
		end
	else
		-- drop
		fromInventory = tonumber(fromInventory)
		local fromItemData = Drops[fromInventory].items[fromSlot]
		local fromAmount = tonumber(fromAmount) ~= nil and tonumber(fromAmount) or fromItemData.amount
		if fromItemData ~= nil and fromItemData.amount >= fromAmount then
			local itemInfo = sharedItems[fromItemData.name:lower()]
			if toInventory == "player" or toInventory == "hotbar" then
				local toItemData = Player.Functions.GetItemBySlot(toSlot)
				RemoveFromDrop(fromInventory, fromSlot, itemInfo["name"], fromAmount)
				if toItemData ~= nil then
					local toAmount = tonumber(toAmount) ~= nil and tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						Player.Functions.RemoveItem(toItemData.name, toAmount, toSlot)
						AddToDrop(fromInventory, toSlot, itemInfo["name"], toAmount, toItemData.info)
						TriggerEvent("qbr-log:server:CreateLog", "drop", "Swapped Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) swapped item; name: **"..toItemData.name.."**, amount: **" .. toAmount .. "** with item; name: **"..fromItemData.name.."**, amount: **" .. fromAmount .. "** - dropid: *" .. fromInventory .. "*")
					else
						TriggerEvent("qbr-log:server:CreateLog", "drop", "Stacked Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) stacked item; name: **"..toItemData.name.."**, amount: **" .. toAmount .. "** - from dropid: *" .. fromInventory .. "*")
					end
				else
					TriggerEvent("qbr-log:server:CreateLog", "drop", "Received Item", "green", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) received item; name: **"..fromItemData.name.."**, amount: **" .. fromAmount.. "** -  dropid: *" .. fromInventory .. "*")
				end
				Player.Functions.AddItem(fromItemData.name, fromAmount, toSlot, fromItemData.info)
			else
				toInventory = tonumber(toInventory)
				local toItemData = Drops[toInventory].items[toSlot]
				RemoveFromDrop(fromInventory, fromSlot, itemInfo["name"], fromAmount)
				if toItemData ~= nil then
					local itemInfo = sharedItems[toItemData.name:lower()]
					local toAmount = tonumber(toAmount) ~= nil and tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						local itemInfo = sharedItems[toItemData.name:lower()]
						RemoveFromDrop(toInventory, toSlot, itemInfo["name"], toAmount)
						AddToDrop(fromInventory, fromSlot, itemInfo["name"], toAmount, toItemData.info)
					end
				else
				end
				local itemInfo = sharedItems[fromItemData.name:lower()]
				AddToDrop(toInventory, toSlot, itemInfo["name"], fromAmount, fromItemData.info)
			end
		else
			TriggerClientEvent("QBCore:Notify", src, Lang:t("error.not_exist"), 5000, 0, 'mp_lobby_textures', 'cross', 'COLOR_WHITE')
		end
	end
end)

RegisterNetEvent('qbr-inventory:server:SaveStashItems', function(stashId, items)
    exports.oxmysql:insert('INSERT INTO stashitems (stash, items) VALUES (:stash, :items) ON DUPLICATE KEY UPDATE items = :items', {
        ['stash'] = stashId,
        ['items'] = json.encode(items)
    })
end)

RegisterServerEvent("inventory:server:GiveItem", function(target, inventory, item, amount)
    local src = source
    local Player = exports['qbr-core']:GetPlayer(src)
    local OtherPlayer = exports['qbr-core']:GetPlayer(tonumber(target))
    local dist = #(GetEntityCoords(GetPlayerPed(src))-GetEntityCoords(GetPlayerPed(target)))
	if Player == OtherPlayer then return TriggerClientEvent('QBCore:Notify', src, 9, Lang:t("error.yourself"), 5000, 0, 'mp_lobby_textures', 'cross', 'COLOR_WHITE') end
	if dist > 2 then return TriggerClientEvent('QBCore:Notify', src, 9, Lang:t("error.toofar"), 5000, 0, 'mp_lobby_textures', 'cross', 'COLOR_WHITE') end
	if amount <= item.amount then
		if amount == 0 then
			amount = item.amount
		end
		if OtherPlayer.Functions.AddItem(item.name, amount, false, item.info) then
			TriggerClientEvent('inventory:client:ItemBox',target, sharedItems[item.name], "add")
			TriggerClientEvent('QBCore:Notify', target, Lang:t("success.recieved", {amount = amount, item = item.label, firstname = Player.PlayerData.charinfo.firstname, lastname = Player.PlayerData.charinfo.lastname}), 5000, 0, 'hud_textures', 'check', 'COLOR_WHITE')
			TriggerClientEvent("inventory:client:UpdatePlayerInventory", target, true)
			Player.Functions.RemoveItem(item.name, amount, item.slot)
			TriggerClientEvent('inventory:client:ItemBox',src, sharedItems[item.name], "remove")
			TriggerClientEvent('QBCore:Notify', src, 9, Lang:t("success.gave", {amount = amount, item = item.label, firstname = OtherPlayer.PlayerData.charinfo.firstname, lastname = OtherPlayer.PlayerData.charinfo.lastname}), 5000, 0, 'hud_textures', 'check', 'COLOR_WHITE')
			TriggerClientEvent("inventory:client:UpdatePlayerInventory", src, true)
			TriggerClientEvent('qbr-inventory:client:giveAnim', src)
			TriggerClientEvent('qbr-inventory:client:giveAnim', target)
		else

			TriggerClientEvent('QBCore:Notify', src, 9, Lang:t("error.otherfull"), 5000, 0, 'mp_lobby_textures', 'cross', 'COLOR_WHITE')
			TriggerClientEvent('QBCore:Notify', target, Lang:t("error.invfull"), 5000, 0, 'mp_lobby_textures', 'cross', 'COLOR_WHITE')
			TriggerClientEvent("inventory:client:UpdatePlayerInventory", src, false)
			TriggerClientEvent("inventory:client:UpdatePlayerInventory", target, false)
		end
	else
		TriggerClientEvent('QBCore:Notify', src, 9, Lang:t("error.not_enough"), 5000, 0, 'mp_lobby_textures', 'cross', 'COLOR_WHITE')
	end
end)

-- callback

exports['qbr-core']:CreateCallback('qbr-inventory:server:GetStashItems', function(source, cb, stashId)
	cb(GetStashItems(stashId))
end)

-- command

exports['qbr-core']:AddCommand("resetinv", "Reset Inventory (Admin Only)", {{name="type", help="stash"},{name="id/plate", help="ID of stash or license plate"}}, true, function(source, args)
	local invType = args[1]:lower()
	table.remove(args, 1)
	local invId = table.concat(args, " ")
	if invType ~= nil and invId ~= nil then
		if invType == "stash" then
			if Stashes[invId] ~= nil then
				Stashes[invId].isOpen = false
			end
		else
			TriggerClientEvent('QBCore:Notify', source, 9, Lang:t("error.invalid_type"), 5000, 0, 'mp_lobby_textures', 'cross', 'COLOR_WHITE')
		end
	else
		TriggerClientEvent('QBCore:Notify', source, 9, Lang:t("error.arguments"), 5000, 0, 'mp_lobby_textures', 'cross', 'COLOR_WHITE')
	end
end, "admin")

exports['qbr-core']:AddCommand("rob", "Rob Player", {}, false, function(source, args)
	TriggerClientEvent("police:client:RobPlayer", source)
end)

exports['qbr-core']:AddCommand("giveitem", "Give An Item (Admin Only)", {{name="id", help="Player ID"},{name="item", help="Name of the item (not a label)"}, {name="amount", help="Amount of items"}}, true, function(source, args)
	local Player = exports['qbr-core']:GetPlayer(tonumber(args[1]))
	local amount = tonumber(args[3]) or 1
	local itemData = sharedItems[tostring(args[2]):lower()]
	if Player then
		if amount > 0 then
			if itemData then
				-- check iteminfo
				local info = {}
				if itemData["name"] == "id_card" then
					info.citizenid = Player.PlayerData.citizenid
					info.firstname = Player.PlayerData.charinfo.firstname
					info.lastname = Player.PlayerData.charinfo.lastname
					info.birthdate = Player.PlayerData.charinfo.birthdate
					info.gender = Player.PlayerData.charinfo.gender
					info.nationality = Player.PlayerData.charinfo.nationality
				elseif itemData["type"] == "weapon" then
					amount = 1
					info.serie = tostring(exports['qbr-core']:RandomInt(2) .. exports['qbr-core']:RandomStr(3) .. exports['qbr-core']:RandomInt(1) .. exports['qbr-core']:RandomStr(2) .. exports['qbr-core']:RandomInt(3) .. exports['qbr-core']:RandomStr(4))
				elseif itemData["name"] == "harness" then
					info.uses = 20
				elseif itemData["name"] == "markedbills" then
					info.worth = math.random(5000, 10000)
				elseif itemData["name"] == "labkey" then
					info.lab = exports["qbr-methlab"]:GenerateRandomLab()
				elseif itemData["name"] == "printerdocument" then
					info.url = "https://cdn.discordapp.com/attachments/870094209783308299/870104331142189126/Logo_-_Display_Picture_-_Stylized_-_Red.png"
				end

				if Player.Functions.AddItem(itemData["name"], amount, false, info) then
					TriggerClientEvent('QBCore:Notify', source, 9, Lang:t("success.yougave", {amount = amount, item = itemData["name"], name = GetPlayerName(tonumber(args[1]))}), 5000, 0, 'hud_textures', 'check', 'COLOR_WHITE')
					TriggerClientEvent('inventory:client:ItemBox', tonumber(args[1]), sharedItems[itemData["name"]], 'add')
				else
					TriggerClientEvent('QBCore:Notify', source, 9,  Lang:t("error.cant_give"), 5000, 0, 'mp_lobby_textures', 'cross', 'COLOR_WHITE')
				end
			else
				TriggerClientEvent('QBCore:Notify', source, 9,  Lang:t("error.not_exist"), 5000, 0, 'mp_lobby_textures', 'cross', 'COLOR_WHITE')
			end
		else
			TriggerClientEvent('QBCore:Notify', source, 9,  Lang:t("error.invalid_amount"), 5000, 0, 'mp_lobby_textures', 'cross', 'COLOR_WHITE')
		end
	else
		TriggerClientEvent('QBCore:Notify', source, 9,  Lang:t("error.not_online"), 5000, 0, 'mp_lobby_textures', 'cross', 'COLOR_WHITE')
	end
end, "admin")

-- item

exports['qbr-core']:CreateUseableItem("driver_license", function(source, item)
	local PlayerPed = GetPlayerPed(source)
	local PlayerCoords = GetEntityCoords(PlayerPed)
	for k, v in pairs(exports['qbr-core']:GetPlayers()) do
		local TargetPed = GetPlayerPed(v)
		local dist = #(PlayerCoords - GetEntityCoords(TargetPed))
		if dist < 3.0 then
			TriggerClientEvent('chat:addMessage', v,  {
					template = '<div class="chat-message advert"><div class="chat-message-body"><strong>{0}:</strong><br><br> <strong>First Name:</strong> {1} <br><strong>Last Name:</strong> {2} <br><strong>Birth Date:</strong> {3} <br><strong>Licenses:</strong> {4}</div></div>',
					args = {
						"Drivers License",
						item.info.firstname,
						item.info.lastname,
						item.info.birthdate,
						item.info.type
					}
				}
			)
		end
	end
end)

exports['qbr-core']:CreateUseableItem("id_card", function(source, item)
	local PlayerPed = GetPlayerPed(source)
	local PlayerCoords = GetEntityCoords(PlayerPed)
	for k, v in pairs(exports['qbr-core']:GetPlayers()) do
		local TargetPed = GetPlayerPed(v)
		local dist = #(PlayerCoords - GetEntityCoords(TargetPed))
		if dist < 3.0 then
			local gender = "Man"
			if item.info.gender == 1 then
				gender = "Woman"
			end
			TriggerClientEvent('chat:addMessage', v,  {
					template = '<div class="chat-message advert"><div class="chat-message-body"><strong>{0}:</strong><br><br> <strong>Civ ID:</strong> {1} <br><strong>First Name:</strong> {2} <br><strong>Last Name:</strong> {3} <br><strong>Birthdate:</strong> {4} <br><strong>Gender:</strong> {5} <br><strong>Nationality:</strong> {6}</div></div>',
					args = {
						"ID Card",
						item.info.citizenid,
						item.info.firstname,
						item.info.lastname,
						item.info.birthdate,
						gender,
						item.info.nationality
					}
				}
			)
		end
	end
end)
