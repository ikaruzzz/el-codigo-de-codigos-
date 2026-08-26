--[[
    Driving Empire - Delivery Only (State Machine)
    Precisión > Velocidad
    No usa coordenadas hardcodeadas
]]

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

repeat task.wait() until player.Character and player.Character:FindFirstChild("HumanoidRootPart")

if player.PlayerGui:FindFirstChild("DeliveryFarmGui") then
    player.PlayerGui.DeliveryFarmGui:Destroy()
end

-- ====================== CONFIG ======================
local CONFIG = {
    PickupWait = 2.2,
    DeliveryWait = 2.5,
    ScanInterval = 1.0,
    MaxPackageCount = 4,
}

-- ====================== REMOTES ======================
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
local startJob = remotes and remotes:FindFirstChild("RequestStartJobSession")

-- ====================== ESTADO ======================
local States = {
    IDLE = "IDLE",
    ACCEPTING_JOB = "ACCEPTING_JOB",
    FINDING_PICKUP = "FINDING_PICKUP",
    VALIDATING_PICKUP = "VALIDATING_PICKUP",
    GOING_TO_PICKUP = "GOING_TO_PICKUP",
    COLLECTING_PACKAGES = "COLLECTING_PACKAGES",
    VERIFYING_PACKAGES = "VERIFYING_PACKAGES",
    FINDING_DELIVERY = "FINDING_DELIVERY",
    VALIDATING_DELIVERY = "VALIDATING_DELIVERY",
    GOING_TO_DELIVERY = "GOING_TO_DELIVERY",
    DELIVERING = "DELIVERING",
    VERIFYING_DELIVERY = "VERIFYING_DELIVERY",
    WAITING_FOR_NEXT_JOB = "WAITING_FOR_NEXT_JOB",
    ERROR_RECOVERY = "ERROR_RECOVERY",
}

local currentState = States.IDLE
local running = false
local currentPickup = nil
local currentDelivery = nil
local lastPackageCount = 0

-- ====================== DEBUG ======================
local function log(msg)
    print("[DELIVERY] " .. tostring(msg))
end

local function logError(msg)
    warn("[DELIVERY][ERROR] " .. tostring(msg))
end

-- ====================== GUI SIMPLE ======================
local gui = Instance.new("ScreenGui")
gui.Name = "DeliveryFarmGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 200, 0, 160)
panel.Position = UDim2.new(1, -220, 0.5, -80)
panel.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
panel.BorderSizePixel = 0
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 28)
title.BackgroundTransparency = 1
title.Text = "Delivery Farm"
title.TextColor3 = Color3.new(1,1,1)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.Parent = panel

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -16, 0, 50)
statusLabel.Position = UDim2.new(0, 8, 0, 30)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Estado: IDLE"
statusLabel.TextColor3 = Color3.fromRGB(180,180,190)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 12
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.TextWrapped = true
statusLabel.Parent = panel

local startBtn = Instance.new("TextButton")
startBtn.Size = UDim2.new(0, 170, 0, 32)
startBtn.Position = UDim2.new(0.5, -85, 0, 90)
startBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 80)
startBtn.Text = "INICIAR DELIVERY"
startBtn.TextColor3 = Color3.new(1,1,1)
startBtn.Font = Enum.Font.GothamBold
startBtn.TextSize = 13
startBtn.Parent = panel
Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 8)

local stopBtn = Instance.new("TextButton")
stopBtn.Size = UDim2.new(0, 170, 0, 28)
stopBtn.Position = UDim2.new(0.5, -85, 0, 126)
stopBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
stopBtn.Text = "DETENER"
stopBtn.TextColor3 = Color3.new(1,1,1)
stopBtn.Font = Enum.Font.GothamBold
stopBtn.TextSize = 12
stopBtn.Parent = panel
Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 8)

local function setStatus(text)
    statusLabel.Text = "Estado: " .. currentState .. "\n" .. text
end

local function setState(newState)
    currentState = newState
    log("Estado → " .. newState)
    setStatus("")
end

-- ====================== UTILIDADES ======================
local function getHRP()
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function tpTo(pos)
    local root = getHRP()
    if not root or not pos then return false end
    root.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0))
    return true
end

local function isValidPart(obj)
    if not obj or not obj.Parent then return false end
    if obj:IsA("BasePart") then return true end
    if obj:IsA("Model") then
        return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
    end
    return false
end

local function getPart(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then
        return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
    end
    return nil
end

-- ====================== DETECCIÓN (conservadora) ======================
--[[
    Busca candidatos a flecha / caja.
    NO elige al azar: prioriza nombres claros y objetos cercanos al jugador.
    Si no hay candidatos claros → no se mueve.
]]
local function findMarkerCandidates(keywords, maxDistance)
    maxDistance = maxDistance or 2000
    local root = getHRP()
    if not root then return {} end

    local candidates = {}

    for _, obj in pairs(workspace:GetDescendants()) do
        local name = string.lower(obj.Name)
        local match = false
        for _, kw in ipairs(keywords) do
            if string.find(name, kw) then
                match = true
                break
            end
        end

        if match then
            local part = getPart(obj)
            if part then
                local dist = (part.Position - root.Position).Magnitude
                if dist <= maxDistance then
                    table.insert(candidates, {
                        object = obj,
                        part = part,
                        name = obj.Name,
                        distance = dist
                    })
                end
            end
        end
    end

    -- Ordenar por distancia (más cercano primero)
    table.sort(candidates, function(a, b)
        return a.distance < b.distance
    end)

    return candidates
end

local function findPickupCandidates()
    -- Flecha + caja de recogida
    local arrowKeys = {"arrow", "waypoint", "marker", "objective", "billboard", "pointer"}
    local boxKeys   = {"box", "package", "parcel", "crate", "pickup"}

    local arrows = findMarkerCandidates(arrowKeys, 2500)
    local boxes  = findMarkerCandidates(boxKeys, 2500)

    log("Candidatos flecha: " .. #arrows .. " | Candidatos caja: " .. #boxes)

    -- Preferir cajas cercanas; si no hay, flechas
    if #boxes > 0 then
        return boxes
    end
    return arrows
end

local function findDeliveryCandidates()
    local keys = {"delivery", "dropoff", "drop", "deliver", "finish", "destination", "arrow", "waypoint", "marker"}
    return findMarkerCandidates(keys, 2500)
end

-- Intento de leer cantidad de paquetes (si el juego lo expone)
local function getPackageCount()
    -- 1) Atributos del jugador
    local attr = player:GetAttribute("Packages")
        or player:GetAttribute("PackageCount")
        or player:GetAttribute("DeliveryPackages")
        or player:GetAttribute("PackagesHeld")
    if typeof(attr) == "number" then
        return attr
    end

    -- 2) leaderstats / folders comunes
    for _, name in ipairs({"Packages", "PackageCount", "DeliveryPackages"}) do
        local v = player:FindFirstChild(name)
        if v and v:IsA("NumberValue") then
            return v.Value
        end
        local ls = player:FindFirstChild("leaderstats")
        if ls and ls:FindFirstChild(name) and ls[name]:IsA("NumberValue") then
            return ls[name].Value
        end
    end

    -- 3) Desconocido
    return nil
end

-- ====================== ACCIONES ======================
local function tryAcceptJob()
    setState(States.ACCEPTING_JOB)
    setStatus("Intentando aceptar trabajo...")

    if startJob then
        pcall(function() startJob:FireServer("Delivery", "jobPad") end)
        pcall(function() startJob:FireServer("DeliveryDriver", "jobPad") end)
        pcall(function() startJob:FireServer("Delivery", "DeliveryHub") end)
        task.wait(1)
        log("Se intentó aceptar el trabajo (remotos genéricos)")
    else
        logError("No se encontró RequestStartJobSession")
    end

    -- No podemos confirmar el JobID sin estructura real
    log("Trabajo: no se pudo obtener JobID (estructura desconocida)")
    return true
end

local function selectBestCandidate(candidates, label)
    if #candidates == 0 then
        logError("No hay candidatos para " .. label)
        return nil
    end

    -- Si hay varios, no elegimos a ciegas: usamos el más cercano
    -- y lo registramos para depuración
    local best = candidates[1]
    log(label .. " elegido: " .. best.name .. " | dist=" .. math.floor(best.distance))

    if #candidates > 1 then
        log("Otros candidatos: " .. #candidates - 1)
        for i = 2, math.min(4, #candidates) do
            log("  - " .. candidates[i].name .. " dist=" .. math.floor(candidates[i].distance))
        end
    end

    return best
end

-- ====================== MÁQUINA DE ESTADOS ======================
local function runCycle()
    while running do
        ------------------------------------------------
        -- ACCEPTING JOB
        ------------------------------------------------
        if currentState == States.IDLE or currentState == States.WAITING_FOR_NEXT_JOB then
            tryAcceptJob()
            setState(States.FINDING_PICKUP)
        end

        ------------------------------------------------
        -- FINDING / VALIDATING PICKUP
        ------------------------------------------------
        if currentState == States.FINDING_PICKUP then
            setStatus("Buscando punto de recogida (flecha/caja)...")
            local candidates = findPickupCandidates()
            local best = selectBestCandidate(candidates, "Pickup")

            if not best then
                setState(States.ERROR_RECOVERY)
                setStatus("Sin pickup válido. Esperando...")
                task.wait(2)
                setState(States.FINDING_PICKUP)
            else
                currentPickup = best
                setState(States.VALIDATING_PICKUP)
            end
        end

        if currentState == States.VALIDATING_PICKUP then
            if not currentPickup or not currentPickup.part or not currentPickup.part.Parent then
                logError("Pickup dejó de ser válido")
                currentPickup = nil
                setState(States.FINDING_PICKUP)
            else
                log("Pickup validado: " .. currentPickup.name)
                setState(States.GOING_TO_PICKUP)
            end
        end

        ------------------------------------------------
        -- GOING TO PICKUP
        ------------------------------------------------
        if currentState == States.GOING_TO_PICKUP then
            if not currentPickup or not currentPickup.part or not currentPickup.part.Parent then
                logError("Pickup desapareció durante el viaje")
                currentPickup = nil
                setState(States.FINDING_PICKUP)
            else
                -- Posición actual justo antes de moverse
                local pos = currentPickup.part.Position
                setStatus("Yendo a recogida: " .. currentPickup.name)
                log("Posición pickup: " .. tostring(pos))
                tpTo(pos)
                task.wait(CONFIG.PickupWait)
                setState(States.COLLECTING_PACKAGES)
            end
        end

        ------------------------------------------------
        -- COLLECTING + VERIFYING PACKAGES
        ------------------------------------------------
        if currentState == States.COLLECTING_PACKAGES then
            setStatus("Recogiendo paquetes...")
            -- Re-escanear por si hay más cajas/paquetes cerca
            local near = findPickupCandidates()
            for i, c in ipairs(near) do
                if not running then break end
                if c.part and c.part.Parent then
                    tpTo(c.part.Position)
                    setStatus("Recogiendo cerca " .. i .. "/" .. #near)
                    task.wait(CONFIG.PickupWait * 0.7)
                end
            end
            setState(States.VERIFYING_PACKAGES)
        end

        if currentState == States.VERIFYING_PACKAGES then
            local count = getPackageCount()
            if count ~= nil then
                lastPackageCount = count
                log("Paquetes (juego): " .. count .. "/" .. CONFIG.MaxPackageCount)
                setStatus("Paquetes: " .. count .. "/" .. CONFIG.MaxPackageCount)

                if count >= CONFIG.MaxPackageCount then
                    log("4/4 confirmados")
                    setState(States.FINDING_DELIVERY)
                else
                    log("Aún no hay 4/4 → seguir recogiendo")
                    setState(States.COLLECTING_PACKAGES)
                    task.wait(1)
                end
            else
                -- Contador desconocido: no inventamos.
                -- Avanzamos con precaución y lo dejamos registrado.
                logError("No se pudo leer el contador de paquetes del juego")
                setStatus("Contador desconocido\nReintentando recogida...")
                -- Intentamos una ronda más de recogida y luego probamos destino
                setState(States.COLLECTING_PACKAGES)
                task.wait(1.5)
                -- Después de un intento extra, permitimos buscar destino
                -- (sin afirmar que tenemos 4/4)
                setState(States.FINDING_DELIVERY)
            end
        end

        ------------------------------------------------
        -- FINDING / VALIDATING DELIVERY
        ------------------------------------------------
        if currentState == States.FINDING_DELIVERY then
            setStatus("Buscando destino de entrega...")
            local candidates = findDeliveryCandidates()
            local best = selectBestCandidate(candidates, "Destino")

            if not best then
                logError("No se pudo identificar el destino")
                setState(States.ERROR_RECOVERY)
                task.wait(2)
                setState(States.FINDING_DELIVERY)
            else
                currentDelivery = best
                setState(States.VALIDATING_DELIVERY)
            end
        end

        if currentState == States.VALIDATING_DELIVERY then
            if not currentDelivery or not currentDelivery.part or not currentDelivery.part.Parent then
                logError("Destino dejó de ser válido")
                currentDelivery = nil
                setState(States.FINDING_DELIVERY)
            else
                log("Destino validado: " .. currentDelivery.name)
                setState(States.GOING_TO_DELIVERY)
            end
        end

        ------------------------------------------------
        -- GOING TO DELIVERY + DELIVERING
        ------------------------------------------------
        if currentState == States.GOING_TO_DELIVERY then
            if not currentDelivery or not currentDelivery.part or not currentDelivery.part.Parent then
                logError("Destino desapareció en el camino")
                currentDelivery = nil
                setState(States.FINDING_DELIVERY)
            else
                local pos = currentDelivery.part.Position
                setStatus("Yendo a entrega: " .. currentDelivery.name)
                log("Posición destino: " .. tostring(pos))
                tpTo(pos)
                task.wait(CONFIG.DeliveryWait)
                setState(States.DELIVERING)
            end
        end

        if currentState == States.DELIVERING then
            setStatus("Intentando entregar...")
            -- No hay Remote de entrega confirmado → solo presencia en el punto
            task.wait(1.2)
            setState(States.VERIFYING_DELIVERY)
        end

        if currentState == States.VERIFYING_DELIVERY then
            local count = getPackageCount()
            if count ~= nil and count == 0 then
                log("Entrega confirmada (paquetes = 0)")
                setStatus("Entrega confirmada")
                currentPickup = nil
                currentDelivery = nil
                setState(States.WAITING_FOR_NEXT_JOB)
            elseif count ~= nil and count > 0 then
                logError("Entrega no confirmada (aún hay paquetes: " .. count .. ")")
                setStatus("Entrega no confirmada")
                setState(States.FINDING_DELIVERY)
                task.wait(1.5)
            else
                -- Sin contador: no afirmamos éxito total
                log("Entrega no verificable (sin contador). Reiniciando ciclo con precaución.")
                setStatus("Entrega no verificable")
                currentPickup = nil
                currentDelivery = nil
                setState(States.WAITING_FOR_NEXT_JOB)
            end
            task.wait(1)
        end

        ------------------------------------------------
        -- ERROR / WAIT
        ------------------------------------------------
        if currentState == States.ERROR_RECOVERY then
            setStatus("Recuperando...")
            task.wait(1.5)
            setState(States.FINDING_PICKUP)
        end

        if currentState == States.WAITING_FOR_NEXT_JOB then
            setStatus("Esperando siguiente trabajo...")
            task.wait(CONFIG.ScanInterval)
            setState(States.ACCEPTING_JOB)
        end

        task.wait(0.15)
    end

    setState(States.IDLE)
    setStatus("Detenido")
end

-- ====================== BOTONES ======================
startBtn.MouseButton1Click:Connect(function()
    if running then return end
    running = true
    startBtn.Text = "EN MARCHA..."
    startBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
    setState(States.IDLE)
    task.spawn(runCycle)
end)

stopBtn.MouseButton1Click:Connect(function()
    running = false
    currentPickup = nil
    currentDelivery = nil
    startBtn.Text = "INICIAR DELIVERY"
    startBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 80)
    setState(States.IDLE)
    setStatus("Detenido por el usuario")
    log("Detenido por el usuario")
end)

player.CharacterAdded:Connect(function(char)
    char:WaitForChild("HumanoidRootPart")
end)

log("Delivery Farm cargado (máquina de estados)")
log("Precisión > Velocidad | Sin coordenadas fijas")
