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
  final String status; // open | accepted | in_progress | completed | cancelled
  final String paymentStatus; // unpaid | paid | refund_requested | refunded
  final DateTime createdAt;
  final String? clientName;
  final String? workerName;

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
    required this.createdAt,
    this.clientName,
    this.workerName,
  });

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
      createdAt: DateTime.parse(map['created_at'] as String),
      clientName: _fullName(map['client']),
      workerName: _fullName(map['worker']),
    );
  }

  static String? _fullName(dynamic profile) {
    if (profile is! Map) return null;
    final first = profile['first_name'] as String?;
    final last = profile['last_name'] as String?;
    if ((first == null || first.isEmpty) && (last == null || last.isEmpty)) return null;
    return '${first ?? ''} ${last ?? ''}'.trim();
  }
}
