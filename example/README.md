# sileo_toast example

A playground for every option of [sileo_toast](../README.md). Light and dark follow the system.

## Run

```sh
cd example
fvm flutter run            # pick a device: iOS, Android, macOS or Chrome
fvm flutter test           # widget smoke tests
```

## Controls

Set the options, then fire a toast with a type button. Tap or hover a toast to expand it; swipe it away to dismiss it.

- **Position**: where the toast appears (six positions).
- **Size**: `compact` pill or `large` card.
- **Fill**: the theme fill, Sileo light (`#1A1A1A`), Sileo dark (`#F2F2F2`) or a custom blue.
- **Roundness**: corner radius 0, 8, 12, 16 or 24.
- **Duration**: 2 s, 6 s or persistent.
- **Autopilot**: default, off, or custom (expand after 500 ms, collapse after 3 s).
- **Description**, **Button**: show a description line and an action button.
- **Trailing image** (large only): a built-in gradient thumbnail.
- **Second button** (large only, needs Button): a `Decline` / `Accept` pair.
- **Separate id**: off, a new toast morphs the visible one; on, toasts stack.
- **Types**: Success, Error, Warning, Info, Action (with button), Custom icon, and Promise, a loading toast that
  resolves after 2.5 s as the chosen outcome (success, error or action).
- **Actions**: dismiss the latest toast, clear all, or clear the selected position.

A toast's buttons dismiss their own toast.
