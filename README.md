# NEON SURVIVORS: ECHOES OF DAWN — Story V2

Playable Godot 4.3+ Android-oriented prototype.

## Story
In 2189, Earth's colony network goes dark. A mysterious signal promises to bring the missing colonists back. The pilot of the scout ship Искра visits five planets, recovers fragments of a navigation core, and discovers that the signal comes from an archive intelligence called Echo-Prime. It has trapped human consciousnesses in an attempt to preserve them. The final choice is to shut it down and restore freedom to the colonies.

The five planets:
1. Arcadia-9 — dead garden / Root Warden
2. Red Tributary — machine desert / Siege Titan
3. Nyx — frozen moon / Ice Matriarch
4. Veles — ghost city / Archivarius
5. Zero Sun — signal source / Echo-Prime

## Mechanics in this prototype
- Portrait layout and touch joystick
- Auto-targeting and auto-fire
- Three enemy archetypes with planet scaling
- Boss encounter after 85 seconds
- XP, levels and three-choice upgrades
- Five planets with unlock progression
- Coins and a cosmetic skin shop
- Local save using Godot ConfigFile
- Story prologue, mission briefings and ending
- No forced ads, tracking, purchases or network calls

## Run
1. Install Godot 4.3 or newer on a computer.
2. Open `project.godot`.
3. Press F6/F5 to run.
4. For Android, install matching export templates and Android SDK/JDK, configure Editor Settings → Export → Android, then Project → Export → Android.

## Monetization integration (not active yet)
The project intentionally contains no live ads or billing. For a release:
- Add AdMob through a maintained Godot Android plugin.
- Use test ad unit IDs during development.
- Offer opt-in rewarded ads (e.g. revive or double end-of-run coins).
- Do not show ads during combat or before the player expects them.
- Add Google Play Billing for optional cosmetic purchases / season pass.
- Verify purchases server-side where appropriate, implement restore purchases, privacy disclosures, consent and regional requirements.
- Never use real production ad IDs while testing.
