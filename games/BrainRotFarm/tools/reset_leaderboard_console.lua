-- ============================================================
-- RESET LEADERBOARD GLOBAL — Console Studio
-- OrderedDataStore : GlobalLB_Coins_v1
-- Usage : coller dans la console Studio (F9 → onglet Server)
-- ⚠️  Supprime les scores du classement global (toutes les entrées)
-- ⚠️  Ne touche PAS aux données joueur (BrainRotIdleV1)
-- ============================================================

local DataStoreService = game:GetService("DataStoreService")

-- ID à retirer en priorité (dobidobane)
local TARGET_USER_ID = 10621969326

-- Nombre max d'entrées à parcourir (ODS paginé par 100)
local MAX_PAGES = 10

local ODS = DataStoreService:GetOrderedDataStore("GlobalLB_Coins_v1")

-- ── 1. Retirer l'entrée spécifique ──────────────────────────
local okDel, errDel = pcall(function()
    ODS:RemoveAsync(tostring(TARGET_USER_ID))
end)
if okDel then
    print(string.format("[LB-RESET] ✓ Entrée %d supprimée.", TARGET_USER_ID))
else
    warn("[LB-RESET] ✗ Échec suppression entrée cible : " .. tostring(errDel))
end

-- ── 2. Vider toutes les autres entrées ──────────────────────
print("[LB-RESET] Parcours du classement pour tout effacer...")

local totalSupprime = 0
local pages

local okGet, errGet = pcall(function()
    pages = ODS:GetSortedAsync(false, 100)
end)

if not okGet then
    warn("[LB-RESET] ✗ Impossible de lire l'ODS : " .. tostring(errGet))
    return
end

for pageNum = 1, MAX_PAGES do
    local okPage, pageData = pcall(function() return pages:GetCurrentPage() end)
    if not okPage or not pageData then
        warn("[LB-RESET] Erreur lecture page " .. pageNum)
        break
    end

    if #pageData == 0 then
        print("[LB-RESET] Leaderboard vide à la page " .. pageNum .. " — arrêt.")
        break
    end

    for _, entry in ipairs(pageData) do
        local uid = entry.key
        local score = entry.value
        local ok, err = pcall(function()
            ODS:RemoveAsync(uid)
        end)
        if ok then
            totalSupprime = totalSupprime + 1
            print(string.format("[LB-RESET]   supprimé uid=%s score=%d", uid, score))
        else
            warn(string.format("[LB-RESET]   ✗ uid=%s : %s", uid, tostring(err)))
        end
        -- Respect rate limit (60 écritures/min → ~1/s)
        task.wait(1.1)
    end

    if pages.IsFinished then
        print("[LB-RESET] Dernière page atteinte.")
        break
    end

    local okNext = pcall(function() pages:AdvanceToNextPageAsync() end)
    if not okNext then
        warn("[LB-RESET] AdvanceToNextPageAsync échoué.")
        break
    end
end

print(string.format("[LB-RESET] ✓ Terminé — %d entrées supprimées au total.", totalSupprime))
print("[LB-RESET]   → Le leaderboard se re-remplira naturellement à la prochaine connexion des joueurs.")
