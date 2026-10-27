# AZS Run History

AZS Run History is an addon for Azeroth Survivors. It records each run that you play. It shows your past runs in a window in the game.

## What the addon records

For each run, the addon records this data:

- The class, the hero, the zone and the result of the run.
- The time, the level, the kills, the damage and the gold.
- The spells and the ranks that you got, and the time that you got them.
- The rings, the trinkets and the amulet that you wore, with their stats.
- The talents that did damage or healing during the run.
- The loot that dropped. The window shows new items first.
- The talent experience and the talent points that you got.
- The zones that you opened and the achievements that you got.
- The damage and the healing of each spell and talent.
- A timeline of the bosses, the levels and the picks.

The addon does not keep a run that did not start. If you enter a zone and leave before the run starts, the addon does not record that run.

## Install

1. Download the `AZSHistory` zip file from the Releases page.
2. Extract the zip file.
3. Put the `AZSHistory` folder in this folder: `benilla-config/AddOns/`.
4. Start the game. Make sure that the addon is on in the AddOns options.
5. Start a run. The addon loads at the start of the next run.

## Use

| Command | Result |
| --- | --- |
| `/runs` | Opens or closes the history window. |
| `/runs minimap` | Shows or hides the minimap button. |
| `/runs tz <hours>` | Sets your time zone in hours from UTC. Example: `/runs tz -5`. |
| `/runs help` | Shows the commands. |

The commands `/runhistory` and `/azh` do the same thing as `/runs`.

You can also open the window with these controls:

- Click the book button on the minimap. Drag the button to move it.
- Set a key for "Run History" in the key bindings.

To close the window, push Escape. To move the window, drag its top area.

## Limits

- The game loads addons only in a run. You cannot open the window from the main menu. Open the window before you move at the start of a run. The run clock does not start until you move.
- The game shows its end screen above all addon windows. Close the end screen before you open the history.
- The game gives times in UTC. Use `/runs tz` to set your time zone.

## Saved data

The addon keeps its data in this file: `benilla-config/saved/AZSHistory.lua`. The addon keeps a maximum of 200 runs. When there are more than 200 runs, the addon deletes the oldest run.

To delete one run, select the run and push Delete two times.

## License

This addon uses the MIT license. Refer to the `LICENSE` file.
