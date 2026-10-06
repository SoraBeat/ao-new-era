--!strict
--[[
	Casas — constantes y textos de las casas por alquiler (Fase 20, docs/39 §3). Las 44 casas están en Generado/Casas;
	la referencia, en herramientas/fase20_ref.py (casas).
]]

local Casas = {}

Casas.Dias = 30 -- lo que dura un pago
Casas.MaxDias = 60 -- no se puede pagar más allá de esto por adelantado (D20-17 A)
Casas.AvisoDias = 3 -- al entrar, si faltan 3 días o menos
Casas.Dia = 86400
Casas.Baul = 740 -- "Baul Cerrado" (obj.dat:8947)
Casas.DistVendedor = 5 -- Manhattan, para abrir la ventana y en cada operación
Casas.RefrescoSeg = 300 -- cada servidor vuelve a leer el registro, por si se perdió un aviso
Casas.ReintentoSeg = 30 -- si no se pudo leer

Casas.Msg = {
	cerrada = "La puerta esta cerrada con llave.",
	libre = "Esta casa esta libre. %s la alquila por %s monedas de oro cada 30 dias.",
	ocupada = "Esta casa la alquila %s.",
	tuya = "Esta es tu casa. El alquiler vence en %s.",
	sinOro = "No tienes suficiente oro.",
	yaTienes = "Ya alquilas una casa: primero debes dejarla.",
	tomada = "Esa casa ya esta alquilada.",
	noEsTuya = "Esa casa no es tuya.",
	alquilada = "Has alquilado %s por 30 dias. La puerta se abre solo para ti.",
	renovada = "Has renovado el alquiler: vence en %s.",
	tope = "No puedes pagar mas de 60 dias por adelantado.",
	dejada = "Has dejado %s. Tu baul queda guardado para cuando vuelvas a alquilar.",
	vencida = "Vencio el alquiler de tu casa. Tu baul queda guardado para cuando vuelvas a alquilar.",
	porVencer = "El alquiler de tu casa vence en %s.",
	baulAfuera = "El baul es de quien alquila la casa.",
	sinRegistro = "No puedo atenderte ahora. Vuelve en un rato.",
	error = "No se pudo guardar. Intenta de nuevo en un momento.",
	prueba = "Los personajes de prueba no alquilan casas.",
	muerto = "No puedes realizar esta accion estando muerto.",
	lejos = "Estas demasiado lejos.",
	sinNpc = "Primero tienes que seleccionar un personaje, haz click izquierdo sobre el.",
} :: { [string]: string }

-- "12 dias", "1 dia", "5 horas", "menos de una hora" (fase20_ref.falta_texto)
function Casas.faltaTexto(seg: number): string
	if seg >= Casas.Dia then
		local d = seg // Casas.Dia
		return `{d} dia{if d == 1 then "" else "s"}`
	end
	if seg >= 3600 then
		local h = seg // 3600
		return `{h} hora{if h == 1 then "" else "s"}`
	end
	return "menos de una hora"
end

-- 1000000 → "1.000.000"
function Casas.miles(n: number): string
	local s = tostring(math.floor(n))
	local r = ""
	while #s > 3 do
		r = "." .. string.sub(s, -3) .. r
		s = string.sub(s, 1, -4)
	end
	return s .. r
end

-- ─── Las reglas del registro (fase20_ref: alquilar, renovar, dejar, puede_abrir, puede_baul) ─────────────────────────
-- El registro: { [casa] = { u = usuario, id = personaje, pj = su nombre, hasta = unix } }: una sola clave para las 44.
export type Entrada = { u: number, id: any, pj: string, hasta: number }
export type Registro = { [string]: Entrada }

function Casas.vigente(reg: Registro, casa: string, ahora: number): boolean
	local r = reg[casa]
	return r ~= nil and r.hasta > ahora
end

-- La casa que alquila esa cuenta (una por cuenta, D20-16 A)
function Casas.casaDe(reg: Registro, usuario: number, ahora: number): string?
	for c, r in reg do
		if r.u == usuario and r.hasta > ahora then
			return c
		end
	end
	return nil
end

-- Devuelven el motivo por el que no se puede (nil = se hizo, y `reg` quedó cambiado). El oro lo maneja el que llama.
function Casas.alquilar(reg: Registro, casa: string, usuario: number, id: any, nombre: string, ahora: number): string?
	if Casas.vigente(reg, casa, ahora) then
		return "tomada"
	end
	if Casas.casaDe(reg, usuario, ahora) then
		return "yaTienes"
	end
	reg[casa] = { u = usuario, id = id, pj = nombre, hasta = ahora + Casas.Dias * Casas.Dia }
	return nil
end

function Casas.renovar(reg: Registro, casa: string, usuario: number, id: any, ahora: number): string?
	local r = reg[casa]
	if not r or r.hasta <= ahora or r.u ~= usuario or r.id ~= id then
		return "noEsTuya"
	end
	if r.hasta + Casas.Dias * Casas.Dia > ahora + Casas.MaxDias * Casas.Dia then
		return "tope"
	end
	r.hasta += Casas.Dias * Casas.Dia
	return nil
end

-- La deja cualquier personaje de la cuenta
function Casas.dejar(reg: Registro, casa: string, usuario: number, ahora: number): string?
	local r = reg[casa]
	if not r or r.hasta <= ahora or r.u ~= usuario then
		return "noEsTuya"
	end
	reg[casa] = nil
	return nil
end

function Casas.esInquilino(reg: Registro, casa: string, usuario: number, id: any, ahora: number): boolean
	local r = reg[casa]
	return r ~= nil and r.hasta > ahora and r.u == usuario and r.id == id
end

return Casas
