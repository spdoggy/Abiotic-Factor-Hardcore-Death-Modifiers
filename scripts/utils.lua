-- Note: Refer to the following to setup Lua syntax
-- https://docs.ue4ss.com/guides/using-custom-lua-bindings


--[[
    Author: SpDoggy
    Date: 2026-08-19
    Mod Name: utilities
]]


-- ============================================================
-- CONFIG
-- ============================================================

local Config = require("../config")
local ConfigAdmin = require("../config_admin")
local Enums = require("enums")
local Utils = {}


-- ============================================================
-- INSTANCES
-- ============================================================
local TheWorld = CreateInvalidObject() ---@cast WorldCache UWorld
local DayNightManagerCache = CreateInvalidObject() ---@cast DayNightManagerCache ADayNightManager_C
local LeyakNpcCache = CreateInvalidObject() -- @ANPC_Leyak_C;
local LeyakDirectorCache = CreateInvalidObject() -- @ULeyakDirectorComponent_C;
local AIDirectorCache = CreateInvalidObject() ---@cast AIDirectorCache AAbiotic_AIDirector_C
local WeatherEventLibCache = CreateInvalidObject() ---@cast WeatherEventLibCache UWeatherEventHandleFunctionLibrary
local buffHandleFuncLibCache = CreateInvalidObject() ---@cast buffHandleFuncLibCache UBuffDebuffHandleFunctionLibrary
local sound_has_finished = true

-- ============================================================
-- UTILITIES
-- ============================================================

---Determine if obj is valid
---@param obj UObject|any
---@return boolean
function Utils.IsValid(obj)
    return obj ~= nil and obj.IsValid ~= nil and obj:IsValid()
end


---Cache the world object
---@param world UWorld
function Utils.WorldCache(world)
    if Utils.IsValid(world) then
        TheWorld = world
    end
end


function Utils.GetWorld()
    if Utils.IsValid(TheWorld) then
        return TheWorld
    else
        local gameState = FindFirstOf("Abiotic_Survival_GameState_C")
        if gameState:IsValid() then
            local world = gameState:GetWorld()
            if world and world:IsValid() then
                Utils.WorldCache(world)
                return world
            end
        end
    end
    Utils.error("[GetWorld]: Invalid World")
    return TheWorld
end



---Debug Logging
function Utils.log(message)
    if Config.Debug then
        print(message)
        print("\n")
    end
end


---Error Logging
function Utils.error(message)
    print("Error: " .. message .. "\n")
end

---Log a Vector
---@param vector FVector
---@param actor_name string
function Utils.log_vector(vector, actor_name)
    if Config.Debug then
        if actor_name then
            print(string.format("%s@X/Y/Z: %f, %f, %f\n", actor_name, vector.X, vector.Y, vector.Z))
        else
            print(string.format("X/Y/Z: %f, %f, %f\n", vector.X, vector.Y, vector.Z))
        end
    end
end

-- Split a str based on the separator character
---@param inputstr string
---@param sep string
---@return table
function Utils.split_str(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local tbl = {}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(tbl, str)
    end
    return tbl
end

--- Return the object path
function ObjectPath(obj)

    if not Utils.IsValid(obj) then
        return nil
    end
    local obj_name = ""
    pcall(
        function() obj_name = obj:GetFullName()
    end)
    if not obj_name then
        return nil
    end
    -- Remove the name of the class and extra preceding space
    return obj_name:match("^%S+ (.+)$") or obj_name
end

--- PCall Safe StaticFindObject
function StaticFindObjectWrapper(path)
    if not path then
        return nil
    end
    local obj = nil
    pcall(
        function() obj = StaticFindObject(path)
    end)
    if obj and obj:IsValid() then
        return obj
    end
    return nil
end

---Get World.AuthorityGameMode
---@return AGameModeBase
function Utils.GetGameMode()
    if Utils.IsValid(TheWorld) and TheWorld.AuthorityGameMode then
        return TheWorld.AuthorityGameMode
    else
        local world = Utils.GetWorld()
        if Utils.IsValid(world) and world.AuthorityGameMode then
            return world.AuthorityGameMode
        end
    end
    Utils.error("[GetGameMode]: Failed to get AuthorityGameMode")
    return CreateInvalidObject() ---@type AGameModeBase
end

---Get the AI Director
---@return AAbiotic_AIDirector_C
function Utils.GetAiDirector()
    if Utils.IsValid(AIDirectorCache) then
        return AIDirectorCache
    end
    local gameMode = Utils.GetGameMode() ---@cast gameMode AAbiotic_Survival_GameMode_C

    if Utils.IsValid(gameMode) and gameMode.AI_Director then
        AIDirectorCache = gameMode.AI_Director
        return AIDirectorCache
    end

    Utils.error("[GetAiDirector]: Failed to get AiDirector")
    return CreateInvalidObject() ---@type AAbiotic_AIDirector_C
end

---Get the Leyak AI Director
---@return ULeyakDirectorComponent_C
function Utils.GetLeyakAiDirector()
    if Utils.IsValid(LeyakDirectorCache) then
        return LeyakDirectorCache
    end

    local ai_director = Utils.GetAiDirector()
    if Utils.IsValid(ai_director) then
        return ai_director.LeyakDirectorComponent
    end

    Utils.error("[GetLeyakAiDirector]: Failed to get LeyakAiDirector")
    return CreateInvalidObject() ---@type ULeyakDirectorComponent_C
end

---Get the current Leyak_NPC
---@return ANPC_Leyak_C
function Utils.GetLeyak()
    if Utils.IsValid(LeyakNpcCache) then
        return LeyakNpcCache
    end

    local ai_director = Utils.GetAiDirector()
    if Utils.IsValid(ai_director) then
        LeyakNpcCache = ai_director.ActiveLeyak
        return LeyakNpcCache
    end

    Utils.error("[GetLeyak]: Failed to get Leyak")
    return CreateInvalidObject() ---@type ANPC_Leyak_C
end

---Get the current DayNightManager
---@return ADayNightManager_C
function Utils.GetDayNightManager()
    if Utils.IsValid(DayNightManagerCache) then
        return DayNightManagerCache
    end

    local ai_director = Utils.GetAiDirector()
    if Utils.IsValid(ai_director) and ai_director.DayNightManager then
        DayNightManagerCache = ai_director.DayNightManager
    end
    return DayNightManagerCache
end

--Cache the DayNightManager
function Utils.CacheDayNightManager(dn_manager)
    if Utils.IsValid(dn_manager) then
        DayNightManagerCache = dn_manager
    end
end


---Find a PlayerState object by the player_id
---@param player_id string|FString
---@return AAbiotic_PlayerState_C
function Utils.GetPlayerStateFromID(player_id)
    if type(player_id) == "userdata" and player_id:type() == "FString" then
        player_id = player_id:ToString()
    end
    
    if type(player_id) == "string" and player_id ~= "" then
        if Utils.IsValid(TheWorld) then
            local gameState = TheWorld.GameState ---@type AGameStateBase
            if Utils.IsValid(gameState) and gameState.PlayerArray then
                for i = 1, #gameState.PlayerArray do
                    local playerState = gameState.PlayerArray[i] ---@cast playerState AAbiotic_PlayerState_C
                    if playerState.UniquePlayerID and playerState.UniquePlayerID:ToString() == player_id then
                        return playerState
                    end
                end
            end
        end
    end
    return CreateInvalidObject() ---@type AAbiotic_PlayerState_C
end

---Find a PlayerState object by the player_name
---@param player_name string|FString
---@return AAbiotic_PlayerState_C
function Utils.GetPlayerStateFromName(player_name)
    if type(player_name) == "string" and player_name ~= "" then
        if Utils.IsValid(TheWorld) then
            local gameState = TheWorld.GameState ---@type AGameStateBase
            if Utils.IsValid(gameState) and gameState.PlayerArray then
                for i = 1, #gameState.PlayerArray do
                    local playerState = gameState.PlayerArray[i] ---@cast playerState AAbiotic_PlayerState_C
                    local playerName = playerState:GetPlayerName():ToString() ---@type string
                    if playerName == player_name then
                        return playerState
                    end
                end
            end
        end
    end
    return CreateInvalidObject() ---@type AAbiotic_PlayerState_C
end

---Find a player by the player_id
---@param player_id FString|string
---@return AAbiotic_PlayerCharacter_C
function Utils.GetPlayerFromId(player_id)
    local playerState = Utils.GetPlayerStateFromID(player_id)
    if Utils.IsValid(playerState) and playerState.PawnPrivate then
        return playerState.PawnPrivate ---@type AAbiotic_PlayerCharacter_C
    end
    return CreateInvalidObject() ---@type AAbiotic_PlayerCharacter_C
end


---Find a player by the player name
---@param player_id FString|string
---@return AAbiotic_PlayerCharacter_C
function Utils.GetPlayerFromName(player_name)
    local playerState = Utils.GetPlayerStateFromName(player_name)
    if Utils.IsValid(playerState) and playerState.PawnPrivate then
        return playerState.PawnPrivate ---@type AAbiotic_PlayerCharacter_C
    end
    return CreateInvalidObject() ---@type AAbiotic_PlayerCharacter_C
end

---Lookup a player name by the player_id
---@param player_id FString|string
---@return string
function Utils.GetPlayerNameFromID(player_id)
    local playerState = Utils.GetPlayerStateFromID(player_id)
    if Utils.IsValid(playerState) then
        return playerState:GetPlayerName():ToString() ---@type string
    end
    return ""
end

---Lookup a player name for a valid PlayerChar
---@param player AAbiotic_PlayerCharacter_C
---@return string
function Utils.GetPlayerName(player)
    if Utils.IsValid(player) then
        return player.MyPlayerState:GetPlayerName():ToString()
    end
    return ""
end

---Return a player from the list of online players
---@return AAbiotic_PlayerState_C
function Utils.GetRandomPlayerState()
    if Utils.IsValid(TheWorld) then
        local gameState = TheWorld.GameState ---@type AGameStateBase
        if Utils.IsValid(gameState) and gameState.PlayerArray then
            local selected = math.random(1, #gameState.PlayerArray)
            local playerState = gameState.PlayerArray[selected] ---@cast playerState AAbiotic_PlayerState_C
            local playerName = playerState.PlayerNamePrivate:ToString()
            return playerState
        end
    end
    return CreateInvalidObject() ---@type AAbiotic_PlayerState_C
end


---Get the Admin Player from ConfigAdmin
---@return AAbiotic_PlayerCharacter_C
function Utils.GetAdminPlayer()
    msg_prefix = msg_prefix or ""
    local admin_player = Utils.GetPlayerFromId(ConfigAdmin.admin_id)

    if Utils.IsValid(admin_player.MyPlayerController) then
        return admin_player
    end
    return CreateInvalidObject() ---@type AAbiotic_PlayerCharacter_C
end

---Send a text chat message to the admin player only
---@param msg string Message to Send
---@param msg_prefix FString|string Prefix of Message to Send, i.e name of the Mod
---@param prefix_color table Message prefix color
---@param msg_color table Message color
function Utils.AdminMessage(msg, msg_prefix, prefix_color,  msg_color)
    msg_prefix = msg_prefix or ""
    local admin_player = Utils.GetPlayerFromId(ConfigAdmin.admin_id)
    if Utils.IsValid(admin_player.MyPlayerController) then
        local admin_player_controller = admin_player.MyPlayerController    
        admin_player_controller:Local_DisplayTextChatMessage(msg_prefix, prefix_color, msg, msg_color, admin_player_controller, false)
        Utils.log(msg_prefix .. msg)
    end
end


---Send a text chat message to the admin player only
---@param msg string Message to Send
---@param msg_prefix FString|string Prefix of Message to Send, i.e name of the Mod
---@param prefix_color table Message prefix color
---@param msg_color table Message color
function Utils.AdminWarnMessage(msg, CriticalityLevel, WarningBeep)
    local admin_player = Utils.GetPlayerFromId(ConfigAdmin.admin_id)
    if Utils.IsValid(admin_player) then
        Utils.ClientDisplayWarningMessage(admin_player, msg, CriticalityLevel, WarningBeep)
        Utils.log(msg)
    end
end

---Send a text chat message to the player, Overload of Local_DisplayTextChatMessage
---@param player_controller AAbiotic_PlayerController_C Player message recipient (direct via PlayerController)
---@param msg string Message to Send
---@param msg_prefix string|FString Prefix of Message to Send, i.e name of the Mod
---@param prefix_color table Message prefix color
---@param msg_color table Message color
function Utils.PlayCtrlTextChatMessage(player_controller, msg, msg_prefix, prefix_color,  msg_color)
    msg_prefix = msg_prefix or ""
    if Utils.IsValid(player_controller) then
        player_controller:Local_DisplayTextChatMessage(msg_prefix, prefix_color, msg, msg_color, player_controller, false)
        Utils.log(msg_prefix .. msg)
    end
end

---Send a text chat message to the player, Overload of Local_DisplayTextChatMessage
---@param player AAbiotic_PlayerCharacter_C Player message recipient (via PlayerCharacter)
---@param msg string Message to Send
---@param msg_prefix string Prefix of Message to Send, i.e name of the Mod
---@param prefix_color table Message prefix color
---@param msg_color table Message color
function Utils.PlayTextChatMessage(player, msg, msg_prefix, prefix_color,  msg_color)
    msg_prefix = msg_prefix or ""

    if Utils.IsValid(player) then
        local player_controller = player.MyPlayerController
        if Utils.IsValid(player_controller) then
            Utils.PlayCtrlTextChatMessage(player_controller, msg, msg_prefix, prefix_color,  msg_color)
        end
    end
end


---AAbiotic_PlayerCharacter_C function, that shows colored text at the top of the screen and can play a warning beep
---@param Message string
---@param CriticalityLevel ECriticalityLevels|CriticalityLevels|integer|nil Color of the message is based on the CriticalityLevel
---@param WarningBeep boolean|nil Should a warning sound be played
function Utils.AllClientDisplayWarningMessage(Message, CriticalityLevel, WarningBeep)
    if not Message then return end
    -- Default values
    CriticalityLevel = CriticalityLevel or Enums.ClientWarnMessageColors.Green
    WarningBeep = WarningBeep or false

    if Utils.IsValid(TheWorld) then
        local gameState = TheWorld.GameState ---@type AGameStateBase
        if Utils.IsValid(gameState) and gameState.PlayerArray then
            for i = 1, #gameState.PlayerArray do
                local playerState = gameState.PlayerArray[i] ---@cast playerState AAbiotic_PlayerState_C
                local playerName = playerState.PlayerNamePrivate:ToString()
                local fText = FText(Message)
                if fText then
                    playerState.PawnPrivate:Client_DisplayWarningMessage(fText, CriticalityLevel, WarningBeep)
                else
                    Utils.log('ClientDisplayWarningMessage: Couldn\'t get a FText out of "'..Message..'"')
                end
            end
        end
    end
end

---AAbiotic_PlayerCharacter_C function, that shows colored text at the top of the screen and can play a warning beep
---@param player AAbiotic_PlayerCharacter_C
---@param Message string
---@param CriticalityLevel ECriticalityLevels|CriticalityLevels|integer|nil Color of the message is based on the CriticalityLevel
---@param WarningBeep boolean|nil Should a warning sound be played
function Utils.ClientDisplayWarningMessage(player, Message, CriticalityLevel, WarningBeep)
    if not Message then return end
    -- Default values
    CriticalityLevel = CriticalityLevel or Enums.ClientWarnMessageColors.Green
    WarningBeep = WarningBeep or false

    if Utils.IsValid(player) then
        local fText = FText(Message)
        if fText then
            player:Client_DisplayWarningMessage(fText, CriticalityLevel, WarningBeep)
        else
            Utils.log('ClientDisplayWarningMessage: Couldn\'t get a FText out of "'..Message..'"')
        end
    end
end

---Get a List of the story event flags
---@return table
function Utils.GetWorldEventFlags()

    wfs = FindFirstOf("WorldFlagSubsystem")

    if not Utils.IsValid(wfs) then
        return {}
    end

    local ok, loaded = pcall(function() return wfs:HasWorldFlagsLoaded() end)
    if not ok or not loaded then return nil end

    local out = {}
    local flags = {}
    pcall(function() wfs:GetWorldFlags(flags) end)
    for _, f in ipairs(flags) do
        local ok2, name = pcall(function() return f:get():ToString() end)
        if ok2 and name and name ~= "" then out[name] = true end
    end
    return out
end



---Print a List of the story event flags
function Utils.PrintWorldEventFlags()

    wfs = FindFirstOf("WorldFlagSubsystem")

    if not Utils.IsValid(wfs) then
        return {}
    end

    local ok, loaded = pcall(function() return wfs:HasWorldFlagsLoaded() end)
    if not ok or not loaded then return nil end

    local out = {}
    local flags = {}
    pcall(function() wfs:GetWorldFlags(flags) end)
    for _, f in ipairs(flags) do
        local ok2, name = pcall(function() return f:get():ToString() end)
        print(name)
    end
    return out
end

---Returns true if an event name is true in the world event log
---@return boolean
function Utils.WorldHasEventOccurred(event_name)
    local event_flags = Utils.GetWorldEventFlags()
    if event_flags then
        for k, v in pairs(event_flags) do
            if k == event_name and v then
                return true
            end
        end
    end
    return false
end


Utils.AssetCache = {}

---Wait and load the asset at path when able
---Used with LoadAsync
---@param path string -- The asset path to load
---@param callback any -- The call handler
function Utils.LoadAssets(path, callback)

    local obj = StaticFindObject(path)
    if obj and Utils.IsValid(obj) then
        Utils.AssetCache[path] = obj
        callback(obj)
        return
    end

    ExecuteInGameThread(function()
        local asset, found, loaded = LoadAsset(path)
        if found and loaded and Utils.IsValid(asset) then
            Utils.AssetCache[path] = asset
            -- Utils.log("ASSETS loaded: " .. path)
        else
            Utils.error("ASSETS failed to load: " .. path)
            Utils.AssetCache[path] = nil
        end
        local waiters = {path}
        for _, cb in ipairs(waiters) do
            local ok, err = pcall(callback, path)
            if not ok then
                Utils.error("ASSETS callback error: " .. tostring(err))
            end
        end
    end)
end

---Wait and load the assets in paths when able
---@param paths string -- The asset paths to load
---@param finalCallback any -- The call handler for after asset has loaded
function LoadAsync(paths, finalCallback)
    local remaining = #paths
    local results = {}

    if remaining == 0 then
        finalCallback(results)
        return
    end

    for _, path in ipairs(paths) do
        Utils.LoadAssets(path, function(asset)
            results[path] = asset
            remaining = remaining - 1
            if remaining == 0 then
                finalCallback(results)
            end
        end)
    end
end

---Play Sound in World using GameplayStatics
---@param snd_path string -- Path to the sound, i.e "/Game/Audio/Monsters/Leyak/s_leyak_breathing.s_leyak_breathing"
---@param volume float -- Sound volume
---@param stop_delay number -- Delay before stopping
function Utils.PlaySFX(snd_path, volume, stop_delay)


    LoadAsync({ snd_path }, function()
        local gs = StaticFindObject("/Script/Engine.Default__GameplayStatics")

        -- local gs = GetGameplayStatics()
        local world = TheWorld
        
        --local sound = GetIfValid(snd_path)
        local sound = StaticFindObject(snd_path)
        if sound and Utils.IsValid(sound) then
    
            --player:Client_Play2DSoundEffect(sound)
            --player:Client_UpdateUISound(TEnumAsByte<E_ResultState::Type> State, class USoundBase* Sound);

            if not Utils.IsValid(sound) then return end

                if stop_delay then
                    local comp
                    -- (World, Sound, Vol, Pitch, StartTime, Concurrency, bPersistAcrossLevel, bAutoDestroy)
                    pcall(function() comp = gs:CreateSound2D(world, sound, volume, 1.0, 0.0, nil, false, false) end)
                    if Utils.IsValid(comp) then
                        pcall(function() comp:Play(0.0) end)
                        ExecuteWithDelay(stop_delay, function()
                            pcall(function() comp:Stop(0.0) end)
                        end)
                    end
                else
                    -- (World, Sound, Vol, Pitch, StartTime, Concurrency, OwningController, bIsUISound)
                    pcall(function() 
                        gs:PlaySound2D(world, sound, volume, 1.0, 0.0, nil, nil, true)
                    end)
                end
        end
    end)
end


---Play Sound at Locating using GameplayStatics
---@param snd_path string -- Path to the sound, i.e "/Game/Audio/Monsters/Leyak/s_leyak_breathing.s_leyak_breathing"
---@param location table -- Location to play sound at
---@param volume float|number -- Sound volume
---@param pitch float|number -- Sound pitch, default 1.0
---@param wait boolean -- Wait for the sound to complete before accepting new sounds
function Utils.PlaySoundAtLocation(snd_path, location, rotation, volume, pitch, wait)
    LoadAsync({ snd_path }, function()
        local gs = StaticFindObject("/Script/Engine.Default__GameplayStatics")
        local world = TheWorld
        local sound = StaticFindObject(snd_path)
        local start_at = 0.0
        local wait = wait or false

        -- Return if not accepting and prev sound has not finished
        if wait and not sound_has_finished then
            return
        end
        if sound and Utils.IsValid(sound) then
            
            sound_has_finished = false
            gs:PlaySoundAtLocation(world, sound, location, rotation, volume, pitch, start_at, nil, nil, nil, nil)
            local sound_off_delay = 1000 + math.floor(sound.Duration * 1000)
            
            ExecuteWithDelay(sound_off_delay, function()
                sound_has_finished = true
            end)
        end
    end)
end

-- void Broadcast_PlaySoundAtLocation(class USoundBase* Sound, FVector Location, bool LoudAmbientSound);
-- This will work on dedicate servers
function Utils.Broadcast_PlaySoundAtLocation(snd_path, location, volume, pitch, wait)
    LoadAsync({ snd_path }, function()
        
        local world = TheWorld
        local game_state = TheWorld.GameState
        local sound = StaticFindObject(snd_path)
        local wait = wait or false

        -- Return if not accepting and prev sound has not finished
        if wait and not sound_has_finished then
            return
        end
        if sound and Utils.IsValid(sound) and Utils.IsValid(TheWorld) then
            sound.Volume = volume -- Won't work on dedicated servers
            sound.Pitch = pitch
            sound_has_finished = false
            local loud = true
            -- sound.bLooping = false -- Some sounds like alarms, will loop endlessly -- this is apparently client side only
            game_state:Broadcast_PlaySoundAtLocation(sound, location, loud)
            local sound_off_delay = 1000 + math.floor(sound.Duration * 1000)

            ExecuteWithDelay(sound_off_delay, function()
                sound_has_finished = true
            end)
        end
    end)
end


---Play Sound at Player or Actor using GameplayStatics
---@param snd_path string -- Path to the sound, i.e "/Game/Audio/Monsters/Leyak/s_leyak_breathing.s_leyak_breathing"
---@param player AAbiotic_PlayerCharacter_C|AActor where sound should be played near
---@param volume float|number -- Sound volume
---@param pitch float|number -- Sound pitch, default 1.0
---@param wait boolean -- Wait for the sound to complete before accepting new sounds
function Utils.PlaySoundAtActor(snd_path, player_or_actor, volume, pitch, wait)
    if  Utils.IsValid(player_or_actor) then
        local location = player_or_actor:K2_GetActorLocation()
        local rotation = {}
        local wait = wait or false
        --Utils.PlaySoundAtLocation(snd_path, location, rotation, volume, pitch, wait)
        Utils.Broadcast_PlaySoundAtLocation(snd_path, location, volume, pitch, wait)
    end
end


---Play Sound at Player or Actor using GameplayStatics, Overload of Utils.PlaySoundAtActor
---@param snd_path string -- Path to the sound, i.e "/Game/Audio/Monsters/Leyak/s_leyak_breathing.s_leyak_breathing"
---@param player AAbiotic_PlayerCharacter_C|AActor where sound should be played near
---@param volume float|number -- Sound volume
---@param pitch float|number -- Sound pitch, default 1.0
---@param wait boolean -- Wait for the sound to complete before accepting new sounds
function Utils.PlaySoundAtPlayer(snd_path, player_or_actor, volume, pitch, wait)
    local wait = wait or false
    Utils.PlaySoundAtActor(snd_path, player_or_actor, volume, pitch, wait)
end

---Play Sound at every Player using GameplayStatics
function Utils.PlaySoundAtAllPlayers(snd_path, volume, pitch, wait)
    local wait = wait or false
    if Utils.IsValid(TheWorld) then
        local gameState = TheWorld.GameState ---@type AGameStateBase
        if Utils.IsValid(gameState) and gameState.PlayerArray then
            for i = 1, #gameState.PlayerArray do
                local playerState = gameState.PlayerArray[i] ---@cast playerState AAbiotic_PlayerState_C
                Utils.PlaySoundAtActor(snd_path, playerState.PawnPrivate, volume, pitch, wait)
            end
        end
    end
end


-------------------

-- void Broadcast_Play3DSoundEffect(class USoundBase* Sound, bool Attached, FVector UnattachedLocation, bool PlayForLocalPlayer);

function Utils.Broadcast_Play3DSoundEffect(snd_path, player, location, wait)
    LoadAsync({ snd_path }, function()
        local gs = StaticFindObject("/Script/Engine.Default__GameplayStatics")
        local world = TheWorld
        local sound = StaticFindObject(snd_path)
        local start_at = 0.0
        local wait = wait or false

        -- Return if not accepting and prev sound has not finished
        if wait and not sound_has_finished then
            return
        end
        if sound and Utils.IsValid(sound) and player and Utils.IsValid(player) then
            
            sound_has_finished = false
            player:Broadcast_Play3DSoundEffect(sound, false, location, true)
            local sound_off_delay = 1000 + math.floor(sound.Duration * 1000)
            
            ExecuteWithDelay(sound_off_delay, function()
                sound_has_finished = true
            end)
        end
    end)
end

------------

local function GetPlayerInventory(playerPawn)
    if (not playerPawn or not playerPawn:IsValid()) then
        return nil
    end

    if (playerPawn.CharacterInventory and playerPawn.CharacterInventory:IsValid()) then
        return playerPawn.CharacterInventory
    end

    return nil
end


local function FindEmptySlot(inventory)
    if (not inventory or not inventory.CurrentInventory) then
        return nil
    end

    for i = 1, #inventory.CurrentInventory do
        local slot = inventory.CurrentInventory[i]

        if (slot) then
            local rowName = slot.ItemDataTable.RowName:ToString()

            if (rowName == "None" or rowName == "Empty" or rowName == "") then
                return i
            end
        end
    end

    return nil
end

-- Place one item into one target's inventory. Writes its own errors; returns success.
function Utils.GiveItemToTarget(pawn, name, itemId, item_table, item_cat, quantity)

    local inventory = GetPlayerInventory(pawn)
    if (not inventory) then
        print(string.format("[Error] Cannot access %s's inventory", name))
        return false
    end

    local dataTable = StaticFindObject(item_table)
    if (not dataTable or not dataTable:IsValid()) then
        print(string.format("[Error] Failed to load table: %s", item_cat))
        return false
    end

    local slotIndex = FindEmptySlot(inventory)
    if (not slotIndex) then
        print(string.format("[Error] %s's inventory is full", name))
        return false
    end

    local slot = inventory.CurrentInventory[slotIndex]


    slot.ItemDataTable.RowName = FName(itemId)
    slot.ChangeableData.CurrentItemDurability = 100
    slot.ChangeableData.MaxItemDurability = 100
    slot.ChangeableData.CurrentStack = quantity

    pcall(function()
        inventory:OnRep_CurrentInventory()
    end)

    print(string.format("+ Gave %s: %s x%d", name, itemId, quantity))
    return true
end

-----------------


function Utils.CacheWeatherEventLib(w_event_lib)
    if Utils.IsValid(w_event_lib) then
        WeatherEventLibCache = w_event_lib
    end
end

---@return UWeatherEventHandleFunctionLibrary
function Utils.GetWeatherEventLib()
    if not Utils.IsValid(WeatherEventLibCache) then
        WeatherEventLibCache = StaticFindObject("/Script/AbioticFactor.Default__WeatherEventHandleFunctionLibrary")
        ---@cast WeatherEventLibCache UWeatherEventHandleFunctionLibrary
    end
    return WeatherEventLibCache
end


---Triggers a weather event
---@param EventName string|WeatherEvents
---@return boolean Success
function Utils.TriggerWeatherEvent(EventName)

    if type(EventName) ~= "string" then return false end

    local weatherEventHandleFunctionLibrary = Utils.GetWeatherEventLib()
    local dn_manager = Utils.GetDayNightManager()
    if Utils.IsValid(weatherEventHandleFunctionLibrary) and Utils.IsValid(dn_manager) then
        ---@type table<LocalUnrealParam>
        local outRowHandles = {} ---@type LocalUnrealParam[]
        weatherEventHandleFunctionLibrary:GetAllWeatherEventRowHandles(outRowHandles)

        if #outRowHandles > 0 and EventName == "None" then
            local rowHandle = outRowHandles[1]:get() ---@type FWeatherEventRowHandle
            rowHandle.RowName = NAME_None
            local event_table_row = { 
                RowName = rowHandle.RowName,
                DataTablePath = rowHandle.DataTablePath
            }
            dn_manager:TriggerWeatherEvent(event_table_row)
            return true
        end

        for i = 1, #outRowHandles, 1 do
            local param = outRowHandles[i]
            local rowHandle = param:get() ---@type FWeatherEventRowHandle
            local rowName = rowHandle.RowName:ToString()
            if rowName == EventName then
                local event_table_row = { 
                    RowName = rowHandle.RowName,
                    DataTablePath = rowHandle.DataTablePath
                }
                dn_manager:TriggerWeatherEvent(event_table_row)
                return true
            end
        end
    end
    return false
end

-- Log Current In-Game Time
function Utils.LogCurrentTime()
    local dn_manager = Utils.GetDayNightManager()
    if not Utils.IsValid(dn_manager) then
        return
    end
    local total_seconds = dn_manager.CurrentTimeInSeconds
    local hours = math.floor((total_seconds/60)/60)
    local minutes = math.floor( (dn_manager.CurrentTimeInSeconds - (hours*60*60) ) / 60 )
    local seconds = dn_manager.CurrentTimeInSeconds - (hours*60*60) - (minutes*60)
    Utils.log(string.format("Time: %02d:%02d:%02d", hours,minutes,seconds))
end


-- Log Current In-Game Time
---@return number
function Utils.GetCurrentGameHour()
    local dn_manager = Utils.GetDayNightManager()
    if not Utils.IsValid(dn_manager) then
        return
    end
    local total_seconds = dn_manager.CurrentTimeInSeconds
    local hours = math.floor((total_seconds/60)/60)
    local minutes = math.floor( (dn_manager.CurrentTimeInSeconds - (hours*60*60) ) / 60 )
    local seconds = dn_manager.CurrentTimeInSeconds - (hours*60*60) - (minutes*60)
    Utils.log(string.format("Time: %02d:%02d:%02d", hours,minutes,seconds))
    return hours
end

-- Is tomorrow a portal reset day?
---@return boolean
function Utils.IsPortalResetEve()
    local dn_manager = Utils.GetDayNightManager()
    if not Utils.IsValid(dn_manager) then
        return false
    end
    -- enum class EDayOfTheWeek {
    --     Monday = 0,
    --     Tuesday = 1,
    --     Wednesday = 2,
    --     Thursday = 3,
    --     Friday = 4,
    --     Saturday = 5,
    --     Sunday = 6,
    --     EDayOfTheWeek_MAX = 7,
    -- };
    local day_index = (dn_manager.CurrentDay % 7)
    local found = false
    dn_manager.PortalResetDays:ForEach(function(element)
        local value = element:get()
    
        -- break if true
        if (day_index + 1) == value  then

            found = true
            return true
        end
    end)
    if found then
        return true
    end
    return false
end

----

-- Return true if a player has a matching named Buff
---@param player AAbiotic_PlayerCharacter_C
---@param buff_name string
---@return boolean
function Utils.doesPlayerHaveBuff(player, buff_name)
    local buff_map = player.BuffDebuffComponent.CurrentBuffs -- @TArray<FBuffDebuffEntry> CurrentBuffs;
    local has_the_buff = false
    buff_map:ForEach(function(index, value)
        local buff_debuff_name = value:get().BuffRow.RowName:ToString()
        if buff_debuff_name == buff_name then
            has_the_buff = true
        end
    end)
    return has_the_buff
end

local function apply_buff_helper(actor, linkedActor, apply, label)

    if not Utils.IsValid(actor) then
        return
    end

    local comp_path = ObjectPath(actor.BuffDebuffComponent)
    if not comp_path then
        Utils.error("[Utils::apply_buff_helper]: Invalid BuffDebuffComponent")
        return
    end
    local linkPath = linkedActor and Utils.ObjectPath(linkedActor) or nil

    ExecuteInGameThread(function()
        local comp = StaticFindObjectWrapper(comp_path)
        if comp then
            local link = linkPath and StaticFindObjectWrapper(linkPath) or nil
            apply(comp, link)
        end
    end)
end


function Utils.ApplyBuff(actor, buff, duration, linkedActor, limb)
    apply_buff_helper(actor, linkedActor, function(comp, link)
        if not Utils.IsValid(buffHandleFuncLibCache) then
            buffHandleFuncLibCache = StaticFindObject("/Script/AbioticFactor.Default__BuffDebuffHandleFunctionLibrary")
        end
        if not Utils.IsValid(buffHandleFuncLibCache) then
            Utils.LogBad("ApplyBuff - BuffDebuffHandleFunctionLibrary not found")
            return
        end
        pcall(function()
            local handle = buffHandleFuncLibCache:MakeBuffDebuffRowHandle(FName(buff))
            -- Server_ApplyBuff(handle, , NewDuration, Limb, LinkedActor, bool)
            local OverrideDefaultDuration = true
            local skip_dialog = false
            comp:Server_ApplyBuff(handle, OverrideDefaultDuration, duration or 10, limb or 0, link, skip_dialog)
        end)
    end)
end


-- Get Buff-Debuff Row matching by matching name
function Utils.GetBuffDebuffRow(named)

    if not Utils.IsValid(buffHandleFuncLibCache) then
        buffHandleFuncLibCache = StaticFindObject("/Script/AbioticFactor.Default__BuffDebuffHandleFunctionLibrary")
    end
    if not Utils.IsValid(buffHandleFuncLibCache) then
        Utils.LogBad("ApplyBuff - BuffDebuffHandleFunctionLibrary not found")
        return
    end

    local out_row_handles = {}
    buffHandleFuncLibCache:GetAllBuffDebuffRowHandles(out_row_handles)

    for i = 1, #out_row_handles, 1 do
        local param = out_row_handles[i]
        local row_handle = param:get() ---@type FWeatherEventRowHandle
        local row_name = row_handle.RowName:ToString()
        --Utils.log(i..":")
        --Utils.log(row_name)
        if row_name == named then
            return row_handle
        end
    end

    return nil
end

--- Remove the named buff from the player
---@param player AAbiotic_PlayerCharacter_C
---@buff_name string
---@all_stacks boolean
---@limb number (Limbs Enum)
---@expired_by_time boolean
function Utils.RemoveBuff(player, buff_name, all_stacks, limb, expired_by_time)
    local remove_all_stacks = all_stacks or false
    local limbs = limb or 0
    local expired_by_time_flag = expired_by_time or false

    if not Utils.IsValid(buffHandleFuncLibCache) then
        buffHandleFuncLibCache = StaticFindObject("/Script/AbioticFactor.Default__BuffDebuffHandleFunctionLibrary")
    end

    local row_handle = Utils.GetBuffDebuffRow(buff_name)
    if row_handle and Utils.IsValid(row_handle) then
        player.BuffDebuffComponent:Server_RemoveBuff(row_handle, remove_all_stacks, limbs, expired_by_time_flag)
    end
end



return Utils