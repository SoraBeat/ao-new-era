--!strict
--[[
	Produccion — la ventana de herrería y carpintería (frmHerrero y frmCarpinteria, 446×363; docs/32 §7).

	- Pestañas: herrería Armas / Armaduras / Mejorar; carpintería Objetos / Mejorar. Las recetas que el skill permite
	  (el servidor manda el skill efectivo), 4 por página con flechas y la rueda del mouse.
	- Cada fila: el ícono, los materiales (en rojo lo que falta para una) y "Construir" o "Mejorar". En Mejorar, las
	  mejoras de lo que hay en el inventario y el ícono del "Item Final".
	- "Cantidad" (con −, + y Máx = lo que alcanzan los materiales de la fila elegida) y "Construir por ciclo" (solo el
	  Trabajador). El servidor lleva la cola (DP16-05 A): "Parar" la corta y la ventana queda abierta (DP16-13 A).
	- El nombre del objeto: al pasar el mouse (PC) o al tocar el ícono (celular), abajo a la izquierda.
	- Fase 32 (docs/52 §4, pedido del autor): la ficha, una franja debajo de la ventana con el nombre, el golpe o la
	  defensa y qué clases lo usan ("Lo usan: Guerrero, Bandido y Paladín"). Es la de la fila tocada o, si no se tocó
	  ninguna de las que se ven, la de la primera. En Mejorar describe el objeto final.
	El servidor la abre con Produccion("abrir", { oficio, efectivo, porCiclo }).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Recetas = require(ReplicatedStorage.Shared.Generado.Recetas) :: any
local Objetos = require(ReplicatedStorage.Shared.Generado.ObjetosInventario) :: any
local UiAssets = require(ReplicatedStorage.Shared.Generado.UiAssets) :: any
local Cfg = require(ReplicatedStorage.Shared.Config.Produccion)
local Remotes = require(ReplicatedStorage.Shared.Red.Remotes)
local Equipo = require(ReplicatedStorage.Shared.Jugador.Equipo)
local Boton = require(script.Parent.Boton)
local Ventana = require(script.Parent.Ventana)
local GrillaItems = require(script.Parent.GrillaItems)
local Inventario = require(script.Parent.Inventario)
local Grh = require(script.Parent.Parent.Render.Grh)
local Click = require(script.Parent.Click)

local Produccion = {}

-- Lo pone Main: el F8 de talar / fundir se apaga al empezar a construir
Produccion.alConstruir = nil :: (() -> ())?

local FILAS_Y = { 93, 146, 199, 252 } -- los marcos de cada fila (px del .frm)
local ANCHO, ALTO = 446, 363 -- la ventana del original
local FICHA_ALTO = 50 -- Fase 32: la franja de la ficha, debajo
local LINGOTES = { { "h", 386 }, { "p", 387 }, { "o", 388 } }
local MADERAS = { { "madera", 58 }, { "elfica", 1006 } } -- la común y la élfica (P8, docs/36 §9)

-- Pestañas: { nombre, fondo, x, y, w, h, lista o "mejorar" }
local PESTANIAS = {
	Herreria = {
		{ "Armas", "herreriaArmas", 48, 32, 65, 17, "armas" },
		{ "Armaduras", "herreriaArmaduras", 112, 32, 97, 17, "armaduras" },
		{ "Mejorar", "herreriaMejorar", 216, 32, 73, 17, "mejorar" },
	},
	Carpinteria = {
		{ "Objetos", "carpinteriaItems", 48, 32, 65, 17, "carpinteria" },
		{ "Mejorar", "carpinteriaMejorar", 112, 32, 81, 17, "mejorar" },
	},
}

type Fila = {
	marco: ImageLabel,
	icono: ImageButton,
	mats: Frame,
	grilla: GrillaItems.Grilla,
	boton: ImageButton,
	marcoFinal: ImageLabel,
	final: ImageLabel,
}

type Estado = {
	gui: ScreenGui,
	fondo: ImageLabel,
	oficio: string,
	efectivo: number,
	porCicloMax: number,
	porCiclo: number,
	pestania: number,
	pagina: number,
	lista: { number }, -- objetos (o, en Mejorar, los orígenes)
	elegido: number?, -- el objeto de la última fila tocada (para Máx)
	filas: { Fila },
	cantidad: TextBox,
	botonesCant: { GuiObject },
	columna: Frame,
	ciclo: Frame,
	cicloTexto: TextLabel,
	nombre: TextLabel,
	fichaTitulo: TextLabel, -- Fase 32: "Espada Vikinga · Golpe 6-17"
	fichaUsan: TextLabel, -- "Lo usan: ..."
	etiquetaCant: TextLabel,
	parar: ImageButton,
	conexion: RBXScriptConnection?,
}
local v: Estado? = nil

function Produccion.abierta(): boolean
	return v ~= nil
end

-- ─── Inventario ──────────────────────────────────────────────────────────────
local function tengo(obj: number): number
	local n = 0
	for slot, d in Inventario.slots() do
		if slot <= Inventario.usables() and d.obj == obj then
			n += d.cant
		end
	end
	return n
end

-- Los materiales de una receta (o del costo de una mejora): { {obj, cant} }
local function materiales(d: any, oficio: string): { { number } }
	local m = {}
	for _, par in (if oficio == "Herreria" then LINGOTES else MADERAS) do
		table.insert(m, { par[2], d[par[1]] or 0 })
	end
	return m
end

-- Cuántas veces alcanza (Máx)
local function alcanzaPara(d: any, oficio: string, extra: number?): number
	local n = math.huge
	for _, x in materiales(d, oficio) do
		if x[2] > 0 then
			n = math.min(n, tengo(x[1]) // x[2])
		end
	end
	if extra then
		n = math.min(n, tengo(extra)) -- en Mejorar, el objeto de origen
	end
	return if n == math.huge then 1 else math.max(1, math.min(n, Cfg.MaxTotal))
end

-- ─── Piezas ──────────────────────────────────────────────────────────────────
-- Un recorte de la hoja botones_produccion.png
local function pieza(parent: Instance, x: number, y: number, w: number, h: number, ox: number, oy: number, clase: string?): any
	local i = Instance.new((clase or "ImageLabel") :: any) :: any
	i.BackgroundTransparency = 1
	i.Image = UiAssets.botonesProduccion
	i.ImageRectOffset = Vector2.new(ox, oy)
	i.ImageRectSize = Vector2.new(w, h)
	i.Position = UDim2.fromOffset(x, y)
	i.Size = UDim2.fromOffset(w, h)
	i.ZIndex = 3
	i.Parent = parent
	return i
end

-- Un botón del original en tres estados (fila de la hoja: 0 Construir, 28 Mejorar, 56 Cerrar)
local function botonHoja(parent: Instance, x: number, y: number, w: number, h: number, oy: number, alTocar: () -> ()): ImageButton
	local b = pieza(parent, x, y, w, h, 0, oy, "ImageButton") :: ImageButton
	b.AutoButtonColor = false
	b.ZIndex = 4
	Click.entra(b, function()
		b.ImageRectOffset = Vector2.new(w, oy)
	end)
	Click.sale(b, function()
		b.ImageRectOffset = Vector2.new(0, oy)
	end)
	b.MouseButton1Down:Connect(function()
		b.ImageRectOffset = Vector2.new(2 * w, oy)
	end)
	b.MouseButton1Up:Connect(function()
		b.ImageRectOffset = Vector2.new(w, oy)
	end)
	Click.activado(b, alTocar)
	return b
end

local function cantidadValor(e: Estado): number
	local n = tonumber(e.cantidad.Text)
	return if n and n >= 1 then math.min(math.floor(n), Cfg.MaxTotal) else 1
end

-- ─── Dibujo ──────────────────────────────────────────────────────────────────
local function esMejorar(e: Estado): boolean
	return PESTANIAS[e.oficio][e.pestania][7] == "mejorar"
end

local function armarLista(e: Estado)
	local clave = PESTANIAS[e.oficio][e.pestania][7]
	local l = {}
	if clave == "mejorar" then
		for origen, m in Recetas.mejoras do
			local d = Recetas.datos[m.destino]
			if d and d.oficio == e.oficio and d.sk <= e.efectivo and tengo(origen) > 0 then
				table.insert(l, origen)
			end
		end
		table.sort(l)
	else
		for _, obj in Recetas[clave] do
			local d = Recetas.datos[obj]
			if d and d.sk <= e.efectivo then
				table.insert(l, obj)
			end
		end
	end
	e.lista = l
	e.pagina = math.clamp(e.pagina, 0, math.max(0, #l - #FILAS_Y))
end

-- La fila de la que se habla: la elegida si está a la vista; si no, la primera que se ve (nil con la lista vacía)
local function filaActual(e: Estado): number?
	for i = 1, #FILAS_Y do
		if e.elegido ~= nil and e.lista[e.pagina + i] == e.elegido then
			return e.elegido
		end
	end
	return e.lista[e.pagina + 1]
end

-- Fase 32 (docs/52 §4): la ficha del objeto de la fila elegida (si ya no se ve, la de la primera fila)
local function pintarFicha(e: Estado)
	local obj: number? = filaActual(e)
	if obj and esMejorar(e) then
		obj = Recetas.mejoras[obj] and Recetas.mejoras[obj].destino
	end
	local o = obj and Objetos[obj]
	if not o then
		e.fichaTitulo.Text, e.fichaUsan.Text = "", ""
		return
	end
	local dato, usan, pide = Equipo.ficha(o)
	if pide ~= "" then -- Fase 39 (docs/59 §4): el skill que pide para equiparse, después de las clases
		usan = (if usan ~= "" then usan .. ". " else "") .. pide .. "."
	end
	if Cfg.deUna(o.tipo) then -- Fase 34 (docs/54 §7): las flechas salen todas juntas, en un solo golpe de serrucho
		dato = (if dato ~= "" then dato .. "  ·  " else "") .. "se hacen todas juntas"
	end
	e.fichaTitulo.Text = if dato ~= "" then `{o.nombre}  ·  {dato}` else o.nombre
	e.fichaUsan.Text = usan
end

local function pintar(e: Estado)
	local mejorar = esMejorar(e)
	for i, f in e.filas do
		local obj = e.lista[e.pagina + i]
		local hay = obj ~= nil
		for _, g in { f.marco, f.icono, f.mats, f.boton } do
			g.Visible = hay
		end
		f.marcoFinal.Visible = hay and mejorar
		f.final.Visible = hay and mejorar
		if hay then
			Grh.aplicar(f.icono, Objetos[obj] and Objetos[obj].grh or 0)
			f.icono.Size = UDim2.fromOffset(32, 32)
			local costo = if mejorar then Recetas.mejoras[obj] else Recetas.datos[obj]
			-- En carpintería van solo las maderas que pide, una al lado de la otra (Fase 34, docs/54 §6): antes había un
			-- solo casillero, el de la madera común, y lo que pide madera élfica (la Galera, el Galeón) no mostraba nada
			local mats = materiales(costo, e.oficio)
			if e.oficio ~= "Herreria" then
				local pide = {}
				for _, x in mats do
					if x[2] > 0 then
						table.insert(pide, x)
					end
				end
				mats = pide
			end
			local items = {}
			for k, x in mats do
				items[k] = { obj = x[1], cant = x[2] }
			end
			f.grilla:set(items)
			for k, x in mats do
				local c = f.grilla.celdas[k]
				if c then
					c.cant.TextColor3 = if tengo(x[1]) < x[2] then Color3.fromRGB(255, 70, 70) else Color3.new(1, 1, 1)
					c.cant.Visible = x[2] > 0
				end
			end
			f.boton.ImageRectOffset = Vector2.new(0, if mejorar then 28 else 0)
			if mejorar then
				local destino = Recetas.mejoras[obj].destino
				Grh.aplicar(f.final, Objetos[destino] and Objetos[destino].grh or 0)
				f.final.Size = UDim2.fromOffset(32, 32)
			end
		end
	end
	-- En Mejorar la columna derecha es el "Item Final": la cantidad baja a la línea de "Cerrar" (nuestro)
	e.cantidad.Position = if mejorar then UDim2.fromOffset(312, 316) else UDim2.fromOffset(347, 197)
	e.cantidad.Size = if mejorar then UDim2.fromOffset(30, 15) else UDim2.fromOffset(66, 15)
	for k, bt in e.botonesCant do
		bt.Position = if mejorar then UDim2.fromOffset(345 + (k - 1) * 24, 313) else UDim2.fromOffset(345 + (k - 1) * 24, 216)
	end
	e.etiquetaCant.Visible = mejorar
	e.ciclo.Visible = not mejorar and e.porCicloMax > 1
	e.cicloTexto.Text = tostring(e.porCiclo)
	pintarFicha(e)
end

local function cambiarPestania(e: Estado, i: number)
	e.pestania = i
	e.pagina = 0
	e.elegido = nil -- lo elegido era de la otra pestaña (Máx y la ficha lo buscarían en esta lista)
	e.fondo.Image = UiAssets[PESTANIAS[e.oficio][i][2]]
	armarLista(e)
	pintar(e)
end

local function mover(e: Estado, d: number)
	local antes = e.pagina
	e.pagina = math.clamp(e.pagina + d, 0, math.max(0, #e.lista - #FILAS_Y))
	if e.pagina ~= antes then
		pintar(e)
	end
end

function Produccion.cerrar()
	local e = v
	if not e then
		return
	end
	v = nil
	e.gui:Destroy()
end

-- ─── Acciones ────────────────────────────────────────────────────────────────
local function tocarFila(e: Estado, i: number)
	local obj = e.lista[e.pagina + i]
	if not obj then
		return
	end
	e.elegido = obj
	local nombreObj = Objetos[obj] and Objetos[obj].nombre or ""
	if esMejorar(e) then
		local destino = Recetas.mejoras[obj].destino
		nombreObj = `{nombreObj} → {Objetos[destino] and Objetos[destino].nombre or ""}`
	end
	e.nombre.Text = nombreObj
	pintarFicha(e)
end

local function construir(e: Estado, i: number)
	local obj = e.lista[e.pagina + i]
	if not obj then
		return
	end
	tocarFila(e, i)
	local f = Produccion.alConstruir
	if f then
		f()
	end
	if esMejorar(e) then
		Remotes.evento("Mejorar"):FireServer(obj, cantidadValor(e))
	else
		Remotes.evento("Construir"):FireServer(e.oficio, obj, cantidadValor(e), e.porCiclo)
	end
end

local function abrir(d: any)
	Produccion.cerrar()
	local oficio = if d.oficio == "Carpinteria" then "Carpinteria" else "Herreria"
	-- Fase 32: la ficha va debajo de la ventana, así que el conjunto es más alto: se achica lo que haga falta para
	-- que entre en la pantalla y se sube la mitad de la franja para que quede centrado (Fase 35: lo hace UI/Encaje)
	local gui, fondo = Ventana.crear("Produccion", UiAssets[PESTANIAS[oficio][1][2]], ANCHO, ALTO, { abajo = FICHA_ALTO })
	local ficha = Instance.new("Frame")
	ficha.Name = "Ficha"
	ficha.BackgroundColor3 = Color3.fromRGB(12, 10, 8)
	ficha.BackgroundTransparency = 0.12
	ficha.BorderSizePixel = 0
	ficha.Position = UDim2.fromOffset(8, ALTO)
	ficha.Size = UDim2.fromOffset(ANCHO - 16, FICHA_ALTO - 4)
	ficha.ZIndex = 2
	ficha.Active = true -- un click sobre la franja no pasa al mapa de atrás
	ficha.Parent = fondo
	local esquina = Instance.new("UICorner")
	esquina.CornerRadius = UDim.new(0, 4)
	esquina.Parent = ficha
	local borde = Instance.new("UIStroke")
	borde.Color = Color3.fromRGB(110, 96, 70)
	borde.Thickness = 1
	borde.Parent = ficha
	local e: Estado = {
		gui = gui,
		fondo = fondo,
		oficio = oficio,
		efectivo = d.efectivo or 0,
		porCicloMax = math.max(1, d.porCiclo or 1),
		porCiclo = math.max(1, d.porCiclo or 1),
		pestania = 1,
		pagina = 0,
		lista = {},
		elegido = nil,
		filas = {},
		cantidad = nil :: any,
		botonesCant = {},
		columna = nil :: any,
		ciclo = nil :: any,
		cicloTexto = nil :: any,
		nombre = Ventana.label(fondo, "", 30, 312, 150, 18, { Font = Enum.Font.Arial, TextSize = 12, TextColor3 = Boton.ColorTexto }),
		fichaTitulo = Ventana.label(ficha, "", 8, 3, ANCHO - 32, 15, { TextSize = 12 }),
		fichaUsan = Ventana.label(ficha, "", 8, 18, ANCHO - 32, 26, {
			Font = Enum.Font.Arial,
			TextSize = 11,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Boton.ColorTexto,
		}),
		parar = nil :: any,
		etiquetaCant = nil :: any,
		conexion = nil,
	}
	v = e
	-- Pestañas: zonas invisibles sobre el dibujo
	for i, p in PESTANIAS[oficio] do
		local b = Instance.new("TextButton")
		b.Name = "Pestania" .. p[1]
		b.BackgroundTransparency = 1
		b.Text = ""
		b.Position = UDim2.fromOffset(p[3], p[4])
		b.Size = UDim2.fromOffset(p[5], p[6])
		b.ZIndex = 5
		b.Parent = fondo
		Click.activado(b, function()
			cambiarPestania(e, i)
		end)
	end
	-- Las 4 filas
	local xBoton = if oficio == "Herreria" then 224 else 210
	local anchoMats = if oficio == "Herreria" then 116 else 84
	local celdas = if oficio == "Herreria" then 3 else 2 -- carpintería: la madera común y la élfica
	for i, y in FILAS_Y do
		local fila: Fila = {} :: any
		fila.marco = pieza(fondo, 48, y, 52, 52, 0, 80)
		local icono = Instance.new("ImageButton")
		icono.BackgroundTransparency = 1
		icono.ResampleMode = Enum.ResamplerMode.Pixelated
		icono.Position = UDim2.fromOffset(58, y + 10)
		icono.Size = UDim2.fromOffset(32, 32)
		icono.ZIndex = 4
		icono.Parent = fondo
		Click.activado(icono, function()
			tocarFila(e, i)
		end)
		Click.entra(icono, function()
			tocarFila(e, i)
		end)
		fila.icono = icono
		local mats = pieza(fondo, 104, y, anchoMats, 52, if oficio == "Herreria" then 52 else 168, 80) :: any
		fila.mats = mats
		local marcoGrilla = Instance.new("Frame")
		marcoGrilla.BackgroundTransparency = 1
		marcoGrilla.Position = UDim2.fromOffset(10, 10)
		marcoGrilla.Size = UDim2.fromOffset(32 * celdas, 32)
		marcoGrilla.Parent = mats
		fila.grilla = GrillaItems.nueva(marcoGrilla, celdas, celdas, 32)
		fila.boton = botonHoja(fondo, xBoton, y + 11, 114, 28, 0, function()
			construir(e, i)
		end)
		fila.marcoFinal = pieza(fondo, 352, y, 52, 52, 0, 80)
		local final = Instance.new("ImageLabel")
		final.BackgroundTransparency = 1
		final.ResampleMode = Enum.ResamplerMode.Pixelated
		final.Position = UDim2.fromOffset(362, y + 10)
		final.Size = UDim2.fromOffset(32, 32)
		final.ZIndex = 4
		final.Parent = fondo
		fila.final = final
		e.filas[i] = fila
	end
	-- Flechas y rueda (nuestras, en la zona de la barra del original: (30, 94), 17×209)
	for _, p in { { UiAssets.flechaSubir, 94, -1 }, { UiAssets.flechaBajar, 287, 1 } } do
		local b = Instance.new("ImageButton")
		b.BackgroundTransparency = 1
		b.Image = p[1]
		b.Position = UDim2.fromOffset(30, p[2])
		b.Size = UDim2.fromOffset(16, 17)
		b.ZIndex = 5
		b.Parent = fondo
		local d = p[3]
		Click.activado(b, function()
			mover(e, d)
		end)
	end
	fondo.InputChanged:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			mover(e, if input.Position.Z > 0 then -1 else 1)
		end
	end)
	-- El mando (Fase 34, docs/54 §4): la cruceta hace de rueda
	Click.cruceta(fondo, function(_dx: number, dy: number)
		if dy ~= 0 then
			mover(e, dy)
		end
	end)
	-- Columna derecha: Cantidad (−, +, Máx) y Construir por ciclo
	local col = Instance.new("Frame")
	col.Name = "Columna"
	col.BackgroundTransparency = 1
	col.Size = UDim2.fromScale(1, 1)
	col.ZIndex = 3
	col.Parent = fondo
	e.columna = col
	local caja = Instance.new("TextBox")
	caja.Name = "Cantidad"
	caja.BackgroundColor3 = Color3.new(0, 0, 0)
	caja.BorderSizePixel = 0
	caja.Position = UDim2.fromOffset(347, 197)
	caja.Size = UDim2.fromOffset(66, 15)
	caja.Font = Enum.Font.ArialBold
	caja.TextSize = 12
	caja.TextColor3 = Color3.new(1, 1, 1)
	caja.ClearTextOnFocus = false
	caja.Text = "1"
	caja.ZIndex = 4
	caja.Parent = col
	caja:GetPropertyChangedSignal("Text"):Connect(function()
		local limpio = string.sub(string.gsub(caja.Text, "%D", ""), 1, 5)
		if limpio ~= caja.Text then
			caja.Text = limpio
		end
	end)
	e.cantidad = caja
	e.etiquetaCant = Ventana.label(col, "Cant.", 283, 314, 29, 18, { TextSize = 12, TextColor3 = Boton.ColorTexto })
	local function setCant(n: number)
		caja.Text = tostring(math.clamp(math.floor(n), 1, Cfg.MaxTotal))
	end
	for _, b in {
		{ "−", 345, 22, function() setCant(cantidadValor(e) - 1) end },
		{ "+", 369, 22, function() setCant(cantidadValor(e) + 1) end },
		{ "Máx", 393, 32, function()
			local obj = filaActual(e) -- la misma fila que describe la ficha
			if not obj then
				return
			end
			if esMejorar(e) then
				if not Recetas.mejoras[obj] then
					return
				end
				setCant(alcanzaPara(Recetas.mejoras[obj], e.oficio, obj))
			else
				setCant(alcanzaPara(Recetas.datos[obj], e.oficio))
			end
		end },
	} do
		local bt = Boton.nuevo(col, b[1], UDim2.fromOffset(b[2], 216), UDim2.fromOffset(b[3], 22), { tamTexto = 12 })
		bt.ZIndex = 4
		Click.activado(bt, b[4])
		table.insert(e.botonesCant, bt)
	end
	local ciclo = Instance.new("Frame")
	ciclo.Name = "PorCiclo"
	ciclo.BackgroundTransparency = 1
	ciclo.Size = UDim2.fromScale(1, 1)
	ciclo.Parent = col
	e.ciclo = ciclo
	pieza(ciclo, 344, 242, 74, 43, 252, 80)
	local menos = Boton.nuevo(ciclo, "−", UDim2.fromOffset(345, 288), UDim2.fromOffset(22, 20), { tamTexto = 12 })
	e.cicloTexto = Ventana.label(ciclo, "", 369, 288, 22, 20, { TextXAlignment = Enum.TextXAlignment.Center })
	local mas = Boton.nuevo(ciclo, "+", UDim2.fromOffset(393, 288), UDim2.fromOffset(22, 20), { tamTexto = 12 })
	Click.activado(menos, function()
		e.porCiclo = math.max(1, e.porCiclo - 1)
		e.cicloTexto.Text = tostring(e.porCiclo)
	end)
	Click.activado(mas, function()
		e.porCiclo = math.min(e.porCicloMax, e.porCiclo + 1)
		e.cicloTexto.Text = tostring(e.porCiclo)
	end)
	-- "Parar" (donde estaba la casilla "Usar Macro") y "Cerrar"
	local parar = Boton.nuevo(fondo, "Parar", UDim2.fromOffset(345, 106), UDim2.fromOffset(70, 26), { tamTexto = 14 })
	parar.ZIndex = 5
	parar.Visible = false
	Click.activado(parar, function()
		Remotes.evento("PararTrabajo"):FireServer()
	end)
	e.parar = parar
	botonHoja(fondo, 184, 310, 97, 24, 56, function()
		Produccion.cerrar()
	end)
	armarLista(e)
	pintar(e)
end

function Produccion.iniciar()
	Inventario.alCambiarInventario(function()
		local e = v
		if e then
			armarLista(e)
			pintar(e)
		end
	end)
	Remotes.evento("Produccion").OnClientEvent:Connect(function(accion: string, a: any)
		if accion == "abrir" then
			abrir(a)
		elseif accion == "cola" then
			local e = v
			if e then
				e.parar.Visible = a == true
			end
		end
	end)
end

return Produccion
