# PinayPal Remote

A Flutter mobile app for remotely controlling PinayPal Backup Manager on your PC.

## Features

- Remote control of FTP, Mailchimp, and SQL backups
- Real-time device status monitoring
- Firebase-powered command relay
- Cross-platform (Android, iOS, Web)

## Setup

### 1. Firebase Configuration

1. Download `google-services.json` from Firebase Console
2. Place it in `android/app/` directory

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Run the App

```bash
flutter run
```

## Usage

1. Login with your username (same as PC app)
2. View your registered devices
3. Tap command buttons to trigger backup operations on your PC

## Supported Commands

- FTP Sync / FTP Backup
- Mailchimp Sync / Mailchimp Backup
- SQL Sync / SQL Backup

## Firebase Database Structure

```
users/{username}/devices/{deviceId}/commands/{commandId}
```

## PC App Integration

The PC app (PinayPal Backup Manager) must be running and connected to Firebase to receive commands.
