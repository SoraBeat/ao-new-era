--!strict
--[[
	Mascotas — la ventana de las mascotas (Fase 16c, docs/33 §6, DM16-06 A). Nuestra: el original solo tiene los
	comandos /QUIETO, /ACOMPANAR y /LIBERAR con la mascota clickeada.

	Aparece sola cuando el personaje tiene alguna mascota, arriba a la izquierda de la vista (la monta HudPC o
	HudTactil). Una fila por mascota: el nombre, la vida y, las invocadas, los segundos que les quedan; las que esperan
	afuera, en gris. Al tocar una fila, Quieto / Acompañar / Liberar (pide confirmar). "–" la minimiza.
	El servidor manda la lista con el evento Mascotas (al cambiar y cada segundo mientras haya mascotas).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Red.Remotes)
local Boton = require(script.Parent.Boton)
local Dialogo = require(script.Parent.Dialogo)
local Click = require(script.Parent.Click)

local Mascotas = {}

type Fila = { slot: number, nombre: string, hp: number, maxHp: number, invocada: boolean, restante: number?, esperando: boolean, quieta: boolean }

local ANCHO = 196
local FILA = 30
local TITULO = 22
local BOTONES = 30

local lista: { Fila } = {}
local seleccionado: number? = nil
local minimizada = false
local panel: ImageLabel? = nil
local evOrden: RemoteEvent? = nil
-- Lo que cambia cada segundo (vida, tiempo) se actualiza sin rearmar la ventana: así no se pierde un toque
local claveArmada = ""
local refs: { [number]: { estado: TextLabel, llena: Frame, nombre: TextLabel } } = {}

local function textoEstado(f: Fila): string
	return if f.esperando then "Te espera afuera"
		elseif f.restante then `{f.restante} s`
		elseif f.quieta then "Quieta"
		else ""
end

local function clave(): string
	local partes = { tostring(seleccionado), tostring(minimizada) }
	for _, f in lista do
		table.insert(partes, `{f.slot}:{f.esperando}`)
	end
	return table.concat(partes, ",")
end

local function label(parent: Instance, texto: string, pos: UDim2, tam: UDim2, props: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = tam
	l.Font = Enum.Font.ArialBold
	l.TextSize = 12
	l.TextColor3 = Boton.ColorTexto
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Text = texto
	l.ZIndex = 3
	if props then
		for k, v in props do
			(l :: any)[k] = v
		end
	end
	l.Parent = parent
	return l
end

local function ordenar(accion: string)
	local s = seleccionado
	if not s or not evOrden then
		return
	end
	if accion == "liberar" then
		local nombre = "tu mascota"
		for _, f in lista do
			if f.slot == s then
				nombre = f.nombre
			end
		end
		task.spawn(function()
			local si = Dialogo.confirmar(`¿Liberar a {nombre}? Desaparecerá para siempre.`, "Liberar")
			if si and evOrden then
				evOrden:FireServer(s, "liberar")
			end
		end)
		return
	end
	evOrden:FireServer(s, accion)
end

local function pintar(forzar: boolean?)
	local p = panel
	if not p then
		return
	end
	local k = clave()
	if not forzar and k == claveArmada and #lista > 0 then
		for _, f in lista do
			local r = refs[f.slot]
			if r then
				r.estado.Text = textoEstado(f)
				r.llena.Size = UDim2.fromScale(if f.maxHp > 0 then math.clamp(f.hp / f.maxHp, 0, 1) else 0, 1)
			end
		end
		return
	end
	claveArmada = k
	table.clear(refs)
	for _, c in p:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	p.Visible = #lista > 0
	if #lista == 0 then
		seleccionado = nil
		return
	end
	local hay = false
	for _, f in lista do
		if f.slot == seleccionado then
			hay = true
		end
	end
	if not hay then
		seleccionado = nil
	end
	label(p, "Mascotas", UDim2.fromOffset(8, 4), UDim2.new(1, -40, 0, 16), { TextSize = 13 })
	local mini = Instance.new("TextButton")
	mini.Name = "Minimizar"
	mini.BackgroundTransparency = 1
	mini.Position = UDim2.new(1, -26, 0, 2)
	mini.Size = UDim2.fromOffset(22, 18)
	mini.Font = Enum.Font.ArialBold
	mini.TextSize = 16
	mini.TextColor3 = Boton.ColorTexto
	mini.Text = if minimizada then "+" else "–"
	mini.ZIndex = 3
	mini.Parent = p
	Click.activado(mini, function()
		minimizada = not minimizada
		pintar()
	end)
	if minimizada then
		p.Size = UDim2.fromOffset(ANCHO, TITULO + 4)
		return
	end
	local y = TITULO
	for _, f in lista do
		local fila = Instance.new("TextButton")
		fila.Name = "Fila" .. f.slot
		fila.AutoButtonColor = false
		fila.Text = ""
		fila.BackgroundColor3 = Color3.fromRGB(0, 0, 128)
		fila.BackgroundTransparency = if f.slot == seleccionado then 0.3 else 1
		fila.BorderSizePixel = 0
		fila.Position = UDim2.fromOffset(4, y)
		fila.Size = UDim2.new(1, -8, 0, FILA - 2)
		fila.ZIndex = 2
		fila.Parent = p
		Click.activado(fila, function()
			seleccionado = if seleccionado == f.slot then nil else f.slot
			pintar()
		end)
		local gris = f.esperando
		local color = if gris then Color3.fromRGB(140, 140, 140) else Boton.ColorTexto
		local nombre = label(fila, f.nombre, UDim2.fromOffset(4, 1), UDim2.new(1, -90, 0, 14), { TextColor3 = color })
		local est = label(fila, textoEstado(f), UDim2.new(1, -90, 0, 1), UDim2.fromOffset(86, 14), { TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.Arial })
		local barra = Instance.new("Frame")
		barra.BackgroundColor3 = Color3.fromRGB(40, 0, 0)
		barra.BorderSizePixel = 0
		barra.Position = UDim2.fromOffset(4, 18)
		barra.Size = UDim2.new(1, -8, 0, 6)
		barra.ZIndex = 3
		barra.Parent = fila
		local llena = Instance.new("Frame")
		llena.BackgroundColor3 = if gris then Color3.fromRGB(110, 110, 110) else Color3.fromRGB(200, 30, 30)
		llena.BorderSizePixel = 0
		llena.Size = UDim2.fromScale(if f.maxHp > 0 then math.clamp(f.hp / f.maxHp, 0, 1) else 0, 1)
		llena.ZIndex = 4
		llena.Parent = barra
		refs[f.slot] = { estado = est, llena = llena, nombre = nombre }
		y += FILA
	end
	if seleccionado then
		local ancho = (ANCHO - 16) / 3
		for i, par in { { "Quieto", "quieto" }, { "Acompañar", "acompanar" }, { "Liberar", "liberar" } } do
			local b = Boton.nuevo(p, par[1], UDim2.fromOffset(4 + (i - 1) * (ancho + 4), y + 2), UDim2.fromOffset(ancho, BOTONES - 4), { tamTexto = 11 })
			b.Name = par[1]
			b.ZIndex = 3
			local accion = par[2]
			Click.activado(b, function()
				ordenar(accion)
			end)
		end
		y += BOTONES
	end
	p.Size = UDim2.fromOffset(ANCHO, y + 6)
end

-- Monta la ventana en un contenedor del HUD (el de la PC o el del celular); la anterior, si había, se va
function Mascotas.montar(parent: Instance, pos: UDim2, escala: number?)
	if panel then
		panel:Destroy()
	end
	local p = Boton.marco(parent, pos, UDim2.fromOffset(ANCHO, TITULO))
	p.Name = "Mascotas"
	p.ZIndex = 1
	p.Visible = false
	if escala and escala ~= 1 then
		local u = Instance.new("UIScale")
		u.Scale = escala
		u.Parent = p
	end
	panel = p
	pintar(true)
end

function Mascotas.iniciar()
	evOrden = Remotes.evento("OrdenMascota")
	Remotes.evento("Mascotas").OnClientEvent:Connect(function(l: any)
		lista = if typeof(l) == "table" then l else {}
		pintar()
	end)
end

function Mascotas.lista(): { Fila }
	return lista
end

-- Sin mascotas (Fase 25, docs/44 §9: al volver a la pantalla de personajes; el personaje siguiente manda las suyas)
function Mascotas.limpiar()
	lista = {}
	pintar()
end

return Mascotas
