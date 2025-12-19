# Changelog

All notable changes to this project will be documented in this file.

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
