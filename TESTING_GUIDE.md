# Testing Guide for Detach App

## Prerequisites

### 1. Install Patrol CLI

```bash
dart pub global activate patrol_cli
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Add Element Keys to Your UI

You need to add keys to your UI elements so Patrol can find them. Add these to your widgets:

```dart
// In your home view
ElevatedButton(
  key: const Key('appSelectionButton'),
  onPressed: () => controller.toggleAppSelection(),
  child: Text('Select Apps'),
)

// In your pause view
Text(
  key: const Key('countdownTimer'),
  'Time Remaining: $remainingTime',
)

// In your settings
ElevatedButton(
  key: const Key('lightThemeButton'),
  onPressed: () => themeService.setTheme(ThemeMode.light),
  child: Text('Light'),
)
```

## Step-by-Step Testing Process

### Step 1: Start with Simple Tests

Run the basic test first:

```bash
patrol test --target test/integration_test/simple_test.dart
```

### Step 2: Run Working Tests

Run the comprehensive test:

```bash
patrol test --target test/integration_test/working_test.dart
```

### Step 3: Run All Tests

```bash
patrol test
```

## Available Test Files

### 1. `simple_test.dart` - Basic Tests

- ✅ App launch
- ✅ Permission flow
- ✅ Theme switching

### 2. `working_test.dart` - Comprehensive Tests

- ✅ App launch and navigation
- ✅ Permission checks
- ✅ Timer slider functionality
- ✅ Theme switching
- ✅ App locking
- ✅ Background timer

## Common Issues and Solutions

### Issue 1: "Element not found"

**Solution**: Add proper keys to your UI elements

```dart
// Add this to your widgets
key: const Key('elementName')
```

### Issue 2: "App class not found"

**Solution**: Use the correct app class name

```dart
// Use this
await $.pumpWidgetAndSettle(const DetachApp());

// NOT this
await $.pumpWidgetAndSettle(const MyApp());
```

### Issue 3: "Method not found"

**Solution**: Use correct Patrol methods

```dart
// Correct Patrol methods
await $.native.pressHome();
await $.native.pressBack();
await $(#elementKey).tap();
await $.pumpAndSettle();

// NOT these (they don't exist)
await $.native.getCurrentApp();
await $(#elementKey).dragTo();
```

## Testing Your Specific Scenarios

### 1. Timer Background Running

```dart
patrolTest('Timer Background Test', ($) async {
  await $.pumpWidgetAndSettle(const DetachApp());

  // Grant permissions
  await _grantPermissions($);

  // Set timer
  await $(#appSelectionButton).tap();
  await $(#appItem).first.tap();
  await $(#lockButton).tap();

  // Close app
  await $.native.pressHome();

  // Try to open blocked app
  await $.native.openApp('com.whatsapp');

  // Verify pause screen
  expect($('Pause').exists, true);
});
```

### 2. Permission Check

```dart
patrolTest('Permission Check Test', ($) async {
  await $.pumpWidgetAndSettle(const DetachApp());

  // Try to lock without permissions
  await $(#lockButton).tap();

  // Verify permission bottom sheet
  expect($('Permission Required').exists, true);
});
```

### 3. Timer Slider Minimum Value

```dart
patrolTest('Timer Slider Test', ($) async {
  await $.pumpWidgetAndSettle(const DetachApp());

  // Test slider
  await $(#timerSlider).tap();

  // Verify minimum value
  final value = $(#timerValue).text;
  expect(value, '1 min');
});
```

## Running Tests on Specific Devices

### List Available Devices

```bash
patrol devices
```

### Run on Specific Device

```bash
patrol test --device-id <device_id>
```

### Run on Multiple Devices

```bash
patrol test --devices android
```

## Debugging Tests

### 1. Enable Verbose Output

```bash
patrol test --verbose
```

### 2. Take Screenshots on Failure

```bash
patrol test --screenshots-on-failure
```

### 3. Run Single Test

```bash
patrol test --target test/integration_test/working_test.dart --test-name "App Launch and Basic Navigation"
```

## Continuous Integration

### GitHub Actions Example

```yaml
name: Integration Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: patrol test
```

## Troubleshooting

### 1. Tests Not Finding Elements

- Check that keys are added to UI elements
- Verify element text matches exactly
- Use `await $.pumpAndSettle()` after interactions

### 2. App Not Launching

- Verify app class name is correct
- Check that main.dart exports the app correctly
- Ensure no compilation errors

### 3. Permission Issues

- Handle permission granting in tests
- Use `_simulatePermissionsGranted()` helper
- Test both granted and denied scenarios

### 4. Background Service Tests

- Use `$.native.pressHome()` to background app
- Test service persistence
- Verify pause screen appears

## Next Steps

1. **Add Keys**: Add keys to all your UI elements
2. **Run Simple Tests**: Start with `simple_test.dart`
3. **Expand Tests**: Add more specific scenarios
4. **Set Up CI**: Add GitHub Actions for automated testing
5. **Monitor Results**: Track test success rates

## Useful Commands

```bash
# Install Patrol
dart pub global activate patrol_cli

# Get dependencies
flutter pub get

# Run tests
patrol test

# Run specific test file
patrol test --target test/integration_test/working_test.dart

# List devices
patrol devices

# Run with verbose output
patrol test --verbose

# Take screenshots on failure
patrol test --screenshots-on-failure
```

## Success Criteria

A test is successful when:

- ✅ App launches correctly
- ✅ UI elements are found and interacted with
- ✅ Expected text appears
- ✅ Navigation works
- ✅ No crashes occur
- ✅ Background functionality works
