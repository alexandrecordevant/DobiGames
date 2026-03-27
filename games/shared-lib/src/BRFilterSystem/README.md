# Système de Filtres BR — BrainRotFarm

## Vue d'ensemble

Tous les BRs sont modifiés via des **filtres modulaires** appliqués par `FilterManager`.
**Aucune modification directe** n'est autorisée (`part.Color`, `ScaleTo`, `Instance.new("BillboardGui")`).

## Principe

Un BR = combinaison de filtres appliqués dans l'ordre :

1. **Rarity** — couleur de référence + effets base par rareté
2. **Scale** — Miniature / Normal / Large / Geant
3. **Billboard** — HUD texte au-dessus du BR
4. **State** — Pickupable / Carried / Deposited
5. **Visual** — optionnel : Glow, Trail, Sparkles
6. **Element** — optionnel : ElementEau / Feu / Terre / Vent (mutants)

## Usage

### Spawn normal

```lua
local FilterManager = require(game.ReplicatedStorage.SharedLib.BRFilterSystem.FilterManager)

FilterManager.Apply(br, {
    {Name = "RarityCOMMON"},
    {Name = "Normal"},
    {Name = "Billboard", Params = {Text = "COMMON", Color = Color3.fromRGB(200,200,200)}},
})
```

### BR Mutant (FlowerPot)

```lua
FilterManager.Apply(br, {
    {Name = "ElementEau"},
    {Name = "Normal"},
    {Name = "Billboard", Params = {Text = "🌊 Mutant EAU", Color = Color3.fromRGB(0,150,255)}},
})
```

### BR déposé sur base

```lua
FilterManager.Apply(br, {
    {Name = "Deposited"},
    {Name = "Miniature"},
    {Name = "Billboard", Params = {Text = "RARE", Color = Color3.fromRGB(0,120,255)}},
})
```

### Mettre à jour un Billboard (ex: countdown)

```lua
-- Accéder directement au filtre Billboard pour mise à jour
local BillboardFilter = require(game.ReplicatedStorage.SharedLib.BRFilterSystem.Filters.Visual.Billboard)
BillboardFilter.Update(br, "MYTHIC · 30s", Color3.fromRGB(148, 0, 211))
```

## Catégories de filtres

### Scale/
| Filtre    | Échelle | Usage                        |
|-----------|---------|------------------------------|
| Miniature | 0.5×    | Carried, Deposited           |
| Normal    | 1.0×    | Spawn standard               |
| Large     | 1.5×    | ChampCommun MYTHIC/SECRET    |
| Geant     | 2.5×    | Événements spéciaux          |

### Rarity/
`RarityCOMMON`, `RarityOG`, `RarityRARE`, `RarityEPIC`, `RarityLEGENDARY`, `RarityMYTHIC`, `RaritySECRET`

Chaque filtre Rarity :
- Stocke l'attribut `Rarete` sur le BR (lu par IncomeSystem)
- Ajoute effets visuels progressifs (EPIC → PointLight, LEGENDARY → Sparkles, MYTHIC/SECRET → particules)
- Colore les parts si `params.AppliquerCouleur = true` (utilisé pour mutants)

### Element/
`ElementEau`, `ElementFeu`, `ElementTerre`, `ElementVent`

Chaque filtre Element :
- Teinte toutes les BaseParts avec la couleur élémentaire
- Ajoute un ParticleEmitter élémentaire
- Ajoute un PointLight coloré
- Stocke l'attribut `ElementType`

### Visual/
| Filtre    | Effet              |
|-----------|--------------------|
| Glow      | PointLight générique|
| Trail     | Trail de traîne    |
| Sparkles  | Sparkles Roblox    |
| Billboard | HUD texte          |

### State/
| Filtre    | Effet                                             |
|-----------|---------------------------------------------------|
| Pickupable| Crée ProximityPrompt "PickupPrompt"               |
| Carried   | Supprime ProximityPrompt + Billboard              |
| Deposited | Désactive ProximityPrompt, ancre les parts        |

## Créer un nouveau filtre

1. Copier `Filters/Template.lua` dans la catégorie appropriée
2. Renommer le fichier ET le module Lua
3. Implémenter `Apply(brModel, params)`
4. Ajouter le nom dans `FilterRegistry.lua` (table `FILTRES_VALIDES`)
5. Tester : `FilterManager.Apply(br, {{Name = "MonFiltre"}})`

## Règles obligatoires

```lua
-- ✅ Toujours via FilterManager
FilterManager.Apply(br, { {Name = "RarityCOMMON"}, ... })

-- ❌ Jamais directement
part.Color = Color3.fromRGB(...)
brModel:ScaleTo(0.5)
Instance.new("BillboardGui")
```

1. Toujours appliquer via `FilterManager.Apply()`
2. Toujours inclure un filtre Scale
3. Toujours vérifier `brModel.PrimaryPart` dans un filtre
4. Nommer les instances créées (pour que `FilterManager.RemoveAll()` puisse les supprimer)
5. Commentaires en français (convention DobiGames)

## Debugging

```lua
-- Voir les filtres appliqués à un BR
local filtres = FilterManager.GetApplied(br)
print("Filtres appliqués:", table.concat(filtres, ", "))

-- Vérifier si un filtre spécifique est actif
if FilterManager.HasFilter(br, "ElementEau") then
    print("Ce BR est un mutant eau")
end

-- Reset complet
FilterManager.RemoveAll(br)

-- Réappliquer
FilterManager.Apply(br, { {Name = "Normal"}, {Name = "RarityCOMMON"} })
```
