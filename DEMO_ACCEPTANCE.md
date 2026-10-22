# Demo Acceptance Checklist

Updated: 2026-10-08. Scope: local Flutter demo, not a production service.
Status: NOT yet complete against every Figma screen.

## Accounts

- Player: `0901234567` / `Demo1234`.
- Owner: `owner@nvh.demo` / `Demo1234`, through staff login.
- Admin: `admin@nvh.demo` / `Demo1234`, through staff login.
- Employees: manager grants a password/permissions in employee profile > employee-access;
  Account > Khong gian nhan vien signs in with NS ID or roster phone. No seeded password.

## Local Workflows To Test

| Area | Entry / expected local behavior | Boundary |
| --- | --- | --- |
| Login / registration / recovery | Player login, signup OTP, recovery OTP, validation/expiry/resend | Local OTP simulation, not SMS |
| Booking | Primary or approved public facility > date/court/hour > confirm > history/payment; approved facility hourly bands apply to each hour | Existing bookings retain agreed prices |
| Payments / cancellation / refunds | Proof submission > manager review > cancellation decision > refund receipt; Admin dispute decision/closure | No bank transfer or external settlement |
| Tickets / attendance | Social/tournament registration > ticket/QR > staff code lookup > check-in/completion | Local QR/code checking, no camera/server signature |
| Tournament management | Management > Quan ly giai dau; current/custom/historical cohorts; search/date filters | Not an automatic tournament engine |
| Tournament schedule/results | Schedule two registered teams; cancel or change a future fixture; enter scores after both check-ins and match end; Admin reasoned correction | Court label does not reserve booking inventory |
| Team views | Ticket > schedule > own-team/state filters; team result summary and sorting | Summary does not declare official rankings/champions |
| Activities / groups | Draft/review, optional member approval, group-linked activities and actual registration/posting | Group media/automatic brackets remain |
| Facilities | Draft/review/correction/suspension > public discovery > booking/calendar/reschedule; facility manual reservations/locks; hourly tariff proposal/Admin review; scoped reviews/daily dashboards | Complete legal/PDF and incomplete drafts remain |
| Court types | Management > Loai san; Owner draft/edit/submit; Admin approval/correction/suspension/reopening; facility form selects approved matching-sport types | Optional type link; standard legacy profiles remain supported; no new sport engine |
| Operations | Calendar holds/manual bookings/reschedule, tariff surcharge/expiry, customers, roster/shifts, employee login and facility-scoped attendance/onsite payments | Shifts remain primary-roster based |
| Owner verification | Management > Ho so chu san; Owner submits proof; Admin password-confirmed verification/correction | Local record, not legal identity checking or arbitrary role editing |
| Whole activity cancellation | Future custom activity > cancel with reason; tickets/fixtures cancelled; confirmed fees enter pending 100% refund | No seeded recurring-event cancellation or automatic money transfer |
| Payouts | Management > Chi tra demo; save recipient, request against eligible net balance, Admin receipt/rejection | Local evidence ledger, not bank execution |
| Community / reviews / chat / map | Local forum, groups/expenses, booking reviews/moderation, text chat, external map links | No remote replies/chat media/calls/embedded GPS |

Screens, model tests and widget tests are not physical-device acceptance. APK
installation and a complete manual walkthrough on the user's device are not verified.

## Functional Backlog

- Arbitrary Admin role editing beyond existing fixed identities/employee permissions.
- Facility legal/PDF completeness and incomplete-draft support.
- Richer system-wide financial reports beyond scoped/all-facility daily booking metrics.
- Richer group tools beyond existing membership/posts/expenses/events and cover images.
- Automatic tournament groups/brackets/advancement, official tie-break rules,
  walkovers, court inventory allocation and seeded whole-event cancellation.
- Configurable cancellation policies.
- Richer system-wide local reports and bank-date reporting.

Production authentication/SMS/bank/push/remote sync are outside the agreed
demo-first scope; they are not silently counted as finished demo features.

## Visual Backlog

The 19 overview images establish broad flows, not readable pixel-level specs.
Figma design context and screenshots still returned the Starter quota error on
2026-10-08. Exact screen geometry, original imagery and all exception variants
cannot currently be checked. The existing sample court image is not verified
as a badminton court or as the original Figma venue photograph.

Required comparison input: full-file PDF or per-screen PNG exports at 1x/2x.
See `SCREEN_COVERAGE.md` for the reference groups and `COMPLETION_STATUS.md`
for implementation/verification history.
