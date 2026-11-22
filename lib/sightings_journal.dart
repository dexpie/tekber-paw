import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CatPin {
  const CatPin(this.id, this.name, this.description, this.point, this.seenAt);

  final String id;
  final String name;
  final String description;
  final LatLng point;
  final DateTime seenAt;
}

Future<List<CatPin>> loadCatPins(
  SupabaseClient client, {
  required LatLng southwest,
  required LatLng northeast,
}) async {
  var query = client
      .from('latest_cat_sightings')
      .select('cat_id, name, description, latitude, longitude, seen_at')
      .gte('latitude', southwest.latitude)
      .lte('latitude', northeast.latitude);
  query = southwest.longitude <= northeast.longitude
      ? query
            .gte('longitude', southwest.longitude)
            .lte('longitude', northeast.longitude)
      : query.or(
          'longitude.gte.${southwest.longitude},longitude.lte.${northeast.longitude}',
        );

  final rows = await query.order('seen_at').order('cat_id').limit(100);
  return rows
      .map(
        (row) => CatPin(
          row['cat_id'] as String,
          row['name'] as String,
          row['description'] as String,
          _point(row),
          DateTime.parse(row['seen_at'] as String),
        ),
      )
      .toList();
}

LatLng _point(Map<String, dynamic> row) => LatLng(
  (row['latitude'] as num).toDouble(),
  (row['longitude'] as num).toDouble(),
);

class SightingEntry {
  const SightingEntry(this.point, this.seenAt, this.note);

  final LatLng point;
  final DateTime seenAt;
  final String note;
}

Future<List<SightingEntry>> loadSightingJournal(
  SupabaseClient client,
  String catId,
) async {
  final rows = await client
      .from('sightings')
      .select('seen_at, latitude, longitude, note')
      .eq('cat_id', catId)
      .order('seen_at')
      .order('id')
      .limit(30);
  return rows
      .map(
        (row) => SightingEntry(
          _point(row),
          DateTime.parse(row['seen_at'] as String),
          row['note'] as String,
        ),
      )
      .toList();
}

Future<CatPin> saveSighting(
  SupabaseClient client, {
  required LatLng point,
  required String note,
  required String name,
  required String description,
  CatPin? cat,
}) async {
  if (cat == null) {
    final catId = await client.rpc<String>(
      'add_cat_with_sighting',
      params: {
        'p_name': name,
        'p_description': description,
        'p_latitude': point.latitude,
        'p_longitude': point.longitude,
        'p_note': note,
      },
    );
    return CatPin(catId, name, description, point, DateTime.now());
  }

  final row = await client
      .from('sightings')
      .insert({
        'cat_id': cat.id,
        'latitude': point.latitude,
        'longitude': point.longitude,
        'note': note,
      })
      .select('seen_at')
      .single();
  return CatPin(
    cat.id,
    cat.name,
    cat.description,
    point,
    DateTime.parse(row['seen_at'] as String),
  );
}
