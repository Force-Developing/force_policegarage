# force_policegarage

Free job garage for FiveM. Police (or any job you configure) open the garage at a ped or marker, pick a vehicle
from an ox_lib menu and drive off. Driving a garage vehicle back to the store point and pressing **E** stores it.

- ESX Legacy, QBCore and QBox out of the box, other frameworks through `custom.lua`
- ox_target or qb-target, with an [E] + text UI fallback when neither runs
- Several garages, each with its own jobs, minimum grades, spawn points and vehicle list
- Everything is checked on the server: job, grade, duty, distance, cooldown and the vehicle list.
  Vehicles are spawned by the server, so a client can't ask for a model that isn't in the garage
- Keys for qb-vehiclekeys and qbx_vehiclekeys
- English and Swedish locales

## Requirements

- [ox_lib](https://github.com/overextended/ox_lib)
- OneSync (on by default on current servers)

No database is used.

## Install

1. Put the folder in your resources as `force_policegarage`.
2. Add `ensure force_policegarage` to `server.cfg` below `ensure ox_lib`. The start order relative to your
   framework and target resource doesn't matter.
3. Edit `config.lua`: jobs, coordinates and vehicles per garage.

## Documentation

https://docs.forcedevelopments.com/free-resources/force_policegarage/introduction

## License

Apache 2.0, see [LICENSE](LICENSE).
