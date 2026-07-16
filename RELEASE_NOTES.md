# Palworld Accessible Controls v1.0.55

## Highlights

- Restores Change Weapon Up to Mouse Wheel Up and Change Weapon Down to Mouse Wheel Down without storing duplicate Palworld weapon overrides.
- Keeps Palworld's contextual building rotation on its original controls while allowing the weapon actions to share the wheel safely.
- Clears saved custom weapon keys and stale persistent entries when F12 Restore Mod Defaults or Palworld's native Restore to Default is confirmed.
- Prevents the intentional shared-wheel default from blocking the Settings screen with a "key already in use" error.
- Saves accepted custom weapon keys across restarts and refreshes the weapon-switch prompt below the weapon HUD.
- Restores an individually cleared weapon row to its original wheel direction.
- Re-adopts already-open Options and Keyboard widgets after a UE4SS Lua hot reload, including the F12 Restore Mod Defaults footer.

## Restore Mod Defaults

Open **Options > Keyboard**, press **F12**, and confirm Yes. Only these four mod-added rows are reset:

- Change Weapon Up
- Change Weapon Down
- Rotate Building Left
- Rotate Building Right

Unrelated Palworld controls are left unchanged.

## Included accessibility controls

- Toggle Aim (ADS)
- Separate weapon-switch and building-rotation actions
- Backtick/tilde, function-key, mouse-button, and mouse-wheel binding support
- Native Palworld key boxes, confirmation dialogs, and Settings footer integration

## Compatibility

- Palworld for Steam on Windows
- Client-side installation
- Packaged with the pinned Okaetsu/RE-UE4SS Palworld runtime
