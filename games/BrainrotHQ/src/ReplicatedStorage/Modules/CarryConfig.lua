-- CarryConfig.lua
-- ReplicatedStorage/Modules/CarryConfig
-- Configuration centrale du système carry brainrot.
-- Partagé entre Server et Client via require().

local CarryConfig = {}

-- Offset du brainrot porté par rapport au HumanoidRootPart du joueur.
-- (0, 4.5, 0) = au-dessus de la tête.
CarryConfig.CARRY_OFFSET = CFrame.new(0, 4.5, 0)

-- Durée de maintien du ProximityPrompt avant ramassage (secondes).
CarryConfig.HOLD_DURATION = 1.5

-- Distance max pour que le ProximityPrompt soit visible/activable (studs).
CarryConfig.MAX_DISTANCE = 8

-- Distance max tolérée entre le joueur et le brainrot au moment du pickup (anti-exploit).
CarryConfig.MAX_PICKUP_DISTANCE = 15

-- Vitesse de marche pendant le carry.
CarryConfig.CARRY_WALKSPEED = 12

-- JumpPower / JumpHeight pendant le carry (0 = impossible de sauter).
CarryConfig.CARRY_JUMPPOWER = 0

-- Récompense par défaut accordée lors d'un dépôt réussi.
CarryConfig.DEFAULT_REWARD = 50

-- Nom de l'attribut Cash sur le joueur (IntValue ou Attribute).
CarryConfig.CASH_ATTRIBUTE = "Cash"

-- Animation ID pour l'animation "bras levés" (AnimationTrack).
-- Remplacer par l'ID Roblox réel avant publication.
CarryConfig.ANIMATION_ID = "rbxassetid://YOUR_ANIMATION_ID"

-- true  = bras levés via Motor6D (pas besoin d'animation uploadée, marche en local)
-- false = AnimationTrack (nécessite un ID d'animation valide uploadé sur Roblox)
CarryConfig.USE_MOTOR6D = true

-- Délai avant que le brainrot réapparaisse à sa position originale après dépôt (secondes).
CarryConfig.RESPAWN_DELAY = 8

return CarryConfig
