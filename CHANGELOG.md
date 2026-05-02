# Changelog

## Unreleased

### Features
- API token can now be loaded from a file via the `apiTokenPath` setting. When set, file contents (trimmed) take precedence over the inline `apiToken`. Enables declarative configs (e.g. NixOS) without storing secrets in the config tree.

## v1.0.0 - Initial Release

### Features

#### Season Tab
- Browse all anime airing in the current season
- Search/filter anime by title
- Add anime to watchlist with star button
- Visual indicator for watchlist status

#### Today Tab
- View watchlist anime airing today
- Toggle between "Watchlist" (today's anime) and "All" (full watchlist)
- Remove anime from watchlist directly
- Air time and countdown display

#### Bar Indicator
- Three display modes:
  - **Icon Only** - Minimal calendar icon
  - **Icon + Count** - Shows number of watchlist anime airing today
  - **Icon + Countdown** - Shows time until next episode

#### Notifications
- **Instant Notifications** - Get notified when a watchlist episode starts airing
- **Daily Digest** - Morning summary of all watchlist anime airing today
- Configurable digest time (HH:MM format)
- Custom notification icon support (system icons or custom image path)
- Test notification button in settings

#### Data Management
- Persistent watchlist stored locally (`~/.config/quickshell/anime-watchlist.json`)
- Configurable refresh interval (5-60 minutes)
- Automatic data caching
- Rate limiting protection

#### Settings
- API token configuration
- Bar indicator mode selection
- Notification toggles and timing
- Refresh interval slider
- Notification icon customization
- Test notification button

### Technical Details
- Built with QML for QuickShell/DankMaterialShell
- Uses animeschedule.net API for anime data
- Singleton services architecture for state management
- Separate NotificationService to prevent duplicate notifications

---

## Getting Started

1. Install the plugin in your DankMaterialShell plugins directory
2. Get an API token from [animeschedule.net](https://animeschedule.net)
3. Configure the token in plugin settings
4. Start adding anime to your watchlist!

## Known Issues

- None reported yet

## Future Plans

- [ ] Anime detail popup on click
- [ ] Multiple season support
- [ ] Dub/raw timetable support
- [ ] Notification sound customization
- [ ] Widget themes
