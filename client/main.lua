local RESOURCE = GetCurrentResourceName()
local MENU_ID = RESOURCE .. ":menu"
local CALLBACK_TIMEOUT = 15000
local PED_DISTANCE = 60.0
local MARKER_DISTANCE = 15.0
local KEY_E = 38

local peds = {}         -- [garage id] = ped handle
local pedWanted = {}    -- [garage id] = true while the player is near the ped
local points = {}       -- lib.points
local oxZones = {}      -- ox_target zone ids
local qbZones = {}      -- qb-target zone names
local shownText = nil   -- key of the text UI this resource shows
local busy = false
local lastKeyPress = 0

local function notify(message, notifyType)
  lib.notify({ description = message, type = notifyType or "inform" })
end

local function showText(key, text)
  if shownText == key then return end
  lib.showTextUI(text)
  shownText = key
end

local function hideText(key)
  if not shownText or (key and shownText ~= key) then return end
  lib.hideTextUI()
  shownText = nil
end

local function canUse(garage)
  return CanUseGarage(garage, GetPlayerJob())
end

--- lib.callback with its own timeout (ox_lib waits 5 minutes and throws). Returns nil when the server didn't answer.
local function awaitServer(name, ...)
  local p = promise.new()
  local settled = false
  local function settle(value)
    if settled then return end
    settled = true
    p:resolve(value)
  end
  lib.callback(name, false, function(...)
    settle({ n = select("#", ...), ... })
  end, ...)
  SetTimeout(CALLBACK_TIMEOUT, function() settle(false) end)
  local result = Citizen.Await(p)
  if not result then return nil end
  return table.unpack(result, 1, result.n)
end

local function warpIntoVehicle(netId)
  if type(netId) ~= "number" then return end
  local deadline = GetGameTimer() + 5000
  while not NetworkDoesNetworkIdExist(netId) and GetGameTimer() < deadline do Wait(50) end
  if not NetworkDoesNetworkIdExist(netId) then return end
  local vehicle = NetToVeh(netId)
  if vehicle ~= 0 and DoesEntityExist(vehicle) then
    TaskWarpPedIntoVehicle(cache.ped, vehicle, -1)
  end
end

--- Asks the server for a vehicle. The server checks the job, grade, distance and cooldown again.
--- @param garageId string
--- @param index number index in the garage's vehicles list
function TakeOutVehicle(garageId, index)
  if busy then return notify(locale("busy"), "error") end
  busy = true
  local ok, success, result = pcall(awaitServer, RESOURCE .. ":server:takeOut", garageId, index)
  busy = false

  if not ok then
    Debug("error", "Taking out a vehicle failed: %s", tostring(success))
    return notify(locale("server_no_response"), "error")
  end
  if success == nil then return notify(locale("server_no_response"), "error") end
  if not success then return notify(locale(type(result) == "string" and result or "spawn_failed"), "error") end

  notify(locale("taken_out", result.label), "success")
  if Config.WarpIntoVehicle then warpIntoVehicle(result.netId) end
end

--- Stores a garage vehicle. The server checks that it is a garage vehicle at a store point.
--- @param vehicle number
function StoreVehicle(vehicle)
  if busy then return end
  if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return notify(locale("no_vehicle"), "error") end
  busy = true
  local ok, success, reason = pcall(function()
    return awaitServer(RESOURCE .. ":server:store", NetworkGetNetworkIdFromEntity(vehicle))
  end)
  busy = false

  if not ok then
    Debug("error", "Storing a vehicle failed: %s", tostring(success))
    return notify(locale("server_no_response"), "error")
  end
  if success == nil then return notify(locale("server_no_response"), "error") end
  if not success then return notify(locale(type(reason) == "string" and reason or "not_garage_vehicle"), "error") end
  notify(locale("stored"), "success")
end

--- Opens the vehicle list of a garage (only the vehicles the player's grade allows)
--- @param garageId string
function OpenGarageMenu(garageId)
  local garage = GetGarage(garageId)
  if not garage then return end
  local job = GetPlayerJob()
  if not CanUseGarage(garage, job) then return notify(locale("not_allowed"), "error") end

  local options = {}
  for index, vehicle in ipairs(garage.vehicles) do
    if CanUseVehicle(garage, vehicle, job) then
      options[#options + 1] = {
        title = vehicle.label,
        description = locale("menu_vehicle_description"),
        icon = vehicle.type == "bike" and "motorcycle" or vehicle.type == "heli" and "helicopter" or "car",
        onSelect = function() TakeOutVehicle(garageId, index) end,
      }
    end
  end
  if #options == 0 then return notify(locale("no_vehicles"), "error") end

  lib.registerContext({ id = MENU_ID, title = garage.label, options = options })
  lib.showContext(MENU_ID)
end

-------------------------------------------------------------------------------------------------------------------
-- World: ped, markers, target zones / [E] points
-------------------------------------------------------------------------------------------------------------------

local function deletePed(id)
  local ped = peds[id]
  peds[id] = nil
  if ped and DoesEntityExist(ped) then DeleteEntity(ped) end
end

local function spawnPed(garage)
  local id = garage.id
  if peds[id] and DoesEntityExist(peds[id]) then return end
  local model = joaat(garage.ped.model)
  local ok, err = pcall(lib.requestModel, model, 10000)
  if not ok then
    Debug("error", "Garage '%s': ped model '%s' could not be loaded: %s", id, tostring(garage.ped.model), tostring(err))
    return
  end
  -- The player may have walked away while the model loaded
  if not pedWanted[id] or (peds[id] and DoesEntityExist(peds[id])) then
    SetModelAsNoLongerNeeded(model)
    return
  end
  local c = garage.ped.coords
  local ped = CreatePed(4, model, c.x + 0.0, c.y + 0.0, c.z + 0.0, (c.w or 0.0) + 0.0, false, false)
  SetModelAsNoLongerNeeded(model)
  FreezeEntityPosition(ped, true)
  SetEntityInvincible(ped, true)
  SetBlockingOfNonTemporaryEvents(ped, true)
  SetPedCanRagdoll(ped, false)
  peds[id] = ped
end

local function drawMarker(coords, size, r, g, b)
  DrawMarker(1, coords.x, coords.y, coords.z - 0.98, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, size, size, 0.6, r, g, b, 90,
    false, false, 2, false, nil, nil, false)
end

local function addTarget(garage)
  local target = GetTargetSystem()
  local name = ("%s:%s"):format(RESOURCE, garage.id)
  local function canInteract() return not cache.vehicle and canUse(garage) end
  local function open() OpenGarageMenu(garage.id) end

  if target == "ox_target" then
    oxZones[#oxZones + 1] = exports.ox_target:addSphereZone({
      coords = garage.coords,
      radius = 1.5,
      options = { {
        name = name, icon = "fa-solid fa-warehouse", label = locale("open_garage"), distance = 2.5,
        canInteract = canInteract, onSelect = open,
      } },
    })
  elseif target == "qb-target" then
    exports["qb-target"]:AddCircleZone(name, garage.coords, 1.5, { name = name, debugPoly = false, useZ = true }, {
      options = { { icon = "fas fa-warehouse", label = locale("open_garage"), canInteract = canInteract, action = open } },
      distance = 2.5,
    })
    qbZones[#qbZones + 1] = name
  end
end

local function addTargets()
  oxZones, qbZones = {}, {}
  for _, garage in pairs(Config.Garages) do
    local ok, err = pcall(addTarget, garage)
    if not ok then Log("error", ("Garage '%s': adding the target zone failed: %s"):format(garage.id, tostring(err))) end
  end
end

local function setupGarage(garage)
  local id = garage.id

  if type(garage.ped) == "table" and type(garage.ped.model) == "string" and garage.ped.coords then
    points[#points + 1] = lib.points.new({
      coords = vector3(garage.ped.coords.x, garage.ped.coords.y, garage.ped.coords.z),
      distance = PED_DISTANCE,
      onEnter = function()
        pedWanted[id] = true
        -- loading the model yields; don't block the points loop
        CreateThread(function() spawnPed(garage) end)
      end,
      onExit = function()
        pedWanted[id] = false
        deletePed(id)
      end,
    })
  end

  local hasTarget = GetTargetSystem() ~= "none"
  local textKey = "menu:" .. id
  points[#points + 1] = lib.points.new({
    coords = vector3(garage.coords.x, garage.coords.y, garage.coords.z),
    distance = MARKER_DISTANCE,
    nearby = function(point)
      if cache.vehicle or lib.getOpenContextMenu() or not canUse(garage) then return hideText(textKey) end
      if Config.DrawMarkers then drawMarker(garage.coords, 1.0, 40, 120, 255) end
      if hasTarget then return end
      if point.currentDistance > 1.5 then return hideText(textKey) end
      showText(textKey, locale("open_garage_textui"))
      if IsControlJustReleased(0, KEY_E) and GetGameTimer() - lastKeyPress > 500 then
        lastKeyPress = GetGameTimer()
        hideText(textKey)
        OpenGarageMenu(id)
      end
    end,
    onExit = function() hideText(textKey) end,
  })

  local store = garage.store
  if store then
    local storeKey = "store:" .. id
    points[#points + 1] = lib.points.new({
      coords = vector3(store.coords.x, store.coords.y, store.coords.z),
      distance = math.max(store.radius, MARKER_DISTANCE),
      nearby = function(point)
        local vehicle = cache.vehicle
        if not vehicle or cache.seat ~= -1 or not canUse(garage) then return hideText(storeKey) end
        if Config.DrawMarkers then drawMarker(store.coords, store.radius * 2.0, 255, 80, 80) end
        if point.currentDistance > store.radius then return hideText(storeKey) end
        showText(storeKey, locale("store_vehicle_textui"))
        if IsControlJustReleased(0, KEY_E) and not busy and GetGameTimer() - lastKeyPress > 500 then
          lastKeyPress = GetGameTimer()
          hideText(storeKey)
          CreateThread(function() StoreVehicle(vehicle) end)
        end
      end,
      onExit = function() hideText(storeKey) end,
    })
  end
end

local targetsAdded = false

OnEnvironmentReady(function()
  for _, garage in pairs(Config.Garages) do
    local ok, err = pcall(setupGarage, garage)
    if not ok then Log("error", ("Garage '%s' could not be set up: %s"):format(tostring(garage.id), tostring(err))) end
  end

  local target = GetTargetSystem()
  if target == "none" then return end
  -- The client starts resources in server.cfg order: a target ensured after this resource isn't running here yet
  CreateThread(function()
    local nextWarning = GetGameTimer() + 10000
    while GetResourceState(target) ~= "started" do
      Wait(250)
      if GetGameTimer() >= nextWarning then
        Log("warn", ("Still waiting for %s to start on this client."):format(target))
        nextWarning = GetGameTimer() + 10000
      end
    end
    if targetsAdded then return end
    targetsAdded = true
    addTargets()
    Debug("info", "Garage target zones added (%s)", target)
  end)
end)

-- A restarted target resource has forgotten our zones
AddEventHandler("onClientResourceStart", function(resource)
  if not targetsAdded or resource ~= GetTargetSystem() then return end
  addTargets()
end)

AddEventHandler("onResourceStop", function(resource)
  if resource ~= RESOURCE then return end
  hideText()
  if lib.getOpenContextMenu() == MENU_ID then lib.hideContext() end
  for id in pairs(peds) do deletePed(id) end
  for _, point in ipairs(points) do point:remove() end
  -- the target resources may be stopped already; nothing to clean up then
  for _, zone in ipairs(oxZones) do pcall(function() exports.ox_target:removeZone(zone) end) end
  for _, name in ipairs(qbZones) do pcall(function() exports["qb-target"]:RemoveZone(name) end) end
end)
