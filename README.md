# Palworld Accessible Controls

Current release: **v1.0.55**

Palworld Accessible Controls is a client-side accessibility mod for the Steam version of Palworld. It adds controls directly to Palworld's native Options screens. There is no standalone application, tray icon, or overlay to keep running.

## Features

Under **Options > Keyboard**:

- Change Weapon Up
- Change Weapon Down
- Rotate Building Left
- Rotate Building Right

Under **Options > Control Settings**:

- Toggle Aim (ADS)

Weapon switching and building rotation use separate actions. Rebinding a building action does not change a weapon action.

Change Weapon Up defaults to **Mouse Wheel Up**, and Change Weapon Down defaults to **Mouse Wheel Down**. The same wheel directions remain available for building rotation in building mode. The mod handles this intentional shared-wheel default without leaving duplicate saved weapon entries that prevent the Settings screen from closing.

Custom weapon keys are saved across restarts. After an accepted weapon rebind, the mod refreshes Palworld's weapon-switch prompt below the weapon HUD to show the newly assigned key icon. Clearing an individual weapon row removes its saved override and restores that row's original wheel direction.

The added rows accept keys Palworld normally omits, including backtick/tilde, function keys, mouse buttons, and the mouse wheel. Escape remains Palworld's menu-cancel key. The rows use Palworld's native key-icon box and do not add a separate Reset button to each row.

## Restoring defaults

While **Options > Keyboard** is visible, the footer shows **F12 Restore Mod Defaults**. Press F12 and confirm Yes to reset only the four mod-added rows:

- Change Weapon Up returns to Mouse Wheel Up.
- Change Weapon Down returns to Mouse Wheel Down.
- Rotate Building Left and Rotate Building Right return to Palworld's original defaults.
- Saved custom weapon overrides and conflicting persistent entries are removed.

Unrelated Palworld controls are not changed by F12.

Palworld's built-in **F Restore to Default** resets the Keyboard page normally. The mod also uses that native reset callback to clear its saved weapon overrides, rebuild the wheel mappings, and refresh the two weapon rows and weapon HUD.

## Toggle Aim behavior

Enable **Toggle Aim (ADS)** under Control Settings. Press and release the normal Aim button once to keep Palworld's native ADS and crosshair active. Press Aim again to stop.

Toggle Aim defaults to Off. It fully releases when:

- Palworld ends aim during a roll or another gameplay action.
- A menu, container, dialog, or pause screen owns input.
- The Palworld window loses focus, including Alt+Tab.
- The player changes worlds or enters a new game session.

Only a valid native Palworld Start Aim action can create the latch. Background, overlay, and menu clicks cannot start it or consume the next valid gameplay click.

## Install on Steam

The source-code archive from GitHub does not contain the generated runtime payload. Players should use the versioned release asset.

1. Download `PalworldAccessibleControls-Steam-v1.0.55.zip` from the GitHub Releases page.
2. Close Palworld.
3. Extract the entire ZIP.
4. Run `Install Palworld Mod.bat` from the extracted folder.
5. Start Palworld through Steam.
6. Accept Palworld's normal Mods Detected warning, then open Options.

The installer locates the Steam library and adds the bundled Palworld-compatible UE4SS runtime only when `UE4SS.dll` is absent. If UE4SS is already installed, the existing runtime is preserved. The installer then copies this mod into `Pal\Binaries\Win64\ue4ss\Mods\PalworldAccessibleControls`.

## Uninstall

1. Close Palworld.
2. Run `Uninstall Palworld Mod.bat` from the extracted release folder.

The uninstaller removes only Palworld Accessible Controls. It preserves the shared UE4SS runtime in case another mod uses it.

## Build from source

From PowerShell, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build-native-release.ps1
```

The first build requires internet access unless the pinned runtime is already present under `.cache`. The script downloads the pinned Palworld UE4SS release, verifies its SHA-256 digest, and creates the player package under `release`.

Repository layout:

- `NativeMod/PalworldAccessibleControls/Scripts/main.lua` - the UE4SS Lua mod.
- `NativeMod/PalworldAccessibleControls/config.ini` - clean default configuration.
- `NativeMod/Installer` - install and uninstall scripts included in player releases.
- `build-native-release.ps1` - reproducible release-packaging script.
- `RELEASE_NOTES.md` - changes in the current version.
- `SHA256SUMS.txt` - checksum for the matching release asset.

## Developer hot reload

The installed Lua mod can be reloaded during development by focusing Palworld and pressing **Ctrl+R**, which reloads all UE4SS mods. v1.0.55 re-adopts Options and Keyboard widgets that survive the Lua reload, including the F12 Restore Mod Defaults footer.

This is a development workflow only. Normal installation and updates should be performed with Palworld closed.

## Notes

- Steam for Windows is required.
- This is a client-side mod; no dedicated-server installation is required for its UI or input behavior.
- Palworld updates can change UI or input code and may require a matching mod update.
- Back up important saves before using mods, as Palworld recommends.

## License and third-party runtime

The mod and installer source are available under the MIT License in `LICENSE`.

Packaged releases bundle the Okaetsu/RE-UE4SS Palworld runtime. Its license is included inside the player package at `Payload/Win64/ue4ss/LICENSE`.

This is an unofficial community project and is not affiliated with or endorsed by Pocketpair.
