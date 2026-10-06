--!strict
--[[
	Quests — las dos ventanas de las misiones (Fase 20, docs/39 §2.6), sobre las imágenes del cliente original.

	- La oferta (frmQuestInfo, VentanaQuest.jpg 435 × 376): "Informacion de la mision:", el texto de la quest y los
	  botones Aceptar y Rechazar. La abre el servidor al pedirle una quest a un NPC (QuestEvento "oferta").
	- La lista (frmQuests, VentanaInfoQuest.jpg 557 × 352): "Informacion de misiones:", las quests activas a la izquierda,
	  el detalle de la elegida a la derecha y los botones Abandonar Mision y Salir. La abren /INFOQUEST y el botón
	  Quests del HUD (QuestEvento "lista"); el servidor la refresca sola cuando algo cambia ("refrescar").
	Las posiciones son las de los .frm (en twips, divididas por 15). Ninguna es modal: se sigue jugando con ellas abiertas.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Red.Remotes)
local Cfg = require(ReplicatedStorage.Shared.Config.Quests)
local UiAssets = require(ReplicatedStorage.Shared.Generado.UiAssets) :: any
local Ventana = require(script.Parent.Ventana)
local Boton = require(script.Parent.Boton)
local Dialogo = require(script.Parent.Dialogo)
local Click = require(script.Parent.Click)

local Quests = {}

type Fila = { id: number, nombre: string, texto: string }

local M = Cfg.Msg
local COLOR_ELEGIDA = Color3.fromRGB(60, 80, 140)

local evAccion: RemoteEvent? = nil
local function accion(...: any)
	if evAccion then
		evAccion:FireServer(...)
	end
end

-- Un recuadro de texto con barra (txtInfo): blanco sobre negro, varias líneas
local function cajaTexto(parent: Instance, x: number, y: number, w: number, h: number): TextLabel
	local sf = Instance.new("ScrollingFrame")
	sf.Name = "Info"
	sf.BackgroundColor3 = Color3.new(0, 0, 0)
	sf.BorderSizePixel = 0
	sf.Position = UDim2.fromOffset(x, y)
	sf.Size = UDim2.fromOffset(w, h)
	sf.CanvasSize = UDim2.fromOffset(0, 0)
	sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sf.ScrollBarThickness = 8
	sf.ZIndex = 3
	sf.Parent = parent
	local l = Instance.new("TextLabel")
	l.Name = "Texto"
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(6, 4)
	l.Size = UDim2.new(1, -20, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.Font = Enum.Font.Arial
	l.TextSize = 13
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.TextWrapped = true
	l.RichText = false
	l.Text = ""
	l.ZIndex = 4
	l.Parent = sf
	return l
end

-- ─── La oferta ───────────────────────────────────────────────────────────────
local oferta: ScreenGui? = nil

local function cerrarOferta()
	if oferta then
		oferta:Destroy()
		oferta = nil
	end
end

local function abrirOferta(d: any)
	cerrarOferta()
	local g, fondo = Ventana.crear("QuestOferta", UiAssets.quest, 435, 376)
	oferta = g
	Ventana.label(fondo, M.tituloOferta, 32, 25, 241, 25, { TextSize = 18 })
	local texto = cajaTexto(fondo, 56, 88, 313, 225)
	texto.Text = tostring(d.texto or "")
	local bAceptar = Boton.nuevo(fondo, "Aceptar", UDim2.fromOffset(56, 325), UDim2.fromOffset(113, 41), { tamTexto = 18 })
	bAceptar.ZIndex = 3
	Click.activado(bAceptar, function()
		accion("aceptar")
		cerrarOferta()
	end)
	local bRechazar = Boton.nuevo(fondo, "Rechazar", UDim2.fromOffset(256, 325), UDim2.fromOffset(113, 41), { tamTexto = 18 })
	bRechazar.ZIndex = 3
	Click.activado(bRechazar, function()
		accion("rechazar")
		cerrarOferta()
	end)
end

-- ─── La lista ────────────────────────────────────────────────────────────────
local listaGui: ScreenGui? = nil
local filas: { Fila } = {}
local elegida: number? = nil -- el id de la quest elegida
local pintarLista: (() -> ())? = nil

function Quests.abierta(): boolean
	return listaGui ~= nil or oferta ~= nil
end

local function cerrarLista()
	if listaGui then
		listaGui:Destroy()
		listaGui = nil
	end
	pintarLista = nil
end

function Quests.cerrar()
	cerrarLista()
	cerrarOferta()
end

local function abrirLista()
	cerrarLista()
	local g, fondo = Ventana.crear("QuestLista", UiAssets.questLista, 557, 352)
	listaGui = g
	Ventana.label(fondo, M.tituloLista, 24, 24, 409, 25, { TextSize = 18 })
	local lista = Instance.new("ScrollingFrame")
	lista.Name = "Lista"
	lista.BackgroundColor3 = Color3.new(0, 0, 0)
	lista.BorderSizePixel = 0
	lista.Position = UDim2.fromOffset(12, 61)
	lista.Size = UDim2.fromOffset(157, 171)
	lista.CanvasSize = UDim2.fromOffset(0, 0)
	lista.ScrollBarThickness = 6
	lista.ZIndex = 3
	lista.Parent = fondo
	local texto = cajaTexto(fondo, 176, 60, 361, 269)
	local ALTO_FILA = 18
	local function pintar()
		for _, c in lista:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		-- La elegida sigue siendo la misma quest aunque la lista cambie; si ya no está, la primera
		local hay = false
		for _, f in filas do
			if f.id == elegida then
				hay = true
			end
		end
		if not hay then
			elegida = if filas[1] then filas[1].id else nil
		end
		lista.CanvasSize = UDim2.fromOffset(0, #filas * ALTO_FILA)
		texto.Text = if #filas == 0 then M.ninguna else ""
		for i, f in filas do
			local b = Instance.new("TextButton")
			b.Name = `Quest{f.id}`
			b.AutoButtonColor = false
			b.BackgroundColor3 = COLOR_ELEGIDA
			b.BackgroundTransparency = if f.id == elegida then 0 else 1
			b.BorderSizePixel = 0
			b.Position = UDim2.fromOffset(0, (i - 1) * ALTO_FILA)
			b.Size = UDim2.new(1, 0, 0, ALTO_FILA)
			b.Font = Enum.Font.Arial
			b.TextSize = 12
			b.TextColor3 = Color3.new(1, 1, 1)
			b.TextXAlignment = Enum.TextXAlignment.Left
			b.TextTruncate = Enum.TextTruncate.AtEnd
			b.Text = " " .. f.nombre
			b.ZIndex = 4
			b.Parent = lista
			Click.activado(b, function()
				elegida = f.id
				pintar()
			end)
			if f.id == elegida then
				texto.Text = f.texto
			end
		end
	end
	pintarLista = pintar
	pintar()
	local bAbandonar = Boton.nuevo(fondo, "Abandonar Mision", UDim2.fromOffset(15, 248), UDim2.fromOffset(153, 41), { tamTexto = 16 })
	bAbandonar.ZIndex = 3
	Click.activado(bAbandonar, function()
		local id = elegida
		if #filas == 0 or not id then
			texto.Text = if #filas == 0 then M.ninguna else M.elegir
			return
		end
		task.spawn(function()
			if Dialogo.confirmar(M.confirmar, "Abandonar") then
				accion("abandonar", id)
			end
		end)
	end)
	local bSalir = Boton.nuevo(fondo, "Salir", UDim2.fromOffset(16, 296), UDim2.fromOffset(153, 41), { tamTexto = 18 })
	bSalir.ZIndex = 3
	Click.activado(bSalir, cerrarLista)
end

local function recibir(d: any): { Fila }
	local r: { Fila } = {}
	if typeof(d) == "table" then
		for _, f in d do
			if typeof(f) == "table" and typeof(f.id) == "number" then
				table.insert(r, { id = f.id, nombre = tostring(f.nombre or ""), texto = tostring(f.texto or "") })
			end
		end
	end
	return r
end

function Quests.iniciar()
	evAccion = Remotes.evento("QuestAccion")
	Remotes.evento("QuestEvento").OnClientEvent:Connect(function(que: string, d: any)
		if que == "oferta" and typeof(d) == "table" then
			abrirOferta(d)
		elseif que == "lista" then
			filas = recibir(d)
			abrirLista()
		elseif que == "refrescar" then
			filas = recibir(d)
			local f = pintarLista
			if f then
				f()
			end
		end
	end)
end

return Quests
