# Analyse impact shared-lib → LavaTower *(mise à jour avec décisions Alex)*

---

## ✅ Systèmes déjà intégrés

| Système | Fichier LavaTower | Note |
|---|---|---|
| `PickupSystem` | `src/ServerScriptService/BrainrotService.server.lua:3` | Une ligne — délègue `.Init()` |
| `BrainrotInventoryService` | `src/ServerScriptService/Main.server.lua:85` + `RebirthServer.server.lua:15` | Utilisé via pcall |

---

## ❌ Systèmes manquants

| Système | Statut | Priorité |
|---|---|---|
| `AssignationSystem` | Absent | **BLOQUANT** |
| `BaseProgressionSystem` | Absent + Workspace à créer | **BLOQUANT** |
| `RebirthSystem` (shared-lib) | À remplacer — `RebirthServer.server.lua` à supprimer | **BLOQUANT** |
| `DropSystem` | Absent | IMPORTANT |
| `IncomeSystem` | Absent | IMPORTANT |
| `CarrySystem` | Non initialisé explicitement | IMPORTANT |
| `BoardSystem` | Absent | Optionnel |
| `RebirthCosmeticsSystem` | Absent | Optionnel |

---

## 🚨 Incompatibilités détectées *(avec statut de résolution)*

### 1. ✅ DÉCIDÉ — Migration RebirthSystem

`RebirthServer.server.lua` (custom, DataStore séparé `"LavaTowerRebirthV1"`) → **à supprimer et remplacer par `RebirthSystem` shared-lib**.

**Ce que ça implique :**

| Élément | Action requise |
|---|---|
| `src/ServerScriptService/RebirthServer.server.lua` | Supprimer |
| `src/ReplicatedStorage/Modules/RebirthConfig.lua:24-35` | Réécrire au format shared-lib |
| `src/ServerScriptService/_RebirthCallbacks.lua` | Supprimer ou adapter |
| `src/ServerScriptService/Main.server.lua:68-93` | Remplacer `SetCallbacks` par injection `RebirthSystem.Config`, `OnRebirthComplete`, `OnResetBase` |
| DataStore `"LavaTowerRebirthV1"` | **Données joueurs perdues** (rebirthCount, slots) — voir risque ci-dessous |

Format cible pour `RebirthConfig.lua` :
```lua
-- Ancien (LavaTower custom) :
[1] = { money = 10000, rarity = "Common", reward = { slots = 1 } }

-- Nouveau (shared-lib RebirthSystem) :
[1] = {
    coinsRequis    = 10000,
    brainRotRequis = { rarete = "Common", quantite = 1 },
    multiplicateur = 1.5,
    slotsBonus     = 1,
    label          = "Rebirth 1",
    couleur        = Color3.fromRGB(200, 200, 200),
    couleurHex     = 0xC8C8C8,
}
```

---

### 2. ✅ DÉCIDÉ — Normalisation raretés shared-lib

**Situation BrainRotFarm** : BRF utilise **deux systèmes de raretés** côte à côte :
- `GameConfig.Raretes` (affichage/spawn items standard) : `"Common"`, `"Rare"` (capitalisé) — **même format que LavaTower**
- Raretés spawn avancées (BRF-specific) : `"COMMON"`, `"OG"`, `"RARE"`, `"BRAINROT_GOD"` (MAJUSCULES) — spécifique BRF, dans `ServerStorage.Brainrots/COMMON/` etc.

**Problème** : Le `DropSystem` cherche le dossier par nom exact (`DropSystem.lua:175`). Si LavaTower a `ServerStorage.Brainrots/Common/` et BRF a `ServerStorage.Brainrots/COMMON/`, les deux casseront si on change le comportement.

**Solution** : Rendre la recherche **case-insensitive** dans DropSystem (non-breaking) :
```lua
-- Modification shared-lib/server/DropSystem.lua :
local dossier = brainrots:FindFirstChild(rarete)
             or brainrots:FindFirstChild(string.upper(rarete))
             or brainrots:FindFirstChild(string.lower(rarete):gsub("^%l", string.upper))
```

LavaTower organise donc `ServerStorage.Brainrots/Common/`, `/Uncommon/`, `/Rare/`, `/Epic/`, `/Legendary/`, `/Secret/`.

> **⚠️ Cross-game impact** : modification shared-lib — tester BRF après.

---

### 3. ✅ DÉCIDÉ — GameConfig split SharedLib + Specific

Pattern retenu :

```
ReplicatedStorage/
  GameConfig.lua          ← merger (point d'entrée, seul fichier que shared-lib voit)
  GameConfigShared.lua    ← champs requis par shared-lib (ProgressionConfig, MaxBases, etc.)
  GameConfigSpecific.lua  ← champs propres au jeu (NomDuJeu, IDs monétisation, audio, etc.)
```

`GameConfig.lua` merger :
```lua
local Config = {}
local Shared   = require(script.Parent.GameConfigShared)
local Specific = require(script.Parent.GameConfigSpecific)
for k, v in pairs(Shared)   do Config[k] = v end
for k, v in pairs(Specific) do Config[k] = v end  -- Specific écrase si conflit
return Config
```

shared-lib continue de faire `require(ReplicatedStorage.GameConfig)` — **aucune modification shared-lib nécessaire**.

**Séparation des responsabilités :**

| `GameConfigShared.lua` | `GameConfigSpecific.lua` |
|---|---|
| `ProgressionConfig` (floors, seuils) | `NomDuJeu = "LavaTower"` |
| `MaxBases` | `CollectibleName = "Stone"` |
| `ValeurParRarete` | `GamePassVIP`, `GamePassOfflineVault`... |
| `IncomeParRarete` | `DiscordWebhookURL` |
| `AnimationConfig` | `CouleurPrimaire`, `CouleurSecondaire` |
| `CaptureConfig`, `CarryNiveaux`, `CarryPrices` | `SonCollecte`, `SonRare`... |
| `RebirthFloorDiscount`, `FloorUnlockCosts` | `BadgePremierPrestige` |
| `Raretes` (format shared-lib) | `ZoneUnlockSeuils`, `ZonePrestigeSeuil` |

> **Note BrainRotFarm** : BRF peut rester avec son `GameConfig.lua` monolithique — aucune migration forcée.

---

### 4. ✅ DÉCIDÉ — Architecture multi-base

Workspace LavaTower devra avoir la structure :
```
Workspace/
  Bases/
    Base_1/
      [Base/]           ← optionnel (BaseProgressionSystem auto-détecte)
        Floor_1/        ← Part ou Model
          spot_1        ← Model avec TouchPart
          spot_2
          ...
        Floor_2/
          ...
    Base_2/
    ...
```

`Config.MaxBases` détermine combien de bases existent. `AssignationSystem` les alloue aux joueurs.
Les noms `Floor_1`, `spot_1` sont reconnus automatiquement par BaseProgressionSystem (tolérance casse/underscore/espace).

> **⚠️ Workspace à créer de zéro en Studio.**

---

### 5. ✅ DÉCIDÉ — CollectibleName = "Stone"

```lua
-- GameConfigSpecific.lua
GameConfig.CollectibleName = "Stone"
GameConfig.NomDuJeu        = "LavaTower"
GameConfig.Theme           = "Lava"
```

Retirer les placeholders `PRIMARY_R/G/B` dans `GameConfig.lua:58`.

---

### 6. DataStore rebirth — migration des données joueurs existants

`RebirthServer.server.lua:23` stocke dans `"LavaTowerRebirthV1"` sous clé `"rebirth_USERID"`.
Le `RebirthSystem` shared-lib stocke dans le **playerData principal** (`data.rebirthLevel`, `data.multiplicateurPermanent`, `data.slotsBonus`).

> **⚠️ DÉCISION RESTANTE** : Jeu en production avec joueurs réels → migration dans `DataStoreManager.Load()` nécessaire. Phase de dev → reset propre, supprimer `"LavaTowerRebirthV1"`.

---

## ❓ Informations toujours manquantes *(décisions restantes)*

1. **Nombre de floors et spots** : Combien de `Floor_X` par base ? Combien de `spot_X` par floor ?
   *(définit `Config.ProgressionConfig.floors` et `seuils`)*
2. **Économie** : Valeur par rareté en coins/s ? (`ValeurParRarete` et `IncomeParRarete` pour DropSystem + IncomeSystem)
3. **Condition Rebirth** : Quelle condition déclenche le bouton Rebirth ?
   Dans BRF : `data.progression["4_10"] == true` (tous les spots du floor 4 débloqués).
   Pour LavaTower : quel seuil ? *(injecté via `RebirthSystem.IsProgressionComplete`)*
4. **LavaTower en production ?** : Joueurs réels → migration DataStore nécessaire. Dev only → reset propre.

---

## 📋 Plan d'intégration recommandé *(ordre strict)*

### Phase 0 — Décisions finales (avant tout code)
1. Décider floors/spots count → définit toute la ProgressionConfig
2. Décider si le jeu est en prod → stratégie migration DataStore

### Phase 1 — Config (½ journée)
3. Créer `GameConfigShared.lua` avec tous les champs shared-lib (MaxBases, ProgressionConfig placeholder, Raretes, ValeurParRarete, IncomeParRarete, AnimationConfig, CarryNiveaux, CarryPrices, RebirthFloorDiscount)
4. Créer `GameConfigSpecific.lua` (NomDuJeu="LavaTower", CollectibleName="Stone", couleurs, IDs monétisation, audio)
5. Transformer `GameConfig.lua` en merger
6. Réécrire `RebirthConfig.lua` au format shared-lib

### Phase 2 — Workspace Studio *(hors code)*
7. Créer `Workspace.Bases.Base_1...Base_N` avec structure `Floor_X/spot_X`
8. Créer `ServerStorage.Brainrots/Common/`, `/Uncommon/`, `/Rare/`, `/Epic/`, `/Legendary/`, `/Secret/` avec modèles Stone

### Phase 3 — Intégration systèmes core
9. **Supprimer** `RebirthServer.server.lua` + `_RebirthCallbacks.lua`
10. **AssignationSystem** dans `Main.server.lua` : `Init()`, `OnAssigned`, `GetSpawnCFrame`
11. **BaseProgressionSystem** dans `OnAssigned` callback
12. **RebirthSystem** : `Init()`, injecter `Config`, `IsProgressionComplete`, `OnResetBase`, `OnRebirthComplete`
13. Brancher `RebirthSystem.MettreAJourBouton` sur les événements coins/collecte

### Phase 4 — Économie
14. **CarrySystem.Init()** (ajouter appel explicite dans Main)
15. **DropSystem.Init()** dans `OnAssigned`
16. **IncomeSystem.Init()** dans `OnAssigned`, brancher tick sur `BaseProgressionSystem.VerifierDeblocages`

### Phase 5 — Patch shared-lib (cross-game)
17. Rendre DropSystem case-insensitive pour les noms de dossiers raretés
18. **Tester BrainRotFarm** après patch

### Phase 6 — Optionnel
19. `BoardSystem`, `RebirthCosmeticsSystem`

---

## ⚠️ Risques

| Risque | Niveau | Détail |
|---|---|---|
| Perte données joueurs rebirth | **HIGH** | Migration `"LavaTowerRebirthV1"` → playerData principal — à traiter avant Phase 3 si prod |
| Workspace inexistant | **HIGH** | Phases 3-4 complètement bloquées sans `Bases/Base_X/Floor_X/spot_X` en Studio |
| Patch DropSystem casse BRF | **MEDIUM** | Modifier shared-lib → tester BRF `ServerStorage.Brainrots/COMMON/` |
| `RebirthSystem.IsProgressionComplete` non défini | **MEDIUM** | Si non injecté, le bouton Rebirth n'apparaît jamais — silent bug |
| DataStoreManager.DefaultData insuffisant | **MEDIUM** | Ne contient pas `rebirthLevel`, `multiplicateurPermanent`, `progression`, `spotsOccupes` — à ajouter dans `Setup()` de Main |
| CarrySystem Init silencieux | **LOW** | PickupSystem appelle `CarrySystem.AjouterAuCarry` sans que Init() ait été appelé — échoue silencieusement |

---

## ⏱️ Estimation effort

| Tâche | Heures |
|---|---|
| Phase 0-1 : Config + RebirthConfig | 2h |
| Phase 2 : Workspace Studio (dépend du nb floors/spots) | 3-6h |
| Phase 3 : AssignationSystem + BaseProgressionSystem + RebirthSystem | 5h |
| Phase 4 : CarrySystem + DropSystem + IncomeSystem | 4h |
| Phase 5 : Patch shared-lib + tests BRF | 2h |
| Tests intégration LavaTower | 4h |
| **Total (sans optionnel)** | **~20-23h** |
| Phases optionnelles (Board + Cosmetics) | +4h |

> **Chemin critique** : Workspace Studio (Phase 2) est la dépendance la plus longue et entièrement manuelle. Les Phases 3-4 ne peuvent pas démarrer sans elle.
