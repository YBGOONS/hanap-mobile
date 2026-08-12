/// Short, human-readable reference code derived from a job's UUID — not a
/// separate stored value, just a display-friendly slice of the id that
/// already uniquely identifies the row. Lets users tell jobs apart at a
/// glance (e.g. two "Plumbing" postings) without exposing the raw UUID.
String jobRefNo(String jobId) {
  final clean = jobId.replaceAll('-', '').toUpperCase();
  final code = clean.length >= 8 ? clean.substring(0, 8) : clean.padRight(8, '0');
  return 'HJ-$code';
}
