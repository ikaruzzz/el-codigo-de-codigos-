# 📖 GUÍA DE INTEGRACIÓN - DELIVERY SYSTEM v2

**Versión:** 2.0  
**Fecha:** 2026-08-26  
**Prioridad:** PRECISIÓN > VELOCIDAD

---

## 📋 ÍNDICE

1. [Introducción](#introducción)
2. [Requisitos Previos](#requisitos-previos)
3. [Estructura de Archivos](#estructura-de-archivos)
4. [Paso a Paso: Adaptación](#paso-a-paso-adaptación)
5. [Debugging y Troubleshooting](#debugging-y-troubleshooting)
6. [Preguntas Frecuentes](#preguntas-frecuentes)

---

## 🎯 Introducción

Este sistema de Delivery automatiza completamente el flujo de trabajo de repartidor en tu juego Roblox:

```
ACEPTAR TRABAJO
    ↓
DETECTAR PICKUP
    ↓
RECOGER 4 PAQUETES
    ↓
DETECTAR DELIVERY
    ↓
ENTREGAR PAQUETES
    ↓
SIGUIENTE TRABAJO
```

**Características principales:**
- ✅ Máquina de estados de 14 niveles
- ✅ Validación en cada paso
- ✅ Sin coordenadas hardcodeadas
- ✅ Adaptable a cualquier estructura
- ✅ Debug en tiempo real

---

## 🔧 Requisitos Previos

- **Roblox Studio** abierto con tu juego
- **Acceso a la estructura** del juego (Workspace, ReplicatedStorage)
- **3 archivos Lua:**
  - `DeliveryConfig.lua`
  - `DeliverySystem_Integrated.lua`
  - (Opcional) `main.lua` mejorado

---

## 📁 Estructura de Archivos

### Tu repositorio debe quedar así:

```
tu-juego/
├── main.lua                      (Mejorado: ATM + otras funciones)
├── DeliverySystem_Integrated.lua (Sistema principal)
├── DeliveryConfig.lua            (Configuración - EDITAR ESTO)
├── INTEGRATION_GUIDE.md          (Esta guía)
└── docs/
    └── CONFIG_EXAMPLES.md        (Ejemplos de configuración)
```

### En Roblox Studio debe estar así:

```
ReplicatedStorage/
├── DeliveryConfig.lua        ← Copiar aquí
├── DeliverySystem_Integrated.lua
└── Remotes/
    ├── CollectPackage
    ├── Deliver
    └── (otros remotes)

Workspace/
└── Game/
    └── Jobs/
        └── (tus trabajos de delivery)
```

---

## 🚀 Paso a Paso: Adaptación

### FASE 1: EXPLORACIÓN (30 minutos)

#### 1.1 Abre tu juego en Roblox Studio

#### 1.2 Presiona **View → Explorer** (Ctrl+Shift+E)

Verás una ventana con toda la estructura del juego.

#### 1.3 Documenta TODAS estas ubicaciones:

Abre un documento de texto y anota:

```
=== ESTRUCTURA DE MI JUEGO ===

1. ¿Dónde están los trabajos?
   - Ubicación: ReplicatedStorage/Jobs o Workspace/Game/Jobs
   - Camino completo: _______________________
   
2. ¿Cómo se llama un trabajo de Delivery?
   - Ejemplos de nombres: _______________________
   - ¿Tiene atributo JobType? Sí/No
   - Si tiene atributo, ¿cuál es el valor?: _______
   
3. ¿Dónde está el punto de recogida?
   - ¿Dentro del Job? Sí/No
   - ¿Nombre del objeto?: _______________________
   - ¿Atributo vinculado?: _______________________
   
4. ¿Cómo contar paquetes?
   - ¿En leaderstats? Sí/No
   - ¿Nombre exacto?: _______________________
   - ¿O es atributo del personaje?: _______________________
   
5. ¿Dónde están los paquetes (objetos)?
   - ¿En el Workspace? Sí/No
   - ¿Nombre/patrón?: _______________________
   
6. ¿Dónde está el punto de entrega?
   - ¿Dentro del Job? Sí/No
   - ¿Nombre?: _______________________
   
7. ¿Qué RemoteEvents existen?
   - Para recoger: _______________________
   - Para entregar: _______________________
   - Ubicación: _______________________
```

---

### FASE 2: CONFIGURACIÓN (15 minutos)

#### 2.1 Abre `DeliveryConfig.lua` en tu editor

#### 2.2 Reemplaza los valores PLACEHOLDER:

**SECCIÓN: Rutas y Ubicaciones**

```lua
DeliveryConfig.Paths = {
    JobsFolder = {
        service = "ReplicatedStorage", -- ← CAMBIAR SI ES DIFERENTE
        path = "Jobs", -- ← CAMBIAR CON TU RUTA
    },
    RemotesFolder = {
        service = "ReplicatedStorage",
        path = "Remotes",
    },
}
```

**SECCIÓN: Identificación de Jobs**

Si tu juego identifica trabajos por **atributo**:

```lua
DeliveryConfig.Job = {
    identifyBy = "Attribute",
    attributeName = "JobType",      -- ← NOMBRE REAL DEL ATRIBUTO
    attributeValue = "Delivery",    -- ← VALOR REAL
    ...
}
```

Si identifica por **nombre**:

```lua
DeliveryConfig.Job = {
    identifyBy = "Name",
    namePattern = "Delivery",  -- ← PATRÓN REAL (ej: "Delivery", "Entrega")
    ...
}
```

**SECCIÓN: Paquetes**

```lua
DeliveryConfig.Package = {
    countMethod = "Leaderstats",
    leaderstatsName = "Packages",  -- ← NOMBRE REAL
    ...
}
```

---

### FASE 3: PRUEBA (20 minutos)

#### 3.1 Copia los archivos a ReplicatedStorage

1. En Studio: **ReplicatedStorage → click derecho → Insert Object → LocalScript**
2. Renómbralo a `DeliveryConfig`
3. Pega el contenido de `DeliveryConfig.lua`

Repite con `DeliverySystem_Integrated.lua`

#### 3.2 Ejecuta una prueba simple

Abre **CommandBar** (Ctrl+Shift+C) y ejecuta:

```lua
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("DeliveryConfig"))
print("Buscando Jobs en: " .. Config.Paths.JobsFolder.path)
local folder = Config:getJobsFolder()
if folder then
    print("✓ Carpeta encontrada!")
    for _, job in pairs(folder:GetChildren()) do
        print("  - " .. job.Name)
    end
else
    print("✗ Carpeta NO encontrada - Revisar ruta")
end
```

Si ves los trabajos → **¡Configuración correcta!**  
Si NO ves nada → **Revisar la ruta en DeliveryConfig.lua**

#### 3.3 Ejecuta el sistema completo

En **ServerScriptService**, agrega un nuevo script con:

```lua
require(game:GetService("ReplicatedStorage"):WaitForChild("DeliverySystem_Integrated"))
```

Si ves el GUI de debug en pantalla → **¡Funcionando!**

---

## 🐛 Debugging y Troubleshooting

### Problema: "Carpeta de trabajos no encontrada"

**Solución:**
```lua
-- En CommandBar, explora la estructura real:
local rs = game:GetService("ReplicatedStorage")
for _, obj in pairs(rs:GetChildren()) do
    print(obj.Name .. " (" .. obj.ClassName .. ")")
end
```

Busca una carpeta con "Jobs", "Job", "Work", "Task", etc.

---

### Problema: "No detecta trabajos de Delivery"

**Solución:**
```lua
-- En CommandBar:
local jobsFolder = game:GetService("ReplicatedStorage"):FindFirstChild("Jobs")
if jobsFolder then
    for _, job in pairs(jobsFolder:GetChildren()) do
        print("Job: " .. job.Name)
        print("  Atributos:", job:GetAttributes())
    end
end
```

Anota exactamente qué atributos tiene cada trabajo.

---

### Problema: "No cuenta los paquetes correctamente"

**Solución:**
```lua
-- En CommandBar:
local player = game.Players.LocalPlayer
local ls = player:FindFirstChild("leaderstats")
if ls then
    for _, stat in pairs(ls:GetChildren()) do
        print(stat.Name .. ": " .. stat.Value)
    end
else
    print("No hay leaderstats")
end

-- O revisa atributos del personaje:
local char = player.Character
if char then
    print("Atributos del personaje:", char:GetAttributes())
end
```

---

### Problema: "El sistema no se mueve"

**Solución:**
1. Revisa la consola (F9) - ¿Hay errores?
2. Abre el GUI de debug (esquina superior izquierda)
3. ¿En qué estado está? ¿Cuánto tiempo lleva?
4. Si dice "ERROR" → Revisa la configuración

---

## 📝 Ejemplos de Configuración

### Ejemplo 1: Juego simple con Attributes

```lua
-- Estructura del juego:
-- ReplicatedStorage/Jobs/DeliveryJob1
--   - Atributo: JobType = "Delivery"
--   - Atributo: PickupPointID = "pickup_1"
--   - Atributo: DeliveryPointID = "delivery_1"

DeliveryConfig.Job = {
    identifyBy = "Attribute",
    attributeName = "JobType",
    attributeValue = "Delivery",
}

DeliveryConfig.Pickup = {
    findBy = "ByAttribute",
    attributeName = "Type",
    attributeValue = "Pickup",
    linkAttribute = "PickupFor",
}
```

---

### Ejemplo 2: Juego con estructura anidada

```lua
-- Estructura:
-- ReplicatedStorage/GameJobs/Delivery/Job1
--   - Pickup (carpeta dentro)
--   - DeliveryPoint (carpeta dentro)

DeliveryConfig.Paths.JobsFolder = {
    service = "ReplicatedStorage",
    path = "GameJobs/Delivery",
}

DeliveryConfig.Pickup.findBy = "Inside"
DeliveryConfig.Pickup.childNames = {"Pickup", "PickupPoint"}

DeliveryConfig.Delivery.findBy = "Inside"
DeliveryConfig.Delivery.childNames = {"DeliveryPoint", "Destination"}
```

---

### Ejemplo 3: Juego con RemoteEvents personalizados

```lua
DeliveryConfig.Remotes = {
    acceptJobNames = {"CustomStartJob", "BeginWork"},
    collectPackageNames = {"GrabBox", "TakeItem"},
    deliverNames = {"DropOff", "Complete"},
    callMethod = "InvokeServer", -- Si es RemoteFunction
}
```

---

## ❓ Preguntas Frecuentes

### P: ¿Qué pasa si mi juego tiene una estructura completamente diferente?

**R:** El sistema está diseñado para ser flexible. Revisa la sección "Paso a Paso: Adaptación" y adapta cada configuración según lo que encuentres.

---

### P: ¿Puedo usar esto en un LocalScript o debe ser ServerScript?

**R:** Puede ser ambos, pero preferiblemente:
- **LocalScript** en StarterPlayer/StarterPlayerScripts (más rápido)
- **ServerScript** en ServerScriptService (más seguro)

---

### P: ¿Qué significan los estados?

**R:**
- `IDLE` → Esperando
- `ACCEPTING_JOB` → Buscando trabajo
- `FINDING_PICKUP` → Localizando punto de recogida
- `GOING_TO_PICKUP` → Viajando al pickup
- `COLLECTING_PACKAGES` → Recogiendo los 4 paquetes
- `FINDING_DELIVERY` → Buscando destino
- `GOING_TO_DELIVERY` → Viajando al destino
- `DELIVERING` → Entregando paquetes
- `ERROR_RECOVERY` → Recuperándose de un error

---

### P: ¿Por qué se queda en un estado sin avanzar?

**R:** Generalmente es porque:
1. **Timeout**: Espera demasiado sin encontrar lo que busca
2. **Configuración incorrecta**: DeliveryConfig.lua tiene valores equivocados
3. **Objeto no existe**: El pickup o delivery no está en su estructura

**Solución:** Revisa los logs de la consola (F9)

---

### P: ¿Puedo pausar o detener el sistema?

**R:** Sí, desde la consola:

```lua
-- Parar
_G.DeliverySystemRunning = false

-- Reiniciar
_G.DeliverySystemRunning = true
```

(Esto requiere modificar el script, pero es fácil)

---

## 🎓 Tips y Mejores Prácticas

✅ **SÍ hacer:**
- Documentar exactamente tu estructura de juego
- Probar cada función de configuración por separado
- Revisar logs en consola regularmente
- Usar atributos en objetos (es más confiable)

❌ **NO hacer:**
- Usar coordenadas XYZ hardcodeadas
- Asumir nombres de objetos sin verificar
- Ejecutar todo de una vez sin probar
- Ignorar mensajes de error

---

## 📞 Soporte

Si tienes problemas:

1. **Revisa los logs** en la consola (F9)
2. **Verifica la estructura** del juego en Explorer
3. **Usa los ejemplos** como referencia
4. **Compara** tu DeliveryConfig.lua con los ejemplos

---

**¡Listo para integrar!** 🚀
