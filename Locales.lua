local ADDON_NAME, ns = ...

-- =========================================================
-- TRANSLATIONS (fr / en)
-- =========================================================
local L = {
    fr = {
        -- XP bar
        BAR_LEVEL = "Niveau",
        BAR_MOBS = "Mobs",
        BAR_RESTED = "Repos",

        -- Options menu
        LANGUAGE = "Langue",
        LANGUAGE_DESC = "Change la langue de l'addon.",
        SECTION_PREVIEW = "APERÇU",
        SECTION_STYLE = "STYLE",
        STYLE_CLASSIC = "Classique",
        STYLE_GOLD = "Encadrée or",
        STYLE_SEGMENTS = "Segmentée",
        STYLE_THIN = "Ligne fine",
        STYLE_SPARK = "Étincelle",
        STYLE_RESTEDBAR = "Repos séparé",
        SECTION_SIZE = "DIMENSIONS",
        SECTION_COLORS = "COULEURS",
        SECTION_OPTIONS = "OPTIONS",
        WIDTH = "Largeur",
        HEIGHT = "Hauteur",
        XP_COLOR = "Barre d'XP",
        RESTED_COLOR = "XP de repos",
        BG_OPACITY = "Opacité du fond",
        CUSTOM_COLOR = "Couleur personnalisée",
        CUSTOM_COLOR_DESC = "Clique pour ouvrir la roue des couleurs.",
        LOCK = "Verrouiller la barre",
        LOCK_DESC = "Empêche de déplacer la barre par erreur.",
        HIDE_BLIZZARD = "Masquer barre Blizzard",
        HIDE_BLIZZARD_DESC = "Cache la barre d'XP d'origine en bas de l'écran.",
        SOUND = "Son à chaque gain d'XP",
        SHOW_TEXT = "Textes sur la barre",
        SHOW_TEXT_DESC = "Niveau, XP actuelle / max, mobs restants et pourcentage.",
        SMOOTH = "Animation fluide",
        SMOOTH_DESC = "La barre glisse jusqu'à sa nouvelle valeur au lieu de sauter.",
        SHOW_GAINS = "Afficher « +XP »",
        SHOW_GAINS_DESC = "Un « +245 XP » monte au-dessus de la barre à chaque gain.",
        SHOW_RESTED = "Texte « Repos »",
        SHOW_RESTED_DESC = "Affiche le pourcentage d'XP de repos sous la barre.",
        MINIMAP = "Bouton minimap",
        MINIMAP_DESC = "Si tu le caches, tape /mxp pour rouvrir ce menu.",
        FULL_WIDTH = "Toute la largeur de l'écran",
        FULL_WIDTH_DESC = "La barre s'étire d'un bord à l'autre de l'écran, quelle que soit ta résolution. La largeur réglée plus haut est alors ignorée.",
        REP_HOVER = "Réputation au survol",
        REP_HOVER_DESC = "Passe la souris sur la barre pour voir ta réputation suivie. Ignoré quand la barre de réputation est affichée.",
        REP_BAR = "Barre de réputation",
        REP_BAR_DESC = "Une barre fine sous la barre d’XP, avec la faction suivie et sa progression.",
        SHOW_SESSION = "XP/h et temps restant",
        SHOW_SESSION_DESC = "Sous la barre : ton XP par heure et le temps estimé jusqu’au niveau visé, calculés depuis ta connexion.",
        TARGET_LEVEL = "Objectif de niveau",
        TARGET_NEXT = "Niveau suivant",
        SESSION_XPH = "%s XP/h",
        SESSION_ETA = "niveau %d dans ~%s",
        HOUR_SHORT = "h",
        MINUTE_SHORT = "min",
        REP_NONE = "Aucune réputation suivie",
        REP_NONE_DESC = "Dans le panneau Réputation, coche « Afficher dans la barre d'expérience » pour une faction.",
        RESET_POSITION = "Recentrer la barre",
        RESET_ALL = "Tout réinitialiser",
        HINT = "Menu ouvert : glisse la barre directement pour la déplacer.\nSinon : Shift + clic gauche.  ·  Commande : /mxp",

        -- Color names
        VIOLET = "Violet", BLUE = "Bleu", CYAN = "Cyan", GREEN = "Vert",
        GOLD = "Or", ORANGE = "Orange", RED = "Rouge", PINK = "Rose",

        -- Minimap button
        TT_LEVEL = "Niveau",
        TT_XP = "XP",
        TT_RESTED = "Repos",
        TT_LEFT_CLICK = "|cffffffffClic gauche|r : options",
        TT_RIGHT_CLICK = "|cffffffffClic droit|r : verrouiller / déverrouiller",
        TT_DRAG = "|cffffffffGlisser|r : déplacer ce bouton",
        CHAT_LOCKED = "barre verrouillée.",
        CHAT_UNLOCKED = "barre déverrouillée.",
    },

    en = {
        -- XP bar
        BAR_LEVEL = "Level",
        BAR_MOBS = "Mobs",
        BAR_RESTED = "Rested",

        -- Options menu
        LANGUAGE = "Language",
        LANGUAGE_DESC = "Change the addon language.",
        SECTION_PREVIEW = "PREVIEW",
        SECTION_STYLE = "STYLE",
        STYLE_CLASSIC = "Classic",
        STYLE_GOLD = "Gold framed",
        STYLE_SEGMENTS = "Segmented",
        STYLE_THIN = "Thin line",
        STYLE_SPARK = "Spark",
        STYLE_RESTEDBAR = "Split rested",
        SECTION_SIZE = "SIZE",
        SECTION_COLORS = "COLORS",
        SECTION_OPTIONS = "OPTIONS",
        WIDTH = "Width",
        HEIGHT = "Height",
        XP_COLOR = "XP bar",
        RESTED_COLOR = "Rested XP",
        BG_OPACITY = "Background opacity",
        CUSTOM_COLOR = "Custom color",
        CUSTOM_COLOR_DESC = "Click to open the color wheel.",
        LOCK = "Lock the bar",
        LOCK_DESC = "Prevents moving the bar by accident.",
        HIDE_BLIZZARD = "Hide Blizzard XP bar",
        HIDE_BLIZZARD_DESC = "Hides the default XP bar at the bottom of the screen.",
        SOUND = "Sound on XP gain",
        SHOW_TEXT = "Texts on the bar",
        SHOW_TEXT_DESC = "Level, current / max XP, mobs left and percentage.",
        SMOOTH = "Smooth animation",
        SMOOTH_DESC = "The bar slides to its new value instead of jumping.",
        SHOW_GAINS = "Show \"+XP\"",
        SHOW_GAINS_DESC = "A floating \"+245 XP\" rises above the bar on every gain.",
        SHOW_RESTED = "\"Rested\" text",
        SHOW_RESTED_DESC = "Shows the rested XP percentage under the bar.",
        MINIMAP = "Minimap button",
        MINIMAP_DESC = "If you hide it, type /mxp to open this menu again.",
        FULL_WIDTH = "Full screen width",
        FULL_WIDTH_DESC = "The bar stretches from one edge of the screen to the other, at any resolution. The width set above is ignored.",
        REP_HOVER = "Reputation on hover",
        REP_HOVER_DESC = "Mouse over the bar to see your tracked reputation. Ignored while the reputation bar is shown.",
        REP_BAR = "Reputation bar",
        REP_BAR_DESC = "A thin bar under the XP bar, with your tracked faction and its progress.",
        SHOW_SESSION = "XP/h and time left",
        SHOW_SESSION_DESC = "Under the bar: your XP per hour and the estimated time to the level you aim for, since you logged in.",
        TARGET_LEVEL = "Target level",
        TARGET_NEXT = "Next level",
        SESSION_XPH = "%s XP/h",
        SESSION_ETA = "level %d in ~%s",
        HOUR_SHORT = "h",
        MINUTE_SHORT = "min",
        REP_NONE = "No reputation tracked",
        REP_NONE_DESC = "In the Reputation panel, check \"Show as Experience Bar\" for a faction.",
        RESET_POSITION = "Recenter the bar",
        RESET_ALL = "Reset everything",
        HINT = "Menu open: drag the bar directly to move it.\nOtherwise: Shift + left click.  ·  Command: /mxp",

        -- Color names
        VIOLET = "Purple", BLUE = "Blue", CYAN = "Cyan", GREEN = "Green",
        GOLD = "Gold", ORANGE = "Orange", RED = "Red", PINK = "Pink",

        -- Minimap button
        TT_LEVEL = "Level",
        TT_XP = "XP",
        TT_RESTED = "Rested",
        TT_LEFT_CLICK = "|cffffffffLeft click|r: options",
        TT_RIGHT_CLICK = "|cffffffffRight click|r: lock / unlock",
        TT_DRAG = "|cffffffffDrag|r: move this button",
        CHAT_LOCKED = "bar locked.",
        CHAT_UNLOCKED = "bar unlocked.",
    },
}

ns.LANGUAGES = { "fr", "en" }

-- Language of the game client, used until the player picks one
function ns.DefaultLanguage()
    return (GetLocale() == "frFR") and "fr" or "en"
end

-- Translated text for a key, in the chosen language
function ns.T(key)
    local lang = (ns.db and ns.db.language) or ns.DefaultLanguage()
    local strings = L[lang] or L.en
    return strings[key] or L.en[key] or key
end
