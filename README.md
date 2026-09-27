# ComfyEnemyBar

**Version 0.4 – Beta**  
**Target: World of Warcraft: Forever 1.60.1 / Interface 16001**  
Author: **TheRealDoubleG**  
Discord: **the.real.double.g**

Lightweight enemy nameplate information bars for WoW Forever.

## Scope

A focused enemy-nameplate enhancer for health, resources, aura visibility and compact combat information. It is not intended to become a Plater clone.

ComfyEnemyBar is developed specifically for **WoW: Forever**. Retail/Modern WoW, Midnight and WoW Classic are not compatibility targets.

## 0.3 Beta

- Health bars now use reaction colors: hostile red, neutral yellow, friendly green.
- Friendly and neutral nameplates are handled as well as hostile nameplates when Blizzard exposes them.
- Added optional threat bar using WoW Forever's native threat APIs.
- Threat bar can sit above health or below the resource bar.
- Threat text can show percent, raw value, both, or be hidden.
- Threat bar color follows WoW's threat-state colors.

## 0.2 Beta

- Uses the Blizzard enemy health bar as the single health bar instead of drawing a second one.
- Optional mana/resource bar directly below the health bar.
- Buffs and debuffs can be enabled/disabled independently.
- Comfy aura rows sit directly next to the health/resource bars; Blizzard's own nameplate aura frame is suppressed while ComfyEnemyBar is active to avoid duplicates.
- Health text modes: off, percent, current, or current + percent.
- Resource text modes: off, percent, current, or current + percent.
- Health/resource text can be centered in the bar or placed to the left.
- Configurable health-bar width/height and aura icon size.
- Secret/protected values are never formatted or compared in Lua.

## 0.1 Beta

- Initial lightweight enemy nameplate overlay.
- Health percentage, level/classification and target highlight.

## Design notes

Plater's long history shows that nameplates become fragile when aura scripting and client-specific behavior are mixed together. ComfyEnemyBar starts with a small Forever-only surface and expands only after in-client testing.

The referenced third-party addons were used only to study public feature ideas, long-term bug patterns and architecture lessons. ComfyEnemyBar uses original Comfy Suite code and Blizzard UI assets; it does not copy their code or artwork.

## Commands

- /comfyenemybar
- /ceb

## Comfy Suite

The addon follows Comfy Suite UI standard generation 2: Settings immediately before Info, per-character/account/custom saved profiles, movable/lockable settings window, opacity controls and the shared Info layout.
