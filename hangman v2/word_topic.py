"""
Infer a display topic for the hangman answer (no spoilers — category only).

Uses: optional ``data/word_theme_map.json`` (built offline from dictionary glosses — see
``scripts/build_word_themes.py``), then exact phrase map, keyword scoring, morphology, …
"""
from __future__ import annotations

import json
import os
import re
import threading
from pathlib import Path

_theme_map_lock = threading.Lock()
_theme_map_cache: dict[str, str] | None = None

# Full answer (uppercase, normalized spacing) -> topic label (no "Theme:" prefix)
EXACT_PHRASE_TOPICS: dict[str, str] = {
    "IRN BRU": "Drink · soft drink (Scotland)",
    "CUP OF TEA": "Food & drink · hot drink",
    "FULL ENGLISH": "Food · breakfast",
    "FULL ENGLISH BREAKFAST": "Food · breakfast",
    "FISH AND CHIPS": "Food · classic dish",
    "BANGERS AND MASH": "Food · classic dish",
    "TOAD IN THE HOLE": "Food · classic dish",
    "YORKSHIRE PUDDING": "Food · side dish",
    "SPOTTED DICK": "Food · dessert",
    "SUNDAY ROAST": "Food · roast dinner",
    "CLOTTED CREAM": "Food · dairy",
    "JAMMIE DODGER": "Food · biscuit / snack",
    "STEAK AND KIDNEY PIE": "Food · pie",
    "SHEPHERDS PIE": "Food · pie",
    "COTTAGE PIE": "Food · pie",
    "BEANS ON TOAST": "Food · snack",
    "CHEESE AND ONION": "Food · flavour",
    "SALT AND VINEGAR": "Food · flavour",
    "PICKLED ONION": "Food · snack",
    "PORK PIE": "Food · pie",
    "SCOTCH EGG": "Food · snack",
    "CORONATION CHICKEN": "Food · dish",
    "PLOUGHMANS LUNCH": "Food · lunch",
    "DOUBLE DECKER BUS": "Transport · bus",
    "RED DOUBLE DECKER": "Transport · bus",
    "BLACK CAB": "Transport · taxi",
    "MIND THE GAP": "UK culture · transport",
    "GOD SAVE THE KING": "UK culture · anthem",
    "RULE BRITANNIA": "UK culture · anthem",
    "LAND OF HOPE AND GLORY": "UK culture · anthem",
    "WIMBLEDON TENNIS": "Sport · tennis",
    "WEMBLEY STADIUM": "Sport · venue",
    "TWICKENHAM STADIUM": "Sport · rugby",
    "MURRAYFIELD STADIUM": "Sport · rugby",
    "PREMIER LEAGUE": "Sport · football",
    "CHAMPIONS LEAGUE": "Sport · football",
    "OXFORD UNIVERSITY": "Education · university",
    "CAMBRIDGE UNIVERSITY": "Education · university",
    "RIVER THAMES": "Geography · river",
    "LAKE DISTRICT": "Geography · national park",
    "PEAK DISTRICT": "Geography · national park",
    "SCOTTISH HIGHLANDS": "Geography · region",
    "WHITE CLIFFS OF DOVER": "Geography · landmark",
    "STONEHENGE": "History · monument",
    "HADRIANS WALL": "History · monument",
    "TOWER BRIDGE": "Places · London landmark",
    "LONDON EYE": "Places · London landmark",
    "BIG BEN": "Places · London landmark",
    "BUCKINGHAM PALACE": "Places · royal / London",
    "WESTMINSTER ABBEY": "Places · church / London",
    "HOUSES OF PARLIAMENT": "Politics & civics · parliament",
    "DOWNING STREET": "Politics & civics · government",
    "CHANGING OF THE GUARD": "UK culture · ceremony",
    "BRITISH MUSEUM": "Culture · museum",
    "NATIONAL GALLERY": "Culture · art gallery",
    "TATE MODERN": "Culture · art gallery",
    "SCIENCE MUSEUM": "Science · museum",
    "NATURAL HISTORY MUSEUM": "Science · museum",
    "HEATHROW AIRPORT": "Transport · airport",
    "GATWICK AIRPORT": "Transport · airport",
    "EUROSTAR TRAIN": "Transport · train",
    "KINGS CROSS": "Places · station / London",
    "ST PANCRAS": "Places · station / London",
    "LOCH NESS": "Geography · lake / legend",
    "GLASTONBURY FESTIVAL": "Music · festival",
    "EDINBURGH CASTLE": "Places · castle",
    "CARDIFF CASTLE": "Places · castle",
    "YORK MINSTER": "Places · cathedral",
    "CANTERBURY CATHEDRAL": "Places · cathedral",
    "STRATFORD UPON AVON": "Places · town (Shakespeare)",
}

# Order matters: first matching topic wins (most specific first).
TOPIC_KEYWORDS: list[tuple[str, frozenset[str]]] = [
    (
        "Education & learning",
        frozenset(
            {
                "SCHOOL",
                "SCHOOLS",
                "UNIVERSITY",
                "UNIVERSITIES",
                "COLLEGE",
                "COLLEGES",
                "CAMPUS",
                "STUDENT",
                "STUDENTS",
                "TEACHER",
                "TEACHERS",
                "LECTURE",
                "LECTURES",
                "TUTOR",
                "TUTORS",
                "PROFESSOR",
                "DEGREE",
                "DEGREES",
                "DIPLOMA",
                "EXAM",
                "EXAMS",
                "TEST",
                "TESTS",
                "HOMEWORK",
                "CLASSROOM",
                "KINDERGARTEN",
                "NURSERY",
                "ACADEMY",
                "ACADEMIC",
                "SCHOLAR",
                "LIBRARY",
                "TEXTBOOK",
                "NOTEBOOK",
                "PENCIL",
                "RULER",
                "BLACKBOARD",
                "HEADMASTER",
                "HEADMISTRESS",
                "PRINCIPAL",
                "SEMESTER",
                "THESIS",
                "LECTERN",
            }
        ),
    ),
    (
        "Food & drink (general)",
        frozenset(
            {
                "FOOD",
                "MEAL",
                "MEALS",
                "BREAKFAST",
                "LUNCH",
                "DINNER",
                "SUPPER",
                "SNACK",
                "BISCUIT",
                "BISCUITS",
                "CRISPS",
                "CHIPS",
                "TOAST",
                "BREAD",
                "BUTTER",
                "CHEESE",
                "EGGS",
                "BACON",
                "SAUSAGE",
                "SAUSAGES",
                "PUDDING",
                "CUSTARD",
                "CREAM",
                "SUGAR",
                "SALT",
                "PEPPER",
                "VINEGAR",
                "ONION",
                "GARLIC",
                "POTATO",
                "TOMATO",
                "SALAD",
                "SOUP",
                "STEW",
                "CURRY",
                "PIE",
                "CAKE",
                "TART",
                "FRUIT",
                "APPLE",
                "BANANA",
                "ORANGE",
                "GRAPE",
                "BERRY",
                "MELON",
                "LEMON",
                "HONEY",
                "JAM",
                "MARMALADE",
                "FLAPJACK",
                "ELEVENSES",
                "TAKEAWAY",
                "RESTAURANT",
                "CAFE",
                "CANTEEN",
                "PANTRY",
                "KITCHEN",
                "RECIPE",
                "COOK",
                "BAKE",
                "GRILL",
                "FRIED",
                "BOILED",
                "ROAST",
                "YORKSHIRE",
                "HAGGIS",
                "NEEPS",
                "TATTIES",
                "KIPPER",
                "KIPPERS",
            }
        ),
    ),
    (
        "Drinks & beverages",
        frozenset(
            {
                "DRINK",
                "DRINKS",
                "TEA",
                "COFFEE",
                "JUICE",
                "WINE",
                "BEER",
                "LAGER",
                "ALE",
                "CIDER",
                "WHISKY",
                "WHISKEY",
                "BRANDY",
                "VODKA",
                "GIN",
                "RUM",
                "COCKTAIL",
                "LEMONADE",
                "SODA",
                "TONIC",
                "MILK",
                "WATER",
                "SPRITE",
                "COLA",
                "PINT",
                "BOTTLE",
                "KETTLE",
                "TEAPOT",
                "CAFFEINE",
                "BREW",
            }
        ),
    ),
    (
        "Places & geography (UK / towns)",
        frozenset(
            {
                "OXFORD",
                "CAMBRIDGE",
                "LONDON",
                "BRISTOL",
                "MANCHESTER",
                "LIVERPOOL",
                "BIRMINGHAM",
                "LEEDS",
                "SHEFFIELD",
                "NOTTINGHAM",
                "LEICESTER",
                "COVENTRY",
                "READING",
                "KINGSTON",
                "YORK",
                "BATH",
                "EXETER",
                "PLYMOUTH",
                "NORWICH",
                "IPSWICH",
                "BRIGHTON",
                "BOURNEMOUTH",
                "BLACKPOOL",
                "CARLISLE",
                "CHESTER",
                "DURHAM",
                "GLOUCESTER",
                "HEREFORD",
                "LANCASTER",
                "LINCOLN",
                "NEWCASTLE",
                "PETERBOROUGH",
                "PRESTON",
                "RIPON",
                "SALISBURY",
                "TRURO",
                "WAKEFIELD",
                "WELLS",
                "WORCESTER",
                "EDINBURGH",
                "GLASGOW",
                "ABERDEEN",
                "DUNDEE",
                "INVERNESS",
                "STIRLING",
                "PERTH",
                "CARDIFF",
                "SWANSEA",
                "BANGOR",
                "BELFAST",
                "DERRY",
                "ENGLAND",
                "SCOTLAND",
                "WALES",
                "IRELAND",
                "BRITAIN",
                "LONDONER",
                "CITY",
                "TOWN",
                "VILLAGE",
                "COUNTY",
                "ISLAND",
                "COAST",
                "HILL",
                "HILLS",
                "VALLEY",
                "MOOR",
                "FEN",
                "FENS",
                "CLIFF",
                "ESTUARY",
                "THAMES",
                "SEVERN",
                "TWEED",
                "CLYDE",
                "MERSEY",
                "TYNE",
                "AVON",
                "CHANNEL",
                "OCEAN",
                "SEA",
                "BAY",
                "SHORE",
                "SHORES",
                "BEACH",
                "BEACHES",
                "SEASHORE",
                "COASTLINE",
                "HEADLAND",
                "LAGOON",
                "STRAIT",
                "ATOLL",
                "REEF",
                "CORAL",
                "DUNE",
                "DUNES",
                "TIDE",
                "TIDAL",
                "SHINGLE",
                "SAND",
                "SANDS",
                "HARBOUR",
                "HARBOR",
                "DOCK",
                "PIER",
                "QUAY",
                "LIGHTHOUSE",
                "YORKSHIRE",
                "LANCASHIRE",
                "CORNWALL",
                "DEVON",
                "SUSSEX",
                "KENT",
                "ESSEX",
                "NORFOLK",
                "SUFFOLK",
                "DERBYSHIRE",
                "CHESHIRE",
                "CUMBRIA",
                "NORTHUMBERLAND",
                "SOMERSET",
                "DORSET",
                "HAMPSHIRE",
                "SURREY",
                "BERKSHIRE",
                "WILTSHIRE",
                "GLOUCESTERSHIRE",
                "WARWICKSHIRE",
                "STAFFORDSHIRE",
                "NOTTINGHAMSHIRE",
                "LEICESTERSHIRE",
                "LINCOLNSHIRE",
                "SHROPSHIRE",
                "HEREFORDSHIRE",
                "WORCESTERSHIRE",
                "OXFORDSHIRE",
                "CAMBRIDGESHIRE",
                "BEDFORDSHIRE",
                "HERTFORDSHIRE",
                "BUCKINGHAMSHIRE",
                "EALING",
                "FOLKESTONE",
                "GREENWICH",
                "WIMBLEDON",
                "WESTMINSTER",
                "BUCKINGHAM",
            }
        ),
    ),
    (
        "Transport & travel",
        frozenset(
            {
                "BUS",
                "BUSES",
                "TRAIN",
                "TRAINS",
                "TRAM",
                "TUBE",
                "METRO",
                "TAXI",
                "CAB",
                "CAR",
                "CARS",
                "AUTOMOBILE",
                "AUTOMOBILES",
                "VEHICLE",
                "VEHICLES",
                "LORRY",
                "LORRIES",
                "VAN",
                "BIKE",
                "BICYCLE",
                "MOTORWAY",
                "HIGHWAY",
                "ROAD",
                "STREET",
                "LANE",
                "BRIDGE",
                "TUNNEL",
                "AIRPORT",
                "STATION",
                "PLATFORM",
                "TICKET",
                "JOURNEY",
                "TRAVEL",
                "DRIVER",
                "PILOT",
                "FERRY",
                "BOAT",
                "BOATS",
                "BOATING",
                "SAILING",
                "SAIL",
                "VESSEL",
                "VESSELS",
                "SHIP",
                "SHIPS",
                "YACHT",
                "YACHTS",
                "NAUTICAL",
                "MARITIME",
                "WARSHIP",
                "WARSHIPS",
                "FRIGATE",
                "FRIGATES",
                "CRUISER",
                "CRUISERS",
                "DESTROYER",
                "DESTROYERS",
                "SUBMARINE",
                "SUBMARINES",
                "SUBWAY",
                "UNDERGROUND",
                "ROUNDABOUT",
                "TRAFFIC",
                "PETROL",
                "DIESEL",
                "ENGINE",
                "WHEEL",
                "TYRE",
                "TIRE",
                "GARAGE",
                "PARKING",
                "HEATHROW",
                "GATWICK",
                "EUROSTAR",
            }
        ),
    ),
    (
        "Sport & games",
        frozenset(
            {
                "SPORT",
                "SPORTS",
                "FOOTBALL",
                "RUGBY",
                "CRICKET",
                "TENNIS",
                "GOLF",
                "HOCKEY",
                "BOXING",
                "RACING",
                "STADIUM",
                "PITCH",
                "GOAL",
                "GOALS",
                "MATCH",
                "LEAGUE",
                "TEAM",
                "PLAYER",
                "COACH",
                "REFEREE",
                "OLYMPIAD",
                "OLYMPIC",
                "MEDAL",
                "TROPHY",
                "WIMBLEDON",
                "WEMBLEY",
                "ATHLETE",
                "RUNNER",
                "SWIMMER",
                "CYCLIST",
                "FISHING",
                "CHESS",
                "DARTS",
                "BILLIARDS",
                "SNOOKER",
                "CRICKETERS",
                "FOOTBALLER",
            }
        ),
    ),
    (
        "Politics & government",
        frozenset(
            {
                "PARLIAMENT",
                "GOVERNMENT",
                "MINISTER",
                "PRIME",
                "COUNCIL",
                "MAYOR",
                "ELECTION",
                "VOTE",
                "VOTES",
                "PARTY",
                "POLICY",
                "LAW",
                "LAWS",
                "COURT",
                "JUDGE",
                "POLICE",
                "BOBBY",
                "CROWN",
                "ROYAL",
                "QUEEN",
                "KING",
                "DUKE",
                "LORD",
                "COMMONS",
                "LORDS",
                "SENATE",
                "CONGRESS",
                "EMBASSY",
                "TREATY",
                "BREXIT",
            }
        ),
    ),
    (
        "Civil rights & society",
        frozenset(
            {
                "OPPRESSION",
                "REPRESSION",
                "SUPPRESSION",
                "SUBJUGATION",
                "PERSECUTION",
                "DISCRIMINATION",
                "SEGREGATION",
                "APARTHEID",
                "LIBERATION",
                "EMANCIPATION",
                "INJUSTICE",
                "EQUALITY",
                "INEQUALITY",
                "PREJUDICE",
                "RACISM",
                "SEXISM",
                "COLONIALISM",
                "IMPERIALISM",
                "TYRANNY",
                "AUTOCRACY",
                "DICTATORSHIP",
                "CENSORSHIP",
                "PROPAGANDA",
                "ACTIVISM",
                "PROTEST",
                "DISSENT",
                "SUFFRAGE",
                "ABOLITION",
            }
        ),
    ),
    (
        "Nature & animals",
        frozenset(
            {
                "ANIMAL",
                "ANIMALS",
                "BIRD",
                "BIRDS",
                "FISH",
                "DOG",
                "DOGS",
                "CAT",
                "CATS",
                "HORSE",
                "COW",
                "SHEEP",
                "PIG",
                "GOAT",
                "DEER",
                "FOX",
                "BADGER",
                "OTTER",
                "HEDGEHOG",
                "RABBIT",
                "MOUSE",
                "RAT",
                "SNAKE",
                "FROG",
                "TREE",
                "TREES",
                "FLOWER",
                "GRASS",
                "LEAF",
                "ROOT",
                "SEED",
                "FOREST",
                "WOOD",
                "MEADOW",
                "GARDEN",
                "WEATHER",
                "RAIN",
                "STORM",
                "SNOW",
                "WIND",
                "SUN",
                "CLOUD",
                "DRIZZLE",
                "THUNDER",
                "LIGHTNING",
                "RAINBOW",
                "SEASON",
                "SPRING",
                "SUMMER",
                "AUTUMN",
                "WINTER",
                "EARTH",
                "RIVER",
                "LAKE",
                "MOUNTAIN",
                "VOLCANO",
                "BEEFEATER",
            }
        ),
    ),
    (
        "Arts & culture",
        frozenset(
            {
                "MUSIC",
                "MUSICAL",
                "SONG",
                "SONGS",
                "BAND",
                "SINGER",
                "CONCERT",
                "OPERA",
                "BALLET",
                "DANCE",
                "FILM",
                "MOVIE",
                "ACTOR",
                "ACTRESS",
                "STAGE",
                "DRAMA",
                "COMEDY",
                "NOVEL",
                "POEM",
                "POETRY",
                "AUTHOR",
                "PAINTING",
                "SCULPTURE",
                "PHOTO",
                "GALLERY",
                "MUSEUM",
                "FESTIVAL",
                "CULTURE",
                "HERITAGE",
            }
        ),
    ),
    (
        "Buildings & homes",
        frozenset(
            {
                "HOUSE",
                "HOUSES",
                "HOME",
                "HOMES",
                "BUILDING",
                "TOWER",
                "CASTLE",
                "PALACE",
                "CATHEDRAL",
                "CHURCH",
                "CHAPEL",
                "TEMPLE",
                "MOSQUE",
                "SYNAGOGUE",
                "THEATRE",
                "THEATER",
                "CINEMA",
                "HOSPITAL",
                "SCHOOL",
                "FACTORY",
                "WAREHOUSE",
                "SKYSCRAPER",
                "COTTAGE",
                "MANSION",
                "HUT",
                "SHED",
                "GARAGE",
                "ROOF",
                "WALL",
                "WALLS",
                "FLOOR",
                "DOOR",
                "WINDOW",
                "CHIMNEY",
                "CELLAR",
                "ATTIC",
                "POSTBOX",
                "POSTBOXES",
            }
        ),
    ),
    (
        "Science & technology",
        frozenset(
            {
                "SCIENCE",
                "SCIENTIST",
                "CHEMISTRY",
                "PHYSICS",
                "BIOLOGY",
                "ATOM",
                "ATOMS",
                "MOLECULE",
                "ENERGY",
                "ELECTRIC",
                "MAGNET",
                "RADIATION",
                "LABORATORY",
                "EXPERIMENT",
                "THEORY",
                "COMPUTER",
                "SOFTWARE",
                "HARDWARE",
                "DIGITAL",
                "INTERNET",
                "ROBOT",
                "ROCKET",
                "SATELLITE",
                "SPACE",
                "PLANET",
                "STAR",
                "GALAXY",
                "DATA",
                "CODE",
                "PROGRAM",
                "SENSOR",
                "BATTERY",
            }
        ),
    ),
    (
        "Body & health",
        frozenset(
            {
                "BODY",
                "HEALTH",
                "HEALTHY",
                "DOCTOR",
                "NURSE",
                "PATIENT",
                "HOSPITAL",
                "CLINIC",
                "MEDICINE",
                "DRUG",
                "BLOOD",
                "HEART",
                "BRAIN",
                "MUSCLE",
                "BONE",
                "SKIN",
                "HAND",
                "FOOT",
                "HEAD",
                "EYE",
                "EYES",
                "EAR",
                "NOSE",
                "PAIN",
                "FEVER",
                "VIRUS",
                "GERM",
            }
        ),
    ),
    (
        "Clothing & fashion",
        frozenset(
            {
                "SHIRT",
                "TROUSERS",
                "PANTS",
                "DRESS",
                "SKIRT",
                "JACKET",
                "COAT",
                "JUMPER",
                "SWEATER",
                "HAT",
                "CAP",
                "SHOES",
                "BOOTS",
                "SOCKS",
                "TRAINERS",
                "SNEAKERS",
                "TIE",
                "SCARF",
                "GLOVES",
                "UNIFORM",
                "FABRIC",
                "COTTON",
                "WOOL",
                "SILK",
                "LEATHER",
                "BUTTON",
                "ZIP",
                "WELLIES",
                "BROLLY",
                "UMBRELLA",
            }
        ),
    ),
    (
        "Work & business",
        frozenset(
            {
                "WORK",
                "WORKER",
                "JOB",
                "JOBS",
                "OFFICE",
                "BOSS",
                "MANAGER",
                "COMPANY",
                "BUSINESS",
                "MONEY",
                "SALARY",
                "WAGE",
                "TRADE",
                "MARKET",
                "SHOP",
                "STORE",
                "BUY",
                "SELL",
                "PRICE",
                "COST",
                "PROFIT",
                "BANK",
                "CASH",
                "COIN",
                "STOCK",
                "SHARE",
                "DEAL",
                "CLIENT",
                "MEETING",
                "EMAIL",
                "LETTER",
                "FAX",
            }
        ),
    ),
    (
        "Emotions & social",
        frozenset(
            {
                "HAPPY",
                "SAD",
                "ANGRY",
                "AFRAID",
                "LOVE",
                "HATE",
                "FEAR",
                "HOPE",
                "DREAM",
                "CHEEKY",
                "CHUFFED",
                "PECKISH",
                "SKINT",
                "BRILLIANT",
                "CHEERS",
                "MATE",
                "BLOKE",
                "PLONKER",
                "CODSWALLOP",
                "GOBSMACKED",
                "KNACKERED",
                "SORRY",
                "FRIEND",
                "FAMILY",
                "CHILD",
                "MOTHER",
                "FATHER",
                "SISTER",
                "BROTHER",
                "WEDDING",
                "PARTY",
                "GREETING",
            }
        ),
    ),
    (
        "Abstract & concepts",
        frozenset(
            {
                "TIME",
                "YEAR",
                "DAY",
                "NIGHT",
                "MORNING",
                "EVENING",
                "IDEA",
                "IDEAS",
                "THOUGHT",
                "MIND",
                "TRUTH",
                "REASON",
                "FACT",
                "FACTS",
                "QUESTION",
                "ANSWER",
                "PROBLEM",
                "CHANCE",
                "LUCK",
                "RISK",
                "POWER",
                "ORDER",
                "CHAOS",
                "PEACE",
                "WAR",
                "RIGHT",
                "WRONG",
                "CORPORATION",
            }
        ),
    ),
]

# Tokens that appear in many dictionary definitions and skew gloss-only scoring.
_GLOSS_STOPWORDS: frozenset[str] = frozenset(
    {
        "A",
        "AN",
        "THE",
        "AND",
        "OR",
        "BUT",
        "IF",
        "AS",
        "AT",
        "BY",
        "FOR",
        "IN",
        "INTO",
        "IS",
        "IT",
        "ITS",
        "OF",
        "ON",
        "TO",
        "SO",
        "THAN",
        "THAT",
        "THIS",
        "THESE",
        "THOSE",
        "WITH",
        "FROM",
        "BE",
        "ARE",
        "WAS",
        "WERE",
        "BEEN",
        "BEING",
        "HAVE",
        "HAS",
        "HAD",
        "DO",
        "DOES",
        "DID",
        "WILL",
        "WOULD",
        "SHALL",
        "SHOULD",
        "MAY",
        "MIGHT",
        "MUST",
        "CAN",
        "COULD",
        "NOT",
        "NO",
        "SOME",
        "ANY",
        "ALL",
        "BOTH",
        "EACH",
        "EVERY",
        "FEW",
        "MORE",
        "MOST",
        "OTHER",
        "SUCH",
        "ONE",
        "TWO",
        "WHICH",
        "WHO",
        "WHOM",
        "WHOSE",
        "WHAT",
        "WHERE",
        "WHEN",
        "WHY",
        "HOW",
        "THERE",
        "HERE",
        "THEN",
        "TOO",
        "VERY",
        "JUST",
        "ONLY",
        "ALSO",
        "EVEN",
        "LIKE",
        "KIND",
        "SORT",
        "TYPE",
        "FORM",
        "WAY",
        "MANNER",
        "THING",
        "THINGS",
        "SOMETHING",
        "ANYTHING",
        "NOTHING",
        "EVERYTHING",
        "SOMEONE",
        "ANYONE",
        "PERSON",
        "PEOPLE",
        "USED",
        "USING",
        "MAKE",
        "MADE",
        "MAKES",
        "MAKING",
        "CAUSE",
        "SMALL",
        "LARGE",
        "GREAT",
        "GOOD",
        "NEW",
        "OLD",
        "LONG",
        "HIGH",
        "LOW",
        "RIGHT",
        "LEFT",
        "SAME",
        "DIFFERENT",
        "SIMILAR",
        "GENERAL",
        "PARTICULAR",
        "SPECIAL",
        "CERTAIN",
        "VARIOUS",
        "RELATING",
        "RELATED",
        "ANOTHER",
        "ACROSS",
        "AROUND",
        "AGAINST",
        "WITHOUT",
        "WITHIN",
        "BETWEEN",
        "AMONG",
        "STATE",
        "ACT",
        "QUALITY",
        "POWER",
        "PERIOD",
        "DEGREE",
        "LEVEL",
        "AMOUNT",
        "NUMBER",
        "POINT",
        "CASE",
        "EXAMPLE",
        "INSTANCE",
        "RESPECT",
        "CONSISTING",
        "COMPOSING",
        "INCLUDING",
        "ESPECIALLY",
        "USUALLY",
        "OFTEN",
        "SOMETIMES",
        "PERHAPS",
        "ABLE",
        "ABOUT",
        "ABOVE",
        "AFTER",
        "AGAIN",
        "ALMOST",
        "ALREADY",
        "ALTHOUGH",
        "ALWAYS",
        "BECAUSE",
        "BEFORE",
        "BEHIND",
        "BELOW",
        "BESIDE",
        "BEYOND",
        "CONSIDERED",
        "DESCRIBED",
        "DESIGNATED",
        "DONE",
        "DOWN",
        "DURING",
        "EITHER",
        "ENOUGH",
        "EVER",
        "EVERYWHERE",
        "EXCEPT",
        "FAR",
        "FURTHER",
        "GIVEN",
        "HAVING",
        "HOWEVER",
        "INDEED",
        "INSTEAD",
        "INVOLVING",
        "ITSELF",
        "KNOW",
        "KNOWN",
        "LATTER",
        "LEAST",
        "LESS",
        "LIKELY",
        "LITTLE",
        "MANY",
        "MEAN",
        "MEANS",
        "MERELY",
        "MUCH",
        "MYSELF",
        "NEAR",
        "NEARLY",
        "NEITHER",
        "NEVER",
        "NEXT",
        "NONE",
        "NORMAL",
        "ONCE",
        "OUR",
        "OUT",
        "OUTSIDE",
        "OVER",
        "OWN",
        "PER",
        "QUITE",
        "RATHER",
        "REALLY",
        "REGARDING",
        "SEEM",
        "SEEMS",
        "SEEN",
        "SEVERAL",
        "SHALL",
        "SHE",
        "SHOULD",
        "SIMPLY",
        "SINCE",
        "STILL",
        "SUCH",
        "THAN",
        "THAT",
        "THEIR",
        "THEM",
        "THEMSELVES",
        "THEREFORE",
        "THROUGH",
        "THROUGHOUT",
        "THUS",
        "TOWARD",
        "TOWARDS",
        "UNDER",
        "UNLESS",
        "UNTIL",
        "UPON",
        "VARIOUS",
        "VERY",
        "WANT",
        "WELL",
        "WHETHER",
        "WHILE",
        "WHOSE",
        "WHY",
        "WILL",
        "WITH",
        "WITHIN",
        "WITHOUT",
        "YET",
        "YOUR",
        "YOURS",
    }
)


def _topic_keywords_for_gloss() -> list[tuple[str, frozenset[str]]]:
    """Slightly stricter buckets for definition text (fewer false positives)."""
    out: list[tuple[str, frozenset[str]]] = []
    for label, kw in TOPIC_KEYWORDS:
        if label == "Drinks & beverages":
            out.append(
                (
                    label,
                    frozenset(
                        kw
                        - {
                            "WATER",
                            "MILK",
                            "BOTTLE",
                            "PINT",
                            "KETTLE",
                            "TEAPOT",
                        }
                    ),
                )
            )
        elif label == "Food & drink (general)":
            out.append((label, frozenset(kw - {"SALT", "PEPPER", "SUGAR"})))
        else:
            out.append((label, kw))
    return out


TOPIC_KEYWORDS_GLOSS: list[tuple[str, frozenset[str]]] = _topic_keywords_for_gloss()


# Compounds only: stem length >= 5 to avoid noise (e.g. HAM in random words).
SUBSTRING_TOPICS: list[tuple[str, tuple[str, ...]]] = [
    ("Education & learning", ("UNIVERSITY", "COLLEGE", "SCHOOL", "CAMPUS", "LECTURE", "STUDENT")),
    ("Food & drink (general)", ("BREAKFAST", "SANDWICH", "CHOCOLATE", "RESTAURANT")),
    ("Transport & travel", ("AIRPORT", "STATION", "MOTORWAY")),
    ("Science & technology", ("TECHNOLOGY", "COMPUTER", "DIGITAL")),
]

# Lazy: wordfreq is optional (same as word-bank build); improves "how common is this word" hints.
_zipf_frequency_fn: object | None = None


def _get_zipf_frequency():
    global _zipf_frequency_fn
    if _zipf_frequency_fn is False:
        return None
    if _zipf_frequency_fn is not None:
        return _zipf_frequency_fn
    try:
        from wordfreq import zipf_frequency as zf  # type: ignore[import-untyped]

        _zipf_frequency_fn = zf
        return zf
    except ImportError:
        _zipf_frequency_fn = False
        return None


def _morphology_hint(word: str) -> str | None:
    """
    Cheap suffix-based hint for single-token answers when no keyword matched.
    Describes typical grammar / ending pattern — not geometric "shape".
    """
    w = word.strip().upper()
    if len(w) < 3:
        return None
    # Longer / more specific suffixes first
    pairs: list[tuple[tuple[str, ...], str]] = [
        (("TION", "SION"), "Grammar · many abstract nouns end in -tion / -sion"),
        (("NESS",), "Grammar · quality or state (-ness)"),
        (("MENT",), "Grammar · often noun (-ment)"),
        (("ANCE", "ENCE"), "Grammar · often noun (-ance / -ence)"),
        (("ABLE", "IBLE"), "Grammar · often adjective (-able / -ible)"),
        (("EOUS", "IOUS", "UOUS"), "Grammar · often adjective (-ous)"),
        (("OUS",), "Grammar · often adjective (-ous)"),
        (("IVE",), "Grammar · often adjective (-ive)"),
        (("FUL",), "Grammar · with / full of (-ful)"),
        (("LESS",), "Grammar · without (-less)"),
        (("ISH",), "Grammar · somewhat (-ish)"),
        (("ARY", "ORY"), "Grammar · adjective or noun (-ary / -ory)"),
        (("IZE", "ISE"), "Grammar · verb pattern (-ise / -ize)"),
    ]
    for suffixes, label in pairs:
        if any(w.endswith(s) for s in suffixes):
            return label
    if len(w) > 4 and w.endswith("ING"):
        return "Grammar · often gerund or adjective (-ing)"
    if len(w) > 3 and w.endswith("ED"):
        return "Grammar · often past tense or adjective (-ed)"
    if len(w) > 3 and w.endswith("LY"):
        return "Grammar · often adverb (-ly)"
    return None


def _frequency_hint(word: str) -> str | None:
    zf = _get_zipf_frequency()
    if zf is None:
        return None
    try:
        z = float(zf(word.lower(), "en"))
    except Exception:
        return None
    if z <= 0:
        return None
    if z >= 5.2:
        return "Frequency · very common (printed English)"
    if z >= 4.3:
        return "Frequency · common word"
    if z >= 3.45:
        return "Frequency · everyday vocabulary"
    if z >= 2.75:
        return "Frequency · less common"
    return "Frequency · rare or specialized"


def _infer_fallback_topic(secret: str) -> str:
    """When keyword sets miss (most random dictionary words), still show something useful."""
    words = _words(secret)
    if not words:
        return "Vocabulary · English"
    if len(words) >= 2:
        return f"Phrase · {len(words)} words"

    w = words[0]
    m = _morphology_hint(w)
    if m:
        return m
    f = _frequency_hint(w)
    if f:
        return f
    n = len(w)
    if n <= 4:
        return "Length · short word (≤4 letters)"
    if n <= 8:
        return "Length · medium word (5–8 letters)"
    return "Length · long word (9+ letters)"


def _normalize_secret_key(secret: str) -> str:
    s = secret.upper().strip()
    s = re.sub(r"[^A-Z\s]", "", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def _words(secret: str) -> list[str]:
    return [w for w in _normalize_secret_key(secret).split() if w]


def default_theme_map_path() -> Path:
    raw = os.environ.get("HANGMAN_WORD_THEME_MAP_PATH", "").strip()
    if raw:
        p = Path(raw).expanduser()
        root = Path(__file__).resolve().parent
        return p.resolve() if p.is_absolute() else (root / p).resolve()
    return Path(__file__).resolve().parent / "data" / "word_theme_map.json"


def _load_theme_map() -> dict[str, str]:
    global _theme_map_cache
    with _theme_map_lock:
        if _theme_map_cache is not None:
            return _theme_map_cache
        p = default_theme_map_path()
        if not p.is_file():
            _theme_map_cache = {}
            return _theme_map_cache
        try:
            with open(p, encoding="utf-8") as f:
                raw = json.load(f)
        except (json.JSONDecodeError, OSError):
            _theme_map_cache = {}
            return _theme_map_cache
        if not isinstance(raw, dict):
            _theme_map_cache = {}
            return _theme_map_cache
        inner = raw.get("themes") if isinstance(raw.get("themes"), dict) else raw
        if not isinstance(inner, dict):
            _theme_map_cache = {}
            return _theme_map_cache
        out: dict[str, str] = {}
        for k, v in inner.items():
            ks = str(k).strip()
            if ks.startswith("_") or not isinstance(v, str):
                continue
            nk = _normalize_secret_key(ks)
            vv = v.strip()
            if nk and vv:
                out[nk] = vv
        _theme_map_cache = out
        return _theme_map_cache


def _bag_from_english_text(text: str) -> frozenset[str]:
    raw = re.sub(r"[^A-Za-z\s]", " ", text.upper())
    return frozenset(w for w in raw.split() if len(w) >= 2)


def _bag_from_gloss_text(text: str) -> frozenset[str]:
    bag = _bag_from_english_text(text)
    return frozenset(w for w in bag if w not in _GLOSS_STOPWORDS)


def _score_topics_for_bag_with(
    bag: frozenset[str],
    topic_rows: list[tuple[str, frozenset[str]]],
) -> tuple[str | None, int, int, int]:
    if not bag:
        return None, 0, 0, 0
    best_label: str | None = None
    best_exact = 0
    best_stem = 0
    best_score = 0
    stem_hits_by_label: dict[str, int] = {}
    for w in bag:
        for label, stems in SUBSTRING_TOPICS:
            for stem in stems:
                if len(stem) >= 5 and stem in w and w != stem:
                    stem_hits_by_label[label] = stem_hits_by_label.get(label, 0) + 1
                    break

    for label, keywords in topic_rows:
        exact_hits = len(bag & keywords)
        stem_hits = stem_hits_by_label.get(label, 0)
        score = exact_hits * 12 + stem_hits * 2
        if score <= 0:
            continue
        if (
            score > best_score
            or (score == best_score and exact_hits > best_exact)
            or (score == best_score and exact_hits == best_exact and stem_hits > best_stem)
        ):
            best_label = label
            best_exact = exact_hits
            best_stem = stem_hits
            best_score = score

    if best_score > 0 and best_label is not None:
        return best_label, best_score, best_exact, best_stem
    return None, 0, 0, 0


def _score_topics_for_bag(bag: frozenset[str]) -> tuple[str | None, int, int, int]:
    return _score_topics_for_bag_with(bag, TOPIC_KEYWORDS)


def _scrub_headword_tokens_from_text(text: str, head_tokens: frozenset[str]) -> str:
    t = text
    for hw in head_tokens:
        if len(hw) >= 2:
            t = re.sub(rf"\b{re.escape(hw)}\b", " ", t, flags=re.IGNORECASE)
    return re.sub(r"\s+", " ", t).strip()


def classify_topic_from_gloss(
    head_tokens: frozenset[str], gloss: str, part_of_speech: str | None = None
) -> str | None:
    """Classify using dictionary definition text (keywords), not the surface answer."""
    scrubbed = _scrub_headword_tokens_from_text(gloss, head_tokens)
    chunks = [scrubbed]
    if part_of_speech:
        chunks.append(part_of_speech.upper().replace("-", " "))
    blob = " ".join(c for c in chunks if c)
    bag = _bag_from_gloss_text(blob)
    label, score, _, _ = _score_topics_for_bag_with(bag, TOPIC_KEYWORDS_GLOSS)
    if label and score > 0:
        return label
    return None


def _dictionary_pos_fallback_label(part_of_speech: str) -> str:
    p = part_of_speech.strip().lower()
    mapping = {
        "noun": "Dictionary sense · noun",
        "verb": "Dictionary sense · verb",
        "adjective": "Dictionary sense · adjective",
        "adverb": "Dictionary sense · adverb",
        "pronoun": "Dictionary sense · pronoun",
        "preposition": "Dictionary sense · preposition",
        "conjunction": "Dictionary sense · conjunction",
        "interjection": "Dictionary sense · interjection",
    }
    return mapping.get(p, f"Dictionary sense · {p}")


def classify_secret_topic(secret: str) -> str:
    """
    Return a short topic label for UI (e.g. 'Education & learning').
    Does not reveal the answer.
    """
    key = _normalize_secret_key(secret)
    if key in EXACT_PHRASE_TOPICS:
        return EXACT_PHRASE_TOPICS[key]

    bag = frozenset(_words(secret))
    if not bag:
        return _infer_fallback_topic(secret)

    label, score, _, _ = _score_topics_for_bag(bag)
    if label and score > 0:
        return label

    return _infer_fallback_topic(secret)


def theme_is_weak_heuristic_label(label: str) -> bool:
    """True if the label is a generic fallback (offline builder may replace with OpenAI)."""
    s = label.strip()
    weak_prefixes = (
        "Dictionary sense ·",
        "Grammar ·",
        "Length ·",
        "Frequency ·",
        "Vocabulary ·",
    )
    return any(s.startswith(p) for p in weak_prefixes)


def theme_for_bank_line_build(
    bank_line: str,
    *,
    definition: str | None = None,
    part_of_speech: str | None = None,
) -> str:
    """
    Theme string stored in ``word_theme_map.json`` (no ``Theme:`` prefix).
    Built offline by ``scripts/build_word_themes.py``.
    """
    key = _normalize_secret_key(bank_line)
    if not key:
        return "Vocabulary · English"
    words_bag = frozenset(_words(bank_line))
    if len(words_bag) >= 2:
        return classify_secret_topic(bank_line)
    if definition and words_bag:
        inferred = classify_topic_from_gloss(words_bag, definition, part_of_speech)
        if inferred:
            return inferred
    if part_of_speech:
        return _dictionary_pos_fallback_label(part_of_speech)
    return classify_secret_topic(bank_line)


def word_theme_label(secret: str) -> str:
    """Full line for the web UI."""
    nk = _normalize_secret_key(secret)
    mapped = _load_theme_map().get(nk)
    if mapped:
        return f"Theme: {mapped}"
    heuristic = classify_secret_topic(secret)
    topic = heuristic
    if (
        os.environ.get("HANGMAN_OPENAI_API_KEY", "").strip()
        or os.environ.get("HANGMAN_WORD_THEME_API_KEY", "").strip()
    ):
        try:
            from word_topic_ai import fetch_ai_topic_cached

            ai_topic = fetch_ai_topic_cached(secret, heuristic_hint=heuristic)
            if ai_topic:
                topic = ai_topic
        except Exception:
            pass
    return f"Theme: {topic}"
