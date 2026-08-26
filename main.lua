-- Driving Empire Farm - Corrección ATM activo + Delivery con señal de caja
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
    ATMActiveWait = 5.2,
    ATMInactiveWait = 1.4,
    BetweenATM = 0.3,
    DeliveryWait = 2.4,
}

-- ====================== REMOTES ======================
local remotes = ReplicatedStorage:WaitForChild("Remotes", 8)

local function getRemote(name)
    return remotes and remotes:FindFirstChild(name)
end

local bustStart = getRemote("AttemptATMBustStart")
local bustEnd   = getRemote("AttemptATMBustComplete")
local startJob  = getRemote("RequestStartJobSession")

-- ====================== ATMs ======================
local allATMPositions = {}

local function scanAllATMs()
    allATMPositions = {}
    local found = {}
    
    pcall(function()
        local spawners = workspace.Game.Jobs.CriminalATMSpawners
        for _, spawner in ipairs(spawners:GetChildren()) do
            local part = spawner:IsA("BasePart") and spawner or spawner:FindFirstChildWhichIsA("BasePart")
            if part then
                local key = math.floor(part.Position.X) .. "_" .. math.floor(part.Position.Z)
                if not found[key] then
                    found[key] = true
                    table.insert(allATMPositions, {
                        position = part.Position,
                        spawner = spawner
                    })
                end
            end
        end
    end)
    
    print("[Farm] ATMs: " .. #allATMPositions)
end

scanAllATMs()

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

Instance.new("UIStroke", panel).Color = Color3.fromRGB(60, 60, 70)
Instance.new("UIStroke", panel).Thickness = 1.5

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
infoLabel.Text = "ATMs: " .. #allATMPositions .. "\nListo"
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
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getCurrentMoney()
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        local m = ls:FindFirstChild("Cash") or ls:FindFirstChild("Money")
        if m then return m.Value end
    end
    return player:GetAttribute("Cash") or player:GetAttribute("Money") or 0
end

local function joinOutlaw()
    if startJob then
        pcall(function() startJob:FireServer("Criminal", "jobPad") end)
        task.wait(0.6)
    end
end

local function joinDeliveryJob()
    if startJob then
        pcall(function() startJob:FireServer("Delivery", "jobPad") end)
        pcall(function() startJob:FireServer("DeliveryDriver", "jobPad") end)
        task.wait(0.8)
    end
end

-- DETECCIÓN MEJORADA DE ATM ACTIVO
local function getATMStatus(spawner)
    if not spawner then return false, nil end
    
    local atm = spawner:FindFirstChild("CriminalATM")
    if not atm then 
        -- A veces el ATM está directamente en el spawner
        atm = spawner
    end
    
    -- Varias formas de saber si está activo
    local state = atm:GetAttribute("State")
    if state == "Normal" or state == "Available" or state == "Ready" then
        return true, atm
    end
    
    -- Si no tiene State, asumimos que puede estar activo e intentamos robar
    if state == nil then
        return true, atm
    end
    
    return false, atm
end

local function robATM(data)
    local root = getHRP()
    if not root then return end
    
    root.CFrame = CFrame.new(data.position + Vector3.new(0, 5, 0))
    task.wait(0.3)
    
    local active, atmModel = getATMStatus(data.spawner)
    
    if active then
        infoLabel.Text = "ATM ACTIVO\nRobando..."
        
        if bustStart and atmModel then
            pcall(function()
                if bustStart:IsA("RemoteFunction") then
                    bustStart:InvokeServer(atmModel)
                else
                    bustStart:FireServer(atmModel)
                end
            end)
        end
        
        task.wait(CONFIG.ATMActiveWait)
        
        if bustEnd and atmModel then
            pcall(function()
                if bustEnd:IsA("RemoteFunction") then
                    bustEnd:InvokeServer(atmModel)
                else
                    bustEnd:FireServer(atmModel)
                end
            end)
        end
    else
        infoLabel.Text = "Inactivo → siguiente"
        task.wait(CONFIG.ATMInactiveWait)
    end
end

local function applyLimit()
    local num = tonumber((limitBox.Text or ""):gsub("%D", ""))
    if num and num > 0 then
        CONFIG.MoneyLimit = num
        limitBox.Text = tostring(num)
        infoLabel.Text = "Límite: $" .. num
    end
end

-- ====================== ATM ======================
local function toggleATM()
    atmFarming = not atmFarming
    
    if atmFarming then
        atmBtn.Text = "ATM AutoFarm: ON"
        atmBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        joinOutlaw()
        
        task.spawn(function()
            while atmFarming do
                if #allATMPositions == 0 then
                    scanAllATMs()
                    task.wait(2)
                else
                    for i, data in ipairs(allATMPositions) do
                        if not atmFarming then break end
                        infoLabel.Text = "ATM " .. i .. "/" .. #allATMPositions
                        robATM(data)
                        task.wait(CONFIG.BetweenATM)
                    end
                end
                task.wait(0.3)
            end
        end)
    else
        atmBtn.Text = "ATM AutoFarm: OFF"
        atmBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
        infoLabel.Text = "ATM detenido"
    end
end

-- ====================== DELIVERY (SEÑAL DE CAJA) ======================
local function findBoxMarkers()
    local markers = {}
    
    for _, obj in pairs(workspace:GetDescendants()) do
        local name = string.lower(obj.Name)
        
        -- Busca la señal/caja que aparece cuando eres Delivery
        if (string.find(name, "box") 
         or string.find(name, "package") 
         or string.find(name, "parcel") 
         or string.find(name, "crate")
         or string.find(name, "marker")
         or string.find(name, "pickup")
         or string.find(name, "delivery")
         or string.find(name, "arrow")
         or string.find(name, "waypoint")
         or string.find(name, "objective")) 
         and (obj:IsA("BasePart") or obj:IsA("Model") or obj:IsA("MeshPart") or obj:IsA("BillboardGui") or obj:IsA("Attachment")) then
            
            local part = nil
            if obj:IsA("BasePart") or obj:IsA("MeshPart") then
                part = obj
            elseif obj:IsA("Model") then
                part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            elseif obj:IsA("Attachment") then
                part = obj.Parent
            end
            
            if part and part:IsA("BasePart") then
                table.insert(markers, part)
            end
        end
    end
    
    return markers
end

local function toggleDelivery()
    deliveryFarming = not deliveryFarming
    
    if deliveryFarming then
        deliveryBtn.Text = "Delivery AutoFarm: ON"
        deliveryBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        
        joinDeliveryJob()
        infoLabel.Text = "Trabajo aceptado\nBuscando señal de caja..."
        
        task.spawn(function()
            while deliveryFarming do
                local markers = findBoxMarkers()
                
                if #markers == 0 then
                    infoLabel.Text = "No se encontró\nla señal de caja"
                    task.wait(2)
                else
                    -- Ir a todas las señales de caja (recogida)
                    for i, part in ipairs(markers) do
                        if not deliveryFarming then break end
                        local root = getHRP()
                        if root and part and part.Parent then
                            root.CFrame = CFrame.new(part.Position + Vector3.new(0, 6, 0))
                            infoLabel.Text = "Caja/Recogida " .. i .. "/" .. #markers
                            task.wait(CONFIG.DeliveryWait)
                        end
                    end
                    
                    -- Después de recoger, vuelve a buscar (puede cambiar a punto de entrega)
                    task.wait(1)
                    local deliverMarkers = findBoxMarkers()
                    for i, part in ipairs(deliverMarkers) do
                        if not deliveryFarming then break end
                        local root = getHRP()
                        if root and part and part.Parent then
                            root.CFrame = CFrame.new(part.Position + Vector3.new(0, 6, 0))
                            infoLabel.Text = "Entrega " .. i .. "/" .. #deliverMarkers
                            task.wait(CONFIG.DeliveryWait)
                        end
                    end
                end
                
                task.wait(1)
            end
        end)
    else
        deliveryBtn.Text = "Delivery AutoFarm: OFF"
        deliveryBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 80)
        infoLabel.Text = "Delivery detenido"
    end
end

-- ====================== OTROS ======================
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

atmBtn.MouseButton1Click:Connect(toggleATM)
deliveryBtn.MouseButton1Click:Connect(toggleDelivery)
stopBtn.MouseButton1Click:Connect(stopAll)
applyBtn.MouseButton1Click:Connect(applyLimit)
minimizeBtn.MouseButton1Click:Connect(toggleMinimize)
limitBox.FocusLost:Connect(function(e) if e then applyLimit() end end)

player.CharacterAdded:Connect(function(char)
    char:WaitForChild("HumanoidRootPart")
end)

print("✅ Script cargado - ATMs: " .. #allATMPositions)
