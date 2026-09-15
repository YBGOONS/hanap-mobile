/// Mirrors public.refund_messages in supabase/schema.sql — one entry in
/// the back-and-forth between client and worker on a refund dispute
/// (admin joins the same thread once the worker has replied).
class RefundMessage {
  final String id;
  final String jobId;
  final String senderId;
  final String? senderName;
  final String? senderRole;
  final String body;
  final String? evidencePath;
  final DateTime createdAt;

  const RefundMessage({
    required this.id,
    required this.jobId,
    required this.senderId,
    this.senderName,
    this.senderRole,
    required this.body,
    this.evidencePath,
    required this.createdAt,
  });

  bool get isFromAdmin => senderRole == 'admin';

  factory RefundMessage.fromMap(Map<String, dynamic> map) {
    final sender = map['sender'] as Map<String, dynamic>?;
    final first = sender?['first_name'] as String?;
    final last = sender?['last_name'] as String?;
    final name = [
      first,
      last,
    ].where((s) => s != null && s.isNotEmpty).join(' ');
    return RefundMessage(
      id: map['id'] as String,
      jobId: map['job_id'] as String,
      senderId: map['sender_id'] as String,
      senderName: name.isEmpty ? null : name,
      senderRole: sender?['role'] as String?,
      body: map['body'] as String,
      evidencePath: map['evidence_path'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
