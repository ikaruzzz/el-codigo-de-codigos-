--[[
    DELIVERY SYSTEM - CONFIGURATION FILE
    =====================================
    
    Este archivo contiene TODAS las configuraciones necesarias para adaptar
    el sistema de Delivery a tu juego específico.
    
    Instrucciones:
    1. Abre tu juego en Roblox Studio
    2. Explora la estructura y busca dónde están los Jobs, Pickups, Packages, etc.
    3. Reemplaza los PLACEHOLDERS con información real de tu juego
    4. Prueba el sistema
]]

local DeliveryConfig = {}

-- ==================== RUTAS Y UBICACIONES ====================
DeliveryConfig.Paths = {
    -- Donde se almacenan los trabajos activos
    JobsFolder = {
        service = "ReplicatedStorage", -- "ReplicatedStorage", "Workspace", "ServerStorage"
        path = "Jobs", -- Ruta dentro del servicio: "Jobs" o "Game/Jobs" o "Remotes/Jobs"
    },
    
    -- Donde se almacenan los Remotes/Events
    RemotesFolder = {
        service = "ReplicatedStorage",
        path = "Remotes",
    },
}

-- ==================== IDENTIFICACIÓN DE JOBS ====================
DeliveryConfig.Job = {
    -- ¿Cómo se identifica un trabajo de Delivery?
    -- Opciones: "Name", "Attribute", "ParentName", "Custom"
    identifyBy = "Attribute", -- CAMBIAR SEGÚN TU JUEGO
    
    -- Si es por Attribute:
    attributeName = "JobType",
    attributeValue = "Delivery",
    
    -- Si es por Name (búsqueda de texto):
    namePattern = "Delivery", -- Busca trabajos que contengan "Delivery" en el nombre
    
    -- Propiedades que caracterizan un Job
    properties = {
        hasID = true, -- ¿El job tiene un ID único?
        idAttribute = "JobID",
        hasPickupReference = true, -- ¿Referencia al pickup?
        pickupReferenceAttribute = "PickupPointID",
        hasDeliveryReference = true, -- ¿Referencia al destino?
        deliveryReferenceAttribute = "DeliveryPointID",
    },
}

-- ==================== IDENTIFICACIÓN DE PICKUP ====================
DeliveryConfig.Pickup = {
    -- ¿Cómo encontrar el punto de recogida?
    -- Opciones: "Inside", "ByAttribute", "ByName", "Custom"
    findBy = "ByAttribute", -- CAMBIAR SEGÚN TU JUEGO
    
    -- Si está dentro del Job (findBy = "Inside"):
    childNames = {"Pickup", "PickupPoint", "RecogidaPoint"},
    
    -- Si es por Attribute:
    attributeName = "Type",
    attributeValue = "Pickup",
    
    -- Vinculación con el Job actual
    linkAttribute = "PickupFor", -- ¿Qué atributo vincula Pickup con Job?
    
    -- Validaciones
    mustBeBasePart = true,
    detectionRadius = 200, -- Radio de búsqueda desde el Job
}

-- ==================== IDENTIFICACIÓN DE PAQUETES ====================
DeliveryConfig.Package = {
    -- ¿Cómo contar los paquetes?
    -- Opciones: "Attribute", "Leaderstats", "Inventory", "Custom"
    countMethod = "Leaderstats", -- CAMBIAR SEGÚN TU JUEGO
    
    -- Si es por Leaderstats:
    leaderstatsName = "Packages", -- Busca en leaderstats la propiedad "Packages"
    leaderstatsAlternatives = {"PackagesCarrying", "DeliveryPackages", "PackageCount"},
    
    -- Si es por Atributo del personaje:
    characterAttributeName = "Packages",
    
    -- Identificación de objetos paquete en el mundo
    packageIdentification = {
        findBy = "Name", -- "Name", "Attribute", "Custom"
        namePatterns = {"Package", "Box", "Parcel", "Crate"},
        attributeName = "Type",
        attributeValue = "Package",
    },
    
    -- RemoteEvent para recoger
    remoteNames = {"CollectPackage", "TakePackage", "PickupPackage", "GetPackage"},
    
    -- Número objetivo
    targetCount = 4,
    searchRadius = 50, -- Desde el punto de recogida
}

-- ==================== IDENTIFICACIÓN DE DELIVERY ====================
DeliveryConfig.Delivery = {
    -- ¿Cómo encontrar el punto de entrega?
    findBy = "ByAttribute", -- "Inside", "ByAttribute", "ByName", "Custom"
    
    -- Si está dentro del Job:
    childNames = {"Delivery", "DeliveryPoint", "Destination", "EntregaPoint"},
    
    -- Si es por Attribute:
    attributeName = "Type",
    attributeValue = "Delivery",
    
    -- Vinculación con el Job
    linkAttribute = "DeliveryFor",
    
    -- Validaciones
    mustBeBasePart = true,
    detectionRadius = 500, -- Radio de búsqueda global
}

-- ==================== REMOTES Y EVENTOS ====================
DeliveryConfig.Remotes = {
    -- RemoteEvent para aceptar trabajo
    acceptJobNames = {"RequestStartJobSession", "AcceptJob", "StartJob"},
    
    -- RemoteEvent para recoger paquetes
    collectPackageNames = {"CollectPackage", "TakePackage", "PickupPackage"},
    
    -- RemoteEvent para entregar
    deliverNames = {"Deliver", "DeliverPackages", "CompleteDelivery", "FinishDelivery"},
    
    -- ¿Cómo se llama? ¿FireServer() o InvokeServer()?
    callMethod = "FireServer", -- "FireServer" o "InvokeServer"
}

-- ==================== CONFIRMACIÓN DE ENTREGA ====================
DeliveryConfig.Verification = {
    -- ¿Cómo se verifica que la entrega fue exitosa?
    -- Opciones: "PackageCount", "Attribute", "Event", "Custom"
    verifyBy = "PackageCount", -- CAMBIAR SEGÚN TU JUEGO
    
    -- Si es por conteo de paquetes:
    successPackageCount = 0, -- Si llega a 0, entrega exitosa
    
    -- Si es por atributo:
    attributeName = "DeliveryComplete",
    expectedValue = true,
    
    -- Espera antes de verificar (segundos)
    verificationDelay = 1,
    
    -- ¿Hay evento que notifique fin de trabajo?
    eventName = "DeliveryCompleted",
}

-- ==================== CONFIGURACIÓN GENERAL ====================
DeliveryConfig.General = {
    -- Debug activo
    DEBUG = true,
    
    -- Timeouts
    TIMEOUT_JOB_DETECTION = 5,
    TIMEOUT_PICKUP_DETECTION = 10,
    TIMEOUT_PACKAGE_DETECTION = 8,
    TIMEOUT_DELIVERY_DETECTION = 10,
    
    -- Movimiento
    MOVEMENT_OFFSET = Vector3.new(0, 3, 0), -- Altura para no clavarse en el suelo
    ARRIVAL_DISTANCE = 15, -- Distancia considerada como "llegada"
    MOVEMENT_SPEED = 0.1, -- Interpolación de movimiento (0-1)
    MOVEMENT_TIMEOUT = 30, -- Segundos máximos para llegar
    
    -- Delays
    DELAY_BETWEEN_PACKAGES = 0.3,
    DELAY_BETWEEN_DELIVERIES = 2,
    DELAY_STATE_CHECK = 0.1,
    DELAY_RETRY = 1,
    DELAY_NEXT_JOB = 2,
}

-- ==================== FUNCIONES AUXILIARES ====================

local function getService(serviceName)
    if serviceName == "ReplicatedStorage" then
        return game:GetService("ReplicatedStorage")
    elseif serviceName == "Workspace" then
        return game:GetService("Workspace")
    elseif serviceName == "ServerStorage" then
        return game:GetService("ServerStorage")
    end
    return nil
end

function DeliveryConfig:getJobsFolder()
    local service = getService(self.Paths.JobsFolder.service)
    if not service then return nil end
    
    local current = service
    local pathParts = string.split(self.Paths.JobsFolder.path, "/")
    
    for _, part in ipairs(pathParts) do
        current = current:FindFirstChild(part)
        if not current then return nil end
    end
    
    return current
end

function DeliveryConfig:getRemotesFolder()
    local service = getService(self.Paths.RemotesFolder.service)
    if not service then return nil end
    
    local current = service
    local pathParts = string.split(self.Paths.RemotesFolder.path, "/")
    
    for _, part in ipairs(pathParts) do
        current = current:FindFirstChild(part)
        if not current then return nil end
    end
    
    return current
end

function DeliveryConfig:getRemote(remoteType)
    -- remoteType: "acceptJob", "collectPackage", "deliver"
    local remotesFolder = self:getRemotesFolder()
    if not remotesFolder then return nil end
    
    local names = self.Remotes[remoteType .. "Names"]
    if not names then return nil end
    
    for _, name in ipairs(names) do
        local remote = remotesFolder:FindFirstChild(name)
        if remote then return remote end
    end
    
    return nil
end

-- ==================== EXPORTAR CONFIGURACIÓN ====================
return DeliveryConfig
