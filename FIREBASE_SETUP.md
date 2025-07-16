# Firebase Analytics Setup Guide

This app has been configured with Firebase Analytics to track user behavior and app usage. Follow these steps to complete the setup:

## 1. Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project" or "Add project"
3. Enter your project name (e.g., "Detach App")
4. Follow the setup wizard

## 2. Add Android App

1. In your Firebase project, click the Android icon to add an Android app
2. Enter package name: `com.example.detach`
3. Enter app nickname: "Detach"
4. Download the `google-services.json` file
5. Replace the placeholder file at `android/app/google-services.json` with your downloaded file

## 3. Add iOS App (if needed)

1. In your Firebase project, click the iOS icon to add an iOS app
2. Enter bundle ID: `com.example.detach`
3. Enter app nickname: "Detach"
4. Download the `GoogleService-Info.plist` file
5. Replace the placeholder file at `ios/Runner/GoogleService-Info.plist` with your downloaded file

## 4. Update Configuration Files

### Android

The Android configuration is already set up in:

- `android/app/build.gradle.kts` - Added Google Services plugin
- `android/build.gradle.kts` - Added Google Services classpath

### iOS

The iOS configuration is already set up in:

- `ios/Runner/GoogleService-Info.plist` - Placeholder file (replace with your actual file)

## 5. Analytics Events Being Tracked

The app automatically tracks the following events:

### App Lifecycle

- `app_launch` - When the app starts
- `screen_view` - When users navigate to different screens

### Permissions

- `permission_requested` - When a permission is requested
- `permission_granted` - When a permission is granted
- `permission_denied` - When a permission is denied

### App Management

- `app_blocked` - When an app is blocked
- `app_unblocked` - When an app is unblocked
- `apps_configured` - When apps are configured
- `apps_blocked_count` - Number of apps blocked

### Pause Sessions

- `pause_session_started` - When a pause session begins
- `pause_session_completed` - When a pause session completes
- `pause_session_interrupted` - When a pause session is interrupted

### Features

- `feature_used` - When specific features are used
- `app_error` - When errors occur

## 6. User Properties

The app automatically sets these user properties:

- `app_version` - Current app version
- `build_number` - Build number
- `connectivity_type` - Network connectivity type
- `device_model` - Device model
- `android_version` / `ios_version` - OS version

## 7. View Analytics

1. In Firebase Console, go to your project
2. Click "Analytics" in the left sidebar
3. View real-time and historical data about your app usage

## 8. Custom Events

You can add custom events by calling:

```dart
AnalyticsService.to.logEvent(
  name: 'custom_event_name',
  parameters: {'key': 'value'},
);
```

## 9. Testing

To test analytics:

1. Run the app in debug mode
2. Check the console logs for analytics events
3. View real-time data in Firebase Console

## 10. Privacy Considerations

- Analytics data is collected anonymously
- No personally identifiable information is tracked
- Users can opt out of analytics in their device settings
- Consider adding a privacy policy for your app

## Troubleshooting

1. **Analytics not showing**: Wait 24-48 hours for data to appear in Firebase Console
2. **Events not logging**: Check that `google-services.json` is properly configured
3. **Build errors**: Ensure all Firebase dependencies are properly added to `pubspec.yaml`

## Next Steps

1. Replace placeholder configuration files with your actual Firebase project files
2. Test the app to ensure analytics events are being logged
3. Set up custom dashboards in Firebase Console for specific insights
4. Consider setting up crashlytics for error tracking
