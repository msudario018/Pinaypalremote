# PinayPal Remote - Setup Guide

## Prerequisites

1. Flutter SDK installed on your machine
2. Android Studio or VS Code with Flutter extension
3. Firebase account with the pinaypal-backup-manager project

## Setup Steps

### 1. Install Flutter Dependencies

Open terminal in the project directory and run:

```bash
cd "D:\Flutter Project Remote\pinaypal_remote"
flutter pub get
```

### 2. Configure Firebase

1. Go to Firebase Console: https://console.firebase.google.com/
2. Select your project: `pinaypal-backup-manager`
3. Add Android app:
   - Package name: `com.example.pinaypal_remote`
   - Download `google-services.json`
4. Place `google-services.json` in `android/app/` directory
5. Rename `google-services.json.txt` to `google-services.json` if you downloaded it

### 3. Run the App

#### On Emulator:
```bash
flutter emulators --launch <emulator_id>
flutter run
```

#### On Physical Device:
1. Enable USB debugging on your Android device
2. Connect device via USB
3. Run:
```bash
flutter devices
flutter run
```

### 4. Test the App

1. Open the app on your device/emulator
2. Login with your username (e.g., "Wesley")
3. You should see your registered PC devices
4. Tap any command button to test

### 5. Verify PC App Receives Commands

1. Make sure PC app is running and logged in
2. Send a command from the mobile app
3. Check Firebase Console → Realtime Database to see command status
4. PC app should execute the command

## Troubleshooting

### "No devices found"
- Make sure PC app is running and logged in
- Check Firebase Console to see if device is registered under your username
- Verify database URL in FirebaseService matches your Firebase project

### "Failed to send command"
- Check internet connection
- Verify Firebase configuration
- Check Firebase Console for permission errors

### Build Errors
- Run `flutter clean` then `flutter pub get`
- Ensure all dependencies are compatible with your Flutter SDK version

## Database Structure Reference

```
users/
  {username}/
    devices/
      {deviceId}/
        name: "Home PC"
        platform: "windows"
        lastSeen: "2026-04-05T23:30:00Z"
        status: "online"
        commands/
          {commandId}/
            type: "ftp_sync"
            status: "completed"
            timestamp: 1712345678900
            result: "Success"
```

## Next Steps

- Add password verification for login
- Add real-time status updates from PC
- Add command history/logs view
- Add push notifications for command completion
