# Career save + GitHub Actions fix

Fixes included:
- robust WorldSave temporary-file promotion with copy fallback;
- PlayerContract JSON persistence and PlayerCareer contract restoration;
- career-start regression test covering save/load after contract confirmation;
- GitHub Actions now runs from the repository root (no stale `fpg84` working-directory);
- APK artifact path is relative to the repository root;
- CI runs `flutter test` before building the release APK.
