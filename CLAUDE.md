# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**smartglass** is a Flutter mobile application for indoor navigation and location management, with Arabic language support. The app enables users to:
- Save and manage hierarchical locations (main locations with sub-locations)
- Create and manage navigation paths between locations
- Track current location and determine which saved location the user is in
- Navigate step-by-step between saved locations using sensor data and voice guidance

## Development Commands

### Running the app
```bash
flutter run
```

### Running on specific devices

```bash
# Android
flutter run -d android

# iOS (macOS only)
flutter run -d ios
```

### Building the app
```bash
# Android APK
flutter build apk

# Android App Bundle
flutter build appbundle

# iOS (macOS only)
flutter build ios
```

### Testing
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Run with coverage
flutter test --coverage
```

### Code Quality
```bash
# Run static analysis
flutter analyze

# Format code
flutter format lib/ test/

# Check formatting without modifying
flutter format --set-exit-if-changed lib/ test/
```

### Dependencies
```bash
# Get dependencies
flutter pub get

# Update dependencies
flutter pub upgrade

# Check for outdated packages
flutter pub outdated
```

## Architecture

### Core Structure

The app follows a simple screen-based architecture without a formal state management solution (Provider is listed in dev_dependencies but not actively used in the architecture).

**Key directories:**
- `lib/core/` - Core models and services
- `lib/screens/` - UI screens
- `test/` - Widget and unit tests

### Data Layer (lib/core/location_models_and_service.dart)

This is the heart of the application, containing all data models and the centralized service.

**Data Models:**
- `Coordinates` - Lat/long pairs with JSON serialization
- `SavedLocation` - Represents a location with hierarchical sub-locations. Important: Uses `id` field for equality comparison, not reference equality
- `PathStep` - Individual step in a navigation path with coordinates and optional event description
- `MovementPath` - Complete path between two locations with ordered steps

**LocationService:**
- Singleton-style service for all location operations
- Uses SharedPreferences for persistence (keys: `saved_locations_data`, `movement_paths_data`)
- Handles GPS location access with permission checks and error handling in Arabic
- Methods: `loadLocations()`, `saveLocations()`, `loadPaths()`, `savePaths()`, `getCurrentLocation()`, `findParentLocation()`

### UI Layer (lib/screens/)

Each screen is a separate StatefulWidget/StatelessWidget file:

- `home_screen.dart` - Main menu with navigation to all features
- `saved_locations_screen.dart` - CRUD operations for locations and sub-locations (~400 lines)
- `path_manager_screen.dart` - List and create navigation paths
- `path_creation_screen.dart` - Multi-step form for creating paths between locations (~330 lines)
- `where_am_i_screen.dart` - Detects current location and matches against saved locations (~270 lines)
- `navigation_screen.dart` - Real-time navigation with sensor data, voice guidance, and maps (~730 lines, most complex screen)
- `splach_scereen.dart` - Splash screen (note: filename typo "scereen")

### Navigation Pattern

Simple Navigator.push pattern throughout - no named routes or advanced routing.

### Important Implementation Details

**SavedLocation Equality:**
The `SavedLocation` class overrides `==` and `hashCode` to compare by `id` only. This was specifically done to fix dropdown/selection issues. When comparing or updating locations, always use the `id` field.

**Arabic UI:**
All user-facing strings are in Arabic. Error messages, labels, and descriptions should maintain Arabic language consistency.

**Location Hierarchy:**
Main locations contain `subLocations` list. When working with locations, be aware of this two-level hierarchy. Use `LocationService.findParentLocation(subLocationId)` to traverse up the hierarchy.

**Persistence Strategy:**
All data persists through SharedPreferences as JSON strings. Changes are not automatically persisted - screens must explicitly call `LocationService.saveLocations()` or `savePaths()` after modifications.

## Key Dependencies

- `geolocator` - GPS location access
- `permission_handler` - Runtime permissions
- `shared_preferences` - Local data persistence
- `speech_to_text` - Voice input for navigation
- `sensors_plus` - Device sensors (accelerometer, gyroscope) for navigation
- `google_maps_flutter` - Map visualization in navigation
- `uuid` - Unique ID generation
- `google_fonts` - Custom typography
- `avatar_glow` - UI animations
- `intl` - Internationalization utilities

## Known Issues

- Test file (`test/widget_test.dart`) contains boilerplate counter test that doesn't match actual app functionality
- Splash screen filename has typo: `splach_scereen.dart` instead of `splash_screen.dart`
- Provider is in dev_dependencies but not used for state management in the current implementation
