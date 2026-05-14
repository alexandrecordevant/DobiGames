-- shared-lib/src/shared/UIConfig.lua
-- Design Tokens centralisés — source de vérité unique pour toute l'UI DobiGames
-- Utilisé par ShopHUD, FlowerPotHUD, MiniTutoHUD, IndexClient, HUDController, etc.

local UIConfig = {}

-- ═══════════════════════════════════════════════
-- DÉTECTION PLATEFORME
-- ═══════════════════════════════════════════════
local UserInputService    = game:GetService("UserInputService")
UIConfig.IsMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

-- ═══════════════════════════════════════════════
-- TYPOGRAPHIE — 4 niveaux, 2 polices
-- ═══════════════════════════════════════════════
UIConfig.Fonts = {
    Title = Enum.Font.GothamBold,
    Body  = Enum.Font.GothamMedium,
}

UIConfig.TextSizes = {
    H1      = UIConfig.IsMobile and 28 or 22,   -- Titre modale
    H2      = UIConfig.IsMobile and 20 or 16,   -- Nom item / section
    Body    = UIConfig.IsMobile and 16 or 14,   -- Description courante
    Caption = UIConfig.IsMobile and 13 or 11,   -- Métadonnées / labels
}

-- ═══════════════════════════════════════════════
-- BOUTONS — 3 tailles standardisées
-- ═══════════════════════════════════════════════
UIConfig.ButtonSizes = {
    Large = {
        Height   = UIConfig.IsMobile and 64 or 48,
        TextSize = UIConfig.IsMobile and 18 or 14,
    },
    Medium = {
        Height   = UIConfig.IsMobile and 52 or 40,
        TextSize = UIConfig.IsMobile and 16 or 13,
    },
    Small = {
        Height   = UIConfig.IsMobile and 40 or 32,
        TextSize = UIConfig.IsMobile and 14 or 12,
    },
}

-- ═══════════════════════════════════════════════
-- COULEURS
-- ═══════════════════════════════════════════════
UIConfig.Colors = {
    -- Fonds modales
    Overlay           = Color3.fromRGB(0,   0,   0),
    ModalBackground   = Color3.fromRGB(26,  26,  26),
    ModalBorder       = Color3.fromRGB(58,  58,  58),
    SectionBackground = Color3.fromRGB(42,  42,  42),

    -- Boutons actions
    GreenNormal  = Color3.fromRGB(76,  175, 80),
    GreenHover   = Color3.fromRGB(102, 187, 106),
    OrangeNormal = Color3.fromRGB(255, 152, 0),
    OrangeHover  = Color3.fromRGB(255, 167, 38),
    RedNormal    = Color3.fromRGB(229, 57,  53),
    RedHover     = Color3.fromRGB(239, 83,  80),
    GrayLocked   = Color3.fromRGB(66,  66,  66),
    GrayOwned    = Color3.fromRGB(55,  55,  55),

    -- Textes
    TextOnDark  = Color3.fromRGB(255, 255, 255),
    TextOnLight = Color3.fromRGB(20,  20,  20),
    TextLocked  = Color3.fromRGB(170, 170, 170),
    TextDim     = Color3.fromRGB(130, 130, 130),
    TextGold    = Color3.fromRGB(255, 213, 79),

    -- Raretés
    Rarities = {
        COMMON       = Color3.fromRGB(158, 158, 158),
        OG           = Color3.fromRGB(100, 150, 255),
        RARE         = Color3.fromRGB(66,  165, 245),
        EPIC         = Color3.fromRGB(171, 71,  188),
        LEGENDARY    = Color3.fromRGB(255, 213, 79),
        MYTHIC       = Color3.fromRGB(233, 30,  99),
        SECRET       = Color3.fromRGB(244, 67,  54),
        BRAINROT_GOD = Color3.fromRGB(255, 235, 59),
    },
}

-- ═══════════════════════════════════════════════
-- DIMENSIONS MODALES
-- ═══════════════════════════════════════════════
UIConfig.Modal = {
    WidthScale         = UIConfig.IsMobile and 0.92 or 0.5,
    WidthMaxPx         = UIConfig.IsMobile and 520  or 700,
    HeightScale        = UIConfig.IsMobile and 0.82 or 0.75,
    Padding            = UIConfig.IsMobile and 16   or 24,
    CloseButtonSize    = UIConfig.IsMobile and 44   or 34,
    CornerRadius       = 12,
    ScrollBarThickness = UIConfig.IsMobile and 6    or 4,
}

-- ═══════════════════════════════════════════════
-- ESPACEMENT
-- ═══════════════════════════════════════════════
UIConfig.Spacing = {
    XS = 4,
    SM = 8,
    MD = 16,
    LG = 24,
    XL = 32,
}

-- ═══════════════════════════════════════════════
-- HELPERS — Création d'éléments standardisés
-- ═══════════════════════════════════════════════

-- Crée un TextButton stylisé
-- sizeType  : "Large" | "Medium" | "Small"
-- colorType : "Green" | "Orange" | "Red" | "Gray"
function UIConfig.CreateButton(parent, sizeType, colorType, text, onClick)
    local sizes = UIConfig.ButtonSizes[sizeType] or UIConfig.ButtonSizes.Medium
    local bgMap = {
        Green  = UIConfig.Colors.GreenNormal,
        Orange = UIConfig.Colors.OrangeNormal,
        Red    = UIConfig.Colors.RedNormal,
        Gray   = UIConfig.Colors.GrayLocked,
    }

    local btn = Instance.new("TextButton")
    btn.Size            = UDim2.new(1, 0, 0, sizes.Height)
    btn.BackgroundColor3 = bgMap[colorType] or UIConfig.Colors.GrayLocked
    btn.TextColor3      = UIConfig.Colors.TextOnDark
    btn.Font            = UIConfig.Fonts.Title
    btn.TextSize        = sizes.TextSize
    btn.TextScaled      = false
    btn.Text            = text or ""
    btn.TextWrapped     = true
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent          = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, UIConfig.Modal.CornerRadius)
    if onClick then btn.MouseButton1Click:Connect(onClick) end
    return btn
end

-- Crée un TextLabel standardisé
-- sizeType : "H1" | "H2" | "Body" | "Caption"
function UIConfig.CreateLabel(parent, sizeType, text, color, xAlign)
    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, 0, 0, 0)
    lbl.AutomaticSize          = Enum.AutomaticSize.Y
    lbl.BackgroundTransparency = 1
    lbl.Text                   = text or ""
    lbl.TextColor3             = color or UIConfig.Colors.TextOnDark
    lbl.Font  = (sizeType == "H1" or sizeType == "H2") and UIConfig.Fonts.Title or UIConfig.Fonts.Body
    lbl.TextSize               = UIConfig.TextSizes[sizeType] or UIConfig.TextSizes.Body
    lbl.TextScaled             = false
    lbl.TextWrapped            = true
    lbl.TextXAlignment         = xAlign or Enum.TextXAlignment.Left
    lbl.Parent                 = parent
    return lbl
end

-- Crée la structure d'une modale (overlay + panel + header + scrollFrame)
-- Retourne { overlay, panel, content, xBtn, titleLbl }
function UIConfig.CreateModal(screenGui, title, onClose)
    local vp = workspace.CurrentCamera.ViewportSize
    local w  = math.min(math.floor(vp.X * UIConfig.Modal.WidthScale), UIConfig.Modal.WidthMaxPx)
    local h  = math.floor(vp.Y * UIConfig.Modal.HeightScale)
    local P  = UIConfig.Modal.Padding
    local CB = UIConfig.Modal.CloseButtonSize

    -- Fond obscurcissant
    local overlay = Instance.new("Frame")
    overlay.Size                   = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3       = UIConfig.Colors.Overlay
    overlay.BackgroundTransparency = 0.5
    overlay.BorderSizePixel        = 0
    overlay.ZIndex                 = 10
    overlay.Parent                 = screenGui

    -- Panneau principal
    local panel = Instance.new("Frame")
    panel.AnchorPoint            = Vector2.new(0.5, 0.5)
    panel.Size                   = UDim2.new(0, w, 0, h)
    panel.Position               = UDim2.new(0.5, 0, 0.5, 0)
    panel.BackgroundColor3       = UIConfig.Colors.ModalBackground
    panel.BackgroundTransparency = 0
    panel.BorderSizePixel        = 0
    panel.ZIndex                 = 11
    panel.Parent                 = screenGui
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, UIConfig.Modal.CornerRadius)
    local panelStroke = Instance.new("UIStroke", panel)
    panelStroke.Color     = UIConfig.Colors.ModalBorder
    panelStroke.Thickness = 1

    -- Hauteur du header
    local headerH = CB + P

    -- Titre
    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size                   = UDim2.new(1, -(CB + P * 2), 0, headerH)
    titleLbl.Position               = UDim2.new(0, P, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text                   = title or ""
    titleLbl.TextColor3             = UIConfig.Colors.TextOnDark
    titleLbl.Font                   = UIConfig.Fonts.Title
    titleLbl.TextSize               = UIConfig.TextSizes.H1
    titleLbl.TextScaled             = false
    titleLbl.TextXAlignment         = Enum.TextXAlignment.Left
    titleLbl.TextYAlignment         = Enum.TextYAlignment.Center
    titleLbl.ZIndex                 = 12
    titleLbl.Parent                 = panel

    -- Bouton fermer
    local xBtn = Instance.new("TextButton")
    xBtn.Size              = UDim2.new(0, CB, 0, CB)
    xBtn.Position          = UDim2.new(1, -(CB + P / 2), 0, P / 2)
    xBtn.BackgroundColor3  = UIConfig.Colors.GrayLocked
    xBtn.Text              = "X"
    xBtn.TextColor3        = UIConfig.Colors.TextOnDark
    xBtn.Font              = UIConfig.Fonts.Title
    xBtn.TextSize          = UIConfig.TextSizes.H2
    xBtn.TextScaled        = false
    xBtn.BorderSizePixel   = 0
    xBtn.ZIndex            = 12
    xBtn.Parent            = panel
    Instance.new("UICorner", xBtn).CornerRadius = UDim.new(0, UIConfig.Modal.CornerRadius)
    if onClose then xBtn.MouseButton1Click:Connect(onClose) end

    -- Séparateur
    local sep = Instance.new("Frame")
    sep.Size             = UDim2.new(1, -P * 2, 0, 1)
    sep.Position         = UDim2.new(0, P, 0, headerH)
    sep.BackgroundColor3 = UIConfig.Colors.ModalBorder
    sep.BorderSizePixel  = 0
    sep.ZIndex           = 12
    sep.Parent           = panel

    -- Zone scrollable
    local content = Instance.new("ScrollingFrame")
    content.Size                   = UDim2.new(1, -P * 2, 1, -(headerH + 2 + P))
    content.Position               = UDim2.new(0, P, 0, headerH + 2)
    content.BackgroundTransparency = 1
    content.BorderSizePixel        = 0
    content.ScrollBarThickness     = UIConfig.Modal.ScrollBarThickness
    content.ScrollBarImageColor3   = UIConfig.Colors.ModalBorder
    content.AutomaticCanvasSize    = Enum.AutomaticSize.Y
    content.CanvasSize             = UDim2.new(0, 0, 0, 0)
    content.ZIndex                 = 12
    content.Parent                 = panel

    return { overlay = overlay, panel = panel, content = content, xBtn = xBtn, titleLbl = titleLbl }
end

return UIConfig
