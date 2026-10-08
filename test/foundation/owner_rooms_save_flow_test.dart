import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:kos_manage_mobile/domain/models/owner_management.dart';
import 'package:kos_manage_mobile/features/owner/application/owner_module_providers.dart';
import 'package:kos_manage_mobile/features/owner/presentation/rooms_page.dart';
import 'package:kos_manage_mobile/data/repositories/owner_rooms_repository.dart';

class _FakeOwnerRoomsRepository implements OwnerRoomsRepository {
  final List<OwnerRoom> rooms = [];
  Object? createError;
  int getRoomsCalls = 0;

  @override
  Future<List<OwnerRoom>> getRooms(String propertyId, {String query = '', String status = 'all'}) async {
    getRoomsCalls++;
    return rooms
        .where((room) =>
            (query.isEmpty || room.roomNumber.contains(query)) &&
            (status == 'all' || room.status == status))
        .toList();
  }

  @override
  Future<List<OwnerFacility>> getFacilities(String propertyId) async => const [];

  @override
  Future<List<String>> getRoomFacilityIds(String roomId) async => const [];

  @override
  Future<OwnerRoom> createRoom(
    String propertyId, {
    required String roomNumber,
    required int? floor,
    required num price,
    required String status,
    required String? notes,
    required List<String> facilityIds,
  }) async {
    if (createError != null) throw createError!;
    final room = OwnerRoom(
      id: 'room-${rooms.length + 1}',
      roomNumber: roomNumber,
      floor: floor,
      price: price,
      status: status,
      notes: notes,
    );
    rooms.add(room);
    return room;
  }

  @override
  Future<OwnerRoom> updateRoom(
    String roomId, {
    required String roomNumber,
    required int? floor,
    required num price,
    required String status,
    required String? notes,
    required List<String> facilityIds,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteRoom(String roomId) async {
    rooms.removeWhere((room) => room.id == roomId);
  }

  @override
  Future<OwnerFacility> createFacility(String propertyId, String name) =>
      throw UnimplementedError();
}

Widget _buildTestApp({
  required _FakeOwnerRoomsRepository repository,
}) {
  const property = OwnerProperty(id: 'property-1', name: 'Kos Test');

  return ProviderScope(
    overrides: [
      ownerPropertyProvider.overrideWith((ref) async => property),
      ownerRoomsRepositoryProvider.overrideWithValue(repository),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: RoomsPage(),
      ),
    ),
  );
}

void main() {
  testWidgets('shows a clear error when a room cannot be saved', (tester) async {
    final repository = _FakeOwnerRoomsRepository()
      ..createError = PostgrestException(
        message: 'duplicate key value violates unique constraint',
        code: '23505',
      );

    await tester.pumpWidget(_buildTestApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Tambah').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '101');
    await tester.enterText(find.byType(TextField).at(1), '1');
    await tester.enterText(find.byType(TextField).at(2), '1500000');

    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Nomor kamar sudah digunakan.'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows the newly created room after save', (tester) async {
    final repository = _FakeOwnerRoomsRepository();

    await tester.pumpWidget(_buildTestApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Tambah').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '101');
    await tester.enterText(find.byType(TextField).at(1), '1');
    await tester.enterText(find.byType(TextField).at(2), '1500000');

    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Kamar 101'), findsOneWidget);
    expect(repository.rooms, hasLength(1));
  });
}
