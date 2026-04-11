# Changelog

All notable changes to PinayPal Remote will be documented in this file.

## [Unreleased]

### Added
- Placeholder for future changes

## [1.1.0] - 2025-04-12

### Added
- Firebase Cloud Messaging (FCM) integration for push notifications
- Notification settings screen with FCM token display and copy functionality
- Sync check button in backup screen to check PC sync status
- File download functionality for backup files via HTTP from PC app
- Backup schedule sync between Flutter app and PC app via Firebase
- Time picker for backup schedule settings (replaced text input)
- Backup health indicators for Website, Mailchimp, and SQL backups
- Storage breakdown visualization in backup screen
- Quick actions for triggering Website, Mailchimp, and SQL backups
- System monitoring UI in dashboard
- Activity log display in dashboard
- PC status check with animated pulsing indicator
- Backup files list view with search and category filters
- Backup history screen with file management controls
- Local notifications for backup completion and health warnings
- PC status notifications
- Scheduled backup reminders
- Login history tracking for Firebase service
- Two-factor authentication setup with secret key display and copy
- Backup codes display in two-factor setup
- User management screen with invite codes support
- Profile screen with account info and settings

### Changed
- Updated dashboard uptime to show PC app uptime
- Updated disk usage to show total backup size
- Switched position of account info and account settings in profile screen
- Converted backup schedule time to 12-hour format
- Fixed deprecated `activeColor` to `activeThumbColor` in SwitchListTile
- Fixed deprecated `withOpacity` usage throughout the app
- Optimized app bar layout in backup screen
- Reduced pulsing node size in backup screen

### Fixed
- Fixed compilation errors in two_factor_setup_screen.dart
- Fixed null safety compilation errors in backup_screen.dart
- Fixed scrolling issue in backup_screen.dart
- Fixed null check operator error in dashboard screen
- Fixed backup codes layout width and alignment in two_factor_setup_screen
- Fixed loading delay for user management and invite codes buttons in settings screen
- Fixed user management and invite codes buttons not showing in settings screen
- Fixed FormatException in _formatRelativeTime when timestamp is 'Never'
- Fixed animation controller disposal to prevent crash in dashboard
- Fixed undefined _backupHealth reference in backup_screen.dart
- Fixed deprecated 'value' parameters in backup_settings_screen.dart
- Fixed flutter_local_notifications build error by upgrading package version
- Fixed Firebase initialization issue by properly configuring FCM
- Fixed duplicate method definitions in firebase_service.dart
- Fixed duplicate getAutoScanSettings and saveAutoScanSettings methods
- Prevented admin user from being disabled in user management screen
- Isolated and fixed app hang issues

### Technical
- Added firebase_messaging package for FCM
- Added flutter_local_notifications package for local notifications
- Added path_provider package for file download functionality
- Added timezone package for notification scheduling
- Installed flutterfire CLI for Firebase configuration
- Created firebase_options.dart with existing Firebase project
- Updated firebase_options.dart with actual API keys from google-services.json
- Downloaded google-services.json from Firebase Console
- Configured Firebase for FCM push notifications
- Implemented FCM token saving to Firebase for PC app retrieval
- Implemented FCM token refresh handling
- Added Android notification permissions
- Fixed Android core library desugaring for flutter_local_notifications

## [1.0.0] - Initial Release

### Added
- Remote control of FTP, Mailchimp, and SQL backups
- Real-time device status monitoring
- Firebase-powered command relay
- Cross-platform support (Android, iOS, Web)
- User authentication with Firebase
- Dashboard with PC status monitoring
- Backup file management
- Command trigger buttons for backup operations
