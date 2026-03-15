# DobiGames — Contexte Projet
> Fichier de référence pour Claude Code. Lire avant toute intervention.
> Dernière mise à jour : mars 2026

---

## Profil Développeur

- Dev expérimenté : web/backend, automatisation IA, MVP rapide
- Utilisation avancée de Claude pour générer 100% du code Lua
- Peu de temps disponible : déléguer 80% à l'IA
- Objectif : 10 000€/mois en 6 mois via jeux Roblox
- Groupe Roblox : **DobiGames** (GitHub : alexandrecordevant/DobiGames)

---

## Stratégie DobiGames

**Modèle validé :** BrainRot Idle/Carry Engine
**Référence marché :** Grow a Garden ($12M/mois mai 2025, 1B visites en 33 jours)
**DevEx rate :** 0.0035€/Robux

### Factory de jeux
- 1 template → 8 reskins
- Reskin = modifier `GameConfig.lua` + implémenter les stubs Specialized
- Script de génération : `./setup-dobigames.sh NomJeu "Nom Affiché"`
- Sync Studio↔Git via **Rojo**

### 8 Jeux planifiés
| # | Jeu | Statut |
|---|---|---|
| 1 | **BrainRotFarm** | En développement — flagship |
| 2 | BrainRotZoo | Template prêt |
| 3 | BrainRotKitchen | Template prêt |
| 4 | BrainRotArmy | Template prêt |
| 5 | BrainRotGalaxy | Template prêt |
| 6 | BrainRotOcean | Template prêt |
| 7 | BrainRotMine | Template prêt |
| 8 | MutantGrow | Template prêt |

---

## BrainRotFarm — Jeu Flagship

### Concept
**Phrase du jeu :** "Fais pousser des Brain Rots dans ta ferme, collecte-les, dépose-les dans ta base, upgrade à l'infini."

### Game Design
- **6 joueurs humains** simultanés
- Chaque joueur a **son propre champ** (Brain Rots spawent, joueur ramasse→porte→dépose)
- Chaque joueur a **sa propre base** (4 étages, spots débloqués progressivement)
- **ChampCommun** central : event toutes les 5 min (MYTHIC/SECRET exclusifs)
- Carry : 1 BR par défaut → upgrade jusqu'à 5
- Mort = perd tous les BR portés (sauf Game Pass Protection)

### Monétisation
| Produit | Prix | Type |
|---|---|---|
| VIP Pass | 149 R$ | Game Pass — carry ×2 permanent |
| Offline Vault | 199 R$ | Game Pass — income offline ×3 |
| Auto Collect | 299 R$ | Game Pass — collecte auto |
| Protection | 149 R$ | Game Pass — garde BR à la mort |
| Lucky Hour | 35 R$ | Dev Product — spawn ×5 / 30 min |
| Secret Reveal | 25 R$ | Dev Product — révèle prochain rare |
| Skip Tier | 50 R$ | Dev Product — skip un palier |

### Admin Abuse automatique (0 intervention humaine)
- Event auto toutes les 2h (spawn ×10, 5 min)
- Admin Abuse hebdo : samedi 20h UTC (spawn ×50, 45 min)
- Discord webhook automatique branché sur EventManager

---

## Architecture des Sources (nouvelle structure Common/Specialized)

```
_template/src/
├── ReplicatedStorage/
│   ├── Common/              ← identique dans tous les jeux
│   │   ├── CollectSystem.lua
│   │   └── UpgradeSystem.lua
│   └── Specialized/         ← stub à surcharger par jeu
│       └── GameConfig.lua
├── ServerScriptService/
│   ├── Common/              ← identique dans tous les jeux
│   │   ├── Main.server.lua
│   │   ├── DataStoreManager.lua
│   │   ├── EventManager.lua
│   │   ├── MonetizationHandler.lua
│   │   ├── DiscordWebhook.lua
│   │   ├── CarrySystem.lua
│   │   ├── RebirthSystem.lua
│   │   ├── DropSystem.lua      ← stub
│   │   ├── IncomeSystem.lua    ← stub
│   │   └── ShopSystem.lua      ← stub
│   └── Specialized/         ← stubs à implémenter par jeu
│       ├── SpawnManager.lua
│       ├── ChampCommunSpawner.lua
│       ├── BaseProgressionSystem.lua
│       ├── AssignationSystem.lua
│       └── LeaderboardSystem.lua
└── StarterPlayer/StarterPlayerScripts/
    └── Common/
        └── HUDController.client.lua

games/BrainRotFarm/src/
├── ReplicatedStorage/
│   ├── Common/              ← copie du template
│   └── Specialized/
│       ├── GameConfig.lua   ← config spécifique BrainRotFarm
│       └── BrainrotSpawnConfig.lua
├── ServerScriptService/
│   ├── Common/              ← copie du template
│   └── Specialized/
│       ├── BrainRotSpawner.lua
│       ├── ChampCommunSpawner.lua
│       └── BaseProgressionSystem.lua
└── StarterPlayer/StarterPlayerScripts/
    └── Common/
        └── HUDController.client.lua
```

### Chemins require() — Règle de nommage

```lua
-- ReplicatedStorage
local Config        = require(game.ReplicatedStorage.Specialized.GameConfig)
local CollectSystem = require(game.ReplicatedStorage.Common.CollectSystem)
local UpgradeSystem = require(game.ReplicatedStorage.Common.UpgradeSystem)

-- ServerScriptService
local DataStoreManager      = require(ServerScriptService.Common.DataStoreManager)
local CarrySystem           = require(ServerScriptService.Common.CarrySystem)
local RebirthSystem         = require(ServerScriptService.Common.RebirthSystem)
local BrainRotSpawner       = require(ServerScriptService.Specialized.BrainRotSpawner)
local BaseProgressionSystem = require(ServerScriptService.Specialized.BaseProgressionSystem)
local ChampCommunSpawner    = require(ServerScriptService.Specialized.ChampCommunSpawner)
```

---

## Architecture Studio (Workspace)

```
Workspace/
├── Bases/
│   ├── Base_1/
│   │   ├── SpawnZone/          ← Folder avec Wall_Top, Wall_Bottom, Wall_Left, Wall_Right
│   │   ├── Field/              ← Visuel du champ
│   │   ├── Base/               ← Bâtiment 4 étages
│   │   │   ├── Floor  1        ← Part (DOUBLE ESPACE) avec spot_1→spot_10 enfants
│   │   │   ├── Floor 2         ← Model avec spot_1→spot_10 + Pillars + Roof + Ladder
│   │   │   ├── Floor 3         ← Model (même structure)
│   │   │   └── Floor 4         ← Model (même structure)
│   │   ├── Shop/               ← Magasin upgrades
│   │   ├── Sprinklers/         ← Upgrade arroseur
│   │   └── Tractor/            ← Upgrade tracteur
│   ├── Base_2/ ... Base_6/     ← Même structure exacte
│
├── ChampCommun/                ← Event toutes les 5 min
│   └── (3 points de spawn)
│       Point A : X=190.92, Y=16.189, Z=66.30
│       Point B : X=250.93, Y=16.189, Z=-80.20
│       Point C : X=189.51, Y=16.189, Z=-241.28
│
└── Baseplate

ServerStorage/
└── Brainrots/
    ├── COMMON/
    ├── OG/
    ├── RARE/
    ├── EPIC/
    ├── LEGENDARY/
    ├── MYTHIC/        ← Réservé ChampCommun uniquement
    ├── SECRET/        ← Réservé ChampCommun uniquement
    └── BRAINROT_GOD/
```

### Points critiques Studio
- `Floor  1` a un **double espace** dans son nom
- Les `spot` dans `Floor  1` sont des `Model` enfants d'une `Part`
- Les `spot` dans `Floor 2/3/4` sont des `Model` enfants d'un `Model`
- Chaque `spot` contient : `TouchPart` (Part) + `Part` (visuel)
- `TouchPart` contient un `SurfaceGui` avec `$amount` et `$offline`

---

## Scripts — Statut Complet (BrainRotFarm)

### Terminés

| Script | Localisation | Rôle |
|---|---|---|
| `Main.server.lua` | SSS/Common | Boot, RemoteEvents, init modules |
| `DataStoreManager.lua` | SSS/Common | Save/load + offline income |
| `EventManager.lua` | SSS/Common | Admin Abuse auto + hebdo |
| `MonetizationHandler.lua` | SSS/Common | ProcessReceipt + GamePasses |
| `DiscordWebhook.lua` | SSS/Common | Webhook Discord auto |
| `CarrySystem.lua` | SSS/Common | Transport BR + ProximityPrompt |
| `RebirthSystem.lua` | SSS/Common | Reset volontaire + multiplicateur permanent |
| `CollectSystem.lua` | RS/Common | Raretés + multiplicateurs |
| `UpgradeSystem.lua` | RS/Common | Tiers + prestige |
| `HUDController.client.lua` | StarterPlayerScripts/Common | HUD coins/tier + event timer |
| `BrainRotSpawner.lua` | SSS/Specialized | Spawn BR champs individuels |
| `ChampCommunSpawner.lua` | SSS/Specialized | Spawn MYTHIC/SECRET + compteur + timer |
| `BaseProgressionSystem.lua` | SSS/Specialized | Déblocage progressif étages + spots |
| `GameConfig.lua` | RS/Specialized | Config par jeu (seul fichier à modifier) |
| `BrainrotSpawnConfig.lua` | RS/Specialized | Config spawn BR spécifique BrainRotFarm |

### À faire

| Script | Localisation cible | Rôle |
|---|---|---|
| `DropSystem.lua` | SSS/Common | Dépôt BR sur spot → coins |
| `IncomeSystem.lua` | SSS/Common | Coins/sec par BR déposé |
| `ShopSystem.lua` | SSS/Common | Arroseur, tracteur, speed, carry+ |
| `AssignationSystem.lua` | SSS/Specialized | Assignation base → joueur à la connexion |
| `LeaderboardSystem.lua` | SSS/Specialized | Classement visible par tous |

---

## Règles Code Lua — Impératives

```lua
-- TOUJOURS
task.wait()           -- jamais wait()
pcall()               -- sur TOUS les appels DataStore
-- Validation côté serveur uniquement (jamais faire confiance au client)
-- Commentaires en français
-- ProcessReceipt dans MonetizationHandler UNIQUEMENT

-- RAMASSAGE Brain Rots — TOUS via ProximityPrompt
-- COMMON/OG/RARE → HoldDuration = 0 (instantané, équivalent Touched)
-- EPIC           → HoldDuration = 0.5s
-- LEGENDARY      → HoldDuration = 1.5s
-- MYTHIC         → HoldDuration = 3.0s
-- SECRET         → HoldDuration = 5.0s
-- BRAINROT_GOD   → HoldDuration = 8.0s
-- Note : Touched désactivé (CanCollide=false + Anchored=true ne fire pas Touched)

-- DÉPÔT à la base
-- ProximityPrompt instantané (HoldDuration = 0)
-- Visible uniquement si joueur porte au moins 1 BR

-- ASSETS
-- BrainRots dans ServerStorage (anti-copie)
-- JAMAIS dans Workspace ou ReplicatedStorage

-- JAMAIS
wait()                -- utiliser task.wait() à la place
-- DataStore sans pcall
-- RemoteEvents non validés côté serveur
```

---

## Table des Raretés Brain Rots

### Champs individuels (BrainRotSpawner)
| Rareté | Dossier | Chance | Valeur coins |
|---|---|---|---|
| Common | COMMON | 55% | 1 |
| OG | OG | 22% | 3 |
| Rare | RARE | 13% | 10 |
| Epic | EPIC | 7% | 30 |
| Legendary | LEGENDARY | 2.8% | 100 |
| BrainRot God | BRAINROT_GOD | 0.2% | 2000 |

### ChampCommun uniquement (ChampCommunSpawner)
| Rareté | Intervalle | Compteur visible avant | Valeur coins |
|---|---|---|---|
| MYTHIC | 8 min | 3 min | 300 |
| SECRET | 20 min | 5 min | 1000 |

---

## Progression Base (BaseProgressionSystem)

| Étape | Seuil coins | Déblocage |
|---|---|---|
| Départ | 0 | Floor 1 — spot_1 + spot_2 |
| 2 | 50 | Floor 1 — spot_3 |
| ... | ... | ... |
| Floor 2 | 2 000 | Floor 2 complet (spot_1 unlock) |
| Floor 3 | 15 000 | Floor 3 complet |
| Floor 4 | 80 000 | Floor 4 complet |
| Max | 300 000 | Floor 4 — spot_10 → bouton Rebirth visible |

---

## Système Rebirth (RebirthSystem)

| Niveau | Coins requis | BR rare requis | Multiplicateur | Slots bonus |
|---|---|---|---|---|
| Rebirth I | 300 000 | 1 LEGENDARY | ×1.5 | +2 |
| Rebirth II | 500 000 | 1 MYTHIC | ×2.0 | +4 |
| Rebirth III | 1 000 000 | 1 SECRET | ×3.0 | +6 |
| Rebirth IV | 2 000 000 | 1 BRAINROT_GOD | ×5.0 | +10 |
| Rebirth V+ | 2M × 2^(n-4) | 1 BRAINROT_GOD | 5 + 1.5×(n-4) | +5 |

---

## RemoteEvents créés par Main.server.lua

```
UpdateHUD              → FireClient — mise à jour coins/tier
NotifEvent             → FireClient — notifications in-game
EventStarted           → FireAllClients — event démarré + durée
EventEnded             → FireAllClients — event terminé
OfflineIncomeNotif     → FireClient — revenu offline au login
SecretRevealNotif      → FireClient — prochain rare révélé
CollectVFX             → FireClient — effet visuel collecte
DemandeUpgrade         → OnServerEvent — achat upgrade
DemandePrestige        → OnServerEvent — prestige
DemandeCollecte        → OnServerEvent — collecte BR (legacy)
CarryUpdate            → FireClient — mise à jour carry (X/Y BR)
RebirthButtonUpdate    → FireClient — état bouton rebirth
DemandeRebirth         → OnServerEvent — demande rebirth
RebirthAnimation       → FireClient — déclenche animation rebirth
```

---

## Stack Technique

| Outil | Usage |
|---|---|
| Roblox Studio | Construction + test |
| Rojo | Sync fichiers PC ↔ Studio |
| Git + GitHub | Versioning (alexandrecordevant/DobiGames) |
| Claude Code | Génération scripts Lua |
| Claude.ai | Stratégie + prompts |

### Git workflow
```bash
# Nouveau jeu depuis template
./setup-dobigames.sh BrainRotZoo "Brain Rot Zoo"

# Push normal
git add .
git commit -m "description"
git push

# Config LF/CRLF (Windows)
git config --global core.autocrlf false
```

---

## Checklist Publish (avant chaque jeu)

```
[ ] GameConfig.lua : NomDuJeu, IDs Game Pass, IDs Dev Products, DiscordWebhookURL
[ ] Stubs Specialized remplacés par implémentations réelles
[ ] API Services activé : roblox.com/develop → Security → Enable Studio Access
[ ] DataStore testé (save + load + offline income)
[ ] Event auto testé (EventIntervalleMinutes = 1 pour test rapide)
[ ] ProcessReceipt testé avec achat test
[ ] Admin Abuse hebdo : vérifier jour/heure UTC dans Config
[ ] Leaderboard visible au spawn
[ ] Mobile : HUD lisible petit écran
[ ] Like ratio > 70% premières 48h (mobiliser amis/Discord)
```

---

## Prochaines Actions Prioritaires

1. **DropSystem.lua** — dépôt BR sur spot → coins (cœur de la boucle économique)
2. **IncomeSystem.lua** — coins/sec par BR déposé
3. **ShopSystem.lua** — upgrades achetables
4. **AssignationSystem.lua** — assigner base au joueur à la connexion
5. **LeaderboardSystem.lua** — classement visible
6. **Publish BrainRotFarm** — premier jeu live

---

*DobiGames · BrainRotFarm · Mars 2026*
*À mettre à jour après chaque session de développement*
