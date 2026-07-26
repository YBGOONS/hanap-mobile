/// Mirrors public.notifications in supabase/schema.sql — system-generated
/// events (job accepted, status changed, paid, refund requested/resolved).
class AppNotification {
  final String id;
  final String title;
  final String? body;
  final String? jobId;
  final DateTime createdAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    required this.title,
    this.body,
    this.jobId,
    required this.createdAt,
    this.readAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      title: map['title'] as String,
      body: map['body'] as String?,
      jobId: map['job_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      readAt: map['read_at'] != null ? DateTime.parse(map['read_at'] as String) : null,
    );
  }
}
