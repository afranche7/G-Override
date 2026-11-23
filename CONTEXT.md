# G-Override

Turns the spare buttons on a Logitech G502 into shortcuts for working with the Claude desktop app, on Windows and macOS.

## Language

**Button**:
One of the spare physical mouse buttons G-Override uses: G6 (the sniper button), G7 or G8.
_Avoid_: key, mouse key

**Trigger Key**:
The keystroke a **Button** emits, as stored in the **Onboard Profile** (by default F17 for G6, F18 for G7 and F19 for G8). It's the only thing a **Helper** listens for.
_Avoid_: hotkey, shortcut, binding

**Onboard Profile**:
The button-to-key mapping saved in the mouse's own memory, so it travels with the mouse between machines.
_Avoid_: G HUB profile, software profile

**Helper**:
The per-OS background program that turns **Trigger Keys** into **Actions**: AutoHotkey on Windows, Hammerspoon on macOS.
_Avoid_: daemon, agent, script

**Action**:
One user-visible thing a **Helper** does in response to a **Trigger Key**: **Focus Claude**, **Send to Claude**, **Region Snip**, **Window Snip** or **Prompt Palette**.
_Avoid_: command, macro

**Focus Claude**:
The **Action** that brings the **Claude App** to the front, returns to the previous window if Claude is already in front, and launches Claude if it isn't running.

**Send to Claude**:
The **Action** that puts the current **Selection** into the **Claude App**'s prompt as a fenced block with its source. If there is no **Selection**, it falls back to a **Region Snip**.

**Region Snip** / **Window Snip**:
**Actions** that capture a dragged region, or the active window, and paste the image into the **Claude App**'s prompt.

**Prompt Palette**:
The searchable menu of **Palette Entries** opened at the cursor.

**Palette Entry**:
One item in the **Prompt Palette**: a title plus either text to insert into the prompt (optionally auto-submitted) or a capture **Action** to run.

**Selection**:
Text the user had highlighted in the active app when a **Button** was pressed. It's captured by sending that app's copy key.

**Claude App**:
The Claude desktop application, as opposed to the `claude` CLI, which may run in terminals with the same executable name.
_Avoid_: Claude, the CLI

## Relationships

- Each **Button** emits exactly one **Trigger Key**, defined by the **Onboard Profile**
- A **Helper** maps each **Trigger Key** to exactly one **Action**
- **Send to Claude** and the **Prompt Palette** both capture the **Selection** first
- Every **Action** that pastes into the **Claude App** restores the user's clipboard afterwards and never submits, unless a **Palette Entry** is marked to send

## Example dialogue

> **Dev:** "When I press G7 in the terminal with nothing selected, does it kill my build?"
> **Domain expert:** "No. The **Helper** uses the terminal's own copy key, so there's no interrupt. With no **Selection**, **Send to Claude** falls back to a **Region Snip**."

## Flagged ambiguities

- "Claude" was used for both the desktop app and the CLI. Resolved: the **Claude App** is always the desktop app, and **Focus Claude** must never pick a CLI window.
