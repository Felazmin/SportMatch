# NVH Sports Demo

Flutter Android/iOS project for the NVH Sports booking demo. Home, authentication
and account styling use the available Figma assets. Additional functional screens
reuse the same theme; they have not been pixel-matched to inaccessible Figma frames.
The chat list/detail layouts follow the readable screenshot supplied on October 6.
Original chat avatar assets are unavailable, so initials are used temporarily.

## Booking Policies, Revenue And Event Courts

Primary Admin settings include cancellation threshold, early/late refund
percentages and minimum notice. Owner facility policy edits require the existing
Admin publication process. Each booking captures its own agreed policy; later
settings never rewrite existing contracts. Ticket refunds still use their separate
fixed 24-hour/100% rule. All monetary operations remain local demonstrations.

Owner/Admin revenue is reachable from the overview and settlement report. It
uses actual locally recorded receipt/refund dates, not scheduled playing dates.
Daily charts, period/date/facility/channel filters and CSV clipboard export are
available. Legacy undated approved payments are marked, not assigned false dates.
Approved bank transfers may be given a manual received date; there is no bank feed.

Activity management opens the seeded event catalog. Managers may cancel one
future occurrence, cancel linked future fixtures and queue full refunds for paid
tickets. The next rolling occurrence is unaffected. Seeded/custom published events
can allocate primary courts through event/activity/tournament details. Allocations
lock the entire event duration in the existing seven-day booking calendar, prevent
double booking and release on whole cancellation. Calendar event locks open the
allocation editor instead of allowing independent unlocks. Old label-only fixture
schedules remain compatible when there is no explicit allocation.

These additions have focused model/widget tests, not a fresh full-project test
certification. The existing APK predates the updates. Exact Figma parity and
physical-device acceptance remain unverified; see FIVE_GROUP_ACCEPTANCE.md.

## Facility Drafts And Documents

Owner forms can retain incomplete input with `Luu thong tin dang nhap`,
resume it from the facility list after restart, or discard it with confirmation.
Incomplete input is separate from validated/published facility contracts.
Saving a complete facility clears the matching partial form; obsolete revisions
cannot overwrite changed profiles. Local save failures retain input for retry.

Legal demo attachments accept PNG/JPEG or PDF, at most 400KB. PDF selection
requires an unlocked, readable document of 1-50 pages. Owner/Admin can view
attached PDFs in-app; public profiles always omit legal attachments. Use sample
documents only, never genuine personal records. File selection uses Flutter's
`file_selector`; viewing uses `pdfrx`. Native picker/device integration is not
certified by unit/widget tests. The existing APK has not been rebuilt.

## Run Commands

```powershell
flutter pub get
flutter run
flutter analyze
flutter test --dart-define=SCREENSHOT=true
flutter build apk --debug
```

If Gradle's Unix-domain socket path is too long on Windows:

```powershell
$env:JAVA_TOOL_OPTIONS = '-Djdk.net.unixdomain.tmpdir=C:\Windows\Temp'
flutter build apk --debug
```

APK: `build/app/outputs/flutter-apk/app-debug.apk`.
Optional test screenshots: `build/previews/`.
Kotlin incremental compilation is disabled in `android/gradle.properties` to
avoid cross-drive cache errors when the Pub cache is on C: and the project on D:.

## Test Account

Phone: `0901234567`, or email: `demo@nvh.vn`.
Initial password: `Demo1234`. Both aliases refer to the same account.
After changing the password, use the new password for both aliases.
New registrations and changed passwords remain on this device across restarts.
Use test information and passwords only.

## Demo Workflows

### Employee Access, Facilities And Group Membership

- Owner/Admin > Nhan vien & ca lam > employee profile > employee-access.
  Set an employee password and schedule/attendance/onsite-payment permissions,
  confirming with the current manager password. A worker signs in from Account >
  Khong gian nhan vien using NS ID or roster phone. Revoked/inactive credentials
  cannot log in. Employee sessions are separate from player/Owner/Admin identities;
  they cannot grant permissions or access refunds, user administration or finances.
  No employee credentials are seeded. This is encrypted local demo access, not
  production authentication. Select all facilities or specific published facilities;
  schedules, attendance and onsite collection enforce that assignment.
- Approved active facilities appear in Explore/map results with their own supplied
  image and price. Public facility > Dat san selects that facility's court count,
  opening hours and flat base price. Booking success/history/payment preserve the
  venue name, address and contracted rates. Suspension blocks new bookings but
  retains earlier records. Staff facility detail > Lich san shows its daily bookings;
  existing bookings can be rescheduled without changing ID, duration or price.
  Facility calendars support manual reservations and scoped locks/unlocks.
  Bảng giá theo giờ opens Owner proposals/Admin review with weekday/weekend bands,
  surcharge and inclusive expiry. New booking/manual quotes use each hourly rate.
  Review totals and public ratings are scoped to that venue; daily dashboards can
  select one venue or all venues, using their own court counts and opening hours.
- Primary tariff proposals now include surcharge and optional inclusive end date.
  The approved quote includes the surcharge only within the tariff's date/hour
  range; previously agreed booking prices stay unchanged.
- Group drafts can enable Duyet thanh vien moi. Joining then creates a pending
  request; members cannot post until Owner/Admin approves it. Rejection needs a
  reason; withdrawal/reapplication and approval use revision guards and persistence.
- Activity drafts can select an approved badminton group. After activity approval,
  its link appears on the community group and opens the actual registration flow.
  Registration requires joined membership. Suspending a group hides its activities
  from new registration while keeping existing tickets and finance/attendance.
- See FIVE_GROUP_ACCEPTANCE.md for the explicit remaining work. These additions do
  not establish exact Figma layout/assets or finish every feature in all five groups.

### Custom Activity Approval And Tickets

- Owner: management > Quan ly hoat dong > Tao hoat dong. Choose social/tournament,
  fixed date/hour, 1-4 hour duration, capacity, fee and rules; save draft > Gui duyet.
  Rejected drafts can be corrected and resubmitted. Approved definitions cannot
  be edited, so existing ticket prices/schedules/rules are stable.
- Admin: work center > Hoat dong > approve/reject with reason. Suspension stops
  new registration, NOT an event cancellation: existing tickets, QR payloads and
  payment/cancellation/refund/attendance workflows remain in force. Reopen before
  the scheduled start. Organizer detail links to actual registration records.
- Player: Giao luu & giai dau includes approved custom activities. Search and join
  through the same entry form/ticket pages. Draft/pending/rejected/suspended/ended
  custom activities do not appear as registerable catalog entries.
- Custom tickets store immutable event snapshots. Restoration validates the
  registry/definition link, capacity and finance records atomically; old seeded
  tickets and stores without activities migrate unchanged. Failed writes retry.
- Primary demo venue/badminton only, one seeded Owner, 100 custom activities,
  future dates within 30 days and whole-hour schedules within 06:00-22:00.
  Optional primary court allocation now locks the full event window against the
  booking calendar within its seven-day horizon. No automatic brackets, custom
  media or external delivery. The existing sample court photograph is reused; it is
  not a verified badminton/venue photograph or a newly matched Figma event asset.

### Tournament Fixtures And Results

- Organizer: management > Quan ly hoat dong > approved tournament > Lich dau &
  ket qua > Xep tran. Select two actual live registration ticket IDs, a 30-minute
  slot inside the event and court 1-3. Team labels are visible below the IDs.
  Team/court overlaps across tournament matches are rejected. Event allocation
  reserves courts against ordinary bookings; scheduled/rescheduled fixtures must
  use those courts when an allocation exists. Without an allocation, fixture
  court labels alone still do not reserve ordinary booking inventory.
- After the match end, Owner/Admin can enter a non-tied 0-99 aggregate score
  only when both teams have checked in. Chosen event rules determine scoring;
  this is not a badminton set/rules engine. Owner cannot overwrite a result;
  Admin may explicitly correct it with a reason and a stale-revision check.
  A scheduled match can be cancelled with a reason; cancelling a match does
  NOT cancel registration tickets or automatically refund their fees.
- Player: Ve cua toi > tournament ticket > Lich dau & ket qua. Read-only team
  labels, times and results are shared with that tournament's registered players,
  not contacts/phone numbers. Cancelled tickets retain historical access.
- Matches survive restart; ticket links, attendance, counters, score states and
  overlapping slots validate before atomic restore. Old snapshots migrate;
  failed saves retry without duplicate fixture creation. Cap 1000 matches.
- Management > Quan ly giai dau includes current seed events and approved/custom
  tournaments plus historical registration dates. Accent-insensitive search and
  not-ended/ended/all filters preserve old event dates rather than shifting them.
- Players can filter all/own team fixtures and scheduled/completed/cancelled
  states. Ket qua cac doi derives played/wins/losses/scored/conceded/difference
  from completed matches only; zero-result and cancelled-ticket rows are retained.
  Sort by name or number of wins is a view option, NOT an official tie-break,
  bracket advancement or winner declaration. Team contacts are not shown.
- Before a scheduled match starts, managers may change its time/court with a
  5-300 character reason. IDs/teams stay fixed; within-event bounds and court/team
  overlap checks are repeated. Admin result corrections also need a reason,
  different valid scores and current revision. The local operation journal
  records old/new time/court or scores; latest reason stays on the match.
  Journal is capped at 1000 entries, not a permanent external audit ledger.
- No automatic groups/brackets, official standings/tie-break rules, seeding,
  winner advancement, walkovers or remote synchronization.
  Original Figma geometry/assets remain unverified; design context and screenshots
  still returned Starter-plan quota errors when retried on 2026-10-09.

### Owner Verification, Cancellation And Payouts

- Management > Ho so chu san: Owner submits representative/contact and a PNG/JPEG
  proof; Admin verifies or requests correction with password and revision checks.
  This is a private local review record, not legal identity validation or a global
  permission gate. No representative proof is exposed publicly.
- Approved/suspended future custom activities can be cancelled with a reason.
  Live registrations and future fixtures are cancelled atomically. Confirmed fees
  create pending 100% refunds; money is not automatically transferred. Existing
  cancelled ticket histories remain intact. Seeded events now support cancellation
  of one known occurrence (current catalog, existing tickets or allocated courts),
  never permanently cancelling the rolling event ID. Manager catalog entries keep
  old future ticket/lock cohorts reachable after the sample schedule changes day.
- Management > Chi tra demo: Owner saves a recipient account with password
  confirmation, then requests a payout against ended, confirmed transfer revenue.
  Pending/recorded requests reserve the balance; onsite receipts are excluded.
  Admin records evidence/reference or rejects with a reason. Recipient snapshots
  remain unchanged after account edits; duplicate references and stale actions fail.
  A dispute/refund can reduce the balance, including a visible demo deficit.
  This ledger does not execute or verify bank transfers. Five incorrect Admin
  confirmation passwords trigger a 60-second local cooldown.

### Play Group Approval

Approval-required custom groups support reasoned membership revocation from the
Owner/Admin group detail. The member's existing posts, tickets and finance are
retained, but new posts/linked registrations require membership again. Players
see the reason and may reapply for review. Stale revisions and account changes
reject; failed writes use the save-retry banner without repeating the action.
This is not a permanent ban or a revocation tool for immediate-join/sample groups.

Group drafts can select/remove an optional PNG/JPEG cover up to 400 KB.
The cover survives rejection/correction and review transitions; only approved
groups expose it publicly on their community board. This is local media only.

Latest facility/group work was verified with focused tests only, at the user's
request. No whole-project run or APK rebuild was performed for this batch.
The previously linked APK does not include these latest source changes.

- Owner: management > Quan ly nhom choi > Tao nhom > save draft > group detail >
  Gui duyet. Name/sport/description are editable only while draft or rejected.
- Admin: management > Trung tam xu ly > Nhom choi, or Quan ly nhom choi.
  Approve a pending group, reject with a reason, suspend an approved group or
  reopen a suspended group. Rejected groups must be edited and submitted again.
- Player: Community > Nhom choi. Only approved custom groups are public; joining
  enables posting to that group's board. Suspending hides the group/posts and
  prevents joining/new posts without deleting memberships or history. Reopening
  restores that history. The two fixed sample groups remain unchanged.
- Offline local demo, one seeded Owner, maximum 100 custom groups. Optional member
  approval/revocation, PNG/JPEG cover upload and linked group events are available;
  no legal document upload for groups, remote delivery or exact
  Figma layout matching. Stale forms/role changes cannot approve an outdated group.

### Daily Staff Overview

- Owner/Admin: Account > management > Tong quan. Day arrows cover today through
  six days ahead; shortcuts open the calendar, customers, employees, facilities,
  settlement, attendance and (Admin only) approval center. Booking rows open the
  linked workflow rather than a separate sample detail.
- Occupancy uses hourly cells on currently enabled courts, 06:00-22:00, at the
  primary demo venue. Unpaid holds count, cancelled bookings do not. Disabled-court
  historical bookings still appear in the list but not the occupancy denominator.
- Unreserved/unlocked hours include past hours. Confirmed booking value is by
  service date before refunds/fees, not actual cash received. Pending work covers
  all dates; this is not a system-wide multi-venue financial dashboard.

### Ticket Finance And Attendance

- Player: Account > Ve & lich tham gia > registration > Thanh toan / huy / hoan /
  khieu nai. Submit a sample image and reference for owner review.
- Owner/Admin: management > Ve, check-in & hoan tien > ticket or booking.
  Review ticket proof/cancellation, check attendance and record refund evidence.
- Staff check-in requires approved payment; use the ticket code or paste its
  full demo QR payload. Check-in opens 30 minutes before start. Completion and
  no-show are available after the scheduled end and require confirmation.
- Ticket cancellation is requested at least 24 hours before start and retains
  capacity until approval. Approved paid tickets queue a 100-percent demo refund.
- Booking cancellation stores the request time: at least two hours before start
  refunds 95 percent; later pre-start requests refund 50 percent. A delayed owner
  approval does not change that policy amount.
- Admin disputes can uphold the result or queue a demo refund (95 percent for
  bookings, 100 percent for event tickets). Recording a refund in the UI requires
  a sample image and reference, and does not transfer money.
- No camera scanner, bank integration, remote delivery or server validation.
  Gallery drafts for the new ticket/refund forms do not recover an interrupted
  OS image-picker session. Local ledger and evidence remain encrypted on-device.

- Registration > OTP confirmation: explicit local code `123456`, five-minute
  expiry, maximum five wrong attempts and a 60-second resend cooldown. Both
  phone and email registration use this offline demo; no SMS/email is sent.
  The UI creates an account only after the correct code. Returning to edit or
  resending invalidates the old challenge. Pending names/passwords/challenges
  are not persisted; restarting requires beginning registration again.
- Verified registration displays saved-success or pending-save status. Failed
  writes can retry without creating another account. Continuing with an unsaved
  account requires acknowledging that it may be lost after closing the app.
  The model's low-level `register` remains available for local fixture creation;
  this is a UI workflow demo, not a backend security or identity-verification gate.

- Owner management > San cua toi: create/edit facility profiles with contacts,
  court count, opening hours, reference rate, gallery photo, amenities, legal
  sample image and cancellation policy. Save draft then send for Admin review;
  sample photos are required for submission. Never upload real personal papers.
- Admin management > Quan ly & duyet co so: pending queue, approve/request
  corrections, suspend/reopen public visibility. Editing/rejection leaves the
  last approved public profile unchanged. Stale form/review revisions are denied.
- Account > Co so da duyet: approved non-suspended profiles only. Legal sample
  image and private representative name are excluded from the public model/view.
  Published active profiles create facility-specific booking inventory and join
  discovery/map results. Primary-venue booking remains backward compatible.
  Drafts/reviews survive restart, and failed saves can retry without duplicate
  records. The registry is limited to 20 local sample facilities.

- Staff account > management workspace > Quan ly van hanh: Owner proposes
  hourly prices and open/closed state for each of the three demo courts. Admin
  approves or rejects with a reason. Published settings stay unchanged while
  pending/rejected. Approved rates affect discovery filters and new reservations.
  Existing bookings retain their quoted rates; stale confirmation quotes are
  rejected instead of silently charging a different total. Closing a court only
  blocks new reservations, not existing bookings.
- Operations also contains employee roster create/edit/inactive state (not staff
  login accounts), customer booking history, booking-date-filtered payment/refund
  summaries, and a local operations journal capped at the latest 1,000 entries.
  Reports exclude unpaid pay-at-venue amounts and event/tournament registrations.
- Admin > operations > accounts can block/unblock local player login (both seeded
  aliases obey the block). Moderation hides/restores local forum posts. These
  controls preserve history and cannot grant an ordinary account management roles.

- Login > Danh cho Chu san / Admin: choose the matching role. Owner email is
  `owner@nvh.demo`; Admin email is `admin@nvh.demo`; initial password for both
  is `Demo1234`. These are separate local staff identities; registering an
  ordinary account with the same email never grants management permissions.
  Account > management workspace opens the booking calendar and review queues.
  Admin additionally has a local player directory and operations login-block controls.
- Booking details > payment/evidence: start a 30-minute demo transfer attempt
  (never later than booking start), select a PNG/JPEG up to 400 KB and submit
  with a reference. Images are copied into encrypted local storage, not uploaded.
  Android lost-picker results are recovered as drafts, never auto-submitted.
  There is no real bank account and no money should be transferred.
- Owner/Admin can approve or reject evidence; rejected/expired attempts allow
  correction/restart. Submitted evidence stays pending until reviewed rather
  than expiring while waiting for staff. Storage failures offer save retry.
- Bank-transfer bookings require cancellation approval; pending/rejected requests
  keep the slot reserved. Approval releases the slot and, for approved payments,
  queues a demo refund record. Recording a refund does not transfer money.
- Booking/ticket disputes have per-account history, an Owner response and an
  explicit Admin decision. A refund decision queues a local refund; recording
  the refund is a separate action and never transfers money.
  These workspaces cover one demo venue, not complete multi-venue/admin management.

- Home / Account > Community: local forum, group membership/boards and posting;
  authors can delete their own posts. Local accounts share the device's boards.
  Expense splitting/history is private to each account. Integer remainder is
  allocated in name order so shares always sum to the original amount.
- Login > Forgot password: explicit offline recovery demo, displayed code 123456,
  five-minute expiry, 60-second resend cooldown and five wrong attempts maximum.
  Passwords require 8-128 characters with letters and digits. No SMS/email is sent;
  this is not production identity verification. Save failure can be retried.

- Home > Giao luu / Giai dau (or Xe ve gan toi): discovery, accent-insensitive
  search, details, ticket quantity / doubles-team entry, confirmation and personal
  registrations. Account > Ve & lich tham gia lists both event types. Capacity is
  shared across local accounts; duplicate entries are rejected. Unpaid entries
  without a transfer attempt can cancel before start. Transfer entries use the
  cancellation review flow above. QR contains a ticket reference without contacts.
  Check-in is a local simulation, available 30 minutes before start until the
  event ends, not real attendance verification. Save failures allow retry without
  duplicates. Registrations survive restart and old snapshots remain compatible.

- Home, venue search, sport/price/rating filters, featured venues and favorites.
- Select court, date and duration; authenticate without losing the draft;
  confirm booking; view history/details; cancel future bookings and release slots.
- Wallet: `DEMO10` (10%), `DEMO20` (20,000 VND, minimum 120,000 VND),
  `DEMO30` (30,000 VND, minimum 240,000 VND). Each account gets three demo codes.
  Each code can be attached to one non-cancelled booking; cancelling returns it.
- Points: one demo point per 1,000 VND of discounted booking total, rounded down.
  Cancellation removes that booking's points. The seeded account has 1,040
  starting points plus its two seeded bookings, initially 1,280 points.
- Academy: two demo classes, registration confirmation, personal schedule,
  duplicate/capacity checks and future-class cancellation. Fee is unpaid.
- Account: edit name, contact phone, change password using the current password,
  payment-at-venue information, points ledger and wallet.
- Help: FAQs and local support-ticket creation/history/closure. Tickets are not
  sent to staff or a server.
- Account > Tin nhan: five sample conversations, accent-insensitive name search,
  sport/unread filters, read badges, text/emoji sending and local history.
  Save failures retain the draft and can be retried without duplicate messages.
  Calls, photos and voice messages are not connected; no automatic replies,
  remote delivery, actual live presence or real event confirmation are claimed.
- Map tab: address search/copy, venue details and external Google Maps search
  or directions. Nearby chips request an external sport search. The app does
  not contain an embedded map, collect GPS, invent coordinates or estimate distances.

## Storage And Limits

Admin > management > Quan ly nguoi dung searches name (including without accents),
email or contact phone and filters active/blocked accounts. Open a profile to view
court/ticket history and disputes. Lock/unlock requires a reason and the current
Admin password; history stays intact and stale forms cannot overwrite a newer
decision. Five wrong confirmations wait 60 seconds across logout/login, but this
in-memory limit resets when the app restarts. Decisions/reasons persist; confirmation
input does not. This is not server-side identity verification or production abuse
protection. Owner/player access, arbitrary role changes and staff-account deletion
are not provided by this directory. Other staff actions keep their existing guards.

Staff > management > Doi soat doanh thu shows confirmed local booking/ticket
payments, gross/vouchers, pending and recorded refunds, daily net and individual
finance links. Filter by service date, payment channel or booking/ticket. The copy
icon puts CSV for the current filters on the clipboard, not a downloaded file.
Simulated transfer fees default to 3 percent (0/3/5 percent selectable) on the
amount retained after refunds, rounded down per record; onsite payments have
zero simulated fee. Pending refunds are reserved, not subtracted again when
recorded. Open cancellation/dispute net is included but flagged under review.
No provider fee rule, tax, bank balance, recipient account, or actual payout is
verified. These are estimates based on local confirmations and service dates.

Player > completed paid booking > Danh gia san submits one 1-5-star review.
Venue detail > Xem danh gia opens public reviews; authors also see their own
hidden reviews and moderation reason. Admin > management > Kiem duyet danh gia
supports search/status and reasoned hide/restore. Hidden scores do not contribute
to public ratings; no public reviews uses the explicitly labeled 4.9 sample
fallback. This does not verify attendance/payment with a real venue or bank.

Staff > management > Khach hang searches booking/ticket contact names and phones,
filters customers with at least two reservation records (including cancellations)
and opens venue-scoped histories; this is not a verified return-visit metric. Confirmed paid totals
are before refunds, not net revenue. Accounts without venue records are excluded.
Admin > management > Trung tam xu ly combines pending facility/price/payment/
cancellation/refund work and unclosed disputes. One case can represent multiple
work items; links reuse guarded detail actions. Court-type/group/activity authoring
queues are included. Employee delegation and multi-venue booking are described above.

Staff > management > Nhan vien & ca lam searches roster name/phone/job and filters
active/inactive employees. Open a profile > Phan ca to schedule 1-12 whole hours
between 06:00 and 22:00 in the next 30 days. Overlapping shifts are rejected.
Shift detail records manager-confirmed arrival from 15 minutes before start,
completion/absence at end, or reasoned cancellation before start. Refresh time
using the refresh icon. Cancellation releases the time slot; history remains.
These shifts are manager-entered demo records, not GPS attendance, payroll or
recurring schedules. Employee login and booking capabilities are granted separately.

Admin > management > Khieu nai > select a case > record a structured decision.
The close action becomes available immediately for an upheld result, or after
staff records a linked refund with its reference and image receipt for a refund
decision. Confirm Dong ho so to retain a one-time closure date and audit; the
linked player/Owner can view the same closed result. Saving failures use the
existing retry banner, not a second closure. Legacy untyped decisions stay open.
No actual refund is verified and no notification is delivered to another device.

Owner > management > San & gia > De nghi thay doi > clock-plus icon adds a
court tariff for weekdays (Monday-Friday) or weekends (Saturday-Sunday), whole-hour
range, surcharge, effective start date and optional inclusive end date.
Outside a band's range/date, the base price applies.
Admin must approve before new bookings use it. Add/delete bands before submitting;
overlapping hours for the same court/day group are rejected when their date windows
also overlap. Disjoint date windows are allowed. There are no holiday overrides.
Player confirmation and manual reservation sum each booked hour and persist that
quote. Vouchers use the summed subtotal; existing bookings are never repriced.

Staff > management > Lich san & khoa gio opens the primary venue's three-court
hourly grid. Choose a day/cell to reserve for an existing local player or lock
time; locks also prevent player bookings. Staff can move eligible future bookings
from their details without changing the booking ID, duration or agreed total.
Unpaid bookings have an explicit onsite demo-payment confirmation before check-in;
it does not collect money or verify a real bank transaction. Calendar actions
cover today through six days ahead and whole hours between 06:00 and 22:00.

The production entry point supplies flutter_secure_storage to the local demo
session. Snapshots are encrypted by the platform storage implementation. Loading
errors block mutation rather than overwriting existing data; write errors display
a retry banner. Additive fields remain compatible with earlier version-1 snapshots.
Bookings, favorites, contacts, classes, tickets and chat history are isolated by account.
Social-event and tournament registrations are also isolated by account.

See `COMPLETION_STATUS.md` and `SCREEN_COVERAGE.md` for current coverage. `REVIEW_REPORT.md` is the earlier
audit; its six confirmed defect groups have subsequently been addressed.
New event layouts reuse project conventions, not newly retrieved Figma geometry
or assets. Exact Figma matching remains unverified because MCP is quota-limited.

This is not a deployed booking platform. All slots, prices, promotions, points,
class schedules and support requests are demonstration data. No venue is contacted
and no money is collected. Venue name/address follow the design and have not been
verified as a real establishment. The catalog currently contains one design venue.

Authentication is local, not a backend authentication service. Test passwords
are stored inside the encrypted snapshot, not as production password hashes.
Real registration OTP delivery, real password recovery, Face ID and
Apple/Google/Facebook login are not connected. Registration and forgot-password
only offer explicitly marked offline code demos.
Real payments, refunds, push notifications, server inventory and cross-device
sync require backend/provider configuration and are not simulated as successful.
Uninstalling the app can remove local data; the demo has no cloud backup.

Maps links follow the [Google Maps URL documentation](https://developers.google.com/maps/documentation/urls/get-started)
and are opened with [url_launcher](https://pub.dev/packages/url_launcher).
# Court Types (Local Demo, 2026-10-08)

Owner/Admin: management workspace > Loai san. Owner creates a proposal, saves a
draft and submits; Admin reviews from Trung tam xu ly > Loai san. Corrections
require editing/resubmission; suspension/reopening uses guarded revisions.
Facility forms select approved types matching the chosen sport. Switching sports
clears the type selection. Suspension keeps old links/history but prevents new
selection/submission/approval until reopened or replaced. Legacy profiles without
a type still load. No new sport rules or multi-venue booking inventory are added.
Original Figma geometry/assets remain unverified while the connector is quota-limited.

# Admin System Report (Local Demo)

Admin: open `Tong quan` -> `Bao cao he thong`. Today/7/30-day and custom-period
filters apply to cash receipts/refunds and service-date booking/ticket counts.
Current player/facility/group totals and pending queues remain current-state data.
Only Admin can view this report. Bank transactions and registration-growth data
are not synthesized. See `FIVE_GROUP_ACCEPTANCE.md` for remaining Figma gaps.

