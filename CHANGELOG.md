## Unreleased

- Large size (`SileoOptions.size`, `trailing`, `secondaryButton`). A top-level `Semantics` trailing stays exposed to screen readers; other trailings are hidden.
- Island presentation: `SileoPosition.island` grows the toast out of the camera cutout; `SileoToaster.island` overrides detection, `SileoIsland.detect` is the default.
- Breaking for exhaustive switches: `SileoPosition` has a new `island` value; add the case to any `switch` over it.
- The large secondary button label now follows the toast's text color instead of fixed white.

## 0.1.0

- Initial scaffold: options, theme, constants, spring and icons.
