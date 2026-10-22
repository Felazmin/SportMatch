# Five-Group Delivery Checklist

Updated: 2026-10-09. Scope: local Flutter demo in D:\PTUDDD\test_do_an.
This checklist does NOT certify full completion or pixel-perfect Figma matching.
The five groups are work areas, not five individual screens. Checked entries are
implemented local behavior; unchecked entries remain work, not hidden TODOs.

## 1. Accounts And Permissions

- [x] Player/Owner/Admin login and isolated histories.
- [x] Player login save retry and stale-actor guards; registration/recovery hide obsolete challenges/results after account switches, including delayed saves and confirmation dialogs.
- [x] Employee credential creation, manager-password confirmation and revocation.
- [x] Employee schedule, attendance and onsite-payment capabilities.
- [x] Employee-only session, own shifts, role/revision guards and persistence.
- [x] Employee permission-save retry without revision replay; original-manager/stale-editor guards, plus guarded employee login/logout/payment/attendance save retries.
- [x] Assign employees to individual facilities, with scoped schedule/payment/attendance guards.
- [x] Owner verification submission, Admin approval/correction, proof and stale-revision guards.

## 2. Facilities And Booking

- [x] Facility draft/edit/review/correction/publishing/suspension.
- [x] Approved court-type links and supplied facility images.
- [x] Published facility discovery/map results and favorites.
- [x] Facility-specific court count, hours, flat base prices and availability.
- [x] Durable venue/rate contracts across success/history/payment.
- [x] Failed booking writes retain one committed reservation for retry; opening-account guards and no success/navigation after account changes or disposal.
- [x] Facility day calendars and venue-aware booking rescheduling.
- [x] Facility-specific manual reservations/locks and Owner-proposed/Admin-reviewed hourly price bands.
- [x] Per-facility star reviews and scoped/all-facility daily occupancy/confirmed-value aggregation.
- [x] Incomplete form save/resume/discard and private legal demo PNG/JPEG/PDF attachments.

## 3. Groups And Tournaments

- [x] Group/activity drafts, Admin review, public catalogs and suspension.
- [x] Optional member approval, rejection, withdrawal and reapplication.
- [x] Manager-scoped current member roster for direct-join and approval groups; accent-insensitive search, approval-state filters/counts and empty states.
- [x] Reasoned revocation of approved members in approval-required groups, stale/role guards, preserved historical posts/tickets and reviewed reapplication.
- [x] Group-linked badminton activity authoring and community event navigation.
- [x] Member-only linked activity registration, durable tickets/finance/attendance.
- [x] Manual tournament fixtures/results, rescheduling and Admin score correction.
- [x] Accent-insensitive fixture/team/ticket search, combined court/state/own-team filters, active-ticket results filter and explicit empty states.
- [x] Tournament confirmations and schedule forms retain their opening account; failed writes report retry without replaying fixture/result changes.
- [x] Optional group cover upload, persistence and public approved-group rendering.
- [x] Future custom-event cancellation, linked fixture cancellation and pending 100% refunds.
- [x] Primary venue court allocation for seeded/custom events, shared booking/calendar locks and fixture court guards.
- [x] Seeded whole-occurrence cancellation, linked fixture cancellation, pending full refunds and release of event court locks.

## 4. Finance And Reports

- [x] Proof review/resubmission, cancellation/refunds and disputes/closure.
- [x] Primary tariff surcharge and inclusive end date; immutable agreed prices.
- [x] Local settlement estimates, refund liabilities, filters and CSV clipboard.
- [x] Per-facility hourly tariff approval and immutable booking contracts.
- [x] Configurable booking cancellation thresholds/percentages/minimum notice; immutable agreed policies, Owner facility drafts/Admin review and protected primary Admin settings.
- [x] Recipient bank-account configuration and local payout requests/receipt ledger.
- [x] Local receipt-date/refund-date reports, daily paired charts, facility/channel filters and CSV export; manual received-date recording.
- [x] Admin-only system report with period filters, receipt/refund chart, service-date booking/ticket counts, current player/facility/group totals and current approval/cancellation/dispute queues.
- [ ] Compare system-wide dashboard variants against readable Figma frames. Current reports are local demo records, not a bank connection.

## 5. Figma And Acceptance

- [x] Supplied overview screenshots inventoried; readable chat screenshot used.
- [x] Local chat photo selection/preview/removal, optional captions, persisted outgoing image bubbles and guarded zoom viewer.
- [x] Local voice recording/review/removal, optional captions, per-account persistence and single-player message playback with microphone/lifecycle/account guards.
- [x] New critical forms/views tested at normal and 320px/200% text scaling.
- [ ] Compare every frame's geometry, typography, assets and exception variants.
- [ ] Original avatar/event/venue assets verified against Figma.
- [ ] Complete APK installation/manual acceptance on the user's device.

Detailed Figma context and screenshot calls were quota-blocked again on 2026-10-09.
The overview images do not contain enough readable detail to certify exact parity.
No invented completion percentage is used. Remote OTP/bank/chat/GPS integration
is outside the selected demo-first scope and is not claimed as implemented.

## Verification

### Unconfirmed Extensions

These are not delivered and are not verified missing Figma frames. They were
previously mixed into the five-group checklist; separating them does not certify
completion or silently implement them:
- Arbitrary Admin role editing beyond fixed identities/employee permissions.
- Richer group tools beyond memberships/posts/expenses/events (unspecified).
- Automatic brackets/advancement and official scoring/tie-break rules (unspecified).
Automatic bank reconciliation is outside the user's selected local-demo scope,
not an outstanding implemented bank connection. Detailed Figma parity, chat
video/call behavior and native-device acceptance still cannot be certified.

Last full-suite baseline: 726 tests, before this facility/group batch.
Latest batch: 115 focused checks passed, plus 15 dashboard/review widget checks;
static analyzer passed. No full-suite rerun; see COMPLETION_STATUS.md.
APK was rebuilt after the October 9 roster batch; signature/package checks passed.
No connected device was available for installation or manual acceptance.
Exact visual parity and physical-device installation remain unverified.

Additional facility-document batch: incomplete input is separately persisted,
revision/ownership guarded and never published. PDF picking validates readable,
unlocked 1-50-page documents up to 400KB; legal images remain compatible.
PDF rendering and normal/200%-scale form controls have focused coverage.
Native document picking and PDF viewing on the user's phone still need manual
acceptance; no APK rebuild or full-suite rerun was performed for this work.
Verification: 66 focused facility checks passed, then all 12 new draft/document
checks passed after the final font/screenshot and failed-save-retry updates.
These overlapping runs are not a new full-suite total. Static analysis passed.

## October 9 Functional Batch

Booking policies: 76 focused checks passed (15 new model/widget checks).
Cashflow: 50 focused checks passed (15 new model/widget checks), followed by
51 focused cashflow/workflow/payout/policy/PDF regression checks after the chart fix.
Event cancellation and court allocation: 82 focused model/widget/regression
checks passed. These runs overlap; none is a new full-suite result.
Final navigation/write-retry batch: 30 focused widget checks passed, followed by
all six allocation widget checks, including calendar-to-allocation navigation.
Normal/200%-text-scale allocation previews were inspected. Static analysis passed.
After the rolling-cohort correction, 32 focused allocation/cancellation checks
passed, including keeping old future ticket cohorts reachable in the manager catalog.

Event court allocations use existing court-block records, reserve the full event
window at the primary venue and appear in the existing calendar/occupancy views.
Manual unlocking cannot bypass the event editor. Stale editors and conflicting
bookings/locks reject atomically; cancellation releases only that event's locks.
Old snapshots without allocation links or occurrence cancellation ledgers migrate.
Fixtures without an explicit event allocation retain their old label-only behavior.
Registration fees and bank transfers remain demo-only; pending refunds are not
reported as completed transfers. Ticket cancellation remains the existing fixed
24-hour/100% policy, not the configurable booking policy.

Unchecked broad group tools and automatic tournament rules still need an explicit
rule/engine specification; they are not inferred as matching unreadable frames.
Arbitrary role editing, "richer group tools" and an automatic tournament engine
are unconfirmed requirements, not verified missing Figma frames. Do not count
them as proven Figma omissions or mark them delivered without a specification.
The five-group checklist remains open and does not certify full Figma completion.
Read-only browser fallback also required a Figma login; no credentials were entered.
No full project restart, full-suite rerun, APK build or device install in this batch.

## Group Member Revocation

Owner/Admin can revoke an approved membership in a managed custom group with a
5-300-character reason and confirmation, including while that group is suspended.
Only new membership-based actions are revoked. Existing posts/tickets/financial
records remain intact; no automatic ticket cancellation or refund is created.
The player sees the reason in the public group catalog and may apply for review
again. Pending requests remain handled by existing approval/rejection actions.
This does not add bans or revoke members of immediate-join/seeded groups.
Verification: 32 focused group checks passed, including 10 new model/widget checks,
normal/200%-text-scale confirmation, failed-save retry and account-change guards.
Runs overlap the earlier membership/event checks. No full-suite or APK rebuild.

## Admin System Report

Admin dashboard now opens a read-only system report using actual local records.
Presets cover today/7/30 days; a custom range is limited to 366 days. Receipts and
refunds use recorded transaction dates, while booking/ticket counts use service
dates. Current scale and pending queues intentionally do not change with the period.
The report excludes fixed staff identities from player totals and does not invent
daily registrations where the account model has no registration-date ledger.
Empty cashflow periods show an explicit empty state; legacy undated receipts are
disclosed separately. Account changes immediately remove access to the report.
Verification: 28 focused report/dashboard/cashflow checks passed, including seven
new checks and normal/320px-200%-text preview inspection. No full-suite rerun,
app restart or APK rebuild. Exact Figma dashboard variants remain unchecked.

## Review Confirmation And Report Navigation

Group/activity/court-type review confirmations reject account changes while the
dialog is open. Group/activity copy names the operation rather than falling back
to bank-transaction text. Failed persistence is explicitly reported; retry-save
persists the committed revision without repeating approval. Activity cancellation
uses the same failed-save reporting. Admin cashflow drill-down retains the chosen
report date range. Both custom pickers use 2020-through-today bounds and 366 days.
Verification: 35 focused review/group/activity/court-type widget checks passed;
17 report/cashflow/confirmation checks passed in a separate overlapping run.
Seven new checks cover account changes, failed-write retry/reload and navigation.
Static analysis passed. No full-suite run, app restart, APK build or device install.

## Payment And Attendance Confirmation

Booking/ticket payment decisions and reason dialogs retain their initiating
account. Switching between Owner and Admin before confirmation no longer applies
the old action under the new account. Attendance confirmation uses the same guard.
Failed writes are explicitly reported; retry-save persists the existing approved
receipt without invoking approval again. Reload tests check the receipt timestamp
and a single cashflow entry. Attendance lists now include checked-in and cancelled
filters alongside pending/completed/absent, with stable keys and wrapping controls.
Verification: 37 focused payment/workflow widget checks passed, including eight
new account-change/save-retry/filter regressions. Normal and 320px/200%-text
attendance previews were inspected. No full-suite run, app restart or APK build.

## Group Member Roster

Owner/Admin can see current membership of managed custom groups, including direct
join groups that have no approval requests. Pending/withdrawn/rejected/revoked
requests are not counted as active members. Suspended groups keep their historical
membership. Player/guest/unmanaged-group requests reject; results are immutable.
The existing group details now include accent-insensitive search, a clear command,
approval-state counts/filters and empty states. Existing approve/reject/revoke
actions retain their revision, actor and save-retry guards. No new membership
schema is persisted and no joining dates or contact details are invented.
29 focused group model/widget checks passed, including six new roster checks.
Normal/320px-200%-text roster screenshots were inspected. Static analysis passed.
This implements specific group-management tools, not every unspecified feature
that might appear in unreadable Figma frames. Exact visual parity remains open.

## Roster Batch Debug APK

Build succeeded after using a short process-local Java socket temporary directory
inside build/java_tmp. No global Java settings were changed. Output:
build/app/outputs/flutter-apk/app-debug.apk, 215368634 bytes, 2026-10-09 06:47:02
Asia/Saigon. apksigner verification passed (v2, one signer). aapt confirmed package
com.example.test_do_an, version 1.0.0+1, min SDK 24, target SDK 36 and MainActivity.
This is a debug build, not a production-signed release. adb listed no attached
device, so installation, launch and manual acceptance remain unchecked.

## Tournament Search And Confirmation

Fixture search matches normalized team names and fixture/ticket IDs, combining
with existing own-team/state filters and a court selector. Results search matches
team/ticket IDs; an active-ticket switch excludes cancelled entries without
deleting historical statistics. Sorting remains descriptive, not an official
ranking/tie-break or automatic advancement algorithm.
Cancel/result/correction dialogs reject changes to their initiating account.
Schedule editors retain the opening actor. Failed writes explicitly report an
error; the existing save notice retries persistence, not the business operation.
53 focused tournament model/widget checks passed, including 10 new checks.
Static analysis of all four changed Dart files passed after a brace-style repair.
Normal and 320px/200%-text-scale results/fixture previews were inspected.
No full-suite rerun or application restart. Exact Figma parity remains unverified.
Debug APK rebuilt for this tournament batch: 215363044 bytes, October 9 at
06:59:08 Asia/Saigon; v2 signature verification passed. No Android device was
connected, so the installation/manual-acceptance item remains open. A subsequent
source-only brace-style lint repair does not alter the built runtime behavior.

## Chat Images

The existing Figma chat photo command now selects a local PNG/JPEG, previews it
without sending, permits removing it without erasing text, and sends an image
with an optional caption. Attachment previews in the conversation list identify
images. Tapping a sent image opens a zoomable viewer; changing account removes
access to it. There is no remote delivery, incoming image simulation or fabricated
avatar. Voice was subsequently implemented in the batch below; video/calling and
exact original-avatar parity remain unimplemented.
Photos use the existing gallery picker and bounded image encoding: 400KB per image,
at most 20 chat images across an account's conversations. UI selection additionally
checks decoding, 4096px dimensions and 12-megapixel area before attachment. Errors
and cancelled selections preserve the text draft. A selection returned after an
account change is discarded. Sending is disabled while selecting or retrying save.
Save retry persists one committed message, without adding a second image bubble;
legacy snapshots without image fields preserve their text histories. Corrupt
encoding/over-limit snapshots fail without overwriting saved data.
Unsent photo drafts are not persisted. If Android terminates the picker activity,
the user must reselect; no recovered image is routed into another account/thread.
45 focused chat/persistence checks passed (13 new image model/widget checks).
The five image-widget checks were rerun with decoded/nonblank-pixel assertions;
normal and 320px/200%-text previews were inspected after image decoding settled.
Analysis of the five changed Dart files passed. No full-suite rerun or app restart.
Native gallery selection still requires manual testing on a connected device.
Updated debug APK: build/app/outputs/flutter-apk/app-debug.apk, 215376496 bytes,
October 9 at 07:10:56 Asia/Saigon. Build and v2 signature verification passed.

## Local Voice Messages

The chat microphone command opens a recorder without requesting permission until
Record is pressed. Permission denial is actionable; the user may retry. The native
recorder uses record 7.1.1 for mono WAV at 16kHz, and audioplayers 6.8.1 handles
preview/message playback. Temporary capture files are removed on stop/cancel.
Recording auto-stops after 20 seconds; the user can listen, record again, discard,
or attach before sending. Prepared recordings can be removed without deleting text.
Image and voice attachments are mutually exclusive. Text captions remain optional.
One player owns message/draft playback; starting another stops the previous one.
Sending, account changes, leaving the screen or backgrounding stops playback.
Active capture is cancelled on account change/backgrounding; a late permission or
capture result cannot attach to a different account. A failed save retries the
existing committed message, not a second send. Legacy image/text snapshots migrate
with empty voice fields. WAV chunks, PCM format, byte size and actual duration are
validated, with one-second native-final-buffer tolerance; limits are 700KB/recording
and 20 persisted recordings per account. Invalid snapshots do not overwrite storage.
Android RECORD_AUDIO and iOS microphone purpose text were added; no background
recording or remote delivery was enabled. Web capture is explicitly unavailable.
Unsent recordings are memory-only; there is no live calling/video/signaling service.
28 focused model checks passed; 33 widget/persistence checks passed in a disjoint
run (61 total, including 16 new voice checks). Normal/320px-200%-text recorder and
voice bubble screenshots were inspected. Device fakes exercise permissions, player,
timers, background cancellation and account races; this is NOT microphone/speaker
hardware acceptance. No full-suite rerun or app restart. Native recording/playback
quality and iOS build acceptance remain unverified on this Windows host.
Implementation references: https://pub.dev/packages/record and
https://pub.dev/packages/audioplayers; Android WAV output was checked against the
installed record_android 2.2.0 WaveContainer implementation.
Changed-code static analysis passed. Debug APK built at 07:27:20 Asia/Saigon on
October 9: 215688234 bytes. v2 signature verification passed; aapt confirmed
RECORD_AUDIO in the actual APK manifest. adb found no connected Android device.

Hardware acceptance still required: log in as a player, open a conversation,
tap the microphone and Record, grant permission, speak, stop, listen, attach and
send. Replay after closing/reopening the app; verify another account cannot access
it. Also test microphone denial, cancelling/discarding, 20-second auto-stop and
switching away while recording. Confirm sound is captured/heard on the actual
phone; the passing automated fake-device tests cannot establish those facts.

## Booking And Staff Login Delivery Repair

Staff login stays open on failed persistence; retry does not repeat authentication.
Primary and public-facility booking confirmations keep one pending reservation
and retry storage, rather than reserving again or presenting unsaved success.
Inputs/quoted contracts remain fixed while awaiting save. Both flows retain their
opening actor and reject account changes; disposed screens cannot navigate late.
38 focused booking/facility/tariff checks passed, including ten new checks. Two
large-text previews were rerun with actual app theme/fonts and visually inspected.
Staff-login's earlier four new checks plus ten persistence checks also passed.
These runs are not a full-suite total. Changed-code analysis passed.
New debug APK includes both repairs: 215684700 bytes, October 9 at 07:41:39
Asia/Saigon; v2 signature verification passed. No full-suite rerun/app restart.
Detailed Figma parity and native-device acceptance remain unchecked, not completed
by producing the APK. Read-only Figma inventory still hit the Starter quota.

## Account Workflow Delivery Repair

Player login no longer closes on failed persistence; retry saves its current
session without authenticating again. Input/method changes are disabled while
pending. Actor changes during save or before retry cannot complete the old login.
Registration/recovery hide stale challenge/results after account changes; the
registration continue-without-save dialog rechecks its actor after confirmation.
Existing disclosed pending-save states remain available. Recovery retry reports
repeated failure, disables duplicate requests/exit while saving and does not reset
the password again. 37 widget plus 32 model/persistence checks passed (69 disjoint
checks, including 11 new checks); two screenshot checks overlap that run and were
visually inspected at 320px/200%-text. Changed-code analysis passed.
Updated debug APK: 215688415 bytes, October 9 at 07:50:15 Asia/Saigon; v2 signature
verified. Includes account, booking and staff-login repairs. No full-suite/app
restart or physical-device acceptance; adb listed no connected Android device.
Detailed Figma geometry/typography/assets remain unchecked. No remote OTP,
real calls/video, bank settlement or GPS service is claimed by this local demo.

## Employee Workflow Delivery Repair

Failed permission saves no longer show success. Retry saves the committed revision
without configuring permissions again; newer revisions and manager switches reject.
Employee login, collections, attendance and logout disclose failed writes and retry
the current snapshot without repeating business actions. Pending input/actions are
disabled; employee session changes cannot apply an old retry under a different actor.
37 focused employee/model/widget/persistence checks passed (11 new checks). Two
large-text checks were repeated with correct lazy-list scrolling and inspected at
320px/200%-text; runs overlap, not a new full-suite total. Application code analysis
passed. Debug APK: 215692400 bytes, October 9 at 08:00:04 Asia/Saigon, v2 signature
verified. Contains this and the preceding account/booking/staff-login repairs.
No full-suite/app restart or physical-device installation. Figma typography,
geometry, original assets and native microphone/speaker acceptance remain unchecked.
