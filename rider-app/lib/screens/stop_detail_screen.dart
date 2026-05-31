import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/locator.dart';

/// Detail + action screen for a single delivery stop.
/// - Navigate (opens maps for routing)
/// - Update status (queued offline)
/// - Capture proof of delivery (photo + OTP)
/// - Record COD and mark Delivered
class StopDetailScreen extends StatefulWidget {
  final RiderStop? stop;
  final int? shipmentId;

  const StopDetailScreen({super.key, required RiderStop this.stop}) : shipmentId = null;

  /// Used for push deep-links where we only have the shipment id.
  const StopDetailScreen.byShipmentId(int this.shipmentId, {super.key}) : stop = null;

  @override
  State<StopDetailScreen> createState() => _StopDetailScreenState();
}

class _StopDetailScreenState extends State<StopDetailScreen> {
  RiderStop? _stop;
  String? _status;
  String? _photoPath;
  final _otp = TextEditingController();
  final _cod = TextEditingController();
  String? _message;
  bool _busy = false;
  bool _resolving = false;   // deep-link lookup in progress
  bool _notFound = false;    // deep-link shipment not in today's stops

  @override
  void initState() {
    super.initState();
    _stop = widget.stop;
    _status = widget.stop?.status;
    if (_stop?.isCod == true) _cod.text = _stop!.codAmount.toStringAsFixed(2);
    if (_stop == null && widget.shipmentId != null) {
      _resolveByShipment();
    }
  }

  @override
  void dispose() {
    _otp.dispose();
    _cod.dispose();
    super.dispose();
  }

  // For deep-link entry: try to find the stop in today's list.
  Future<void> _resolveByShipment() async {
    setState(() {
      _resolving = true;
      _notFound = false;
    });
    try {
      final stops = await Services.rider.dailyStops();
      final match = stops.where((s) => s.id == widget.shipmentId).firstOrNull;
      if (!mounted) return;
      setState(() {
        _stop = match;
        _status = match?.status;
        _notFound = match == null; // surface a clear state instead of hanging on "Loading…"
        if (match?.isCod == true) _cod.text = match!.codAmount.toStringAsFixed(2);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _notFound = true);
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<(double?, double?)> _location() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return (null, null);
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return (null, null); // proceed without a geo-tag rather than block delivery
      }
      final pos = await Geolocator.getCurrentPosition();
      return (pos.latitude, pos.longitude);
    } catch (_) {
      return (null, null);
    }
  }

  Future<void> _navigate() async {
    final s = _stop;
    if (s == null) return;
    // Open the device maps app with a search for the receiver address.
    final query = Uri.encodeComponent('${s.receiverAddress} ${s.receiverPincode}');
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _setStatus(String status) async {
    final s = _stop;
    if (s == null) return;
    setState(() => _busy = true);
    final (lat, lng) = await _location();
    await Services.rider.updateStatus(s.id, status, lat: lat, lng: lng);
    if (!mounted) return;
    setState(() {
      _status = status;
      _busy = false;
      _message = Services.queue.pendingCount > 0
          ? 'Saved offline — will sync when online.'
          : 'Status updated to $status.';
    });
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 60);
    if (file != null && mounted) setState(() => _photoPath = file.path);
  }

  Future<void> _completeDelivery() async {
    final s = _stop;
    if (s == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final (lat, lng) = await _location();

    // Choose POD type: OTP if an OTP was entered, else Photo.
    final hasOtp = _otp.text.trim().isNotEmpty;
    final type = hasOtp ? 'OTP' : 'Photo';

    double? codCollected;
    if (s.isCod) {
      codCollected = double.tryParse(_cod.text.trim());
      if (codCollected == null) {
        setState(() {
          _busy = false;
          _message = 'Enter a valid COD amount.';
        });
        return;
      }
    }

    await Services.rider.submitPod(
      s.id,
      type: type,
      photoUrl: _photoPath, // local path; a real build uploads first and sends the URL
      otp: hasOtp ? _otp.text.trim() : null,
      lat: lat,
      lng: lng,
      codCollected: codCollected,
      remarks: 'Delivered by rider',
    );

    if (!mounted) return;
    setState(() {
      _status = 'Delivered';
      _busy = false;
      _message = Services.queue.pendingCount > 0
          ? 'Delivery saved offline — will sync when online.'
          : 'Delivered ✓';
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _stop;
    return Scaffold(
      appBar: AppBar(title: Text(s?.trackingId ?? 'Shipment ${widget.shipmentId ?? ''}')),
      body: s == null
          ? _resolving
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _notFound
                              ? 'This shipment is not in your current stops.\nIt may already be delivered or reassigned.'
                              : 'Could not load this shipment.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _resolveByShipment,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(s.receiverName, style: Theme.of(context).textTheme.titleLarge),
                Text(s.receiverPhone),
                const SizedBox(height: 4),
                Text(s.receiverAddress),
                Text('Pincode: ${s.receiverPincode}'),
                const SizedBox(height: 8),
                Row(children: [
                  Chip(label: Text(_status ?? s.status)),
                  const SizedBox(width: 8),
                  if (s.isCod) Chip(label: Text('COD ₹${s.codAmount.toStringAsFixed(2)}')),
                ]),
                const Divider(height: 28),

                OutlinedButton.icon(
                  onPressed: _navigate,
                  icon: const Icon(Icons.navigation),
                  label: const Text('Navigate'),
                ),
                const SizedBox(height: 12),

                Text('Update status', style: Theme.of(context).textTheme.titleMedium),
                Wrap(spacing: 8, children: [
                  FilledButton.tonal(onPressed: _busy ? null : () => _setStatus('PickedUp'), child: const Text('Picked up')),
                  FilledButton.tonal(onPressed: _busy ? null : () => _setStatus('OutForDelivery'), child: const Text('Out for delivery')),
                  FilledButton.tonal(onPressed: _busy ? null : () => _setStatus('Failed'), child: const Text('Failed')),
                ]),
                const Divider(height: 28),

                Text('Proof of delivery', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(children: [
                  OutlinedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(_photoPath == null ? 'Take photo' : 'Photo captured ✓'),
                  ),
                ]),
                const SizedBox(height: 8),
                TextField(
                  controller: _otp,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'OTP (if receiver provides one)'),
                ),

                if (s.isCod) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _cod,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'COD collected (₹)'),
                  ),
                ],

                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : _completeDelivery,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Complete delivery'),
                ),

                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(_message!, style: const TextStyle(color: Colors.green)),
                ],
              ],
            ),
    );
  }
}
