-- Runs once force_policegarage knows the framework is "qbx" (Config.Framework, or detected by the server).
-- Keep your code inside this function.
RegisterFramework("qbx", function()
  --- @param source number
  --- @return table|nil { name, grade, onDuty }
  function GetPlayerJob(source)
    if GetResourceState("qbx_core") ~= "started" then return nil end
    local ok, player = pcall(function() return exports.qbx_core:GetPlayer(source) end)
    local job = ok and player and player.PlayerData and player.PlayerData.job
    if type(job) ~= "table" or type(job.name) ~= "string" then return nil end
    local grade = type(job.grade) == "table" and job.grade.level or job.grade
    return { name = job.name, grade = tonumber(grade) or 0, onDuty = job.onduty ~= false }
  end

  --- qbx_vehiclekeys. Replace this with your key resource if you use another one.
  --- @param source number
  --- @param vehicle number server entity handle
  --- @param plate string
  function GiveVehicleKeys(source, vehicle, plate)
    if GetResourceState("qbx_vehiclekeys") == "started" then
      exports.qbx_vehiclekeys:GiveKeys(source, vehicle)
    end
  end
end)
