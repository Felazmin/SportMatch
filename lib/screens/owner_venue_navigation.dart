import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../venues/venue_catalog.dart';
import 'facilities_screen.dart';
import 'operations_screen.dart';

void openOwnerVenue(BuildContext context, DemoSession session, String id) {
  if (session.role != DemoRole.owner || session.user == null) return;
  final facility = session.managedFacilities
      .where((f) => f.id == id)
      .firstOrNull;
  if (id != demoVenueId && facility == null) return;
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => facility == null
          ? OperationsScreen(session: session)
          : FacilityDetailScreen(session: session, facility: facility),
    ),
  );
}
