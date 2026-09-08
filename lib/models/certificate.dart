/// Mirrors public.certificates in supabase/schema.sql.
class Certificate {
  final String id;
  final String workerId;
  final String title;
  final String? issuer;
  final String filePath;
  final DateTime createdAt;

  const Certificate({
    required this.id,
    required this.workerId,
    required this.title,
    this.issuer,
    required this.filePath,
    required this.createdAt,
  });

  bool get isImage {
    final ext = filePath.toLowerCase();
    return ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png');
  }

  factory Certificate.fromMap(Map<String, dynamic> map) {
    return Certificate(
      id: map['id'] as String,
      workerId: map['worker_id'] as String,
      title: map['title'] as String,
      issuer: map['issuer'] as String?,
      filePath: map['file_path'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
