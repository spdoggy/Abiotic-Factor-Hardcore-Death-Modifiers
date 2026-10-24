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

Utils.log("Starting Hardcore-Modifiers mod initialization")


local function IsPlayerInDeathLog(player_name)
    local temp_log = require("../death_note")
    for key, value in pairs(temp_log) do
        if player_name == key then
            return true
        end
    end
    return false
end

local function WriteDeathNote(death_table)
    local death_notes,err = io.open("./ue4ss/Mods/death_note.lua","w")
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

local function LogPlayerDeath(player_name)
    local death_note = require("../death_note")
    if IsPlayerInDeathLog(player_name) then
        death_note[player_name] = death_note[player_name] + 1
    else
        death_note[player_name] = 1
    end
    WriteDeathNote(death_note)
end

local function ResetPlayerLives(player_name)
    local death_note = require("../death_note")
    death_note[player_name] = 0
    WriteDeathNote(death_note)
end

local function GetNumPlayerDeaths(player_name)
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
        local msg = string.format("Player %s: %d extra lives left!", player_name, lives_remaining)
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
        for i = 1, 16, 1 do
            player_prog:Server_AddXPToSkill(i, 940, true, success)
        end
    end
end

local function PlayerSetSkillDebug(player_name)
    local player = Utils.GetPlayerFromName(player_name)
    local player_prog = player.CharacterProgressionComponent
    if Utils.IsValid(player) and Utils.IsValid(player_prog) then
        local amnesia_threshold = true
        player_prog:Request_ResetAllSkills(amnesia_threshold)
        local success = {}
        for i = 1, 16, 1 do
            player_prog:Server_AddXPToSkill(i, 94000, true, success)
        end
    end
end

local function RespawnFromHardcoreDeath(player, player_state)

    -- TODO: Make this detect and work in Hardcore mode.
    -- player_state:AdminReviveFromHardcoreDeath()
    local success = {}

    -- void AdminReviveFromHardcoreDeath();
    ExecuteWithDelay(1000, function()
        --player:RespawnPlayerCharacter(false, false, FName("sector_office"), success)
        player:AdminReviveFromHardcoreDeath()
    end)

    ExecuteWithDelay(1100, function()
        local cafeteria_location = {X = -15314, Y = 12532, Z = 128}
        local cafeteria_rotation = {Pitch = 0.0, Yaw = 359.0, Roll = 0.0}
        --player:TeleportPlayer(cafeteria_location, cafeteria_rotation, true, false, false, false)
        player:K2_TeleportTo(cafeteria_location, cafeteria_rotation)
    end)
end


local function Handle_OnRep_IsDead(context)
    local player = context:Get()
    local world = Utils.GetWorld()
    if Utils.IsValid(player) and Utils.IsValid(player.MyPlayerState) then
        local player_name = player.MyPlayerState:GetPlayerName():ToString()
        local player_state = player.MyPlayerState
        
        -- Handle_OnRep_IsDead may be called again on respawn, double-check
        if player.IsDead then
            LogPlayerDeath(player_name)
            if PlayerHasLivesLeft(player_name) then
                if player_state.IsHardcoreDead then
                    player_state.IsHardcoreDead = false
                    RespawnFromHardcoreDeath(player, player_state)
                else
                    ResetPlayerLives(player_name)
                end
            end
        else
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
        end
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
            --DisplayPlayerLivesRemaining("SpDoggy")
            local player_name = "SpDoggy"
            -- PlayerSetSkillDebug(player_name)
            local player = Utils.GetPlayerFromName(player_name)
            local player_state = player.MyPlayerState

            -- local is_hardcore_dead = player_state.IsHardcoreDead
            -- print("IsHardcoreDead")
            -- print(player_state.IsHardcoreDead)
            
            if player_state.IsHardcoreDead then
                -- TODO: Make this detect and work in Hardcore mode.
                -- player_state:AdminReviveFromHardcoreDeath()
                local success = {}

                -- -- void AdminReviveFromHardcoreDeath();
                -- player:RespawnPlayerCharacter(false, false, FName("sector_office"), success);

                -- local cafeteria_location = {X = -15314, Y = 12532, Z = 128}
                -- local cafeteria_rotation = {Pitch = 0.0, Yaw = 359.0, Roll = 0.0}
                -- --player:TeleportPlayer(cafeteria_location, cafeteria_rotation, true, false, false, false)
                -- player:K2_TeleportTo(cafeteria_location, cafeteria_rotation)
            end
        end)
    end

    RegisterKeyBind(ToggleKey, ToggleKeyModifiers, function()
        SetModState(not ModEnabled)
    end)
end

Utils.log("Mod loaded successfully")
