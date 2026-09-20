# FPG V32 — Context Mounted Fix

## Fixed
- `relationship_actions_screen.dart`: replaced post-`await` State mounted checks with `context.mounted` around Navigator and SnackBar usage.
- Added a second `context.mounted` guard after the awaited navigation.
- Bumped application version to `0.9.0+3`.

## CI gate
The existing workflow remains strict: `flutter analyze --fatal-warnings --fatal-infos`, `flutter test`, release APK and AAB builds with Dart obfuscation.

## Verification limitation
Flutter/Dart SDK is not installed in this environment, so runtime/build execution cannot be truthfully claimed here. The ZIP was structurally checked after creation.
