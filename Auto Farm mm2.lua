-- ================================================================= --
--                     WINDUI LIBRARY LOADING                        --
-- ================================================================= --

local WindUI = nil

local success1, result1 = pcall(function()
    return loadstring(game:HttpGet("https://tree-hub.vercel.app/api/UI/WindUI"))()
end)

if success1 and result1 then
    WindUI = result1
else
    local success2, result2 = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
    end)
    
    if success2 and result2 then
        WindUI = result2
    else
        local success3, result3 = pcall(function()
            return loadstring(game:HttpGet("https://cdn.jsdelivr.net/gh/Footagesus/WindUI@main/dist/main.lua"))()
        end)
        
        if success3 and result3 then
            WindUI = success3
        end
    end
end

if not WindUI then
    error("Error loading WindUI! Please check your internet connection or try using VPN.")
    return
end

-- ================================================================= --
--                   CONFIG PERSISTENCE SYSTEM (JSON)                --
-- ================================================================= --

local HttpService = game:GetService("HttpService")
local CONFIG_FILE = "cfg.json"

local ConfigData = {
    AutoFarmActive = false,
    CoinAuraActive = false,
    CoinAuraDistance = 6,
    AutoTeleportActive = false,
    TeleportDistance = 10,
    SafeCoinMode = false,
    NoclipActive = false,
    CamNoclipActive = false,
    AntiFlingActive = false,
    AutoResetAt40 = false,
    FarmSpeed = 20,
    CoinWaitDelayMs = 0,
    OffsetX = 0,
    OffsetY = -1.1,
    OffsetZ = 0,
    PlayerAvoidanceActive = true,
    PlayerAvoidanceDistance = 25,
    PlayerAvoidanceTime = 20,
    AntiVoidActive = true,
    MinVoidHeight = -50,
    ESPCoinsActive = false
}

local function SaveConfigToFile()
    pcall(function()
        if writefile then
            local jsonString = HttpService:JSONEncode(ConfigData)
            writefile(CONFIG_FILE, jsonString)
            print("[JABA Hub] Configuration saved to " .. CONFIG_FILE)
        end
    end)
end

local function LoadConfigFromFile()
    pcall(function()
        if readfile and isfile and isfile(CONFIG_FILE) then
            local rawData = readfile(CONFIG_FILE)
            local decoded = HttpService:JSONDecode(rawData)
            if type(decoded) == "table" then
                for key, val in pairs(decoded) do
                    ConfigData[key] = val
                end
                print("[JABA Hub] Configuration successfully loaded from " .. CONFIG_FILE)
            end
        end
    end)
end

LoadConfigFromFile()

-- ================================================================= --
--                    INTERFACE INITIALIZATION                       --
-- ================================================================= --

local Window = WindUI:CreateWindow({
    Title = "JABA Hub | Coin Farmer",
    Icon = "sparkles",
    Author = "by JABA",
    Folder = "JHUB",
    
    Size = UDim2.fromOffset(580, 660),
    MinSize = Vector2.new(560, 420),
    MaxSize = Vector2.new(850, 850),
    
    ToggleKey = Enum.KeyCode.RightShift,
    
    Transparent = true,
    Theme = "Dark",
    Resizable = true,
    SideBarWidth = 200,
    BackgroundImageTransparency = 0.42,
    HideSearchBar = true,
    ScrollBarEnabled = false,
    
    User = {
        Enabled = true,
        Anonymous = false,
        Callback = function()
            print("Profile switched")
        end,
    },
    
    KeySystem = { 
        Key = { "key2bbjajjmjaucueAgghheuvbsj" },
        Note = "",
        URL = "",
        SaveKey = false,
    },
})

-- ================================================================= --
--                  RIGHT SHIFT TOGGLE HANDLER                       --
-- ================================================================= --

local UserInputService = game:GetService("UserInputService")

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.RightShift then
        if Window and Window.Toggle then
            Window:Toggle()
        end
    end
end)

-- ================================================================= --
--                         INTERFACE TABS                            --
-- ================================================================= --

local MainTab = Window:Tab({
    Title = "Main Farm",
    Icon = "coins",
    Locked = false,
})

local CombatTab = Window:Tab({
    Title = "Combat",
    Icon = "swords",
    Locked = false,
})

local SafetyTab = Window:Tab({
    Title = "Player Avoid & Anti-Void",
    Icon = "shield",
    Locked = false,
})

local AntiTab = Window:Tab({
    Title = "Anti",
    Icon = "bird",
    Locked = false,
})

local ESPTab = Window:Tab({
    Title = "Visuals (ESP)",
    Icon = "eye",
    Locked = false,
})

-- ================================================================= --
--                     FARM LOGIC VARIABLES                          --
-- ================================================================= --

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local autoFarmActive = ConfigData.AutoFarmActive
local autoResetAt40 = ConfigData.AutoResetAt40
local safeCoinMode = ConfigData.SafeCoinMode
local coinAuraActive = ConfigData.CoinAuraActive
local autoTeleportActive = ConfigData.AutoTeleportActive
local noclipActive = ConfigData.NoclipActive
local camNoclipActive = ConfigData.CamNoclipActive
local antiFlingActive = ConfigData.AntiFlingActive

local farmSpeed = ConfigData.FarmSpeed
local coinWaitDelayMs = ConfigData.CoinWaitDelayMs
local coinAuraDistance = ConfigData.CoinAuraDistance
local teleportDistance = ConfigData.TeleportDistance

-- Avoidance & Anti-Void variables
local playerAvoidanceActive = ConfigData.PlayerAvoidanceActive
local playerAvoidanceDistance = ConfigData.PlayerAvoidanceDistance
local playerAvoidanceTime = ConfigData.PlayerAvoidanceTime
local antiVoidActive = ConfigData.AntiVoidActive
local minVoidHeight = ConfigData.MinVoidHeight

local avoidanceStartTime = os.clock()

-- XYZ Offset variables relative to coin position
local offsetX = ConfigData.OffsetX
local offsetY = ConfigData.OffsetY
local offsetZ = ConfigData.OffsetZ

local isFading = false

local forbiddenPosition = Vector3.new(2, -67, -23)
local forbiddenRadius = 200

local farmThread = nil
local auraThread = nil
local balanceCheckThread = nil
local statsThread = nil
local avoidanceThread = nil
local antiVoidThread = nil
local noclipConnection = nil
local camNoclipConnection = nil
local antiFlingConnection = nil

local cachedNilMainCoin = nil

-- Farm statistics
local sessionCollectedCoins = 0
local farmStartTime = 0
local ignoredCoins = {}

-- Cache table for optimized coin tracking
local coinCache = {}

-- ESP Variables & Highlights
local espCoinsActive = ConfigData.ESPCoinsActive
local coinHighlights = {}

-- Fling & Combat
local flingMurderActive = false
local flingSheriffActive = false
local killAllAsMurderActive = false

local flingThread = nil
local isExecutingCombat = false

-- Water AntiDie
local antiWaterActive = false
local antiWaterConnection = nil

-- Forward declaration
local executeCombatFling

-- ================================================================= --
--               UNANCHORED PARTS FLING SYSTEM                       --
-- ================================================================= --

local originalPositions = {}

local function getUnanchoredParts()
    local parts = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") and not v.Anchored then
            local isPlayerPart = false
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character and v:IsDescendantOf(player.Character) then
                    isPlayerPart = true
                    break
                end
            end
            if not isPlayerPart and LocalPlayer.Character and not v:IsDescendantOf(LocalPlayer.Character) then
                table.insert(parts, v)
            end
        end
    end
    return parts
end

local function flingPlayerWithParts(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    local primaryPart = targetPlayer.Character.PrimaryPart or targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not primaryPart then return end

    local unanchoredParts = getUnanchoredParts()
    for _, part in ipairs(unanchoredParts) do
        if not originalPositions[part] then
            originalPositions[part] = part.Position
        end
        part.Velocity = Vector3.new(5700, 3478.756, 5700)
        part.RotVelocity = Vector3.new(5700, 3478.756, 5700)
        part.Position = primaryPart.Position
    end
end

local function stopPartFling()
    for part, originalPosition in pairs(originalPositions) do
        if part and part.Parent then
            part.Velocity = Vector3.new(0, 0, 0)
            part.RotVelocity = Vector3.new(0, 0, 0)
            part.Position = originalPosition
        end
    end
    originalPositions = {}
end

-- ================================================================= --
--                     ESP COIN HIGHLIGHT SYSTEM                     --
-- ================================================================= --

local function applyCoinHighlight(obj)
    if not obj or not obj:IsA("BasePart") then return end
    if coinHighlights[obj] then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "CoinESPHighlight"
    highlight.Adornee = obj
    highlight.FillColor = Color3.fromRGB(255, 215, 0)
    highlight.FillTransparency = 0.3
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineTransparency = 0
    highlight.Parent = obj

    coinHighlights[obj] = highlight
end

local function removeCoinHighlight(obj)
    if coinHighlights[obj] then
        pcall(function()
            coinHighlights[obj]:Destroy()
        end)
        coinHighlights[obj] = nil
    end
end

local function updateCoinESPState()
    if espCoinsActive then
        for coin, _ in pairs(coinCache) do
            if coin and coin:IsDescendantOf(Workspace) then
                applyCoinHighlight(coin)
            end
        end
    else
        for coin, highlight in pairs(coinHighlights) do
            if highlight then
                pcall(function() highlight:Destroy() end)
            end
        end
        coinHighlights = {}
    end
end

-- ================================================================= --
--                     FREEZE POSITION FUNCTION                      --
-- ================================================================= --

local function freezeInPlace(durationSeconds)
    if durationSeconds <= 0 then return end

    local character = LocalPlayer.Character
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    local freezeCFrame = rootPart.CFrame
    local startTime = os.clock()

    while (os.clock() - startTime) < durationSeconds and autoFarmActive do
        rootPart.CFrame = freezeCFrame
        rootPart.AssemblyLinearVelocity = Vector3.zero
        rootPart.AssemblyAngularVelocity = Vector3.zero
        RunService.Heartbeat:Wait()
    end
end

-- ================================================================= --
--               PLAYER AVOIDANCE & ANTI-VOID LOGIC                  --
-- ================================================================= --

local function getClosestOtherPlayer()
    local character = LocalPlayer.Character
    if not character then return nil, math.huge end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil, math.huge end

    local closestPlayer = nil
    local minDistance = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local otherRoot = player.Character:FindFirstChild("HumanoidRootPart")
            local otherHumanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if otherRoot and otherHumanoid and otherHumanoid.Health > 0 then
                local dist = (rootPart.Position - otherRoot.Position).Magnitude
                if dist < minDistance then
                    minDistance = dist
                    closestPlayer = player
                end
            end
        end
    end

    return closestPlayer, minDistance
end

local function startAvoidanceLoop()
    if avoidanceThread then
        task.cancel(avoidanceThread)
        avoidanceThread = nil
    end

    avoidanceThread = task.spawn(function()
        while true do
            task.wait(0.03)
            
            if playerAvoidanceActive then
                local elapsed = os.clock() - avoidanceStartTime
                if elapsed <= playerAvoidanceTime then
                    local character = LocalPlayer.Character
                    if character then
                        local rootPart = character:FindFirstChild("HumanoidRootPart")
                        if rootPart then
                            local closestPlayer, dist = getClosestOtherPlayer()
                            if closestPlayer and closestPlayer.Character and dist < playerAvoidanceDistance then
                                local otherRoot = closestPlayer.Character:FindFirstChild("HumanoidRootPart")
                                if otherRoot then
                                    local currentPos = rootPart.Position
                                    local otherPos = otherRoot.Position
                                    
                                    local horizontalDir = (currentPos - otherPos) * Vector3.new(1, 0, 1)
                                    if horizontalDir.Magnitude == 0 then
                                        horizontalDir = Vector3.new(1, 0, 0)
                                    else
                                        horizontalDir = horizontalDir.Unit
                                    end
                                    
                                    local targetPos = otherPos + (horizontalDir * (playerAvoidanceDistance * 0.7))
                                    targetPos = Vector3.new(targetPos.X, currentPos.Y + 25, targetPos.Z)
                                    
                                    local stepPos = currentPos:Lerp(targetPos, 0.25)
                                    
                                    rootPart.CFrame = CFrame.new(stepPos) * CFrame.Angles(math.rad(90), 0, 0)
                                    rootPart.AssemblyLinearVelocity = Vector3.zero
                                    rootPart.AssemblyAngularVelocity = Vector3.zero
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end

local function startAntiVoidLoop()
    if antiVoidThread then
        task.cancel(antiVoidThread)
        antiVoidThread = nil
    end

    antiVoidThread = task.spawn(function()
        while true do
            task.wait(0.05)
            if antiVoidActive then
                local character = LocalPlayer.Character
                if character then
                    local rootPart = character:FindFirstChild("HumanoidRootPart")
                    if rootPart then
                        if rootPart.Position.Y <= minVoidHeight then
                            local safeY = minVoidHeight + 35
                            local freezePos = Vector3.new(rootPart.Position.X, safeY, rootPart.Position.Z)
                            
                            rootPart.CFrame = CFrame.new(freezePos)
                            rootPart.AssemblyLinearVelocity = Vector3.zero
                            rootPart.AssemblyAngularVelocity = Vector3.zero
                        end
                    end
                end
            end
        end
    end)
end

startAvoidanceLoop()
startAntiVoidLoop()

LocalPlayer.CharacterAdded:Connect(function(character)
    avoidanceStartTime = os.clock()
    task.wait(0.5)
    if noclipActive then updateNoclipState() end
    if camNoclipActive then updateCamNoclipState() end
    if antiFlingActive then updateAntiFlingState() end
end)

-- ================================================================= --
--                     NOCLIP / CAM NOCLIP / ANTI-FLING              --
-- ================================================================= --

function updateNoclipState()
    if noclipActive then
        if not noclipConnection then
            noclipConnection = RunService.Stepped:Connect(function()
                if not noclipActive then return end
                local character = LocalPlayer.Character
                if character then
                    for _, part in ipairs(character:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                end
            end)
        end
    else
        if noclipConnection then
            noclipConnection:Disconnect()
            noclipConnection = nil
        end
        local character = LocalPlayer.Character
        if character then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end
end

function updateCamNoclipState()
    if camNoclipActive then
        LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
        if not camNoclipConnection then
            camNoclipConnection = RunService.RenderStepped:Connect(function()
                if not camNoclipActive then return end
                LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
                
                local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
                if playerGui then
                    local cameraScript = playerGui:FindFirstChild("PlayerModule")
                    if cameraScript then
                        pcall(function()
                            local cameraModule = require(cameraScript):GetCameras()
                            if cameraModule and cameraModule.activeCameraController then
                                cameraModule.activeCameraController.getSubjectPosition = function(self)
                                    return LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position or Vector3.new(0,0,0)
                                end
                            end
                        end)
                    end
                end
            end)
        end
    else
        if camNoclipConnection then
            camNoclipConnection:Disconnect()
            camNoclipConnection = nil
        end
        LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom
    end
end

function updateAntiFlingState()
    if antiFlingActive then
        if not antiFlingConnection then
            antiFlingConnection = RunService.Heartbeat:Connect(function()
                if not antiFlingActive then return end
                
                for _, otherPlayer in ipairs(Players:GetPlayers()) do
                    if otherPlayer ~= LocalPlayer and otherPlayer.Character then
                        local otherChar = otherPlayer.Character
                        for _, part in ipairs(otherChar:GetDescendants()) do
                            if part:IsA("BasePart") then
                                part.CustomPhysicalProperties = PhysicalProperties.new(0, 0, 0, 0, 0)
                                part.Velocity = Vector3.new(0, 0, 0)
                                part.RotVelocity = Vector3.new(0, 0, 0)
                                part.CanCollide = false
                            end
                        end
                    end
                end
            end)
        end
    else
        if antiFlingConnection then
            antiFlingConnection:Disconnect()
            antiFlingConnection = nil
        end
    end
end

-- ================================================================= --
--                  REMOTEEVENTS & CHARACTER KILL                    --
-- ================================================================= --

local function killCharacter()
    local character = LocalPlayer.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.Health = 0
        end
        character:BreakJoints()
        print("Character destroyed.")
    end
end

task.spawn(function()
    local fadeRemote = nil
    local endFadeRemote = nil

    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            if obj.Name == "Fade" then
                fadeRemote = obj
            elseif obj.Name == "EndFade" then
                endFadeRemote = obj
            end
        end
    end

    if fadeRemote then
        fadeRemote.OnClientEvent:Connect(function()
            isFading = true
            task.delay(20, function() isFading = false end)
        end)
    end

    if endFadeRemote then
        endFadeRemote.OnClientEvent:Connect(function()
            isFading = false
            killCharacter()
        end)
    end
end)

-- ================================================================= --
--                    HELPER FUNCTIONS                               --
-- ================================================================= --

local function updateNilCoinCache()
    if getnilinstances then
        for _, v in next, getnilinstances() do
            if v.ClassName == "MeshPart" and v.Name == "MainCoin" then
                cachedNilMainCoin = v
                return
            end
        end
    end
    cachedNilMainCoin = nil
end

task.spawn(updateNilCoinCache)

local function isInForbiddenZone()
    local character = LocalPlayer.Character
    if not character then return false end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end

    local distance = (rootPart.Position - forbiddenPosition).Magnitude
    return distance <= forbiddenRadius
end

local function getCoinAmount()
    local success, result = pcall(function()
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if not playerGui then return 0 end

        local targetObj = playerGui:FindFirstChild("MainGUI")
            and playerGui.MainGUI:FindFirstChild("Game")
            and playerGui.MainGUI.Game:FindFirstChild("CoinBags")
            and playerGui.MainGUI.Game.CoinBags:FindFirstChild("Container")
            and playerGui.MainGUI.Game.CoinBags.Container:FindFirstChild("Coin")
            and playerGui.MainGUI.Game.CoinBags.Container.Coin:FindFirstChild("CurrencyFrame")
            and playerGui.MainGUI.Game.CoinBags.Container.Coin.CurrencyFrame:FindFirstChild("Icon")
            and playerGui.MainGUI.Game.CoinBags.Container.Coin.CurrencyFrame.Icon:FindFirstChild("Coins")

        if targetObj then
            local textValue = ""
            if targetObj:IsA("TextLabel") or targetObj:IsA("TextBox") or targetObj:IsA("TextButton") then
                textValue = targetObj.Text
            elseif targetObj:FindFirstChild("Text") then
                textValue = tostring(targetObj.Text)
            end

            local number = string.match(textValue, "%d+")
            if number then
                return tonumber(number) or 0
            end
        end

        return 0
    end)

    if success and result then
        return result
    end

    return 0
end

-- =============================================
--               COMBAT SYSTEM LOGIC
-- =============================================

local function getPlayerWeapon(player, weaponName)
    if not player or not player.Character then return nil end
    local char = player.Character
    return char:FindFirstChild(weaponName) or player.Backpack:FindFirstChild(weaponName)
end

local function isMurderer(player)
    return getPlayerWeapon(player, "Knife") ~= nil
end

local function isSheriff(player)
    return getPlayerWeapon(player, "Gun") ~= nil
end

local function autoEquipKnife()
    local knife = LocalPlayer.Backpack:FindFirstChild("Knife")
    if knife then
        pcall(function()
            knife.Parent = LocalPlayer.Character
        end)
    end
end

local function stabPlayer()
    local knife = LocalPlayer.Backpack:FindFirstChild("Knife") or LocalPlayer.Character:FindFirstChild("Knife")
    if not knife then return false end
    
    local stabEvent = knife:FindFirstChild("Events") and knife.Events:FindFirstChild("KnifeStabbed")
    if stabEvent then
        pcall(function() stabEvent:FireServer() end)
        return true
    end
    return false
end

-- Функция выполнения атаки/флинга при ровно/более 40 монетах
executeCombatFling = function()
    if isExecutingCombat then return end
    
    -- ПРОВЕРКА: Если монет меньше 40 — никуда не летим и никого не флингим
    if getCoinAmount() < 40 then return end
    
    -- Если ни один боевой режим не включен — выходим
    if not (flingMurderActive or flingSheriffActive or killAllAsMurderActive) then return end

    isExecutingCombat = true
    playerAvoidanceActive = false
    print("[Combat]: 40 Coins collected! Executing Fling attack...")

    local targets = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            if flingMurderActive and isMurderer(player) then
                table.insert(targets, player)
            elseif flingSheriffActive and isSheriff(player) then
                table.insert(targets, player)
            elseif killAllAsMurderActive then
                table.insert(targets, player)
            end
        end
    end

    if #targets > 0 then
        local startTime = os.clock()
        local loopConn
        
        -- Выполняем флинг в течение 3 секунд
        loopConn = RunService.Heartbeat:Connect(function()
            if os.clock() - startTime >= 3.0 then
                if loopConn then loopConn:Disconnect() end
                return
            end

            for _, targetPlayer in ipairs(targets) do
                if targetPlayer and targetPlayer.Character then
                    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
                    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    
                    if targetRoot and myRoot then
                        -- Телепортируемся к цели
                        myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 2, 0)
                        
                        -- Применяем флинг через детали
                        flingPlayerWithParts(targetPlayer)
                        
                        if killAllAsMurderActive then
                            autoEquipKnife()
                            stabPlayer()
                        end
                    end
                end
            end
        end)

        task.wait(3.0)
        
        if loopConn then loopConn:Disconnect() end
        stopPartFling()
        print("[Combat]: 3 seconds fling completed.")
    end

    -- ПРОВЕРКА: Смерть происходит ТОЛЬКО при включенной галочке Reset at 40 Coins
    if autoResetAt40 then
        print("[Combat]: Auto-Reset enabled. Resetting character...")
        task.wait(0.2)
        killCharacter()
    else
        print("[Combat]: Auto-Reset is disabled. Character will not reset.")
    end

    isExecutingCombat = false
end

-- Регулярная проверка на 40 монет
local function checkResetCondition()
    if isFading then return end
    if getCoinAmount() >= 40 then
        executeCombatFling()
    end
end

local function startBalanceChecker()
    if balanceCheckThread then
        task.cancel(balanceCheckThread)
        balanceCheckThread = nil
    end

    balanceCheckThread = task.spawn(function()
        while true do
            task.wait(0.5)
            checkResetCondition()
        end
    end)
end

startBalanceChecker()

-- ================================================================= --
--             OPTIMIZED COIN TRACKING SYSTEM                        --
-- ================================================================= --

local function isCoinInstance(obj)
    if not obj or not obj:IsA("BasePart") then return false end
    if obj.Name == "MainCoin" then
        return true
    elseif obj.Parent and obj.Parent.Name == "CoinVisual" then
        return true
    end
    return false
end

local function registerCoin(obj)
    if isCoinInstance(obj) then
        coinCache[obj] = true
        if espCoinsActive then
            applyCoinHighlight(obj)
        end
    end
end

local function unregisterCoin(obj)
    coinCache[obj] = nil
    removeCoinHighlight(obj)
end

for _, obj in ipairs(Workspace:GetDescendants()) do
    registerCoin(obj)
end

Workspace.DescendantAdded:Connect(function(obj)
    registerCoin(obj)
end)

Workspace.DescendantRemoving:Connect(function(obj)
    unregisterCoin(obj)
end)

local function isValidCoin(obj)
    if not obj or not obj:IsA("BasePart") then return false end
    if obj.Transparency >= 1 then return false end
    if cachedNilMainCoin and obj == cachedNilMainCoin then return false end
    if ignoredCoins[obj] then return false end

    if playerAvoidanceActive and (os.clock() - avoidanceStartTime <= playerAvoidanceTime) then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                local playerPos = player.Character.HumanoidRootPart.Position
                if (obj.Position - playerPos).Magnitude < playerAvoidanceDistance then
                    return false
                end
            end
        end
    end

    return true
end

local function getCoins()
    local coins = {}
    for coin, _ in pairs(coinCache) do
        if coin and coin:IsDescendantOf(Workspace) then
            if isValidCoin(coin) then
                table.insert(coins, coin)
            end
        else
            coinCache[coin] = nil
            removeCoinHighlight(coin)
        end
    end
    return coins
end

local function getClosestCoin()
    local character = LocalPlayer.Character
    if not character then return nil end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end

    local coins = getCoins()
    local closestCoin = nil
    local shortestDistance = math.huge

    for _, coin in ipairs(coins) do
        local distance = (rootPart.Position - coin.Position).Magnitude
        if distance < shortestDistance then
            shortestDistance = distance
            closestCoin = coin
        end
    end

    return closestCoin
end

-- ================================================================= --
--                       COIN AURA SYSTEM                            --
-- ================================================================= --

local function startCoinAuraLoop()
    if auraThread then
        task.cancel(auraThread)
        auraThread = nil
    end

    auraThread = task.spawn(function()
        while coinAuraActive do
            task.wait(0.05)
            local character = LocalPlayer.Character
            if character then
                local rootPart = character:FindFirstChild("HumanoidRootPart")
                if rootPart then
                    local coins = getCoins()
                    for _, coin in ipairs(coins) do
                        local distance = (rootPart.Position - coin.Position).Magnitude
                        if distance <= coinAuraDistance then
                            pcall(function()
                                coin.CFrame = rootPart.CFrame
                                if firetouchinterest then
                                    firetouchinterest(rootPart, coin, 0)
                                    firetouchinterest(rootPart, coin, 1)
                                end
                            end)
                        end
                    end
                end
            end
        end
    end)
end

-- ================================================================= --
--                 MOVEMENT LOGIC TO COINS                           --
-- ================================================================= --

local function moveToCoin(targetCoin)
    local character = LocalPlayer.Character
    if not character then return false end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end

    local reached = false
    local touchConnection = nil

    touchConnection = targetCoin.Touched:Connect(function(hit)
        if hit and hit.Parent == character then
            reached = true
        end
    end)

    while autoFarmActive and targetCoin and targetCoin:IsDescendantOf(Workspace) and isValidCoin(targetCoin) and not reached do
        if isExecutingCombat then break end

        if isInForbiddenZone() then
            if touchConnection then touchConnection:Disconnect() end
            return false
        end

        if playerAvoidanceActive and (os.clock() - avoidanceStartTime <= playerAvoidanceTime) then
            local closestPlayer, playerDist = getClosestOtherPlayer()
            if closestPlayer and playerDist < playerAvoidanceDistance then
                if touchConnection then touchConnection:Disconnect() end
                task.wait(0.1)
                return false
            end
        end

        local currentPos = rootPart.Position
        local targetServerPos = targetCoin.Position
        if safeCoinMode then
            targetServerPos = targetCoin.Position + Vector3.new(offsetX, offsetY, offsetZ)
        end

        local distance = (targetServerPos - currentPos).Magnitude

        if autoTeleportActive and distance <= teleportDistance then
            rootPart.CFrame = CFrame.new(targetServerPos) * CFrame.Angles(math.rad(90), 0, 0)
            rootPart.AssemblyLinearVelocity = Vector3.zero
            rootPart.AssemblyAngularVelocity = Vector3.zero
            currentPos = rootPart.Position
            distance = (targetServerPos - currentPos).Magnitude
        end

        if distance <= coinAuraDistance and coinAuraActive then
            pcall(function()
                targetCoin.CFrame = rootPart.CFrame
                if firetouchinterest then
                    firetouchinterest(rootPart, targetCoin, 0)
                    firetouchinterest(rootPart, targetCoin, 1)
                end
            end)
        end

        if distance <= 0.6 then
            reached = true
            ignoredCoins[targetCoin] = true
            sessionCollectedCoins = sessionCollectedCoins + 1
            
            if firetouchinterest then
                pcall(function()
                    firetouchinterest(rootPart, targetCoin, 0)
                    if coinWaitDelayMs > 0 then task.wait(0.02) end
                    firetouchinterest(rootPart, targetCoin, 1)
                end)
            end
            break
        end

        local direction = (targetServerPos - currentPos).Unit
        local step = farmSpeed * RunService.Heartbeat:Wait()
        local newPos = currentPos + (direction * math.min(step, distance))

        rootPart.CFrame = CFrame.new(newPos) * CFrame.Angles(math.rad(90), 0, 0)
        rootPart.AssemblyLinearVelocity = Vector3.zero
        rootPart.AssemblyAngularVelocity = Vector3.zero
    end

    if touchConnection then touchConnection:Disconnect() end
    return reached
end

local function startFarmLoop()
    if farmThread then
        task.cancel(farmThread)
        farmThread = nil
    end

    farmThread = task.spawn(function()
        while autoFarmActive do
            if isExecutingCombat then
                task.wait(0.5)
            elseif isInForbiddenZone() then
                task.wait(0.2)
            else
                local targetCoin = getClosestCoin()
                if targetCoin then
                    local success = moveToCoin(targetCoin)
                    if success and autoFarmActive and coinWaitDelayMs > 0 then
                        freezeInPlace(coinWaitDelayMs / 1000)
                    end
                else
                    task.wait(0.1)
                end
            end
        end
    end)
end

-- ================================================================= --
--              CONTROL ELEMENTS AND STATISTICS (WINDUI)             --
-- ================================================================= --

local CoinStatsParagraph = MainTab:Paragraph({
    Title = "Farm Statistics",
    Desc = "Farm speed: 0 coins/hr\nCollected this session: 0",
    Icon = "bar-chart-3"
})

local function updateStatsLoop()
    if statsThread then
        task.cancel(statsThread)
        statsThread = nil
    end

    statsThread = task.spawn(function()
        while true do
            task.wait(1)
            if autoFarmActive and farmStartTime > 0 then
                local elapsedTime = os.time() - farmStartTime
                if elapsedTime > 0 then
                    local coinsPerHour = math.floor((sessionCollectedCoins / elapsedTime) * 3600)
                    CoinStatsParagraph:SetDesc("Farm speed: " .. tostring(coinsPerHour) .. " coins/hr\nCollected this session: " .. tostring(sessionCollectedCoins))
                end
            elseif not autoFarmActive then
                CoinStatsParagraph:SetDesc("Farm stopped.\nFarm speed: 0 coins/hr\nCollected this session: " .. tostring(sessionCollectedCoins))
            end
        end
    end)
end

updateStatsLoop()

-- =============================================
--              ANTI WATER (Yacht Map)
-- =============================================

local function startAntiWaterLoop()
    if antiWaterConnection then
        antiWaterConnection:Disconnect()
        antiWaterConnection = nil
    end
    
    if antiWaterActive then
        antiWaterConnection = RunService.Heartbeat:Connect(function()
            if not antiWaterActive then return end
            local character = LocalPlayer.Character
            if not character then return end
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            if not rootPart then return end
            
            local water = workspace:FindFirstChild("Yacht", true) or workspace:FindFirstChild("Water", true)
            if water and water:IsA("BasePart") then
                local waterY = water.Position.Y + water.Size.Y / 2
                if rootPart.Position.Y <= waterY + 1 then
                    local safePos = Vector3.new(rootPart.Position.X, waterY + 1.1, rootPart.Position.Z)
                    rootPart.CFrame = CFrame.new(safePos) * CFrame.Angles(math.rad(90), 0, 0)
                    rootPart.AssemblyLinearVelocity = Vector3.new(0, 5, 0)
                end
            end
        end)
    end
end

-- MAIN TAB CONTROLS
local ToggleFarm = MainTab:Toggle({
    Title = "Auto-Collect Coins",
    Desc = "Automated continuous flying and coin collection across the map",
    Icon = "zap",
    Type = "Checkbox",
    Value = ConfigData.AutoFarmActive,
    Flag = "AutoFarmActive",
    Callback = function(state) 
        autoFarmActive = state
        ConfigData.AutoFarmActive = state
        SaveConfigToFile()

        if autoFarmActive then
            if farmStartTime == 0 then farmStartTime = os.time() end
            startFarmLoop()
        else
            if farmThread then
                task.cancel(farmThread)
                farmThread = nil
            end
        end
    end
})

local ToggleAura = MainTab:Toggle({
    Title = "Coin Aura",
    Desc = "Teleports nearby coins within radius directly to character",
    Icon = "magnet",
    Type = "Checkbox",
    Value = ConfigData.CoinAuraActive,
    Flag = "CoinAuraActive",
    Callback = function(state)
        coinAuraActive = state
        ConfigData.CoinAuraActive = state
        SaveConfigToFile()

        if coinAuraActive then
            startCoinAuraLoop()
        else
            if auraThread then
                task.cancel(auraThread)
                auraThread = nil
            end
        end
    end
})

local AuraDistanceSlider = MainTab:Slider({
    Title = "Aura Distance (Studs)",
    Desc = "Distance threshold to teleport coins (1 - 50 studs)",
    Step = 1,
    Value = { Min = 1, Max = 50, Default = ConfigData.CoinAuraDistance },
    Flag = "CoinAuraDistance",
    Callback = function(value)
        coinAuraDistance = value
        ConfigData.CoinAuraDistance = value
        SaveConfigToFile()
    end
})

local ToggleTeleport = MainTab:Toggle({
    Title = "Auto Teleport to Coin",
    Desc = "Instantly teleports you to the coin when within configured range",
    Icon = "locate-fixed",
    Type = "Checkbox",
    Value = ConfigData.AutoTeleportActive,
    Flag = "AutoTeleportActive",
    Callback = function(state)
        autoTeleportActive = state
        ConfigData.AutoTeleportActive = state
        SaveConfigToFile()
    end
})

local TeleportDistanceSlider = MainTab:Slider({
    Title = "Teleport Distance (Studs)",
    Desc = "Triggers instant teleport when coin is within this range (1 - 50 studs)",
    Step = 1,
    Value = { Min = 1, Max = 50, Default = ConfigData.TeleportDistance },
    Flag = "TeleportDistance",
    Callback = function(value)
        teleportDistance = value
        ConfigData.TeleportDistance = value
        SaveConfigToFile()
    end
})

local ToggleSafe = MainTab:Toggle({
    Title = "Safe Coin (Offset Pick Up)",
    Desc = "Approach coins using XYZ offset settings",
    Icon = "shield-check",
    Type = "Checkbox",
    Value = ConfigData.SafeCoinMode,
    Flag = "SafeCoinMode",
    Callback = function(state)
        safeCoinMode = state
        ConfigData.SafeCoinMode = state
        SaveConfigToFile()
    end
})

local ToggleNoclip = MainTab:Toggle({
    Title = "Powerful Noclip",
    Desc = "Allows character to pass through all walls and objects",
    Icon = "ghost",
    Type = "Checkbox",
    Value = ConfigData.NoclipActive,
    Flag = "NoclipActive",
    Callback = function(state)
        noclipActive = state
        ConfigData.NoclipActive = state
        SaveConfigToFile()
        updateNoclipState()
    end
})

local ToggleCamNoclip = MainTab:Toggle({
    Title = "Cam Noclip (Camera Through Walls)",
    Desc = "Allows camera to move freely through obstacles without zooming",
    Icon = "camera",
    Type = "Checkbox",
    Value = ConfigData.CamNoclipActive,
    Flag = "CamNoclipActive",
    Callback = function(state)
        camNoclipActive = state
        ConfigData.CamNoclipActive = state
        SaveConfigToFile()
        updateCamNoclipState()
    end
})

local ToggleReset = MainTab:Toggle({
    Title = "Reset at 40 Coins",
    Desc = "Resets character upon reaching 40 coins AFTER fling attack",
    Icon = "skull",
    Type = "Checkbox",
    Value = ConfigData.AutoResetAt40,
    Flag = "AutoResetAt40",
    Callback = function(state)
        autoResetAt40 = state
        ConfigData.AutoResetAt40 = state
        SaveConfigToFile()
    end
})

local SpeedSlider = MainTab:Slider({
    Title = "Fly Speed (Max 30)",
    Desc = "Adjust speed toward coins (1 - 30)",
    Step = 1,
    Value = { Min = 1, Max = 30, Default = ConfigData.FarmSpeed },
    Flag = "FarmSpeed",
    Callback = function(value)
        farmSpeed = value
        ConfigData.FarmSpeed = value
        SaveConfigToFile()
    end
})

local DelaySlider = MainTab:Slider({
    Title = "Coin Delay (ms)",
    Desc = "Pause duration before moving to the next coin (max 5000 ms)",
    Step = 50,
    Value = { Min = 0, Max = 5000, Default = ConfigData.CoinWaitDelayMs },
    Flag = "CoinWaitDelayMs",
    Callback = function(value)
        coinWaitDelayMs = value
        ConfigData.CoinWaitDelayMs = value
        SaveConfigToFile()
    end
})

-- ================================================================= --
--                  XYZ COIN OFFSET SETTINGS                         --
-- ================================================================= --

local OffsetXSlider = MainTab:Slider({
    Title = "X-Axis Offset",
    Desc = "Offset left / right from the coin",
    Step = 0.01,
    Value = { Min = -10, Max = 10, Default = ConfigData.OffsetX },
    Flag = "OffsetX",
    Callback = function(value)
        offsetX = value
        ConfigData.OffsetX = value
        SaveConfigToFile()
    end
})

local OffsetYSlider = MainTab:Slider({
    Title = "Y-Axis Offset (Height)",
    Desc = "Offset below / above the coin (default -1.1)",
    Step = 0.01,
    Value = { Min = -10, Max = 10, Default = ConfigData.OffsetY },
    Flag = "OffsetY",
    Callback = function(value)
        offsetY = value
        ConfigData.OffsetY = value
        SaveConfigToFile()
    end
})

local OffsetZSlider = MainTab:Slider({
    Title = "Z-Axis Offset",
    Desc = "Offset forward / backward from the coin",
    Step = 0.01,
    Value = { Min = -10, Max = 10, Default = ConfigData.OffsetZ },
    Flag = "OffsetZ",
    Callback = function(value)
        offsetZ = value
        ConfigData.OffsetZ = value
        SaveConfigToFile()
    end
})

-- ================================================================= --
--                     SAFETY & AVOIDANCE TAB                        --
-- ================================================================= --

local ToggleAvoidance = SafetyTab:Toggle({
    Title = "Player Avoidance (Уклонение от игроков)",
    Desc = "Автоматически отходит от игроков на безопасное расстояние",
    Icon = "user-minus",
    Type = "Checkbox",
    Value = ConfigData.PlayerAvoidanceActive,
    Flag = "PlayerAvoidanceActive",
    Callback = function(state)
        playerAvoidanceActive = state
        ConfigData.PlayerAvoidanceActive = state
        SaveConfigToFile()
        avoidanceStartTime = os.clock()
    end
})

local AvoidanceDistSlider = SafetyTab:Slider({
    Title = "Distance to Keep from Players (Studs)",
    Desc = "Минимальное расстояние до других игроков (5 - 100 студов)",
    Step = 1,
    Value = { Min = 5, Max = 100, Default = ConfigData.PlayerAvoidanceDistance },
    Flag = "PlayerAvoidanceDistance",
    Callback = function(value)
        playerAvoidanceDistance = value
        ConfigData.PlayerAvoidanceDistance = value
        SaveConfigToFile()
    end
})

local AvoidanceTimeSlider = SafetyTab:Slider({
    Title = "Avoidance Active Time (Sec)",
    Desc = "Время активности уклонения после спавна (1 - 60 сек)",
    Step = 1,
    Value = { Min = 1, Max = 60, Default = ConfigData.PlayerAvoidanceTime },
    Flag = "PlayerAvoidanceTime",
    Callback = function(value)
        playerAvoidanceTime = value
        ConfigData.PlayerAvoidanceTime = value
        SaveConfigToFile()
    end
})

local ToggleAntiVoid = SafetyTab:Toggle({
    Title = "Anti-Void Freeze (Защита от падения)",
    Desc = "Фризит персонажа в воздухе при вылете или падении за карту",
    Icon = "anchor",
    Type = "Checkbox",
    Value = ConfigData.AntiVoidActive,
    Flag = "AntiVoidActive",
    Callback = function(state)
        antiVoidActive = state
        ConfigData.AntiVoidActive = state
        SaveConfigToFile()
    end
})

-- ================================================================= --
--                         COMBAT TAB                                --
-- ================================================================= --

local ToggleFlingMurder = CombatTab:Toggle({
    Title = "Fling Murder (On 40 Coins)",
    Desc = "Fling player with Knife using unanchored parts (Only at 40 coins)",
    Icon = "check",
    Type = "Checkbox",
    Value = false,
    Callback = function(state)
        flingMurderActive = state
    end
})

local ToggleFlingSheriff = CombatTab:Toggle({
    Title = "Fling Sheriff (On 40 Coins)",
    Desc = "Fling player with Gun using unanchored parts (Only at 40 coins)",
    Icon = "check",
    Type = "Checkbox",
    Value = false,
    Callback = function(state)
        flingSheriffActive = state
    end
})

local ToggleKillAllMurder = CombatTab:Toggle({
    Title = "Kill All As Murder (On 40 Coins)",
    Desc = "Auto equip knife → fling + stab all players (Only at 40 coins)",
    Icon = "check",
    Type = "Checkbox",
    Value = false,
    Callback = function(state)
        killAllAsMurderActive = state
    end
})

-- ================================================================= --
--                          ANTI TAB                                 --
-- ================================================================= --

local ToggleAntiFling = AntiTab:Toggle({
    Title = "Anti-Fling Protection",
    Desc = "Protects your character from being pushed or flinged by other players",
    Icon = "shield-alert",
    Type = "Checkbox",
    Value = ConfigData.AntiFlingActive,
    Flag = "AntiFlingActive",
    Callback = function(state)
        antiFlingActive = state
        ConfigData.AntiFlingActive = state
        SaveConfigToFile()
        updateAntiFlingState()
    end
})

local ToggleAntiWater = AntiTab:Toggle({
    Title = "Anti Water (Yacht)",
    Desc = "Никогда не касаться воды на яхте. Авто-подъём на 1+ студ",
    Icon = "check",
    Type = "Checkbox",
    Value = false,
    Callback = function(state)
        antiWaterActive = state
        if state then
            startAntiWaterLoop()
        elseif antiWaterConnection then
            antiWaterConnection:Disconnect()
            antiWaterConnection = nil
        end
    end
})

-- ================================================================= --
--                          ESP TAB                                  --
-- ================================================================= --

local ToggleESPCoins = ESPTab:Toggle({
    Title = "ESP Coins",
    Desc = "Highlights all current and newly spawned coins in yellow/gold color",
    Icon = "sparkles",
    Type = "Checkbox",
    Value = ConfigData.ESPCoinsActive,
    Flag = "ESPCoinsActive",
    Callback = function(state)
        espCoinsActive = state
        ConfigData.ESPCoinsActive = state
        SaveConfigToFile()
        updateCoinESPState()
    end
})

-- ================================================================= --
--              APPLY LOADED CONFIGURATION ON STARTUP                --
-- ================================================================= --

task.spawn(function()
    task.wait(0.5)

    if autoFarmActive then
        farmStartTime = os.time()
        startFarmLoop()
    end

    if coinAuraActive then
        startCoinAuraLoop()
    end

    if noclipActive then
        updateNoclipState()
    end

    if camNoclipActive then
        updateCamNoclipState()
    end

    if antiFlingActive then
        updateAntiFlingState()
    end

    if espCoinsActive then
        updateCoinESPState()
    end
end)
