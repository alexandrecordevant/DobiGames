-- shared-lib/src/shared/UITheme.lua
-- Thème sombre neutre -- noir dominant, orange en accent (aligné LavaTower)

local UITheme = {}

-- ============================================================
-- Palette principale
-- ============================================================
UITheme.fondPrincipal    = Color3.fromRGB(10,  10,  10)   -- noir panel
UITheme.fondSecondaire   = Color3.fromRGB(20,  20,  20)   -- carte sombre
UITheme.fondBouton       = Color3.fromRGB(80,  140, 80)   -- vert discret
UITheme.fondBoutonRobux  = Color3.fromRGB(220, 110, 15)   -- orange accent
UITheme.fondBoutonDanger = Color3.fromRGB(140, 70,  70)   -- rouge discret
UITheme.fondBoutonRebirth= Color3.fromRGB(220, 110, 15)   -- orange accent
UITheme.texte            = Color3.fromRGB(220, 220, 220)  -- gris clair
UITheme.texteTitre       = Color3.fromRGB(220, 220, 220)  -- gris clair (même)
UITheme.texteSecondaire  = Color3.fromRGB(130, 130, 130)  -- gris moyen
UITheme.bordure          = Color3.fromRGB(60,  60,  60)   -- gris bordure
UITheme.bordureAccent    = Color3.fromRGB(220, 110, 15)   -- orange bordure
UITheme.barreVide        = Color3.fromRGB(30,  30,  30)   -- fond barre
UITheme.barrePleine      = Color3.fromRGB(80,  140, 80)   -- vert progression
UITheme.barreRebirth     = Color3.fromRGB(220, 110, 15)   -- orange rebirth

return UITheme
