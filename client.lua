RegisterCommand('showUI', function()
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = 'open'
    })
end, false)

RegisterCommand('showserverpage', function()
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = 'open'
    })
end, false)

RegisterNUICallback('closeUI', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({
        type = 'close'
    })
    cb('ok')
end)

RegisterNUICallback('hide_ui', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({
        type = 'close'
    })
    cb('ok')
end)






-- Отримання даних із сервера
RegisterNetEvent('receiveDataFromServer')
AddEventHandler('receiveDataFromServer', function(data)
    if data.error then
        print("Error received from server: " .. data.error)
        -- Відправка помилки у веб-інтерфейс
        SendNUIMessage({
            type = "error",
            message = data.error
        })
    else
        print("Data received from server")
        for key, value in pairs(data) do
            print(key .. ": " .. tostring(value))
        end
        -- Відправка отриманих даних у веб-інтерфейс
        SendNUIMessage({
            type = "updatePlayerInfo",
            payload = {
                firstName = data.firstName,
                lastName = data.lastName,
                job = data.job
            }
        })
    end
end)

-- Запит даних при відкритті інтерфейсу
RegisterNUICallback('requestPlayerInfo', function(_, cb)
    TriggerServerEvent('requestDataFromServer') -- Запит до сервера
    cb('ok')
end)



-- Функція для відправлення запиту на сервер для отримання даних
function requestDataFromServer()
    print("Requesting data from server...")
    local playerId = GetPlayerServerId(PlayerId())  -- Отримати серверний ID поточного гравця
    TriggerServerEvent('requestDataFromServer', playerId)
end


-- NUI Callback для виклику з JavaScript
RegisterNUICallback('requestData', function(data, cb)
    requestDataFromServer()
    cb('ok')  -- Відправлення відповіді назад у веб-інтерфейс
end)



RegisterNetEvent('playerExperience:update')
AddEventHandler('playerExperience:update', function(role, currentXP, newXP, currentLevel, newLevel, xpToNextLevel, skillName, skillDescription, skillIcon)
    -- Відправка даних на HTML сторінку через NUI
    SendNUIMessage({
        action = "updateExperience",
        role = role,
        currentXP = currentXP,
        newXP = newXP,
        currentLevel = currentLevel,
        newLevel = newLevel,
        xpToNextLevel = xpToNextLevel,
        skillName = skillName,
        skillDescription = skillDescription,
        skillIcon = skillIcon  -- Передаємо іконку
    })
end)





-- Функція для запиту даних гравця з сервера
function requestPlayerSkills()
    print("Запит даних гравця з сервера...")
    TriggerServerEvent('getPlayerSkills')
end

-- Обробка отриманих даних з сервера
RegisterNetEvent('receivePlayerSkills')
AddEventHandler('receivePlayerSkills', function(data)
    if data.error then
        print("Error From Server: " .. data.error)
        SendNUIMessage({
            type = "error",
            message = data.error
        })

    else

        for key, value in pairs(data) do
            print(key .. ": " .. tostring(value))
        end
        -- Відправка даних в NUI
        SendNUIMessage({
            type = "updatePlayerSkills",
            payload = data,
            achievements = data.achievements or {}
        })
    end
end)





-- Виклик функції для запиту даних з сервера через NUI Callback
RegisterNUICallback('requestPlayerSkills', function(data, cb)
    requestPlayerSkills()
    cb('ok')
end)

-- Відкрити браузер при натисканні іконки медіа партнера
RegisterNUICallback('openUrl', function(data, cb)
    local url = data.url
    if url then
        -- Викликати нативну функцію для відкриття URL у браузері
        SetNuiFocus(false, false) -- Закрити NUI, якщо потрібно
        -- Використання нативної функції для відкриття URL
        Citizen.InvokeNative(0xE3B05614DCE1D014, url)
    end
    cb('ok')
end)

-- Виконання команди в чаті.
RegisterNetEvent('executeCommand')
AddEventHandler('executeCommand', function(command)
    if command then
        ExecuteCommand(command)
    end
end)


RegisterNUICallback('executeCommand', function(data, cb)
    local command = data.command
    if command then
        TriggerEvent('executeCommand', command)
    end
    cb('ok')
end)



-- Динамічні сторінки


-- Запит даних з серверної частини
RegisterNUICallback('getMenuItems', function(_, cb)
    -- Викликаємо серверний обробник для отримання меню
    TriggerServerEvent('getMenuItems')

    -- Слухаємо подію від сервера з отриманими даними
    RegisterNetEvent('receiveMenuItems')
    AddEventHandler('receiveMenuItems', function(menuItems)
        cb(menuItems) -- Повертаємо дані в NUI
    end)
end)

RegisterNUICallback('getEventList', function(_, cb)
    TriggerServerEvent('marko_leveling:getEventList')
    print("➡️ Викликано сервер для отримання списку івентів")

    RegisterNetEvent('marko_leveling:sendEventList')
    AddEventHandler('marko_leveling:sendEventList', function(eventList)
        print("✅ Отримано список івентів: " .. json.encode(eventList))
        cb(eventList)
    end)
end)

-- Загальні налаштування.


-- Отримання налаштувань з сервера
RegisterNUICallback('requestSettings', function(_, cb)
    TriggerServerEvent('marko_leveling:requestSettings')
    RegisterNetEvent('marko_leveling:receiveSettings', function(settings)
        cb(settings)
    end)
end)

-- Збереження налаштувань через сервер
RegisterNUICallback('saveSettings', function(data, cb)
    TriggerServerEvent('marko_leveling:saveSettings', data)
    cb({ success = true })
end)
