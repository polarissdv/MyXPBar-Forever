# MyXPBar - Changelog

## 2.8
- New **reputation bar**: a thin bar under the XP bar with your tracked
  faction, its standing and its progress, in the faction's color. It hides
  itself when no faction is tracked, and replaces the reputation on hover
  while it is shown. Off by default.
- New **XP per hour and time left** under the bar, counted from the moment
  you logged in. Pick a target level in the options (or leave it on "Next
  level"). The XP needed per level is learned as you level up, so the
  estimate for a far away level gets better the more you play.

## 2.7
- Fixed: the Blizzard bars at the bottom of the screen stayed visible on the
  Forever client. Both the XP bar and the reputation / honor bar are hidden
  now, together with the manager that kept showing them again.
- The width slider now goes up to the width of your screen (it stopped at
  1400 px).
- New "Full screen width" option: the bar runs from one edge of the screen
  to the other, at any resolution and UI scale. Move it up or down with
  Shift + drag as usual.
- New "Reputation on hover" option (on by default): mouse over the bar to
  see your tracked reputation (faction, standing, progress). If no faction
  is tracked, a tooltip explains how to pick one.

## 2.6
- Fixed: position, size, colors, style and options were reset after closing
  and restarting the game. The Forever beta never writes the CVar backup to
  disk, so it only covered a relog. The settings are now also kept in one
  account macro named "MyXPBar", which the server stores: they come back
  after a full restart. Keep the macro (it is recreated if deleted).
- Settings are backed up every 5 seconds instead of 20, and a change made
  in combat is saved as soon as combat ends.
- /mxp debug now also shows the macro backup.

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
