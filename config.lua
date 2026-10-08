Config = {}

-- Prints extra info to the F8 / server console. Setup errors are always printed.
Config.Debug = false

-- "en", "sv" or "auto" (follows the replicated ox:locale convar: setr ox:locale "sv")
Config.Locale = "en"

-- "auto" (detected by the server: qbx_core, es_extended, qb-core), "esx", "qb", "qbx" or "custom"
Config.Framework = "auto"

-- "auto" (ox_target, then qb-target, else [E] + text UI), "ox_target", "qb-target" or "none" ([E] + text UI)
Config.Target = "auto"

-- Draw ground markers at the garage and the store point
Config.DrawMarkers = true

-- QBCore / QBox: the player must be on duty to use a garage. ESX has no duty state and ignores this.
Config.RequireDuty = false

-- Plate for every vehicle that has no `plate` of its own (max 8 characters).
-- false = a random plate: Config.PlatePrefix followed by random digits up to 8 characters.
Config.DefaultPlate = false
Config.PlatePrefix = "LSPD"

-- Seconds between two take-outs by the same player
Config.Cooldown = 5

-- Garage vehicles one player can have out at once. Taking out one more deletes the oldest one, unless
-- someone sits in it (then the player has to store a vehicle first).
Config.MaxVehiclesPerPlayer = 1

-- Put the player in the driver seat after the vehicle spawned
Config.WarpIntoVehicle = true

-- Delete every garage vehicle that is still out when force_policegarage stops or restarts
Config.DeleteVehiclesOnStop = true

-- Delete a player's garage vehicles when they disconnect
Config.DeleteVehiclesOnDisconnect = false

-- How far (meters) a player may be from the garage point when taking out a vehicle (checked on the server)
Config.InteractDistance = 5.0

--[[
  Garages. Each key is the garage id.
  label       = menu title
  jobs        = { [job name] = minimum grade }. Only these jobs can use the garage.
  coords      = where the menu is opened (target zone or [E] point)
  ped         = optional ped standing at the garage: { model, coords = vec4 }, or false for none
  spawnPoints = list of vec4, the first free one is used
  store       = { coords, radius }: drive a vehicle from this garage here and press [E] to store it
  vehicles    = list of { model, label, grade (optional minimum grade), plate (optional), type (optional) }
                `type` is needed to spawn the vehicle on the server: "automobile" (default), "bike", "heli",
                "boat", "plane", "submarine", "trailer" or "train". Motorbikes need "bike".
]]
Config.Garages = {
    mrpd = {
        label = "Police Garage",
        jobs = { police = 0 },
        coords = vec3(443.38, -1013.92, 28.61),
        ped = { model = "s_m_y_cop_01", coords = vec4(443.29, -1012.90, 27.61, 180.0) },
        spawnPoints = {
            vec4(443.90, -1019.13, 28.64, 90.0),
        },
        store = { coords = vec3(443.90, -1019.13, 28.64), radius = 4.0 },
        vehicles = {
            { model = "police",  label = "Police Cruiser" },
            { model = "police2", label = "Police Buffalo" },
            { model = "police3", label = "Police Interceptor" },
            { model = "policeb", label = "Police Bike", type = "bike" },
            { model = "policet", label = "Police Transporter", grade = 1 },
            { model = "police4", label = "Unmarked Cruiser", grade = 2 },
        },
    },
}
