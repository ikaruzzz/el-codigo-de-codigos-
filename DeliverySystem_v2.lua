--[[
    DELIVERY AUTOMATION SYSTEM v2
    Roblox Studio - Driving Empire
    
    PRIORIDAD: PRECISIÓN > VELOCIDAD
    NO utiliza coordenadas hardcodeadas
    NO utiliza suposiciones sobre ubicaciones
    Implementa máquina de estados completa
]]

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")

-- ==================== CONFIGURACIÓN ====================
local CONFIG = {
    DEBUG = true,
    TIMEOUT_JOB_DETECTION = 5,
    TIMEOUT_PICKUP_DETECTION = 10,
    TIMEOUT_PACKAGE_DETECTION = 8,
    TIMEOUT_DELIVERY_DETECTION = 10,
    TARGET_PACKAGES = 4,
    MOVEMENT_OFFSET = Vector3.new(0, 3, 0),
    ARRIVAL_DISTANCE = 15,
}

-- ==================== ESTADOS ====================
local STATE = {
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

-- ==================== SISTEMA DE DEBUG ====================
local function log(state, message, isError)
    local prefix = isError and "[DELIVERY][ERROR]" or "[DELIVERY]"
    local timestamp = os.date("%H:%M:%S")
    print(prefix .. " [" .. timestamp .. "] [" .. state .. "] " .. message)
end

-- ==================== CLASE: DELIVERY SYSTEM ====================
local DeliverySystem = {}
DeliverySystem.__index = DeliverySystem

function DeliverySystem.new()
    local self = setmetatable({}, DeliverySystem)
    
    self.currentState = STATE.IDLE
    self.activeJob = nil
    self.pickupPoint = nil
    self.deliveryPoint = nil
    self.packagesCarrying = 0
    self.lastUpdateTime = 0
    self.stateStartTime = tick()
    
    return self
end

function DeliverySystem:setState(newState)
    if self.currentState ~= newState then
        log(self.currentState, "→ Transición a: " .. newState)
        self.currentState = newState
        self.stateStartTime = tick()
    end
end

function DeliverySystem:getElapsedStateTime()
    return tick() - self.stateStartTime
end

function DeliverySystem:isStateTimeout(maxSeconds)
    return self:getElapsedStateTime() > maxSeconds
end

-- ==================== DETECCIÓN DE JOB ====================

--[[
    NECESITA INFORMACIÓN:
    ¿Dónde se almacenan los trabajos activos?
    ¿Cómo se identifica que es un trabajo de Delivery?
    ¿Qué propiedades tiene?
]]

local function detectActiveJob()
    log(STATE.ACCEPTING_JOB, "Buscando trabajo activo...")
    
    -- PLACEHOLDER: Adaptar según la estructura real del juego
    local possibleJobs = {}
    
    -- Opción 1: Buscar en ReplicatedStorage
    pcall(function()
        local jobsFolder = ReplicatedStorage:FindFirstChild("Jobs")
        if jobsFolder then
            for _, job in pairs(jobsFolder:GetChildren()) do
                if job:GetAttribute("JobType") == "Delivery" or 
                   string.find(job.Name, "Delivery") then
                    table.insert(possibleJobs, job)
                end
            end
        end
    end)
    
    -- Opción 2: Buscar en workspace
    pcall(function()
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and obj:GetAttribute("JobType") == "Delivery" then
                table.insert(possibleJobs, obj)
            end
        end
    end)
    
    -- Validación
    if #possibleJobs == 0 then
        log(STATE.ACCEPTING_JOB, "No se encontraron trabajos de Delivery", true)
        return nil
    elseif #possibleJobs > 1 then
        log(STATE.ACCEPTING_JOB, "Múltiples trabajos encontrados: " .. #possibleJobs .. " (usando el primero)", true)
    end
    
    local job = possibleJobs[1]
    log(STATE.ACCEPTING_JOB, "Trabajo detectado: " .. job.Name .. " (ID: " .. (job:GetAttribute("JobID") or "N/A") .. ")")
    
    return job
end

-- ==================== VALIDACIÓN DE PICKUP ====================

--[[
    NECESITA INFORMACIÓN:
    ¿Cómo se vincula el Pickup al Job?
    ¿Cómo se identifica un Pickup válido?
    ¿Dónde están ubicados?
]]

local function findPickupPoint(job)
    if not job then
        log(STATE.FINDING_PICKUP, "Job inválido", true)
        return nil
    end
    
    log(STATE.FINDING_PICKUP, "Buscando punto de recogida para: " .. job.Name)
    
    local candidates = {}
    
    -- Opción 1: Buscar dentro del Job
    pcall(function()
        local pickup = job:FindFirstChild("Pickup") or job:FindFirstChild("PickupPoint")
        if pickup then
            table.insert(candidates, pickup)
        end
    end)
    
    -- Opción 2: Buscar por atributo
    pcall(function()
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:GetAttribute("PickupFor") == job.Name or
               obj:GetAttribute("PickupJobID") == job:GetAttribute("JobID") then
                table.insert(candidates, obj)
            end
        end
    end)
    
    -- Opción 3: Buscar por proximidad (último recurso)
    if #candidates == 0 then
        log(STATE.FINDING_PICKUP, "No se encontró Pickup con atributos, buscando por proximidad", true)
        local jobPos = job:FindFirstChildWhichIsA("BasePart")
        if jobPos then
            for _, obj in pairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and 
                   (string.find(obj.Name, "Pickup") or obj:GetAttribute("Type") == "Pickup") then
                    local dist = (obj.Position - jobPos.Position).Magnitude
                    if dist < 100 then
                        table.insert(candidates, obj)
                    end
                end
            end
        end
    end
    
    if #candidates == 0 then
        log(STATE.FINDING_PICKUP, "No se encontró punto de recogida", true)
        return nil
    elseif #candidates > 1 then
        log(STATE.FINDING_PICKUP, "Múltiples puntos encontrados: " .. #candidates, true)
    end
    
    local pickup = candidates[1]
    if pickup:IsA("BasePart") then
        log(STATE.VALIDATING_PICKUP, "Pickup validado: " .. pickup.Name .. " en " .. tostring(pickup.Position))
        return pickup
    else
        log(STATE.VALIDATING_PICKUP, "Pickup no es una BasePart", true)
        return nil
    end
end

-- ==================== DETECCIÓN Y RECOGIDA DE PAQUETES ====================

--[[
    NECESITA INFORMACIÓN:
    ¿Cómo obtener el contador de paquetes actual?
    ¿Dónde se almacenan los paquetes en el trabajo?
    ¿Cómo se recogen?
]]

local function getPackageCount()
    -- PLACEHOLDER: Adaptar según la estructura real
    
    local count = 0
    
    -- Opción 1: leaderstats
    pcall(function()
        local ls = player:FindFirstChild("leaderstats")
        if ls then
            local packages = ls:FindFirstChild("Packages") or 
                           ls:FindFirstChild("PackagesCarrying") or
                           ls:FindFirstChild("DeliveryPackages")
            if packages then
                count = packages.Value
            end
        end
    end)
    
    -- Opción 2: Character attribute
    if count == 0 then
        pcall(function()
            count = character:GetAttribute("Packages") or 
                   character:GetAttribute("PackageCount") or 0
        end)
    end
    
    return count
end

local function findPackages(pickupPoint)
    if not pickupPoint then return {} end
    
    log(STATE.COLLECTING_PACKAGES, "Buscando paquetes cerca de: " .. pickupPoint.Name)
    
    local packages = {}
    local searchRadius = 50
    
    pcall(function()
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                local isPackage = string.find(obj.Name, "Package") or 
                                string.find(obj.Name, "Box") or
                                obj:GetAttribute("Type") == "Package"
                
                if isPackage then
                    local dist = (obj.Position - pickupPoint.Position).Magnitude
                    if dist < searchRadius then
                        table.insert(packages, obj)
                    end
                end
            end
        end
    end)
    
    log(STATE.COLLECTING_PACKAGES, "Encontrados " .. #packages .. " paquetes")
    return packages
end

local function collectPackage(package)
    if not package then return false end
    
    log(STATE.COLLECTING_PACKAGES, "Recogiendo paquete: " .. package.Name)
    
    -- Intentar recoger mediante RemoteEvent
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes then
            local collectRemote = remotes:FindFirstChild("CollectPackage") or
                                 remotes:FindFirstChild("TakePackage") or
                                 remotes:FindFirstChild("PickupPackage")
            
            if collectRemote then
                collectRemote:FireServer(package)
                return true
            end
        end
    end)
    
    -- Fallback: Acercarse y esperar
    hrp.CFrame = CFrame.new(package.Position + CONFIG.MOVEMENT_OFFSET)
    task.wait(0.5)
    
    local newCount = getPackageCount()
    log(STATE.COLLECTING_PACKAGES, "Paquetes actuales: " .. newCount .. "/" .. CONFIG.TARGET_PACKAGES)
    
    return true
end

-- ==================== BÚSQUEDA DE PUNTO DE ENTREGA ====================

--[[
    NECESITA INFORMACIÓN:
    ¿Cómo se vincula el Delivery Point al Job?
    ¿Se obtiene desde el Job mismo?
    ¿Existe una RemoteFunction que lo retorna?
]]

local function findDeliveryPoint(job)
    if not job then
        log(STATE.FINDING_DELIVERY, "Job inválido", true)
        return nil
    end
    
    log(STATE.FINDING_DELIVERY, "Buscando punto de entrega para: " .. job.Name)
    
    local candidates = {}
    
    -- Opción 1: Buscar dentro del Job
    pcall(function()
        local delivery = job:FindFirstChild("Delivery") or 
                        job:FindFirstChild("DeliveryPoint") or
                        job:FindFirstChild("Destination")
        if delivery then
            table.insert(candidates, delivery)
        end
    end)
    
    -- Opción 2: Buscar por atributo del Job
    pcall(function()
        local deliveryID = job:GetAttribute("DeliveryPointID")
        if deliveryID then
            for _, obj in pairs(workspace:GetDescendants()) do
                if obj:GetAttribute("ID") == deliveryID then
                    table.insert(candidates, obj)
                end
            end
        end
    end)
    
    -- Opción 3: Buscar por atributo correlativo
    pcall(function()
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:GetAttribute("DeliveryFor") == job.Name or
               obj:GetAttribute("DeliveryJobID") == job:GetAttribute("JobID") then
                table.insert(candidates, obj)
            end
        end
    end)
    
    if #candidates == 0 then
        log(STATE.FINDING_DELIVERY, "No se encontró punto de entrega", true)
        return nil
    elseif #candidates > 1 then
        log(STATE.FINDING_DELIVERY, "Múltiples puntos encontrados: " .. #candidates, true)
    end
    
    local delivery = candidates[1]
    if delivery:IsA("BasePart") then
        log(STATE.VALIDATING_DELIVERY, "Delivery validado: " .. delivery.Name .. " en " .. tostring(delivery.Position))
        return delivery
    else
        log(STATE.VALIDATING_DELIVERY, "Delivery no es una BasePart", true)
        return nil
    end
end

-- ==================== MOVIMIENTO SEGURO ====================

local function moveToTarget(target, targetName)
    if not target or not target.Parent then
        log(STATE.GOING_TO_DELIVERY, "Destino desaparecido: " .. (targetName or "unknown"), true)
        return false
    end
    
    local targetPos = target.Position + CONFIG.MOVEMENT_OFFSET
    log(STATE.GOING_TO_DELIVERY, "Moviendo a: " .. targetName .. " (" .. tostring(targetPos) .. ")")
    
    local startTime = tick()
    local timeout = 30
    
    while tick() - startTime < timeout do
        if not target or not target.Parent then
            log(STATE.GOING_TO_DELIVERY, "Destino desapareció durante el viaje", true)
            return false
        end
        
        targetPos = target.Position + CONFIG.MOVEMENT_OFFSET
        hrp.CFrame = CFrame.new(hrp.Position:Lerp(targetPos, 0.1))
        
        local distance = (hrp.Position - targetPos).Magnitude
        if distance < CONFIG.ARRIVAL_DISTANCE then
            log(STATE.GOING_TO_DELIVERY, "Llegada a: " .. targetName)
            return true
        end
        
        task.wait(0.1)
    end
    
    log(STATE.GOING_TO_DELIVERY, "Timeout al ir a: " .. targetName, true)
    return false
end

-- ==================== ENTREGA ====================

local function deliverPackages(deliveryPoint)
    if not deliveryPoint then return false end
    
    log(STATE.DELIVERING, "Intentando entregar en: " .. deliveryPoint.Name)
    
    local success = false
    
    -- Intentar mediante RemoteEvent
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes then
            local deliverRemote = remotes:FindFirstChild("Deliver") or
                                 remotes:FindFirstChild("DeliverPackages") or
                                 remotes:FindFirstChild("CompleteDelivery")
            
            if deliverRemote then
                deliverRemote:FireServer(deliveryPoint)
                success = true
            end
        end
    end)
    
    task.wait(1)
    
    local packagesNow = getPackageCount()
    if packagesNow == 0 then
        log(STATE.VERIFYING_DELIVERY, "Entrega confirmada - Paquetes: 0/" .. CONFIG.TARGET_PACKAGES)
        return true
    else
        log(STATE.VERIFYING_DELIVERY, "Entrega no confirmada - Paquetes: " .. packagesNow .. "/" .. CONFIG.TARGET_PACKAGES, true)
        return false
    end
end

-- ==================== CICLO PRINCIPAL ====================

function DeliverySystem:run()
    while true do
        if CONFIG.DEBUG then
            log(self.currentState, "Estado actual, tiempo: " .. string.format("%.1f", self:getElapsedStateTime()) .. "s")
        end
        
        if self.currentState == STATE.IDLE then
            task.wait(1)
            self:setState(STATE.ACCEPTING_JOB)
        
        elseif self.currentState == STATE.ACCEPTING_JOB then
            self.activeJob = detectActiveJob()
            
            if self.activeJob then
                self:setState(STATE.FINDING_PICKUP)
            elseif self:isStateTimeout(CONFIG.TIMEOUT_JOB_DETECTION) then
                log(STATE.ACCEPTING_JOB, "Timeout al detectar trabajo", true)
                self:setState(STATE.ERROR_RECOVERY)
            else
                task.wait(0.5)
            end
        
        elseif self.currentState == STATE.FINDING_PICKUP then
            self.pickupPoint = findPickupPoint(self.activeJob)
            
            if self.pickupPoint then
                self:setState(STATE.VALIDATING_PICKUP)
            elseif self:isStateTimeout(CONFIG.TIMEOUT_PICKUP_DETECTION) then
                log(STATE.FINDING_PICKUP, "Timeout al detectar pickup", true)
                self:setState(STATE.ERROR_RECOVERY)
            else
                task.wait(1)
            end
        
        elseif self.currentState == STATE.VALIDATING_PICKUP then
            if self.pickupPoint and self.pickupPoint.Parent then
                log(STATE.VALIDATING_PICKUP, "Pickup validado correctamente")
                self:setState(STATE.GOING_TO_PICKUP)
            else
                log(STATE.VALIDATING_PICKUP, "Pickup ya no es válido", true)
                self:setState(STATE.FINDING_PICKUP)
            end
        
        elseif self.currentState == STATE.GOING_TO_PICKUP then
            if moveToTarget(self.pickupPoint, "Pickup") then
                self:setState(STATE.COLLECTING_PACKAGES)
            else
                log(STATE.GOING_TO_PICKUP, "No se pudo llegar al pickup", true)
                self:setState(STATE.ERROR_RECOVERY)
            end
        
        elseif self.currentState == STATE.COLLECTING_PACKAGES then
            local packages = findPackages(self.pickupPoint)
            
            if #packages == 0 then
                log(STATE.COLLECTING_PACKAGES, "No hay paquetes disponibles", true)
                self:setState(STATE.ERROR_RECOVERY)
            else
                for _, pkg in pairs(packages) do
                    if getPackageCount() < CONFIG.TARGET_PACKAGES then
                        collectPackage(pkg)
                        task.wait(0.3)
                    end
                end
                
                self:setState(STATE.VERIFYING_PACKAGES)
            end
        
        elseif self.currentState == STATE.VERIFYING_PACKAGES then
            self.packagesCarrying = getPackageCount()
            
            if self.packagesCarrying == CONFIG.TARGET_PACKAGES then
                log(STATE.VERIFYING_PACKAGES, "✓ Confirmados " .. CONFIG.TARGET_PACKAGES .. "/" .. CONFIG.TARGET_PACKAGES .. " paquetes")
                self:setState(STATE.FINDING_DELIVERY)
            elseif self.packagesCarrying > 0 then
                log(STATE.VERIFYING_PACKAGES, "Paquetes incompletos: " .. self.packagesCarrying .. "/" .. CONFIG.TARGET_PACKAGES)
                self:setState(STATE.COLLECTING_PACKAGES)
            else
                log(STATE.VERIFYING_PACKAGES, "No hay paquetes", true)
                self:setState(STATE.ERROR_RECOVERY)
            end
        
        elseif self.currentState == STATE.FINDING_DELIVERY then
            self.deliveryPoint = findDeliveryPoint(self.activeJob)
            
            if self.deliveryPoint then
                self:setState(STATE.VALIDATING_DELIVERY)
            elseif self:isStateTimeout(CONFIG.TIMEOUT_DELIVERY_DETECTION) then
                log(STATE.FINDING_DELIVERY, "Timeout al detectar delivery", true)
                self:setState(STATE.ERROR_RECOVERY)
            else
                task.wait(1)
            end
        
        elseif self.currentState == STATE.VALIDATING_DELIVERY then
            if self.deliveryPoint and self.deliveryPoint.Parent and self.packagesCarrying == CONFIG.TARGET_PACKAGES then
                log(STATE.VALIDATING_DELIVERY, "Delivery validado correctamente")
                self:setState(STATE.GOING_TO_DELIVERY)
            else
                log(STATE.VALIDATING_DELIVERY, "Delivery no es válido o paquetes perdidos", true)
                self:setState(STATE.ERROR_RECOVERY)
            end
        
        elseif self.currentState == STATE.GOING_TO_DELIVERY then
            if moveToTarget(self.deliveryPoint, "Delivery") then
                self:setState(STATE.DELIVERING)
            else
                log(STATE.GOING_TO_DELIVERY, "No se pudo llegar al delivery", true)
                self:setState(STATE.ERROR_RECOVERY)
            end
        
        elseif self.currentState == STATE.DELIVERING then
            if deliverPackages(self.deliveryPoint) then
                log(STATE.DELIVERING, "✓ Entrega completada")
                self:setState(STATE.VERIFYING_DELIVERY)
            else
                log(STATE.DELIVERING, "Entrega fallida", true)
                self:setState(STATE.ERROR_RECOVERY)
            end
        
        elseif self.currentState == STATE.VERIFYING_DELIVERY then
            local finalPackages = getPackageCount()
            if finalPackages == 0 then
                log(STATE.VERIFYING_DELIVERY, "✓ Recompensa confirmada")
                self:setState(STATE.WAITING_FOR_NEXT_JOB)
            else
                log(STATE.VERIFYING_DELIVERY, "Verificación fallida: " .. finalPackages .. " paquetes restantes", true)
                self:setState(STATE.ERROR_RECOVERY)
            end
        
        elseif self.currentState == STATE.WAITING_FOR_NEXT_JOB then
            log(STATE.WAITING_FOR_NEXT_JOB, "Esperando siguiente trabajo...")
            self.activeJob = nil
            self.pickupPoint = nil
            self.deliveryPoint = nil
            self.packagesCarrying = 0
            task.wait(2)
            self:setState(STATE.ACCEPTING_JOB)
        
        elseif self.currentState == STATE.ERROR_RECOVERY then
            log(STATE.ERROR_RECOVERY, "Iniciando recuperación de error...")
            self.activeJob = nil
            self.pickupPoint = nil
            self.deliveryPoint = nil
            task.wait(2)
            self:setState(STATE.IDLE)
        end
        
        task.wait(0.1)
    end
end

-- ==================== INICIAR SISTEMA ====================
local deliverySystem = DeliverySystem.new()
print("✓ Delivery System v2 iniciado")

task.spawn(function()
    deliverySystem:run()
end)

-- Limpiar GUI anterior si existe
if player.PlayerGui:FindFirstChild("DeliveryDebugGui") then
    player.PlayerGui.DeliveryDebugGui:Destroy()
end

-- GUI de debug
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DeliveryDebugGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local textLabel = Instance.new("TextLabel")
textLabel.Size = UDim2.new(0, 300, 0, 150)
textLabel.Position = UDim2.new(0, 10, 0, 10)
textLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
textLabel.TextColor3 = Color3.new(1, 1, 1)
textLabel.TextSize = 12
textLabel.Font = Enum.Font.Monospace
textLabel.TextXAlignment = Enum.TextXAlignment.Left
textLabel.TextYAlignment = Enum.TextYAlignment.Top
textLabel.Parent = screenGui
Instance.new("UICorner", textLabel).CornerRadius = UDim.new(0, 8)

game:GetService("RunService").Heartbeat:Connect(function()
    textLabel.Text = "DELIVERY SYSTEM v2\n" ..
                     "Estado: " .. deliverySystem.currentState .. "\n" ..
                     "Paquetes: " .. deliverySystem.packagesCarrying .. "/" .. CONFIG.TARGET_PACKAGES .. "\n" ..
                     "Tiempo Estado: " .. string.format("%.1f", deliverySystem:getElapsedStateTime()) .. "s\n" ..
                     "Job: " .. (deliverySystem.activeJob and deliverySystem.activeJob.Name or "N/A") .. "\n" ..
                     "Pickup: " .. (deliverySystem.pickupPoint and deliverySystem.pickupPoint.Name or "N/A") .. "\n" ..
                     "Delivery: " .. (deliverySystem.deliveryPoint and deliverySystem.deliveryPoint.Name or "N/A")
end)
