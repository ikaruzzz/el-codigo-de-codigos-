--[[
    Driving Empire - Delivery (caja + pin + interacción)
    Base: tu script que funciona
    + Interactuar (ProximityPrompt / ClickDetector / zona)
    + Confirmar recogida y entrega de verdad
]]

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local player = Players.LocalPlayer

repeat task.wait() until player.Character and player.Character:FindFirstChild("HumanoidRootPart")

if player.PlayerGui:FindFirstChild("DeliveryOnlySymbols") then
    player.PlayerGui.DeliveryOnlySymbols:Destroy()
end

local CONFIG = {
    WaitPickup = 1.2,
    WaitDelivery = 1.2,
    InteractRadius = 25,
    ConfirmDelay = 0.6,
    MaxPackageTries = 12,
    MaxDeliveryTries = 10,
    Between = 0.8,
    MaxDistance = 5000,
}

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
local startJob = remotes and remotes:FindFirstChild("RequestStartJobSession")

local running = false
local jobAcceptedOnce = false
local phase = "PICKUP"
local lastPos = nil
local lockedDeliveryPos = nil
local packagesCollected = 0

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
        root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
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
    setStatus("Trabajo aceptado (1 vez)")
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

    if string.find(blob, "police") or string.find(blob, "security") or string.find(blob, "jobpad") then
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

    if isBox then return "PICKUP" end
    if isPin then return "DELIVERY" end
    return nil
end

local function findSymbols(wantedPhase)
    local root = getHRP()
    if not root then return {} end
    local rootPos = root.Position
    local list = {}
    local seen = {}
    local n = 0

    for _, obj in ipairs(workspace:GetDescendants()) do
        n = n + 1
        if n % 700 == 0 then task.wait() end
        if obj:IsA("BillboardGui") and isIconBillboard(obj) then
            if classifySymbol(obj) == wantedPhase then
                local pos = billboardPosition(obj)
                if pos then
                    local dist = (pos - rootPos).Magnitude
                    if dist <= CONFIG.MaxDistance then
                        local key = string.format("%.0f_%.0f_%.0f", pos.X, pos.Y, pos.Z)
                        if not seen[key] then
                            seen[key] = true
                            table.insert(list, {
                                position = pos,
                                distance = dist,
                                name = obj.Name
                            })
                        end
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.distance < b.distance end)
    return list
end

-- ====================== INTERACCIÓN ======================
local function getPromptWorldPos(prompt)
    local p = prompt.Parent
    if not p then return nil end
    if p:IsA("BasePart") then return p.Position end
    if p:IsA("Attachment") then return p.WorldPosition end
    if p:IsA("Model") then
        local bp = p.PrimaryPart or p:FindFirstChildWhichIsA("BasePart")
        return bp and bp.Position
    end
    return nil
end

local function firePrompt(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then
        return false
    end
    -- Métodos comunes en executors
    if fireproximityprompt then
        pcall(function() fireproximityprompt(prompt) end)
        return true
    end
    pcall(function()
        prompt:InputHoldBegin()
        task.wait(math.max(prompt.HoldDuration or 0, 0.05) + 0.05)
        prompt:InputHoldEnd()
    end)
    return true
end

local function fireClick(cd)
    if not cd or not cd:IsA("ClickDetector") then return false end
    if fireclickdetector then
        pcall(function() fireclickdetector(cd) end)
        return true
    end
    pcall(function()
        -- fallback débil
        cd.MouseClick:Fire(player)
    end)
    return true
end

-- Busca y activa interacciones cerca del jugador
local function interactNearby(centerPos)
    local root = getHRP()
    if not root then return 0 end
    centerPos = centerPos or root.Position
    local fired = 0

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            local pos = getPromptWorldPos(obj)
            if pos and (pos - centerPos).Magnitude <= CONFIG.InteractRadius then
                local action = string.lower(obj.ActionText or "")
                local object = string.lower(obj.ObjectText or "")
                local name = string.lower(obj.Name)
                -- priorizar textos de delivery/paquete
                local relevant =
                    string.find(action, "pick") or string.find(action, "collect") or
                    string.find(action, "deliver") or string.find(action, "drop") or
                    string.find(object, "package") or string.find(object, "box") or
                    string.find(name, "package") or string.find(name, "deliver") or
                    true -- si está en radio, intentar igual

                if relevant then
                    if firePrompt(obj) then
                        fired = fired + 1
                        print("[DELIVERY] ProximityPrompt: " .. obj.Name .. " / " .. (obj.ActionText or ""))
                    end
                end
            end
        elseif obj:IsA("ClickDetector") then
            local part = obj.Parent
            if part and part:IsA("BasePart") and (part.Position - centerPos).Magnitude <= CONFIG.InteractRadius then
                if fireClick(obj) then
                    fired = fired + 1
                    print("[DELIVERY] ClickDetector: " .. obj:GetFullName())
                end
            end
        end
    end

    -- Tecla E por si el prompt depende de input
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)

    return fired
end

-- Contar cajas físicas cerca (señal de paquetes aún en el suelo)
local function countGroundPackages(center, radius)
    radius = radius or 20
    local n = 0
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local name = string.lower(obj.Name)
            if string.find(name, "box") or string.find(name, "package")
            or string.find(name, "parcel") or string.find(name, "crate") then
                local part = obj:IsA("BasePart") and obj or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                if part and (part.Position - center).Magnitude <= radius then
                    n = n + 1
                end
            end
        end
    end
    return n
end

local function pinStillNear(pos)
    if not pos then return #findSymbols("DELIVERY") > 0 end
    for _, p in ipairs(findSymbols("DELIVERY")) do
        if (p.position - pos).Magnitude < 30 then return true end
    end
    return false
end

-- ====================== FASES CON INTERACCIÓN ======================
local function doPickupAt(pos)
    setStatus("Recogiendo paquetes...")
    print("[DELIVERY] Llegada a pickup - interactuando")
    tpTo(pos)
    task.wait(0.3)

    local before = countGroundPackages(pos, 22)
    packagesCollected = 0

    for i = 1, CONFIG.MaxPackageTries do
        if not running then return false end
        tpTo(pos)
        local fired = interactNearby(pos)
        setStatus("Pickup try " .. i .. " | prompts=" .. fired)

        -- pequeño movimiento para TouchInterest de zona
        local root = getHRP()
        if root then
            root.CFrame = root.CFrame * CFrame.new(1.5, 0, 0)
            task.wait(0.15)
            root.CFrame = root.CFrame * CFrame.new(-1.5, 0, 0)
        end

        task.wait(CONFIG.ConfirmDelay)
        local now = countGroundPackages(pos, 22)
        if now < before then
            packagesCollected = packagesCollected + (before - now)
            before = now
            print("[DELIVERY] Paquete recogido (cajas en suelo: " .. now .. ")")
            setStatus("Paquetes ~" .. packagesCollected)
        end

        -- Si ya no hay cajas en suelo o hay pin de entrega → recogida lista
        local pins = findSymbols("DELIVERY")
        if #pins > 0 and now <= 1 then
            print("[DELIVERY] Recogida CONFIRMADA (pin visible)")
            return true
        end
        if now == 0 and i >= 3 then
            print("[DELIVERY] Recogida CONFIRMADA (sin cajas en suelo)")
            return true
        end
    end

    -- Si aparece pin, aceptar y seguir
    if #findSymbols("DELIVERY") > 0 then
        print("[DELIVERY] Recogida asumida: pin de entrega activo")
        return true
    end

    print("[DELIVERY] Recogida NO confirmada del todo")
    return false
end

local function doDeliveryAt(pos)
    setStatus("Entregando...")
    print("[DELIVERY] Llegada a delivery - interactuando")
    lockedDeliveryPos = pos
    tpTo(pos)
    task.wait(0.3)

    for i = 1, CONFIG.MaxDeliveryTries do
        if not running then return false end
        tpTo(pos)
        local fired = interactNearby(pos)
        setStatus("Entrega try " .. i .. " | prompts=" .. fired)

        local root = getHRP()
        if root then
            root.CFrame = root.CFrame * CFrame.new(1.2, 0, 0)
            task.wait(0.12)
            root.CFrame = root.CFrame * CFrame.new(-1.2, 0, 0)
        end

        task.wait(CONFIG.ConfirmDelay)

        if not pinStillNear(pos) then
            print("[DELIVERY] Entrega CONFIRMADA (pin desapareció)")
            setStatus("Entrega CONFIRMADA")
            lockedDeliveryPos = nil
            return true
        end
        print("[DELIVERY] Entrega NO confirmada - reintento")
    end

    print("[DELIVERY] Entrega NO confirmada tras intentos")
    return false
end

-- ====================== LOOP ======================
local function farmLoop()
    acceptJobOnce()
    phase = "PICKUP"
    setStatus("Fase: RECOGIDA")

    while running do
        if phase == "PICKUP" then
            local list = findSymbols("PICKUP")
            setStatus("Cajas: " .. #list)
            if #list == 0 then
                task.wait(1.2)
            else
                local data = list[1]
                print("[DELIVERY] Pickup: " .. data.name)
                tpTo(data.position)
                task.wait(CONFIG.WaitPickup)

                local ok = doPickupAt(data.position)
                if ok then
                    phase = "DELIVERY"
                    setStatus("Fase: ENTREGA")
                    task.wait(0.5)
                else
                    setStatus("Reintentando pickup...")
                    task.wait(0.8)
                end
            end

        elseif phase == "DELIVERY" then
            local list = findSymbols("DELIVERY")
            setStatus("Pines: " .. #list)
            if #list == 0 then
                task.wait(1.2)
                -- si no hay pin, quizá ya entregó
                if #findSymbols("DELIVERY") == 0 and #findSymbols("PICKUP") > 0 then
                    phase = "PICKUP"
                end
            else
                local data = list[1]
                print("[DELIVERY] Destino: " .. data.name)
                tpTo(data.position)
                task.wait(CONFIG.WaitDelivery)

                local ok = doDeliveryAt(data.position)
                if ok then
                    phase = "PICKUP"
                    packagesCollected = 0
                    setStatus("Fase: RECOGIDA")
                    task.wait(0.8)
                else
                    setStatus("Reintentando entrega...")
                    -- NO cambiar de pin automáticamente; reintentar mismo ciclo
                    task.wait(0.6)
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
    jobAcceptedOnce = false
    phase = "PICKUP"
    packagesCollected = 0
    lockedDeliveryPos = nil
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

print("[DELIVERY] Interacción + confirmación (sin asumir por timer)")
