--[[
    Driving Empire - Auto Delivery
    1) Confirmar dentro del círculo
    2) 2x salir (más allá del borde) + entrar
    3) Interactuar
    4) TP al otro punto y repetir
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
    -- Radio del círculo de interacción (aprox. según el juego)
    CircleRadius = 14,
    -- Margen: "claramente dentro"
    InsideMargin = 3,
    -- Salida: un poco más allá del borde (no demasiado lejos)
    WalkOutExtra = 6,
    WalkTimeout = 4,
    CircleExits = 2,
    ConfirmDelay = 0.4,
    MaxDistance = 5000,
    MaxTries = 6,
    InteractScan = 22,
}

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
local startJob = remotes and remotes:FindFirstChild("RequestStartJobSession")

local running = false
local jobAcceptedOnce = false
local phase = "PICKUP"

local cache = {
    pickup = nil,
    delivery = nil,
}

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
title.Text = "Delivery · Auto"
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

local function getHum()
    local c = player.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function tpTo(pos)
    local root = getHRP()
    if root and pos then
        root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
        return true
    end
    return false
end

local function walkTo(pos, timeout)
    local hum = getHum()
    local root = getHRP()
    if not hum or not root or not pos then return false end
    hum:MoveTo(pos)
    local t0 = tick()
    timeout = timeout or CONFIG.WalkTimeout
    while tick() - t0 < timeout do
        if not running then
            hum:MoveTo(root.Position)
            return false
        end
        if (root.Position - pos).Magnitude <= 3.5 then return true end
        if tick() - t0 > 1 then hum:MoveTo(pos) end
        task.wait(0.12)
    end
    return (root.Position - pos).Magnitude <= 6
end

-- Distancia horizontal al centro del círculo
local function horizDist(a, b)
    local dx = a.X - b.X
    local dz = a.Z - b.Z
    return math.sqrt(dx * dx + dz * dz)
end

local function isInsideCircle(centerPos)
    local root = getHRP()
    if not root or not centerPos then return false end
    -- Claramente dentro: radio - margen
    return horizDist(root.Position, centerPos) <= (CONFIG.CircleRadius - CONFIG.InsideMargin)
end

local function isOutsideCircle(centerPos)
    local root = getHRP()
    if not root or not centerPos then return true end
    return horizDist(root.Position, centerPos) > (CONFIG.CircleRadius + 1)
end

-- Obligatorio: estar dentro ANTES de cualquier salida
local function ensureInsideCircle(centerPos, label)
    local root = getHRP()
    if not root then return false end

    if isInsideCircle(centerPos) then
        print("[DELIVERY] Ya dentro del círculo")
        return true
    end

    setStatus(label .. "\nEntrando al círculo...")
    print("[DELIVERY] Fuera → caminar al centro")
    -- Centro del círculo (claramente dentro)
    local ok = walkTo(centerPos, CONFIG.WalkTimeout)
    task.wait(0.15)

    if isInsideCircle(centerPos) then
        return true
    end
    -- Segundo intento más al centro
    walkTo(centerPos, CONFIG.WalkTimeout)
    task.wait(0.1)
    return isInsideCircle(centerPos) or horizDist(getHRP().Position, centerPos) < CONFIG.CircleRadius
end

local function acceptJobOnce()
    if jobAcceptedOnce then return end
    if startJob then
        pcall(function() startJob:FireServer("Delivery", "jobPad") end)
        pcall(function() startJob:FireServer("DeliveryDriver", "jobPad") end)
        task.wait(0.5)
    end
    jobAcceptedOnce = true
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

local function cacheEntryValid(entry)
    if not entry or not entry.bb then return false end
    if not entry.bb.Parent or not entry.bb:IsA("BillboardGui") or not entry.bb.Enabled then return false end
    local pos = billboardPosition(entry.bb)
    if not pos then return false end
    entry.position = pos
    return true
end

local function fullScan()
    local root = getHRP()
    if not root then return end
    local rootPos = root.Position
    local bestP, bestD = nil, nil
    local bestPD, bestDD = math.huge, math.huge
    local n = 0

    for _, obj in ipairs(workspace:GetDescendants()) do
        n = n + 1
        if n % 1000 == 0 then task.wait() end
        if obj:IsA("BillboardGui") and isIconBillboard(obj) then
            local kind = classifySymbol(obj)
            if kind then
                local pos = billboardPosition(obj)
                if pos then
                    local dist = (pos - rootPos).Magnitude
                    if dist <= CONFIG.MaxDistance then
                        if kind == "PICKUP" and dist < bestPD then
                            bestPD = dist
                            bestP = { bb = obj, position = pos, name = obj.Name }
                        elseif kind == "DELIVERY" and dist < bestDD then
                            bestDD = dist
                            bestD = { bb = obj, position = pos, name = obj.Name }
                        end
                    end
                end
            end
        end
    end
    cache.pickup = bestP
    cache.delivery = bestD
end

local function getTarget(kind)
    local entry = (kind == "PICKUP") and cache.pickup or cache.delivery
    if cacheEntryValid(entry) then return entry end
    if kind == "PICKUP" then cache.pickup = nil else cache.delivery = nil end
    fullScan()
    entry = (kind == "PICKUP") and cache.pickup or cache.delivery
    if cacheEntryValid(entry) then return entry end
    return nil
end

local function invalidate(kind)
    if kind == "PICKUP" then cache.pickup = nil
    elseif kind == "DELIVERY" then cache.delivery = nil
    else cache.pickup = nil; cache.delivery = nil end
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
    if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then return false end
    if fireproximityprompt then
        pcall(function() fireproximityprompt(prompt) end)
        return true
    end
    pcall(function()
        prompt:InputHoldBegin()
        task.wait(math.max(prompt.HoldDuration or 0, 0.05) + 0.04)
        prompt:InputHoldEnd()
    end)
    return true
end

local function interactNearby(centerPos)
    local fired = 0
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            local pos = getPromptWorldPos(obj)
            if pos and (pos - centerPos).Magnitude <= CONFIG.InteractScan then
                if firePrompt(obj) then fired = fired + 1 end
            end
        elseif obj:IsA("ClickDetector") then
            local part = obj.Parent
            if part and part:IsA("BasePart") and (part.Position - centerPos).Magnitude <= CONFIG.InteractScan then
                if fireclickdetector then
                    pcall(function() fireclickdetector(obj) end)
                    fired = fired + 1
                end
            end
        end
    end
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(0.03)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
    return fired
end

-- 1 ciclo: SOLO si ya está dentro → salir más allá del borde → volver dentro
local function oneExitEnterCycle(centerPos, label, index)
    -- NUNCA salir sin estar dentro
    if not ensureInsideCircle(centerPos, label) then
        print("[DELIVERY][ERROR] No se pudo entrar al círculo")
        return false
    end

    -- Punto fuera: radio + extra (claramente fuera, sin irse lejos)
    local outDist = CONFIG.CircleRadius + CONFIG.WalkOutExtra
    local outPos = centerPos + Vector3.new(outDist, 0, 0)

    setStatus(label .. "\nSalida " .. index .. "/2")
    print("[DELIVERY] " .. label .. " salir #" .. index)
    walkTo(outPos, CONFIG.WalkTimeout)
    task.wait(0.2)

    setStatus(label .. "\nEntrada " .. index .. "/2")
    print("[DELIVERY] " .. label .. " entrar #" .. index)
    walkTo(centerPos, CONFIG.WalkTimeout)
    task.wait(0.15)

    -- Confirmar de nuevo dentro
    ensureInsideCircle(centerPos, label)
    interactNearby(centerPos)
    return true
end

local function doTwoExitEnterCycles(centerPos, label)
    for i = 1, CONFIG.CircleExits do
        if not running then return false end
        if not oneExitEnterCycle(centerPos, label, i) then
            return false
        end
        task.wait(CONFIG.ConfirmDelay)
    end
    return true
end

-- ====================== RECOGIDA ======================
local function doPickup(target)
    local pos = target.position
    setStatus("TP recogida\n" .. target.name)
    print("[DELIVERY] TP → pickup")

    tpTo(pos)
    task.wait(0.2)

    -- Verificar dentro ANTES de las salidas
    if not ensureInsideCircle(pos, "Recogida") then
        return false, nil
    end

    doTwoExitEnterCycles(pos, "Recogida")
    interactNearby(pos)

    for _ = 1, CONFIG.MaxTries do
        if not running then return false, nil end
        invalidate("DELIVERY")
        local del = getTarget("DELIVERY")
        if del then
            print("[DELIVERY] Recogida OK")
            invalidate("PICKUP")
            return true, del
        end
        interactNearby(pos)
        task.wait(CONFIG.ConfirmDelay)
    end

    local del = getTarget("DELIVERY")
    if del then
        invalidate("PICKUP")
        return true, del
    end
    print("[DELIVERY][ERROR] Recogida no confirmada")
    return false, nil
end

-- ====================== ENTREGA ======================
local function doDelivery(target)
    local pos = target.position
    setStatus("TP entrega\n" .. target.name)
    print("[DELIVERY] TP → delivery")

    tpTo(pos)
    task.wait(0.2)

    if not ensureInsideCircle(pos, "Entrega") then
        return false
    end

    doTwoExitEnterCycles(pos, "Entrega")
    interactNearby(pos)

    for _ = 1, CONFIG.MaxTries do
        if not running then return false end
        if not cacheEntryValid(cache.delivery) then
            print("[DELIVERY] Entrega CONFIRMADA")
            invalidate(nil)
            return true
        end
        interactNearby(pos)
        task.wait(CONFIG.ConfirmDelay)
        if cache.delivery then pos = cache.delivery.position end
    end

    if not cacheEntryValid(cache.delivery) then
        invalidate(nil)
        return true
    end
    print("[DELIVERY][ERROR] Entrega no confirmada")
    return false
end

-- ====================== LOOP ======================
local function farmLoop()
    acceptJobOnce()
    phase = "PICKUP"
    fullScan()

    while running do
        if phase == "PICKUP" then
            local target = getTarget("PICKUP")
            if not target then
                setStatus("Buscando caja...")
                fullScan()
                task.wait(0.35)
            else
                local ok, deliveryTarget = doPickup(target)
                if ok then
                    if not deliveryTarget then
                        deliveryTarget = getTarget("DELIVERY")
                    end
                    if deliveryTarget then
                        if doDelivery(deliveryTarget) then
                            phase = "PICKUP"
                            setStatus("Siguiente pedido...")
                        else
                            invalidate(nil)
                            phase = "PICKUP"
                        end
                    else
                        fullScan()
                        phase = "DELIVERY"
                    end
                else
                    invalidate("PICKUP")
                    task.wait(0.25)
                end
            end

        elseif phase == "DELIVERY" then
            local target = getTarget("DELIVERY")
            if not target then
                setStatus("Buscando pin...")
                fullScan()
                task.wait(0.35)
                if getTarget("PICKUP") and not getTarget("DELIVERY") then
                    phase = "PICKUP"
                end
            else
                if doDelivery(target) then
                    phase = "PICKUP"
                    setStatus("Siguiente pedido...")
                else
                    invalidate("DELIVERY")
                    phase = "PICKUP"
                end
            end
        end

        task.wait(0.12)
    end
    setStatus("Detenido")
end

startBtn.MouseButton1Click:Connect(function()
    if running then return end
    running = true
    jobAcceptedOnce = false
    phase = "PICKUP"
    cache.pickup = nil
    cache.delivery = nil
    startBtn.Text = "EN MARCHA..."
    startBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
    task.spawn(farmLoop)
end)

stopBtn.MouseButton1Click:Connect(function()
    running = false
    local hum = getHum()
    local root = getHRP()
    if hum and root then hum:MoveTo(root.Position) end
    startBtn.Text = "INICIAR"
    startBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 80)
    setStatus("Detenido")
end)

print("[DELIVERY] ensureInside → 2x exit/enter → interact")
