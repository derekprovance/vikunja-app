# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Vikunja is a cross-platform Flutter app (Android primary focus, iOS community-supported) for the open-source Vikunja task management system. The app supports task management, Kanban/Gantt/table views, team collaboration, and end-to-end encryption.

The app is in **alpha pre-release** and requires the latest unstable build of Vikunja. Uses Flutter with Dart 3.9+.

## Commands

```bash
flutter pub get
make format                                          # Format lib/ before committing
make format-check                                    # Check formatting (exits 1 if unformatted)
make test                                            # Run all tests
flutter test test/<file>_test.dart                   # Run a single test file
flutter test -n "pattern"                            # Run tests matching a name pattern
flutter analyze                                      # Dart analyzer + custom_lint
flutter pub run build_runner build                   # One-time code generation
flutter pub run build_runner watch                   # Watch mode during development
```

### Builds
```bash
make build-debug             # unsigned flavor, debug
make build-unsigned-release  # unsigned flavor, minified, debug-signed (local testing)
make build-profile           # unsigned flavor, performance profiling
make build-ios               # iOS, no code signing
```

Production Play Store builds use the `production` flavor and are handled by CI/Fastlane.

**Code Generation Requirement**: Every file with `@riverpod` annotations must have `part 'filename.g.dart';` at the top. Code generation will fail without it.

## Architecture

Clean architecture with three layers — domain → data → presentation — plus core for cross-cutting concerns.

- **`lib/domain/`** — entities (plain Dart) and abstract repository interfaces. No framework dependencies.
- **`lib/data/`** — DTOs (`*Dto` suffix), data sources, and concrete repository implementations. All JSON serialization is **manual** (no `json_serializable`). DTO↔entity conversion uses `toDomain()` / `fromDomain()` extensions.
- **`lib/presentation/`** — Riverpod controllers (`manager/`), pages, and widgets.
- **`lib/core/`** — DI providers, network client, OAuth, theming, utilities.

## Dependency Injection

Providers live in `lib/core/di/`:

- `network_provider.dart` — `AuthData`, `CurrentUser` (both `keepAlive: true`), and `ClientProvider` (`keepAlive: true`). These must persist for the app lifetime. When auth changes, `AuthData.set()` calls `ref.invalidate(clientProviderProvider)` to rebuild the client.
- `data_source_provider.dart` — each data source watches `clientProviderProvider` and passes `Client` directly. `SettingsDatasource` is the exception (takes `FlutterSecureStorage` instead).
- `repository_provider.dart` — each repo watches its data source and passes it to the `*Impl` constructor.

**Naming quirk**: Riverpod codegen for a class named `ClientProvider` generates `clientProviderProvider` (double "Provider").

## State Management (Riverpod v3)

Controllers in `lib/presentation/manager/` follow this pattern:
- Class-based `@riverpod` extending the generated `_$ClassName` base.
- `build()` returns `Future<T>` for async providers.
- State mutations call `reload()` (sets `AsyncLoading`, re-fetches) except for optimistic updates (delete/mark-done) which patch `state` directly.
- Always check `ref.mounted` before mutating state after an `await`.
- Use `ref.watch()` only inside `build()`; use `ref.read()` for one-shot reads inside methods.

`PaginationMixin` (`lib/presentation/manager/pagination_mixin.dart`) handles multi-page loading — reads `x-pagination-total-pages` from response headers.

## Network Layer (`lib/core/network/`)

`Response<T>` is a sealed class:
- `SuccessResponse<T>` — body, statusCode, headers
- `VoidResponse<T>` — success with no body (extends `SuccessResponse`)
- `ErrorResponse<T>` — statusCode + error map from JSON
- `ExceptionResponse<T>` — exception + stackTrace

All response handling in controllers uses exhaustive `switch` pattern matching on these cases.

`Client` key behaviors:
- Platform-specific HTTP: Cronet on Android, CupertinoClient on iOS/macOS, `IOClient` fallback.
- On 401 with error code `11`, automatically refreshes the token (using `TokenLock` for cross-isolate safety) and retries the request once.
- On 401 without a refresh path, navigates imperatively to `/login` via `globalNavigatorKey`.
- `postUnauthenticated()` exists for login/token endpoints that don't need a Bearer header.

Two important globals in `main.dart`:
- `globalSnackbarKey` (`GlobalKey<ScaffoldMessengerState>`) — imperative snackbars
- `globalNavigatorKey` (`GlobalKey<NavigatorState>`) — imperative navigation inside `Client`

## Build Flavors & Variants

Two flavors:
- **production**: Release builds with play store signing (requires `key.properties`)
- **unsigned**: Debug/profile builds without signing

Default flavor is "unsigned" in `pubspec.yaml`. Android: `minSdkVersion 36` (Android 13+).

## Key Dependencies

- **flutter_riverpod** (v3): State management with code generation
- **http** (v1.6.0), **cronet_http** (Android), **cupertino_http** (iOS/macOS): Platform-specific HTTP clients
- **background_downloader**: Download management for task attachments
- **flutter_local_notifications**: Local push notifications
- **workmanager**: Background task scheduling
- **flutter_secure_storage**: Encrypted secure storage for tokens
- **intl**: Internationalization (ARB files in `lib/l10n/`)
- **app_links**: Deep linking support
- **home_widget**: Home screen widget (Android, uses Jetpack Glance)


## Logging

The app uses the `logging` package for error tracking and event emission. Logs are captured via `dart:developer` and can be viewed during development.

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

## Localization

ARB format, source in `lib/l10n/app_en.arb`. Access via `AppLocalizations.of(context)` or `context.l10n` (extension). Run `flutter gen-l10n` after editing ARB files.

## Debugging

- **Enable verbose logging**: `flutter run -v`
- **Dart DevTools**: `flutter pub global run devtools`
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
