# Loot Blare 1.1.13

Loot Blare is a World of Warcraft addon originally designed **Turtle WoW**.
This is a version edited to fit Kulový Blesk soft reserve system.

This addon displays a pop-up frame showing items and rolls when a single uncommon item is linked in Raid Warning. Rolls are automatically sorted by type to streamline the master looter's workflow. If the item as soft reserved the roll will have appropriate bonus added to it. It also allows for MS+ points to be allocated by the master looter, which are automatically used in MS rolls.

### Features:
#### Soft Reserve + import
  You can import your SR as a CSV file in this format:
  ```
  Name|Item|Points;
  Name|Item|Points;
  Name|Item|Points
```

Another option is to use https://raidres.fly.dev CSV format

```
ID,Item,Boss,Attendee,Class,Specialization,Comment,Date,"Date (GMT)",SR+
ID,"Item",Boss,Name,Warrior,Arms,,"01/01/2025, 00:00:00","DATE"
ID,"Item",Boss,Name,Warlock,Affliction,,"01/01/2025, 00:00:00","DATE"
```

#### Sync between addon users
  Master looter automatically syncs SR list between users using CHAT_MSG_ADDON events. SR list sync happens whenever the sr list is imported, new player joins the raid and player enters the instance. If a user comes 
  online after a disconnect they will automaticaly request a master looter and SR list sync.

#### Soft Reserve distinguishment
  Whenever someone rolls on SR their roll will be distinguished by a different colour

#### MS+1 (WIP)
  You can mark players in your raid with MS+1 through a table. If someone has some points they will be shown in the roll table.

Changelog:

- **1.1.13**: Added MS+ support, RaidRes supported import, Advanced Syncing, Data Persistency, SFX, Sync Queue, Various Fixes
- **1.1.12**: Added Disconnect and Master Looter sync requests (User is not present for setting of master loote)
- **1.1.11**: Added SR list sync, fixed minimap button, distinguished between MS and SR
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
* [Martinez](https://github.com/realMartinez?tab=repositories)
* [Siventt](https://github.com/Siventt/LootBlare)
* [SeguisDumble](https://github.com/SeguisDumble)
* [Weird Vibes](MarcelineVQ/LootBlare)
