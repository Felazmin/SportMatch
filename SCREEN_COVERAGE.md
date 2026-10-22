# Screenshot Coverage Matrix

Updated: 2026-10-08. Project: D:\PTUDDD\test_do_an.

This inventory is based on the seven Owner/Admin flow screenshots supplied in
chat. Each screen is small in these overview images. They establish navigation
and feature groups, not readable typography, original assets or complete rules.
"Implemented" means local demo behavior, not pixel-perfect Figma compliance.

| Image | Screen group | Current coverage | Remaining |
| --- | --- | --- | --- |
| 1 | Owner dashboard | Daily venue selector/all-facility aggregation, hourly capacity/occupancy/locks, confirmed booking value, pending work and linked schedules | Exact Figma composition, richer system-wide financial metrics and actual received revenue |
| 1 | Customers / employees | Customer history; employee roster/shifts; password-confirmed credential grants; separate employee login, own shifts and facility-scoped booking attendance/onsite payment | Recurring shifts/payroll and exact Figma layout |
| 1 | Matches / profile | Owner custom social/tournament drafts/submission, Admin approval, public approved discovery, attendee links, manual fixture/results, future custom-event cancellation/refund requests and private Owner verification | Automatic brackets, court inventory allocation and exact role-specific profile composition |
| 2 | My facilities / add / pending / edit | Facility registry, validated forms, gallery/legal sample images, draft/pending/rejected/approved state, correction/resubmission and approved matching-sport court-type selection with feature descriptions | Original Figma assets/geometry, document PDF uploads and incomplete drafts |
| 2 | Price table | Primary and per-facility weekday/weekend bands, inclusive expiry/surcharge, Owner proposal/Admin review; per-hour booking quotes | Original Figma layout |
| 3 | Calendar / booking detail / requests | Primary/per-facility manual reservations/locks; player booking/day calendars/rescheduling; onsite confirmation and payment review | Original request-specific screen composition |
| 3 | Waiting / expired payment | Booking proof deadline, pending review, rejection/resubmission and restart | Designed timer screens, expiry-driven inventory release and full activity history |
| 4 | Reconciliation / confirmed / net settlement | Confirmed-payment breakdown, refund liabilities, simulated commission/net; onsite separated; recipient snapshots, local payout requests and Admin receipt/rejection ledger | Taxes, actual bank reconciliation and exact Figma composition |
| 4 | Revenue account / revenue report | Service-date/channel/type filters, booking/ticket payments, refunds, daily net bars, recipient account and CSV clipboard | File download, complete financial charting and bank-date reports |
| 5 | Admin login / dashboard / reports / audit settings | Role login, management summary, basic local reports and latest-1,000 operations journal | Dedicated dashboard/charts, system-wide metrics, full audit/settings screens |
| 6 | Venue list / detail | Facility management/detail, public profiles, suspension/reopening, discovery/map/favorites, bookable local courts, scoped ratings/reviews and hourly quotes | Original Figma composition |
| 6 | Owner list / detail | One seeded Owner, private representative/proof submission and Admin password-confirmed verification/correction | Multi-owner directory, arbitrary owner permissions and exact Figma composition |
| 6 | Player list / detail | Admin search/status filters, contact/profile, booking/ticket/dispute links, reasoned password-confirmed login lock/unlock, stale-version checks | Arbitrary role editing, deletion and exact Figma composition |
| 6 | Review list / detail | Completed paid booking reviews, 1-5 stars, public/own-hidden detail, Admin search/status filters, reasoned hide/restore with stale-revision guards; live public rating | Report-a-review flow, reviewer replies, original Figma composition |
| 7 | Approval center / venue review | Unified Admin work center with live category counts/search/filters and links to pending court types/activities/groups/facilities, price proposals, payment proofs, cancellations, refunds and unclosed disputes; facility approve/correction | Complete venue checks and original designed layout |
| 7 | Court types / activities / groups | Court-type/group/activity approval, member review, group covers, linked events, manual fixtures/results, future custom cancellation/full refund requests | Richer group tools, automatic brackets/official standings, seeded cancellation and exact Figma composition |

## Current Entry Points

- Management > Ho so chu san > private Owner submission/Admin review.
- Management > Chi tra demo > recipient account > request > Admin receipt/rejection.
- Future approved/suspended custom activity > Huy hoat dong > reason/confirmation.
- Employee profile > employee-access > specific assigned facilities.

- Staff login > matching Owner/Admin role > Account > management workspace.
- Staff > management > Tong quan > day arrows, shortcuts and linked schedule.
- Staff > management > Lich san & khoa gio > select day/cell > reserve or lock.
- Staff booking detail > Doi lich; agreed prices, duration and IDs remain unchanged.
- Owner > San & gia > De nghi thay doi > clock-plus icon > add tariff > submit.
- Admin > San & gia > review proposed bands > approve or reject.
- Staff > management > Doi soat doanh thu > filters > record detail > original finance record.
- Admin > management > Quan ly nguoi dung > search/filter > profile > access decision.
- Admin > management > Kiem duyet danh gia > search/status > reasoned hide/restore.
- Staff > management > Khach hang > search/returning filter > profile > related record.
- Staff > management > Nhan vien & ca lam > profile > Phan ca > shift detail.
- Admin > management > Trung tam xu ly > category/search > actionable record.
- Owner > management > Quan ly nhom choi > draft/edit > Gui duyet.
- Admin > management > Trung tam xu ly > Nhom choi > approve/reject.
- Player > Community > Nhom choi > join approved custom group > group board.
- Owner > management > Quan ly hoat dong > draft > Gui duyet.
- Admin > work center > Hoat dong > review; organizer activity > registration record.
- Player > Giao luu & giai dau > approved activity > entry form > local ticket.
- Organizer > approved custom tournament detail > Lich dau & ket qua > Xep tran.
- Player > tournament ticket > Lich dau & ket qua (read-only).
- Management > Quan ly giai dau > seed/custom/historical cohort > schedule/results.
- Schedule > Ket qua cac doi; player filters own team; manager changes future
  fixture time/court; Admin corrects completed score with reason.
- Player > completed paid booking > Danh gia san; venue detail > Xem danh gia.
- Owner > My facilities > Add > Save draft > Send approval request.
- Admin > Manage/review facilities > pending filter > approve or request changes.
- Owner > rejected facility > edit > save draft > submit again.
- Account > approved facilities: public business information only; no legal
  sample image or private representative name is exposed in the public profile.

Published active facility profiles now create bookable local inventory using their
court count, opening hours and published flat base rate. Explore/map details open
their public profile/booking form; day calendars and venue-aware rescheduling are
available to managers. Primary bookings/history migrate unchanged. Per-facility
hourly proposals/review, manual reservations/locks and scoped reviews now operate
through the same booking inventory. Existing prices/contracts remain unchanged.

The daily overview covers today through six days ahead for the selected venue or
all published managed venues. The primary venue keeps the original behavior below.
Occupancy counts reserved hourly calendar cells on currently enabled courts within
06:00-22:00, including unpaid reservations, and excludes cancelled bookings.
Disabled-court historical bookings remain in the schedule/value but not occupancy.
Unreserved/unlocked cells include past hours and are not a current availability
promise. Confirmed value is by service date before refunds/fees, not received cash.
Pending work counts cover all service dates and reuse the existing approval rules.

Registration OTP now has an explicit local demo (wrong/expired/resend/success),
with account creation after code confirmation and save retry. Real delivery and
identity verification remain absent. The additional twelve exception-flow
screenshots supplied on 2026-10-07 cover OTP, booking/social refunds and disputes,
check-in/no-show/completion, facility outcomes, permissions and system states.
OTP and local booking/ticket finance, evidence, dispute decisions and staff
attendance are now covered behaviorally. They reuse project-native layouts;
the exact Figma screen composition and every exception variant are not verified.
The twelve references are saved as design_reference/08 through 19 PNG files.

Other User screens (event/tournament payments, automatic tournament brackets,
embedded map/GPS and chat media/calls) are outside these seven images and remain
listed in COMPLETION_STATUS.md. Real identity/legal/bank verification is not
performed. Sample image uploads remain on this device.
