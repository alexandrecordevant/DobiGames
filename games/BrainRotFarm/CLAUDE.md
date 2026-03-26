- Projet actif : BrainRotFarm
- Ne pas modifier LavaTower ou BrainRotKong sauf demande explicite
- shared-lib peut être lu, mais ne doit être modifié qu'en cas de besoin réel
- Toujours signaler l'impact cross-game si shared-lib change

# DobiGames Context — Claude Code Reference

## Modèle validé
**Idle/farm infini** (benchmark: Grow a Garden ~$12M/mois)
- Format: carry/farm avec spawns progressifs, carry capacity upgrades, base progression, events
- Pas d'obby, pas de combat complexe
- Mobile-first (60%+ joueurs)

## Flagship actuel
**BrainRotFarm** — 6-player carry/farm game
- Chaque joueur: field individuel (BrainRots spawn) + base 4 étages (40 slots unlock progressif)
- ChampCommun: event toutes 5min, MYTHIC/SECRET spawns uniquement
- Carry capacity: 1 BR défaut → upgradable à 5
- Mort = lose all carried BRs (sauf Protection Game Pass)

---

## Standards Lua (OBLIGATOIRE)

### Syntaxe
```lua
-- ✅ TOUJOURS
task.wait(1)           -- NEVER wait()
task.spawn(function)   -- NEVER spawn()
task.delay(2, func)    -- NEVER delay()

-- ✅ DataStore protection
local success, data = pcall(function()
    return DataStore:GetAsync(key)
end)
if not success then
    warn("DataStore error:", data)
    return defaultValue
end

-- ✅ Server-side validation uniquement
-- Client → demande action
-- Server → valide + exécute + réplique résultat
```

### Mobile compatibility
```lua
-- ✅ Pickup: Touched (fonctionne mobile)
part.Touched:Connect(function(hit)
    local character = hit.Parent
    -- logic
end)

-- ✅ Deposit: ProximityPrompt (mobile-compatible)
local prompt = Instance.new("ProximityPrompt")
prompt.ActionText = "Déposer BrainRots"
prompt.Triggered:Connect(function(player)
    -- logic
end)
```

### Commentaires
```lua
-- ✅ Toujours en français
-- Configure le système de spawn
local spawnRate = 5 -- secondes entre chaque spawn

-- ❌ JAMAIS
-- Configure spawn system
local spawnRate = 5 -- seconds between spawns
```

---

## Architecture idle/farm

### Séparation obligatoire
Chaque système = 1 script distinct:

**1. Spawn** (`BrainRotSpawner.lua`, `ChampCommunSpawner.lua`)
- Generation zones, timers, rarity logic
- Weighted random selection
- Respect spawn limits par zone

**2. Carry** (`CarrySystem.lua`)
- Pickup (Touched pour COMMON/OG/RARE, ProximityPrompt pour EPIC+)
- Stack sur tête joueur (CFrame offset Y+)
- Capacity tracking (default 1, max 5)
- Drop on death

**3. Deposit** (`IncomeSystem.lua`)
- Base interaction (ProximityPrompt)
- Income calculation par rarity
- DataStore save coins
- Clear carried BRs après deposit

**4. Shop** (`ShopSystem.lua`)
- Upgrades (carry capacity, spawn boost, auto-collect)
- Game Pass validation (VIP, Protection, Offline Vault)
- ProcessReceipt dans `MonetizationHandler.lua` ONLY

**5. Progression** (`BaseProgressionSystem.lua`)
- Base floors unlock (0→100k→200k→300k coins)
- Spots unlock (10 par floor)
- Visual feedback unlock

**6. Data** (`DataManager.lua`)
- DataStore GET/SET avec pcall
- Auto-save toutes 60s
- Session persistence
- Default values si GetAsync fail

### Folder structure
```
ServerScriptService/
├── Systems/
│   ├── SpawnSystem/
│   │   ├── BrainRotSpawner.lua
│   │   └── ChampCommunSpawner.lua
│   ├── CarrySystem.lua
│   ├── IncomeSystem.lua
│   ├── ShopSystem.lua
│   ├── BaseProgressionSystem.lua
│   └── DataManager.lua
├── Handlers/
│   ├── MonetizationHandler.lua
│   └── EventManager.lua
└── Config/
    └── GameConfig.lua  ← SEUL fichier modifié pour reskins

ServerStorage/
└── Brainrots/  ← JAMAIS dans Workspace/ReplicatedStorage (anti-copy)
    ├── COMMON/
    ├── OG/
    ├── RARE/
    ├── EPIC/
    ├── LEGENDARY/
    ├── MYTHIC/
    ├── SECRET/
    └── BRAINROT_GOD/
```

---

## Factory système

### Principe
```bash
DobiGames/
├── shared-lib/         ← Engine complet réutilisable (DO NOT MODIFY)
└── BrainRotFarm/       ← Jeu actif
    ├── src/
    └── GameConfig.lua  ← SEUL fichier modifié pour ce jeu
```

### Reskin workflow
**Modifier GameConfig.lua UNIQUEMENT:**
```lua
-- GameConfig.lua
return {
    GameName = "BrainRotFarm",  -- ou "Zoo", "Kitchen"...
    
    -- Renommer les collectibles
    CollectibleName = "BrainRot", -- ou "Animal", "Ingredient"
    CollectibleNamePlural = "BrainRots",
    
    -- Rarities (noms + couleurs + spawn rates)
    Rarities = {
        {Name = "COMMON", Color = Color3.fromRGB(200,200,200), Weight = 50},
        {Name = "OG", Color = Color3.fromRGB(100,150,255), Weight = 25},
        -- ...
    },
    
    -- Income par rarity
    IncomeMultipliers = {
        COMMON = 1,
        OG = 2,
        RARE = 5,
        -- ...
    }
}
```

**Tous les scripts lisent GameConfig.lua:**
```lua
local Config = require(game.ServerScriptService.Config.GameConfig)
print("Spawning", Config.CollectibleName) -- "BrainRot" ou "Animal"
```

### BrainRotFarm ship FIRST
Valider + publish BrainRotFarm AVANT de démarrer les reskins.
Évite bugs composés sur 8 jeux simultanés.

---

## Hard limits Roblox

### Légal (ban permanent si violé)
- ❌ NO Robux redistribution (raffles, player-to-player trades)
- ❌ NO gambling mechanics (loot boxes avec odds cachées)
- ✅ OK: Game Passes fixed price, Developer Products

### Technique
- ❌ HttpService bloqué pour fetch game data (private IDs, Roblox API)
- ❌ `/v1/games` endpoint = 404
- ❌ Physics instability si scaling >10x (prefer accessories pour visual growth)
- ✅ Mobile = 60%+ players (touch-first, no keyboard shortcuts required)

### Anti-copy protection
```lua
-- ✅ Assets in ServerStorage (invisible client)
local brainrots = game.ServerStorage.Brainrots

-- ❌ JAMAIS dans Workspace ou ReplicatedStorage
-- (copiable par exploiters)
```

---

## Monetization compliance

### Game Passes autorisés
```lua
-- VIP Pass (149 Robux) = carry capacity x2
-- Offline Vault (199 Robux) = income quand offline
-- Auto Collect (299 Robux) = auto-deposit proche base
-- Lucky Hour (35 Robux) = spawn rate x5 pendant 30min
-- Secret Reveal (25 Robux) = show SECRET spawn locations
-- Skip Tier (50 Robux) = unlock next base floor instantly
-- Protection (149 Robux) = garde BRs à la mort
```

### Admin Abuse events (compliance)
- ✅ Automatique toutes 2h + hebdo samedi 20h UTC
- ✅ Fully scripted, zero human intervention
- ✅ Discord webhook automatique via EventManager
- ❌ NO manual spawns par staff (= unfair advantage)

### ProcessReceipt
```lua
-- ✅ Dans MonetizationHandler.lua UNIQUEMENT
local MarketplaceService = game:GetService("MarketplaceService")

MarketplaceService.ProcessReceipt = function(receiptInfo)
    -- Validation server-side
    -- Grant rewards
    return Enum.ProductPurchaseDecision.PurchaseGranted
end
```

---

## Game design idle/farm (4 principes)

### 1. FEEDBACK LOOP SERRÉ
Chaque action = hit dopamine immédiat:
- Spawn rare: son unique + particle effect + notification UI
- Deposit réussi: "+coins" floating text + satisfaction sound
- Unlock slot: confetti + badge popup + leaderboard update

### 2. ÉCONOMIE VISIBLE
Zero opacité:
- Spawn zones colorées par rarity (vert COMMON, violet EPIC...)
- BRs stack visible sur tête joueur (CFrame Y+ offset)
- HUD minimaliste: coins + carry count only (pas de clutter)

### 3. ZERO FRICTION ONBOARDING
Apprendre en jouant:
- Flèches 3D spawn→base (TweenService pulse)
- Pas de tutorial pop-up (auto-skip après 10s si affiché)
- First deposit = unlock tutorial complete badge

### 4. SYSTÈMES SOCIAUX
Comparaison + partage:
- Leaderboard temps réel (richest players, visible spawn)
- Badge milestones (1M coins, 100 legendaries collected)
- Discord webhook Admin Abuse events (screenshot auto)

---

## Modularité progressive

### Refacto en steps
Quand un système devient trop complexe:

**Step 1:** Identifier point bloquant
- Ex: "BaseProgressionSystem bug car 'Floor 1' (simple espace — vérifié Studio mars 2026)"

**Step 2:** Proposer plan progressif
- Ex: "Step 1: extract floor unlock logic → FloorUnlocker.lua"
- Ex: "Step 2: centralize naming → NameValidator.lua"
- Ex: "Step 3: test chaque floor individuellement"

**Step 3:** Préserver conventions existantes
- Naming: PascalCase scripts, camelCase variables
- Folder structure: respect ServerScriptService/Systems/
- Comments: français uniquement

**Step 4:** Tester chaque step avant next
- Publish test place
- Validate 1 player slot complet
- Duplicate slot × 6 seulement après validation

---

## Debugging checklist

### Script ne fonctionne pas
```lua
-- 1. Vérifier Output pour errors
-- 2. Ajouter print() debug
print("DEBUG: Script started")
print("DEBUG: Variable value:", variable)

-- 3. Vérifier wait() → task.wait()
-- 4. Vérifier pcall() sur DataStore
-- 5. Vérifier server-side validation (pas client)
```

### BrainRots ne spawn pas
```lua
-- 1. Vérifier ServerStorage.Brainrots existe
-- 2. Vérifier rarity folders (COMMON, OG, RARE...)
-- 3. Vérifier weighted random logic
-- 4. Vérifier spawn zones (SpawnZone part existe)
-- 5. Print spawn attempts: print("Attempting spawn:", rarityName)
```

### Carry system ne fonctionne pas
```lua
-- 1. Vérifier Touched connection (mobile-compatible)
-- 2. Vérifier capacity tracking (default 1, max 5)
-- 3. Vérifier stack position (CFrame Y+ offset)
-- 4. Vérifier drop on death logic
-- 5. Print pickup attempts: print("Player picked up:", brName)
```

### DataStore errors
```lua
-- 1. Vérifier pcall() wrapper
-- 2. Vérifier default values si GetAsync fail
-- 3. Vérifier auto-save interval (60s recommended)
-- 4. Print save attempts: print("Saving data for:", player.Name)
-- 5. Vérifier Studio → Game Settings → Enable Studio Access to API Services
```

---

## Conventions naming

### Scripts
```lua
BrainRotSpawner.lua       -- PascalCase
CarrySystem.lua           -- PascalCase
BaseProgressionSystem.lua -- PascalCase
```

### Variables
```lua
local spawnRate = 5            -- camelCase
local maxCarryCapacity = 5     -- camelCase
local currentFloorUnlocked = 1 -- camelCase
```

### Functions
```lua
local function spawnBrainRot()  -- camelCase
local function calculateIncome() -- camelCase
local function unlockNextFloor() -- camelCase
```

### Services
```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
```

---

## Quick reference patterns

### Weighted random rarity
```lua
local rarities = {
    {Name = "COMMON", Weight = 50},
    {Name = "RARE", Weight = 25},
    {Name = "EPIC", Weight = 15},
    {Name = "LEGENDARY", Weight = 10}
}

local totalWeight = 0
for _, rarity in ipairs(rarities) do
    totalWeight = totalWeight + rarity.Weight
end

local rand = math.random(1, totalWeight)
local cumulative = 0

for _, rarity in ipairs(rarities) do
    cumulative = cumulative + rarity.Weight
    if rand <= cumulative then
        return rarity.Name
    end
end
```

### Clone BR from ServerStorage
```lua
local ServerStorage = game:GetService("ServerStorage")

local function spawnBrainRot(rarityName, position)
    local brFolder = ServerStorage.Brainrots:FindFirstChild(rarityName)
    if not brFolder then
        warn("Rarity folder not found:", rarityName)
        return
    end
    
    local brModels = brFolder:GetChildren()
    if #brModels == 0 then
        warn("No BrainRots in folder:", rarityName)
        return
    end
    
    local randomBR = brModels[math.random(1, #brModels)]
    local clone = randomBR:Clone()
    clone:SetPrimaryPartCFrame(CFrame.new(position))
    clone.Parent = workspace.ActiveBrainRots -- Folder temporaire
    
    return clone
end
```

### Auto-save DataStore
```lua
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local playerData = DataStoreService:GetDataStore("PlayerData")
local AUTO_SAVE_INTERVAL = 60 -- secondes

local function savePlayerData(player)
    local success, err = pcall(function()
        local data = {
            Coins = player.leaderstats.Coins.Value,
            CarryCapacity = player.CarryCapacity.Value,
            FloorUnlocked = player.FloorUnlocked.Value
        }
        playerData:SetAsync(player.UserId, data)
    end)
    
    if not success then
        warn("Failed to save data for", player.Name, ":", err)
    end
end

-- Auto-save loop
task.spawn(function()
    while true do
        task.wait(AUTO_SAVE_INTERVAL)
        for _, player in ipairs(Players:GetPlayers()) do
            savePlayerData(player)
        end
    end
end)
```

### ProximityPrompt deposit system
```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Dans chaque base, créer ProximityPrompt
local function setupBasePrompt(baseFolder)
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Déposer BrainRots"
    prompt.HoldDuration = 0.5
    prompt.MaxActivationDistance = 10
    prompt.Parent = baseFolder.PrimaryPart
    
    prompt.Triggered:Connect(function(player)
        -- Valider que le joueur a des BRs
        local carriedBRs = player:FindFirstChild("CarriedBRs")
        if not carriedBRs or #carriedBRs:GetChildren() == 0 then
            return
        end
        
        -- Calculer income
        local totalIncome = 0
        for _, br in ipairs(carriedBRs:GetChildren()) do
            local rarity = br:GetAttribute("Rarity")
            local multiplier = Config.IncomeMultipliers[rarity] or 1
            totalIncome = totalIncome + (10 * multiplier)
        end
        
        -- Sauvegarder coins
        player.leaderstats.Coins.Value = player.leaderstats.Coins.Value + totalIncome
        
        -- Clear carried BRs
        for _, br in ipairs(carriedBRs:GetChildren()) do
            br:Destroy()
        end
        
        -- Feedback visuel
        local billboardGui = Instance.new("BillboardGui")
        -- ... floating text "+X coins"
    end)
end
```

---

## Stratégie publication & croissance

### Phase 1 — Validation (Semaines 1-4)
**Objectif:** Valider que BrainRotFarm fonctionne techniquement et retient les joueurs.

**Actions:**
- Publish BrainRotFarm en public
- Inviter 20-50 joueurs via Discord/amis
- Tracker retention (temps moyen de jeu >5min = bon signe)
- Corriger bugs critiques sous 24h

**Success criteria:**
- ✅ 0 crash serveur sur 100+ sessions
- ✅ Retention moyenne >5min
- ✅ Like ratio >60%
- ✅ Au moins 1 achat Game Pass (validation monetization)

### Phase 2 — Itération (Semaines 5-8)
**Objectif:** Améliorer retention et monétisation.

**Actions:**
- Ajouter 1-2 features "waouh" (champignon progression, éruption base)
- Tester 2-3 prix Game Pass différents (A/B test)
- Recruter 2-3 créateurs TikTok joueurs (partage screens)
- Lancer Admin Abuse events réguliers

**Success criteria:**
- ✅ Retention moyenne >10min
- ✅ 500+ visites/semaine organiques
- ✅ 2-5 Game Pass vendus/semaine
- ✅ 1-2 vidéos TikTok avec >1k vues

### Phase 3 — Scale (Mois 3-6)
**Objectif:** Scaler ce qui marche.

**SI BrainRotFarm >5k visites/mois:**
- Lancer 1er reskin (Zoo ou Ocean)
- Investir dans ads Roblox (200-500 Robux/jour)
- Pipeline TikTok semi-auto

**SI BrainRotFarm <5k visites/mois:**
- NE PAS lancer reskins
- Pivoter concept (tester autre genre idle/farm)
- Analyser feedback joueurs (pourquoi pas de retention?)

**Success criteria mois 6:**
- ✅ 1 jeu >10k visites/mois OU 2-3 jeux >5k visites/mois chacun
- ✅ 50-200€/mois revenus récurrents
- ✅ Like ratio >70% sur jeu principal

---

## KPIs à suivre (par jeu)

| Métrique | Seuil OK | Seuil Bon | Fréquence |
|----------|----------|-----------|-----------|
| Visites/semaine | > 500 | > 2000 | Hebdo |
| Retention (temps moyen) | > 5 min | > 10 min | Hebdo |
| Like ratio | > 60% | > 75% | Hebdo |
| Game Pass sales/semaine | > 2 | > 10 | Hebdo |
| Robux/mois | > 5k | > 50k | Mensuel |

**Règle d'abandon:**
Si un jeu <500 visites/semaine après 1 mois de publication → abandonner ou pivoter drastiquement.

---

## Ressources et liens utiles

- **Roblox DevHub** : developer.roblox.com (API officielle)
- **Analytics** : roblox.com/develop → Mes Expériences → Stats
- **DevEx** (convertir Robux en €) : seuil minimum 30 000 Robux (~105€)
- **Rate DevEx mars 2026** : ~0.0035€/Robux

---

## FAQ rapide

**"Combien de temps avant les premiers Robux ?"**
→ 2-4 semaines après publication si lancement actif (Discord, TikTok)

**"Faut-il un compte Roblox Premium pour DevEx ?"**
→ Oui, Premium obligatoire + 30 000 Robux minimum sur le compte

**"Peut-on générer tout le code avec Claude ?"**
→ Oui à 80-90%. Le 10-20% restant = ajustements visuels dans Studio

**"Combien coûte un Roblox Group ?"**
→ 100 Robux (~0.35€). Indispensable pour centraliser les revenus multi-jeux

**"Brain Rot idle/farm c'est saturé ?"**
→ Obbys Brain Rot = OUI très saturé. Idle/farm Brain Rot = NON, encore peu exploré.
BrainRotFarm a différenciation suffisante (ChampCommun events, carry system complexe, base progression).

**"Quel genre rapporte le plus en 2026 ?"**
→ Idle/farm games (Grow a Garden) et collection games (Steal a Brainrot) ont les meilleurs taux de monétisation.
Social hangouts (Brookhaven) ont le plus de visites mais monétisation plus difficile.

**"Quel revenu réaliste les 6 premiers mois ?"**
→ Conservateur: 1 jeu >5k visites/mois = ~50-200€/mois.
Optimiste: 1 hit >50k visites = ~500-2000€/mois.
Focus: valider 1 jeu rentable avant scaler.

**"Les reskins marchent vraiment ?"**
→ OUI si le core engine est validé d'abord. C'est pourquoi BrainRotFarm doit ship et prouver sa rentabilité AVANT de lancer Zoo/Kitchen/etc.

---

## Limites de ce document

Ce CLAUDE.md contient les **invariants techniques et stratégiques pour BrainRotFarm**.

**Il NE contient PAS:**
- Templates génériques (ObbyMaster, IdleMaster) → voir docs/TEMPLATES.md si besoin
- Roadmap détaillée 6 mois → voir docs/STRATEGY.md
- Architecture Workspace détaillée BrainRotFarm → dans thread actif uniquement
- Scripts status (✅ done / ❌ pending) → dans thread actif uniquement
- Bugs spécifiques en cours → dans thread actif uniquement

**Pour les autres jeux (LavaTower, BrainRotKong):**
Créer leur propre CLAUDE.md dans leur dossier respectif.

---

**Version:** 2.0 — Mars 2026 (nettoyée)
**Usage:** @CLAUDE.md dans chaque prompt Claude Code pour cohérence maximale
**Maintenance:** Supprimer cette ligne après chaque session pour éviter drift de version
