local Translations = {
    error = {
        failed  = "Falló",
        not_owned = "¡No eres propietario de este artículo!",
        no_near = "¡No hay nadie cerca!",
        no_access = "No accesible",
        veh_locked = "¡El vehículo está bloqueado!",
        not_exist = "¿El elemento no existe?",
        no_cash = "No tienes suficiente efectivo...",
        missing_item = "No tienes los elementos correctos...",
        tú mismo = "¿No puedes darte un artículo?",
        toofar = "¡Estás demasiado lejos para regalar objetos!",
        otherfull = "¡El inventario de otros jugadores está lleno!",
        invfull = "¡Tu inventario está lleno!",
        not_enough = "No tienes suficientes elementos para transferir",
        invalid_type = "No es un tipo válido...",
        argumentos = "Argumentos no completados correctamente...",
        cant_give = "¡No puedo dar el artículo!",
        invalid_amount = "Cantidad no válida",
        not_online = "El jugador no está en línea",
    },
    success = {
        bought_item  = "%{item} comprado!",
        recieved  = "¡Recibiste %{amount}x %{item} de %{firstname} %{lastname}!",
        gave  = "Usted dio %{firstname} %{lastname} %{amount}x %{item}!",
        yougave = "¡Has dado %{name} %{amount}x %{item}!",
    },
    info = {
        pickup_snow = "Recogiendo bolas de nieve...",
        stash_none = "Alijo-Ninguno",
        stash  = "alijo-",
        trunk_none = "Troncal-Ninguno",
        trunk  = "tronco-",
        glove_none  = "Guantera-Ninguno",
        glovebox  = "Guantera-",
        playerLabel = "Jugador-",
        drop_none = "No eliminado",
        dropped  = "Caído-",
    }
}

if GetConvar('qbr_locale', 'en') == 'es' then
    Lang = Locale:new({
        phrases = Translations,
        warnOnMissing = true,
        fallbackLang = Lang,
    })
end
