local playerIdentity = {}
local alreadyRegistered = {}
local multichar = ESX.GetConfig().Multichar

local function deleteIdentityFromDatabase(xPlayer)
    MySQL.query.await(
        'UPDATE users SET firstname = ?, lastname = ?, dateofbirth = ?, sex = ?, height = ? WHERE identifier = ?',
        {nil, nil, nil, nil, nil, xPlayer.identifier}
    )

    if Config.FullCharDelete then
        MySQL.update.await('UPDATE addon_account_data SET money = 0 WHERE account_name IN (?) AND owner = ?',
            {{'bank_savings', 'caution'}, xPlayer.identifier})

        MySQL.prepare.await('UPDATE datastore_data SET data = ? WHERE name IN (?) AND owner = ?',
            {'\'{}\'', {'user_ears', 'user_glasses', 'user_helmet', 'user_mask'}, xPlayer.identifier})
    end
end

local function deleteIdentity(xPlayer)
    if not alreadyRegistered[xPlayer.identifier] then return end

    xPlayer.setName(('Unknown Unknown'))
    xPlayer.set('firstName', nil)
    xPlayer.set('lastName', nil)
    xPlayer.set('dateofbirth', nil)
    xPlayer.set('sex', nil)
    xPlayer.set('height', nil)
    deleteIdentityFromDatabase(xPlayer)
end

local function saveIdentityToDatabase(identifier, identity)
    MySQL.update.await(
        'UPDATE users SET firstname = ?, lastname = ?, dateofbirth = ?, sex = ?, height = ? WHERE identifier = ?',
        {identity.firstName, identity.lastName, identity.dateOfBirth, identity.sex, identity.height, identifier}
    )
end

local function formatName(name)
    return name:gsub("^%l", string.upper)
end

local function formatDate(str)
    local date
    if Config.DateFormat == "DD/MM/YYYY" then
        date = os.date('%d/%m/%Y', tonumber(str))
    elseif Config.DateFormat == "MM/DD/YYYY" then
        date = os.date('%m/%d/%Y', tonumber(str))
    elseif Config.DateFormat == "YYYY/MM/DD" then
        date = os.date('%Y/%m/%d', tonumber(str))
    end
    return date
end

-- Illenium integration only needed when identity is being created
RegisterNetEvent('esx_identity:registerIdentity', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    if alreadyRegistered[xPlayer.identifier] then
        xPlayer.showNotification(TranslateCap('already_registered'), "error")
        return
    end

    playerIdentity[xPlayer.identifier] = {
        firstName = formatName(string.sub(data.firstname, 1, Config.MaxNameLength)),
        lastName = formatName(string.sub(data.lastname, 1, Config.MaxNameLength)),
        dateOfBirth = formatDate(data.dateofbirth),
        sex = data.sex,
        height = data.height
    }

    local currentIdentity = playerIdentity[xPlayer.identifier]

    xPlayer.setName(('%s %s'):format(currentIdentity.firstName, currentIdentity.lastName))
    xPlayer.set('firstName', currentIdentity.firstName)
    xPlayer.set('lastName', currentIdentity.lastName)
    xPlayer.set('dateofbirth', currentIdentity.dateOfBirth)
    xPlayer.set('sex', currentIdentity.sex)
    xPlayer.set('height', currentIdentity.height)

    saveIdentityToDatabase(xPlayer.identifier, currentIdentity)
    alreadyRegistered[xPlayer.identifier] = true
    playerIdentity[xPlayer.identifier] = nil

    -- ✳️ Open appearance menu (illenium)
    TriggerClientEvent('illenium-appearance:client:CreateFirstCharacter', src)

    TriggerClientEvent('esx_identity:setPlayerData', src, currentIdentity)
end)

-- On player load: check and assign identity
RegisterNetEvent('esx:playerLoaded', function(playerId, xPlayer)
    MySQL.single('SELECT firstname, lastname, dateofbirth, sex, height FROM users WHERE identifier = ?', {xPlayer.identifier}, function(result)
        if result and result.firstname then
            alreadyRegistered[xPlayer.identifier] = true
            xPlayer.setName(('%s %s'):format(result.firstname, result.lastname))
            xPlayer.set('firstName', result.firstname)
            xPlayer.set('lastName', result.lastname)
            xPlayer.set('dateofbirth', result.dateofbirth)
            xPlayer.set('sex', result.sex)
            xPlayer.set('height', result.height)
            TriggerClientEvent('esx_identity:setPlayerData', xPlayer.source, result)
            TriggerClientEvent('esx_identity:alreadyRegistered', xPlayer.source)
        else
            alreadyRegistered[xPlayer.identifier] = false
            TriggerClientEvent('esx_identity:showRegisterIdentity', xPlayer.source)
        end
    end)
end)

-- Char delete command
if Config.EnableCommands then
    ESX.RegisterCommand('chardel', 'user', function(xPlayer)
        if alreadyRegistered[xPlayer.identifier] then
            deleteIdentity(xPlayer)
            playerIdentity[xPlayer.identifier] = nil
            alreadyRegistered[xPlayer.identifier] = false
            TriggerClientEvent('esx_identity:showRegisterIdentity', xPlayer.source)
            xPlayer.showNotification(TranslateCap('deleted_character'))
        else
            xPlayer.showNotification(TranslateCap('error_delete_character'))
        end
    end, false, {help = TranslateCap('delete_character')})

    ESX.RegisterCommand('char', 'user', function(xPlayer)
        if xPlayer and xPlayer.getName() then
            xPlayer.showNotification(TranslateCap('active_character', xPlayer.getName()))
        else
            xPlayer.showNotification(TranslateCap('error_active_character'))
        end
    end, false, {help = TranslateCap('show_active_character')})
end
