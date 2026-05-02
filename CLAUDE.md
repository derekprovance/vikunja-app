# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Vikunja is a cross-platform Flutter app for the open-source Vikunja task management system. The app supports Android, iOS, and web, with features including task management, Kanban/Gantt/table views, team collaboration, and end-to-end encryption support.

The app is in **alpha pre-release** and requires the latest unstable build of Vikunja to run. It uses Flutter 3.9+ and Dart 3.9+.

## Common Development Tasks

### Get Started
```bash
flutter pub get
make format  # Format code before committing
```

### Build & Run
- **Debug APK**: `make build-debug` (builds with unsigned flavor)
- **Release APK**: `make build-release` (builds with main flavor, requires signing)
- **Profile APK**: `make build-profile` (for performance profiling)
- **iOS build**: `make build-ios` (no code signing, for development)
- **All builds**: `make build-all`

### Testing
```bash
make test              # Run all tests
flutter test test/<test_file>_test.dart  # Run specific test file
flutter test -n "test name pattern"      # Run tests matching pattern
```

### Code Quality
```bash
flutter analyze        # Run dart analyzer (includes custom_lint)
make format-check      # Check formatting without applying changes
make format            # Format all lib code
```

### Code Generation
Code generation is needed when modifying:
- Riverpod providers (`.dart` files in `lib/core/di/` and `lib/presentation/manager/`)
- App localizations/translations

Run code generation:
```bash
flutter pub run build_runner build              # One-time generation
flutter pub run build_runner watch              # Watch mode during development
```

Generated files have `.g.dart` suffix and should never be edited directly.

## Architecture

The app follows **clean architecture** with clear separation of concerns:

### Domain Layer (`lib/domain/`)
- **entities/**: Plain Dart classes representing core business concepts (Task, Project, Label, etc.)
- **repositories/**: Abstract interfaces defining repository contracts

### Data Layer (`lib/data/`)
- **models/**: DTOs (Data Transfer Objects) with `*Dto` suffix for API serialization/deserialization
- **data_sources/**: Concrete implementations for different data sources (API, local storage)
- **repositories/**: Concrete implementations of domain repository interfaces

### Presentation Layer (`lib/presentation/`)
- **manager/**: Riverpod controllers managing state and business logic
- **pages/**: Top-level screens/routes
- **widgets/**: Reusable UI components

### Core Layer (`lib/core/`)
- **di/**: Dependency injection providers using Riverpod
- **network/**: HTTP client setup, response wrapping
- **oauth/**: OAuth/OIDC authentication flow implementation
- **theming/**: Theme management and Material/Cupertino design
- **utils/**: Shared utilities (extensions, formatters, validators)

**Key Pattern**: DTO → Domain Entity conversion happens in data layer via `toDomain()` and `fromDomain()` extensions.

## State Management

The app uses **Flutter Riverpod** (v2.6.1+) with code generation via `riverpod_generator`:

- Providers are defined in `lib/core/di/` (DI providers for services) and `lib/presentation/manager/` (UI state)
- Riverpod providers are decorated with `@riverpod` or use class-based `Notifier` with `@riverpod` annotation
- Generated `.g.dart` files are created automatically via `build_runner`
- Custom lint rules from `riverpod_lint` help catch provider misuse

Avoid using deprecated `ChangeNotifierProvider` (Riverpod v1 style).

## Build Flavors & Variants

Two main flavors are configured:
- **main**: Release builds with play store signing configuration
- **unsigned**: Debug/profile builds without signing

Flavors are defined in `android/app/build.gradle` and `ios/Runner/Build.xcconfig`. The Flutter default flavor is set to "unsigned" in `pubspec.yaml`.

## Key Dependencies

- **flutter_riverpod**: State management with code generation
- **background_downloader**: Download management for task attachments
- **flutter_local_notifications**: Local push notifications
- **sentry_flutter**: Error tracking and crash reporting
- **workmanager**: Background task scheduling
- **flutter_secure_storage**: Encrypted secure storage for tokens
- **intl**: Internationalization (ARB files in `lib/l10n/`)
- **dynamic_color**: Material You dynamic theming support
- **home_widget**: Home screen widget (Android)

## Internationalization (i18n)

Translations use ARB (Application Resource Bundle) format:
- Source translations: `lib/l10n/app_en.arb`
- Other languages: `lib/l10n/app_<locale>.arb`
- Run `flutter gen-l10n` to generate localization files
- Access via `AppLocalizations.of(context)?.key` or `context.l10n.key` (if extension available)

See [translation docs](https://vikunja.io/docs/translations/) for contributing new languages.

## Error Tracking & Logging

The app integrates **Sentry** for crash reporting and error tracking:
- Configured in `lib/main.dart` with `SentryWidgetsFlutterBinding`
- Network errors from Cronet (Android) are filtered to avoid noise (see `_ignoredNetworkErrors`)
- Use Sentry SDK for manual event capture when needed

## Testing Approach

- **Unit tests**: Located in `test/` directory (utilities, parsers, models)
- **Widget tests**: In `test/widget_test.dart` for testing UI components
- **Integration tests**: In `integration_test/` directory (end-to-end flows)

Test file naming: `*_test.dart`

**Note**: Full test suite is currently commented out in CI pipeline but can be run locally.

## OAuth & Authentication

OAuth/OIDC authentication is implemented in `lib/core/oauth/`:
- PKCE (Proof Key for Code Exchange) support for security
- Token refresh and storage in secure storage
- Server version compatibility checks before login

## Responsive & Multi-Platform Design

The app supports:
- **Android**: Uses Material Design and Cronet HTTP client
- **iOS**: Uses Cupertino design elements and cupertino_http client
- **Web**: Supported through Flutter Web

Use `Theme.of(context).platform` to detect platform and adjust UI accordingly.

## Performance Notes

- **Code Generation**: Always run before committing Riverpod provider changes
- **Lazy Loading**: Use `.select()` on Riverpod providers to listen only to needed state
- **Image Assets**: Already optimized in `assets/` directory
- **Profile Builds**: Use `make build-profile` for performance profiling before release

## Common Patterns

### Adding a New Feature
1. Define entity in `lib/domain/entities/`
2. Create abstract repository in `lib/domain/repositories/`
3. Define DTO in `lib/data/models/` with serialization logic
4. Implement data source in `lib/data/data_sources/`
5. Implement repository in `lib/data/repositories/`
6. Create Riverpod provider in `lib/core/di/repository_provider.dart` or appropriate location
7. Create controller in `lib/presentation/manager/` if state management needed
8. Build UI in `lib/presentation/pages/` and `lib/presentation/widgets/`

### Adding a Repository Provider
Edit `lib/core/di/repository_provider.dart` and re-run code generation.

### Modifying API Models
Update DTO in `lib/data/models/`, run code generation, ensure `toDomain()` and `fromDomain()` extensions work.

## Debugging

- **Enable verbose logging**: `flutter run -v`
- **Dart DevTools**: `flutter pub global run devtools`
- **Check Sentry dashboard**: Review sent errors/crashes
- **Local API testing**: Point to local Vikunja instance in login settings

## Release Process

1. Update version in `pubspec.yaml`
2. Create git tag matching version: `git tag v<version>`
3. CI pipeline automatically builds and releases to download servers
4. Android releases also pushed to Google Play Beta channel

## Additional Resources

- [Vikunja main repo](https://github.com/go-vikunja/vikunja)
- [Flutter documentation](https://flutter.dev/docs)
- [Riverpod documentation](https://riverpod.dev)
- [Translation contribution guide](https://vikunja.io/docs/translations/)
