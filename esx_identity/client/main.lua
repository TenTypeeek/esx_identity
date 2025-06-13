local loadingScreenFinished = false
local guiEnabled = false
local timecycleModifier = "hud_def_blur"

-- Loading screen hook
AddEventHandler('esx:loadingScreenOff', function()
    loadingScreenFinished = true
end)

-- Set ESX player data after registration
RegisterNetEvent('esx_identity:setPlayerData', function(data)
    SetTimeout(1, function()
        ESX.SetPlayerData("name", string.format("%s %s", data.firstName, data.lastName))
        ESX.SetPlayerData("firstName", data.firstName)
        ESX.SetPlayerData("lastName", data.lastName)
        ESX.SetPlayerData("dateofbirth", data.dateOfBirth)
        ESX.SetPlayerData("sex", data.sex)
        ESX.SetPlayerData("height", data.height)
    end)
end)

-- Already registered (skip registration and proceed)
RegisterNetEvent('esx_identity:alreadyRegistered', function()
    while not loadingScreenFinished do Wait(100) end
    -- Trigger appearance loading or skip to game logic here
    TriggerEvent('illenium-appearance:client:ReloadSkin') -- optional
end)

-- Registration logic (only runs if Config.UseDeferrals == false)
if not Config.UseDeferrals then
    local input

    local function showRegistration(state)
        guiEnabled = state

        if state then
            SetTimecycleModifier(timecycleModifier)
        else
            lib.closeInputDialog()
            ClearTimecycleModifier()
            return
        end

        input = lib.inputDialog(TranslateCap('application_name'), {
            {type = 'input', label = TranslateCap('first_name'), description = TranslateCap('first_name_description'), required = true},
            {type = 'input', label = TranslateCap('last_name'), description = TranslateCap('last_name_description'), required = true},
            {type = 'number', label = TranslateCap('height'), min = Config.MinHeight, max = Config.MaxHeight, description = TranslateCap('height_description'), required = true},
            {type = 'date', label = TranslateCap('dob'), description = TranslateCap('dob_description'), format = Config.DateFormat, required = true},
            {type = 'select', label = TranslateCap('gender'), description = TranslateCap('gender_description'), options = {
                {value = "m", label = TranslateCap('gender_male')},
                {value = "f", label = TranslateCap('gender_female')}
            }, required = true},
            {type = 'checkbox', label = TranslateCap('prepared_to_rp'), required = true}
        }, {
            allowCancel = false
        })

        if not input then
            -- Should never happen unless user forcibly cancels UI
            ClearTimecycleModifier()
            return
        end

        local data = {
            firstname = input[1],
            lastname = input[2],
            height = input[3],
            dateofbirth = math.floor(input[4] / 1000), -- ox_lib returns UNIX ms timestamp
            sex = input[5] -- "m" or "f"
        }

        ESX.TriggerServerCallback('esx_identity:registerIdentity', function(success)
            if not success then
                lib.notify({
                    title = TranslateCap('application_name'),
                    description = TranslateCap('application_failed'),
                    type = 'error',
                    position = 'top',
                })
                ClearTimecycleModifier()
                return
            end

            lib.notify({
                title = TranslateCap('application_name'),
                description = TranslateCap('application_accepted'),
                type = 'success',
                position = 'top',
            })

            ClearTimecycleModifier()
            guiEnabled = false

            -- 👇 Open Illenium Appearance creator
            TriggerEvent('illenium-appearance:client:CreateFirstCharacter')

        end, data)
    end

    RegisterNetEvent('esx_identity:showRegisterIdentity', function()
        if not ESX.PlayerData.dead then
            showRegistration(true)
        end
    end)
end
