-- SharedLib/Server/BrainrotPositioner.lua
-- Positionnement commun des Brainrots sur une surface :
--   • droit (Y vertical, pas d'inclinaison)
--   • bas du bounding box aligné sur la surface (corrige le bug des parties décalées)
--   • orienté vers baseCenter si fourni (face vers l'intérieur)
--
-- Utilisé par DropSystem (base slots) et BrainrotPlatformSpawner (plateformes LavaTower)

local BrainrotPositioner = {}

-- Positionne un modèle sur une surface.
--
-- Paramètres :
--   modele        : Model ou BasePart à repositionner (doit être in workspace ou parented)
--   surfaceY      : Y du dessus de la surface de dépôt
--                   (ex : touchPart.Position.Y + touchPart.Size.Y * 0.5)
--   posX, posZ    : position X/Z cible (centre du slot ou de la plateforme)
--   baseCenter    : Vector3 vers lequel le modèle doit regarder (nil = pas de rotation)
--   hauteurOffset : studs supplémentaires au-dessus de la surface (défaut 0)
--
-- Comportement :
--   Le bas du bounding box du modèle est placé à (surfaceY + hauteurOffset).
--   Cela garantit que les modèles de toutes tailles (COMMON = petit, LEGENDARY = grand)
--   reposent correctement sur la surface sans être à moitié enfouis.
function BrainrotPositioner.positionnerSurSurface(modele, surfaceY, posX, posZ, baseCenter, hauteurOffset)
    hauteurOffset = hauteurOffset or 0

    -- Décalage entre le pivot du modèle et le bas de son bounding box.
    -- pivotToBottom > 0  →  le pivot est AU-DESSUS du bas (cas normal).
    -- En plaçant le pivot à (surfaceY + pivotToBottom), le bas du modèle
    -- arrive exactement à surfaceY.
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
        -- Rotation purement horizontale : le modèle reste droit (Y vertical).
        -- On aplatit Y du lookTarget pour éviter toute inclinaison.
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

    pcall(function() modele:PivotTo(finalCF) end)
end

return BrainrotPositioner
