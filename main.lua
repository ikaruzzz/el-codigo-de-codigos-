--[[
    Driving Empire - Auto Delivery
    Reintento: distancia real → dentro → 2x salir/entrar (solo MoveTo)
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
    CircleRadius = 14,       -- radio del área de interacción
    InsideNeed = 11,         -- <= esto = dentro (margen)
    OutsideNeed = 16,        -- >= esto = fuera del círculo
    WalkOutDist = 20,        -- destino de salida (un poco más allá del borde)
    WalkTimeout = 5,
    CircleExits = 2,
    MaxRetries = 4,
    ConfirmDelay = 0.4,
    MaxDistance = 5000,
    InteractScan = 22,
}

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
local startJob = remotes and remotes:FindFirstChild("RequestStartJobSession")

local running = false
local jobAcceptedOnce = false
local phase = "PICKUP"

local cache = { pickup = nil, delivery = nil }

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
end

local function log(msg)
    print("[DELIVERY] " .. msg)
end

local function logErr(msg)
    print("[DELIVERY][ERROR] " .. msg)
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

-- Solo para ir al punto de trabajo (trayecto largo). El reintento NO usa esto.
local function tpTo(pos)
    local root = getHRP()
    if root and pos then
        root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
        return true
    end
    return false
end

local function horizDist(a, b)
    if not a or not b then return nil end
    local dx = a.X - b.X
    local dz = a.Z - b.Z
    return math.sqrt(dx * dx + dz * dz)
end

local function distanceTo(centerPos)
    local root = getHRP()
    if not root or not centerPos then return nil end
    return horizDist(root.Position, centerPos)
end

-- Movimiento SOLO con Humanoid:MoveTo (sin CFrame)
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
        local d = horizDist(root.Position, pos)
        if d and d <= 3.5 then
            return true
        end
        if tick() - t0 > 1.2 then
            hum:MoveTo(pos)
        end
        task.wait(0.12)
    end
    local d = horizDist(getHRP() and getHRP().Position, pos)
    return d ~= nil and d <= 6
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

-- ====================== RUTINA DE REINTENTO (corregida) ======================
--[[
  1. Posición REAL del objetivo
  2. Distancia al HRP
  3. Si fuera → caminar hacia dentro (MoveTo)
  4. Recomprobar
  5. Solo si DENTRO → salir / comprobar / entrar / comprobar
  6. Verificar interacción
  Sin CFrame en este proceso.
]]
local function approachUntilInside(centerPos)
    local dist = distanceTo(centerPos)
    if dist == nil then
        logErr("No se pudo determinar la distancia")
        return false
    end

    log(string.format("Distancia al objetivo: %.1f", dist))

    if dist <= CONFIG.InsideNeed then
        log("Dentro del área → iniciando reintento")
        return true
    end

    log("Fuera del área de interacción → acercándose")
    setStatus("Acercándose al círculo...")
    walkTo(centerPos, CONFIG.WalkTimeout)
    task.wait(0.15)

    dist = distanceTo(centerPos)
    if dist == nil then
        logErr("Distancia no fiable tras acercarse")
        return false
    end
    log(string.format("Distancia al objetivo: %.1f", dist))

    if dist <= CONFIG.InsideNeed then
        log("Dentro del área → iniciando reintento")
        return true
    end

    -- segundo intento de acercamiento
    walkTo(centerPos, CONFIG.WalkTimeout)
    task.wait(0.15)
    dist = distanceTo(centerPos)
    if dist == nil then return false end
    log(string.format("Distancia al objetivo: %.1f", dist))

    if dist <= CONFIG.CircleRadius then
        log("Dentro del área → iniciando reintento")
        return true
    end

    logErr("No se pudo entrar al área de interacción")
    return false
end

local function oneExitEnterCycle(centerPos, index)
    -- OBLIGATORIO: confirmar dentro ANTES de salir
    local dist = distanceTo(centerPos)
    if dist == nil then
        logErr("Distancia no fiable — no se inicia salida")
        return false
    end
    if dist > CONFIG.InsideNeed then
        log("Aún fuera — no se inicia salida")
        if not approachUntilInside(centerPos) then
            return false
        end
    end

    local outPos = Vector3.new(
        centerPos.X + CONFIG.WalkOutDist,
        centerPos.Y,
        centerPos.Z
    )

    log("Saliendo del círculo... (" .. index .. "/2)")
    setStatus("Saliendo " .. index .. "/2")
    walkTo(outPos, CONFIG.WalkTimeout)
    task.wait(0.2)

    dist = distanceTo(centerPos)
    if dist == nil then
        logErr("Distancia no fiable tras salida")
        return false
    end
    if dist >= CONFIG.OutsideNeed then
        log("Salida confirmada")
    else
        log(string.format("Salida parcial (dist=%.1f) — continuar", dist))
    end

    log("Volviendo al círculo...")
    setStatus("Entrando " .. index .. "/2")
    walkTo(centerPos, CONFIG.WalkTimeout)
    task.wait(0.15)

    dist = distanceTo(centerPos)
    if dist == nil then
        logErr("Distancia no fiable tras entrada")
        return false
    end
    if dist <= CONFIG.InsideNeed then
        log("Entrada confirmada")
    else
        log(string.format("Entrada parcial (dist=%.1f)", dist))
        -- forzar acercamiento sin asumir éxito
        approachUntilInside(centerPos)
    end

    return true
end

local function interactionRetryRoutine(centerPos, label, isDelivery)
    -- Posición actual del objetivo (no cache vieja sin validar)
    local dist = distanceTo(centerPos)
    if dist == nil then
        logErr("No se pudo determinar la distancia — recovery")
        return false
    end
    log(string.format("Distancia al objetivo: %.1f", dist))

    -- Acercarse si hace falta (SIN salir todavía)
    if not approachUntilInside(centerPos) then
        return false
    end

    -- 2 ciclos salir/entrar
    for i = 1, CONFIG.CircleExits do
        if not running then return false end
        if not oneExitEnterCycle(centerPos, i) then
            return false
        end
        task.wait(CONFIG.ConfirmDelay)
    end

    log("Verificando interacción...")
    setStatus("Verificando interacción...")
    local fired = interactNearby(centerPos)
    task.wait(CONFIG.ConfirmDelay)

    if isDelivery then
        if not cacheEntryValid(cache.delivery) then
            log("Interacción confirmada")
            setStatus("Entrega OK")
            return true
        end
        -- reintentos limitados
        for r = 1, CONFIG.MaxRetries do
            if not running then return false end
            log("Interacción no confirmada — reintento " .. r)
            if not approachUntilInside(centerPos) then return false end
            oneExitEnterCycle(centerPos, 1)
            interactNearby(centerPos)
            task.wait(CONFIG.ConfirmDelay)
            if not cacheEntryValid(cache.delivery) then
                log("Interacción confirmada")
                return true
            end
        end
        logErr("Interacción de entrega no confirmada")
        return false
    else
        -- Recogida: confirmada si aparece pin de entrega
        invalidate("DELIVERY")
        local del = getTarget("DELIVERY")
        if del then
            log("Interacción confirmada")
            setStatus("Recogida OK")
            return true, del
        end
        for r = 1, CONFIG.MaxRetries do
            if not running then return false end
            log("Interacción no confirmada — reintento " .. r)
            if not approachUntilInside(centerPos) then return false end
            oneExitEnterCycle(centerPos, 1)
            interactNearby(centerPos)
            task.wait(CONFIG.ConfirmDelay)
            invalidate("DELIVERY")
            del = getTarget("DELIVERY")
            if del then
                log("Interacción confirmada")
                return true, del
            end
        end
        logErr("Interacción de recogida no confirmada")
        return false
    end
end

-- ====================== PICKUP / DELIVERY ======================
local function doPickup(target)
    local pos = target.position
    setStatus("TP recogida\n" .. target.name)
    log("Objetivo recogida: " .. target.name)

    -- TP solo para llegar al pedido (trayecto largo)
    tpTo(pos)
    task.wait(0.25)

    -- Reintento: solo MoveTo + distancias reales
    local ok, del = interactionRetryRoutine(pos, "Recogida", false)
    if ok then
        invalidate("PICKUP")
        return true, del or getTarget("DELIVERY")
    end
    return false, nil
end

local function doDelivery(target)
    local pos = target.position
    setStatus("TP entrega\n" .. target.name)
    log("Objetivo entrega: " .. target.name)

    tpTo(pos)
    task.wait(0.25)

    local ok = interactionRetryRoutine(pos, "Entrega", true)
    if ok then
        invalidate(nil)
        return true
    end
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
                    deliveryTarget = deliveryTarget or getTarget("DELIVERY")
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
                    task.wait(0.3)
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

print("[DELIVERY] Reintento: distancia real → dentro → salir/entrar")
