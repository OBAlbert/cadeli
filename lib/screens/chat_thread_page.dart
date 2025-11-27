import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import 'chat_list_page.dart';

class ChatThreadPage extends StatefulWidget {
  const ChatThreadPage({
    super.key,
    required this.orderId,
    required this.customerId,
    this.isAdminView = false,
  });

  final String orderId;
  final String customerId;
  final bool isAdminView;

  @override
  State<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _SystemChip extends StatelessWidget {
  const _SystemChip(this.text, this.time);
  final String text;
  final DateTime? time;

  String _fmt(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final ap = t.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ap';
  }

  // If a single token is extremely long (no spaces), insert zero-width spaces
  // every N chars so it can wrap without overflowing.
  String _safelyWrapLongTokens(String s, {int chunk = 24}) {
    final words = s.split(' ');
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      if (w.length > chunk) {
        // Insert \u200B between characters so Flutter can wrap it.
        words[i] = w.split('').join('\u200B');
      }
    }
    return words.join(' ');
  }



  @override
  Widget build(BuildContext context) {
    final when = time != null ? _fmt(time!) : '';
    final maxChipWidth = (MediaQuery.of(context).size.width * 0.82).clamp(0, 600);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxChipWidth.toDouble()),
            child: Container(
              clipBehavior: Clip.antiAlias, // no leaks
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF2F6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.8)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // centered message text with safe wrapping
                  Text(
                    _safelyWrapLongTokens(text),
                    textAlign: TextAlign.center,
                    softWrap: true,
                    maxLines: null,
                    overflow: TextOverflow.clip,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4A5673),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (when.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      when,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10, color: Color(0xFF7C869D)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

String _safelyWrapLongTokens(String s, {int chunk = 24}) {
  final words = s.split(' ');
  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    if (w.length > chunk) {
      words[i] = w.split('').join('\u200B');
    }
  }
  return words.join(' ');
}


class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.isMine, required this.time});
  final String text;
  final bool isMine;
  final DateTime time;

  String _fmt(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final ap = t.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ap';
  }

  @override
  Widget build(BuildContext context) {
    final align = isMine ? Alignment.centerRight : Alignment.centerLeft;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(14),
      topRight: const Radius.circular(14),
      bottomLeft: isMine ? const Radius.circular(14) : const Radius.circular(4),
      bottomRight: isMine ? const Radius.circular(4) : const Radius.circular(14),
    );

    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFF1A233D) : Colors.white,
          borderRadius: radius,
          border: Border.all(color: Colors.black12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // inside _Bubble.build
            Text(
              _safelyWrapLongTokens(text),
              softWrap: true,
              maxLines: null,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isMine ? Colors.white : const Color(0xFF1A233D),
                fontSize: 14,
              ),
            ),


            const SizedBox(height: 4),
            Text(
              _fmt(time),
              style: TextStyle(
                color: isMine ? Colors.white70 : Colors.black45,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatThreadPageState extends State<ChatThreadPage> {
  final _controller = TextEditingController();
  final _listController = ScrollController();

  // ADMIN quick chips
  static const List<(String label, String text)> _adminQuick = [
  ('On the way 🚚', 'Delivery is on the way.'),
  ('Outside 🛎️', 'The driver is outside.'),
  ('Delivered ✅', 'Order delivered. Thank you!'),
  ];

  // ADMIN more templates
  static const List<String> _adminMore = [
  'Running 10–15 min late. Sorry!',
  'We’re preparing your order now.',
  'Please confirm your address.',
  'Please answer your phone.',
  'Unable to reach you, trying again.',
  ];

  // CUSTOMER chips
  static const List<(String label, String text)> _customerQuick = [
  ('Where is my order?', 'Hi! Where is my order, please?'),
  ('ETA please?', 'Hi! Could I get an ETA, please?'),
  ('Leave at door', 'Please leave at the door.'),
  ('Call on arrival', 'Please call me when you arrive.'),
  ];

  @override
  void initState() {
  super.initState();
  // Customer may ensure shell (allowed by rules). Admin won’t create.
  if (!widget.isAdminView) {
  ChatService.instance.ensureChat(
  orderId: widget.orderId,
  customerId: widget.customerId,
  adminId: '', // harmless, or:
  );
  }

  // Mark read on open
  ChatService.instance.markThreadRead(widget.orderId, isAdmin: widget.isAdminView);
  }

  @override
  void dispose() {
  _controller.dispose();
  _listController.dispose();
  super.dispose();
  }

  String _shortId(String s) => s.length <= 6 ? s : s.substring(0, 6);

  @override
  Widget build(BuildContext context) {
  final me = FirebaseAuth.instance.currentUser?.uid ?? '';
  final myQuick = widget.isAdminView ? _adminQuick : _customerQuick;

  return Scaffold(
  backgroundColor: Colors.white,
  body: Stack(
  fit: StackFit.expand,
  children: [
  Positioned.fill(child: Image.asset('assets/background/fade_base.jpg', fit: BoxFit.cover)),
  SafeArea(
  bottom: false,
  child: Column(
  children: [
  // Header
  Padding(
  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
  child: Row(
  children: [
  TextButton.icon(
  onPressed: () => Navigator.pop(context),
  icon: const Icon(Icons.arrow_back),
  label: const Text('Your Order Chats'),
  style: TextButton.styleFrom(foregroundColor: const Color(0xFF1A233D)),
  ),
  const Spacer(),
  if (widget.isAdminView)
  IconButton(
  tooltip: 'More templates',
  icon: const Icon(Icons.more_vert, color: Color(0xFF1A233D)),
  onPressed: _showAdminMoreTemplates,
  ),
  OutlinedButton.icon(
  onPressed: _showOrderDetails,
  icon: const Icon(Icons.receipt_long),
  label: Text('Order #${_shortId(widget.orderId)}'),
  style: OutlinedButton.styleFrom(
  foregroundColor: const Color(0xFF1A233D),
  side: const BorderSide(color: Color(0xFF1A233D)),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  visualDensity: VisualDensity.compact,
  ),
  ),
  ],
  ),
  ),

  // Messages
  Expanded(
  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
  stream: ChatService.instance.streamMessages(widget.orderId),
  builder: (context, snap) {
  if (snap.connectionState == ConnectionState.waiting) {
  return const Center(child: CircularProgressIndicator());
  }
  final docs = snap.data?.docs ?? [];
  if (docs.isEmpty) {
  return const Center(
  child: Text('Say hi 👋', style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w600)),
  );
  }

  // auto scroll to bottom on new data
  WidgetsBinding.instance.addPostFrameCallback((_) {
  if (_listController.hasClients) {
  final pos = _listController.position;
  _listController.jumpTo(pos.maxScrollExtent);
  }
  });

  return ListView.builder(
  controller: _listController,
  padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
  itemCount: docs.length,
  itemBuilder: (_, i) {
  final m = docs[i].data();
  final type = (m['type'] ?? 'text').toString();
  final senderId = (m['senderId'] ?? '').toString();
  final ts = m['createdAt'];
  final when = ts is Timestamp ? ts.toDate() : DateTime.now();
  final text = (m['text'] ?? '').toString();

  if (type == 'system') {
  return _SystemChip(text, when);
  }

  final isMine = senderId == me;
  return _Bubble(text: text, isMine: isMine, time: when);
  },
  );
  },
  ),
  ),

  // Input
  _InputBar(
  controller: _controller,
  onSend: (text) async {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return;
  await ChatService.instance.sendMessage(
  orderId: widget.orderId,
  senderId: me,
  text: trimmed,
  );
  _controller.clear();
  },
  quickActions: myQuick,
  trailingActions: widget.isAdminView
  ? [
  IconButton(
  tooltip: 'Set ETA',
  icon: const Icon(Icons.schedule, color: Color(0xFF1A233D)),
  onPressed: _sendEtaPrompt,
  )
  ]
      : const [],
  ),
  ],
  ),
  ),
  ],
  ),
  );
  }

  Future<void> _sendEtaPrompt() async {
  final me = FirebaseAuth.instance.currentUser?.uid ?? '';
  final minutes = await showDialog<int?>(
  context: context,
  builder: (_) {
  final c = TextEditingController();
  return AlertDialog(
  title: const Text('Set ETA (minutes)'),
  content: TextField(
  controller: c,
  keyboardType: TextInputType.number,
  decoration: const InputDecoration(hintText: 'e.g. 12'),
  ),
  actions: [
  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
  ElevatedButton(
  onPressed: () {
  final n = int.tryParse(c.text.trim());
  Navigator.pop(context, n);
  },
  child: const Text('Send'),
  )
  ],
  );
  },
  );
  if (minutes == null || minutes <= 0) return;
  await ChatService.instance.sendMessage(
  orderId: widget.orderId,
  senderId: me,
  text: 'ETA ~$minutes minutes.',
  );
  }

  void _showAdminMoreTemplates() {
  final me = FirebaseAuth.instance.currentUser?.uid ?? '';
  showModalBottomSheet(
  context: context,
  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
  builder: (_) => SafeArea(
  child: ListView.separated(
  padding: const EdgeInsets.all(8),
  itemCount: _adminMore.length,
  separatorBuilder: (_, __) => const Divider(height: 0),
  itemBuilder: (_, i) {
  final text = _adminMore[i];
  return ListTile(
  title: Text(text),
  onTap: () async {
  Navigator.pop(context);
  await ChatService.instance.sendMessage(orderId: widget.orderId, senderId: me, text: text);
  },
  );
  },
  ),
  ),
  );
  }

  void _showOrderDetails() {
  showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
  builder: (_) => _OrderDetailsSheet(orderId: widget.orderId),
  );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.quickActions,
    this.trailingActions = const [],
  });

  final TextEditingController controller;
  final Future<void> Function(String) onSend;
  final List<(String label, String text)> quickActions;
  final List<Widget> trailingActions;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (quickActions.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                scrollDirection: Axis.horizontal,
                itemCount: quickActions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final (label, text) = quickActions[i];
                  return OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF1A233D),
                      side: const BorderSide(color: Colors.white),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => onSend(text),
                    child: Text(label),
                  );
                },
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    onSubmitted: (v) => onSend(v),
                    decoration: InputDecoration(
                      hintText: 'Type a message…',
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.black26),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.black26),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF1A233D), width: 1.4),
                      ),
                    ),
                    textInputAction: TextInputAction.newline,
                  ),
                ),
              ),
              ...trailingActions,
              Padding(
                padding: const EdgeInsets.only(right: 12.0, bottom: 8),
                child: CircleAvatar(
                  backgroundColor: const Color(0xFF1A233D),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: () => onSend(controller.text),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String? _pidOfItem(Map it) {
  final pid = (it['product_id'] ?? it['productId'] ?? it['id']);
  return pid?.toString();
}

String? _thumbFromImmediate(Map it) {
  if (it['image'] is Map && (it['image']['src'] ?? '').toString().isNotEmpty) {
    return it['image']['src'].toString();
  }
  if (it['image'] is String && (it['image'] as String).startsWith('http')) {
    return it['image'].toString();
  }
  if (it['images'] is List && (it['images'] as List).isNotEmpty) {
    final m = (it['images'] as List).first;
    if (m is Map && (m['src'] ?? '').toString().isNotEmpty) return m['src'].toString();
  }
  if ((it['imageUrl'] ?? '').toString().startsWith('http')) return it['imageUrl'].toString();
  return null;
}

Widget itemThumb(Map it, {double size = 36}) {
  final url = _thumbFromImmediate(it);
  if (url != null && url.isNotEmpty) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }

  final pid = _pidOfItem(it);
  if (pid == null) return const SizedBox.shrink();

  return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    future: FirebaseFirestore.instance.collection('products').doc(pid).get(),
    builder: (context, snap) {
      final m = snap.data?.data();
      final img = (m?['imageUrl'] ?? m?['image'] ?? '').toString();
      if (img.isEmpty) return const SizedBox.shrink();
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          img,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );
    },
  );
}

class _OrderDetailsSheet extends StatelessWidget {
  const _OrderDetailsSheet({required this.orderId});
  final String orderId;


  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('orders').doc(orderId);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: ref.get(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final m = snap.data?.data() ?? {};
            final items = (m['wooLineItems'] as List?) ?? (m['items'] as List?) ?? const [];
            final address = (m['address'] as Map?) ?? {};
            final total = (m['total'] ?? m['amount'] ?? 0).toString();
            final currency = (m['currency'] ?? '').toString();
            final currencySymbol = currency == 'EUR'
                ? '€'
                : currency == 'USD'
                ? '\$'
                : currency == 'GBP'
                ? '£'
                : currency; // fallback
            final email = (m['email'] ?? m['address']?['email'] ?? '').toString();
            // SUBSCRIPTION LOGIC (moved OUTSIDE widget tree)
            final bool isSub = (m['meta']?['delivery_type'] ?? '') == 'subscription';
            final String cycle = (m['cycle_number'] ?? '').toString();
            final String parent = (m['parentId'] ?? '').toString();


            return Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: ListView(
                controller: controller,
                children: [
                  Center(
                    child: Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(3))),
                  ),
                  const SizedBox(height: 16),
                  Text('Order Receipt', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A233D))),

                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    const Text(
                      // keep it subtle but in brand color
                      '',
                      // placeholder removed – we’ll show email below with color
                    ),
                  ],
                  // dark-blue email:
                  if (email.isNotEmpty)
                    const SizedBox(height: 0),
                  if (email.isNotEmpty)
                    Text(email, style: const TextStyle(color: Color(0xFF1A2D3D), fontWeight: FontWeight.w600)),

                  const SizedBox(height: 16),
                  const Divider(height: 24),
                  const Text('Items', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1A233D))),
                  const SizedBox(height: 8),

                  ...items.map((raw) {
                    // normalize to Map<String, dynamic>
                    final Map<String, dynamic> it = (raw is Map<String, dynamic>)
                        ? raw
                        : Map<String, dynamic>.from(raw as Map);

                    final String name = (it['name'] ?? 'Item').toString();
                    final String qty  = (it['quantity'] ?? 1).toString();
                    final String price = (it['total'] ?? '').toString(); // show line total on the right

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // thumbnail (helper hides itself if none/404)
                          itemThumb(it, size: 36),
                          const SizedBox(width: 10),

                          // name × qty
                          Expanded(
                            child: Text(
                              '$name × $qty',
                              softWrap: true,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A2D3D), // dark blue body
                              ),
                            ),
                          ),

                          // price (uses the already computed currencySymbol)
                          Text(
                            price.isNotEmpty ? '$currencySymbol $price' : '',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A2D3D), // dark blue price
                            ),
                          ),
                        ],
                      ),
                    );
                  }),


                  const SizedBox(height: 16),
                  const Divider(height: 24),
                  const Text('Delivery', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1A233D))),
                  const SizedBox(height: 8),

                  Text(
                    (address['address_1'] ?? address['line1'] ?? address['address'] ?? '').toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2A3A58), // slightly lighter than header
                    ),
                  ),
                  if ((address['city'] ?? '').toString().isNotEmpty)
                    Text(
                      address['city'],
                      style: const TextStyle(fontSize: 13, color: Color(0xFF2A3A58)),
                    ),
                  if ((address['country'] ?? '').toString().isNotEmpty)
                    Text(
                      address['country'],
                      style: const TextStyle(fontSize: 13, color: Color(0xFF2A3A58)),
                    ),


                  const SizedBox(height: 16),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total (incl. VAT)',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1A233D)),
                      ),
                      Text(
                        '$currency $total',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Color(0xFF1A2D3D),
                        ),
                      ),
                    ],
                  ),

                  if (isSub) ...[
                    const SizedBox(height: 20),
                    const Divider(height: 24),

                    const Text(
                      'Subscription Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A233D),
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (cycle.isNotEmpty)
                      Text(
                        'Current Cycle: $cycle',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A2D3D),
                        ),
                      ),

                    if (parent.isNotEmpty)
                      Text(
                        'Parent Subscription: ${parent.substring(0, 8)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF2A3A58),
                        ),
                      ),

                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      icon: const Icon(Icons.cancel, color: Colors.white),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      label: const Text(
                        'Cancel Subscription',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Cancel Subscription'),
                            content: const Text('Are you sure you want to cancel this subscription?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await FirebaseFirestore.instance
                              .collection('orders')
                              .doc(orderId)
                              .update({
                            'subscriptionCancelled': true,
                            'status': 'cancelled',
                            'updatedAt': FieldValue.serverTimestamp(),
                          });
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ],



                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }



}


