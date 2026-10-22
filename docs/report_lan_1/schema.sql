-- SportMatch relational design, SQLite 3, version 1, 2026-10-10.
-- DESIGN ONLY: the Flutter demo still uses a secure JSON snapshot.
-- Run on a NEW database. This is not a migration and contains no passwords.
-- UTC Unix seconds; integer VND; enable foreign_keys on EVERY connection.
PRAGMA foreign_keys = ON;
BEGIN;

CREATE TABLE users (
  id INTEGER PRIMARY KEY,
  display_name TEXT NOT NULL CHECK(length(trim(display_name)) BETWEEN 2 AND 100),
  identifier TEXT NOT NULL UNIQUE,
  phone TEXT,
  email TEXT,
  password_hash TEXT NOT NULL CHECK(length(password_hash) >= 20),
  status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active','blocked','disabled')),
  created_at INTEGER NOT NULL,
  revision INTEGER NOT NULL DEFAULT 0 CHECK(revision >= 0)
);
CREATE TABLE roles (code TEXT PRIMARY KEY CHECK(code IN ('player','owner','admin','employee')));
INSERT INTO roles VALUES ('player'),('owner'),('admin'),('employee');
CREATE TABLE user_roles (
  user_id INTEGER NOT NULL REFERENCES users(id),
  role_code TEXT NOT NULL REFERENCES roles(code),
  PRIMARY KEY(user_id,role_code)
);
CREATE TABLE documents (
  id INTEGER PRIMARY KEY,
  uploaded_by INTEGER NOT NULL REFERENCES users(id),
  kind TEXT NOT NULL CHECK(kind IN ('venue_photo','legal','payment','student','refund','qr','chat','other')),
  storage_uri TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  byte_size INTEGER NOT NULL CHECK(byte_size > 0),
  is_private INTEGER NOT NULL DEFAULT 1 CHECK(is_private IN (0,1)),
  created_at INTEGER NOT NULL
);
CREATE TABLE sports (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE);
CREATE TABLE court_types (
  id INTEGER PRIMARY KEY,
  sport_id INTEGER NOT NULL REFERENCES sports(id),
  name TEXT NOT NULL,
  attributes_json TEXT NOT NULL DEFAULT '{}',
  state TEXT NOT NULL CHECK(state IN ('draft','pending','approved','rejected','suspended')),
  revision INTEGER NOT NULL DEFAULT 0,
  UNIQUE(sport_id,name)
);
CREATE TABLE facilities (
  id INTEGER PRIMARY KEY,
  owner_id INTEGER NOT NULL REFERENCES users(id),
  state TEXT NOT NULL DEFAULT 'draft' CHECK(state IN ('draft','pending','approved','rejected')),
  suspended INTEGER NOT NULL DEFAULT 0 CHECK(suspended IN (0,1)),
  review_decision TEXT NOT NULL DEFAULT '' CHECK(review_decision IN ('','approved','supplement','rejected')),
  review_note TEXT NOT NULL DEFAULT '',
  published_version_id INTEGER REFERENCES facility_versions(id),
  revision INTEGER NOT NULL DEFAULT 0 CHECK(revision >= 0),
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL CHECK(updated_at >= created_at)
);
CREATE TABLE facility_versions (
  id INTEGER PRIMARY KEY,
  facility_id INTEGER NOT NULL REFERENCES facilities(id),
  version_no INTEGER NOT NULL CHECK(version_no > 0),
  name TEXT NOT NULL,
  address TEXT NOT NULL,
  district_label TEXT NOT NULL,
  city TEXT NOT NULL,
  court_type_id INTEGER NOT NULL REFERENCES court_types(id),
  court_count INTEGER NOT NULL CHECK(court_count BETWEEN 1 AND 20),
  open_minute INTEGER NOT NULL CHECK(open_minute BETWEEN 0 AND 1439),
  close_minute INTEGER NOT NULL CHECK(close_minute BETWEEN 1 AND 1440 AND close_minute > open_minute),
  hourly_price_vnd INTEGER NOT NULL CHECK(hourly_price_vnd >= 0),
  contact_phone TEXT NOT NULL,
  representative TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  amenities_json TEXT NOT NULL DEFAULT '[]',
  photo_document_id INTEGER REFERENCES documents(id),
  legal_document_id INTEGER REFERENCES documents(id),
  cancellation_policy_json TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  UNIQUE(facility_id,version_no)
);
CREATE TRIGGER facility_publish_scope BEFORE UPDATE OF published_version_id ON facilities
WHEN NEW.published_version_id IS NOT NULL BEGIN
  SELECT RAISE(ABORT,'published version belongs to another facility')
  WHERE NOT EXISTS(SELECT 1 FROM facility_versions v WHERE v.id=NEW.published_version_id AND v.facility_id=NEW.id);
END;
CREATE TRIGGER facility_publish_insert BEFORE INSERT ON facilities
WHEN NEW.published_version_id IS NOT NULL BEGIN
  SELECT RAISE(ABORT,'insert facility before publishing its version');
END;
CREATE TRIGGER facility_version_move BEFORE UPDATE OF facility_id ON facility_versions
WHEN NEW.facility_id <> OLD.facility_id BEGIN
  SELECT RAISE(ABORT,'facility version cannot move');
END;
CREATE TABLE courts (
  id INTEGER PRIMARY KEY,
  facility_id INTEGER NOT NULL REFERENCES facilities(id),
  number INTEGER NOT NULL CHECK(number > 0),
  active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0,1)),
  UNIQUE(facility_id,number)
);
CREATE TABLE owner_verifications (
  id INTEGER PRIMARY KEY,
  owner_id INTEGER NOT NULL REFERENCES users(id),
  legal_document_id INTEGER REFERENCES documents(id),
  state TEXT NOT NULL CHECK(state IN ('draft','pending','approved','rejected')),
  note TEXT NOT NULL DEFAULT '',
  revision INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL
);
CREATE TABLE tariff_proposals (
  id INTEGER PRIMARY KEY,
  facility_id INTEGER NOT NULL REFERENCES facilities(id),
  submitted_by INTEGER NOT NULL REFERENCES users(id),
  state TEXT NOT NULL CHECK(state IN ('draft','pending','approved','rejected')),
  surcharge_vnd INTEGER NOT NULL DEFAULT 0 CHECK(surcharge_vnd >= 0),
  valid_from INTEGER NOT NULL,
  valid_until INTEGER CHECK(valid_until >= valid_from),
  review_note TEXT NOT NULL DEFAULT '',
  revision INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE tariff_bands (
  id INTEGER PRIMARY KEY,
  tariff_id INTEGER NOT NULL REFERENCES tariff_proposals(id),
  day_kind TEXT NOT NULL CHECK(day_kind IN ('weekday','weekend')),
  from_minute INTEGER NOT NULL CHECK(from_minute BETWEEN 0 AND 1439),
  to_minute INTEGER NOT NULL CHECK(to_minute > from_minute AND to_minute <= 1440),
  price_vnd INTEGER NOT NULL CHECK(price_vnd >= 0)
);
CREATE TABLE employee_profiles (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL UNIQUE REFERENCES users(id),
  owner_id INTEGER NOT NULL REFERENCES users(id),
  employee_code TEXT NOT NULL UNIQUE,
  active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0,1)),
  access_revision INTEGER NOT NULL DEFAULT 0,
  CHECK(user_id <> owner_id)
);
CREATE TABLE employee_permissions (
  employee_id INTEGER NOT NULL REFERENCES employee_profiles(id),
  permission TEXT NOT NULL CHECK(permission IN ('schedule','attendance','onsite')),
  PRIMARY KEY(employee_id,permission)
);
CREATE TABLE employee_facilities (
  employee_id INTEGER NOT NULL REFERENCES employee_profiles(id),
  facility_id INTEGER NOT NULL REFERENCES facilities(id),
  PRIMARY KEY(employee_id,facility_id)
);
CREATE TRIGGER employee_facility_scope BEFORE INSERT ON employee_facilities BEGIN
  SELECT RAISE(ABORT,'employee facility owner mismatch') WHERE NOT EXISTS(
    SELECT 1 FROM employee_profiles e JOIN facilities f ON f.owner_id=e.owner_id
    WHERE e.id=NEW.employee_id AND f.id=NEW.facility_id);
END;
CREATE TRIGGER employee_facility_scope_update BEFORE UPDATE ON employee_facilities BEGIN
  SELECT RAISE(ABORT,'employee facility owner mismatch') WHERE NOT EXISTS(
    SELECT 1 FROM employee_profiles e JOIN facilities f ON f.owner_id=e.owner_id
    WHERE e.id=NEW.employee_id AND f.id=NEW.facility_id);
END;
CREATE TABLE employee_shifts (
  id INTEGER PRIMARY KEY,
  employee_id INTEGER NOT NULL REFERENCES employee_profiles(id),
  facility_id INTEGER NOT NULL REFERENCES facilities(id),
  starts_at INTEGER NOT NULL,
  ends_at INTEGER NOT NULL CHECK(ends_at > starts_at),
  note TEXT NOT NULL DEFAULT '',
  revision INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE play_groups (
  id INTEGER PRIMARY KEY,
  founder_id INTEGER NOT NULL REFERENCES users(id),
  sport_id INTEGER NOT NULL REFERENCES sports(id),
  name TEXT NOT NULL,
  district_label TEXT NOT NULL,
  description TEXT NOT NULL,
  rules TEXT NOT NULL,
  requires_approval INTEGER NOT NULL DEFAULT 0 CHECK(requires_approval IN (0,1)),
  state TEXT NOT NULL CHECK(state IN ('draft','pending','approved','rejected','suspended')),
  note TEXT NOT NULL DEFAULT '',
  revision INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE group_memberships (
  group_id INTEGER NOT NULL REFERENCES play_groups(id),
  user_id INTEGER NOT NULL REFERENCES users(id),
  member_role TEXT NOT NULL DEFAULT 'member' CHECK(member_role IN ('member','moderator','founder')),
  joined_at INTEGER NOT NULL,
  PRIMARY KEY(group_id,user_id)
);
CREATE TABLE group_join_requests (
  id INTEGER PRIMARY KEY,
  group_id INTEGER NOT NULL REFERENCES play_groups(id),
  user_id INTEGER NOT NULL REFERENCES users(id),
  state TEXT NOT NULL CHECK(state IN ('pending','approved','rejected','withdrawn')),
  reason TEXT NOT NULL DEFAULT '',
  requested_at INTEGER NOT NULL,
  revision INTEGER NOT NULL DEFAULT 0
);
CREATE UNIQUE INDEX one_pending_group_request ON group_join_requests(group_id,user_id) WHERE state='pending';
CREATE TABLE posts (
  id INTEGER PRIMARY KEY,
  author_id INTEGER NOT NULL REFERENCES users(id),
  group_id INTEGER REFERENCES play_groups(id),
  sport_id INTEGER REFERENCES sports(id),
  content TEXT NOT NULL CHECK(length(trim(content)) > 0),
  hidden INTEGER NOT NULL DEFAULT 0 CHECK(hidden IN (0,1)),
  moderation_note TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL
);
CREATE TABLE events (
  id INTEGER PRIMARY KEY,
  organizer_id INTEGER NOT NULL REFERENCES users(id),
  facility_id INTEGER NOT NULL REFERENCES facilities(id),
  group_id INTEGER REFERENCES play_groups(id),
  title TEXT NOT NULL,
  kind TEXT NOT NULL CHECK(kind IN ('social','tournament')),
  description TEXT NOT NULL,
  rules TEXT NOT NULL,
  state TEXT NOT NULL CHECK(state IN ('draft','pending','approved','rejected','suspended','cancelled')),
  revision INTEGER NOT NULL DEFAULT 0,
  review_note TEXT NOT NULL DEFAULT ''
);
CREATE TABLE event_occurrences (
  id INTEGER PRIMARY KEY,
  event_id INTEGER NOT NULL REFERENCES events(id),
  starts_at INTEGER NOT NULL,
  ends_at INTEGER NOT NULL CHECK(ends_at > starts_at),
  capacity INTEGER NOT NULL CHECK(capacity > 0),
  fee_vnd INTEGER NOT NULL CHECK(fee_vnd >= 0),
  cancelled INTEGER NOT NULL DEFAULT 0 CHECK(cancelled IN (0,1)),
  UNIQUE(event_id,starts_at)
);
CREATE TABLE orders (
  id INTEGER PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  customer_id INTEGER NOT NULL REFERENCES users(id),
  kind TEXT NOT NULL CHECK(kind IN ('booking','registration')),
  amount_vnd INTEGER NOT NULL CHECK(amount_vnd >= 0),
  cancelled INTEGER NOT NULL DEFAULT 0 CHECK(cancelled IN (0,1)),
  created_at INTEGER NOT NULL,
  revision INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE bookings (
  order_id INTEGER PRIMARY KEY REFERENCES orders(id),
  court_id INTEGER NOT NULL REFERENCES courts(id),
  starts_at INTEGER NOT NULL,
  ends_at INTEGER NOT NULL CHECK(ends_at > starts_at),
  contact_name TEXT NOT NULL,
  contact_phone TEXT NOT NULL,
  venue_snapshot_json TEXT NOT NULL,
  hourly_rates_json TEXT NOT NULL,
  discount_vnd INTEGER NOT NULL DEFAULT 0 CHECK(discount_vnd >= 0),
  cancellation_policy_json TEXT NOT NULL,
  attendance TEXT NOT NULL DEFAULT 'pending' CHECK(attendance IN ('pending','checkedIn','absent','completed'))
);
CREATE TRIGGER booking_order_kind BEFORE INSERT ON bookings BEGIN
  SELECT RAISE(ABORT,'booking requires booking order')
  WHERE NOT EXISTS(SELECT 1 FROM orders WHERE id=NEW.order_id AND kind='booking');
END;
CREATE TRIGGER booking_order_kind_update BEFORE UPDATE OF order_id ON bookings BEGIN
  SELECT RAISE(ABORT,'booking requires booking order')
  WHERE NOT EXISTS(SELECT 1 FROM orders WHERE id=NEW.order_id AND kind='booking');
END;
CREATE TABLE registrations (
  order_id INTEGER PRIMARY KEY REFERENCES orders(id),
  occurrence_id INTEGER NOT NULL REFERENCES event_occurrences(id),
  team_name TEXT NOT NULL DEFAULT '',
  partner_name TEXT NOT NULL DEFAULT '',
  quantity INTEGER NOT NULL DEFAULT 1 CHECK(quantity > 0),
  event_snapshot_json TEXT NOT NULL,
  attendance TEXT NOT NULL DEFAULT 'pending' CHECK(attendance IN ('pending','checkedIn','absent','completed'))
);
CREATE TRIGGER registration_order_kind BEFORE INSERT ON registrations BEGIN
  SELECT RAISE(ABORT,'registration requires registration order')
  WHERE NOT EXISTS(SELECT 1 FROM orders WHERE id=NEW.order_id AND kind='registration');
END;
CREATE TRIGGER registration_capacity BEFORE INSERT ON registrations BEGIN
  SELECT RAISE(ABORT,'event capacity exceeded') WHERE
    NEW.quantity + COALESCE((SELECT SUM(r.quantity) FROM registrations r JOIN orders o ON o.id=r.order_id
    WHERE r.occurrence_id=NEW.occurrence_id AND o.cancelled=0),0)
    > (SELECT capacity FROM event_occurrences WHERE id=NEW.occurrence_id);
END;
CREATE TRIGGER registration_capacity_update BEFORE UPDATE ON registrations BEGIN
  SELECT RAISE(ABORT,'registration requires registration order')
  WHERE NOT EXISTS(SELECT 1 FROM orders WHERE id=NEW.order_id AND kind='registration');
  SELECT RAISE(ABORT,'event capacity exceeded') WHERE
    NEW.quantity + COALESCE((SELECT SUM(r.quantity) FROM registrations r JOIN orders o ON o.id=r.order_id
    WHERE r.occurrence_id=NEW.occurrence_id AND r.order_id<>OLD.order_id AND o.cancelled=0),0)
    > (SELECT capacity FROM event_occurrences WHERE id=NEW.occurrence_id);
END;
CREATE TRIGGER order_kind_immutable BEFORE UPDATE OF kind ON orders WHEN NEW.kind<>OLD.kind BEGIN
  SELECT RAISE(ABORT,'order kind cannot change');
END;
CREATE TRIGGER order_no_uncancel BEFORE UPDATE OF cancelled ON orders WHEN OLD.cancelled=1 AND NEW.cancelled=0 BEGIN
  SELECT RAISE(ABORT,'create a new order instead of reactivating a cancelled order');
END;
CREATE TABLE payments (
  id INTEGER PRIMARY KEY,
  order_id INTEGER NOT NULL UNIQUE REFERENCES orders(id),
  state TEXT NOT NULL CHECK(state IN ('awaitingProof','pending','rejected','approved')),
  deadline INTEGER NOT NULL,
  proof_document_id INTEGER REFERENCES documents(id),
  student_document_id INTEGER REFERENCES documents(id),
  reference TEXT NOT NULL DEFAULT '',
  received_at INTEGER,
  review_note TEXT NOT NULL DEFAULT '',
  simulated_gateway INTEGER NOT NULL DEFAULT 0 CHECK(simulated_gateway IN (0,1)),
  method TEXT NOT NULL DEFAULT 'transfer',
  CHECK((state='approved' AND received_at IS NOT NULL) OR (state<>'approved' AND received_at IS NULL))
);
CREATE TABLE cancellation_requests (
  id INTEGER PRIMARY KEY,
  order_id INTEGER NOT NULL REFERENCES orders(id),
  requested_by INTEGER NOT NULL REFERENCES users(id),
  requested_at INTEGER NOT NULL,
  reason TEXT NOT NULL CHECK(length(trim(reason)) BETWEEN 5 AND 300),
  state TEXT NOT NULL CHECK(state IN ('requested','accepted','rejected')),
  estimated_refund_vnd INTEGER NOT NULL CHECK(estimated_refund_vnd >= 0),
  destination_json TEXT NOT NULL,
  reviewed_by INTEGER REFERENCES users(id),
  review_note TEXT NOT NULL DEFAULT '',
  revision INTEGER NOT NULL DEFAULT 0
);
CREATE UNIQUE INDEX one_pending_cancellation ON cancellation_requests(order_id) WHERE state='requested';
CREATE TABLE refunds (
  id INTEGER PRIMARY KEY,
  cancellation_id INTEGER NOT NULL UNIQUE REFERENCES cancellation_requests(id),
  amount_vnd INTEGER NOT NULL CHECK(amount_vnd > 0),
  state TEXT NOT NULL CHECK(state IN ('pending','recorded')),
  reference TEXT NOT NULL DEFAULT '',
  proof_document_id INTEGER REFERENCES documents(id),
  recorded_at INTEGER,
  CHECK((state='recorded' AND recorded_at IS NOT NULL AND proof_document_id IS NOT NULL AND length(reference)>0)
     OR (state='pending' AND recorded_at IS NULL))
);
CREATE TABLE court_reservations (
  id INTEGER PRIMARY KEY,
  court_id INTEGER NOT NULL REFERENCES courts(id),
  booking_order_id INTEGER UNIQUE REFERENCES bookings(order_id),
  occurrence_id INTEGER REFERENCES event_occurrences(id),
  kind TEXT NOT NULL CHECK(kind IN ('booking','manual','event')),
  starts_at INTEGER NOT NULL,
  ends_at INTEGER NOT NULL CHECK(ends_at > starts_at),
  active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0,1)),
  reason TEXT NOT NULL DEFAULT '',
  CHECK((kind='booking' AND booking_order_id IS NOT NULL AND occurrence_id IS NULL)
     OR (kind='event' AND occurrence_id IS NOT NULL AND booking_order_id IS NULL)
     OR (kind='manual' AND occurrence_id IS NULL AND booking_order_id IS NULL))
);
CREATE INDEX reservation_lookup ON court_reservations(court_id,active,starts_at,ends_at);
CREATE TRIGGER reservation_insert BEFORE INSERT ON court_reservations BEGIN
  SELECT RAISE(ABORT,'court reservation overlap') WHERE NEW.active=1 AND EXISTS(
    SELECT 1 FROM court_reservations r WHERE r.court_id=NEW.court_id AND r.active=1
    AND r.starts_at<NEW.ends_at AND NEW.starts_at<r.ends_at);
  SELECT RAISE(ABORT,'reservation does not match booking') WHERE NEW.kind='booking' AND NOT EXISTS(
    SELECT 1 FROM bookings b JOIN orders o ON o.id=b.order_id WHERE b.order_id=NEW.booking_order_id
    AND b.court_id=NEW.court_id AND b.starts_at=NEW.starts_at AND b.ends_at=NEW.ends_at
    AND (NEW.active=0 OR o.cancelled=0));
  SELECT RAISE(ABORT,'reservation does not match occurrence') WHERE NEW.kind='event' AND NOT EXISTS(
    SELECT 1 FROM event_occurrences x JOIN events e ON e.id=x.event_id JOIN courts c ON c.facility_id=e.facility_id
    WHERE x.id=NEW.occurrence_id AND c.id=NEW.court_id AND x.starts_at=NEW.starts_at AND x.ends_at=NEW.ends_at
    AND (NEW.active=0 OR x.cancelled=0));
END;
CREATE TRIGGER reservation_update BEFORE UPDATE ON court_reservations BEGIN
  SELECT RAISE(ABORT,'court reservation overlap') WHERE NEW.active=1 AND EXISTS(
    SELECT 1 FROM court_reservations r WHERE r.id<>OLD.id AND r.court_id=NEW.court_id AND r.active=1
    AND r.starts_at<NEW.ends_at AND NEW.starts_at<r.ends_at);
  SELECT RAISE(ABORT,'reservation does not match booking') WHERE NEW.kind='booking' AND NOT EXISTS(
    SELECT 1 FROM bookings b JOIN orders o ON o.id=b.order_id WHERE b.order_id=NEW.booking_order_id
    AND b.court_id=NEW.court_id AND b.starts_at=NEW.starts_at AND b.ends_at=NEW.ends_at
    AND (NEW.active=0 OR o.cancelled=0));
  SELECT RAISE(ABORT,'reservation does not match occurrence') WHERE NEW.kind='event' AND NOT EXISTS(
    SELECT 1 FROM event_occurrences x JOIN events e ON e.id=x.event_id JOIN courts c ON c.facility_id=e.facility_id
    WHERE x.id=NEW.occurrence_id AND c.id=NEW.court_id AND x.starts_at=NEW.starts_at AND x.ends_at=NEW.ends_at
    AND (NEW.active=0 OR x.cancelled=0));
END;
-- Booking rescheduling must deactivate/delete its reservation, update the booking,
-- then replace/reactivate the reservation in ONE transaction.
CREATE TRIGGER booking_reserved_update BEFORE UPDATE OF court_id,starts_at,ends_at ON bookings
WHEN EXISTS(SELECT 1 FROM court_reservations r WHERE r.booking_order_id=OLD.order_id AND r.active=1) BEGIN
  SELECT RAISE(ABORT,'deactivate reservation before rescheduling in transaction');
END;
CREATE TRIGGER order_cancel_release AFTER UPDATE OF cancelled ON orders WHEN NEW.cancelled=1 BEGIN
  UPDATE court_reservations SET active=0 WHERE booking_order_id=NEW.id;
END;
CREATE TABLE tournament_matches (
  id INTEGER PRIMARY KEY,
  occurrence_id INTEGER NOT NULL REFERENCES event_occurrences(id),
  team_a_order_id INTEGER NOT NULL REFERENCES registrations(order_id),
  team_b_order_id INTEGER NOT NULL REFERENCES registrations(order_id),
  court_id INTEGER NOT NULL REFERENCES courts(id),
  starts_at INTEGER NOT NULL,
  ends_at INTEGER NOT NULL CHECK(ends_at > starts_at),
  state TEXT NOT NULL CHECK(state IN ('scheduled','completed','cancelled')),
  score_a INTEGER CHECK(score_a BETWEEN 0 AND 99),
  score_b INTEGER CHECK(score_b BETWEEN 0 AND 99),
  reason TEXT NOT NULL DEFAULT '',
  revision INTEGER NOT NULL DEFAULT 0,
  CHECK(team_a_order_id<>team_b_order_id),
  CHECK((state='completed' AND score_a IS NOT NULL AND score_b IS NOT NULL AND score_a<>score_b)
     OR (state<>'completed' AND score_a IS NULL AND score_b IS NULL))
);
CREATE TRIGGER match_insert BEFORE INSERT ON tournament_matches BEGIN
  SELECT RAISE(ABORT,'match participants or window invalid') WHERE NOT EXISTS(
    SELECT 1 FROM registrations a JOIN registrations b ON b.occurrence_id=a.occurrence_id
    JOIN orders oa ON oa.id=a.order_id JOIN orders ob ON ob.id=b.order_id
    JOIN event_occurrences x ON x.id=a.occurrence_id JOIN events e ON e.id=x.event_id
    JOIN courts c ON c.facility_id=e.facility_id
    WHERE a.order_id=NEW.team_a_order_id AND b.order_id=NEW.team_b_order_id AND x.id=NEW.occurrence_id
    AND e.kind='tournament' AND c.id=NEW.court_id AND x.starts_at<=NEW.starts_at AND x.ends_at>=NEW.ends_at
    AND oa.cancelled=0 AND ob.cancelled=0);
  SELECT RAISE(ABORT,'match overlap') WHERE NEW.state<>'cancelled' AND EXISTS(
    SELECT 1 FROM tournament_matches m WHERE m.state<>'cancelled' AND m.starts_at<NEW.ends_at AND NEW.starts_at<m.ends_at
    AND (m.court_id=NEW.court_id OR m.team_a_order_id IN (NEW.team_a_order_id,NEW.team_b_order_id)
      OR m.team_b_order_id IN (NEW.team_a_order_id,NEW.team_b_order_id)));
END;
CREATE TRIGGER match_update BEFORE UPDATE ON tournament_matches BEGIN
  SELECT RAISE(ABORT,'match participants or window invalid') WHERE NOT EXISTS(
    SELECT 1 FROM registrations a JOIN registrations b ON b.occurrence_id=a.occurrence_id
    JOIN orders oa ON oa.id=a.order_id JOIN orders ob ON ob.id=b.order_id
    JOIN event_occurrences x ON x.id=a.occurrence_id JOIN events e ON e.id=x.event_id
    JOIN courts c ON c.facility_id=e.facility_id
    WHERE a.order_id=NEW.team_a_order_id AND b.order_id=NEW.team_b_order_id AND x.id=NEW.occurrence_id
    AND e.kind='tournament' AND c.id=NEW.court_id AND x.starts_at<=NEW.starts_at AND x.ends_at>=NEW.ends_at
    AND (NEW.state='cancelled' OR (oa.cancelled=0 AND ob.cancelled=0)));
  SELECT RAISE(ABORT,'match overlap') WHERE NEW.state<>'cancelled' AND EXISTS(
    SELECT 1 FROM tournament_matches m WHERE m.id<>OLD.id AND m.state<>'cancelled'
    AND m.starts_at<NEW.ends_at AND NEW.starts_at<m.ends_at
    AND (m.court_id=NEW.court_id OR m.team_a_order_id IN (NEW.team_a_order_id,NEW.team_b_order_id)
      OR m.team_b_order_id IN (NEW.team_a_order_id,NEW.team_b_order_id)));
END;
CREATE TABLE reviews (
  id INTEGER PRIMARY KEY,
  booking_order_id INTEGER NOT NULL UNIQUE REFERENCES bookings(order_id),
  author_id INTEGER NOT NULL REFERENCES users(id),
  stars INTEGER NOT NULL CHECK(stars BETWEEN 1 AND 5),
  content TEXT NOT NULL,
  hidden INTEGER NOT NULL DEFAULT 0 CHECK(hidden IN (0,1)),
  moderation_note TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL
);
CREATE TRIGGER review_owner BEFORE INSERT ON reviews BEGIN
  SELECT RAISE(ABORT,'review requires completed owned booking') WHERE NOT EXISTS(
    SELECT 1 FROM bookings b JOIN orders o ON o.id=b.order_id WHERE b.order_id=NEW.booking_order_id
    AND o.customer_id=NEW.author_id AND o.cancelled=0 AND b.attendance='completed');
END;
CREATE TRIGGER review_owner_update BEFORE UPDATE OF booking_order_id,author_id ON reviews BEGIN
  SELECT RAISE(ABORT,'review ownership cannot change');
END;
CREATE TABLE disputes (
  id INTEGER PRIMARY KEY,
  order_id INTEGER NOT NULL REFERENCES orders(id),
  customer_id INTEGER NOT NULL REFERENCES users(id),
  subject TEXT NOT NULL,
  message TEXT NOT NULL,
  evidence_document_id INTEGER REFERENCES documents(id),
  owner_response TEXT NOT NULL DEFAULT '',
  decision TEXT CHECK(decision IN ('refund','uphold')),
  resolution TEXT NOT NULL DEFAULT '',
  closed_at INTEGER,
  created_at INTEGER NOT NULL
);
CREATE TABLE audit_entries (
  id INTEGER PRIMARY KEY,
  actor_id INTEGER NOT NULL REFERENCES users(id),
  subject_type TEXT NOT NULL,
  subject_id TEXT NOT NULL,
  action TEXT NOT NULL,
  note TEXT NOT NULL DEFAULT '',
  before_json TEXT,
  after_json TEXT,
  created_at INTEGER NOT NULL
);
CREATE TABLE favorites (
  user_id INTEGER NOT NULL REFERENCES users(id),
  facility_id INTEGER NOT NULL REFERENCES facilities(id),
  PRIMARY KEY(user_id,facility_id)
);
CREATE TABLE payment_methods (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id),
  provider TEXT NOT NULL,
  last_four TEXT NOT NULL CHECK(length(last_four)=4 AND last_four NOT GLOB '*[^0-9]*'),
  is_default INTEGER NOT NULL DEFAULT 0 CHECK(is_default IN (0,1))
);
CREATE UNIQUE INDEX one_default_method ON payment_methods(user_id) WHERE is_default=1;
CREATE TABLE support_tickets (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id),
  subject TEXT NOT NULL,
  message TEXT NOT NULL,
  state TEXT NOT NULL CHECK(state IN ('open','closed')),
  created_at INTEGER NOT NULL
);
CREATE TABLE courses (
  id INTEGER PRIMARY KEY,
  facility_id INTEGER NOT NULL REFERENCES facilities(id),
  title TEXT NOT NULL,
  capacity INTEGER NOT NULL CHECK(capacity > 0),
  fee_vnd INTEGER NOT NULL CHECK(fee_vnd >= 0)
);
CREATE TABLE enrollments (
  id INTEGER PRIMARY KEY,
  course_id INTEGER NOT NULL REFERENCES courses(id),
  user_id INTEGER NOT NULL REFERENCES users(id),
  starts_at INTEGER NOT NULL,
  cancelled INTEGER NOT NULL DEFAULT 0 CHECK(cancelled IN (0,1))
);
CREATE TABLE expenses (
  id INTEGER PRIMARY KEY,
  created_by INTEGER NOT NULL REFERENCES users(id),
  title TEXT NOT NULL,
  total_vnd INTEGER NOT NULL CHECK(total_vnd >= 0),
  created_at INTEGER NOT NULL
);
CREATE TABLE expense_shares (
  id INTEGER PRIMARY KEY,
  expense_id INTEGER NOT NULL REFERENCES expenses(id),
  user_id INTEGER REFERENCES users(id),
  display_name TEXT NOT NULL,
  amount_vnd INTEGER NOT NULL CHECK(amount_vnd >= 0)
);
CREATE TABLE chat_conversations (id INTEGER PRIMARY KEY, created_at INTEGER NOT NULL);
CREATE TABLE chat_participants (
  conversation_id INTEGER NOT NULL REFERENCES chat_conversations(id),
  user_id INTEGER NOT NULL REFERENCES users(id),
  last_read_at INTEGER,
  PRIMARY KEY(conversation_id,user_id)
);
CREATE TABLE chat_messages (
  id INTEGER PRIMARY KEY,
  conversation_id INTEGER NOT NULL REFERENCES chat_conversations(id),
  sender_id INTEGER NOT NULL REFERENCES users(id),
  kind TEXT NOT NULL CHECK(kind IN ('text','image','voice')),
  body TEXT NOT NULL DEFAULT '',
  document_id INTEGER REFERENCES documents(id),
  created_at INTEGER NOT NULL,
  FOREIGN KEY(conversation_id,sender_id) REFERENCES chat_participants(conversation_id,user_id),
  CHECK((kind='text' AND length(body)>0 AND document_id IS NULL) OR (kind IN ('image','voice') AND document_id IS NOT NULL))
);
CREATE TABLE payouts (
  id INTEGER PRIMARY KEY,
  owner_id INTEGER NOT NULL REFERENCES users(id),
  amount_vnd INTEGER NOT NULL CHECK(amount_vnd > 0),
  destination_json TEXT NOT NULL,
  state TEXT NOT NULL CHECK(state IN ('pending','recorded','rejected')),
  note TEXT NOT NULL DEFAULT '',
  proof_document_id INTEGER REFERENCES documents(id),
  recorded_at INTEGER,
  created_at INTEGER NOT NULL
);
CREATE TABLE payout_items (
  payout_id INTEGER NOT NULL REFERENCES payouts(id),
  payment_id INTEGER NOT NULL UNIQUE REFERENCES payments(id),
  allocated_vnd INTEGER NOT NULL CHECK(allocated_vnd > 0),
  PRIMARY KEY(payout_id,payment_id)
);
CREATE INDEX booking_window ON bookings(court_id,starts_at,ends_at);
CREATE INDEX customer_orders ON orders(customer_id,created_at);
CREATE INDEX facility_owner ON facilities(owner_id,state);
CREATE INDEX occurrence_window ON event_occurrences(event_id,starts_at);
CREATE INDEX audit_subject ON audit_entries(subject_type,subject_id,created_at);
CREATE INDEX message_window ON chat_messages(conversation_id,created_at);
COMMIT;

-- Deliberate application-layer responsibilities:
-- authenticate and authorize each request; hash passwords; validate policy JSON;
-- keep every order paired with exactly one matching detail row in a transaction;
-- verify financial transitions, amounts and deadlines; issue idempotency keys;
-- preserve snapshots and published versions as immutable business contracts;
-- update/cancel occurrences and all affected allocations/registrations atomically;
-- check tariff/shift overlaps, schedule dependency for permissions, audit integrity;
-- enforce PSP/webhook verification, malware checks, private file access and retention.
