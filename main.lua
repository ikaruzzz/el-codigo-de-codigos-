--[[
    Driving Empire - Solo círculos de Delivery (recogida + entrega)
    Basado en las capturas: anillo amarillo/naranja + paquetes o pin
]]

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

repeat task.wait() until player.Character and player.Character:FindFirstChild("HumanoidRootPart")

if player.PlayerGui:FindFirstChild("DeliveryYellowCircles") then
    player.PlayerGui.DeliveryYellowCircles:Destroy()
end

local CONFIG = {
    WaitInCircle = 3.2,
    BetweenTargets = 1.0,
    RescanDelay = 1.5,
    MaxDistance = 6000,

    -- Anillo mediano-grande (como en las fotos)
    MinDiameter = 12,
    MaxDiameter = 55,
    MaxHeight = 3.5,
}

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
local startJob = remotes and remotes:FindFirstChild("RequestStartJobSession")

local running = false
local lastPos = nil

-- ====================== GUI ======================
local gui = Instance.new("ScreenGui")
gui.Name = "DeliveryYellowCircles"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 210, 0, 155)
panel.Position = UDim2.new(1, -230, 0.5, -80)
panel.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
panel.BorderSizePixel = 0
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 28)
title.BackgroundTransparency = 1
title.Text = "Delivery · Zonas reales"
title.TextColor3 = Color3.new(1,1,1)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.Parent = panel

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -12, 0, 48)
status.Position = UDim2.new(0, 6, 0, 30)
status.BackgroundTransparency = 1
status.Text = "Detenido"
status.TextColor3 = Color3.fromRGB(180,180,190)
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.TextWrapped = true
status.Parent = panel

local startBtn = Instance.new("TextButton")
startBtn.Size = UDim2.new(0, 180, 0, 32)
startBtn.Position = UDim2.new(0.5, -90, 0, 85)
startBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 80)
startBtn.Text = "INICIAR"
startBtn.TextColor3 = Color3.new(1,1,1)
startBtn.Font = Enum.Font.GothamBold
startBtn.TextSize = 13
startBtn.Parent = panel
Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 8)

local stopBtn = Instance.new("TextButton")
stopBtn.Size = UDim2.new(0, 180, 0, 28)
stopBtn.Position = UDim2.new(0.5, -90, 0, 121)
stopBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
stopBtn.Text = "DETENER"
stopBtn.TextColor3 = Color3.new(1,1,1)
stopBtn.Font = Enum.Font.GothamBold
stopBtn.TextSize = 12
stopBtn.Parent = panel
Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 8)

local function setStatus(t)
    status.Text = t
    print("[DELIVERY] " .. t)
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
        return true
    end
    return false
end

local function tryAcceptJob()
    if not startJob then return end
    pcall(function() startJob:FireServer("Delivery", "jobPad") end)
    pcall(function() startJob:FireServer("DeliveryDriver", "jobPad") end)
    task.wait(0.7)
end

local function isYellowOrange(color)
    if typeof(color) ~= "Color3" then return false end
    local r, g, b = color.R, color.G, color.B
    -- Amarillo / naranja dorado (como en las fotos)
    return r > 0.6 and g > 0.35 and b < 0.45 and r >= g * 0.85
end

local function isRingShape(part)
    local s = part.Size
    local diameter = math.max(s.X, s.Z)
    return diameter >= CONFIG.MinDiameter
        and diameter <= CONFIG.MaxDiameter
        and s.Y <= CONFIG.MaxHeight
        and math.abs(s.X - s.Z) < 8 -- casi redondo
end

-- ¿Hay cajas/paquetes cerca? (zona de recogida)
local function hasPackagesNearby(center, radius)
    radius = radius or 25
    local n = 0
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local name = string.lower(obj.Name)
            if string.find(name, "box") or string.find(name, "package")
            or string.find(name, "parcel") or string.find(name, "crate")
            or string.find(name, "cardboard") then
                local part = obj:IsA("BasePart") and obj or (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart"))
                if part and (part.Position - center).Magnitude <= radius then
                    n += 1
                end
            end
        end
    end
    return n
end

local function findDeliveryRings()
    local root = getHRP()
    if not root then return {} end
    local rootPos = root.Position
    local results = {}

    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and isRingShape(obj) then
            local dist = (obj.Position - rootPos).Magnitude
            if dist <= CONFIG.MaxDistance then
                local score = 0

                if isYellowOrange(obj.Color) then score += 40 end
                if obj.Material == Enum.Material.Neon then score += 15 end
                if obj.Transparency > 0.05 and obj.Transparency < 0.9 then score += 10 end

                local packages = hasPackagesNearby(obj.Position, math.max(obj.Size.X, obj.Size.Z) * 0.7)
                if packages >= 1 then
                    score += 35 -- muy probable zona de recogida
                end

                local name = string.lower(obj.Name)
                local parent = obj.Parent and string.lower(obj.Parent.Name) or ""
                if string.find(name, "circle") or string.find(name, "ring")
                or string.find(name, "zone") or string.find(name, "marker")
                or string.find(name, "delivery") or string.find(name, "pickup")
                or string.find(parent, "delivery") or string.find(parent, "job") then
                    score += 25
                end

                -- Evitar el mismo sitio que acabamos de visitar
                if lastPos and (obj.Position - lastPos).Magnitude < 8 then
                    score -= 20
                end

                if score >= 45 then
                    table.insert(results, {
                        part = obj,
                        score = score,
                        distance = dist,
                        packages = packages,
                        name = obj.Name,
                        kind = packages >= 1 and "PICKUP" or "DELIVERY?"
                    })
                end
            end
        end
    end

    table.sort(results, function(a, b)
        if a.score == b.score then return a.distance < b.distance end
        return a.score > b.score
    end)

    return results
end

-- ====================== LOOP ======================
local function farmLoop()
    tryAcceptJob()
    setStatus("Buscando anillos\nde Delivery...")

    while running do
        local rings = findDeliveryRings()

        if #rings == 0 then
            setStatus("Sin anillos válidos\nReintentando...")
            tryAcceptJob()
            task.wait(CONFIG.RescanDelay)
        else
            for i, data in ipairs(rings) do
                if not running then break end
                if data.part and data.part.Parent then
                    lastPos = data.part.Position
                    setStatus(string.format(
                        "%s %d/%d\n%s | cajas≈%d",
                        data.kind, i, #rings, data.name, data.packages
                    ))

                    tpTo(data.part.Position)
                    task.wait(CONFIG.WaitInCircle)

                    -- Micro-movimiento para activar la zona
                    local root = getHRP()
                    if root then
                        root.CFrame = root.CFrame * CFrame.new(1, 0, 0)
                        task.wait(0.25)
                        root.CFrame = root.CFrame * CFrame.new(-1, 0, 0)
                    end

                    task.wait(CONFIG.BetweenTargets)
                end
            end
        end

        task.wait(0.35)
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
    lastPos = nil
    startBtn.Text = "INICIAR"
    startBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 80)
    setStatus("Detenido")
end)

player.CharacterAdded:Connect(function(char)
    char:WaitForChild("HumanoidRootPart")
end)

print("[DELIVERY] Filtro de anillos amarillos/naranja listo")
