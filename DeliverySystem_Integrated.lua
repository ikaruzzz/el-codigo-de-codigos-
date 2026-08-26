--[[
    DELIVERY AUTOMATION SYSTEM - INTEGRATED VERSION
    Roblox Studio - Driving Empire
    
    Integración completa con DeliveryConfig.lua
    PRIORIDAD: PRECISIÓN > VELOCIDAD
]]

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")

-- ==================== CARGAR CONFIGURACIÓN ====================
local DeliveryConfig = require(ReplicatedStorage:WaitForChild("DeliveryConfig"))
local CONFIG = DeliveryConfig.General

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
    if not CONFIG.DEBUG then return end
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
local function detectActiveJob()
    log(STATE.ACCEPTING_JOB, "Buscando trabajo activo...")
    
    local jobsFolder = DeliveryConfig:getJobsFolder()
    if not jobsFolder then
        log(STATE.ACCEPTING_JOB, "No se encontró carpeta de trabajos", true)
        return nil
    end
    
    local possibleJobs = {}
    
    for _, job in pairs(jobsFolder:GetChildren()) do
        local isDelivery = false
        
        -- Método 1: Por Attribute
        if DeliveryConfig.Job.identifyBy == "Attribute" then
            local attr = job:GetAttribute(DeliveryConfig.Job.attributeName)
            if attr == DeliveryConfig.Job.attributeValue then
                isDelivery = true
            end
        end
        
        -- Método 2: Por Name
        if DeliveryConfig.Job.identifyBy == "Name" and not isDelivery then
            if string.find(string.lower(job.Name), string.lower(DeliveryConfig.Job.namePattern)) then
                isDelivery = true
            end
        end
        
        if isDelivery then
            table.insert(possibleJobs, job)
        end
    end
    
    if #possibleJobs == 0 then
        log(STATE.ACCEPTING_JOB, "No se encontraron trabajos de Delivery", true)
        return nil
    elseif #possibleJobs > 1 then
        log(STATE.ACCEPTING_JOB, "Múltiples trabajos encontrados: " .. #possibleJobs .. " (usando el primero)", true)
    end
    
    local job = possibleJobs[1]
    local jobID = job:GetAttribute(DeliveryConfig.Job.properties.idAttribute) or "UNKNOWN"
    log(STATE.ACCEPTING_JOB, "Trabajo detectado: " .. job.Name .. " (ID: " .. tostring(jobID) .. ")")
    
    return job
end

-- ==================== VALIDACIÓN DE PICKUP ====================
local function findPickupPoint(job)
    if not job then
        log(STATE.FINDING_PICKUP, "Job inválido", true)
        return nil
    end
    
    log(STATE.FINDING_PICKUP, "Buscando punto de recogida para: " .. job.Name)
    
    local candidates = {}
    
    -- Método 1: Dentro del Job
    if DeliveryConfig.Pickup.findBy == "Inside" then
        for _, childName in ipairs(DeliveryConfig.Pickup.childNames) do
            local pickup = job:FindFirstChild(childName)
            if pickup then
                table.insert(candidates, pickup)
            end
        end
    end
    
    -- Método 2: Por Attribute
    if DeliveryConfig.Pickup.findBy == "ByAttribute" or #candidates == 0 then
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                local typeAttr = obj:GetAttribute(DeliveryConfig.Pickup.attributeName)
                local linkAttr = obj:GetAttribute(DeliveryConfig.Pickup.linkAttribute)
                
                if typeAttr == DeliveryConfig.Pickup.attributeValue then
                    if linkAttr == job.Name or linkAttr == job:GetAttribute("JobID") then
                        table.insert(candidates, obj)
                    end
                end
            end
        end
    end
    
    -- Método 3: Por proximidad
    if #candidates == 0 then
        log(STATE.FINDING_PICKUP, "No se encontró Pickup, buscando por proximidad", true)
        local jobPart = job:FindFirstChildWhichIsA("BasePart")
        if jobPart then
            for _, obj in pairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and string.find(string.lower(obj.Name), "pickup") then
                    local dist = (obj.Position - jobPart.Position).Magnitude
                    if dist < DeliveryConfig.Pickup.detectionRadius then
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
    log(STATE.VALIDATING_PICKUP, "Pickup validado: " .. pickup.Name .. " en " .. tostring(pickup.Position))
    return pickup
end

-- ==================== CONTEO DE PAQUETES ====================
local function getPackageCount()
    local count = 0
    
    -- Método 1: Leaderstats
    if DeliveryConfig.Package.countMethod == "Leaderstats" then
        pcall(function()
            local ls = player:FindFirstChild("leaderstats")
            if ls then
                local packages = ls:FindFirstChild(DeliveryConfig.Package.leaderstatsName)
                if not packages then
                    for _, alt in ipairs(DeliveryConfig.Package.leaderstatsAlternatives) do
                        packages = ls:FindFirstChild(alt)
                        if packages then break end
                    end
                end
                if packages then
                    count = packages.Value
                end
            end
        end)
    end
    
    -- Método 2: Atributo del personaje
    if count == 0 and DeliveryConfig.Package.countMethod == "Attribute" then
        pcall(function()
            count = character:GetAttribute(DeliveryConfig.Package.characterAttributeName) or 0
        end)
    end
    
    return count
end

local function findPackages(pickupPoint)
    if not pickupPoint then return {} end
    
    log(STATE.COLLECTING_PACKAGES, "Buscando paquetes cerca de: " .. pickupPoint.Name)
    
    local packages = {}
    
    pcall(function()
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                local isPackage = false
                
                -- Por nombre
                for _, pattern in ipairs(DeliveryConfig.Package.packageIdentification.namePatterns) do
                    if string.find(string.lower(obj.Name), string.lower(pattern)) then
                        isPackage = true
                        break
                    end
                end
                
                -- Por atributo
                if not isPackage then
                    local typeAttr = obj:GetAttribute(DeliveryConfig.Package.packageIdentification.attributeName)
                    if typeAttr == DeliveryConfig.Package.packageIdentification.attributeValue then
                        isPackage = true
                    end
                end
                
                if isPackage then
                    local dist = (obj.Position - pickupPoint.Position).Magnitude
                    if dist < DeliveryConfig.Package.searchRadius then
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
    
    -- Intentar mediante RemoteEvent
    pcall(function()
        local remote = DeliveryConfig:getRemote("collectPackage")
        if remote then
            if remote:IsA("RemoteFunction") then
                remote:InvokeServer(package)
            else
                remote:FireServer(package)
            end
        end
    end)
    
    -- Fallback: Acercarse
    hrp.CFrame = CFrame.new(package.Position + CONFIG.MOVEMENT_OFFSET)
    task.wait(DeliveryConfig.Package.searchRadius and 0.5 or 0.3)
    
    local newCount = getPackageCount()
    log(STATE.COLLECTING_PACKAGES, "Paquetes actuales: " .. newCount .. "/" .. DeliveryConfig.Package.targetCount)
    
    return true
end

-- ==================== BÚSQUEDA DE DESTINO ====================
local function findDeliveryPoint(job)
    if not job then
        log(STATE.FINDING_DELIVERY, "Job inválido", true)
        return nil
    end
    
    log(STATE.FINDING_DELIVERY, "Buscando punto de entrega para: " .. job.Name)
    
    local candidates = {}
    
    -- Método 1: Dentro del Job
    if DeliveryConfig.Delivery.findBy == "Inside" then
        for _, childName in ipairs(DeliveryConfig.Delivery.childNames) do
            local delivery = job:FindFirstChild(childName)
            if delivery then
                table.insert(candidates, delivery)
            end
        end
    end
    
    -- Método 2: Por Attribute
    if DeliveryConfig.Delivery.findBy == "ByAttribute" or #candidates == 0 then
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                local typeAttr = obj:GetAttribute(DeliveryConfig.Delivery.attributeName)
                local linkAttr = obj:GetAttribute(DeliveryConfig.Delivery.linkAttribute)
                
                if typeAttr == DeliveryConfig.Delivery.attributeValue then
                    if linkAttr == job.Name or linkAttr == job:GetAttribute("JobID") then
                        table.insert(candidates, obj)
                    end
                end
            end
        end
    end
    
    -- Método 3: Por proximidad global
    if #candidates == 0 then
        log(STATE.FINDING_DELIVERY, "No se encontró Delivery, buscando por proximidad", true)
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and string.find(string.lower(obj.Name), "delivery") then
                table.insert(candidates, obj)
            end
        end
    end
    
    if #candidates == 0 then
        log(STATE.FINDING_DELIVERY, "No se encontró punto de entrega", true)
        return nil
    elseif #candidates > 1 then
        log(STATE.FINDING_DELIVERY, "Múltiples puntos encontrados: " .. #candidates, true)
    end
    
    local delivery = candidates[1]
    log(STATE.VALIDATING_DELIVERY, "Delivery validado: " .. delivery.Name .. " en " .. tostring(delivery.Position))
    return delivery
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
    
    while tick() - startTime < CONFIG.MOVEMENT_TIMEOUT do
        if not target or not target.Parent then
            log(STATE.GOING_TO_DELIVERY, "Destino desapareció durante el viaje", true)
            return false
        end
        
        targetPos = target.Position + CONFIG.MOVEMENT_OFFSET
        hrp.CFrame = CFrame.new(hrp.Position:Lerp(targetPos, CONFIG.MOVEMENT_SPEED))
        
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
    
    pcall(function()
        local remote = DeliveryConfig:getRemote("deliver")
        if remote then
            if DeliveryConfig.Remotes.callMethod == "InvokeServer" then
                remote:InvokeServer(deliveryPoint)
            else
                remote:FireServer(deliveryPoint)
            end
        end
    end)
    
    task.wait(DeliveryConfig.Verification.verificationDelay)
    
    local packagesNow = getPackageCount()
    if packagesNow == DeliveryConfig.Verification.successPackageCount then
        log(STATE.VERIFYING_DELIVERY, "✓ Entrega confirmada - Paquetes: " .. packagesNow)
        return true
    else
        log(STATE.VERIFYING_DELIVERY, "Entrega no confirmada - Paquetes: " .. packagesNow, true)
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
                    if getPackageCount() < DeliveryConfig.Package.targetCount then
                        collectPackage(pkg)
                        task.wait(DeliveryConfig.General.DELAY_BETWEEN_PACKAGES)
                    end
                end
                
                self:setState(STATE.VERIFYING_PACKAGES)
            end
        
        elseif self.currentState == STATE.VERIFYING_PACKAGES then
            self.packagesCarrying = getPackageCount()
            
            if self.packagesCarrying == DeliveryConfig.Package.targetCount then
                log(STATE.VERIFYING_PACKAGES, "✓ Confirmados " .. DeliveryConfig.Package.targetCount .. "/" .. DeliveryConfig.Package.targetCount .. " paquetes")
                self:setState(STATE.FINDING_DELIVERY)
            elseif self.packagesCarrying > 0 then
                log(STATE.VERIFYING_PACKAGES, "Paquetes incompletos: " .. self.packagesCarrying .. "/" .. DeliveryConfig.Package.targetCount)
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
            if self.deliveryPoint and self.deliveryPoint.Parent and self.packagesCarrying == DeliveryConfig.Package.targetCount then
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
            task.wait(DeliveryConfig.General.DELAY_NEXT_JOB)
            self:setState(STATE.ACCEPTING_JOB)
        
        elseif self.currentState == STATE.ERROR_RECOVERY then
            log(STATE.ERROR_RECOVERY, "Iniciando recuperación de error...")
            self.activeJob = nil
            self.pickupPoint = nil
            self.deliveryPoint = nil
            task.wait(DeliveryConfig.General.DELAY_RETRY)
            self:setState(STATE.IDLE)
        end
        
        task.wait(CONFIG.DELAY_STATE_CHECK)
    end
end

-- ==================== INICIAR SISTEMA ====================
local deliverySystem = DeliverySystem.new()
print("✓ Delivery System Integrated - Iniciado correctamente")

task.spawn(function()
    deliverySystem:run()
end)

-- GUI de debug
if player.PlayerGui:FindFirstChild("DeliveryDebugGui") then
    player.PlayerGui.DeliveryDebugGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DeliveryDebugGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local textLabel = Instance.new("TextLabel")
textLabel.Size = UDim2.new(0, 350, 0, 180)
textLabel.Position = UDim2.new(0, 10, 0, 10)
textLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
textLabel.TextColor3 = Color3.new(1, 1, 1)
textLabel.TextSize = 11
textLabel.Font = Enum.Font.Monospace
textLabel.TextXAlignment = Enum.TextXAlignment.Left
textLabel.TextYAlignment = Enum.TextYAlignment.Top
textLabel.Parent = screenGui
Instance.new("UICorner", textLabel).CornerRadius = UDim.new(0, 8)

game:GetService("RunService").Heartbeat:Connect(function()
    textLabel.Text = "═══ DELIVERY SYSTEM v2 INTEGRATED ═══\n" ..
                     "Estado: " .. deliverySystem.currentState .. "\n" ..
                     "Paquetes: " .. deliverySystem.packagesCarrying .. "/" .. DeliveryConfig.Package.targetCount .. "\n" ..
                     "Tiempo Estado: " .. string.format("%.1f", deliverySystem:getElapsedStateTime()) .. "s\n" ..
                     "Job: " .. (deliverySystem.activeJob and deliverySystem.activeJob.Name or "N/A") .. "\n" ..
                     "Pickup: " .. (deliverySystem.pickupPoint and deliverySystem.pickupPoint.Name or "N/A") .. "\n" ..
                     "Delivery: " .. (deliverySystem.deliveryPoint and deliverySystem.deliveryPoint.Name or "N/A") .. "\n" ..
                     "═════════════════════════════════════"
end)
