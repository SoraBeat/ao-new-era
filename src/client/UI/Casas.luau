--!strict
--[[
	Casas — la ventana de propiedades (Fase 20, docs/39 §3.4). Nuestra: en el original el vendedor de propiedades es un
	comerciante que vende llaves.

	Se abre con doble click sobre el vendedor de propiedades de la ciudad (o /CASAS con él clickeado): el servidor manda
	las casas que alquila (CasaEvento "abrir" y "refrescar"). Usa el marco de la lista de quests (VentanaInfoQuest.jpg,
	557 × 352), que tiene la misma forma: a la izquierda las casas (en verde las libres, en dorado la tuya, en gris las
	ocupadas); a la derecha el detalle de la elegida; abajo, Alquilar o Renovar, y Salir. "Dejar la casa", sobre el
	detalle, cuando es la tuya. Todo pide confirmación; el servidor hace el resto (CasaAccion).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Red.Remotes)
local Cfg = require(ReplicatedStorage.Shared.Config.Casas)
local ConfigComercio = require(ReplicatedStorage.Shared.Config.Comercio)
local UiAssets = require(ReplicatedStorage.Shared.Generado.UiAssets) :: any
local Ventana = require(script.Parent.Ventana)
local Boton = require(script.Parent.Boton)
local Dialogo = require(script.Parent.Dialogo)
local Click = require(script.Parent.Click)

local Casas = {}

type Fila = { id: string, nombre: string, numero: number, tiles: number, estado: string, inquilino: string?, vence: number? }

local VERDE = Color3.fromRGB(130, 225, 130)
local DORADO = Color3.fromRGB(255, 215, 110)
local GRIS = Color3.fromRGB(150, 150, 150)
local COLOR_ELEGIDA = Color3.fromRGB(60, 80, 140)

local gui: ScreenGui? = nil
local datos: any = nil
local elegida: string? = nil
local pintar: (() -> ())? = nil
local evAccion: RemoteEvent? = nil

local function accion(...: any)
	if evAccion then
		evAccion:FireServer(...)
	end
end

function Casas.abierta(): boolean
	return gui ~= nil
end

function Casas.cerrar()
	if gui then
		gui:Destroy()
		gui = nil
		accion("cerrar")
	end
	pintar = nil
end

local function mayuscula(s: string): string
	return string.upper(string.sub(s, 1, 1)) .. string.sub(s, 2)
end

local function etiqueta(f: Fila): string
	return if f.numero == 0 then "La Mansion" else `Casa {f.numero}`
end

local function abrir()
	if gui then
		gui:Destroy()
	end
	local g, fondo = Ventana.crear("Casas", UiAssets.questLista, 557, 352)
	gui = g
	local titulo = Ventana.label(fondo, "", 24, 24, 500, 25, { TextSize = 18 })
	local lista = Instance.new("ScrollingFrame")
	lista.Name = "Lista"
	lista.BackgroundColor3 = Color3.new(0, 0, 0)
	lista.BorderSizePixel = 0
	lista.Position = UDim2.fromOffset(12, 61)
	lista.Size = UDim2.fromOffset(157, 171)
	lista.ScrollBarThickness = 6
	lista.ZIndex = 3
	lista.Parent = fondo
	local caja = Instance.new("Frame")
	caja.Name = "Info"
	caja.BackgroundColor3 = Color3.new(0, 0, 0)
	caja.BorderSizePixel = 0
	caja.Position = UDim2.fromOffset(176, 60)
	caja.Size = UDim2.fromOffset(361, 269)
	caja.ZIndex = 3
	caja.Parent = fondo
	local texto = Ventana.label(caja, "", 8, 6, 345, 210, {
		Name = "Texto", Font = Enum.Font.Arial, TextSize = 14, TextWrapped = true, TextTruncate = Enum.TextTruncate.None,
		TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 4,
	})
	local bPrincipal = Boton.nuevo(fondo, "Alquilar", UDim2.fromOffset(15, 248), UDim2.fromOffset(153, 41), { tamTexto = 18 })
	bPrincipal.Name = "Principal"
	bPrincipal.ZIndex = 3
	local bSalir = Boton.nuevo(fondo, "Salir", UDim2.fromOffset(16, 296), UDim2.fromOffset(153, 41), { tamTexto = 18 })
	bSalir.ZIndex = 3
	Click.activado(bSalir, Casas.cerrar)
	local bDejar = Boton.nuevo(caja, "Dejar la casa", UDim2.fromOffset(211, 229), UDim2.fromOffset(140, 30), { tamTexto = 14 })
	bDejar.Name = "Dejar"
	bDejar.ZIndex = 5
	local ALTO_FILA = 18

	local function filaElegida(): Fila?
		for _, f in datos.casas do
			if f.id == elegida then
				return f
			end
		end
		return nil
	end

	local function repintar()
		local d = datos
		titulo.Text = `Propiedades de {d.ciudad}`
		for _, c in lista:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		if not filaElegida() then
			-- De entrada, la tuya si está acá; si no, la primera libre; si no, la primera
			elegida = nil
			for _, f in d.casas do
				if f.estado == "tuya" then
					elegida = f.id
				end
			end
			if not elegida then
				for _, f in d.casas do
					if f.estado == "libre" then
						elegida = f.id
						break
					end
				end
			end
			if not elegida and d.casas[1] then
				elegida = d.casas[1].id
			end
		end
		lista.CanvasSize = UDim2.fromOffset(0, #d.casas * ALTO_FILA)
		for i, f in d.casas do
			local b = Instance.new("TextButton")
			b.Name = f.id
			b.AutoButtonColor = false
			b.BackgroundColor3 = COLOR_ELEGIDA
			b.BackgroundTransparency = if f.id == elegida then 0 else 1
			b.BorderSizePixel = 0
			b.Position = UDim2.fromOffset(0, (i - 1) * ALTO_FILA)
			b.Size = UDim2.new(1, 0, 0, ALTO_FILA)
			b.Font = Enum.Font.ArialBold
			b.TextSize = 12
			b.TextColor3 = if f.estado == "tuya" or f.estado == "cuenta" then DORADO elseif f.estado == "libre" then VERDE else GRIS
			b.TextXAlignment = Enum.TextXAlignment.Left
			b.Text = ` {etiqueta(f)} - {if f.estado == "tuya" then "tuya" elseif f.estado == "cuenta" then "de tu cuenta" elseif f.estado == "libre" then "libre" else "ocupada"}`
			b.ZIndex = 4
			b.Parent = lista
			Click.activado(b, function()
				elegida = f.id
				repintar()
			end)
		end
		local f = filaElegida()
		if not f then
			texto.Text = ""
			bPrincipal.Visible, bDejar.Visible = false, false
			return
		end
		local L = { mayuscula(f.nombre) .. ".", "" }
		table.insert(L, `Alquiler: {Cfg.miles(d.precio)} monedas de oro cada {Cfg.Dias} dias.`)
		if f.estado == "tuya" then
			table.insert(L, `Es tuya: el alquiler vence en {Cfg.faltaTexto(f.vence or 0)}.`)
		elseif f.estado == "cuenta" then
			-- La alquiló otro personaje de la cuenta: desde este solo se puede dejarla
			table.insert(L, `La alquila {f.inquilino or "otro personaje"}, de tu cuenta: vence en {Cfg.faltaTexto(f.vence or 0)}. La usa y la renueva ese personaje; desde este puedes dejarla.`)
		elseif f.estado == "ocupada" then
			table.insert(L, `La alquila {f.inquilino or "alguien"}.`)
		else
			table.insert(L, "Esta libre.")
		end
		table.insert(L, "")
		table.insert(L, `Un cuarto de {f.tiles} baldosas. La puerta se abre solo para quien la alquila, y adentro hay un baul de {ConfigComercio.SlotsBaul} lugares que se guarda con tu personaje.`)
		table.insert(L, "")
		table.insert(L, "Si no renuevas a tiempo la casa queda libre para otro; lo que haya en el baul te espera hasta que vuelvas a alquilar.")
		if f.estado == "libre" and d.tengo then
			table.insert(L, "")
			table.insert(L, `Ya alquilas {d.tengo}: para alquilar otra, primero tienes que dejarla.`)
		end
		texto.Text = table.concat(L, "\n")
		bDejar.Visible = f.estado == "tuya" or f.estado == "cuenta"
		bPrincipal.Visible = f.estado == "tuya" or (f.estado == "libre" and not d.tengo)
		Boton.texto(bPrincipal, if f.estado == "tuya" then "Renovar" else "Alquilar")
	end
	pintar = repintar
	repintar()

	Click.activado(bPrincipal, function()
		local f = filaElegida()
		if not f then
			return
		end
		local renovar = f.estado == "tuya"
		task.spawn(function()
			local pregunta = if renovar
				then `¿Renovar el alquiler de {f.nombre} por 30 dias mas? Cuesta {Cfg.miles(datos.precio)} monedas de oro.`
				else `¿Alquilar {f.nombre} por 30 dias? Cuesta {Cfg.miles(datos.precio)} monedas de oro.`
			if Dialogo.confirmar(pregunta, if renovar then "Renovar" else "Alquilar") then
				accion(if renovar then "renovar" else "alquilar", f.id)
			end
		end)
	end)
	Click.activado(bDejar, function()
		local f = filaElegida()
		if not f or (f.estado ~= "tuya" and f.estado ~= "cuenta") then
			return
		end
		task.spawn(function()
			if Dialogo.confirmar(`¿Dejar {f.nombre}? Queda libre en el momento y no se devuelve el oro. Tu baul queda guardado.`, "Dejar la casa") then
				accion("dejar", f.id)
			end
		end)
	end)
end

function Casas.iniciar()
	evAccion = Remotes.evento("CasaAccion")
	-- Al cambiar de mapa la ventana se cierra (el vendedor quedó en el otro)
	Remotes.evento("CambiarMapa").OnClientEvent:Connect(function()
		if gui then
			Casas.cerrar()
		end
	end)
	Remotes.evento("CasaEvento").OnClientEvent:Connect(function(que: string, d: any)
		if que == "cerrar" then
			if gui then
				Casas.cerrar()
			end
			return
		end
		if typeof(d) ~= "table" or typeof(d.casas) ~= "table" then
			return
		end
		if que == "abrir" then
			datos = d
			elegida = nil
			abrir()
		elseif que == "refrescar" and gui then
			datos = d
			local f = pintar
			if f then
				f()
			end
		end
	end)
end

return Casas
