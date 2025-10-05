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

  @override
  Widget build(BuildContext context) {
    final when = time != null ? _fmt(time!) : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF2F6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.8)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline, size: 16, color: Color(0xFF4A5673)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(text,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF4A5673), fontWeight: FontWeight.w600)),
                ),
                if (when.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(when, style: const TextStyle(fontSize: 10, color: Color(0xFF7C869D))),
                ],
              ],
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
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
            Text(
              text,
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
  adminId: 'ADMIN',
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
                      side: const BorderSide(color: Color(0xFF1A233D)),
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
            final email = (m['email'] ?? m['address']?['email'] ?? '').toString();

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
                  Text('Order #$orderId', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(email, style: const TextStyle(color: Colors.black54)),
                  ],
                  const SizedBox(height: 16),
                  const Divider(height: 24),
                  const Text('Items', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ...items.map((it) {
                    final name = (it is Map && it['name'] != null) ? it['name'].toString() : 'Item';
                    final qty  = (it is Map && it['quantity'] != null) ? it['quantity'].toString() : '1';
                    final price = (it is Map && it['total'] != null) ? it['total'].toString() : '';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(child: Text('$name × $qty', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                          Text(price.isNotEmpty ? '$currency $price' : '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  const Divider(height: 24),
                  const Text('Delivery', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text((address['address_1'] ?? address['line1'] ?? address['address'] ?? '').toString(),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if ((address['city'] ?? '').toString().isNotEmpty) Text(address['city'], style: const TextStyle(color: Colors.black54)),
                  if ((address['country'] ?? '').toString().isNotEmpty) Text(address['country'], style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 16),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Text('$currency $total', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    ],
                  ),
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
