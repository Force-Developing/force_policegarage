RegisterNUICallback("NuiToggle", function(state)
    SetNuiFocus(state, state)
end)

RegisterNUICallback("SpawnVehicle", function(data)
    Funcs.SpawnVehicle(data)
end)