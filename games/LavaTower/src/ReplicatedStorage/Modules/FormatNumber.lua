-- ReplicatedStorage/Modules/FormatNumber.lua
-- Formate un montant avec suffixes (1K, 1M, 1B…)
-- 1 décimale uniquement si la valeur n'est pas ronde.
-- Extensible : ajouter un palier = une ligne dans PALIERS.

local FormatNumber = {}

-- Table ordonnée par seuil croissant
local PALIERS = {
    { seuil = 1e3,  suffixe = "K"   },
    { seuil = 1e6,  suffixe = "M"   },
    { seuil = 1e9,  suffixe = "B"   },
    { seuil = 1e12, suffixe = "T"   },
    { seuil = 1e15, suffixe = "Q"   },
    { seuil = 1e18, suffixe = "Qa"  },
    { seuil = 1e21, suffixe = "Sx"  },
    { seuil = 1e24, suffixe = "Sp"  },
    { seuil = 1e27, suffixe = "Oc"  },
    { seuil = 1e30, suffixe = "No"  },
    { seuil = 1e33, suffixe = "Dc"  },
    { seuil = 1e36, suffixe = "Ud"  },
    { seuil = 1e39, suffixe = "Dd"  },
    { seuil = 1e42, suffixe = "Td"  },
    { seuil = 1e45, suffixe = "Qad" },
    { seuil = 1e48, suffixe = "Qid" },
    { seuil = 1e51, suffixe = "Sxd" },
    { seuil = 1e54, suffixe = "Spd" },
    { seuil = 1e57, suffixe = "Ocd" },
    { seuil = 1e60, suffixe = "Nod" },
    { seuil = 1e63, suffixe = "Vg"  },
    { seuil = 1e66, suffixe = "Uvg" },
}

-- Formate un nombre en chaîne lisible avec suffixe.
-- n : nombre (peut être très grand)
function FormatNumber.format(n)
    n = tonumber(n) or 0

    -- En dessous de 1000 : affichage brut entier
    if n < 1e3 then
        return tostring(math.floor(n))
    end

    -- Boucle à l'envers pour trouver le palier le plus haut applicable
    local palier = nil
    for i = #PALIERS, 1, -1 do
        if n >= PALIERS[i].seuil then
            palier = PALIERS[i]
            break
        end
    end

    -- Sécurité : aucun palier trouvé (ne devrait pas arriver)
    if not palier then
        return tostring(math.floor(n))
    end

    local valeur = n / palier.seuil

    -- 1 décimale seulement si la valeur n'est pas ronde
    local texte
    if math.floor(valeur * 10) % 10 == 0 then
        texte = tostring(math.floor(valeur))
    else
        texte = string.format("%.1f", valeur)
    end

    return texte .. palier.suffixe
end

return FormatNumber
