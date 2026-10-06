--!strict
--[[
	Carga — la pantalla de carga (docs/26). Corre desde ReplicatedFirst, antes que el resto del cliente:

	1. Tapa todo con negro y espera los módulos generados (UiAssets y Grh) de ReplicatedStorage.
	2. Precarga la imagen de carga, la muestra y saca la pantalla de carga de Roblox. Desde el 2026-10-03 (docs/45
	   §6, pedido del autor) es la portada del dragón. Encima de la imagen, con puntos de color que se mueven y sin
	   imágenes nuevas (Fase 22, docs/41 §4.2): el resplandor de la descarga que late sobre el dragón, las chispas
	   doradas de la curación y motas que flotan en el dungeon.
	3. Precarga las texturas: los atlas de sprites que no se cargan por mapa (Generado/Grh.atlas menos Grh.porMapa) y
	   las imágenes de la interfaz (Generado/UiAssets), con la barra de progreso en el panel de abajo de la imagen.
	   Las de terreno y criaturas las carga client/Render/Texturas por mapa, y la música de cada mapa se carga al
	   tocarla (Fase 17a, docs/35 §1.2, DW17-02 A).
	4. Marca ReplicatedFirst.Precargado = true (Main.client lo espera antes del menú) y se desvanece.

	Las texturas quedan puestas en etiquetas de 1 px, casi transparentes, en la ScreenGui "ReservaTexturas", que
	vive toda la sesión: si una textura no se ve, Roblox puede sacarla de memoria después de precargarla
	(ContentProvider:PreloadAsync, "Limitations"), y la queremos siempre lista.

	Si algo tarda más de EsperaSaltear segundos aparece "Entrar igual"; si algo falla, igual se marca Precargado.
]]

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

local EsperaSaltear = 25 -- segundos hasta ofrecer "Entrar igual"
local ColorTexto = Color3.fromRGB(235, 215, 170)
local ColorBorde = Color3.fromRGB(150, 118, 70)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

-- 1. El negro, antes que nada
local g = Instance.new("ScreenGui")
g.Name = "Carga"
g.IgnoreGuiInset = true
g.ResetOnSpawn = false
g.DisplayOrder = 1000
g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local negro = Instance.new("Frame")
negro.Name = "Negro"
negro.BackgroundColor3 = Color3.new(0, 0, 0)
negro.BorderSizePixel = 0
negro.Size = UDim2.fromScale(1, 1)
negro.Parent = g
g.Parent = playerGui

local listo = false
local function terminar()
	if listo then
		return
	end
	listo = true
	ReplicatedFirst:SetAttribute("Precargado", true)
	-- Main.client arma el menú (o entra al mundo) debajo; después nos desvanecemos
	task.wait(0.4)
	local info = TweenInfo.new(0.5)
	for _, d in g:GetDescendants() do
		if d:IsA("ImageLabel") then
			TweenService:Create(d, info, { ImageTransparency = 1, BackgroundTransparency = 1 }):Play()
		elseif d:IsA("TextLabel") or d:IsA("TextButton") then
			TweenService:Create(d, info, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		elseif d:IsA("Frame") then
			TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
		elseif d:IsA("UIStroke") then
			TweenService:Create(d, info, { Transparency = 1 }):Play()
		end
	end
	task.wait(0.55)
	g:Destroy()
end

local ok, err = pcall(function()
	local Generado = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Generado")
	local UiAssets = require(Generado:WaitForChild("UiAssets")) :: any
	local Grh = require(Generado:WaitForChild("Grh")) :: any

	-- 2. La imagen de carga: de fondo, recortada y oscurecida, llenando la pantalla; encima, entera (16:9)
	local fondo = Instance.new("ImageLabel")
	fondo.Name = "Fondo"
	fondo.BackgroundTransparency = 1
	fondo.Image = UiAssets.carga
	fondo.ScaleType = Enum.ScaleType.Crop
	fondo.ImageColor3 = Color3.fromRGB(70, 60, 50)
	fondo.ImageTransparency = 1
	fondo.Size = UDim2.fromScale(1, 1)
	fondo.Parent = negro
	local lienzo = Instance.new("ImageLabel")
	lienzo.Name = "Imagen"
	lienzo.BackgroundTransparency = 1
	lienzo.Image = UiAssets.carga
	lienzo.ImageTransparency = 1
	lienzo.AnchorPoint = Vector2.new(0.5, 0.5)
	lienzo.Position = UDim2.fromScale(0.5, 0.5)
	lienzo.Size = UDim2.fromScale(1, 1)
	lienzo.Parent = negro
	local aspecto = Instance.new("UIAspectRatioConstraint")
	aspecto.AspectRatio = 16 / 9
	aspecto.AspectType = Enum.AspectType.FitWithinMaxSize
	aspecto.Parent = lienzo

	-- El texto y la barra, abajo a la izquierda (Fase 22, D22-26 A), sobre un fondo oscuro propio: la imagen nueva
	-- no trae cartel dibujado
	local p = UiAssets.panelCarga
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundColor3 = Color3.fromRGB(12, 9, 8)
	panel.BackgroundTransparency = 1
	panel.BorderSizePixel = 0
	panel.Position = UDim2.fromScale(p[1], p[2])
	panel.Size = UDim2.fromScale(p[3] - p[1], p[4] - p[2])
	panel.ZIndex = 3
	panel.Parent = lienzo
	local esquinas = Instance.new("UICorner")
	esquinas.CornerRadius = UDim.new(0.12, 0)
	esquinas.Parent = panel
	local bordePanel = Instance.new("UIStroke")
	bordePanel.Color = ColorBorde
	bordePanel.Thickness = 1
	bordePanel.Transparency = 1
	bordePanel.Parent = panel
	local texto = Instance.new("TextLabel")
	texto.Name = "Texto"
	texto.BackgroundTransparency = 1
	texto.Position = UDim2.fromScale(0.05, 0.1)
	texto.Size = UDim2.fromScale(0.9, 0.36)
	texto.Font = Enum.Font.Fantasy
	texto.TextScaled = true
	texto.TextColor3 = ColorTexto
	texto.TextTransparency = 1
	texto.Text = "Preparando el mundo…"
	texto.Parent = panel
	local barra = Instance.new("Frame")
	barra.Name = "Barra"
	barra.BackgroundColor3 = Color3.fromRGB(20, 14, 10)
	barra.BackgroundTransparency = 1
	barra.BorderSizePixel = 0
	barra.Position = UDim2.fromScale(0.06, 0.58)
	barra.Size = UDim2.fromScale(0.88, 0.2)
	barra.Parent = panel
	local borde = Instance.new("UIStroke")
	borde.Color = ColorBorde
	borde.Thickness = 1.5
	borde.Transparency = 1
	borde.Parent = barra
	local lleno = Instance.new("Frame")
	lleno.Name = "Lleno"
	lleno.BackgroundColor3 = Color3.new(1, 1, 1)
	lleno.BackgroundTransparency = 1
	lleno.BorderSizePixel = 0
	lleno.Size = UDim2.fromScale(0, 1)
	lleno.Parent = barra
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(200, 140, 50), Color3.fromRGB(250, 215, 120))
	grad.Parent = lleno

	ContentProvider:PreloadAsync({ lienzo })
	local aparecer = TweenInfo.new(0.35)
	TweenService:Create(fondo, aparecer, { ImageTransparency = 0 }):Play()
	TweenService:Create(lienzo, aparecer, { ImageTransparency = 0 }):Play()
	TweenService:Create(texto, aparecer, { TextTransparency = 0 }):Play()
	TweenService:Create(barra, aparecer, { BackgroundTransparency = 0.2 }):Play()
	TweenService:Create(borde, aparecer, { Transparency = 0 }):Play()
	TweenService:Create(lleno, aparecer, { BackgroundTransparency = 0 }):Play()
	TweenService:Create(panel, aparecer, { BackgroundTransparency = 0.35 }):Play()
	TweenService:Create(bordePanel, aparecer, { Transparency = 0.4 }):Play()
	ReplicatedFirst:RemoveDefaultLoadingScreen()

	-- La animación (Fase 22, docs/41 §4.2, D22-23 A). Todo va en fracciones de la imagen: la descarga cae sobre el
	-- pecho del dragón (0,617; 0,39), al que curan está en (0,716; 0,58) y el resto es piso de dungeon.
	local escena = Instance.new("Frame")
	escena.Name = "Animacion"
	escena.BackgroundTransparency = 1
	escena.Size = UDim2.fromScale(1, 1)
	escena.ZIndex = 2
	escena.Parent = lienzo
	local azar = Random.new()
	local function punto(color: Color3, lado: number, redondo: boolean): Frame
		local f = Instance.new("Frame")
		f.BackgroundColor3 = color
		f.BackgroundTransparency = 1
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = UDim2.fromOffset(lado, lado)
		f.ZIndex = 2
		f.Parent = escena
		if redondo then
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(1, 0)
			c.Parent = f
		end
		return f
	end
	-- El resplandor de la descarga: discos uno dentro del otro, casi transparentes, que laten juntos y cada tanto
	-- dan un fogonazo (muchos y muy tenues, para que no se les note el borde)
	local discos: { Frame } = {}
	for i = 1, 8 do
		local d = punto(Color3.fromRGB(150, 205, 255), 0, true)
		d.Position = UDim2.fromScale(0.617, 0.39)
		d.Size = UDim2.fromScale(0.03 + i * 0.02, 0.03 + i * 0.02)
		d.SizeConstraint = Enum.SizeConstraint.RelativeXX
		discos[i] = d
	end
	-- Las chispas de la curación: cuadraditos dorados que suben despacio y se apagan
	type Chispa = { f: Frame, x: number, y: number, vx: number, vy: number, vida: number, dura: number }
	local chispas: { Chispa } = {}
	local function nacer(c: Chispa, yaEmpezada: boolean)
		c.x = azar:NextNumber(0.682, 0.752)
		c.y = azar:NextNumber(0.5, 0.64)
		c.vx = azar:NextNumber(-0.006, 0.006)
		c.vy = azar:NextNumber(-0.05, -0.02)
		c.dura = azar:NextNumber(1.4, 2.8)
		c.vida = if yaEmpezada then azar:NextNumber(0, c.dura) else 0
		c.f.BackgroundColor3 = Color3.fromRGB(255, azar:NextInteger(200, 240), azar:NextInteger(90, 160))
	end
	for i = 1, 14 do
		local c: Chispa = { f = punto(Color3.new(1, 1, 1), azar:NextInteger(2, 3), false), x = 0, y = 0, vx = 0, vy = 0, vida = 0, dura = 1 }
		nacer(c, true)
		chispas[i] = c
	end
	-- Las motas: puntos verdosos que flotan despacio por el dungeon y titilan
	type Bicho = { f: Frame, x: number, y: number, fase: number, rx: number, ry: number, vel: number }
	local bichos: { Bicho } = {}
	for i = 1, 14 do
		bichos[i] = {
			f = punto(Color3.fromRGB(190, 230, 140), 3, true),
			x = azar:NextNumber(0.26, 0.97), y = azar:NextNumber(0.06, 0.8),
			fase = azar:NextNumber(0, 6.28), rx = azar:NextNumber(0.01, 0.03), ry = azar:NextNumber(0.006, 0.02),
			vel = azar:NextNumber(0.2, 0.5),
		}
	end
	local tAnim = 0
	local conexionAnim: RBXScriptConnection
	conexionAnim = RunService.RenderStepped:Connect(function(dt: number)
		if listo or not g.Parent then
			conexionAnim:Disconnect() -- al terminar, los puntos se desvanecen con todo lo demás
			return
		end
		dt = math.min(dt, 0.1)
		tAnim += dt
		local entrada = math.clamp(tAnim / 0.6, 0, 1) -- aparecen con la imagen
		local latido = 0.5 + 0.5 * math.sin(tAnim * 2.3) * math.sin(tAnim * 0.9 + 1)
		local fogonazo = math.max(0, math.sin(tAnim * 7.1) * math.sin(tAnim * 1.3)) ^ 6
		for _, d in discos do
			d.BackgroundTransparency = 1 - entrada * (0.018 + 0.014 * latido + 0.03 * fogonazo)
		end
		for _, c in chispas do
			c.vida += dt
			if c.vida >= c.dura then
				nacer(c, false)
			end
			c.x += (c.vx + 0.004 * math.sin(tAnim * 3 + c.dura * 7)) * dt
			c.y += c.vy * dt
			local k = c.vida / c.dura
			c.f.Position = UDim2.fromScale(c.x, c.y)
			c.f.BackgroundTransparency = 1 - entrada * (if k < 0.15 then k / 0.15 else 1 - (k - 0.15) / 0.85) * 0.9
		end
		for _, b in bichos do
			local a = tAnim * b.vel + b.fase
			b.f.Position = UDim2.fromScale(b.x + b.rx * math.sin(a) + 0.01 * math.sin(a * 0.37), b.y + b.ry * math.sin(a * 1.7))
			b.f.BackgroundTransparency = 1 - entrada * (0.1 + 0.45 * math.max(0, math.sin(a * 2.1 + b.fase)))
		end
	end)

	if not game:IsLoaded() then
		game.Loaded:Wait()
	end

	-- El himno (6.mp3, cli/General.bas:843; docs/29 §4): suena desde la carga y sigue en el menú. client/Audio/Musica
	-- lo adopta por el nombre (AOMusica) y el número.
	local Sonidos = require(Generado:WaitForChild("Sonidos")) :: any
	local himno = Sonidos.musica[Sonidos.menu.carga]
	if himno and himno ~= "" and not SoundService:FindFirstChild("AOMusica") then
		local s = Instance.new("Sound")
		s.Name = "AOMusica"
		s.SoundId = himno
		s.Looped = true
		s.Volume = 0.5
		s:SetAttribute("Numero", Sonidos.menu.carga)
		s.Parent = SoundService
		s:Play()
	end

	-- 3. Todas las texturas: la interfaz primero (el menú es lo próximo que se ve), después los atlas
	local ids: { string } = {}
	local vistos: { [string]: boolean } = {}
	local function sumar(id: any)
		if type(id) == "string" and string.find(id, "^rbxassetid://%d+$") and not string.find(id, "//0$")
			and not vistos[id] then
			vistos[id] = true
			table.insert(ids, id)
		end
	end
	sumar(UiAssets.menu)
	for _, v in UiAssets do
		sumar(v)
	end
	for i = 1, #Grh.atlas do
		if not (Grh.porMapa and Grh.porMapa[i]) then
			sumar(Grh.atlas[i])
		end
	end

	local reserva = Instance.new("ScreenGui")
	reserva.Name = "ReservaTexturas"
	reserva.ResetOnSpawn = false
	reserva.DisplayOrder = -1000
	local etiquetas = {}
	for i, id in ids do
		local l = Instance.new("ImageLabel")
		l.Name = tostring(i)
		l.BackgroundTransparency = 1
		l.BorderSizePixel = 0
		l.Size = UDim2.fromOffset(1, 1)
		l.ImageTransparency = 0.98
		l.Image = id
		l.Parent = reserva
		etiquetas[i] = l
	end
	reserva.Parent = playerGui
	-- Los audios también (docs/29 §3.1): el de efectos y las músicas del menú, así el primer sonido no tarda (las
	-- de los mapas, al entrar a cada uno: docs/35 §1.2)
	local audios = { Sonidos.efectos }
	for _, n in Sonidos.menu do
		table.insert(audios, Sonidos.musica[n])
	end
	for _, id in audios do
		if type(id) == "string" and string.find(id, "^rbxassetid://%d+$") then
			local s = Instance.new("Sound")
			s.SoundId = id
			table.insert(etiquetas, s :: any)
		end
	end

	local total, hechos, fallas = #etiquetas, 0, 0
	local function mostrar()
		texto.Text = if hechos < total then `Cargando gráficos… {hechos} de {total}` else "¡Listo!"
		TweenService:Create(lleno, TweenInfo.new(0.2), { Size = UDim2.fromScale(hechos / math.max(total, 1), 1) }):Play()
	end
	mostrar()

	-- Si tarda demasiado, se puede entrar igual (la precarga sigue de fondo)
	task.delay(EsperaSaltear, function()
		if listo then
			return
		end
		local b = Instance.new("TextButton")
		b.Name = "EntrarIgual"
		b.BackgroundColor3 = Color3.fromRGB(30, 22, 16)
		b.AutoButtonColor = true
		b.AnchorPoint = Vector2.new(0.5, 0)
		b.AnchorPoint = Vector2.new(0.5, 1)
		b.Position = UDim2.fromScale(0.5, -0.12) -- arriba del panel (que ahora va al pie de la imagen)
		b.Size = UDim2.fromScale(0.4, 0.4)
		b.Font = Enum.Font.Fantasy
		b.TextScaled = true
		b.TextColor3 = ColorTexto
		b.Text = "Entrar igual"
		b.Parent = panel
		local s = Instance.new("UIStroke")
		s.Color = ColorBorde
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = b
		b.Activated:Connect(function()
			task.spawn(terminar)
		end)
		-- El puntero del mando (Fase 34, docs/54 §4): este guion corre antes que el cliente y no puede anotar el botón
		-- en UI/Click; el puntero dispara este evento
		local alClick = Instance.new("BindableEvent")
		alClick.Name = "AlClick"
		alClick.Event:Connect(function()
			task.spawn(terminar)
		end)
		alClick.Parent = b
	end)

	local t0 = os.clock()
	ContentProvider:PreloadAsync(etiquetas, function(id: string, estado: Enum.AssetFetchStatus)
		hechos += 1
		if estado ~= Enum.AssetFetchStatus.Success then
			fallas += 1
			warn(`[Carga] no se pudo cargar {id}: {estado.Name}`)
		end
		mostrar()
	end)
	hechos = total
	mostrar()
	print(string.format("[Carga] %d texturas y audios en %.1f s (%d fallas)", total, os.clock() - t0, fallas))
end)

if not ok then
	warn("[Carga] " .. tostring(err))
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end
terminar()
