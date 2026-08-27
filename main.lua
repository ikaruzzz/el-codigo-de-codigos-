--[[
    Driving Empire - Delivery por SÍMBOLOS
    Recogida = icono de caja 📦
    Entrega  = icono de pin 📍
]]

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

repeat task.wait() until player.Character and player.Character:FindFirstChild("HumanoidRootPart")

if player.PlayerGui:FindFirstChild("DeliverySymbols") then
    player.PlayerGui.DeliverySymbols:Destroy()
end

local CONFIG = {
    WaitPickup = 3.5,
    WaitDelivery = 3.2,
    Between = 1.0,
    ScanEvery = 2,
    MaxDistance = 6000,
}

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
local startJob = remotes and remotes:FindFirstChild("RequestStartJobSession")

local running = false
local phase = "PICKUP"
local scanCounter = 0
local lastPos = nil

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "DeliverySymbols"
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
title.Text = "Delivery · Símbolos"
title.TextColor3 = Color3.new(1,1,1)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
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
        root.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0))
    end
end

local function tryAcceptJob()
    if startJob then
        pcall(function() startJob:FireServer("Delivery", "jobPad") end)
        pcall(function() startJob:FireServer("DeliveryDriver", "jobPad") end)
    end
end

-- Obtener posición mundial de un BillboardGui / Attachment / Part
local function getWorldPosition(obj)
    if not obj then return nil end

    if obj:IsA("BasePart") then
        return obj.Position
    end
    if obj:IsA("Model") then
        local p = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
        return p and p.Position
    end
    if obj:IsA("Attachment") then
        return obj.WorldPosition
    end
    if obj:IsA("BillboardGui") then
        if obj.Adornee then
            if obj.Adornee:IsA("BasePart") then return obj.Adornee.Position end
            if obj.Adornee:IsA("Attachment") then return obj.Adornee.WorldPosition end
            if obj.Adornee:IsA("Model") then
                local p = obj.Adornee.PrimaryPart or obj.Adornee:FindFirstChildWhichIsA("BasePart")
                return p and p.Position
            end
        end
        local parent = obj.Parent
        if parent then
            if parent:IsA("BasePart") then return parent.Position end
            if parent:IsA("Attachment") then return parent.WorldPosition end
            if parent:IsA("Model") then
                local p = parent.PrimaryPart or parent:FindFirstChildWhichIsA("BasePart")
                return p and p.Position
            end
        end
    end
    return nil
end

local PICKUP_KEYS = {
    "package", "box", "parcel", "crate", "pickup", "cargo", "shipment"
}

local DELIVERY_KEYS = {
    "pin", "marker", "waypoint", "destination", "dropoff", "drop",
    "deliver", "location", "objective", "goal", "finish"
}

local function nameMatches(str, keys)
    str = string.lower(str or "")
    for _, k in ipairs(keys) do
        if string.find(str, k) then return true end
    end
    return false
end

--[[
    Busca símbolos flotantes del trabajo:
    - BillboardGui
    - ImageLabel / TextLabel dentro de billboards
    - Attachments / partes asociadas al icono
]]
local function findSymbols(kind)
    local root = getHRP()
    if not root then return {} end
    local rootPos = root.Position
    local keys = (kind == "PICKUP") and PICKUP_KEYS or DELIVERY_KEYS
    local results = {}
    local seen = {}
    local checked = 0

    for _, obj in ipairs(workspace:GetDescendants()) do
        checked += 1
        if checked % 600 == 0 then task.wait() end

        local hit = false
        local label = obj.Name

        -- BillboardGui por nombre
        if obj:IsA("BillboardGui") and nameMatches(obj.Name, keys) then
            hit = true
        end

        -- ImageLabel / TextLabel dentro de billboard (icono)
        if (obj:IsA("ImageLabel") or obj:IsA("ImageButton") or obj:IsA("TextLabel")) then
            if nameMatches(obj.Name, keys) then
                hit = true
            end
            -- a veces el asset no tiene nombre útil; miramos el billboard padre
            local bb = obj:FindFirstAncestorOfClass("BillboardGui")
            if bb and nameMatches(bb.Name, keys) then
                hit = true
                obj = bb
            end
        end

        -- Attachment / Part con nombre de objetivo
        if (obj:IsA("Attachment") or obj:IsA("BasePart")) and nameMatches(obj.Name, keys) then
            hit = true
        end

        if hit then
            local pos = getWorldPosition(obj)
            if pos then
                local dist = (pos - rootPos).Magnitude
                if dist <= CONFIG.MaxDistance then
                    local key = string.format("%.0f_%.0f_%.0f", pos.X, pos.Y, pos.Z)
                    if not seen[key] then
                        if not (lastPos and (pos - lastPos).Magnitude < 10) then
                            seen[key] = true
                            table.insert(results, {
                                object = obj,
                                position = pos,
                                distance = dist,
                                name = label
                            })
                        end
                    end
                end
            end
        end
    end

    table.sort(results, function(a, b) return a.distance < b.distance end)
    return results
end

local function farmLoop()
    tryAcceptJob()
    setStatus("Buscando símbolos...")
    phase = "PICKUP"

    while running do
        scanCounter += 1

        if phase == "PICKUP" then
            local list = findSymbols("PICKUP")
            setStatus("Cajas 📦: " .. #list)

            if #list == 0 then
                tryAcceptJob()
                setStatus("Sin icono de caja\nReintentando...")
                task.wait(1.5)
            else
                for i, data in ipairs(list) do
                    if not running then break end
                    lastPos = data.position
                    setStatus("RECOGIDA " .. i .. "/" .. #list .. "\n" .. data.name)
                    tpTo(data.position)
                    task.wait(CONFIG.WaitPickup)
                end
                phase = "DELIVERY"
                lastPos = nil
            end
        else
            local list = findSymbols("DELIVERY")
            setStatus("Pines 📍: " .. #list)

            if #list == 0 then
                setStatus("Sin icono de entrega\nReintentando...")
                task.wait(1.3)
                -- si no hay pin, volver a recogida
                phase = "PICKUP"
            else
                for i, data in ipairs(list) do
                    if not running then break end
                    lastPos = data.position
                    setStatus("ENTREGA " .. i .. "/" .. #list .. "\n" .. data.name)
                    tpTo(data.position)
                    task.wait(CONFIG.WaitDelivery)
                end
                phase = "PICKUP"
                lastPos = nil
                tryAcceptJob()
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

print("[DELIVERY] Modo símbolos: caja=recogida | pin=entrega")
