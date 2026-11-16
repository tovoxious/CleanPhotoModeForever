# Clean Photo Mode Forever

A World of Warcraft: **Forever** addon (client 1.60.x, Interface 16001) for clean screenshots.

Press **Toggle User Interface** (`Alt-Z` by default). Along with the normal UI, Clean Photo Mode Forever hides everything the game still draws on top of the world. Press it again and every setting goes back exactly the way you had it.

## What gets hidden

Each group can be switched off in the options. All are on by default.

| Option | What it covers |
| --- | --- |
| Nameplates | Enemy, friendly player and friendly NPC nameplates, the personal resource display, soft-target nameplates, and nameplate addons |
| Unit names and titles | Floating names, guild names and titles over players, NPCs, pets, guardians, minions and totems |
| Chat bubbles | Say, yell, party and raid bubbles, including the ones already on screen |
| Floating combat text | Damage, healing, periodic and pet numbers over targets, your own combat text, threat floaters |
| Soft-target icons | Interact, game object, enemy and friend icons (the interact key itself keeps working) |
| Ground circles and character highlights | Quest unit circles, the find-yourself highlight, the obstructed-character silhouette, the motion sickness focal circle |
| Outlines and loot sparkles | Mouseover and target outlines, sparkles on lootable objects |
| Other addon frames in the game world | Anything an addon attached to the 3D world instead of the normal UI |

## Install

1. Download `CleanPhotoModeForever-vX.Y.Z.zip` from the [latest release](https://github.com/tovoxious/CleanPhotoModeForever/releases/latest).
2. Extract it into `World of Warcraft\_forever_\Interface\AddOns\`. You should end up with `AddOns\CleanPhotoModeForever\CleanPhotoModeForever.toc`.
3. Start the game (or `/reload`) and make sure the addon is enabled in the AddOns list.

(Using **Code > Download ZIP** instead also works, but you'll need to rename the extracted folder from `CleanPhotoModeForever-main` to `CleanPhotoModeForever`.)

Or clone it straight into the AddOns folder:

```bash
git clone https://github.com/tovoxious/CleanPhotoModeForever.git
```

## Usage

- Hide the UI with your Toggle User Interface key. That's it.
- Options: **Esc > Options > AddOns > Clean Photo Mode Forever**, or type `/cpm`.
- `/cpm restore` puts back anything still held by photo mode (there's also a button for this in the options).
- `/cpm status` shows how many settings are currently held.
- `/cleanphoto` works anywhere `/cpm` does.

## How your settings stay safe

- Only settings that are currently **on** get turned off, and the original value of each one is recorded.
- If you change one of them yourself while the UI is hidden (for example toggling enemy nameplates with `V`), your new choice is kept instead of being overwritten.
- Most things switch instantly, even in combat. A few settings the game locks during combat (like the personal resource display) catch up the moment combat ends.
- If the game reloads, crashes or logs out while the UI is hidden, everything is restored automatically on your next login.

## Known limits

- The selection circle under your target and the quest `!` / `?` markers above NPCs are part of the 3D scene. Addons can't hide them. Clear your target (`Esc`) before taking the shot.
- Anything that hides the UI (cinematics, or addons like DialogueUI that hide it during conversations) also turns photo mode on. That's harmless: everything comes back with the UI.
- Made for Forever. It hasn't been tested on Retail or Classic.

## License

[MIT](LICENSE)
