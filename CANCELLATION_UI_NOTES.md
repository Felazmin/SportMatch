# Customer Cancellation Screens

## Implemented

- Customer checkout booking details now open a cancellation page, including when the time limit has passed. Requests already sent reopen their status.
- New checkout bookings require at least two hours before the start, or the booking policy's higher minimum. Exactly two hours is allowed. Legacy non-checkout bookings keep their saved policy.
- The form collects a reason, fee acknowledgement and, when a confirmed refundable payment exists, one refund destination: a PNG/JPEG QR image or bank/account/holder details.
- The estimated refund is calculated from the booking's saved cancellation policy. It is not a fixed 95% for every booking. Unconfirmed payments show no confirmed refundable amount.
- Service-side validation rechecks ownership, booking revision (from the UI), eligibility, destination and the quoted refund before recording the request. An expired form cannot bypass the cutoff.
- Refund destination, estimate, request time and reason are persisted. Owner payment review displays the supplied bank details or QR image.
- Sending a request does not cancel the booking or complete a refund. The timeline separately reflects the owner's decision and the existing recorded-refund state.
- The blocked page shows the cutoff, current time, booking start, unchanged booking/payment status and contact/list actions.
- Customer messages are attached to the booking's payment record and shown in owner review. This is a local one-way contact form, not a real-time chat. Contacting the owner never cancels the booking.
- Failed writes remain visible with retry actions; retrying persistence does not create another request.

## Demo Boundaries

- No real transfer, refund processing, server notification or cross-device synchronization. Use fictitious bank details and test images only.
- Uploaded QR images use the existing 400KB image limit, not the mockup's 5MB label. The app accepts image files; it does not decode or verify financial QR content.
- Data uses the existing encrypted native local store. The old snapshot schema remains readable when the new optional fields are absent.
- Existing checkout hold-expiry behavior is unchanged by this update.

## Verification

Focused tests cover exact cutoff boundaries, refund estimates and consent, destination validation, JSON compatibility, rejected-request resubmission, QR selection, actor changes, persistence failure/retry, local contact messages and owner decision/refund states. Screenshot tests cover all three screens at 402px and 320px with 200% text; artifacts are in `build/previews/cancellation-*`.
