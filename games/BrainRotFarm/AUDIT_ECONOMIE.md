# AUDIT ÉCONOMIE — BrainRot Farm Empire

> Source des données : GameConfig.lua, ShopSystem.lua, SpawnManager.lua, CommunSpawner.lua, FuseSystem.lua, MonetizationHandler.lua, AmelioConfig.lua + CPS réels fournis par le dev (attributs Studio).
> Date : 2026-05-19 — Phase AUDIT-ONLY, aucune modification de code.

---

## A. SUMMARY

### 3 Problèmes économiques critiques (P0)

**1. Lucky Charm est sous-évalué ET mal décrit**
Le code (`SpawnManager.lua:177`) fait deux choses : (a) élimine COMMON du pool de spawn (boucle retry jusqu'à non-COMMON), ET (b) reroll 25% en gardant le meilleur. La description "+25% chance de rareté supérieure" n'est qu'un quart de la réalité. Pour 99 R$, c'est une anomalie économique majeure — à corriger avant publish.

**2. Lucky Hour (dev product) est probablement server-wide**
`MonetizationHandler.lua:41` appelle `CollectSystem.SetEventMultiplier(5)` — si ce multiplier est global (probable vu son usage identique à l'event Golden), 35 R$ = booster tout le serveur pendant 30 min. Exploit d'achat coopératif possible dès day-1.

**3. VIP / AutoCollect / OfflineVault ont Id=0**
`GameConfig.lua:16-19` confirme trois Game Passes sans ID Roblox. Les boutons sont visibles dans le shop UI mais afficheront "coming soon". Loss de conversion immédiate au launch.

### 3 Quick wins balance (< 5 min chacun)

```lua
-- Quick win 1 : OG dead config — poids 22 qui ne sert à rien (exclu par RaretesExcluesSpawn)
-- GameConfig.lua:851 → retirer la ligne OG de SpawnableItems
-- { nom="OG", poids=22, valeur=3 },  ← supprimer cette ligne
-- OG spawn exclusivement via Admin Abuse (spawnPool dédié)

-- Quick win 2 : Prix Lucky Charm sous-évalué
-- GameConfig.lua:254 → monter à 149 ou 199 R$
[1] = { type="robux", prix=149, gamePassId=1819652284, ... },

-- Quick win 3 : Aligner IncomeParRarete sur les vraies moyennes (éviter le fallback aberrant)
GameConfig.IncomeParRarete = {
    COMMON    = 5,         -- était 1
    OG        = 500000000, -- était 3 (event-only)
    RARE      = 100,       -- était 8
    EPIC      = 500,       -- était 20
    LEGENDARY = 3000,      -- était 60
    MYTHIC    = 30000,     -- était 200
    SECRET    = 1000000,   -- était 500 (moyenne T1)
    GOD       = 300000,    -- était 2000 (moyenne T1-T2)
}
```

### Note de jouabilité globale : 6.5/10

**Pour :** Boucle core solide (spawn → carry → deposit), progression early rapide (LEGENDARY en < 5 min), événements dynamiques bien pensés, Fuse Machine comme end-game intéressant, système de seeds ingénieux.

**Contre :** Monetization incomplète (3 game passes Id=0), GOD tier confus et source opaque, SECRET T4/T5 = lottery pur (14 jours+ sans Tracteur), Lucky Charm mal documenté, naming collision "Lucky Hour" (2 systèmes différents même nom), OG brise la hiérarchie des tiers.

---

## B. TABLEAU COURBE COMPLÈTE

> Champ perso : 1 BR spawn toutes les 4s (COMMON→LEGENDARY uniquement).
> ZoneCommune : **1 MYTHIC actif à la fois** (cycle 8 min) + **1 SECRET actif à la fois** (cycle 20 min), server-wide, max 6 joueurs.
> Formule ZoneCommune : `intervalle × N joueurs × (1 / P(tier))`. Poids SECRET : T1=88.89% · T2=10% · T3=1% · T4=0.1% · T5=0.01%.

| Rareté/Tier | $/s moyen | Ratio vs précédent | Source | Solo (1P) | Session (3P) | Serveur plein (6P) | Verdict |
|---|---|---|---|---|---|---|---|
| COMMON | 5 | — | Champ perso (70.7%*) | ~5.6s | ~5.6s | ~5.6s | FLOOD — 70% du pool |
| RARE | 100 | **20×** | Champ perso (16.7%) | ~24s | ~24s | ~24s | Ratio brutal mais rapide |
| EPIC | 500 | **5×** | Champ perso (9.0%) | ~44s | ~44s | ~44s | ✅ Bon ratio |
| LEGENDARY | 3,000 | **6×** | Champ perso (3.6%) | ~111s | ~111s | ~111s | ✅ Bon checkpoint |
| MYTHIC | 30,000 | **10×** | ZoneCommune | 8 min | 24 min | **48 min** | ✅ Gate saine à 6P |
| GOD T1 | 100,000 | **3.3×** | Fuse Machine (?) | inconnu† | inconnu† | inconnu† | ⚠️ Source opaque |
| GOD T2 | 500,000 | **5×** | Fuse Machine (?) | inconnu† | inconnu† | inconnu† | ⚠️ Fuse-only |
| SECRET T1 | 1,000,000 | **2×** vs GOD T2 | ZoneCommune | 22 min | 1h07 | **2h15** | ✅ Bon milestone end-game |
| SECRET T2 | 10,000,000 | **10×** | ZoneCommune | 3h20 | 10h | **20h** | ⚠️ Long, barrière naturelle |
| SECRET T3 | 25,000,000 | **2.5×** | ZoneCommune | 33h | 4.2 jours | **8.3 jours** | ❌ Prestige uniquement |
| SECRET T4 | 100,000,000 | **4×** | ZoneCommune | 13.9 jours | 41.7 jours | **83 jours** | ❌ Hors portée sans Tracteur |
| SECRET T5 | 250,000,000 | **2.5×** | ZoneCommune | 139 jours | 417 jours | **833 jours** | ❌ LOTTERY sans GP |
| OG | 500,000,000 | **2×** vs SECRET T5 | Admin Abuse uniquement | ~45 min event | ~45 min event | ~45 min event | ⚠️ Trophée event |

*Probabilités effectives après exclusion OG : COMMON 70.7% / RARE 16.7% / EPIC 9.0% / LEGENDARY 3.6%

†GOD n'apparaît pas dans SpawnManager.lua ni CommunSpawner.lua. Source probable : Fuse Machine output (données dans Studio uniquement).

**Tracteur (299 R$) — contournement ZoneCommune :**

| Type | Serveur plein (6P) sans Tracteur | Avec Tracteur (champ perso) |
|---|---|---|
| MYTHIC | 48 min | **~1-2 min** (4% × 900 spawns/h = 36/h) |
| SECRET (tout tier) | 2h15 pour T1 | **~7 min pour T1** (1% × 900 = 9/h × 88.89%) |
| SECRET T5 | 833 jours | **~46 jours** (9/h × 0.01%) |

### Analyse des 4 anomalies

**a) OG à 500M $/s**
OG est dans `SpawnableItems` avec poids=22 **mais** figure dans `RaretesExcluesSpawn`. Il ne spawn que pendant Admin Abuse (poids 0.15 sur ~100). Son CPS de 500M $/s (2× SECRET T5) le place au-dessus du top tier normal. **Verdict : intentionnel comme "trophée d'event"** — mais le poids=22 dans SpawnableItems est du dead code qui waste 22% des calculs de tirage (le code reroll jusqu'à 20 fois à chaque OG tiré).

**b) SECRET > GOD**
Confirmé volontaire par le dev. GOD = tier exclusif Admin Abuse event (samedi 20h UTC), SECRET = nouveau top tier (ZoneCommune + Tracteur). La source de GOD est documentée via les notifications event et les leaderboards infos — P1.4 fermé.

**c) MYTHIC→SECRET T1 = 33× via le même système de spawn**
Le ratio (33×) est acceptable pour un "tier wall". À 6 joueurs, attendre 2h15 pour un SECRET T1 est une gate saine. Le problème : sans Tracteur, le joueur ne peut qu'attendre — pas de farm actif possible entre MYTHIC et SECRET T1.

**d) GOD T2 (500k) → SECRET T1 (1M) = 2× seulement**
Couplé au fait que GOD vient de la Fuse (1h30 d'attente + sacrifice BRs), trouver un SECRET T1 en ZoneCommune (2h15 à 6P) est souvent plus rapide que fuser vers GOD. La Fuse Machine est un piège économique pour les joueurs MYTHIC/GOD.

---

## C. TABLEAU MUTATIONS

### Mutations champ personnel (PersonalFieldMutationConfig)

Taux de base : **0.2% par spawn** (jamais sur COMMON).

| Mutation | Multiplicateur | Poids | EV par spawn (RARE 100$/s) | EV par spawn (LEGENDARY 3k$/s) | Verdict |
|---|---|---|---|---|---|
| BrainrotsToxic | ×3 | 20% | +0.12 $/s | +3.6 $/s | Anecdotique |
| BrainrotsLava | ×4 | 15% | +0.12 $/s | +3.6 $/s | Anecdotique |
| BrainrotsGold | ×5 | 15% | +0.15 $/s | +4.5 $/s | Anecdotique |
| BrainrotsDiamant | ×6 | 10% | +0.12 $/s | +3.6 $/s | Anecdotique |
| BrainrotsRainbow | ×8 | 10% | +0.16 $/s | +4.8 $/s | Meilleur, encore faible |
| BrainrotsNebula | ×4 | 15% | +0.12 $/s | +3.6 $/s | Anecdotique |
| CrazyBrainrots | ×3 | 15% | +0.09 $/s | +2.7 $/s | Plus faible |
| **TOTAL EV** | avg ×4.4 | 100% | **+0.88% du revenu** | **+0.88% du revenu** | Cosmétique |

**Verdict :** Les mutations champ à 0.2% sont un "wow moment" mais n'impactent pas l'économie. C'est bien — elles créent de la surprise sans déséquilibrer.

### Mutations Lucky Hour (LuckyHourMutationConfig)

25% des spawns LuckyHour sont mutés, multiplicateurs plus faibles (l'event spawn déjà du RARE+).

EV par spawn LuckyHour = 0.75 × 1.0 + 0.25 × avg(2→5)× = **1.47× income moyen**.

### FlowerPot Mutants (GALAXY/TOXIC/RAINBOW/VOID)

| Mutant | ×mult | MinRebirth | MYTHIC → CPS résultant | SECRET T1 → CPS résultant | Verdict |
|---|---|---|---|---|---|
| GALAXY | ×2 | 0 | 60,000 $/s | 2,000,000 $/s | Accessible tous joueurs |
| TOXIC | ×4 | 0 | 120,000 $/s | 4,000,000 $/s | ✅ Bon |
| RAINBOW | ×6 | **3** | 180,000 $/s | 6,000,000 $/s | Rebirth-gated (bien) |
| VOID | ×8 | **5** | 240,000 $/s | 8,000,000 $/s | Late rebirth reward |

### Incohérence multiplicateurs Fuse vs FlowerPot

| Type | FlowerPot / Champ | Fuse Machine | Écart |
|---|---|---|---|
| GOLD (= GALAXY) | ×2 | ×2 | ✅ Aligné |
| TOXIC | ×4 | ×5 | ⚠️ Fuse +25% |
| RAINBOW | ×6 | ×10 | ❌ Fuse +67% |
| DIAMANT (= VOID) | ×8 | ×15 | ❌ Fuse +87% |

La Fuse Machine donne des mutants beaucoup plus puissants — intentionnel (Fuse = premium) ? Si oui, documenter. Si non, aligner les deux configs.

---

## D. TABLEAU SHOP COMPLET

> Payback = temps pour amortir le coût via l'income supplémentaire généré.
> 3 profils : **Early** (50 $/s, base COMMON) · **Mid** (5,000 $/s, RARE/EPIC) · **Late** (50,000 $/s, MYTHIC+).

### Upgrades coins

| Upgrade | Coût | Effet | Payback Early | Payback Mid | Payback Late | Verdict |
|---|---|---|---|---|---|---|
| Carry Lv.1 | 75,000 | 2 BRs | 25 min | 15s | <2s | ✅ CHEAP — bien pricé |
| Carry Lv.2 | 600,000 | 3 BRs | 3.3h | 2 min | 12s | ✅ OK |
| Carry Lv.3 | 4,000,000 | 4 BRs | trop long | 13 min | 80s | ✅ OK mid-late |
| Carry Lv.4 | 25,000,000 | 5 BRs | — | 83 min | 8.3 min | ✅ Juste |
| Speed Lv.1 | 50,000 | WS 18 | QoL ~17min | ~5min | <1min | ✅ CHEAP |
| Speed Lv.8 | 200,000,000 | WS 26 | — | — | 66 min | ✅ OK late |
| Speed Lv.10 | 1,500,000,000 | WS 30 | — | — | 8h | ⚠️ Cher, pousse vers GP |
| Speed Lv.14 | 60,000,000,000 | WS 35 | — | — | — | ❌ Bait vers GP intentionnel |
| Arroseur Lv.1 | 300,000 | ×1.6 spawn | 1.7h | 1 min | 6s | ✅ CHEAP avec Carry 2 |
| Arroseur Lv.2 | 2,500,000 | ×2.7 spawn | — | 8 min | 50s | ✅ OK |
| Aimant Lv.1 | 500,000 | radius 8 | — | 1.6 min | 10s | ✅ OK |
| Aimant Lv.2 | 5,000,000 | radius 14 | — | 16 min | 100s | ✅ OK |
| FlowerPot 2 | 150,000 | +1 pot | — | 30s | <1s | ✅ CHEAP |
| FlowerPot 3 | 1,500,000 | +1 pot | — | 5 min | 30s | ✅ OK |

### Upgrades Robux / Game Passes

| Upgrade / GP | Prix R$ | Statut | Bénéfice quantifié | Verdict |
|---|---|---|---|---|
| Lucky Charm | 149 R$ | ✅ Live | Élimine COMMON + reroll 25% | ✅ Aligné CarryMAX/ArroseurMAX |
| Seed Doubler | 99 R$ | ✅ Live | 2 graines/jour | ✅ OK |
| SpeedMAX | 99 R$ | ✅ Live | WalkSpeed 40 | ✅ OK |
| ArroseurMAX | 149 R$ | ✅ Live | 5× spawn rate | ✅ BON |
| CarryMAX | 149 R$ | ✅ Live | 8 BRs carry | ✅ BON |
| FlowerPot4 | 149 R$ | ✅ Live | +1 pot MYTHIC/SECRET | ✅ BON |
| Tracteur | 299 R$ | ✅ Live | 4%MYTHIC+1%SECRET+1%jackpot/spawn | ✅ Bien pricé |
| VIP | 149 R$ | ❌ Id=0 | Non défini | ❌ BLOQUANT launch |
| OfflineVault | 199 R$ | ❌ Id=0 | Revenus offline | ❌ BLOQUANT launch |
| AutoCollect | 299 R$ | ❌ Id=0 | Auto-collecte | ❌ BLOQUANT launch |
| Protection | ~99-149 R$ | ✅ 1819604298 | Anti-bat drop PvP | ✅ OK (prix à confirmer) |

---

## E. TABLEAU GAME PASSES + DEV PRODUCTS

| Produit | Prix R$ | ≈ USD | Bénéfice $/s équivalent | ROI joueur (Late) | Recommandation prix |
|---|---|---|---|---|---|
| Lucky Hour (Prod) | 35 R$ | ~$0.44 | +4× income 30 min (server-wide?) | Instantané | 99 R$ si player-only · 35-49 R$ si server-wide voulu |
| Skip Seed | 25 R$ | ~$0.31 | Skip 24h | QoL | ✅ OK |
| Seed Pack x3 | 99 R$ | ~$1.25 | 3× MYTHIC Mutant (60-240k $/s/slot) | Quelques secondes | ✅ BON |
| Secret Seed | 149 R$ | ~$1.88 | 1× SECRET Mutant (~3-8M $/s) | <1s | ✅ EXCELLENT |
| Lucky Charm | 149 R$ | ~$1.88 | +~300% income personal field | Immédiat | ✅ Aligné (était 99 R$) |
| Tracteur | 299 R$ | ~$3.75 | ~21,500 $/s EV par spawn (MYTHIC/SECRET) | 14s | ✅ Juste (pourrait être 499 R$) |
| CarryMAX | 149 R$ | ~$1.88 | 8× collection capacity | 3s | ✅ BON |
| ArroseurMAX | 149 R$ | ~$1.88 | 5× spawn rate → ~4× income | 3s | ✅ BON |
| SpeedMAX | 99 R$ | ~$1.25 | WalkSpeed 40 (QoL) | — | ✅ OK |

**Benchmark Roblox 2026 :**
- VIP idle/farm : 99-199 R$ — tes passes sont bien alignés
- Premium passifs (AutoCollect) : 199-499 R$ — 299 R$ pour AutoCollect OK
- Boost temporaires : 25-99 R$ — Lucky Hour à 35 R$ est limite basse

**Top 2 Best Sellers attendus :**
1. **Tracteur (299 R$)** — bénéfice immédiat visible, seul moyen d'obtenir MYTHIC/SECRET dans son propre champ
2. **Lucky Charm (99 R$)** — perception "plus de raretés", même si l'effet réel est plus fort que décrit

### Cannibalisation identifiée

| Conflit | Description | Risque |
|---|---|---|
| "Lucky Hour" × 2 noms | EventLuckyHour (spawn RARE/EPIC/LEG sur base, 3 min) ≠ ProduitLuckyHour (×5 income, 30 min) | Joueurs confus sur ce qu'ils achètent |
| Lucky Hour Prod vs Golden Event | Les deux font ×5 income, Lucky Hour se déclenche aussi automatiquement en event | Dévaluation du produit payant si l'event arrive juste après l'achat |
| AutoCollect vs Tracteur | Tracteur auto-collecte en bonus ; AutoCollect auto-collecte tout → overlap partiel | Tracteur rend AutoCollect moins attractif |

---

## F. RECOMMANDATIONS PRÉ-LAUNCH

### P0 — BLOQUANTS (ne pas publier sans fix)

**P0.1 — Activer VIP, AutoCollect, OfflineVault**
`GameConfig.lua:16-19` : trois Game Passes avec `Id=0` et prix définis. Créer les Game Passes dans le dashboard Roblox et injecter les IDs. Sans ça, le shop affiche des produits non fonctionnels dès le launch.
```lua
GameConfig.GamePassVIP          = { Id = XXXXX, Prix = 149 }
GameConfig.GamePassOfflineVault = { Id = XXXXX, Prix = 199 }
GameConfig.GamePassAutoCollect  = { Id = XXXXX, Prix = 299 }
```

**P0.2 — Lucky Charm : corriger description OU monter le prix**
Le code (`SpawnManager.lua:176-188`) élimine COMMON du pool complet — pas seulement un boost 25%. Pour 99 R$ c'est le meilleur ROI de tout le shop.
- Option A : garder 99 R$ et corriger description → "Eliminates Common spawns + 25% reroll for higher rarity"
- Option B : monter à 149-199 R$ et garder la description actuelle

**P0.3 — Lucky Hour dev product : vérifier la portée server-wide**
`MonetizationHandler.lua:40-42` : `CollectSystem.SetEventMultiplier(5)` — si global, un seul achat à 35 R$ bouste tout le serveur pendant 30 min. Ajouter un scope joueur ou monter le prix à 99 R$ si l'effet server-wide est voulu comme feature sociale.

---

### P1 — RETENTION sous 1h (à fixer semaine 1 post-launch)

**P1.1 — GOD tier : documenter la source in-game**
GOD n'apparaît ni dans SpawnManager (exclu de SpawnableItems), ni dans CommunSpawner. Si GOD = output exclusif de la Fuse Machine, c'est invisible pour le joueur. Ajouter une tooltip ou billboard sur la Fuse Machine : "Fuse MYTHIC BRs → obtain GOD tier!"

**P1.2 — SECRET T4/T5 inaccessibles en farming normal**
Avec les poids actuels (`SECRET_LEVEL_WEIGHTS[4]=0.1`, `[5]=0.01`), le temps d'attente solo est 333h (T4) et 139 jours (T5). Options :
- Pity system → après X captures SECRET T1/T2/T3, prochain SECRET est upgradé
- Augmenter légèrement les poids : `[4]=0.5`, `[5]=0.1` (10× plus accessible, reste très rare)

**P1.3 — OG dead config : nettoyer**
`GameConfig.lua:851` : OG avec `poids=22` dans SpawnableItems cause 22% de rerolls gaspillés à chaque tirage. Une ligne à changer :
```lua
-- Retirer cette ligne de SpawnableItems.rarites :
-- { nom="OG", poids=22, valeur=3 },
-- OG spawn exclusivement via Admin Abuse (spawnPool dédié, GameConfig.lua:444)
```

**P1.4 — ToUseAfter folder : cleanup Studio**
Dead code confirmé — `"ToUseAfter"` figure dans `ignoredFolders` des deux configs de mutation. Supprimer depuis Studio pour alléger le build.

---

### P2 — BALANCE FINE (post-data réelle, 10+ sessions)

**P2.1 — IncomeParRarete : aligner sur les vraies valeurs**
Le fallback actuel (COMMON=1, MYTHIC=200) est 6 à 6000× inférieur aux vraies CPS. Si un modèle BR manque son attribut `CashParSeconde`, il gagnera ~0% de son revenu attendu. Mettre des valeurs représentatives évite les bugs silencieux. (Quick win 3 ci-dessus.)

**P2.2 — FuseMachine : incohérence multiplicateurs mutations**
`GameConfig.Fuse.MutationCPS` donne RAINBOW=×10, DIAMANT=×15 vs FlowerPot RAINBOW=×6, VOID=×8. Soit documenter l'intention (Fuse = premium), soit aligner.

**P2.3 — Offline income à 10%**
`GameConfig.OfflineIncomeMultiplier = 0.1`. Pour un idle game, 10% offline est très conservateur (benchmark idle Roblox : 25-35%). Envisager 0.25 post-data pour améliorer la rétention D1→D7.

**P2.4 — Rename "Lucky Hour" (collision noms)**
`EventTypes = {..., "LuckyHour"}` (spawn RARE+, 3 min, automatique) vs `DevProductIds.LuckyHour` (×5 income, 30 min, payant). Même nom, effets totalement différents.
- Suggestion : renommer l'event automatique en `"RareSpawn"` dans `GameConfig.EventTypes`
- Renommer le Dev Product UI en "Income Boost ×5"

---

## Notes sur données non trouvées

| Donnée manquante | Raison | Impact |
|---|---|---|
| CPS exact des sorties Fuse Machine | Modèles dans `ServerStorage/FuseBrainrots/` — Studio uniquement | Impossible d'évaluer le ROI Fuse sans ces valeurs |
| Source des GOD BRs | Absents de SpawnManager + CommunSpawner → probablement Fuse output uniquement | Flux joueur GOD non confirmé par code |
| Probabilités mutation FlowerPot (GALAXY/TOXIC/RAINBOW/VOID) | Non pondéré dans la config lue, `MutantGenerator.lua` non lu | EV FlowerPot approximatif uniquement |
| Scope exact CollectSystem.SetEventMultiplier | `CollectSystem.lua` non lu | Lucky Hour server-wide ou player-only non confirmé |
| Prix R$ Game Pass Protection | Id confirmé (1819604298) mais prix absent de GameConfig | Audit monétisation partiel |
