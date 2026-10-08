-- Runs once force_policegarage knows the framework is "custom": Config.Framework = "custom", or "auto" when none
-- of qbx_core, es_extended and qb-core is installed. Keep your code inside this function.
RegisterFramework("custom", function()
  --- TODO: return the player's job from your framework. Without it nobody can use a garage.
  --- @param source number
  --- @return table|nil { name = "police", grade = 0, onDuty = true }
  function GetPlayerJob(source)
    return nil
  end

  --- Optional: give keys with your key resource.
  --- @param source number
  --- @param vehicle number server entity handle
  --- @param plate string
  function GiveVehicleKeys(source, vehicle, plate)
  end
end)
