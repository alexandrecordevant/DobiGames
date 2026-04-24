-- SharedLib/Server/BrainrotPositioner.lua
-- Positionnement commun des Brainrots sur une surface :
--   . droit (Y vertical, pas d'inclinaison)
--   . bas du bounding box aligne sur la surface (corrige le bug des parties decalees)
--   . oriente vers baseCenter si fourni (face vers l'interieur)
--
-- Utilise par DropSystem (base slots) et BrainrotPlatformSpawner (plateformes LavaTower)

local BrainrotPositioner = {}

-- Cherche le pivot principal d'un modele dans l'ordre :
--   1. HumanoidRootPart  (brainrots standards)
--   2. FakeRootPart      (ex : Strawberry Elephant, Los Noobinis)
--   3. PrimaryPart       (tout autre modele avec pivot explicite)
local function getPivot(modele)
    return modele:FindFirstChild("HumanoidRootPart")
        or modele:FindFirstChild("FakeRootPart")
        or modele.PrimaryPart
end

-- Garantit que PrimaryPart est assigne avant tout appel a PivotTo.
-- PivotTo echoue silencieusement si PrimaryPart est nil, laissant
-- le modele a sa position d'origine et causant l'explosion visuelle
-- des parts sur le slot.
-- Doit etre appele avant GetPivot() pour que le calcul pivotToBottom
-- soit coherent avec le pivot effectivement utilise par PivotTo.
local function assurerPrimaryPart(modele)
    if not modele.PrimaryPart then
        local fakePart = modele:FindFirstChild("FakeRootPart")
        if fakePart then
            modele.PrimaryPart = fakePart
        end
    end
end

-- Positionne un modele sur une surface.
--
-- Parametres :
--   modele        : Model ou BasePart a repositionner (doit etre in workspace ou parented)
--   surfaceY      : Y du dessus de la surface de depot
--                   (ex : touchPart.Position.Y + touchPart.Size.Y * 0.5)
--   posX, posZ    : position X/Z cible (centre du slot ou de la plateforme)
--   baseCenter    : Vector3 vers lequel le modele doit regarder (nil = pas de rotation)
--   hauteurOffset : studs supplementaires au-dessus de la surface (defaut 0)
--
-- Comportement :
--   Le bas du bounding box du modele est place a (surfaceY + hauteurOffset).
--   Cela garantit que les modeles de toutes tailles (COMMON = petit, LEGENDARY = grand)
--   reposent correctement sur la surface sans etre a moitie enfouis.
function BrainrotPositioner.positionnerSurSurface(modele, surfaceY, posX, posZ, baseCenter, hauteurOffset)
    hauteurOffset = hauteurOffset or 0

    -- Assigner PrimaryPart si absent avant tout calcul de pivot.
    -- Indispensable pour Strawberry Elephant et Los Noobinis qui utilisent
    -- FakeRootPart comme pivot principal a la place de HumanoidRootPart.
    assurerPrimaryPart(modele)

    -- Decalage entre le pivot du modele et le bas de son bounding box.
    -- pivotToBottom > 0  ->  le pivot est AU-DESSUS du bas (cas normal).
    -- En placant le pivot a (surfaceY + pivotToBottom), le bas du modele
    -- arrive exactement a surfaceY.
    -- GetPivot() utilise PrimaryPart si assigne, donc le calcul est coherent
    -- avec le pivot effectivement utilise par PivotTo() ci-dessous.
    local pivotToBottom = 0
    pcall(function()
        local bbCF, bbSize = modele:GetBoundingBox()
        local pivotCF      = modele:GetPivot()
        pivotToBottom = pivotCF.Position.Y - (bbCF.Position.Y - bbSize.Y / 2)
    end)

    local targetY   = surfaceY + pivotToBottom + hauteurOffset
    local targetPos = Vector3.new(posX, targetY, posZ)

    local finalCF
    if baseCenter then
        -- Rotation purement horizontale : le modele reste droit (Y vertical).
        -- On aplatit Y du lookTarget pour eviter toute inclinaison.
        local lookTarget = Vector3.new(baseCenter.X, targetY, baseCenter.Z)
        local dir        = lookTarget - targetPos
        if dir.Magnitude > 0.1 then
            -- CFrame.lookAt avec up explicite = (0,1,0) garantit l'absence d'inclinaison.
            finalCF = CFrame.lookAt(targetPos, lookTarget, Vector3.new(0, 1, 0))
        else
            finalCF = CFrame.new(targetPos)
        end
    else
        finalCF = CFrame.new(targetPos)
    end

    -- PivotTo deplace le modele entier (toutes les parts bougent ensemble),
    -- ce qui est correct quelle que soit la structure interne du modele.
    pcall(function() modele:PivotTo(finalCF) end)
end

-- Expose getPivot pour les appelants externes qui en auraient besoin.
BrainrotPositioner.getPivot = getPivot

return BrainrotPositioner
