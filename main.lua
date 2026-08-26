-- Driving Empire Farm - Versión mejorada ATM + Delivery
-- ATM ahora intenta robar de verdad y pasa al siguiente

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

repeat task.wait() until player.Character and player.Character:FindFirstChild("HumanoidRootPart")

if player.PlayerGui:FindFirstChild("FarmGui") then
    player.PlayerGui.FarmGui:Destroy()
end

-- ====================== CONFIG ======================
local CONFIG = {
    MoneyLimit = 50000,
    ATMWaitTime = 5.5,       -- Tiempo de espera después de iniciar el robo (importante)
    BetweenATM = 1.2,        -- Tiempo entre un ATM y el siguiente
    DeliveryWaitTime = 2.8,
}

-- ====================== REMOTES ======================
local remotes = ReplicatedStorage:WaitForChild("Remotes", 8)

local function getRemote(name)
    return remotes and remotes:FindFirstChild(name)
end

local bustStart = getRemote("AttemptATMBustStart")
local bustEnd   = getRemote("AttemptATMBustComplete")
local startJob  = getRemote("RequestStartJobSession")
local endJob    = getRemote("RequestEndJobSession")

-- ====================== GUI (igual que antes) ======================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FarmGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 180, 0, 340)
panel.Position = UDim2.new(1, -195, 0.5, -170)
panel.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
panel.BorderSizePixel = 0
panel.Parent = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

local stroke = Instance.new("UIStroke", panel)
stroke.Color = Color3.fromRGB(60, 60, 70)
stroke.Thickness = 1.5

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 0, 28)
title.Position = UDim2.new(0, 10, 0, 6)
title.BackgroundTransparency = 1
title.Text = "Driving Empire Farm"
title.TextColor3 = Color3.new(1,1,1)
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 26, 0, 26)
minimizeBtn.Position = UDim2.new(1, -32, 0, 6)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
minimizeBtn.Text = "−"
minimizeBtn.TextColor3 = Color3.new(0,0,0)
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 18
minimizeBtn.Parent = panel
Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0, 6)

local content = Instance.new("Frame")
content.Size = UDim2.new(1, 0, 1, -35)
content.Position = UDim2.new(0, 0, 0, 35)
content.BackgroundTransparency = 1
content.Parent = panel

local function createBtn(text, posY, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 160, 0, 34)
    btn.Position = UDim2.new(0.5, -80, 0, posY)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Parent = content
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    return btn
end

local atmBtn = createBtn("ATM AutoFarm: OFF", 5, Color3.fromRGB(0, 120, 255))
local deliveryBtn = createBtn("Delivery AutoFarm: OFF", 45, Color3.fromRGB(0, 170, 80))
local stopBtn = createBtn("FINALIZAR FARMEO", 150, Color3.fromRGB(200, 40, 40))

local limitTitle = Instance.new("TextLabel")
limitTitle.Size = UDim2.new(1, -20, 0, 18)
limitTitle.Position = UDim2.new(0, 10, 0, 90)
limitTitle.BackgroundTransparency = 1
limitTitle.Text = "Límite para entregar:"
limitTitle.TextColor3 = Color3.fromRGB(200,200,210)
limitTitle.Font = Enum.Font.Gotham
limitTitle.TextSize = 12
limitTitle.TextXAlignment = Enum.TextXAlignment.Left
limitTitle.Parent = content

local limitBox = Instance.new("TextBox")
limitBox.Size = UDim2.new(0, 100, 0, 28)
limitBox.Position = UDim2.new(0, 10, 0, 110)
limitBox.BackgroundColor3 = Color3.fromRGB(40,40,50)
limitBox.Text = tostring(CONFIG.MoneyLimit)
limitBox.TextColor3 = Color3.new(1,1,1)
limitBox.Font = Enum.Font.GothamBold
limitBox.TextSize = 14
limitBox.Parent = content
Instance.new("UICorner", limitBox).CornerRadius = UDim.new(0, 6)

local applyBtn = Instance.new("TextButton")
applyBtn.Size = UDim2.new(0, 50, 0, 28)
applyBtn.Position = UDim2.new(0, 115, 0, 110)
applyBtn.BackgroundColor3 = Color3.fromRGB(140, 60, 200)
applyBtn.Text = "OK"
applyBtn.TextColor3 = Color3.new(1,1,1)
applyBtn.Font = Enum.Font.GothamBold
applyBtn.TextSize = 14
applyBtn.Parent = content
Instance.new("UICorner", applyBtn).CornerRadius = UDim.new(0, 6)

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -16, 0, 100)
infoLabel.Position = UDim2.new(0, 8, 0, 195)
infoLabel.BackgroundTransparency = 1
infoLabel.Text = "Listo\n\nATM intenta robar de verdad"
infoLabel.TextColor3 = Color3.fromRGB(180,180,190)
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextSize = 12
infoLabel.TextYAlignment = Enum.TextYAlignment.Top
infoLabel.Parent = content

-- ====================== VARIABLES ======================
local atmFarming = false
local deliveryFarming = false
local isMinimized = false
local originalSize = panel.Size

-- ====================== FUNCIONES ======================

local function getHRP()
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        return char.HumanoidRootPart
    end
    return nil
end

local function getCurrentMoney()
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        local m = ls:FindFirstChild("Cash") or ls:FindFirstChild("Money")
        if m then return m.Value end
    end
    return player:GetAttribute("Cash") or player:GetAttribute("Money") or 0
end

-- Detectar ATMs disponibles
local function getAvailableATMs()
    local list = {}
    local ok, spawners = pcall(function()
        return workspace.Game.Jobs.CriminalATMSpawners
    end)
    
    if not ok or not spawners then return list end
    
    for _, spawner in ipairs(spawners:GetChildren()) do
        local atm = spawner:FindFirstChild("CriminalATM")
        if atm and atm:GetAttribute("State") == "Normal" then
            table.insert(list, {
                spawner = spawner,
                atm = atm,
                pos = spawner:IsA("BasePart") and spawner.Position or (spawner:FindFirstChildWhichIsA("BasePart") and spawner:FindFirstChildWhichIsA("BasePart").Position)
            })
        end
    end
    return list
end

-- Unirse a Outlaw
local function joinOutlaw()
    if startJob then
        pcall(function()
            startJob:FireServer("Criminal", "jobPad")
        end)
        task.wait(0.6)
    end
end

-- Robar ATM de verdad
local function robATM(data)
    local root = getHRP()
    if not root or not data.pos then return false end
    
    -- 1. Teletransporte al ATM
    root.CFrame = CFrame.new(data.pos + Vector3.new(0, 5, 0))
    task.wait(0.4)
    
    -- 2. Iniciar el robo
    if bustStart then
        local success = pcall(function()
            if bustStart:IsA("RemoteFunction") then
                bustStart:InvokeServer(data.atm)
            else
                bustStart:FireServer(data.atm)
            end
        end)
        
        if success then
            infoLabel.Text = "Robando ATM...\nEsperando..."
        end
    end
    
    -- 3. Esperar a que el robo procese
    task.wait(CONFIG.ATMWaitTime)
    
    -- 4. Intentar completar (algunos servidores lo necesitan)
    if bustEnd then
        pcall(function()
            if bustEnd:IsA("RemoteFunction") then
                bustEnd:InvokeServer(data.atm)
            else
                bustEnd:FireServer(data.atm)
            end
        end)
    end
    
    return true
end

local function applyLimit()
    local num = tonumber((limitBox.Text or ""):gsub("%D", ""))
    if num and num > 0 then
        CONFIG.MoneyLimit = num
        limitBox.Text = tostring(num)
        infoLabel.Text = "Límite: $" .. num
    else
        limitBox.Text = tostring(CONFIG.MoneyLimit)
    end
end

-- ====================== TOGGLE ATM (MEJORADO) ======================
local function toggleATM()
    atmFarming = not atmFarming
    
    if atmFarming then
        atmBtn.Text = "ATM AutoFarm: ON"
        atmBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        
        -- Unirse al trabajo
        joinOutlaw()
        infoLabel.Text = "Unido a Outlaw\nBuscando ATMs..."
        
        task.spawn(function()
            while atmFarming do
                local atms = getAvailableATMs()
                
                if #atms == 0 then
                    infoLabel.Text = "No hay ATMs disponibles\nReintentando..."
                    task.wait(2.5)
                else
                    for i, data in ipairs(atms) do
                        if not atmFarming then break end
                        
                        infoLabel.Text = "ATM " .. i .. "/" .. #atms .. "\nRobando..."
                        robATM(data)
                        
                        -- Pequeña pausa antes del siguiente
                        task.wait(CONFIG.BetweenATM)
                        
                        -- Revisar dinero
                        local money = getCurrentMoney()
                        infoLabel.Text = "Dinero: $" .. money .. "\nLímite: $" .. CONFIG.MoneyLimit
                    end
                end
                
                task.wait(0.8)
            end
        end)
    else
        atmBtn.Text = "ATM AutoFarm: OFF"
        atmBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
        infoLabel.Text = "ATM detenido"
    end
end

-- ====================== DELIVERY (MEJORADO) ======================
local function toggleDelivery()
    deliveryFarming = not deliveryFarming
    
    if deliveryFarming then
        deliveryBtn.Text = "Delivery AutoFarm: ON"
        deliveryBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        
        task.spawn(function()
            while deliveryFarming do
                local found = false
                local root = getHRP()
                
                -- Busca de forma más agresiva
                for _, obj in pairs(workspace:GetDescendants()) do
                    if not deliveryFarming then break end
                    
                    local name = string.lower(obj.Name)
                    if obj:IsA("BasePart") or obj:IsA("Model") then
                        if string.find(name, "package") 
                        or string.find(name, "delivery") 
                        or string.find(name, "drop") 
                        or string.find(name, "pickup")
                        or string.find(name, "parcel")
                        or string.find(name, "box") then
                            
                            local part = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")) or obj
                            if part and root then
                                root.CFrame = CFrame.new(part.Position + Vector3.new(0, 6, 0))
                                infoLabel.Text = "Delivery: " .. obj.Name
                                found = true
                                task.wait(CONFIG.DeliveryWaitTime)
                            end
                        end
                    end
                end
                
                if not found then
                    infoLabel.Text = "No se encontraron\npuntos de Delivery"
                    task.wait(2)
                end
                
                task.wait(0.5)
            end
        end)
    else
        deliveryBtn.Text = "Delivery AutoFarm: OFF"
        deliveryBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 80)
    end
end

local function stopAll()
    atmFarming = false
    deliveryFarming = false
    atmBtn.Text = "ATM AutoFarm: OFF"
    atmBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
    deliveryBtn.Text = "Delivery AutoFarm: OFF"
    deliveryBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 80)
    infoLabel.Text = "Todo detenido"
end

local function toggleMinimize()
    isMinimized = not isMinimized
    if isMinimized then
        content.Visible = false
        panel.Size = UDim2.new(0, 180, 0, 38)
        minimizeBtn.Text = "+"
    else
        content.Visible = true
        panel.Size = originalSize
        minimizeBtn.Text = "−"
    end
end

-- Conexiones
atmBtn.MouseButton1Click:Connect(toggleATM)
deliveryBtn.MouseButton1Click:Connect(toggleDelivery)
stopBtn.MouseButton1Click:Connect(stopAll)
applyBtn.MouseButton1Click:Connect(applyLimit)
minimizeBtn.MouseButton1Click:Connect(toggleMinimize)
limitBox.FocusLost:Connect(function(e) if e then applyLimit() end end)

player.CharacterAdded:Connect(function(char)
    char:WaitForChild("HumanoidRootPart")
end)

print("✅ Script mejorado cargado - ATM intenta robar de verdad")
