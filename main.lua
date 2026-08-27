--[[
    Driving Empire - Delivery Lite v2
    Filtra flechas de calle y líneas de helicóptero
    Prioriza: 1) recogida (cajas)  2) entrega (anillo sin cajas)
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
    WaitPickup = 3.2,
    WaitDelivery = 3.0,
    Between = 1.0,
    ScanEvery = 3,
    MaxDistance = 4000,

    -- Anillo tipo Delivery (como tus fotos)
    MinDiameter = 14,
    MaxDiameter = 50,
    MaxHeight = 2.5,
    MaxElongation = 1.35, -- X y Z casi iguales (no líneas)
}

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
local startJob = remotes and remotes:FindFirstChild("RequestStartJobSession")

local running = false
local cached = { pickup = {}, delivery = {} }
local scanCounter = 0
local phase = "PICKUP" -- PICKUP -> DELIVERY -> PICKUP ...
local lastPos = nil

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "DeliveryLite"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 210, 0, 160)
panel.Position = UDim2.new(1, -230, 0.5, -80)
panel.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
panel.BorderSizePixel = 0
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 26)
title.BackgroundTransparency = 1
title.Text = "Delivery Lite v2"
title.TextColor3 = Color3.new(1,1,1)
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.Parent = panel

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -12, 0, 50)
status.Position = UDim2.new(0, 6, 0, 28)
status.BackgroundTransparency = 1
status.Text = "Detenido"
status.TextColor3 = Color3.fromRGB(180,180,190)
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.TextWrapped = true
status.Parent = panel

local startBtn = Instance.new("TextButton")
startBtn.Size = UDim2.new(0, 180, 0, 32)
startBtn.Position = UDim2.new(0.5, -90, 0, 88)
startBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 80)
startBtn.Text = "INICIAR"
startBtn.TextColor3 = Color3.new(1,1,1)
startBtn.Font = Enum.Font.GothamBold
startBtn.TextSize = 13
startBtn.Parent = panel
Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 8)

local stopBtn = Instance.new("TextButton")
stopBtn.Size = UDim2.new(0, 180, 0, 28)
stopBtn.Position = UDim2.new(0.5, -90, 0, 124)
stopBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
stopBtn.Text = "DETENER"
stopBtn.TextColor3 = Color3.new(1,1,1)
stopBtn.Font = Enum.Font.GothamBold
stopBtn.TextSize = 12
stopBtn.Parent = panel
Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 8)

local function setStatus(t) status.Text = t end

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
    return c.R > 0.55 and c.G > 0.35 and c.B < 0.5
end

-- Rechaza líneas, flechas de calle, marcas de heli
local function isValidRing(part)
    local s = part.Size
    local d = math.max(s.X, s.Z)
    local minSide = math.min(s.X, s.Z)

    -- Debe ser anillo, no línea larga
    if d < CONFIG.MinDiameter or d > CONFIG.MaxDiameter then return false end
    if s.Y > CONFIG.MaxHeight then return false end
    if minSide < 8 then return false end -- evita líneas finas
    if (d / math.max(minSide, 0.1)) > CONFIG.MaxElongation then return false end

    -- Nombres típicos de cosas que NO queremos
    local n = string.lower(part.Name)
    local p = part.Parent and string.lower(part.Parent.Name) or ""
    if string.find(n, "arrow") or string.find(n, "heli") or string.find(n, "helipad")
    or string.find(n, "runway") or string.find(n, "road") or string.find(n, "lane")
    or string.find(n, "street") or string.find(n, "traffic") or string.find(n, "sign")
    or string.find(p, "heli") or string.find(p, "airport") or string.find(p, "road") then
        return false
    end

    return isYellowOrange(part.Color)
end

local function countPackagesNear(center, radius)
    local n = 0
    for _, obj in pairs(workspace:GetDescendants()) do
        if n >= 4 then break end
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local name = string.lower(obj.Name)
            if string.find(name, "box") or string.find(name, "package")
            or string.find(name, "parcel") or string.find(name, "crate") then
                local part = obj:IsA("BasePart") and obj or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                if part and (part.Position - center).Magnitude <= radius then
                    n += 1
                end
            end
        end
    end
    return n
end

local function scan()
    local root = getHRP()
    if not root then return { pickup = {}, delivery = {} } end
    local rootPos = root.Position
    local pickups, deliveries = {}, {}
    local checked = 0

    for _, obj in ipairs(workspace:GetDescendants()) do
        checked += 1
        if checked % 500 == 0 then task.wait() end

        if obj:IsA("BasePart") and isValidRing(obj) then
            local dist = (obj.Position - rootPos).Magnitude
            if dist <= CONFIG.MaxDistance then
                if lastPos and (obj.Position - lastPos).Magnitude < 12 then
                    -- skip reciente
                else
                    local pkgs = countPackagesNear(obj.Position, math.max(obj.Size.X, obj.Size.Z) * 0.65)
                    local entry = {
                        part = obj,
                        distance = dist,
                        packages = pkgs,
                        name = obj.Name
                    }
                    if pkgs >= 1 then
                        table.insert(pickups, entry)
                    else
                        table.insert(deliveries, entry)
                    end
                end
            end
        end
    end

    table.sort(pickups, function(a,b) return a.distance < b.distance end)
    table.sort(deliveries, function(a,b) return a.distance < b.distance end)

    -- limitar
    while #pickups > 5 do table.remove(pickups) end
    while #deliveries > 5 do table.remove(deliveries) end

    return { pickup = pickups, delivery = deliveries }
end

local function farmLoop()
    tryAcceptJob()
    setStatus("Escaneando zonas...")
    task.wait(0.4)
    cached = scan()
    phase = "PICKUP"

    while running do
        scanCounter += 1
        if scanCounter >= CONFIG.ScanEvery then
            setStatus("Reescaneando...")
            task.wait(0.15)
            cached = scan()
            scanCounter = 0
        end

        if phase == "PICKUP" then
            if #cached.pickup == 0 then
                setStatus("Sin recogida\nBuscando...")
                tryAcceptJob()
                task.wait(1.5)
                cached = scan()
            else
                local data = cached.pickup[1]
                if data.part and data.part.Parent then
                    lastPos = data.part.Position
                    setStatus("RECOGIDA\n" .. data.name .. " | cajas≈" .. data.packages)
                    tpTo(data.part.Position)
                    task.wait(CONFIG.WaitPickup)
                    phase = "DELIVERY"
                    scanCounter = CONFIG.ScanEvery -- forzar reescaneo tras recogida
                end
            end
        else -- DELIVERY
            if #cached.delivery == 0 then
                setStatus("Sin entrega\nBuscando...")
                task.wait(1.2)
                cached = scan()
                -- si no hay entrega, volver a intentar recogida
                if #cached.delivery == 0 then
                    phase = "PICKUP"
                end
            else
                local data = cached.delivery[1]
                if data.part and data.part.Parent then
                    lastPos = data.part.Position
                    setStatus("ENTREGA\n" .. data.name)
                    tpTo(data.part.Position)
                    task.wait(CONFIG.WaitDelivery)
                    phase = "PICKUP"
                    lastPos = nil
                    scanCounter = CONFIG.ScanEvery
                    tryAcceptJob()
                end
            end
        end

        task.wait(CONFIG.Between)
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

print("[DELIVERY] Lite v2 - filtra calles/heli, prioriza recogida→entrega")
