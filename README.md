# Palworld Accessible Controls

A client-side accessibility mod for the Steam version of Palworld. The controls appear directly inside Palworld's native Options screens; there is no standalone app, tray icon, or overlay to keep open.

## In-game controls

Under **Options > Keyboard**:

- Change Weapon Up
- Change Weapon Down
- Rotate Building Left
- Rotate Building Right

Under **Options > Control Settings**:

- Toggle Aim (ADS)

Weapon cycling and building rotation use four separate Palworld actions. Rebinding a building action does not change either weapon action.

On the first v1.0.21 launch, only Palworld's stock `MouseScrollUp` and `MouseScrollDown` mappings for the two added weapon actions are cleared. The new Change Weapon Up/Down rows therefore start blank without removing a custom key you already chose.

The accessibility rows also accept Palworld-omitted keys such as the backtick/tilde key, function keys, and mouse buttons. Escape remains Palworld's menu-cancel key.

Backtick is captured after Palworld closes its key-listening callback. Because Unreal reserves that physical key before Palworld's normal action mappings run, the mod dispatches Palworld's own Change Weapon Up/Down handler directly and renders a centered backtick inside Palworld's native key box.

Accessibility key labels are hit-test invisible, so the native binding box remains clickable. Each weapon row has a tiny `Reset` control tucked inside the left edge of its black binding box. It restores Change Weapon Up to Mouse Wheel Up or Change Weapon Down to Mouse Wheel Down, briefly turns green, and leaves Palworld's original wheel icon visible.

Toggle Aim fully releases when Palworld ends aim during a roll or another gameplay action, preventing the mod from preserving zoom after the game has removed its crosshair presentation.

With Toggle Aim (ADS) enabled, press and release Aim once to keep aiming and press it again to stop. The latch resumes aim on the next input frame so Palworld's normal button-release processing cannot cancel it.

Toggle Aim defaults to Off. Changing worlds or re-entering a game fully releases any previous aim latch before the new player session starts.

Alt+Tab also fully releases the current aim latch before Palworld loses focus. The Toggle Aim setting remains enabled, so the next right-click starts a fresh latch after returning to the game.

Toggle Aim ignores clicks during the first 1.5 seconds of a new player session and debounces clicks closer than 350 ms apart. Accepted aim transitions replay Palworld's full controller-level start after button release so zoom and crosshair initialize together.

When Palworld has more than one controller object during loading, Toggle Aim selects the local controller that currently owns the playable character and shooter instead of relying on the first controller in memory.

Right-clicks are accepted only during active gameplay. A visible menu cursor, ignored look input, or a paused game blocks Toggle Aim; opening one of those states while aim is latched fully releases it.

## Install on Steam

1. Close Palworld.
2. Extract `PalworldAccessibleControls-Steam.zip`.
3. Run `Install Palworld Mod.bat`.
4. Start Palworld through Steam.
5. Accept Palworld's normal mod warning, then open Options.

The installer locates the Steam library, installs the Palworld-compatible UE4SS runtime only when needed, and copies the accessibility mod into the game. It does not install or run a desktop application.

## Build the release package

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\build-native-release.ps1
```

The build script downloads the pinned Palworld UE4SS release, verifies its SHA-256 digest, and creates the distributable zip under `release`.

## Notes

- This is a client-side mod; no dedicated-server install is required for the UI or input behavior.
- Palworld displays its standard Mods Detected warning when any mod is installed.
- Palworld updates can change its UI or input code and may require a matching mod update.
- Back up important saves before using mods, as Palworld itself recommends.

The older standalone Windows app source remains in this workspace for reference, but it is not included in the native-mod release.
