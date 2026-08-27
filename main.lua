--[[
    Driving Empire - SOLO símbolos de caja y pin
    No busca anillos, árboles ni flechas
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
    WaitAtSymbol = 3.5,
    Between = 1.0,
    MaxDistance = 5000,
}

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
local startJob = remotes and remotes:FindFirstChild("RequestStartJobSession")

local running = false
local phase = "PICKUP" -- PICKUP = caja | DELIVERY = pin
local lastPos = nil

-- GUI mínima
local gui = Instance.new("ScreenGui")
gui.Name = "DeliveryOnlySymbols"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 200, 0, 150)
panel.Position = UDim2.new(1, -220, 0.5, -75)
panel.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
panel.BorderSizePixel = 0
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 26)
title.BackgroundTransparency = 1
title.Text = "Solo Caja / Pin"
title.TextColor3 = Color3.new(1,1,1)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.Parent = panel

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -12, 0, 45)
status.Position = UDim2.new(0, 6, 0, 28)
status.BackgroundTransparency = 1
status.Text = "Detenido"
status.TextColor3 = Color3.fromRGB(180,180,190)
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.TextWrapped = true
status.Parent = panel

local startBtn = Instance.new("TextButton")
startBtn.Size = UDim2.new(0, 170, 0, 32)
startBtn.Position = UDim2.new(0.5, -85, 0, 80)
startBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 80)
startBtn.Text = "INICIAR"
startBtn.TextColor3 = Color3.new(1,1,1)
startBtn.Font = Enum.Font.GothamBold
startBtn.TextSize = 13
startBtn.Parent = panel
Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 8)

local stopBtn = Instance.new("TextButton")
stopBtn.Size = UDim2.new(0, 170, 0, 28)
stopBtn.Position = UDim2.new(0.5, -85, 0, 116)
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

-- Posición del BillboardGui (el símbolo flotante)
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

--[[
    SOLO BillboardGui que parecen iconos del Delivery:
    - Tienen ImageLabel (el dibujo de la caja o del pin)
    - Suelen ser AlwaysOnTop
    - Tamaño de icono (no UI enorme)
]]
local function isIconBillboard(bb)
    if not bb:IsA("BillboardGui") then return false end
    if not bb.Enabled then return false end

    -- Debe tener al menos una imagen (el símbolo)
    local hasImage = false
    for _, ch in ipairs(bb:GetDescendants()) do
        if ch:IsA("ImageLabel") or ch:IsA("ImageButton") then
            if ch.Image ~= "" and ch.Visible ~= false then
                hasImage = true
                break
            end
        end
    end
    if not hasImage then return false end

    -- Iconos suelen ser relativamente pequeños en studs
    local sz = bb.Size
    local maxAxis = math.max(sz.X.Offset, sz.Y.Offset, sz.X.Scale * 50, sz.Y.Scale * 50)
    -- evitar billboards gigantes de decoración
    if maxAxis > 200 then return false end

    return true
end

local function collectIconBillboards()
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
            local pos = billboardPosition(obj)
            if pos then
                local dist = (pos - rootPos).Magnitude
                if dist <= CONFIG.MaxDistance then
                    local key = string.format("%.0f_%.0f_%.0f", pos.X, pos.Y, pos.Z)
                    if not seen[key] then
                        if not (lastPos and (pos - lastPos).Magnitude < 8) then
                            seen[key] = true
                            table.insert(list, {
                                bb = obj,
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

local function farmLoop()
    tryAcceptJob()
    setStatus("Buscando iconos...")

    while running do
        local icons = collectIconBillboards()
        setStatus("Iconos encontrados: " .. #icons)

        if #icons == 0 then
            tryAcceptJob()
            setStatus("Sin símbolos\nReintentando...")
            task.wait(1.8)
        else
            -- Va a cada icono de Billboard encontrado (caja y pin son de este tipo)
            for i, data in ipairs(icons) do
                if not running then break end
                lastPos = data.position
                setStatus("Símbolo " .. i .. "/" .. #icons .. "\n" .. data.name)
                tpTo(data.position)
                task.wait(CONFIG.WaitAtSymbol)
            end
            lastPos = nil
            tryAcceptJob()
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

print("[DELIVERY] Solo BillboardGui con imagen (caja/pin)")
