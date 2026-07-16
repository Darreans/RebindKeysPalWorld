# Palworld Accessible Controls v1.0.55

This client-side Steam mod adds accessibility controls directly to Palworld's native Options UI. It does not run a standalone window, tray icon, or overlay.

## In-game settings

Under **Options > Keyboard**:

- Change Weapon Up
- Change Weapon Down
- Rotate Building Left
- Rotate Building Right

Under **Options > Control Settings**:

- Toggle Aim (ADS)

Change Weapon Up defaults to Mouse Wheel Up, and Change Weapon Down defaults to Mouse Wheel Down. Building rotation remains a separate contextual action and can continue using the same wheel directions.

Custom weapon bindings are saved in `config.ini`, restored at launch, and reflected by the weapon-switch prompt below the weapon HUD. Clearing an individual weapon row removes that saved override and immediately restores the row's original wheel direction.

The added rows accept backtick/tilde, function keys, mouse buttons, and mouse-wheel directions that Palworld normally omits. They use Palworld's native key-icon boxes and do not add per-row Reset buttons.

## Restore Mod Defaults

While the Keyboard page is visible, press **F12 Restore Mod Defaults** and confirm Yes. This clears only the four mod-added row overrides:

- Weapon switching returns to Mouse Wheel Up/Down.
- Building rotation returns to Palworld's original defaults.
- Stale persistent weapon entries are removed so intentional wheel sharing does not block closing Settings.

Palworld's built-in **F Restore to Default** still resets the Keyboard page normally. The mod also clears its two saved weapon overrides, rebuilds the wheel mappings, and refreshes the rows and weapon HUD from that callback.

## Toggle Aim

With Toggle Aim enabled, press and release Aim once to keep Palworld's native ADS and crosshair active. Press Aim again to stop.

The latch releases when Palworld ends aim, a menu or dialog owns input, the game is paused, the Palworld window loses focus, or the player changes sessions. Only a valid native Palworld Start Aim action can create the latch; background, overlay, and menu clicks are ignored.

## Requirements

- Palworld for Steam on Windows
- A compatible UE4SS runtime

The packaged player release includes the pinned Palworld UE4SS runtime. A source checkout does not; `build-native-release.ps1` downloads and verifies it while creating the release package.

This is an unofficial client-side community mod. Game updates can change Palworld's UI or input code and may require a matching mod update.
