# DATASTORE_SCHEMA.md — Schéma DataStore BrainRotFarm
> Généré le 2026-03-30 — Audit technique DobiGames
> Source : DataStoreManager.lua — DataStore "BrainRotIdleV1"

---

## Structure DefaultData complète

```lua
local defaultData = {
    -- === CHAMPS SHARED (cross-game potentiel) ===
    coins               = 0,          -- monnaie principale
    tier                = 1,          -- niveau de progression
    prestige            = 0,          -- alias rebirth (ancien système)
    coinsParMinute      = 0,          -- revenu passif calculé
    multiplicateurPermanent = 1,      -- bonus multiplicateur rebirth
    rebirthCount        = 0,          -- nombre de rebirths effectués
    upgrades = {                      -- upgrades achetés (clés variables)
        Arroseur        = 0,          -- ⚠️ nom BRF-specific
        Speed           = 0,
        Carry           = 0,
        Aimant          = 0,          -- ⚠️ nom BRF-specific
    },

    -- === CHAMPS BRF-SPECIFIC ===
    inventory = {                     -- compteurs de collectibles par rareté
        COMMON          = 0,
        OG              = 0,          -- rareté exclusive BRF (entre COMMON et RARE)
        RARE            = 0,
        EPIC            = 0,
        LEGENDARY       = 0,
        MYTHIC          = 0,
        SECRET          = 0,
        BRAINROT_GOD    = 0,
    },
    flowerPotSlots = {               -- 4 pots de fleurs (feature exclusive BRF)
        [1] = {
            rarete          = nil,   -- rareté du BR planté (MYTHIC ou SECRET)
            stageBoisson    = 0,     -- stade de croissance (0-5)
            tempsRestant    = 0,     -- secondes avant prochain stade
            elementType     = nil,   -- élément mutant (EAU/FEU/TERRE/VENT)
            brNom           = nil,   -- nom du BR planté
        },
        [2] = { ... },               -- identique
        [3] = { ... },               -- identique
        [4] = { ... },               -- identique
    },
    dailySeed = {                    -- système de graine quotidienne
        jourActuel      = 0,         -- jour du cycle (0-6)
        graineDispo     = true,      -- graine disponible ce jour
        lastClaimDay    = 0,         -- timestamp dernier claim
    },
    lastSaveTime        = 0,         -- timestamp dernière sauvegarde
    totalPlayTime       = 0,         -- temps de jeu total (secondes)
    tempsJeuSemaine     = 0,         -- temps jeu semaine courante (Top Farmer)
    weeklyResetTime     = 0,         -- timestamp reset hebdo
}
```

---

## Classification des champs

### Champs SHARED (réutilisables cross-game)

| Champ | Type | Description | Utilisé par |
|-------|------|-------------|-------------|
| `coins` | number | Monnaie principale | Tous les jeux |
| `tier` | number | Niveau de progression | Tous les jeux |
| `rebirthCount` | number | Nombre de rebirths | Tous les jeux |
| `multiplicateurPermanent` | number | Bonus rebirth cumulé | Tous les jeux |
| `coinsParMinute` | number | Revenu passif | Tous les jeux |
| `lastSaveTime` | number | Timestamp sauvegarde | Tous les jeux |
| `totalPlayTime` | number | Temps de jeu total | Tous les jeux |
| `tempsJeuSemaine` | number | Classement hebdo | Tous les jeux |
| `weeklyResetTime` | number | Reset hebdomadaire | Tous les jeux |
| `prestige` | number | Alias rebirth (legacy) | Héritage (préserver) |

### Champs hybrides (génériques mais noms BRF)

| Champ | Type | Problème | Fix |
|-------|------|----------|-----|
| `upgrades.Arroseur` | number | Nom BRF (sprinkler) | Renommer selon GameConfig.ShopUpgrades |
| `upgrades.Aimant` | number | Nom BRF (aimant) | Renommer selon GameConfig.ShopUpgrades |
| `upgrades.Speed` | number | Générique OK | Garder |
| `upgrades.Carry` | number | Générique OK | Garder |

### Champs BRF-SPECIFIC (à recréer par jeu)

| Champ | Type | Feature BRF | Équivalent Zoo |
|-------|------|-------------|----------------|
| `inventory` | table | Compteurs par rareté BRF | Compteurs par espèce/rareté Zoo |
| `flowerPotSlots[1..4]` | table | 4 pots de fleurs | N/A (pas de pots dans Zoo) |
| `dailySeed` | table | Graine quotidienne | N/A |
| `inventory.OG` | number | Rareté exclusive BRF | N/A |
| `inventory.BRAINROT_GOD` | number | Rareté ultime BRF | Équivalent à créer |

---

## Problèmes détectés

### RED FLAG 1 — DataStore name hardcodé
```lua
-- DataStoreManager.lua (ligne 4)
❌ local DS = DataStoreService:GetDataStore("BrainRotIdleV1")
   → "BrainRotIdleV1" hardcodé en dur

-- Fix recommandé :
✅ local DS = DataStoreService:GetDataStore(GameConfig.DataStoreName)
   -- GameConfig.DataStoreName = "BrainRotIdleV1" pour BRF
   -- GameConfig.DataStoreName = "ZooIdleV1" pour Zoo
```

### RED FLAG 2 — Noms upgrades hardcodés
```lua
-- DefaultData upgrades
❌ upgrades.Arroseur  -- "Arroseur" = terme agraire BRF
❌ upgrades.Aimant    -- "Aimant" = fonctionnalité BRF

-- Fix recommandé :
-- Les clés upgrades devraient correspondre à GameConfig.ShopUpgrades[].Id
-- Chaque jeu a ses propres upgrades → DataStoreManager généré depuis Config
```

### RED FLAG 3 — Schéma inventory BRF figé
```lua
-- inventory contient exactement les raretés BRF
❌ inventory.OG         -- rareté exclusive BRF
❌ inventory.BRAINROT_GOD -- rareté ultime BRF

-- Pour Zoo reskin :
-- inventory devrait avoir les raretés Zoo (BRONZE, SILVER, GOLD, etc.)
-- Nécessite DataStoreManager spécifique par jeu (correct — mais à documenter)
```

---

## Qui écrit dans quels champs ? (ownership)

| Champ | Écrit par | Problème |
|-------|-----------|----------|
| `coins` | IncomeSystem ✅ | OK |
| `rebirthCount` | RebirthSystem ✅ | OK |
| `multiplicateurPermanent` | RebirthSystem ✅ | OK |
| `flowerPotSlots` | Main.server.lua ⚠️ | Logique FlowerPot dans orchestrateur (450+ lignes) |
| `dailySeed` | Main.server.lua ⚠️ | Idem — devrait être dans FlowerPotSystem |
| `inventory` | IncomeSystem ✅ | OK |
| `upgrades` | ShopSystem ✅ | OK |
| `tempsJeuSemaine` | Main.server.lua ⚠️ | Devrait être dans LeaderboardSystem |

### Violation ownership critique
```
❌ Main.server.lua (InitialiserPots ~400 lignes) gère directement :
   - player.Data.flowerPotSlots → devrait être FlowerPotGrowthSystem
   - player.Data.dailySeed → devrait être SeedInventory
   - player.Data.tempsJeuSemaine → devrait être LeaderboardSystem

→ L'orchestrateur est trop gros (450+ lignes) car il assume des responsabilités système
```

---

## Recommandations DataStore

1. **Ajouter `GameConfig.DataStoreName`** — paramétrer le nom du DS
2. **Extraire logique FlowerPot de Main.server.lua** — 400 lignes vers FlowerPotGrowthSystem
3. **Documenter que DataStoreManager est BRF-specific** — chaque jeu a le sien
4. **Pour reskins** — copier DataStoreManager, adapter DefaultData + DS name via Config
