-- ReplicatedStorage/Modules/RebirthConfig.lua
-- Format shared-lib RebirthSystem
-- Injecté via RebirthSystem.Init({ Config = require(ReplicatedStorage.RebirthConfig) })

local RebirthConfig = {}

RebirthConfig.Tiers = {
    [1]  = { coinsRequis=10000,     brainRotRequis={rarete="COMMON",    quantite=1}, multiplicateur=1.2, slotsBonus=1, label="Rebirth I",    couleur=Color3.fromRGB(200, 200, 200), couleurHex=0xC8C8C8 },
    [2]  = { coinsRequis=25000,     brainRotRequis={rarete="RARE",      quantite=1}, multiplicateur=1.4, slotsBonus=1, label="Rebirth II",   couleur=Color3.fromRGB(100, 200, 100), couleurHex=0x64C864 },
    [3]  = { coinsRequis=60000,     brainRotRequis={rarete="RARE",      quantite=1}, multiplicateur=1.6, slotsBonus=1, label="Rebirth III",  couleur=Color3.fromRGB(100, 130, 255), couleurHex=0x6482FF },
    [4]  = { coinsRequis=150000,    brainRotRequis={rarete="EPIC",      quantite=1}, multiplicateur=1.8, slotsBonus=1, label="Rebirth IV",   couleur=Color3.fromRGB(100, 130, 255), couleurHex=0x6482FF },
    [5]  = { coinsRequis=500000,    brainRotRequis={rarete="EPIC",      quantite=1}, multiplicateur=2.2, slotsBonus=1, label="Rebirth V",    couleur=Color3.fromRGB(180, 50,  255), couleurHex=0xB432FF },
    [6]  = { coinsRequis=1500000,   brainRotRequis={rarete="LEGENDARY", quantite=1}, multiplicateur=2.7, slotsBonus=1, label="Rebirth VI",   couleur=Color3.fromRGB(180, 50,  255), couleurHex=0xB432FF },
    [7]  = { coinsRequis=5000000,   brainRotRequis={rarete="LEGENDARY", quantite=1}, multiplicateur=3.5, slotsBonus=1, label="Rebirth VII",  couleur=Color3.fromRGB(255, 200, 0  ), couleurHex=0xFFC800 },
    [8]  = { coinsRequis=20000000,  brainRotRequis={rarete="MYTHIC",    quantite=1}, multiplicateur=4.5, slotsBonus=1, label="Rebirth VIII", couleur=Color3.fromRGB(255, 200, 0  ), couleurHex=0xFFC800 },
    [9]  = { coinsRequis=75000000,  brainRotRequis={rarete="GOD",       quantite=1}, multiplicateur=6.0, slotsBonus=1, label="Rebirth IX",   couleur=Color3.fromRGB(255, 50,  50 ), couleurHex=0xFF3232 },
    [10] = { coinsRequis=250000000, brainRotRequis={rarete="GOD",       quantite=1}, multiplicateur=8.0, slotsBonus=1, label="Rebirth X",    couleur=Color3.fromRGB(255, 50,  50 ), couleurHex=0xFF3232 },
}

return RebirthConfig
