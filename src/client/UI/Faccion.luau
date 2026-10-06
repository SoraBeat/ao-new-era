--!strict
--[[
	Faccion — la ventana de la Armada Real y la Legión Oscura (P8, docs/36 §10, DF17-10 A). Nuestra: el original solo
	tiene los comandos /ENLISTAR, /INFORMACION, /RECOMPENSA y /RETIRARFACCION, que también andan.

	Se abre con doble click en el Rey o el Demonio. El servidor manda lo que hay que mostrar (evento Faccion: "abrir" o
	"estado") y hace todo: la ventana solo pide (FaccionAccion: "enlistar", "recompensa", "retirar"). El NPC contesta
	con su globo, como en el original.
	  - Si no sos miembro: los requisitos, cada uno con su tilde o su cruz, y el botón Enlistarse.
	  - Si sos miembro: tu título, la barra hacia el próximo rango, lo que vas a recibir, y los botones Pedir
	    recompensa y Retirarse (pide confirmar).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Red.Remotes)
local Boton = require(script.Parent.Boton)
local Dialogo = require(script.Parent.Dialogo)
local Grh = require(script.Parent.Parent.Render.Grh)
local Click = require(script.Parent.Click)
local Encaje = require(script.Parent.Encaje)

local Faccion = {}

local ANCHO = 400
local MARGEN = 18
local COLOR = {
	armada = Color3.fromRGB(130, 150, 255),
	caos = Color3.fromRGB(255, 80, 40),
}
local VERDE, ROJO = Color3.fromRGB(110, 220, 110), Color3.fromRGB(240, 90, 80)
local CLARO = Color3.fromRGB(235, 225, 205)

local gui: ScreenGui? = nil
local evAccion: RemoteEvent? = nil

function Faccion.abierta(): boolean
	return gui ~= nil
end

function Faccion.cerrar()
	if gui then
		gui:Destroy()
		gui = nil
	end
end

local function miles(n: number): string
	local s = tostring(math.floor(n))
	local r = ""
	while #s > 3 do
		r = "." .. string.sub(s, -3) .. r
		s = string.sub(s, 1, -4)
	end
	return s .. r
end

local function accion(nombre: string)
	if evAccion then
		evAccion:FireServer(nombre)
	end
end

local function pintar(d: any)
	Faccion.cerrar()
	local g = Instance.new("ScreenGui")
	g.Name = "Faccion"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = 45
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local caja = Boton.marco(g, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(ANCHO, 100))
	caja.Name = "Ventana"
	caja.AnchorPoint = Vector2.new(0.5, 0.5)
	caja.Active = true

	local y = 14
	local function texto(t: string, alto: number, props: { [string]: any }?): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromOffset(MARGEN, y)
		l.Size = UDim2.fromOffset(ANCHO - 2 * MARGEN, alto)
		l.Font = Enum.Font.Arial
		l.TextSize = 13
		l.TextColor3 = CLARO
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextYAlignment = Enum.TextYAlignment.Top
		l.TextWrapped = true
		l.Text = t
		l.ZIndex = 3
		for k, v in props or {} do
			(l :: any)[k] = v
		end
		l.Parent = caja
		y += alto
		return l
	end

	-- Una línea con su tilde (verde) o su cruz (roja), dibujadas con dos trazos: los símbolos de texto no toman color
	local function requisito(t: string, ok: boolean)
		local c = if ok then VERDE else ROJO
		local m = Instance.new("Frame")
		m.Name = if ok then "Tilde" else "Cruz"
		m.BackgroundTransparency = 1
		m.Position = UDim2.fromOffset(MARGEN, y + 2)
		m.Size = UDim2.fromOffset(14, 14)
		m.ZIndex = 4
		m.Parent = caja
		local trazos = if ok then { { 4, 9, 7, 45 }, { 9, 7, 11, -52 } } else { { 7, 7, 14, 45 }, { 7, 7, 14, -45 } }
		for _, tr in trazos do
			local f = Instance.new("Frame")
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.BackgroundColor3 = c
			f.BorderSizePixel = 0
			f.Position = UDim2.fromOffset(tr[1], tr[2])
			f.Size = UDim2.fromOffset(tr[3], 3)
			f.Rotation = tr[4]
			f.ZIndex = 4
			f.Parent = m
		end
		local l = texto(t, 20, { TextColor3 = c })
		l.Position = UDim2.fromOffset(MARGEN + 22, l.Position.Y.Offset)
		l.Size = UDim2.fromOffset(ANCHO - 2 * MARGEN - 22, 20)
	end

	local color = COLOR[d.bando] or CLARO
	texto(d.titulo, 24, { Font = Enum.Font.ArialBold, TextSize = 19, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Center })
	texto(d.noble, 18, { TextSize = 12, TextColor3 = Boton.ColorTexto, TextXAlignment = Enum.TextXAlignment.Center })
	y += 6

	local botones: { { string } } = {}
	if d.miembro then
		texto(`Tu rango: {d.rangoTitulo}`, 22, { Font = Enum.Font.ArialBold, TextSize = 15, TextColor3 = Color3.new(1, 1, 1) })
		local p = d.proximo
		if p then
			local desde = d.bajasRango or 0
			local frac = math.clamp((d.bajas - desde) / math.max(1, p.bajas - desde), 0, 1)
			texto(`Proximo rango: {p.titulo}`, 20, { TextColor3 = Boton.ColorTexto })
			-- La barra hacia el próximo rango
			local fondo = Instance.new("Frame")
			fondo.BackgroundColor3 = Color3.fromRGB(30, 26, 22)
			fondo.BorderColor3 = Boton.ColorTexto
			fondo.Position = UDim2.fromOffset(MARGEN, y)
			fondo.Size = UDim2.fromOffset(ANCHO - 2 * MARGEN, 16)
			fondo.ZIndex = 3
			fondo.Parent = caja
			local llena = Instance.new("Frame")
			llena.BackgroundColor3 = color
			llena.BorderSizePixel = 0
			llena.Size = UDim2.fromScale(frac, 1)
			llena.ZIndex = 4
			llena.Parent = fondo
			local cuenta = Instance.new("TextLabel")
			cuenta.BackgroundTransparency = 1
			cuenta.Size = UDim2.fromScale(1, 1)
			cuenta.Font = Enum.Font.ArialBold
			cuenta.TextSize = 12
			cuenta.TextColor3 = Color3.new(1, 1, 1)
			cuenta.TextStrokeTransparency = 0.3
			cuenta.Text = `{d.enemigos} matados: {miles(d.bajas)} / {miles(p.bajas)}`
			cuenta.ZIndex = 5
			cuenta.Parent = fondo
			y += 24
			requisito(`Nivel {p.nivel} (tenes {d.nivel})`, d.nivel >= p.nivel)
			y += 4
			texto("Vas a recibir:", 18, { TextColor3 = Boton.ColorTexto })
			texto(`{miles(p.exp)} puntos de experiencia`, 18, {})
			for _, premio in p.premios do
				local icono = Grh.nuevo(caja, premio.grh, 4)
				icono.Position = UDim2.fromOffset(MARGEN, y)
				icono.Size = UDim2.fromOffset(24, 24)
				local l = texto(`{premio.cant} x {premio.nombre}`, 26, { TextYAlignment = Enum.TextYAlignment.Center })
				l.Position = UDim2.fromOffset(MARGEN + 30, l.Position.Y.Offset)
				l.Size = UDim2.fromOffset(ANCHO - 2 * MARGEN - 30, 26)
			end
			table.insert(botones, { "Pedir recompensa", "recompensa" })
		else
			texto("Llegaste al rango mas alto.", 20, { TextColor3 = VERDE })
			texto(`{d.enemigos} matados: {miles(d.bajas)}`, 20, {})
			table.insert(botones, { "Pedir recompensa", "recompensa" })
		end
		table.insert(botones, { "Retirarse", "retirar" })
	elseif d.otra then
		texto("Perteneces a la otra faccion: aqui no eres bienvenido.", 36, { TextColor3 = ROJO })
	else
		-- Fase 26 (docs/46 §3.4): el que no es del bando del noble primero le jura lealtad (cambia su alineación)
		if d.jura then
			local nuevo = if d.jura == "ciudadano" then "ciudadano" else "criminal"
			texto("Jurar lealtad", 20, { Font = Enum.Font.ArialBold, TextColor3 = Boton.ColorTexto })
			texto(if d.juraDesde == "newbie" then `Cuando dejes de ser newbie vas a poder jurar y ser {nuevo}.`
				else `Hoy sos {d.juraDesde}. Si le juras lealtad pasas a ser {nuevo}. Se puede cambiar una vez por hora y fuera de pelea.`, 34, { TextSize = 12 })
			if (d.juraMulta or 0) > 0 then
				texto(`Multa por los ciudadanos que mataste: {miles(d.juraMulta)} monedas de oro.`, 18, { TextSize = 12, TextColor3 = ROJO })
			end
			y += 6
			if d.juraDesde ~= "newbie" then
				table.insert(botones, { "Jurar lealtad", "jurar" })
			end
		end
		texto(if d.jura then "Despues, para entrar a su ejercito" else "Requisitos para enlistarte", 20, { Font = Enum.Font.ArialBold, TextColor3 = Boton.ColorTexto })
		for _, r in d.requisitos or {} do
			requisito(r.texto, r.ok == true)
		end
		y += 4
		if d.vuelve then
			texto(`Ya fuiste miembro: conservas tu rango ({d.rangoTitulo}) y no recibes otra vez lo del ingreso.`, 34, { TextSize = 12 })
		else
			texto("Al entrar recibis las armaduras de la faccion, el cuerno de llamado y experiencia.", 34, { TextSize = 12 })
		end
		if not d.jura then
			table.insert(botones, { "Enlistarse", "enlistar" })
		end
	end
	y += 8

	-- Los botones, en una fila
	table.insert(botones, { "Cerrar", "cerrar" })
	local anchoBoton = math.floor((ANCHO - 2 * MARGEN - (#botones - 1) * 8) / #botones)
	for i, b in botones do
		local boton = Boton.nuevo(caja, b[1], UDim2.fromOffset(MARGEN + (i - 1) * (anchoBoton + 8), y), UDim2.fromOffset(anchoBoton, 30), { tamTexto = 13 })
		boton.Name = b[2]
		boton.ZIndex = 4
		Click.activado(boton, function()
			if b[2] == "cerrar" then
				Faccion.cerrar()
			elseif b[2] == "jurar" then
				task.spawn(function()
					local nuevo = if d.jura == "ciudadano" then "ciudadano" else "criminal"
					local multa = if (d.juraMulta or 0) > 0 then ` Pagas {miles(d.juraMulta)} monedas de oro de multa.` else ""
					if Dialogo.confirmar(`¿Jurar lealtad y pasar a ser {nuevo}?{multa}`, "Jurar") then
						accion("enlistar")
					end
				end)
			elseif b[2] == "retirar" then
				task.spawn(function()
					local si = Dialogo.confirmar(`¿Dejar la {d.titulo}? Conservas el rango, pero volver a entrar gasta uno de tus {d.maxIngresos} ingresos (usaste {d.ingresos}).`, "Retirarse")
					if si then
						accion("retirar")
					end
				end)
			else
				accion(b[2])
			end
		end)
	end
	y += 30 + 14

	caja.Size = UDim2.fromOffset(ANCHO, y)
	Encaje.ventana(caja, ANCHO, y, { techo = 1.3 })
	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = g
end

function Faccion.iniciar()
	evAccion = Remotes.evento("FaccionAccion")
	Remotes.evento("Faccion").OnClientEvent:Connect(function(que: string, d: any)
		if typeof(d) ~= "table" then
			return
		end
		-- "estado" refresca la ventana solo si está abierta
		if que == "abrir" or (que == "estado" and gui ~= nil) then
			pintar(d)
		end
	end)
end

return Faccion
