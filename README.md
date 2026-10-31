# sileo_toast

Physics-based gooey toast for Flutter, a port of [Sileo](https://github.com/hiaaryan/sileo) by Aaryan Sharma.
Depends on the Flutter SDK only (`widgets`, `physics`, `rendering`, `scheduler`), so it works with
material_ui, cupertino_ui or plain widgets.

## Install

```yaml
dependencies:
  sileo_toast:
    path: ../packages/sileo_toast
    # or
    # git:
    #   url: https://github.com/<owner>/sileo_toast.git
```

Requires Dart `^3.13.0` and Flutter `>=3.47.0`.

## Usage

Host the toaster above the Navigator, for example in `MaterialApp.builder`, and pass the app's text style:

```dart
MaterialApp(
  builder: (context, child) => SileoToaster(
    theme: SileoThemeMode.system,
    textStyle: Theme.of(context).textTheme.bodyMedium,
    child: child!,
  ),
);

// anywhere below:
Sileo.of(context).success(SileoOptions(title: 'Saved', description: const Text('Done.')));
```

Pass your own `SileoController` to show toasts without a `BuildContext`; the toaster then never disposes it.

## API

| Sileo | sileo_toast |
|---|---|
| `<Toaster position offset options theme />` | `SileoToaster(child, controller, position, offset, options, theme, textStyle, island, persistWhenAccessibleNavigation)` |
| `sileo.show / success / error / warning / info / action` | `SileoController.show / success / error / warning / info / action(SileoOptions)`, each returns the id |
| `sileo.promise(promise, { loading, success, error, action })` | `controller.promise(future, SileoPromiseOptions(loading, success, error, action))`, returns the future |
| `sileo.dismiss(id)` / `sileo.clear(position?)` | `controller.dismiss(id)` / `controller.clear([position])` |
| options `title, description, type, position, duration, icon, styles, fill, roundness, autopilot, button, id` | `SileoOptions` with the same fields; `description` is a `Widget` (`SileoOptions.text('...')` wraps a string) |
| `duration: null` | `persistent: true` (a `duration` of zero or less also means persistent) |
| `autopilot: false \| { expand, collapse }` | `SileoAutopilot.off` / `SileoAutopilot(expand:, collapse:)` |
| `styles.{title, description, badge, button}` | `SileoStyles(title, description, badgeBackground, badgeForeground, buttonForeground, buttonBackground, buttonPressedBackground)` |
| `button: { title, onClick }` | `SileoButton(title:, onPressed:)` |
| positions `top-left` ... `bottom-right` | `SileoPosition.topLeft` ... `bottomRight` (physical, no RTL flip) |
| `theme: light \| dark \| system` | `SileoThemeMode.light / dark / system` (`light` gives a dark toast, as in Sileo) |

Same-id toasts morph into each other; distinct ids stack (top newest first, bottom newest last).

## Large size

`SileoOptions(size: SileoSize.large)` (or a toaster default through `options`) gives a full-width card capped at 520 dp: title row, description, an optional `trailing` thumbnail
(sized and clipped to 64 dp by the package; pass a `ResizeImage`d widget, the package never decodes images) and up to two buttons. `secondaryButton` sits left of `button`
in equal cells. Compact ignores `trailing` and `secondaryButton`.

## Island

`SileoPosition.island` grows a black toast out of the hardware camera cutout: a neck springs down from the cutout to a pill that starts at the island's width. The pill fill is always
pure black (it must blend with the hardware), whatever `theme` or `fill`, and text uses the light pairing. Only one island toast is shown at a time; a new id replaces the old one.

What a foreground app cannot do: the real Dynamic Island (Live Activities, the system morph) belongs to the OS. An app cannot draw into or above the system layer, so this is an
imitation painted just below the status bar row with a black neck that overlaps the cutout. It never covers status bar items.

Detection uses `MediaQuery` only, resolved once per `MediaQuery` change:

| Platform | Rule |
|---|---|
| iOS | Portrait, and (`viewPadding.top`, screen size) matches a known device: 14 Pro / 15 / 16 family (59 pt, 393x852 and 430x932). 16 Pro, 17 and Air have a different top inset and fall back until their island size is measured. |
| Android | A `DisplayFeatureType.cutout` that starts above the status bar, is centered within 1 dp and is at most 200 dp wide (a punch-hole camera). Corner holes and notches fall back. |

Anything else (Display Zoom, iPad, landscape, notch phones, desktop, web) falls back: the toast looks like `topCenter` with the theme fill. Provide your own cutout rect with
`SileoToaster(island: (MediaQueryData data) => Rect?)`; return null for "no island". `SileoIsland.detect` is the default and is public.

## Differences from Sileo

- Touch has no hover: tapping a toast toggles expand and pauses/resumes the timers. Mouse hover works as in Sileo.
- `persistent: true` replaces `duration: null`.
- The gooey shape is one analytic path (pill, body and concave fillets), not an SVG blur + threshold filter. No `saveLayer`.
- Only the fallback title (the state name) is capitalized; a given title is shown as is (CSS `capitalize` breaks Turkish `i`).
- Accessibility additions: a live-region semantics node with a dismiss action, 48 dp tap targets, no auto-dismiss under accessible navigation (`persistWhenAccessibleNavigation`), reduce motion jumps animations to their end, text scale up to 2.0 without clipping.
- Swipe up or down past 30 dp dismisses; the package has no strings of its own.

## Hosting above the Navigator

`SileoToaster` is a plain `Stack`, not an Overlay, and sits above the Navigator. There is no `Material` or `Overlay` there, so
`InkWell`, `Tooltip` and other Material widgets inside a `description` will not work. Pass `textStyle` from the app theme: without it
the toast uses a neutral style, and text would otherwise inherit `MaterialApp`'s error style. Decorations are always removed.

## License

MIT. Original Sileo design and code by Aaryan Sharma; Flutter port by Mert Akif Korkmaz. See [LICENSE](LICENSE).
