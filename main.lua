--[[
    Driving Empire - Delivery (caja + pin)
    - Acepta el trabajo UNA sola vez
    - SOLO se teletransporta a: caja (recogida) o pin (entrega)
    - No va a policía ni a otros marcadores
]]

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

repeat task.wait() until player.Character and player.Character:FindFirstChild("HumanoidRootPart")

if player.PlayerGui:FindFirstChild("DeliveryOnlySymbols") then
    player.PlayerGui.DeliveryOnlySymbols:Destroy()
end

local CONFIG = {
    WaitPickup = 3.5,
    WaitDelivery = 3.5,
    Between = 1.2,
    MaxDistance = 5000,
}

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
local startJob = remotes and remotes:FindFirstChild("RequestStartJobSession")

local running = false
local jobAcceptedOnce = false
local phase = "PICKUP" -- PICKUP | DELIVERY
local lastPos = nil

-- ====================== GUI ======================
local gui = Instance.new("ScreenGui")
gui.Name = "DeliveryOnlySymbols"
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
title.Text = "Delivery · Caja + Pin"
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
        root.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0))
        return true
    end
    return false
end

local function acceptJobOnce()
    if jobAcceptedOnce then return end
    if startJob then
        pcall(function() startJob:FireServer("Delivery", "jobPad") end)
        pcall(function() startJob:FireServer("DeliveryDriver", "jobPad") end)
        task.wait(1)
    end
    jobAcceptedOnce = true
    setStatus("Trabajo aceptado (solo 1 vez)")
end

local function billboardPosition(bb)
    if not bb or not bb:IsA("BillboardGui") then return nil end
    if bb.Adornee then
        if bb.Adornee:IsA("BasePart") then return bb.Adornee.Position end
        if bb.Adornee:IsA("Attachment") then return bb.Adornee.WorldPosition end
        if bb.Adornee:IsA("Model") then
            local p = bb.Adornee.PrimaryPart or bb.Adornee:FindFirstChildWhichIsA("BasePart")
            return p and p.Position
        end
    end
    local par = bb.Parent
    if par then
        if par:IsA("BasePart") then return par.Position end
        if par:IsA("Attachment") then return par.WorldPosition end
        if par:IsA("Model") then
            local p = par.PrimaryPart or par:FindFirstChildWhichIsA("BasePart")
            return p and p.Position
        end
    end
    return nil
end

local function isIconBillboard(bb)
    if not bb:IsA("BillboardGui") or not bb.Enabled then return false end
    for _, ch in ipairs(bb:GetDescendants()) do
        if (ch:IsA("ImageLabel") or ch:IsA("ImageButton")) and ch.Image ~= "" and ch.Visible ~= false then
            return true
        end
    end
    return false
end

-- Bloquear policía y otros trabajos
local BLOCK = {
    "police", "cop", "security", "officer", "sheriff",
    "criminal", "outlaw", "jobpad", "job_pad",
    "arrest", "bail", "wanted", "citizen"
}

local function isBlocked(blob)
    for _, w in ipairs(BLOCK) do
        if string.find(blob, w) then return true end
    end
    return false
end

-- SOLO devuelve PICKUP, DELIVERY o nil (nada de UNKNOWN)
local function classifySymbol(bb)
    local texts = { string.lower(bb.Name) }
    if bb.Parent then table.insert(texts, string.lower(bb.Parent.Name)) end
    for _, ch in ipairs(bb:GetDescendants()) do
        table.insert(texts, string.lower(ch.Name))
        if ch:IsA("TextLabel") or ch:IsA("TextButton") then
            table.insert(texts, string.lower(ch.Text or ""))
        end
    end
    local blob = table.concat(texts, " ")

    if isBlocked(blob) then
        return nil
    end

    local isBox =
        string.find(blob, "box") or string.find(blob, "package") or
        string.find(blob, "parcel") or string.find(blob, "crate") or
        string.find(blob, "pickup") or string.find(blob, "cargo")

    local isPin =
        string.find(blob, "pin") or string.find(blob, "marker") or
        string.find(blob, "waypoint") or string.find(blob, "location") or
        string.find(blob, "dropoff") or string.find(blob, "drop") or
        string.find(blob, "deliver") or string.find(blob, "destination") or
        string.find(blob, "goal") or string.find(blob, "objective")

    -- Si tiene ambos, priorizar por fase no aplica aquí; preferir box si es box
    if isBox and not isPin then return "PICKUP" end
    if isPin and not isBox then return "DELIVERY" end
    if isBox then return "PICKUP" end
    if isPin then return "DELIVERY" end
    return nil -- desconocido = NO usar (evita teleports random)
end

-- Solo símbolos del tipo pedido (caja O pin)
local function findSymbols(wantedPhase)
    local root = getHRP()
    if not root then return {} end
    local rootPos = root.Position
    local list = {}
    local seen = {}
    local n = 0

    for _, obj in ipairs(workspace:GetDescendants()) do
        n += 1
        if n % 700 == 0 then task.wait() end

        if obj:IsA("BillboardGui") and isIconBillboard(obj) then
            local kind = classifySymbol(obj)
            -- ESTRICTO: solo el tipo de la fase actual
            if kind == wantedPhase then
                local pos = billboardPosition(obj)
                if pos then
                    local dist = (pos - rootPos).Magnitude
                    if dist <= CONFIG.MaxDistance then
                        local key = string.format("%.0f_%.0f_%.0f", pos.X, pos.Y, pos.Z)
                        if not seen[key] then
                            if not (lastPos and (pos - lastPos).Magnitude < 12) then
                                seen[key] = true
                                table.insert(list, {
                                    position = pos,
                                    distance = dist,
                                    name = obj.Name,
                                    kind = kind
                                })
                            end
                        end
                    end
                end
            end
        end
    end

    table.sort(list, function(a, b) return a.distance < b.distance end)
    return list
end

-- ====================== LOOP ======================
local function farmLoop()
    acceptJobOnce()
    phase = "PICKUP"
    setStatus("Fase: RECOGIDA (caja)")

    while running do
        if phase == "PICKUP" then
            local list = findSymbols("PICKUP")
            setStatus("Cajas: " .. #list)

            if #list == 0 then
                setStatus("Esperando icono de caja...")
                task.wait(1.5)
            else
                -- SOLO el punto de recogida más cercano
                local data = list[1]
                lastPos = data.position
                setStatus("RECOGIDA\n" .. data.name)
                tpTo(data.position)
                task.wait(CONFIG.WaitPickup)

                phase = "DELIVERY"
                lastPos = nil
                setStatus("Fase: ENTREGA (pin)")
                task.wait(0.8)
            end

        else -- DELIVERY
            local list = findSymbols("DELIVERY")
            setStatus("Pines: " .. #list)

            if #list == 0 then
                setStatus("Esperando icono de entrega...")
                task.wait(1.5)
            else
                -- SOLO el punto de entrega más cercano
                local data = list[1]
                lastPos = data.position
                setStatus("ENTREGA\n" .. data.name)
                tpTo(data.position)
                task.wait(CONFIG.WaitDelivery)

                -- Volver SOLO a la caja (nada más)
                phase = "PICKUP"
                lastPos = nil
                setStatus("Fase: RECOGIDA (caja)")
                task.wait(1)
            end
        end

        task.wait(CONFIG.Between)
    end

    setStatus("Detenido")
end

startBtn.MouseButton1Click:Connect(function()
    if running then return end
    running = true
    jobAcceptedOnce = false
    phase = "PICKUP"
    lastPos = nil
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

print("[DELIVERY] Solo caja y pin | Sin otros teleports")
