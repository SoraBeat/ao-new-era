--!strict
--[[
	CrearPersonaje — el formulario de creación (frmCrearPersonaje, docs/21 §3), sobre VentanaCrearPersonaje.jpg
	(800×600) con los controles en las posiciones del .frm (en px).

	- Nombre (txtNombre): los espacios del principio se sacan al escribir; los del final se recortan al crear con el
	  aviso del original. Más de 15 letras: "El nombre del personaje debe tener menos de 30 letras.".
	- Pueblo de origen: fijo, Ullathorpe (DF13-05 A: nace ahí y es su hogar).
	- Raza, clase y género: listas desplegables; las clases que no están (DF12-03 A) se ven grises con "Próximamente".
	- Dados (imgDados "Tirar Dados"): el servidor tira; se muestran los dados, el modificador de la raza y el final.
	- Cabeza: carrusel de 5 cabezas con flechas sobre el cuerpo desnudo de la raza y el género, y dos flechas para
	  girar la vista previa (picHead, HeadPJ, picPJ y DirPJ).
	- "Volver" y "Crear Personaje". Los errores del servidor salen en un aviso.
	CrearPersonaje.abrir() espera y devuelve la respuesta del servidor ({ ok, id, personajes }) o nil si se volvió.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cfg = require(ReplicatedStorage.Shared.Config.Cuenta)
local CfgProg = require(ReplicatedStorage.Shared.Config.Progresion)
local ConfigPJ = require(ReplicatedStorage.Shared.Config.Personajes)
local Remotes = require(ReplicatedStorage.Shared.Red.Remotes)
local UiAssets = require(ReplicatedStorage.Shared.Generado.UiAssets)
local Boton = require(script.Parent.Boton)
local Dialogo = require(script.Parent.Dialogo)
local Sonido = require(script.Parent.Parent.Audio.Sonido)
local Retrato = require(script.Parent.Parent.Render.Retrato)
local Click = require(script.Parent.Click)

local CrearPersonaje = {}

local AMARILLO = Color3.fromRGB(255, 255, 225)
local GRIS = Color3.fromRGB(120, 120, 120)
local FILAS_ATRIB = { 230, 252, 275, 298, 322 } -- lblAtributos / lblModRaza / lblAtributoFinal (1..5)

-- Textos de ayuda del panel derecho (spanish.json AYUDA_CREARPJ_*)
local AYUDA = {
	nombre = "Se cuidadoso al seleccionar el nombre de tu personaje. Argentum es un juego de rol, un mundo magico y fantastico, y si seleccionas un nombre obsceno o con connotacion politica, los administradores borraran tu personaje y no habra ninguna posibilidad de recuperarlo.",
	dados = "Presionando sobre la Esfera Roja, se modificaran al azar los atributos de tu personaje, de esta manera puedes elegir los que mas te parezcan para definir a tu personaje.",
	hogar = "Define el hogar de tu personaje.", -- DF13-05 A (el original sigue con la frase de Nemahuak)
	raza = "De la raza que elijas dependera como se modifiquen los dados que saques. Podes cambiar de raza para poder visualizar como se modifican los distintos atributos.",
	clase = "La clase influira en las caracteristicas principales que tenga tu personaje, asi como en su magia e items que podra utilizar.",
	genero = "Indica si el personaje sera masculino o femenino. Esto influye en los items que podra equipar.",
	Fuerza = "De ella dependera que tan potentes seran tus golpes, tanto con armas de cuerpo a cuerpo, a distancia o sin armas.",
	Agilidad = "Este atributo intervendra en que tan bueno seas, tanto evadiendo como acertando golpes, respecto de otros personajes como de las criaturas a las q te enfrentes.",
	Inteligencia = "Influira de manera directa en cuanto mana ganaras por nivel.",
	Carisma = "Sera necesario tanto para la relacion con otros personajes (entrenamiento en grupos) como con las criaturas (domar animales).",
	Constitucion = "Afectara a la cantidad de vida que podras ganar por nivel.",
}

local function texto(parent: Instance, t: string, x: number, y: number, w: number, h: number, props: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(x, y)
	l.Size = UDim2.fromOffset(w, h)
	l.Font = Enum.Font.ArialBold
	l.TextSize = 13
	l.TextColor3 = AMARILLO
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = t
	l.ZIndex = 3
	for k, v in props or {} do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

-- Lista desplegable (ComboBox): opciones = { { valor, texto, habilitada } }
local function combo(nombre: string, parent: Instance, x: number, y: number, w: number, h: number, opciones: { any }, inicial: any, alCambiar: (any) -> (), alPasar: (() -> ())?)
	local b = Instance.new("TextButton")
	b.Name = nombre
	b.BackgroundColor3 = Color3.new(0, 0, 0)
	b.BorderColor3 = Boton.ColorTexto
	b.Position = UDim2.fromOffset(x, y)
	b.Size = UDim2.fromOffset(w, h)
	b.Font = Enum.Font.Arial
	b.TextSize = 14
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.AutoButtonColor = false
	b.ZIndex = 5
	b.Parent = parent
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 4)
	pad.Parent = b
	local flecha = texto(b, "▼", w - 22, 0, 18, h, { ZIndex = 6, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Boton.ColorTexto })
	flecha.Font = Enum.Font.Arial
	local lista: Frame? = nil
	local function nombreDe(v: any): string
		for _, o in opciones do
			if o[1] == v then
				return o[2]
			end
		end
		return ""
	end
	b.Text = nombreDe(inicial)
	local function cerrarLista()
		if lista then
			lista:Destroy()
			lista = nil
		end
	end
	Click.activado(b, function()
		if lista then
			cerrarLista()
			return
		end
		local f = Instance.new("Frame")
		f.Name = nombre .. "_lista"
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderColor3 = Boton.ColorTexto
		f.Position = UDim2.fromOffset(x, y + h)
		f.Size = UDim2.fromOffset(w, #opciones * 18 + 2)
		f.ZIndex = 20
		f.Parent = parent
		lista = f
		for i, o in opciones do
			local item = Instance.new("TextButton")
			item.Name = tostring(o[1])
			item.BackgroundColor3 = Color3.new(0, 0, 0)
			item.BorderSizePixel = 0
			item.AutoButtonColor = o[3] ~= false
			item.Position = UDim2.fromOffset(1, 1 + (i - 1) * 18)
			item.Size = UDim2.new(1, -2, 0, 18)
			item.Font = Enum.Font.Arial
			item.TextSize = 13
			item.TextXAlignment = Enum.TextXAlignment.Left
			item.TextColor3 = if o[3] == false then GRIS else Color3.new(1, 1, 1)
			item.Text = "  " .. o[2] .. (if o[3] == false then "  (Próximamente)" else "")
			item.ZIndex = 21
			item.Parent = f
			Click.entra(item, function()
				if o[3] ~= false then
					item.BackgroundColor3 = Color3.fromRGB(0, 0, 128)
				end
			end)
			Click.sale(item, function()
				item.BackgroundColor3 = Color3.new(0, 0, 0)
			end)
			Click.activado(item, function()
				if o[3] == false then
					return
				end
				b.Text = o[2]
				cerrarLista()
				alCambiar(o[1])
			end)
		end
	end)
	if alPasar then
		Click.entra(b, alPasar)
	end
	return b
end

local function flechaBoton(nombre: string, parent: Instance, t: string, x: number, y: number, w: number, h: number): TextButton
	local b = Instance.new("TextButton")
	b.Name = nombre
	b.BackgroundTransparency = 1
	b.Position = UDim2.fromOffset(x, y)
	b.Size = UDim2.fromOffset(w, h)
	b.Font = Enum.Font.ArialBold
	b.TextSize = 16
	b.TextColor3 = Boton.ColorTexto
	b.Text = t
	b.ZIndex = 5
	b.Parent = parent
	return b
end

function CrearPersonaje.abrir(): any
	-- La ventana se arma con la misma función del panel (evita requerirlo: el panel requiere este módulo)
	local PanelCuenta = require(script.Parent.PanelCuenta) :: any
	local _, fondo, cerrar = PanelCuenta.ventana("CrearPersonaje", UiAssets.crear, 800, 600)

	local raza, genero, clase = "Humano", "Hombre", "Guerrero"
	local cabeza = Cfg.Cabezas.Humano.Hombre[1]
	local heading = 3
	local dados: { [string]: number }? = nil
	local resultado: any = nil
	local terminado = false

	-- Ayuda (lblHelp, el panel de la derecha)
	local ayuda = texto(fondo, AYUDA.nombre, 628, 100, 138, 350, { TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextSize = 12, Font = Enum.Font.Arial })
	local function mostrarAyuda(clave: string)
		return function()
			ayuda.Text = AYUDA[clave] or ""
		end
	end

	-- Nombre
	texto(fondo, "Nombre del Personaje", 235, 86, 321, 30, { TextXAlignment = Enum.TextXAlignment.Center, TextSize = 16 })
	local nombre = Instance.new("TextBox")
	nombre.Name = "txtNombre"
	nombre.BackgroundTransparency = 1
	nombre.Position = UDim2.fromOffset(240, 124)
	nombre.Size = UDim2.fromOffset(321, 31)
	nombre.Font = Enum.Font.ArialBold
	nombre.TextSize = 18
	nombre.TextColor3 = Color3.new(1, 1, 1)
	nombre.ClearTextOnFocus = false
	nombre.PlaceholderText = ""
	nombre.Text = ""
	nombre.ZIndex = 5
	nombre.Parent = fondo
	nombre:GetPropertyChangedSignal("Text"):Connect(function()
		-- txtNombre_Change (frmCrearPersonaje.frm:1924): sin espacios al principio; MaxLength = 30
		local limpio = string.gsub(nombre.Text, "^ +", "")
		limpio = string.sub(limpio, 1, 30)
		if limpio ~= nombre.Text then
			nombre.Text = limpio
		end
	end)
	nombre.Focused:Connect(mostrarAyuda("nombre"))

	-- Pueblo de origen (fijo), raza, clase y género
	texto(fondo, "Pueblo de Origen", 405, 184, 160, 17)
	local hogar = texto(fondo, "Ullathorpe", 404, 200, 175, 21, { Font = Enum.Font.Arial, TextSize = 14, TextColor3 = GRIS })
	Click.entra(hogar, mostrarAyuda("hogar"))
	texto(fondo, "Raza", 405, 219, 60, 15)
	texto(fondo, "Clase", 405, 255, 60, 15)
	texto(fondo, "Genero", 405, 289, 60, 15)

	-- Vista previa: cabezas y cuerpo
	local cabezas: { ImageLabel } = {}
	for i = 0, 4 do
		local cuadro = Instance.new("Frame")
		cuadro.BackgroundTransparency = 1
		cuadro.Position = UDim2.fromOffset(426 + i * 27, 392)
		cuadro.Size = UDim2.fromOffset(24, 24)
		cuadro.ZIndex = 4
		cuadro.Parent = fondo
		if i == 2 then
			local borde = Instance.new("UIStroke")
			borde.Color = Boton.ColorTexto
			borde.Parent = cuadro
		end
		local l = Instance.new("ImageLabel")
		l.BackgroundTransparency = 1
		l.ResampleMode = Enum.ResamplerMode.Pixelated
		l.ZIndex = 5
		l.Parent = cuadro
		cabezas[i + 1] = l
	end
	local previa = Instance.new("Frame")
	previa.BackgroundTransparency = 1
	previa.Position = UDim2.fromOffset(472, 424)
	previa.Size = UDim2.fromOffset(41, 65)
	previa.Parent = fondo
	local retrato = Retrato.nuevo(previa, 4, 26, 5)

	local function rango(): { number }
		return Cfg.Cabezas[raza][genero]
	end
	local function pintarPrevia()
		local r = rango()
		local n = r[2] - r[1] + 1
		for i = 1, 5 do
			local c = r[1] + ((cabeza - r[1]) + (i - 3)) % n
			Retrato.cabeza(cabezas[i], c, 24, 24)
		end
		local a = { cuerpo = ConfigPJ.cuerpoDesnudoDe(raza, genero), cabeza = cabeza, casco = 0, arma = 0, escudo = 0 }
		Retrato.dibujar(retrato, a, heading, false)
	end
	local function moverCabeza(d: number)
		local r = rango()
		local n = r[2] - r[1] + 1
		cabeza = r[1] + ((cabeza - r[1]) + d) % n
		pintarPrevia()
	end
	Click.activado(flechaBoton("HeadPJ0", fondo, "<", 402, 392, 20, 22), function()
		moverCabeza(-1)
	end)
	Click.activado(flechaBoton("HeadPJ1", fondo, ">", 562, 392, 20, 22), function()
		moverCabeza(1)
	end)
	-- DirPJ: girar la vista previa (N, E, S, O)
	Click.activado(flechaBoton("DirPJ0", fondo, "<", 460, 488, 20, 18), function()
		heading = (heading - 2) % 4 + 1
		pintarPrevia()
	end)
	Click.activado(flechaBoton("DirPJ1", fondo, ">", 502, 488, 20, 18), function()
		heading = heading % 4 + 1
		pintarPrevia()
	end)

	-- Atributos: dados, modificador de raza y final
	texto(fondo, "Atributos", 240, 184, 97, 20, { TextSize = 15 })
	local lblDados, lblMod, lblFinal = {}, {}, {}
	for i, a in CfgProg.Atributos do
		local y = FILAS_ATRIB[i]
		local nom = texto(fondo, a, 220 - 10, y - 2, 80, 17, { TextSize = 12 })
		Click.entra(nom, mostrarAyuda(a))
		lblDados[a] = texto(fondo, "", 296, y, 19, 13, { TextXAlignment = Enum.TextXAlignment.Right, TextSize = 12 })
		lblMod[a] = texto(fondo, "", 326, y, 19, 13, { TextXAlignment = Enum.TextXAlignment.Right, TextSize = 12 })
		lblFinal[a] = texto(fondo, "", 360, y, 21, 13, { TextXAlignment = Enum.TextXAlignment.Center, TextSize = 12, TextColor3 = Color3.fromRGB(255, 255, 0) })
	end
	local function pintarAtributos()
		for _, a in CfgProg.Atributos do
			local m = CfgProg.ModRaza[raza][a]
			lblMod[a].Text = if m >= 0 then `+{m}` else tostring(m)
			lblDados[a].Text = if dados then tostring(dados[a]) else ""
			lblFinal[a].Text = if dados then tostring(dados[a] + m) else ""
		end
	end

	local opcionesRaza = {}
	for _, r in Cfg.Razas do
		table.insert(opcionesRaza, { r, Cfg.NombreRaza[r], true })
	end
	local opcionesClase = {}
	for _, c in Cfg.Clases do
		table.insert(opcionesClase, { c, Cfg.NombreClase[c] or c, Cfg.ClasesHabilitadas[c] == true })
	end
	local opcionesGenero = { { "Hombre", "Hombre", true }, { "Mujer", "Mujer", true } }
	-- Se crean en orden inverso para que la lista de arriba quede sobre los combos de abajo
	combo("lstGenero", fondo, 404, 304, 175, 21, opcionesGenero, genero, function(v)
		genero = v
		cabeza = rango()[1]
		pintarPrevia()
	end, mostrarAyuda("genero"))
	combo("lstProfesion", fondo, 404, 269, 175, 21, opcionesClase, clase, function(v)
		clase = v
	end, mostrarAyuda("clase"))
	combo("lstRaza", fondo, 404, 233, 175, 21, opcionesRaza, raza, function(v)
		raza = v
		cabeza = rango()[1]
		pintarPrevia()
		pintarAtributos()
	end, mostrarAyuda("raza"))

	-- Dados (imgDados)
	local bDados = Boton.nuevo(fondo, "Tirar Dados", UDim2.fromOffset(88, 208), UDim2.fromOffset(89, 50), { tamTexto = 14, animado = true })
	bDados.ZIndex = 5
	bDados:SetAttribute("SinClick", true) -- suena el cubilete (SND_DICE, frmCrearPersonaje.frm:1647-1649)
	Click.entra(bDados, mostrarAyuda("dados"))
	Click.activado(bDados, function()
		Sonido.tocar("cupdice")
		local ok, t = pcall(function()
			return Remotes.funcion("TirarDados"):InvokeServer()
		end)
		if ok and typeof(t) == "table" then
			dados = t
			pintarAtributos()
		end
	end)

	-- Volver y crear
	local bVolver = Boton.nuevo(fondo, "Volver", UDim2.fromOffset(80, 544), UDim2.fromOffset(97, 33), { tamTexto = 15, animado = true })
	local bCrear = Boton.nuevo(fondo, "Crear Personaje", UDim2.fromOffset(608, 544), UDim2.fromOffset(169, 33), { tamTexto = 15, animado = true })
	bVolver.ZIndex, bCrear.ZIndex = 5, 5
	Click.activado(bVolver, function()
		terminado = true
	end)
	local enviando = false
	Click.activado(bCrear, function()
		if enviando then
			return
		end
		-- CheckData (frmCrearPersonaje.frm:1485-1536 y :1611-1615)
		local n = nombre.Text
		if string.match(n, " +$") then
			n = string.gsub(n, " +$", "")
			nombre.Text = n
			Dialogo.aviso(Cfg.MsgEspaciosFinal)
		end
		if #n > Cfg.LargoNombre then
			Dialogo.aviso(Cfg.MsgNombreLargo)
			return
		end
		if not Cfg.normalizarNombre(n) then
			Dialogo.aviso(Cfg.MsgNombreInvalido)
			return
		end
		if not dados then
			Dialogo.aviso(Cfg.MsgSinDados)
			return
		end
		enviando = true
		local ok, r = pcall(function()
			return Remotes.funcion("CrearPersonaje"):InvokeServer({ nombre = n, raza = raza, genero = genero, clase = clase, cabeza = cabeza })
		end)
		enviando = false
		if ok and r and r.ok then
			resultado = r
			terminado = true
		else
			Dialogo.aviso(if ok and r and r.error then r.error else Cfg.MsgErrorGuardado)
		end
	end)

	pintarPrevia()
	pintarAtributos()
	while not terminado do
		task.wait()
	end
	cerrar()
	return resultado
end

return CrearPersonaje
