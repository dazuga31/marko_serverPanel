local ESX, QBCore = nil, nil

local oxmysql = exports.oxmysql

if Config.FrameWork == 'ESX' then
    ESX = exports["es_extended"]:getSharedObject()
    print("[LEVELING] - Обраний FrameWork = [ESX]")
elseif Config.FrameWork == 'QB' then
    QBCore = exports['qb-core']:GetCoreObject()
    print("[LEVELING] - Обраний FrameWork = [QB]")
end

--[[ Масив для зберігання рівнів гравців ]]
local PlayerLVL = {}
local DroppedPlayersFromServer = {}


local function CheckAdmin(playerId, minAccessLevel)
    local accessLevels = {
        admin = 6,
        moderator = 5,
        helper_4 = 4,
        helper_3 = 3,
        helper_2 = 2,
        helper_1 = 1
    }

    local playerAccessLevel = 0
    for group, level in pairs(accessLevels) do
        if IsPlayerAceAllowed(playerId, group) and level > playerAccessLevel then
            playerAccessLevel = level
        end
    end

    return playerAccessLevel >= minAccessLevel
end

-- Функція для глибокого копіювання таблиці
function table.deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[table.deepcopy(orig_key)] = table.deepcopy(orig_value)
        end
        setmetatable(copy, table.deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- Функція для завантаження даних гравця з бази даних
local function loadPlayerData(identifier, callback)
    exports.oxmysql:execute('SELECT * FROM marko_leveling WHERE identifier = ?', {identifier}, function(result)
        if result and result[1] then
            local playerData = result[1]
            -- Конвертуємо JSON-колонку achievements у таблицю
            playerData.achievements = playerData.achievements and json.decode(playerData.achievements) or {}
            -- Переконуємося, що settings теж правильно десеріалізуються
            playerData.settings = playerData.settings and json.decode(playerData.settings) or {
                theme = "light",
                levelgrid = "true"
            }
            PlayerLVL[identifier] = playerData
            callback(true)
        else
            callback(false)
        end
    end)
end



-- Функція для виконання запиту з callback
local function executeQuery(query, params, callback)
    oxmysql:execute(query, params, function(result)
        if result then
            callback(result, nil)
        else
            callback(nil, "Error executing query")
        end
    end)
end

--[[ Функція для завантаження даних онлайн гравців при старті ресурсу ]]
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end
    local players = GetPlayers()
    for _, playerId in ipairs(players) do
        local identifiers = GetPlayerIdentifiers(playerId)
        for _, id in ipairs(identifiers) do
            if string.match(id, "license") then
                loadPlayerData(id, function(success)
                    if success then
                      --  print(Config.Lang["DebugMessages"].LoadedIdentifier:format(id))
                    else
                        print(Config.Lang["DebugMessages"].FailedToLoadIdentifier:format(id))
                    end
                end)
                break
            end
        end
    end
end)




--[[ Додавання даних для нових гравців, що приєднуються ]]
AddEventHandler('playerConnecting', function(playerName, setKickReason, deferrals)
    local src = source
    local identifiers = GetPlayerIdentifiers(src)
    local identifier = nil

    for _, id in ipairs(identifiers) do
        if string.match(id, "license") then
            identifier = id
            break
        end
    end

    if identifier then
        -- Якщо гравець повернувся до циклу збереження, видаляємо його з DroppedPlayersFromServer
        DroppedPlayersFromServer[identifier] = nil
        if not PlayerLVL[identifier] then
            loadPlayerData(identifier, function(success)
                if not success then
                    local queryData = {identifier, table.unpack(Config.PlayerDefaultData.defaultValues)}
                    PlayerLVL[identifier] = queryData
                    exports.oxmysql:execute('INSERT INTO marko_leveling (' .. Config.PlayerDefaultData.columns .. ') VALUES (' .. Config.PlayerDefaultData.values .. ')', queryData, function(result)
                        if Config.DebugMode then
                            print(Config.Lang["DebugMessages"]["AddedNewPlayerToDatabase"]:format(identifier))
                        end
                    end)
                end
            end)
        end
    else
        deferrals.done(Config.Lang["DebugMessages"]["UnableToRetrievePlayerIdentifier"])
    end
end)

--[[ Видалення даних для гравців, що виходять ]]
AddEventHandler('playerDropped', function(reason)
    local src = source
    local identifiers = GetPlayerIdentifiers(src)
    local identifier = nil

    for _, id in ipairs(identifiers) do
        if string.match(id, "license") then
            identifier = id
            break
        end
    end

    if identifier then
        DroppedPlayersFromServer[identifier] = true

        if Config.Lang["DebugMessages"] and Config.Lang["DebugMessages"].PlayerDroppedAddedToRemovalList then
            print(Config.Lang["DebugMessages"].PlayerDroppedAddedToRemovalList:format(identifier))
        else
            print("Player dropped: " .. identifier .. " added to removal list.")
        end
    end
end)



-- Формуємо правильний запит для UPDATE
local function formatUpdateQuery(data, identifier)
    local setClause = ""
    local params = {}

    for key, value in pairs(data) do
        if type(key) == "string" then
            if value == nil then
                -- Замінюємо nil значення на порожній JSON, якщо це settings чи achievements
                if key == "settings" or key == "achievements" then
                    value = "{}"
                else
                    print(string.format("Помилка у formatUpdateQuery: Nil значення для ключа: %s", key))
                    goto continue
                end
            elseif type(value) == "table" then
                -- Серіалізуємо таблиці в JSON
                if key == "settings" or key == "achievements" then
                    value = json.encode(value)
                else
                    print(string.format("Попередження: Таблиця не підтримується для ключа: %s", key))
                    goto continue
                end
            end

            -- Додаємо колонку до запиту
            setClause = setClause .. key .. " = ?, "
            table.insert(params, value)
        else
            print(string.format("Помилка у formatUpdateQuery: Неправильний ключ або значення. Ключ: %s, Значення: %s", tostring(key), tostring(value)))
        end
        ::continue::
    end

    -- Видаляємо останню кому та пробіл, якщо є дані
    if #setClause > 0 then
        setClause = setClause:sub(1, -3)
    else
        print("Помилка: SQL запит не містить жодної валідної колонки для оновлення!")
        return nil, nil
    end

    table.insert(params, identifier) -- Додаємо identifier як останній параметр

    return "UPDATE marko_leveling SET " .. setClause .. " WHERE identifier = ?", params
end








--[[ Функція для збереження всіх рівнів гравців в базу даних при зупинці ресурсу ]]
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end

    local count = 0
    local errors = 0
    local completed = 0
    local total = 0

    for identifier, data in pairs(PlayerLVL) do
        total = total + 1
        local updateData = table.deepcopy(data)

        -- Видаляємо непотрібні поля перед збереженням
        updateData.id = nil
        updateData.fullName = nil
        updateData.firstName = nil
        updateData.lastName = nil
        updateData.job = nil
        updateData.ExpNeededForEarnLVL = nil

        -- Перевіряємо кожне поле в `updateData` і логуємо, якщо значення nil
        for key, value in pairs(updateData) do
            if value == nil then
                print(string.format("Warning: Field '%s' is nil for identifier '%s'", key, identifier))
            end
        end

        -- Формуємо запит
        local query, params = formatUpdateQuery(updateData, identifier)

        -- Виконуємо запит
        executeQuery(query, params, function(result, err)
            completed = completed + 1
            if not err and result and result.affectedRows and result.affectedRows > 0 then
                count = count + 1
            else
                errors = errors + 1
                print(Config.Lang["DebugMessages"].SavingErrorForIdentifier:format(identifier, err or "unknown error"))
            end

            -- Перевіряємо, чи всі запити завершені
            if completed == total then
                print(Config.Lang["DebugMessages"].SavedIdentifiersOnStop:format(count))
                if errors > 0 then
                    print(Config.Lang["DebugMessages"].FailedToSaveIdentifiersOnStop:format(errors))
                end
            end
        end)
    end

    -- Якщо немає даних для збереження
    if total == 0 then
        print(Config.Lang["DebugMessages"].NoPlayersToSave)
    end
end)




--[[ Періодичне збереження даних гравців кожних 30 хвилин ]]
CreateThread(function()
    while true do
        Wait(1800000) -- 30 хвилин в мілісекундах (5000 мс для тестування)
        local count = 0
        local errors = 0
        local completed = 0
        local total = 0

        -- Початок періодичного збереження
        print(Config.Lang["DebugMessages"].PeriodicSaveStart)

        for identifier, data in pairs(PlayerLVL) do
            total = total + 1
            local updateData = table.deepcopy(data)
            updateData.id = nil
            updateData.fullName = nil

            -- Серіалізуємо ачівки
            if updateData.achievements then
                updateData.achievements = json.encode(updateData.achievements)
            else
                updateData.achievements = "{}" -- Порожній JSON за замовчуванням
            end

            local query, params = formatUpdateQuery(updateData, identifier)
            executeQuery(query, params, function(result, err)
                completed = completed + 1
                if not err and result and result.affectedRows and result.affectedRows > 0 then
                    count = count + 1
                else
                    errors = errors + 1
                    print(Config.Lang["DebugMessages"].PeriodicSaveErrorForIdentifier:format(identifier, err or "unknown error"))
                end
                if completed == total then
                    print(Config.Lang["DebugMessages"].PeriodicSaveComplete:format(count, total))
                    if errors > 0 then
                        print(Config.Lang["DebugMessages"].PeriodicSaveFailure:format(errors))
                    end
                    -- Видаляємо гравців, що вийшли з сервера, з локального масиву
                    if next(DroppedPlayersFromServer) ~= nil then
                        print(Config.Lang["DebugMessages"].RemovingDroppedPlayers)
                    end
                    local removedCount = 0
                    for droppedIdentifier, _ in pairs(DroppedPlayersFromServer) do
                        if PlayerLVL[droppedIdentifier] then
                            PlayerLVL[droppedIdentifier] = nil
                            DroppedPlayersFromServer[droppedIdentifier] = nil
                            removedCount = removedCount + 1
                            print(Config.Lang["DebugMessages"].RemovedPlayerData:format(droppedIdentifier))
                        else
                            print(Config.Lang["DebugMessages"].FailedToRemovePlayerIdentifier:format(droppedIdentifier))
                        end
                    end
                    if removedCount > 0 then
                        print(Config.Lang["DebugMessages"].RemovedDroppedPlayersCount:format(removedCount))
                    end
                end
            end)
        end

        -- Якщо немає жодного гравця у масиві PlayerLVL
        if total == 0 then
            print(Config.Lang["DebugMessages"].NoPlayersToSave)
        end
    end
end)





RegisterServerEvent('checkplayerlvlbyUI')
AddEventHandler('checkplayerlvlbyUI', function()
    local playerLevel = 5
    local playerExperience = 500
    local playerData = {
        level = playerLevel,
        experience = playerExperience
    }

    TriggerClientEvent('updatePlayerLevelUI', source, playerData)
end)

--[[ Функція для додавання досвіду гравцю ]]

function addExperience(source, identifier, columnName, amount)
    if not identifier then
        if Config.DebugMode then
            print(Config.Lang["DebugMessages"]["NoIdentifier"])
        end
        return
    end

    local role = columnName:gsub("_xp", "") -- Визначаємо роль з назви колонки
    local levelColumn = Config.LevelColumns[role] and Config.LevelColumns[role].lvl or nil
    local playerXPColumn = 'player_xp' -- Колонка для загального досвіду гравця

    if not levelColumn then
        if Config.DebugMode then
            print(string.format(Config.Lang["DebugMessages"]["NoLevelColumn"], columnName))
        end
        return
    end

    if Config.DebugMode then
        print(string.format(Config.Lang["DebugMessages"]["InitiatingXPUpdate"], columnName))
    end

    local playerData = PlayerLVL[identifier]
    if playerData then
        -- Переконаємося, що achievements — це таблиця
        if type(playerData.achievements) ~= "table" then
            playerData.achievements = {} -- Ініціалізація як порожньої таблиці
        end

        local currentXP = playerData[columnName] or 0
        local currentLevel = playerData[levelColumn] or 0
        local newXP = currentXP + amount
        local totalXPNeededForNextLevel = Config.Levels[role .. "_lvl"][currentLevel + 1] or 0

        -- Оновлення даних
        playerData[columnName] = newXP
        playerData[playerXPColumn] = (playerData[playerXPColumn] or 0) + amount

        -- Визначення прогресу до наступного рівня
        local xpToNextLevel = totalXPNeededForNextLevel - newXP
        if xpToNextLevel < 0 then xpToNextLevel = 0 end -- Захист від негативного значення

        -- Перевірка на нові ачівки
        local nextAchievementXP = nil
        if Config.Achievements[role] then
            for _, achievement in ipairs(Config.Achievements[role]) do
                if newXP < achievement.xp then
                    nextAchievementXP = achievement.xp - newXP
                    break
                end
            end
        end

        -- Перевірка всіх змінних перед друком
        identifier = identifier or "N/A"
        amount = amount or 0
        xpToNextLevel = xpToNextLevel or 0
        nextAchievementXP = nextAchievementXP and tostring(nextAchievementXP) or "немає"

        -- Покращений друк інформації про отриманий досвід
        print(string.format(
            "Отримання досвіду: Гравець %s - Отримано xp: %d, До наст рівня: %d xp, До наст ачівки: %s",
            identifier, amount, xpToNextLevel, nextAchievementXP
        ))

        -- Нотифікація гравця про доданий досвід
        if Config.NotifyPlayerWhenAddEXP then
            NotifyAddPlayerExperience(role, currentXP, newXP, currentLevel, currentLevel + 1, totalXPNeededForNextLevel, source)
        end

        -- Перевірка на нові ачівки
        if Config.Achievements[role] then
            for _, achievement in ipairs(Config.Achievements[role]) do
                if newXP >= achievement.xp and not playerData.achievements[achievement.name] then
                    -- Додаємо ачівку до даних
                    playerData.achievements[achievement.name] = {
                        name = achievement.name,
                        title = achievement.title,
                        achievedAt = os.time() -- Час досягнення
                    }

                    -- Відправляємо нотифікацію гравцю про нову ачівку
                    TriggerClientEvent('marko_leveling:notifyAchievement', source, {
                        role = role,
                        title = achievement.title
                    })

                    if Config.DebugMode then
                        print(string.format(Config.Lang["DebugMessages"]["AchievementEarned"], achievement.title))
                    end
                end
            end
        end

        -- Оновлення рівня гравця
        local levels = Config.Levels[role .. "_lvl"]
        local newLevel = currentLevel
        for level, xpRequired in ipairs(levels) do
            if newXP >= xpRequired then
                newLevel = level
            end
        end

        if newLevel ~= currentLevel then
            playerData[levelColumn] = newLevel

            -- Відправляємо нотифікацію про зміну рівня
            TriggerClientEvent('marko_leveling:notifyLevelUp', source, {
                role = role,
                newLevel = newLevel
            })

            if Config.DebugMode then
                print(string.format(Config.Lang["DebugMessages"]["LevelChange"], currentLevel, newLevel))
            end
        end
    else
        if Config.DebugMode then
            print(string.format(Config.Lang["DebugMessages"]["FailedToGetCurrentValues"], columnName))
        end
    end
end









--[[ Функція для отримання рівня гравця за певною роллю ]]
function getPlayerLevel(identifier, role, callback)
    print("getPlayerLevel function: identifier = ", identifier, ", role = ", role)
    if not identifier or not role then
        if Config.DebugMode then
            print(Config.Lang["DebugMessages"]["InvalidArgumentsToGetPlayerLevelFunction"])
        end
        return
    end

    local levelColumn = Config.LevelColumns[role] and Config.LevelColumns[role].lvl or nil
    if not levelColumn then
        if Config.DebugMode then
            print(Config.Lang["DebugMessages"]["NoLevelColumnConfigurationFoundForRole"]:format(role))
        end
        return
    end

    local playerData = PlayerLVL[identifier]
    if playerData then
        local playerLevel = playerData[levelColumn] or 0
        if Config.DebugMode then
            print(Config.Lang["DebugMessages"]["LevelForRoleIs"]:format(role, playerLevel))
        end
        if callback then
            callback(playerLevel)
        end
    else
        if Config.DebugMode then
            print(Config.Lang["DebugMessages"]["FailedToFetchLevelForRole"]:format(role))
        end
        if callback then
            callback(nil)
        end
    end
end

--[[ Обробник події для отримання рівня ]]
AddEventHandler('marko_leveling:getPlayerLevel', function(identifier, role, callback)
    local levelColumn = Config.LevelColumns[role] and Config.LevelColumns[role].lvl
    if not levelColumn then
        if Config.DebugMode then
            print(Config.Lang["DebugMessages"]["NoLevelColumnConfigurationFoundForRole"]:format(role))
        end
        if callback then callback(nil) end
        return
    end

    local playerData = PlayerLVL[identifier]
    if playerData then
        local playerLevel = playerData[levelColumn] or 0
        if Config.DebugMode then
            print(Config.Lang["DebugMessages"]["RetrievedLevel"]:format(identifier, role, playerLevel))
        end
        if callback then callback(playerLevel) end
    else
        if Config.DebugMode then
            print(Config.Lang["DebugMessages"]["NoRecordsFoundForIdentifier"]:format(identifier, role))
        end
        if callback then callback(nil) end
    end
end)


--[[ Відправка даних для нотифікації гравця.]]

function NotifyAddPlayerExperience(role, currentXP, newXP, currentLevel, newLevel, xpToNextLevel, source)
    local skillData = Config.Skills[role] or { name = "Unknown Skill", description = "No description", icon = "default.png" }
    
    if GetPlayerName(source) then
        TriggerClientEvent('playerExperience:update', source, role, currentXP, newXP, currentLevel, newLevel, xpToNextLevel, skillData.name, skillData.description, skillData.icon)
    else
        if Config.DebugMode then
            print("Player not found with source:", source)
        end
    end
end





--[[ Реєстрація серверної події для додавання досвіду гравцю ]]
RegisterServerEvent('addPlayerExperience')
AddEventHandler('addPlayerExperience', function(columnName, amount, src)
    if Config.DebugMode then
        print(Config.Lang["DebugMessages"]["EventAddPlayerExperienceTriggered"]:format(src))
        print(Config.Lang["DebugMessages"]["AddingExperienceToColumn"]:format(columnName))
        print(Config.Lang["DebugMessages"]["AmountOfExperienceToAdd"]:format(amount))
    end

    local identifier = nil
    if Config.FrameWork == 'ESX' then
        local identifiers = GetPlayerIdentifiers(src)
        -- Перебираємо ідентифікатори гравця, щоб знайти потрібний
        for _, id in ipairs(identifiers) do
            if string.match(id, "license") then
                identifier = id
                break
            end
        end
    elseif Config.FrameWork == 'QB' then
        local xPlayer = QBCore.Functions.GetPlayer(src)
        identifier = xPlayer.PlayerData.license
    end

    if identifier then
        -- Додавання досвіду гравцю
        addExperience(src, identifier, columnName, amount)
        
    else
        if Config.DebugMode then
            print(Config.Lang["DebugMessages"]["AddPlayerExperienceUnableToGetIdentifier"]:format(src))
        end
    end
end)



--[[ Запит даних з сервера ]]
RegisterServerEvent('requestDataFromServer')
AddEventHandler('requestDataFromServer', function(playerId)
    local src = source
    local identifier, firstName, lastName

    if Config.FrameWork == 'ESX' then
        local identifiers = GetPlayerIdentifiers(src)
        for _, id in ipairs(identifiers) do
            if string.match(id, "license") then
                identifier = id
                break
            end
        end
        if identifier then
            local xPlayer = ESX.GetPlayerFromId(src)
            if xPlayer then
                firstName = xPlayer.get('firstName')
                lastName = xPlayer.get('lastName')
            end
        end
    elseif Config.FrameWork == 'QB' then
        local xPlayer = QBCore.Functions.GetPlayer(src)
        if xPlayer then
            identifier = xPlayer.PlayerData.license
            firstName = xPlayer.PlayerData.charinfo.firstname
            lastName = xPlayer.PlayerData.charinfo.lastname
        end
    end

    if identifier and PlayerLVL[identifier] then
        local data = table.deepcopy(PlayerLVL[identifier])
        data.firstName = firstName
        data.lastName = lastName
        data.job = job
        TriggerClientEvent('receiveDataFromServer', src, data)
    else
        print("Data for Player no Found:", identifier or "Unknown")
        TriggerClientEvent('receiveDataFromServer', src, { error = "No data found" })
    end
    
end)


--[[ Функція для розділення рядка ]]
function split(s, delimiter)
    local result = {}
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match)
    end
    return result
end

RegisterServerEvent('RewardPlayer')
AddEventHandler('RewardPlayer', function(src, itemID, itemQuantity, lvlColumn, moneyTrigger)
    print(string.format(Config.Lang["DebugMessages"]["RewardPlayerStart"], src))
    print(string.format(Config.Lang["DebugMessages"]["ItemInfo"], itemID, itemQuantity, lvlColumn, moneyTrigger))

    local identifier = nil
    local xPlayer = nil
    local frameworkType = Config.FrameWork  -- Перевіряємо який фреймворк використовується

    -- Логуємо фреймворк, що використовується
    print(string.format(Config.Lang["DebugMessages"]["FrameworkUsed"], frameworkType))

    -- Отримання гравця залежно від фреймворку
    if frameworkType == 'ESX' then
        local identifiers = GetPlayerIdentifiers(src)
        for _, id in ipairs(identifiers) do
            if string.match(id, "license") then
                identifier = id
                break
            end
        end
        if identifier then
            xPlayer = ESX.GetPlayerFromIdentifier(identifier)
        end
    elseif frameworkType == 'QB' then
        xPlayer = QBCore.Functions.GetPlayer(src)
        if xPlayer then
            identifier = xPlayer.PlayerData.license
        end
    end

    -- Логуємо отриманого гравця
    print(string.format(Config.Lang["DebugMessages"]["PlayerInfo"], identifier or "Невідомо", frameworkType))

    -- Якщо гравець знайдений
    if identifier and PlayerLVL[identifier] then
        local playerLevel = PlayerLVL[identifier][lvlColumn]
        print(string.format(Config.Lang["DebugMessages"]["PlayerLevel"], src, tostring(playerLevel)))

        local moneyAmount = 0
        if moneyTrigger == 'true' then
            moneyAmount = Config.Reward[lvlColumn][playerLevel]
        end

        -- Видаємо гравцеві гроші
        print(string.format(Config.Lang["DebugMessages"]["PlayerMoney"], moneyAmount))
        GivePlayerRewardMoney(src, moneyAmount, frameworkType)

        -- Додаємо предмет, якщо це вказано
        if itemID and itemQuantity and itemID ~= "none" then
            if xPlayer then
                print(string.format(Config.Lang["DebugMessages"]["AddItem"], src, itemID, itemQuantity))

                -- Додаємо предмет для QBCore або ESX
                if frameworkType == 'QB' then
                    xPlayer.Functions.AddItem(itemID, itemQuantity)
                elseif frameworkType == 'ESX' then
                    xPlayer.addInventoryItem(itemID, itemQuantity)
                end
            end
        end
    else
        print(string.format(Config.Lang["DebugMessages"]["NoPlayerLevel"], src))
    end
end)




--[[ Функція для додавання грошей гравцю ]]
function GivePlayerRewardMoney(src, amount, framework)
    if amount <= 0 then
        if Config.DebugMode then
            print(Config.Lang["DebugMessages"].InvalidRewardMoneyAmount)
        end
        return
    end

    local xPlayer = nil
    if framework == 'ESX' then
        xPlayer = ESX.GetPlayerFromId(src)
    elseif framework == 'QB' then
        xPlayer = QBCore.Functions.GetPlayer(src)
    end

    if not xPlayer then
        if Config.DebugMode then
            print(Config.Lang["DebugMessages"].FailedToRetrievePlayer:format(src))
        end
        return
    end

    if Config.DebugMode then
        print(Config.Lang["DebugMessages"].AttemptingToAddMoney:format(amount, framework))
    end

    if framework == 'ESX' then
        xPlayer.addAccountMoney('bank', amount)
        if Config.DebugMode then
            print(Config.Lang["DebugMessages"].MoneyAddedESX:format(src))
        end
    elseif framework == 'QB' then
        xPlayer.Functions.AddMoney('bank', amount)
        if Config.DebugMode then
            print(Config.Lang["DebugMessages"].MoneyAddedQB:format(src))
        end
    else
        print(Config.Lang["DebugMessages"].UnsupportedFramework:format(tostring(framework)))
    end
end


--[[ Функція для оновлення рівня гравця ]]
RegisterServerEvent('marko_busjob:server:UpdatePlayerLevel')
AddEventHandler('marko_busjob:server:UpdatePlayerLevel', function()
    local src = source
    UpdatePlayerLevel(src)
end)




------------ Інтерфейс

RegisterServerEvent('getPlayerSkills')
AddEventHandler('getPlayerSkills', function()
    local src = source
    local identifiers = GetPlayerIdentifiers(src)
    local identifier = nil
    local firstName, lastName, job

    -- Отримуємо ідентифікатор гравця
    for _, id in ipairs(identifiers) do
        if string.match(id, "license") then
            identifier = id
            break
        end
    end

    -- Отримуємо дані гравця залежно від фреймворку
    if Config.FrameWork == 'ESX' then
        if identifier then
            local xPlayer = ESX.GetPlayerFromId(src)
            if xPlayer then
                firstName = xPlayer.get('firstName') or "Гравець"
                lastName = xPlayer.get('lastName') or "Безіменний"
                job = xPlayer.job.label or "Безробітний"
            end
        end
    elseif Config.FrameWork == 'QB' then
        local xPlayer = QBCore.Functions.GetPlayer(src)
        if xPlayer then
            identifier = xPlayer.PlayerData.license
            firstName = xPlayer.PlayerData.charinfo.firstname or "Гравець"
            lastName = xPlayer.PlayerData.charinfo.lastname or "Безіменний"
            job = xPlayer.PlayerData.job.label or "Безробітний"
        end
    end

    -- Перевіряємо дані гравця
    if identifier and PlayerLVL[identifier] then
        local playerData = PlayerLVL[identifier]
        if not playerData then
            print("PlayerLVL[identifier] повернув nil")
        else
            print("PlayerLVL знайдено, дані:")
            for key, value in pairs(playerData) do
                print(string.format("  %s: %s", key, tostring(value)))
            end
        end

        -- Перевірка рівнів і досвіду для кожної навички
        for skillKey, columns in pairs(Config.LevelColumns) do
            local lvl = playerData[columns.lvl]
            local xp = playerData[columns.xp]
            if lvl == nil or xp == nil then
                print(string.format("Не вдалося отримати дані рівня або досвіду для навички: %s", skillKey))
            else
                print(string.format("Навичка: %s, Рівень: %s, Досвід: %s", skillKey, lvl, xp))
            end
        end

        -- Передача ачівок
        local achievements = playerData.achievements or {}
        print("Ачівки гравця:")
        local formattedAchievements = {}

        for name, data in pairs(achievements) do
            local configAchievement = nil

            -- Пошук даних про ачівку в Config.Achievements
            for _, category in pairs(Config.Achievements) do
                for _, achievement in ipairs(category) do
                    if achievement.name == name then
                        configAchievement = achievement
                        break
                    end
                end
                if configAchievement then break end
            end

            -- Якщо знайдено відповідну ачівку в конфігурації, додаємо дані
            if configAchievement then
                table.insert(formattedAchievements, {
                    name = name,
                    title = data.title,
                    achievedAt = data.achievedAt,
                    description = configAchievement.description or "Опис відсутній",
                    icon = configAchievement.icon or "default.svg" -- Додаємо іконку або заміну за замовчуванням
                })
                print(string.format("  Назва: %s, Отримано: %s, Опис: %s, Іконка: %s", 
                    name, 
                    os.date("%Y-%m-%d %H:%M:%S", data.achievedAt), 
                    data.title, 
                    configAchievement.icon or "default.svg"
                ))
            else
                print(string.format("  Ачівка %s не знайдена в Config.Achievements", name))
            end
        end

        -- Формуємо дані для клієнта
        local clientData = table.deepcopy(playerData)
        clientData.ExpNeededForEarnLVL = Config.Levels
        clientData.LevelColumns = Config.LevelColumns
        clientData.SkillData = Config.SkillData
        clientData.firstName = firstName
        clientData.lastName = lastName
        clientData.job = job
        clientData.achievements = formattedAchievements -- Передаємо відформатовані ачівки

        TriggerClientEvent('receivePlayerSkills', src, clientData)

    else
        print("Дані гравця не знайдено для:", identifier or "Невідомий")
        TriggerClientEvent('receivePlayerSkills', src, { error = "No data found" })
    end
end)





RegisterNetEvent('executeCommand')
AddEventHandler('executeCommand', function(command)
    if command then
        ExecuteCommand(command)
    end
end)


-- Експорти
exports('getPlayerLevel', function(source, role, callback)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player then
        local identifier = Player.PlayerData.license
        print("getPlayerLevel called with arguments: ", identifier, role)
        getPlayerLevel(identifier, role, callback)
    else
        print("Invalid source: ", source)
        if callback then
            callback(nil)
        end
    end
end)

-- Експорт функції для додавання досвіду гравцю
exports('addExperience', function(source, columnName, amount)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player then
        local identifier = Player.PlayerData.license
        print("addExperience called with arguments: ", identifier, columnName, amount)
        addExperience(source, identifier, columnName, amount)
    else
        print("Invalid source: ", source)
    end
end)



-- Динамічні сторінки


Config = Config or {}
local menuItems = Config.MenuItems

RegisterNetEvent('getMenuItems')
AddEventHandler('getMenuItems', function()
    local src = source -- Отримуємо ID гравця

    -- Відправляємо дані меню клієнту
    TriggerClientEvent('receiveMenuItems', src, menuItems)
end)


RegisterNetEvent('marko_leveling:getEventList', function()
    local src = source
    if not Config.IventDataList or #Config.IventDataList == 0 then
        print("⚠️ Немає доступних івентів для відправлення")
    else
        print("✅ Відправляємо " .. #Config.IventDataList .. " івентів для гравця з ID: " .. src)
    end
    TriggerClientEvent('marko_leveling:sendEventList', src, Config.IventDataList)
end)




-- Налаштування інтерфейсу

-- Запит налаштувань для гравця
RegisterNetEvent('marko_leveling:requestSettings')
AddEventHandler('marko_leveling:requestSettings', function()
    local src = source
    local identifiers = GetPlayerIdentifiers(src)
    local identifier = nil

    for _, id in ipairs(identifiers) do
        if string.match(id, "license") then
            identifier = id
            break
        end
    end

    local settings = nil
    if identifier and PlayerLVL[identifier] and PlayerLVL[identifier].settings then
        -- Перевірка, чи settings є рядком JSON
        if type(PlayerLVL[identifier].settings) == "string" then
            settings = json.decode(PlayerLVL[identifier].settings)
        else
            settings = PlayerLVL[identifier].settings -- Вже декодований об'єкт
        end
    end

    if not settings then
        settings = { theme = "light", levelgrid = "false" } -- Значення за замовчуванням
    end

    -- Виводимо лог налаштувань перед надсиланням
    print("Налаштування, які відправляються гравцю:", json.encode(settings))
    TriggerClientEvent('marko_leveling:receiveSettings', src, settings)
end)



-- Збереження налаштувань гравця
RegisterNetEvent('marko_leveling:saveSettings')
AddEventHandler('marko_leveling:saveSettings', function(settings)
    local src = source
    local identifiers = GetPlayerIdentifiers(src)
    local identifier = nil

    for _, id in ipairs(identifiers) do
        if string.match(id, "license") then
            identifier = id
            break
        end
    end

    if not identifier then
        print("Не вдалося отримати ідентифікатор для збереження налаштувань.")
        return
    end

    local settingsJson = json.encode(settings)
    PlayerLVL[identifier].settings = settingsJson

    exports.oxmysql:execute('UPDATE marko_leveling SET settings = ? WHERE identifier = ?', {settingsJson, identifier}, function()
        print(string.format("Налаштування гравця %s збережено.", identifier))
    end)
end)





--[[ Тестова команда для додавання досвіду Видаліть після тестування! ]]

-- Додавання команди givetestxp
RegisterCommand("givetestxp", function(source, args, rawCommand)
    if source == 0 then
        print("[Error]: This command cannot be run from the console.")
        return
    end

    local identifier = GetPlayerIdentifier(source, 0)
    if not identifier then
        print("[Error]: Failed to retrieve player identifier.")
        return
    end

    local skill = args[1] -- Навичка, для якої додається XP
    local xpAmount = tonumber(args[2]) -- Кількість XP

    if not skill or not xpAmount then
        print("[Error]: Invalid arguments. Usage: /givetestxp <skill> <amount>")
        return
    end

    local columnName = skill .. "_xp"
    if not Config.LevelColumns[skill] then
        print("[Error]: Invalid skill name: " .. skill)
        return
    end

    -- Виклик функції для додавання XP
    addExperience(source, identifier, columnName, xpAmount)

    print(string.format("[Test Command]: Added %d XP to skill '%s' for player.", xpAmount, skill))
end, false)

-- Config.LevelColumns = {
--     ['mining'] = { lvl = 'mining_lvl' },
--     ['fishing'] = { lvl = 'fishing_lvl' },
--     ['crafting'] = { lvl = 'crafting_lvl' }
-- }

-- Config.DebugMode = true
