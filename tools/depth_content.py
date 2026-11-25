"""Content for the depth update (ADR-0015): city maps, country facts, events,
thief messages, story, gang files, objectives. Original text; facts are public
geography. Generated into game/data/*.json by generate_campaign.py.
"""

# ---------------------------------------------------------------------------
# City map data: landmark shown on the map + water feature drawn ("coast",
# "river" or "none").  city_id: (landmark_es, landmark_en, water)
CITY_MAP = {
    "buenos_aires": ("Obelisco", "Obelisk", "river"),
    "lisbon": ("Torre de Belém", "Belém Tower", "coast"),
    "budapest": ("Parlamento", "Parliament", "river"),
    "tokyo": ("Cruce de Shibuya", "Shibuya Crossing", "coast"),
    "cairo": ("Pirámides de Guiza", "Giza Pyramids", "river"),
    "toronto": ("CN Tower", "CN Tower", "coast"),
    "mumbai": ("Puerta de la India", "Gateway of India", "coast"),
    "sydney": ("Ópera", "Opera House", "coast"),
    "mexico_city": ("Zócalo", "Zócalo", "none"),
    "new_york": ("Estatua de la Libertad", "Statue of Liberty", "coast"),
    "los_angeles": ("Cartel de Hollywood", "Hollywood Sign", "coast"),
    "chicago": ("Willis Tower", "Willis Tower", "coast"),
    "miami": ("Ocean Drive", "Ocean Drive", "coast"),
    "havana": ("Malecón", "Malecón", "coast"),
    "bogota": ("Museo del Oro", "Gold Museum", "none"),
    "lima": ("Plaza de Armas", "Plaza de Armas", "coast"),
    "santiago": ("Cerro San Cristóbal", "San Cristóbal Hill", "river"),
    "sao_paulo": ("Avenida Paulista", "Paulista Avenue", "none"),
    "rio": ("Cristo Redentor", "Christ the Redeemer", "coast"),
    "reykjavik": ("Hallgrímskirkja", "Hallgrímskirkja", "coast"),
    "london": ("Big Ben", "Big Ben", "river"),
    "paris": ("Torre Eiffel", "Eiffel Tower", "river"),
    "madrid": ("Museo del Prado", "Prado Museum", "none"),
    "rome": ("Fontana di Trevi", "Trevi Fountain", "river"),
    "berlin": ("Puerta de Brandeburgo", "Brandenburg Gate", "river"),
    "amsterdam": ("Canales", "Canals", "river"),
    "vienna": ("Ópera Estatal", "State Opera", "river"),
    "stockholm": ("Gamla Stan", "Gamla Stan", "coast"),
    "athens": ("Acrópolis", "Acropolis", "coast"),
    "istanbul": ("Mezquita Azul", "Blue Mosque", "coast"),
    "moscow": ("Plaza Roja", "Red Square", "river"),
    "marrakech": ("Jemaa el-Fna", "Jemaa el-Fna", "none"),
    "lagos": ("Puerto de Lagos", "Lagos Harbour", "coast"),
    "nairobi": ("Parque Nacional", "National Park", "none"),
    "cape_town": ("Montaña de la Mesa", "Table Mountain", "coast"),
    "dubai": ("Burj Khalifa", "Burj Khalifa", "coast"),
    "bangkok": ("Gran Palacio", "Grand Palace", "river"),
    "singapore": ("Merlion", "Merlion", "coast"),
    "hong_kong": ("Victoria Peak", "Victoria Peak", "coast"),
    "beijing": ("Ciudad Prohibida", "Forbidden City", "none"),
    "seoul": ("Palacio Gyeongbokgung", "Gyeongbokgung Palace", "river"),
    "auckland": ("Sky Tower", "Sky Tower", "coast"),
}

# ---------------------------------------------------------------------------
# Country facts for combined clues (ADR-0015 §7). None = not usable (mixed or
# unclear: Istanbul spans two continents; China's game cities differ; equatorial
# countries have no clear July season).
# code: (continent, language, currency, drive, season)
FACTS = {
    "ARE": ("asia", "arabic", "dirham", "right", "north"),
    "ARG": ("south_america", "spanish", "peso", "right", "south"),
    "AUS": ("oceania", "english", "dollar", "left", "south"),
    "AUT": ("europe", "german", "euro", "right", "north"),
    "BRA": ("south_america", "portuguese", "real", "right", "south"),
    "CAN": ("north_america", "english", "dollar", "right", "north"),
    "CHL": ("south_america", "spanish", "peso", "right", "south"),
    "CHN": ("asia", "chinese", None, None, "north"),
    "COL": ("south_america", "spanish", "peso", "right", None),
    "CUB": ("north_america", "spanish", "peso", "right", "north"),
    "DEU": ("europe", "german", "euro", "right", "north"),
    "EGY": ("africa", "arabic", "pound", "right", "north"),
    "ESP": ("europe", "spanish", "euro", "right", "north"),
    "FRA": ("europe", "french", "euro", "right", "north"),
    "GBR": ("europe", "english", "pound", "left", "north"),
    "GRC": ("europe", "greek", "euro", "right", "north"),
    "HUN": ("europe", "hungarian", "forint", "right", "north"),
    "IND": ("asia", "hindi", "rupee", "left", "north"),
    "ISL": ("europe", "icelandic", "krona", "right", "north"),
    "ITA": ("europe", "italian", "euro", "right", "north"),
    "JPN": ("asia", "japanese", "yen", "left", "north"),
    "KEN": ("africa", "swahili", "shilling", "left", None),
    "KOR": ("asia", "korean", "won", "right", "north"),
    "MAR": ("africa", "arabic", "dirham", "right", "north"),
    "MEX": ("north_america", "spanish", "peso", "right", "north"),
    "NGA": ("africa", "english", "naira", "right", None),
    "NLD": ("europe", "dutch", "euro", "right", "north"),
    "NZL": ("oceania", "english", "dollar", "left", "south"),
    "PER": ("south_america", "spanish", "sol", "right", "south"),
    "PRT": ("europe", "portuguese", "euro", "right", "north"),
    "RUS": ("europe", "russian", "rouble", "right", "north"),
    "SGP": ("asia", "english", "dollar", "left", None),
    "SWE": ("europe", "swedish", "krona", "right", "north"),
    "THA": ("asia", "thai", "baht", "left", "north"),
    "TUR": (None, "turkish", "lira", "right", "north"),
    "USA": ("north_america", "english", "dollar", "right", "north"),
    "ZAF": ("africa", "english", "rand", "left", "south"),
}
FACT_CATEGORIES = ["continent", "language", "currency", "drive", "season"]

FACT_VALUES = {
    "continent": {
        "europe": ("Europa", "Europe"), "asia": ("Asia", "Asia"), "africa": ("África", "Africa"),
        "north_america": ("Norteamérica o el Caribe", "North America or the Caribbean"),
        "south_america": ("Sudamérica", "South America"), "oceania": ("Oceanía", "Oceania"),
    },
    "language": {
        "arabic": ("árabe", "Arabic"), "spanish": ("español", "Spanish"), "english": ("inglés", "English"),
        "german": ("alemán", "German"), "portuguese": ("portugués", "Portuguese"), "chinese": ("chino", "Chinese"),
        "french": ("francés", "French"), "greek": ("griego", "Greek"), "hungarian": ("húngaro", "Hungarian"),
        "hindi": ("hindi", "Hindi"), "icelandic": ("islandés", "Icelandic"), "italian": ("italiano", "Italian"),
        "japanese": ("japonés", "Japanese"), "swahili": ("suajili", "Swahili"), "korean": ("coreano", "Korean"),
        "dutch": ("neerlandés", "Dutch"), "russian": ("ruso", "Russian"), "swedish": ("sueco", "Swedish"),
        "thai": ("tailandés", "Thai"), "turkish": ("turco", "Turkish"),
    },
    "currency": {
        "dirham": ("dírhams", "dirhams"), "peso": ("pesos", "pesos"), "dollar": ("dólares", "dollars"),
        "euro": ("euros", "euros"), "real": ("reales", "reais"), "pound": ("libras", "pounds"),
        "forint": ("florines", "forints"), "rupee": ("rupias", "rupees"), "krona": ("coronas", "kronor"),
        "yen": ("yenes", "yen"), "shilling": ("chelines", "shillings"), "won": ("wones", "won"),
        "naira": ("nairas", "naira"), "sol": ("soles", "soles"), "rouble": ("rublos", "roubles"),
        "baht": ("bahts", "baht"), "lira": ("liras", "lira"), "rand": ("rands", "rand"),
    },
    "drive": {"left": ("izquierda", "left"), "right": ("derecha", "right")},
    "season": {"north": ("verano", "summer"), "south": ("invierno", "winter")},
}

# Half-clue sentences. {v} = the value's label.
FACT_TEXT = {
    "continent": ("Su vuelo aterrizó en {v}.", "Their flight landed in {v}."),
    "language": ("Lo escucharon hablar en {v} por teléfono.", "They were heard speaking {v} on the phone."),
    "currency": ("Cambió plata a {v} antes de salir.", "They changed money into {v} before leaving."),
    "drive": ("Alquiló un auto allá: se maneja por la {v}.", "They rented a car there: people drive on the {v}."),
    "season": ("Armó la valija para el {v}: allá en julio es {v}.", "They packed for {v}: it's {v} there in July."),
}

# ---------------------------------------------------------------------------
# Hideout (recover objective): attribute values + money-trail hints + place names.
HIDEOUT_ATTRS = ["zone", "kind", "detail"]
HIDEOUT_VALUES = {
    "zone": {
        "water": (("junto al agua", "by the water"), ("Pagó el amarre de un bote junto al agua.", "They paid for a boat mooring by the water.")),
        "center": (("en el centro", "downtown"), ("Pagó estacionamiento en pleno centro, todos los días.", "They paid for parking right downtown, every day.")),
        "outskirts": (("en las afueras", "on the outskirts"), ("Cargó combustible en una estación de las afueras.", "They filled up at a petrol station on the outskirts.")),
    },
    "kind": {
        "warehouse": (("depósito", "warehouse"), ("Alquiló un montacargas por una semana.", "They rented a forklift for a week.")),
        "shop": (("negocio", "shop"), ("Compró un cartel luminoso para un negocio.", "They bought a neon sign for a shop.")),
        "house": (("vivienda", "home"), ("Pagó luz y gas de una vivienda.", "They paid the power and gas bills of a home.")),
    },
    "detail": {
        "dogs": (("con perros guardianes", "with guard dogs"), ("Compró comida para perros de guardia, de los grandes.", "They bought food for big guard dogs.")),
        "cameras": (("con cámaras de seguridad", "with security cameras"), ("Pagó la instalación de cámaras de seguridad.", "They paid to have security cameras installed.")),
        "for_sale": (("con cartel de «se vende»", "with a 'for sale' sign"), ("Pagó un cartel de «se vende», para que parezca vacío.", "They paid for a 'for sale' sign, to make it look empty.")),
    },
}
# (kind, zone) -> name
HIDEOUT_NAMES = {
    ("warehouse", "water"): ("Depósito del puerto", "Harbour warehouse"),
    ("warehouse", "center"): ("Galpón del centro", "Downtown storeroom"),
    ("warehouse", "outskirts"): ("Depósito de las afueras", "Outskirts warehouse"),
    ("shop", "water"): ("Pescadería del muelle", "Pier fish shop"),
    ("shop", "center"): ("Galería de arte del centro", "Downtown art gallery"),
    ("shop", "outskirts"): ("Taller mecánico de las afueras", "Outskirts garage"),
    ("house", "water"): ("Casa flotante", "Houseboat"),
    ("house", "center"): ("Departamento del centro", "Downtown flat"),
    ("house", "outskirts"): ("Mansión de las afueras", "Outskirts mansion"),
}

# ---------------------------------------------------------------------------
# Objectives and branches (ADR-0015 §6). Cases not listed are pursuits.
OBJECTIVES = {4: "recover", 8: "recover", 10: "recover", 11: "rescue", 13: "rescue", 7: "split", 14: "split"}
SPLITS = {
    7: (2, ["mexico_city", "bogota"]),            # split after los_angeles: long branch north, short branch south
    14: (3, ["lisbon", "paris", "amsterdam"]),   # split after rio
}
# Crime texts rewritten for the new objectives.
CRIME_OVERRIDES = {
    4: ("Un contenedor con documentos adulterados desapareció del puerto de Ciudad del Cabo. Esta vez no alcanza con seguirlos: recuperá la carga antes de que la vendan.",
        "A container of doctored papers vanished from the port of Cape Town. Following them isn't enough this time: recover the cargo before it's sold."),
    7: ("Un ataque informático apagó la bolsa de Seúl durante diez minutos. Fueron dos hackers, y se van a separar con el botín.",
        "A cyberattack blanked the Seoul stock exchange for ten minutes. It was two hackers, and they'll split up with the loot."),
    8: ("Robaron la llave física de un monedero cripto con millones de una empresa berlinesa. Recuperala antes de que lo vacíen.",
        "The hardware key to a crypto wallet holding millions was stolen from a Berlin company. Recover it before they empty it."),
    10: ("En un museo de París descubrieron que un cuadro famoso era una copia. El original lleva días de viaje: recuperalo antes de que se venda.",
         "A Paris museum discovered a famous painting was a copy. The original has been travelling for days: recover it before it's sold."),
    11: ("Secuestraron a una violinista en Viena, junto con su violín de trescientos años. Encontrá a los captores y rescatala.",
         "A violinist was kidnapped in Vienna along with her three-hundred-year-old violin. Find her captors and rescue her."),
    13: ("El contador del cartel de la Serpiente de Cristal no escapó: el cartel se lo llevó de Bogotá junto con los libros. Rescatalo antes de que lo hagan callar.",
         "The Glass Serpent Cartel's accountant didn't run: the cartel took him from Bogotá along with the books. Rescue him before they silence him."),
    14: ("Una red de casas de cambio en Lima mueve dinero del cartel. Dos mensajeros llevan el dinero y en algún punto se van a separar.",
         "A network of exchange houses in Lima moves cartel money. Two couriers carry it, and at some point they'll split up."),
}

# ---------------------------------------------------------------------------
# Gang files: the gang's rule twist, shown in the briefing (ADR-0015 §3).
GANG_FILES = {
    "paper_saints": ("Falsifican documentos: en algunas ciudades una pista escrita es falsa y apunta a otro país. Confirmá con otra fuente: las cámaras nunca mienten. El Detector de mentiras marca la falsa.",
                     "They forge documents: in some cities a written clue is fake and points to another country. Confirm with a second source: cameras never lie. The Lie detector marks the fake."),
    "blue_harbour": ("Viajan en barco: en algunos tramos el analista no tiene datos de vuelos y no sugiere países. Buscá la ciudad en el globo; el margen del pin es generoso. El Radar de puertos ayuda.",
                     "They travel by sea: on some legs the analyst has no flight data and suggests no countries. Find the city on the globe; the pin margin is generous. The Port radar helps."),
    "zero_signal": ("Interfieren las comunicaciones: algunas escuchas llegan con palabras tapadas. Pagá 1 h para descifrarlas o confiá en otras fuentes. El Descifrador las limpia.",
                    "They jam communications: some wiretaps arrive with words blacked out. Pay 1 h to decrypt them or trust other sources. The Decoder cleans them."),
    "velvet_hands": ("Usan dobles: en algunas ciudades la cámara muestra a un doble del sospechoso en otro país. Las pistas escritas sí son confiables. La Lupa forense detecta al doble.",
                     "They use body doubles: in some cities the camera shows a double of the suspect in another country. Written clues are reliable there. The Forensic lens spots the double."),
    "glass_serpent": ("El cartel aprendió de todas las bandas: puede falsificar pistas, viajar en barco, interferir escuchas y usar dobles.",
                      "The cartel learned from every gang: it may forge clues, travel by sea, jam wiretaps and use body doubles."),
}
GANG_TWIST = {"paper_saints": "forged", "blue_harbour": "sea", "zero_signal": "jam", "velvet_hands": "double", "glass_serpent": "mixed"}

# ---------------------------------------------------------------------------
# Event cards (ADR-0015 §2). Effects: ["hours", n] (n>0 costs hours, n<0 gives
# them back), ["next_flight", n], ["free_action"], ["extra_action"],
# ["lose_action"], ["eliminate"], ["reveal_who"], ["reveal_fact"], ["lead", n],
# ["burn", spot], ["plant"], ["minigame", kind, success_effects, fail_effects].
# needs: "analyst" = only when the leg has an analyst shortlist.
EVENTS = [
    {"id": "informant", "needs": ["analyst"],
     "title": ("Un informante", "An informant"),
     "text": ("Un hombre en el bar dice que vio al sospechoso comprar un pasaje. Quiere que lo invites a cenar, y habla mucho.",
              "A man at the bar says he saw the suspect buy a ticket. He wants you to buy him dinner, and he talks a lot."),
     "options": [
         {"label": ("Invitarlo (2 h): el analista descarta 2 países", "Buy him dinner (2 h): the analyst drops 2 countries"), "effects": [["hours", 2], ["eliminate"]]},
         {"label": ("No tengo tiempo", "No time"), "effects": []}]},
    {"id": "strike",
     "title": ("Huelga en el aeropuerto", "Airport strike"),
     "text": ("El personal del aeropuerto para por un día. Los vuelos van a salir con demora.",
              "Airport staff walk out for a day. Flights will leave late."),
     "options": [
         {"label": ("Esperar: el próximo vuelo tarda 3 h más", "Wait: the next flight takes 3 h longer"), "effects": [["next_flight", 3]]},
         {"label": ("Tren a otra ciudad (+1 h al vuelo), pero hoy investigás una vez menos", "Train to another city (+1 h to the flight), but you investigate once less today"), "effects": [["next_flight", 1], ["lose_action"]]}]},
    {"id": "corrupt_cop",
     "title": ("Un policía corrupto", "A corrupt cop"),
     "text": ("Un agente te ofrece la ficha del sospechoso a cambio de «un favor» que te va a llevar horas.",
              "An officer offers you the suspect's file in exchange for 'a favour' that will take hours."),
     "options": [
         {"label": ("Aceptar (3 h): un dato de QUIÉN es", "Accept (3 h): a fact about WHO it is"), "effects": [["hours", 3], ["reveal_who"]]},
         {"label": ("Denunciarlo (1 h): te ganás un aliado, tu próxima investigación es gratis", "Report him (1 h): you gain an ally, your next investigation is free"), "effects": [["hours", 1], ["free_action"]]}]},
    {"id": "ambush",
     "title": ("¡Emboscada!", "Ambush!"),
     "text": ("Dos matones de la banda te cierran el paso en un callejón.",
              "Two of the gang's thugs block your way in an alley."),
     "options": [
         {"label": ("Escapar corriendo (si fallás, 3 h perdidas)", "Run for it (fail and lose 3 h)"), "effects": [["minigame", "checkpoint", [], [["hours", 3]]]]},
         {"label": ("Llamar a la policía local y esperar (2 h)", "Call the local police and wait (2 h)"), "effects": [["hours", 2]]}]},
    {"id": "envelope",
     "title": ("Un sobre anónimo", "An anonymous envelope"),
     "text": ("Alguien deslizó un sobre por debajo de la puerta de tu hotel.",
              "Someone slipped an envelope under your hotel door."),
     "options": [
         {"label": ("Abrirlo: un dato del próximo destino", "Open it: a fact about the next destination"), "effects": [["reveal_fact"]]},
         {"label": ("Puede ser una trampa: no abrirlo", "It could be a trap: leave it"), "effects": []}]},
    {"id": "witness",
     "title": ("Una testigo", "A witness"),
     "text": ("Una vendedora del mercado vio al sospechoso ayer y se acuerda de él.",
              "A market vendor saw the suspect yesterday and remembers them."),
     "options": [
         {"label": ("Preguntarle cómo era (2 h): un dato de QUIÉN es", "Ask what they looked like (2 h): a fact about WHO it is"), "effects": [["hours", 2], ["reveal_who"]]},
         {"label": ("Preguntarle a dónde iba (1 h): un dato del destino", "Ask where they were going (1 h): a fact about the destination"), "effects": [["hours", 1], ["reveal_fact"]]}]},
    {"id": "pickpocket",
     "title": ("¡Te robaron la billetera!", "Your wallet's gone!"),
     "text": ("Un carterista se llevó tu billetera en la calle. Todavía se lo ve entre la gente.",
              "A pickpocket took your wallet in the street. You can still see them in the crowd."),
     "options": [
         {"label": ("Perseguirlo (si se escapa, 2 h perdidas)", "Chase them (if they get away, lose 2 h)"), "effects": [["minigame", "sighting", [], [["hours", 2]]]]},
         {"label": ("Dejarlo y hacer la denuncia (2 h)", "Let it go and file a report (2 h)"), "effects": [["hours", 2]]}]},
    {"id": "storm",
     "title": ("Se viene una tormenta", "A storm is coming"),
     "text": ("El pronóstico anuncia tormenta. Los vuelos van a salir tarde.",
              "The forecast says storm. Flights will leave late."),
     "options": [
         {"label": ("Esperar: el próximo vuelo tarda 2 h más", "Wait: the next flight takes 2 h longer"), "effects": [["next_flight", 2]]},
         {"label": ("Aprovechar: una investigación más antes de que se enfríe el rastro (+1 h al vuelo)", "Make use of it: one more investigation before the trail cools (+1 h to the flight)"), "effects": [["extra_action"], ["next_flight", 1]]}]},
    {"id": "colleague",
     "title": ("Un viejo colega", "An old colleague"),
     "text": ("Te cruzás con un excompañero de Interpol que ahora trabaja en esta ciudad.",
              "You run into a former Interpol colleague who now works in this city."),
     "options": [
         {"label": ("Pedirle ayuda: tu próxima investigación es gratis", "Ask for help: your next investigation is free"), "effects": [["free_action"]]},
         {"label": ("Pedirle sus contactos: una investigación más antes de que se enfríe el rastro", "Ask for contacts: one more investigation before the trail cools"), "effects": [["extra_action"]]}]},
    {"id": "reporter",
     "title": ("Una periodista", "A reporter"),
     "text": ("Una periodista quiere entrevistarte sobre el caso para el noticiero de la noche.",
              "A reporter wants to interview you about the case for the evening news."),
     "options": [
         {"label": ("Dar la nota (1 h): el ladrón se pone nervioso y su ventaja baja 3 h", "Give the interview (1 h): the thief gets nervous and their lead drops 3 h"), "effects": [["hours", 1], ["lead", -3]]},
         {"label": ("Sin comentarios", "No comment"), "effects": []}]},
]

# Reaction cards: the thief reacts when you get close (lead ≤ 4 h).
REACTIONS = [
    {"id": "tipoff",
     "title": ("Te denunciaron", "Someone reported you"),
     "text": ("El ladrón avisó a la policía local que un «extranjero sospechoso» anda por la ciudad. Vienen a hacerte preguntas.",
              "The thief told the local police a 'suspicious foreigner' is in town. They come to question you."),
     "options": [
         {"label": ("Colaborar con paciencia (2 h)", "Cooperate patiently (2 h)"), "effects": [["hours", 2]]},
         {"label": ("Mostrar la credencial de Interpol: te dejan ir, pero investigás una vez menos", "Show your Interpol badge: they let you go, but you investigate once less"), "effects": [["lose_action"]]}]},
    {"id": "burned",
     "title": ("Le pagaron al contacto", "The contact was paid off"),
     "text": ("El ladrón le pagó a tu contacto local para que no hable.",
              "The thief paid your local contact to keep quiet."),
     "options": [
         {"label": ("Pagarle más que él (2 h): el contacto habla", "Outbid the thief (2 h): the contact talks"), "effects": [["hours", 2]]},
         {"label": ("Seguir sin el contacto en esta ciudad", "Carry on without the contact in this city"), "effects": [["burn", "contact"]]}]},
    {"id": "plant",
     "title": ("Un regalito del ladrón", "A little gift from the thief"),
     "text": ("Interceptaron un mensaje: el ladrón dejó una pista falsa en esta ciudad. Una de las pistas escritas te va a mandar al país equivocado.",
              "An intercepted message: the thief left a fake clue in this city. One of the written clues will send you to the wrong country."),
     "options": [
         {"label": ("Entendido: voy a confirmar con dos fuentes", "Understood: I'll confirm with two sources"), "effects": [["plant"]]}]},
    {"id": "thugs",
     "title": ("Te estaban esperando", "They were waiting for you"),
     "text": ("El ladrón dejó a dos matones vigilando la salida del hotel.",
              "The thief left two thugs watching the hotel exit."),
     "options": [
         {"label": ("Salir corriendo (si fallás, 3 h perdidas)", "Make a run for it (fail and lose 3 h)"), "effects": [["minigame", "checkpoint", [], [["hours", 3]]]]},
         {"label": ("Salir por la cocina, despacio (2 h)", "Slip out through the kitchen (2 h)"), "effects": [["hours", 2]]}]},
]

# Intercepted messages from the thief. {city} = the current city.
MESSAGES = {
    "far": [("«¿Todavía me buscás? Disfrutá {city}, yo ya estoy lejos.»", "\"Still looking for me? Enjoy {city}, I'm long gone.\""),
            ("«Llegás tarde, detective. Como siempre.»", "\"Late again, detective. As always.\""),
            ("«Te dejé el café servido. Ya se enfrió.»", "\"I left you a coffee. It's gone cold.\"")],
    "close": [("«Siento tus pasos... no te va a alcanzar.»", "\"I can hear your footsteps... it won't be enough.\""),
              ("«Bien jugado. Pero yo juego mejor.»", "\"Well played. But I play better.\""),
              ("«Si me seguís tan de cerca, me voy a poner nervioso.»", "\"Follow me this closely and I'll get nervous.\"")],
    "here": [("«¿Qué hacés acá? ¡No puede ser!»", "\"What are you doing here? It can't be!\""),
             ("«Te vi en el aeropuerto. Corré, si querés.»", "\"I saw you at the airport. Run, if you like.\"")],
    "miss": [("«¿{city}? Ni cerca. Seguí paseando.»", "\"{city}? Not even close. Keep sightseeing.\""),
             ("«Te mandé a pasear. Volvé cuando quieras.»", "\"I sent you sightseeing. Come back whenever.\"")],
    "plant": [("«Te dejé un regalito en la ciudad. Elegí bien en quién confiar.»", "\"I left you a little gift in town. Choose carefully who you trust.\"")],
}

# ---------------------------------------------------------------------------
# Story (ADR-0015 §4). speaker ids: rivas, nico, varela, a suspect id, or
# "culprit" (the case's culprit, resolved at runtime). {culprit} = their name.
CHARACTERS = {
    "rivas": ("Inspectora Marta Rivas", "Inspector Marta Rivas"),
    "nico": ("Nico, el analista", "Nico, the analyst"),
    "varela": ("Dr. Aldo Varela, Interpol", "Dr. Aldo Varela, Interpol"),
    "hostage_violin": ("Clara Wenzel, violinista", "Clara Wenzel, violinist"),
    "hostage_accountant": ("Elías Prado, contador", "Elías Prado, accountant"),
}
# Fixed portraits for the story cast (indices into suspect_portrait.gd's SKIN/HAIR/COAT;
# hair_style 2 = long hair, 3 = bald; traits.mark draws glasses etc.).
CHARACTER_LOOKS = {
    "rivas": {"skin": 1, "hair": 1, "coat": 0, "hair_style": 2, "hat": False},
    "nico": {"skin": 3, "hair": 0, "coat": 3, "hair_style": 0, "hat": False},
    "varela": {"skin": 0, "hair": 4, "coat": 4, "hair_style": 3, "hat": False, "traits": {"mark": "glasses"}},
    "hostage_violin": {"skin": 0, "hair": 3, "coat": 5, "hair_style": 2, "hat": False},
    "hostage_accountant": {"skin": 2, "hair": 0, "coat": 1, "hair_style": 1, "hat": False, "traits": {"mark": "glasses"}},
}
L = lambda sp, es, en: [sp, es, en]  # noqa: E731

STORY = {
    1: {"intro": [L("rivas", "Te doy la bienvenida a la unidad, detective. Soy la inspectora Marta Rivas.", "Welcome to the unit, detective. I'm Inspector Marta Rivas."),
                  L("rivas", "Una banda de falsificadores vació un banco en Buenos Aires. Quiero que la sigas.", "A gang of forgers emptied a bank in Buenos Aires. I want you on their trail."),
                  L("nico", "Soy Nico, el analista. Cuando viajes te sugiero cuatro países: uno siempre es el correcto.", "I'm Nico, the analyst. When you travel I'll suggest four countries: one is always right.")],
        "outro": [L("rivas", "Buen trabajo. Ya tenemos a {culprit}.", "Good work. {culprit} is in custody."),
                  L("nico", "En sus papeles hay una firma rara: una «C» dorada. ¿C de qué?", "There's an odd signature in their papers: a golden 'C'. C for what?")]},
    2: {"intro": [L("rivas", "Los Santos de Papel siguen activos. Ojo: falsifican todo, hasta las pistas.", "The Paper Saints are still active. Careful: they forge everything, even the clues."),
                  L("varela", "Aldo Varela, de Interpol. Persigo a esta gente hace años. Cuenten conmigo.", "Aldo Varela, Interpol. I've chased these people for years. Count on me.")],
        "outro": [L("nico", "Otra vez la «C». Alguien les paga a los Santos.", "The 'C' again. Someone is paying the Saints."),
                  L("varela", "Interesante... Lo voy a averiguar.", "Interesting... I'll look into it.")]},
    3: {"intro": [L("rivas", "La jefa de los Santos, {culprit}, imprimió bonos falsos en Nueva York.", "The Saints' boss, {culprit}, printed fake bonds in New York."),
                  L("varela", "Si la atrapan, quizás nos diga quién es «C».", "Catch her and she may tell us who 'C' is.")],
        "outro": [L("culprit", "Yo solo firmaba. Las órdenes las da El Coleccionista.", "I only signed. The orders come from the Collector."),
                  L("rivas", "¿El Coleccionista? Nico, buscá todo lo que haya.", "The Collector? Nico, dig up everything.")]},
    4: {"intro": [L("rivas", "El Sindicato Puerto Azul se llevó un contenedor de Ciudad del Cabo. Esta vez hay que recuperar la carga.", "The Blue Harbour Syndicate took a container from Cape Town. This time we need the cargo back."),
                  L("nico", "El rastro de dinero te va a contar cómo es el escondite: zona, tipo de lugar y un detalle.", "The money trail will tell you what the hideout is like: area, kind of place and a detail.")],
        "outro": [L("nico", "En la carga había un sello: la misma «C» dorada. El Coleccionista colecciona... de todo.", "The cargo carried a seal: the same golden 'C'. The Collector collects... everything.")]},
    5: {"intro": [L("nico", "Puerto Azul se mueve por mar. En esos tramos no voy a tener datos de vuelos para darte.", "Blue Harbour moves by sea. On those legs I won't have flight data for you."),
                  L("varela", "Cuando Nico no vea nada, buscá la ciudad en el globo.", "When Nico can't see a thing, find the city on the globe.")],
        "outro": [L("rivas", "Bien. Su capitán va a tener que dar la cara.", "Good. Their captain will have to show his face.")]},
    6: {"intro": [L("rivas", "{culprit}, el capitán de Puerto Azul, cerró un trato en Singapur.", "{culprit}, Blue Harbour's captain, closed a deal in Singapore.")],
        "outro": [L("culprit", "El Coleccionista siempre sabía dónde iba a estar la policía. Siempre.", "The Collector always knew where the police would be. Always."),
                  L("rivas", "Entonces alguien le pasa información...", "Then someone is feeding him information...")]},
    7: {"intro": [L("nico", "Señal Cero apagó la bolsa de Seúl. Fueron dos, y se van a separar.", "Zero Signal blanked the Seoul exchange. There were two of them, and they'll split up."),
                  L("rivas", "Cuando se separen, seguí a uno. El que tengas más cerca.", "When they split, follow one. Whichever you can catch.")],
        "outro": [L("nico", "En la computadora del hacker hay mensajes de alguien con acceso a Interpol.", "The hacker's laptop has messages from someone with Interpol access.")]},
    8: {"intro": [L("varela", "Robaron la llave de un monedero cripto en Berlín. Recupérenla antes de que lo vacíen.", "A crypto wallet key was stolen in Berlin. Get it back before they empty it."),
                  L("nico", "Cuidado: las escuchas de Señal Cero llegan con interferencia.", "Careful: Zero Signal's wiretaps come in jammed.")],
        "outro": [L("rivas", "La llave estaba en un lugar que solo conocía Interpol. Raro, ¿no?", "The key was somewhere only Interpol knew about. Odd, isn't it?")]},
    9: {"intro": [L("rivas", "{culprit}, el líder de Señal Cero, clonó una voz para robar millones.", "{culprit}, Zero Signal's leader, cloned a voice to steal millions.")],
        "outro": [L("culprit", "¿Quieren al Coleccionista? Miren más cerca. Siempre estuvo en sus reuniones.", "You want the Collector? Look closer. He's always been in your meetings."),
                  L("rivas", "¿En nuestras reuniones...?", "In our meetings...?")]},
    10: {"intro": [L("rivas", "Cambiaron un cuadro del museo de París por una copia. Recuperá el original.", "A Paris museum painting was swapped for a copy. Recover the original."),
                   L("varela", "Las Manos de Terciopelo usan dobles. No confíes solo en las cámaras.", "The Velvet Hands use body doubles. Don't trust the cameras alone.")],
         "outro": [L("nico", "El original tenía una etiqueta: «Para la colección privada de A. V.»", "The original had a label: 'For the private collection of A. V.'")]},
    11: {"intro": [L("rivas", "Secuestraron a una violinista en Viena, con su violín. Encontrá a los captores.", "A violinist was kidnapped in Vienna, with her violin. Find the captors."),
                   L("nico", "Cuando los encuentres, vas a tener que sacarla de ahí a toda velocidad.", "When you find them, you'll have to get her out at full speed.")],
         "outro": [L("hostage_violin", "Gracias. Mis captores hablaban de un tal «doctor» que pagaba todo.", "Thank you. My captors talked about some 'doctor' who paid for everything.")]},
    12: {"intro": [L("rivas", "La condesa de las Manos de Terciopelo, {culprit}, se llevó una máscara de jade.", "The Velvet Hands' countess, {culprit}, took a jade mask.")],
         "outro": [L("culprit", "Varela... perdón, El Coleccionista, odia los errores. Y ustedes son uno.", "Varela... sorry, the Collector, hates mistakes. And you are one."),
                   L("nico", "¿Dijo «Varela»?", "Did she say 'Varela'?")]},
    13: {"intro": [L("rivas", "El contador de la Serpiente no escapó: lo secuestraron con los libros. Rescatalo.", "The Serpent's accountant didn't run: he was taken with the books. Rescue him."),
                   L("varela", "Ese hombre sabe demasiado... Mejor que no llegue a declarar.", "That man knows too much... Better if he never testifies.")],
         "outro": [L("hostage_accountant", "Los libros muestran pagos a una cuenta de Interpol, a nombre de A. Varela.", "The books show payments to an Interpol account, in the name of A. Varela."),
                   L("rivas", "Lo sospechaba. Varela es El Coleccionista.", "I suspected it. Varela is the Collector.")]},
    14: {"intro": [L("rivas", "Varela desapareció. El cartel mueve su dinero con dos mensajeros que se van a separar.", "Varela has vanished. The cartel moves its money with two couriers who will split up."),
                   L("nico", "Elegí a uno y no lo sueltes. El tramo corto es más rápido; el largo te da más pistas.", "Pick one and don't let go. The short branch is faster; the long one gives you more clues.")],
         "outro": [L("nico", "La Serpiente salió de Río en un vuelo privado. Es la última.", "The Serpent left Rio on a private flight. She's the last one.")]},
    15: {"intro": [L("rivas", "Es ahora o nunca. Atrapá a {culprit}: ella sabe dónde está Varela.", "It's now or never. Catch {culprit}: she knows where Varela is.")],
         "outro": [L("culprit", "Llegaron tarde. El Coleccionista ya se fue... con lo mejor de cada banda.", "You're too late. The Collector is gone... with the best of every gang."),
                   L("rivas", "Varela era El Coleccionista y se escapó. Esto no terminó, detective. Descansá: te voy a necesitar.", "Varela was the Collector, and he got away. This isn't over, detective. Get some rest: I'll need you.")]},
}
