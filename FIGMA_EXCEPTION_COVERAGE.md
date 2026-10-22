# Exception Flow Coverage

Updated 2026-10-07. Local demo only; no exact Figma visual parity is asserted.
References are the supplied PNG overviews saved in design_reference.

| Reference | Implemented behavior | Remaining |
| --- | --- | --- |
| 08 User OTP | Registration/recovery wrong, expired, resend, success and save retry | Exact individual-screen layout and real delivery |
| 09 User payment/refund | Booking proof rejection/resubmission; review, cancellation, policy refund and image receipt | Designed standalone state screens and bank recipient form |
| 10 Social/disputes | Ticket transfer, review, 24-hour cancellation, 100-percent refund, QR payload, evidence and Admin decisions | Camera scanning and original screen composition |
| 11 Resolution/public venue | Follow refund evidence; Admin closes executed decisions, visible to linked player/Owner; approved facilities public-only profile | External notifications and complete public booking integration |
| 12 User system states | Root loading/read failure; scoped empty/access denial, action errors/save retry | Dedicated Figma state-page composition |
| 13 Owner cancellation | Ticket/booking approval or reasoned rejection with confirmation | Dedicated decision-summary pages and editable refund account |
| 14 Owner refund/proof | Reference/image receipt, one-time refund, proof rejection/resubmission | Real bank verification and full designed result screens |
| 15 Owner attendance | Typed ID/full local QR lookup, check-in, no-show, completion, history | Camera scanner and separate confirmation-result pages |
| 16 Owner facility outcomes | Draft/pending/approved/correction/resubmission/public separation | Exact outcome layouts and dedicated system-state pages |
| 17 Admin dispute | Uphold/refund with confirmation, bounded amounts, linked pending/recorded refund; Admin-only one-time closure with persisted date and audit | Arbitrary policy decisions, owner execution deadlines and exact separate result layouts |
| 18 Admin facility review | Approve/correction/resubmit/suspend and published-version isolation | Complete legal-check decisions and designed separate result pages |
| 19 Permissions/system states | Player directory/detail and reasoned password-confirmed lock/unlock; fixed Owner/Admin roles, guarded actions and stale revisions | Role editing, delegated staff login, deletion and password confirmation for other sensitive actions |

## How To Test New Flows

1. Player login > Account > Ve & lich tham gia > choose ticket > finance action.
2. Create a demo transfer, select a sample PNG/JPEG image and submit a reference.
3. Owner login > management > Ve, check-in & hoan tien > same ticket.
4. Review proof; return to Player to request cancellation (24-hour lead time).
5. Owner approves cancellation, selects a refund sample image/reference and confirms.
6. Player can follow the same ledger and create a ticket-linked dispute.
7. Admin > management > Khieu nai > choose uphold/refund, enter explanation, confirm.
8. Staff attendance accepts only local records with approved payments and valid times.

There is no simulated clock control in the app. Tests inject a clock to verify
start/end boundaries; real app actions follow device time. The QR lookup checks
the full payload against local ticket data but is not a cryptographic signature.
No money moves, no notification reaches another device, and the image-picker
drafts on the new ticket/refund forms do not recover interrupted OS sessions.

SCREEN_COVERAGE.md tracks the original seven Owner/Admin references, including
still-missing dashboard composition, multi-venue inventory, tariff surcharges/expiry,
multi-venue calendars, bank payout/recipient-account settlement, role management,
approval queues for groups/activities/court types and star-review moderation.
These are unfinished, not hidden behind a claim of full Figma completion.

Dispute closure distinguishes a decision from its execution. An uphold decision
can be closed by Admin; a refund decision requires the linked recorded refund,
reference and image receipt. Closed cases cannot be reopened or closed again.
Legacy untyped resolutions remain unclosed; no decision type is guessed. The
status is local to this device and does not send a push/SMS notification.

The primary venue now has a three-court hourly grid, manual reservations for
existing player accounts, shared time locks, guarded rescheduling and explicit
onsite demo-payment confirmation. These are project-native layouts, not verified
pixel-exact replacements for every Figma calendar/result screen.

Read-only settlement now derives confirmed booking/ticket payments and refund
liabilities, with voucher/fee/net breakdown, filters, daily bars and CSV clipboard.
The fee is a selectable demo assumption; these views do not execute a payout or
confirm bank reconciliation and do not replace every designed settlement state.
