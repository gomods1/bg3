# Navigation: the one model every screen follows

The user's rule (2026-09-29): keyboard navigation follows what things **mean**, the way a screen
reader user moves through an application, never how the screen **looks**. Every screen, list and
mode of the mod, today and later, uses this model and these keys (the same rule and keys as the
Sims mods, `..\sims4\NAVIGATION.md`). It sits beside the other key rules in CLAUDE.md (one mod menu,
no key per feature): a new feature adds a command, or sections and items to a list; it never
invents its own keys for moving.

## The model

- A screen is a list (`Screens/ListScreen.lua`) of **sections**: a hotbar, a spell level, a kind
  of nearby thing, a history buffer, a group of the mod menu, one container of several open.
  A control carries `section = "<name>"`; consecutive controls with the same name are one section.
- Sections hold **items**. An item may open a deeper **level** (`ListScreen:Push`: a character
  creation section, an inventory section, a journal quest).
- What belongs together comes from meaning: the game's view models and their collections, the
  mod's own data. Nothing is grouped or ordered by screen coordinates (grid geometry is only used
  to aim clicks).

## The keys

| Key | What it does |
|---|---|
| Tab / Shift+Tab | the next / previous section (wraps); says "section, N items", then the item. A list with one section leaves Tab to the game (except message boxes, where it says the button again) |
| Up / Down | previous / next item of the section; no wrap (the end item is said again) |
| Left / Right | the item's value (an option, a spell slot level, a reaction mode); an item without one moves like Up / Down. Difficulty keeps the game's own Left / Right (its preset carousel) |
| Home / End | first / last item of the section |
| Enter, Space, keypad Enter | activate; a section of character creation, the inventory... opens (a level) |
| Escape / Backspace | back up a level; Escape at a mod list's top level closes it (game screens: the game's) |
| a letter | the next item starting with it, in mod lists and sub-lists (says the section when it changes) |
| Ctrl+M, Ctrl+R, Ctrl+D | the mod menu, read the screen, details (CLAUDE.md) |

Game screens that mirror the game's own tabs keep their tabs on Tab (Options): the tabs are that
screen's sections.

## Spatial tools (the only exception)

The place cursor (`Combat/Place.lua`: Jump, areas, Move) moves in space: the arrows one meter
relative to the camera, Shift five, Home back to the character, Enter confirms, Escape cancels.
