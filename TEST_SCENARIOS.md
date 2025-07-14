# Detach App - Comprehensive Test Scenarios

## Overview

This document outlines all critical test scenarios for the Detach app based on real-world issues encountered during development. These tests should be implemented using Patrol for comprehensive integration testing.

## Test Categories

### 1. Permission Management Tests

#### 1.1 Permission Check Before Locking

**Scenario**: User tries to lock apps without required permissions
**Test Steps**:

1. Launch app without permissions
2. Try to select and lock apps
3. Verify permission bottom sheet appears
4. Test permission granting flow
5. Verify app locking works after permissions granted

**Expected Results**:

- Permission bottom sheet shows when trying to lock without permissions
- Navigation to permission page works correctly
- App locking succeeds after permissions granted

#### 1.2 Permission Denial Handling

**Scenario**: User denies required permissions
**Test Steps**:

1. Try to lock apps
2. Deny permissions when prompted
3. Verify app handles denial gracefully
4. Test re-requesting permissions

**Expected Results**:

- App doesn't crash on permission denial
- User can retry permission granting
- App remains functional without permissions

### 2. Timer Functionality Tests

#### 2.1 Timer Background Running

**Scenario**: Timer continues running when app is closed
**Test Steps**:

1. Set timer for 2-5 minutes
2. Close Detach app completely
3. Wait for timer to run in background
4. Try to open blocked app
5. Verify pause screen appears

**Expected Results**:

- Timer data persists in SharedPreferences
- Background service monitors app launches
- Pause screen appears when blocked app opens during timer

#### 2.2 Timer Data Persistence

**Scenario**: Timer data survives app restarts
**Test Steps**:

1. Set timer and close app
2. Force close app from recent apps
3. Restart app
4. Verify timer data is preserved
5. Verify UI reflects active timer

**Expected Results**:

- Timer data persists after app restart
- UI shows active timer status
- Background monitoring continues

#### 2.3 Timer Slider Minimum Value

**Scenario**: Timer slider enforces minimum 1-minute value
**Test Steps**:

1. Try to set timer to 0 minutes
2. Verify minimum value is enforced
3. Test various slider positions
4. Verify timer display accuracy

**Expected Results**:

- Minimum timer value is 1 minute
- Slider doesn't allow 0-minute setting
- Timer display shows correct values

### 3. Pause Screen Tests

#### 3.1 Pause Screen Appearance

**Scenario**: Pause screen appears when blocked app opens during timer
**Test Steps**:

1. Set active timer
2. Close Detach app
3. Open blocked app
4. Verify pause screen overlay appears
5. Test countdown timer accuracy

**Expected Results**:

- Pause screen appears as overlay
- Countdown timer shows correct remaining time
- Timer updates every second

#### 3.2 Pause Screen Back Button (After Revert)

**Scenario**: Back button behavior after reverting close-app-completely changes
**Test Steps**:

1. Trigger pause screen
2. Press back button
3. Verify pause screen remains visible
4. Test "Take Action" functionality

**Expected Results**:

- Back button doesn't close app completely
- Pause screen remains visible
- "Take Action" options work correctly

#### 3.3 Pause Screen Actions

**Scenario**: User can take actions from pause screen
**Test Steps**:

1. Open pause screen
2. Tap "Take Action"
3. Test "Permanently Block" option
4. Test "Reset Timer" option
5. Test "Continue Waiting" option

**Expected Results**:

- Action options appear correctly
- Each action works as expected
- UI updates appropriately

### 4. Theme System Tests

#### 4.1 Theme Switching

**Scenario**: App theme changes correctly
**Test Steps**:

1. Switch to light theme
2. Verify status bar color changes
3. Switch to dark theme
4. Verify status bar color changes
5. Switch to system theme
6. Test theme persistence

**Expected Results**:

- Theme switches immediately
- Status bar color adapts to theme
- Theme persists after app restart

#### 4.2 Status Bar Color Updates

**Scenario**: Status bar color updates with theme changes
**Test Steps**:

1. Change theme while app is running
2. Verify status bar updates immediately
3. Test system theme detection
4. Verify proper contrast

**Expected Results**:

- Status bar updates immediately on theme change
- Proper contrast in all themes
- System theme detection works

### 5. Data Persistence Tests

#### 5.1 SharedPreferences Data Integrity

**Scenario**: Timer and app data persists correctly
**Test Steps**:

1. Set timer and select apps
2. Force close app
3. Restart app
4. Verify all data is preserved
5. Test data consistency

**Expected Results**:

- Timer data persists correctly
- Selected apps list persists
- Data types match between Flutter and Android

#### 5.2 App State Recovery

**Scenario**: App recovers state after crashes/restarts
**Test Steps**:

1. Set up active timer
2. Simulate app crash
3. Restart app
4. Verify state recovery
5. Test background service restart

**Expected Results**:

- App recovers active timer state
- Background service restarts correctly
- UI reflects current state

### 6. Background Service Tests

#### 6.1 Service Persistence

**Scenario**: Background service continues running
**Test Steps**:

1. Start timer and close app
2. Wait for background service to run
3. Test service survival through app switches
4. Verify service restarts after system restart

**Expected Results**:

- Service continues running in background
- Service survives app switches
- Service restarts after system restart

#### 6.2 App Launch Detection

**Scenario**: Service detects blocked app launches
**Test Steps**:

1. Set active timer
2. Try to open different blocked apps
3. Verify pause screen appears for each
4. Test multiple app launches

**Expected Results**:

- Service detects all blocked app launches
- Pause screen appears consistently
- No false positives/negatives

### 7. Edge Case Tests

#### 7.1 Multiple App Blocking

**Scenario**: Multiple apps can be blocked simultaneously
**Test Steps**:

1. Select multiple apps
2. Set timer and lock
3. Try to open each blocked app
4. Verify pause screen for each

**Expected Results**:

- Multiple apps can be selected
- All selected apps are blocked
- Pause screen appears for each blocked app

#### 7.2 Timer Expiration

**Scenario**: Timer expires correctly
**Test Steps**:

1. Set short timer (1-2 minutes)
2. Wait for timer to expire
3. Try to open blocked app
4. Verify no pause screen appears

**Expected Results**:

- Timer expires at correct time
- No pause screen after expiration
- App returns to normal state

#### 7.3 Rapid App Switching

**Scenario**: App handles rapid switching between apps
**Test Steps**:

1. Set active timer
2. Rapidly switch between apps
3. Test pause screen behavior
4. Verify no crashes or issues

**Expected Results**:

- App handles rapid switching gracefully
- Pause screen appears correctly
- No crashes or performance issues

## Implementation Notes

### Patrol Test Structure

```dart
patrolTest(
  'Test Name',
  ($) async {
    // Test implementation
  },
);
```

### Key Patrol Methods

- `$.pumpWidgetAndSettle()` - Launch app
- `$.native.pressHome()` - Press home button
- `$.native.openApp()` - Open specific app
- `$.native.pressBack()` - Press back button
- `$(#elementId).tap()` - Tap element by ID
- `$('Text').exists` - Check if text exists

### Test Data Management

- Use mock data for timer values
- Implement SharedPreferences reading for data persistence tests
- Use realistic app package names for testing

### Device Configuration

- Test on multiple Android devices
- Test different screen sizes
- Test with different Android versions

## Running Tests

### Install Patrol CLI

```bash
dart pub global activate patrol_cli
```

### Run Tests

```bash
patrol test
```

### Run Specific Test

```bash
patrol test --target test/integration_test/simple_test.dart
```

### Run on Specific Device

```bash
patrol test --device-id <device_id>
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

## Success Criteria

A test is considered successful if:

1. All expected UI elements appear
2. All user interactions work correctly
3. Data persists as expected
4. Background services function properly
5. No crashes or errors occur
6. Performance remains acceptable

## Maintenance

- Update tests when UI changes
- Add new tests for new features
- Review and update test data regularly
- Monitor test execution time
- Keep Patrol version updated
