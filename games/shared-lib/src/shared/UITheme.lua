-- shared-lib/src/shared/UITheme.lua
-- Thème "Farm Brain Rot" — marron bois + jaune blé + vert farm

local UITheme = {}

-- ============================================================
-- Palette principale
-- ============================================================
UITheme.fondPrincipal    = Color3.fromRGB(45, 30, 10)    -- marron bois foncé
UITheme.fondSecondaire   = Color3.fromRGB(60, 40, 15)    -- marron bois moyen
UITheme.fondBouton       = Color3.fromRGB(80, 140, 30)   -- vert farm
UITheme.fondBoutonRobux  = Color3.fromRGB(220, 160, 0)   -- jaune blé doré
UITheme.fondBoutonDanger = Color3.fromRGB(180, 50, 30)   -- rouge danger
UITheme.fondBoutonRebirth= Color3.fromRGB(200, 140, 0)   -- jaune blé foncé
UITheme.texte            = Color3.fromRGB(255, 240, 180)  -- jaune blé clair
UITheme.texteTitre       = Color3.fromRGB(255, 220, 50)   -- jaune blé vif
UITheme.texteSecondaire  = Color3.fromRGB(200, 180, 120)  -- beige blé
UITheme.bordure          = Color3.fromRGB(140, 100, 30)   -- bois doré
UITheme.bordureAccent    = Color3.fromRGB(220, 180, 50)   -- jaune blé bordure
UITheme.barreVide        = Color3.fromRGB(40, 40, 20)     -- fond barre
UITheme.barrePleine      = Color3.fromRGB(80, 200, 40)    -- vert farm progression
UITheme.barreRebirth     = Color3.fromRGB(220, 160, 0)    -- jaune blé rebirth

return UITheme
