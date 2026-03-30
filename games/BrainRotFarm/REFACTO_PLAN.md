# REFACTO_PLAN.md — Plan de refactorisation
> Généré le 2026-03-30 — Audit technique DobiGames
> Trié par impact sur les reskins (priorité décroissante)

---

## Priorité 1 — CRITIQUE (casse les reskins si non corrigé)

### P1-A : MonetizationHandler — supprimer require(FlowerPotSystem)

**Problème :**
```lua
-- shared-lib/server/MonetizationHandler.lua
❌ local FlowerPotSystem = require(...FlowerPotSystem)
-- Zoo n'a pas FlowerPotSystem → require() plantera au démarrage
```

**Fix :**
```lua
-- Pattern callback injection
-- Dans Main.server.lua (BRF-specific) :
MonetizationHandler.RegisterProductHandler(Config.Products.SkipSeedTimer, function(player)
    FlowerPotSystem.SkipTimer(player)
end)
MonetizationHandler.RegisterProductHandler(Config.Products.SeedPack, function(player)
    SeedInventory.AddPack(player, 3)
end)

-- Dans MonetizationHandler.lua (shared) :
local productHandlers = {}
function MonetizationHandler.RegisterProductHandler(productId, callback)
    productHandlers[productId] = callback
end
-- ProcessReceipt appelle productHandlers[receiptInfo.ProductId](player)
```

**Effort :** 45 min
**Risk :** MEDIUM (tester ProcessReceipt après changement)
**Impact :** CRITIQUE — reskin Zoo planterait au boot sans ce fix

---

### P1-B : FilterRegistry — lire couleurs depuis GameConfig

**Problème :**
```lua
-- shared-lib/BRFilterSystem/FilterRegistry.lua
❌ if rarity == "BRAINROT_GOD" then return Color3.fromRGB(255, 140, 0) end
❌ if rarity == "MYTHIC" then return Color3.fromRGB(148, 0, 211) end
❌ if rarity == "SECRET" then return Color3.fromRGB(255, 255, 255) end
-- Zoo n'a pas MYTHIC/SECRET/BRAINROT_GOD → couleur non trouvée → fallback incorrect
```

**Fix :**
```lua
-- FilterRegistry.lua
local GameConfig = require(game.ReplicatedStorage.GameConfig)

function FilterRegistry.GetRarityColor(rarityName)
    local rarity = GameConfig.Raretes[rarityName]
    if rarity and rarity.Color then
        return rarity.Color
    end
    return Color3.fromRGB(200, 200, 200) -- fallback neutre
end

-- GameConfig.lua (chaque jeu définit ses propres couleurs)
Raretes = {
    MYTHIC = { Color = Color3.fromRGB(148, 0, 211), ... },
    SECRET = { Color = Color3.fromRGB(255, 255, 255), ... },
}
```

**Effort :** 20 min
**Risk :** LOW (lecture seule depuis Config)
**Impact :** CRITIQUE — visuels incorrects sur tous les reskins

---

### P1-C : RebirthSystem — paramétrer condition "BRAINROT_GOD"

**Problème :**
```lua
-- shared-lib/server/RebirthSystem.lua (ligne 63-65)
❌ if rebirthCount >= 5 then requiredRarity = "BRAINROT_GOD" end
-- Zoo n'a pas "BRAINROT_GOD" → condition rebirth brisée
```

**Fix :**
```lua
-- GameConfig.lua (BRF)
RebirthConfig = {
    RequiredRarity = {
        [1] = "LEGENDARY",
        [3] = "MYTHIC",
        [5] = "SECRET",
        [8] = "BRAINROT_GOD",
    }
}

-- RebirthSystem.lua (shared)
local function getRequiredRarity(rebirthCount)
    local paliers = GameConfig.RebirthConfig.RequiredRarity
    local required = "LEGENDARY" -- fallback générique
    for niveau, rarity in pairs(paliers) do
        if rebirthCount >= niveau then required = rarity end
    end
    return required
end
```

**Effort :** 15 min
**Risk :** LOW
**Impact :** CRITIQUE — rebirth brisé sur reskins sans rareté GOD

---

### P1-D : PickupSystem — lire couleurs raretés depuis Config

**Problème :**
```lua
-- shared-lib/server/PickupSystem.lua
❌ local RARETE_COULEURS = {
    COMMON = Color3.fromRGB(200,200,200),
    RARE   = Color3.fromRGB(100,150,255),
    -- ... toutes les raretés BRF hardcodées
    BRAINROT_GOD = Color3.fromRGB(255,140,0),
}
❌ if rarity == "BRAINROT_GOD" then -- animation rainbow
❌ if rarity == "SECRET" then -- animation pulse
```

**Fix :**
```lua
-- PickupSystem.lua
local GameConfig = require(game.ReplicatedStorage.GameConfig)

local function getRarityColor(rarityName)
    local rarity = GameConfig.Raretes[rarityName]
    return rarity and rarity.Color or Color3.fromRGB(200,200,200)
end

local function getSpecialAnimation(rarityName)
    local rarity = GameConfig.Raretes[rarityName]
    return rarity and rarity.SpecialAnimation or nil
end

-- GameConfig.lua
Raretes = {
    BRAINROT_GOD = {
        Color = Color3.fromRGB(255, 140, 0),
        SpecialAnimation = "rainbow",
    },
    SECRET = {
        Color = Color3.fromRGB(255, 255, 255),
        SpecialAnimation = "pulse",
    },
}
```

**Effort :** 30 min
**Risk :** LOW (UI seulement)
**Impact :** ÉLEVÉ — billboard avec mauvaises couleurs sur reskins

---

## Priorité 2 — ÉLEVÉ (comportement incorrect mais pas crash)

### P2-A : EventManager — lire types depuis GameConfig

**Problème :**
```lua
-- shared-lib/server/EventManager.lua
❌ types = {"NightMode", "MeteorDrop", "Rain", "Golden", "LuckyHour", "DoubleCoins"}
-- Zoo n'a pas de "MeteorDrop" ou "Rain" → thème incohérent
```

**Fix :**
```lua
-- GameConfig.lua (BRF)
EventTypes = {"NightMode", "MeteorDrop", "Rain", "Golden", "LuckyHour", "DoubleCoins"}

-- GameConfig.lua (Zoo)
EventTypes = {"Stampede", "RainbowAnimals", "Golden", "DoubleCoins"}

-- EventManager.lua
local types = GameConfig.EventTypes
```

**Effort :** 10 min
**Risk :** LOW
**Impact :** ÉLEVÉ — events inadaptés au thème du jeu

---

### P2-B : DataStoreManager — paramétrer nom du DataStore

**Problème :**
```lua
❌ local DS = DataStoreService:GetDataStore("BrainRotIdleV1")
```

**Fix :**
```lua
-- GameConfig.lua
DataStoreName = "BrainRotIdleV1"  -- pour BRF
-- DataStoreName = "ZooIdleV1"    -- pour Zoo

-- DataStoreManager.lua
local DS = DataStoreService:GetDataStore(GameConfig.DataStoreName)
```

**Effort :** 5 min
**Risk :** ⚠️ ATTENTION — changer le nom efface les données existantes
**Note :** Ne changer que pour les nouveaux jeux, JAMAIS pour BRF en prod

---

### P2-C : BatEquipHandler — paramétrer nom de l'arme

**Problème :**
```lua
❌ local weapon = ServerStorage.Weapons:FindFirstChild("BaseballBat")
```

**Fix :**
```lua
-- GameConfig.lua
Combat = {
    BatEnabled = true,
    StartingWeapon = "BaseballBat",  -- BRF
    -- StartingWeapon = "Net",       -- Zoo
}

-- BatEquipHandler.lua
local weapon = ServerStorage.Weapons:FindFirstChild(GameConfig.Combat.StartingWeapon)
```

**Effort :** 5 min
**Risk :** LOW

---

## Priorité 3 — MOYEN (incohérence mais non-bloquant)

### P3-A : UITheme — externaliser palette dans GameConfig

**Problème :**
```lua
-- shared-lib/shared/UITheme.lua
❌ fondPrincipal = Color3.fromRGB(101, 67, 33)   -- marron bois BRF
❌ fondBouton   = Color3.fromRGB(218, 165, 32)   -- jaune blé BRF
```

**Fix :**
```lua
-- GameConfig.lua
UITheme = {
    fondPrincipal = Color3.fromRGB(101, 67, 33),
    fondBouton    = Color3.fromRGB(218, 165, 32),
    texte         = Color3.fromRGB(255, 255, 255),
}

-- UITheme.lua
local GameConfig = require(game.ReplicatedStorage.GameConfig)
return GameConfig.UITheme
```

**Effort :** 15 min
**Risk :** LOW (cosmétique)

---

### P3-B : BrainrotInventoryService — renommer générique

**Problème :**
```lua
❌ "BrainrotInventoryService" → nom couplé à BRF
❌ RemoteEvent "BrainrotCollected"
```

**Fix :**
```lua
-- Renommer le fichier → CollectibleInventoryService.lua
-- RemoteEvent → GameConfig.CollectibleName .. "Collected"
```

**Effort :** 10 min
**Risk :** LOW (mise à jour références)

---

### P3-C : RebirthCosmeticsSystem — externaliser paliers

**Problème :**
```lua
❌ PALIERS_COSMETIQUES = {[1]=..., [3]=..., [5]=..., [10]="REBIRTH_GOD"}
```

**Fix :**
```lua
-- GameConfig.lua
RebirthCosmetics = {
    [1]  = { aura = "blue",   label = "Rebirth I" },
    [3]  = { aura = "purple", label = "Rebirth III" },
    [5]  = { aura = "gold",   label = "Rebirth V" },
    [10] = { aura = "red",    label = "REBIRTH_GOD" },
}
```

**Effort :** 20 min
**Risk :** LOW

---

## Priorité 4 — LOW (nice to have)

### P4-A : Déplacer filtres Element vers BRF

**Action :** Déplacer `ElementEau.lua`, `ElementFeu.lua`, `ElementTerre.lua`, `ElementVent.lua`
de `shared-lib/BRFilterSystem/Filters/Element/`
vers `BrainRotFarm/src/Systems/FlowerPotSystem/Filters/`

**Effort :** 10 min (déplacer + mettre à jour références)
**Risk :** LOW
**Bénéfice :** shared-lib allégée, architecture plus claire

---

### P4-B : Extraire logique FlowerPot de Main.server.lua

**Problème :** `Main.server.lua` fait 450+ lignes et contient ~400 lignes de logique FlowerPot
(InitialiserPots, gestion dailySeed, gestion tempsJeuSemaine)

**Fix :**
```
Déplacer vers FlowerPotGrowthSystem.lua :
- InitialiserPots()
- GérerDailySeed()

Déplacer vers LeaderboardSystem.lua :
- GérerTempsJeuSemaine()
```

**Effort :** 60 min
**Risk :** MEDIUM (tester comportement après extraction)

---

### P4-C : ShopSystem vers shared-lib

**Action :** Déplacer `ShopSystem.lua` (logique générique)
de `BrainRotFarm/` vers `shared-lib/server/`

**Prérequis :** Contenu shop déjà dans `GameConfig.ShopUpgrades` ✅
**Effort :** 15 min
**Risk :** LOW

---

## Résumé exécutif

| ID | Fix | Effort | Risk | Bloque reskin |
|----|-----|--------|------|---------------|
| P1-A | MonetizationHandler callbacks | 45 min | MEDIUM | ❌ OUI |
| P1-B | FilterRegistry → GameConfig | 20 min | LOW | ❌ OUI |
| P1-C | RebirthSystem rareté condition | 15 min | LOW | ❌ OUI |
| P1-D | PickupSystem couleurs raretés | 30 min | LOW | ❌ OUI |
| P2-A | EventManager types depuis Config | 10 min | LOW | ⚠️ PARTIEL |
| P2-B | DataStore name depuis Config | 5 min | ⚠️ ATTENTION | ⚠️ PARTIEL |
| P2-C | BatEquipHandler nom arme | 5 min | LOW | NON |
| P3-A | UITheme palette depuis Config | 15 min | LOW | NON |
| P3-B | Renommer CollectibleInventory | 10 min | LOW | NON |
| P3-C | RebirthCosmetics depuis Config | 20 min | LOW | NON |
| P4-A | Déplacer filtres Element | 10 min | LOW | NON |
| P4-B | Extraire FlowerPot de Main | 60 min | MEDIUM | NON |
| P4-C | ShopSystem vers shared-lib | 15 min | LOW | NON |

**Total Priorité 1 :** ~110 min
**Total Priorité 1+2 :** ~140 min
**Total complet :** ~260 min

---

## Ordre d'exécution recommandé

**Avant premier reskin (obligatoire) :**
1. P1-A MonetizationHandler callbacks
2. P1-B FilterRegistry → GameConfig
3. P1-C RebirthSystem condition
4. P1-D PickupSystem couleurs
5. P2-A EventManager types

**Au démarrage du premier reskin (recommandé) :**
6. P2-B DataStore name (UNIQUEMENT pour le nouveau jeu)
7. P3-A UITheme palette
8. P4-A Déplacer filtres Element

**Backlog maintenabilité (optionnel) :**
9. P3-B Renommer CollectibleInventory
10. P3-C RebirthCosmetics
11. P4-B Extraire FlowerPot de Main
12. P4-C ShopSystem vers shared-lib
