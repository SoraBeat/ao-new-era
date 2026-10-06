--!strict
--[[
	Apariencia de un personaje vivo según su raza, género, cabeza y lo que tiene equipado (ChangeUserChar con los
	NumRopaje / WeaponAnim / RazaEnanaAnim / CascoAnim / ShieldAnim del obj.dat). La usan el servidor (lo que ven los
	demás) y el panel de cuenta (los retratos).

	- Sin armadura: el cuerpo desnudo de la raza y el género (DarCuerpoDesnudo, General.bas:45-110).
	- Arma: GetWeaponAnim (Modulo_UsUaRiOs.bas:344-369): enanos y gnomos usan RazaEnanaAnim si el arma lo tiene.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigPJ = require(ReplicatedStorage.Shared.Config.Personajes)
local Objetos = require(ReplicatedStorage.Shared.Generado.ObjetosInventario)

export type Apariencia = { cuerpo: number, cabeza: number, casco: number, arma: number, escudo: number }

local Apariencia = {}

-- equipados: los números de objeto que tiene equipados (uno por tipo)
function Apariencia.viva(raza: string, genero: string, cabeza: number, equipados: { number }): Apariencia
	local a: Apariencia = { cuerpo = ConfigPJ.cuerpoDesnudoDe(raza, genero), cabeza = cabeza, casco = 0, arma = 0, escudo = 0 }
	local enano = raza == "Enano" or raza == "Gnomo"
	for _, id in equipados do
		local o: any = Objetos[id]
		if o then
			if o.tipo == "armadura" then
				a.cuerpo = o.ropaje or a.cuerpo
			elseif o.tipo == "arma" then
				a.arma = if enano and o.animEnana then o.animEnana else (o.anim or 0)
			elseif o.tipo == "casco" then
				a.casco = o.anim or 0
			elseif o.tipo == "escudo" then
				a.escudo = o.anim or 0
			end
		end
	end
	return a
end

return Apariencia
