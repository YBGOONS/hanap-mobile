/// Mirrors public.jobs in supabase/schema.sql.
class Job {
  final String id;
  final String clientId;
  final String? workerId;
  final String category;
  final String description;
  final double? budget;
  final String location;
  final DateTime? scheduledDate;
  final String status; // open | accepted | arrived | in_progress | completed | cancelled
  final String paymentStatus; // unpaid | paid | refund_requested | refunded | released
  final double? serviceFee; // HANAP's 10% cut, set once escrowed
  final String? arrivalOtp; // shown to the client, entered by the worker on arrival
  final DateTime? arrivalVerifiedAt;
  final List<String> completionPhotos; // storage paths in the completion-photos bucket
  final DateTime? confirmedAt;
  final DateTime createdAt;
  final String? clientName;
  final String? workerName;
  final int? rating;
  final String? ratingComment;
  final String? refundAdminMessage;

  const Job({
    required this.id,
    required this.clientId,
    this.workerId,
    required this.category,
    required this.description,
    this.budget,
    required this.location,
    this.scheduledDate,
    required this.status,
    this.paymentStatus = 'unpaid',
    this.serviceFee,
    this.arrivalOtp,
    this.arrivalVerifiedAt,
    this.completionPhotos = const [],
    this.confirmedAt,
    required this.createdAt,
    this.clientName,
    this.workerName,
    this.rating,
    this.ratingComment,
    this.refundAdminMessage,
  });

  /// Labor fee + service fee — what the client actually pays at escrow time.
  double get totalCharged => (budget ?? 0) + (serviceFee ?? 0);

  factory Job.fromMap(Map<String, dynamic> map) {
    return Job(
      id: map['id'] as String,
      clientId: map['client_id'] as String,
      workerId: map['worker_id'] as String?,
      category: map['category'] as String,
      description: map['description'] as String,
      budget: (map['budget'] as num?)?.toDouble(),
      location: map['location'] as String,
      scheduledDate: map['scheduled_date'] != null ? DateTime.tryParse(map['scheduled_date'] as String) : null,
      status: map['status'] as String,
      paymentStatus: map['payment_status'] as String? ?? 'unpaid',
      serviceFee: (map['service_fee'] as num?)?.toDouble(),
      arrivalOtp: map['arrival_otp'] as String?,
      arrivalVerifiedAt: map['arrival_verified_at'] != null ? DateTime.tryParse(map['arrival_verified_at'] as String) : null,
      completionPhotos: (map['completion_photos'] as List?)?.cast<String>() ?? const [],
      confirmedAt: map['confirmed_at'] != null ? DateTime.tryParse(map['confirmed_at'] as String) : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      clientName: _fullName(map['client']),
      workerName: _fullName(map['worker']),
      rating: _rating(map['ratings'])?['rating'] as int?,
      ratingComment: _rating(map['ratings'])?['comment'] as String?,
      refundAdminMessage: map['refund_admin_message'] as String?,
    );
  }

  /// `ratings` comes back from Supabase as a *single embedded object* (not
  /// a list) when the query selects `ratings(rating,comment)` — the unique
  /// constraint on ratings.job_id makes PostgREST treat this as a to-one
  /// relationship. Handles the list shape too, defensively, in case that
  /// ever changes. Absent/null entirely on queries that don't embed it, or
  /// on a job that hasn't been rated yet.
  static Map<String, dynamic>? _rating(dynamic embedded) {
    if (embedded is Map) return embedded.cast<String, dynamic>();
    if (embedded is List && embedded.isNotEmpty) return embedded.first as Map<String, dynamic>;
    return null;
  }

  static String? _fullName(dynamic profile) {
    if (profile is! Map) return null;
    final first = profile['first_name'] as String?;
    final last = profile['last_name'] as String?;
    if ((first == null || first.isEmpty) && (last == null || last.isEmpty)) return null;
    return '${first ?? ''} ${last ?? ''}'.trim();
  }
}
