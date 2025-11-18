import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  bool _busy = false;

  Future<void> _runFixChatParticipants() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // Call your deployed callable in us-central1
      final fn = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('fixChatParticipantsOnce');

      final res = await fn.call(); // no payload required
      final data = (res.data as Map?) ?? {};
      final total = data['total'] ?? 0;
      final updated = data['participantsUpdated'] ?? 0;
      final cleaned = data['adminIdCleaned'] ?? 0;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Fix complete • scanned=$total • participantsUpdated=$updated • adminIdCleaned=$cleaned',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fix failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History (Admin)'),
        actions: [
          IconButton(
            tooltip: 'Fix chats (one-time)',
            onPressed: _busy ? null : _runFixChatParticipants,
            icon: const Icon(Icons.build),
          ),
        ],
      ),
      body: Center(
        child: _busy
            ? const CircularProgressIndicator()
            : const Text(
          'Order History Page\n\nTap the wrench to run the one-time chat fix.',
          textAlign: TextAlign.center,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _runFixChatParticipants,
        icon: const Icon(Icons.build),
        label: const Text('Fix chats'),
      ),
    );
  }
}
