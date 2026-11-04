## 0.1.2

- A hovered or touch-expanded toast no longer holds back dismissal forever. The toaster gets a `maxPause` parameter (default 15 s): past it the pause is released and the toasts dismiss on their normal timers, so a stuck hover (a resting mouse pointer) or touch cannot keep a toast on screen. The pause still releases at once when the pointer leaves, the pointer is removed, or the engaged toast goes away.

## 0.1.1

- A title now wraps to a second line (then ellipsizes) at a scaled-up text size instead of being cut off on one line. The header grows with the wrapped title. At the default text size nothing changes.

## 0.1.0

First release of the Flutter port of Sileo.

- Physics-based gooey toast: spring-driven morphing, analytic gooey shape, promise API, swipe to dismiss.
- Compact and large sizes. Large adds a trailing image and primary and secondary buttons.
- Six positions, theming, autopilot.
- Accessibility: semantics with a live region and dismiss action, reduce motion, text scale up to 2.0.
- Flutter SDK only. Supports Dart `^3.7.0` and Flutter `>=3.29.0`.
