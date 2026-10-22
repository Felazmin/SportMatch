# Customer Booking Checkout

## Implemented Flow

- Court/time selection opens the shared customer information form for both the primary venue and published facilities.
- Name, Vietnamese phone number and consent are required. An optional note is saved with the payment. Existing voucher and quoted-price/policy validation remain active.
- Checkout starts a 15-minute proof-submission window, capped at the booking start time. Older non-checkout transfer flows keep their previous 30-minute window.
- Completing checkout requires a payment image and a student/pupil-card image. The order becomes pending, not approved. The owner can inspect both images in the existing payment-review screen.
- Successful disk persistence precedes navigation to the submitted-booking screen. Failed writes can be retried without creating another booking or submitting twice.
- Account/history entry points reopen the corresponding new booking details for checkout bookings. Cancellation remains a reasoned request for the owner to review.
- The expiry sheet offers home navigation or a new submission window. Submitted/approved proofs do not expire automatically.

## Demo Boundaries

- No real bank transfer or payment gateway. Bank details are explicitly fictitious; never send real money.
- Use test images, not real identity documents. PNG/JPEG only, at most 400KB after picker compression, matching existing storage limits. The screenshot's 5MB limit is not used.
- Native app persistence uses the existing encrypted local store. There is no server upload, bank verification or cross-device owner/customer synchronization.
- Expiry currently ends the proof-submission window, not the underlying booking. There is no server-side hold-release worker. Returning home does not cancel a booking; cancellation must be requested separately.
- A new payment window is unavailable once the booking starts, after cancellation, or while a cancellation request awaits review.
- Images are persisted once selection completes. If Android kills the app while its image picker is open, reselect the checkout image after reopening the booking; this new screen does not promise picker-process recovery.
- The student-card requirement follows the supplied mockup and does not automatically grant a student discount.
- Calendar strips on the submitted-booking/detail screens identify the booking date. Use All Bookings for browsing/filtering other dates.

## Verification

Focused tests cover responsive layouts at 402px and 320px/200% text; consent and contact checks; both required images; submit/history/detail navigation; cancellation requests; timeout/retry; pending proofs after the deadline; account switches; save failures; persistence compatibility and both venue entry paths. Screenshot artifacts are generated under `build/previews/checkout-*` with `--dart-define=SCREENSHOT=true`.
