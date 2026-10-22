# Implementation Progress

Date: 2026-10-09. Project: `D:\PTUDDD\test_do_an`.

## Latest Verified State

- Employee permission saves no longer claim success on failed writes. Retry
  saves the committed snapshot without incrementing access revision again;
  stale newer revisions and manager-account switches reject the old editor.
  Pending inputs/permissions/scopes are locked. Employee login/payment/attendance
  and logout report failed persistence, with guarded retry that does not replay
  collections or attendance. Actions are disabled during confirmation/save and
  while pending retry; logout may replace a pending operation with a guest save.
  37 focused employee/persistence checks passed, including 11 new checks. Two
  large-text preview checks were repeated after adjusting lazy-list scrolling,
  and the permission error/retry plus portal previews were inspected. Changed
  application code analysis passed; later changes only adjust test scrolling.
  Latest debug APK: 215692400 bytes, October 9 at 08:00:04 Asia/Saigon; v2
  signature verified. Includes employee, account, booking and staff-login repairs.
  No full-suite/app restart or device installation. Detailed Figma matching,
  original-asset parity and microphone/speaker/device acceptance remain open.
- Player login now reports failed persistence, keeps its form open and retries
  the current session without reauthenticating. Pending inputs/method toggles
  are locked. Switching actors during save or before retry does not finish the
  old login or write on behalf of that actor.
  Registration/recovery screens hide stale challenges and completion controls
  after an account change, including during persistence and in the registration
  continue-without-save confirmation. Existing explicit pending-save behavior
  is preserved; registration verification/password reset are not replayed.
  Recovery retry reports repeated failure and disables duplicate retry/exit while
  saving. 37 widget and 32 model/persistence checks passed in disjoint runs (69),
  including 11 new widget checks. Two large-text checks were repeated with
  screenshots and inspected. Changed-code analysis passed after a brace repair.
  Latest debug APK: 215688415 bytes, October 9 at 07:50:15 Asia/Saigon; v2
  signature verified. It includes the account, booking and staff-login repairs.
  adb listed no connected device; no installation/hardware acceptance. No app
  restart/full-suite rerun. Figma geometry/assets parity remains unverified.
- Primary and public-facility booking confirmations now retain their opening
  account, reject account switches before/after save, and do not show success
  when persistence fails. Retry saves the existing booking without reserving
  again; quoted rates/policy/contact fields stay fixed while a booking awaits save.
  Disposed screens cannot navigate after a delayed save. Ten new focused widget
  checks cover retry/reload, actor switches, disposal and 320px/200%-text layouts.
  38 booking/facility/tariff checks passed; the two large-text previews were
  repeated with the actual app theme/fonts and visually inspected. Runs overlap,
  not a full-suite total. Changed-code analysis passed before the preview-only
  test theme update. No app restart or full-suite rerun.
  Debug APK rebuilt at 07:41:39 Asia/Saigon, October 9, 215684700 bytes; v2
  signature verified. It includes BOTH this booking repair and the staff-login
  repair below. Real-device acceptance and detailed Figma parity remain open.
- Staff login now stays open on failed persistence and retries storage without
  reauthenticating. Account changes during save or before retry cannot complete
  the original login or overwrite the new actor. Four new widget checks and ten
  persistence regressions passed (14 focused checks); no full-suite/app restart.
  The new 07:41:39 APK above contains this repair; the earlier 07:27:20 APK did not.
  A read-only Figma inventory attempt also hit the Starter quota on October 9.
  Detailed parity requires readable frame exports; phone hardware acceptance
  requires an attached device. Neither is certified by the automated tests.
- Local voice chat is implemented: microphone permission on explicit Record,
  20-second auto-stop, listen/re-record/discard/attach, optional captions,
  single-player playback, account/background cancellation and retry-safe storage.
  28 model and 33 widget/persistence checks passed in disjoint focused runs,
  including 16 new voice checks. Normal and 320px/200%-text previews were inspected.
  Automated tests use device fakes; real microphone/speaker quality is not verified.
  Changed-code static analysis passed with no issues.
  No live voice/video/call service, web capture, full-suite rerun or app restart.
- Local image chat is implemented: gallery selection, preview/removal, optional
  captions, persistent per-account images and a guarded zoom viewer. Selection
  rejects account changes, oversized/undecodable images; failed-write retry does
  not duplicate messages. 45 focused chat/persistence checks passed, including
  13 new image checks. Five widget checks were repeated with nonblank decoded-pixel
  assertions; normal and 320px/200%-text screenshots were inspected. Static analysis
  of all five changed Dart files passed. No full-suite rerun or app restart.
- Photo drafts before sending are not persistent; Android-killed gallery selection
  needs reselection. Native picker/device acceptance remains unverified. Chat is
  still local-only, with no live voice/video/call service or original Figma avatar parity.
- Tournament search/court filters and active-ticket result filtering are implemented.
  Confirmations/editors reject account changes; failed writes report retry without
  replaying mutations. 53 focused tournament checks passed, including 10 new checks;
  normal and 320px/200%-text-scale previews were inspected.
- Current member rosters, accent-insensitive search and approval-state filters
  are implemented for managed custom groups. Latest focused group run: 29 passed.
- Earlier debug APK rebuilt after the voice-chat updates at 07:27:20 Asia/Saigon on
  October 9, 215688234 bytes; v2 signature verification passed (one signer).
  aapt confirmed the RECORD_AUDIO permission in the built manifest. adb still
  listed no connected device for physical microphone/speaker acceptance.
  This supersedes the earlier tournament/roster artifacts, not the remaining
  Figma/device limitations. Changed-file static analysis passed.
- APK: build/app/outputs/flutter-apk/app-debug.apk. No connected Android device
  was available for install/launch checks. Historical no-build statements below
  refer to their individual earlier batches, not this updated artifact. No device
  was connected on the subsequent tournament build either.
- Exact Figma comparison, unspecified advanced group tools, arbitrary account
  role changes and automatic tournament rules remain unresolved. No full-suite
  rerun or production-backend completion is claimed.
- The broad role/group/automatic-engine entries are unconfirmed requirements,
  not verified missing Figma screens. Detailed Figma metadata is still quota-blocked.

## Implemented In This Batch

- Continued group work: reasoned revocation of an approved membership in a managed
  approval-required custom group. Owner/Admin access, member revision/state guards,
  5-300-character reason, atomic membership/request change and operation journal.
  Removed users cannot create new group posts or register linked activities;
  existing posts/tickets/finance remain intact. Reapplication resets the reason
  and requires a fresh review. Suspended groups still permit manager revocation.
  Snapshot validation rejects a removed request paired with active membership.
- Manager confirmation captures the actor, checks it again before committing and
  reports write failures; the existing save-retry banner retries the current
  snapshot without replaying removal. Player catalog displays the removal reason.
  No permanent ban, immediate-join/seeded group revocation or remote notification.
- Group verification: 32 focused model/widget/regression checks passed (10 new
  checks), with normal/200%-text-scale previews inspected. No full-suite rerun,
  app restart, APK rebuild or device installation. Full Figma parity is still open.

- October 9: configurable booking cancellation policy with numeric bounds,
  immutable booking terms, minimum notice and request-time refund calculation.
  Owner facility changes are drafts requiring existing Admin publication; primary
  policy changes require Admin password confirmation and revision checks.
  Save retries do not replay mutations. Standard legacy terms migrate unchanged.
- Receipt-date cashflow separates money received from service-date booked value.
  Manual receipt dates, actual refund-recorded dates, pending liabilities, daily
  receipt/refund charts, facility/channel filters and CSV clipboard export.
  Legacy approved payments with no receipt date remain explicitly undated.
  Ticket income has its own Events category, not a fabricated venue attribution.
  No real bank synchronization or claim of a real bank balance.
- Seeded event cancellation is keyed by event and exact start time, not a permanent
  cancellation of a rolling catalog ID. Stops joining only that occurrence,
  cancels linked not-started fixtures, creates pending 100% refunds only for paid
  active tickets and preserves other dates/events. All records validate before
  atomic changes; occurrence ledgers restore with additive legacy migration.
- Seeded/custom approved events can allocate primary courts for the full event
  duration within the existing seven-day calendar horizon. Existing court locks
  prevent booking/manual-lock overlap; rescheduling bookings uses the same guard.
  Event-linked locks appear in calendar and occupancy, redirect to the event court
  editor and release on whole-event cancellation. Allocation cannot omit courts
  of active fixtures; new/rescheduled fixtures respect a present allocation.
  Stale edits, role changes, corrupted links and write retry have focused coverage.
  Legacy label-only fixture schedules stay compatible when no allocation exists.
- Verification: 76 policy checks, 50 cashflow checks, 51 financial/workflow/PDF
  regression checks, and 82 event/calendar/tournament checks passed in separate
  overlapping runs. These numbers are NOT a new full-suite total. Final navigation
  and analyzer results are recorded after their completion below.
- Figma context and screenshot tools were retried on October 9 and still hit the
  Starter quota. Complete frame geometry/original assets cannot be certified from
  the overview screenshots. FIVE_GROUP_ACCEPTANCE.md remains open, not 100% done.
  No app restart/full-suite run/APK rebuild/device installation was performed.

Earlier batch entries below describe their implementation-time limitations;
the October 9 entries supersede their now-implemented policy/report/allocation/
seeded-cancellation limitations, not the remaining Figma or backend boundaries.

Final navigation/write-retry checks: 30 focused widget tests passed, followed by
six allocation widget checks including calendar navigation. Normal and 200%-scale
allocation previews were inspected; analyzer passed after the write-retry fix.
Browser fallback reached a Figma login requirement; no credentials were entered.
Known seeded ticket/lock cohorts remain manageable after the catalog rolls to a
new date, while joining still uses the currently published occurrence only.
Final rolling-cohort batch: 32 focused checks passed, including manager navigation
to old future ticket cohorts. Static analysis passed after the final source edits.

- Facility form buffers now preserve incomplete input independently of validated
  facility profiles. Owner-only save/resume/discard, bounded immutable data,
  additive snapshot restoration, obsolete-revision guards and failed-save retry.
  Completing the profile clears its buffer without changing existing published data.
- Legal demo attachments now support PDFs alongside existing PNG/JPEG images.
  Native file selection checks size and PDF readability/password/page count;
  private Owner/Admin viewing uses pdfrx. Public facility data strips legal files.
  Real legal verification and physical-device plugin acceptance are not claimed.
  No full-suite rerun, application restart or APK rebuild for this batch.
  Verification: 66 focused facility checks passed; the final 12 draft/document
  checks also passed, including native PDF page rendering and save-failure retry.
  Runs overlap and must not be summed as unique tests. Static analysis passed.
  Form previews at 402px/100% and 320px/200% and the rendered PDF page were inspected.

- Employee credentials and permission editor, separate employee login/session,
  own-shift view and seven-day booking/ticket schedule. Attendance and onsite
  booking payment are independently delegated and guarded at commit time.
  Inactive/revoked staff cannot use retained access. Revision checks, manager
  password confirmation, local cooldown, encrypted snapshot restoration and
  failed-save retry are covered. Employee identities never acquire manager roles.
  No seeded employee password, per-facility delegation, payroll or production auth.
- Published active facilities now feed Explore/map discovery with their actual
  supplied image, base price and no invented star rating. Facility-specific booking
  validates court count/opening hours/availability; immutable venue/rate contracts
  flow through booking success/history/payment and survive restart/suspension.
  Separate facility calendars and venue-aware rescheduling preserve agreed prices.
  Primary holds/occupancy/reviews no longer count another facility's records.
- Primary tariff proposals support surcharge and optional inclusive expiry date;
  date-disjoint bands may reuse hours. Quotes use the approved fee/date windows,
  while existing booking contracts and legacy snapshots remain unchanged.
- Optional member approval on custom groups: pending requests, manager approve/
  reasoned rejection, withdrawal/reapplication, posting prerequisites, role/revision
  checks and additive atomic persistence. The default remains immediate membership
  for existing groups. Approved badminton groups can be linked to activity drafts;
  community links open real event details/registration. Joining requires actual
  membership. Group suspension stops new registration, not valid existing tickets.
- Five-group completion is still NOT claimed. FIVE_GROUP_ACCEPTANCE.md separates
  implemented items, remaining functional items and unverified Figma parity.

- Court-type registry: Owner proposes named types under existing supported sports,
  edits drafts/corrections and submits. Admin reviews with reasons, suspends and
  reopens; pending proposals appear in the work center. Immutable records, revision
  guards, role checks, bounded local audit, save retry and atomic restoration.
- Facility profiles have an optional durable court-type link. New selections,
  submission and approval require an approved matching-sport type. Suspension
  preserves existing profiles/history; retained drafts may be saved but not newly
  submitted/approved until the type is reopened or replaced. Legacy profiles migrate
  with no type link. Full type names wrap below the selection at 200% text scale.
  Existing sport engines and standard primary-venue inventory are unchanged.
  This is functional local coverage, not verified Figma pixel parity.

- Tournament management hub includes seeded/custom and historical event cohorts;
  time/name/date filters, player own-team/status fixture filters and derived team
  result summaries with sorting. No private contact fields in shared summaries.
- Managers can reschedule not-started fixtures with a reason, fixed teams/IDs,
  overlap/window/revision checks. Admin-only reasoned score corrections update
  summaries and preserve old/new values in the bounded local operation journal.
  Changes, latest reasons and aggregates survive save retry/restart. These finish
  the interrupted tournament-view work, not all remaining Figma requirements.
  On 2026-10-08 both Figma design-context and screenshot calls still hit Starter
  quota; exact visual parity remains unverified.

- Manual tournament fixtures/results using actual registration ticket IDs:
  Owner/Admin schedule 30-minute slots, prevent team/court overlap, cancel with
  reason, and enter non-tied 0-99 aggregate scores after match end
  and both teams' check-in. Registered players view schedule/results from their
  tickets without seeing other teams' private contacts. Custom tournament
  organizer entry is linked from activity detail. Additive durable snapshots,
  stale revision/role checks, failed-save retry and atomic corruption rejection.
  Court labels do not reserve booking inventory. No automatic brackets/groups,
  official standings/tie-breaks, official set-scoring engine or walkovers.
  Layout uses existing project styles, not newly verified Figma geometry/assets.

- Owner custom social/tournament activity registry: validated fixed date/hour,
  duration/capacity/fee/rules, drafts/corrections/submission; Admin reasoned review,
  suspension/reopening, stale-revision/role guards and pending work-center entries.
- Approved custom activities feed the actual public event search/details/forms.
  Player registration enforces capacity, one live ticket per account and team
  details for tournaments. Organizer detail links to attendee workflow records.
- Immutable custom event snapshots preserve existing ticket fees/start/duration,
  QR payloads and finance/attendance across suspension and restart. Registry/ticket
  links, counters, duplicates and contracts are checked before atomic restoration.
  Old seeded events/tickets migrate; failed saves retry without adding duplicates.
- Suspension stops only new registrations, not valid tickets or event occurrence.
  Primary demo venue/badminton, cap 100 activities, 30-day future schedules,
  whole hours within 06:00-22:00. No court allocation, automatic brackets,
  seeded whole-event cancellation, custom images or remote synchronization.
  Existing sample court photo/theme are reused; the photograph is not verified as
  badminton/venue media. Exact Figma layout and original event images remain unverified.

- Owner-authored custom play groups with validated sport/name/description,
  draft/edit/submit and rejected-group correction. Admin approve/reject with
  reason, suspend/reopen, stale revision/role guards and local operation journal.
- Approved groups feed the actual community catalog, membership and post forms;
  pending groups feed the unified Admin work center. Suspension hides the public
  group/posts and prevents new membership/posts while preserving history.
- Additive snapshots migrate old stores, validate IDs/counters/owner/state/name
  uniqueness and group-linked posts/memberships before atomic restoration.
  Failed writes retry without repeating creation. One seeded Owner, cap 100.
  No group media, remote synchronization or exact Figma
  matching. Detailed design context remains Starter-plan quota-limited, verified
  again on 2026-10-07; readable exports are needed for visual parity.

- Dedicated Owner/Admin daily overview at the primary demo venue, today through
  six days ahead. Counts enabled-court reserved/locked hourly calendar cells,
  including unpaid holds but not cancelled bookings; disabled-court history is
  still listed. Zero-capacity courts do not cause invalid progress values.
- Service-date confirmed booking value before refunds/fees (not received revenue),
  all-date pending proofs/cancellations/refunds/disputes, guarded role changes,
  navigation shortcuts and links to real daily booking records. Read-only derived
  data, no new persistence schema. Original Figma geometry/global metrics remain.
- This overview adds seven model and six widget tests, including restricted roles,
  clock horizon, locks, disabled courts, cancellation, navigation and 320px/200%
  layouts. Verification results for this batch are recorded after checks finish.

- Staff employee directory/profile with accent-insensitive name/phone/job search,
  active/inactive filters and links to existing roster editing. Whole-hour shifts
  within 06:00-22:00, 1-12 hours, up to 30 days ahead, active-worker and overlap checks.
- Manager-recorded check-in from 15 minutes before start, completion only at end,
  absence at end, reasoned cancellation before start and stale-revision protection.
  Terminal states cannot be replayed; cancelled shifts release the time range.
  Shift details can refresh time explicitly. Employee login, GPS, recurring shifts,
  payroll and per-venue delegation are NOT implemented by these roster records.
  Separate employee access is described above; roster records alone grant no login.
- Shift snapshots validate employee links, counters, IDs, state revisions and
  overlaps before atomic restoration. Legacy snapshots migrate; failed writes retry
  the saved snapshot without adding a duplicate shift. Primary local demo venue only.

- Star reviews for the primary venue: one per completed/paid own booking, immutable
  content and bounded 1-5 stars/10-1,000-character message. Public list/detail,
  author-visible hidden reviews, Admin search/status filters and reasoned hide/
  restore with revision guards. Public ratings and discovery filters update live;
  4.9 remains an explicitly labeled sample fallback when no public reviews exist.
- Review snapshots restore atomically with booking/owner/completion/payment checks;
  missing reviews migrate. Failed saves retry without resubmitting. Private drafts
  disappear when switching accounts; Owner cannot moderate star reviews.
- Staff customer directory derives only venue booking/ticket contacts, excludes
  accounts without reservations, and supports accent-insensitive name/phone search,
  repeat-reservation filter (at least two records, including cancellations),
  customer history and real record links. This is not a verified return-visit metric. Paid totals
  are gross confirmed amounts before refunds, not estimated net revenue.
- Admin work center combines pending facilities/prices/proofs/cancellations/refunds
  and unclosed disputes with live category counts, search and record navigation.
  Counts represent work items, not unique cases; closed disputes leave the queue.
  Court-type/group/activity authoring/approval now feeds this center;
  full venue legal checks remain unfinished.

- Explicit Admin dispute closure after a structured decision: upheld results can
  close directly; refunds require a recorded linked reference/image receipt.
  One-time closure date and audit persist, and the linked player/Owner see the
  closed result. Role changes during confirmation cannot bypass model guards.
- Legacy untyped results are not auto-closed. Invalid closure timestamps and
  closed refund cases without recorded receipts fail restoration atomically.
  Failed writes retry the snapshot without repeating the closure. There are no
  external notifications, real transfers, reopen actions or execution deadlines.

- Admin player directory with accent-insensitive name/email/contact-phone search,
  active/blocked filters, clear and empty states. Profile/history links cover
  court bookings, event tickets and related disputes, not private expense records.
- Lock/unlock now requires the current Admin password and a 5-300-character reason
  at the model boundary as well as in the UI. Current state and revision are checked
  to reject stale forms and replay, including a lock/unlock cycle back to old state.
  No player/Owner can execute it or target the fixed staff identities.
- Five wrong confirmations impose a 60-second in-memory cooldown across logout/login;
  it resets on app restart and is NOT server-side abuse prevention. Confirmation
  input is cleared after attempts and never added to decision records. Existing
  local authentication still stores demo passwords in encrypted snapshots.
- Latest reason/date/revision persist with blocked status and bounded audit entries;
  history remains intact. Legacy snapshots without decisions migrate, corrupted
  owner/state/reason/revision data fail atomically, and failed saves retry without
  repeating the account action. Other sensitive staff actions are unchanged.

- Read-only local settlement report: original gross, voucher discount, confirmed
  payments, pending/recorded refunds, retained amount, simulated transfer fee and
  estimated net. Fees default to 3 percent, selectable 0/3/5 percent for comparison;
  these are explicit demo assumptions, not real provider/venue commission rules.
  Onsite payments have zero simulated fee; unconfirmed/rejected proofs are excluded.
- Service-date/channel/booking-ticket filters, daily net bars, per-record breakdown
  and navigation to the original finance record. Open cancellation/dispute amounts
  remain included in the estimate but are identified separately as under review.
- CSV clipboard output for the current filters, with quoted fields and spreadsheet
  formula neutralization. Report values are derived live, not a separate saved ledger.
  No bank execution or tax calculation. The separate local payout workflow now
  stores recipient accounts, requests and Admin receipt/rejection records.
- Corrected the older report caption: approved onsite demo payments are included;
  unconfirmed venue payments are still excluded.

- Primary-venue tariffs: court-specific weekday/weekend hourly ranges and effective
  start dates, base-rate fallback, overlap/rate/range validation and a 36-band cap.
  Owner proposal and Admin approval/rejection reuse the existing price workflow.
  Future-dated bands outside the seven-day horizon do not lower discovery prices.
- New player/manual bookings quote and persist each hour separately; cross-band
  totals and voucher eligibility use the sum. Confirmation rejects stale hourly
  quotes even if the first-hour price remains unchanged. Existing reservations
  and staff rescheduling keep the original hourly price contract.
- Additive legacy snapshot migration, invalid tariff/hourly-array rejection and
  failed-save retry. Tariffs are local demo rules, not verified real venue prices.

- Staff hourly calendar for the primary venue's three courts, with a seven-day
  booking horizon, horizontal court navigation and accessible large-text layouts.
  Staff time blocks share availability with player reservations; unlock is guarded.
- Manual reservations for existing nonblocked local player accounts, validated
  contact details and current price quotes. No guest account is created implicitly.
- Staff rescheduling preserves booking ID, duration, agreed rate, voucher and total.
  Revision checks reject stale forms; pending transfers, cancellation/refund states
  and attended bookings cannot be moved. Overlapping bookings/blocks are rejected.
- Explicit demo onsite-payment confirmation for unpaid bookings permits attendance
  without inventing a bank proof. Existing transfers cannot be overwritten.
  Blocks, revisions and onsite records persist with atomic validation and save retry.

- Event/tournament transfer demo: image proof, reference, deadline/restart,
  owner approval/rejection/resubmission and cancellation review queues.
  Approved cancellation releases capacity and creates one local refund record.
  Tickets require a 24-hour cancellation lead time and refund 100 percent;
  this is an explicit demo policy, not a validated tournament rule from Figma.
- Booking refunds store policy amounts (95 percent with a two-hour lead time,
  otherwise 50 percent before start) based on request time. UI refund completion
  requires an image and reference; no bank transaction occurs. Legacy model-only
  fixture methods and migrated records may lack refund evidence.
- Staff attendance for bookings and tickets: typed-code/QR-payload lookup,
  confirmed-payment prerequisite, check-in window, no-show after the end and
  completion after check-in/end. Invalid, cancelled and repeated actions fail.
  No camera scanner or signed server ticket was added.
- Booking/social/tournament disputes: evidence image, owner response, explicit
  Admin uphold/refund decisions, linked pending refund, and player follow-up.
  Event refund decisions queue 100 percent; booking decisions queue 95 percent.
  This is a local demo decision workflow, not an actual legal or bank ruling.
- Reports now include paid event tickets and policy refund amounts. A bounded
  per-record audit view and encrypted snapshot migration/save retry are included.

- Registration OTP demo: phone/email draft, explicit test code, five-minute
  expiry, five wrong attempts maximum, 60-second resend cooldown, invalidated
  old/foreign/cancelled challenges, and verified-account confirmation.
  No SMS/email or real identity check. Account creation is gated in the UI;
  the low-level local fixture-registration method still exists for tests.
- Pending registration secrets/challenges are ephemeral, not stored. Verified
  accounts use the existing encrypted persistence with retry without duplication.
  Saved success is distinguished from pending save; returning to edit cancels
  the challenge. Continuing unsaved requires explicit acknowledgement.

- Owner facility registry: create/edit profile, photo/amenities, legal sample
  image, opening hours, reference rate and cancellation policy; valid draft
  saving, submission, correction/resubmission and pending form locks.
- Admin facility pending queue, approval/request correction, suspension/reopening.
  Published and draft profiles are separate; edits/rejections keep old approved
  information public. Stale revisions and foreign record objects are rejected.
- Public approved profiles exclude private representative and legal attachments.
  New facilities are NOT wired to player booking inventory or discovery/maps.
- Additive encrypted persistence, atomic validation, migration and save retry.
  Gallery cancellation/errors handled; sample PNG/JPEG attachments up to 400KB.
  Interrupted gallery sessions on the facility form do not have draft recovery.
- Seven supplied screenshots mapped to current coverage in SCREEN_COVERAGE.md.

- Operations workspace: three-court hourly price/open-state proposals, Admin
  approval/rejection/resubmission and application to new reservations/discovery.
  Pending/rejected changes do not affect published settings. Existing bookings
  preserve rates, discounts and totals. Stale confirmation quotes are rejected.
- Employee roster create/edit/inactive state with validation and stable IDs.
  These profiles are NOT new staff login accounts or delegated permissions.
- Customer booking history, booking-date-range payment/refund summaries excluding
  unpaid venue payments, and latest-1,000 local operations audit entries.
- Admin local player login blocking/unblocking and forum post hiding/restoring.
  No arbitrary role escalation. History is retained; moderation affects public
  boards. Encrypted persistence, migration and corrupted-snapshot rejection.

- Booking transfer demo: gallery evidence drafts/submission, reference validation,
  rejection/resubmission, submission deadline and expired-attempt restart.
  PNG/JPEG evidence up to 400 KB is stored locally in the encrypted snapshot.
  Android interrupted image-picker results are recovered as drafts only.
- Separate local Owner/Admin login and role checks. One-venue booking calendar,
  payment/cancellation queues, staff review actions and Admin player directory.
  Ordinary registrations cannot grant themselves staff privileges.
- Cancellation requests retain inventory until approved; approved paid bookings
  queue a refund record. Recording it is explicitly a demo, not money movement.
- Booking-linked disputes, account history, Owner responses and Admin resolutions.
- Persisted staff profile/password, finance states, drafts and disputes with
  strict snapshot validation, additive migration and save retry.
- Account scroll resets on identity change; booking details deny other accounts.

- Explicit offline demo password recovery: account lookup, displayed test code,
  five-minute expiry, 60-second resend cooldown, five incorrect attempts maximum,
  password confirmation and encrypted persistence with retry. No SMS/email or
  real identity verification. Registration OTP now has a separate local demo.
- Local community forum/group boards, join/leave groups, create/delete own posts.
  Posts are shared only among accounts on this device, not with remote users.
- Account-private expense history with integer equal splitting, remainder
  allocation and validation. It is a calculation record, not payment/debt tracking.

- Social events: discovery, accent-insensitive search, details, quantity/contact
  form, confirmation, personal tickets, cancellation and capacity release.
- Tournaments: details, team/contact/partner registration, confirmation and
  personal participation schedule. Detailed fixture results are not generated.
- Shared local capacity, account-isolated histories, duplicate prevention,
  validated additive persistence and storage retry without duplicate tickets.
- Real QR rendering via qr_flutter 4.1.0. Payload has a demo ticket reference,
  not name/phone. QR is hidden on cancellation/check-in/expiry. This is not a
  signed real-world ticket or camera-scanning workflow.
- Explicit local check-in simulation within the attendance window. Cancellation
  is only before start and before check-in. No money is collected or refunded.
- Entry points: Home > Giao luu / Giai dau / Xe ve gan toi;
  Account > Ve & lich tham gia.

## Review Defects Addressed

- Settings can explicitly clear the contact phone and retain the change after
  restart. Invalid nonempty phone updates still fail existing validation.
- Booking success Home action selects the Home tab even when entering via Explore.
- Auth accessible layouts grow to accommodate scaled labels/errors. Explore uses
  a unified scroll view so the landscape keyboard does not overflow the header.
- Name/password registration maximums show validation rather than duplicate errors.
- Booking and academy states distinguish upcoming, in progress and ended.
- Registration privacy copy reflects encrypted local persistence.

## Still Remaining

- Remote community replies/moderation and richer group tools.
- Automatic tournament groups/brackets/winner advancement,
  court allocation, seeded whole-event cancellation and configurable cancellation policies.
- Real bank reconciliation and richer system-wide financial/bank-date reports.
  Per-facility hourly prices, manual reservations/locks, scoped ratings and
  daily/all-facility booking metrics are now implemented.
  Facility registry creation/editing/review now exists, but original Figma layout,
  complete legal checks and PDF/sample-document uploads remain. Approved named
  court types now include their own surface/feature description.
- Arbitrary Admin role editing, complete facility
  legal checks and richer review moderation remain unfinished.
  Current moderation covers forum posts and local booking star reviews; dispute results and
  player blocking are local. Reports cover booking service dates, not bank dates.
- Embedded map/GPS; real chat media/calls; original avatar assets.
- Staff QR scanner, signed/server-validated tickets, real payment/auth/OTP services.
- Exact Figma visual comparison for new flows; automatic tournament brackets,
  official standings/tie-break rules beyond the derived team result summary.

These are not claimed as complete. The chosen scope remains a local demo first;
external backend/provider integrations are separate from local-screen coverage.

## Verification

### Latest Facility And Group Batch

The user requested focused checks only: no full-project test rerun, app launch or
APK rebuild. The 726-test run below is a PRIOR baseline, not verification of every
current file. The previously built APK does not contain this batch.

- Facility manual reservations/locks: scoped inventory, venue hours/court limits,
  legacy block migration, atomic restore links and primary-dashboard isolation.
- Facility hourly pricing: immutable proposal/published lists, Owner submit/Admin
  review, overlap/bounds/stale guards, weekday/weekend bands, surcharge, inclusive
  expiry, base fallback and per-hour booking/manual quotes. Pending/rejected plans
  leave published rates unchanged. An approved empty proposal resets to base rates.
- Public per-facility ratings/reviews, completed-paid-ticket eligibility, hidden
  moderation exclusion and actual detail/public-facility navigation.
- Daily dashboard venue selector and aggregate capacity/occupancy/locks/confirmed
  booking value. Suspended facilities retain history/value but have zero active
  capacity; queues and other shared management tools still have global scope.
- Optional group cover: PNG/JPEG up to 400 KB, selection/removal, immutable review
  transitions, restart and public approved-group board rendering. The sample court
  image is used only as a test rendering fixture, not a seeded group photograph.

Added 29 focused tests: 5 holds, 7 tariff models, 3 review/dashboard models,
3 group-media models and 11 UI flows (normal and 320px/200% text included).
The consolidated focused run passed 115 tests with no failures. Group/community
UI checks separately passed 34 tests (overlapping coverage, not an additional
unique-test count). The final dashboard/review label adjustment passed all 15
targeted widgets. Flutter analyze reported no issues. There was no full-suite
rerun or new APK build for this batch.
Inspected tariff, scoped dashboard/review and group cover preview screenshots.
Full Figma matching, remaining checklist functions and device acceptance are not
claimed complete.

Latest full run on 2026-10-08: 726 tests passed, zero failures; Flutter analyze:
no issues. The first run found a customer-navigation test tapping before scrolling
settled after new management entries moved the target. Its helper now waits before
tapping; the complete rerun passed without suppressing warnings.

This finalization batch adds 42 tests: employee facility scope (4 model), Owner
verification (8 model/7 widgets, including scope forms), custom whole-activity
cancellation (6 model/2 widgets), and payout accounts/ledger (11 model/4 widgets).
The new workflows are persisted additively and validate corruption/stale roles,
revisions, duplicate receipts, failed saves/retry and restart.
Owner verification, assigned facilities, cancelled activities and payout views
were captured and inspected at normal and 320px/200% text sizes. This is not a
pixel-match certificate or an actual bank/identity verification.

Owner verification is a private local review record, not a global operating gate.
Custom activity cancellation cancels future fixtures/tickets and queues full
refunds for confirmed fees; it does not transfer money or cancel recurring seeds.
Recipient snapshots and payout reservations use ended confirmed transfer revenue,
excluding onsite receipts/held records; deficits remain visible after later
refunds/disputes. Admin receipt/rejection does not execute a bank payout.

This batch adds 52 tests: employee access (12 model/4 widget), multi-facility
booking/discovery/calendar (11 model/5 widget), tariff expiry/surcharge (4 model/1
widget), group membership (7 model/2 widget), group-linked events (4 model/2 widget).
Tests include actual UI navigation, role denial/revocation, stale commits, legacy
snapshots, corrupted links, failed saves/retry and restart. Inspected employee,
facility-booking, tariff and member views at normal/320px-200% text sizes.
Exact Figma visual parity and physical-device acceptance remain unverified.
Debug APK rebuilt successfully on 2026-10-08 at 22:54:42 host time after the
726-test run: build/app/outputs/flutter-apk/app-debug.apk, 202310496 bytes.
Later changes only strengthen image-render assertions in tests, not APK code.
Device installation is not part of this automated test result.

Employee shifts add eleven model and ten widget tests for role denial, overlap/
adjacent ranges, inactive/unknown staff, dates/hours, check-in/completion boundaries,
terminal-state replay, cancellation, stale revisions, restore/migration/corruption,
save retry, search/profile/form navigation and role switches during confirmation.
Roster/profile/form/shift detail are captured at normal and 320px/200-percent text.

This batch adds ten review model and nine review widget tests, three customer
model and seven customer widget tests, and seven approval-center widget tests.
Coverage includes authorization, own-account history/drafts, one-time reviews,
moderation revisions/reasons, restart/migration/corruption/save retry, public
rating updates, search/filtering and actual navigation. Forms/details/empty and
populated queues are captured at 402px/normal and 320px/200-percent text.

Dispute closure adds nine model and four widget tests: role denial, decision and
receipt prerequisites, one-time execution, linked-player visibility, role changes
during confirmation, restart/legacy migration, save retry and atomic rejection
of corrupted closures. Closed result views were captured and inspected at
402px/normal and 320px/200-percent text.

Admin player coverage adds 19 model and 14 widget tests for guarded profile/history
access, password/reason checks, cooldown boundaries, changed passwords, stale/replay
states, long identifiers, login aliases, restart/migration/corruption, save retry,
search/filters, actual navigation and role denial. Directory/detail/confirmation/
empty views are captured at 402px/normal and 320px/200-percent text, including lower
sections. Final full-suite/analyzer/APK results are reported in the delivery message.

Settlement adds 17 model and 11 widget tests for confirmed-payment selection,
voucher amounts, pending/recorded/full refunds, onsite fees, rounding, held amounts,
date/channel/type filtering, CSV safety, restart, access denial, live detail updates,
management navigation and clipboard failure/retry. Three views were captured and
visually inspected at normal/320px 200-percent text sizes, including bottom sections.
Final full-suite, analyzer and APK results are reported in the delivery message.

Tariff coverage adds 19 model and eight widget tests, including the real
Owner-to-Admin approval path, player per-hour quote, invalid/overlapping ranges,
future effective dates, migration, restart, save retry and preserved booking
totals. Three views are captured at 402px/normal and 320px/200-percent text.
The tariff form and booking confirmation were visually inspected. Final full
suite, analyzer and APK results for this batch are reported in the delivery message.

Previous full run on 2026-10-08: Flutter reported 632 passing tests and no failures;
analyzer reported no issues. Court types add 12 model and four widget tests:
permissions/revisions, correction/resubmission, normalized duplicate names,
approved matching-sport facility links, suspension retention, legacy migration,
save failure/retry, public draft-name privacy and atomic corruption rejection.
Real Owner submission and Admin queue approval are exercised; role changes during
confirmation cannot approve. Registry and facility selection screenshots were
inspected at 402px/normal and 320px/200% text. A clipped long selected name now
wraps below its short ID. The approval-center navigation helper now waits for
scrolling to settle before tapping; all seven tests and the full rerun pass.

Previous full run on 2026-10-08: Flutter reported 616 passing tests and no failures;
analyzer reported no issues. The interrupted tournament views and changes add
27 tests: six derived-view model tests, twelve view widgets, four change model
tests and five change widgets. Coverage includes historical seed dates, private
contact exclusion, own-team/status filters, summaries in both score orientations,
role changes during correction confirmation, stale revisions, reschedule overlap,
long reasons, failed-save retry and restart. Inspected normal/320px-200% directory,
results, own fixtures and reschedule views; shortened a clipped time-filter label.
An old review-navigation test now waits for scrolling to settle before tapping;
its nine tests and the subsequent full suite pass without suppressing warnings.

The previous full run on 2026-10-07 passed 589 tests. Tournament fixtures/results
add 16 model and four
widget tests: real organizer/player entry routes, team/court/date validation,
role changes during confirmation, check-in/end-time guards, immutable results,
save retry, legacy snapshots and corrupted fixture links/attendance/overlaps.
Inspected list/form/score dialog at 402px/normal and 320px/200-percent text.
The match view formats actual minutes instead of the whole-hour booking helper.

Activities add 15 model and ten widget tests,
including Owner creation/Admin approval/player registration, capacity/team
rules, immutable ticket prices, payment/refund restoration, role changes,
failed saves and corrupted registry/contract data. Inspected 402px/320px images
of organizer list/form/detail and public event detail at 200% text.
The final policy-copy adjustment passed 30 old/new event widget tests.
Final analyzer is clean and the debug APK built successfully at
`build/app/outputs/flutter-apk/app-debug.apk`; physical-device installation
is not verified.
Calendar coverage adds
20 model and 17 widget tests for shared inventory, overlapping ranges, access,
stale forms/prices, preserved booking totals, onsite confirmation, migration,
corrupted snapshots and save retry. Five calendar/editor/payment views are
captured at 402px/normal and 320px/200-percent text. Final full-suite, analyzer
and APK results for this batch are recorded in the delivery message. Calendar
grid, manual reservation, rescheduling and onsite-payment layouts were visually
inspected, including narrow 320px views with 200-percent text scaling.
The new workflow coverage adds 19 model tests and 17 widget tests, including
gallery/reference submission, review, refund, QR lookup, attendance, request-time
refund policy, replay/foreign access, corruption, restart and save retry. Seven
new views are captured at 402px/normal and 320px/200-percent text. Proof imagery
and normal/large-text layouts were visually inspected. APK build status is
reported in the delivery message. Registration adds 23 model/widget
tests for wrong/expired/resend/locked/success states, cancelled/foreign/replayed
requests, restart/privacy and save retry, including four normal/large-text views.
The existing signup integration test now confirms OTP before expecting account
success. The 12 registration widget tests also passed in a final screenshot
recheck after adapting the app-bar title for large text. APK build results are
reported in the delivery message.
Facility coverage adds 39 model/widget
tests for profile review, published/draft isolation, private attachment exclusion,
suspension, stale revisions, gallery errors, save retry, corrupted snapshots and
six screens at 402px/320px with normal/200-percent text. Final full-suite/analyzer
and APK results are recorded in the delivery message. Earlier operations adds 35 model/widget tests for
approval/rejection, court closure, immutable booking prices, stale quotes,
employees, login blocking, moderation, restart/migration, invalid snapshots,
save retry and seven 402px/320px large-text views. Final full-suite, analyzer
and APK results are reported in the delivery message.
Generated payment and management screenshots were visually inspected, including
rendered evidence and large-text screens.
No connected emulator/physical device was available for installation. Debug APK
build status and final rechecks are reported in the delivery message.

Automated tests cover ticket registration/cancellation, team validation, capacity,
account isolation, check-in boundaries, restart/migration, malformed snapshots,
failed saves/retry, navigation and the previous review reproductions. Screenshots
are generated in `build/previews` with `--dart-define=SCREENSHOT=true`, including
normal and 320px/200-percent text views. Final command results are recorded in the
delivery message. Physical-device and iOS verification are not included.

Figma detailed context remains quota-limited. New workflows use project-native
components and an existing venue image; no exact Figma asset/layout match is claimed.

## October 9: Admin System Report

Added Admin dashboard navigation to a read-only, period-filtered system report.
Uses actual local receipt/refund dates and separate service-date booking/ticket
counts. Player/public facility/group totals and pending review/cancellation/dispute
queues are current-state counts, not date-filtered historical snapshots.
No synthetic registration-growth data, bank connection or exact Figma parity claim.
Verification: 28 focused model/widget/dashboard/cashflow checks passed, including
seven new report checks. Normal and 320px/200%-text previews were inspected.
No whole-project restart, full-suite run, APK rebuild or device installation.

## October 9: Review Confirmation Reliability

Group/activity/court-type review dialogs reject account changes before mutation.
Group/activity confirmations use operation-specific copy. Review/cancellation
failed saves show explicit errors; existing retry-save persists the committed
transition without repeating it. Reload tests verify approved state and revision.
Cashflow details opened from the system report retain its selected period.
35 focused review/group/activity/court-type widget checks and 17 overlapping
report/cashflow/confirmation checks passed, including seven new regression checks.
Static analysis passed. No full project rerun, app restart, APK build or device install.
This batch does not close remaining broad Figma/role/tournament gaps.

## October 9: Payment And Attendance Reliability

Booking/ticket confirmation and reason dialogs reject a changed initiating
account, including Owner-to-Admin changes where both roles otherwise have access.
Attendance confirmation uses the same account guard. Failed persistence reports
an explicit error; retry-save writes the existing approved receipt without a
second approval. Reload tests check timestamps and a single cashflow entry.
Attendance now has checked-in and cancelled filters with wrapped controls.
37 focused payment/workflow widget checks passed, including eight new regressions.
Normal and 320px/200%-text attendance previews were inspected. No full suite,
whole-app restart, APK rebuild or device installation in this batch.

## October 9: Group Member Roster

Implemented immutable manager-scoped rosters for direct-join and approval-required
custom groups, using existing membership data. Counts exclude pending, withdrawn,
rejected and revoked requests. Group details provide accent-insensitive search,
clear, approval-state filters/counts and empty states while retaining existing
review/revoke actions. Suspended groups retain historical members.
29 focused group checks passed, including six new model/widget checks. Normal and
320px/200%-text previews were inspected; static analysis passed. No full-suite run
or whole-app restart. This does not certify all Figma screens or undefined group
tools, and does not implement automated tournament rules or arbitrary role changes.

## October 9: Updated Debug APK

flutter build apk --debug --no-pub succeeded. Gradle's Java loopback error was
resolved by using a short TEMP/TMP/jdk.net.unixdomain.tmpdir inside build/java_tmp
for this process only. No global JVM or Gradle configuration was changed.
Output: build/app/outputs/flutter-apk/app-debug.apk, 215368634 bytes; timestamp
2026-10-09 06:47:02 Asia/Saigon. apksigner verified the v2 signature; aapt confirmed
com.example.test_do_an / 1.0.0+1 / min SDK 24 / target SDK 36 / MainActivity.
adb found no device. Installation and runtime/manual acceptance remain unverified.
No full-suite rerun or app restart was performed. Full Figma parity remains open.
