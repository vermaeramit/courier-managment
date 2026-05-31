import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/locator.dart';
import '../services/push_service.dart';
import 'scan_screen.dart';
import 'stop_detail_screen.dart';

class StopsScreen extends StatefulWidget {
  const StopsScreen({super.key});
  @override
  State<StopsScreen> createState() => _StopsScreenState();
}

class _StopsScreenState extends State<StopsScreen> {
  List<RiderStop> _stops = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    Services.queue.addListener(_onQueueChanged);
  }

  @override
  void dispose() {
    Services.queue.removeListener(_onQueueChanged);
    super.dispose();
  }

  void _onQueueChanged() => setState(() {});

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Stops are already ordered server-side by pincode; see README for hooking a
      // maps Directions API to optimise the exact stop sequence.
      final stops = await Services.rider.dailyStops();
      setState(() => _stops = stops);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    if (code == null) return;
    final match = _stops.where((s) => s.trackingId == code).firstOrNull;
    if (match != null) {
      _openStop(match);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scanned $code — not in today\'s stops.')),
      );
    }
  }

  void _openStop(RiderStop stop) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => StopDetailScreen(stop: stop),
    )).then((_) => _load());
  }

  Future<void> _logout() async {
    await PushService.logout();
    await Services.auth.clear();
  }

  @override
  Widget build(BuildContext context) {
    final pending = Services.queue.pendingCount;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today\'s stops'),
        actions: [
          if (pending > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: const Icon(Icons.sync_problem, size: 16),
                label: Text('$pending queued'),
              ),
            ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scan,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(children: [Padding(padding: const EdgeInsets.all(20), child: Text(_error!, style: const TextStyle(color: Colors.red)))])
                : _stops.isEmpty
                    ? ListView(children: const [Padding(padding: EdgeInsets.all(20), child: Text('No stops assigned today.'))])
                    : ListView.separated(
                        itemCount: _stops.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final s = _stops[i];
                          return ListTile(
                            leading: CircleAvatar(child: Text('${i + 1}')),
                            title: Text(s.receiverName),
                            subtitle: Text('${s.receiverAddress}\n${s.trackingId} · ${s.status}'),
                            isThreeLine: true,
                            trailing: s.isCod
                                ? Chip(label: Text('COD ₹${s.codAmount.toStringAsFixed(0)}'))
                                : const Text('Prepaid'),
                            onTap: () => _openStop(s),
                          );
                        },
                      ),
      ),
    );
  }
}
