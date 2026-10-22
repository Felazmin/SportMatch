# Owner Management Figma Coverage

Reference: screenshots supplied in this chat. This is not a claim that the entire Figma file has been inspected or matched.

## Close-up references received

| Dashboard shortcut | Reference | Implementation |
| --- | --- | --- |
| Dashboard | Previous screenshot | OwnerDashboardTab |
| Khach hang | Previous screenshot | CustomersScreen |
| Nhan vien | Latest screenshot 1 | EmployeeRosterScreen / OwnerStaffView |
| Quan ly tran dau | Latest screenshot 2 | ActivitiesScreen / OwnerActivitiesView |
| Ho so | Latest screenshot 3 | AccountScreen / OwnerProfileView |
| San cua toi | Latest screenshot 4 | FacilitiesScreen / OwnerFacilitiesView |
| Them san | Latest screenshots 5-6 | FacilityFormScreen |

| Cho duyet | Pending application close-up | FacilityPendingScreen |
| Chinh sua san | Pending edit close-ups | FacilityFormScreen pending editor |
| Lich san | Latest four-screen reference 1 | OwnerCalendarView |
| Chi tiet dat san | Latest four-screen reference 2 | OwnerBookingView |
| Doanh thu | Latest four-screen reference 3 | OwnerRevenueView |
| Bang gia | Latest four-screen reference 4 | OwnerPricesView |

## Reference scope

The Dashboard edit shortcut now opens a card list with "Chinh sua" actions, not
the old operations screen or a preselected facility. Each action opens the existing
prefilled form; save submits an approval revision and cancel leaves the saved
profile unchanged. The primary demo venue is included via a separate CS0000
profile record, not another bookable facility. Admin approval publishes its name,
address and photo into the existing cong-thuong catalog entry. Its 3-court booking
contract, 06:00-22:00 hours, prices and cancellation settings are unchanged; those
form controls are read-only for the primary venue. Sample legal proof is required
for its first submission, never invented. The new snapshot key is optional for
older saved sessions.

Dashboard "Cho duyet" now opens the owner's actual pending facility application.
One application opens directly; multiple applications show a picker; no application
shows an empty state. The sent-profile editor retains pending status and revision
checks. Submission timestamps preserve minutes. A failed device write no longer
navigates to the status screen as though saving succeeded; the existing retry-save
control persists the revised pending application without another update.

Close-up references have now been supplied for all twelve main Dashboard shortcuts. Nested screens are awaiting the user's next screenshots; their existing functional flows are retained. This does not establish full parity with the entire Figma file.

- Calendar uses actual primary/managed facility court counts, dates, booking and event blocks; the sample seven courts are not fabricated.
- Booking detail uses actual contacts, payment evidence and audit history. Unavailable student documents are not fabricated. Call/SMS use device applications.
- Revenue is recorded receipts by transaction date, with refunds reported separately; outstanding booking amounts use booking dates. CSV export copies the existing report to the clipboard. The advanced cashflow report remains available for settlement filters.
- Prices use the venue's actual sport and courts. Weekday/weekend bands retain validation, effective dates and Admin approval. Existing booking quotes remain unchanged. Rental equipment and recurring-customer discounts have no contract in the current model and are not fabricated.

## Data and contract boundaries

- Counts, revenue, employee status, shifts, venue state and verification are read from the session; sample numbers and names are not hardcoded.
- Staff shifts and locally created social/tournament activities currently use the primary venue contract. Their venue context is read-only, not a nonfunctional dropdown.
- Facility filters distinguish actual pending applications from drafts, rejected revisions and suspended facilities.
- Existing draft, document picker, approval and role checks remain in use. Direct submission validates required proof before creating the application.
- The current facility model accepts whole-hour opening/closing times, one venue photo and documents up to 400KB. The screenshot's half-hour time, eight photos and 10MB upload are not supported by that model and have not been simulated.
- Surface information uses the existing court-type data; no independent surface-material field was added.
- Notifications open the in-app request center. Switching to Player signs out and opens login; it does not silently impersonate a different role.
- Profile verification, payouts, refunds and file handling remain local demo workflows, not live financial or identity services.
