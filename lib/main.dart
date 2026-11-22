import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:latlong2/latlong.dart';

import 'cat_summary.dart';
import 'nearby_map.dart';
import 'sighting_form.dart';
import 'sightings_journal.dart';
import 'supabase_setup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(PawMapApp(backend: await PawMapBackend.initialize()));
}

class PawMapApp extends StatelessWidget {
  const PawMapApp({super.key, required this.backend});

  final PawMapBackend backend;

  @override
  Widget build(BuildContext context) {
    final client = backend.client;
    return MaterialApp(
      title: 'PawMap',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF28645D)),
      home: Scaffold(
        appBar: AppBar(title: const Text('PawMap')),
        body: client == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    backend.problem ?? 'Konfigurasi Supabase belum siap.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : NearbyMap(
                client: client,
                onCatSelected: (context, cat) => showCatSummary(
                  context,
                  name: cat.name,
                  description: cat.description,
                  lastSeen: formatSightingTime(context, cat.seenAt),
                ),
                onJournal: (context, cat) => _openJournal(context, client, cat),
                onReport: (context, point, cat) =>
                    _openForm(context, client, point, cat),
              ),
      ),
    );
  }
}

void _openJournal(BuildContext context, SupabaseClient client, CatPin cat) {
  Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => SightingsJournal(client: client, cat: cat),
    ),
  );
}

Future<CatPin?> _openForm(
  BuildContext context,
  SupabaseClient client,
  LatLng point,
  CatPin? cat,
) async {
  final navigator = Navigator.of(context);
  if (client.auth.currentSession == null) {
    final signedIn = await navigator.push<bool>(
      MaterialPageRoute(builder: (_) => PawMapSignInPage(client: client)),
    );
    if (signedIn != true || !context.mounted) return null;
  }
  return navigator.push<CatPin>(
    MaterialPageRoute(
      builder: (_) => SightingForm(client: client, point: point, cat: cat),
    ),
  );
}
