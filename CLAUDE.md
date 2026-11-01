# sileo_toast

Flutter port of Sileo (physics-based gooey toast). Flutter SDK only: `lib/` imports `widgets`, `physics`, `rendering`, `scheduler`, `foundation`, never `material` or `cupertino`. Every number lives in `lib/src/constants.dart`.

## Commands (Flutter pinned in `.fvmrc`)

```sh
fvm flutter test
fvm flutter analyze
dart format --set-exit-if-changed .
fvm dart pub publish --dry-run
cd example && fvm flutter test
```

## Release

Bump `version` in `pubspec.yaml`, add the CHANGELOG entry, commit, tag `vX.Y.Z`, push the tag. Pre-releases use `-dev.N`.
