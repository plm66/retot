# Changelog

## v0.6 — Apple Intelligence & Formatting Tools (2026-03-24)

### Apple Intelligence Integration
- **AI Toolbar button (✨)** — Sparkles button with popover for all AI actions
- **Translation** — Select text → Traduire → Apple native translation sheet (on-device, via Translation framework)
- **Résumer** — Summarize selected text or full note via Foundation Models (streaming)
- **Reformuler** — Rephrase selected text with improved style (streaming)
- **Corriger** — Grammar and spelling correction (streaming)
- **AI Assistant** — Chat interface with tool calling: the LLM can search, list, and read your notes
- **Entity extraction** — Extract TODOs, dates, names, and topics from note content (@Generable structured output)
- **Auto-tagging** — Notes are automatically tagged by topic after 10s of inactivity (Foundation Models + @Generable)
- **System instructions** — Centralized French-first persona for all AI interactions
- **Writing Tools** — macOS native Writing Tools enabled via right-click context menu (TextKit 1 panel mode)
- **Model prewarm** — Foundation Models preloaded at app launch for faster first response

### Formatting Tools
- **Text color picker** — Button with color grid popover, applies foreground color to selected text
- **Format Painter** — Capture formatting from one selection, apply to another (one-shot mode with visual indicator)
- **Clear formatting** — New icon (textformat.alt), clears inline colors and note-level font color

### Table Enhancements
- **Add Row Above / Below** — Right-click in a table cell
- **Add Column Left / Right** — Right-click in a table cell
- **Delete Row / Column** — Right-click (protected: can't delete last row or column)

### System Integration
- **macOS Service** — "Send to Retot" in system Services menu: select text in any app → send to a specific note via dot picker dialog
- **Reset text colors** — Available in toolbar and right-click context menu

### UX Improvements
- **Settings compact layout** — Reference sections in 2×2 DisclosureGroup grid, Done/Quit as sticky footer
- **Deployment target** bumped to macOS 15.0 (enables Writing Tools + Translation)

### Fixes
- **applyNoteColors** no longer overwrites per-range foreground colors (was using textView.textColor, now uses typingAttributes)
- **Translation sheet** moved from popover to NoteEditorView for reliable presentation

### Architecture
- New `Retot/AI/` directory with: AIPopoverView, AIResultView, AIAssistantView, AIInstructions, AutoTagger, EntityExtractor, ExtractionResultView, NoteTools, IntelligenceAvailability
- Foundation Models usage wrapped in `#if canImport(FoundationModels)` + `@available(macOS 26.0, *)`

## v0.5 — Floating Notes & Print (2026-03-19)

### Features
- **Floating notes** — Detach any note as an independent floating window (button in DotBar or right-click)
- **Real-time sync** — Floating window shares NSTextStorage with main window, edits appear in both instantly
- **Print / PDF** — Cmd+P or printer icon, with print-friendly white background regardless of note theme
- **Multiple floats** — Open several notes as floating windows simultaneously

### Fixes
- Print forces white background + dark text (no more black page printing)
- Clear note now also clears the NSTextView directly (prevents auto-save ghost content)

### Documentation
- Updated Settings: all shortcuts, toolbar guide, DotBar actions, right-click reference
- CHANGELOG maintained per version

### Roadmap (V2)
- Image resize with drag handles
- iCloud sync (Mac + iPhone)
- Minimap for long notes
- Configurable number of notes (5/10/15)

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
