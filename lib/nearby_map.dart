import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'cat_summary.dart';
import 'sightings_journal.dart';

class NearbyMap extends StatefulWidget {
  const NearbyMap({
    super.key,
    required this.client,
    required this.onCatSelected,
    required this.onJournal,
    required this.onReport,
  });

  final SupabaseClient client;
  final Future<CatSummaryAction?> Function(BuildContext, CatPin) onCatSelected;
  final void Function(BuildContext, CatPin) onJournal;
  final Future<CatPin?> Function(BuildContext, LatLng, CatPin?) onReport;

  @override
  State<NearbyMap> createState() => _NearbyMapState();
}

class _NearbyMapState extends State<NearbyMap> {
  final _map = MapController();
  List<CatPin> _pins = [];
  bool _ready = false;
  bool _loading = false;
  bool _failed = false;
  int _request = 0;

  Future<void> _loadArea() async {
    if (!_ready || !mounted) return;
    final bounds = _map.camera.visibleBounds;
    final request = ++_request;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final pins = await loadCatPins(
        widget.client,
        southwest: bounds.southWest,
        northeast: bounds.northEast,
      );
      if (mounted && request == _request) setState(() => _pins = pins);
    } catch (_) {
      if (mounted && request == _request) setState(() => _failed = true);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _reportAt(LatLng point, {CatPin? cat}) async {
    final saved = await widget.onReport(context, point, cat);
    if (saved == null || !mounted) return;
    _map.move(saved.point, 16);
    await _loadArea();
    if (mounted) widget.onJournal(context, saved);
  }

  Future<void> _showCat(CatPin cat) async {
    final action = await widget.onCatSelected(context, cat);
    if (!mounted) return;
    if (action == CatSummaryAction.journal) {
      widget.onJournal(context, cat);
    } else if (action == CatSummaryAction.report) {
      await _reportAt(cat.point, cat: cat);
    }
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: Stack(
          alignment: Alignment.center,
          children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: const LatLng(-7.2825, 112.7957),
                initialZoom: 15,
                minZoom: 4,
                maxZoom: 19,
                onMapReady: () {
                  _ready = true;
                  _loadArea();
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'app.pawmap.tekber_paw',
                ),
                MarkerLayer(
                  markers: [
                    for (final cat in _pins)
                      Marker(
                        point: cat.point,
                        width: 48,
                        height: 48,
                        child: IconButton.filled(
                          tooltip: cat.name,
                          icon: const Icon(Icons.pets),
                          onPressed: () => _showCat(cat),
                        ),
                      ),
                  ],
                ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      onTap: () => launchUrl(
                        Uri.parse('https://www.openstreetmap.org/copyright'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const IgnorePointer(child: Icon(Icons.add, color: Colors.black87)),
          ],
        ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              if (_loading)
                const LinearProgressIndicator()
              else
                Text(
                  _failed
                      ? 'Penanda gagal dimuat. Coba muat area ini lagi.'
                      : _pins.isEmpty
                      ? 'Belum ada penampakan di area yang dimuat.'
                      : '${_pins.length} kucing di area yang dimuat.',
                ),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  TextButton(
                    onPressed: _ready && !_loading ? _loadArea : null,
                    child: const Text('Muat area ini'),
                  ),
                  FilledButton(
                    onPressed: _ready
                        ? () => _reportAt(_map.camera.center)
                        : null,
                    child: const Text('Tambah di tanda +'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
