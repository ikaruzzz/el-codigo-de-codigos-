--[[
    Farm GUI + ATM AutoFarm + Delivery AutoFarm
    Autor: [Tu Nombre]
    
    - ATM: Farma sin parar. Al llegar al límite, entrega y continúa.
    - Delivery: Busca paquetes automáticamente.
    - Botón "Finalizar Farmeo" para detener todo.
]]

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- ======================================================
--                    CONFIGURACIÓN
-- ======================================================

local CONFIG = {
	-- Apariencia
	ButtonSize = UDim2.new(0, 160, 0, 34),
	PrimaryColor = Color3.fromRGB(0, 170, 80),
	SecondaryColor = Color3.fromRGB(0, 120, 255),
	AccentColor = Color3.fromRGB(255, 170, 0),
	StopColor = Color3.fromRGB(200, 40, 40),
	BackgroundColor = Color3.fromRGB(22, 22, 28),
	TextColor = Color3.fromRGB(255, 255, 255),
	PanelPosition = UDim2.new(1, -185, 1, -380),
	
	-- ATM
	ATMPositions = {
		Vector3.new(100, 5, 50),
		Vector3.new(150, 5, 80),
		Vector3.new(200, 5, 30),
	},
	ATMRemote = "WithdrawMoney",
	ATMPrompt = "ATMPrompt",
	ATMWaitTime = 1.1,
	
	-- Límite de dinero
	MoneyLimit = 50000,
	MoneyValueName = "Money",
	
	-- Punto de entrega
	DeliveryPosition = Vector3.new(0, 10, 0),
	DeliveryRemote = "DeliverItem",
	DeliveryPrompt = "DeliveryPrompt",
	
	-- Delivery (paquetes)
	PackageNames = {
		"Package", "Box", "Delivery", "Parcel", "Caja", "Paquete", "Pickup"
	},
	DeliveryWaitTime = 1.3,
}

-- ======================================================
--                 CREACIÓN DE LA GUI
-- ======================================================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FarmGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "MainPanel"
panel.Size = UDim2.new(0, 175, 0, 360)
panel.Position = CONFIG.PanelPosition
panel.BackgroundColor3 = CONFIG.BackgroundColor
panel.BorderSizePixel = 0
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(55, 55, 65)
panelStroke.Thickness = 1.5
panelStroke.Parent = panel

-- Título
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 0, 28)
title.Position = UDim2.new(0, 10, 0, 5)
title.BackgroundTransparency = 1
title.Text = "Farm Menu"
title.TextColor3 = CONFIG.TextColor
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

-- Botón Minimizar
local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 28, 0, 28)
minimizeBtn.Position = UDim2.new(1, -33, 0, 5)
minimizeBtn.BackgroundColor3 = CONFIG.AccentColor
minimizeBtn.Text = "−"
minimizeBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 20
minimizeBtn.BorderSizePixel = 0
minimizeBtn.Parent = panel

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 6)
minCorner.Parent = minimizeBtn

-- Contenedor
local content = Instance.new("Frame")
content.Name = "Content"
content.Size = UDim2.new(1, 0, 1, -35)
content.Position = UDim2.new(0, 0, 0, 35)
content.BackgroundTransparency = 1
content.Parent = panel

-- Botón Delivery AutoFarm
local deliveryBtn = Instance.new("TextButton")
deliveryBtn.Size = CONFIG.ButtonSize
deliveryBtn.Position = UDim2.new(0.5, -80, 0, 5)
deliveryBtn.BackgroundColor3 = CONFIG.PrimaryColor
deliveryBtn.Text = "Delivery AutoFarm: OFF"
deliveryBtn.TextColor3 = CONFIG.TextColor
deliveryBtn.Font = Enum.Font.GothamBold
deliveryBtn.TextSize = 12
deliveryBtn.BorderSizePixel = 0
deliveryBtn.Parent = content

local dCorner = Instance.new("UICorner")
dCorner.CornerRadius = UDim.new(0, 8)
dCorner.Parent = deliveryBtn

-- Botón ATM AutoFarm
local atmBtn = Instance.new("TextButton")
atmBtn.Size = CONFIG.ButtonSize
atmBtn.Position = UDim2.new(0.5, -80, 0, 45)
atmBtn.BackgroundColor3 = CONFIG.SecondaryColor
atmBtn.Text = "ATM AutoFarm: OFF"
atmBtn.TextColor3 = CONFIG.TextColor
atmBtn.Font = Enum.Font.GothamBold
atmBtn.TextSize = 12
atmBtn.BorderSizePixel = 0
atmBtn.Parent = content

local aCorner = Instance.new("UICorner")
aCorner.CornerRadius = UDim.new(0, 8)
aCorner.Parent = atmBtn

-- Texto límite
local limitTitle = Instance.new("TextLabel")
limitTitle.Size = UDim2.new(1, -20, 0, 18)
limitTitle.Position = UDim2.new(0, 10, 0, 90)
limitTitle.BackgroundTransparency = 1
limitTitle.Text = "Límite para entregar:"
limitTitle.TextColor3 = Color3.fromRGB(200, 200, 210)
limitTitle.Font = Enum.Font.Gotham
limitTitle.TextSize = 12
limitTitle.TextXAlignment = Enum.TextXAlignment.Left
limitTitle.Parent = content

-- TextBox
local limitBox = Instance.new("TextBox")
limitBox.Size = UDim2.new(0, 100, 0, 28)
limitBox.Position = UDim2.new(0, 10, 0, 110)
limitBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
limitBox.Text = tostring(CONFIG.MoneyLimit)
limitBox.TextColor3 = CONFIG.TextColor
limitBox.Font = Enum.Font.GothamBold
limitBox.TextSize = 14
limitBox.PlaceholderText = "Ej: 50000"
limitBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
limitBox.ClearTextOnFocus = false
limitBox.BorderSizePixel = 0
limitBox.Parent = content

local boxCorner = Instance.new("UICorner")
boxCorner.CornerRadius = UDim.new(0, 6)
boxCorner.Parent = limitBox

-- Botón OK
local applyBtn = Instance.new("TextButton")
applyBtn.Size = UDim2.new(0, 50, 0, 28)
applyBtn.Position = UDim2.new(0, 115, 0, 110)
applyBtn.BackgroundColor3 = Color3.fromRGB(140, 60, 200)
applyBtn.Text = "OK"
applyBtn.TextColor3 = CONFIG.TextColor
applyBtn.Font = Enum.Font.GothamBold
applyBtn.TextSize = 14
applyBtn.BorderSizePixel = 0
applyBtn.Parent = content

local applyCorner = Instance.new("UICorner")
applyCorner.CornerRadius = UDim.new(0, 6)
applyCorner.Parent = applyBtn

-- Botón FINALIZAR FARMEO
local stopBtn = Instance.new("TextButton")
stopBtn.Size = UDim2.new(0, 160, 0, 36)
stopBtn.Position = UDim2.new(0.5, -80, 0, 150)
stopBtn.BackgroundColor3 = CONFIG.StopColor
stopBtn.Text = "FINALIZAR FARMEO"
stopBtn.TextColor3 = CONFIG.TextColor
stopBtn.Font = Enum.Font.GothamBold
stopBtn.TextSize = 13
stopBtn.BorderSizePixel = 0
stopBtn.Parent = content

local stopCorner = Instance.new("UICorner")
stopCorner.CornerRadius = UDim.new(0, 8)
stopCorner.Parent = stopBtn

-- Info
local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -16, 0, 90)
infoLabel.Position = UDim2.new(0, 8, 0, 200)
infoLabel.BackgroundTransparency = 1
infoLabel.Text = "Límite: $" .. CONFIG.MoneyLimit .. "\n\nAl llegar al límite\nentrega y sigue farmeando"
infoLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextSize = 12
infoLabel.TextYAlignment = Enum.TextYAlignment.Top
infoLabel.Parent = content

-- ======================================================
--                    FUNCIONES
-- ======================================================

local atmFarming = false
local deliveryFarming = false
local isMinimized = false
local originalSize = panel.Size

local function getCurrentMoney()
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local money = leaderstats:FindFirstChild(CONFIG.MoneyValueName) 
			or leaderstats:FindFirstChild("Cash") 
			or leaderstats:FindFirstChild("Money")
		if money then return money.Value end
	end
	
	local attr = player:GetAttribute(CONFIG.MoneyValueName) 
		or player:GetAttribute("Money") 
		or player:GetAttribute("Cash")
	if attr then return attr end
	
	local data = player:FindFirstChild("Data") or player:FindFirstChild("Stats")
	if data then
		local money = data:FindFirstChild(CONFIG.MoneyValueName) or data:FindFirstChild("Money")
		if money then return money.Value end
	end
	
	return 0
end

local function findPackages()
	local packages = {}
	for _, obj in pairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") or obj:IsA("Model") then
			local name = string.lower(obj.Name)
			for _, packageName in ipairs(CONFIG.PackageNames) do
				if string.find(name, string.lower(packageName)) then
					local part = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")) or obj
					if part then
						table.insert(packages, part)
					end
					break
				end
			end
		end
	end
	return packages
end

local function goToPackage(part)
	if not humanoidRootPart or not humanoidRootPart.Parent then return end
	humanoidRootPart.CFrame = CFrame.new(part.Position + Vector3.new(0, 4, 0))
end

local function doDelivery()
	if not humanoidRootPart or not humanoidRootPart.Parent then return end
	
	humanoidRootPart.CFrame = CFrame.new(CONFIG.DeliveryPosition + Vector3.new(0, 3, 0))
	task.wait(0.5)
	
	local prompt = workspace:FindFirstChild(CONFIG.DeliveryPrompt, true)
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt:InputHoldBegin()
		task.wait(0.2)
		prompt:InputHoldEnd()
	end
	
	local remote = game:GetService("ReplicatedStorage"):FindFirstChild(CONFIG.DeliveryRemote)
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer()
	end
end

local function doATM(position)
	if not humanoidRootPart or not humanoidRootPart.Parent then return end
	humanoidRootPart.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
	task.wait(0.25)
	
	local prompt = workspace:FindFirstChild(CONFIG.ATMPrompt, true)
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt:InputHoldBegin()
		task.wait(0.15)
		prompt:InputHoldEnd()
	end
	
	local remote = game:GetService("ReplicatedStorage"):FindFirstChild(CONFIG.ATMRemote)
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer()
	end
end

local function applyLimit()
	local text = limitBox.Text:gsub("%D", "")
	local number = tonumber(text)
	
	if number and number > 0 then
		CONFIG.MoneyLimit = number
		limitBox.Text = tostring(number)
		infoLabel.Text = "Límite: $" .. CONFIG.MoneyLimit .. "\n\nAl llegar al límite\nentrega y sigue farmeando"
	else
		infoLabel.Text = "Error: escribe un\nnúmero válido"
		limitBox.Text = tostring(CONFIG.MoneyLimit)
	end
end

-- FINALIZAR TODO
local function stopAllFarming()
	atmFarming = false
	deliveryFarming = false
	
	atmBtn.Text = "ATM AutoFarm: OFF"
	atmBtn.BackgroundColor3 = CONFIG.SecondaryColor
	
	deliveryBtn.Text = "Delivery AutoFarm: OFF"
	deliveryBtn.BackgroundColor3 = CONFIG.PrimaryColor
	
	infoLabel.Text = "Farmeo finalizado\n\nTodo detenido"
	print("[Farm] Farmeo finalizado por el usuario")
end

local function toggleDelivery()
	deliveryFarming = not deliveryFarming
	
	if deliveryFarming then
		deliveryBtn.Text = "Delivery AutoFarm: ON"
		deliveryBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
		
		task.spawn(function()
			while deliveryFarming do
				local packages = findPackages()
				
				if #packages == 0 then
					infoLabel.Text = "Buscando paquetes...\nNo se encontraron"
					task.wait(2)
				else
					for _, pack in ipairs(packages) do
						if not deliveryFarming then break end
						if pack and pack.Parent then
							goToPackage(pack)
							infoLabel.Text = "Yendo a paquete...\nEncontrados: " .. #packages
							task.wait(CONFIG.DeliveryWaitTime)
						end
					end
				end
				task.wait(0.4)
			end
		end)
	else
		deliveryBtn.Text = "Delivery AutoFarm: OFF"
		deliveryBtn.BackgroundColor3 = CONFIG.PrimaryColor
	end
end

local function toggleATM()
	atmFarming = not atmFarming
	
	if atmFarming then
		atmBtn.Text = "ATM AutoFarm: ON"
		atmBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
		
		task.spawn(function()
			while atmFarming do
				local currentMoney = getCurrentMoney()
				
				if currentMoney >= CONFIG.MoneyLimit then
					infoLabel.Text = "¡Límite alcanzado!\nEntregando dinero..."
					doDelivery()
					task.wait(1.2)
					infoLabel.Text = "Dinero entregado\nContinuando farm..."
				end
				
				for _, pos in ipairs(CONFIG.ATMPositions) do
					if not atmFarming then break end
					doATM(pos)
					
					local money = getCurrentMoney()
					infoLabel.Text = "Dinero: $" .. money .. "\nLímite: $" .. CONFIG.MoneyLimit
					task.wait(CONFIG.ATMWaitTime)
				end
				
				task.wait(0.3)
			end
		end)
	else
		atmBtn.Text = "ATM AutoFarm: OFF"
		atmBtn.BackgroundColor3 = CONFIG.SecondaryColor
	end
end

local function toggleMinimize()
	isMinimized = not isMinimized
	if isMinimized then
		content.Visible = false
		panel.Size = UDim2.new(0, 175, 0, 38)
		minimizeBtn.Text = "+"
	else
		content.Visible = true
		panel.Size = originalSize
		minimizeBtn.Text = "−"
	end
end

-- Conexiones
deliveryBtn.MouseButton1Click:Connect(toggleDelivery)
atmBtn.MouseButton1Click:Connect(toggleATM)
applyBtn.MouseButton1Click:Connect(applyLimit)
stopBtn.MouseButton1Click:Connect(stopAllFarming)
minimizeBtn.MouseButton1Click:Connect(toggleMinimize)

limitBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		applyLimit()
	end
end)

player.CharacterAdded:Connect(function(newChar)
	character = newChar
	humanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
end)

print("[FarmGui] Cargado")
print("→ Usa el botón rojo 'FINALIZAR FARMEO' para detener todo")
