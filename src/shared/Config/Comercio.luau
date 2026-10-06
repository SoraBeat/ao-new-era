--!strict
--[[
	Comercio y banco (docs/22 §5-§7, DF13-13 a DF13-21). Lo que vende cada comerciante: Shared.Generado.Tiendas;
	las fórmulas: Shared.Comercio.Precios.
]]

local Comercio = {}

Comercio.Distancia = 3 -- Manhattan, para abrir y en cada operación (Acciones.bas:92, :117; DF13-18 A)
-- Fase 32 (docs/52 §3, pedido del autor): los sastres venden todas las prendas y no entran en una ventana. El
-- comerciante tiene SlotsNpc casilleros (eran 35: MAX_INVENTORY_SLOTS del NPC, Declares.bas:924) y la ventana muestra
-- SlotsPagina por vez, con flechas para pasar de página. Tres páginas: los sastres de ropa de enano y gnomo llenan
-- dos, y queda lugar para lo que les vendan los jugadores. Verificado contra herramientas/fase32_ref.py.
Comercio.SlotsNpc = 105
Comercio.SlotsPagina = 35
Comercio.SlotsBanco = 40 -- MAX_BANCOINVENTORY_SLOTS
Comercio.SlotsBaul = 20 -- Fase 20 (docs/39 §3.5, D20-19 A): el baúl de la casa alquilada; solo objetos
Comercio.MaxCantidad = 10000 -- más que esto el original banea; acá se descarta
-- Fase 30 (docs/50 §3, pedido del autor): lo que un comerciante trae de fábrica (Generado/Tiendas) no se termina: la
-- cantidad que muestra es lo máximo que se puede comprar de una vez, y no baja. Hasta la Fase 29 se gastaba (lo
-- Crucial se reponía al llegar a cero; lo demás, solo cuando el comerciante quedaba vacío o se reiniciaba el servidor).
Comercio.StockIlimitado = true
Comercio.MaxOro = 200000000 -- MAXORO (Declares.bas:416): tope de la billetera al vender
Comercio.TipoBanquero = 4 -- eNPCType.Banquero
Comercio.CualquierTipo = 1000 -- TipoItems del Mercader: compra todo menos oro
Comercio.Oro = 12 -- "Monedas de Oro" (iORO)
-- Tirar oro a mano (docs/22 §7.2). Fase 24 (docs/43 §13, pedido del autor): sin tope (hasta la Fase 23, 10000 por
-- vez); cae en un solo montón, que puede tener hasta MaxOro, y desde ConfirmarTirarOro el cliente pregunta antes
Comercio.ConfirmarTirarOro = 100000
Comercio.MsgConfirmarTirarOro = "Vas a tirar %s monedas de oro al piso. Cualquiera las puede levantar."
Comercio.NivelTirarOro = 18 -- docs/24 DA-13 A: antes no se puede tirar oro
Comercio.MsgNivelTirarOro = "Debes ser nivel 18 para tirar oro."

-- /BANCARROTA (Fase 26, docs/46 §2, pedido del autor): 5.000 monedas de oro, una vez por hora cada personaje,
-- tenga el oro que tenga. Verificado contra herramientas/fase26_ref.py.
Comercio.BancarrotaOro = 5000
Comercio.BancarrotaSeg = 3600
Comercio.MsgBancarrota = "Recibiste 5.000 monedas de oro. Podes volver a pedirlas dentro de una hora."
Comercio.MsgBancarrotaTope = "No podes llevar mas oro."
-- Los segundos que faltan para volver a usarla (0 = ya puede). ahora y ultima: os.time(); ultima 0 = nunca
function Comercio.bancarrotaFalta(ahora: number, ultima: number): number
	if ultima <= 0 then
		return 0
	end
	return math.max(0, Comercio.BancarrotaSeg - (ahora - ultima))
end
-- El tope de la cuenta (para que borrar y volver a crear personajes no lo saltee): tantos pedidos por hora como
-- personajes entran en una cuenta. `usos`: los os.time() de los pedidos de la cuenta; saca los vencidos y devuelve
-- los segundos que faltan (0 = puede).
Comercio.BancarrotaPorCuenta = 10
function Comercio.bancarrotaCuentaFalta(ahora: number, usos: { number }): number
	for i = #usos, 1, -1 do
		if typeof(usos[i]) ~= "number" or ahora - usos[i] >= Comercio.BancarrotaSeg or usos[i] > ahora then
			table.remove(usos, i)
		end
	end
	if #usos < Comercio.BancarrotaPorCuenta then
		return 0
	end
	local primero = math.huge
	for _, t in usos do
		primero = math.min(primero, t)
	end
	return math.max(1, Comercio.BancarrotaSeg - (ahora - primero))
end
function Comercio.msgBancarrotaEspera(segundos: number): string
	local m = math.max(1, math.ceil(segundos / 60))
	return `Ya pediste tu oro. Podes volver a pedirlo en {m} {if m == 1 then "minuto" else "minutos"}.`
end

-- Mensajes (docs/22 §13)
Comercio.MsgLejos = "Estas demasiado lejos del vendedor."
Comercio.MsgMuerto = "No puedes realizar esta accion estando muerto."
Comercio.MsgSinDinero = "No tienes suficiente dinero."
Comercio.MsgSinOroCliente = "No tienes suficiente oro."
Comercio.MsgNoInteresa = "Lo siento, no estoy interesado en este tipo de objetos."
Comercio.MsgInventarioLleno = "No puedes cargar mas objetos."
Comercio.MsgYaTienesPersonal = "Ya tienes una: no necesitas otra." -- Fase 21 (docs/40 §9, D21-34 A): la Gema de Fundación, de a una
Comercio.MsgBancoLleno = "No tienes mas espacio en el banco!!"
Comercio.MsgBancoTope = "El banco no puede cargar tantos objetos."
Comercio.MsgRetirarLleno = "No podes tener mas objetos."
Comercio.MsgSinCantidadDepositar = "No tenes esa cantidad."
Comercio.MsgSinCantidadRetirar = "No tienes esa cantidad."
Comercio.MsgPrueba = "Los personajes de prueba no pueden comerciar." -- nuestro (docs/22 §5.8)
Comercio.MsgPisoLleno = "No hay espacio en el piso."
function Comercio.msgOroBanco(n: number): string
	return `Tenes {n} monedas de oro en tu cuenta.`
end

-- Pergaminos (docs/22 §9) y Poción Negra (§5.9)
Comercio.MsgSinArtes = "No tienes conocimientos de las Artes Arcanas."
Comercio.MsgClaseHechizo = "Tu clase no tiene la habilidad de aprender este hechizo."
Comercio.MsgYaTienes = "Ya tienes ese hechizo."
Comercio.MsgSinEspacioHechizos = "No tienes espacio para mas hechizos."
Comercio.MsgPocionNegra = "Sientes un gran mareo y pierdes el conocimiento."

return Comercio
