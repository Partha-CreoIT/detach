# Changelog

All notable changes to the Detach app will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-12-19

### Added

- Initial release of Detach app
- App blocking functionality with background monitoring
- Timer-based session management
- Pause screen overlay for blocked apps
- Comprehensive permission handling (Usage Access, Overlay, Battery Optimization)
- Modern UI with Material Design 3
- Dark/Light theme support with automatic switching
- Firebase Analytics integration
- Android foreground service for reliable background operation
- App filtering to show only user apps
- Session persistence across app restarts
- Wake lock management for consistent operation
- Service restart capability after system reboots
- Local data storage with SharedPreferences
- Real-time app launch detection and interception
- Guided permission setup flow
- Responsive design for various screen sizes
- Smooth animations and transitions
- Privacy-focused analytics with no personal data collection

### Technical Features

- Android API level 21+ support
- Native integration with UsageStatsManager
- Efficient app filtering algorithms
- Memory and battery optimization
- Robust error handling and data validation
- Automatic service recovery mechanisms

### Known Issues

- Some system apps may appear in app list (automatically filtered)
- Timer sync delay after app restart
- Slight pause screen delay on first app launch

---

## Version History

- **1.0.0+3** - Initial release with core functionality
- **1.0.0+2** - Beta testing version
- **1.0.0+1** - Alpha testing version
- **1.0.0+0** - Development version
