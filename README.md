# orca-modules

Project-owned remakes/reskins of external scripts for the AudioCrafter/Orca shell.

## Load

```lua
-- Unnamed ESP (Orca edition): draggable window, switches, unload button
loadstring(game:HttpGet("https://raw.githubusercontent.com/sudodc2/orca-modules/main/orca-esp.lua"))()

-- Infinite Yield (Orca skin): same code, dark rounded UI, pinned bottom-right
loadstring(game:HttpGet("https://raw.githubusercontent.com/sudodc2/orca-modules/main/infiniteyield.lua"))()
```

- `orca-esp.lua` — clean-room rewrite of Unnamed ESP in Orca style. RightShift hides the menu, red footer button unloads everything.
- `infiniteyield.lua` — verbatim Infinite Yield source + Orca skin block (dark palette, rounded corners, bottom-right anchor).