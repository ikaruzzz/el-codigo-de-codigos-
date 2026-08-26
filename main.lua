--[[
    Driving Empire - Delivery por círculos AMARILLOS
    Detecta círculos amarillos medianos-grandes (zona de 4 paquetes)
    Se teletransporta dentro y repite el ciclo de recogida/entrega
]]

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

repeat task.wait() until player.Character and player.Character:FindFirstChild("HumanoidRootPart")

if player.PlayerGui:FindFirstChild("DeliveryYellowCircles") then
    player.PlayerGui.DeliveryYellowCircles:Destroy()
end

-- ====================== CONFIG ======================
local CONFIG = {
    WaitInCircle = 3.0,     -- tiempo dentro del círculo
    BetweenCircles = 0.8,   -- pausa al cambiar de círculo
    RescanDelay = 1.5,      -- si no encuentra ninguno
    MaxDistance = 5000,

    -- Tamaño del círculo (mediano-grande)
    MinSize = 6,            -- diámetro mínimo aprox
    MaxSize = 40,           -- diámetro máximo aprox
    MaxHeight = 4,          -- que sea relativamente plano

    -- Color amarillo (tolerancia)
    YellowTolerance = 0.35,
}

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
local startJob = remotes and remotes:FindFirstChild("RequestStartJobSession")

local running = false
local lastTarget = nil

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
title.Text = "Delivery · Círculos 🟡"
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
        root.CFrame = CFrame.new(pos + Vector3.new(0, 3.5, 0))
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

-- ¿Es color amarillo / dorado?
local function isYellow(color)
    if typeof(color) ~= "Color3" then return false end
    local r, g, b = color.R, color.G, color.B
    -- Amarillo: R y G altos, B más bajo
    return r > 0.55 and g > 0.45 and b < 0.55 and (r + g) > (b * 2.2)
end

-- ¿Tamaño de círculo mediano-grande y plano?
local function isMediumLargeFlat(part)
    local s = part.Size
    local diameter = math.max(s.X, s.Z)
    local height = s.Y
    return diameter >= CONFIG.MinSize
        and diameter <= CONFIG.MaxSize
        and height <= CONFIG.MaxHeight
end

local function scoreCircle(part, rootPos)
    local score = 0
    local s = part.Size
    local diameter = math.max(s.X, s.Z)

    if isYellow(part.Color) then score += 50 end
    if part.Material == Enum.Material.Neon then score += 15 end
    if part.Transparency > 0.15 and part.Transparency < 0.95 then score += 10 end
    if isMediumLargeFlat(part) then score += 25 end

    -- Preferir discos casi redondos
    if math.abs(s.X - s.Z) < 3 then score += 10 end

    local name = string.lower(part.Name)
    if string.find(name, "circle") or string.find(name, "zone")
    or string.find(name, "marker") or string.find(name, "package")
    or string.find(name, "delivery") or string.find(name, "pickup") then
        score += 20
    end

    local dist = (part.Position - rootPos).Magnitude
    -- un poco de preferencia a los más cercanos, sin ser lo único
    score += math.max(0, 30 - (dist / 100))

    return score, dist
end

local function findYellowCircles()
    local root = getHRP()
    if not root then return {} end
    local rootPos = root.Position
    local results = {}

    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local dist = (obj.Position - rootPos).Magnitude
            if dist <= CONFIG.MaxDistance then
                -- Filtro rápido: amarillo O forma de círculo mediano
                if isYellow(obj.Color) or isMediumLargeFlat(obj) then
                    if isMediumLargeFlat(obj) or isYellow(obj.Color) then
                        local sc, d = scoreCircle(obj, rootPos)
                        if sc >= 40 then -- umbral mínimo
                            table.insert(results, {
                                part = obj,
                                score = sc,
                                distance = d,
                                name = obj.Name
                            })
                        end
                    end
                end
            end
        end
    end

    table.sort(results, function(a, b)
        if a.score == b.score then
            return a.distance < b.distance
        end
        return a.score > b.score
    end)

    return results
end

-- ====================== LOOP ======================
local function farmLoop()
    tryAcceptJob()
    setStatus("Trabajo aceptado\nBuscando círculos amarillos...")

    while running do
        local circles = findYellowCircles()

        if #circles == 0 then
            setStatus("No hay círculos amarillos\nReintentando...")
            tryAcceptJob()
            task.wait(CONFIG.RescanDelay)
        else
            setStatus("Círculos encontrados: " .. #circles)

            for i, data in ipairs(circles) do
                if not running then break end

                -- Evitar repetir el mismo al instante
                if lastTarget == data.part and #circles > 1 then
                    continue
                end

                if data.part and data.part.Parent then
                    lastTarget = data.part
                    setStatus(string.format(
                        "Círculo %d/%d\n%s | score=%d",
                        i, #circles, data.name, math.floor(data.score)
                    ))

                    tpTo(data.part.Position)
                    task.wait(CONFIG.WaitInCircle)

                    -- Pequeño movimiento para “activar” la zona
                    local root = getHRP()
                    if root then
                        root.CFrame = root.CFrame * CFrame.new(0, 0, 1)
                        task.wait(0.2)
                        root.CFrame = root.CFrame * CFrame.new(0, 0, -1)
                    end

                    task.wait(CONFIG.BetweenCircles)
                end
            end
        end

        task.wait(0.4)
    end

    setStatus("Detenido")
end

-- ====================== BOTONES ======================
startBtn.MouseButton1Click:Connect(function()
    if running then return end
    running = true
    startBtn.Text = "EN MARCHA..."
    startBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
    task.spawn(farmLoop)
end)

stopBtn.MouseButton1Click:Connect(function()
    running = false
    lastTarget = nil
    startBtn.Text = "INICIAR"
    startBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 80)
    setStatus("Detenido")
end)

player.CharacterAdded:Connect(function(char)
    char:WaitForChild("HumanoidRootPart")
end)

print("[DELIVERY] Círculos amarillos listo")
