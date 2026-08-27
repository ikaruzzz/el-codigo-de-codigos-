--[[
    Driving Empire - Delivery (versión LIGERA, menos lag)
    Escanea poco, cachea círculos, no satura el juego
]]

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

repeat task.wait() until player.Character and player.Character:FindFirstChild("HumanoidRootPart")

if player.PlayerGui:FindFirstChild("DeliveryLite") then
    player.PlayerGui.DeliveryLite:Destroy()
end

local CONFIG = {
    WaitInCircle = 3.0,
    BetweenTargets = 1.2,
    ScanEvery = 4,          -- solo reescanea cada X ciclos (importante para el lag)
    MaxDistance = 3500,
    MinDiameter = 12,
    MaxDiameter = 55,
    MaxHeight = 3.5,
}

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
local startJob = remotes and remotes:FindFirstChild("RequestStartJobSession")

local running = false
local cachedRings = {}
local scanCounter = 0
local lastPos = nil

-- ====================== GUI ======================
local gui = Instance.new("ScreenGui")
gui.Name = "DeliveryLite"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 200, 0, 150)
panel.Position = UDim2.new(1, -220, 0.5, -75)
panel.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
panel.BorderSizePixel = 0
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 26)
title.BackgroundTransparency = 1
title.Text = "Delivery Lite"
title.TextColor3 = Color3.new(1,1,1)
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.Parent = panel

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -12, 0, 45)
status.Position = UDim2.new(0, 6, 0, 28)
status.BackgroundTransparency = 1
status.Text = "Detenido"
status.TextColor3 = Color3.fromRGB(180,180,190)
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.TextWrapped = true
status.Parent = panel

local startBtn = Instance.new("TextButton")
startBtn.Size = UDim2.new(0, 170, 0, 32)
startBtn.Position = UDim2.new(0.5, -85, 0, 80)
startBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 80)
startBtn.Text = "INICIAR"
startBtn.TextColor3 = Color3.new(1,1,1)
startBtn.Font = Enum.Font.GothamBold
startBtn.TextSize = 13
startBtn.Parent = panel
Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 8)

local stopBtn = Instance.new("TextButton")
stopBtn.Size = UDim2.new(0, 170, 0, 28)
stopBtn.Position = UDim2.new(0.5, -85, 0, 116)
stopBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
stopBtn.Text = "DETENER"
stopBtn.TextColor3 = Color3.new(1,1,1)
stopBtn.Font = Enum.Font.GothamBold
stopBtn.TextSize = 12
stopBtn.Parent = panel
Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 8)

local function setStatus(t)
    status.Text = t
end

-- ====================== UTILS ======================
local function getHRP()
    local c = player.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function tpTo(pos)
    local root = getHRP()
    if root and pos then
        root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    end
end

local function tryAcceptJob()
    if startJob then
        pcall(function() startJob:FireServer("Delivery", "jobPad") end)
        pcall(function() startJob:FireServer("DeliveryDriver", "jobPad") end)
    end
end

local function isYellowOrange(c)
    if typeof(c) ~= "Color3" then return false end
    return c.R > 0.6 and c.G > 0.35 and c.B < 0.45
end

local function isRing(part)
    local s = part.Size
    local d = math.max(s.X, s.Z)
    return d >= CONFIG.MinDiameter and d <= CONFIG.MaxDiameter
        and s.Y <= CONFIG.MaxHeight and math.abs(s.X - s.Z) < 10
end

-- Escaneo LENTO y por partes (no congela)
local function scanRings()
    local root = getHRP()
    if not root then return {} end

    local rootPos = root.Position
    local found = {}
    local checked = 0

    -- Solo mira hijos directos de carpetas grandes + un pase limitado
    local roots = {workspace}
    pcall(function()
        if workspace:FindFirstChild("Game") then
            table.insert(roots, workspace.Game)
        end
    end)

    for _, base in ipairs(roots) do
        for _, obj in ipairs(base:GetDescendants()) do
            checked += 1
            -- Ceder el hilo cada cierto número de objetos
            if checked % 400 == 0 then
                task.wait()
            end

            if obj:IsA("BasePart") and isRing(obj) then
                local dist = (obj.Position - rootPos).Magnitude
                if dist <= CONFIG.MaxDistance and isYellowOrange(obj.Color) then
                    local score = 40
                    if obj.Material == Enum.Material.Neon then score += 15 end
                    if obj.Transparency > 0.05 then score += 10 end

                    table.insert(found, {
                        part = obj,
                        score = score,
                        distance = dist,
                        name = obj.Name
                    })
                end
            end
        end
    end

    table.sort(found, function(a, b)
        if a.score == b.score then return a.distance < b.distance end
        return a.score > b.score
    end)

    -- Máximo 8 objetivos por ciclo
    if #found > 8 then
        local trim = {}
        for i = 1, 8 do trim[i] = found[i] end
        found = trim
    end

    return found
end

local function farmLoop()
    tryAcceptJob()
    setStatus("Escaneando (ligero)...")
    task.wait(0.5)

    cachedRings = scanRings()
    setStatus("Anillos: " .. #cachedRings)

    while running do
        scanCounter += 1

        -- Reescanear solo de vez en cuando
        if scanCounter >= CONFIG.ScanEvery or #cachedRings == 0 then
            setStatus("Reescaneando...")
            task.wait(0.2)
            cachedRings = scanRings()
            scanCounter = 0
            setStatus("Anillos: " .. #cachedRings)
        end

        if #cachedRings == 0 then
            tryAcceptJob()
            setStatus("Sin anillos\nEsperando...")
            task.wait(2)
        else
            for i, data in ipairs(cachedRings) do
                if not running then break end
                if data.part and data.part.Parent then
                    -- Saltar si es el mismo sitio
                    if lastPos and (data.part.Position - lastPos).Magnitude < 10 then
                        continue
                    end

                    lastPos = data.part.Position
                    setStatus("Zona " .. i .. "/" .. #cachedRings .. "\n" .. data.name)
                    tpTo(data.part.Position)
                    task.wait(CONFIG.WaitInCircle)
                    task.wait(CONFIG.BetweenTargets)
                end
            end
        end

        task.wait(0.5)
    end

    setStatus("Detenido")
end

startBtn.MouseButton1Click:Connect(function()
    if running then return end
    running = true
    startBtn.Text = "EN MARCHA..."
    startBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
    task.spawn(farmLoop)
end)

stopBtn.MouseButton1Click:Connect(function()
    running = false
    startBtn.Text = "INICIAR"
    startBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 80)
    setStatus("Detenido")
end)

print("[DELIVERY] Versión lite cargada (menos lag)")
