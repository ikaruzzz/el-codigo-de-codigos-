-- Driving Empire Farm GUI (Adaptado)
-- Detecta ATMs automáticamente + sistema de límite

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

repeat task.wait() until player.Character and player.Character:FindFirstChild("HumanoidRootPart")
local character = player.Character
local hrp = character:WaitForChild("HumanoidRootPart")

if player.PlayerGui:FindFirstChild("FarmGui") then
    player.PlayerGui.FarmGui:Destroy()
end

-- ====================== CONFIG ======================
local CONFIG = {
    MoneyLimit = 50000,          -- Límite para entregar (cámbialo desde el menú)
    ATMWaitTime = 4.5,           -- Tiempo entre cada ATM (recomendado 4-6)
    DeliveryWaitTime = 2.5,
}

-- ====================== REMOTES ======================
local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local bustStart = remotes and remotes:FindFirstChild("AttemptATMBustStart")
local bustEnd = remotes and remotes:FindFirstChild("AttemptATMBustComplete")
local startJob = remotes and remotes:FindFirstChild("RequestStartJobSession")
local endJob = remotes and remotes:FindFirstChild("RequestEndJobSession")

-- ====================== GUI ======================
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
limitBox.PlaceholderText = "Ej: 50000"
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
infoLabel.Text = "Listo para farmear\n\nATM detecta automáticamente"
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
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        return player.Character.HumanoidRootPart
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
    local spawners = workspace:FindFirstChild("Game") 
        and workspace.Game:FindFirstChild("Jobs") 
        and workspace.Game.Jobs:FindFirstChild("CriminalATMSpawners")
    
    if not spawners then return list end
    
    for _, spawner in ipairs(spawners:GetChildren()) do
        local atm = spawner:FindFirstChild("CriminalATM")
        if atm and atm:GetAttribute("State") == "Normal" then
            table.insert(list, {spawner = spawner, atm = atm})
        end
    end
    return list
end

-- Unirse al trabajo Outlaw
local function joinOutlaw()
    if startJob then
        pcall(function()
            startJob:FireServer("Criminal", "jobPad")
        end)
    end
end

-- Robar un ATM
local function robATM(data)
    local root = getHRP()
    if not root then return end
    
    -- Teletransporte cerca del ATM
    root.CFrame = CFrame.new(data.spawner.Position + Vector3.new(0, 4, 0))
    task.wait(0.35)
    
    -- Iniciar el robo
    if bustStart then
        pcall(function()
            if bustStart:IsA("RemoteFunction") then
                bustStart:InvokeServer(data.atm)
            else
                bustStart:FireServer(data.atm)
            end
        end)
    end
    
    task.wait(0.8)
    
    -- Completar
    if bustEnd then
        pcall(function()
            if bustEnd:IsA("RemoteFunction") then
                bustEnd:InvokeServer(data.atm)
            else
                bustEnd:FireServer(data.atm)
            end
        end)
    end
end

-- Aplicar límite
local function applyLimit()
    local num = tonumber(limitBox.Text:gsub("%D", ""))
    if num and num > 0 then
        CONFIG.MoneyLimit = num
        limitBox.Text = tostring(num)
        infoLabel.Text = "Límite: $" .. num .. "\n\nAl llegar entrega y sigue"
    else
        infoLabel.Text = "Número inválido"
        limitBox.Text = tostring(CONFIG.MoneyLimit)
    end
end

-- Toggle ATM
local function toggleATM()
    atmFarming = not atmFarming
    
    if atmFarming then
        atmBtn.Text = "ATM AutoFarm: ON"
        atmBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        joinOutlaw()
        
        task.spawn(function()
            while atmFarming do
                local money = getCurrentMoney()
                
                if money >= CONFIG.MoneyLimit then
                    infoLabel.Text = "¡Límite alcanzado!\nEntregando..."
                    -- Aquí podrías teletransportar a la base de Outlaws
                    -- Por ahora solo avisa
                    task.wait(2)
                end
                
                local atms = getAvailableATMs()
                if #atms == 0 then
                    infoLabel.Text = "Buscando ATMs...\nNinguno disponible"
                    task.wait(2)
                else
                    for _, data in ipairs(atms) do
                        if not atmFarming then break end
                        robATM(data)
                        infoLabel.Text = "Robando ATM...\nDisponibles: " .. #atms
                        task.wait(CONFIG.ATMWaitTime)
                    end
                end
                task.wait(0.5)
            end
        end)
    else
        atmBtn.Text = "ATM AutoFarm: OFF"
        atmBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
    end
end

-- Toggle Delivery (búsqueda básica)
local function toggleDelivery()
    deliveryFarming = not deliveryFarming
    
    if deliveryFarming then
        deliveryBtn.Text = "Delivery AutoFarm: ON"
        deliveryBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        
        task.spawn(function()
            while deliveryFarming do
                -- Busca objetos que parezcan puntos de delivery
                local found = false
                for _, obj in pairs(workspace:GetDescendants()) do
                    if not deliveryFarming then break end
                    local name = string.lower(obj.Name)
                    if (string.find(name, "package") or string.find(name, "delivery") or string.find(name, "dropoff") or string.find(name, "pickup")) 
                       and (obj:IsA("BasePart") or obj:IsA("Model")) then
                        local part = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")) or obj
                        if part then
                            local root = getHRP()
                            if root then
                                root.CFrame = CFrame.new(part.Position + Vector3.new(0, 5, 0))
                                infoLabel.Text = "Yendo a punto Delivery..."
                                found = true
                                task.wait(CONFIG.DeliveryWaitTime)
                            end
                        end
                    end
                end
                if not found then
                    infoLabel.Text = "Buscando puntos Delivery...\nNo se encontraron"
                    task.wait(2)
                end
                task.wait(0.4)
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
    infoLabel.Text = "Farmeo finalizado"
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
limitBox.FocusLost:Connect(function(enter) if enter then applyLimit() end end)

player.CharacterAdded:Connect(function(char)
    character = char
    hrp = char:WaitForChild("HumanoidRootPart")
end)

print("✅ Driving Empire Farm cargado - Detecta ATMs automáticamente")
