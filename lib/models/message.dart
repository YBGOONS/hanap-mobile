/// Mirrors public.messages in supabase/schema.sql — one thread per job.
class Message {
  final String id;
  final String jobId;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  const Message({
    required this.id,
    required this.jobId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String,
      jobId: map['job_id'] as String,
      senderId: map['sender_id'] as String,
      body: map['body'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      readAt: map['read_at'] != null ? DateTime.parse(map['read_at'] as String) : null,
    );
  }
}
