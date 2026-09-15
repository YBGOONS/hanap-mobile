/// Mirrors public.work_photos in supabase/schema.sql.
class WorkPhoto {
  final String id;
  final String workerId;
  final String photoPath;
  final String? caption;
  final DateTime createdAt;

  const WorkPhoto({
    required this.id,
    required this.workerId,
    required this.photoPath,
    this.caption,
    required this.createdAt,
  });

  factory WorkPhoto.fromMap(Map<String, dynamic> map) {
    return WorkPhoto(
      id: map['id'] as String,
      workerId: map['worker_id'] as String,
      photoPath: map['photo_path'] as String,
      caption: map['caption'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
