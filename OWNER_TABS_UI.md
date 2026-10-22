# Owner Tabs

The owner role now has separate content in the existing five-tab navigation.

| Tab | Owner content |
| --- | --- |
| Home | Dashboard, facility selection, daily metrics, pending requests, management shortcuts, recent bookings |
| Map | Owned facilities by default, optional public venues, blue owned markers, management navigation |
| Explore | Owned social activities and tournaments, search, filters, creation, calendar, customers and employees |
| Featured | My facilities, approval filters, facility creation, calendar, tariffs and settlement links |

## Data And Privacy

- Dashboard figures come from the demo session. Revenue uses recorded receipts for the selected facility and day; court activity uses published court availability.
- Owner map facilities include private drafts and pending applications. The public venue catalog remains unchanged.
- A published facility with pending edits uses its published profile on the map.
- Account changes reset tab selection and the map widget to avoid retaining private owner markers.
- Owned venue actions open management, not customer booking.
- Address geocoding remains approximate when only a road or district match is available. No exact entrance location is invented.

## Design Reference

Implemented from the owner Figma screenshots supplied in the conversation. Figma design-context access reached its plan quota, so exact pixel parity with every source frame has not been verified. Customer tabs and the existing account tab are retained.

## Verification

- Dashboard updated against the supplied close-up: compact centered header, facility/address selector, four metrics, confirmation notice, exact 12 management shortcuts and recent booking cards. Extra settlement, check-in and payout shortcuts were removed from this dashboard only.
- Latest owner tests: 17 passed, including exact shortcut order, facility-specific edit navigation and booking cards at normal/large text sizes.

- Focused owner, customer tabs and home tests: 51 passed.
- Owner coverage includes 320/402 logical-pixel widths, normal/large text, route selection and private facility isolation.
- Android integration covers owner tab navigation, activity creation entry, owned venue marker and loaded map image widgets.
- Static analysis of changed Dart files passed.
