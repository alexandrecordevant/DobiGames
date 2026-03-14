# 🎮 DobiGames — Contexte Projet
> Fichier de référence pour Claude Code. Lire avant toute intervention.
> Dernière mise à jour : mars 2026

---

## 👤 Profil Développeur

- Dev expérimenté : web/backend, automatisation IA, MVP rapide
- Utilisation avancée de Claude pour générer 100% du code Lua
- Peu de temps disponible : déléguer 80% à l'IA
- Objectif : 10 000€/mois en 6 mois via jeux Roblox
- Groupe Roblox : **DobiGames** (GitHub : alexandrecordevant/DobiGames)

---

## 🏭 Stratégie DobiGames

**Modèle validé :** BrainRot Idle/Carry Engine
**Référence marché :** Grow a Garden ($12M/mois mai 2025, 1B visites en 33 jours)
**DevEx rate :** 0.0035€/Robux

### Factory de jeux
- 1 template → 8 reskins
- Reskin = modifier `GameConfig.lua` uniquement
- Script de génération : `setup-dobigames.sh`
- Sync Studio↔Git via **Rojo**

### 8 Jeux planifiés
| # | Jeu | Statut |
|---|---|---|
| 1 | **BrainRotFarm** | 🔴 En développement — flagship |
| 2 | BrainRotZoo | ⏳ Template prêt |
| 3 | BrainRotKitchen | ⏳ Template prêt |
| 4 | BrainRotArmy | ⏳ Template prêt |
| 5 | BrainRotGalaxy | ⏳ Template prêt |
| 6 | BrainRotOcean | ⏳ Template prêt |
| 7 | BrainRotMine | ⏳ Template prêt |
| 8 | MutantGrow | ⏳ Template prêt |

---

## 🎮 BrainRotFarm — Jeu Flagship

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

## 🏗️ Architecture Studio (Workspace)

```
Workspace/
├── Bases/
│   ├── Base_1/
│   │   ├── SpawnZone/          ← Folder avec Wall_Top, Wall_Bottom, Wall_Left, Wall_Right
│   │   ├── Field/              ← Visuel du champ
│   │   ├── Base/               ← Bâtiment 4 étages
│   │   │   ├── Floor  1        ← Part (DOUBLE ESPACE) avec spot_1→spot_10 enfants
│   │   │   ├── Floor 2         ← Model avec spot_1→spot_10 + Pillars + Roofd + Ladder
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

### ⚠️ Points critiques Studio
- `Floor  1` a un **double espace** dans son nom
- Les `spot` dans `Floor  1` sont des `Model` enfants d'une `Part`
- Les `spot` dans `Floor 2/3/4` sont des `Model` enfants d'un `Model`
- Chaque `spot` contient : `TouchPart` (Part) + `Part` (visuel)
- `TouchPart` contient un `SurfaceGui` avec `$amount` et `$offline`

---

## 📜 Scripts — Statut Complet

### ✅ Terminés

| Script | Localisation | Rôle |
|---|---|---|
| `Main.server.lua` | ServerScriptService | Boot, RemoteEvents, init modules |
| `DataStoreManager.lua` | ServerScriptService | Save/load + offline income |
| `EventManager.lua` | ServerScriptService | Admin Abuse auto + hebdo |
| `MonetizationHandler.lua` | ServerScriptService | ProcessReceipt + GamePasses |
| `DiscordWebhook.lua` | ServerScriptService | Webhook Discord auto |
| `CollectSystem.lua` | ReplicatedStorage/Modules | Raretés + multiplicateurs |
| `UpgradeSystem.lua` | ReplicatedStorage/Modules | Tiers + prestige |
| `GameConfig.lua` | ReplicatedStorage/Modules | Config par jeu (seul fichier à modifier) |
| `HUDController.client.lua` | StarterPlayerScripts | HUD coins/tier + event timer |
| `BrainRotSpawner.lua` | ServerScriptService | Spawn BR champs individuels |
| `ChampCommunSpawner.lua` | ServerScriptService | Spawn MYTHIC/SECRET + compteur |
| `CarrySystem.lua` | ServerScriptService | Transport BR + ProximityPrompt |

### ❌ À faire

| Script | Rôle |
|---|---|
| `BaseProgressionSystem.lua` | ⚠️ Généré mais NE FONCTIONNE PAS — à débugger |
| `DropSystem.lua` | Dépôt BR sur spot → coins |
| `IncomeSystem.lua` | Coins/sec par BR déposé |
| `ShopSystem.lua` | Arroseur, tracteur, speed, carry+ |
| `AssignationSystem.lua` | Assignation base → joueur à la connexion |
| `LeaderboardSystem.lua` | Classement visible par tous |

---

## 🔧 Règles Code Lua — Impératives

```lua
-- ✅ TOUJOURS
task.wait()           -- jamais wait()
pcall()               -- sur TOUS les appels DataStore
-- Validation côté serveur uniquement (jamais faire confiance au client)
-- Commentaires en français
-- ProcessReceipt dans MonetizationHandler UNIQUEMENT

-- ✅ RAMASSAGE Brain Rots
-- COMMON/OG/RARE → Touched (automatique, mobile-compatible)
-- EPIC → ProximityPrompt HoldDuration = 0.5s
-- LEGENDARY → ProximityPrompt HoldDuration = 1.5s
-- MYTHIC → ProximityPrompt HoldDuration = 3.0s
-- SECRET → ProximityPrompt HoldDuration = 5.0s
-- BRAINROT_GOD → ProximityPrompt HoldDuration = 8.0s

-- ✅ DÉPÔT à la base
-- ProximityPrompt instantané (HoldDuration = 0)
-- Visible uniquement si joueur porte au moins 1 BR

-- ✅ ASSETS
-- BrainRots dans ServerStorage (anti-copie)
-- JAMAIS dans Workspace ou ReplicatedStorage

-- ❌ JAMAIS
wait()                -- utiliser task.wait() à la place
-- DataStore sans pcall
-- RemoteEvents non validés côté serveur
-- ProximityPrompt pour ramassage COMMON/OG/RARE
```

---

## 💰 Table des Raretés Brain Rots

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

## 📈 Progression Base (BaseProgressionSystem)

| Étape | Seuil coins | Déblocage |
|---|---|---|
| Départ | 0 | Floor 1 — spot_1 + spot_2 |
| 2 | 100 | Floor 1 — spots suivants |
| 3 | 2 000 | Floor 2 complet |
| 4 | 15 000 | Floor 3 complet |
| 5 | 80 000 | Floor 4 complet |
| Max | 300 000 | Floor 4 — spot_10 |

---

## 🚀 RemoteEvents créés par Main.server.lua

```
UpdateHUD           → FireClient — mise à jour coins/tier
NotifEvent          → FireClient — notifications in-game
EventStarted        → FireAllClients — event démarré + durée
EventEnded          → FireAllClients — event terminé
OfflineIncomeNotif  → FireClient — revenu offline au login
SecretRevealNotif   → FireClient — prochain rare révélé
CollectVFX          → FireClient — effet visuel collecte
DemandeUpgrade      → OnServerEvent — achat upgrade
DemandePrestige     → OnServerEvent — prestige
DemandeCollecte     → OnServerEvent — collecte BR
CarryUpdate         → FireClient — mise à jour carry (X/Y BR)
```

---

## 🛠️ Stack Technique

| Outil | Usage |
|---|---|
| Roblox Studio | Construction + test |
| Rojo | Sync fichiers PC ↔ Studio |
| Git + GitHub | Versioning (alexandrecordevant/DobiGames) |
| Claude Code | Génération scripts Lua |
| Claude.ai | Stratégie + prompts |

### Git workflow
```bash
# Premier push
git push --set-upstream origin main

# Push normal
git add .
git commit -m "description"
git push

# Config LF/CRLF (Windows)
git config --global core.autocrlf false
```

---

## 📋 Checklist Publish (avant chaque jeu)

```
[ ] GameConfig.lua : NomDuJeu, IDs Game Pass, IDs Dev Products, DiscordWebhookURL
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

## 🎯 Prochaines Actions Prioritaires

1. **Débugger BaseProgressionSystem.lua** — script généré mais ne fonctionne pas
2. **DropSystem.lua** — dépôt BR sur spot → coins (cœur de la boucle économique)
3. **IncomeSystem.lua** — coins/sec par BR déposé
4. **ShopSystem.lua** — upgrades achetables
5. **AssignationSystem.lua** — assigner base au joueur à la connexion
6. **Leaderboard** — classement visible
7. **Publish BrainRotFarm** — premier jeu live

---

*DobiGames · BrainRotFarm · Mars 2026*
*À mettre à jour après chaque session de développement*
