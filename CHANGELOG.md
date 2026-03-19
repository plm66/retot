# Changelog

## v0.4 — UX Polish (2026-03-19)

### Features
- **Undo/Redo buttons** — Toolbar arrows for visual undo/redo
- **Pin to top** — Keep Retot above all windows (works across app switches)
- **Clear note with confirmation** — Trash icon + "Are you sure?" dialog
- **Copy note content** — Right-click dot to copy rich text to clipboard
- **Duplicate to...** — Right-click dot to duplicate content to another note
- **Dynamic window title** — Shows "Retot — Note Label (Dot N)"
- **Cmd+S manual save** — With "Saved" green feedback in footer
- **Cmd+W** hides window, **Cmd+N** jumps to first empty note
- **Menu bar badge** — Shows active dot number next to icon
- **Double-click rename** — Double-click a dot label to edit inline
- **Delete Table** — Right-click on any table to remove it
- **Tooltips** — All toolbar icons show descriptive tooltip on hover
- **Shortcuts reference** — Full keyboard/toolbar/right-click guide in Settings
- **RTFD storage** — Images now persist (screenshots, pasted images)

### Fixes
- Pin-to-top stays visible when switching apps (hidesOnDeactivate fix)
- Clear note removes both RTFD and legacy HTML (no more ghost content)
- Empty notes show green LED indicator (visible in dark mode)

### Roadmap (V2)
- **Floating notes** — Detach any dot as an independent floating window
- **iCloud sync** — Cross-device note synchronization
- **Minimap** — Sublime Text-style content overview for long notes
- **Drag & drop dots** — Reorder or copy notes by dragging dots

## v0.3 — Pastilles & Polish (2026-03-19)

### Features
- **Pastilles** — Select text, click the pastille button to create a movable content block. Right-click to move it to another note (inserted at the top)
- **Global search** — Search across all 10 notes. Click the magnifying glass in the toolbar or Cmd+Shift+F
- **Smart paste** — Paste HTML tables from browsers and markdown tables from terminal, automatically rendered as native tables
- **Keyboard shortcuts** — Cmd+1 through Cmd+0 to switch notes instantly
- **Theme selector** — Force Light or Dark mode independently of system settings (in App Settings)
- **NSWindow migration** — Proper resizable window with title bar, replaces the limited MenuBarExtra panel
- **Onboarding** — First launch shows a Welcome guide with flowform logo and shortcuts table

### Improvements
- Dot labels now expand with window width (no more "claudec..." truncation)
- Search icon moved to the Editor Toolbar (with formatting tools)
- Note footer shows dot number, label, line/char/word counts, time ago, tags

## v0.2 — Rich Editor (2026-03-18)

### Features
- **Font size controls** — +/- buttons in toolbar (8pt to 72pt, 2pt steps)
- **Table insertion** — Toolbar button creates 3x3 NSTextTable with styled header row
- **Color pickers** — Per-note font color and background color (12-color palette)
- **Tags** — Add/remove tags per note, visible in footer and NoteSettings
- **Wiki links** — Type [[Note Name]] to create clickable links between notes
- **Quit button** — In App Settings
- **RAM monitor** — Live memory usage display in App Settings
- **Bulk export/import** — Export all notes as Markdown + metadata JSON

### Improvements
- NoteSettings with ScrollView, larger fonts (title2/headline), bigger color swatches (32px)
- App icon: flowform graphic, cropped to fill frame
- build-and-run.sh script for quick build+install to /Applications

## v0.1 — Foundation (2026-03-17)

### Features
- macOS menu bar app with 10 colored note dots
- Rich text editor (bold, italic, underline, strikethrough, headings, bullet lists)
- NSTextView with RTFD support (images, drag & drop)
- Per-note color selection (10 preset colors)
- HTML-based storage in ~/Library/Application Support/Retot/
- Markdown export per note
- Dark/Light mode text color normalization
