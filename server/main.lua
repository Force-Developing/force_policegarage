local RESOURCE = GetCurrentResourceName()
local SPAWN_CLEAR_RADIUS = 3.0
local STORE_PLAYER_DISTANCE = 10.0

local spawned = {}    -- [vehicle entity] = { owner = source|nil, garage = id }
local byPlayer = {}   -- [source] = { vehicle entity, ... } oldest first
local lastTakeOut = {} -- [source] = GetGameTimer() of the last successful take-out
local busy = {}       -- [source] = true while a request is handled

local function u32(hash)
  return math.tointeger(hash) and (hash & 0xFFFFFFFF) or hash
end

-- Model hashes per garage, unsigned: GetEntityModel and joaat can disagree on the sign
local garageModels = {}
for id, garage in pairs(Config.Garages) do
  garageModels[id] = {}
  for hash in pairs(garage.models) do garageModels[id][u32(hash)] = true end
end

local function playerCoords(source)
  local ped = GetPlayerPed(source)
  if not ped or ped == 0 then return nil end
  return GetEntityCoords(ped)
end

local function toVector3(v)
  return vector3(v.x + 0.0, v.y + 0.0, v.z + 0.0)
end

local function untrack(vehicle)
  local entry = spawned[vehicle]
  if not entry then return end
  spawned[vehicle] = nil
  local list = entry.owner and byPlayer[entry.owner]
  if not list then return end
  for i = #list, 1, -1 do
    if list[i] == vehicle then table.remove(list, i) end
  end
end

local function deleteVehicle(vehicle)
  untrack(vehicle)
  if DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
end

--- The player's garage vehicles that still exist, oldest first
local function activeVehicles(source)
  local list = byPlayer[source]
  if not list then return {} end
  for i = #list, 1, -1 do
    if not DoesEntityExist(list[i]) then
      spawned[list[i]] = nil
      table.remove(list, i)
    end
  end
  return list
end

local function isOccupied(vehicle)
  for _, id in ipairs(GetPlayers()) do
    local ped = GetPlayerPed(id)
    if ped ~= 0 and GetVehiclePedIsIn(ped, false) == vehicle then return true end
  end
  return false
end

local function isSpotFree(point)
  local coords = toVector3(point)
  for _, vehicle in ipairs(GetAllVehicles()) do
    if #(GetEntityCoords(vehicle) - coords) < SPAWN_CLEAR_RADIUS then return false end
  end
  return true
end

local function makePlate(vehicle)
  if type(vehicle.plate) == "string" and vehicle.plate ~= "" then return vehicle.plate:sub(1, 8) end
  if type(Config.DefaultPlate) == "string" and Config.DefaultPlate ~= "" then return Config.DefaultPlate:sub(1, 8) end
  local plate = tostring(Config.PlatePrefix or ""):sub(1, 7)
  while #plate < 8 do plate = plate .. math.random(0, 9) end
  return plate
end

--- @return boolean allowed, string|table reasonOrJob
local function checkAccess(source, garage)
  if not IsFrameworkReady() then return false, "not_ready" end
  local job = GetPlayerJob(source)
  if not job then return false, "not_allowed" end
  if CanUseGarage(garage, job) then return true, job end
  if Config.RequireDuty and job.onDuty == false and garage.jobs[job.name] ~= nil then return false, "not_on_duty" end
  return false, "not_allowed"
end

local function spawnVehicle(source, garage, vehicle)
  local list = activeVehicles(source)
  local max = math.max(1, math.floor(tonumber(Config.MaxVehiclesPerPlayer) or 1))
  if #list >= max then
    local oldest = list[1]
    if isOccupied(oldest) then return false, "limit_reached" end
    Debug("info", "Deleting %s's oldest garage vehicle to stay within the limit", GetPlayerName(source))
    deleteVehicle(oldest)
  end

  local point
  for _, candidate in ipairs(garage.spawnPoints) do
    if isSpotFree(candidate) then
      point = candidate
      break
    end
  end
  if not point then return false, "spawn_blocked" end

  local entity = CreateVehicleServerSetter(vehicle.hash, vehicle.type, point.x + 0.0, point.y + 0.0, point.z + 0.0,
    (point.w or 0.0) + 0.0)
  local deadline = GetGameTimer() + 5000
  while (not entity or entity == 0 or not DoesEntityExist(entity)) and GetGameTimer() < deadline do Wait(0) end
  if not entity or entity == 0 or not DoesEntityExist(entity) then
    Log("error", ("Could not spawn '%s' from garage '%s'. Check the model name and the vehicle type in config.lua.")
      :format(vehicle.model, garage.id))
    return false, "spawn_failed"
  end

  -- The player may have left while the entity was created
  if GetPlayerPed(source) == 0 then
    DeleteEntity(entity)
    return false, "spawn_failed"
  end

  local plate = makePlate(vehicle)
  SetVehicleNumberPlateText(entity, plate)
  SetEntityRoutingBucket(entity, GetPlayerRoutingBucket(source))

  spawned[entity] = { owner = source, garage = garage.id }
  byPlayer[source] = byPlayer[source] or {}
  table.insert(byPlayer[source], entity)
  lastTakeOut[source] = GetGameTimer()

  local ok, err = pcall(GiveVehicleKeys, source, entity, plate)
  if not ok then Log("error", "Giving vehicle keys failed: " .. tostring(err)) end

  Debug("info", "%s took out %s (%s) from %s", GetPlayerName(source), vehicle.model, plate, garage.id)
  return true, { netId = NetworkGetNetworkIdFromEntity(entity), label = vehicle.label, plate = plate }
end

lib.callback.register("force_policegarage:server:takeOut", function(source, garageId, index)
  local garage = GetGarage(garageId)
  local vehicle = garage and type(index) == "number" and garage.vehicles[index]
  if not vehicle or vehicle.invalid then return false, "not_allowed" end

  if busy[source] then return false, "busy" end
  local cooldown = (tonumber(Config.Cooldown) or 0) * 1000
  if lastTakeOut[source] and GetGameTimer() - lastTakeOut[source] < cooldown then return false, "cooldown" end

  local allowed, job = checkAccess(source, garage)
  if not allowed then return false, job end
  if not CanUseVehicle(garage, vehicle, job) then return false, "not_allowed" end

  local coords = playerCoords(source)
  local maxDistance = (tonumber(Config.InteractDistance) or 5.0) + 1.0
  if not coords or #(coords - toVector3(garage.coords)) > maxDistance then return false, "too_far" end

  busy[source] = true
  local ok, success, result = pcall(spawnVehicle, source, garage, vehicle)
  busy[source] = nil
  if not ok then
    Log("error", "Taking out a vehicle failed: " .. tostring(success))
    return false, "spawn_failed"
  end
  return success, result
end)

lib.callback.register("force_policegarage:server:store", function(source, netId)
  if type(netId) ~= "number" then return false, "no_vehicle" end
  local entity = NetworkGetEntityFromNetworkId(netId)
  if not entity or entity == 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then
    return false, "no_vehicle"
  end

  local coords = playerCoords(source)
  local vehicleCoords = GetEntityCoords(entity)
  if not coords or #(coords - vehicleCoords) > STORE_PLAYER_DISTANCE then return false, "too_far" end

  local model = u32(GetEntityModel(entity))
  local reason = "too_far"
  for id, garage in pairs(Config.Garages) do
    local store = garage.store
    if store and #(vehicleCoords - toVector3(store.coords)) <= store.radius + 2.0 then
      local allowed, why = checkAccess(source, garage)
      if not allowed then
        reason = why
      elseif not garageModels[id][model] and not spawned[entity] then
        reason = "not_garage_vehicle"
      else
        Debug("info", "%s stored a vehicle at %s", GetPlayerName(source), id)
        deleteVehicle(entity)
        return true
      end
    end
  end
  return false, reason
end)

AddEventHandler("playerDropped", function()
  local src = source
  busy[src] = nil
  lastTakeOut[src] = nil
  local list = byPlayer[src]
  byPlayer[src] = nil
  if not list then return end
  for _, vehicle in ipairs(list) do
    if Config.DeleteVehiclesOnDisconnect then
      spawned[vehicle] = nil
      if DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
    elseif spawned[vehicle] then
      spawned[vehicle].owner = nil
    end
  end
end)

AddEventHandler("onResourceStop", function(resource)
  if resource ~= RESOURCE or not Config.DeleteVehiclesOnStop then return end
  for vehicle in pairs(spawned) do
    if DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
  end
end)
