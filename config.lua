Config = {}

Config.CraftingObject = `prop_toolchest_05`

Config.CraftingItems = {
    [1] = {
        name = "lockpick",
        amount = 20,
        info = {},
        costs = {
            ["metalscrap"] = 20,
            ["plastic"] = 20,
        },
        type = "item",
        threshold = 0,
        points = 1,
    },
    [2] = {
        name = "coffee",
        amount = 20,
        info = {},
        costs = {
            ["coffeeseeds"] = 20,
            ["water_bottle"] = 20,
        },
        type = "item",
        threshold = 0,
        points = 2,
    },
}

Config.AttachmentCraftingLocation = vector3(-277.2096, 779.3605, 119.504)

Config.AttachmentCrafting = {
    [1] = {
        name = "weapon_revolver_cattleman",
        amount = 50,
        info = {},
        costs = {
            ["metalscrap"] = 140,
        },
        type = "item",
        threshold = 0,
        points = 1,
    },
}

MaxInventorySlots = 41

Config.MaximumAmmoValues = {
    ["pistol"] = 250,
    ["rifle"] = 250,
}
