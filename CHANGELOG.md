# Changelog

## 1.4 — 2026-10-29

- Works with the Harbor hub: Inlet's settings appear in Harbor and changes made there apply right away. With Harbor installed, Settings… in the menu opens Inlet's page there.
- Signed with the Harbor certificate, so macOS keeps Inlet's permissions across updates.
- A small Settings button next to the battery in the expanded island.
- Much lighter on battery: near-zero CPU while music plays (was ~7–16%). Level bars run on Core Animation, Music/Spotify changes arrive via their notifications instead of polling every second, scripts are compiled once, hover uses a small sensor window instead of a global mouse monitor, and timers allow the system to coalesce wakeups.
- Privacy: while the Mac is locked, the island only opens to Now Playing — calendar and tray stay hidden.
- Track names containing unusual characters no longer break Now Playing.
- Weather data is credited to Open-Meteo (CC BY 4.0) in Settings, About and on the website.

## 1.3 — 2026-10-28

- English and Turkish, following the system language, with a language picker in Settings → General.
- A new, simpler website.
- The everyday island is a normal window again; a twin window covers the lock screen. This fixes file drag-and-drop onto the island.
- Lock screen: a near-square Now Playing card (or a compact one), scaled to the display, and two configurable small widgets — Focus, weather, battery or next event.

## 1.2

- Lock-screen Now Playing card with shuffle and output indicator.
- Dragging a file toward the notch opens the tray page directly.
- Fixed spurious "AirPods connected" notices caused by short background Bluetooth links.

## 1.1

- File tray and AirDrop drop zones.
- Island on the lock screen with an unlock animation.
- Quick timer, Bluetooth device notices and a Caps Lock indicator.

## 1.0

- The island: hover, click and two-finger swipe to open, spring animations.
- Now Playing for Apple Music and Spotify.
- Volume and brightness HUDs, charging and low-battery alerts, today's calendar events.
