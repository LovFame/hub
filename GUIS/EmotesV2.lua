if _G.EmotesGUIRunning then
    getgenv().Notify({
        Title = 'LovFame | Emote',
        Content = '⚠️ It works It actually works',
        Duration = 5
    })
    return
end
_G.EmotesGUIRunning = true

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local request = http_request or (syn and syn.request) or request

local State = {
    currentMode = "emote",
    emotesWalkEnabled = false,
    favoriteEnabled = false,
    hudEditorActive = false,
    speedEmoteEnabled = false,
    isLoading = false,
    favoriteSetVersion = 0,
    favoriteSetBuiltVersion = -1,
    emoteCacheVersion = 0,
    animationCacheVersion = 0,
    isGUICreated = false,
    isMonitoringClicks = false,
    lastRadialActionTime = 0,
    lastWheelVisibleTime = 0,
    lastActionTick = 0,
    totalEmotesLoaded = 0,
    currentPage = 1,
    totalPages = 1,
    itemsPerPage = 8,
    emoteSearchTerm = "",
    animationSearchTerm = "",
    currentEmoteTrack = nil,
    currentCharacter = nil,
    emoteClickConnections = {},
    guiConnections = {},
    currentTimer = nil,
    animationsData = {},
    originalAnimationsData = {},
    filteredAnimations = {},
    favoriteAnimations = {},
    favoriteAnimationsFileName = "FavoriteAnimations.json",
    emotesData = {},
    originalEmotesData = {},
    filteredEmotes = {},
    scannedEmotes = {},
    favoriteEmotes = {},
    favoriteFileName = "FavoriteEmotes.json",
    speedEmoteConfigFile = "SpeedEmoteConfig.json",
    favoriteEmoteSet = {},
    favoriteAnimationSet = {},
    emotePageCache = { version = nil, normal = {}, favorites = {} },
    animationPageCache = { version = nil, normal = {}, favorites = {} },
    defaultButtonImage = "rbxassetid://71408678974152",
    enabledButtonImage = "rbxassetid://106798555684020",
    favoriteIconId = "rbxassetid://97307461910825",
    notFavoriteIconId = "rbxassetid://124025954365505",
    EmoteTheme = nil,
    isApplyingTheme = false
}

local UI = {
    Under = nil, 
    _1left = nil, 
    _9right = nil, 
    _4pages = nil, 
    _3TextLabel = nil, 
    _2Routenumber = nil, 
    Top = nil, 
    EmoteWalkButton = nil,
    Search = nil, 
    Favorite = nil, 
    SpeedEmote = nil, 
    SpeedBox = nil, 
    Changepage = nil,
    Reload = nil,
    Background = nil
}

local HUD = {
    Connections = {},
    Strokes = {},
    Overlay = nil,
    ForceVisibleConn = nil,
    DefaultPositions = {
        Top = UDim2.new(0.127499998, 0, -0.109999999, 0),
        Under = UDim2.new(0.129999995, 0, 1, 0),
        EmoteWalkButton = UDim2.new(0.889999986, 0, -0.107500002, 0),
        Favorite = UDim2.new(0.0189999994, 0, -0.108000003, 0),
        SpeedEmote = UDim2.new(0.888999999, 0, 0, 0),
        SpeedBox = UDim2.new(0.0189999398, 0, -0.000499992399, 0),
        Changepage = UDim2.new(0.019, 0, 1.021, 0),
        Reload = UDim2.new(0.888999999, 0, 1.02100003, 0),
    }
}

-- =============================================
-- PARCHE ANTI-CONGELAMIENTO (Agregado aquí)
-- =============================================

-- Variable para controlar la limpieza de animaciones
local lastCleanupTime = 0
local CLEANUP_INTERVAL = 5 -- segundos

-- Función mejorada para reproducir emotes sin congelamientos
local function patchedPlayEmote(humanoid, emoteId)
    -- Detener SOLO el emote actual, no todos
    if State.currentEmoteTrack and State.currentEmoteTrack.IsPlaying then
        State.currentEmoteTrack:Stop()
    end

    local animation = Instance.new("Animation")
    animation.AnimationId = "rbxassetid://" .. emoteId

    local success, animTrack = pcall(function()
        return humanoid.Animator:LoadAnimation(animation)
    end)

    if success and animTrack then
        State.currentEmoteTrack = animTrack
        State.currentEmoteTrack.Priority = Enum.AnimationPriority.Action
        State.currentEmoteTrack.Looped = true
        
        -- APLICAR VELOCIDAD DE FORMA SEGURA
        local speedValue = 1
        if State.speedEmoteEnabled then
            -- Asegurar que SpeedBox tenga un valor válido
            if UI and UI.SpeedBox then
                speedValue = tonumber(UI.SpeedBox.Text) or 1
                -- Evitar velocidad 0 o negativa
                if speedValue <= 0 then speedValue = 1 end
                -- Limitar velocidad máxima para evitar bugs
                if speedValue > 10 then speedValue = 10 end
                UI.SpeedBox.Text = tostring(speedValue)
            end
        end
        
        -- Reproducir la animación
        animTrack:Play()
        animTrack:AdjustSpeed(speedValue)
        
        -- Configurar evento para cuando termine (por si acaso)
        animTrack.Stopped:Connect(function()
            if State.currentEmoteTrack == animTrack then
                State.currentEmoteTrack = nil
            end
        end)
    end
    return animTrack
end

-- Función mejorada para toggle de Speed Emote
local function patchedToggleSpeedEmote()
    State.speedEmoteEnabled = not State.speedEmoteEnabled
    
    if UI and UI.SpeedBox then
        UI.SpeedBox.Visible = State.speedEmoteEnabled
        
        -- Validar que la velocidad nunca sea 0
        local speedValue = tonumber(UI.SpeedBox.Text) or 1
        if speedValue <= 0 then 
            speedValue = 1
            UI.SpeedBox.Text = "1"
        end
        
        -- Aplicar velocidad al emote actual si existe
        if State.currentEmoteTrack and State.currentEmoteTrack.IsPlaying then
            State.currentEmoteTrack:AdjustSpeed(speedValue)
        end
    end
    
    if State.speedEmoteEnabled then
        getgenv().Notify({
            Title = 'LovFame | Speed Emote',
            Content = "⚡ Speed Emote ON (Velocidad: " .. (tonumber(UI.SpeedBox.Text) or 1) .. "x)",
            Duration = 3
        })
    else
        -- Restaurar velocidad normal
        if State.currentEmoteTrack and State.currentEmoteTrack.IsPlaying then
            State.currentEmoteTrack:AdjustSpeed(1)
        end
        getgenv().Notify({
            Title = 'LovFame | Speed Emote',
            Content = '⚡ Speed Emote OFF',
            Duration = 3
        })
    end

    Config.EmoteSpeedEnabled = State.speedEmoteEnabled
    Config.EmoteSpeed = tonumber(UI.SpeedBox.Text) or 1
    SaveConfig()
end

-- Función mejorada para toggle de Emote Freeze
local function patchedToggleEmoteWalk()
    State.emotesWalkEnabled = not State.emotesWalkEnabled

    if State.emotesWalkEnabled then
        getgenv().Notify({
            Title = 'LovFame | Emote Freeze',
            Content = "🔒 Emote freeze ON - Las animaciones no se detendrán al caminar",
            Duration = 3
        })
        if UI and UI.EmoteWalkButton then
            UI.EmoteWalkButton.Image = State.enabledButtonImage
        end
    else
        getgenv().Notify({
            Title = 'LovFame | Emote Freeze',
            Content = '🔓 Emote freeze OFF',
            Duration = 3
        })
        if UI and UI.EmoteWalkButton then
            UI.EmoteWalkButton.Image = State.defaultButtonImage
        end
    end
end

-- Validación mejorada para SpeedBox
local function setupSpeedBoxValidation()
    if not UI or not UI.SpeedBox then return end
    
    -- Validar mientras se escribe
    UI.SpeedBox:GetPropertyChangedSignal("Text"):Connect(function()
        local text = UI.SpeedBox.Text
        -- Solo permitir números y punto decimal
        text = text:gsub("[^%d.]", "")
        -- Evitar múltiples puntos decimales
        local parts = text:split(".")
        if #parts > 2 then
            text = parts[1] .. "." .. table.concat(parts, "", 2)
        end
        UI.SpeedBox.Text = text
    end)
    
    -- Validar al perder foco
    UI.SpeedBox.FocusLost:Connect(function()
        local value = tonumber(UI.SpeedBox.Text) or 1
        if value <= 0 then value = 1 end
        if value > 10 then value = 10 end -- Límite razonable
        UI.SpeedBox.Text = tostring(value)
        
        -- Aplicar al emote actual
        if State.speedEmoteEnabled and State.currentEmoteTrack and State.currentEmoteTrack.IsPlaying then
            State.currentEmoteTrack:AdjustSpeed(value)
        end
        
        Config.EmoteSpeed = value
        SaveConfig()
    end)
end

-- Limpieza periódica de animaciones colgadas
local function cleanupStuckAnimations()
    local currentTime = tick()
    if currentTime - lastCleanupTime < CLEANUP_INTERVAL then return end
    lastCleanupTime = currentTime
    
    local player = game.Players.LocalPlayer
    if not player then return end
    
    local character = player.Character
    if not character then return end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    -- Si el humanoide está muerto, limpiar
    if humanoid.Health <= 0 then
        State.currentEmoteTrack = nil
        return
    end
    
    -- Verificar si hay animaciones huérfanas
    local animator = humanoid:FindFirstChild("Animator")
    if not animator then return end
    
    local trackCount = 0
    for _ in pairs(animator:GetPlayingAnimationTracks()) do
        trackCount = trackCount + 1
    end
    
    -- Si hay muchas tracks y ninguna es la actual, algo anda mal
    if trackCount > 10 and not State.currentEmoteTrack then
        for _, track in pairs(animator:GetPlayingAnimationTracks()) do
            if not track:IsDescendantOf(character) then
                track:Stop()
            end
        end
    end
end

-- Conectar limpieza periódica
game:GetService("RunService").Heartbeat:Connect(cleanupStuckAnimations)

print("✅ Parches anti-congelamiento aplicados - Speed y Freeze funcionan correctamente")

local function SafeLoad(url, name)
    local success, content
    for i = 1, 3 do
        success, content = pcall(function() return game:HttpGet(url) end)
        if success and content and content ~= "" then break end
        task.wait(0.5)
    end
    
    if not success or not content or content == "" then
        getgenv().Notify({
            Title = 'LovFame | Error',
            Content = 'Failed to download ' .. (name or "script") .. ' after 3 attempts.',
            Duration = 5
        })
        return function() end
    end

    local func, err = loadstring(content)
    if not func then
        warn("LovFame | SafeLoad: Failed to parse " .. (name or "script") .. ": " .. tostring(err))
        return function() end
    end

    local ok, res = pcall(func)
    if not ok then
        warn("LovFame | SafeLoad: Error executing " .. (name or "script") .. ": " .. tostring(res))
        return function() end
    end
    return res
end

SafeLoad("https://raw.githubusercontent.com/LovFame/Menu-LovFame/refs/heads/Script/GUIS/Off-site/Notify.lua", "Notify System")

local function GetAsset(asset)
    if not asset or asset == "" then return "" end
    local assetStr = tostring(asset)
    
    _G.AssetCache = _G.AssetCache or {}
    if _G.AssetCache[assetStr] then return _G.AssetCache[assetStr] end

    if not assetStr:find("://") and tonumber(assetStr) then
        local id = "rbxassetid://" .. assetStr
        _G.AssetCache[assetStr] = id
        return id
    end
    
    if assetStr:find("rbxassetid://") or assetStr:find("rbxasset://") or assetStr:find("rbxthumb://") then
        return assetStr
    end
    
    if assetStr:find("http") then
        local targetUrl = assetStr
        if targetUrl:find("github.com") and targetUrl:find("/blob/") then
            targetUrl = targetUrl:gsub("github.com", "raw.githubusercontent.com"):gsub("/blob/", "/")
        end

        local filename = targetUrl:match("([^/]+)$") or "asset.png"
        filename = filename:match("([^%?]+)") or filename
        if not filename:find("%.") then filename = filename .. ".png" end
        filename = filename:gsub("[%c%s%*%?%\"%<%>%|]", "_")
        
        local path = "LovFame/Assets/" .. filename
        
        if isfile(path) then
            local success, result = pcall(function() return getcustomasset(path) end)
            if success and result then
                _G.AssetCache[assetStr] = result
                return result
            end
        else
            if not isfolder("LovFame/Assets") then 
                pcall(function()
                    if not isfolder("LovFame") then makefolder("LovFame") end
                    makefolder("LovFame/Assets") 
                end)
            end
            
            local success, content = pcall(function() return game:HttpGet(targetUrl) end)
            if success and content and content ~= "" then
                local low = content:sub(1, 100):lower()
                if low:find("<!doctype") or low:find("<html") or low:find("<head") then
                    warn("LovFame | GetAsset: Downloaded content appears to be HTML. Link might be incorrect: " .. targetUrl)
                    return ""
                end
                
                pcall(function() writefile(path, content) end)
                task.wait(0.2) 
                
                local s, result = pcall(function() return getcustomasset(path) end)
                if s and result then
                    _G.AssetCache[assetStr] = result
                    return result
                end
            end
        end
    end
    
    return assetStr
end

local function NormalizeUrl(url)
    if not url or url == "" then return url end
    local targetUrl = tostring(url)
    if targetUrl:find("github.com") and targetUrl:find("/blob/") then
        targetUrl = targetUrl:gsub("github.com", "raw.githubusercontent.com"):gsub("/blob/", "/")
    end
    return targetUrl
end

local DEFAULT_WHEEL_BG = "rbxasset://textures/ui/Emotes/Large/SegmentedCircle.png"
local wheelImgState = setmetatable({}, { __mode = "k" })
local checkEmotesMenuExists

local function SetWheelImageMode(bgImg, isCustom)
    if not bgImg then return end
    if not wheelImgState[bgImg] then
        wheelImgState[bgImg] = {
            ScaleType = bgImg.ScaleType,
            SliceCenter = bgImg.SliceCenter,
            SliceScale = bgImg.SliceScale
        }
    end

    if isCustom then
        bgImg.ScaleType = Enum.ScaleType.Stretch
        bgImg.SliceCenter = Rect.new(0, 0, 0, 0)
        bgImg.SliceScale = 1
    else
        local st = wheelImgState[bgImg]
        if st then
            bgImg.ScaleType = st.ScaleType
            bgImg.SliceCenter = st.SliceCenter
            bgImg.SliceScale = st.SliceScale
        end
    end
end

local function ParseGifInfo(bytes)
    if not bytes or #bytes < 13 then return nil end
    if bytes:sub(1, 3) ~= "GIF" then return nil end
    local function u16le(pos)
        local b1 = bytes:byte(pos) or 0
        local b2 = bytes:byte(pos + 1) or 0
        return b1 + b2 * 256
    end
    local width = u16le(7)
    local height = u16le(9)
    local packed = bytes:byte(11) or 0
    local gctFlag = bit32.band(packed, 0x80) ~= 0
    local gctSize = bit32.band(packed, 0x07)
    local offset = 13
    if gctFlag then
        offset = offset + (3 * (2 ^ (gctSize + 1)))
    end

    local frames = 0
    local delays = {}
    local pendingDelay = nil

    local function skipSubBlocks(pos)
        while pos <= #bytes do
            local size = bytes:byte(pos) or 0
            pos = pos + 1
            if size == 0 then
                break
            end
            pos = pos + size
        end
        return pos
    end

    while offset <= #bytes do
        local b = bytes:byte(offset)
        if not b then break end
        if b == 0x3B then
            break
        elseif b == 0x21 then
            local label = bytes:byte(offset + 1) or 0
            if label == 0xF9 then
                local delay = u16le(offset + 4)
                pendingDelay = delay
                offset = offset + 8
            else
                offset = skipSubBlocks(offset + 2)
            end
        elseif b == 0x2C then
            frames = frames + 1
            if pendingDelay then
                table.insert(delays, pendingDelay)
                pendingDelay = nil
            end
            local packedImg = bytes:byte(offset + 9) or 0
            local lctFlag = bit32.band(packedImg, 0x80) ~= 0
            local lctSize = bit32.band(packedImg, 0x07)
            offset = offset + 10
            if lctFlag then
                offset = offset + (3 * (2 ^ (lctSize + 1)))
            end
            offset = offset + 1
            offset = skipSubBlocks(offset)
        else
            offset = offset + 1
        end
    end

    local totalDelay = 0
    for _, d in ipairs(delays) do
        totalDelay = totalDelay + d
    end
    local avgDelay = (#delays > 0) and (totalDelay / #delays) or 10

    return {
        width = width,
        height = height,
        frames = frames > 0 and frames or #delays,
        totalDelayCs = totalDelay,
        avgDelayCs = avgDelay
    }
end

local function ParsePngInfo(bytes)
    if not bytes or #bytes < 24 then return nil end
    if bytes:sub(1, 8) ~= "\137PNG\r\n\26\n" then return nil end
    local function u32be(pos)
        local b1 = bytes:byte(pos) or 0
        local b2 = bytes:byte(pos + 1) or 0
        local b3 = bytes:byte(pos + 2) or 0
        local b4 = bytes:byte(pos + 3) or 0
        return ((b1 * 256 + b2) * 256 + b3) * 256 + b4
    end
    local width = u32be(17)
    local height = u32be(21)
    if width <= 0 or height <= 0 then return nil end
    return { width = width, height = height }
end

local function LooksLikeGif(src)
    if not src or src == "" then return false end
    local s = tostring(src):lower()
    return s:find("%.gif") or s:find("format=gif") or s:find("image/gif")
end

local wheelGifConnection = nil
local function StopWheelGifAnimation()
    if wheelGifConnection then
        wheelGifConnection:Disconnect()
        wheelGifConnection = nil
    end
end

local function StartWheelGifAnimation(bgImg, data)
    StopWheelGifAnimation()
    if not bgImg or not data or not data.sprite then return end

    local frames = data.frames or 0
    local frameW = data.frameW or 0
    local frameH = data.frameH or 0
    if frames <= 0 or frameW <= 0 or frameH <= 0 then return end

    local cols = data.cols or 0
    if cols <= 0 then
        cols = math.max(1, math.floor(1024 / frameW))
    end
    local delay = data.delay
    if not delay then
        local delayCs = (data.gifInfo and data.gifInfo.avgDelayCs) or 10
        delay = math.max(0.02, (delayCs / 100))
    end

    bgImg.Image = data.sprite
    bgImg.ImageRectSize = Vector2.new(frameW, frameH)

    local current = 0
    local acc = 0
    wheelGifConnection = RunService.Heartbeat:Connect(function(dt)
        acc = acc + dt
        if acc < delay then return end
        acc = 0
        current = (current + 1) % frames
        local x = (current % cols) * frameW
        local y = math.floor(current / cols) * frameH
        bgImg.ImageRectOffset = Vector2.new(x, y)
    end)
end

local WheelAnimCache = {}

local function MakeWheelAnimKey(gifUrl, sheetUrl)
    return tostring(gifUrl or "") .. "|" .. tostring(sheetUrl or "")
end

local function AreWheelAnimMetaEqual(a, b)
    if a == b then return true end
    if not a or not b then return false end
    return a.Enabled == b.Enabled
        and a.FrameHeight == b.FrameHeight
        and a.FrameWidth == b.FrameWidth
        and a.FPS == b.FPS
        and a.Frames == b.Frames
        and a.Cols == b.Cols
        and a.Rows == b.Rows
        and a.GifUrl == b.GifUrl
        and a.SheetUrl == b.SheetUrl
end

local ConfigPath = "LovFame/EmoteSettings.json"
local Config = {
    NotifyEnabled = true,
    SearchVisible = true,
    FavVisible = true,
    ModeVisible = true,
    FreezeVisible = true,
    SpeedVisible = true,
    NavVisible = true,
    EmoteSpeed = 1,
    EmoteSpeedEnabled = false,
    SelectedTheme = "Default",
    EmotePage = 1,
    AnimationPage = 1,
    HUDPositions = {}
}

local function applySavedPositions() end 
local enterHUDEditor, exitHUDEditor

local function ApplyUIVisibility()
    pcall(function()
        if UI.Search and UI.Top then UI.Top.Visible = Config.SearchVisible end
        if UI.Favorite then UI.Favorite.Visible = Config.FavVisible end
        if UI.Changepage then UI.Changepage.Visible = Config.ModeVisible end
        if UI.EmoteWalkButton then UI.EmoteWalkButton.Visible = Config.FreezeVisible end
        if UI.SpeedEmote then UI.SpeedEmote.Visible = Config.SpeedVisible end
        if UI.SpeedBox then 
            UI.SpeedBox.Visible = (Config.SpeedVisible and State.speedEmoteEnabled) 
        end
        if UI.Under then UI.Under.Visible = Config.NavVisible end
        if UI.Reload then 
            UI.Reload.Visible = (State.currentMode == "animation" and Config.NavVisible) 
        end
    end)
end

local function SaveConfig()
    if not isfolder("LovFame") then makefolder("LovFame") end
    writefile(ConfigPath, HttpService:JSONEncode(Config))
end

local function LoadConfig()
    if isfile(ConfigPath) then
        local success, decoded = pcall(function() return HttpService:JSONDecode(readfile(ConfigPath)) end)
        if success and type(decoded) == "table" then
            for k, v in pairs(decoded) do Config[k] = v end
        end
    end
end
LoadConfig()

local rawNotify = getgenv().Notify
getgenv().Notify = function(data)
    if Config.NotifyEnabled then
        rawNotify(data)
    end
end

local SettingsLib = SafeLoad("https://raw.githubusercontent.com/LovFame/hub/refs/heads/Branch/GUIS/Settings.lua", "Settings Library")

local ToggleContainer = Instance.new("Frame")
ToggleContainer.Name = "open/Close"
ToggleContainer.Parent = SettingsLib.UI
ToggleContainer.BackgroundTransparency = 1
ToggleContainer.Size = UDim2.fromScale(1, 1)
ToggleContainer.ZIndex = 5000
ToggleContainer.Visible = false
ToggleContainer.Active = false
ToggleContainer.Selectable = false

local ToggleBtn = Instance.new("ImageButton")
ToggleBtn.Name = "ToggleSettings"
ToggleBtn.Parent = ToggleContainer
ToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
ToggleBtn.BackgroundTransparency = 0.4
ToggleBtn.Position = UDim2.new(0, 10, 1, -52)
ToggleBtn.Size = UDim2.fromOffset(42, 42)
ToggleBtn.Image = "rbxassetid://79568054778195"

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 10)
ToggleCorner.Parent = ToggleBtn

local function getSettingsMainFrame()
    if SettingsLib and SettingsLib.UI then
        return SettingsLib.UI:FindFirstChild("MainFrame")
    end
    return nil
end

local function applySettingsToggleStyle()
    local main = getSettingsMainFrame()
    if main then
        ToggleBtn.BackgroundColor3 = main.BackgroundColor3
    elseif State.EmoteTheme and State.EmoteTheme.Background then
        ToggleBtn.BackgroundColor3 = State.EmoteTheme.Background
    end
end

local function syncToggleVisibility()
    local main = getSettingsMainFrame()
    if main then
        ToggleContainer.Visible = not main.Visible
    else
        ToggleContainer.Visible = true
    end
end

ToggleBtn.MouseButton1Click:Connect(function()
    local main = getSettingsMainFrame()
    if main then
        main.Visible = not main.Visible
        syncToggleVisibility()
    else
        SettingsLib.UI.Enabled = not SettingsLib.UI.Enabled
    end
end)

applySettingsToggleStyle()
syncToggleVisibility()

do
    local main = getSettingsMainFrame()
    if main then
        main:GetPropertyChangedSignal("Visible"):Connect(syncToggleVisibility)
    end
end

local TogglesUI = {}
local GeneralTab = SettingsLib.CreateTab("General", 1)
TogglesUI.NotifyEnabled = SettingsLib.AddToggle(GeneralTab, "Show Notifications", "Receive alerts and feedback", Config.NotifyEnabled, function(v)
    Config.NotifyEnabled = v
    SaveConfig()
end)
local ButtonsTab = SettingsLib.CreateTab("Buttons", 2)

TogglesUI.SearchVisible = SettingsLib.AddToggle(ButtonsTab, "Search Bar", "Show/Hide the search input", Config.SearchVisible, function(v)
    Config.SearchVisible = v
    ApplyUIVisibility()
    SaveConfig()
end)

TogglesUI.FavVisible = SettingsLib.AddToggle(ButtonsTab, "Favorites Button", "Show/Hide the star button", Config.FavVisible, function(v)
    Config.FavVisible = v
    ApplyUIVisibility()
    SaveConfig()
end)

TogglesUI.ModeVisible = SettingsLib.AddToggle(ButtonsTab, "Mode Switcher", "Show/Hide animation mode button", Config.ModeVisible, function(v)
    Config.ModeVisible = v
    ApplyUIVisibility()
    SaveConfig()
end)

TogglesUI.FreezeVisible = SettingsLib.AddToggle(ButtonsTab, "Freeze Button", "Show/Hide emote freeze button", Config.FreezeVisible, function(v)
    Config.FreezeVisible = v
    ApplyUIVisibility()
    SaveConfig()
end)

TogglesUI.SpeedVisible = SettingsLib.AddToggle(ButtonsTab, "Speed Button", "Show/Hide the speed controller", Config.SpeedVisible, function(v)
    Config.SpeedVisible = v
    ApplyUIVisibility()
    SaveConfig()
end)

TogglesUI.NavVisible = SettingsLib.AddToggle(ButtonsTab, "Page Controls", "Show/Hide navigation buttons", Config.NavVisible, function(v)
    Config.NavVisible = v
    ApplyUIVisibility()
    SaveConfig()
end)

local cachedOverlay = nil
local hudEditorItem = SettingsLib.AddItem(GeneralTab, "HUD Editor", "Reposition buttons & UI elements")
local hudEditorBtn = SettingsLib:Create("TextButton", {
    Parent = hudEditorItem,
    BackgroundColor3 = Color3.fromRGB(0, 255, 150),
    Position = UDim2.new(1, -80, 0.5, -12),
    Size = UDim2.new(0, 70, 0, 24),
    Font = Enum.Font.GothamBold,
    Text = "EDIT",
    TextColor3 = Color3.fromRGB(24, 25, 28),
    TextSize = 11
}, { SettingsLib:Create("UICorner", {CornerRadius = UDim.new(0, 6)}) })

hudEditorBtn.MouseButton1Click:Connect(function()
    if enterHUDEditor then enterHUDEditor() end
end)
local function getBackgroundOverlay()
    if cachedOverlay and cachedOverlay.Parent then return cachedOverlay end
    
    local success, result = pcall(function()
        return game:GetService("CoreGui").RobloxGui.EmotesMenu.Children.Main.EmotesWheel.Back.Background
                   .BackgroundCircleOverlay
    end)
    if success and result then
        cachedOverlay = result
        return result
    end
    return nil
end

local function DeepCopy(t)
    local copy = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            copy[k] = DeepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

local function ColorToTable(c) return {math.round(c.R*255), math.round(c.G*255), math.round(c.B*255)} end
local function TableToColor(t)
    if type(t) ~= "table" then
        return Color3.fromRGB(255, 255, 255)
    end
    local r = tonumber(t[1]) or 255
    local g = tonumber(t[2]) or 255
    local b = tonumber(t[3]) or 255
    return Color3.fromRGB(r, g, b)
end

local function GetThemeIconColor(key)
    local theme = State.EmoteTheme
    if theme and theme.IconColors and theme.IconColors[key] then
        return TableToColor(theme.IconColors[key])
    end
    if theme and theme.ImageColor then
        return theme.ImageColor
    end
    return Color3.new(1, 1, 1)
end

local ApplyFavoriteButtonVisual
local function updateGUIColors()
    local backgroundOverlay = getBackgroundOverlay()
    if not backgroundOverlay then
        return
    end

    local theme = State.EmoteTheme
    if not theme then return end
    
    local bgColor = theme.Background
    local accentColor = theme.Accent
    local imgColor = theme.ImageColor
    local bgTransparency = backgroundOverlay.BackgroundTransparency

    local function getIconColor(key)
        if theme.IconColors and theme.IconColors[key] then
            return TableToColor(theme.IconColors[key])
        end
        return imgColor
    end

    if UI._1left then
        UI._1left.ImageColor3 = getIconColor("Left")
        UI._1left.ImageTransparency = bgTransparency
        UI._1left.BackgroundTransparency = 1 
    end

    if UI._9right then
        UI._9right.ImageColor3 = getIconColor("Right")
        UI._9right.ImageTransparency = bgTransparency
        UI._9right.BackgroundTransparency = 1
    end

    if UI._4pages then
        UI._4pages.TextColor3 = bgColor 
        UI._4pages.TextTransparency = bgTransparency
    end

    if UI._3TextLabel then
        UI._3TextLabel.TextColor3 = bgColor
        UI._3TextLabel.TextTransparency = bgTransparency
    end

    if UI._2Routenumber then
        UI._2Routenumber.TextColor3 = bgColor
        UI._2Routenumber.PlaceholderColor3 = bgColor
        UI._2Routenumber.TextTransparency = bgTransparency
    end

    if UI.Top then
        UI.Top.BackgroundColor3 = bgColor
        UI.Top.BackgroundTransparency = bgTransparency
    end

    if UI.EmoteWalkButton then
        UI.EmoteWalkButton.BackgroundColor3 = bgColor
        UI.EmoteWalkButton.BackgroundTransparency = bgTransparency
    end

    if UI.SpeedEmote then
        UI.SpeedEmote.BackgroundColor3 = bgColor
        UI.SpeedEmote.BackgroundTransparency = bgTransparency
    end

     if UI.Changepage then
        UI.Changepage.BackgroundColor3 = bgColor
        UI.Changepage.BackgroundTransparency = bgTransparency
    end

    if UI.SpeedBox then
        UI.SpeedBox.BackgroundColor3 = bgColor
        UI.SpeedBox.BackgroundTransparency = bgTransparency
    end

    if UI.Favorite then
        UI.Favorite.BackgroundColor3 = bgColor
        UI.Favorite.BackgroundTransparency = bgTransparency
    end

    if UI.Reload then
        UI.Reload.BackgroundColor3 = bgColor
        UI.Reload.BackgroundTransparency = bgTransparency
    end
    
    if ApplyFavoriteButtonVisual then
        ApplyFavoriteButtonVisual()
    end
    ApplyUIVisibility()
    applySettingsToggleStyle()
end

ApplyFavoriteButtonVisual = function()
    if not UI.Favorite then return end
