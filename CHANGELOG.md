# Changelog

All notable changes to this project will be documented in this file.

## [0.3] - 2025-12-23 - Discord Embeds & Architecture Overhaul
### Added
- **Discord Rich Embeds:** Highlights sent to Discord now use beautiful "Embed" cards with gold side-bars, containing formatted quotes, chapter info, page numbers, and dates in the footer.
- **Improved Preview UI:** The text preview in Queue and Archive menus is now cleaner, stripping internal IDs/Tags while preserving formatting.
- **Network Helper:** Complete modernization of the networking layer for better stability and error handling.
- **Book-like Formatting:** Highlights are now formatted with proper paragraph indentation (using Em Spaces) for a more pleasant reading experience. Note: Rich text formatting (bold/italic) is currently stripped to ensure compatibility.
- **Highlight Navigation:**
    - **Go to Page:** Added a button to "Go to Page" for any highlight in the Archive or Queue.
    - **History Support:** Jumping to a highlight saves your previous position, so you can easily "Go Back" (swipe or menu) to continue reading where you left off.
- **Stable Page Numbers:** Automatically detects if "Stable Page Numbers" are enabled in KOReader and displays the print page number (e.g., `📄 Print Page: 405 of 480 [84%]`) alongside the percentage.

### Changed
- **Codebase Refactoring:** Massive cleanup of `main.lua`.
    - Centralized dependencies and network calls.
    - Simplified Settings Manager using metaprogramming patterns.
    - Unified logic for background sender and manual sender (standardized message composition).
- **Telegram Downloader:** Rewritten to use the new Network helper, improving reliability and error reporting when fetching books.
- **Performance:** Optimized memory usage by lazy-loading heavy libraries (socket, json, lfs) only when needed.

## [0.2] - 2025-12-20 - Archive, Spoilers & Stability
### Added
- **Highlight Archive:** Browse all highlights (default as well) in the current book!
    - **Menu Item:** New "Book Highlights" option in the main Errol menu.
    - **Browser:** Lists all your past highlights.
    - **Actions:** Send any old highlight again—normally or as a **spoiler**. Supports **offline queue** like standard sending.

### Fixed & Improved
- **Text Truncation:** Removed incorrect limit that cut non-English text too short.
- **UI Overflow:** Long quotes in preview dialogs are now truncated safely (full text still sent).
- **Queue Optimization:** Implemented memory caching to reduce disk reads.

## [0.1.1] - 2025-12-19 - Spoiler Mode
### Added
- **Spoiler Mode:** Mark highlights as spoilers!
    - **Telegram:** Sends blurred text (`<span class="tg-spoiler">`).
    - **Discord:** Sends hidden text (`||text||`).
- **Main Menu UI:** "Mark as Spoiler" toggle has been added to the main menu for quick access.
- **Context Menu:** New "Errol: Spoiler" button to force-hide a specific highlight without changing global settings.

## [0.1] - 2025-12-19 - Initial Release

### Added
- **Multi-Platform**: Support for sending highlights to Telegram and Discord.
- **Offline Mode**: Automatic queuing of highlights when offline, with background sync.
- **Queue Manager**: Dedicated menu to view, manage, and send pending highlights.
- **Book Downloader**: Fetch and download book files sent to the Telegram bot.
- **Settings**: Customizable date formats, check intervals, and "Tools" menu integration.
