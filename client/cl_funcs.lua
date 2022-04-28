Funcs = {};

Funcs.Text3D = function(coords, text)
    local onScreen, _x, _y = World3dToScreen2d(coords.x, coords.y, coords.z)
    
    SetTextScale(0.38, 0.38)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 200)
    SetTextEntry("STRING")
    SetTextCentre(1)

    AddTextComponentString(text)
    DrawText(_x, _y)

    local factor = string.len(text) / 370
    DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 41, 11, 41, 68)
end

Funcs.SpawnVehicle = function(data)
    if ESX.Game.IsSpawnPointClear(Config.SpawnVehiclePos, 3.0) then
        ESX.Game.SpawnVehicle(data, Config.SpawnVehiclePos, Config.SpawnVehicleHeading, function() 
            
        end)

        SendNUIMessage({
            action = "CloseMenu"
        })
    else
        SendNUIMessage({
            action = "CantSpawnVehicle"
        })
    end
end