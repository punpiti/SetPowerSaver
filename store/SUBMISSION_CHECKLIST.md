# Microsoft Store submission checklist

## Before building the package

- [ ] Complete the Partner Center developer profile.
- [ ] Reserve **Temporary Laptop Modes** (or the selected final name).
- [ ] Copy the exact Partner Center **Identity name** and **Publisher** values.
- [ ] Install the Windows SDK for `makeappx.exe` and `signtool.exe`.
- [ ] Test every mode on a plugged-in laptop and on battery.
- [ ] Confirm Restore normal returns the original active plan and settings.

## Build and test MSIX

- [ ] Run `scripts\New-Msix.ps1` with the Partner Center identity values.
- [ ] Upload the MSIX to a draft submission and address package validation
  errors, if any.
- [ ] Install the Store test/flight package on a second Windows PC if possible.

## Store listing

- [ ] Paste English copy from `STORE_LISTING.md`.
- [ ] Paste Thai copy from `STORE_LISTING.md`.
- [ ] Host `PRIVACY_POLICY.md` at a public HTTPS URL and enter it in the
  Privacy policy field.
- [ ] Add a support email address.
- [ ] Capture at least four real desktop screenshots at 1366×768 or larger:
  1. Normal state: tray icon and clear CURRENT STATUS card.
  2. Focus active: purple icon and automatic restore time.
  3. Presentation active: orange icon and keep-screen-on description.
  4. Restored state: confirmation notification and Normal status.
- [ ] Add the generated Store logo from the MSIX assets, or replace it with a
  reviewed final brand asset.
- [ ] Complete category, pricing, availability, and age-rating questionnaire.

## Certification notes

Paste this into the Partner Center certification-notes field if useful:

> This is a local system-tray utility. Power settings are changed only after
> the user chooses a temporary mode. The app snapshots the current power plan
> and restores it automatically after the mode ends, when AC power is
> connected for Battery mode, when the user chooses Restore normal, or on a
> clean app exit. The app has no account, analytics, advertising, or network
> functionality.
