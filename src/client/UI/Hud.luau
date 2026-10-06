--!strict
--[[
	Hud — elige la interfaz según el equipo y apaga la de Roblox que no es de AO (docs/17 §3 y §10).

	- Táctil sin teclado (celular, tableta) → HudTactil (DF9-02 B), siempre horizontal.
	- Si no → HudPC, la ventana del cliente original (DF9-01 A).
	En Studio, el atributo "HudTactil" del Workspace (puesto en modo edición) fuerza el táctil para probarlo.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local HudComun = require(script.Parent.HudComun)
local HudPC = require(script.Parent.HudPC)
local HudTactil = require(script.Parent.HudTactil)
local Diagnostico = require(script.Parent.Diagnostico)
local Opciones = require(script.Parent.Opciones)
local Inventario = require(script.Parent.Inventario)

local Hud = {}

local impl: any = nil

function Hud.esTactil(): boolean
	if RunService:IsStudio() and workspace:GetAttribute("HudTactil") == true then
		return true
	end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function apagarCoreGui()
	-- (el menú de gestos, desde la Fase 34: en el mando Roblox lo abre con la cruceta, que acá camina)
	for _, tipo in { Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Chat, Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Health, Enum.CoreGuiType.EmotesMenu } do
		for _ = 1, 10 do
			if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, tipo, false) then
				break
			end
			task.wait(0.2)
		end
	end
end

function Hud.iniciar(ctx: HudComun.Contexto, controlador: any)
	task.spawn(apagarCoreGui)
	Diagnostico.iniciar()
	Inventario.setClase(ctx.clase, ctx.raza, ctx.genero) -- la "X" roja de lo que no se puede usar (docs/20 §6.6)
	controlador.alOpciones = function()
		Opciones.alternarVentana(controlador) -- F5 o el botón Opciones: audio y, desde ahí, las teclas (docs/29 §5)
	end
	if Hud.esTactil() then
		Players.LocalPlayer:WaitForChild("PlayerGui").ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
		HudTactil.iniciar(ctx, controlador)
		impl = HudTactil
	else
		HudPC.iniciar(ctx, controlador)
		impl = HudPC
	end
	controlador.filtroClick = impl.dentroDeLaVista
	controlador.filtroVista = impl.enLaVista -- la misma pregunta, sin cerrar nada (el puntero del mando, Fase 34)
end

-- Otro personaje en la misma sesión (Fase 25, docs/44 §9: se volvió a la pantalla de personajes y se entró de nuevo)
function Hud.setPersonaje(ctx: HudComun.Contexto)
	Inventario.setClase(ctx.clase, ctx.raza, ctx.genero)
	if impl then
		impl.setNombre(ctx.nombre)
	end
end

-- Muestra u oculta el HUD entero (oculto mientras está la pantalla de personajes: que no se toque nada por detrás)
function Hud.mostrar(si: boolean)
	local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if pg then
		for _, nombre in { "HudAO", "HudAOArriba" } do
			local g = pg:FindFirstChild(nombre)
			if g and g:IsA("ScreenGui") then
				g.Enabled = si
			end
		end
	end
end

-- El mando (Fase 18, docs/37 §7.2): la pestaña del inventario o la de los hechizos, y el rectángulo de la vista
-- tenue: en el celular, la lista de hechizos traslúcida (cuando la abre el mando al cambiar de hechizo: Fase 35)
function Hud.pestana(inventario: boolean, tenue: boolean?)
	if impl then
		impl.pestana(inventario, tenue)
	end
end

-- El panel del celular que está abierto ("inventario", "hechizos" o nil; en la PC, siempre nil), y cerrarlo
function Hud.panelAbierto(): string?
	return if impl then impl.panelAbierto() else nil
end

function Hud.cerrarPanel()
	if impl then
		impl.cerrarPanel()
	end
end

function Hud.panelTenue(): GuiObject?
	return if impl then impl.panelTenue() else nil
end

-- Dónde está en la pantalla una parte del HUD (la marca del tutorial, Fase 22): posición y tamaño, o nil
function Hud.parte(nombre: string): (Vector2?, Vector2?)
	if impl then
		return impl.parte(nombre)
	end
	return nil, nil
end

function Hud.rectVista(): (Vector2, Vector2)
	if impl then
		return impl.rectVista()
	end
	local camara = workspace.CurrentCamera
	local barra = game:GetService("GuiService"):GetGuiInset()
	return Vector2.new(0, -barra.Y), if camara then camara.ViewportSize else Vector2.new(800, 600)
end

-- Tamaño guardado de la consola del celular (docs/23 DN-09); en PC no hace nada
function Hud.setConsola(n: number)
	HudTactil.setConsola(n)
end

-- Fase 33 (docs/53 §5): opacidad del minimapa y de los botones del celular, en % (de Opciones); en PC no hace nada
function Hud.setTransparencia(mini: number, botones: number)
	HudTactil.setTransparencia(mini, botones)
end

-- Fase 38 (docs/58): cómo acomodó el jugador la interfaz del celular (lo guardado, al entrar); en PC no hace nada
function Hud.setInterfazGuardada(g: any)
	HudTactil.setGuardado(g)
end

-- Si la interfaz que se armó es la del celular (antes de armarla, la que tocaría)
function Hud.interfazTactil(): boolean
	if impl then
		return impl == HudTactil
	end
	return Hud.esTactil()
end

function Hud.estadisticas(s: any)
	HudComun.setDopas(s.dopas or 0)
	if impl then
		impl.estadisticas(s)
	end
end

function Hud.paralisis(ticks: number)
	HudComun.setParalisis(ticks)
end

function Hud.invisibilidad(ticks: number)
	HudComun.setInvisibilidad(ticks)
end

-- Fase 13a (docs/22 §2.3): cambio de mapa (minimapa, etiqueta y el nombre que se desvanece)
function Hud.cambiarMapa(n: number, nombre: string)
	if impl then
		impl.cambiarMapa(n, nombre)
	end
	HudComun.mostrarNombreMapa(nombre)
end

function Hud.cartel(texto: string, grh: number)
	HudComun.mostrarCartel(texto, grh)
end

function Hud.viaje(seg: number)
	HudComun.setViaje(seg)
end

return Hud
