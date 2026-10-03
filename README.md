# RPS Toolbar

A customizable, theme-aware icon toolbar for REAPER. Open, focus, and close **ReaBrowse**, **ReaDrumXT**, **ReaRoll**, and **ReaSpect**, with resizable icons, configurable button order and visibility, automatic REAPER theme detection, and custom colors.

Developed by **Davvo**. [Contact and support](https://forum.cockos.com/showthread.php?t=311768).

## Install with ReaPack

1. Install [ReaPack](https://reapack.com/) if needed.
2. Install **ReaImGui 0.10 or newer** and **JS_ReaScriptAPI** through ReaPack. RPS Toolbar uses the ReaImGui 0.10 API binding.
3. In REAPER, open **Extensions → ReaPack → Import repositories** and paste:

   ```text
   https://raw.githubusercontent.com/davvolinni-ui/RPS-Toolbar/main/index.xml
   ```

4. Open **Extensions → ReaPack → Browse packages**, find **RPS Toolbar**, select **Install**, and apply.
5. Run **RPS Toolbar - ReaBrowse, ReaDrumXT, ReaRoll and ReaSpect launcher** from REAPER's main Action List.

Install the apps you want to control separately and register their main scripts in REAPER's main Action List. The toolbar does not bundle or install them. You can hide buttons for apps you do not use.

## Controls

- **Left-click:** open an app, or focus its existing window and activate its dock tab.
- **Right-click:** close the existing app window. No context menu or termination-dialog fallback.
- **Vertical dots:** open Settings.
- **Resize the toolbar window:** scale the icons. Buttons always show icons only; hover tooltips identify the apps.

The toolbar can be docked using REAPER's normal ReaImGui docking controls.

## Settings

**Appearance:** follow REAPER's theme automatically, import its colors with Auto Detect / Dark / Light, choose Dark / Light / FL Studio presets, or customize individual colors. Display contrast safeguards protect icons in normal, hover, and pressed states. Manual edits disable automatic following so your choices persist.

**Buttons:** check or uncheck each app to show or hide its button. Use Up / Down to arrange them; changes persist across restarts. Horizontal order runs left to right, vertical order top to bottom. Hidden apps keep their position, and Settings remains accessible even when all apps are hidden.

**Applications:** rescan registered scripts, or enter a specific action command ID when several copies are installed. Right-click an action in REAPER's Action List to copy its command ID. Map the action to the exact copy you use.

Startup diagnostics distinguish the synchronous action call from click-to-visible-window time. Window appearance does not confirm full app readiness. A launch guard prevents repeated action invocations while an app starts, including after a toolbar restart. Clear a failed launch guard in Settings only if the app failed to start.

## Limitations

This is an initial public release. Offline checks cover launch guards, direct closing, dock activation, responsive layout, button order and visibility, and theme contrast. Complete live validation across operating systems and REAPER configurations is still pending.

Other scripts control their own startup work; the toolbar cannot guarantee an instant launch. Windows must be identifiable for focus and closing. Startup checks use exact titles temporarily; the toolbar does not continuously enumerate native windows or automatically force focus.

## Manual installation

Keep `RPS Toolbar.lua`, `src/`, and `EULA.md` together. In REAPER's main Action List, choose **New action → Load ReaScript** and load `RPS Toolbar.lua`. The old `RPS Tool Bar.lua` entry is a compatibility wrapper for earlier local installations; new users should use the renamed script.

## License

Copyright © 2026 Davvo. All rights reserved. Free to use for personal or commercial music and audio work under the [End User License Agreement](EULA.md). This is not an open-source license. Read the EULA before installing or using.

REAPER, ReaImGui, JS_ReaScriptAPI, and the controlled apps are separate products governed by their own licenses.

## Development

Run `tools/run_offline.py` with Python and Lupa's Lua 5.4 runtime available in `tools/.deps` or on the Python path. This does not launch REAPER or modify projects. The optional `tools/check.lua` harness requires a separate isolated REAPER profile.

`tools/build_index.py` creates a ReaPack index with source URLs pinned to a Git commit. Commit all release files first, then generate and commit `index.xml`; verify the pinned revision contains every listed file before pushing. Published versions should not be replaced with different files under the same version number.
