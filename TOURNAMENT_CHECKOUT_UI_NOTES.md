# Customer Tournament Checkout

Customer tournament detail pages open a three-step flow: registration information,
payment method, and persisted receipt. Social event registration remains unchanged.
The design follows the supplied mobile screenshots; event names, dates, fees,
capacity, and descriptions come from the local event model. The seed tournament is
badminton, not the Pickleball tournament shown in the design references. The existing
generated badminton illustration is reused (see FORUM_UI_NOTES.md).

Registration stores birth year, email, level, accepted terms, team, and teammate.
An unpaid registration reserves a team slot and can be resumed from its detail or
the Explore event page. Failed writes keep the user on the current step and allow
retry without another registration or another receipt.

All three payment methods are simulations. QR uses an nvh-demo URI, NOT a bank
VietQR payload. Bank details are deliberately non-payable. No wallet opens, no
money moves, and no email is sent. The success screen confirms a LOCAL DEMO receipt
only. It does not implement a payment gateway, bank callback, or server inventory.
Data uses the app's existing encrypted local session store on the device.

Manual-proof legacy event payments remain unchanged and cannot be overwritten by
the new demo method. Only the registration owner can pay. Existing capacity,
event cancellation, attendance, cancellation requests (at least 24 hours before
the event), organizer review, and refund bookkeeping are preserved. New JSON
fields are optional so older saved registrations remain readable.

Production requires authenticated server-side registration, inventory locking,
verified payment provider integration and callbacks, receipts and email delivery.
