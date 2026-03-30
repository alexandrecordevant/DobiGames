# HARDCODED_VALUES.md — Valeurs BRF-specific dans shared-lib
> Généré le 2026-03-30 — Audit technique DobiGames
> Focus : violations dans shared-lib/ uniquement

---

## RED FLAGS — Valeurs hardcodées critiques

### FilterRegistry.lua
```
❌ GetRarityColor("BRAINROT_GOD") → Color3.fromRGB(255, 140, 0)
   → Devrait lire GameConfig.Rarities[rarity].Color

❌ GetRarityColor("MYTHIC") → Color3.fromRGB(148, 0, 211)
   → Devrait lire GameConfig.Rarities["MYTHIC"].Color

❌ GetRarityColor("SECRET") → Color3.fromRGB(255, 255, 255)
   → Devrait lire GameConfig.Rarities["SECRET"].Color

❌ Noms des filtres "RarityMYTHIC", "RaritySECRET", "BRAINROT_GOD"
   → Zoo reskin n'a pas ces raretés → filtre introuvable → erreur silencieuse
```
**Impact reskin :** Filtre visuel incorrect sur tous les jeux sauf BRF.

---

### RarityMYTHIC.lua (Filter)
```
❌ Couleur hardcodée (148, 0, 211) — violet MYTHIC BRF
❌ Particules configurées spécifiquement pour l'esthétique BRF
❌ PointLight avec intensité calibrée pour BRF

→ Devrait lire depuis GameConfig.Rarities.MYTHIC.Color
→ Devrait lire depuis GameConfig.Rarities.MYTHIC.ParticleConfig
```
**Impact reskin :** Filtre inutilisable si le jeu n'a pas la rareté "MYTHIC".

---

### RaritySECRET.lua (Filter)
```
❌ Feu rouge hardcodé (couleur + intensité)
❌ Sparkles blancs hardcodés
❌ Nom "SECRET" encodé en dur dans la logique conditionnelle

→ Devrait lire depuis GameConfig.Rarities.SECRET.VisualConfig
```
**Impact reskin :** Identique à MYTHIC — inutilisable sans rareté SECRET.

---

### ElementEau.lua, ElementFeu.lua, ElementTerre.lua, ElementVent.lua
```
❌ Système d'éléments = feature exclusive FlowerPot de BRF
❌ Noms "EAU", "FEU", "TERRE", "VENT" codés en dur
❌ Textures et particules spécifiques à l'univers BRF

→ Devrait être dans BrainRotFarm/Systems/FlowerPotSystem/
→ Complètement hors périmètre shared-lib
```
**Impact reskin :** Ces filtres ne seront jamais utilisés par Zoo ou Ocean — code mort dans shared-lib.

---

### MonetizationHandler.lua
```
❌ require(FlowerPotSystem) → dépendance directe sur BRF-specific
   → shared-lib NE DOIT PAS dépendre de systèmes BRF

❌ Produit "LuckyHour" hardcodé (ligne 43)
❌ Produit "SkipSeedTimer" hardcodé → feature FlowerPot exclusive BRF
❌ Produit "SeedPack×3" hardcodé → feature FlowerPot exclusive BRF
❌ Produit "SecretSeed" hardcodé → feature FlowerPot exclusive BRF

→ Devrait lire depuis GameConfig.DeveloperProducts
→ Callbacks injectés pour produits custom (FlowerPot gère son propre produit)
```
**Impact reskin :** CRITIQUE — MonetizationHandler plantera sur Zoo (FlowerPotSystem inexistant).

---

### EventManager.lua
```
❌ types = {"NightMode", "MeteorDrop", "Rain", "Golden", "LuckyHour", "DoubleCoins"}
   → Events BRF hardcodés en dur
   → Zoo n'a pas de "MeteorDrop" ou "Rain" (thème incohérent)

→ Devrait lire depuis GameConfig.EventTypes
```
**Impact reskin :** Events inadaptés au thème du jeu (pluie dans un jeu spatial ?).

---

### PickupSystem.lua
```
❌ RARETE_COULEURS = {COMMON=..., UNCOMMON=..., RARE=..., ...} hardcodé
   → Toutes les couleurs de raretés BRF codées en dur

❌ Animations spéciales si rarity == "BRAINROT_GOD" → couleur rainbow
❌ Animations spéciales si rarity == "SECRET" → pulse effect

→ Devrait lire depuis GameConfig.Rarities[].Color
→ Devrait lire depuis GameConfig.Rarities[].SpecialAnimation
```
**Impact reskin :** Billboard de pickup avec mauvaises couleurs sur reskins.

---

### RebirthSystem.lua
```
❌ Ligne 63-65 : fallback rareté "BRAINROT_GOD" (condition rebirth niveau 5+)
   → Zoo n'a pas de "BRAINROT_GOD"

→ Devrait lire depuis GameConfig.RebirthConfig.RequiredRarity[level]
```
**Impact reskin :** Condition rebirth brisée sur les reskins (rareté introuvable).

---

### UITheme.lua
```
❌ Palette couleurs thème "Farm Brain Rot" (marron bois + jaune blé + vert ferme)
   → Zoo devrait avoir palette bleue/verte animale
   → Ocean devrait avoir palette bleu/turquoise

→ Devrait lire depuis GameConfig.UITheme.{fondPrincipal, fondBouton, texte}
```
**Impact reskin :** Interface visuellement incohérente avec le thème du jeu.

---

### BrainrotInventoryService.lua
```
❌ Nom du service : "BrainrotInventoryService" (BRF dans le nom)
❌ RemoteEvent "BrainrotCollected" hardcodé

→ Devrait s'appeler "CollectibleInventoryService"
→ Devrait utiliser GameConfig.CollectibleName pour nommer l'event
```
**Impact reskin :** Nom trompeur — pas bloquant mais confusant pour maintenance.

---

### RebirthCosmeticsSystem.lua
```
❌ PALIERS_COSMETIQUES = {[1]=..., [3]=..., [5]=..., [10]="REBIRTH_GOD"}
   → "REBIRTH_GOD" label hardcodé BRF
   ❌ Auras et effets codés en dur (couleurs BRF)

→ Devrait lire depuis GameConfig.RebirthCosmetics
```
**Impact reskin :** Cosmétiques Rebirth avec textes/couleurs BRF sur reskins.

---

### DataStoreManager.lua (BRF - pour référence)
```
❌ DataStore name = "BrainRotIdleV1" hardcodé
   → Devrait être GameConfig.DataStoreName

❌ Clés inventory : COMMON, OG, RARE, EPIC, LEGENDARY, MYTHIC, SECRET, BRAINROT_GOD
   → BRF-specific dans DataStoreManager (correct car BRF-specific)
   → À répliquer dans DataStoreManager propre pour chaque reskin
```
**Note :** DataStoreManager est BRF-specific — pas une violation. Mais le nom du DS devrait venir de Config.

---

## Fichiers shared-lib PROPRES (aucune valeur BRF hardcodée)
- ✅ FilterManager.lua
- ✅ BaseProgressionSystem.lua
- ✅ AssignationSystem.lua
- ✅ CollectSystem.lua (lit Config.Raretes)
- ✅ CarrySystem.lua
- ✅ DropSystem.lua
- ✅ BatSystem.lua
- ✅ SafeZoneTracker.lua
- ✅ RespawnInvincibility.lua
- ✅ NotificationHandler.client.lua
- ✅ BatController.client.lua
- ✅ Filtres visuels (Billboard, Glow, Trail, Sparkles, Scale×4)
- ✅ Filtres State (Pickupable, Deposited, Carried)

---

## Résumé par criticité

| Criticité | Fichiers | Impact |
|-----------|----------|--------|
| ❌ CRITIQUE | MonetizationHandler, FilterRegistry | Crash garanti sur reskins |
| ❌ ÉLEVÉ | EventManager, PickupSystem, Rarity filters (MYTHIC/SECRET) | Comportement incorrect |
| ⚠️ MOYEN | RebirthSystem, UITheme, BrainrotInventoryService, RebirthCosmeticsSystem | Incohérence visuelle/logique |
| ⚠️ FAIBLE | BatEquipHandler, Element filters | Couplage nommage, code mort |
