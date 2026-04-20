-- shared-lib/src/shared/FormatNumber.lua
-- Formate un nombre avec suffixes (1K, 1M, 1B…)
-- Accessible depuis le serveur ET le client.
-- 1 décimale uniquement si la valeur n'est pas ronde.

local FormatNumber = {}

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

function FormatNumber.format(n)
    n = tonumber(n) or 0

    if n < 1e3 then
        return tostring(math.floor(n))
    end

    local palier = nil
    for i = #PALIERS, 1, -1 do
        if n >= PALIERS[i].seuil then
            palier = PALIERS[i]
            break
        end
    end

    if not palier then
        return tostring(math.floor(n))
    end

    local valeur = n / palier.seuil

    local texte
    if math.floor(valeur * 10) % 10 == 0 then
        texte = tostring(math.floor(valeur))
    else
        texte = string.format("%.1f", valeur)
    end

    return texte .. palier.suffixe
end

return FormatNumber
