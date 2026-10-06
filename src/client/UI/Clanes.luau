--!strict
--[[
	Clanes — las ventanas de clanes del cliente original (Fase 15b-1, docs/28 §3 y §12), con sus fondos y botones
	(ui/clan_*.png y botones_clan.png, posiciones de los .frm en px):

	- Botón "Clanes" del HUD (btnClanes, frmMain.frm:1964-1968) → el panel según el cargo (SendGuildLeaderInfo):
	    sin clan: frmGuildAdm (lista de clanes, Detalles) + "Fundar un clan" (nuestro, en vez de escribir /FUNDARCLAN);
	    miembro: frmGuildMember (clanes, miembros, Detalles, Noticias) + "Salir del clan" (nuestro, /SALIRCLAN);
	    líder: frmGuildLeader (clanes, miembros, noticias editables, aspirantes, Detalles, Editar codex) + "Cerrar el
	    clan" (nuestro, /CERRARCLAN).
	- Ficha de un clan (frmGuildBrief) con "Solicitar ingreso" → frmGuildSol.
	- Ficha de un aspirante o miembro para el líder (frmCharInfo): Aceptar, Rechazar (con motivo, frmCommet) y Echar.
	- Fundar: la alineación (VentanaFundarClan, Legal / Neutral / Criminal), el nombre (frmGuildFoundation, sin URL) y
	  la descripción con el codex (frmGuildDetails). El líder edita el codex en la misma ventana.
	- Noticias del clan al entrar (frmGuildNews).
	Todo lo decide el servidor (remote Clan); acá solo se muestra.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cfg = require(ReplicatedStorage.Shared.Config.Clanes)
local Remotes = require(ReplicatedStorage.Shared.Red.Remotes)
local UiAssets = require(ReplicatedStorage.Shared.Generado.UiAssets) :: any
local Ventana = require(script.Parent.Ventana)
local Boton = require(script.Parent.Boton)
local Dialogo = require(script.Parent.Dialogo)
local Click = require(script.Parent.Click)

local Clanes = {}

local abiertas: { [string]: ScreenGui } = {}
local panelAbierto = false

local BLANCO = Color3.new(1, 1, 1)
local SEL = Color3.fromRGB(0, 0, 128)

-- ─── Piezas ──────────────────────────────────────────────────────────────────
local function cerrar(nombre: string)
	local g = abiertas[nombre]
	if g then
		g:Destroy()
		abiertas[nombre] = nil
	end
	if nombre == "ClanPanel" then
		panelAbierto = false
	end
end

local function ventana(nombre: string, imagen: string, ancho: number, alto: number): ImageLabel
	cerrar(nombre)
	local g, fondo = Ventana.crear(nombre, imagen, ancho, alto)
	g.DisplayOrder = 42
	abiertas[nombre] = g
	return fondo
end

-- Un botón de la hoja botones_clan.png (normal, encima, apretado uno debajo del otro)
local function boton(fondo: Instance, clave: string, nombre: string): ImageButton
	local l = UiAssets.botonesClanLayout[clave][nombre]
	local b = Instance.new("ImageButton")
	b.Name = "img" .. nombre
	b.BackgroundTransparency = 1
	b.Image = UiAssets.botonesClan
	b.ImageRectSize = Vector2.new(l.w, l.h)
	b.ImageRectOffset = Vector2.new(l.ox, l.oy)
	b.Position = UDim2.fromOffset(l.x, l.y)
	b.Size = UDim2.fromOffset(l.w, l.h)
	b.ZIndex = 4
	b.Parent = fondo
	Click.entra(b, function()
		b.ImageRectOffset = Vector2.new(l.ox, l.oy + l.h)
	end)
	Click.sale(b, function()
		b.ImageRectOffset = Vector2.new(l.ox, l.oy)
	end)
	b.MouseButton1Down:Connect(function()
		b.ImageRectOffset = Vector2.new(l.ox, l.oy + 2 * l.h)
	end)
	b.MouseButton1Up:Connect(function()
		b.ImageRectOffset = Vector2.new(l.ox, l.oy + l.h)
	end)
	return b
end

-- Fase 31 (docs/51, D31-14): cuántos miembros tiene el clan y cuántos admite, "12 de 38". El tope lo da el Liderazgo
-- del líder (20 más uno cada 5 puntos) y lo manda el servidor; si todavía no lo tiene anotado (un clan de antes, cuyo
-- líder no volvió a entrar), va solo la cantidad.
local function cuantosDe(cantidad: any, tope: any): string
	local n = tonumber(cantidad) or 0
	return if typeof(tope) == "number" then `{n} de {tope}` else tostring(n)
end

local function generico(fondo: Instance, texto: string, x: number, y: number, w: number, h: number): ImageButton
	local b = Boton.nuevo(fondo, texto, UDim2.fromOffset(x, y), UDim2.fromOffset(w, h), { tamTexto = if h < 24 then 12 else 14 })
	b.ZIndex = 4
	return b
end

local function label(fondo: Instance, texto: string, x: number, y: number, w: number, h: number, props: { [string]: any }?): TextLabel
	local l = Ventana.label(fondo, texto, x, y, w, h, props)
	l.ZIndex = 4
	return l
end

local function caja(fondo: Instance, nombre: string, x: number, y: number, w: number, h: number, tope: number, multilinea: boolean?, soloLectura: boolean?): TextBox
	local c = Instance.new("TextBox")
	c.Name = nombre
	c.BackgroundColor3 = Color3.new(0, 0, 0)
	c.BackgroundTransparency = 0.15
	c.BorderSizePixel = 0
	c.Position = UDim2.fromOffset(x, y)
	c.Size = UDim2.fromOffset(w, h)
	c.Font = Enum.Font.Arial
	c.TextSize = 13
	c.TextColor3 = BLANCO
	c.TextXAlignment = Enum.TextXAlignment.Left
	c.TextYAlignment = if multilinea then Enum.TextYAlignment.Top else Enum.TextYAlignment.Center
	c.MultiLine = multilinea == true
	c.TextWrapped = multilinea == true
	c.ClearTextOnFocus = false
	c.TextEditable = not soloLectura
	c.ClipsDescendants = true
	c.Text = ""
	c.ZIndex = 4
	c.Parent = fondo
	c:GetPropertyChangedSignal("Text"):Connect(function()
		local n = utf8.len(c.Text)
		if n and n > tope then
			c.Text = string.sub(c.Text, 1, (utf8.offset(c.Text, tope + 1) :: number) - 1)
		end
	end)
	return c
end

export type Lista = {
	poner: (items: { { clave: string, texto: string } }) -> (),
	seleccion: () -> string?,
	filtrar: (texto: string) -> (),
	alElegir: ((string) -> ())?,
	alDobleClick: ((string) -> ())?,
}

-- Un ListBox del original: fondo negro, letras blancas, el elegido en azul
local function lista(fondo: Instance, nombre: string, x: number, y: number, w: number, h: number): Lista
	local sf = Instance.new("ScrollingFrame")
	sf.Name = nombre
	sf.BackgroundColor3 = Color3.new(0, 0, 0)
	sf.BorderSizePixel = 0
	sf.Position = UDim2.fromOffset(x, y)
	sf.Size = UDim2.fromOffset(w, h)
	sf.ScrollBarThickness = 6
	sf.CanvasSize = UDim2.new()
	sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sf.ZIndex = 4
	sf.Parent = fondo
	local orden = Instance.new("UIListLayout")
	orden.SortOrder = Enum.SortOrder.LayoutOrder
	orden.Parent = sf
	local filas: { [string]: TextButton } = {}
	local elegido: string? = nil
	local L: Lista = {} :: any
	local ultimoClick, ultimaClave = 0, ""
	local function pintar()
		for k, f in filas do
			f.BackgroundTransparency = if k == elegido then 0 else 1
		end
	end
	function L.poner(items)
		for _, f in filas do
			f:Destroy()
		end
		table.clear(filas)
		local sigue = false
		for i, it in items do
			local f = Instance.new("TextButton")
			f.Name = it.clave
			f.AutoButtonColor = false
			f.BackgroundColor3 = SEL
			f.BorderSizePixel = 0
			f.Size = UDim2.new(1, -6, 0, 15)
			f.LayoutOrder = i
			f.Font = Enum.Font.Arial
			f.TextSize = 13
			f.TextColor3 = BLANCO
			f.TextXAlignment = Enum.TextXAlignment.Left
			f.TextTruncate = Enum.TextTruncate.AtEnd
			f.Text = " " .. it.texto
			f.ZIndex = 5
			f.Parent = sf
			filas[it.clave] = f
			if it.clave == elegido then
				sigue = true
			end
			Click.activado(f, function()
				elegido = it.clave
				pintar()
				local ahora = os.clock()
				local doble = ultimaClave == it.clave and ahora - ultimoClick < 0.45
				ultimoClick, ultimaClave = ahora, it.clave
				if L.alElegir then
					(L.alElegir :: (string) -> ())(it.clave)
				end
				if doble and L.alDobleClick then
					(L.alDobleClick :: (string) -> ())(it.clave)
				end
			end)
		end
		if not sigue then
			elegido = nil
		end
		pintar()
	end
	function L.seleccion()
		return elegido
	end
	function L.filtrar(texto)
		local q = string.lower(texto)
		for _, f in filas do
			f.Visible = q == "" or string.find(string.lower(f.Text), q, 1, true) ~= nil
		end
	end
	return L
end

local function pedir(accion: string, a: any?, b: any?): any
	local ok, r = pcall(function()
		return Remotes.funcion("Clan"):InvokeServer(accion, a, b)
	end)
	if not ok then
		return { error = "No hay conexion con el servidor." }
	end
	return r or {}
end

-- Muestra el error (o el mensaje) sin trabar el juego
local function avisar(texto: string?)
	if texto then
		task.spawn(Dialogo.aviso, texto)
	end
end

-- ─── Ficha de un clan (frmGuildBrief) ────────────────────────────────────────
local abrirSolicitud: (string, string) -> ()

function Clanes.detalles(clave: string)
	local d = pedir("detalles", clave)
	if not d or d.error then
		avisar(d and d.error)
		return
	end
	local f = ventana("ClanDetalles", UiAssets.clanDetalles, 508, 510)
	local props = { Font = Enum.Font.Arial, TextSize = 13 }
	label(f, d.nombre, 88, 36, 313, 17, props)
	label(f, d.fundador, 96, 58, 185, 17, props)
	label(f, d.fecha, 384, 56, 97, 17, props)
	label(f, d.lider, 72, 80, 209, 17, props)
	label(f, "-", 96, 103, 177, 17, props) -- sin URL (DS15-21 A)
	label(f, cuantosDe(d.miembros, d.tope), 344, 104, 129, 17, props) -- (Fase 31: "12 de 38")
	label(f, if d.elecciones then "Si" else "No", 352, 81, 121, 17, props)
	label(f, d.alineacion, 352, 128, 121, 17, props)
	label(f, tostring(d.enemigos or 0), 128, 127, 145, 17, props)
	label(f, tostring(d.aliados or 0), 120, 149, 105, 17, props)
	label(f, d.antifaccion, 152, 171, 161, 17, props)
	for i = 1, Cfg.LineasCodex do
		label(f, (d.codex or {})[i] or "", 24, 240 + (i - 1) * 16, 449, 17, props)
	end
	local desc = caja(f, "Desc", 21, 406, 462, 61, Cfg.LargoDesc, true, true)
	desc.Text = d.desc or ""
	Click.activado(boton(f, "detalles", "Cerrar"), function()
		cerrar("ClanDetalles")
	end)
	if d.puedeSolicitar then
		Click.activado(boton(f, "detalles", "SolicitarIngreso"), function()
			abrirSolicitud(d.clave, d.nombre)
		end)
	end
	-- Fase 19 (docs/38 §6.4, DC19-19 A): clan contra clan ganados y perdidos (a la derecha de "Clanes aliados")
	local gan, per = tonumber(d.cvcGanados) or 0, tonumber(d.cvcPerdidos) or 0
	label(f, `Clan vs clan: {gan} {if gan == 1 then "ganado" else "ganados"}, {per} {if per == 1 then "perdido" else "perdidos"}`, 288, 149, 200, 17, props)
	-- 15b-2 (DS15-16 A): el líder de otro clan ofrece paz o alianza, o declara la guerra
	if d.relacion then
		label(f, `Relacion con tu clan: {d.relacion}`, 300, 171, 190, 17, props)
		-- Fase 19 (docs/38 §6.2): y lo desafía a un clan contra clan
		Click.activado(generico(f, "Desafiar a clan contra clan", 288, 188, 196, 17), function()
			task.spawn(function()
				if Dialogo.confirmar(`Desafiar a {d.nombre} a un clan contra clan?`) then
					local r = Clanes.pedir("cvc", "desafiar", d.clave)
					avisar(r and (r.error or r.mensaje))
					cerrar("ClanDetalles")
				end
			end)
		end)
		local function oferta(accion: string, titulo: string)
			Clanes.comentario(titulo, function(texto: string)
				local r = Clanes.pedir(accion, d.clave, texto)
				avisar(r.error or r.mensaje)
			end)
		end
		Click.activado(boton(f, "detalles", "OfrecerPaz"), function()
			oferta("ofrecerPaz", "Oferta de paz")
		end)
		Click.activado(boton(f, "detalles", "OfrecerAlianza"), function()
			oferta("ofrecerAlianza", "Oferta de alianza")
		end)
		Click.activado(boton(f, "detalles", "DeclararGuerra"), function()
			task.spawn(function()
				if Dialogo.confirmar(`Declararle la guerra a {d.nombre}?`) then
					local r = Clanes.pedir("guerra", d.clave)
					avisar(r.error)
					cerrar("ClanDetalles")
				end
			end)
		end)
	end
end

-- ─── Pedir ingreso (frmGuildSol) ─────────────────────────────────────────────
abrirSolicitud = function(clave: string, _nombre: string)
	local f = ventana("ClanIngreso", UiAssets.clanIngreso, 312, 233)
	local texto = caja(f, "Text1", 20, 104, 265, 69, Cfg.LargoSolicitud, true)
	Click.activado(boton(f, "ingreso", "Cerrar"), function()
		cerrar("ClanIngreso")
	end)
	Click.activado(boton(f, "ingreso", "Enviar"), function()
		local r = pedir("solicitar", clave, texto.Text)
		if r.error then
			avisar(r.error)
			return
		end
		cerrar("ClanIngreso")
		cerrar("ClanDetalles")
		avisar(r.mensaje)
	end)
end

-- ─── Un texto (frmCommet): el motivo del rechazo ─────────────────────────────
local function abrirComentario(titulo: string, alEnviar: (string) -> ())
	local f = ventana("ClanComentario", UiAssets.clanComentario, 338, 219)
	label(f, titulo, 24, 8, 290, 22, { TextColor3 = BLANCO, TextSize = 14 })
	local texto = caja(f, "Text1", 16, 32, 305, 129, Cfg.LargoMotivo, true)
	Click.activado(generico(f, "Enviar", 72, 168, 65, 33), function()
		cerrar("ClanComentario")
		alEnviar(texto.Text)
	end)
	Click.activado(generico(f, "Cerrar", 192, 168, 65, 33), function()
		cerrar("ClanComentario")
	end)
end

Clanes.comentario = abrirComentario
Clanes.pedir = pedir

-- ─── Propuestas de paz o alianza (frmPeaceProp, 15b-2) ───────────────────────
local function abrirPropuestas(tipo: string)
	local d = pedir("propuestas", tipo)
	if d.error then
		avisar(d.error)
		return
	end
	local f = ventana("ClanPropuestas", UiAssets.clanPropuestas, 338, 219)
	label(f, if tipo == "paz" then "Ofertas de paz" else "Ofertas de alianza", 24, 14, 290, 22, { TextColor3 = BLANCO, TextSize = 14 })
	local l = lista(f, "lista", 16, 40, 308, 119)
	local textos: { [string]: string } = {}
	local items = {}
	for _, p in d.lista or {} do
		table.insert(items, { clave = p.clave, texto = p.nombre })
		textos[p.clave] = p.texto
	end
	l.poner(items)
	Click.activado(generico(f, "Cerrar", 16, 176, 65, 25), function()
		cerrar("ClanPropuestas")
	end)
	Click.activado(generico(f, "Detalle", 96, 176, 65, 25), function()
		local s = l.seleccion()
		if s then
			avisar(if textos[s] and textos[s] ~= "" then textos[s] else "(sin texto)")
		end
	end)
	local function responder(accion: string)
		local s = l.seleccion()
		if not s then
			return
		end
		local r = pedir(accion, s, tipo)
		avisar(r.error)
		abrirPropuestas(tipo)
	end
	Click.activado(generico(f, "Aceptar", 176, 176, 65, 25), function()
		responder("aceptarPropuesta")
	end)
	Click.activado(generico(f, "Rechazar", 256, 176, 65, 25), function()
		responder("rechazarPropuesta")
	end)
end

-- ─── Ficha de un aspirante o miembro para el líder (frmCharInfo) ─────────────
local function abrirFicha(llave: string)
	local d = pedir("ficha", llave)
	if not d or d.error then
		avisar(d and d.error)
		return
	end
	local f = ventana("ClanFicha", UiAssets.clanInfoPj, 432, 439)
	label(f, "Personaje", 24, 8, 200, 25, { TextSize = 16, TextColor3 = BLANCO })
	label(f, "Nombre", 40, 48, 60, 17)
	label(f, d.nombre, 110, 47, 250, 17, { Font = Enum.Font.Arial })
	if d.aspirante then
		label(f, "Estado", 40, 66, 60, 17)
		label(f, d.estado or "", 110, 65, 250, 17, { Font = Enum.Font.Arial })
		label(f, "Pidio entrar", 40, 84, 80, 17)
		label(f, d.fecha or "", 130, 83, 250, 17, { Font = Enum.Font.Arial })
		label(f, "Solicitud de ingreso", 24, 192, 300, 17)
		local t = caja(f, "txtPeticiones", 24, 214, 382, 72, Cfg.LargoSolicitud, true, true)
		t.Text = d.texto or ""
		Click.activado(generico(f, "Rechazar", 264, 400, 73, 33), function()
			abrirComentario("Motivo del rechazo", function(motivo: string)
				local r = pedir("rechazar", llave, motivo)
				avisar(r.error)
				cerrar("ClanFicha")
			end)
		end)
		Click.activado(generico(f, "Aceptar", 344, 400, 73, 33), function()
			local r = pedir("aceptar", llave)
			avisar(r.error)
			cerrar("ClanFicha")
		end)
	else
		label(f, if d.esLider then "Lider del clan" else "Miembro del clan", 40, 66, 200, 17, { Font = Enum.Font.Arial })
		if not d.esLider then
			Click.activado(generico(f, "Echar", 88, 400, 73, 33), function()
				task.spawn(function()
					if Dialogo.confirmar(`Echar a {d.nombre} del clan?`) then
						local r = pedir("echar", llave)
						avisar(r.error)
						cerrar("ClanFicha")
					end
				end)
			end)
		end
	end
	Click.activado(generico(f, "Cerrar", 8, 400, 73, 33), function()
		cerrar("ClanFicha")
	end)
end

-- ─── Noticias (frmGuildNews) ─────────────────────────────────────────────────
function Clanes.noticias(d: any)
	local f = ventana("ClanNoticias", UiAssets.clanNoticias, 335, 453)
	local n = caja(f, "news", 21, 55, 285, 140, 4000, true, true)
	local texto = if d and d.noticias then d.noticias else ""
	if d and d.eleccion then
		-- Al entrar durante una elección (modGuilds.bas:637-643)
		texto ..= "\n\nHoy es la votacion para elegir un nuevo lider para el clan.\nLa eleccion durara 24 horas, se puede votar a cualquier miembro del clan.\nPara votar escribe /VOTO NICKNAME (o elegi al miembro en el panel y toca Votar).\nSolo se computara un voto por miembro. Tu voto no puede ser cambiado."
	end
	n.Text = texto
	local g = caja(f, "txtClanesGuerra", 21, 232, 285, 68, 4000, true, true)
	g.Text = table.concat(if d and d.guerra then d.guerra else {}, "\n")
	local a = caja(f, "txtClanesAliados", 21, 336, 285, 68, 4000, true, true)
	a.Text = table.concat(if d and d.aliados then d.aliados else {}, "\n")
	Click.activado(boton(f, "noticias", "Aceptar"), function()
		cerrar("ClanNoticias")
	end)
end

-- ─── Descripción y codex (frmGuildDetails): fundar o editar ──────────────────
local function abrirCodex(desc: string, codex: { string }, alConfirmar: (string, { string }) -> ())
	local f = ventana("ClanCodex", UiAssets.clanCodex, 456, 455)
	local d = caja(f, "txtDesc", 27, 28, 401, 100, Cfg.LargoDesc, true)
	d.Text = desc
	local lineas: { TextBox } = {}
	local Y = { 217, 243, 268, 292, 317, 342, 367, 391 }
	for i = 1, Cfg.LineasCodex do
		lineas[i] = caja(f, `txtCodex{i}`, 32, Y[i], 389, 17, Cfg.LargoCodex)
		lineas[i].Text = codex[i] or ""
	end
	Click.activado(boton(f, "codex", "Salir"), function()
		cerrar("ClanCodex")
	end)
	Click.activado(boton(f, "codex", "Confirmar"), function()
		local cx = {}
		for i, l in lineas do
			cx[i] = l.Text
		end
		alConfirmar(d.Text, cx)
	end)
end

-- ─── Fundar (docs/28 §3; /FUNDARCLAN) ────────────────────────────────────────
local function pasoNombre(alineacion: string)
	local f = ventana("ClanNombre", UiAssets.clanNombre, 272, 258)
	local nombre = caja(f, "txtClanName", 24, 121, 223, 19, Cfg.NombreMax)
	Click.activado(boton(f, "nombre", "Cancelar"), function()
		cerrar("ClanNombre")
	end)
	Click.activado(boton(f, "nombre", "Siguiente"), function()
		local n = Cfg.validarNombre(nombre.Text)
		if not n then
			avisar(Cfg.Msg.NombreInvalido .. ` Letras y espacios, de {Cfg.NombreMin} a {Cfg.NombreMax}.`)
			return
		end
		cerrar("ClanNombre")
		abrirCodex("", {}, function(desc, codex)
			local r = pedir("fundar", { alineacion = alineacion, nombre = n, desc = desc, codex = codex })
			if r.error then
				avisar(r.error)
				return
			end
			cerrar("ClanCodex")
			cerrar("ClanPanel")
		end)
	end)
end

local function pasoAlineacion(estado: string?, permitidas: { [string]: boolean }?)
	local f = ventana("ClanAlineacion", UiAssets.alineacionClan, 449, 352)
	-- P8 (docs/36 §8): las cinco del original, en las posiciones del .frm (lblTitleReal 120, Legal 1080, Neutral 2040,
	-- Criminal 3000 y Caos 3960 twips); el título de la ventana ya no entra
	local FILAS = { 8, 72, 136, 200, 264 }
	local COLOR = {
		real = Color3.fromRGB(130, 150, 255),
		legal = Color3.fromRGB(78, 78, 252),
		neutral = Color3.fromRGB(190, 190, 190),
		criminal = Color3.fromRGB(255, 0, 0),
		delmal = Color3.fromRGB(255, 80, 40),
	}
	local MOTIVO = { legal = Cfg.Msg.FundarLegal, criminal = Cfg.Msg.FundarCriminal, real = Cfg.Msg.FundarReal, delmal = Cfg.Msg.FundarDelMal, neutral = Cfg.Msg.FundarNeutral }
	for i, clave in Cfg.OrdenAlineaciones do
		local t = Cfg.TextosAlineacion[clave]
		local permitida = if permitidas then permitidas[clave] == true else (estado == nil or Cfg.Alineaciones[clave].permite[estado] == true)
		local b = Instance.new("TextButton")
		b.Name = clave
		b.Text = ""
		b.AutoButtonColor = false
		b.BackgroundColor3 = BLANCO
		b.BackgroundTransparency = 1
		b.Position = UDim2.fromOffset(20, FILAS[i] - 6)
		b.Size = UDim2.fromOffset(409, 60)
		b.ZIndex = 3
		b.Parent = f
		label(b, t.titulo, 44, 2, 340, 16, { TextColor3 = COLOR[clave], TextSize = 14 })
		label(b, t.texto, 44, 18, 362, 44, { Font = Enum.Font.Arial, TextSize = 10, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextTransparency = if permitida then 0 else 0.5 })
		Click.entra(b, function()
			b.BackgroundTransparency = 0.9
		end)
		Click.sale(b, function()
			b.BackgroundTransparency = 1
		end)
		Click.activado(b, function()
			if not permitida then
				avisar(MOTIVO[clave] or Cfg.Msg.AlineacionInvalida)
				return
			end
			cerrar("ClanAlineacion")
			pasoNombre(clave)
		end)
	end
	-- Fase 21 (docs/40 §9): la gema se gasta al fundar
	label(f, Cfg.Msg.GemaSeGasta, 24, 324, 316, 20, { Font = Enum.Font.Arial, TextSize = 11, TextColor3 = Color3.fromRGB(230, 200, 120), TextXAlignment = Enum.TextXAlignment.Left })
	Click.activado(generico(f, "Cancelar", 348, 322, 90, 24), function()
		cerrar("ClanAlineacion")
	end)
end

function Clanes.fundar()
	local r = pedir("puedeFundar")
	if r.error then
		avisar(r.error)
		return
	end
	pasoAlineacion(r.estado, r.permitidas)
end

-- ─── El panel (btnClanes) ────────────────────────────────────────────────────
local function itemsClanes(d: any): { { clave: string, texto: string } }
	local r = {}
	for _, c in d.clanes or {} do
		table.insert(r, { clave = c.clave, texto = c.nombre })
	end
	return r
end

local function itemsMiembros(lst: any): { { clave: string, texto: string } }
	local r = {}
	for _, m in lst or {} do
		table.insert(r, { clave = m.llave, texto = m.nombre })
	end
	return r
end

local function buscador(fondo: Instance, nombre: string, x: number, y: number, w: number, h: number, l: Lista)
	local c = caja(fondo, nombre, x, y, w, h, 30)
	c:GetPropertyChangedSignal("Text"):Connect(function()
		l.filtrar(c.Text)
	end)
end

-- 15b-2: bajo el panel, el estado de la elección, "Votar" al miembro elegido y (si el líder no entra hace 30 días)
-- "Abrir elecciones" para los miembros
function Clanes.botonesEleccion(f: Instance, d: any, lm: Lista, y: number)
	local e = d.eleccion
	if not e then
		return
	end
	if e.abierta then
		local horas = math.floor(e.faltan / 3600)
		local minutos = math.floor(e.faltan % 3600 / 60)
		label(f, `Elecciones abiertas: faltan {horas} h {minutos} min.{if e.yaVoto then " Ya votaste." else ""}`, 10, y, 260, 20, { TextColor3 = Color3.fromRGB(255, 255, 0), TextSize = 12 })
		if not e.yaVoto then
			Click.activado(generico(f, "Votar al elegido", 270, y - 4, 120, 26), function()
				local s = lm.seleccion()
				if not s then
					avisar("Elegi en la lista al miembro que queres votar.")
					return
				end
				local r = pedir("votar", s)
				avisar(r.error or r.mensaje)
				Clanes.panel()
			end)
		end
	elseif e.puedeAbrir and d.tipo == "miembro" then
		Click.activado(generico(f, "Abrir elecciones", 270, y - 4, 120, 26), function()
			local r = pedir("elecciones")
			avisar(r.error)
		end)
	end
end

function Clanes.panel()
	local d = pedir("panel")
	if not d or d.error or not d.tipo then
		avisar(d and d.error)
		return
	end
	if d.tipo == "lista" then
		local f = ventana("ClanPanel", UiAssets.clanLista, 271, 370)
		local l = lista(f, "GuildsList", 33, 38, 205, 236)
		l.poner(itemsClanes(d))
		l.alDobleClick = Clanes.detalles
		buscador(f, "txtBuscar", 33, 310, 207, 16, l)
		Click.activado(boton(f, "lista", "Cerrar"), function()
			cerrar("ClanPanel")
		end)
		Click.activado(boton(f, "lista", "Detalles"), function()
			local s = l.seleccion()
			if s then
				Clanes.detalles(s)
			end
		end)
		-- Fundar (nuestro: el original pide escribir /FUNDARCLAN)
		Click.activado(generico(f, "Fundar un clan", 60, 374, 150, 26), Clanes.fundar)
	elseif d.tipo == "miembro" then
		local f = ventana("ClanPanel", UiAssets.clanMiembro, 399, 376)
		local lc = lista(f, "lstClanes", 13, 46, 174, 171)
		lc.poner(itemsClanes(d))
		lc.alDobleClick = Clanes.detalles
		local lm = lista(f, "lstMiembros", 205, 45, 174, 171)
		lm.poner(itemsMiembros(d.miembros))
		buscador(f, "txtSearch", 15, 242, 170, 15, lc)
		label(f, tostring(d.cantidad or 0), 309, 234, 30, 13, { Font = Enum.Font.Arial })
		-- Fase 31 (docs/51, D31-14): en el hueco de "El clan cuenta con __ miembros" entra solo el número; el tope va al
		-- lado del título "Miembros" de la lista: "12 de 38"
		if typeof(d.tope) == "number" then
			label(f, cuantosDe(d.cantidad, d.tope), 264, 22, 114, 16, { Font = Enum.Font.Arial, TextSize = 12, TextColor3 = Color3.fromRGB(252, 203, 130) })
		end
		Click.activado(boton(f, "miembro", "Detalles"), function()
			Clanes.detalles(lc.seleccion() or d.clan.clave)
		end)
		Click.activado(boton(f, "miembro", "Noticias"), function()
			Clanes.noticias({ noticias = d.noticias, eleccion = d.eleccion and d.eleccion.abierta })
		end)
		Clanes.botonesEleccion(f, d, lm, 380)
		Click.activado(boton(f, "miembro", "Cerrar"), function()
			cerrar("ClanPanel")
		end)
		Click.activado(generico(f, "Salir del clan", 200, 280, 185, 25), function()
			task.spawn(function()
				if Dialogo.confirmar(`Salir del clan {d.clan.nombre}?`) then
					local r = pedir("salir")
					avisar(r.error)
					cerrar("ClanPanel")
				end
			end)
		end)
	else
		local f = ventana("ClanPanel", UiAssets.clanLider, 399, 495)
		local lc = lista(f, "guildslist", 12, 36, 173, 93)
		lc.poner(itemsClanes(d))
		lc.alDobleClick = Clanes.detalles
		local lm = lista(f, "members", 204, 36, 173, 93)
		lm.poner(itemsMiembros(d.miembros))
		lm.alDobleClick = abrirFicha
		buscador(f, "txtFiltrarClanes", 13, 156, 172, 16, lc)
		buscador(f, "txtFiltrarMiembros", 205, 156, 172, 15, lm)
		local news = caja(f, "txtguildnews", 13, 229, 365, 46, Cfg.LargoNoticias, true)
		news.Text = d.noticias or ""
		local ls = lista(f, "solicitudes", 13, 340, 173, 54)
		ls.poner(itemsMiembros(d.solicitudes))
		ls.alDobleClick = abrirFicha
		label(f, tostring(d.cantidad or 0), 121, 434, 30, 17, { Font = Enum.Font.Arial })
		-- Fase 31 (docs/51, D31-14): el tope, al lado del título "Miembros" de la lista: "12 de 38". Al líder le llega
		-- el de su Liderazgo de ahora, que es el que se le controla al aceptar.
		if typeof(d.tope) == "number" then
			label(f, cuantosDe(d.cantidad, d.tope), 258, 14, 120, 16, { Font = Enum.Font.Arial, TextSize = 12, TextColor3 = Color3.fromRGB(252, 203, 130) })
		end
		Click.activado(boton(f, "lider", "DetallesClan"), function()
			Clanes.detalles(lc.seleccion() or d.clan.clave)
		end)
		Click.activado(boton(f, "lider", "DetallesMiembros"), function()
			local s = lm.seleccion()
			if s then
				abrirFicha(s)
			end
		end)
		Click.activado(boton(f, "lider", "DetallesSolicitudes"), function()
			local s = ls.seleccion()
			if s then
				abrirFicha(s)
			end
		end)
		Click.activado(boton(f, "lider", "Actualizar"), function()
			local r = pedir("noticias", news.Text)
			avisar(r.error)
		end)
		Click.activado(boton(f, "lider", "EditarCodex"), function()
			local t = pedir("textos")
			if t.error then
				avisar(t.error)
				return
			end
			abrirCodex(t.desc or "", t.codex or {}, function(desc, codex)
				local r = pedir("codex", desc, codex)
				if r.error then
					avisar(r.error)
					return
				end
				cerrar("ClanCodex")
			end)
		end)
		Click.activado(boton(f, "lider", "Cerrar"), function()
			cerrar("ClanPanel")
		end)
		-- 15b-2: elecciones y propuestas
		Click.activado(boton(f, "lider", "Elecciones"), function()
			if d.eleccion and d.eleccion.abierta then
				avisar("Ya hay elecciones abiertas en tu clan. Elegi a un miembro y toca Votar.")
				return
			end
			task.spawn(function()
				if Dialogo.confirmar("Abrir elecciones para elegir al lider? Duran 24 horas.") then
					local r = pedir("elecciones")
					avisar(r.error)
				end
			end)
		end)
		Click.activado(boton(f, "lider", "PropuestasPaz"), function()
			abrirPropuestas("paz")
		end)
		Click.activado(boton(f, "lider", "PropuestasAlianzas"), function()
			abrirPropuestas("alianza")
		end)
		Clanes.botonesEleccion(f, d, lm, 499)
		-- Cerrar el clan (DS15-22 A; /CERRARCLAN): en el lugar del botón de la URL
		Click.activado(generico(f, "Cerrar el clan", 200, 345, 185, 33), function()
			task.spawn(function()
				local ok, escrito = Dialogo.confirmar(`Cerrar el clan {d.clan.nombre}? Se borra para siempre.`, nil, "Escribi el nombre del clan para confirmar")
				if ok and string.lower(escrito) == string.lower(d.clan.nombre) then
					local r = pedir("cerrar")
					avisar(r.error)
					cerrar("ClanPanel")
				end
			end)
		end)
	end
	panelAbierto = true
end

-- ─── Eventos del servidor ────────────────────────────────────────────────────
function Clanes.evento(tipo: string, d: any)
	if tipo == "abrir" then
		Clanes.panel()
	elseif tipo == "fundar" then
		Clanes.fundar()
	elseif tipo == "refrescar" then
		if panelAbierto then
			Clanes.panel()
		end
	elseif tipo == "noticias" then
		Clanes.noticias(d)
	elseif tipo == "aviso" then
		avisar(d)
	end
end

function Clanes.abierta(): boolean
	return next(abiertas) ~= nil
end

-- Cierra todas las ventanas de clanes (Fase 25, docs/44 §9: al volver a la pantalla de personajes)
function Clanes.cerrarTodo()
	local nombres = {}
	for nombre in abiertas do
		table.insert(nombres, nombre)
	end
	for _, nombre in nombres do
		cerrar(nombre)
	end
end


return Clanes
