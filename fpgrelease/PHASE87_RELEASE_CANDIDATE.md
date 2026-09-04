# Phase 87 — Release Candidate

Status: **PREPARED / RUNTIME BUILD REQUIRED**

## Release changes
- Version bumped to `0.9.0+1`.
- Production-facing Settings label now identifies the build as Release Candidate.
- Release gate script added: `tools/run_phase84_88_gate.sh`.
- Required logo and audio assets are covered by an automated readiness test.

## Required release commands
```text
flutter pub get
flutter analyze
flutter test --coverage --reporter expanded
flutter build apk --release
```

## Release checklist
- [ ] clean install
- [ ] upgrade install over previous save
- [ ] save survives restart
- [ ] delete-save confirmation works
- [ ] release APK launches
- [ ] no debug banner
- [ ] no fatal startup errors
- [ ] long-run career remains intact
- [ ] final app icon verified on launcher

## Exit criterion
Release APK installs, launches, saves and completes the primary career loop on a real device.
