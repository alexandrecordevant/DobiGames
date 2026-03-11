# Brain Rot Farm — Document de règles fonctionnelles

**Studio :** DobiGames
**Genre :** Collector / Tycoon
**Stack :** Roblox Studio + Rojo

---

## Setup développeur
```bash
cd games/BrainRotFarm
rojo serve
```
Studio → Plugins → Rojo → Connect

---

## À faire avant publish
- [ ] Créer Game Pass VIP (149 R$) → ID dans GameConfig.lua
- [ ] Créer Game Pass Offline Vault (199 R$) → ID dans GameConfig.lua
- [ ] Créer Game Pass Auto Collect (299 R$) → ID dans GameConfig.lua
- [ ] Créer Dev Product Lucky Hour (35 R$) → ID dans GameConfig.lua
- [ ] Créer Dev Product Secret Reveal (25 R$) → ID dans GameConfig.lua
- [ ] Créer Dev Product Skip Tier (50 R$) → ID dans GameConfig.lua
- [ ] Créer webhook Discord → URL dans GameConfig.lua
- [ ] Activer API Services sur roblox.com/develop
- [ ] Tester DataStore (save/load)
- [ ] Tester event automatique (EventIntervalleMinutes = 1 pour test)
- [ ] Publish sous DobiGames group

---

# 1. Présentation du jeu

## Concept

Brain Rot Farm est un jeu Roblox de type **Collector/Tycoon**.
Des créatures appelées **Brainrots** apparaissent dans des zones de spawn. Les joueurs les ramassent, les transportent jusqu'à leur base, et les convertissent en argent pour progresser.

## Objectif du joueur

Collecter le maximum de Brainrots, en priorisant les raretés élevées, pour accumuler des coins, améliorer sa base, et atteindre les niveaux de prestige les plus hauts.

## Boucle de gameplay principale

```
Brainrot spawn → Joueur explore → Ramasse → Transporte → Dépose en base → Coins → Upgrade → Recommence
```

---

# 2. Boucle de gameplay (core loop)

| Étape | Action | Résultat |
|-------|--------|----------|
| 1 | Un Brainrot apparaît dans la zone de spawn | Visible sur la map |
| 2 | Le joueur s'approche du Brainrot | ProximityPrompt affiché |
| 3 | Le joueur ramasse le Brainrot | Porté au-dessus de la tête |
| 4 | Le joueur marche jusqu'à sa base | Brainrot transporté |
| 5 | Le joueur dépose le Brainrot dans sa base | Brainrot converti en coins |
| 6 | Les coins s'accumulent | Accès aux upgrades |
| 7 | Le joueur achète des améliorations | Vitesse, capacité, gains augmentés |
| 8 | Retour à l'étape 1 | Boucle infinie |

---

# 3. Système de spawn des Brainrots

## Deux zones de spawn coexistent

### Champ individuel (base du joueur)

Chaque joueur possède une `SpawnArea` dans sa propre base clonée.

| Paramètre | Valeur |
|-----------|--------|
| Intervalle de spawn | 8 secondes |
| Max actifs simultanés | 6 par base |
| Raretés disponibles | Common, Epic |
| Ramassage | Propriétaire uniquement |
| Expiration Common | 45 secondes |
| Expiration Epic | 60 secondes |

### Champ commun (Workspace.ChampCommun)

Zone partagée entre tous les joueurs. Spawn les raretés supérieures.

| Paramètre | Valeur |
|-----------|--------|
| Intervalle de spawn | 45 secondes |
| Max actifs simultanés | 4 au total |
| Max Legendary simultanés | 2 |
| Max Mythic simultanés | 1 |
| Max God simultanés | 1 |
| Raretés disponibles | Legendary, Mythic, God |
| Ramassage | Tout le monde (premier arrivé) |
| Expiration Legendary/Mythic | 120 secondes |
| Expiration God | Jamais (persiste jusqu'au ramassage) |

## Logique d'apparition

- La rareté est tirée aléatoirement selon les probabilités pondérées.
- La position est aléatoire dans les limites XZ de la zone de spawn.
- Le Brainrot sort de terre avec une animation de croissance (scale 0.01 → 1).
- Un billboard affiche la rareté au-dessus du modèle.

---

# 4. Rareté des Brainrots

| Rareté | Probabilité | Valeur (coins) | Zone de spawn | Intérêt joueur |
|--------|------------|----------------|---------------|----------------|
| Common | 55% | 10 | Individuelle | Revenu de base stable |
| Epic | 25% | 35 | Individuelle | Rentable à collecter activement |
| Legendary | 12% | 100 | Commune | Nécessite de surveiller la map |
| Mythic | 6% | 300 | Commune | Très rentable, compétition entre joueurs |
| God | 2% | 1 000 | Commune | Événement rare, annoncé au chat serveur |

### Notes de design

- Les probabilités sont renormalisées automatiquement sur le sous-ensemble disponible (champ individuel = Common+Epic seulement, donc 55%+25% = 100% renormalisé).
- Le God ne disparaît jamais : il attend qu'un joueur le ramasse.
- Un Brainrot God déclenche une annonce chat serveur au spawn et au ramassage.

---

# 5. Transport des Brainrots

## Ramassage

Le joueur s'approche d'un Brainrot. Un `ProximityPrompt` apparaît :

| Rareté | HoldDuration (maintien requis) |
|--------|-------------------------------|
| Common | 0s (instantané) |
| Epic | 0s (instantané) |
| Legendary | 0s (instantané) |
| Mythic | 0.5s |
| God | 2s |

Le HoldDuration est une friction intentionnelle pour les raretés élevées : le joueur doit rester sur place, créant de la compétition sur le champ commun.

## Transport

- Le Brainrot est affiché au-dessus de la tête du joueur via un `Weld` sur le `HumanoidRootPart`.
- Un seul Brainrot transporté à la fois (MVP).
- Pas de malus de vitesse en MVP (peut être ajouté en upgrade inverse).

## Vol

- Sur le champ individuel : vol impossible (ProximityPrompt vérifie `player == propriétaire`).
- Sur le champ commun : premier arrivé, premier servi. Compétition loyale.

---

# 6. Bases des joueurs

## Structure d'une base

Chaque joueur reçoit un clone du `Model` `BaseTemplate` depuis `ReplicatedStorage`.
Le clone est nommé `Base_[UserId]` et positionné sur un slot libre (`Slot_1` à `Slot_6` dans `Workspace/Slots`).

### Composants attendus dans BaseTemplate

| Composant | Type | Rôle |
|-----------|------|------|
| `SpawnArea` | BasePart | Zone de spawn des Brainrots individuels |
| `DepotZone` | BasePart | Zone de dépôt des Brainrots collectés |
| Décorations | Models | Personnalisation visuelle |

## Dépôt

Quand le joueur entre dans la `DepotZone` avec un Brainrot :
1. Le Brainrot est retiré de sa tête.
2. Sa valeur (× multiplicateur du joueur) est créditée en coins.
3. Un effet visuel (`CollectVFX`) est joué côté client.
4. Le HUD est mis à jour.

## Gestion des bases

- À la déconnexion : la base est détruite, le slot est libéré.
- Si tous les slots sont occupés : le joueur est mis en file d'attente (warn dans les logs en MVP).

---

# 7. Système économique

## Sources de revenus

| Source | Montant |
|--------|---------|
| Dépôt d'un Brainrot Common | 10 × multiplicateur |
| Dépôt d'un Brainrot Epic | 35 × multiplicateur |
| Dépôt d'un Brainrot Legendary | 100 × multiplicateur |
| Dépôt d'un Brainrot Mythic | 300 × multiplicateur |
| Dépôt d'un Brainrot God | 1 000 × multiplicateur |
| Income offline | coinsParMinute × 0.1 × heuresAbsence (max 8h) |

## Multiplicateur

Le multiplicateur est calculé par `CollectSystem.GetMultiplier(data)` en fonction du `tier` (niveau d'upgrade) et du `prestige` du joueur.

- Tier 0 = multiplicateur de base (x1)
- Chaque upgrade augmente le multiplicateur
- Chaque prestige applique un bonus permanent (`PrestigeMultiplier = x2.0`)

## Progression

| Action | Coût | Effet |
|--------|------|-------|
| Upgrade (tier++) | 100 × 2.5^tier coins | Multiplicateur de gains |
| Prestige | Réinitialise coins et tier | Bonus multiplicateur permanent |

---

# 8. Limites et équilibre du jeu

| Limite | Valeur MVP | Raison |
|--------|-----------|--------|
| Max Brainrots sur le champ individuel | 6 | Évite la saturation de la base |
| Max Brainrots sur le champ commun | 4 | Maintient la rareté des hauts rangs |
| Expiration des Brainrots | 25–120s selon rareté | Nettoie la map, crée l'urgence |
| Max slots de base | 6 | Limite le nombre de joueurs simultanés |
| Income offline max | 8 heures | Évite l'accumulation passive infinie |

### Règles anti-inflation

- Les Brainrots disparus ne génèrent pas de coins (pas de revenu passif automatique).
- Le joueur doit être actif pour gagner des coins (transport obligatoire).
- Le multiplicateur est plafonné indirectement par le coût exponentiel des upgrades.

---

# 9. Boosts et améliorations

## Upgrades in-game (coins)

| Upgrade | Effet | Impacte |
|---------|-------|---------|
| Tier++ | +multiplicateur de gains | Valeur de chaque Brainrot |
| Prestige | +bonus permanent | Tous les gains futurs |

## Game Passes (Robux)

| Pass | Prix | Effet |
|------|------|-------|
| VIP | 149 R$ | Multiplicateur permanent |
| Offline Vault | 199 R$ | Revenu offline amélioré |
| Auto Collect | 299 R$ | Collecte automatique |

## Dev Products (usage unique)

| Produit | Prix | Effet |
|---------|------|-------|
| Lucky Hour | 35 R$ | Spawn × multiplier pendant 5 min |
| Secret Reveal | 25 R$ | Révèle la rareté d'un Brainrot caché |
| Skip Tier | 50 R$ | Passe directement au tier suivant |

### Principe de design

Les boosts accélèrent le confort sans court-circuiter la boucle principale. Un joueur sans Robux peut tout débloquer, simplement plus lentement.

---

# 10. Configuration technique

Tous les paramètres critiques sont centralisés dans des modules Lua.

## `BrainrotSpawnConfig.lua` — ReplicatedStorage/Modules

```lua
Config.Raretes            -- probabilités, valeurs, couleurs, tailles
Config.ChampIndividuel    -- SpawnInterval, MaxActifs, Expiration
Config.ChampCommun        -- SpawnInterval, MaxActifs, MaxParRarete, HoldDuration
```

## `GameConfig.lua` — ReplicatedStorage/Modules

```lua
GameConfig.BaseSpawnRate          -- fréquence de spawn de base
GameConfig.CoutUpgradeBase        -- coût du premier upgrade
GameConfig.CoutUpgradeMultiplier  -- progression exponentielle des coûts
GameConfig.PrestigeMultiplier     -- bonus par prestige
GameConfig.OfflineIncomeMultiplier -- ratio income offline
GameConfig.MaxOfflineHeures       -- plafond offline
GameConfig.EventIntervalleMinutes -- fréquence des events automatiques
```

## `BrainRotSpawner.lua` — ServerScriptService

```lua
CHAMP.X_MIN / X_MAX / Z_MIN / Z_MAX  -- zone de spawn (champ de la map)
CHAMP.Y                               -- hauteur d'apparition
MAX_BRAINROTS_MAP                     -- max simultanés sur la map
DESPAWN_SECONDES                      -- durée de vie d'un Brainrot
SPAWN_INTERVALLE                      -- secondes entre chaque spawn
```

---

# 11. Futurs ajouts possibles

## Événements rares

- **Admin Abuse** : spawn x50 pendant 45 min (déjà implémenté, hebdomadaire)
- **Lucky Hour** : spawn x10 pendant 5 min (achetable)
- **Double Value Weekend** : tous les Brainrots valent x2 pendant un week-end
- **Mystery Event** : rareté inconnue jusqu'au ramassage

## Brainrots spéciaux

- **Cursed Brainrot** : vaut beaucoup mais fuit le joueur (se déplace)
- **Giant Brainrot** : nécessite 2 joueurs pour le transporter (coopération)
- **Golden Brainrot** : apparaît une fois par serveur, valeur maximale
- **Seasonal Brainrots** : modèles thématiques selon les saisons (Halloween, Noël)

## Zones supplémentaires

- **Zone VIP** : champ réservé aux Game Pass VIP, raretés supérieures garanties
- **Zone Prestige** : accessible uniquement aux joueurs Prestige 3+
- **Zone Commando** : champ PvP où le vol de Brainrots est autorisé

## Progression avancée

- **Collection** : débloquer un badge/récompense en collectant 1 de chaque rareté
- **Leaderboard** : classement global par coins totaux collectés
- **Guildes/Teams** : partager une base commune avec des amis
- **Missions journalières** : collecter X Brainrots d'une rareté donnée pour un bonus

---

*Document rédigé pour DobiGames — Brain Rot Farm MVP*
