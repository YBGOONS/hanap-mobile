import 'package:flutter/material.dart';
import '../../main.dart';
import '../../models/job.dart';
import '../../models/message.dart';
import '../../theme/dashboard_theme.dart';

/// One job's message thread. Streams live via Supabase Realtime (the
/// `messages` table is added to the `supabase_realtime` publication in
/// schema.sql) so both sides see new messages without polling or a manual
/// refresh.
class ChatScreen extends StatefulWidget {
  final Job job;
  final String otherName;
  const ChatScreen({super.key, required this.job, required this.otherName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _bodyCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late final String _userId;
  late final Stream<List<Map<String, dynamic>>> _stream;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _userId = supabase.auth.currentUser!.id;
    _stream = supabase.from('messages').stream(primaryKey: ['id']).eq('job_id', widget.job.id).order('created_at');
    _markRead();
  }

  @override
  void dispose() {
    _bodyCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    await supabase
        .from('messages')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('job_id', widget.job.id)
        .neq('sender_id', _userId)
        .isFilter('read_at', null);
  }

  Future<void> _send() async {
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    _bodyCtrl.clear();
    try {
      await supabase.from('messages').insert({'job_id': widget.job.id, 'sender_id': _userId, 'body': body});
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DashboardColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: DashboardColors.primary),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.otherName, style: DashboardText.heading(size: 15, color: Colors.black87)),
            Text(widget.job.category, style: DashboardText.body(size: 11, color: DashboardColors.muted)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: DashboardColors.primary));
                }
                final messages = snapshot.data!.map((m) => Message.fromMap(m)).toList();
                if (messages.isEmpty) {
                  return Center(
                    child: Text("Say hello to ${widget.otherName}.", style: DashboardText.body(size: 13, color: DashboardColors.muted)),
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollCtrl.hasClients) {
                    _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
                  }
                });
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, i) => _MessageBubble(message: messages[i], isMine: messages[i].senderId == _userId),
                );
              },
            ),
          ),
          _Composer(controller: _bodyCtrl, sending: _sending, onSend: _send),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  const _MessageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final time = "${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}";
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? DashboardColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: isMine ? null : Border.all(color: DashboardColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message.body, style: DashboardText.body(size: 14, color: isMine ? Colors.white : Colors.black87)),
            const SizedBox(height: 4),
            Text(time, style: DashboardText.body(size: 10, color: isMine ? Colors.white70 : DashboardColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  const _Composer({required this.controller, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: DashboardColors.border))),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: DashboardText.body(size: 14, color: Colors.black87),
                decoration: InputDecoration(
                  hintText: "Type a message…",
                  hintStyle: DashboardText.body(size: 14, color: DashboardColors.muted),
                  filled: true,
                  fillColor: DashboardColors.bg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: sending ? null : onSend,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: DashboardColors.accent, shape: BoxShape.circle),
                child: sending
                    ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send, color: Colors.white, size: 19),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
