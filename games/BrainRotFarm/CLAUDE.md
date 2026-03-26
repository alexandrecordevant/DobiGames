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
setup-dobigames.sh
├── _template/  ← Engine complet réutilisable
│   ├── src/
│   └── Config/GameConfig.lua
└── BrainRotFarm/  ← Reskin #1
└── Zoo/           ← Reskin #2
└── Kitchen/       ← Reskin #3
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

**Tous les autres scripts lisent GameConfig.lua:**
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
- Ex: "BaseProgressionSystem bug car 'Floor  1' a double space"

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

---

## Limites de ce document

Ce CONTEXT.md contient les **invariants techniques et stratégiques**.

**Il NE contient PAS:**
- Architecture détaillée BrainRotFarm (Workspace/Bases structure)
- Scripts status (✅ done / ❌ pending)
- Prix Game Pass actuels
- Bugs spécifiques en cours
- Features temporaires (TikTok pipeline, etc.)

→ Ces infos appartiennent au **thread actif** dans Claude.ai ou dans des notes sprint.

---

**Version:** 1.0 — Mars 2026
**Usage:** @CONTEXT.md dans chaque prompt Claude Code pour cohérence maximale

---
name: roblox-cashgen
description: Expert Roblox cash generation skill. Use this skill for ANY question related to Roblox game development, Lua code generation, monetization strategy, Robux optimization, game publishing, trending genres (Brain Rot, Idle/AFK, social hangouts), Roblox algorithm, scaling multiple games, or reaching revenue goals via Roblox. Trigger whenever the user mentions Roblox, Lua, obby, idle games, simulator, Brain Rot, Robux, game dev income, or wants to build/launch/monetize a Roblox game. Also trigger for any revenue strategy question in the context of this project, market saturation analysis, or genre selection.
---
 
# Roblox Cash Generation Expert
 
## Profil Utilisateur
 
- **Dev expérimenté** : web/backend, automatisation IA, MVP rapide
- **Objectif** : 10 000 €/mois en 6 mois via Roblox
- **Contraintes** : temps limité, déléguer max à l'IA, maintenance minimale
- **Budget initial** : < 100€
- **Approche** : volume de jeux + templates réutilisables + Claude pour le code Lua
 
---
 
## État du Marché Roblox (Mars 2026)
 
### ⚠️ ALERTE SATURATION : Brain Rot Obby
 
**Le marché Brain Rot obby est SATURÉ en mars 2026.**
 
- Steal a Brainrot : 47,4 milliards de visites, 23,4M joueurs concurrents (sept 2025)
- Des centaines de clones Brain Rot publiés chaque semaine
- Compétition féroce sur CTR/icônes/titres = difficile de percer
- "Tous les top games Roblox sont maintenant des jeux brainrot" (créateur TikTok, fin 2025)
 
**⚠️ Ne PAS miser uniquement sur Brain Rot obby.**
 
### 🔥 Genres en croissance (Mars 2026)
 
| Genre | Exemple phare | Pourquoi ça marche | Complexité IA |
|-------|---------------|-------------------|---------------|
| **Idle/AFK Simulator** | Grow a Garden (21B+ visites, lancé mars 2026) | Gameplay cozy, sessions courtes, dopamine régulière | 🟢 Faible |
| **Social Hangouts** | Brookhaven RP (69B visites) | Expression d'identité, avatar customization, 0 objectif | 🟡 Moyenne |
| **Collection + Base Building** | Steal a Brainrot, Pet Simulator 99 | Économie de rareté, trading, événements limités | 🟡 Moyenne |
| **Skill-based Competitive** | Tower of Hell, RIVALS (FPS) | Pas de P2W, mastery pure, leaderboards | 🟢 Faible |
 
### Tendances Roblox 2026 (données récentes)
 
- **Sessions courtes** : joueurs préfèrent entrer/sortir sans friction (idle games dominent)
- **Identity expression** : avatars, poses, émotes, hangouts sociaux = spikes de découverte
- **Low-spec optimization** : jeux qui tournent bien partout = meilleure rétention
- **Progression profonde** : Blox Fruits prouve que les joueurs s'engagent sur systèmes complexes si récompenses visibles
 
---
 
## Stratégie Core Révisée (Mars 2026)
 
### Modèle recommandé : Portfolio Diversifié
 
**Ne PAS faire** : 10 obbys Brain Rot identiques (marché saturé)
 
**FAIRE** : 3-5 jeux bien différenciés, chacun ciblant un genre différent
 
#### Portfolio optimal (6 mois)
 
```
Mois 1-2 : 1 Idle/AFK Game (template maître)
  └─ Ex: "Grow a Pet" / "Farm Simulator" / "Collect Crystals"
  └─ Tech: système d'idle earnings, auto-clicker, prestige loops
 
Mois 2-3 : 1 Social Hangout (si compétences building)
  └─ Ex: "Vibe House" / "Roleplay City"
  └─ Tech: customization poussée, zones photos, émotes
 
Mois 3-4 : 1 Skill-based Competitive
  └─ Ex: Obby challenge (NON Brain Rot, thème original), Tower climber
  └─ Tech: leaderboards, no-checkpoint mode, speedrun timers
 
Mois 4-5 : 1 Collection Game (peut être Brain Rot si bien exécuté)
  └─ Ex: "Collect [X]" avec trading et événements
  └─ Tech: rareté, crafting, limited-time drops
 
Mois 5-6 : Doubler sur le(s) jeu(x) qui performent
  └─ Séquelles, variantes, updates majeures
```
 
**Objectif par jeu** : 1000-5000 Robux/mois → 5 jeux = 5k-25k Robux/mois = 175-875€/mois
Pour atteindre 10k€/mois = ~2,8M Robux/mois → nécessite 1-2 hits majeurs (>50k visites/mois) + plusieurs jeux stables
 
### Pourquoi diversifier ?
 
- Réduction du risque : si Brain Rot s'effondre, tu as d'autres revenus
- Apprentissage multi-genre : tu identifies tes forces (obby? idle? social?)
- Algo boost : Roblox favorise les créateurs qui innovent vs clone
- Test de marché : tu découvres quel genre TU peux le mieux exécuter
 
---
 
## 4 Principes Impératifs de Game Design
 
> Ces principes s'appliquent à CHAQUE jeu généré, sans exception.
> Les vérifier comme une checklist avant tout publish.
 
### 1. Compréhension Instantanée
- Le concept du jeu se résume en **1 phrase** — si tu ne peux pas, le jeu est trop complexe
- Exemples valides : "Saute sur des plateformes pour atteindre la fin" / "Fais pousser des plantes pour gagner de l'argent" / "Échappe au Skibidi Toilet géant"
- Exemple invalide : "Explore le monde, collecte des objets et bats des ennemis"
- Le titre du jeu = cette phrase raccourcie au maximum
- **En code** : premier checkpoint/action visible dès le spawn, chemin évident, zéro tutoriel
 
### 2. Dopamine Régulière
- **Récompense visible toutes les 30-60 secondes** : 
  - Obbys : son + particules à chaque checkpoint
  - Idle games : notification "+1000 coins!" régulière, unlock de nouveau contenu
  - Collection games : animation satisfaisante à chaque nouveau "brainrot" obtenu
- Progression toujours affichée ("Stage 7/30" / "Level 15" / "1,234 coins")
- **En code** : SoundService + ParticleEmitter + GUI notifications
 
### 3. Privilégier la Clarté
- UI minimaliste : 1-2 éléments HUD max à l'écran
- Obstacles/objectifs visuellement distincts (contraste de couleur fort)
- Pas de texte superflu, pas d'effets qui cachent le gameplay
- **En code** : GUI épurée, BackgroundTransparency élevée, TextSize lisible mobile
 
### 4. Le Social
- Leaderboard visible avec les scores/progression des autres joueurs
- Badge à débloquer = partage naturel sur profil Roblox
- Message/notification quand un ami dépasse ton score
- **En code** : BadgeService + leaderboard global DataStore + notifications in-game
 
---
 
## Template de Jeu par Genre
 
### Genre 1 : Idle/AFK Simulator (🔥 TENDANCE 2026)
 
**Pourquoi c'est hot** : Grow a Garden a atteint 21B+ visites en quelques mois (lancé mars 2026), record de vitesse pour atteindre 1B de visites (33 jours)
 
#### Concept Core
1. Joueur plante/achète des générateurs passifs (arbres, usines, animaux, cristaux...)
2. Générateurs produisent de la monnaie au fil du temps (même offline)
3. Monnaie sert à acheter de meilleurs générateurs
4. Loop infini : upgrade → earn faster → unlock new tiers → prestige/reset pour bonus
 
#### Mécanique technique Lua
```lua
-- Générateur de base (ModuleScript)
local Generator = {}
Generator.__index = Generator
 
function Generator.new(type, baseRate, cost)
    local self = setmetatable({}, Generator)
    self.Type = type
    self.BaseRate = baseRate  -- coins par seconde
    self.Cost = cost
    self.Level = 1
    return self
end
 
function Generator:Upgrade()
    self.Level = self.Level + 1
    self.Cost = self.Cost * 1.5  -- coût croissant
end
 
function Generator:GetCurrentRate()
    return self.BaseRate * self.Level
end
 
-- Système d'idle earning (ServerScript)
-- Sauvegarde last login time, calcule earnings offline au retour
```
 
#### Monétisation Idle Games
- **2x Earnings Game Pass** : 149 Robux (super populaire sur idle games)
- **Auto-Collector** : 99 Robux (collecter les coins automatiquement)
- **Exclusive Generator** : 299 Robux (générateur unique 5x plus rentable)
- **Developer Product "Boost 1hr"** : 49 Robux (earnings x3 pendant 1h, répétable)
 
#### Checklist Idle Game
```
[ ] Générateurs ont un feedback visuel satisfaisant (animation quand ils produisent)
[ ] Notification "+X coins!" apparaît régulièrement
[ ] Système de prestige qui donne envie de restart (bonus permanent)
[ ] Leaderboard "Total Coins Earned All-Time"
[ ] Offline earnings fonctionnent (max 24h d'absence)
```
 
#### Timeline de dev Idle Game avec Claude
**Jour 1 (3h)** : Claude génère le GeneratorSystem.lua + DataStore + GUI
**Jour 2 (3h)** : Placement visuel des générateurs dans Studio + ajout animations
**Jour 3 (2h)** : Monétisation (Game Pass handler) + icône/description + publish
 
**Difficulté IA** : 🟢 Faible — système très formulaire, parfait pour génération code
 
---
 
### Genre 2 : Obby (Skill-based, NON Brain Rot)
 
**Mise à jour 2026** : Le marché Brain Rot obby est saturé. Si tu fais un obby, choisis un thème ORIGINAL.
 
#### Thèmes qui marchent encore (mars 2026)
- **Escape [Lieu Spécifique]** : Escape Prison, Escape School, Escape Carnival
- **Tower Climb** : Tower of Hell style, mais avec thème unique (cyberpunk, underwater, space)
- **Story-based Obby** : narration entre chaque niveau (ex: sauver un personnage)
- **Nostalgia Obby** : référence années 2000-2010 (pas Brain Rot = différenciation)
 
#### Éviter absolument
- ❌ "[BRAIN ROT] Obby Skibidi ☠️" — marché saturé, 0 chance de percer
- ❌ Tout ce qui contient "Skibidi", "Fanum Tax", "Rizz" dans le titre (sauf si tu as une twist unique)
 
Le reste des principes obby (checkpoints, VFX, monétisation) du skill original reste valide.
 
---
 
### Genre 3 : Collection + Trading Game
 
**Pourquoi c'est viable** : Steal a Brainrot prouve le modèle (47B+ visites), mais tu peux appliquer à d'autres thèmes
 
#### Concept Core
1. Joueur possède une base avec des "collectibles" qui génèrent de l'argent
2. Collectibles ont des raretés (Common → Mythical)
3. Joueurs peuvent voler/trader les collectibles des autres
4. Système de crafting : combiner X collectibles = nouveau rare
 
#### Thèmes alternatifs à Brain Rot
- Dragons / Creatures mythologiques
- Voitures de luxe / Supercars
- Gemmes / Cristaux magiques
- Pets futuristes / Robots
 
#### Mécanique clé : Rareté + Événements
```lua
-- Système de rareté (identique à Steal a Brainrot)
local Rarities = {
    Common = {Weight = 60, MoneyPerSecond = 10},
    Uncommon = {Weight = 25, MoneyPerSecond = 50},
    Rare = {Weight = 10, MoneyPerSecond = 200},
    Epic = {Weight = 4, MoneyPerSecond = 1000},
    Legendary = {Weight = 0.9, MoneyPerSecond = 5000},
    Mythical = {Weight = 0.1, MoneyPerSecond = 25000}
}
 
-- Événement limité (ex: "Halloween Special Brainrot" disponible 3 jours)
-- = FOMO énorme, boost de joueurs massif
```
 
---
 
### Genre 4 : Social Hangout (si compétences building)
 
**Données 2026** : Brookhaven RP = 69B visites, jeu #1 all-time sur Roblox
 
**Pourquoi c'est difficile pour toi** : Nécessite du level design / building manuel (pas juste du code)
 
**Si tu veux quand même essayer** :
- Utilise Toolbox Roblox pour assets gratuits (maisons, meubles, véhicules)
- Focus sur customization avatar + poses/émotes
- Zones "photo spots" pour selfies = viralité TikTok
- Pas d'objectifs, juste un monde libre à explorer
 
**Monétisation Social Hangout** :
- Game Pass "VIP House" : 199 Robux (maison exclusive)
- Game Pass "All Vehicles" : 149 Robux
- Developer Product "Furniture Pack" : 99 Robux répétable
 
---
 
## Checklist Game Design (avant chaque publish)
```
[ ] Je comprends quoi faire en 5 secondes en regardant le spawn ?
[ ] Il y a un son/effet satisfaisant à chaque checkpoint ?
[ ] L'UI ne surcharge pas l'écran ?
[ ] Le leaderboard est visible dès le lancement ?
```
 
---
 
## Monétisation Roblox — Playbook
 
### Structure de monétisation recommandée par jeu
 
```
Jeu gratuit (TOUJOURS)
├── Game Pass "VIP" — 99 Robux (~1€)
│   └── Vitesse x2, effets cosmétiques, badge exclusif
├── Game Pass "Double XP" — 49 Robux
│   └── XP x2 pour débloquer des skins
├── Developer Product "Skip Level" — 25 Robux
│   └── Passer un niveau difficile (achat répétable)
└── Developer Product "Revive" — 15 Robux
    └── Continuer après une mort (achat répétable)
```
 
### Taux de conversion réalistes
- 1000 visites → ~5-15 achats Game Pass (0.5-1.5%)
- Revenu moyen par visite active : 0.03–0.08 Robux
- Seuil rentable : 10 000 visites/mois par jeu
 
### Taux de change Robux → €
- 1000 Robux = ~3.50€ (taux DevEx standard)
- Pour 10k€/mois = ~2 857 000 Robux/mois
- Avec 20 jeux à 10k visites/mois chacun = ~200k visites totales
- Réaliste en mois 4-6 avec bonne exécution
 
---
 
## Algorithme Roblox — Comment Fonctionner
 
### Facteurs de ranking
1. **CTR (Click-Through Rate)** — icône + titre = priorité absolue
2. **Retention** — temps moyen en jeu (viser > 8 minutes)
3. **Likes ratio** — viser > 70% positifs
4. **Sessions actives** — boost au lancement (inviter des amis, alt accounts)
5. **Fréquence de mise à jour** — publier une update = boost d'algo
 
### Stratégie de lancement
```
Jour 1 : Publier le jeu
Jour 2 : 10-20 sessions actives simultanées (amis, groupes Discord Roblox)
Jour 3-7 : Partager sur TikTok/YouTube Shorts avec gameplay Brain Rot
Semaine 2 : Publier une "update" même mineure pour regain d'algo
```
 
### Icônes et titres qui convertissent
- Titre : "[BRAIN ROT] Obby Impossible ☠️ SKIBIDI" 
- Icône : personnage Brain Rot coloré, fond flashy, chiffre "100 niveaux"
- Thumbnail : screenshot gameplay avec overlay texte dramatique
 
---
 
## Génération de Code Lua avec Claude
 
### Template de prompt pour générer un obby complet
 
```
Tu es expert Roblox Studio et Lua.
Génère un script ServerScript complet pour un obby avec :
- [X] niveaux de difficulté croissante
- Checkpoint system (SpawnLocation par niveau)
- Leaderboard avec temps de completion
- Système de Game Pass VIP (vitesse x2)
- Developer Product "Skip Level" (25 Robux)
- Effets visuels Brain Rot : couleurs néon, sons rigolos
- Anti-exploit basique
Format : Script unique, commentaires en français, prêt à coller dans ServerScriptService
```
 
### Modules Lua réutilisables à générer une fois
 
| Module | Utilité | Priorité |
|--------|---------|----------|
| GamePassService | Vérifier/donner avantages Game Pass | 🔴 Critique |
| CheckpointManager | Sauvegarder progression joueur | 🔴 Critique |
| LeaderboardService | Afficher scores/temps | 🟡 Important |
| VFXManager | Effets visuels (particules, sons) | 🟢 Nice-to-have |
| DataStore | Sauvegarder données entre sessions | 🟡 Important |
 
### Anti-patterns à éviter (demander à Claude de les éviter)
- Loops infinis côté client
- RemoteEvents non sécurisés (exploit risk)
- DataStore sans pcall (crash si Roblox down)
 
---
 
## Pipeline de Production IA
 
### Workflow complet pour 1 jeu en 3 jours
 
**Jour 1 — Structure (2h)**
```
1. Claude génère le ServerScript principal (obby logic + checkpoints)
2. Claude génère le GamePassHandler
3. Importer dans Roblox Studio, tester en solo
```
 
**Jour 2 — Design (2h)**
```
1. Toolbox Roblox : importer assets Brain Rot gratuits
2. Claude génère le script de placement automatique des obstacles
3. Ajuster les niveaux visuellement dans Studio
```
 
**Jour 3 — Lancement (1h)**
```
1. Claude génère description du jeu + tags optimisés
2. Midjourney/DALL-E génère l'icône (prompt fourni ci-dessous)
3. Publier + partager sur Discord Roblox dev
```
 
### Prompt icône pour IA image
```
Roblox game icon, Brain Rot style, cartoon character with googly eyes
and distorted face, neon colors, obstacle course in background,
"OBBY" text, high contrast, mobile game icon style, 512x512
```
 
---
 
## Scaling — Portfolio Diversifié (Stratégie 2026)
 
### Mois 1-2 : Template Master + Premier Hit
- **1 Idle/AFK Game complet**, testé, monétisé (template maître)
- Tous les scripts modulaires réutilisables
- Checklist de lancement validée
- **Objectif** : identifier si l'idle genre fonctionne pour toi
 
### Mois 2-3 : Deuxième Genre
- **1 Obby skill-based OU 1 Collection Game**
- Réutiliser les modules communs (DataStore, GamePass, Leaderboard)
- Changer : genre, gameplay loop, thème visuel
- **Objectif** : 2 jeux actifs, 2 genres testés
 
### Mois 3-4 : Troisième Genre + Analyse
- **1 nouveau jeu dans le genre restant**
- Analyser les KPIs des 3 jeux :
  - Lequel a le meilleur CTR ?
  - Lequel a la meilleure retention (temps moyen) ?
  - Lequel monétise le mieux ?
- **Objectif** : identifier ton "genre gagnant"
 
### Mois 4-5 : Double Down
- **NE PAS lancer de nouveaux jeux random**
- Prendre le jeu #1 en performance
- Créer 1-2 variantes/séquelles de ce jeu
- Publier une grosse update sur le jeu original
- **Objectif** : scaler ce qui marche
 
### Mois 5-6 : Optimisation Revenus
- Focus sur les 2-3 meilleurs jeux uniquement
- Ajouter :
  - Merch Roblox (t-shirts du jeu) pour revenus passifs
  - Premium Payouts optimization
  - Événements limités (FOMO = boost de ventes)
- Abandonner les jeux < 500 visites/semaine après 1 mois
- **Objectif** : maximiser $/visite, pas volume de jeux
 
### Règle d'Or 2026
 
**Mieux vaut 3 jeux différenciés avec 10k visites/mois chacun**
**que 10 clones identiques avec 2k visites/mois chacun**
 
Pourquoi ?
- Algo Roblox pénalise les créateurs "spam" (beaucoup de jeux similaires)
- Retention meilleure sur jeux uniques = algo boost
- Maintenance : 3 jeux = gérable, 10 jeux = enfer
- Apprentissage : tu deviens expert d'un genre vs médiocre sur tout
 
---
 
## KPIs à Suivre (par jeu)
 
| Métrique | Seuil OK | Seuil Bon | Fréquence |
|----------|----------|-----------|-----------|
| Visites/semaine par jeu | > 500 | > 2000 | Hebdo |
| Retention (temps moyen) | > 5 min | > 10 min | Hebdo |
| Like ratio | > 60% | > 75% | Hebdo |
| Robux/mois total | > 50k | > 200k | Mensuel |
| Jeux actifs (>500 vis/sem) | > 5 | > 15 | Mensuel |
 
---
 
## Ressources et Liens Utiles
 
- **Roblox DevHub** : developer.roblox.com (API officielle)
- **Toolbox assets Brain Rot** : chercher "UGC Brain Rot" dans Roblox Studio
- **Analytics** : roblox.com/develop → Mes Expériences → Stats
- **DevEx** (convertir Robux en €) : seuil minimum 50 000 Robux
 
---
 
## Templates de Référence
 
### ObbyMaster — Template Obby (généré mars 2026)
 
Template modulaire validé, 6 fichiers Lua prêts à coller dans Studio.
**Cloner un jeu = modifier `Config.lua` uniquement + remplacer obstacles.**
 
#### Structure complète
 
```
ObbyMaster/
├── ReplicatedStorage/Modules/Config.lua       ← ModuleScript — cerveau du jeu
├── ServerScriptService/Main.server.lua         ← Script — boot + création RemoteEvents
├── ServerScriptService/CheckpointManager.lua   ← ModuleScript — stages + DataStore + badge
├── ServerScriptService/GamePassHandler.lua     ← ModuleScript — VIP + Skip + Revive
├── ServerScriptService/LeaderboardService.lua  ← ModuleScript — top 10 global
└── StarterPlayerScripts/HUDController.client.lua ← LocalScript — HUD + VFX + shop
```
 
#### RemoteEvents créés automatiquement par Main.server.lua
`StageUpdate` · `LeaderboardUpdate` · `AppliquerVIP` · `AcheterVIP` · `AcheterSkip` · `AcheterRevive` · `SkipStage` · `NotifAmi`
 
#### Règles d'architecture impératives
- `ProcessReceipt` toujours dans `GamePassHandler` — jamais ailleurs
- Tous les DataStore calls enveloppés dans `pcall()`
- Validation Skip Stage **côté serveur** uniquement
- `task.wait()` partout — jamais `wait()`
- Checkpoints = `SpawnLocation` nommées `Stage_1` à `Stage_N` dans `workspace.Checkpoints`
 
#### Config.lua — paramètres clés à changer par jeu
```lua
NomDuJeu, TotalStages,
GamePassVIP.Id, ProduitSkipStage.Id, ProduitRevive.Id,
BadgeCompletionId,
CouleurPrimaire, CouleurSecondaire,   -- thème néon
SonCheckpoint, SonFinObby             -- IDs audio Roblox
```
 
#### Monétisation embarquée
| Produit | Prix | Type |
|---|---|---|
| VIP (vitesse x1.8) | 99 R$ | Game Pass |
| Skip Stage | 25 R$ | Developer Product (répétable) |
| Revive | 15 R$ | Developer Product (répétable) |
 
#### Checklist installation rapide
```
[ ] ModuleScript Config dans ReplicatedStorage/Modules
[ ] Script Main + 3 ModuleScripts dans ServerScriptService
[ ] LocalScript HUDController dans StarterPlayerScripts
[ ] Folder "Checkpoints" dans Workspace avec Stage_1..Stage_N SpawnLocations
[ ] RespawnTime = 0 dans Workspace properties
[ ] IDs Game Pass/Badge mis à jour dans Config.lua
```
 
---
 
### IdleMaster — Template Idle/AFK Game (🆕 Mars 2026)
 
Template pour idle/simulator games type Grow a Garden. Code généré par Claude, prêt à l'emploi.
 
#### Structure complète
 
```
IdleMaster/
├── ReplicatedStorage/
│   ├── Modules/Config.lua              ← Configuration jeu + générateurs
│   └── Modules/GeneratorData.lua       ← Stats de chaque type de générateur
├── ServerScriptService/
│   ├── Main.server.lua                 ← Boot + RemoteEvents
│   ├── GeneratorSystem.lua             ← Système de générateurs + idle earnings
│   ├── GamePassHandler.lua             ← 2x Earnings + Auto-Collector + Boost
│   ├── PrestigeSystem.lua              ← Reset avec bonus permanent
│   └── DataStoreManager.lua            ← Sauvegarde progression + offline time
└── StarterPlayerScripts/
    └── IdleGUI.client.lua              ← GUI coins + shop + notifications
```
 
#### Générateurs types (exemples)
 
```lua
-- Dans GeneratorData.lua
local Generators = {
    Tree = {
        BaseRate = 10,          -- coins/seconde
        BaseCost = 100,
        UnlockLevel = 1,
        Model = "rbxassetid://..."  -- ID du modèle dans Toolbox
    },
    Crystal = {
        BaseRate = 50,
        BaseCost = 1000,
        UnlockLevel = 5,
        Model = "rbxassetid://..."
    },
    Factory = {
        BaseRate = 500,
        BaseCost = 25000,
        UnlockLevel = 15,
        Model = "rbxassetid://..."
    }
}
```
 
#### Système d'offline earnings
 
```lua
-- Dans GeneratorSystem.lua
function CalculateOfflineEarnings(player)
    local data = DataStore:GetAsync(player.UserId)
    local lastLogin = data.LastLogin or os.time()
    local currentTime = os.time()
    local secondsOffline = currentTime - lastLogin
    
    -- Max 24h d'offline earnings
    secondsOffline = math.min(secondsOffline, 86400)
    
    local totalRate = 0
    for _, gen in pairs(data.Generators) do
        totalRate = totalRate + gen:GetCurrentRate()
    end
    
    return totalRate * secondsOffline
end
```
 
#### Monétisation Idle Game
 
| Produit | Prix | Type | Impact |
|---|---|---|---|
| 2x Earnings | 149 R$ | Game Pass | Double tous les gains (permanent) |
| Auto-Collector | 99 R$ | Game Pass | Collecte coins auto toutes les 5s |
| Exclusive Generator | 299 R$ | Game Pass | Générateur 5x plus rentable |
| 1hr Boost | 49 R$ | Dev Product | Gains x3 pendant 1h (répétable) |
 
#### Checklist installation rapide
 
```
[ ] Config + GeneratorData dans ReplicatedStorage/Modules
[ ] 5 ModuleScripts dans ServerScriptService
[ ] LocalScript IdleGUI dans StarterPlayerScripts
[ ] Folder "Generators" dans Workspace pour placer les modèles visuels
[ ] IDs Game Pass mis à jour dans Config.lua
[ ] Tester offline earnings : join → wait 5 min → rejoin → vérifier coins
```
 
#### Prompt Claude pour générer IdleMaster
 
```
Tu es expert Roblox Studio et Lua.
Génère un système complet d'Idle/AFK Game avec :
- 5 types de générateurs (Tree, Crystal, Factory, Robot, Dragon) avec upgrade system
- Système d'offline earnings (max 24h) sauvegardé dans DataStore
- Système de prestige (reset pour bonus x2 permanent)
- Game Pass "2x Earnings" + "Auto-Collector"
- Developer Product "Boost 1hr" (gains x3, 49 Robux)
- GUI avec compteur de coins, shop de générateurs, notifications "+X coins!"
- Effets visuels : particules quand générateur produit, son satisfaisant
- Anti-exploit : validation serveur pour tous les achats
Format : Scripts séparés par fichier, commentaires en français, prêt à coller dans Studio
```
 
---
 
## Réponses Rapides aux Questions Fréquentes
 
**"Combien de temps avant les premiers Robux ?"**
→ 2-4 semaines après publication si lancement actif (Discord, TikTok)
 
**"Faut-il un compte Roblox Premium pour DevEx ?"**
→ Oui, Premium obligatoire + 30 000 Robux minimum sur le compte
 
**"Peut-on générer tout le code avec Claude ?"**
→ Oui à 80-90%. Le 10-20% restant = ajustements visuels dans Studio
 
**"Combien coûte un Roblox Group ?"**
→ 100 Robux (~0.35€). Indispensable pour centraliser les revenus multi-jeux
 
**"Brain Rot c'est encore tendance en 2026 ?"**
→ OUI mais marché SATURÉ. Steal a Brainrot domine avec 47B+ visites. Si tu fais du Brain Rot, il faut un twist unique ou une exécution exceptionnelle. Recommandation : explore idle games ou collection games avec thèmes alternatifs.
 
**"Quel genre rapporte le plus ?"**
→ Données mars 2026 : Idle/AFK games (Grow a Garden) et collection games (Steal a Brainrot) ont les meilleurs taux de monétisation. Social hangouts (Brookhaven) ont le plus de visites mais monétisation plus difficile.
 
**"Combien de jeux faut-il pour atteindre 10k€/mois ?"**
→ Réaliste : 1-2 hits (>50k visites/mois, ~500k-1M Robux/mois chacun) + 3-5 jeux stables (5-10k visites/mois). Total = ~2,8M Robux/mois = 10k€. Miser sur qualité > quantité.
 
**"Les obbys marchent encore ?"**
→ OUI si thème original. Tower of Hell reste dans le top 10. Évite les titres "[BRAIN ROT] Obby Impossible ☠️" saturés. Préfère "Escape [Lieu Unique]" ou tower climber avec thème fort.
 
**"Idle games c'est facile à faire ?"**
→ Techniquement OUI (code très formulaire = parfait pour IA). Grow a Garden prouve qu'un idle game bien exécuté peut exploser. Claude peut générer 90% du code.