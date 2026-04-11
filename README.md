# PinayPal Remote

<div align="center">

A Flutter mobile application for remotely controlling the PinayPal Backup Manager on your PC.

[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?logo=dart)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Cloud%20Database-FFCA28?logo=firebase)](https://firebase.google.com)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

</div>

## 📱 Features

### Core Functionality
- **Remote Backup Control**: Trigger FTP, Mailchimp, and SQL backups remotely from your mobile device
- **Real-time PC Status Monitoring**: Monitor your PC's connection status, uptime, and system health
- **Firebase Command Relay**: Securely send commands to your PC via Firebase Realtime Database
- **Cross-Platform Support**: Works on Android, iOS, and Web

### Advanced Features
- **Push Notifications**: Receive FCM notifications for backup completion, health warnings, and PC status updates
- **Two-Factor Authentication (2FA)**: Enhanced security with TOTP and backup codes support
- **Backup Health Monitoring**: Visual indicators for Website, Mailchimp, and SQL backup health
- **Backup Scheduling**: Configure and sync backup schedules between mobile app and PC
- **File Management**: View, search, and download backup files directly from your mobile device
- **Activity Logs**: Track login history and backup activities
- **User Management**: Admin features for managing users and invite codes
- **Device Remembering**: Secure device authentication with 30-day expiration

### User Interface
- **Dashboard**: Comprehensive overview with system monitoring, activity logs, and quick actions
- **Backup Screen**: Detailed backup status, health indicators, and storage breakdown
- **Profile Screen**: Account information, settings, and security options
- **Settings Screen**: App configuration, notification preferences, and user management
- **Notification Settings**: FCM token management and notification preferences

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.0 or higher
- Dart SDK 3.0 or higher
- A Firebase project with Realtime Database enabled
- Android Studio / VS Code with Flutter extensions
- For Android: Android SDK with API level 21+
- For iOS: Xcode 14+ (macOS only)

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/yourusername/pinaypal_remote.git
cd pinaypal_remote
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Firebase Configuration**

#### Android Setup
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or use an existing one
3. Add an Android app with your package name
4. Download `google-services.json`
5. Place it in `android/app/` directory
6. Add the following to `android/build.gradle`:
```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.3.15'
    }
}
```
7. Add the following to `android/app/build.gradle`:
```gradle
apply plugin: 'com.google.gms.google-services'
```

#### iOS Setup
1. In Firebase Console, add an iOS app
2. Download `GoogleService-Info.plist`
3. Place it in `ios/Runner/` directory
4. Add the following to `ios/Runner/Info.plist`:
```xml
<key>FirebaseAppDelegateProxyEnabled</key>
<false/>
```

#### Web Setup
1. In Firebase Console, add a Web app
2. Copy the Firebase configuration
3. Update `lib/firebase_options.dart` with your configuration

4. **Run the app**
```bash
flutter run
```

## 📖 Usage

### First-Time Setup

1. **Launch the App**: Open PinayPal Remote on your device
2. **Login**: Enter your username (same as your PC app username)
3. **2FA Setup** (if enabled): 
   - Scan the QR code with your authenticator app
   - Enter the verification code
   - Save your backup codes securely
4. **Grant Permissions**: Allow notification permissions for push notifications

### Dashboard Navigation

- **PC Status**: View your PC's online status with animated indicator
- **Quick Actions**: Trigger immediate backups for FTP, Mailchimp, or SQL
- **System Monitoring**: View uptime, disk usage, and backup health
- **Activity Log**: Recent backup activities and system events

### Backup Management

1. **View Backups**: Navigate to the Backup screen
2. **Check Health**: Monitor backup status with color-coded indicators
3. **Trigger Backups**: Use quick action buttons for immediate backups
4. **Schedule Backups**: Configure automated backup schedules
5. **Download Files**: Access and download backup files from your PC

### Settings & Configuration

- **Notification Settings**: Manage FCM token and notification preferences
- **Profile**: Update account information, change username/password
- **Security**: Enable/disable 2FA, view login history
- **User Management**: (Admin only) Manage users and generate invite codes

## 🏗️ Architecture

### Project Structure

```
lib/
├── firebase_options.dart       # Firebase configuration
├── main.dart                   # App entry point
├── screens/                    # UI screens
│   ├── splash_screen.dart
│   ├── main_screen.dart
│   ├── dashboard_screen.dart
│   ├── backup_screen.dart
│   ├── backup_settings_screen.dart
│   ├── backup_history_screen.dart
│   ├── profile_screen.dart
│   ├── settings_screen.dart
│   ├── notification_settings_screen.dart
│   ├── two_factor_setup_screen.dart
│   ├── two_factor_login_screen.dart
│   ├── change_username_screen.dart
│   ├── change_password_screen.dart
│   ├── login_history_screen.dart
│   ├── user_management_screen.dart
│   └── invite_codes_screen.dart
├── services/                   # Business logic
│   ├── firebase_service.dart   # Firebase operations
│   └── notification_service.dart # Push notifications
└── utils/                      # Utilities
    ├── app_theme.dart          # App theming
    └── theme_mode_inherited.dart # Theme mode management
```

### Firebase Database Structure

```
pinaypal-backup-manager-default-rtdb.firebaseio.com/
├── users/
│   ├── {username}/
│   │   ├── PasswordHash
│   │   ├── Salt
│   │   ├── Username
│   │   ├── backup_schedule
│   │   ├── backup_status
│   │   ├── commands/
│   │   ├── connection/
│   │   │   ├── status
│   │   │   ├── lastSeen
│   │   │   ├── ipAddress
│   │   │   └── port
│   │   ├── fcm_token
│   │   ├── health_thresholds
│   │   ├── system_status
│   │   └── auto_scan
├── 2fa/
│   ├── {username}/
│   │   ├── SecretKey
│   │   ├── BackupCodes
│   │   └── IsEnabled
├── login_history/
│   ├── {username}/
│   │   ├── {timestamp}/
│   │   │   ├── success
│   │   │   ├── deviceId
│   │   │   ├── deviceInfo
│   │   │   ├── ipAddress
│   │   │   └── userAgent
└── remembered_devices/
    ├── {username}/
    │   ├── {deviceId}/
    │   │   ├── expirationDate
    │   │   └── createdAt
```

### Key Components

- **FirebaseService**: Handles all Firebase operations including authentication, command relay, and data synchronization
- **NotificationService**: Manages FCM token registration and local notifications
- **Screens**: Each screen handles its own state and UI logic
- **AppTheme**: Centralized theming with light/dark mode support

## 🔐 Security

- **Password Hashing**: Uses SHA-256 with salt for secure password storage
- **Two-Factor Authentication**: TOTP-based 2FA with backup codes
- **Device Remembering**: Secure device authentication with expiration
- **Firebase Security Rules**: Implement appropriate rules to protect user data
- **Login History**: Tracks all login attempts for security auditing

## 🔧 Dependencies

- `flutter`: Flutter SDK
- `firebase_database`: Firebase Realtime Database
- `firebase_core`: Firebase core functionality
- `firebase_messaging`: FCM for push notifications
- `shared_preferences`: Local storage
- `crypto`: Cryptographic functions
- `http`: HTTP requests
- `fl_chart`: Chart visualization
- `flutter_local_notifications`: Local notifications
- `timezone`: Timezone support
- `path_provider`: File system access
- `image_picker`: Image selection

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow Flutter/Dart style guidelines
- Write clean, documented code
- Test on multiple platforms when possible
- Update the CHANGELOG.md for significant changes

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase for the backend services
- The open-source community

## 📞 Support

For issues, questions, or contributions:
- Open an issue on GitHub
- Contact: [your-email@example.com]

## 🔗 Links

- [PinayPal Backup Manager (PC App)](https://github.com/yourusername/pinaypal-backup-manager)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Flutter Documentation](https://flutter.dev/docs)

---

<div align="center">

Made with ❤️ by [Your Name]

</div>
