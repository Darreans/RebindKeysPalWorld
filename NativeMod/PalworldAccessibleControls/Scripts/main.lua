local MOD_NAME = "PalworldAccessibleControls"
local LOG_PREFIX = "[Palworld Accessible Controls]"
local CONFIG_PATH = "ue4ss/Mods/" .. MOD_NAME .. "/config.ini"
local FORCE_WEAPON_RESET_PATH = "ue4ss/Mods/" .. MOD_NAME .. "/force-weapon-reset-once.flag"
local SELF_TEST_PATH = "ue4ss/Mods/" .. MOD_NAME .. "/dev-selftest.flag"
local AIM_HOLD_FLAG = FName("PalworldAccessibleControls")
local RIGHT_MOUSE_KEY = { KeyName = FName("RightMouseButton") }
local RESTORE_DIALOG_CLASS = "/Script/Pal.PalDialogParameterDialog"
local PAL_UTILITY_DEFAULT = "/Script/Pal.Default__PalUtility"
local RESTORE_DIALOG_LEFT = "/Game/Pal/Blueprint/UI/Dialog/WBP_PalDialog.WBP_PalDialog_C:"
    .. "BndEvt__WBP_PalDialog_WBP_CommonPopupWindow_K2Node_ComponentBoundEvent_2_"
    .. "OnClickedLeftButton__DelegateSignature"
local RESTORE_DIALOG_RIGHT = "/Game/Pal/Blueprint/UI/Dialog/WBP_PalDialog.WBP_PalDialog_C:"
    .. "BndEvt__WBP_PalDialog_WBP_CommonPopupWindow_K2Node_ComponentBoundEvent_3_"
    .. "OnClickedRightButton__DelegateSignature"
local RESTORE_DIALOG_CANCEL = "/Game/Pal/Blueprint/UI/Dialog/WBP_PalDialog.WBP_PalDialog_C:OnCancelAction"
local APPLICATION_FOCUS_HOOK = "/Script/Pal.PalHUDInGame:OnApplicationActivationStateChanged"

local ASSETS = {
    "/Game/Pal/Blueprint/PlayerInput/BP_PalPlayerInput",
    "/Game/Pal/Blueprint/UI/UserInterface/MainMenu/Option/WBP_Key_Settings",
    "/Game/Pal/Blueprint/UI/UserInterface/MainMenu/Option/WBP_Control_Settings",
    "/Game/Pal/Blueprint/UI/UserInterface/MainMenu/Option/WBP_OptionSettings",
    "/Game/Pal/Blueprint/UI/UserInterface/MainMenu/Option/WBP_OptionSettings_ListContent",
    "/Game/Pal/Blueprint/UI/UserInterface/MainMenu/Option/WBP_OptionSettings_ListContentSwitch",
    "/Game/Pal/Blueprint/UI/CommonWidget/ActionWidget/WBP_PlayerInputKeyGuideIcon",
    "/Game/Pal/Blueprint/UI/Dialog/WBP_PalDialog",
}

local PATHS = {
    player_input_class = "/Game/Pal/Blueprint/PlayerInput/BP_PalPlayerInput.BP_PalPlayerInput_C",
    player_input_default = "/Game/Pal/Blueprint/PlayerInput/BP_PalPlayerInput.Default__BP_PalPlayerInput_C",
    key_settings_class = "/Game/Pal/Blueprint/UI/UserInterface/MainMenu/Option/WBP_Key_Settings.WBP_Key_Settings_C",
    control_settings_class = "/Game/Pal/Blueprint/UI/UserInterface/MainMenu/Option/WBP_Control_Settings.WBP_Control_Settings_C",
    option_settings_class = "/Game/Pal/Blueprint/UI/UserInterface/MainMenu/Option/WBP_OptionSettings.WBP_OptionSettings_C",
    weapon_hud_icon_class = "/Game/Pal/Blueprint/UI/CommonWidget/ActionWidget/WBP_PlayerInputKeyGuideIcon.WBP_PlayerInputKeyGuideIcon_C",
    row_class = "/Game/Pal/Blueprint/UI/UserInterface/MainMenu/Option/WBP_OptionSettings_ListContent.WBP_OptionSettings_ListContent_C",
    row_default = "/Game/Pal/Blueprint/UI/UserInterface/MainMenu/Option/WBP_OptionSettings_ListContent.Default__WBP_OptionSettings_ListContent_C",
    dialog_class = "/Game/Pal/Blueprint/UI/Dialog/WBP_PalDialog.WBP_PalDialog_C",
}

local EXTRA_BINDABLE_KEYS = {
    "Tilde",
    "Enter",
    "BackSpace",
    "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12",
    "F13", "F14", "F15", "F16", "F17", "F18", "F19", "F20", "F21", "F22", "F23", "F24",
    "LeftMouseButton",
    "RightMouseButton",
    "MouseScrollUp",
    "MouseScrollDown",
    "Pause",
    "NumLock",
    "ScrollLock",
    "PrintScreen",
}

local KEY_ROWS = {
    { map = "InputActionsMap_KM", action = "ChangeWeaponPrev", label = "Change Weapon Up", configure_input = true },
    { map = "InputActionsMap_KM", action = "ChangeWeaponNext", label = "Change Weapon Down", configure_input = true },
    { map = "UIActionsMap_KM", action = "BuildRotateLeft", label = "Rotate Building Left" },
    { map = "UIActionsMap_KM", action = "BuildRotateRight", label = "Rotate Building Right" },
}

local DEFAULT_WEAPON_WHEEL_BINDINGS = {
    { action = "ChangeWeaponPrev", key = "MouseScrollUp" },
    { action = "ChangeWeaponNext", key = "MouseScrollDown" },
}
local UNBOUND_WEAPON_KEY = "None"

local PALWORLD_KEY_OVERRIDES_TO_REMOVE = {
    MouseAndKeyboardActionMappings = {
        ChangeWeaponPrev = true,
        ChangeWeaponNext = true,
    },
    MouseAndKeyboardUIInputMappings = {
        Legacy_DT_UIInputAction_BuildRotateLeft = true,
        Legacy_DT_UIInputAction_BuildRotateRight = true,
    },
}

local config = {
    toggle_ads = false,
    ads_default_off_applied = false,
    weapon_prev_key = "",
    weapon_next_key = "",
}

local control_rows = {}
local toggle_switches = {}
local key_settings_widgets = {}
local option_settings_widgets = {}
local option_footer_errors = {}
local key_row_owners = {}
local mod_binding_rows = {}
local backtick_keycaps = {}
local aim_states = {}
local aim_guard = {}
local assets_ready = false
local asset_load_attempts = 0
local self_test_scheduled = false
local logged_bindable_key_patch = false
local hud_icon_notification_registered = false
local ui_function_hooks_registered = false
local dialog_function_hooks_registered = false
local pending_weapon_binding = nil
local pending_restore_dialog = nil
local pending_unverified_rmb = nil
local unverified_rmb_id = 0
local application_focus_state = nil
local tilde_capture_in_progress = nil
local wheel_capture_state = nil
local aim_input_generation = 0
local AIM_DUPLICATE_RAW_WINDOW_SECONDS = 0.12
local AIM_INITIAL_RELEASE_TIMEOUT_SECONDS = 0.15
local AIM_INPUT_STATE_ERROR_TIMEOUT_SECONDS = 1.0
local AIM_UNVERIFIED_RMB_GRACE_SECONDS = 0.15
local AIM_UNVERIFIED_CLEANUP_INTERVAL_SECONDS = 0.05
local AIM_SESSION_WARMUP_SECONDS = 1.5
local aim_ready_after = os.clock() + AIM_SESSION_WARMUP_SECONDS
local last_aim_input_at = -1000
local last_aim_guard_log_at = -1000
local settings_adoption_poll_ticks = 0

local function log(message)
    print(string.format("%s %s\n", LOG_PREFIX, message))
end

local function is_valid(object)
    if object == nil then
        return false
    end

    local ok, result = pcall(function()
        return object:IsValid()
    end)
    return ok and result == true
end

local function unwrap(parameter)
    if parameter == nil then
        return nil
    end

    local ok, object = pcall(function()
        return parameter:get()
    end)
    if ok then
        return object
    end
    return parameter
end

local function read_switch_state(switch)
    if not is_valid(switch) then
        return nil
    end

    -- IsOn is a Blueprint function whose bool is exposed as an output
    -- parameter. UE4SS does not consistently return that output as a normal
    -- Lua boolean, so read the widget's backing property first.
    local ok, value = pcall(function()
        return switch:GetPropertyValue("CurrentIsOn")
    end)
    if ok then
        value = unwrap(value)
        if type(value) == "boolean" then
            return value
        end
    end

    ok, value = pcall(function()
        return switch:IsOn()
    end)
    if ok then
        value = unwrap(value)
        if type(value) == "boolean" then
            return value
        end
    end

    return nil
end

local function class_name(object)
    if not is_valid(object) then
        return ""
    end

    local ok, name = pcall(function()
        return object:GetClass():GetFName():ToString()
    end)
    return ok and name or ""
end

local function file_exists(path)
    local file = io.open(path, "rb")
    if file == nil then
        return false
    end
    file:close()
    return true
end

local function parse_boolean(value)
    local normalized = string.lower((value or ""):gsub("%s+", ""))
    return normalized == "true" or normalized == "1" or normalized == "on" or normalized == "yes"
end

local function trim(value)
    return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function load_config()
    local file = io.open(CONFIG_PATH, "r")
    if file == nil then
        log("No config.ini found; Toggle Aim (ADS) starts off")
        return
    end

    for line in file:lines() do
        local key, value = line:match("^%s*([%w_]+)%s*=%s*([^;#]+)")
        if key ~= nil then
            key = string.lower(key)
            if key == "toggle_ads" then
                config.toggle_ads = parse_boolean(value)
            elseif key == "ads_default_off_applied" then
                config.ads_default_off_applied = parse_boolean(value)
            elseif key == "weapon_prev_key" then
                config.weapon_prev_key = trim(value)
            elseif key == "weapon_next_key" then
                config.weapon_next_key = trim(value)
            end
        end
    end
    file:close()
    log(string.format("Loaded config: toggle_ads=%s", tostring(config.toggle_ads)))
end

local function save_config()
    local file, error_message = io.open(CONFIG_PATH, "w")
    if file == nil then
        log("Could not save config.ini: " .. tostring(error_message))
        return false
    end

    file:write("; Palworld Accessible Controls\n")
    file:write("; This value is also controlled by the in-game Control Settings switch.\n")
    file:write("toggle_ads=" .. tostring(config.toggle_ads) .. "\n")
    file:write("; One-time safety migration: existing installs start with Toggle Aim off after this update.\n")
    file:write("ads_default_off_applied=" .. tostring(config.ads_default_off_applied) .. "\n")
    file:write("; Last accepted weapon-row overrides, used to keep input and the HUD in sync.\n")
    file:write("; Leave blank to use MouseScrollUp/MouseScrollDown.\n")
    file:write("weapon_prev_key=" .. config.weapon_prev_key .. "\n")
    file:write("weapon_next_key=" .. config.weapon_next_key .. "\n")
    file:close()
    return true
end

local function consume_forced_weapon_reset()
    local marker = io.open(FORCE_WEAPON_RESET_PATH, "r")
    if marker == nil then
        return false
    end
    marker:close()
    config.weapon_prev_key = ""
    config.weapon_next_key = ""
    save_config()
    os.remove(FORCE_WEAPON_RESET_PATH)
    log("Consumed the one-time weapon reset repair and cleared both saved custom keys")
    return true
end

local function get_saved_weapon_key(action_name)
    if action_name == "ChangeWeaponPrev" then
        return config.weapon_prev_key
    elseif action_name == "ChangeWeaponNext" then
        return config.weapon_next_key
    end
    return ""
end

local function get_default_weapon_key(action_name)
    for _, definition in ipairs(DEFAULT_WEAPON_WHEEL_BINDINGS) do
        if definition.action == action_name then
            return definition.key
        end
    end
    return ""
end

local function set_saved_weapon_key(action_name, key_name)
    local field = nil
    if action_name == "ChangeWeaponPrev" then
        field = "weapon_prev_key"
    elseif action_name == "ChangeWeaponNext" then
        field = "weapon_next_key"
    end
    if field == nil or config[field] == key_name then
        return
    end
    config[field] = key_name
    save_config()
end

local function force_rebuild_player_input_maps(input_settings)
    input_settings = input_settings
        or StaticFindObject("/Script/Engine.Default__InputSettings")
    if not is_valid(input_settings) then
        return false, "Unreal input settings are unavailable"
    end
    -- UPlayerInput:ForceRebuildingKeyMaps is not reflected in this shipping
    -- build, so a Lua call to it silently fails. UInputSettings exposes the
    -- Blueprint-callable rebuild that actually pushes the changed defaults to
    -- every live PlayerInput cache.
    return pcall(function()
        input_settings:ForceRebuildKeymaps()
    end)
end

local function update_live_palworld_action_mapping(action_name, key_name)
    local ok, inputs = pcall(function()
        return FindAllOf("BP_PalPlayerInput_C")
    end)
    if not ok or inputs == nil then
        return 0, ok and nil or inputs
    end

    local updated = 0
    local last_error = nil
    for _, player_input in pairs(inputs) do
        if is_valid(player_input) then
            local update_ok, update_result = pcall(function()
                return player_input:UpdateActionMapping(
                    FName(action_name),
                    {
                        MainKey = { KeyName = FName(key_name) },
                        SecondaryKey = { KeyName = FName("None") },
                    },
                    0
                )
            end)
            if update_ok and update_result ~= false then
                updated = updated + 1
            else
                last_error = update_ok and "Palworld rejected the mapping" or update_result
            end
        end
    end
    return updated, last_error
end

local function collect_action_mappings(input_settings, action_name, only_key_name)
    local removals = {}
    local mappings = input_settings:GetPropertyValue("ActionMappings")
    for index = 1, #mappings do
        local mapping = mappings[index]
        local mapping_action = mapping.ActionName:ToString()
        local mapping_key = mapping.Key.KeyName:ToString()
        if mapping_action == action_name and (only_key_name == nil or mapping_key == only_key_name) then
            removals[#removals + 1] = {
                ActionName = FName(action_name),
                Key = { KeyName = FName(mapping_key) },
                bShift = mapping.bShift == true,
                bCtrl = mapping.bCtrl == true,
                bAlt = mapping.bAlt == true,
                bCmd = mapping.bCmd == true,
            }
        end
    end
    return removals
end

local function remove_engine_action_mapping(action_name, key_name)
    local input_settings = StaticFindObject("/Script/Engine.Default__InputSettings")
    if not is_valid(input_settings) then
        return false, "Unreal input settings are unavailable"
    end

    local ok, removed_or_error = pcall(function()
        local removals = collect_action_mappings(input_settings, action_name, key_name)
        for _, mapping in ipairs(removals) do
            input_settings:RemoveActionMapping(mapping, false)
        end
        if #removals > 0 then
            input_settings:SaveKeyMappings()
            local rebuild_ok, rebuild_error = force_rebuild_player_input_maps(input_settings)
            if not rebuild_ok then
                error("Could not rebuild live input maps: " .. tostring(rebuild_error))
            end
        end
        return #removals
    end)
    return ok, removed_or_error
end

local function replace_engine_action_mapping(action_name, key_name)
    local input_settings = StaticFindObject("/Script/Engine.Default__InputSettings")
    if not is_valid(input_settings) then
        return false, "Unreal input settings are unavailable"
    end

    local ok, result_or_error = pcall(function()
        local removals = collect_action_mappings(input_settings, action_name, nil)
        for _, mapping in ipairs(removals) do
            input_settings:RemoveActionMapping(mapping, false)
        end
        input_settings:AddActionMapping({
            ActionName = FName(action_name),
            Key = { KeyName = FName(key_name) },
            bShift = false,
            bCtrl = false,
            bAlt = false,
            bCmd = false,
        }, false)
        input_settings:SaveKeyMappings()
        local rebuild_ok, rebuild_error = force_rebuild_player_input_maps(input_settings)
        if not rebuild_ok then
            error("Could not rebuild live input maps: " .. tostring(rebuild_error))
        end
        local _, live_error = update_live_palworld_action_mapping(action_name, key_name)
        if live_error ~= nil then
            log(string.format(
                "Could not update Palworld's live %s mapping to %s: %s",
                action_name,
                key_name,
                tostring(live_error)
            ))
        end
        return #removals
    end)
    return ok, result_or_error
end

local function restore_palworld_persistent_key_defaults(key_settings)
    if not is_valid(key_settings) then
        return false, "Palworld's live key-settings widget is unavailable"
    end
    local ok, result_or_error = pcall(function()
        local settings = unwrap(key_settings:GetPropertyValue("KeyConfigSettingsCache"))
        if settings == nil then
            error("Palworld did not provide its native key-settings cache")
        end

        local removed = 0
        for field_name, targets in pairs(PALWORLD_KEY_OVERRIDES_TO_REMOVE) do
            local map = settings[field_name]
            if map ~= nil then
                -- Mutate Palworld's native remote TMaps in place. Passing a
                -- reconstructed local map through SetKeyConfigSettings can
                -- crash this UE4SS build while marshalling FName keys.
                for key_name, _ in pairs(targets) do
                    local map_key = FName(key_name)
                    if map:Contains(map_key) then
                        map:Remove(map_key)
                        removed = removed + 1
                    end
                end
            end
        end

        key_settings:SetPropertyValue("SomethingChanged", true)
        key_settings:ApplySettings()
        return removed
    end)
    return ok, result_or_error
end

local function remove_persistent_weapon_key_entries(key_settings)
    if not is_valid(key_settings) then
        return false, "Palworld's live key-settings widget is unavailable"
    end
    local ok, result_or_error = pcall(function()
        local settings = unwrap(key_settings:GetPropertyValue("KeyConfigSettingsCache"))
        if settings == nil then
            error("Palworld did not provide its native key-settings cache")
        end
        local map = settings.MouseAndKeyboardActionMappings
        local removed = 0
        for _, definition in ipairs(DEFAULT_WEAPON_WHEEL_BINDINGS) do
            local map_key = FName(definition.action)
            if map ~= nil and map:Contains(map_key) then
                -- A blank mod config is authoritative: the user has requested
                -- defaults, so no Palworld user override may survive for these
                -- injected actions. Keeping an entry here either resurrects an
                -- old custom key or makes wheel/build duplicates block Back.
                map:Remove(map_key)
                removed = removed + 1
            end
        end
        if removed > 0 then
            key_settings:SetPropertyValue("SomethingChanged", true)
            key_settings:ApplySettings()
        end
        return removed
    end)
    return ok, result_or_error
end

local function initialize_saved_weapon_bindings()
    for _, definition in ipairs({
        { action = "ChangeWeaponPrev", key = config.weapon_prev_key },
        { action = "ChangeWeaponNext", key = config.weapon_next_key },
    }) do
        local effective_key = definition.key
        if effective_key == "" then
            effective_key = get_default_weapon_key(definition.action)
        end

        if effective_key == UNBOUND_WEAPON_KEY then
            local ok, result = remove_engine_action_mapping(definition.action, nil)
            if ok then
                log(string.format("Restored unbound weapon action %s", definition.action))
            else
                log(string.format("Could not restore unbound weapon action %s: %s", definition.action, tostring(result)))
            end
        elseif effective_key == "Tilde" then
            -- Tilde is reserved by Unreal before normal action mappings run.
            -- Remove ordinary mappings for this action; the UE4SS physical-key
            -- callback below dispatches Palworld's real weapon handler alone.
            local ok, result = remove_engine_action_mapping(definition.action, nil)
            if not ok then
                log(string.format("Could not clean the old %s Tilde mapping: %s", definition.action, tostring(result)))
            end
            log(string.format("Restored direct backtick shortcut %s = Tilde", definition.action))
        elseif effective_key ~= "" then
            -- Normalize every saved override into Unreal's live action map. A
            -- blank config value intentionally restores the wheel default.
            local ok, result = replace_engine_action_mapping(definition.action, effective_key)
            if ok then
                local opposite_action = definition.action == "ChangeWeaponPrev"
                    and "ChangeWeaponNext"
                    or "ChangeWeaponPrev"
                remove_engine_action_mapping(opposite_action, effective_key)
                log(string.format("Restored weapon binding %s = %s", definition.action, effective_key))
            else
                log(string.format("Could not restore weapon binding %s = %s: %s", definition.action, effective_key, tostring(result)))
            end
        end
    end
end

local function set_row_label(row, text)
    if not is_valid(row) then
        return false
    end

    local ok, error_message = pcall(function()
        local label = row.BP_PalTextBlock_Name
        if not is_valid(label) then
            error("label widget is unavailable")
        end
        label:SetText(FText(text))
    end)

    if not ok then
        log(string.format("Could not set row label '%s': %s", text, tostring(error_message)))
    end
    return ok
end

local function get_accessibility_keycap_text(key_name)
    if key_name == "Tilde" then
        return "`", 28
    end
    return nil, nil
end

local function set_accessibility_keycap(row, key_name)
    if not is_valid(row) then
        return false
    end

    local display_text, font_size = get_accessibility_keycap_text(key_name)
    local address = row:GetAddress()
    local existing = backtick_keycaps[address]
    if display_text == nil then
        if existing ~= nil and is_valid(existing.text) then
            pcall(function() existing.text:RemoveFromParent() end)
        end
        backtick_keycaps[address] = nil
        return true
    end

    if existing ~= nil and is_valid(existing.text) then
        pcall(function()
            existing.text:SetText(FText(display_text))
            local font = unwrap(existing.text:GetFont())
            font.Size = font_size
            existing.text:SetFont(font)
            -- HitTestInvisible keeps the whole native key box clickable.
            existing.text:SetVisibility(3)
        end)
        return true
    end

    local ok, result_or_error = pcall(function()
        local key_box = unwrap(row.WBP_OptionSettings_ListContentButton)
        local image = is_valid(key_box) and unwrap(key_box.Image_Key) or nil
        local parent = is_valid(image) and unwrap(image:GetParent()) or nil
        local widget_tree = is_valid(key_box) and unwrap(key_box:GetPropertyValue("WidgetTree")) or nil
        local text_class = StaticFindObject("/Script/UMG.TextBlock")
        if not is_valid(key_box) or not is_valid(parent) or not is_valid(widget_tree) or not is_valid(text_class) then
            error("the native key-box widgets are unavailable")
        end

        local text = StaticConstructObject(text_class, widget_tree, FName("PAC_AccessibilityKeycap"))
        if not is_valid(text) then
            error("could not construct the accessibility TextBlock")
        end
        text:SetText(FText(display_text))
        text:SetJustification(1)
        pcall(function()
            local font = unwrap(text:GetFont())
            font.Size = font_size
            text:SetFont(font)
        end)

        local slot = unwrap(parent:AddChild(text))
        if not is_valid(slot) then
            error("could not place the backtick TextBlock in the key box")
        end
        local slot_class = slot:GetClass():GetFName():ToString()
        if slot_class == "CanvasPanelSlot" then
            slot:SetAnchors({ Minimum = { X = 0, Y = 0 }, Maximum = { X = 1, Y = 1 } })
            slot:SetOffsets({ Left = 0, Top = 0, Right = 0, Bottom = 0 })
            slot:SetAlignment({ X = 0.5, Y = 0.5 })
            slot:SetZOrder(20)
        elseif slot_class == "OverlaySlot" then
            slot:SetHorizontalAlignment(2)
            slot:SetVerticalAlignment(2)
        end
        -- HitTestInvisible renders the character without intercepting clicks.
        text:SetVisibility(3)
        backtick_keycaps[address] = { row = row, text = text }
        return true
    end)

    if not ok then
        log("Could not place the accessibility label inside the native key box: " .. tostring(result_or_error))
        return false
    end
    return result_or_error == true
end

local function map_find(map, key)
    local ok, value = pcall(function()
        return map:Find(FName(key))
    end)
    if ok then
        return unwrap(value)
    end
    return nil
end

local function extend_bindable_keys(player_input)
    if not is_valid(player_input) then
        return 0
    end

    local ok, added_or_error = pcall(function()
        local enabled_keys = player_input:GetPropertyValue("EnableKeys")
        local disabled_keys = player_input:GetPropertyValue("DisableKeys")
        local added = 0
        for _, key_name in ipairs(EXTRA_BINDABLE_KEYS) do
            local key = { KeyName = FName(key_name) }
            if not enabled_keys:Contains(key) then
                enabled_keys:Add(key)
                if enabled_keys:Contains(key) then
                    added = added + 1
                end
            end
            if disabled_keys:Contains(key) then
                disabled_keys:Remove(key)
            end
        end
        return added
    end)

    if not ok then
        log("Could not extend Palworld's bindable-key list: " .. tostring(added_or_error))
        return 0
    end
    return added_or_error
end

local function patch_player_input_keys()
    local default_input = StaticFindObject(PATHS.player_input_default)
    local added = extend_bindable_keys(default_input)

    local ok, inputs = pcall(function()
        return FindAllOf("BP_PalPlayerInput_C")
    end)
    if ok and inputs ~= nil then
        for _, input in pairs(inputs) do
            extend_bindable_keys(input)
        end
    end

    if not logged_bindable_key_patch and is_valid(default_input) then
        logged_bindable_key_patch = true
        log(string.format(
            "Extended Palworld's accessibility key list (%d new keys; backtick uses Tilde)",
            added
        ))
    end
end

local function on_new_player_input(player_input)
    extend_bindable_keys(player_input)
end

local function inject_key_rows(widget)
    local placeholder = StaticFindObject(PATHS.row_default)
    if not is_valid(placeholder) then
        log("The native keybind row template is unavailable")
        return 0
    end

    local prepared = 0
    for _, definition in ipairs(KEY_ROWS) do
        local ok, error_message = pcall(function()
            local map = widget[definition.map]
            local action_name = FName(definition.action)
            if not map:Contains(action_name) then
                -- Palworld's Construct event replaces this template with a real row.
                -- A typed template is used because this TMap stores widget objects.
                map:Add(action_name, placeholder)
            end
            if map:Contains(action_name) then
                prepared = prepared + 1
            end
        end)

        if not ok then
            log(string.format("Could not add '%s' to %s: %s", definition.action, definition.map, tostring(error_message)))
        end
    end
    return prepared
end

local function get_current_input_action_key(action_name)
    local saved_key = get_saved_weapon_key(action_name)
    if saved_key ~= "" then
        return { KeyName = FName(saved_key) }
    end

    local input_settings = StaticFindObject("/Script/Engine.Default__InputSettings")
    if not is_valid(input_settings) then
        return { KeyName = FName("None") }
    end

    local ok, key_or_error = pcall(function()
        local mappings = input_settings:GetPropertyValue("ActionMappings")
        for index = 1, #mappings do
            local mapping = mappings[index]
            if mapping.ActionName:ToString() == action_name then
                return { KeyName = mapping.Key.KeyName }
            end
        end
        return { KeyName = FName("None") }
    end)

    if ok then
        return key_or_error
    end
    log(string.format("Could not read the current binding for '%s': %s", action_name, tostring(key_or_error)))
    return { KeyName = FName("None") }
end

local function get_fname_property(object, property_name)
    if not is_valid(object) then return "" end
    local ok, value = pcall(function()
        return unwrap(object:GetPropertyValue(property_name))
    end)
    if not ok or value == nil then return "" end
    ok, value = pcall(function() return value:ToString() end)
    return ok and tostring(value) or ""
end

local function refresh_weapon_hud_icons()
    local ok, widgets = pcall(function()
        return FindAllOf("WBP_PlayerInputKeyGuideIcon_C")
    end)
    if not ok or widgets == nil then return 0 end

    local refreshed = 0
    for _, widget in pairs(widgets) do
        if is_valid(widget) then
            local action_name = get_fname_property(widget, "BindInputActionName")
            if action_name == "ChangeWeaponPrev" or action_name == "ChangeWeaponNext" then
                local refresh_ok = pcall(function()
                    local saved_key = get_saved_weapon_key(action_name)
                    local key = nil
                    if saved_key ~= "" then
                        key = { KeyName = FName(saved_key) }
                    else
                        key = get_current_input_action_key(action_name)
                    end
                    local key_name = key ~= nil and key.KeyName:ToString() or "None"
                    if key_name ~= "" and key_name ~= "None" then
                        local utility = StaticFindObject("/Script/Pal.Default__PalUIUtility")
                        local brush = is_valid(utility) and unwrap(utility:GetKeyIconByKey(
                            widget,
                            key,
                            0
                        )) or nil
                        if brush ~= nil then
                            -- Palworld's normal OnKeyConfigChanged path does not
                            -- repaint these HUD widgets for the two mod-added
                            -- split weapon actions. Push the accepted key brush
                            -- directly into the native widget instead.
                            widget:UpdateImage(brush)
                            return
                        end
                    end
                    widget:OnKeyConfigChanged()
                end)
                if refresh_ok then refreshed = refreshed + 1 end
            end
        end
    end
    return refreshed
end

local function schedule_weapon_hud_refresh(delay_ms)
    ExecuteInGameThreadWithDelay(delay_ms or 0, function()
        local refreshed = refresh_weapon_hud_icons()
        if refreshed > 0 then
            log(string.format("Refreshed %d in-game weapon binding icon%s", refreshed, refreshed == 1 and "" or "s"))
        end
    end)
end

local function on_new_weapon_hud_icon(widget)
    -- BindInputActionName is assigned during the widget's Construct path. Wait
    -- until that finishes, then repaint newly rebuilt weapon prompts from the
    -- saved override (or the mod's explicit wheel default).
    ExecuteInGameThreadWithDelay(100, function()
        if is_valid(widget) then
            refresh_weapon_hud_icons()
        end
    end)
end

local function finish_key_rows(widget, should_log)
    local completed = 0
    local placeholder = StaticFindObject(PATHS.row_default)
    for _, definition in ipairs(KEY_ROWS) do
        local map = widget[definition.map]
        local row = map_find(map, definition.action)
        if is_valid(row) and (not is_valid(placeholder) or row:GetAddress() ~= placeholder:GetAddress()) then
            local configured = true
            local current_key = nil
            if definition.configure_input then
                local configure_ok, configure_error = pcall(function()
                    -- Palworld does not activate the key-capture button when an
                    -- action has no mapping. Put the row into the same native
                    -- config-button mode used by its built-in keyboard rows,
                    -- then explicitly render the current key (or None).
                    current_key = get_current_input_action_key(definition.action)
                    row:SetConfigButton(FName(definition.action), 0, 0)
                    row:SetKeyIcon(current_key, 0)
                end)
                configured = configure_ok
                if not configure_ok and should_log then
                    log(string.format("Could not activate '%s' as a key-capture row: %s", definition.action, tostring(configure_error)))
                end
            end

            local display_label = definition.label
            if current_key ~= nil then
                local key_ok, key_name = pcall(function() return current_key.KeyName:ToString() end)
                if key_ok then
                    -- Palworld has no dependable texture feedback for these
                    -- accessibility keys, so render centered click-through text.
                    set_accessibility_keycap(row, key_name)
                end
            end

            if configured and set_row_label(row, display_label) then
                mod_binding_rows[row:GetAddress()] = {
                    row = row,
                    action = definition.action,
                }
                if definition.configure_input then
                    key_row_owners[row:GetAddress()] = {
                        owner = widget,
                        row = row,
                        action = definition.action,
                        opening = false,
                    }
                end
                if configured then
                    completed = completed + 1
                end
            end
        end
    end

    if should_log then
        log(string.format("Added %d/4 native keybind rows", completed))
    end
    return completed
end

local function default_wheel_reset_active()
    return config.weapon_prev_key == "" and config.weapon_next_key == ""
end

local function cleanup_persistent_weapon_key_entries()
    if not default_wheel_reset_active() then
        return
    end
    local ok, widgets = pcall(function()
        return FindAllOf("WBP_Key_Settings_C")
    end)
    if not ok or widgets == nil then
        return
    end
    for _, widget in pairs(widgets) do
        if is_valid(widget) then
            local cleanup_ok, removed_or_error = remove_persistent_weapon_key_entries(widget)
            if cleanup_ok and removed_or_error > 0 then
                log(string.format(
                    "Removed %d persisted weapon entr%s so Palworld can close Settings without restoring an old or duplicate key",
                    removed_or_error,
                    removed_or_error == 1 and "y" or "ies"
                ))
            elseif not cleanup_ok then
                log("Could not clear the persisted duplicate-wheel state: " .. tostring(removed_or_error))
            end
        end
    end
end

local function clear_mod_row_warning(row)
    if not is_valid(row) then
        return
    end
    pcall(function()
        local key_box = unwrap(row.WBP_OptionSettings_ListContentButton)
        if is_valid(key_box) then
            key_box:EnableWarning(false)
        end
    end)
end

local function clear_default_wheel_warnings()
    if not default_wheel_reset_active() then
        return
    end
    for address, state in pairs(mod_binding_rows) do
        if state ~= nil and is_valid(state.row) then
            clear_mod_row_warning(state.row)
        else
            mod_binding_rows[address] = nil
        end
    end
end

local function on_mod_key_warning_updated(context)
    if not default_wheel_reset_active() then
        return
    end
    local row = unwrap(context)
    if not is_valid(row) or mod_binding_rows[row:GetAddress()] == nil then
        return
    end
    -- Key Conflict Check only paints this warning; it does not reject the
    -- mapping. The weapon/build wheel overlap is intentional in the reset
    -- state, so clear the warning on our four rows without touching any other
    -- Palworld conflict warning.
    ExecuteInGameThreadWithDelay(0, function()
        if default_wheel_reset_active() and is_valid(row) then
            clear_mod_row_warning(row)
        end
    end)
end

local function update_mod_defaults_footer_visibility(state)
    if state == nil or not is_valid(state.owner) then
        return false
    end

    local visible = false
    pcall(function()
        local key_settings = unwrap(state.owner.KeySettings)
        visible = is_valid(key_settings) and unwrap(key_settings:IsVisible()) == true
    end)
    state.visible = visible

    local visibility = visible and 0 or 1
    if is_valid(state.keycap) then state.keycap:SetVisibility(visibility) end
    if is_valid(state.label) then state.label:SetVisibility(visibility) end
    if visible and is_valid(state.keycap) then
        -- Palworld can refresh a key guide when the active input method changes.
        -- Ask Palworld for a fresh native F12 brush before each visible refresh,
        -- so this does not depend on a temporary widget's SlateBrush lifetime.
        pcall(function()
            local action_widget = unwrap(state.keycap.PalUIActionWidgetBase_24)
            local utility = StaticFindObject("/Script/Pal.Default__PalUIUtility")
            local key_brush = is_valid(utility) and unwrap(utility:GetKeyIconByKey(
                state.owner,
                { KeyName = FName("F12") },
                0
            )) or nil
            if key_brush == nil and is_valid(state.key_source_image) then
                key_brush = unwrap(state.key_source_image:GetPropertyValue("Brush"))
            end
            if is_valid(action_widget) and key_brush ~= nil then
                action_widget:OverrideImage(key_brush)
            end
        end)
    end
    return visible
end

local function ensure_mod_defaults_footer(widget)
    if not is_valid(widget) then
        return false
    end

    local address = widget:GetAddress()
    local existing = option_settings_widgets[address]
    if existing ~= nil and is_valid(existing.keycap) and is_valid(existing.label) then
        local still_attached = false
        pcall(function()
            local key_parent = unwrap(existing.keycap:GetParent())
            local label_parent = unwrap(existing.label:GetParent())
            still_attached = is_valid(existing.footer)
                and is_valid(key_parent)
                and is_valid(label_parent)
                and key_parent:GetAddress() == existing.footer:GetAddress()
                and label_parent:GetAddress() == existing.footer:GetAddress()
        end)
        if still_attached then
            update_mod_defaults_footer_visibility(existing)
            return true
        end
        option_settings_widgets[address] = nil
    end

    -- A previous Lua generation may have created the footer widgets before a
    -- hot reload cleared our tables. Adopt that exact pair instead of adding a
    -- second F12 action to the still-live HorizontalBox.
    local adopted = nil
    pcall(function()
        local default_guide = unwrap(widget.WBP_PalKeyGuideIcon_Default)
        local footer = is_valid(default_guide) and unwrap(default_guide:GetParent()) or nil
        if not is_valid(footer) then return end
        local child_count = unwrap(footer:GetChildrenCount())
        for index = 1, child_count - 1 do
            local label = unwrap(footer:GetChildAt(index))
            if is_valid(label) and label:GetFName():ToString() == "PAC_ModDefaultsLabel" then
                local keycap = unwrap(footer:GetChildAt(index - 1))
                if is_valid(keycap) then
                    adopted = {
                        owner = widget,
                        footer = footer,
                        keycap = keycap,
                        key_brush = nil,
                        key_source = nil,
                        key_source_image = nil,
                        label = label,
                        original_label_color = unwrap(label:GetPropertyValue("ColorAndOpacity")),
                        visible = false,
                    }
                end
                break
            end
        end
    end)
    if adopted ~= nil then
        option_footer_errors[address] = nil
        option_settings_widgets[address] = adopted
        update_mod_defaults_footer_visibility(adopted)
        log("Re-adopted the existing F12 Restore Mod Defaults footer after Lua reload")
        return true
    end

    local ok, state_or_error = pcall(function()
        local default_guide = unwrap(widget.WBP_PalKeyGuideIcon_Default)
        local default_text = unwrap(widget.BP_PalTextBlock_Default)
        local footer = is_valid(default_guide) and unwrap(default_guide:GetParent()) or nil
        local widget_tree = unwrap(widget:GetPropertyValue("WidgetTree"))
        local library = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
        local row_class = StaticFindObject(PATHS.row_class)
        if not is_valid(default_guide)
            or not is_valid(default_text)
            or not is_valid(footer)
            or footer:GetClass():GetFName():ToString() ~= "HorizontalBox"
            or not is_valid(widget_tree)
            or not is_valid(library)
            or not is_valid(row_class) then
            error("Palworld's native Options footer is not ready")
        end

        -- Create the key guide from Palworld's own footer widget class. A
        -- temporary native settings row supplies the game's F12 key brush,
        -- including the same border and typography used by its F/Esc guides.
        local player = widget:GetOwningPlayer()
        local keycap = library:Create(widget, default_guide:GetClass(), player)
        local label = StaticConstructObject(default_text:GetClass(), widget_tree, FName("PAC_ModDefaultsLabel"))
        if not is_valid(keycap) or not is_valid(label) then
            error("could not construct the mod-default footer widgets")
        end

        keycap:SetInputAction(widget.DefaultActionName)
        local key_source = nil
        local key_source_image = nil
        local key_brush = nil
        local utility = StaticFindObject("/Script/Pal.Default__PalUIUtility")
        if is_valid(utility) then
            local utility_ok, utility_brush = pcall(function()
                return unwrap(utility:GetKeyIconByKey(
                    widget,
                    { KeyName = FName("F12") },
                    0
                ))
            end)
            if utility_ok then key_brush = utility_brush end
        end
        if key_brush == nil then
            -- Compatibility fallback for builds where the utility return value
            -- is not exposed to Lua: read the same brush through a native row.
            key_source = library:Create(widget, row_class, player)
            if is_valid(key_source) then
                key_source:SetKeyIcon({ KeyName = FName("F12") }, 0)
                local key_source_button = unwrap(key_source.WBP_OptionSettings_ListContentButton)
                key_source_image = is_valid(key_source_button) and unwrap(key_source_button.Image_Key) or nil
                key_brush = is_valid(key_source_image)
                    and unwrap(key_source_image:GetPropertyValue("Brush")) or nil
            end
        end
        local action_widget = unwrap(keycap.PalUIActionWidgetBase_24)
        if key_brush == nil or not is_valid(action_widget) then
            error("Palworld did not provide its native F12 key brush")
        end
        action_widget:OverrideImage(key_brush)

        label:SetText(FText("Restore Mod Defaults"))
        -- GetFont is not exposed reliably on this Blueprint text widget, but
        -- its Font property is. Copying that property preserves Palworld's
        -- exact 14-point Medium footer type instead of UMG's 24-point Bold
        -- fallback that caused the oversized text seen in-game.
        local native_font = unwrap(default_text:GetPropertyValue("Font"))
        local native_color = unwrap(default_text:GetPropertyValue("ColorAndOpacity"))
        local native_shadow_offset = unwrap(default_text:GetPropertyValue("ShadowOffset"))
        local native_shadow_color = unwrap(default_text:GetPropertyValue("ShadowColorAndOpacity"))
        label:SetFont(native_font)
        label:SetColorAndOpacity(native_color)
        label:SetShadowOffset(native_shadow_offset)
        label:SetShadowColorAndOpacity(native_shadow_color)
        label:SetAutoWrapText(false)

        -- Keep the original flexible spacer, then rebuild only the action side
        -- as [F12 mod defaults][F game defaults][Esc back]. Snapshot every
        -- native HorizontalBox slot first so its exact padding/alignment is
        -- retained; the custom pair copies the F guide and label layouts.
        local function capture_slot_layout(child)
            local slot = unwrap(child:GetPropertyValue("Slot"))
            if not is_valid(slot) then
                error("could not read a native footer slot")
            end
            return {
                padding = unwrap(slot:GetPropertyValue("Padding")),
                horizontal_alignment = unwrap(slot:GetPropertyValue("HorizontalAlignment")),
                vertical_alignment = unwrap(slot:GetPropertyValue("VerticalAlignment")),
            }
        end

        local function apply_slot_layout(slot, layout)
            slot:SetPadding(layout.padding)
            slot:SetHorizontalAlignment(layout.horizontal_alignment)
            slot:SetVerticalAlignment(layout.vertical_alignment)
        end

        local key_layout = capture_slot_layout(default_guide)
        local label_layout = capture_slot_layout(default_text)
        local native_actions = {}
        local footer_child_count = unwrap(footer:GetChildrenCount())
        for index = 1, footer_child_count - 1 do
            local child = unwrap(footer:GetChildAt(index))
            native_actions[#native_actions + 1] = {
                child = child,
                layout = capture_slot_layout(child),
            }
        end
        for _, action in ipairs(native_actions) do
            if not unwrap(footer:RemoveChild(action.child)) then
                error("could not reorder Palworld's native footer actions")
            end
        end

        local key_slot = unwrap(footer:AddChild(keycap))
        local label_slot = unwrap(footer:AddChild(label))
        if not is_valid(key_slot) or not is_valid(label_slot) then
            error("could not attach the mod-default action to Palworld's footer")
        end
        apply_slot_layout(key_slot, key_layout)
        apply_slot_layout(label_slot, label_layout)

        for _, action in ipairs(native_actions) do
            local slot = unwrap(footer:AddChild(action.child))
            if not is_valid(slot) then
                error("could not restore a native footer action after reordering")
            end
            apply_slot_layout(slot, action.layout)
        end

        return {
            owner = widget,
            footer = footer,
            keycap = keycap,
            key_brush = key_brush,
            key_source = key_source,
            key_source_image = key_source_image,
            label = label,
            original_label_color = native_color,
            visible = false,
        }
    end)

    if not ok then
        if option_footer_errors[address] ~= tostring(state_or_error) then
            option_footer_errors[address] = tostring(state_or_error)
            log("Could not add the F12 footer action: " .. tostring(state_or_error))
        end
        return false
    end

    option_footer_errors[address] = nil
    option_settings_widgets[address] = state_or_error
    update_mod_defaults_footer_visibility(state_or_error)
    log("Added native-styled F12 Restore Mod Defaults to the left side of Palworld's Options footer")
    return true
end

local function call_end_aim(controller)
    local address = controller:GetAddress()
    aim_guard[address] = true
    local ok, error_message = pcall(function()
        controller:OnEndAim()
    end)
    aim_guard[address] = nil
    if not ok then
        log("Could not release Toggle Aim (ADS): " .. tostring(error_message))
    end
    return ok
end

local function get_character_shooter(character)
    if not is_valid(character) then
        return nil
    end

    local ok, shooter = pcall(function()
        local property_ok, property_value = pcall(function()
            return unwrap(character:GetPropertyValue("ShooterComponent"))
        end)
        if property_ok and is_valid(property_value) then
            return property_value
        end
        return unwrap(character.ShooterComponent)
    end)

    if ok and is_valid(shooter) then
        return shooter
    end
    return nil
end

local function get_shooter_component(controller)
    if not is_valid(controller) then
        return nil
    end

    for _, getter in ipairs({
        function() return unwrap(controller:GetPawn()) end,
        function() return unwrap(controller:GetCharacter()) end,
        function() return unwrap(controller:GetPropertyValue("AcknowledgedPawn")) end,
        function() return unwrap(controller:GetPropertyValue("Pawn")) end,
    }) do
        local ok, character = pcall(getter)
        if ok then
            local shooter = get_character_shooter(character)
            if is_valid(shooter) then
                return shooter
            end
        end
    end

    local ok, characters = pcall(function()
        return FindAllOf("PalPlayerCharacter")
    end)
    if ok and characters ~= nil then
        for _, character in pairs(characters) do
            local owned = false
            pcall(function()
                local character_controller = unwrap(character:GetController())
                owned = is_valid(character_controller)
                    and character_controller:GetAddress() == controller:GetAddress()
            end)
            if owned then
                local shooter = get_character_shooter(character)
                if is_valid(shooter) then
                    return shooter
                end
            end
        end
    end

    -- Never fall back to an arbitrary player while ownership is moving during
    -- world load. Latching a stale pawn can leave camera zoom and HUD state split.
    return nil
end

local function get_direct_player_character(controller)
    if not is_valid(controller) then
        return nil
    end
    for _, getter in ipairs({
        function() return unwrap(controller:GetPawn()) end,
        function() return unwrap(controller:GetCharacter()) end,
        function() return unwrap(controller:GetPropertyValue("AcknowledgedPawn")) end,
        function() return unwrap(controller:GetPropertyValue("Pawn")) end,
    }) do
        local ok, character = pcall(getter)
        if ok and is_valid(character) then
            return character
        end
    end
    return nil
end

local function find_ready_local_aim_context()
    local ok, controllers = pcall(function() return FindAllOf("PalPlayerController") end)
    if not ok or controllers == nil then
        return nil, nil, nil
    end

    local fallback = nil
    for _, controller in pairs(controllers) do
        if is_valid(controller) then
            local character = get_direct_player_character(controller)
            local shooter = get_character_shooter(character)
            if is_valid(character) and is_valid(shooter) then
                local is_local = false
                local local_check_ok = pcall(function()
                    is_local = unwrap(controller:IsLocalController()) == true
                end)
                if local_check_ok and is_local then
                    return controller, character, shooter
                end
                if fallback == nil then
                    fallback = { controller = controller, character = character, shooter = shooter }
                end
            end
        end
    end

    if fallback ~= nil then
        return fallback.controller, fallback.character, fallback.shooter
    end
    return nil, nil, nil
end

local function is_gameplay_aim_allowed(controller)
    if not is_valid(controller) then
        return false, "no active gameplay controller"
    end

    local character = get_direct_player_character(controller)
    if not is_valid(character) or not is_valid(get_character_shooter(character)) then
        return false, "no active gameplay character"
    end

    local cursor_visible = false
    pcall(function()
        cursor_visible = unwrap(controller:GetPropertyValue("bShowMouseCursor")) == true
    end)
    if cursor_visible then
        return false, "a menu cursor is visible"
    end

    local look_input_ignored = false
    pcall(function()
        look_input_ignored = unwrap(controller:IsLookInputIgnored()) == true
    end)
    if look_input_ignored then
        return false, "Palworld is blocking gameplay look input"
    end

    local paused = false
    local gameplay_statics = StaticFindObject("/Script/Engine.Default__GameplayStatics")
    if is_valid(gameplay_statics) then
        pcall(function()
            paused = unwrap(gameplay_statics:IsGamePaused(controller)) == true
        end)
    end
    if paused then
        return false, "the game is paused"
    end

    return true, nil
end

local function get_shooter_aim_priority(shooter)
    if not is_valid(shooter) then
        return nil
    end

    local ok, priority = pcall(function()
        return unwrap(shooter:GetAimingPriority())
    end)
    if ok then
        return priority
    end
    return nil
end

local function set_shooter_end_aim_disabled(shooter, disabled)
    if not is_valid(shooter) then
        return false
    end

    local ok, error_message = pcall(function()
        -- Palworld uses this named native flag to keep aim active even after
        -- the physical aim button is released. It is safer and more reliable
        -- than repeatedly replaying the controller input callback.
        shooter:SetDisableEndAim(AIM_HOLD_FLAG, disabled == true)
    end)
    if not ok then
        log("Could not change the native Toggle Aim hold: " .. tostring(error_message))
    end
    return ok
end

local function start_shooter_aim(shooter)
    if not is_valid(shooter) then
        return false
    end

    local ok, error_message = pcall(function()
        shooter:StartAim()
    end)
    if not ok then
        log("Could not start the native Toggle Aim hold: " .. tostring(error_message))
    end
    return ok
end

local function end_shooter_aim(shooter, all_priorities)
    if not is_valid(shooter) then
        return false
    end

    local ok, error_message = pcall(function()
        shooter:EndAim(all_priorities == true)
    end)
    if not ok then
        log("Could not release the native Toggle Aim hold: " .. tostring(error_message))
    end
    return ok
end

local function release_shooter_aim_hold(state)
    if state == nil then
        return
    end

    state.shooter = get_shooter_component(state.controller) or state.shooter
    set_shooter_end_aim_disabled(state.shooter, false)
    if is_valid(state.shooter) then
        pcall(function()
            state.shooter:ResetRequestAiming()
            if state.priority ~= nil then
                state.shooter:SetRequestAiming(state.priority, false)
                state.shooter:SetAiming(state.priority, false)
                state.shooter:ChangeIsAiming(state.priority, false)
            end
        end)
    end
    end_shooter_aim(state.shooter, true)
    if is_valid(state.controller) then
        call_end_aim(state.controller)
        pcall(function()
            local character = unwrap(state.controller:GetPawn())
            if not is_valid(character) then
                character = unwrap(state.controller:GetCharacter())
            end
            if is_valid(character) then
                local is_shooting = false
                if is_valid(state.shooter) then
                    is_shooting = unwrap(state.shooter:IsShooting()) == true
                end
                -- EndAim clears the shooter flags, while this callback clears
                -- the player's remaining weapon-ready locomotion and crosshair.
                character:OnChangeShooterState(false, is_shooting)
            end
        end)
    end
end

local function apply_shooter_aim_hold(state)
    if state == nil or not state.latched then
        return false
    end

    state.shooter = get_shooter_component(state.controller) or state.shooter
    if not is_valid(state.shooter) then
        if not state.missing_shooter_logged then
            state.missing_shooter_logged = true
            log("Toggle Aim could not find the local player's ShooterComponent")
        end
        return false
    end

    state.priority = state.priority or get_shooter_aim_priority(state.shooter)
    set_shooter_end_aim_disabled(state.shooter, true)

    local requested = false
    if state.priority ~= nil then
        local ok, error_message = pcall(function()
            state.shooter:SetRequestAiming(state.priority, true)
            state.shooter:SetAiming(state.priority, true)
        end)
        requested = ok
        if not ok and not state.request_error_logged then
            state.request_error_logged = true
            log("Could not maintain Palworld's native aim request: " .. tostring(error_message))
        end
    end

    local aiming = false
    pcall(function()
        aiming = unwrap(state.shooter:IsAiming()) == true
    end)
    if not aiming then
        start_shooter_aim(state.shooter)
    end
    return requested or aiming
end

local function read_shooter_is_aiming(shooter)
    if not is_valid(shooter) then
        return nil
    end
    local ok, aiming = pcall(function()
        return unwrap(shooter:IsAiming()) == true
    end)
    if not ok then
        return nil
    end
    return aiming
end

local function read_right_mouse_down(controller)
    if not is_valid(controller) then
        return nil
    end
    local ok, is_down = pcall(function()
        return unwrap(controller:IsInputKeyDown(RIGHT_MOUSE_KEY)) == true
    end)
    if not ok then
        return nil
    end
    return is_down
end

local function sweep_unverified_right_mouse_aim(pending)
    if pending == nil then
        return nil
    end

    local controller = pending.controller
    local shooter = pending.shooter
    if not is_valid(controller) or not is_valid(shooter) then
        controller, _, shooter = find_ready_local_aim_context()
    end
    if not is_valid(controller) or not is_valid(shooter) then
        return nil
    end

    pending.controller = controller
    pending.shooter = shooter
    pending.address = controller:GetAddress()

    -- A quarantined input is never allowed to become a maintained latch. If
    -- Palworld created one after the quarantine began, retire that state first.
    local existing = aim_states[pending.address]
    if existing ~= nil then
        existing.generation = (existing.generation or 0) + 1
        existing.latched = false
        release_shooter_aim_hold(existing)
        aim_states[pending.address] = nil
        aim_guard[pending.address] = nil
    end

    release_shooter_aim_hold({
        controller = controller,
        shooter = shooter,
        priority = get_shooter_aim_priority(shooter),
        latched = false,
    })
    return read_right_mouse_down(controller)
end

local function release_all_toggle_aim_states(reason)
    if pending_unverified_rmb ~= nil then
        sweep_unverified_right_mouse_aim(pending_unverified_rmb)
        pending_unverified_rmb = nil
    end

    local released = 0
    for address, state in pairs(aim_states) do
        state.generation = (state.generation or 0) + 1
        state.latched = false
        release_shooter_aim_hold(state)
        aim_states[address] = nil
        aim_guard[address] = nil
        released = released + 1
    end

    if released > 0 then
        log(string.format(
            "Toggle Aim fully released because %s (%d aim state%s cleared)",
            reason,
            released,
            released == 1 and "" or "s"
        ))
    end
    return released
end

local function handle_application_focus_changed(focused, source)
    focused = focused == true
    if application_focus_state == focused then
        -- Focus-loss cleanup is intentionally idempotent. The Alt+Tab backup
        -- must still release a latch if the native hook already reported that
        -- Palworld was unfocused before the latch was created.
        if not focused and config.toggle_ads then
            aim_input_generation = aim_input_generation + 1
            release_all_toggle_aim_states(source or "Palworld remained out of focus")
        end
        return
    end

    application_focus_state = focused
    aim_input_generation = aim_input_generation + 1

    if not config.toggle_ads then
        pending_unverified_rmb = nil
        return
    end

    if not focused then
        local released = release_all_toggle_aim_states(source or "Palworld lost application focus")
        if released == 0 then
            log("Palworld lost focus; Toggle Aim input was reset")
        end
        return
    end

    release_all_toggle_aim_states(source or "Palworld regained application focus")
    log("Palworld regained focus; Toggle Aim is ready for the next valid right-click")
end

local function on_application_activation_state_changed(_, focused_parameter)
    local focused = unwrap(focused_parameter) == true
    handle_application_focus_changed(
        focused,
        focused and "Palworld regained application focus" or "Palworld lost application focus"
    )
end

local function maintain_toggle_aim_states()
    local now = os.clock()
    if not config.toggle_ads then
        return
    end

    local pending = pending_unverified_rmb
    if pending ~= nil then
        if pending.input_generation ~= aim_input_generation then
            sweep_unverified_right_mouse_aim(pending)
            pending_unverified_rmb = nil
        else
            local controller = pending.controller
            if not is_valid(controller) then
                controller = select(1, find_ready_local_aim_context())
                pending.controller = controller
            end

            if not pending.cleanup_active
                and now - pending.created_at >= AIM_UNVERIFIED_RMB_GRACE_SECONDS then
                pending.cleanup_active = true
                pending.last_cleanup_at = -1000
                log("Quarantined an unverified right-click and began clearing orphan aim state")
            end

            if pending_unverified_rmb == pending and pending.cleanup_active then
                local should_sweep = not pending.cleanup_performed
                local right_mouse_down = nil
                if should_sweep then
                    pending.last_cleanup_at = now
                    right_mouse_down = sweep_unverified_right_mouse_aim(pending)
                    pending.cleanup_performed = true
                elseif is_valid(pending.controller) then
                    right_mouse_down = read_right_mouse_down(pending.controller)
                end

                if right_mouse_down == true then
                    pending.release_cleanup_at = nil
                elseif right_mouse_down == false and not pending.release_cleanup_at then
                    -- Wait one stable frame, then perform one final cleanup.
                    -- Repeating EndAim while a menu/container is active causes
                    -- Palworld's interaction audio to fire over and over.
                    pending.release_cleanup_at = now
                elseif right_mouse_down == false
                    and pending.release_cleanup_at ~= nil
                    and now - pending.release_cleanup_at >= AIM_UNVERIFIED_CLEANUP_INTERVAL_SECONDS then
                    sweep_unverified_right_mouse_aim(pending)
                    pending_unverified_rmb = nil
                    log("Cleared the orphan aim state from an unverified right-click")
                elseif right_mouse_down == nil
                    and now - pending.created_at >= AIM_INPUT_STATE_ERROR_TIMEOUT_SECONDS then
                    sweep_unverified_right_mouse_aim(pending)
                    pending_unverified_rmb = nil
                    log("Cleared an unverified right-click after its input state became unavailable")
                end
            end
        end
    end

    for address, state in pairs(aim_states) do
        if state.latched and is_valid(state.controller) then
            local allowed, reason = is_gameplay_aim_allowed(state.controller)
            if allowed then
                state.shooter = get_shooter_component(state.controller) or state.shooter
                local now = os.clock()
                local release_reason = nil

                if state.initial_press_active then
                    -- Ignore the raw key-down callback belonging to the first
                    -- click. Once Palworld observes a stable button release,
                    -- the next fresh RMB press becomes the toggle-off click.
                    local right_mouse_down = read_right_mouse_down(state.controller)
                    if right_mouse_down == true then
                        state.release_observed_at = nil
                        state.input_read_failed_at = nil
                    elseif right_mouse_down == false then
                        state.input_read_failed_at = nil
                        state.release_observed_at = state.release_observed_at or now
                        if now - state.release_observed_at >= AIM_UNVERIFIED_CLEANUP_INTERVAL_SECONDS then
                            state.initial_press_active = false
                            state.release_observed_at = nil
                        end
                    else
                        state.release_observed_at = nil
                        state.input_read_failed_at = state.input_read_failed_at or now
                        if now - state.input_read_failed_at >= AIM_INPUT_STATE_ERROR_TIMEOUT_SECONDS then
                            state.initial_press_active = false
                            state.input_read_failed_at = nil
                        end
                    end
                end

                local native_aiming = read_shooter_is_aiming(state.shooter)
                if native_aiming == false
                    and now - (state.armed_at or now) >= AIM_INITIAL_RELEASE_TIMEOUT_SECONDS then
                    release_reason = "Toggle Aim fully released because Palworld cancelled the native ADS state"
                end

                if release_reason ~= nil then
                    state.generation = (state.generation or 0) + 1
                    state.latched = false
                    release_shooter_aim_hold(state)
                    aim_states[address] = nil
                    aim_guard[address] = nil
                    log(release_reason)
                end
            else
                state.generation = (state.generation or 0) + 1
                state.latched = false
                release_shooter_aim_hold(state)
                aim_states[address] = nil
                aim_guard[address] = nil
                log("Toggle Aim released because gameplay input became unavailable: " .. tostring(reason))
            end
        end
    end
end

local function get_parameter_name(parameter)
    local value = unwrap(parameter)
    local ok, result = pcall(function()
        return value:ToString()
    end)
    return ok and result or tostring(value)
end

local function get_parameter_key(parameter)
    local key = unwrap(parameter)
    local ok, name = pcall(function()
        return key.KeyName:ToString()
    end)
    return key, ok and name or ""
end

local function allow_accessibility_key(_, key_parameter, _, return_value)
    local _, key_name = get_parameter_key(key_parameter)
    if key_name == "" or key_name == "None" or key_name == "Invalid" then
        return
    end

    local ok, error_message = pcall(function()
        return_value:set(true)
    end)
    if not ok then
        log("Could not allow accessibility key '" .. key_name .. "': " .. tostring(error_message))
    end
end

local function is_weapon_action(action_name)
    return action_name == "ChangeWeaponPrev" or action_name == "ChangeWeaponNext"
end

local function is_wheel_key(key_name)
    return key_name == "MouseScrollUp" or key_name == "MouseScrollDown"
end

local function save_weapon_action_override(action_name, key_name)
    local displaced_action = nil
    if action_name == "ChangeWeaponPrev" then
        config.weapon_prev_key = key_name
        local next_effective_key = config.weapon_next_key ~= ""
            and config.weapon_next_key
            or get_default_weapon_key("ChangeWeaponNext")
        if next_effective_key == key_name then
            config.weapon_next_key = UNBOUND_WEAPON_KEY
            displaced_action = "ChangeWeaponNext"
        end
    else
        config.weapon_next_key = key_name
        local previous_effective_key = config.weapon_prev_key ~= ""
            and config.weapon_prev_key
            or get_default_weapon_key("ChangeWeaponPrev")
        if previous_effective_key == key_name then
            config.weapon_prev_key = UNBOUND_WEAPON_KEY
            displaced_action = "ChangeWeaponPrev"
        end
    end
    save_config()
    return displaced_action
end

local function restore_wheel_capture(state)
    if state == nil then return end
    for _, entry in ipairs(state.scroll_boxes or {}) do
        if is_valid(entry.scroll_box) then
            pcall(function()
                entry.scroll_box:SetScrollOffset(entry.original_offset)
                if entry.animate ~= nil then
                    entry.scroll_box:SetAnimateWheelScrolling(entry.animate)
                end
            end)
        end
    end
    if wheel_capture_state == state then
        wheel_capture_state = nil
    end
end

local function refresh_weapon_binding_row(owner, action_name, input_type)
    if not is_valid(owner) then
        return
    end
    local row = map_find(owner.InputActionsMap_KM, action_name)
    if not is_valid(row) then
        return
    end
    pcall(function()
        local key = get_current_input_action_key(action_name)
        local key_name = key.KeyName:ToString()
        row:SetConfigButton(FName(action_name), input_type or 0, 0)
        row:SetKeyIcon(key, input_type or 0)
        local key_box = unwrap(row.WBP_OptionSettings_ListContentButton)
        local image = is_valid(key_box) and unwrap(key_box.Image_Key) or nil
        if is_valid(image) then
            if key_name == "" or key_name == "None" or key_name == "Tilde" then
                -- SetKeyIcon(None) leaves the template's previous brush painted.
                -- Collapse only the image so an unbound row is visibly blank;
                -- the native full-row binding button remains clickable.
                image:SetVisibility(1)
            else
                local utility = StaticFindObject("/Script/Pal.Default__PalUIUtility")
                local brush = is_valid(utility) and unwrap(utility:GetKeyIconByKey(
                    row,
                    key,
                    input_type or 0
                )) or nil
                if brush ~= nil then image:SetBrush(brush) end
                -- HitTestInvisible: visible without blocking the native row.
                image:SetVisibility(3)
            end
        end
        set_accessibility_keycap(row, key_name)
        for _, definition in ipairs(KEY_ROWS) do
            if definition.action == action_name then
                set_row_label(row, definition.label)
                break
            end
        end
    end)
end

local function refresh_all_weapon_binding_rows(input_type)
    for _, widget_state in pairs(key_settings_widgets) do
        if is_valid(widget_state.widget) then
            refresh_weapon_binding_row(widget_state.widget, "ChangeWeaponPrev", input_type or 0)
            refresh_weapon_binding_row(widget_state.widget, "ChangeWeaponNext", input_type or 0)
        end
    end
end

local function schedule_all_weapon_binding_rows_refresh(delay_ms, input_type)
    ExecuteInGameThreadWithDelay(delay_ms or 0, function()
        refresh_all_weapon_binding_rows(input_type or 0)
    end)
end

local function refresh_building_binding_row(owner, action_name, input_type)
    if not is_valid(owner) then
        return
    end
    local row = map_find(owner.UIActionsMap_KM, action_name)
    if not is_valid(row) then
        return
    end
    pcall(function()
        row:SetUIConfigButton(FName(action_name), input_type or 0)
        for _, definition in ipairs(KEY_ROWS) do
            if definition.action == action_name then
                set_row_label(row, definition.label)
                break
            end
        end
    end)
end

local function clear_saved_weapon_overrides()
    config.weapon_prev_key = ""
    config.weapon_next_key = ""
    return save_config()
end

local function restore_default_weapon_engine_mappings()
    local input_settings = StaticFindObject("/Script/Engine.Default__InputSettings")
    if not is_valid(input_settings) then
        return false, "Unreal input settings are unavailable"
    end

    local ok, result_or_error = pcall(function()
        local removed = 0
        -- Replace both actions as one transaction. This prevents either of the
        -- intermediate key-map rebuilds from leaving the live player with only
        -- one restored wheel direction.
        for _, definition in ipairs(DEFAULT_WEAPON_WHEEL_BINDINGS) do
            local removals = collect_action_mappings(input_settings, definition.action, nil)
            for _, mapping in ipairs(removals) do
                input_settings:RemoveActionMapping(mapping, false)
                removed = removed + 1
            end
        end
        for _, definition in ipairs(DEFAULT_WEAPON_WHEEL_BINDINGS) do
            input_settings:AddActionMapping({
                ActionName = FName(definition.action),
                Key = { KeyName = FName(definition.key) },
                bShift = false,
                bCtrl = false,
                bAlt = false,
                bCmd = false,
            }, false)
        end
        input_settings:SaveKeyMappings()
        input_settings:ForceRebuildKeymaps()
        for _, definition in ipairs(DEFAULT_WEAPON_WHEEL_BINDINGS) do
            local _, live_error = update_live_palworld_action_mapping(
                definition.action,
                definition.key
            )
            if live_error ~= nil then
                log(string.format(
                    "Could not update Palworld's live %s default: %s",
                    definition.action,
                    tostring(live_error)
                ))
            end
        end
        return removed
    end)
    if not ok then
        return false, result_or_error
    end
    return true, result_or_error
end

local function schedule_default_weapon_engine_mapping_restore(delay_ms)
    ExecuteInGameThreadWithDelay(delay_ms or 0, function()
        if not default_wheel_reset_active() then
            return
        end
        local restored, error_message = restore_default_weapon_engine_mappings()
        if not restored then
            log("Could not finish the delayed wheel-default rebuild: " .. tostring(error_message))
        end
    end)
end

local function finish_default_binding_refresh(key_settings, input_type)
    if is_valid(key_settings) then
        refresh_weapon_binding_row(key_settings, "ChangeWeaponPrev", input_type or 0)
        refresh_weapon_binding_row(key_settings, "ChangeWeaponNext", input_type or 0)
        refresh_building_binding_row(key_settings, "BuildRotateLeft", input_type or 0)
        refresh_building_binding_row(key_settings, "BuildRotateRight", input_type or 0)
    end
    schedule_all_weapon_binding_rows_refresh(50, input_type or 0)
    schedule_all_weapon_binding_rows_refresh(250, input_type or 0)
    schedule_all_weapon_binding_rows_refresh(750, input_type or 0)
    ExecuteInGameThreadWithDelay(50, clear_default_wheel_warnings)
    ExecuteInGameThreadWithDelay(250, clear_default_wheel_warnings)
    ExecuteInGameThreadWithDelay(750, clear_default_wheel_warnings)
    schedule_weapon_hud_refresh(100)
    schedule_weapon_hud_refresh(500)
    schedule_weapon_hud_refresh(1000)
end

local function on_palworld_native_defaults_restored(context)
    local key_settings = unwrap(context)
    -- Palworld's built-in F Restore to Default rebuilds its own key cache but
    -- does not emit On Action Key Changed for injected actions. Clear the mod's
    -- two overrides from that exact reset callback as well.
    clear_saved_weapon_overrides()
    ExecuteInGameThreadWithDelay(0, function()
        local restored, error_message = restore_default_weapon_engine_mappings()
        if not restored then
            log("Palworld defaults cleared the saved weapon keys, but " .. tostring(error_message))
        end
        schedule_default_weapon_engine_mapping_restore(250)
        finish_default_binding_refresh(key_settings, 0)
        log("Palworld Restore to Default cleared the saved mod weapon bindings and restored the wheel defaults")
    end)
end

local function restore_mod_default_bindings(footer_state)
    if footer_state == nil or not is_valid(footer_state.owner) then
        return false
    end

    restore_wheel_capture(wheel_capture_state)
    local key_settings = unwrap(footer_state.owner.KeySettings)
    if not is_valid(key_settings) then
        for _, widget_state in pairs(key_settings_widgets) do
            if is_valid(widget_state.widget) then
                key_settings = widget_state.widget
                break
            end
        end
    end

    -- Clear our file first. Even if Palworld rejects its native cache update,
    -- the next row/HUD refresh and the next launch can no longer resurrect the
    -- user's old mod keys.
    clear_saved_weapon_overrides()

    local persistent_ok, removed_or_error = restore_palworld_persistent_key_defaults(key_settings)
    if not persistent_ok then
        log("Could not restore Palworld's persistent key defaults: " .. tostring(removed_or_error))
    end

    -- Blank file values mean the user has no saved override. Keep explicit
    -- weapon mappings for the defaults because Palworld's contextual building
    -- wheel path does not dispatch the two weapon actions by itself.
    local restored, restore_error = restore_default_weapon_engine_mappings()
    if not restored then log(restore_error) end
    schedule_default_weapon_engine_mapping_restore(250)

    for _, widget_state in pairs(key_settings_widgets) do
        if is_valid(widget_state.widget)
            and (not is_valid(key_settings) or widget_state.widget:GetAddress() ~= key_settings:GetAddress()) then
            refresh_weapon_binding_row(widget_state.widget, "ChangeWeaponPrev", 0)
            refresh_weapon_binding_row(widget_state.widget, "ChangeWeaponNext", 0)
            refresh_building_binding_row(widget_state.widget, "BuildRotateLeft", 0)
            refresh_building_binding_row(widget_state.widget, "BuildRotateRight", 0)
        end
    end
    finish_default_binding_refresh(key_settings, 0)
    log(string.format(
        "Restored all four mod rows; removed %s persistent override%s and restored MouseScrollUp/MouseScrollDown",
        persistent_ok and tostring(removed_or_error) or "unknown",
        persistent_ok and removed_or_error == 1 and "" or "s"
    ))
    return restored
end

local function show_restore_mod_defaults_confirmation(footer_state)
    -- Fail closed if F12 is pressed during the short asset/hook warm-up. An
    -- unhooked native dialog could otherwise be displayed without a safe way
    -- for this mod to distinguish Yes from No/Escape.
    if not dialog_function_hooks_registered then
        log("Restore Mod Defaults is still initializing; confirmation was not opened")
        return false
    end

    if pending_restore_dialog ~= nil then
        if is_valid(pending_restore_dialog.parameter)
            and is_valid(pending_restore_dialog.footer_state.owner) then
            return true
        end
        pending_restore_dialog = nil
    end

    local ok, error_message = pcall(function()
        local parameter_class = StaticFindObject(RESTORE_DIALOG_CLASS)
        local pal_utility = StaticFindObject(PAL_UTILITY_DEFAULT)
        if not is_valid(parameter_class) or not is_valid(pal_utility) then
            error("Palworld's confirmation dialog API is unavailable")
        end

        local parameter = StaticConstructObject(parameter_class, footer_state.owner, 0)
        if not is_valid(parameter) then
            error("Palworld did not create the confirmation dialog")
        end

        parameter:SetParameters(FText(
            "Restore Mod Default Keys?\n\n"
            .. "The four custom bindings will be cleared. Weapon switching will return "
            .. "to Mouse Wheel Up and Mouse Wheel Down. "
            .. "Are you sure?"
        ), 1, true, 1)
        parameter:SetPropertyValue("IsCloseWhenDamaged", false)
        parameter:SetPropertyValue("IsEnableShortcutConfirmInput", false)

        -- Store the exact parameter address before opening the modal. The
        -- global callback hook also sees every other Palworld dialog, so only
        -- this object is allowed to restore the mod bindings.
        pending_restore_dialog = {
            parameter = parameter,
            footer_state = footer_state,
        }
        pal_utility:DialogWithParameter(footer_state.owner, parameter)
    end)

    if not ok then
        pending_restore_dialog = nil
        log("Could not open the Restore Mod Defaults confirmation: " .. tostring(error_message))
        return false
    end

    log("Opened Palworld's confirmation dialog for Restore Mod Defaults")
    return true
end

local function matching_pending_restore_dialog(context)
    local pending = pending_restore_dialog
    if pending == nil then
        return nil
    end

    local widget = unwrap(context)
    if not is_valid(widget) or not is_valid(pending.parameter) then
        pending_restore_dialog = nil
        return nil
    end

    local parameter = nil
    local parameter_ok = pcall(function()
        parameter = unwrap(widget:GetPropertyValue("Parameter"))
    end)
    if not parameter_ok or not is_valid(parameter) then
        return nil
    end

    local matches = false
    pcall(function()
        matches = parameter:GetAddress() == pending.parameter:GetAddress()
    end)
    if not matches then
        return nil
    end
    return pending
end

local function on_restore_dialog_yes(context)
    local pending = matching_pending_restore_dialog(context)
    if pending == nil then
        return
    end
    local footer_state = pending.footer_state
    pending_restore_dialog = nil
    ExecuteInGameThreadWithDelay(0, function()
        restore_mod_default_bindings(footer_state)
    end)
end

local function on_restore_dialog_cancel(context)
    if matching_pending_restore_dialog(context) == nil then
        return
    end
    pending_restore_dialog = nil
    log("Restore Mod Defaults was cancelled")
end

local function register_restore_dialog_hooks()
    if dialog_function_hooks_registered then
        return true
    end

    local ok, error_message = pcall(function()
        -- These are Blueprint/script UFunctions. This UE4SS build registers
        -- their one callback after execution, so the real handler must be the
        -- first callback rather than the native pre/post overload.
        RegisterHook(RESTORE_DIALOG_LEFT, on_restore_dialog_yes)
        RegisterHook(RESTORE_DIALOG_RIGHT, on_restore_dialog_cancel)
        RegisterHook(RESTORE_DIALOG_CANCEL, on_restore_dialog_cancel)
    end)
    if not ok then
        log("Could not enable the Restore Mod Defaults dialog hooks: " .. tostring(error_message))
        return false
    end

    dialog_function_hooks_registered = true
    log("Enabled fail-closed Yes/No hooks for Restore Mod Defaults")
    return true
end

local function on_f12_pressed()
    -- F12 remains bindable while Palworld's key-capture dialog is open.
    if pending_weapon_binding ~= nil or pending_restore_dialog ~= nil then
        return
    end
    ExecuteInGameThreadWithDelay(0, function()
        for address, state in pairs(option_settings_widgets) do
            if not is_valid(state.owner) or not is_valid(state.label) then
                option_settings_widgets[address] = nil
            else
                -- Palworld nests WBP_OptionSettings inside its menu instead of
                -- adding this widget directly to the viewport. The visible
                -- Keyboard footer is the correct active-screen signal.
                if update_mod_defaults_footer_visibility(state) then
                    show_restore_mod_defaults_confirmation(state)
                    return
                end
            end
        end
    end)
end

local function finish_wheel_capture(capture, key_name)
    if capture == nil or capture.completion_scheduled or not is_wheel_key(key_name) then
        return
    end
    capture.completion_scheduled = true
    if pending_weapon_binding == capture then
        pending_weapon_binding = nil
    end
    restore_wheel_capture(wheel_capture_state)

    ExecuteInGameThreadWithDelay(100, function()
        local mapping_ok, mapping_result = replace_engine_action_mapping(capture.action, key_name)
        if not mapping_ok then
            log(string.format("Could not bind %s to %s: %s", capture.action, key_name, tostring(mapping_result)))
            return
        end

        save_weapon_action_override(capture.action, key_name)
        local opposite_action = capture.action == "ChangeWeaponPrev"
            and "ChangeWeaponNext"
            or "ChangeWeaponPrev"
        -- Palworld may still have the same wheel direction mapped to the
        -- opposite weapon action. Retire that duplicate before saving the new
        -- bind so one physical input cannot dispatch both weapon directions.
        remove_engine_action_mapping(opposite_action, key_name)

        local owner = capture.owner
        if is_valid(owner) then
            local row = map_find(owner.InputActionsMap_KM, capture.action)
            if is_valid(row) then
                pcall(function()
                    local key = { KeyName = FName(key_name) }
                    row:SetConfigButton(FName(capture.action), capture.input_type or 0, 0)
                    row:SetKeyIcon(key, capture.input_type or 0)
                    set_accessibility_keycap(row, key_name)
                    for _, definition in ipairs(KEY_ROWS) do
                        if definition.action == capture.action then
                            set_row_label(row, definition.label)
                            break
                        end
                    end
                end)
            end

            local opposite_row = map_find(owner.InputActionsMap_KM, opposite_action)
            if is_valid(opposite_row) then
                pcall(function()
                    local opposite_key = get_current_input_action_key(opposite_action)
                    opposite_row:SetConfigButton(FName(opposite_action), capture.input_type or 0, 0)
                    opposite_row:SetKeyIcon(opposite_key, capture.input_type or 0)
                    local opposite_key_name = opposite_key.KeyName:ToString()
                    set_accessibility_keycap(opposite_row, opposite_key_name)
                end)
            end
        end
        log(string.format("Bound mouse wheel: %s = %s", capture.action, key_name))
        schedule_all_weapon_binding_rows_refresh(50, capture.input_type or 0)
        schedule_all_weapon_binding_rows_refresh(250, capture.input_type or 0)
        schedule_weapon_hud_refresh(100)
    end)
end

local function begin_wheel_capture(capture)
    restore_wheel_capture(wheel_capture_state)
    local state = {
        capture = capture,
        scroll_boxes = {},
        armed = false,
        started = os.clock(),
    }
    wheel_capture_state = state

    local ok, scroll_boxes = pcall(function() return FindAllOf("ScrollBox") end)
    if ok and scroll_boxes ~= nil then
        for _, scroll_box in pairs(scroll_boxes) do
            if is_valid(scroll_box) then
                local entry_ok, entry = pcall(function()
                    local original_offset = unwrap(scroll_box:GetScrollOffset())
                    local end_offset = unwrap(scroll_box:GetScrollOffsetOfEnd())
                    if type(original_offset) ~= "number" or type(end_offset) ~= "number" or end_offset <= 1 then
                        return nil
                    end
                    local animate = nil
                    pcall(function() animate = unwrap(scroll_box:GetPropertyValue("bAnimateWheelScrolling")) end)
                    local baseline = math.max(1, math.min(end_offset - 1, original_offset))
                    scroll_box:SetAnimateWheelScrolling(false)
                    scroll_box:SetScrollOffset(baseline)
                    return {
                        scroll_box = scroll_box,
                        original_offset = original_offset,
                        baseline = baseline,
                        animate = type(animate) == "boolean" and animate or nil,
                    }
                end)
                if entry_ok and entry ~= nil then
                    state.scroll_boxes[#state.scroll_boxes + 1] = entry
                end
            end
        end
    end

    ExecuteInGameThreadWithDelay(200, function()
        if wheel_capture_state ~= state or pending_weapon_binding ~= capture then
            restore_wheel_capture(state)
            return
        end
        for _, entry in ipairs(state.scroll_boxes) do
            if is_valid(entry.scroll_box) then
                local current_ok, current = pcall(function() return unwrap(entry.scroll_box:GetScrollOffset()) end)
                if current_ok and type(current) == "number" then
                    entry.baseline = current
                end
            end
        end
        state.armed = true
        log(string.format(
            "Wheel capture armed for %s (%d scroll panel%s monitored)",
            capture.action,
            #state.scroll_boxes,
            #state.scroll_boxes == 1 and "" or "s"
        ))
    end)
end

local function poll_wheel_capture()
    local state = wheel_capture_state
    if state == nil then return end
    if pending_weapon_binding ~= state.capture or os.clock() - state.started > 20 then
        if pending_weapon_binding == state.capture and os.clock() - state.started > 20 then
            pending_weapon_binding = nil
            local capture = state.capture
            if is_valid(capture.owner) then
                local row = map_find(capture.owner.InputActionsMap_KM, capture.action)
                if is_valid(row) then
                    pcall(function()
                        local current_key = get_current_input_action_key(capture.action)
                        row:SetConfigButton(FName(capture.action), capture.input_type or 0, 0)
                        row:SetKeyIcon(current_key, capture.input_type or 0)
                        set_accessibility_keycap(row, current_key.KeyName:ToString())
                    end)
                end
            end
        end
        restore_wheel_capture(state)
        return
    end
    if not state.armed then return end

    for _, entry in ipairs(state.scroll_boxes) do
        if is_valid(entry.scroll_box) then
            local ok, current = pcall(function() return unwrap(entry.scroll_box:GetScrollOffset()) end)
            if ok and type(current) == "number" then
                local delta = current - entry.baseline
                if math.abs(delta) > 0.05 then
                    local key_name = delta < 0 and "MouseScrollUp" or "MouseScrollDown"
                    local capture = state.capture
                    restore_wheel_capture(state)
                    finish_wheel_capture(capture, key_name)
                    return
                end
            end
        end
    end
end

local function on_key_config_changing(context, action_parameter, input_type_parameter)
    local action_name = get_parameter_name(action_parameter)
    if is_weapon_action(action_name) then
        pending_weapon_binding = {
            action = action_name,
            input_type = unwrap(input_type_parameter),
            owner = unwrap(context),
        }
        log(string.format(
            "Opened Palworld's key capture for %s (input type %s)",
            action_name,
            tostring(unwrap(input_type_parameter))
        ))
    end
end

local function finish_tilde_capture(capture)
    if capture == nil then
        return
    end

    save_weapon_action_override(capture.action, "Tilde")
    remove_engine_action_mapping("ChangeWeaponPrev", "Tilde")
    remove_engine_action_mapping("ChangeWeaponNext", "Tilde")

    local owner = capture.owner
    if not is_valid(owner) then
        for _, widget_state in pairs(key_settings_widgets) do
            if is_valid(widget_state.widget) then
                owner = widget_state.widget
                break
            end
        end
    end

    if is_valid(owner) then
        local row = map_find(owner.InputActionsMap_KM, capture.action)
        if is_valid(row) then
            pcall(function()
                row:SetKeyIcon({ KeyName = FName("Tilde") }, capture.input_type or 0)
                for _, definition in ipairs(KEY_ROWS) do
                    if definition.action == capture.action then
                        set_accessibility_keycap(row, "Tilde")
                        set_row_label(row, definition.label)
                        break
                    end
                end
            end)
        end
    end

    if tilde_capture_in_progress == capture then
        tilde_capture_in_progress = nil
    end
    log(string.format("Bound direct backtick shortcut: %s = Tilde", capture.action))
    schedule_all_weapon_binding_rows_refresh(50, capture.input_type or 0)
    schedule_all_weapon_binding_rows_refresh(250, capture.input_type or 0)
    schedule_weapon_hud_refresh(100)
end

local function schedule_tilde_capture(capture)
    if capture == nil or capture.completion_scheduled then
        return
    end
    capture.completion_scheduled = true
    tilde_capture_in_progress = capture
    restore_wheel_capture(wheel_capture_state)
    if pending_weapon_binding == capture then
        pending_weapon_binding = nil
    end
    -- Leave both the Slate key event and Palworld's Blueprint callback before
    -- touching the row or config. The gameplay shortcut itself does not depend
    -- on Palworld accepting Tilde as an ordinary action key.
    ExecuteInGameThreadWithDelay(200, function()
        finish_tilde_capture(capture)
    end)
end

local function trigger_saved_tilde_weapon_action()
    local action_name = nil
    if config.weapon_prev_key == "Tilde" then
        action_name = "ChangeWeaponPrev"
    elseif config.weapon_next_key == "Tilde" then
        action_name = "ChangeWeaponNext"
    end
    if action_name == nil then
        return
    end

    ExecuteInGameThreadWithDelay(0, function()
        local controller = FindFirstOf("PalPlayerController")
        if not is_valid(controller) then
            return
        end

        local ok, error_message = pcall(function()
            if action_name == "ChangeWeaponPrev" then
                controller:OnPressedWeaponPrevButton()
            else
                controller:OnPressedWeaponNextButtonKeyboard()
            end
        end)
        if ok then
            log("Triggered " .. action_name .. " from the physical backtick key")
            return
        end

        -- The controller handlers are the exact keyboard input targets in the
        -- current Steam build. Keep the character callbacks as a compatibility
        -- fallback in case a later build moves those controller functions.
        local fallback_ok, fallback_error = pcall(function()
            local character = unwrap(controller:GetPawn())
            if not is_valid(character) then
                character = unwrap(controller:GetCharacter())
            end
            if not is_valid(character) then
                error("local player character is unavailable")
            end
            if action_name == "ChangeWeaponPrev" then
                character:OnChangePrevWeapon()
            else
                character:OnChangeNextWeapon()
            end
        end)
        if fallback_ok then
            log("Triggered " .. action_name .. " from the physical backtick key (character fallback)")
        else
            log(string.format("Could not trigger %s from backtick: %s / %s", action_name, tostring(error_message), tostring(fallback_error)))
        end
    end)
end

local function on_action_key_changed(context, action_parameter, key_parameter, input_type_parameter, _)
    local action_name = get_parameter_name(action_parameter)
    if not is_weapon_action(action_name) then
        return
    end

    local key, key_name = get_parameter_key(key_parameter)
    local input_type = unwrap(input_type_parameter)
    local widget = unwrap(context)
    if is_wheel_key(key_name) then
        local capture = pending_weapon_binding
        if capture ~= nil and capture.action == action_name then
            finish_wheel_capture(capture, key_name)
            return
        end
    elseif key_name == "Tilde" then
        local capture = pending_weapon_binding
        if capture ~= nil and capture.action == action_name then
            schedule_tilde_capture(capture)
        end
    elseif pending_weapon_binding ~= nil and pending_weapon_binding.action == action_name then
        pending_weapon_binding = nil
    end

    local has_key = key_name ~= "" and key_name ~= "None" and key_name ~= "Invalid"
    if not has_key then
        restore_wheel_capture(wheel_capture_state)
        set_saved_weapon_key(action_name, "")
        ExecuteInGameThreadWithDelay(100, function()
            local default_key = get_default_weapon_key(action_name)
            local restore_ok, restore_result = replace_engine_action_mapping(action_name, default_key)
            if not restore_ok then
                log(string.format("Could not restore default %s = %s: %s", action_name, default_key, tostring(restore_result)))
                return
            end
            local opposite_action = action_name == "ChangeWeaponPrev"
                and "ChangeWeaponNext"
                or "ChangeWeaponPrev"
            remove_engine_action_mapping(opposite_action, default_key)
            refresh_weapon_binding_row(widget, action_name, input_type)
            schedule_all_weapon_binding_rows_refresh(150, input_type)
            schedule_weapon_hud_refresh(100)
            schedule_weapon_hud_refresh(500)
            log(string.format("Cleared the custom %s key and restored %s", action_name, default_key))
        end)
        return
    end

    local old_saved_key = get_saved_weapon_key(action_name)
    if old_saved_key ~= "" and key_name ~= old_saved_key then
        set_saved_weapon_key(action_name, "")
        ExecuteInGameThreadWithDelay(100, function()
            local remove_ok, remove_result = remove_engine_action_mapping(action_name, old_saved_key)
            if not remove_ok then
                log(string.format("Could not retire old fallback binding %s = %s: %s", action_name, old_saved_key, tostring(remove_result)))
            end
        end)
    end
    -- Cache every accepted weapon key, not only wheel/backtick fallbacks. The
    -- injected rows and the weapon HUD can then paint the exact accepted key
    -- even when Palworld's native redraw does not expose these split actions.
    local displaced_action = save_weapon_action_override(action_name, key_name)
    if displaced_action ~= nil then
        ExecuteInGameThreadWithDelay(100, function()
            local remove_ok, remove_result = remove_engine_action_mapping(displaced_action, key_name)
            if not remove_ok then
                log(string.format("Could not clear duplicate binding %s = %s: %s", displaced_action, key_name, tostring(remove_result)))
            end
        end)
    end

    local row = map_find(widget.InputActionsMap_KM, action_name)
    if is_valid(row) then
        pcall(function()
            row:SetKeyIcon(key, input_type)
            for _, definition in ipairs(KEY_ROWS) do
                if definition.action == action_name then
                    set_accessibility_keycap(row, key_name)
                    set_row_label(row, definition.label)
                    break
                end
            end
        end)
    end
    log(string.format("Palworld accepted binding %s = %s", action_name, key_name))
    schedule_all_weapon_binding_rows_refresh(50, input_type)
    schedule_all_weapon_binding_rows_refresh(250, input_type)
    schedule_weapon_hud_refresh(150)
    schedule_weapon_hud_refresh(600)
end

local function on_tilde_key_pressed()
    local pending = pending_weapon_binding
    if pending ~= nil and is_weapon_action(pending.action) then
        schedule_tilde_capture(pending)
        return
    end
    if tilde_capture_in_progress ~= nil then
        return
    end
    trigger_saved_tilde_weapon_action()
end

local function on_key_row_clicked(context)
    local row = unwrap(context)
    if not is_valid(row) then
        return
    end

    local state = key_row_owners[row:GetAddress()]
    if state == nil or state.opening or not is_valid(state.owner) then
        return
    end

    state.opening = true
    ExecuteInGameThreadWithDelay(600, function()
        if key_row_owners[row:GetAddress()] == state then
            state.opening = false
        end
    end)

    local ok, error_message = pcall(function()
        -- These generated Blueprint functions contain spaces, so use bracket
        -- lookup and pass the owning settings widget explicitly as self.
        local open_capture = state.owner["On Key Config Changing"]
        open_capture(state.owner, FName(state.action), 0, 0)
    end)
    if ok then
        log("Forwarded the " .. state.action .. " row click to Palworld's native key capture")
    else
        log("Could not open key capture for " .. state.action .. ": " .. tostring(error_message))
    end
end

local function register_ui_function_hooks()
    if ui_function_hooks_registered then
        return
    end

    local key_settings_path = "/Game/Pal/Blueprint/UI/UserInterface/MainMenu/Option/WBP_Key_Settings.WBP_Key_Settings_C:"
    local ok, error_message = pcall(function()
        RegisterHook(key_settings_path .. "On Key Config Changing", on_key_config_changing)
        -- Blueprint paths run their single hook callback after the function.
        RegisterHook(key_settings_path .. "On Action Key Changed", on_action_key_changed)
        RegisterHook(key_settings_path .. "SetDefault", on_palworld_native_defaults_restored)
        RegisterHook(PATHS.row_class .. ":SetKeyWarning", on_mod_key_warning_updated)
    end)
    if ok then
        ui_function_hooks_registered = true
        log("Enabled native key-capture and live binding hooks")
    else
        log("Could not enable the key-capture hooks: " .. tostring(error_message))
    end
end

local function set_toggle_ads(enabled, should_save)
    enabled = enabled == true
    if config.toggle_ads == enabled and not should_save then
        return
    end

    config.toggle_ads = enabled

    if not enabled then
        if pending_unverified_rmb ~= nil then
            sweep_unverified_right_mouse_aim(pending_unverified_rmb)
            pending_unverified_rmb = nil
        end
        for address, state in pairs(aim_states) do
            if state.latched then
                state.latched = false
                release_shooter_aim_hold(state)
            elseif is_valid(state.shooter) then
                set_shooter_end_aim_disabled(state.shooter, false)
            end
            aim_states[address] = nil
        end
    end

    if should_save then
        save_config()
        log(string.format("Toggle Aim (ADS) changed to %s", enabled and "On" or "Off"))
    end
end

local function create_toggle_ads_row(widget)
    local owner_address = widget:GetAddress()
    local existing = control_rows[owner_address]
    if existing ~= nil and is_valid(existing.row) then
        set_row_label(existing.row, "Toggle Aim (ADS)")
        return
    end

    local row_class = StaticFindObject(PATHS.row_class)
    local library = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
    if not is_valid(row_class) or not is_valid(library) then
        log("The native Control Settings row assets are unavailable")
        return
    end

    local ok, row_or_error = pcall(function()
        local player = widget:GetOwningPlayer()
        local row = library:Create(widget, row_class, player)
        if not is_valid(row) then
            error("Palworld did not create the settings row")
        end

        widget.VerticalBox_KM:AddChild(row)
        row:SetSwitcher(config.toggle_ads)
        set_row_label(row, "Toggle Aim (ADS)")
        return row
    end)

    if not ok then
        log("Could not create the Toggle Aim (ADS) row: " .. tostring(row_or_error))
        return
    end

    local row = row_or_error
    local switch = row.WBP_OptionSettings_ListContentSwitch
    if not is_valid(switch) then
        log("Toggle Aim (ADS) row was created, but its switch is unavailable")
        return
    end

    control_rows[owner_address] = {
        owner = widget,
        row = row,
        switch = switch,
        last_enabled = config.toggle_ads,
    }
    toggle_switches[switch:GetAddress()] = owner_address
    log("Added the native Toggle Aim (ADS) switch")
end

local function on_widget_constructing(context)
    local widget = unwrap(context)
    if class_name(widget) == "WBP_Key_Settings_C" then
        inject_key_rows(widget)
    end
end

local function on_widget_constructed(context)
    local widget = unwrap(context)
    local name = class_name(widget)
    if name == "WBP_Key_Settings_C" then
        finish_key_rows(widget)
    elseif name == "WBP_Control_Settings_C" then
        create_toggle_ads_row(widget)
    end
end

local function on_new_key_settings(widget)
    local prepared = inject_key_rows(widget)
    key_settings_widgets[widget:GetAddress()] = { widget = widget, ready = false }
    ExecuteInGameThreadWithDelay(100, cleanup_persistent_weapon_key_entries)
    log(string.format("Prepared %d/4 keyboard actions for Palworld's settings screen", prepared))
end

local function on_new_control_settings(widget)
    ExecuteInGameThreadWithDelay(50, function()
        if is_valid(widget) then
            create_toggle_ads_row(widget)
        end
    end)
end

local function on_new_option_settings(widget)
    option_settings_widgets[widget:GetAddress()] = {
        owner = widget,
        keycap = nil,
        label = nil,
        visible = false,
    }
    ExecuteInGameThreadWithDelay(100, function()
        if is_valid(widget) then
            ensure_mod_defaults_footer(widget)
        end
    end)
end

local function adopt_existing_settings_widgets()
    -- Hot reload restarts Lua state but does not reconstruct Palworld's already
    -- open Options widgets. Re-adopt those live objects so the F12 footer and
    -- injected key rows are restored without requiring the user to close the
    -- menu or restart the game.
    local option_ok, option_widgets = pcall(function()
        return FindAllOf("WBP_OptionSettings_C")
    end)
    if option_ok and option_widgets ~= nil then
        for _, widget in pairs(option_widgets) do
            if is_valid(widget) then
                local address = widget:GetAddress()
                if option_settings_widgets[address] == nil then
                    option_settings_widgets[address] = {
                        owner = widget,
                        keycap = nil,
                        label = nil,
                        visible = false,
                    }
                end
                ensure_mod_defaults_footer(widget)
            end
        end
    end

    local key_ok, key_widgets = pcall(function()
        return FindAllOf("WBP_Key_Settings_C")
    end)
    if key_ok and key_widgets ~= nil then
        for _, widget in pairs(key_widgets) do
            if is_valid(widget) then
                local address = widget:GetAddress()
                if key_settings_widgets[address] == nil then
                    inject_key_rows(widget)
                    key_settings_widgets[address] = { widget = widget, ready = false }
                end
                local completed = finish_key_rows(widget, false)
                if completed == #KEY_ROWS then
                    key_settings_widgets[address].ready = true
                end
            end
        end
    end

    cleanup_persistent_weapon_key_entries()
end

local function on_key_settings_constructed(context)
    local widget = unwrap(context)
    if is_valid(widget) then
        finish_key_rows(widget)
    end
end

local function on_control_settings_constructed(context)
    local widget = unwrap(context)
    if is_valid(widget) then
        create_toggle_ads_row(widget)
    end
end

local function poll_toggle_switches()
    -- NotifyOnNewObject cannot replay objects that survived a Lua hot reload.
    -- When no Options owner is known, rescan once per second until the live
    -- screen can be adopted and its F12 Restore Mod Defaults footer restored.
    if assets_ready
        and (next(option_settings_widgets) == nil or next(key_settings_widgets) == nil) then
        settings_adoption_poll_ticks = settings_adoption_poll_ticks + 1
        if settings_adoption_poll_ticks >= 4 then
            settings_adoption_poll_ticks = 0
            adopt_existing_settings_widgets()
        end
    else
        settings_adoption_poll_ticks = 0
    end

    for address, state in pairs(option_settings_widgets) do
        if not is_valid(state.owner) then
            option_settings_widgets[address] = nil
        elseif not is_valid(state.keycap) or not is_valid(state.label) then
            ensure_mod_defaults_footer(state.owner)
        else
            -- ensure_mod_defaults_footer also detects Blueprint rebuilds that
            -- leave valid custom objects detached from the live footer.
            ensure_mod_defaults_footer(state.owner)
        end
    end

    for address, state in pairs(key_settings_widgets) do
        if not is_valid(state.widget) then
            key_settings_widgets[address] = nil
        elseif not state.ready then
            local completed = finish_key_rows(state.widget, false)
            if completed == #KEY_ROWS then
                state.ready = true
                log("Added 4/4 native keybind rows")
            end
        end
    end

    for owner_address, state in pairs(control_rows) do
        if not is_valid(state.owner) or not is_valid(state.switch) then
            if is_valid(state.switch) then
                toggle_switches[state.switch:GetAddress()] = nil
            end
            control_rows[owner_address] = nil
        else
            local enabled = read_switch_state(state.switch)
            if enabled ~= nil then
                if state.last_enabled ~= enabled then
                    state.last_enabled = enabled
                    set_toggle_ads(enabled, true)
                end
            end
        end
    end
end

local log_guarded_aim_input

local function on_start_aim(context)
    if not config.toggle_ads then
        return
    end

    local controller = unwrap(context)
    if not is_valid(controller) then
        return
    end

    local is_local = true
    local local_check_ok = pcall(function()
        is_local = unwrap(controller:IsLocalController()) == true
    end)
    if local_check_ok and not is_local then
        return
    end

    local address = controller:GetAddress()
    if aim_guard[address] then
        return
    end

    local now = os.clock()
    local pending = pending_unverified_rmb
    local pending_matches = pending ~= nil
        and pending.input_generation == aim_input_generation
        and (pending.address == nil or pending.address == address)

    local state = aim_states[address]
    if state ~= nil and state.latched then
        if pending_matches then
            pending_unverified_rmb = nil
        end
        state.controller = controller
        state.shooter = get_shooter_component(controller) or state.shooter
        state.priority = get_shooter_aim_priority(state.shooter) or state.priority
        return
    end

    if now < aim_ready_after then
        log_guarded_aim_input("the player session is still loading")
        return
    end
    local gameplay_allowed, blocked_reason = is_gameplay_aim_allowed(controller)
    if not gameplay_allowed then
        log_guarded_aim_input(blocked_reason or "gameplay input is unavailable")
        return
    end

    local shooter = get_shooter_component(controller)
    if not is_valid(shooter) then
        log_guarded_aim_input("Palworld did not provide the local ShooterComponent")
        return
    end
    local can_aim = false
    local can_aim_ok = pcall(function()
        can_aim = unwrap(shooter:CanAim()) == true
    end)
    if not can_aim_ok or not can_aim then
        return
    end

    local priority = get_shooter_aim_priority(shooter)
    if priority == nil then
        log_guarded_aim_input("Palworld has not assigned an aiming priority yet")
        return
    end

    -- Only a native start that passes the same gameplay/CanAim checks as a
    -- real latch verifies the raw input. Rejected roll/menu/spam starts remain
    -- quarantined and fail closed.
    if pending_matches then
        pending_unverified_rmb = nil
    end

    if state == nil then
        state = { controller = controller, shooter = shooter, priority = priority, latched = false, generation = 0 }
        aim_states[address] = state
    end

    state.controller = controller
    state.shooter = shooter
    state.priority = priority
    state.generation = (state.generation or 0) + 1
    state.latched = true
    state.presentation_established = true
    state.initial_press_active = true
    state.armed_at = now
    state.release_observed_at = nil
    state.input_read_failed_at = nil
    last_aim_input_at = now

    -- Only Palworld's native OnStartAim event may create a latch. Raw mouse
    -- input can also arrive while another window or overlay owns focus; using
    -- that path to arm was the source of zoom without a crosshair.
    -- Apply Palworld's own named hold before the physical button is released.
    -- This keeps the original native camera and crosshair presentation alive;
    -- it does not end aim and try to reconstruct only the weapon-ready pose.
    if not set_shooter_end_aim_disabled(shooter, true) then
        state.latched = false
        aim_states[address] = nil
        return
    end
    log(string.format(
        "Toggle Aim is holding Palworld's native ADS presentation; priority=%s",
        tostring(state.priority)
    ))
end

log_guarded_aim_input = function(reason)
    local now = os.clock()
    if now - last_aim_guard_log_at >= 1 then
        last_aim_guard_log_at = now
        log("Ignored Toggle Aim input: " .. reason)
    end
end

local function on_right_mouse_pressed()
    if not config.toggle_ads then
        return
    end

    local input_generation = aim_input_generation
    ExecuteInGameThreadWithDelay(15, function()
        if input_generation ~= aim_input_generation or not config.toggle_ads then
            return
        end
        local controller, _, shooter = find_ready_local_aim_context()
        local address = is_valid(controller) and controller:GetAddress() or nil
        local state = address ~= nil and aim_states[address] or nil

        -- A menu, container, dialog, pause screen, or other UI-owned input
        -- must be completely invisible to Toggle Aim. In particular, do not
        -- create an unverified-input cleanup: calling Palworld's aim-release
        -- functions while UI is open can replay its interaction sound.
        local gameplay_allowed = is_gameplay_aim_allowed(controller)
        if not gameplay_allowed then
            pending_unverified_rmb = nil
            return
        end

        -- Raw RMB is release-only. In particular, never create a latch here:
        -- this callback may observe an activation/background click that the
        -- game correctly rejected as an aim action.
        local now = os.clock()
        if state ~= nil and state.latched then
            -- Do not mistake the async notification for the first physical
            -- press as a second click. Maintenance clears this marker only
            -- after the button has been stably released.
            if state.initial_press_active then
                pending_unverified_rmb = nil
                return
            end
            if read_right_mouse_down(controller) ~= true then
                return
            end

            if now < aim_ready_after then
                return
            end
            last_aim_input_at = now
            pending_unverified_rmb = nil

            state.controller = controller
            state.shooter = shooter or state.shooter
            state.priority = get_shooter_aim_priority(state.shooter) or state.priority
            state.generation = (state.generation or 0) + 1
            state.latched = false
            release_shooter_aim_hold(state)
            log("Toggle Aim latch released by the second right-click")

            local generation = state.generation
            ExecuteInGameThreadWithDelay(50, function()
                local current = aim_states[address]
                if current ~= nil and not current.latched and current.generation == generation then
                    release_shooter_aim_hold(current)
                    aim_states[address] = nil
                    aim_guard[address] = nil
                end
            end)
            return
        end

        local active_pending = pending_unverified_rmb
        if active_pending ~= nil
            and active_pending.input_generation == input_generation
            and active_pending.cleanup_active then
            active_pending.controller = controller or active_pending.controller
            active_pending.shooter = shooter or active_pending.shooter
            active_pending.address = address or active_pending.address
            active_pending.release_cleanup_at = nil
            sweep_unverified_right_mouse_aim(active_pending)
            active_pending.cleanup_performed = true
            return
        end

        -- A duplicate raw notification from a release that was just handled
        -- must not create a quarantine which consumes the next valid aim.
        if state ~= nil and not state.latched
            and now - last_aim_input_at < AIM_DUPLICATE_RAW_WINDOW_SECONDS then
            return
        end

        local existing_pending = pending_unverified_rmb
        if existing_pending ~= nil and existing_pending.input_generation == input_generation then
            -- A repeat press must not reset the original grace period or stop
            -- an active cleanup. It only means key-up is no longer continuous.
            existing_pending.release_cleanup_at = nil
            if not is_valid(existing_pending.controller) and is_valid(controller) then
                existing_pending.controller = controller
                existing_pending.shooter = shooter
                existing_pending.address = address
            end
            return
        elseif existing_pending ~= nil then
            sweep_unverified_right_mouse_aim(existing_pending)
        end

        unverified_rmb_id = unverified_rmb_id + 1
        pending_unverified_rmb = {
            id = unverified_rmb_id,
            input_generation = input_generation,
            address = address,
            controller = controller,
            shooter = shooter,
            created_at = now,
            cleanup_active = false,
            cleanup_performed = false,
            last_cleanup_at = nil,
            release_cleanup_at = nil,
        }
    end)
end

local function on_alt_tab_pressed()
    if not config.toggle_ads then
        return
    end

    -- The native HUD focus notification is authoritative. This shortcut is a
    -- same-frame backup so an active latch is released before Windows finishes
    -- switching away.
    ExecuteInGameThreadWithDelay(0, function()
        handle_application_focus_changed(false, "Alt+Tab moved focus away from Palworld")
    end)
end

local function on_end_aim(context)
    if not config.toggle_ads then
        return
    end

    local controller = unwrap(context)
    if not is_valid(controller) then
        return
    end

    local address = controller:GetAddress()
    if aim_guard[address] then
        return
    end

    local state = aim_states[address]
    if state ~= nil and state.latched then
        if state.initial_press_active then
            -- SetDisableEndAim normally prevents the button-release EndAim
            -- from reaching this hook. If Palworld still reports it, keep the
            -- already-created native presentation held and let maintenance
            -- observe the physical release for second-click readiness.
            apply_shooter_aim_hold(state)
            return
        end

        state.generation = (state.generation or 0) + 1
        state.latched = false
        release_shooter_aim_hold(state)
        aim_states[address] = nil
        aim_guard[address] = nil
        log("Toggle Aim fully released because Palworld ended ADS during another gameplay action")
    end
end

local function on_client_restart(context)
    aim_input_generation = aim_input_generation + 1
    aim_ready_after = os.clock() + AIM_SESSION_WARMUP_SECONDS
    last_aim_input_at = -1000
    if pending_unverified_rmb ~= nil then
        sweep_unverified_right_mouse_aim(pending_unverified_rmb)
        pending_unverified_rmb = nil
    end
    local controller = unwrap(context)
    if is_valid(controller) then
        local address = controller:GetAddress()
        local state = aim_states[address]
        if state ~= nil then
            state.latched = false
            release_shooter_aim_hold(state)
        end
        aim_states[address] = nil
        aim_guard[address] = nil
    end
    if config.toggle_ads then
        log("Player session changed; Toggle Aim input will unlock after a 1.5 second safety warmup")
    end
    schedule_weapon_hud_refresh(2500)
end

local run_self_test

local function load_assets_and_hooks()
    asset_load_attempts = asset_load_attempts + 1
    local loaded = 0
    for _, asset in ipairs(ASSETS) do
        local ok = pcall(function()
            LoadAsset(asset)
        end)
        if ok then
            loaded = loaded + 1
        else
            log("Could not load UI asset: " .. asset)
        end
    end

    local key_class = StaticFindObject(PATHS.key_settings_class)
    local control_class = StaticFindObject(PATHS.control_settings_class)
    local option_class = StaticFindObject(PATHS.option_settings_class)
    local weapon_hud_icon_class = StaticFindObject(PATHS.weapon_hud_icon_class)
    local row_class = StaticFindObject(PATHS.row_class)
    local row_default = StaticFindObject(PATHS.row_default)
    local dialog_class = StaticFindObject(PATHS.dialog_class)
    patch_player_input_keys()
    assets_ready = loaded == #ASSETS
        and is_valid(key_class)
        and is_valid(control_class)
        and is_valid(option_class)
        and is_valid(weapon_hud_icon_class)
        and is_valid(row_class)
        and is_valid(row_default)
        and is_valid(dialog_class)

    if assets_ready then
        if not hud_icon_notification_registered then
            local notification_ok, notification_error = pcall(function()
                NotifyOnNewObject(PATHS.weapon_hud_icon_class, on_new_weapon_hud_icon)
            end)
            if notification_ok then
                hud_icon_notification_registered = true
                schedule_weapon_hud_refresh(100)
            else
                log("Could not monitor rebuilt weapon HUD icons: " .. tostring(notification_error))
            end
        end
        register_ui_function_hooks()
        assets_ready = register_restore_dialog_hooks()
    end

    if assets_ready then
        log(string.format("Verified %d/%d Palworld UI assets", loaded, #ASSETS))
        adopt_existing_settings_widgets()
        if file_exists(SELF_TEST_PATH) and not self_test_scheduled then
            self_test_scheduled = true
            ExecuteInGameThreadWithDelay(6000, run_self_test)
        end
    elseif asset_load_attempts < 30 then
        if asset_load_attempts == 1 or asset_load_attempts % 5 == 0 then
            log(string.format("Waiting for Palworld's options UI (attempt %d/30)", asset_load_attempts))
        end
        ExecuteInGameThreadWithDelay(2000, load_assets_and_hooks)
    else
        log("UI asset verification failed after 30 attempts")
    end
end

run_self_test = function()
    if not file_exists(SELF_TEST_PATH) then
        return
    end
    if not assets_ready then
        log("SELF_TEST_FAIL settings hooks are not ready")
        return
    end

    local controller = FindFirstOf("PalPlayerController")
    if not is_valid(controller) then
        log("SELF_TEST_FAIL no local PalPlayerController was found")
        return
    end

    local library = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
    local key_class = StaticFindObject("/Game/Pal/Blueprint/UI/UserInterface/MainMenu/Option/WBP_Key_Settings.WBP_Key_Settings_C")
    local control_class = StaticFindObject("/Game/Pal/Blueprint/UI/UserInterface/MainMenu/Option/WBP_Control_Settings.WBP_Control_Settings_C")
    local option_class = StaticFindObject("/Game/Pal/Blueprint/UI/UserInterface/MainMenu/Option/WBP_OptionSettings.WBP_OptionSettings_C")
    if not is_valid(library) or not is_valid(key_class) or not is_valid(control_class) or not is_valid(option_class) then
        log("SELF_TEST_FAIL one or more widget classes are missing")
        return
    end

    local ok, widgets_or_error = pcall(function()
        local key_widget = library:Create(controller, key_class, controller)
        local control_widget = library:Create(controller, control_class, controller)
        local option_widget = library:Create(controller, option_class, controller)
        if not is_valid(key_widget) or not is_valid(control_widget) or not is_valid(option_widget) then
            error("widget creation failed")
        end
        key_widget:AddToViewport(0)
        option_widget:AddToViewport(1)
        local construct_ok, construct_error = pcall(function()
            -- The standalone test widget is not hosted by WBP_OptionSettings, so
            -- explicitly enter the current Steam build's generated Construct body.
            key_widget:ExecuteUbergraph_WBP_Key_Settings(4602)
        end)
        if not construct_ok then
            log("SELF_TEST keyboard Construct call failed: " .. tostring(construct_error))
        end
        ensure_mod_defaults_footer(option_widget)
        return { key_widget = key_widget, control_widget = control_widget, option_widget = option_widget }
    end)

    if not ok then
        log("SELF_TEST_FAIL " .. tostring(widgets_or_error))
        return
    end

    ExecuteInGameThreadWithDelay(750, function()
        local verify_ok, result = pcall(function()
            local key_rows = 0
            local prepared_rows = 0
            local template_rows = 0
            local clean_weapon_rows = 0
            local accessibility_keycaps_ok = true
            local placeholder = StaticFindObject(PATHS.row_default)
            for _, definition in ipairs(KEY_ROWS) do
                if widgets_or_error.key_widget[definition.map]:Contains(FName(definition.action)) then
                    prepared_rows = prepared_rows + 1
                end
                local row = map_find(widgets_or_error.key_widget[definition.map], definition.action)
                if is_valid(row) and row:GetAddress() ~= StaticFindObject(PATHS.row_default):GetAddress() then
                    key_rows = key_rows + 1
                    if definition.configure_input then
                        local row_is_clean = true
                        pcall(function()
                            local key_box = unwrap(row.WBP_OptionSettings_ListContentButton)
                            local key_image = unwrap(key_box.Image_Key)
                            local key_canvas = unwrap(key_image:GetParent())
                            local count = unwrap(key_canvas:GetChildrenCount())
                            for index = 0, count - 1 do
                                local child = unwrap(key_canvas:GetChildAt(index))
                                local child_name = child:GetFName():ToString()
                                if string.find(child_name, "PAC_Reset", 1, true) then
                                    row_is_clean = false
                                end
                            end
                        end)
                        if row_is_clean then clean_weapon_rows = clean_weapon_rows + 1 end
                        local saved_key = get_saved_weapon_key(definition.action)
                        local expected_text = get_accessibility_keycap_text(saved_key)
                        local keycap = backtick_keycaps[row:GetAddress()]
                        if expected_text ~= nil then
                            accessibility_keycaps_ok = accessibility_keycaps_ok
                                and keycap ~= nil
                                and is_valid(keycap.text)
                        else
                            accessibility_keycaps_ok = accessibility_keycaps_ok
                                and (keycap == nil or not is_valid(keycap.text))
                        end
                    end
                elseif is_valid(row) and is_valid(placeholder) and row:GetAddress() == placeholder:GetAddress() then
                    template_rows = template_rows + 1
                end
            end

            local control_state = control_rows[widgets_or_error.control_widget:GetAddress()]
            local toggle_row_ok = control_state ~= nil and is_valid(control_state.row)
            local footer_hint_ok = false
            local footer_order_ok = false
            local footer_key_font_size = -1
            local footer_label_font_size = -1
            pcall(function()
                local footer = unwrap(widgets_or_error.option_widget.WBP_PalKeyGuideIcon_Default:GetParent())
                local keycap = unwrap(footer:GetChildAt(1))
                local label = unwrap(footer:GetChildAt(2))
                local footer_state = option_settings_widgets[widgets_or_error.option_widget:GetAddress()]
                local label_font = unwrap(label:GetPropertyValue("Font"))
                footer_label_font_size = label_font.Size
                footer_order_ok = is_valid(keycap)
                    and footer_state ~= nil
                    and is_valid(footer_state.keycap)
                    and keycap:GetAddress() == footer_state.keycap:GetAddress()
                    and keycap:GetClass():GetFName():ToString() == "WBP_PalKeyGuideIcon_C"
                    and is_valid(label)
                    and label:GetFName():ToString() == "PAC_ModDefaultsLabel"
                footer_hint_ok = label:GetText():ToString() == "Restore Mod Defaults"
                    and footer_label_font_size == 14
                    and label_font.TypefaceFontName:ToString() == "Medium"
                    and footer_order_ok
            end)
            local tilde_ok = false
            local default_input = StaticFindObject(PATHS.player_input_default)
            if is_valid(default_input) then
                local enabled_keys = default_input:GetPropertyValue("EnableKeys")
                tilde_ok = enabled_keys:Contains({ KeyName = FName("Tilde") })
            end

            local toggle_persistence_ok = false
            if toggle_row_ok then
                local initial_toggle = config.toggle_ads
                local initial_widget_toggle = read_switch_state(control_state.switch)
                control_state.switch:Switch()
                local changed_widget_toggle = read_switch_state(control_state.switch)
                poll_toggle_switches()
                local changed = config.toggle_ads ~= initial_toggle
                control_state.switch:Switch()
                local restored_widget_toggle = read_switch_state(control_state.switch)
                poll_toggle_switches()
                toggle_persistence_ok = initial_widget_toggle == initial_toggle
                    and changed_widget_toggle == not initial_toggle
                    and restored_widget_toggle == initial_toggle
                    and changed
                    and config.toggle_ads == initial_toggle
            end
            widgets_or_error.key_widget:RemoveFromParent()
            widgets_or_error.control_widget:RemoveFromParent()
            widgets_or_error.option_widget:RemoveFromParent()
            return {
                key_rows = key_rows,
                prepared_rows = prepared_rows,
                template_rows = template_rows,
                clean_weapon_rows = clean_weapon_rows,
                footer_hint_ok = footer_hint_ok,
                footer_order_ok = footer_order_ok,
                footer_key_font_size = footer_key_font_size,
                footer_label_font_size = footer_label_font_size,
                toggle_row_ok = toggle_row_ok,
                tilde_ok = tilde_ok,
                toggle_persistence_ok = toggle_persistence_ok,
                accessibility_keycaps_ok = accessibility_keycaps_ok,
            }
        end)

        if not verify_ok then
            log("SELF_TEST_FAIL " .. tostring(result))
        elseif result.key_rows == 4 and result.clean_weapon_rows == 2 and result.footer_hint_ok and result.toggle_row_ok and result.tilde_ok and result.toggle_persistence_ok and result.accessibility_keycaps_ok then
            log("SELF_TEST_PASS key_bindings=4 inline_resets=0 footer_f12=1 native_wheel_icons=1 toggle_row=1 toggle_persistence=1 tilde_bindable=1")
        else
            log(string.format(
                "SELF_TEST_FAIL key_bindings=%d clean_weapon_rows=%d footer_f12=%d footer_order=%d prepared=%d templates=%d accessibility_keycaps=%d toggle_row=%d toggle_persistence=%d tilde_bindable=%d",
                result.key_rows,
                result.clean_weapon_rows,
                result.footer_hint_ok and 1 or 0,
                result.footer_order_ok and 1 or 0,
                result.prepared_rows,
                result.template_rows,
                result.accessibility_keycaps_ok and 1 or 0,
                result.toggle_row_ok and 1 or 0,
                result.toggle_persistence_ok and 1 or 0,
                result.tilde_ok and 1 or 0
            ))
        end
    end)
end

load_config()
consume_forced_weapon_reset()

if not config.ads_default_off_applied then
    config.toggle_ads = false
    config.ads_default_off_applied = true
    save_config()
    log("Toggle Aim (ADS) was reset to Off for the login-safety update")
end

ExecuteInGameThreadWithDelay(1000, initialize_saved_weapon_bindings)
ExecuteInGameThreadWithDelay(1500, cleanup_persistent_weapon_key_entries)

-- These notifications run immediately after the exact Palworld widget object is
-- constructed. The key map is therefore extended before Palworld builds its rows.
NotifyOnNewObject(PATHS.key_settings_class, on_new_key_settings)
NotifyOnNewObject(PATHS.control_settings_class, on_new_control_settings)
NotifyOnNewObject(PATHS.option_settings_class, on_new_option_settings)
NotifyOnNewObject(PATHS.player_input_class, on_new_player_input)
RegisterHook("/Script/Pal.PalPlayerController:OnStartAim", function() end, on_start_aim)
RegisterHook("/Script/Pal.PalPlayerController:OnEndAim", function() end, on_end_aim)
RegisterHook("/Script/Engine.PlayerController:ClientRestart", on_client_restart)
RegisterHook("/Script/Pal.PalPlayerInput:IsEnableKey", function() end, allow_accessibility_key)
local focus_hook_ok, focus_hook_error = pcall(function()
    RegisterHook(APPLICATION_FOCUS_HOOK, on_application_activation_state_changed)
end)
if focus_hook_ok then
    log("Enabled native Palworld application-focus safety hook")
else
    log("Could not enable native application-focus hook; Alt+Tab safety remains active: "
        .. tostring(focus_hook_error))
end
RegisterKeyBindAsync(Key.F12, on_f12_pressed)
-- The raw callback is release/quarantine-only and can never arm a latch.
-- Palworld's native OnStartAim event is the sole authority for starting ADS.
RegisterKeyBindAsync(Key.RIGHT_MOUSE_BUTTON, on_right_mouse_pressed)
RegisterKeyBindAsync(Key.OEM_THREE, on_tilde_key_pressed)
RegisterKeyBindAsync(Key.TAB, {ModifierKey.ALT}, on_alt_tab_pressed)

ExecuteInGameThreadWithDelay(5000, load_assets_and_hooks)
LoopInGameThreadWithDelay(250, poll_toggle_switches)
LoopInGameThreadWithDelay(50, maintain_toggle_aim_states)

log("Loaded. Settings appear only inside Palworld; no standalone window is used")
