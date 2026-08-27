-- Driving Empire Delivery (caja + pin + confirmar)
if not game:IsLoaded() then game.Loaded:Wait() end

local player = game.Players.LocalPlayer
repeat task.wait() until player.Character and player.Character:FindFirstChild("HumanoidRootPart")

pcall(function()
    if player.PlayerGui:FindFirstChild("DeliveryOnlySymbols") then
        player.PlayerGui.DeliveryOnlySymbols:Destroy()
    end
end)

local CONFIG = {
    WaitPickup = 3.5,
    WaitDelivery = 3.5,
    ConfirmChecks = 4,
    ConfirmDelay = 1.0,
    Between = 1.0,
    MaxDistance = 5000,
}

local remotes = game.ReplicatedStorage:FindFirstChild("Remotes")
local startJob = remotes and remotes:FindFirstChild("RequestStartJobSession")

local running = false
local jobAcceptedOnce = false
local phase = "PICKUP"
local lastPos = nil

-- GUI
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
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.Parent = panel

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -12, 0, 50)
status.Position = UDim2.new(0, 6, 0, 28)
status.BackgroundTransparency = 1
status.Text = "Detenido"
status.TextColor3 = Color3.fromRGB(180, 180, 190)
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.TextWrapped = true
status.Parent = panel

local startBtn = Instance.new("TextButton")
startBtn.Size = UDim2.new(0, 180, 0, 32)
startBtn.Position = UDim2.new(0.5, -90, 0, 88)
startBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 80)
startBtn.Text = "INICIAR"
startBtn.TextColor3 = Color3.new(1, 1, 1)
startBtn.Font = Enum.Font.GothamBold
startBtn.TextSize = 13
startBtn.Parent = panel
Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 8)

local stopBtn = Instance.new("TextButton")
stopBtn.Size = UDim2.new(0, 180, 0, 28)
stopBtn.Position = UDim2.new(0.5, -90, 0, 124)
stopBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
stopBtn.Text = "DETENER"
stopBtn.TextColor3 = Color3.new(1, 1, 1)
stopBtn.Font = Enum.Font.GothamBold
stopBtn.TextSize = 12
stopBtn.Parent = panel
Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 8)

local function setStatus(t)
    status.Text = t
end

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

local function acceptJobOnce()
    if jobAcceptedOnce then return end
    if startJob then
        pcall(function() startJob:FireServer("Delivery", "jobPad") end)
        pcall(function() startJob:FireServer("DeliveryDriver", "jobPad") end)
        task.wait(1)
    end
    jobAcceptedOnce = true
    setStatus("Trabajo aceptado")
end

local function billboardPosition(bb)
    if bb.Adornee then
        if bb.Adornee:IsA("BasePart") then return bb.Adornee.Position end
        if bb.Adornee:IsA("Attachment") then return bb.Adornee.WorldPosition end
    end
    if bb.Parent and bb.Parent:IsA("BasePart") then return bb.Parent.Position end
    if bb.Parent and bb.Parent:IsA("Attachment") then return bb.Parent.WorldPosition end
    return nil
end

local function isIconBillboard(bb)
    if not bb:IsA("BillboardGui") or not bb.Enabled then return false end
    for _, ch in ipairs(bb:GetDescendants()) do
        if (ch:IsA("ImageLabel") or ch:IsA("ImageButton")) and ch.Image ~= "" then
            return true
        end
    end
    return false
end

local function classifySymbol(bb)
    local blob = string.lower(bb.Name)
    if bb.Parent then blob = blob .. " " .. string.lower(bb.Parent.Name) end
    for _, ch in ipairs(bb:GetDescendants()) do
        blob = blob .. " " .. string.lower(ch.Name)
        if ch:IsA("TextLabel") then
            blob = blob .. " " .. string.lower(ch.Text or "")
        end
    end

    if string.find(blob, "police") or string.find(blob, "security") or string.find(blob, "jobpad") then
        return nil
    end

    local isBox = string.find(blob, "box") or string.find(blob, "package") or string.find(blob, "pickup") or string.find(blob, "crate")
    local isPin = string.find(blob, "pin") or string.find(blob, "marker") or string.find(blob, "waypoint") or string.find(blob, "location") or string.find(blob, "drop") or string.find(blob, "deliver")

    if isBox then return "PICKUP" end
    if isPin then return "DELIVERY" end
    return nil
end

local function findSymbols(wanted)
    local root = getHRP()
    if not root then return {} end
    local rootPos = root.Position
    local list = {}
    local seen = {}
    local n = 0

    for _, obj in ipairs(workspace:GetDescendants()) do
        n = n + 1
        if n % 800 == 0 then task.wait() end

        if obj:IsA("BillboardGui") and isIconBillboard(obj) then
            if classifySymbol(obj) == wanted then
                local pos = billboardPosition(obj)
                if pos then
                    local dist = (pos - rootPos).Magnitude
                    if dist <= CONFIG.MaxDistance then
                        local key = math.floor(pos.X) .. "_" .. math.floor(pos.Z)
                        if not seen[key] then
                            seen[key] = true
                            table.insert(list, { position = pos, distance = dist, name = obj.Name })
                        end
                    end
                end
            end
        end
    end

    table.sort(list, function(a, b) return a.distance < b.distance end)
    return list
end

local function pinStillNear(pos)
    local pins = findSymbols("DELIVERY")
    for _, p in ipairs(pins) do
        if (p.position - pos).Magnitude < 25 then
            return true
        end
    end
    return false
end

local function confirmDelivery(pos)
    setStatus("Confirmando entrega...")
    for i = 1, CONFIG.ConfirmChecks do
        if not running then return false end
        tpTo(pos)
        task.wait(CONFIG.ConfirmDelay)
        setStatus("Confirmando " .. i .. "/" .. CONFIG.ConfirmChecks)
        if not pinStillNear(pos) then
            setStatus("Entrega CONFIRMADA")
            return true
        end
    end
    setStatus("NO confirmada - reintento")
    return false
end

local function farmLoop()
    acceptJobOnce()
    phase = "PICKUP"

    while running do
        if phase == "PICKUP" then
            local list = findSymbols("PICKUP")
            setStatus("Cajas: " .. #list)
            if #list == 0 then
                task.wait(1.5)
            else
                local data = list[1]
                setStatus("RECOGIDA")
                tpTo(data.position)
                task.wait(CONFIG.WaitPickup)
                phase = "DELIVERY"
                task.wait(0.8)
            end
        else
            local list = findSymbols("DELIVERY")
            setStatus("Pines: " .. #list)
            if #list == 0 then
                task.wait(1.2)
                if #findSymbols("DELIVERY") == 0 then
                    phase = "PICKUP"
                end
            else
                local data = list[1]
                setStatus("ENTREGA")
                tpTo(data.position)
                task.wait(CONFIG.WaitDelivery)
                if confirmDelivery(data.position) then
                    phase = "PICKUP"
                    task.wait(1)
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

print("Delivery script OK")
