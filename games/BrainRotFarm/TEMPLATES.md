# DobiGames — Templates de Référence

> Templates génériques réutilisables pour différents genres de jeux Roblox.
> Ces templates ne sont PAS spécifiques à BrainRotFarm.

\---

### RemoteEvents créés automatiquement par Main.server.lua

`StageUpdate` · `LeaderboardUpdate` · `AppliquerVIP` · `AcheterVIP` · `AcheterSkip` · `AcheterRevive` · `SkipStage` · `NotifAmi`

### Règles d'architecture impératives

* `ProcessReceipt` toujours dans `GamePassHandler` — jamais ailleurs
* Tous les DataStore calls enveloppés dans `pcall()`
* Validation Skip Stage **côté serveur** uniquement
* `task.wait()` partout — jamais `wait()`
* Checkpoints = `SpawnLocation` nommées `Stage\_1` à `Stage\_N` dans `workspace.Checkpoints`

### Config.lua — paramètres clés à changer par jeu

```lua
NomDuJeu, TotalStages,
GamePassVIP.Id, ProduitSkipStage.Id, ProduitRevive.Id,
BadgeCompletionId,
CouleurPrimaire, CouleurSecondaire,   -- thème néon
SonCheckpoint, SonFinObby             -- IDs audio Roblox
```

### Monétisation embarquée

|Produit|Prix|Type|
|-|-|-|
|VIP (vitesse x1.8)|99 R$|Game Pass|
|Skip Stage|25 R$|Developer Product (répétable)|
|Revive|15 R$|Developer Product (répétable)|

### Checklist installation rapide

```
\[ ] ModuleScript Config dans ReplicatedStorage/Modules
\[ ] Script Main + 3 ModuleScripts dans ServerScriptService
\[ ] LocalScript HUDController dans StarterPlayerScripts
\[ ] Folder "Checkpoints" dans Workspace avec Stage\_1..Stage\_N SpawnLocations
\[ ] RespawnTime = 0 dans Workspace properties
\[ ] IDs Game Pass/Badge mis à jour dans Config.lua
```

\---

## IdleMaster — Template Idle/AFK Game (mars 2026)

**Note:** Ce template est générique. BrainRotFarm utilise une architecture idle/farm différente.
Consulter CLAUDE.md de BrainRotFarm pour l'architecture spécifique.

### Structure complète

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

### Générateurs types (exemples)

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

### Système d'offline earnings

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
    for \_, gen in pairs(data.Generators) do
        totalRate = totalRate + gen:GetCurrentRate()
    end
    
    return totalRate \* secondsOffline
end
```

### Monétisation Idle Game

|Produit|Prix|Type|Impact|
|-|-|-|-|
|2x Earnings|149 R$|Game Pass|Double tous les gains (permanent)|
|Auto-Collector|99 R$|Game Pass|Collecte coins auto toutes les 5s|
|Exclusive Generator|299 R$|Game Pass|Générateur 5x plus rentable|
|1hr Boost|49 R$|Dev Product|Gains x3 pendant 1h (répétable)|

### Checklist installation rapide

```
\[ ] Config + GeneratorData dans ReplicatedStorage/Modules
\[ ] 5 ModuleScripts dans ServerScriptService
\[ ] LocalScript IdleGUI dans StarterPlayerScripts
\[ ] Folder "Generators" dans Workspace pour placer les modèles visuels
\[ ] IDs Game Pass mis à jour dans Config.lua
\[ ] Tester offline earnings : join → wait 5 min → rejoin → vérifier coins
```

### Prompt Claude pour générer IdleMaster

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

\---

## Quand utiliser ces templates?

**IdleMaster:**

* Référence pour offline earnings systems
* Inspiration pour générateurs passifs (différent de carry/farm actif)
* Comparaison prestige systems

**Attention:**
Ces templates ne sont PAS l'architecture active de BrainRotFarm.
Consulter `/BrainRotFarm/CLAUDE.md` pour l'architecture réelle du projet actif.

\---

**Version:** 1.0 — Mars 2026
**Maintenance:** Mettre à jour si templates réutilisés dans futurs projets

