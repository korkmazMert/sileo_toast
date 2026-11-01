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

## SDK floor

`pubspec.yaml` supports Dart `^3.7.0` / Flutter `>=3.29.0`; `.fvmrc` pins the latest stable for development and CI. Do not use newer language features in `lib/` (for example `const new` / shorthand constructors, which need Dart 3.13). `Brightness` is imported from `dart:ui` because older Flutter does not re-export it from `widgets.dart`. Tests may use newer test-only APIs (`SemanticsData.flagsCollection`, `Tristate`). To verify the floor: copy the package, set `very_good_analysis: ^8.0.0` and `fake_async: ^1.3.2`, use Flutter 3.29.3, and run `flutter analyze lib`.

## Later

- Automated publishing (not enabled): on pub.dev, Admin tab, Automated publishing, enable GitHub Actions for `korkmazMert/sileo_toast` with tag pattern `v{{version}}`, then add a publish workflow. Protect it first: GitHub ruleset for `v*` tags, limited write access, and a required-reviewer environment (for example `pub.dev`) on the publish job. Until then, publish manually with `fvm dart pub publish`.
- GitHub repo settings: description, website `https://pub.dev/packages/sileo_toast`, topics (flutter, dart, toast, animation, snackbar, notification).
