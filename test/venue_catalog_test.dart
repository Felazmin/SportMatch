import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/venues/venue_catalog.dart';

import 'persistence_test.dart' show TestSessionStore;

void main() {
  const fixtures = [
    VenueSummary(
      id: 'a',
      name: 'Sân Ánh Dương',
      address: 'Tân Phú',
      sport: 'Cầu lông',
      image: '',
      price: 100000,
      rating: 4.5,
      featured: true,
    ),
    VenueSummary(
      id: 'b',
      name: 'Sân Bình Minh',
      address: 'Quận 7',
      sport: 'Pickleball',
      image: '',
      price: 200000,
      rating: 4.9,
    ),
    VenueSummary(
      id: 'c',
      name: 'Sân C',
      address: 'Tân Phú',
      sport: 'Cầu lông',
      image: '',
      price: 120000,
      rating: 4.5,
    ),
  ];
  test('Vietnamese search accepts accents, case, extra spaces and reordered keywords', () {
    for (final query in [
      'dai hoc cong thuong',
      ' ĐẠI HỌC  ',
      'cau long tay thanh',
      'tay thanh cong thuong',
    ]) {
      expect(filterVenues(query: query).single.id, demoVenueId);
    }
    expect(filterVenues(query: 'không tồn tại'), isEmpty);
  });
  test('Sport, inclusive price/rating, saved and featured filters compose', () {
    expect(
      filterVenues(
        venues: fixtures,
        sport: 'Cầu lông',
        maxPrice: 120000,
        minRating: 4.5,
      ).map((v) => v.id),
      ['a', 'c'],
    );
    expect(filterVenues(venues: fixtures, maxPrice: 99999), isEmpty);
    expect(filterVenues(venues: fixtures, minRating: 5), isEmpty);
    expect(
      filterVenues(
        venues: fixtures,
        favorites: {'b'},
        favoritesOnly: true,
      ).single.id,
      'b',
    );
    expect(filterVenues(venues: fixtures, featuredOnly: true).single.id, 'a');
    expect(
      filterVenues(venues: fixtures, sport: 'Pickleball', featuredOnly: true),
      isEmpty,
    );
  });
  test('Sorting is deterministic and does not mutate source catalog', () {
    expect(
      filterVenues(venues: fixtures, sort: VenueSort.rating).map((v) => v.id),
      ['b', 'a', 'c'],
    );
    expect(
      filterVenues(venues: fixtures, sort: VenueSort.price).map((v) => v.id),
      ['a', 'c', 'b'],
    );
    expect(
      filterVenues(venues: fixtures, sort: VenueSort.name).map((v) => v.id),
      ['a', 'b', 'c'],
    );
    expect(fixtures.map((v) => v.id), ['a', 'b', 'c']);
  });
  test(
    'Guest and account favorites are isolated and exposed as immutable sets',
    () {
      final session = DemoSession();
      session.toggleFavorite(demoVenueId);
      expect(session.isFavorite(demoVenueId), isTrue);
      expect(() => session.favoriteVenueIds.clear(), throwsUnsupportedError);
      session.login(DemoSession.phone, DemoSession.password);
      expect(session.favoriteVenueIds, isEmpty);
      session.toggleFavorite(demoVenueId);
      session.register('Other', '0912345678', 'Test1234');
      expect(session.favoriteVenueIds, isEmpty);
      session.login(DemoSession.email, DemoSession.password);
      expect(session.isFavorite(demoVenueId), isTrue);
      session.toggleFavorite(demoVenueId);
      expect(session.favoriteVenueIds, isEmpty);
      session.logout();
      expect(session.isFavorite(demoVenueId), isTrue);
      expect(() => session.toggleFavorite('unknown'), throwsArgumentError);
      session.dispose();
    },
  );
  test(
    'Favorites persist through restart without affecting bookings',
    () async {
      final store = TestSessionStore();
      final first = DemoSession(store: store);
      await first.initialize();
      first.toggleFavorite(demoVenueId);
      first.login(DemoSession.phone, DemoSession.password);
      first.toggleFavorite(demoVenueId);
      await first.flush();
      first.dispose();
      final second = DemoSession(store: store);
      await second.initialize();
      expect(second.isFavorite(demoVenueId), isTrue);
      expect(second.bookings.length, 2);
      second.toggleFavorite(demoVenueId);
      second.logout();
      expect(second.isFavorite(demoVenueId), isTrue);
      await second.flush();
      second.dispose();
      final third = DemoSession(store: store);
      await third.initialize();
      third.login(DemoSession.phone, DemoSession.password);
      expect(third.favoriteVenueIds, isEmpty);
      await third.flush();
      third.dispose();
    },
  );
  test('Previous APK snapshot without favorites restores existing login and history', () async {
    final store = TestSessionStore();
    final first = DemoSession(store: store);
    await first.initialize();
    first.login(DemoSession.phone, DemoSession.password);
    await first.flush();
    first.dispose();
    final old = jsonDecode(store.value!) as Map<String, dynamic>
      ..remove('favorites');
    store.value = jsonEncode(old);
    final session = DemoSession(store: store);
    await session.initialize();
    expect(session.loadFailed, isFalse);
    expect(session.user!.identifier, DemoSession.phone);
    expect(session.bookings.length, 2);
    expect(session.favoriteVenueIds, isEmpty);
    session.dispose();
  });
  test('Invalid favorites ownership preserves original snapshot', () async {
    final store = TestSessionStore();
    final first = DemoSession(store: store);
    await first.initialize();
    first.dispose();
    final data = jsonDecode(store.value!) as Map<String, dynamic>;
    data['favorites'] = {
      'unknown@example.com': [demoVenueId],
    };
    final original = jsonEncode(data);
    store.value = original;
    final session = DemoSession(store: store);
    await session.initialize();
    expect(session.loadFailed, isTrue);
    expect(store.value, original);
    session.dispose();
  });
}
