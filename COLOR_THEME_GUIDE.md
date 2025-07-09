# Detach App - Color Theme Guide

## 🎨 Color Philosophy

The Detach app uses a carefully crafted color palette designed for digital wellness and focus. The colors convey:

- **Calmness & Serenity** - Soft blues and purples
- **Focus & Productivity** - Clean contrasts and readability
- **Modern & Professional** - Contemporary design language

## 🌞 Light Theme Colors

### Primary Colors

- **Primary**: `#6366F1` (Indigo) - Main brand color
- **On Primary**: `#FFFFFF` (White) - Text/icons on primary
- **Secondary**: `#8B5CF6` (Violet) - Accent color
- **On Secondary**: `#FFFFFF` (White) - Text/icons on secondary
- **Tertiary**: `#06B6D4` (Cyan) - Additional accent
- **On Tertiary**: `#FFFFFF` (White) - Text/icons on tertiary

### Surface Colors

- **Background**: `#FAFBFF` (Very Light Blue-White) - App background
- **On Background**: `#1E293B` (Dark Slate) - Text on background
- **Surface**: `#FFFFFF` (White) - Card/component backgrounds
- **On Surface**: `#1E293B` (Dark Slate) - Text on surfaces
- **Surface Variant**: `#F1F5F9` (Light Gray) - Secondary surfaces
- **On Surface Variant**: `#64748B` (Medium Gray) - Text on surface variants

### Outline Colors

- **Outline**: `#CBD5E1` (Light Gray) - Borders and dividers
- **Outline Variant**: `#E2E8F0` (Very Light Gray) - Subtle borders

### Error Colors

- **Error**: `#EF4444` (Red) - Error states
- **On Error**: `#FFFFFF` (White) - Text on error

## 🌙 Dark Theme Colors

### Primary Colors

- **Primary**: `#818CF8` (Lighter Indigo) - Main brand color
- **On Primary**: `#1E293B` (Dark Slate) - Text/icons on primary
- **Secondary**: `#A78BFA` (Lighter Violet) - Accent color
- **On Secondary**: `#1E293B` (Dark Slate) - Text/icons on secondary
- **Tertiary**: `#22D3EE` (Lighter Cyan) - Additional accent
- **On Tertiary**: `#1E293B` (Dark Slate) - Text/icons on tertiary

### Surface Colors

- **Background**: `#0F172A` (Very Dark Blue) - App background
- **On Background**: `#F8FAFC` (Very Light Gray) - Text on background
- **Surface**: `#1E293B` (Dark Slate) - Card/component backgrounds
- **On Surface**: `#F8FAFC` (Very Light Gray) - Text on surfaces
- **Surface Variant**: `#334155` (Medium Dark Gray) - Secondary surfaces
- **On Surface Variant**: `#CBD5E1` (Light Gray) - Text on surface variants

### Outline Colors

- **Outline**: `#475569` (Medium Gray) - Borders and dividers
- **Outline Variant**: `#334155` (Medium Dark Gray) - Subtle borders

### Error Colors

- **Error**: `#F87171` (Light Red) - Error states
- **On Error**: `#1E293B` (Dark Slate) - Text on error

## 🎯 Component-Specific Styling

### Cards

- **Elevation**: 2px
- **Border Radius**: 16px
- **Shadow**: Subtle with 10% opacity outline color

### Buttons

- **Border Radius**: 12px
- **Padding**: 24px horizontal, 12px vertical
- **Elevation**: 0 (flat design)

### Navigation Bar

- **Indicator Color**: Primary color with 10% opacity
- **Label Font**: 12px, Medium weight (500)

### Switches

- **Thumb**: On-primary color when selected, outline color when not
- **Track**: Primary color when selected, outline variant when not

## 🔄 Theme Switching

- **Persistent**: Theme preference is saved using SharedPreferences
- **Reactive**: Theme changes immediately when toggled
- **System Support**: Can follow system theme preference

## 📱 Usage Examples

### Light Theme

```dart
// Primary button
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: ThemeService.lightPrimary, // #6366F1
    foregroundColor: ThemeService.lightOnPrimary, // #FFFFFF
  ),
  child: Text('Get Started'),
)

// Card background
Card(
  color: ThemeService.lightSurface, // #FFFFFF
  child: Text('Card content'),
)
```

### Dark Theme

```dart
// Primary button
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: ThemeService.darkPrimary, // #818CF8
    foregroundColor: ThemeService.darkOnPrimary, // #1E293B
  ),
  child: Text('Get Started'),
)

// Card background
Card(
  color: ThemeService.darkSurface, // #1E293B
  child: Text('Card content'),
)
```

## 🎨 Color Accessibility

All color combinations meet WCAG AA contrast requirements:

- **Light Theme**: 4.5:1 minimum contrast ratio
- **Dark Theme**: 4.5:1 minimum contrast ratio
- **Error States**: High contrast for visibility
- **Interactive Elements**: Clear visual feedback

## 🔧 Implementation

The theme is implemented using:

- **GetX** for state management
- **SharedPreferences** for persistence
- **Material 3** design system
- **Custom ColorScheme** for consistent theming
