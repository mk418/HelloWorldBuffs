# HelloWorldBuffs

A World of Warcraft Classic Era addon that tracks **world buffs across all
your characters**. Log in on any alt and see at a glance which of your
characters still have Rallying Cry, Spirit of Zandalar, Songflower, the DM
tributes, Warchief's Blessing, or a DMF buff — and how long is left on each.

## What it does

- Every time your buffs change, the addon snapshots your active world buffs
  (using their server-relative expiration time) to an account-wide saved
  variable.
- A single window lists every character that has ever logged in with the
  addon, in a grid: one row per character, one column per world buff.
- Class-coloured character names. Live countdown ticks while the window is
  open.

## Usage

- `/hwb` — toggle the main window
- `/hwb refresh` — re-snapshot the current character's buffs
- `/hwb reset` — wipe the database

Left-click the minimap button to open the window. Right-click it for options.

## Status

Initial scaffold. Tracks the canonical Classic Era world buffs (Rallying
Cry, Spirit of Zandalar, Songflower, Warchief's Blessing, DM tributes, DMF
Sayge's Dark Fortunes). Chronoboon awareness is stubbed but the meta-aura
is captured per character.
