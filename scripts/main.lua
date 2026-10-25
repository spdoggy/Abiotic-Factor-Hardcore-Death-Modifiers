--[[
    Author: SpDoggy
    Date: 2026-10-21
    Mod Name: Hardcore Modifiers
]]

---------- Configurations ----------
-- Enable mod from the start
ModEnabled = true

-------------- Hotkeys -------------
-- Possible keys: https://github.com/UE4SS-RE/RE-UE4SS/blob/main/docs/lua-api/table-definitions/key.md
-- See ModifierKey: https://github.com/UE4SS-RE/RE-UE4SS/blob/main/docs/lua-api/table-definitions/modifierkey.md
-- ModifierKeys can be combined. e.g.: {ModifierKey.CONTROL, ModifierKey.ALT} = CTRL + ALT + Q
-- Set to `nil` to disable hotkey.
ToggleKey = Key.F5
ToggleKeyModifiers = {ModifierKey.CONTROL}
------------------------------------
local Utils = require("utils")
local Config = require("../config")
------------------------------
-- Don't change code below --
------------------------------
ModName = "Hardcore-Modifiers"
ModVersion = "1.0.0"
DebugMode = false
LogFilePath = "./ue4ss/Mods/Abiotic-Factor-Hardcore-Death-Modifiers/death_note.lua"
local re_spawned_state = {}
local SpawnStates = {
    Alive = "Alive",
    Dead = "Dead",
    Reviving = "Reviving",
}

Utils.log("Starting Hardcore-Modifiers mod initialization")


local function WriteDeathNote(death_table)
    local death_notes,err = io.open(LogFilePath,"w")
    if death_notes then
        death_notes:write("return {\n")
        for key, value in pairs(death_table) do
            local line = string.format("    %s = %s,\n", key, value)
            death_notes:write(line)
        end
        death_notes:write("}\n")
        death_notes:close()
    end
end

local function CheckDeathNoteExists()
    local f=io.open(LogFilePath,"r")
    if f ~= nil then
        io.close(f)
        return true
    else
        init_table = {
            Player1 = 4,
            Player2 = 0,
        }
        WriteDeathNote(init_table)
        return false
    end
end

local function IsPlayerInDeathLog(player_name)
    CheckDeathNoteExists()
    local temp_log = require("../death_note")
    for key, value in pairs(temp_log) do
        if player_name == key then
            return true
        end
    end
    return false
end

local function LogPlayerDeath(player_name)
    CheckDeathNoteExists()
    local death_note = require("../death_note")
    if IsPlayerInDeathLog(player_name) then
        death_note[player_name] = death_note[player_name] + 1
    else
        death_note[player_name] = 1
    end
    WriteDeathNote(death_note)
end

local function ResetPlayerLives(player_name)
    CheckDeathNoteExists()
    local death_note = require("../death_note")
    death_note[player_name] = 0
    WriteDeathNote(death_note)
end

local function GetNumPlayerDeaths(player_name)
    CheckDeathNoteExists()
    local death_log = require("../death_note")
    if IsPlayerInDeathLog(player_name) then
        return death_log[player_name]
    end
    return 0
end

local function PlayerHasLivesLeft(player_name)
    local death_count = GetNumPlayerDeaths(player_name)
    local lives_remaining = Config.extra_lives - death_count
    return lives_remaining > 0
end

local function DisplayPlayerLivesRemaining(player_name)
    local player = Utils.GetPlayerFromName(player_name)
    if Utils.IsValid(player) then
        local death_count = GetNumPlayerDeaths(player_name)
        local lives_remaining = math.max(Config.extra_lives - death_count, 0)
        local msg = string.format("Player %s: %d lives left!", player_name, lives_remaining)
        local color = Enums.ClientWarnMessageColors.Green
        if lives_remaining == 1 then
            color= Enums.ClientWarnMessageColors.Yellow
            msg = string.format("Player %s: %d life left!", player_name, lives_remaining)
        elseif lives_remaining <= 1 then
            color= Enums.ClientWarnMessageColors.Red
            msg = string.format("You died.. some knowledge has been lost...")
        end
        ExecuteWithDelay(2500, function()
            Utils.ClientDisplayWarningMessage(player, msg, color, false)
        end)
    else
        print("[DisplayPlayerLivesRemaining]: player not found")
    end
end

local function PlayerApplyAmnesia(player_name)
    local player = Utils.GetPlayerFromName(player_name)
    local player_prog = player.CharacterProgressionComponent
    if Utils.IsValid(player) and Utils.IsValid(player_prog) then

        local amnesia_threshold = true
        player_prog:Request_ResetAllSkills(amnesia_threshold)
        local success = {}
        local delay = 1000
        for i = 1, 16, 1 do
            ExecuteWithDelay(delay, function()
                local IgnoreModifiers = true
                player_prog:Server_AddXPToSkill(i, Config.reset_xp, IgnoreModifiers, success)
            end)
            delay = delay + 200
        end
    end
end

local function PlayerSetSkillDebug(player_name, xp)
    xp = xp or 94000
    local player = Utils.GetPlayerFromName(player_name)
    local player_prog = player.CharacterProgressionComponent
    if Utils.IsValid(player) and Utils.IsValid(player_prog) then
        local amnesia_threshold = true
        player_prog:Request_ResetAllSkills(amnesia_threshold)
        local success = {}
        local delay = 500
        for i = 1, 16, 1 do
            ExecuteWithDelay(delay, function()
                player_prog:Server_AddXPToSkill(i, xp, true, success)
                xp = xp + 10
            end)
        end
    end
end

local function RespawnFromHardcoreDeath(player, player_state)

    ExecuteInGameThread(function()

        local success = {}
        player:RespawnPlayerCharacter(false, false, FName("sector_office"), success)
        player_state:AdminReviveFromHardcoreDeath()
        local cafeteria_location = {X = -15314, Y = 12532, Z = 128}
        local cafeteria_rotation = {Pitch = 0.0, Yaw = 359.0, Roll = 0.0}
        player:K2_TeleportTo(cafeteria_location, cafeteria_rotation)

        -- ExecuteWithDelay(1500, function()
        --     local success = {}
        --     player:RespawnPlayerCharacter(false, false, FName("sector_office"), success)
        --     player_state:AdminReviveFromHardcoreDeath()
        -- end)

        -- ExecuteWithDelay(1600, function()
        --     local cafeteria_location = {X = -15314, Y = 12532, Z = 128}
        --     local cafeteria_rotation = {Pitch = 0.0, Yaw = 359.0, Roll = 0.0}
        --     player:K2_TeleportTo(cafeteria_location, cafeteria_rotation)
        -- end)

    end)

end

local function DetermineDeathState(player)
    local player_name = player.MyPlayerState:GetPlayerName():ToString()
    local player_state = player.MyPlayerState
    local log_msg = string.format("[Handle_OnRep_IsDead]: %s, IsDead: %s, Flag: %s", player_name, player.IsDead, re_spawned_state[player_name])
    Utils.log(log_msg)

    -- Handle_OnRep_IsDead may be called again on respawn, double-check

    -- First Death, No Log Entry -> Reviving
    if re_spawned_state[player_name] == nil and player.IsDead then
        re_spawned_state[player_name] = SpawnStates.Reviving
        LogPlayerDeath(player_name)
        if PlayerHasLivesLeft(player_name) or Config.no_hardcore_perma_death then
            if player_state.IsHardcoreDead then
                RespawnFromHardcoreDeath(player, player_state)
            end
        end
    -- Death, Existing Log Entry in Session Memory -> Reviving
    elseif re_spawned_state[player_name] == SpawnStates.Alive and player.IsDead then
        LogPlayerDeath(player_name)
        re_spawned_state[player_name] = SpawnStates.Reviving
        if PlayerHasLivesLeft(player_name) or Config.no_hardcore_perma_death then
            if player_state.IsHardcoreDead then
                RespawnFromHardcoreDeath(player, player_state)
            end
        end
    -- Reviving -> Reviving (No change)
    elseif player.IsDead and re_spawned_state[player_name] == SpawnStates.Reviving then
        -- Re-Entrance, do not increment
        -- [TODO]: Understand why this is needed
        -- Without: Bounces between IsDead True/False, even using ExecuteInGameThread??
        -- [2026-10-25 01:46:48.0092247] [Lua] [Handle_OnRep_IsDead]: SpDoggy, IsDead: true, Flag: nil[2026-10-25 01:46:48.0092247] [Lua] 
        -- [2026-10-25 01:46:48.0412250] [Lua] [Handle_OnRep_IsDead]: SpDoggy, IsDead: false, Flag: Reviving[2026-10-25 01:46:48.0422250] [Lua] 
        -- [2026-10-25 01:46:48.0442250] [Lua] [Handle_OnRep_IsDead]: SpDoggy, IsDead: true, Flag: nil[2026-10-25 01:46:48.0442250] [Lua] 
        -- [2026-10-25 01:46:48.0472250] [Lua] [Handle_OnRep_IsDead]: SpDoggy, IsDead: false, Flag: Reviving[2026-10-25 01:46:48.0472250] [Lua] 
        -- [2026-10-25 01:46:48.0492250] [Lua] [Handle_OnRep_IsDead]: SpDoggy, IsDead: true, Flag: nil[2026-10-25 01:46:48.0492250] [Lua] 
        -- [2026-10-25 01:46:48.0752253] [Lua] [Handle_OnRep_IsDead]: SpDoggy, IsDead: false, Flag: Reviving[2026-10-25 01:46:48.0752253] [Lua] 

        -- With: Successfully revives, why? Too many cycles for the player to actually revive? Have to force it every time during this period?
        -- [2026-10-25 01:57:24.9549229] [Lua] [Handle_OnRep_IsDead]: SpDoggy, IsDead: true, Flag: nil[2026-10-25 01:57:24.9549229] [Lua] 
        -- [2026-10-25 01:57:25.0219235] [Lua] [Handle_OnRep_IsDead]: SpDoggy, IsDead: true, Flag: Reviving[2026-10-25 01:57:25.0219235] [Lua] 
        -- [2026-10-25 01:57:25.0219235] [Lua] [Handle_OnRep_IsDead]: SpDoggy, IsDead: true, Flag: Reviving[2026-10-25 01:57:25.0219235] [Lua] 
        -- [2026-10-25 01:57:25.0219235] [Lua] [Handle_OnRep_IsDead]: SpDoggy, IsDead: true, Flag: Reviving[2026-10-25 01:57:25.0219235] [Lua] 
        -- [2026-10-25 01:57:25.0219235] [Lua] [Handle_OnRep_IsDead]: SpDoggy, IsDead: true, Flag: Reviving[2026-10-25 01:57:25.0219235] [Lua] 
        -- [2026-10-25 01:57:25.0879241] [Lua] [Handle_OnRep_IsDead]: SpDoggy, IsDead: false, Flag: Reviving[2026-10-25 01:57:25.0879241] [Lua] 
        -- [2026-10-25 01:57:40.0920580] [Lua] [Handle_OnRep_IsDead]: Lockout Expired: SpDoggy, IsDead: false, Flag: Alive[2026-10-25 01:57:40.0920580] [Lua] 
        if PlayerHasLivesLeft(player_name) or Config.no_hardcore_perma_death then
            if player_state.IsHardcoreDead then
                RespawnFromHardcoreDeath(player, player_state)
            end
        end
    -- Reviving -> Alive
    elseif not player.IsDead and re_spawned_state[player_name] == SpawnStates.Reviving then
        re_spawned_state[player_name] = SpawnStates.Amnesia
        DisplayPlayerLivesRemaining(player_name)
        if not PlayerHasLivesLeft(player_name) then
            ExecuteWithDelay(5000, function()
                PlayerApplyAmnesia(player_name)
            end)
            ExecuteWithDelay(10000, function()
                ResetPlayerLives(player_name)
                DisplayPlayerLivesRemaining(player_name)
            end)
        else
            DisplayPlayerLivesRemaining(player_name)
        end

        -- Lockout delay before processing further Handle_OnRep_IsDead hooks 
        ExecuteWithDelay(15000, function()
            re_spawned_state[player_name] = SpawnStates.Alive
            local log_msg = string.format("[Handle_OnRep_IsDead]: Lockout Expired: %s, IsDead: %s, Flag: %s", player_name, player.IsDead, re_spawned_state[player_name])
            Utils.log(log_msg)
        end)

    elseif player.IsDead then
        Utils.error("[Handle_OnRep_IsDead]:Invalid State Machine")
    end
end

local function Handle_OnRep_IsDead(context)
    local player = context:Get()
    local world = Utils.GetWorld()
    if Utils.IsValid(player) and Utils.IsValid(player.MyPlayerState) then
        ExecuteInGameThread(function()
            DetermineDeathState(player)
        end)
    end
end

ExecuteInGameThread(function()
    Utils.log("Initializing Hardcore-Modifiers hooks")


    ExecuteWithDelay(2500, function()
    local okHook, errHook = pcall(RegisterHook,
        "Function /Game/Blueprints/Characters/Abiotic_Character_ParentBP.Abiotic_Character_ParentBP_C:OnRep_IsDead",
        Handle_OnRep_IsDead
    )
        if not okHook then
            print("Hook registration failed: %s", tostring(errHook))
        else
            print("Hook registration success: Handle_Server_ApplyBuff")
        end
    end)

    Utils.log("Hardcore-Modifiers Hooks initialized")
end)


if ToggleKey and ToggleKeyModifiers then
    local function SetModState(Enable)
        ExecuteInGameThread(function()

            -- test stuff here
            local world = Utils.GetWorld()

        end)
    end

    RegisterKeyBind(ToggleKey, ToggleKeyModifiers, function()
        SetModState(not ModEnabled)
    end)
end

Utils.log("Mod loaded successfully")
