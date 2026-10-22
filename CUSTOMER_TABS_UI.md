# Customer tabs update - 2026-10-09

## Map lookup repair

Fixed a self-referential Future in pending-request cleanup that prevented geocoding results from completing. Venue lookups now have an 18-second UI deadline with finally cleanup; selecting/searching a venue can retry a failed coordinate lookup. Submitted address searches have a distinct result pin and center the camera, with stale results discarded when the query changes.

Lookup now uses Nominatim, with normalized Vietnamese queries, Vietnam-only results, an identifying app User-Agent, serialized requests spaced at least 1.1 seconds apart and session caching. It runs on explicit search submission or for the displayed venue catalog, not address autocomplete. Native geocoding remains a fallback. The geocoder endpoint is configurable through GEOCODING_URL. Queries/addresses are sent to the provider; review its privacy and usage policies before public rollout: https://operations.osmfoundation.org/policies/nominatim/.

The demo address 73/1 Nguyen Do Cung is not indexed at house-number level by the checked provider. A road-level fallback is marked approximate; it must not be presented as a verified entrance coordinate. A verified venue latitude/longitude is still required for exact entrance placement.

Implemented from the supplied screenshots:

- Explore: five shortcuts, upcoming event, three recommendations, editorial/community links.
- Featured: voucher banner, featured venue posters, bookable venue recommendations, favorites.
- Map: embedded OpenStreetMap tiles, pan/zoom, search, sport filters, venue detail and booking.
- Venue detail: photo header, address, amenities, actual app reviews and booking action.

Content uses the existing DemoSession catalog, events, courses and vouchers. The default catalog currently has one featured venue. Original Figma K99, Thao Dien and racket-guide images are not available locally, so existing project photos are reused. This is not a claim of pixel-perfect image/content parity.

Map tiles loaded successfully in an Android emulator integration test. Venue geocoding and device GPS depend on platform/network services; unavailable coordinates are reported instead of fabricated. GPS permission is requested only after pressing the location button. Native geocoding targets Android/iOS; desktop/web geocoding is not provided. Real-device GPS accuracy has not been verified.

Tile source: https://tile.openstreetmap.org/{z}/{x}/{y}.png
Attribution remains visible; flutter_map's built-in cache is used. MAP_TILE_URL can override the provider. Before public production rollout, review provider capacity and https://operations.osmfoundation.org/policies/tiles/.

Verification: focused widget tests, narrow-screen and large-text screenshots, static analysis of changed files, Android integration test including nonempty rendered map tiles. Device screenshots are in build/previews/customer-*-device.png. Map fixture screenshots from widget tests are not live-map evidence.
