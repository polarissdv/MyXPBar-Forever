# MyXPBar - Changelog

## 2.5
- 6 bar styles: classic, gold framed, segmented, thin line, spark and split
  rested. Pick one in the new Style section, the preview follows.
- Options menu redesigned in the World of Warcraft style: stone frame, gold
  ornaments, gothic titles, Blizzard checkboxes and buttons.

## 2.4
- Smooth bar fill: the bar now slides to its new value instead of jumping.
- Floating "+245 XP" above the bar on every gain, and a flash on level up.
- Both can be turned off in the options menu.
- Lighter: texts are only redrawn when they change, events that fire together
  are merged into one redraw, nothing runs while the bar is hidden, and the
  settings backup is only written when something actually changed.

## 2.3.1
- Fixed: settings were still reset after a relog on the Forever beta (they were
  read back too early, before the game had loaded them).
- New /mxp debug command to check the settings backup.

## 2.3
- Settings are now saved on WoW Forever beta: position, size, colors and options
  no longer reset after a reload or a relog (workaround for the beta bug where
  addon settings are never loaded).
- Added "Made by Polarz141" in the options menu.

## 2.2
- New language switch (FR | EN) in the options menu header.
- The whole addon is translated: menu, tooltips, minimap button and bar texts.
- New custom icon (minimap button, options menu and addon list).

## 2.1
- New options menu with a live preview, opened from the minimap button or /mxp.
- Width and height sliders, background opacity.
- 8 quick colors + color wheel for the XP bar and the rested XP.
- Toggles: lock the bar, hide the Blizzard XP bar, sound on XP gain,
  texts on the bar, rested text, minimap button.
- Recenter the bar / reset everything.
- Minimap button: left click for options, right click to lock, drag to move.
- Settings are saved per account.

## 2.0
- Updated for World of Warcraft: Forever (1.60.x, Interface 16001).
- Hides the default Blizzard XP bar and gives it back at max level.
- Max level detected automatically.
- XP numbers with thousands separators.
- Fixed the background and the XP gain sound on the modern client.
