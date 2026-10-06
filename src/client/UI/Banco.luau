--!strict
--[[
	Banco — la bóveda (frmBancoObj, Boveda.jpg 462×532; docs/22 §6).

	- Izquierda, la bóveda (40 casillas); derecha, tu inventario (25). "<" deposita lo seleccionado del inventario y
	  ">" retira lo seleccionado de la bóveda, con la cantidad del medio. Shift+click en una casilla deposita o retira
	  todo; el botón "Todo" hace lo mismo con la selección (nuestro, para el celular).
	- Arriba: la bolsa de la izquierda deposita el oro escrito, la de la derecha lo retira; el oro de la cuenta
	  al medio. El banquero contesta con el globo ("Tenes N monedas de oro en tu cuenta.").
	El servidor la abre ("abrir") y la cierra al alejarse, morir o cambiar de mapa ("cerrar").
	Fase 20 (docs/39 §3.5): la misma ventana sirve para el baúl de la casa alquilada ("abrir" con baul = true y lugares):
	menos casillas y sin la parte del oro, que queda tapada con el título.
	Fase 31 (pedido del autor): el botón "Mover" (arriba, entre las dos grillas) ordena la bóveda o el baúl, en PC y en
	el celular: se elige un objeto de la izquierda, se toca "Mover" (queda resaltado y el recuadro de abajo dice qué
	tocar) y después el casillero de la izquierda adonde va, vacío u ocupado: el servidor intercambia los dos
	(MoverBanco). Tocar "Mover" otra vez, el mismo casillero, uno del inventario o cerrar la ventana lo cancela.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Comercio)
local ConfigInv = require(ReplicatedStorage.Shared.Config.Inventario)
local Objetos = require(ReplicatedStorage.Shared.Generado.ObjetosInventario) :: any
local UiAssets = require(ReplicatedStorage.Shared.Generado.UiAssets) :: any
local Remotes = require(ReplicatedStorage.Shared.Red.Remotes)
local Boton = require(script.Parent.Boton)
local Ventana = require(script.Parent.Ventana)
local GrillaItems = require(script.Parent.GrillaItems)
local Inventario = require(script.Parent.Inventario)

local Sonido = require(script.Parent.Parent.Audio.Sonido)
local Click = require(script.Parent.Click)
local Banco = {}

-- Fase 31: el modo "Mover". Los textos van en el recuadro del nombre, en este color
local MSG_MOVER_DESTINO = "Tocá a la izquierda el lugar adonde va."
local MSG_MOVER_ELEGIR = "Primero elegí un objeto de la izquierda."
local COLOR_MOVER = Color3.fromRGB(255, 220, 80)

-- Lo pone Main: el oro de la billetera (de las estadísticas)
Banco.oro = function(): number
	return 0
end

type Estado = {
	gui: ScreenGui,
	boveda: GrillaItems.Grilla,
	yo: GrillaItems.Grilla,
	lado: string?,
	oroBanco: number,
	lblOro: TextLabel,
	nombre: TextLabel,
	cantidad: Ventana.Campo,
	cantOro: Ventana.Campo,
	-- Fase 31: el modo "Mover"
	moviendo: number, -- el casillero de la bóveda que se está por mover (0 = el modo está apagado)
	seguir: number, -- el casillero adonde se pidió mover: cuando el servidor lo confirma queda seleccionado (0 = nada)
	aviso: string?, -- "Primero elegí un objeto…": se va con el toque siguiente
	resalte: UIStroke, -- el borde del botón "Mover" mientras el modo está armado
}
local v: Estado? = nil

function Banco.abierta(): boolean
	return v ~= nil
end

local function misItems(): { [number]: GrillaItems.Item }
	local t = {}
	for slot, d in Inventario.slots() do
		if slot <= Inventario.usables() then -- Fase 16b: con la mochila, 30 o 35
			t[slot] = d
		end
	end
	return t
end

local function mostrar()
	local e = v
	if not e then
		return
	end
	local g = if e.lado == "boveda" then e.boveda elseif e.lado == "yo" then e.yo else nil
	local it: any = nil
	if g then
		it = select(2, g:seleccionado())
	end
	local o = it and Objetos[it.obj]
	-- Fase 31: con el modo "Mover" armado (o un aviso suyo), el recuadro dice qué tocar en vez del nombre
	local ayuda = if e.moviendo > 0 then MSG_MOVER_DESTINO else e.aviso
	e.nombre.Text = if ayuda then ayuda elseif o then Inventario.nombre(it :: any) else ""
	e.nombre.TextColor3 = if ayuda then COLOR_MOVER else Color3.new(1, 1, 1)
	e.resalte.Enabled = e.moviendo > 0
	e.lblOro.Text = tostring(e.oroBanco)
end

function Banco.cerrar(avisarServidor: boolean?)
	local e = v
	if not e then
		return
	end
	v = nil
	e.gui:Destroy()
	if avisarServidor then
		Remotes.evento("CerrarBanco"):FireServer()
	end
end

local function depositar(slot: number, cant: number)
	if slot > 0 then
		Remotes.evento("Depositar"):FireServer(slot, cant)
	end
end

local function retirar(slot: number, cant: number)
	if slot > 0 then
		Remotes.evento("Retirar"):FireServer(slot, cant)
	end
end

local function abrir(d: any)
	Banco.cerrar(false)
	local gui, fondo = Ventana.crear("Banco", UiAssets.banco, 462, 532)
	local esBaul = d.baul == true
	local lugares = if esBaul then tonumber(d.lugares) or Config.SlotsBaul else Config.SlotsBanco
	local marcoB = Instance.new("Frame")
	marcoB.Name = "Boveda"
	marcoB.BackgroundTransparency = 1
	marcoB.Position = UDim2.fromOffset(36, 160)
	marcoB.Size = UDim2.fromOffset(160, 256)
	marcoB.Parent = fondo
	local marcoYo = marcoB:Clone()
	marcoYo.Name = "Yo"
	marcoYo.Position = UDim2.fromOffset(268, 160)
	marcoYo.Parent = fondo
	-- Fase 31: "Mover", arriba en la columna del medio (lo de abajo es de la cantidad)
	local mover = Boton.nuevo(fondo, "Mover", UDim2.fromOffset(204, 176), UDim2.fromOffset(56, 30), { tamTexto = 13 })
	mover.Name = "Mover"
	local resalte = Instance.new("UIStroke")
	resalte.Name = "Resalte"
	resalte.Color = COLOR_MOVER
	resalte.Thickness = 2
	resalte.Enabled = false
	resalte.Parent = mover
	local e: Estado = {
		gui = gui,
		boveda = GrillaItems.nueva(marcoB, Config.SlotsBanco, 5, 32),
		yo = GrillaItems.nueva(marcoYo, ConfigInv.Slots, 5, 32),
		lado = nil,
		oroBanco = d.oro or 0,
		lblOro = Ventana.label(fondo, "", 226, 66, 88, 18, { TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(255, 255, 0) }),
		nombre = Ventana.label(fondo, "", 150, 438, 174, 56, { TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.Arial }),
		cantidad = nil :: any,
		cantOro = nil :: any,
		moviendo = 0,
		seguir = 0,
		aviso = nil,
		resalte = resalte,
	}
	v = e
	local items = {}
	for k, s in d.slots or {} do
		items[tonumber(k) :: number] = s
	end
	e.boveda:set(items)
	for slot, c in e.boveda.celdas do
		c.boton.Visible = slot <= lugares -- el baúl tiene menos casillas que la bóveda
	end
	for slot, c in e.yo.celdas do
		c.boton.Visible = slot <= Inventario.usables() -- Fase 16b: con la mochila, 30 o 35
	end
	e.yo:set(misItems())

	-- Cantidad de objetos, al medio entre las flechas; los −, + y Máx van abajo (no entran al lado)
	e.cantidad = Ventana.cantidad(fondo, 213, 262, 38, 19, Config.MaxCantidad, function(): number
		local g = if e.lado == "boveda" then e.boveda elseif e.lado == "yo" then e.yo else nil
		local it: any = nil
		if g then
			it = select(2, g:seleccionado())
		end
		return if it then it.cant else 1
	end, { botones = false })
	local menos = Boton.nuevo(fondo, "−", UDim2.fromOffset(200, 352), UDim2.fromOffset(28, 24), { tamTexto = 14 })
	local mas = Boton.nuevo(fondo, "+", UDim2.fromOffset(236, 352), UDim2.fromOffset(28, 24), { tamTexto = 14 })
	local todo = Boton.nuevo(fondo, "Todo", UDim2.fromOffset(204, 382), UDim2.fromOffset(56, 24), { tamTexto = 12 })
	menos.Name, mas.Name, todo.Name = "Menos", "Mas", "Todo"
	Click.activado(menos, function()
		e.cantidad.set(e.cantidad.valor() - 1)
	end)
	Click.activado(mas, function()
		e.cantidad.set(e.cantidad.valor() + 1)
	end)
	-- "Todo": deposita o retira toda la pila seleccionada (como Shift+click)
	Click.activado(todo, function()
		if e.lado == "yo" then
			local slot, it = e.yo:seleccionado()
			if it then
				depositar(slot, it.cant)
			end
		elseif e.lado == "boveda" then
			local slot, it = e.boveda:seleccionado()
			if it then
				retirar(slot, it.cant)
			end
		end
	end)

	-- Flechas (el dibujo está en la imagen): "<" deposita, ">" retira
	local izq = Ventana.cerrar(fondo, 218, 226, 28, 28, function()
		local slot = e.yo:seleccionado()
		depositar(slot, e.cantidad.valor())
	end)
	izq.Name = "Depositar"
	local der = Ventana.cerrar(fondo, 218, 290, 28, 28, function()
		local slot = e.boveda:seleccionado()
		retirar(slot, e.cantidad.valor())
	end)
	der.Name = "Retirar"

	if esBaul then
		-- El baúl no guarda oro: la franja de las bolsas queda tapada con el título
		e.lblOro.Visible = false
		local tapa = Boton.marco(fondo, UDim2.fromOffset(84, 52), UDim2.fromOffset(300, 78))
		tapa.Name = "TituloBaul"
		tapa.ZIndex = 4
		Ventana.label(tapa, "Baul de tu casa", 0, 16, 300, 24, { TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5 })
		Ventana.label(tapa, `{lugares} lugares. Se guarda con tu personaje.`, 0, 42, 300, 18, {
			TextSize = 12, Font = Enum.Font.Arial, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5,
		})
	else
		-- Oro: la cantidad en el recuadro del medio, las bolsas a los lados
		e.cantOro = Ventana.cantidad(fondo, 235, 94, 70, 20, Config.MaxOro, function(): number
			return Banco.oro()
		end, { botones = false })
		local depOro = Ventana.cerrar(fondo, 96, 64, 64, 50, function()
			Remotes.evento("DepositarOro"):FireServer(e.cantOro.valor())
		end)
		depOro.Name = "DepositarOro"
		local retOro = Ventana.cerrar(fondo, 312, 60, 64, 54, function()
			Remotes.evento("RetirarOro"):FireServer(e.cantOro.valor())
		end)
		retOro.Name = "RetirarOro"
		local todoOro = Boton.nuevo(fondo, "Todo", UDim2.fromOffset(170, 94), UDim2.fromOffset(56, 20), { tamTexto = 11 })
		todoOro.Name = "TodoOro"
		Click.activado(todoOro, function()
			e.cantOro.set(math.max(1, Banco.oro()))
		end)
	end

	-- Fase 31: "Mover" arma el modo con lo seleccionado de la bóveda; tocarlo de nuevo lo cancela
	Click.activado(mover, function()
		if e.moviendo > 0 then
			e.moviendo = 0
		else
			local slot, it = e.boveda:seleccionado()
			if it then
				e.moviendo = slot
				e.aviso = nil
			else
				e.aviso = MSG_MOVER_ELEGIR -- nada elegido, o lo elegido es del inventario
			end
		end
		mostrar()
	end)
	-- Con el modo armado, el toque en un casillero de la bóveda es el destino: no selecciona ni retira (Shift). El
	-- mismo casillero lo cancela. La selección se pasa al destino cuando llega la respuesta del servidor ("slot").
	e.boveda.alTocar = function(slot: number): boolean
		local desde = e.moviendo
		if desde == 0 then
			return false
		end
		e.moviendo = 0
		if slot ~= desde and slot >= 1 and slot <= lugares and e.boveda.items[desde] then
			Remotes.evento("MoverBanco"):FireServer(desde, slot)
			e.seguir = slot
		end
		mostrar()
		return true
	end

	-- Click (Shift+click deposita o retira todo)
	e.boveda.alSeleccionar = function(slot, it, shift)
		e.lado = "boveda"
		e.yo:seleccionar(0)
		e.seguir, e.aviso = 0, nil
		if shift and it then
			retirar(slot, it.cant)
		end
		mostrar()
	end
	e.yo.alSeleccionar = function(slot, it, shift)
		e.lado = "yo"
		e.boveda:seleccionar(0)
		e.moviendo, e.seguir, e.aviso = 0, 0, nil -- tocar el inventario cancela el modo "Mover"
		if shift and it then
			depositar(slot, it.cant)
		end
		mostrar()
	end
	Ventana.cerrar(fondo, 405, 24, 30, 30, function()
		Banco.cerrar(true)
	end)
	mostrar()
end

function Banco.iniciar()
	Inventario.alCambiarInventario(function()
		local e = v
		if e then
			e.yo:set(misItems())
			mostrar()
		end
	end)
	Remotes.evento("Banco").OnClientEvent:Connect(function(accion: string, a: any, b: any)
		if accion == "abrir" then
			if not (typeof(a) == "table" and a.baul) then
				Sonido.saludo("banquero") -- cli/Red/Protocol.bas:1755
			end
			abrir(a)
		elseif accion == "cerrar" then
			Banco.cerrar(false)
		elseif accion == "slot" then
			local e = v
			if e then
				local t = table.clone(e.boveda.items)
				t[a] = b
				e.boveda:set(t)
				-- Fase 31: lo que se movió queda seleccionado en su lugar nuevo (como al arrastrar en el inventario)
				if e.seguir ~= 0 and e.seguir == a then
					e.seguir = 0
					if b then
						e.boveda:seleccionar(a)
						e.yo:seleccionar(0)
						e.lado = "boveda"
					end
				end
				-- y si lo que se estaba por mover ya no está (se retiró entero), el modo se apaga
				if e.moviendo > 0 and not e.boveda.items[e.moviendo] then
					e.moviendo = 0
				end
				mostrar()
			end
		elseif accion == "oro" then
			local e = v
			if e then
				e.oroBanco = a
				mostrar()
			end
		end
	end)
end

return Banco
