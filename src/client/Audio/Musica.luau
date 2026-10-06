--!strict
--[[
	Musica — la música (paquete P2, docs/29 §4).

	- La del mapa (`musica` de Generado/Mapas, el MusicNumMp3 del original): cambia al cambiar de mapa; si es la
	  misma, sigue sin cortarse (cli/Audio/clsAudio.cls:1050). Un mapa sin música (o sin subir) apaga la anterior.
	- Se repite (DSO-02 A: el MP3 del original sonaba una vez y quedaba en silencio).
	- Fase 17a (DW17-08 A, docs/35 §5): los temas de más de 7 min (el tope de Roblox) vienen en partes; suenan una
	  detrás de la otra y después de la última vuelve la primera.
	- Cambio con fundido de 1 s (DSO-04 A): la que se va baja mientras la nueva sube.
	- Menú (DSO-06 A): el himno (6) lo arranca la pantalla de carga (ReplicatedFirst/Carga, Sound "AOMusica" en
	  SoundService) y este módulo lo adopta; la creación de personaje toca el 7.
	- Volumen y silencio de las opciones: SoundGroup "Musica" (docs/29 §5).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")

local Sonidos = require(ReplicatedStorage.Shared.Generado.Sonidos) :: any

local Musica = {}

Musica.Base = 0.5 -- volumen de la música (el slider va en el SoundGroup)
Musica.Fundido = 1

local grupo: SoundGroup? = nil
-- Lo que suena: uno o varios Sound (las partes de los temas de más de 7 min, docs/35 §5), uno detrás del otro
type Pista = { partes: { Sound }, i: number, con: RBXScriptConnection? }
local actual: Pista? = nil
local numero = 0

local function grupoMusica(): SoundGroup
	if not grupo then
		local g = SoundService:FindFirstChild("Musica") :: SoundGroup?
		if not g then
			g = Instance.new("SoundGroup")
			g.Name = "Musica"
			g.Volume = 1
			g.Parent = SoundService
		end
		grupo = g
	end
	return grupo :: SoundGroup
end

-- Los ids de la música n: uno, o las partes en orden; nil si falta subir alguno
local function idsDe(n: number): { string }?
	local v = Sonidos.musica[n]
	local ids = if type(v) == "table" then v else { v }
	if #ids == 0 then
		return nil
	end
	for _, id in ids do
		if type(id) ~= "string" or id == "" then
			return nil
		end
	end
	return ids
end
Musica.idsDe = idsDe

-- El himno que dejó sonando la pantalla de carga
local function adoptar()
	if actual then
		return
	end
	local s = SoundService:FindFirstChild("AOMusica")
	if s and s:IsA("Sound") then
		s.SoundGroup = grupoMusica()
		actual = { partes = { s }, i = 1 }
		numero = tonumber(s:GetAttribute("Numero")) or Sonidos.menu.carga
	end
end

local function fundirYParar(p: Pista)
	if p.con then
		p.con:Disconnect()
	end
	for _, s in p.partes do
		local t = TweenService:Create(s, TweenInfo.new(Musica.Fundido), { Volume = 0 })
		t.Completed:Connect(function()
			s:Stop()
			s:Destroy()
		end)
		t:Play()
	end
end

-- Toca la música número n (0 = ninguna)
function Musica.tocar(n: number?)
	adoptar()
	n = n or 0
	if n == numero then
		return
	end
	numero = n :: number
	local viejo = actual
	actual = nil
	if viejo then
		fundirYParar(viejo)
	end
	local ids = idsDe(n :: number)
	if not ids then
		return -- sin música (o todavía sin subir): silencio, como el original
	end
	local p: Pista = { partes = {}, i = 1 }
	local vol = if viejo then 0 else Musica.Base
	for k, id in ids do
		local s = Instance.new("Sound")
		s.Name = if k == 1 then "AOMusica" else `AOMusica{k}`
		s.SoundId = id
		s.Looped = #ids == 1 -- una sola parte se repite; varias, se encadenan y al terminar la última vuelve a la 1
		s.SoundGroup = grupoMusica()
		s.Volume = vol
		s:SetAttribute("Numero", n)
		s.Parent = SoundService -- las que esperan, cargándose
		table.insert(p.partes, s)
	end
	if #ids > 1 then
		local function siguiente()
			if actual ~= p then
				return
			end
			if p.con then
				p.con:Disconnect()
			end
			p.i = p.i % #p.partes + 1
			local s = p.partes[p.i]
			s.TimePosition = 0
			s:Play()
			p.con = s.Ended:Connect(siguiente)
		end
		p.con = p.partes[1].Ended:Connect(siguiente)
	end
	p.partes[1]:Play()
	if viejo then
		for _, s in p.partes do
			TweenService:Create(s, TweenInfo.new(Musica.Fundido), { Volume = Musica.Base }):Play()
		end
	end
	actual = p
end

-- La del mapa en el que está
function Musica.deMapa(mapa: any)
	Musica.tocar(if mapa then mapa.musica else 0)
end

-- Fase 17a (docs/35 §1.2): las músicas de los mapas vecinos, en segundo plano y solo en la PC (en el celular gasta
-- datos). Quedan en Sounds sin padre hasta el próximo cambio de mapa.
local vecinas: { [number]: Sound } = {}
function Musica.precargarVecinas(numeros: { number })
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return
	end
	local nuevas: { [number]: Sound } = {}
	local cargar: { Instance } = {}
	for _, n in numeros do
		local ids = idsDe(n)
		if ids and n ~= numero and not nuevas[n] then
			local s = vecinas[n]
			if not s then
				s = Instance.new("Sound")
				s.SoundId = ids[1] -- de los partidos, la primera parte
				table.insert(cargar, s :: Sound)
			end
			nuevas[n] = s :: Sound
		end
	end
	for n, s in vecinas do
		if not nuevas[n] then
			s:Destroy()
		end
	end
	vecinas = nuevas
	if #cargar > 0 then
		task.spawn(function()
			ContentProvider:PreloadAsync(cargar)
		end)
	end
end

-- La de la creación de personaje, y volver al himno
function Musica.creacion(si: boolean)
	Musica.tocar(if si then Sonidos.menu.crear else Sonidos.menu.carga)
end

-- Volumen y silencio (docs/29 §5); el slider como en Sonido: dB de -30 a 0, el 0 silencia
function Musica.setOpciones(prendida: boolean, volumen: number)
	adoptar() -- el himno de la carga pasa al grupo, así respeta el silencio desde el menú
	local v = if volumen <= 0 then 0 else 10 ^ (-30 * (1 - math.min(volumen, 100) / 100) / 20)
	grupoMusica().Volume = if prendida then v else 0
end

function Musica.numero(): number
	return numero
end

return Musica
