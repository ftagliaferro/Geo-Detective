"""Hand-written campaign content: wiretap clues and CCTV hints per city.

Each city has three wiretap clues by difficulty tier:
  1 = obvious (famous landmark or the place itself)
  2 = cultural (currency, language, food, customs)
  3 = subtle (history, geography detail, local words)
and a CCTV "street look" hint (what a player can spot in a street photo).
All facts are public geography; text is original (ADR-0003).
Format: city_id: ((t1_es, t1_en), (t2_es, t2_en), (t3_es, t3_en), (hint_es, hint_en))
"""

CLUES = {
    "buenos_aires": (
        ("Te espero al lado del Obelisco, en la avenida más ancha del mundo.", "Meet me by the Obelisk, on the widest avenue in the world."),
        ("Traé pesos, que esta noche hay milonga en San Telmo.", "Bring pesos, there's a milonga in San Telmo tonight."),
        ("El barco sale del Río de la Plata, el estuario más ancho del planeta.", "The boat leaves from the River Plate, the widest estuary on Earth."),
        ("Colectivos de colores, carteles en español, avenidas enormes y edificios de estilo parisino.", "Colourful 'colectivo' buses, Spanish signs, huge avenues and Paris-style buildings."),
    ),
    "lisbon": (
        ("El contacto espera junto a la Torre de Belém.", "The contact waits by the Belém Tower."),
        ("Pagá en euros y pedí pastéis de nata, que ahí se habla portugués.", "Pay in euros and order pastéis de nata — they speak Portuguese there."),
        ("Subí en el tranvía 28 por las colinas, cerca de la desembocadura del Tajo.", "Ride tram 28 up the hills, near the mouth of the Tagus."),
        ("Veredas de piedritas blancas y negras, tranvías amarillos y patentes europeas con la letra P.", "Black-and-white cobbled pavements, yellow trams and EU plates with the letter P."),
    ),
    "budapest": (
        ("La señal es el Parlamento gigante a orillas del Danubio.", "The signal is the giant Parliament on the Danube."),
        ("Llevá florines: allá el euro no es la moneda oficial.", "Bring forints — the euro isn't the official currency there."),
        ("Nos vemos en los baños termales; la ciudad tiene dos mitades, Buda y Pest.", "See you at the thermal baths; the city has two halves, Buda and Pest."),
        ("Patentes europeas con la letra H, carteles en húngaro con letras como 'ő' y 'ű', tranvías amarillos.", "EU plates with the letter H, Hungarian signs with letters like 'ő' and 'ű', yellow trams."),
    ),
    "madrid": (
        ("Entregá el paquete frente al Museo del Prado.", "Hand over the package outside the Prado Museum."),
        ("Pedí unos churros con chocolate y pagá en euros; el idioma es el castellano.", "Order churros with chocolate and pay in euros; they speak Castilian Spanish."),
        ("Está justo en el centro de la península, a más de 600 metros de altura.", "It sits right in the middle of the peninsula, more than 600 metres above sea level."),
        ("Patentes europeas con la letra E, carteles en español y edificios con balcones de hierro.", "EU plates with the letter E, Spanish signs and buildings with iron balconies."),
    ),
    "paris": (
        ("Nos vemos al pie de la Torre Eiffel.", "Meet me at the foot of the Eiffel Tower."),
        ("Comprá croissants y pagá en euros; practicá tu francés.", "Buy croissants and pay in euros; practise your French."),
        ("La cita es en la Île de la Cité, en medio del Sena.", "The meeting is on the Île de la Cité, in the middle of the Seine."),
        ("Patentes europeas con la letra F, carteles azules de calles y edificios color crema con techos de pizarra.", "EU plates with the letter F, blue street signs and cream buildings with slate roofs."),
    ),
    "amsterdam": (
        ("Escondé la mercadería en una casa flotante de los canales.", "Hide the goods in a houseboat on the canals."),
        ("Pagá en euros; allá todos andan en bicicleta y hablan neerlandés.", "Pay in euros; everyone rides bikes there and speaks Dutch."),
        ("Buena parte del país está bajo el nivel del mar; los diques nos protegen.", "Much of the country is below sea level; the dykes keep us safe."),
        ("Patentes amarillas alargadas con NL, bicicletas por todos lados y casas angostas junto a canales.", "Long yellow plates with NL, bicycles everywhere and narrow houses along canals."),
    ),
    "london": (
        ("El contacto espera debajo del Big Ben.", "The contact waits under Big Ben."),
        ("Pagá en libras esterlinas y no te olvides de mirar a la derecha al cruzar.", "Pay in pounds sterling and remember to look right when crossing."),
        ("El meridiano cero pasa por un barrio de esta ciudad, sobre el Támesis.", "The prime meridian runs through one of its boroughs, on the Thames."),
        ("Patentes amarillas atrás y blancas adelante, manejan por la izquierda, colectivos rojos de dos pisos.", "Yellow rear and white front plates, driving on the left, red double-decker buses."),
    ),
    "new_york": (
        ("Te espero al lado de la Estatua de la Libertad.", "Wait for me by the Statue of Liberty."),
        ("Pagá en dólares y tomá un taxi amarillo hasta Manhattan.", "Pay in dollars and take a yellow cab to Manhattan."),
        ("La ciudad tiene cinco distritos; el dinero está en el que se llama Brooklyn.", "The city has five boroughs; the money is in the one called Brooklyn."),
        ("Taxis amarillos, rascacielos, bocas de incendio y carteles verdes de calles numeradas.", "Yellow cabs, skyscrapers, fire hydrants and green signs for numbered streets."),
    ),
    "havana": (
        ("Nos vemos en el Malecón, frente al mar.", "Meet me on the Malecón, facing the sea."),
        ("Llevá pesos cubanos; vas a ver autos americanos de los años 50.", "Bring Cuban pesos; you'll see 1950s American cars."),
        ("Es la capital de la isla más grande del Caribe.", "It's the capital of the largest island in the Caribbean."),
        ("Autos clásicos de colores, fachadas coloniales gastadas y carteles en español.", "Colourful vintage cars, faded colonial façades and Spanish signs."),
    ),
    "mexico_city": (
        ("El encuentro es en el Zócalo, frente a la catedral.", "The meeting is at the Zócalo, opposite the cathedral."),
        ("Pagá en pesos y pedí tacos al pastor.", "Pay in pesos and order tacos al pastor."),
        ("La ciudad se construyó sobre un antiguo lago, donde estaba Tenochtitlan.", "The city was built on an old lake, where Tenochtitlan once stood."),
        ("Taxis rosas y blancos, puestos callejeros, carteles en español y mucho tránsito.", "Pink-and-white taxis, street stalls, Spanish signs and heavy traffic."),
    ),
    "rome": (
        ("Tirá una moneda en la Fontana di Trevi y esperá la señal.", "Throw a coin in the Trevi Fountain and wait for the signal."),
        ("Pagá en euros y pedí un espresso; ahí se habla italiano.", "Pay in euros and order an espresso; they speak Italian there."),
        ("Dentro de esta ciudad hay otro país, el más chico del mundo.", "Inside this city there's another country, the smallest in the world."),
        ("Patentes europeas con la letra I, motonetas, calles empedradas y ruinas antiguas.", "EU plates with the letter I, scooters, cobbled streets and ancient ruins."),
    ),
    "vienna": (
        ("La cita es después del concierto, frente a la Ópera Estatal.", "The meeting is after the concert, outside the State Opera."),
        ("Pagá en euros y pedí una Sachertorte; hablan alemán.", "Pay in euros and order a Sachertorte; they speak German."),
        ("Fue la capital del imperio de los Habsburgo, sobre el Danubio.", "It was the capital of the Habsburg empire, on the Danube."),
        ("Patentes europeas con la letra A, tranvías rojos y blancos, palacios barrocos.", "EU plates with the letter A, red-and-white trams, baroque palaces."),
    ),
    "athens": (
        ("Subí a la Acrópolis, al lado del Partenón.", "Climb the Acropolis, next to the Parthenon."),
        ("Pagá en euros; los carteles están en alfabeto griego.", "Pay in euros; the signs are in the Greek alphabet."),
        ("El puerto del Pireo está a pocos kilómetros, sobre el mar Egeo.", "The port of Piraeus is a few kilometres away, on the Aegean."),
        ("Patentes europeas con GR, carteles en letras griegas, edificios blancos y olivos.", "EU plates with GR, signs in Greek letters, white buildings and olive trees."),
    ),
    "istanbul": (
        ("Te espero en la Mezquita Azul.", "Wait for me at the Blue Mosque."),
        ("Pagá en liras turcas y tomá un té en el Gran Bazar.", "Pay in Turkish lira and have tea at the Grand Bazaar."),
        ("Es la única gran ciudad repartida entre dos continentes, a ambos lados del Bósforo.", "It's the only major city split between two continents, on both sides of the Bosphorus."),
        ("Patentes con TR, carteles en turco con letras como 'ş' y 'ğ', minaretes en el horizonte.", "Plates with TR, Turkish signs with letters like 'ş' and 'ğ', minarets on the skyline."),
    ),
    "cape_town": (
        ("La entrega es al pie de la Montaña de la Mesa.", "The drop is at the foot of Table Mountain."),
        ("Pagá en rands; vas a escuchar inglés, afrikáans y xhosa.", "Pay in rand; you'll hear English, Afrikaans and Xhosa."),
        ("Desde ahí se ve la isla donde estuvo preso Mandela, cerca del Cabo de Buena Esperanza.", "From there you can see the island where Mandela was held, near the Cape of Good Hope."),
        ("Manejan por la izquierda, una montaña plana de fondo y casas de colores en Bo-Kaap.", "Driving on the left, a flat-topped mountain behind and colourful houses in Bo-Kaap."),
    ),
    "lagos": (
        ("Nos vemos en el puerto más grande del golfo de Guinea.", "Meet me at the biggest port on the Gulf of Guinea."),
        ("Llevá nairas; el idioma oficial es el inglés, pero vas a escuchar yoruba.", "Bring naira; the official language is English, but you'll hear Yoruba."),
        ("Es una de las ciudades más pobladas de África, aunque ya no es la capital del país.", "It's one of Africa's most populous cities, though no longer the country's capital."),
        ("Minibuses amarillos 'danfo', mucho tránsito, carteles en inglés y mercados callejeros.", "Yellow 'danfo' minibuses, heavy traffic, English signs and street markets."),
    ),
    "marrakech": (
        ("El encuentro es en la plaza Jemaa el-Fna, entre encantadores de serpientes.", "The meeting is in Jemaa el-Fna square, among snake charmers."),
        ("Pagá en dírhams; hablan árabe, bereber y francés.", "Pay in dirhams; they speak Arabic, Berber and French."),
        ("La 'ciudad roja', al pie de las montañas del Atlas.", "The 'red city', at the foot of the Atlas Mountains."),
        ("Muros color terracota, carteles en árabe y francés, motos y zocos cubiertos.", "Terracotta walls, signs in Arabic and French, motorbikes and covered souks."),
    ),
    "rio": (
        ("Te espero bajo el Cristo Redentor.", "Wait for me beneath Christ the Redeemer."),
        ("Pagá en reales y vení a la playa de Copacabana; se habla portugués.", "Pay in reais and come to Copacabana beach; they speak Portuguese."),
        ("La bahía de Guanabara y el Pan de Azúcar son la referencia.", "Guanabara Bay and Sugarloaf Mountain are the landmark."),
        ("Veredas onduladas blancas y negras, morros verdes, carteles en portugués.", "Wavy black-and-white pavements, green hills, Portuguese signs."),
    ),
    "dubai": (
        ("Subí al edificio más alto del mundo, el Burj Khalifa.", "Go up the tallest building in the world, the Burj Khalifa."),
        ("Pagá en dírhams de los Emiratos; carteles en árabe e inglés.", "Pay in UAE dirhams; signs in Arabic and English."),
        ("Construyeron islas artificiales con forma de palmera en el golfo Pérsico.", "They built palm-shaped artificial islands in the Persian Gulf."),
        ("Rascacielos de vidrio, desierto, autos de lujo y carteles bilingües árabe-inglés.", "Glass skyscrapers, desert, luxury cars and bilingual Arabic-English signs."),
    ),
    "mumbai": (
        ("El bote parte de la Puerta de la India.", "The boat leaves from the Gateway of India."),
        ("Llevá rupias y probá el vada pav; se habla maratí e hindi.", "Bring rupees and try vada pav; they speak Marathi and Hindi."),
        ("Es la capital del cine más prolífico del mundo, Bollywood.", "It's the home of the world's most prolific film industry, Bollywood."),
        ("Mototaxis negros y amarillos, manejan por la izquierda, carteles en devanagari.", "Black-and-yellow auto-rickshaws, driving on the left, signs in Devanagari."),
    ),
    "singapore": (
        ("El contacto espera en Marina Bay, frente al Merlion.", "The contact waits at Marina Bay, by the Merlion."),
        ("Pagá en dólares de Singapur; ahí está prohibido vender chicle.", "Pay in Singapore dollars; selling chewing gum is banned there."),
        ("Es una ciudad-estado en una isla, casi sobre el ecuador.", "It's an island city-state, almost on the equator."),
        ("Calles impecables, manejan por la izquierda, carteles en inglés, chino, malayo y tamil.", "Spotless streets, driving on the left, signs in English, Chinese, Malay and Tamil."),
    ),
    "hong_kong": (
        ("La cita es en el Victoria Peak, mirando la bahía.", "The meeting is on Victoria Peak, overlooking the harbour."),
        ("Pagá en dólares de Hong Kong; se habla cantonés.", "Pay in Hong Kong dollars; they speak Cantonese."),
        ("Fue colonia británica hasta 1997; ahora es región administrativa especial.", "It was a British colony until 1997; now it's a special administrative region."),
        ("Tranvías de dos pisos, manejan por la izquierda, carteles luminosos en chino e inglés.", "Double-decker trams, driving on the left, neon signs in Chinese and English."),
    ),
    "sydney": (
        ("Nos vemos en las escaleras de la Ópera.", "Meet me on the steps of the Opera House."),
        ("Pagá en dólares australianos y cuidado con el sol.", "Pay in Australian dollars and watch out for the sun."),
        ("El puente de la bahía le dicen 'la percha'; no es la capital del país.", "Locals call the harbour bridge 'the Coathanger'; it isn't the capital."),
        ("Manejan por la izquierda, patentes de NSW, eucaliptos y casas con galerías de hierro.", "Driving on the left, NSW plates, eucalyptus trees and houses with iron verandas."),
    ),
    "auckland": (
        ("Subí a la Sky Tower, la torre más alta del hemisferio sur.", "Go up the Sky Tower, the tallest tower in the Southern Hemisphere."),
        ("Pagá en dólares neozelandeses; vas a escuchar inglés y maorí.", "Pay in New Zealand dollars; you'll hear English and Māori."),
        ("La 'ciudad de las velas', construida sobre decenas de volcanes dormidos.", "The 'City of Sails', built on dozens of dormant volcanoes."),
        ("Manejan por la izquierda, carteles en inglés y maorí, colinas verdes y veleros.", "Driving on the left, English and Māori signs, green hills and sailboats."),
    ),
    "santiago": (
        ("Nos vemos en el cerro San Cristóbal.", "Meet me on San Cristóbal Hill."),
        ("Pagá en pesos chilenos y probá una empanada de pino.", "Pay in Chilean pesos and try an empanada de pino."),
        ("La ciudad está encajonada entre la cordillera de los Andes y la de la Costa.", "The city is wedged between the Andes and the Coastal Range."),
        ("Cordillera nevada de fondo, carteles en español, patentes blancas con letras y números.", "Snow-capped mountains behind, Spanish signs, white plates with letters and numbers."),
    ),
    "lima": (
        ("El encuentro es en la Plaza de Armas, frente al palacio.", "The meeting is at the Plaza de Armas, opposite the palace."),
        ("Pagá en soles y pedí un ceviche.", "Pay in soles and order ceviche."),
        ("Casi nunca llueve, aunque el cielo vive gris por la neblina del Pacífico.", "It almost never rains, though the sky stays grey from the Pacific mist."),
        ("Combis llenas de gente, balcones coloniales de madera y carteles en español.", "Crowded 'combi' vans, wooden colonial balconies and Spanish signs."),
    ),
    "bogota": (
        ("Te espero en el Museo del Oro.", "Wait for me at the Gold Museum."),
        ("Pagá en pesos colombianos y tomá un tinto bien cargado.", "Pay in Colombian pesos and have a strong 'tinto' coffee."),
        ("Es una de las capitales más altas del mundo, a 2.600 metros, en los Andes.", "It's one of the world's highest capitals, at 2,600 metres in the Andes."),
        ("Buses rojos del TransMilenio, cerros verdes, carteles en español, ladrillo rojo.", "Red TransMilenio buses, green hills, Spanish signs, red brick buildings."),
    ),
    "seoul": (
        ("La cita es en el palacio Gyeongbokgung.", "The meeting is at Gyeongbokgung Palace."),
        ("Pagá en wones y pedí kimchi; los carteles están en hangul.", "Pay in won and order kimchi; the signs are in Hangul."),
        ("La zona desmilitarizada está a menos de 60 km al norte.", "The demilitarised zone is less than 60 km to the north."),
        ("Carteles en hangul (letras redondas y cuadradas), mucho neón y autos coreanos.", "Signs in Hangul (circles and squares), lots of neon and Korean cars."),
    ),
    "tokyo": (
        ("Nos vemos en el cruce de Shibuya.", "Meet me at the Shibuya crossing."),
        ("Pagá en yenes y no dejes propina.", "Pay in yen and don't leave a tip."),
        ("Antes se llamaba Edo; hoy es el área metropolitana más poblada del mundo.", "It used to be called Edo; today it's the world's most populous metro area."),
        ("Manejan por la izquierda, carteles con kanji y kana, máquinas expendedoras en cada esquina.", "Driving on the left, signs in kanji and kana, vending machines on every corner."),
    ),
    "toronto": (
        ("El contacto espera arriba de la CN Tower.", "The contact waits at the top of the CN Tower."),
        ("Pagá en dólares canadienses; carteles en inglés y a veces en francés.", "Pay in Canadian dollars; signs in English and sometimes French."),
        ("Está a orillas del lago Ontario, cerca de las cataratas del Niágara.", "It's on Lake Ontario, near Niagara Falls."),
        ("Tranvías rojos, rascacielos, carteles bilingües y hojas de arce por todos lados.", "Red streetcars, skyscrapers, bilingual signs and maple leaves everywhere."),
    ),
    "reykjavik": (
        ("Te espero en la iglesia Hallgrímskirkja.", "Wait for me at Hallgrímskirkja church."),
        ("Pagá en coronas islandesas; vas a ver letras como 'þ' y 'ð'.", "Pay in Icelandic krónur; you'll see letters like 'þ' and 'ð'."),
        ("Es la capital más al norte del mundo; en verano casi no anochece.", "It's the world's northernmost capital; in summer it barely gets dark."),
        ("Casas de chapa de colores, carteles con 'þ' y 'ð', montañas peladas y mar frío.", "Colourful tin-clad houses, signs with 'þ' and 'ð', bare mountains and a cold sea."),
    ),
    "stockholm": (
        ("La entrega es en Gamla Stan, el casco antiguo.", "The drop is in Gamla Stan, the old town."),
        ("Pagá en coronas suecas, casi todo con tarjeta; probá las albóndigas.", "Pay in Swedish kronor, almost all by card; try the meatballs."),
        ("La ciudad está repartida en catorce islas donde el lago Mälaren se une al Báltico.", "The city spreads over fourteen islands where Lake Mälaren meets the Baltic."),
        ("Patentes europeas con la letra S, fachadas ocres y rojas, agua por todos lados.", "EU plates with the letter S, ochre and red façades, water everywhere."),
    ),
    "berlin": (
        ("Nos vemos en la Puerta de Brandeburgo.", "Meet me at the Brandenburg Gate."),
        ("Pagá en euros y pedí una currywurst; hablan alemán.", "Pay in euros and order a currywurst; they speak German."),
        ("Un muro dividió esta ciudad en dos hasta 1989.", "A wall split this city in two until 1989."),
        ("Patentes europeas con la letra D, semáforos con el muñequito 'Ampelmann', tranvías amarillos.", "EU plates with the letter D, 'Ampelmann' pedestrian lights, yellow trams."),
    ),
    "moscow": (
        ("La cita es en la Plaza Roja, frente a las cúpulas de colores.", "The meeting is in Red Square, by the colourful domes."),
        ("Pagá en rublos; los carteles están en alfabeto cirílico.", "Pay in roubles; the signs are in the Cyrillic alphabet."),
        ("Su metro tiene estaciones decoradas como palacios.", "Its metro has stations decorated like palaces."),
        ("Carteles en cirílico, avenidas enormes, edificios de estilo soviético.", "Cyrillic signs, huge avenues, Soviet-style buildings."),
    ),
    "beijing": (
        ("Te espero en la entrada de la Ciudad Prohibida.", "Wait for me at the entrance of the Forbidden City."),
        ("Pagá en yuanes y probá el pato laqueado.", "Pay in yuan and try Peking duck."),
        ("Desde ahí se puede ir en el día a la Gran Muralla.", "From there you can do a day trip to the Great Wall."),
        ("Carteles en caracteres chinos simplificados, avenidas anchas, muchas bicicletas y motos eléctricas.", "Signs in simplified Chinese characters, wide avenues, lots of bikes and e-scooters."),
    ),
    "bangkok": (
        ("El encuentro es en el Gran Palacio, junto al templo del Buda Esmeralda.", "The meeting is at the Grand Palace, by the Emerald Buddha temple."),
        ("Pagá en bahts y tomá un tuk-tuk.", "Pay in baht and take a tuk-tuk."),
        ("Su nombre oficial en tailandés es uno de los más largos del mundo.", "Its official Thai name is one of the longest in the world."),
        ("Manejan por la izquierda, alfabeto tailandés lleno de curvas, tuk-tuks y templos dorados.", "Driving on the left, curly Thai script, tuk-tuks and golden temples."),
    ),
    "nairobi": (
        ("Nos vemos al lado del parque nacional, donde hay jirafas con rascacielos de fondo.", "Meet me by the national park, where giraffes stand against the skyline."),
        ("Pagá con chelines kenianos o con el celular; vas a escuchar suajili.", "Pay with Kenyan shillings or by phone; you'll hear Swahili."),
        ("Está casi sobre el ecuador, pero a más de 1.600 metros de altura.", "It's almost on the equator, but over 1,600 metres high."),
        ("Minibuses 'matatu' decorados, manejan por la izquierda, tierra rojiza.", "Decorated 'matatu' minibuses, driving on the left, reddish soil."),
    ),
    "cairo": (
        ("La cita es frente a las pirámides de Guiza.", "The meeting is in front of the Giza pyramids."),
        ("Pagá en libras egipcias; los carteles están en árabe.", "Pay in Egyptian pounds; the signs are in Arabic."),
        ("La ciudad está a orillas del Nilo, justo antes de que se abra en su delta.", "The city sits on the Nile, just before it fans out into its delta."),
        ("Carteles en árabe, edificios color arena, mucho tránsito y desierto cerca.", "Arabic signs, sand-coloured buildings, heavy traffic and desert nearby."),
    ),
    "los_angeles": (
        ("Te espero debajo del cartel de Hollywood.", "Wait for me under the Hollywood sign."),
        ("Pagá en dólares; acá todos se mueven en auto por las autopistas.", "Pay in dollars; everyone drives the freeways here."),
        ("La ciudad fue fundada por españoles con el nombre de la Virgen de los Ángeles.", "The city was founded by the Spanish and named after Our Lady of the Angels."),
        ("Palmeras altísimas, autopistas enormes, patentes de California y cielo despejado.", "Very tall palm trees, huge freeways, California plates and clear skies."),
    ),
}

# Money-trail flavour per trait value (receipts, payments, transfers).
TRAIT_VALUES = {
    "specialty": ("Especialidad", "Specialty", [
        ("forgery", "Falsificación", "Forgery", "Compras de papel de seguridad y tinta magnética con una tarjeta clonada.", "Purchases of security paper and magnetic ink on a cloned card."),
        ("pickpocket", "Carterista", "Pickpocket", "Tarjetas robadas a turistas usadas una tras otra en el mismo hotel.", "Cards stolen from tourists used one after another at the same hotel."),
        ("smuggling", "Contrabando", "Smuggling", "Pago en efectivo por el alquiler de un contenedor en el puerto.", "Cash payment to rent a shipping container at the port."),
        ("hacking", "Hackeo", "Hacking", "Compra de servidores anónimos pagados con cripto.", "Anonymous servers bought with crypto."),
        ("art_theft", "Robo de arte", "Art theft", "Factura de una empresa que embala cuadros para museos.", "Invoice from a company that crates paintings for museums."),
        ("con_artist", "Estafa", "Con artistry", "Reserva de un uniforme de piloto en una casa de disfraces.", "Booking of a pilot's uniform at a costume shop."),
    ]),
    "vehicle": ("Vehículo", "Vehicle", [
        ("convertible", "Descapotable", "Convertible", "Pago del alquiler de un descapotable rojo.", "Payment for renting a red convertible."),
        ("motorcycle", "Moto", "Motorcycle", "Pago del alquiler de una moto deportiva negra.", "Payment for renting a black sports motorcycle."),
        ("yacht", "Yate", "Yacht", "Amarre pagado por una semana en un club náutico.", "A week's mooring paid at a yacht club."),
        ("private_jet", "Jet privado", "Private jet", "Combustible de aviación cargado a una cuenta en un paraíso fiscal.", "Jet fuel charged to an offshore account."),
        ("vintage_car", "Auto antiguo", "Vintage car", "Repuestos para un auto de colección de los años 60.", "Spare parts for a 1960s classic car."),
    ]),
    "mark": ("Seña particular", "Distinctive mark", [
        ("gold_ring", "Anillo de oro", "Gold signet ring", "Recibo de una joyería: limpieza de un anillo de oro con sello.", "Jeweller's receipt: cleaning of a gold signet ring."),
        ("scar", "Cicatriz", "Scar", "Pago en una clínica de maquillaje para disimular una cicatriz en la ceja.", "Payment at a make-up clinic to cover an eyebrow scar."),
        ("tattoo", "Tatuaje", "Tattoo", "Pago en un estudio de tatuajes: retoque en la muñeca.", "Tattoo studio payment: touch-up on the wrist."),
        ("glasses", "Anteojos redondos", "Round glasses", "Compra de anteojos redondos con marco de carey.", "Purchase of round tortoiseshell glasses."),
        ("red_scarf", "Pañuelo rojo", "Red scarf", "Compra de un pañuelo de seda rojo en una tienda de lujo.", "Purchase of a red silk scarf at a luxury shop."),
    ]),
    "language": ("Idioma", "Language", [
        ("italian", "Italiano", "Italian", "Recarga de un teléfono con línea italiana.", "Top-up of a phone with an Italian SIM."),
        ("german", "Alemán", "German", "Suscripción pagada a un diario en alemán.", "Paid subscription to a German-language newspaper."),
        ("portuguese", "Portugués", "Portuguese", "Pago de un curso para disimular su acento portugués.", "Payment for a course to hide a Portuguese accent."),
        ("french", "Francés", "French", "Compra de libros en francés en el aeropuerto.", "Purchase of French books at the airport."),
        ("russian", "Ruso", "Russian", "Transferencia a un traductor de ruso.", "Transfer to a Russian translator."),
        ("japanese", "Japonés", "Japanese", "Compra de manga en japonés sin traducir.", "Purchase of untranslated Japanese manga."),
    ]),
    "hobby": ("Pasatiempo", "Hobby", [
        ("opera", "Ópera", "Opera", "Dos entradas de ópera pagadas con cripto.", "Two opera tickets paid in crypto."),
        ("chess", "Ajedrez", "Chess", "Compra de un reloj de ajedrez de torneo.", "Purchase of a tournament chess clock."),
        ("golf", "Golf", "Golf", "Reserva pagada en un club de golf.", "Paid booking at a golf club."),
        ("tango", "Tango", "Tango", "Clases de tango pagadas por adelantado.", "Tango lessons paid in advance."),
        ("poker", "Póker", "Poker", "Fichas compradas en un casino a medianoche.", "Chips bought at a casino at midnight."),
        ("photography", "Fotografía", "Photography", "Compra de un teleobjetivo de alta gama.", "Purchase of a high-end telephoto lens."),
    ]),
}

NETWORKS = {
    "paper_saints": {
        "name": ("Los Santos de Papel", "The Paper Saints"),
        "suspects": ["Valentina \"La Firma\" Roca", "Dimitri Vask", "Lucía Ferraz", "Marcel Dupin", "Hugo Brandt", "Inés Salvatierra"],
    },
    "blue_harbour": {
        "name": ("Sindicato Puerto Azul", "Blue Harbour Syndicate"),
        "suspects": ["Kofi Mensah-Lund", "Sasha Ilinskaya", "Tomás Quiroga", "Nadia Farouk", "Elias Varga", "Mara Coelho"],
    },
    "zero_signal": {
        "name": ("Señal Cero", "Zero Signal"),
        "suspects": ["\"Glitch\" Okafor", "Yuna Seo", "Lars Ekdahl", "Priya Raman", "Viktor Hale", "Noor Haddad"],
    },
    "velvet_hands": {
        "name": ("Manos de Terciopelo", "Velvet Hands"),
        "suspects": ["Contessa Aurelia Bianchi", "Felix Marchetti", "Ottilie Strand", "Rafael Montiel", "Zara Whitlock", "Ilya Petrov"],
    },
    "glass_serpent": {
        "name": ("El Cartel de la Serpiente de Cristal", "The Glass Serpent Cartel"),
        "suspects": ["Leonor \"La Serpiente\" Vidal", "Bastián Ortega", "Camila Reyes", "Duarte Sousa", "Akira Mori", "Esteban Ruiz", "Helena Kostas", "Omar Benali"],
    },
}

# number, network, route, tiers (min,max), radius_km, hours, cctv_hint_free, titles, crimes
CASES = [
    (1, "paper_saints", ["buenos_aires", "lisbon", "budapest"], (1, 1), 1000, 96, True,
     ("La firma perfecta", "The Perfect Signature"),
     ("Una red de cheques falsificados vació las cuentas de un banco en Buenos Aires. Cada cheque tenía una firma impecable.", "A forged-cheque ring emptied accounts at a bank in Buenos Aires. Every cheque carried a flawless signature.")),
    (2, "paper_saints", ["madrid", "paris", "amsterdam", "london"], (1, 1), 1000, 110, True,
     ("El falso piloto", "The Fake Pilot"),
     ("Un supuesto piloto de aerolínea cobró cheques de viaje falsos en tres aeropuertos de Madrid en una sola tarde.", "A so-called airline pilot cashed fake traveller's cheques at three Madrid airport desks in a single afternoon.")),
    (3, "paper_saints", ["new_york", "havana", "mexico_city", "rome", "vienna"], (1, 2), 900, 130, True,
     ("La imprenta fantasma", "The Ghost Press"),
     ("Apareció una imprenta clandestina en Nueva York que fabricaba bonos del Tesoro perfectos. La jefa de los Santos de Papel dejó su firma.", "A secret press in New York was printing flawless Treasury bonds. The Paper Saints' leader left her signature.")),
    (4, "blue_harbour", ["cape_town", "lagos", "marrakech", "athens"], (1, 2), 800, 120, False,
     ("Contenedor 47", "Container 47"),
     ("Un contenedor con marfil falso y documentos adulterados desapareció del puerto de Ciudad del Cabo.", "A container of fake ivory and doctored papers vanished from the port of Cape Town.")),
    (5, "blue_harbour", ["rio", "lisbon", "istanbul", "dubai", "mumbai"], (2, 2), 800, 140, False,
     ("Ruta de las especias", "The Spice Route"),
     ("Un barco de bandera falsa zarpó de Río con un cargamento que nadie declaró.", "A ship under a false flag left Rio carrying undeclared cargo.")),
    (6, "blue_harbour", ["singapore", "hong_kong", "sydney", "auckland", "santiago", "lima"], (2, 2), 750, 170, False,
     ("El capitán del Pacífico", "The Pacific Captain"),
     ("El jefe del Sindicato Puerto Azul cerró un trato millonario en Singapur y cruzó el Pacífico antes del amanecer.", "The Blue Harbour boss sealed a million-dollar deal in Singapore and crossed the Pacific before dawn.")),
    (7, "zero_signal", ["seoul", "tokyo", "toronto", "reykjavik", "stockholm"], (2, 2), 650, 150, False,
     ("Pantalla negra", "Black Screen"),
     ("Un ataque informático apagó las pantallas de la bolsa de Seúl durante diez minutos. Alguien ganó una fortuna.", "A cyberattack blanked the Seoul stock exchange screens for ten minutes. Someone made a fortune.")),
    (8, "zero_signal", ["berlin", "moscow", "beijing", "bangkok", "singapore"], (2, 3), 650, 150, False,
     ("Monedero frío", "Cold Wallet"),
     ("Robaron las claves de un monedero cripto con millones de una empresa berlinesa.", "The keys to a crypto wallet holding millions were stolen from a Berlin company.")),
    (9, "zero_signal", ["los_angeles", "new_york", "london", "dubai", "nairobi", "cairo"], (2, 3), 600, 165, False,
     ("La voz clonada", "The Cloned Voice"),
     ("Con una voz clonada por computadora, alguien ordenó una transferencia gigante desde un estudio de Los Ángeles. Es obra del líder de Señal Cero.", "Using a computer-cloned voice, someone ordered a huge transfer from a Los Angeles studio. It's the work of Zero Signal's leader.")),
    (10, "velvet_hands", ["paris", "rome", "athens", "cairo", "istanbul"], (2, 3), 500, 140, False,
     ("El cuadro cambiado", "The Swapped Painting"),
     ("En un museo de París descubrieron que un cuadro famoso era una copia. El original lleva días de viaje.", "A Paris museum discovered a famous painting was a copy. The original has been travelling for days.")),
    (11, "velvet_hands", ["vienna", "budapest", "moscow", "beijing", "tokyo", "sydney"], (3, 3), 500, 170, False,
     ("El violín dormido", "The Sleeping Violin"),
     ("Un violín de trescientos años desapareció de una bóveda en Viena durante un concierto.", "A three-hundred-year-old violin vanished from a Vienna vault during a concert.")),
    (12, "velvet_hands", ["mexico_city", "lima", "bogota", "havana", "madrid", "amsterdam"], (3, 3), 450, 165, False,
     ("La máscara de jade", "The Jade Mask"),
     ("Una máscara de jade prehispánica fue robada de un museo en Ciudad de México. La condesa de las Manos de Terciopelo está detrás.", "A pre-Hispanic jade mask was stolen from a Mexico City museum. The Velvet Hands' countess is behind it.")),
    (13, "glass_serpent", ["bogota", "mexico_city", "los_angeles", "tokyo", "hong_kong", "mumbai"], (3, 3), 400, 175, False,
     ("Primera mordida", "First Bite"),
     ("Un contador del cartel de la Serpiente de Cristal desapareció de Bogotá con los libros de la organización.", "A Glass Serpent Cartel accountant vanished from Bogotá with the organisation's books.")),
    (14, "glass_serpent", ["lima", "santiago", "buenos_aires", "cape_town", "nairobi", "dubai", "moscow"], (3, 3), 400, 190, False,
     ("Lavado en siete pasos", "Laundered in Seven Steps"),
     ("Una red de casas de cambio en Lima mueve dinero del cartel por medio mundo.", "A network of exchange houses in Lima is moving cartel money across half the world.")),
    (15, "glass_serpent", ["rio", "lagos", "marrakech", "madrid", "london", "reykjavik", "toronto", "new_york"], (3, 3), 350, 210, False,
     ("La Serpiente de Cristal", "The Glass Serpent"),
     ("La jefa del cartel salió de Río en un vuelo privado. Es ahora o nunca: atrapá a La Serpiente.", "The cartel boss left Rio on a private flight. It's now or never: catch the Serpent.")),
]
