# RAPPORT SHARED-LIB — 2026-04-06

Audit d'harmonisation de l'utilisation de la shared-lib dans BrainRotFarm et LavaTower.
Audit lecture seule — aucun fichier modifié.

---

## Tableau 1 : État par module

| Module shared-lib | Rôle | BrainRotFarm | LavaTower | Action requise |
|---|---|---|---|---|
| AssignationSystem | Attribution bases joueurs + cleanup déco | ✅ UTILISE | ✅ UTILISE | Aucune |
| BaseProgressionSystem | Unlock floors/spots par tier | ✅ UTILISE | ✅ UTILISE | Aucune |
| CarrySystem | Pickup Brain Rots via ProximityPrompt + Backpack | ✅ UTILISE | ✅ UTILISE | Aucune |
| DropSystem | Dépôt Brain Rots aux bases + visuels | ✅ UTILISE | ✅ UTILISE | Aucune |
| IncomeSystem | Revenu passif coins/sec par BR déposé | ✅ UTILISE | ✅ UTILISE | Aucune |
| RebirthSystem | Reset volontaire + multiplicateur permanent | ✅ UTILISE | ✅ UTILISE | Aucune |
| RebirthCosmeticsSystem | Auras/trails/particules par tier rebirth | ✅ UTILISE | ✅ UTILISE | Aucune |
| PickupSystem | Collecte BR via CollectionService + ProximityPrompt | ❌ ABSENT | ✅ UTILISE | Évaluer si BRF en a besoin |
| CollectSystem | Draw rareté + calculs multiplicateurs + income offline | ✅ UTILISE | ❌ ABSENT | Importer dans LT pour income offline |
| UpgradeSystem | Coût upgrades + tier progression + prestige | ✅ UTILISE | ⚠️ FORK LOCAL | Migrer LT vers shared |
| MonetizationHandler | IAP + GamePass + receipt handling | ✅ UTILISE | ⚠️ FORK LOCAL | Migrer LT vers shared (subset simplifié) |
| EventManager | Événements temporisés + auto-trigger + cycles | ✅ UTILISE | ❌ ABSENT | LT sans events = OK pour l'instant |
| BotSystem | Simulation IA joueurs sur bases vides | ✅ UTILISE | ❌ ABSENT | LT sans bots = OK pour l'instant |
| UITheme | Palette couleurs centralisée (farm: brun/doré/vert) | ✅ UTILISE | ❌ ABSENT | LT doit adopter UITheme dans ses HUDs |
| BatSystem + Combat (4 modules) | Baseball bat PvP + anti-exploit + safe zones | ✅ UTILISE | ❌ ABSENT | LT sans PvP = OK |
| FilterSystem (21 fichiers) | Filtres visuels rareté/éléments/état | ❌ ABSENT | ❌ ABSENT | Aucun jeu ne l'utilise — à investiguer |
| BrainrotInventoryService | Inventaire BR côté serveur (prêt DataStore) | ❌ ABSENT | ❌ ABSENT | Non intégré nulle part — backlog |

**Légende :** ✅ UTILISE = import direct shared-lib | ⚠️ FORK LOCAL = copie locale divergente | ❌ ABSENT = pas implémenté

---

## Tableau 2 : Forks détectés (à harmoniser)

| Fichier fork | Jeu | Module shared-lib équivalent | Différence identifiée | Priorité |
|---|---|---|---|---|
| `src/ServerScriptService/MonetizationHandler.lua` | LavaTower | `Server/MonetizationHandler` | Simplifié : seulement GamePass, pas de receipt handling IAP | 🔴 HAUTE |
| `src/ReplicatedStorage/Modules/UpgradeSystem.lua` | LavaTower | `Shared/UpgradeSystem` | Simplifié : ~70% du code, valeurs hardcodées en fallback | 🔴 HAUTE |
| `src/StarterPlayer/.../HUDController.client.lua` | LavaTower | `Client/HUDController.client` | Implémentation custom complète, couleurs hardcodées au lieu de UITheme | 🟡 MOYENNE |
| `src/StarterPlayer/.../RebirthClient.client.lua` | LavaTower | `Client/RebirthHUD.client` | UI rebirth entièrement custom, pas de UITheme | 🟡 MOYENNE |

---

## Tableau 3 : HUDs et scripts client

| Script client | Jeu | Logique serveur dupliquée ? | Verdict |
|---|---|---|---|
| `ShopHUD.client.lua` | BrainRotFarm | Non — UI display only | ✅ OK — utilise UITheme correctement |
| `FlowerPotHUD.client.lua` | BrainRotFarm | Non — UI display only | ✅ OK — utilise UITheme |
| `SlotMenuHUD.client.lua` | BrainRotFarm | Non — game-specific | ✅ OK — spécifique BRF |
| `SeedsHUD.client.lua` | BrainRotFarm | Non — inventory display | ✅ OK — spécifique BRF |
| `CollectAllButton.client.lua` | BrainRotFarm | Non — single button util | ✅ OK |
| `HUDController.client.lua` | LavaTower | Non — mais réimplémente le shared-lib | ⚠️ FORK — shared-lib version ignorée |
| `RebirthClient.client.lua` | LavaTower | Non — UI only mais couleurs hardcodées | ⚠️ FORK — shared-lib RebirthHUD ignorée |
| `FuseMachineClient.client.lua` | LavaTower | Non — mécanique unique LT | ✅ OK — spécifique LT |
| `SlotTextStyle.client.lua` | LavaTower | Non — styling utility | ✅ OK |

---

## Résumé exécutif

**Modules 100% harmonisés :** 7/17 (AssignationSystem, BaseProgressionSystem, CarrySystem, DropSystem, IncomeSystem, RebirthSystem, RebirthCosmeticsSystem)

**Forks à migrer :** 2 côté serveur (`MonetizationHandler` LT, `UpgradeSystem` LT) + 2 côté client (`HUDController` LT, `RebirthClient` LT)

**Modules unused dans les deux jeux :** FilterSystem (21 fichiers), BrainrotInventoryService — potentiel dead code à clarifier

**Actions prioritaires :**

1. **Migrer `UpgradeSystem` LavaTower** → shared-lib avec config-driven fallbacks (le fork LT est à ~70% identique, delta = valeurs hardcodées)
2. **Migrer `MonetizationHandler` LavaTower** → shared-lib avec flag optionnel pour receipt handling (le fork LT est un subset simplifié)
3. **Importer `CollectSystem` dans LavaTower** → income offline non calculé côté LT actuellement
4. **Adopter `UITheme` dans les HUDs LavaTower** → `HUDController.client` et `RebirthClient.client` hardcodent leurs couleurs
5. **Investiguer FilterSystem** → 21 fichiers dans shared-lib, zéro import dans les deux jeux — dead code ou feature non déployée ?

**Risque actuel :**
- `UpgradeSystem` forké dans LT = tout fix/évolution shared-lib (formules coûts, prestige) ne s'applique pas à LT automatiquement
- `MonetizationHandler` forké dans LT = LT ne gère pas les receipts IAP → risque de perte de revenus si un achat échoue mid-process
- `FilterSystem` (21 fichiers) jamais importé = charge de maintenance pour zéro valeur actuellement
