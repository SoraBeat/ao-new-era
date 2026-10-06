--!strict
--[[
	Chat — la caja para hablar (SendTxt de frmMain; docs/23 DN-06 A).

	- Enter abre la caja y la enfoca; Enter envía y la cierra; Enter con la caja vacía solo la cierra. ESC (o tocar
	  afuera) la cierra sin enviar y guarda lo escrito para la próxima (nuestro).
	- Parseo (ProtocolCmdParse.bas:59-1808): "/COMANDO" va por el remote Comando (no lo ve nadie), "\nick texto" es
	  un susurro (el nick con + en lugar de espacios), "-texto" es un grito y el resto se habla.
	- Hablar y gritar van por el canal "AO" de TextChatService; el susurro, por el canal privado que abre el servidor
	  (remote Susurrar). El tipo va en Metadata (hablar, gritar, muerto, susurro). Lo recibe Main (MessageReceived).
	- Mientras está abierta avisa "escribiendo" (los puntitos).
	- En el celular la abre el botón Chat del HUD (Chat.abrir).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config.Chat)
local Remotes = require(ReplicatedStorage.Shared.Red.Remotes)

local Chat = {}

local caja: TextBox? = nil
local cerradaEn = -1e9
local escribiendoAvisado = false

-- Lo pone Main: si hay otra ventana tomando el teclado (teclas, cantidad, diálogos)
Chat.bloqueada = nil :: (() -> boolean)?
-- Lo pone Main: avisos en la consola ("info")
Chat.aviso = nil :: ((string) -> ())?
-- Los pone Main (Fase 23, docs/42): /REGLAS abre la ventana de reglas; /DENUNCIAR nick, la de la denuncia
Chat.alReglas = nil :: (() -> ())?
Chat.alTienda = nil :: (() -> ())? -- /TIENDA (Fase 23, docs/42 §8.4)
Chat.alDenunciar = nil :: ((string) -> ())?
Chat.alCamino = nil :: (() -> ())? -- /CAMINO (Fase 25, docs/44 §7)
Chat.alGuia = nil :: (() -> ())? -- /GUIA (Fase 25, docs/44 §11)

local muerto = false
function Chat.setMuerto(si: boolean)
	muerto = si
end

local function avisar(texto: string)
	local f = Chat.aviso
	if f then
		f(texto)
	end
end

-- Manda por un canal de TextChatService (CanalesAO.<nombre>); el tipo va en Metadata y el servidor lo valida
local function mandar(nombreCanal: string, texto: string, tipo: string)
	task.spawn(function()
		local carpeta = TextChatService:WaitForChild("CanalesAO", 5)
		local canal = carpeta and carpeta:WaitForChild(nombreCanal, 5)
		if not canal or not canal:IsA("TextChannel") then
			avisar(Config.MsgNoEnviado)
			return
		end
		local ok = pcall(function()
			(canal :: TextChannel):SendAsync(texto, tipo)
		end)
		if not ok then
			avisar(Config.MsgNoEnviado)
		end
	end)
end

local function avisarEscribiendo(si: boolean)
	if si ~= escribiendoAvisado then
		escribiendoAvisado = si
		Remotes.evento("Escribiendo"):FireServer(si)
	end
end

local function enviar(texto: string)
	local t = string.match(texto, "^%s*(.-)%s*$") or ""
	if t == "" then
		-- "Cartelear": Enter, espacio, Enter borra el globo propio (lo escrito o las palabras mágicas). Enter con la caja
		-- vacía solo la cierra, como el original (LenB(stxtbuffer) <> 0, frmMain).
		if texto ~= "" then
			Remotes.evento("Cartelear"):FireServer()
		end
		return
	end
	local primero = string.sub(t, 1, 1)
	if primero == "/" then
		local cmd, arg = string.match(t, "^/(%S+)%s*(.-)$")
		if cmd then
			cmd = string.upper(cmd)
			if cmd == "CMSG" then
				-- Chat de clan (Fase 23, docs/42 §3.4): va por el canal del clan del chat de Roblox, como el de grupo
				local canal = Players.LocalPlayer:GetAttribute("AOClan")
				if arg ~= "" and typeof(canal) == "string" then
					mandar(canal, string.sub(arg, 1, 160), "clan")
				end -- sin clan no pasa nada, como el original
			elseif cmd == "REGLAS" then
				local f = Chat.alReglas
				if f then
					f()
				end
			elseif cmd == "TIENDA" then
				local f = Chat.alTienda
				if f then
					f()
				end
			elseif cmd == "CAMINO" then
				-- Fase 25 (docs/44 §7): la ventana para elegir ciudadano, neutral o criminal, si quedó pendiente
				local f = Chat.alCamino
				if f then
					f()
				end
			elseif cmd == "GUIA" then
				-- Fase 25 (docs/44 §11): la guía del juego
				local f = Chat.alGuia
				if f then
					f()
				end
			elseif cmd == "DENUNCIAR" then
				-- (docs/42 §3.3, D23-12 A): abre la ventana para elegir el motivo
				local f = Chat.alDenunciar
				if arg == "" then
					avisar("Escriba /DENUNCIAR y el nombre del jugador.")
				elseif f then
					f(arg)
				end
			elseif cmd == "PMSG" then
				-- Chat de party (docs/28 §2.3): texto de usuario, va por su canal de TextChatService (filtrado)
				local canal = Players.LocalPlayer:GetAttribute("AOParty")
				if arg == "" then
					avisar("Escriba un mensaje.")
				elseif typeof(canal) == "string" then
					mandar(canal, arg, "party")
				end -- sin party no pasa nada, como el original
			else
				-- Fase 15a (docs/28 §1.1): lo que sigue al primer espacio va como argumento
				-- /CMSG (chat de clan, Fase 15b) y /REPORTE (playtest 3, docs/30) llevan un texto largo; el resto, hasta 40
				local tope = if cmd == "CMSG" then 160 elseif cmd == "REPORTE" then 300 else 40
				Remotes.evento("Comando"):FireServer(cmd, if arg ~= "" then string.sub(arg, 1, tope) else nil)
			end
		end
	elseif primero == "\\" then
		local nick, resto = string.match(t, "^\\(%S+)%s+(.+)$")
		if nick and resto then
			task.spawn(function()
				local ok, canal, aviso = pcall(function()
					return Remotes.funcion("Susurrar"):InvokeServer(nick)
				end)
				if ok and typeof(canal) == "string" then
					mandar(canal, resto, "susurro")
				else
					avisar(if ok and typeof(aviso) == "string" then aviso else Config.MsgNoEnviado)
				end
			end)
		end
	elseif primero == "-" then -- un muerto no grita: lo rechaza el servidor con el aviso
		local resto = string.match(string.sub(t, 2), "^%s*(.-)%s*$") or ""
		if resto ~= "" then
			mandar("AO", resto, "gritar")
		end
	else
		mandar("AO", t, if muerto then "muerto" else "hablar")
	end
end

local function cerrar()
	local c = caja
	if c then
		c.Visible = false
	end
	cerradaEn = os.clock()
	avisarEscribiendo(false)
end

-- Manda un texto como si se escribiera en la caja (la ventana "Grupo" lo usa para "/PMSG", docs/28 §2.3)
function Chat.enviar(texto: string)
	enviar(texto)
end

function Chat.abierta(): boolean
	local c = caja
	return c ~= nil and c.Visible and c:IsFocused()
end

function Chat.caja(): TextBox?
	return caja
end

function Chat.abrir()
	local c = caja
	if not c then
		return
	end
	local b = Chat.bloqueada
	if b and b() then
		return
	end
	c.Visible = true
	c:CaptureFocus()
	avisarEscribiendo(true)
end

-- La caja, dentro de `parent` (la pone cada HUD donde corresponde)
function Chat.montar(parent: Instance, pos: UDim2, tam: UDim2, tamTexto: number)
	if caja then
		caja:Destroy()
	end
	local c = Instance.new("TextBox")
	c.Name = "SendTxt"
	c.BackgroundColor3 = Color3.new(0, 0, 0)
	c.BackgroundTransparency = 0.15
	c.BorderColor3 = Color3.fromRGB(120, 100, 70)
	c.BorderSizePixel = 1
	c.Position = pos
	c.Size = tam
	c.Font = Enum.Font.Arial
	c.TextSize = tamTexto
	c.TextColor3 = Color3.fromRGB(224, 224, 224) -- &HE0E0E0 (frmMain.frm:1469)
	c.PlaceholderText = "Escribí y apretá Enter"
	c.PlaceholderColor3 = Color3.fromRGB(128, 128, 128)
	c.TextXAlignment = Enum.TextXAlignment.Left
	c.ClearTextOnFocus = false
	c.Text = ""
	c.Visible = false
	c.ZIndex = 50
	c.Parent = parent
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 4)
	pad.Parent = c
	c:GetPropertyChangedSignal("Text"):Connect(function()
		if utf8.len(c.Text) and (utf8.len(c.Text) :: number) > Config.Largo then
			c.Text = string.sub(c.Text, 1, utf8.offset(c.Text, Config.Largo + 1) - 1)
		end
	end)
	c.FocusLost:Connect(function(enter: boolean)
		if enter then
			local t = c.Text
			c.Text = ""
			enviar(t)
		end
		cerrar()
	end)
	caja = c
end

-- El Enter que cierra CUALQUIER caja de texto (el chat de la ventana de intercambio, el oro, una cantidad) no abre el
-- chat: sin esto, escribir ahí y apretar Enter dejaba el foco en la caja de hablar (Fase 22)
UserInputService.TextBoxFocusReleased:Connect(function()
	cerradaEn = os.clock()
end)

UserInputService.InputBegan:Connect(function(input, procesado)
	if procesado or input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	if input.KeyCode ~= Enum.KeyCode.Return and input.KeyCode ~= Enum.KeyCode.KeypadEnter then
		return
	end
	if UserInputService:GetFocusedTextBox() or os.clock() - cerradaEn < 0.25 then
		return -- el Enter que acaba de enviar no la vuelve a abrir
	end
	Chat.abrir()
end)

Chat._interno = { enviar = enviar }

return Chat
