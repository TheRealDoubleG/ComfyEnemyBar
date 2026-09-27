# ComfyEnemyBar

**Version 0.1 – Beta**  
**Target: World of Warcraft: Forever 1.60.1 / Interface 16001**  
Author: **TheRealDoubleG**  
Discord: **the.real.double.g**

Lightweight enemy nameplate information bars for WoW Forever.

## Scope

A deliberately small enemy-nameplate layer: health, level/classification and target emphasis. It is not intended to become a Plater clone.

ComfyEnemyBar is developed specifically for **WoW: Forever**. Retail/Modern WoW, Midnight and WoW Classic are not compatibility targets.

## 0.1 Beta

- Added lightweight enemy nameplate overlays.
- Added health percentage, level/classification and target highlight options.
- Protected/secret unit health values are never compared in Lua.

## Design notes

Plater's long history shows that nameplates become fragile when aura scripting and client-specific behavior are mixed together. ComfyEnemyBar starts with a small Forever-only surface and expands only after in-client testing.

The referenced third-party addons were used only to study public feature ideas, long-term bug patterns and architecture lessons. ComfyEnemyBar uses original Comfy Suite code and Blizzard UI assets; it does not copy their code or artwork.

## Commands

- /comfyenemybar
- /ceb

## Comfy Suite

The addon follows Comfy Suite UI standard generation 2: Settings immediately before Info, per-character/account/custom saved profiles, movable/lockable settings window, opacity controls and the shared Info layout.
