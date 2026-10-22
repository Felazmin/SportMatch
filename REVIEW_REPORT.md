# NVH Sports Review

Historical audit. The subsequent implementation addressed the six confirmed
defect groups below and added social-event/tournament demo workflows.
See `COMPLETION_STATUS.md` for current coverage and verification. Findings below
are retained as the original reproduction record, not current open bugs.

Date: 2026-10-06 (Asia/Saigon).
Project: `D:\PTUDDD\test_do_an`.
Scope: current Flutter source, tests, bundled assets, Android/iOS configuration,
and available Figma coverage evidence. No production source was changed.

## Findings

### 1. [P2] Empty contact phone is accepted but not saved

Source: `lib/screens/demo_account_screens.dart:220`.
Reproduction: register an email account, set its contact phone, open Settings,
clear the phone field and save. The form accepts empty input and reports that
settings were saved, but `session.contactPhone` still contains the old number.
The update is skipped whenever the field is empty. Either support clearing the
optional contact or explicitly reject/explain empty input; do not report a change
that was not applied.

### 2. [P2] The booking success Home button returns to the previous tab

Source: `lib/screens/booking_screen.dart:775`.
Reproduction: Explore > venue > schedule > confirmation > success > Home.
The Navigator pops to its first route, but `HomeScreen._tab` remains Explore.
The user sees Explore instead of Home. Returning to the root must also select
the Home tab. The same issue is reachable when booking from the Account wallet.

### 3. [P2] Fixed layouts overflow or clip accessible text and the keyboard

Sources: `lib/screens/auth_screen.dart:245`, `:508`, `:571`, `:619`;
`lib/screens/venue_browse_screen.dart:179`.
At 320x879 with text scale 2, Login produces RenderFlex overflows of 1, 48 and
30 pixels during the inspection flow. Social-provider labels overflow their
fixed-height buttons; phone/email and Face ID labels are visibly clipped.
Registration does not emit an overflow in the tested case, but its fixed mode
control and some error text are also truncated at this scale.
At 879x402 with a simulated 220-pixel keyboard inset, Explore also overflows.
The fixed header/filter controls consume more height than the remaining body.
Use adaptive minimum heights and scrollable/bounded controls. Add regression
coverage for large-text authentication and landscape keyboard layouts.

### 4. [P2] Invalid registration length is reported as a duplicate account

Sources: `lib/screens/auth_screen.dart:60`;
`lib/auth/demo_session.dart:649` and `:651`.
Reproduction: submit a new phone number with a 61-character name or a
129-character password and matching confirmation. Form validation accepts them;
the session rejects their length. Every registration failure is then described
as an already-registered identifier. Registering the same number with valid
lengths succeeds, proving it was not a duplicate. Align form bounds with the
model and distinguish validation failures from duplicate identifiers.

### 5. [P2] In-progress bookings/classes have incorrect time states

Sources: `lib/screens/booking_screen.dart:808` and `:939`;
`lib/screens/demo_account_screens.dart:532`.
A booking from 12:00 to 14:00 is labeled Upcoming at 12:30 because the UI only
checks whether its end is in the future. An Academy class advertised as lasting
90 minutes is marked Ended immediately after its start. Use distinct upcoming,
in-progress and ended states, with the actual duration for classes. Time-bound
screens also need an agreed refresh policy on resume/time boundaries.

### 6. [P2] Registration privacy information contradicts persistent storage

Source: `lib/screens/auth_screen.dart:457`.
The privacy dialog says account data is kept only in application memory.
The production entry point (`lib/main.dart:18`) supplies `SecureSessionStore`,
which writes an encrypted persistent snapshot containing account credentials,
profile/contact data and demo histories. Existing restart tests confirm
persistence. Use one consistent, accurate local-storage disclosure across
registration, Account, Help and README. This is a copy/behavior inconsistency,
not a claim that a remote data leak was found.

## Figma Coverage Still Missing

These are missing demo screens/workflows, distinct from intentionally disconnected
production integrations. Node references come from the earlier successful file
inventory; a fresh metadata request during this review was rate limited.

| Area | Missing or incomplete implementation | Representative nodes |
| --- | --- | --- |
| Social events/tickets | Discovery, details, reservation, personal tickets and ticket states | `3421:415`, `3425:1112`, `3430:1645`, `3430:1769` |
| Ticket cancellation/check-in | Cancellation branches, QR/check-in and related results | `3430:1876`, `3430:2004`, `3430:2111`, `3531:448` |
| Tournaments | Details, entry form, confirmation and registered schedule | `3369:5`, `3410:1097`, `3410:1383`, `3410:1469` |
| Forum/cost sharing | Forum/group activities and shared-cost calendar | `3356:5`, `3363:5` |
| OTP/recovery | Code entry, invalid/expired codes, recovery and result screens | `3531:20`, `3531:52`, `3531:82`, `3531:129`, `3531:148`, `3531:178`, `3531:199` |
| Transfer/payment exceptions | Designed methods screen, instructions, proof submission/resubmission, approval/expiry states | `3352:4`, `3389:393`, `3486:5`, `3531:322`, `3531:340` |
| Cancellation/refunds | Request, waiting, rejection and refund-result workflow; current local cancellation is immediate | `3394:1398`, `3394:1521`, `3394:1638`, `3394:1762`, `3531:413` |
| Disputes | Booking/ticket-linked evidence, owner responses and Admin outcomes; local Help tickets are not this workflow | `3531:604`, `3531:628`, `3531:662`, `3531:679`, `3531:737` |
| Public/system states | Dedicated approved-facility, loading/error/permission layouts and branches | `3531:793`, `3531:821`, `3531:846`, `3531:870`, `3531:887` |
| Owner/organizer | Entire role workspace: dashboard, venue CRUD/approval/pricing, calendars/requests, reconciliation/revenue, customers/staff and decisions | Section `3484:53`, additional states `3531:903` |
| Admin | Entire role workspace: role login, dashboard/reports, entities, moderation, approvals, transactions, disputes and permission changes | Section `3484:4`, additional states `3531:1925` |

The Home nearby-ticket chip currently opens generic venue Explore
(`lib/screens/home_screen.dart:477`), not ticket discovery. This is an incomplete
entry point for the social-ticket flow, not evidence that tickets are implemented.

## Partial Coverage And Release Readiness

- Map is address search/copy plus external Google Maps, not an embedded map/GPS
  experience matching the full design.
- Chat text/emoji/search/read state is local-only. Photo/voice/calls are notice
  dialogs, avatar photos are initials, and no live presence/delivery is claimed.
- Payments have only unpaid pay-at-venue information. No real transfers, refunds,
  OTP, social/biometric login, push notifications or cross-device synchronization.
- The venue catalog contains only one demo venue. Filtering works, but other
  sports/multi-venue discovery need more approved/demo data.
- Android launcher label remains `test_do_an`; iOS display name is `Test Do An`.
  App identifiers still use template naming. Android release signing uses the
  debug key (`android/app/build.gradle.kts:36`). Fine for the current local demo,
  not a completed branded production release configuration.

## Verification And Limits

- Reran the normal suite: 132 tests passed.
- Reran `flutter analyze`: no issues found.
- Verified 75 bundled project assets have nonempty bytes.
- Inspected generated portrait screenshots and captured large-text Auth screens.
- Separate review probes reproduce the observed defects without editing app code.
  They assert the current unexpected behavior; passing them does NOT mean the
  defects are fixed or that they are production acceptance tests.
- The normal suite had not covered the reproduced edge cases. Green existing
  tests do not establish complete Figma coverage or absence of all defects.
- Figma's Starter-plan MCP limit blocked the fresh metadata read. Pixel-perfect
  compliance for all frames, including inaccessible assets, was not reverified.
- These are widget/domain tests with synthetic viewports and clock values, not
  physical-device acceptance tests. Real Android map launching, platform storage
  lifecycle/restore behavior and iOS execution still need device-specific checks.
- No new APK was built or installed in this review. The preceding debug APK
  remains available; no app code was modified during this review.

Review probes:
`C:\Users\Minh Phat\Documents\New project\figma_review_20261006\review_probes_test.dart`.

Run from the project directory:

```powershell
flutter test 'C:\Users\Minh Phat\Documents\New project\figma_review_20261006\review_probes_test.dart' --reporter expanded
```

Recommended order: fix the confirmed defects and add real regression assertions;
then implement social event/ticket demos, tournaments, forum/cost sharing,
payment/cancellation/dispute states, and the Owner/Admin role workspaces.
