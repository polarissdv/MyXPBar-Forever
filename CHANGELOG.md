# MyXPBar - Changelog

## 4.6
- **Picking a font works.** The drop-down of 4.4 never opened in game, and
  4.5 moved it into the menu without fixing it: a list that floats over the
  menu is only drawn where the client agrees to draw it, and it failed
  silently, with no error to read. There is no floating list any more. The
  fonts are buttons in the page, eight at a time, each written in the font
  it picks, with arrows when another addon brought more than eight. Buttons
  in a page are what every other picker of the menu uses, and those work.
- The fake client in `tools/` now picks a font and turns the page, and
  fails the run if the setting does not change. Shipping a picker that
  cannot pick is what it is there to stop.

## 4.5
- **The font list of 4.4 never opened.** It was built in the game's own
  frame rather than in the menu, at a layer the client never put on screen,
  and a timer closed it behind your back. It belongs to the menu now, sixty
  layers above it, and it closes when you click elsewhere or pick a font.
- **The cards no longer run under the bottom row.** A card kept its padding
  but the page did not count it, so the last one of a page, the texture on
  the first page, slid behind the language and profile line.
- **The menu looks finished on a short page**: the pages are drawn on an
  area of their own, a shade darker, and the list of pages runs the whole
  height beside it instead of floating as a small box.
- The cross at the top right is a square with an edge like every other
  field, and turns red under the mouse. The two columns of checkboxes have
  room to breathe.
- Under the hood: `tools/` now holds a fake WoW client that loads the addon
  outside the game, clicks every button, ticks every box and measures the
  menu. The bug above would have been caught by it; from now on it runs
  before a release.

## 4.4
- **The separate rested strip is a measure of its own.** With the Split
  rested style it started where the XP bar ends and ran past it, which read
  as a second XP bar and told you nothing. It fills with the rested XP you
  actually have now: full means a level and a half, all the game lets you
  pile up. Reported by Dream777.
- **That strip can sit above the bar** instead of under it: the new "Rested
  strip above" option, beside the styles.
- **Every font of LibSharedMedia** is in the font list, under the five of
  the addon, when another addon brought the library along. The list is a
  drop-down now, each line written in the font it picks, and it scrolls.
  Nothing is embedded: without the library the five fonts are all there is.
  Asked for by Dream777.

## 4.3
- **The options menu got the look it was missing.** Flat and dark, with a
  slim bar at the top instead of the crest and the big gothic name, the
  pages listed down the left in a panel of their own, and every section of
  settings inside a card: a darker box with a one pixel edge. The checkboxes
  are small squares, the buttons flat fields, the sliders a dark rail with a
  purple fill and the number in a field on the right.
- **Purple instead of gold.** Everything the menu used to draw in gold, from
  the section titles to the colour swatches, follows the purple the bar
  wears out of the box.
- Nothing about the bar changed. Same styles, same textures, same settings,
  same profiles: this is the window you set them in, not what you get on
  screen.

## 4.2
- **A new options menu.** The two columns of widgets are gone: the settings
  are sorted into five pages listed down the left side - the bar, the texts,
  size and colours, the options, the reputation - and the menu shows one at
  a time. It is a third narrower than before, as tall as its tallest page,
  and it stays that size whatever is added later, instead of growing with
  every release.
- The reputation settings live together now, their colour included, and the
  settings about the texts of the bar sit with the font and the text size.
- Nothing about the bar itself changed: same styles, same textures, same
  settings, same profiles.

## 4.1
- **The font of the bar is yours.** Five fonts of the game in the new FONT
  section: the default one, Bold, Arial Narrow, Morpheus and Skurri, each
  button written in the font it picks. Nothing to download, they are in
  every client, and a client missing one keeps the text it had. Bold is
  thick and outlined, so the texts of a small bar stand out over whatever
  is behind them. Asked for by Dream777.
- The What's new panel lists everything 4.0 and 4.1 brought, for the
  players coming from 3.9.

## 4.0
- **Center the bar on one axis.** Two buttons under "Recenter the bar"
  center it horizontally or vertically and leave the other axis exactly
  where you put it: the bar under the minimap keeps its height and lands in
  the middle of the screen, or the other way round. Written and sent in by
  aformagin.
- **The texts of the bar are yours.** A size from 70 to 150 % for every text
  of the bar, and a switch for each one of the three: the level on the left,
  the XP numbers in the middle, the percentage on the right. A small bar
  under the minimap no longer has to choose between a wall of text and no
  text at all. Asked for by Tinter.
- **A colour of its own for the reputation bar**, instead of the colour of
  the standing: the new "Own reputation color" option, with the colour
  picked in the Colors section. The reputation bar beside a purple XP bar
  is told apart at a glance now.

## 3.9
- **The close button of the options menu works on every client.** The strip
  that lets you drag the menu spans its whole top at the very same frame
  level as the cross, so which of the two got the click was up to the client.
  The cross has its own level above the strip now, and closes the menu itself
  instead of relying on the button template. Same for the What's new panel.

## 3.8
- **The reputation bar can sit beside the XP bar** instead of under it: the
  new "Reputation beside the bar" option moves it to the right, at the same
  height, so it costs no vertical space at all. Asked for by a player who
  keeps the bar under his hotbars, where space is a premium. Ignored while
  the bar runs the full width of the screen, since there is no room left.
- **The reputation bar wears the chosen style**, like the XP bar: the gold
  frame and its shine, the separators of the segmented style, and the thin
  line, which it follows down to the bottom of the bar. The decorations of a
  style are built once now and applied to both bars.
- **New "Reputation only" option**: the bar shows your tracked faction
  instead of the XP at any level, not only at max level. With no faction
  tracked there is nothing to show, so the bar goes and the Blizzard one
  stays hidden with it.
- A switch flicked in the options now applies while the menu is open. The
  menu keeps the bar on screen so it can be styled where there is no XP left
  to show, and that was hiding what "Reputation only" did until you closed it.

## 3.7
- **Profiles have names.** Create one from the bar you have in front of you,
  give it a name, and pick it again on any character: the list sits at the
  bottom of the options menu, next to the language. "New" makes one from what
  is on screen, "Delete" removes the one in use and sends the characters that
  had it back to the first one.
- **Nothing to save.** Move the bar, change a colour, a texture, an option:
  it goes into the profile that character uses, right away. Another character
  picking the same profile gets the same bar, and a character that picks
  another one keeps its own.
- **Your settings were kept.** What every character shared becomes the first
  profile, and a character that had its own settings in 3.6 keeps them as a
  profile of its own, named after the character.
- The "Character profile" checkbox of 3.6 is gone: picking a profile in the
  list is what gives it to a character now.
- The minimap tooltip says which profile is in use, and the list of profiles
  names the character it is about.

## 3.6
- **One profile per character.** Move the bar on one character and your others
  keep theirs. Position, size, colours, style, texture, every option: a
  character can have its own set, or use the ones shared by the whole account:
  that is the new "Character profile" option, whose tooltip names the character
  and says which settings are in use. Two buttons at the bottom of the menu
  copy the shared settings onto this character, or turn what you see into the
  shared settings. Everything you had set up before becomes the shared profile,
  so nothing moves on any character.
- **A switch for the bar.** The new "Bar enabled" option hides the bar at any
  level, without disabling the addon - and without the bar of the game taking
  its place, as long as "Hide Blizzard XP bar" is checked. Four ways to reach
  it: the option, a middle click on the minimap button, a key of your own
  (Game Menu > Key Bindings > MyXPBar), and `/mxp off` / `/mxp on`.
- **Reputation at max level.** Instead of simply disappearing at max level, the
  bar can show your tracked faction, standing and progress, in the place of the
  XP. Optional, off by default, and the bar still disappears when you track no
  faction.
- **The addon tells you when it was updated.** One line in the chat and a short
  "What's new" panel, once per version and never again. `/mxp news` opens it
  whenever you want, and "Announce updates" turns the whole thing off.
- The language is now saved for the whole account, next to the profiles, so it
  no longer changes from one character to the next.
- **The narrow options menu is gone**, and with it the "Wide options menu"
  option from 3.2. Stacked in one column the menu was around 1240 units tall
  where a screen offers 768: its lower half, the buttons included, was out of
  reach. The menu is always two columns side by side now.
- Asked for by a player on CurseForge. Thank you.

## 3.5
- **Bar textures.** Eleven of them: the game's own one, plus ten drawn for
  the addon - glaze, satin, minimal, glass, bevel, tube, brushed, linen,
  diagonal and ember. They are chosen from a drop-down that shows each
  texture under its name, wearing your own bar colour, and they apply to
  the XP bar, the rested part, the finished quests and the reputation bars
  alike.
- Asked for by a player on CurseForge. Thank you.

## 3.4
- **A fill that no longer depends on the frame rate.** The bar moved by a
  slice of the time between two images: it crawled when the game stuttered
  and rushed on a fast machine. The same gain now takes the same time
  whatever happens on screen.
- **The numbers climb with the bar.** The XP and the percentage are drawn
  from the bar itself while it fills, instead of jumping to the total the
  moment the kill lands.
- **Levelling up runs to the end of the bar**, flashes there, then starts
  the new level from an empty bar, instead of snapping back to the left.
  (Needs the smooth fill option, and the XP of the level you just finished,
  which the addon learns while you play.)
- The floating "+245 XP" rises quickly then slows down, and only fades at
  the very end instead of from the start.

## 3.3
- **Moving the bar now works the way the unlock message says it does.**
  Unlocking it was not enough: you also had to hold Shift, or keep the
  options menu open, and nothing on screen said so. Unlocked now simply
  means draggable. Shift still works, it is just no longer required.
- The lock description, the unlock message in the chat and the hint at the
  bottom of the options say what to do, in all 7 languages.
- Thanks to the player who reported being unable to move the bar.

## 3.2
- The options menu is now **two columns side by side** instead of one very
  tall column: it no longer runs from the top to the bottom of the screen.
  Same look, same ornaments, just a better layout.
- New **Wide options menu** option: uncheck it to get the old narrow menu
  in one column.

## 3.1
- The percentage on the right of the bar now shows, in gold and in
  parentheses, where your **finished quests** will take you once turned in
  (for example `41.9% (45.9%)`). When there is no finished quest waiting,
  the parentheses go back to the rested XP projection, as before.
- Thanks to Celai for the idea.

## 3.0
- **The addon now speaks 7 languages**: English, French, German, Spanish,
  Portuguese, Russian and Italian.
- The two FR / EN buttons are replaced by a **drop-down list** with every
  language, in the Language line of the options menu.
- The language of your game client is picked automatically the first time,
  and you can change it at any moment: every text updates right away.
- Russian gets a font that can show Cyrillic, since the gothic title font
  of the menu only has it on the Russian client.
- The new translations were made by the author, not by native speakers:
  corrections are welcome on the CurseForge page or on GitHub.

## 2.9
- New option **XP of finished quests** (off by default): the XP of the
  quests you finished but did not turn in yet shows on the bar in gold, and
  under it ("Quests: +4 050 XP"), with "level X once turned in" when it is
  enough to level up. Hover the bar for the list of quests and their XP.
- The reputation bar now updates on every reputation gain, not only on the
  next XP gain.

## 2.8.1
- Fixed: with the reputation bar shown, the rested text and the "level X in
  ~Y min" line were hidden behind it. They now always sit under the lowest
  bar, centered, and the time left takes the place of the rested line when
  there is no rested XP.

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
