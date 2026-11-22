import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sightings_journal.dart';

class SightingForm extends StatefulWidget {
  const SightingForm({
    super.key,
    required this.client,
    required this.point,
    this.cat,
  });

  final SupabaseClient client;
  final LatLng point;
  final CatPin? cat;

  @override
  State<SightingForm> createState() => _SightingFormState();
}

class _SightingFormState extends State<SightingForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _note = TextEditingController();
  late final _latitude = TextEditingController(
    text: widget.point.latitude.toStringAsFixed(5),
  );
  late final _longitude = TextEditingController(
    text: widget.point.longitude.toStringAsFixed(5),
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _note.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (widget.client.auth.currentSession == null) {
      setState(
        () => _error = 'Masuk terlebih dahulu untuk mengirim penampakan.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final latitude = _number(_latitude.text)!;
    final longitude = _number(_longitude.text)!;
    final note = _note.text.trim();
    try {
      final saved = await saveSighting(
        widget.client,
        point: LatLng(latitude, longitude),
        name: _name.text.trim(),
        description: _description.text.trim(),
        note: note,
        cat: widget.cat,
      );
      if (mounted) Navigator.of(context).pop(saved);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Penampakan gagal disimpan. Periksa koneksi dan akunmu.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  double? _number(String? value) =>
      double.tryParse((value ?? '').trim().replaceAll(',', '.'));

  String? _coordinateError(String? value, double limit) {
    final number = _number(value);
    if (number == null || !number.isFinite || number.abs() > limit) {
      return 'Masukkan angka antara ${-limit} dan $limit.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.cat == null ? 'Tambah Kucing' : 'Lapor Penampakan'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (widget.cat case final cat?)
              Text(cat.name, style: Theme.of(context).textTheme.titleLarge)
            else ...[
              _field(_name, 'Nama atau julukan', required: true, limit: 60),
              _field(_description, 'Ciri fisik', required: true, limit: 300),
            ],
            const SizedBox(height: 12),
            const Text('Titik penampakan'),
            _coordinate(_latitude, 'Lintang', 90),
            _coordinate(_longitude, 'Bujur', 180),
            _field(_note, 'Catatan (opsional)', limit: 300),
            if (_error case final message?)
              Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Menyimpan…' : 'Simpan penampakan'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    required int limit,
  }) => TextFormField(
    enabled: !_saving,
    controller: controller,
    decoration: InputDecoration(labelText: label),
    maxLength: limit,
    validator: (value) =>
        required && (value ?? '').trim().isEmpty ? 'Isi bagian ini.' : null,
  );

  Widget _coordinate(
    TextEditingController controller,
    String label,
    double limit,
  ) => TextFormField(
    enabled: !_saving,
    controller: controller,
    decoration: InputDecoration(labelText: label),
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    validator: (value) => _coordinateError(value, limit),
  );
}
