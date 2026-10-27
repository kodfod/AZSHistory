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
- The extra lives, the rerolls and the magnets that you used.
- The summons that you used.
- The buffs that the game reported, with the time that each buff was active.
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
| `/runs key <key>` | Sets a key that opens or closes the window. Example: `/runs key F8`. |
| `/runs key none` | Removes the key. |
| `/runs tz <hours>` | Sets your time zone in hours from UTC. Example: `/runs tz -5`. |
| `/runs help` | Shows the commands. |

The commands `/runhistory` and `/azh` do the same thing as `/runs`.

You can also open the window with these controls:

- Click the book button on the minimap. Drag the button to move it.
- Push the key that you set with `/runs key`.

To close the window, push Escape. To move the window, drag its top area.

## Trends

Push Trends at the top of the run list to see charts for all the runs that show in the list. The filters and the class button change which runs the charts use.

- Spells: the spells that you picked most, and the average part of your damage from each spell.
- Jewelry: the jewelry that you wore most, and your average damage per second with each item.
- Zones: the zones that you played most, with your wins, and your average damage per second in each zone.
- Classes: your runs and your average damage per second for each class.

The damage charts compare runs of one class only. Choose a class with the class button to see them. Push a run in the list to go back to the run.

## Change the words of the window

You can change the words that the addon writes. You do not change the game files.

The file `Strings.lua` in the addon folder lists all the words of the addon. The file `Custom.lua` is the file for your changes.

1. Open `Strings.lua`. Find the line with the words that you want to change. Example: `["Delete run"] = "Delete run",`
2. Copy the line into `Custom.lua`, between the two braces.
3. Change the words on the right side of the equals sign. Example: `["Delete run"] = "Remove run",`
4. Save the file. Start the game again. The addon reads the file when it loads.

Follow these rules:

- Do not change the words on the left side. The addon uses them to find the line.
- Keep the codes `%s`, `%d`, `%.0f` and `%%` in the same order. They show names and numbers. If a code is not correct, the addon uses the English words.
- A new version can change the English words on the left side. A line in `Custom.lua` can then stop working. Compare your lines with `Strings.lua` after you update.
- When you update the addon, keep your `Custom.lua` file.
- The names of spells, talents, zones, bosses and items come from the game. They show in the language of the game. They are not in these files.

## Limits

- The game loads addons only in a run. You cannot open the window from the main menu. Open the window before you move at the start of a run. The run clock does not start until you move.
- The game shows its end screen above all addon windows. Close the end screen before you open the history.
- The Key Bindings page of the game does not show addon key bindings. Use `/runs key` to set a key for the window.
- The game gives times in UTC. Use `/runs tz` to set your time zone.
- The addon has its own list of spell names and icons for buffs. The list comes from the data of the game. A buff that is not in the list shows as `Spell` and its number.
- The window shows the names of the game (spells, talents, zones, bosses, items and messages) in the language that the game uses now. The addon uses only the translations of the game. All other text of the addon is in English. Some long spell descriptions stay in the language that the game used during the run.

## Saved data

The addon keeps its data in this file: `benilla-config/saved/AZSHistory.lua`. The addon keeps your last 50 runs that are not starred. When a run ends and there are more than 50, the addon deletes the oldest run that is not starred. The addon never deletes a starred run.

To keep a run, select the run and push Star run. Push Unstar run to remove the star. A gold bar shows at the left of each starred run. Push Starred to show only the starred runs.

To delete one run, select the run and push Delete two times.

## License

This addon uses the MIT license. Refer to the `LICENSE` file.
