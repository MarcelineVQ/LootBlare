# Loot Blare 1.1.10.1

Loot Blare is a World of Warcraft addon originally designed **Turtle WoW**.
This is a version edited to fit Kulový Blesk soft reserve system.

This addon displays a pop-up frame showing items and rolls when a single uncommon+ item is linked in Raid Warning. Rolls are automatically sorted by type to streamline the master looter's workflow.

### Features:
- Soft Reserve + import
  You can import your SR as a CSV file in this format:
  Name|Item|Points;

- Sync between addon users (WIP)
  Whenever master looter imports a new SR or a new member joins after the SR was uploaded the addon uses a private channel to sync the SR list

- Soft Reserve distinguishment (WIP)
  Whenever someone rolls on SR their roll will be distinguished by a different colour

- MS+1 (WIP)
  You can mark players in your raid with MS+1 through a table. If someone has some points they will be shown in the roll table.

Changelog:

- **1.1.10.1**: Added Kulový blesk SR import and bonus point support
- **1.1.10**: Prevent blare window from closing due to timeout for the Master Looter
- **1.1.9**: Add communication using CHAT_MSG_ADDON events
- **1.1.8**: Remove announce message after each roll. Added time announce message after changing master loot
- **1.1.7**: Added class colors, autoClose option, and config commands. Only show frame if the sender is the ML. Ignore rolls after the time has elapsed. Get FrameShowDuration from the ML.
- **1.1.6**: Simple Buttons and Tooltips.
- **1.1.5**: Added button for SR and roll type order and color.
- **1.1.4**: Added more buttons for OS and Tmog. Now only registers the first roll of each player.
- **1.1.3**: Added MainSpec Button for rolling.

___
Contributors:
* [Siventt](https://github.com/Siventt/LootBlare)
* [SeguisDumble](https://github.com/SeguisDumble)
* [Weird Vibes](MarcelineVQ/LootBlare)
