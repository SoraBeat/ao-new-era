--!strict
--[[
	HudPC — la ventana del cliente original en PC (DF9-01 A, docs/17 §2 y §4).

	La skin VentanaPrincipal (1024×768, con el hueco de la vista transparente) se escala sin estirar y se centra;
	los controles van en sus posiciones del frmMain (twips / 15) dentro del mismo marco, así que todo escala con
	un UIScale. Fuera de la ventana, bandas negras. La cámara abarca el alto de la pantalla y se corre para que
	el PJ quede en el centro del hueco de la vista (380, 459), que muestra 23×19 tiles.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UiAssets = require(ReplicatedStorage.Shared.Generado.UiAssets)
local Objetos = require(ReplicatedStorage.Shared.Generado.ObjetosInventario)
local ConfigInv = require(ReplicatedStorage.Shared.Config.Inventario)
local Remotes = require(ReplicatedStorage.Shared.Red.Remotes)
local Hud = require(script.Parent.HudComun)
local Boton = require(script.Parent.Boton)
local Consola = require(script.Parent.Consola)
local Chat = require(script.Parent.Chat)
local Inventario = require(script.Parent.Inventario)
local Hechizos = require(script.Parent.Hechizos)
local Estadisticas = require(script.Parent.Estadisticas)
local Tienda = require(script.Parent.Tienda)
local Atajos = require(script.Parent.Atajos)
local Diagnostico = require(script.Parent.Diagnostico)
local Mascotas = require(script.Parent.Mascotas)
local MapaMundo = require(script.Parent.MapaMundo)
local Aliados = require(script.Parent.Aliados)
local ReglasAliados = require(ReplicatedStorage.Shared.Mundo.Aliados)
local Grh = require(script.Parent.Parent.Render.Grh)
local Camara = require(script.Parent.Parent.Render.Camara)
local Mundo = require(script.Parent.Parent.Render.Mundo)
local Click = require(script.Parent.Click)


-- Fase 17a (docs/35 §1.2): los minimapas van de a 100 por hoja (UiAssets.minimapa[n] = { hoja, x, y })
local function ponerMinimapa(label: ImageLabel, n: number)
	local u = (UiAssets :: any).minimapa[n]
	if u then
		label.Image = (UiAssets :: any)[`minimapas{u[1]}`]
		label.ImageRectOffset = Vector2.new(u[2], u[3])
		label.ImageRectSize = Vector2.new(100, 100)
	else
		label.Image = ""
	end
end
local HudPC = {}

local ANCHO, ALTO = 1024, 768
-- Fase 22 (docs/41 §1.2, D22-01 C): la ventana crece 40 px hacia abajo para los atajos, que van debajo de la vista sin
-- tapar nada del mapa. La skin sigue siendo de 1024×768; la franja nueva se dibuja debajo. (barra() de fase22_ref.py)
local FRANJA = 40
local ALTO_TOTAL = ALTO + FRANJA
local ATAJO_CELDA, ATAJO_SEP = 36, 4
local VISTA = { x = 12, y = 155, w = 736, h = 608 } -- MainViewPic
local PJ_X, PJ_Y = 380, 459 -- centro del tile del PJ dentro de la ventana
local AMARILLO_CLARO = Color3.fromRGB(255, 255, 225) -- vbInfoBackground (&H80000018)

local marco: Frame
local escala: UIScale
local bandas: { Frame } = {}
local hueco: Frame
local refs: { [string]: any } = {}
local contexto: Hud.Contexto? = nil

-- ─── Helpers ─────────────────────────────────────────────────────────────────
local function label(nombre: string, x: number, y: number, w: number, h: number, props: { [string]: any }?): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = nombre
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromOffset(x, y)
	t.Size = UDim2.fromOffset(w, h)
	t.Font = Enum.Font.ArialBold
	t.TextSize = 11
	t.TextColor3 = AMARILLO_CLARO
	t.ZIndex = 5
	t.Text = ""
	for k, v in props or {} do
		(t :: any)[k] = v
	end
	t.Parent = marco
	return t
end

local function caja(nombre: string, x: number, y: number, w: number, h: number, color: Color3?, z: number?): Frame
	local f = Instance.new("Frame")
	f.Name = nombre
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.BackgroundColor3 = color or Color3.new(0, 0, 0)
	f.BackgroundTransparency = if color then 0 else 1
	f.BorderSizePixel = 0
	f.ZIndex = z or 4
	f.Parent = marco
	return f
end

-- Barra: el "tapa" negro de ancho - bWidth pegado a la derecha (Red/Protocol.bas:1855-1967)
local function barra(nombre: string, xTapa: number, y: number, ancho: number, alto: number, xl: number, yl: number, wl: number)
	local tapa = caja("Tapa" .. nombre, xTapa, y, ancho, alto, Color3.new(0, 0, 0), 3)
	local t = label("lbl" .. nombre, xl, yl, wl, 12)
	refs[nombre] = { tapa = tapa, texto = t, x = xTapa, ancho = ancho }
end

-- Fase 16a (DR16-02 A): el texto de la barra de hambre o sed titila mientras está en 0
local titilar: { [string]: boolean } = {}
task.spawn(function()
	local on = false
	while true do
		task.wait(0.5)
		on = not on
		for nombre, si in titilar do
			local r = refs[nombre]
			if r then
				r.texto.TextTransparency = if si and on then 1 else 0
				r.texto.TextColor3 = if si then Color3.fromRGB(255, 80, 80) else AMARILLO_CLARO
			end
		end
	end
end)

local function setBarra(nombre: string, minv: number, maxv: number)
	local r = refs[nombre]
	local b = Hud.bWidth(minv, maxv, r.ancho)
	r.tapa.Position = UDim2.fromOffset(r.x + b, r.tapa.Position.Y.Offset)
	r.tapa.Size = UDim2.fromOffset(r.ancho - b, r.tapa.Size.Y.Offset)
	r.tapa.Visible = b ~= r.ancho
	r.texto.Text = `{minv}/{maxv}`
end

-- ─── Escalado, bandas y cámara (docs/17 §2.2) ────────────────────────────────
local function acomodar()
	local camara = workspace.CurrentCamera
	if not camara then
		return
	end
	local vp = camara.ViewportSize
	local W, H = vp.X, vp.Y
	local inset = GuiService:GetGuiInset().Y
	local s = math.min(W / ANCHO, H / ALTO_TOTAL)
	local oy = (H - ALTO_TOTAL * s) / 2
	-- Sin bandas a los costados, el botón de Roblox caería sobre la consola: la ventana baja lo que mide la barra
	if (W - ANCHO * s) / 2 < 60 then
		s = math.min(W / ANCHO, (H - inset) / ALTO_TOTAL)
		oy = inset
	end
	local ox = (W - ANCHO * s) / 2
	escala.Scale = s
	marco.Position = UDim2.fromOffset(ox, oy)
	-- Bandas: izquierda, derecha, arriba, abajo
	local fw, fh = ANCHO * s, ALTO_TOTAL * s
	local rects = { { 0, 0, ox, H }, { ox + fw, 0, W - ox - fw, H }, { ox, 0, fw, oy }, { ox, oy + fh, fw, H - oy - fh } }
	for i, r in rects do
		bandas[i].Position = UDim2.fromOffset(r[1], r[2])
		bandas[i].Size = UDim2.fromOffset(math.ceil(r[3]) + 1, math.ceil(r[4]) + 1)
	end
	-- Cámara: el alto de la pantalla en tiles y el corrimiento para centrar el PJ en el hueco de la vista
	local tile = 32 * s
	local pjx, pjy = ox + PJ_X * s, oy + PJ_Y * s
	Camara.configurar(H / tile, (W / 2 - pjx) / tile, (H / 2 - pjy) / tile)
	Mundo.setVista(23, 19)
end

-- ¿El punto (coordenadas de InputObject) cae en el hueco de la vista?
function HudPC.dentroDeLaVista(pos: Vector2): boolean
	local p, t = hueco.AbsolutePosition, hueco.AbsoluteSize
	return pos.X >= p.X and pos.X < p.X + t.X and pos.Y >= p.Y and pos.Y < p.Y + t.Y
end

HudPC.enLaVista = HudPC.dentroDeLaVista -- (en la PC preguntar no cambia nada; en el celular, sí: ver HudTactil)

-- ─── Pestañas (frmMain.frm:2708-2742) ────────────────────────────────────────
local function pestana(inventario: boolean)
	refs.picInv.Visible = inventario
	refs.hlst.Visible = not inventario
	refs.btnLanzar.Visible = not inventario
	refs.btnInfo.Visible = not inventario
	refs.subir.Visible = not inventario
	refs.bajar.Visible = not inventario
end

-- El mando (Fase 18, docs/37 §7.2): al cambiar el objeto o el hechizo, la pestaña que corresponde
function HudPC.pestana(inventario: boolean, _tenue: boolean?)
	if refs.picInv then
		pestana(inventario)
	end
end

-- (en la PC el inventario y los hechizos están siempre a la vista, en el costado: no hay panel que cerrar)
function HudPC.panelAbierto(): string?
	return nil
end

function HudPC.cerrarPanel() end

function HudPC.panelTenue(): GuiObject?
	return nil
end

-- El hueco de la vista en la pantalla: posición y tamaño (la tira de ayuda del mando va abajo)
function HudPC.rectVista(): (Vector2, Vector2)
	return hueco.AbsolutePosition, hueco.AbsoluteSize
end

-- Dónde está en la pantalla una parte del HUD, para la marca del tutorial (Fase 22, docs/41 §6): posición y tamaño,
-- o nil si no está a la vista. En px de la ventana de 1024×808, llevados a la pantalla.
local PARTES: { [string]: { number } } = {
	barras = { 792, 498, 208, 70 },
	inventario = { 806, 166, 170, 233 },
	hechizos = { 896, 128, 89, 33 },
	macros = { 178, 766, 404, 44 },
	consola = { 8, 20, 628, 111 },
}
function HudPC.parte(nombre: string): (Vector2?, Vector2?)
	if not marco then
		return nil, nil
	end
	if nombre == "estrella" then
		local e = refs.estrella
		if e and e.Visible then
			return e.AbsolutePosition, e.AbsoluteSize
		end
		return nil, nil
	end
	local r = PARTES[nombre]
	if not r then
		return nil, nil
	end
	local s = marco.AbsoluteSize.X / ANCHO
	return marco.AbsolutePosition + Vector2.new(r[1], r[2]) * s, Vector2.new(r[3], r[4]) * s
end

-- ─── Arranque ────────────────────────────────────────────────────────────────
function HudPC.iniciar(ctx: Hud.Contexto, controlador: any)
	local gui = Instance.new("ScreenGui")
	gui.Name = "HudAO"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	for i = 1, 4 do
		local b = Instance.new("Frame")
		b.Name = "Banda"
		b.BackgroundColor3 = Color3.new(0, 0, 0)
		b.BorderSizePixel = 0
		b.Parent = gui
		bandas[i] = b
	end

	marco = Instance.new("Frame")
	marco.Name = "Ventana"
	marco.BackgroundTransparency = 1
	marco.Size = UDim2.fromOffset(ANCHO, ALTO_TOTAL)
	marco.Parent = gui
	escala = Instance.new("UIScale")
	escala.Parent = marco

	local skin = Instance.new("ImageLabel")
	skin.Name = "Skin"
	skin.BackgroundTransparency = 1
	skin.Size = UDim2.fromOffset(ANCHO, ALTO)
	skin.Image = UiAssets.ventana
	skin.ZIndex = 1
	skin.Parent = marco

	hueco = caja("Vista", VISTA.x, VISTA.y, VISTA.w, VISTA.h, nil, 1)

	-- La franja de los atajos, debajo de la skin: el mismo marco de los botones, estirado
	local franja = Boton.marco(marco, UDim2.fromOffset(0, ALTO), UDim2.fromOffset(ANCHO, FRANJA))
	franja.Name = "FranjaAtajos"
	franja.ZIndex = 2

	-- Consola (RecTxt)
	local rec = caja("RecTxt", 8, 20, 628, 111, Color3.new(0, 0, 0), 2)
	Consola.montar(rec, { tamTexto = 11, barra = 8 })
	-- SendTxt (frmMain.frm): la caja para escribir, arriba de la vista; Enter la abre (docs/23 DN-06 A)
	Chat.montar(marco, UDim2.fromOffset(24, 160), UDim2.fromOffset(713, 24), 13)

	-- Minimapa (DF9-09 A): punto amarillo del PJ y el rectángulo de la vista (frmMain.frm:3170-3184)
	local mini = Instance.new("ImageLabel")
	mini.Name = "MiniMapa"
	mini.BackgroundTransparency = 1
	mini.Position = UDim2.fromOffset(645, 28)
	mini.Size = UDim2.fromOffset(100, 100)
	ponerMinimapa(mini, ctx.mapa)
	mini.ResampleMode = Enum.ResamplerMode.Pixelated
	mini.ClipsDescendants = true
	mini.ZIndex = 2
	mini.Parent = marco
	local area = Instance.new("Frame")
	area.BackgroundTransparency = 1
	area.Size = UDim2.fromOffset(25, 21)
	area.ZIndex = 3
	area.Parent = mini
	local borde = Instance.new("UIStroke")
	borde.Color = Color3.fromRGB(153, 180, 209) -- ActiveTitle de Windows
	borde.Thickness = 1
	borde.Parent = area
	local punto = Instance.new("Frame")
	punto.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
	punto.BorderSizePixel = 0
	punto.Size = UDim2.fromOffset(3, 3)
	punto.ZIndex = 4
	punto.Parent = mini
	refs.miniArea, refs.miniPunto, refs.mini = area, punto, mini
	-- Fase 24 (docs/43 §4): los aliados que están en este mapa, party en verde y clan en azul
	Aliados.alCambiar(HudPC.aliados)
	-- Fase 17a (docs/35 §5, pedido del autor): tocar el minimapa abre el mapa del mundo
	local abrirMapa = Instance.new("TextButton")
	abrirMapa.Name = "AbrirMapa"
	abrirMapa.BackgroundTransparency = 1
	abrirMapa.Text = ""
	abrirMapa.Size = UDim2.fromScale(1, 1)
	abrirMapa.ZIndex = 5
	abrirMapa.Parent = mini
	Click.activado(abrirMapa, function()
		MapaMundo.abrir()
	end)

	-- Textos de arriba
	refs.mapName = label("lblMapName", 328, 136, 417, 17, { Text = ctx.mapaNombre, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Right })
	contexto = ctx
	HudPC.aliados() -- la lista que haya llegado antes de armar el HUD (Fase 24)
	-- Fase 13a: el nombre del mapa arriba de la vista, el cartel en su centro y el botón Hogar abajo a la derecha
	Hud.montarNombreMapa(marco, UDim2.fromOffset(VISTA.x + VISTA.w / 2, VISTA.y + 50), 16)
	Hud.montarCartel(marco, UDim2.fromOffset(VISTA.x + VISTA.w / 2, VISTA.y + VISTA.h / 2))
	Hud.montarHogar(marco, UDim2.fromOffset(VISTA.x + VISTA.w - 128, VISTA.y + VISTA.h - 44), UDim2.fromOffset(120, 36), 14)
	-- Fase 25 (docs/44 §7 y §9): el botón "Elegí tu camino", arriba a la derecha de la vista, y la cuenta de /SALIR
	Hud.montarCamino(marco, UDim2.fromOffset(VISTA.x + VISTA.w - 158, VISTA.y + 34), UDim2.fromOffset(150, 32), 13)
	Hud.montarSalida(marco, UDim2.fromOffset(VISTA.x + VISTA.w / 2, VISTA.y + 78), 18)
	refs.fps = label("lblFPS", 431, 2, 53, 12)
	refs.nombre = label("lblName", 800, 22, 199, 17, { Text = ctx.nombre, TextColor3 = Color3.fromRGB(192, 192, 255) })
	label("Label6", 832, 83, 31, 15, { Text = "Nivel" })
	refs.nivel = label("lblLvl", 872, 83, 18, 15, { Font = Enum.Font.Code, TextSize = 16, TextColor3 = Color3.new(1, 1, 1), Text = "" })
	-- La estrella de skills (imgAsignarSkill, frmMain.frm:764-770 y :1519-1526): se ve con skillpoints libres
	local estrella = Instance.new("ImageButton")
	estrella.Name = "imgAsignarSkill"
	estrella.BackgroundTransparency = 1
	estrella.Image = UiAssets.estrella
	estrella.Position = UDim2.fromOffset(880, 48)
	estrella.Size = UDim2.fromOffset(30, 30)
	estrella.ZIndex = 5
	estrella.Visible = false
	estrella.Parent = marco
	Click.activado(estrella, function()
		if ctx.abrirSkills then
			ctx.abrirSkills()
		end
	end)
	refs.estrella = estrella
	refs.porc = label("lblPorcLvl", 920, 85, 60, 15, { TextColor3 = Color3.fromRGB(0, 255, 255), TextXAlignment = Enum.TextXAlignment.Left })
	-- Barra de experiencia (uAOProgress: relleno (128, 64, 64), borde negro, texto exp/ELU)
	local exp = caja("uAOProgressExperienceLevel", 816, 100, 161, 17, nil, 3)
	local expBorde = Instance.new("UIStroke")
	expBorde.Color = Color3.new(0, 0, 0)
	expBorde.Parent = exp
	local expRelleno = Instance.new("Frame")
	expRelleno.BackgroundColor3 = Color3.fromRGB(128, 64, 64)
	expRelleno.BorderSizePixel = 0
	expRelleno.Size = UDim2.fromScale(0, 1)
	expRelleno.ZIndex = 3
	expRelleno.Parent = exp
	refs.expRelleno = expRelleno
	refs.expTexto = label("lblExp", 816, 100, 161, 17)
	-- El reloj de la Poción de Experiencia (Fase 23, docs/42 §10): debajo de la barra, solo mientras dura
	Hud.montarRelojExp(label("lblExpBoost", 816, 118, 161, 14))

	-- Pestañas, inventario y hechizos
	local bInv = Boton.nuevo(marco, "Inventario", UDim2.fromOffset(792, 128), UDim2.fromOffset(97, 33), { tamTexto = 16 })
	local bHech = Boton.nuevo(marco, "Hechizos", UDim2.fromOffset(896, 128), UDim2.fromOffset(89, 33), { tamTexto = 16 })
	bInv.ZIndex, bHech.ZIndex = 5, 5
	local picInv = caja("picInv", 811, 170, 160, 225, nil, 5)
	Inventario.montar(picInv, { celda = 32, columnas = 5, cantidad = ConfigInv.Slots, tamTexto = 10, tooltip = true })
	local hlst = caja("hlst", 801, 170, 179, 186, nil, 5)
	Hechizos.montar(hlst, { fila = 13, tamTexto = 11 })
	local bLanzar = Boton.nuevo(marco, "Lanzar", UDim2.fromOffset(792, 376), UDim2.fromOffset(81, 33), { tamTexto = 16 })
	local bInfo = Boton.nuevo(marco, "Info", UDim2.fromOffset(912, 376), UDim2.fromOffset(81, 33), { tamTexto = 16 })
	refs.picInv, refs.hlst, refs.btnLanzar, refs.btnInfo = picInv, hlst, bLanzar, bInfo
	-- Flechas para mover hechizos (cmdMoverHechi: subir en 986,247 y bajar en 986,264; 15×16)
	for _, f in { { "cmdMoverHechiSubir", UiAssets.flechaSubir, 247, true }, { "cmdMoverHechiBajar", UiAssets.flechaBajar, 264, false } } do
		local b = Instance.new("ImageButton")
		b.Name = f[1]
		b.BackgroundTransparency = 1
		b.Image = f[2]
		b.ResampleMode = Enum.ResamplerMode.Pixelated
		b.Position = UDim2.fromOffset(986, f[3])
		b.Size = UDim2.fromOffset(15, 16)
		b.ZIndex = 5
		b.Parent = marco
		Click.activado(b, function()
			Hechizos.mover(f[4])
		end)
		if f[4] then
			refs.subir = b
		else
			refs.bajar = b
		end
	end
	-- Los atajos (Fase 22, docs/41 §1): diez casilleros centrados debajo de la vista. Un casillero vacío guarda lo
	-- elegido en la pestaña que esté abierta.
	local anchoAtajos = 10 * ATAJO_CELDA + 9 * ATAJO_SEP
	Atajos.montar(marco, VISTA.x + (VISTA.w - anchoAtajos) // 2, ALTO + (FRANJA - ATAJO_CELDA) // 2, ATAJO_CELDA, ATAJO_SEP, controlador, function(): (string?, number?)
		if refs.hlst.Visible then
			local _, id = Hechizos.seleccionado()
			return "h", id
		end
		local _, d = Inventario.seleccionado()
		return "o", if d then d.obj else nil
	end)
	Click.activado(bInv, function()
		pestana(true)
	end)
	Click.activado(bHech, function()
		pestana(false)
	end)
	Click.activado(bLanzar, function()
		Hechizos.lanzar(ctx.lanzar)
	end)
	Click.activado(bInfo, function()
		Hechizos.info()
	end)
	pestana(true)

	-- Atributos y oro (fuerza y agilidad: getStrenghtColor / getDexterityColor, General.bas:1277-1290)
	refs.dext = label("lblDext", 816, 462, 14, 14)
	refs.strg = label("lblStrg", 857, 462, 14, 14)
	refs.oro = label("GldLbl", 944, 468, 60, 14, { TextXAlignment = Enum.TextXAlignment.Left })
	Hud.montarTocarOro(marco, UDim2.fromOffset(920, 462), UDim2.fromOffset(86, 26)) -- el oro y su ícono (docs/22 §7.2)

	-- Barras: energía, hambre y sed (83 px), maná y vida (90 px). Hambre y sed desde la Fase 16a (DR16-03 A)
	barra("Energia", 797, 504, 83, 12, 800, 504, 81)
	barra("Hambre", 797, 526, 83, 12, 800, 526, 81)
	barra("Sed", 797, 547, 83, 12, 800, 547, 81)
	barra("Mana", 902, 515, 90, 17, 904, 516, 89)
	barra("Vida", 902, 545, 90, 17, 904, 546, 89)

	-- Equipo: min/max de defensa y ataque (Red/Protocol.bas:3355-3373), de lo equipado en el inventario (Fase 11)
	local f975 = Enum.Font.ArialBold
	local lblEq = {
		armadura = label("lblArmor", 824, 677, 65, 17, { TextColor3 = Color3.fromRGB(255, 128, 128), Font = f975, TextSize = 13 }),
		escudo = label("lblShielder", 928, 677, 65, 17, { TextColor3 = Color3.fromRGB(128, 255, 255), Font = f975, TextSize = 13 }),
		casco = label("lblHelm", 824, 707, 65, 17, { TextColor3 = Color3.fromRGB(255, 128, 0), Font = f975, TextSize = 13 }),
		arma = label("lblWeapon", 928, 707, 65, 17, { TextColor3 = Color3.fromRGB(255, 0, 0), Font = f975, TextSize = 13 }),
	}
	local function pintarEquipo()
		local eq = { arma = "0/0", armadura = "0/0", escudo = "0/0", casco = "0/0" }
		for _, d in Inventario.slots() do
			local o = Objetos[d.obj]
			if o and d.equipado and eq[o.tipo] then
				eq[o.tipo] = if o.tipo == "arma" then `{o.minHit}/{o.maxHit}` else `{o.minDef}/{o.maxDef}`
			end
		end
		for tipo, l in lblEq do
			l.Text = eq[tipo]
		end
	end
	pintarEquipo()
	Inventario.alCambiarInventario(pintarEquipo)

	-- Opciones (btnOpciones, frmMain.frm:383-409): por ahora abre directo la configuración de teclas (docs/20 §4.3)
	local bOpciones = Boton.nuevo(marco, "Opciones", UDim2.fromOffset(896, 616), UDim2.fromOffset(97, 17), { tamTexto = 12 })
	bOpciones.ZIndex = 5
	Click.activado(bOpciones, function()
		if controlador.alOpciones then
			controlador.alOpciones()
		end
	end)

	-- Grupo (btnGrupo, frmMain.frm:356-383 y :1991-1994): pide la ventana de la party (docs/28 §2.3)
	local bGrupo = Boton.nuevo(marco, "Grupo", UDim2.fromOffset(792, 592), UDim2.fromOffset(97, 17), { tamTexto = 12 })
	bGrupo.Name = "btnGrupo"
	bGrupo.ZIndex = 5
	Click.activado(bGrupo, function()
		Remotes.evento("Comando"):FireServer("GRUPO")
	end)

	-- Estadísticas (btnEstadisticas, frmMain.frm:410-420; Fase 22, docs/41 §3): en el lugar del original, que estaba
	-- vacío
	local bEstadisticas = Boton.nuevo(marco, "Estadísticas", UDim2.fromOffset(792, 616), UDim2.fromOffset(97, 17), { tamTexto = 12 })
	bEstadisticas.Name = "btnEstadisticas"
	bEstadisticas.ZIndex = 5
	Click.activado(bEstadisticas, function()
		Estadisticas.abrir()
	end)

	-- Clanes (btnClanes, frmMain.frm:437-463 y :1964-1968): el panel de clanes (docs/28 §3)
	local bClanes = Boton.nuevo(marco, "Clanes", UDim2.fromOffset(792, 640), UDim2.fromOffset(97, 17), { tamTexto = 12 })
	bClanes.Name = "btnClanes"
	bClanes.ZIndex = 5
	Click.activado(bClanes, function()
		Remotes.evento("Comando"):FireServer("CLANES")
	end)

	-- Quests (btnQuests, frmMain.frm:628-637 y :1408-1410; Fase 20, docs/39 §2.6): la lista de las misiones activas
	local bQuests = Boton.nuevo(marco, "Quests", UDim2.fromOffset(896, 640), UDim2.fromOffset(97, 17), { tamTexto = 12 })
	bQuests.Name = "btnQuests"
	bQuests.ZIndex = 5
	Click.activado(bQuests, function()
		Remotes.evento("Comando"):FireServer("INFOQUEST")
	end)

	-- Tienda (Fase 23, docs/42 §8.4, D23-50 A): nuestro, arriba de los seis del original. Fase 26: a la izquierda,
	-- con la Guía al lado
	local bTienda = Boton.nuevo(marco, "Tienda", UDim2.fromOffset(792, 568), UDim2.fromOffset(97, 17), { tamTexto = 12 })
	bTienda.Name = "btnTienda"
	bTienda.ZIndex = 5
	Click.activado(bTienda, function()
		Tienda.abrir()
	end)

	-- Guía (Fase 26, docs/46 §10; pedido del autor): la guía del juego, a mano mientras se juega
	local bGuia = Boton.nuevo(marco, "Guía", UDim2.fromOffset(896, 568), UDim2.fromOffset(97, 17), { tamTexto = 12 })
	bGuia.Name = "btnGuia"
	bGuia.ZIndex = 5
	Click.activado(bGuia, function()
		if controlador.alGuia then
			controlador.alGuia()
		end
	end)

	-- Retos (docs/28 §14): el original solo tenía /RETOS; un botón para abrir la ventana sin tipear
	local bRetos = Boton.nuevo(marco, "Retos", UDim2.fromOffset(896, 592), UDim2.fromOffset(97, 17), { tamTexto = 12 })
	bRetos.Name = "btnRetos"
	bRetos.ZIndex = 5
	Click.activado(bRetos, function()
		Remotes.evento("Comando"):FireServer("RETOS")
	end)

	refs.coord = label("Coord", 786, 744, 97, 17, { Font = Enum.Font.Code, TextSize = 9, TextColor3 = Color3.fromRGB(255, 255, 0) })

	-- Seguro (picSM(1)): 4979 puesto / 4983 sacado; doble click lo cambia (frmMain.frm:2192-2200)
	local sm = Instance.new("ImageButton")
	sm.Name = "picSM1"
	sm.BackgroundTransparency = 1
	sm.AutoButtonColor = false
	sm.Position = UDim2.fromOffset(914, 731)
	sm.Size = UDim2.fromOffset(28, 30)
	sm.ResampleMode = Enum.ResamplerMode.Pixelated
	sm.ZIndex = 5
	sm.Parent = marco
	refs.seguro = sm
	local ultimo = 0
	Click.activado(sm, function()
		local ahora = os.clock()
		if ahora - ultimo < 0.5 then
			ultimo = 0
			ctx.seguro()
		else
			ultimo = ahora
		end
	end)
	HudPC.setSeguro(true)

	-- Macro de trabajo (picSM(3), frmMain.frm:98-112): 4981 prendido / 4985 apagado. Fase 16b (docs/32 §7): se prende
	-- con F8 o con una cola de construcción en curso; un click lo apaga
	local macro = Instance.new("ImageButton")
	macro.Name = "picSM3"
	macro.BackgroundTransparency = 1
	macro.AutoButtonColor = false
	macro.Position = UDim2.fromOffset(968, 731)
	macro.Size = UDim2.fromOffset(28, 30)
	macro.ResampleMode = Enum.ResamplerMode.Pixelated
	macro.ZIndex = 5
	macro.Parent = marco
	local function pintarMacro(on: boolean)
		Grh.aplicar(macro, if on then 4981 else 4985)
		macro.Size = UDim2.fromOffset(28, 30)
	end
	pintarMacro(false)
	controlador.alCambiarMacro = function(estadoMacro: string)
		pintarMacro(estadoMacro == "activo")
	end
	Click.activado(macro, function()
		controlador.alternarMacro()
	end)

	-- Parálisis: "N segundos restantes de Paralisis" en (4, 10) de la vista (TileEngine.bas:1134-1136)
	refs.paralisis = label("Paralisis", VISTA.x + 4, VISTA.y + 10, 400, 14, {
		TextColor3 = Color3.fromRGB(230, 230, 250),
		TextTransparency = 1 - 180 / 255,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	-- Invisibilidad (Fase 14b): en (4, 25), Color_Invisibilidad ARGB(180, 236, 136, 66) (mDx8_Engine.bas:288)
	refs.invisibilidad = label("Invisibilidad", VISTA.x + 4, VISTA.y + 25, 400, 14, {
		TextColor3 = Color3.fromRGB(236, 136, 66),
		TextTransparency = 1 - 180 / 255,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	-- Atributos de pociones y hechizos (correcciones de la 14b): en (4, 40), mismo color
	refs.dopas = label("Dopas", VISTA.x + 4, VISTA.y + 40, 400, 14, {
		TextColor3 = Color3.fromRGB(236, 136, 66),
		TextTransparency = 1 - 180 / 255,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	-- Panel de diagnóstico (F3, DF10-02 B): abajo a la izquierda de la vista
	Diagnostico.montar(marco, UDim2.fromOffset(VISTA.x + 4, VISTA.y + VISTA.h - 4), Vector2.new(0, 1), controlador.descartes, 11)
	-- Fase 16c (docs/33 §6): la ventana Mascotas, arriba a la izquierda de la vista, debajo de los avisos de estado
	Mascotas.montar(marco, UDim2.fromOffset(VISTA.x + 4, VISTA.y + 60))

	acomodar()
	local camara = workspace.CurrentCamera
	if camara then
		camara:GetPropertyChangedSignal("ViewportSize"):Connect(acomodar)
	end

	local frames, acumulado = 0, 0
	RunService.RenderStepped:Connect(function(dt)
		frames += 1
		acumulado += dt
		if acumulado >= 0.5 then
			refs.fps.Text = tostring(math.floor(frames / acumulado + 0.5))
			frames, acumulado = 0, 0
		end
		local x, y = ctx.posicion()
		local tx, ty = math.floor(x + 0.5), math.floor(y + 0.5)
		refs.coord.Text = `Map:{ctx.mapa} X:{tx} Y:{ty}`
		refs.miniPunto.Position = UDim2.fromOffset(tx - 2, ty - 2)
		refs.miniArea.Position = UDim2.fromOffset(tx - 13, ty - 11)
		refs.paralisis.Text = Hud.textoParalisis()
		refs.invisibilidad.Text = Hud.textoInvisibilidad()
		local texto, aviso = Hud.textoDopas()
		local apagado = aviso and Hud.titilaApagado()
		refs.dopas.Text = if apagado then "" else texto
		refs.strg.TextTransparency = if apagado then 0.85 else 0
		refs.dext.TextTransparency = if apagado then 0.85 else 0
	end)
end

-- Fase 24 (docs/43 §4): los puntos de los aliados en el minimapa. Un punto de 3×3 con borde negro (el verde se
-- pierde sobre el bosque y el azul sobre el mar) por cada aliado que está en el mapa del jugador; debajo del punto
-- propio y del botón que abre el mapa del mundo. Se llama al llegar una lista nueva y al cambiar de mapa.
local puntosAliados: { Frame } = {}
function HudPC.aliados()
	local mini, ctx = refs.mini, contexto
	if not mini or not ctx then
		return
	end
	local n = 0
	for _, a in Aliados.lista() do
		if a.mapa == ctx.mapa then
			n += 1
			local p = puntosAliados[n]
			if not p then
				p = Instance.new("Frame")
				p.Name = "Aliado"
				p.BorderSizePixel = 0
				p.Size = UDim2.fromOffset(3, 3)
				p.ZIndex = 3
				local borde = Instance.new("UIStroke")
				borde.Color = Color3.new(0, 0, 0)
				borde.Thickness = 1
				borde.Parent = p
				p.Parent = mini
				puntosAliados[n] = p
			end
			local x, y = ReglasAliados.puntoMinimapa(a.x, a.y)
			p.Position = UDim2.fromOffset(x, y)
			p.BackgroundColor3 = Aliados.color(a.tipo)
			p.Visible = true
		end
	end
	for i = n + 1, #puntosAliados do
		puntosAliados[i].Visible = false
	end
end

-- Fase 13a: al cambiar de mapa, el minimapa y el nombre
-- Otro personaje en la misma sesión (Fase 25, docs/44 §9): su nombre en la ventana
function HudPC.setNombre(nombre: string)
	if refs.nombre then
		refs.nombre.Text = nombre
	end
end

function HudPC.cambiarMapa(n: number, nombre: string)
	local ctx = contexto
	if ctx then
		ctx.mapa, ctx.mapaNombre = n, nombre
	end
	ponerMinimapa(refs.mini, n)
	refs.mapName.Text = nombre
	HudPC.aliados()
end

function HudPC.setSeguro(puesto: boolean)
	local sm = refs.seguro
	if sm then
		Grh.aplicar(sm, if puesto then 4979 else 4983)
		sm.Size = UDim2.fromOffset(28, 30)
	end
end

function HudPC.estadisticas(s: any)
	setBarra("Vida", s.hp, s.maxHp)
	setBarra("Mana", s.mana, s.maxMana)
	setBarra("Energia", s.sta, s.maxSta)
	setBarra("Hambre", s.hambre or 100, 100)
	setBarra("Sed", s.sed or 100, 100)
	titilar.Hambre = (s.hambre or 100) <= 0 -- DR16-02 A: en 0 la barra titila
	titilar.Sed = (s.sed or 100) <= 0
	local oro = s.oro or 0
	refs.oro.Text = tostring(oro)
	local elv = s.elv or 1
	refs.oro.TextColor3 = Hud.colorOro(oro, elv)
	refs.nivel.Text = tostring(elv)
	local exp, elu = s.exp or 0, s.elu or 0
	refs.porc.Text = Hud.porcentajeExp(exp, elu)
	refs.expTexto.Text = if elu > 0 then `{exp}/{elu}` else ""
	refs.expRelleno.Size = UDim2.fromScale(if elu > 0 then math.clamp(exp / elu, 0, 1) else 1, 1)
	Hud.setExpBoost(s.expBoost)
	local fz, ag = s.fuerza or 0, s.agilidad or 0
	refs.strg.Text, refs.strg.TextColor3 = tostring(fz), Hud.colorFuerza(fz)
	refs.dext.Text, refs.dext.TextColor3 = tostring(ag), Hud.colorAgilidad(ag)
	refs.estrella.Visible = (s.skillPts or 0) > 0
	HudPC.setSeguro(s.seguro)
	Hud.setMuerto(s.muerto == true)
end

return HudPC
