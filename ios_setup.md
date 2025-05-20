# iOS Configuration for Gayatri Reminder App

This document outlines the iOS-specific setup for the Gayatri Reminder app.

## Requirements

- iOS 12.0 or later
- Xcode 14.0 or later
- CocoaPods 1.12.0 or later
- Flutter 3.7.0 or later

## Package Configuration

### Geolocator

This app uses Geolocator for location services. The necessary permissions have been configured in Info.plist:

- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`

### Awesome Notifications

For scheduled notifications, the app uses Awesome Notifications. The app includes:

- Background fetch capability
- Remote notification capability
- Custom notification handling in AppDelegate

### Path Provider & File Picker

These packages require:

- Access to Documents directory
- Access to Photos library (for file selection)
- Appropriate permissions in Info.plist

## Building for iOS

1. Navigate to the iOS folder:

```bash
cd ios
```

2. Install CocoaPods dependencies:

```bash
pod install
```

3. Open the project in Xcode:

```bash
open Runner.xcworkspace
```

4. In Xcode, select your development team and ensure signing is configured properly.

5. Build and run the app using the Xcode build button or use Flutter CLI:

```bash
flutter run
```

## Troubleshooting

### Pod Installation Issues

If you encounter CocoaPods issues:

```bash
pod repo update
pod install --repo-update
```

### Permission Issues

If permissions aren't working:

1. Ensure all needed keys are in Info.plist
2. Check that the app has been granted permissions in iOS Settings
3. For location, make sure the app has been allowed "Always" permission if needed

### Notification Issues

If notifications aren't showing:

1. Check iOS system settings to ensure notifications are enabled for the app
2. Verify that the notification code is properly scheduling notifications
3. On physical devices, ensure the app is not in low power mode

## Distribution

For App Store distribution:

1. Update the version numbers in pubspec.yaml
2. Ensure all App Store Connect metadata is complete
3. Archive the app in Xcode
4. Submit to App Store Connect

## Additional Resources

- [Flutter iOS Integration](https://docs.flutter.dev/development/platform-integration/ios)
- [Geolocator iOS Setup](https://pub.dev/packages/geolocator)
- [Awesome Notifications iOS Setup](https://pub.dev/packages/awesome_notifications)
