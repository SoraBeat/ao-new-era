--!strict
--[[
	Skills — la ventana para asignar skillpoints (frmSkills3, docs/21 §7.2), sobre VentanaSkills_spanish.jpg (600×450)
	con los controles del .frm (en px).

	- 20 filas (dos columnas de 10): el valor (Text1), "+" y "−". "+" suma si quedan puntos y el skill no llegó a 100;
	  "−" solo deshace lo que se sumó en esta misma ventana (SumarSkillPoint / RestarSkillPoint, frmSkills3.frm:362-387).
	- Arriba, los puntos libres (puntos). Abajo, la ayuda del skill bajo el mouse (lblHelp) con "* Habilidad
	  inhabilitada para tu clase." donde corresponde (ValidarSkills) y el aviso de Apuñalar (DF12-12 B).
	- "Aceptar" manda lo sumado (WriteModifySkills) y "Cancelar" cierra sin cambios.
	La abre la estrella del HUD (imgAsignarSkill_Click, frmMain.frm:1942-1965).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillsCfg = require(ReplicatedStorage.Shared.Config.Skills)
local Remotes = require(ReplicatedStorage.Shared.Red.Remotes)
local UiAssets = require(ReplicatedStorage.Shared.Generado.UiAssets)
local Click = require(script.Parent.Click)
local Encaje = require(script.Parent.Encaje)

local Skills = {}

local datos: any = { valores = SkillsCfg.vacios(), libres = 0, asignados = 0, clase = "" }
local gui: ScreenGui? = nil

-- Filas del .frm: izquierda (1..10) y derecha (11..20)
local Y_BOTON = { 52, 77, 101, 126, 151, 176, 201, 226, 251, 276 }
local COL = {
	{ menos = 208, valor = 233, mas = 264, etiqueta = 33 },
	{ menos = 484, valor = 509, mas = 540, etiqueta = 313 },
}

function Skills.actualizar(d: any)
	datos = d
end

function Skills.libres(): number
	return datos.libres or 0
end

function Skills.abierta(): boolean
	return gui ~= nil
end

function Skills.cerrar()
	if gui then
		gui:Destroy()
		gui = nil
	end
end

-- Un botón de la hoja botones_skills.png: fila 0 más, 1 menos (20×20); fila 2 aceptar, 3 cancelar (97×24)
local function boton(parent: Instance, fila: number, x: number, y: number): ImageButton
	local grande = fila >= 2
	local w, h = if grande then 97 else 20, if grande then 24 else 20
	local oy = ({ 0, 20, 40, 64 })[fila + 1]
	local b = Instance.new("ImageButton")
	b.BackgroundTransparency = 1
	b.Image = UiAssets.botonesSkills
	b.ImageRectSize = Vector2.new(w, h)
	b.ImageRectOffset = Vector2.new(0, oy)
	b.Position = UDim2.fromOffset(x, y)
	b.Size = UDim2.fromOffset(w, h)
	b.ZIndex = 3
	b.Parent = parent
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
	return b
end

local function label(parent: Instance, t: string, x: number, y: number, w: number, h: number, props: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(x, y)
	l.Size = UDim2.fromOffset(w, h)
	l.Font = Enum.Font.ArialBold
	l.TextSize = 14
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Text = t
	l.ZIndex = 3
	for k, v in props or {} do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

function Skills.abrir()
	Skills.cerrar()
	local g = Instance.new("ScreenGui")
	g.Name = "Skills"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = 45
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local fondo = Instance.new("ImageLabel")
	fondo.BackgroundTransparency = 1
	fondo.Image = UiAssets.skills
	fondo.AnchorPoint = Vector2.new(0.5, 0.5)
	fondo.Position = UDim2.fromScale(0.5, 0.5)
	fondo.Size = UDim2.fromOffset(600, 450)
	fondo.Active = true
	fondo.Parent = g
	Encaje.ventana(fondo, 600, 450, { techo = 1.3 })

	local valores = table.clone(datos.valores)
	local agregados: { [string]: number } = {}
	local libres = datos.libres or 0
	local alocados = libres
	local puntos = label(fondo, tostring(alocados), 320, 10, 60, 24, { TextXAlignment = Enum.TextXAlignment.Left, TextSize = 20, Font = Enum.Font.Garamond })
	local ayuda = label(fondo, "", 44, 318, 513, 75, {
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Enum.Font.Arial,
		TextSize = 13,
	})
	local textos: { [string]: TextLabel } = {}
	local inhabilitadas = SkillsCfg.Inhabilitadas[datos.clase] or {}

	for i, s in SkillsCfg.Lista do
		local col = COL[if i <= 10 then 1 else 2]
		local y = Y_BOTON[(i - 1) % 10 + 1]
		-- Zona de la etiqueta (la imagen de la ventana ya trae el nombre): muestra la ayuda al pasar el mouse
		local zona = Instance.new("TextButton")
		zona.BackgroundTransparency = 1
		zona.Text = ""
		zona.AutoButtonColor = false
		zona.Position = UDim2.fromOffset(col.etiqueta, y - 2)
		zona.Size = UDim2.fromOffset(col.menos - col.etiqueta - 4, 24)
		zona.ZIndex = 2
		zona.Parent = fondo
		Click.entra(zona, function()
			local t = `{s.titulo}:\n{s.ayuda}`
			if inhabilitadas[s.clave] then
				t ..= "\n" .. SkillsCfg.AvisoInhabilitada
			end
			if SkillsCfg.SinEfecto[s.clave] then
				t ..= "\n" .. SkillsCfg.SinEfecto[s.clave]
			end
			ayuda.Text = t
		end)
		Click.sale(zona, function()
			ayuda.Text = ""
		end)
		textos[s.clave] = label(fondo, tostring(valores[s.clave] or 0), col.valor, y + 4, 27, 17, { TextXAlignment = Enum.TextXAlignment.Center })
		local menos = boton(fondo, 1, col.menos, y)
		local mas = boton(fondo, 0, col.mas, y)
		menos.Name, mas.Name = "menos_" .. s.clave, "mas_" .. s.clave
		Click.activado(mas, function()
			if alocados > 0 and (valores[s.clave] or 0) < SkillsCfg.Max then
				valores[s.clave] += 1
				agregados[s.clave] = (agregados[s.clave] or 0) + 1
				alocados -= 1
				textos[s.clave].Text = tostring(valores[s.clave])
				puntos.Text = tostring(alocados)
			end
		end)
		Click.activado(menos, function()
			if alocados < libres and (valores[s.clave] or 0) > 0 and (agregados[s.clave] or 0) > 0 then
				valores[s.clave] -= 1
				agregados[s.clave] -= 1
				alocados += 1
				textos[s.clave].Text = tostring(valores[s.clave])
				puntos.Text = tostring(alocados)
			end
		end)
	end

	local aceptar = boton(fondo, 2, 466, 408)
	local cancelar = boton(fondo, 3, 34, 408)
	aceptar.Name, cancelar.Name = "imgAceptar", "imgCancelar"
	fondo.Name = "Ventana"
	Click.activado(aceptar, function()
		local envio = {}
		local hay = false
		for k, n in agregados do
			if n > 0 then
				envio[k] = n
				hay = true
			end
		end
		if hay then
			Remotes.evento("AsignarSkills"):FireServer(envio)
		end
		Skills.cerrar()
	end)
	Click.activado(cancelar, Skills.cerrar)

	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = g
end

function Skills.alternar()
	if gui then
		Skills.cerrar()
	else
		Skills.abrir()
	end
end

return Skills
