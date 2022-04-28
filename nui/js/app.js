let currentVehicle = "";

$(document).ready(function() {
    window.addEventListener("message", function(event) {
        let data = event.data
        let action = data.action

        if (action == "OpenGarageMenu") {
            OpenGarageMenu(data.data)
        }

        if (action == "CantSpawnVehicle") {
            M.toast({html : "Det är ett fordon ivägen."})
        }

        if (action == "CloseMenu") {
            CloseGarageMenu()
        }

    })

    $(document).keydown(function(key) {
        if (key.keyCode == 27) {
            CloseGarageMenu()
        }
    })
})

function OpenGarageMenu(data) {
    // console.log(data.VehicleLabel)
    // console.log(data.VehicleModel)

    for (let e in data.VehicleData) {
        let obj = data.VehicleData[e]

        document.querySelector(".vehicleList .vehicles").innerHTML +=
        `
        <div class="vehicle">
            <p id="${obj.VehicleModel}" class="waves-effect waves-light" onclick="SpawnVehicleConfirm(this.id)">${obj.VehicleLabel}</p>
        </div>
        `
    }

    $(".container").show(250)
    $.post(`https://force_policegarage/NuiToggle`, JSON.stringify(true))
}

function SpawnVehicleConfirm(data) {
    currentVehicle = data

    $(`.buttons`).html(`
        <button class="waves-effect waves-light" onclick="SpawnVehicle()">Spawna</button>
        <button class="waves-effect waves-light" onclick="GoBackToMain()">Avbryt</button>
    `);

    $(".confirmBox").fadeIn(200)
    // $(".container").hide()
    // $.post(`https://force_policegarage/SpawnVehicle`, JSON.stringify(data))
}

function SpawnVehicle() {
    $.post(`https://force_policegarage/SpawnVehicle`, JSON.stringify(currentVehicle))
}

function GoBackToMain() {
    $(".confirmBox").fadeOut(200)
    $(".container").show()
}

function CloseGarageMenu() {
    M.Toast.dismissAll();
    document.querySelector(".vehicleList .vehicles").innerHTML = ""

    $(".container").hide(250)
    $(".confirmBox").hide(250)
    $.post(`https://force_policegarage/NuiToggle`, JSON.stringify(false))
}